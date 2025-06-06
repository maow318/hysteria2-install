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

# 检查命令是否存在的函数
check_command_exists() {
    if ! command -v $1 &> /dev/null; then
        print_message "未检测到 $1 命令，正在安装..." "$YELLOW"
        apt update && apt install -y $1
        check_command "安装 $1"
    fi
}

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then 
    print_message "请使用 root 权限运行此脚本" "$RED"
    exit 1
fi

# 检查系统要求
print_message "正在检查系统要求..." "$YELLOW"

# 检查是否为 Ubuntu 系统
if ! command -v lsb_release &> /dev/null; then
    print_message "未检测到 lsb_release 命令，正在安装..." "$YELLOW"
    apt update && apt install -y lsb-release
    check_command "安装 lsb-release"
fi

# 检查 Ubuntu 版本
UBUNTU_VERSION=$(lsb_release -cs)
if [[ "$UBUNTU_VERSION" != "focal" && "$UBUNTU_VERSION" != "jammy" ]]; then
    print_message "此脚本仅支持 Ubuntu 20.04 (Focal) 或 22.04 (Jammy)" "$RED"
    exit 1
fi

# 检查必要的命令
REQUIRED_COMMANDS=("curl" "wget" "git" "nginx" "certbot" "openssl" "ufw" "net-tools")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    check_command_exists "$cmd"
done

# 检查系统内存
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -lt 512 ]; then
    print_message "警告：系统内存小于 512MB，可能会影响性能" "$YELLOW"
    read -p "是否继续？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 检查磁盘空间
FREE_SPACE=$(df -m / | awk 'NR==2 {print $4}')
if [ "$FREE_SPACE" -lt 1024 ]; then
    print_message "警告：可用磁盘空间小于 1GB，可能会影响安装" "$YELLOW"
    read -p "是否继续？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 检查网络连接
print_message "正在检查网络连接..." "$YELLOW"
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    print_message "无法连接到网络，请检查网络设置" "$RED"
    exit 1
fi

# 检查端口占用
print_message "正在检查端口占用..." "$YELLOW"
if netstat -tuln | grep -q ":443 "; then
    print_message "警告：443 端口已被占用" "$YELLOW"
    read -p "是否继续？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 创建临时目录
print_message "正在创建临时目录..." "$YELLOW"
TEMP_DIR=$(mktemp -d)
check_command "创建临时目录"

# 下载安装脚本
print_message "正在下载安装脚本..." "$YELLOW"
MAX_RETRIES=3
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -L --connect-timeout 30 --max-time 60 -o "$TEMP_DIR/ubuntu_setup.sh" https://raw.githubusercontent.com/maow318/hysteria2-install/main/ubuntu_setup.sh; then
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        print_message "下载失败，正在重试 ($RETRY_COUNT/$MAX_RETRIES)..." "$YELLOW"
        sleep 5
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    print_message "下载失败，已达到最大重试次数" "$RED"
    exit 1
fi

# 检查下载的文件
if [ ! -f "$TEMP_DIR/ubuntu_setup.sh" ]; then
    print_message "下载失败：未找到安装脚本" "$RED"
    exit 1
fi

# 检查文件大小
FILE_SIZE=$(stat -c%s "$TEMP_DIR/ubuntu_setup.sh" 2>/dev/null || stat -f%z "$TEMP_DIR/ubuntu_setup.sh")
if [ "$FILE_SIZE" -lt 1000 ]; then
    print_message "警告：下载的文件可能不完整" "$YELLOW"
    read -p "是否继续？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 检查文件权限
print_message "正在设置文件权限..." "$YELLOW"
chmod +x "$TEMP_DIR/ubuntu_setup.sh"
check_command "设置文件权限"

# 执行安装脚本
print_message "正在执行安装脚本..." "$YELLOW"
"$TEMP_DIR/ubuntu_setup.sh"
check_command "执行安装脚本"

# 清理临时文件
print_message "正在清理临时文件..." "$YELLOW"
rm -rf "$TEMP_DIR"
check_command "清理临时文件"

print_message "安装完成！" "$GREEN"
