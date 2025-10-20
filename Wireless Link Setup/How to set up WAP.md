# How to set up the WAP on the Raspberry PI
In our case, we uses the mediatek mt7921u 802.11ax chipset as a tri-band WiFi 6E USB adapter from Amazon: [EDUP USB 3.0 WiFi 6E Adapter, AXE3000](https://www.amazon.com/dp/B0CZ82RM5L?ref=ppx_yo2ov_dt_b_fed_asin_title). For a list of easy-to-use chipsets with Linux in-kernel drivers check out [USB-WiFi](https://github.com/morrownr/USB-WiFi/tree/main). This is also a partial resource for setting up wireless access points or bridged wireless access points.

This process is intended to be done as part of setup, and can probably be easily ported to a bash script. As of 9/29/2025 this process needs to be verified with a fresh ubuntu install.

## 1. Confirm adapter has drivers:
To see if the device was automatically detected:
`lsusb`
Now check that the correct driver shows up (looking for mt7921u but sometimes mt76x drivers will be automatically adopted):
`lsmod | grep "mt7*"`

## 2. Install packages
`sudo apt install hostapd dnsmasq iptables net-tools`
hostapd (host access point daemon) is the access point/authentication server.
dnsmasq is the DHCP server.

## 3. configure AP interface:
`ip link`
select the correct interface name, eg wlan0
and create a netplan:
`sudo vim /etc/netplan/01-hotspot.yaml`

The netplan should contain:
```
network:
  version: 2
  renderer: networkd
  ethernets:
    wlan0:
      addresses: [192.168.50.1/24]
      dhcp4: no
```
Apply netplan with
`sudo netplan apply`

## 4. Set up hostapd configuration:
`sudo vim /etc/hostapd/hostapd.conf`

Set the configuration to use 802.11n and advertise HT (40MHz) and short guard interval modes
For more documentation see the [hostapd documentation](https://w1.fi/hostapd/) and [hostapd.conf example](https://git.w1.fi/cgit/hostap/plain/hostapd/hostapd.conf)

```
country_code=US
interface=wlan0
driver=nl80211
ssid=PiAP
hw_mode=g
channel=6
ieee80211n=1
ht_capab=[HT40+][SHORT-GI-20][SHORT-GI-40]
require_ht=1
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=StrongPass123
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_pairwise=CCMP
disassoc_low_ack=0
```

now point hostapd to the hostapd.conf file
`sudo vim /etc/default/hostapd`
and set
`DAEMON_CONF="/etc/hostapd/hostapd.conf"`

## 5. Configure dnsmasq (DHCP server)
back up the original dnsmasq.conf

`sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig`

create a new dnsmasq.conf file to define the ip range and lease duration

`sudo vim /etc/dnsmasq.conf`

```
interface=wlan0
dhcp-authoritative
dhcp-range=192.168.50.2,192.168.50.20,255.255.255.0,24h
```

## 6. Start (and default to start on boot) services
```
sudo systemctl unmask hostapd
sudo systemctl unmask dnsmasq
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl start hostapd
sudo systemctl start dnsmasq
```

### if this fails it may be because something else is already bound to port 55
`sudo lsof -i :53`
### to see if something is bound to port 53... if smth is bound to port 53 then that's what's blocking dnsmasq
### in my case it was systemd-resolved... to fix:
```
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
sudo systemctl restart hostapd
sudo systemctl restart dnsmasq
```

## Common issues:
### 1. "failed to resolve..."
Several times, I encountered that the DNS server was broken by this proccess. If this is the case, you can get the error "failed to resolve..." when doing normal internet-accessing operations. If this occurs after running this proccess, you can fix this with the following:
#### A. Make sure that /etc/resolv.conf is not a symbolic link
```
sudo ls -l /etc/resolv.conf
sudo cat /etc/resolv.conf
```

#### B. Replace it temporarily with a real nameserver
```
sudo rm /etc/resolv.conf
echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" | sudo tee /etc/resolv.conf
```

#### C. Update and replace /etc/resolv.conf when prompted
```
sudo apt update
sudo apt upgrade
```

### 2. networkd vs NM conflict
Using systemd-networkd instead of NetworkManager can cause conflicts. Not really sure how to resolve this one yet other than disabling one of the services. Setting up an AP with Network Manager doesn't allow the same level of configurability as hostapd so we elect not to use it, but using Network Manager to configure other WiFi connections might cause conflict.

