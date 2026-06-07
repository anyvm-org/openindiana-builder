


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

