#!/bin/bash

# Set language to UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    echo -e "Use: ${GREEN}sudo bash install.sh${NC}"
    exit 1
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

# Download main installation script
echo -e "${YELLOW}Downloading installation script...${NC}"
if ! curl -fsSL https://raw.githubusercontent.com/maow318/hysteria2-install/580759d76a8ed3f6c49140fb8cb817cc15ff4ca9/ubuntu_setup.sh -o ubuntu_setup.sh; then
    echo -e "${RED}Failed to download script${NC}"
    exit 1
fi

# Check if file exists and is not empty
if [ ! -f "ubuntu_setup.sh" ] || [ ! -s "ubuntu_setup.sh" ]; then
    echo -e "${RED}Download failed or file is empty${NC}"
    exit 1
fi

# Add execute permission
chmod +x ubuntu_setup.sh

# Run main installation script
echo -e "${GREEN}Starting Hysteria 2 installation...${NC}"
bash ./ubuntu_setup.sh

# Clean up
cd - || exit 1
rm -rf "$TEMP_DIR"

echo -e "${GREEN}Installation completed!${NC}"
