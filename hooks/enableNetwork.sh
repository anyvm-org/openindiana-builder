
if cat /etc/release | grep '2025.10'; then

ifconfig e1000g0 plumb up ; ifconfig e1000g0 dhcp

fi