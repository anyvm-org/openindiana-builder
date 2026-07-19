


# --- console autologin as root (no prompt, no password), with job control ---
cat > /lib/svc/method/console-autologin.py <<'PY'
import os, fcntl, termios
try:
    os.setsid()
except OSError:
    pass
fd = os.open("/dev/console", os.O_RDWR | os.O_NOCTTY)
try:
    fcntl.ioctl(fd, termios.TIOCSCTTY, 0)
except OSError:
    pass
for n in (0, 1, 2):
    os.dup2(fd, n)
if fd > 2:
    os.close(fd)
os.execv("/usr/bin/login", ["login", "-f", "root"])
PY

cat > /lib/svc/method/console-autologin <<'SH'
#!/sbin/sh
instance="$1"
if [ "$instance" = "default" ]; then
    exec /usr/bin/python3 /lib/svc/method/console-autologin.py
fi
exec /lib/svc/method/console-login "$instance"
SH
chmod 0755 /lib/svc/method/console-autologin

svccfg <<'CFG'
select svc:/system/console-login
setprop start/exec = astring: "/lib/svc/method/console-autologin %i"
end
CFG
svcadm refresh svc:/system/console-login:default




rm -f "$HISTFILE" || rm -f ~/.sh_history


# --- Image-slimming cleanup ---
# vm_postBuild.sh runs `pkg update`, and IPS performs the upgrade into a NEW
# boot environment: the OLD BE (a snapshot of the entire pre-update system)
# stays in the pool and is a big part of why the -build images ballooned to
# 5.7-6.5 GB compressed. Destroy every inactive BE (solaris-builder does the
# same in its finalize), then TRIM: destroying only frees the blocks inside
# ZFS -- without a TRIM they stay allocated in the qcow2 and the export-time
# `qemu-img convert -S 4k` sparsify cannot reclaim them (they are not zero).
# QEMU runs the build disk with discard=unmap, so trimmed blocks become
# holes. illumos-gate has had `zpool trim` since 2020, but its -w (wait)
# flag may be absent, so fall back to a bounded poll of `zpool status -t`.
# The in-progress marker in `zpool status -t` is "(N% trimmed, started at
# ...)" and flips to "completed at" when done (verified from real OI and
# FreeBSD build logs) -- poll for "trimmed, started", NOT "trimming" (that
# word never appears; the first version of this loop used it, matched
# nothing, and the shutdown killed the trim at 0%).

echo "=== finalize: image cleanup ==="

# Destroy inactive BEs: rows whose Mountpoint column is "-" (the active BE
# is mounted at /; the header row has "Mountpoint" there, so both human
# layouts filter safely).
beadm list 2>/dev/null | awk '$3 == "-" { print $1 }' | while read -r _be; do
    echo "Destroying inactive BE: ${_be}"
    beadm destroy -F "${_be}" || echo "beadm destroy ${_be} failed (non-fatal)"
done

for _pool in $(zpool list -H -o name 2>/dev/null); do
    echo "Trimming pool ${_pool}..."
    if ! zpool trim -w "${_pool}" 2>/dev/null; then
        if zpool trim "${_pool}"; then
            _i=0
            while zpool status -t "${_pool}" 2>/dev/null | grep -q "trimmed, started"; do
                _i=$((_i + 1))
                [ "${_i}" -ge 120 ] && { echo "trim wait cap hit"; break; }
                sleep 5
            done
        else
            echo "zpool trim ${_pool} unsupported (non-fatal)"
        fi
    fi
    zpool status -t "${_pool}" || true
done

df -h || true
echo "=== finalize: image cleanup done ==="
