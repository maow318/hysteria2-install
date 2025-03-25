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

# 检查命令是否成功执行的函数
check_command() {
    if [ $? -ne 0 ]; then
        print_message "命令执行失败: $1" "$RED"
        exit 1
    fi
}

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then 
    print_message "请使用 root 权限运行此脚本" "$RED"
    exit 1
fi

print_message "开始卸载 Hysteria 2..." "$YELLOW"

# 检查必要的命令
REQUIRED_COMMANDS=("systemctl" "rm" "apt")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v $cmd &> /dev/null; then
        print_message "错误：未检测到 $cmd 命令" "$RED"
        exit 1
    fi
done

# 停止并禁用服务
print_message "正在停止服务..." "$YELLOW"
for service in hysteria nginx cloudflared; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        systemctl stop $service
        check_command "停止 $service 服务"
    fi
    if systemctl is-enabled --quiet $service 2>/dev/null; then
        systemctl disable $service
        check_command "禁用 $service 服务"
    fi
done

# 删除服务文件
print_message "正在删除服务文件..." "$YELLOW"
for service_file in /etc/systemd/system/hysteria.service /etc/systemd/system/cloudflared.service; do
    if [ -f "$service_file" ]; then
        rm -f "$service_file"
        check_command "删除 $service_file"
    fi
done

# 删除配置文件
print_message "正在删除配置文件..." "$YELLOW"
for config_dir in /etc/hysteria /etc/nginx/sites-available/hysteria; do
    if [ -d "$config_dir" ]; then
        rm -rf "$config_dir"
        check_command "删除 $config_dir"
    fi
done

# 删除 Nginx 配置链接
if [ -f "/etc/nginx/sites-enabled/hysteria" ]; then
    rm -f /etc/nginx/sites-enabled/hysteria
    check_command "删除 Nginx 配置链接"
fi

# 删除伪装网站
if [ -d "/var/www/html" ]; then
    print_message "正在删除伪装网站..." "$YELLOW"
    rm -rf /var/www/html
    check_command "删除伪装网站"
fi

# 删除 acme.sh
if [ -d "/root/.acme.sh" ]; then
    print_message "正在删除 acme.sh..." "$YELLOW"
    rm -rf /root/.acme.sh
    check_command "删除 acme.sh"
fi

# 删除 WARP
print_message "正在删除 WARP..." "$YELLOW"
if dpkg -l | grep -q cloudflare-warp; then
    apt remove -y cloudflare-warp
    check_command "删除 WARP"
fi

# 删除 WARP 相关文件
for warp_file in /etc/apt/sources.list.d/cloudflare-client.list /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg; do
    if [ -f "$warp_file" ]; then
        rm -f "$warp_file"
        check_command "删除 $warp_file"
    fi
done

# 删除 Hysteria 2 二进制文件
if [ -f "/usr/local/bin/hysteria" ]; then
    print_message "正在删除 Hysteria 2 二进制文件..." "$YELLOW"
    rm -f /usr/local/bin/hysteria
    check_command "删除 Hysteria 2 二进制文件"
fi

# 删除备份文件
print_message "正在删除备份文件..." "$YELLOW"
for backup_file in /root/hy2_link.txt /root/hysteria_password.txt; do
    if [ -f "$backup_file" ]; then
        rm -f "$backup_file"
        check_command "删除 $backup_file"
    fi
done

# 重新加载 systemd
print_message "正在重新加载 systemd..." "$YELLOW"
systemctl daemon-reload
check_command "重新加载 systemd"

# 重置防火墙规则
print_message "正在重置防火墙规则..." "$YELLOW"
if command -v ufw &> /dev/null; then
    ufw reset
    check_command "重置防火墙规则"
    ufw allow 22/tcp
    check_command "允许 SSH 访问"
    ufw enable
    check_command "启用防火墙"
fi

print_message "卸载完成！" "$GREEN"
print_message "所有 Hysteria 2 相关文件和服务已被删除" "$GREEN"
print_message "防火墙已重置，仅保留 SSH 访问" "$GREEN" 
