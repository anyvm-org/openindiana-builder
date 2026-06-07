# Bring up the e1000g0 NIC + DHCP on the OpenIndiana guest console BEFORE
# _enable_ssh_console_branch pipes enablessh.local over nc/bash.
#
# Why this exists:
#   The OpenIndiana 2025.10 cloud image boots straight to the console login
#   with NO interface plumbed. Until e1000g0 has a DHCP lease the slirp host
#   (192.168.122.1) is unreachable, so the `nc 192.168.122.1 ... | sh` paste in
#   inputFileBash/inputFile would hang forever and sshd would never receive the
#   authorized_keys. Plumb e1000g0 + request a lease first.
#
#   The 2026.04 text-installer image configures networking during install, so
#   the `cat /etc/release | grep 2025.10` guard keeps this a no-op there --
#   faithfully reproducing the old `inputFileStdIn hooks/enableNetwork.sh`.
#
# Host-side hook: run by base-builder/build.py via exec() in this module's
# globals -- string / enter / time / log are bare names.

log("enableNetwork: plumb e1000g0 + DHCP on the guest console (2025.10 only)")

# One-liner so the guest shell itself evaluates the release guard: on 2025.10 it
# plumbs e1000g0 and blocks on `ifconfig ... dhcp` until a lease arrives; on
# 2026.04 the grep fails fast and nothing runs. build.py screenText()s and then
# sleeps 60s after this hook returns, which covers the DHCP wait.
string("if cat /etc/release | grep '2025.10'; then "
       "ifconfig e1000g0 plumb up; ifconfig e1000g0 dhcp; fi")
enter()
time.sleep(2)
