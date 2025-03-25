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

# 检查系统要求
print_message "正在检查系统要求..." "$YELLOW"

# 检查是否为 Ubuntu 系统
if ! command -v lsb_release &> /dev/null; then
    print_message "未检测到 lsb_release 命令，请确保您使用的是 Ubuntu 系统" "$RED"
    exit 1
fi

# 检查 Ubuntu 版本
UBUNTU_VERSION=$(lsb_release -cs)
if [[ "$UBUNTU_VERSION" != "focal" && "$UBUNTU_VERSION" != "jammy" ]]; then
    print_message "此脚本仅支持 Ubuntu 20.04 (Focal) 或 22.04 (Jammy)" "$RED"
    exit 1
fi

# 检查必要的命令
REQUIRED_COMMANDS=("curl" "wget" "git" "nginx" "certbot" "openssl" "ufw")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v $cmd &> /dev/null; then
        print_message "未检测到 $cmd 命令，正在安装..." "$YELLOW"
        apt update && apt install -y $cmd
        check_command "安装 $cmd"
    fi
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
curl -L -o "$TEMP_DIR/ubuntu_setup.sh" https://raw.githubusercontent.com/maow318/hysteria2-install/main/ubuntu_setup.sh
check_command "下载安装脚本"

# 检查下载的文件
if [ ! -f "$TEMP_DIR/ubuntu_setup.sh" ]; then
    print_message "下载失败：未找到安装脚本" "$RED"
    exit 1
fi

# 检查文件大小
FILE_SIZE=$(stat -f%z "$TEMP_DIR/ubuntu_setup.sh")
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
