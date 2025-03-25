#!/bin/bash

# Set language to UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print messages
print_message() {
    echo -e "${2}${1}${NC}"
}

# Check if running on Linux
if [ "$(uname)" != "Linux" ]; then
    print_message "This script only supports Linux systems" "$RED"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_message "Please run as root" "$RED"
    print_message "Use: sudo bash install.sh" "$GREEN"
    exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    print_message "curl is required but not installed. Installing..." "$YELLOW"
    apt update && apt install -y curl || {
        print_message "Failed to install curl" "$RED"
        exit 1
    }
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d) || {
    print_message "Failed to create temporary directory" "$RED"
    exit 1
}
cd "$TEMP_DIR" || {
    print_message "Failed to enter temporary directory" "$RED"
    rm -rf "$TEMP_DIR"
    exit 1
}

# Download main installation script
print_message "Downloading installation script..." "$YELLOW"
if ! curl -fsSL --retry 3 https://raw.githubusercontent.com/maow318/hysteria2-install/580759d76a8ed3f6c49140fb8cb817cc15ff4ca9/ubuntu_setup.sh -o ubuntu_setup.sh; then
    print_message "Failed to download script" "$RED"
    cd - || true
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Check if file exists and is not empty
if [ ! -f "ubuntu_setup.sh" ] || [ ! -s "ubuntu_setup.sh" ]; then
    print_message "Download failed or file is empty" "$RED"
    cd - || true
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Check file permissions
chmod +x ubuntu_setup.sh || {
    print_message "Failed to set execute permissions" "$RED"
    cd - || true
    rm -rf "$TEMP_DIR"
    exit 1
}

# Run main installation script
print_message "Starting Hysteria 2 installation..." "$GREEN"
if ! bash ./ubuntu_setup.sh; then
    print_message "Installation failed" "$RED"
    cd - || true
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Clean up
cd - || true
rm -rf "$TEMP_DIR"

print_message "Installation completed successfully!" "$GREEN" 
