#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print colored messages
print_message() {
    echo -e "${2}${1}${NC}"
}

# Function to generate random password
generate_password() {
    openssl rand -base64 16 | tr -d '/+=' | head -c 16
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_message "Please run as root" "$RED"
    exit 1
fi

# Check Ubuntu version
UBUNTU_VERSION=$(lsb_release -cs)
if [[ "$UBUNTU_VERSION" != "focal" && "$UBUNTU_VERSION" != "jammy" ]]; then
    print_message "This script is designed for Ubuntu 20.04 (Focal) or 22.04 (Jammy)" "$RED"
    exit 1
fi

# Get domain from user
print_message "Please enter your domain (e.g., hy2.example.com):" "$YELLOW"
read -r DOMAIN

# Validate domain format
if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9](?:\.[a-zA-Z]{2,})+$ ]]; then
    print_message "Invalid domain format" "$RED"
    exit 1
fi

# Ask if user wants to use Cloudflare
print_message "Do you want to use Cloudflare? (y/n):" "$YELLOW"
read -r USE_CLOUDFLARE

if [[ "$USE_CLOUDFLARE" =~ ^[Yy]$ ]]; then
    print_message "You will need to log in to Cloudflare when prompted" "$YELLOW"
    print_message "Press Enter to continue..." "$YELLOW"
    read -r
fi

# Generate and save password
PASSWORD=$(generate_password)
echo "Generated password: $PASSWORD" > /etc/hysteria/password.txt
chmod 600 /etc/hysteria/password.txt

# Update system
print_message "Updating system..." "$YELLOW"
apt update && apt upgrade -y

# Install required packages
print_message "Installing required packages..." "$YELLOW"
apt install -y curl wget git nginx certbot python3-certbot-nginx cloudflared openssl ufw

# Configure UFW firewall
print_message "Configuring firewall..." "$YELLOW"
ufw allow 443/tcp
ufw allow 80/tcp
ufw --force enable

# Install acme.sh
print_message "Installing acme.sh..." "$YELLOW"
curl https://get.acme.sh | sh
source ~/.bashrc

# Install Hysteria 2
print_message "Installing Hysteria 2..." "$YELLOW"
bash <(curl -fsSL https://get.hy2.sh/)

# Create necessary directories
print_message "Creating directories..." "$YELLOW"
mkdir -p /etc/hysteria
mkdir -p /var/www/html

# Create a simple index.html for masquerade
cat > /var/www/html/index.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>Welcome</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
        }
        p {
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to Our Website</h1>
        <p>This is a normal website.</p>
    </div>
</body>
</html>
EOL

# Configure Nginx
print_message "Configuring Nginx..." "$YELLOW"
cat > /etc/nginx/sites-available/hysteria << EOL
server {
    listen 80;
    server_name ${DOMAIN};

    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /api {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
EOL

ln -s /etc/nginx/sites-available/hysteria /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Configure Cloudflare Tunnel (only if user chose to use Cloudflare)
if [[ "$USE_CLOUDFLARE" =~ ^[Yy]$ ]]; then
    print_message "Configuring Cloudflare Tunnel..." "$YELLOW"
    cloudflared tunnel login
    cloudflared tunnel create hysteria-tunnel

    # Create Cloudflare Tunnel config
    cat > /etc/cloudflared/config.yml << EOL
tunnel: your-tunnel-id  # Replace with your tunnel ID
credentials-file: /root/.cloudflared/your-tunnel-id.json  # Replace with your credentials file path

ingress:
  - hostname: ${DOMAIN}
    service: http://localhost:80
  - service: http_status:404
EOL

    # Create systemd service for Cloudflare Tunnel
    cat > /etc/systemd/system/cloudflared.service << 'EOL'
[Unit]
Description=cloudflared
After=network.target

[Service]
TimeoutStartSec=0
Type=notify
ExecStart=/usr/bin/cloudflared tunnel --config /etc/cloudflared/config.yml run
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

    # Start Cloudflare Tunnel service
    systemctl enable cloudflared
    systemctl start cloudflared
fi

# Create systemd service for Hysteria
cat > /etc/systemd/system/hysteria.service << 'EOL'
[Unit]
Description=Hysteria 2 Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/server.json
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

# Install WARP
print_message "Installing WARP..." "$YELLOW"
curl -fsSL https://pkg.cloudflareclient.com/cloudflare-warp-archive-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $UBUNTU_VERSION main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
apt update
apt install -y cloudflare-warp

# Configure WARP
print_message "Configuring WARP..." "$YELLOW"
warp-cli register
warp-cli set-mode proxy
warp-cli set-proxy-port 40000

# Start services (modified to handle optional Cloudflare)
print_message "Starting services..." "$YELLOW"
systemctl daemon-reload
systemctl enable nginx hysteria
systemctl start nginx hysteria

if [[ "$USE_CLOUDFLARE" =~ ^[Yy]$ ]]; then
    systemctl enable cloudflared
    systemctl start cloudflared
fi

# Get SSL certificate
print_message "Getting SSL certificate..." "$YELLOW"
acme.sh --issue -d ${DOMAIN} --nginx

# Final setup
print_message "Setting up final configurations..." "$YELLOW"
cp /root/.acme.sh/${DOMAIN}/fullchain.cer /etc/hysteria/cert.crt
cp /root/.acme.sh/${DOMAIN}/${DOMAIN}.key /etc/hysteria/cert.key

# Update server config with generated password
cat > /etc/hysteria/server.json << EOL
{
  "listen": ":443",
  "tls": {
    "cert": "/etc/hysteria/cert.crt",
    "key": "/etc/hysteria/cert.key",
    "alpn": "h3"
  },
  "auth": {
    "type": "password",
    "password": "$PASSWORD"
  },
  "masquerade": {
    "type": "file",
    "file": "/etc/hysteria/masquerade.json"
  },
  "bandwidth": {
    "up": "100 mbps",
    "down": "100 mbps"
  },
  "ignore_client_bandwidth": true,
  "disable_mtu_discovery": true,
  "hop_interval": 10,
  "fast_open": true
}
EOL

# Create client config with generated password
cat > /etc/hysteria/client.json << EOL
{
  "server": "${DOMAIN}:443",
  "auth": {
    "type": "password",
    "password": "$PASSWORD"
  },
  "tls": {
    "sni": "${DOMAIN}",
    "insecure": false
  },
  "bandwidth": {
    "up": "100 mbps",
    "down": "100 mbps"
  },
  "fast_open": true,
  "hop_interval": 10
}
EOL

# Create a backup of the password
cp /etc/hysteria/password.txt /root/hysteria_password.txt
chmod 600 /root/hysteria_password.txt

# Optimize system settings
print_message "Optimizing system settings..." "$YELLOW"
cat > /etc/sysctl.d/99-hysteria.conf << 'EOL'
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
EOL
sysctl -p /etc/sysctl.d/99-hysteria.conf

# Generate Hysteria 2 link
print_message "Generating Hysteria 2 link..." "$YELLOW"
HY2_LINK="hysteria://${PASSWORD}@${DOMAIN}:443?insecure=0&sni=${DOMAIN}"
echo "Hysteria 2 Link:" > /etc/hysteria/hy2_link.txt
echo $HY2_LINK >> /etc/hysteria/hy2_link.txt
chmod 600 /etc/hysteria/hy2_link.txt

# Create a backup of the link
cp /etc/hysteria/hy2_link.txt /root/hy2_link.txt
chmod 600 /root/hy2_link.txt

# Final status check
print_message "Setup completed successfully!" "$GREEN"
print_message "Your Hysteria 2 password has been saved to:" "$YELLOW"
print_message "/etc/hysteria/password.txt" "$YELLOW"
print_message "A backup has been created at:" "$YELLOW"
print_message "/root/hysteria_password.txt" "$YELLOW"
print_message "Your Hysteria 2 link has been saved to:" "$YELLOW"
print_message "/etc/hysteria/hy2_link.txt" "$YELLOW"
print_message "A backup of the link has been created at:" "$YELLOW"
print_message "/root/hy2_link.txt" "$YELLOW"
print_message "Please save these securely!" "$RED"
print_message "To view the password, run:" "$YELLOW"
print_message "cat /etc/hysteria/password.txt" "$YELLOW"
print_message "To view the Hysteria 2 link, run:" "$YELLOW"
print_message "cat /etc/hysteria/hy2_link.txt" "$YELLOW"
print_message "To check service status, run:" "$YELLOW"
print_message "sudo systemctl status hysteria" "$YELLOW"
print_message "sudo systemctl status nginx" "$YELLOW"
if [[ "$USE_CLOUDFLARE" =~ ^[Yy]$ ]]; then
    print_message "sudo systemctl status cloudflared" "$YELLOW"
fi

# 保存 Hysteria 2 链接
echo "hysteria://${PASSWORD}@${DOMAIN}:443?insecure=1&sni=${DOMAIN}#Hysteria2" > /etc/hysteria/hy2_link.txt
echo "hysteria://${PASSWORD}@${DOMAIN}:443?insecure=1&sni=${DOMAIN}#Hysteria2" > /root/hy2_link.txt

# 显示安装完成信息
echo -e "\n${GREEN}=== Hysteria 2 安装完成 ===${NC}"
echo -e "${YELLOW}您的 Hysteria 2 链接：${NC}"
echo -e "${GREEN}hysteria://${PASSWORD}@${DOMAIN}:443?insecure=1&sni=${DOMAIN}#Hysteria2${NC}"
echo -e "\n${YELLOW}重要信息已保存到：${NC}"
echo -e "密码：${GREEN}/etc/hysteria/password.txt${NC}"
echo -e "链接：${GREEN}/etc/hysteria/hy2_link.txt${NC}"
echo -e "\n${YELLOW}备份文件：${NC}"
echo -e "密码：${GREEN}/root/hysteria_password.txt${NC}"
echo -e "链接：${GREEN}/root/hy2_link.txt${NC}"
echo -e "\n${YELLOW}使用说明：${NC}"
echo -e "1. 请保存好您的密码和链接"
echo -e "2. 使用 Hysteria 2 客户端导入链接即可使用"
echo -e "3. 如需查看链接，可运行：${GREEN}cat /etc/hysteria/hy2_link.txt${NC}"
echo -e "4. 如需查看密码，可运行：${GREEN}cat /etc/hysteria/password.txt${NC}"
echo -e "\n${GREEN}=== 安装完成 ===${NC}\n"

# 重启服务
systemctl restart hysteria
if [ "$USE_CLOUDFLARE" = "y" ]; then
    systemctl restart cloudflared
fi 
