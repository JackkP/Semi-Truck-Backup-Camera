How to set up WAP

# 1. confirm adapter has drivers:
lsusb
# does it show up?
lsmod
# do drivers show up?

# 2. install packages
sudo apt install hostapd dnsmasq iptables net-tools

# 3. configure AP interface:
ip link
# -> select interface name, in my case wlxe84e06b0a485
# create a netplan:
sudo vim /etc/netplan/99-hotspot.yaml

network:
  version: 2
  renderer: networkd
  ethernets:
    wlxe84e06b0a485:
      addresses: [192.168.50.1/24]
      dhcp4: no

sudo netplan apply

# 4. configure hostapd
sudo vim /etc/hostapd/hostapd.conf

interface=wlxe84e06b0a485
driver=nl80211
ssid=PiAP
hw_mode=g
channel=6
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=StrongPass123
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP

sudo vim /etc/default/hostapd
# set
DAEMON_CONF="/etc/hostapd/hostapd.conf"

# 5. configure dnsmasq (DHCP server)
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig # back up original
sudo vim /etc/dnsmasq.conf
interface=wlxe84e06b0a485
dhcp-range=192.168.50.2,192.168.50.20,255.255.255.0,24h

# 6. start services
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl start hostapd
sudo systemctl start dnsmasq

# if this fails run
#sudo lsof -i :53
# to see if something is bound to port 53... if smth is bound to port 53 then that's what's blocking dnsmasq
# in my case it was systemd-resolved... to fix:
#sudo systemctl stop systemd-resolved
#sudo systemctl disable systemd-resolved
#sudo systemctl restart hostapd
#sudo systemctl restart dnsmasq

# to get it to auto start on boot
sudo systemctl enable dnsmasq
