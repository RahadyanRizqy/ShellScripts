export DEBIAN_FRONTEND=noninteractive

echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bullseye pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list

wget https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg 

sha512sum /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg 

apt update && apt upgrade -y && apt full-upgrade -y && apt dist-upgrade -y

apt install pve-kernel-5.15 -y

apt install proxmox-ve postfix open-iscsi -y

apt remove linux-image-amd64 'linux-image-5.10*' -y

apt install isc-dhcp-server -y

a=/tmp/$(ls -la /tmp | grep ifupdown | awk '{print $9}')
rm $a

apt install -f -y

update-grub

cat <<EOT >> /etc/network/interfaces
auto vmbr0
iface vmbr0 inet static
        address 192.168.1.254/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0
        post-up   echo 1 > /proc/sys/net/ipv4/ip_forward
        post-up   iptables -t nat -A POSTROUTING -s '192.168.1.0/24' -o eth0 -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -s '192.168.1.0/24' -o eth0 -j MASQUERADE
EOT

cat <<EOT >> etc/dhcp/dhcpd.conf

subnet 192.168.1.0 netmask 255.255.255.0 {
  range 192.168.1.1 192.168.1.253;
  option routers 192.168.1.254;
  option domain-name-servers 8.8.8.8, 8.8.4.4;
  option subnet-mask 255.255.255.0;
}
EOT

sed -i 's/^INTERFACESv4=""/INTERFACESv4="vmbr0"/' /etc/default/isc-dhcp-server

NEW_IP=$(ip a | grep eth0 | head -n 2 | awk '{print $2}' | tail -n 1 | cut -d"/" -f1)
sed -i "s/^127\.0\.1\.1/$NEW_IP/" /etc/hosts

HOSTNAME=$(hostname)

mkdir /tmp/proxmox-cert

openssl genrsa -out /tmp/proxmox-cert/pve-ssl.key 2048

touch /tmp/proxmox-cert/openssl.cnf

cat <<EOL > /tmp/proxmox-cert/openssl.cnf
[req]
distinguished_name = req_distinguished_name
req_extensions = req_ext
prompt = no

[req_distinguished_name]
C = CH
ST = VD
L = Lausanne
O = DigitalOcean
OU = DigitalOcean VPS
CN = $HOSTNAME

[req_ext]
subjectAltName = @alt_names

[alt_names]
IP.1 = 127.0.0.1
DNS.1 = $HOSTNAME
DNS.2 = localhost
EOL

openssl req -new -key /tmp/proxmox-cert/pve-ssl.key -out /tmp/proxmox-cert/pve-ssl.csr -config /tmp/proxmox-cert/openssl.cnf

openssl x509 -req -days 365 -in /tmp/proxmox-cert/pve-ssl.csr -signkey /tmp/proxmox-cert/pve-ssl.key -out /tmp/proxmox-cert/pve-ssl.pem

cp /tmp/proxmox-cert/pve-ssl.key /etc/pve/nodes/$(hostname)/pve-ssl.key

cp /tmp/proxmox-cert/pve-ssl.pem /etc/pve/local/pve-ssl.pem

cat <<EOL > /etc/systemd/system/network-restart.service
[Unit]
Description=Restart Networking

[Service]
Type=oneshot
ExecStart=/bin/systemctl restart networking

[Install]
WantedBy=multi-user.target
EOL

cat <<EOL > /etc/systemd/system/dhcp-restart.service
[Unit]
Description=Restart DHCP
After=network-restart.service

[Service]
Type=oneshot
ExecStart=/bin/systemctl restart isc-dhcp-server

[Install]
WantedBy=multi-user.target
EOL

systemctl enable network-restart
systemctl enable dhcp-restart

systemctl reboot
