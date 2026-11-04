


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
# holes -- but only with the extent cap below (see the illumos sata bug).
# illumos-gate has had `zpool trim` since 2020, but its -w (wait) flag is
# absent (OI 2026.10: "invalid option 'w'"), so fall back to a bounded poll
# of `zpool status -t`.
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

# Leftover snapshots of the running BE. The installer's @install and the
# @<date> that `pkg update` cloned the new BE from end up on the surviving BE
# (and its /var) once the old BE is gone. Nothing in a CI image rolls back to
# them, and they pin the pre-update copy of every replaced file (2.2 GB on
# 202610). /etc/mnttab names the dataset mounted at /, and `zfs list -r`
# limits the destroys to it and its children -- never another BE or pool.
# A snapshot that is still a clone origin refuses to go (non-fatal).
_root=$(awk -F'\t' '$2 == "/" && $3 == "zfs" { print $1 }' /etc/mnttab)
if [ -n "${_root}" ]; then
    zfs list -H -t snapshot -o name -r "${_root}" 2>/dev/null | while read -r _snap; do
        echo "Destroying BE snapshot: ${_snap}"
        zfs destroy "${_snap}" || echo "zfs destroy ${_snap} failed (non-fatal)"
    done
fi

# illumos sata (AHCI) bug: sata_txlt_unmap() copies only the low 16 bits of
# each SCSI UNMAP range length into the ATA DSM TRIM entry and never splits a
# longer range, and as sata emulates no Block Limits VPD page, sd allows one
# range of any length. A manual trim hands out zfs_trim_extent_bytes_max =
# 128 MiB extents = 0x40000 sectors, whose low 16 bits are 0, and QEMU skips
# count-0 entries: the trim reports "100% trimmed, completed" yet discards
# nothing (202610 v2.1.5 shipped a 9.55 GB qcow2 for ~4 GB of live data).
# Capping extents at 16 MiB (32768 sectors) keeps every range below 65536.
# mdb -kw patches the running kernel only; the next boot is back to default.
echo 'zfs_trim_extent_bytes_max/W 0t16777216' | mdb -kw ||
    echo "cannot cap zfs_trim_extent_bytes_max (non-fatal, trim may be a no-op)"

for _pool in $(zpool list -H -o name 2>/dev/null); do
    # The destroys above free their blocks over the next txgs (async destroy,
    # then the deferred-free window); a trim started before that skips them.
    _i=0
    while :; do
        _freeing=$(zpool get -Hp -o value freeing "${_pool}" 2>/dev/null)
        [ -z "${_freeing}" ] || [ "${_freeing}" = "0" ] && break
        _i=$((_i + 1))
        [ "${_i}" -ge 60 ] && { echo "freeing wait cap hit"; break; }
        sleep 5
    done
    sync
    sleep 15
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
