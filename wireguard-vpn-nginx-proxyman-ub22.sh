apt-get update -y && \
apt install git wireguard-tools net-tools --no-install-recommends -y && \
git clone https://github.com/donaldzou/WGDashboard.git && \
cd ./WGDashboard/src && \
chmod +x ./wgd.sh && \
./wgd.sh install && \
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf && \
sysctl -p /etc/sysctl.conf

apt install docker.io docker-compose -y

mkdir -p /root/compose
mkdir -p /root/compose/proxyman

touch /root/compose/proxyman/compose.yml

cat <<EOL > /root/compose/proxyman/compose.yml
version: '3.8'
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    network_mode: "host"   # Use host network mode
EOL

cd /root/compose/proxyman
docker-compose up -d

cd /root/WGDashboard/src
./wgd.sh start
