apt update
apt remove openssh-client openssh-server -y

apt-get remove exim4 exim4-base exim4-config exim4-daemon-light -y
apt install git -y
apt-get install sudo git iptables -y && \
sudo apt-get update && \
sudo apt install wireguard-tools net-tools && \
git clone https://github.com/donaldzou/WGDashboard.git && \
cd ./WGDashboard/src && \
chmod +x ./wgd.sh && \
./wgd.sh install && \
sudo echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf && \
sudo sysctl -p /etc/sysctl.conf
apt autoremove -y

cat << EOF > /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $prikey
Address = 10.255.255.1/24
ListenPort = 65533
SaveConfig = true
DNS = 1.1.1.1, 8.8.8.8

PostUp = sysctl -q -w net.ipv4.ip_forward=1
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = sysctl -q -w net.ipv4.ip_forward=0
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

chmod 600 /etc/wireguard/wg0.conf

echo "WireGuard configuration created at: /etc/wireguard/wg0.conf"

systemctl stop systemd-resolved
sed -i 's/10086/65534/g' static/app/proxy.js
sed -i 's/10086/65534/g' dashboard.py
sed -i 's/#LLMNR=yes/LLMNR=no/g' /etc/systemd/resolved.conf

cd /root/WGDashboard/src
./wgd.sh start
