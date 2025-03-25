#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用 root 权限运行此脚本${NC}"
    echo -e "请使用: ${GREEN}sudo bash install.sh${NC}"
    exit 1
fi

# 创建临时目录
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

# 下载主安装脚本
echo -e "${YELLOW}正在下载安装脚本...${NC}"
curl -sSL https://raw.githubusercontent.com/hysteria2/hysteria2-install/main/ubuntu_setup.sh -o ubuntu_setup.sh

# 检查下载是否成功
if [ ! -f "ubuntu_setup.sh" ]; then
    echo -e "${RED}下载失败，请检查网络连接${NC}"
    exit 1
fi

# 添加执行权限
chmod +x ubuntu_setup.sh

# 运行主安装脚本
echo -e "${GREEN}开始安装 Hysteria 2...${NC}"
./ubuntu_setup.sh

# 清理临时文件
cd -
rm -rf $TEMP_DIR

echo -e "${GREEN}安装完成！${NC}" 
