#!/bin/bash

# 设置语言为 UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 输出彩色信息的函数
print_message() {
    echo -e "${2}${1}${NC}"
}

# 生成随机密码的函数
generate_password() {
    openssl rand -base64 16 | tr -d '/+=' | head -c 16
}

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then 
    print_message "请使用 root 权限运行此脚本" "$RED"
    exit 1
fi

# 检查 Ubuntu 版本
UBUNTU_VERSION=$(lsb_release -cs)
if [[ "$UBUNTU_VERSION" != "focal" && "$UBUNTU_VERSION" != "jammy" ]]; then
    print_message "此脚本仅支持 Ubuntu 20.04 (Focal) 或 22.04 (Jammy)" "$RED"
    exit 1
fi

# 创建必要的目录
print_message "正在创建必要的目录..." "$YELLOW"
mkdir -p /etc/hysteria
mkdir -p /var/www/html
mkdir -p /etc/cloudflared
mkdir -p /root/.acme.sh

# 获取用户域名
print_message "请输入您的域名 (例如: hy2.example.com):" "$YELLOW"
read -r DOMAIN

# 简单的域名验证
if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    print_message "域名格式无效，请确保域名只包含字母、数字、点和连字符" "$RED"
    exit 1
fi

# 检查是否包含至少一个点号
if [[ ! "$DOMAIN" =~ \. ]]; then
    print_message "域名格式无效，必须包含至少一个点号" "$RED"
    exit 1
fi

# 验证域名长度
if [ ${#DOMAIN} -gt 253 ]; then
    print_message "域名长度超过限制（最大253个字符）" "$RED"
    exit 1
fi

# 验证每个部分长度
for part in ${DOMAIN//./ }; do
    if [ ${#part} -gt 63 ]; then
        print_message "域名部分长度超过限制（最大63个字符）" "$RED"
        exit 1
    fi
done

# 询问是否使用 Cloudflare
print_message "是否使用 Cloudflare？(y/n):" "$YELLOW"
read -r USE_CLOUDFLARE

if [[ "$USE_CLOUDFLARE" =~ ^[Yy]$ ]]; then
    print_message "接下来需要登录 Cloudflare" "$YELLOW"
    print_message "按回车键继续..." "$YELLOW"
    read -r
fi

# 生成并保存密码
PASSWORD=$(generate_password)
if [ ! -d "/etc/hysteria" ]; then
    mkdir -p /etc/hysteria
fi
echo "生成的密码: $PASSWORD" > /etc/hysteria/password.txt
chmod 600 /etc/hysteria/password.txt

# 更新系统
print_message "正在更新系统..." "$YELLOW"
apt update && apt upgrade -y

# 安装必要的软件包
print_message "正在安装必要的软件包..." "$YELLOW"
apt install -y curl wget git nginx certbot python3-certbot-nginx cloudflared openssl ufw

# 配置防火墙
print_message "正在配置防火墙..." "$YELLOW"
ufw allow 443/tcp
ufw allow 80/tcp
ufw --force enable

# 安装 acme.sh
print_message "正在安装 acme.sh..." "$YELLOW"
curl https://get.acme.sh | sh
source ~/.bashrc

# 安装 Hysteria 2
print_message "正在安装 Hysteria 2..." "$YELLOW"
bash <(curl -fsSL https://get.hy2.sh/)

# 创建伪装网站的 index.html
print_message "正在创建伪装网站..." "$YELLOW"
cat > /var/www/html/index.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>欢迎</title>
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
        <h1>欢迎访问</h1>
        <p>这是一个普通的网站。</p>
    </div>
</body>
</html>
EOL

# 配置 Nginx
print_message "正在配置 Nginx..." "$YELLOW"
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

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
EOL

ln -s /etc/nginx/sites-available/hysteria /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# 配置 Cloudflare 隧道（如果用户选择使用 Cloudflare）
if [[ "$USE_CLOUDFLARE" =~ ^[Yy]$ ]]; then
    print_message "正在配置 Cloudflare 隧道..." "$YELLOW"
    cloudflared tunnel login
    cloudflared tunnel create hysteria-tunnel

    # 创建 Cloudflare 隧道配置
    cat > /etc/cloudflared/config.yml << EOL
tunnel: your-tunnel-id  # 替换为您的隧道 ID
credentials-file: /root/.cloudflared/your-tunnel-id.json  # 替换为您的凭证文件路径

ingress:
  - hostname: ${DOMAIN}
    service: http://localhost:80
  - service: http_status:404
EOL

    # 创建 Cloudflare 隧道服务
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

    # 启动 Cloudflare 隧道服务
    systemctl enable cloudflared
    systemctl start cloudflared
fi

# 创建 Hysteria 服务
print_message "正在创建 Hysteria 服务..." "$YELLOW"
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

# 安装 WARP
print_message "正在安装 WARP..." "$YELLOW"
curl -fsSL https://pkg.cloudflareclient.com/cloudflare-warp-archive-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $UBUNTU_VERSION main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
apt update
apt install -y cloudflare-warp

# 配置 WARP
print_message "正在配置 WARP..." "$YELLOW"
warp-cli register
warp-cli set-mode proxy
warp-cli set-proxy-port 40000

# 启动服务
print_message "正在启动服务..." "$YELLOW"
systemctl daemon-reload
systemctl enable nginx hysteria
systemctl start nginx hysteria

if [[ "$USE_CLOUDFLARE" =~ ^[Yy]$ ]]; then
    systemctl enable cloudflared
    systemctl start cloudflared
fi

# 获取 SSL 证书
print_message "正在获取 SSL 证书..." "$YELLOW"
~/.acme.sh/acme.sh --issue -d ${DOMAIN} --nginx || {
    print_message "获取 SSL 证书失败" "$RED"
    exit 1
}

# 最终配置
print_message "正在完成最终配置..." "$YELLOW"
cp /root/.acme.sh/${DOMAIN}/fullchain.cer /etc/hysteria/cert.crt
cp /root/.acme.sh/${DOMAIN}/${DOMAIN}.key /etc/hysteria/cert.key

# 更新服务器配置
print_message "正在更新服务器配置..." "$YELLOW"
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

# 创建客户端配置
print_message "正在创建客户端配置..." "$YELLOW"
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

# 创建伪装配置
print_message "正在创建伪装配置..." "$YELLOW"
cat > /etc/hysteria/masquerade.json << 'EOL'
{
    "type": "default",
    "args": {
        "name": "nginx",
        "version": "1.24.0"
    }
}
EOL

# 生成 Hysteria 2 链接
print_message "正在生成 Hysteria 2 链接..." "$YELLOW"
HY2_LINK="hysteria://${PASSWORD}@${DOMAIN}:443?insecure=1&sni=${DOMAIN}#Hysteria2"
echo "$HY2_LINK" > /etc/hysteria/hy2_link.txt
chmod 600 /etc/hysteria/hy2_link.txt

# 创建链接备份
cp /etc/hysteria/hy2_link.txt /root/hy2_link.txt
chmod 600 /root/hy2_link.txt

# 显示完成信息
echo -e "\n${GREEN}=== Hysteria 2 安装完成 ===${NC}"
echo -e "${YELLOW}您的 Hysteria 2 链接：${NC}"
echo -e "${GREEN}$HY2_LINK${NC}"
echo -e "\n${YELLOW}重要文件位置：${NC}"
echo -e "密码：${GREEN}/etc/hysteria/password.txt${NC}"
echo -e "链接：${GREEN}/etc/hysteria/hy2_link.txt${NC}"
echo -e "\n${YELLOW}备份文件：${NC}"
echo -e "密码：${GREEN}/root/hysteria_password.txt${NC}"
echo -e "链接：${GREEN}/root/hy2_link.txt${NC}"
echo -e "\n${YELLOW}使用说明：${NC}"
echo -e "1. 请保存好您的密码和链接"
echo -e "2. 使用 Hysteria 2 客户端导入链接即可使用"
echo -e "3. 查看链接命令：${GREEN}cat /etc/hysteria/hy2_link.txt${NC}"
echo -e "4. 查看密码命令：${GREEN}cat /etc/hysteria/password.txt${NC}"
echo -e "\n${GREEN}=== 安装完成 ===${NC}\n"

# 重启服务
systemctl restart hysteria
if [ "$USE_CLOUDFLARE" = "y" ]; then
    systemctl restart cloudflared
fi

# 优化系统设置
print_message "正在优化系统设置..." "$YELLOW"
cat > /etc/sysctl.d/99-hysteria.conf << 'EOL'
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
EOL
sysctl -p /etc/sysctl.d/99-hysteria.conf 
