#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        printf "${RED}Error: This script must be run as root.${NC}\n"
        exit 1
    fi
}

setup_swap() {
    if ! grep -q "swapfile" /etc/fstab; then
        printf "${CYAN}Creating 2GB swap file for system stability...${NC}\n"
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
}

update_system() {
    printf "${CYAN}Performing full system update and upgrade...${NC}\n"
    apt-get update && apt-get upgrade -y
    apt-get install -y curl gnupg ca-certificates lsb-release
}

install_monitoring() {
    printf "${CYAN}Installing mandatory monitoring tools...${NC}\n"
    apt-get install -y htop btop iotop sysstat glances net-tools
}

install_productivity() {
    printf "${CYAN}Installing Zsh and productivity aliases...${NC}\n"
    apt-get install -y zsh
    if [ -n "${SUDO_USER:-}" ]; then
        BASHRC="/home/$SUDO_USER/.bashrc"
        echo "alias ll='ls -lah'" >> "$BASHRC"
        echo "alias dc='docker compose'" >> "$BASHRC"
        echo "alias update='sudo apt update && sudo apt upgrade -y'" >> "$BASHRC"
        echo "alias ports='sudo lsof -i -P -n | grep LISTEN'" >> "$BASHRC"
        printf "${YELLOW}Global aliases added to $BASHRC.${NC}\n"
    fi
}

install_python() {
    printf "${CYAN}Installing Python3 development stack...${NC}\n"
    apt-get install -y python3 python3-pip python3-venv
}

install_docker() {
    printf "${CYAN}Installing Docker Engine and latest Compose...${NC}\n"
    curl -fsSL https://get.docker.com | sh
    if [ -n "${SUDO_USER:-}" ]; then
        usermod -aG docker "$SUDO_USER"
        printf "${YELLOW}User $SUDO_USER added to 'docker' group.${NC}\n"
    fi
}

install_node() {
    printf "${CYAN}Installing Node.js LTS via NodeSource...${NC}\n"
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
}

install_rust() {
    printf "${CYAN}Installing Rust via rustup.rs...${NC}\n"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
}

install_go() {
    printf "${CYAN}Installing Golang...${NC}\n"
    apt-get install -y golang-go
}

install_databases() {
    printf "${CYAN}Installing Database Suite (PostgreSQL & Redis)...${NC}\n"
    apt-get install -y postgresql postgresql-contrib redis-server
}

install_nginx() {
    printf "${CYAN}Installing Nginx Web Server...${NC}\n"
    apt-get install -y nginx
}

install_security() {
    printf "${CYAN}Installing Security Suite (UFW & Fail2Ban)...${NC}\n"
    apt-get install -y ufw fail2ban
    ufw allow ssh
    ufw --force enable
}

install_editor_tools() {
    printf "${CYAN}Installing Developer Tools (Neovim & Tmux)...${NC}\n"
    apt-get install -y neovim tmux
}

install_utils() {
    printf "${CYAN}Installing essential utilities...${NC}\n"
    apt-get install -y git curl wget unzip build-essential
}

cleanup() {
    printf "${CYAN}Cleaning up redundant packages...${NC}\n"
    apt-get autoremove -y && apt-get autoclean -y
}

SWAP_STATUS="Skipped"
ZSH_STATUS="Skipped"
PYTHON_STATUS="Skipped"
DOCKER_STATUS="Skipped"
NODE_STATUS="Skipped"
RUST_STATUS="Skipped"
GO_STATUS="Skipped"
DB_STATUS="Skipped"
NGINX_STATUS="Skipped"
SECURITY_STATUS="Skipped"
TOOLS_STATUS="Skipped"
UTILS_STATUS="Skipped"

main() {
    clear
    printf "\n"
    printf "${CYAN}   linuxInit - ULTIMATE LINUX SETUP       ${NC}\n"
    printf "\n"

    check_privileges
    update_system
    install_monitoring

    printf "\n${YELLOW}Advanced & Optional Selection:${NC}\n"
    printf "\n"
    
    printf "Create 2GB Swap File? [y/N]: "
    read -r swap_q || swap_q="n"
    if [[ "$swap_q" =~ ^[Yy]$ ]]; then
        setup_swap
        SWAP_STATUS="Created"
    fi

    printf "Install Zsh & Workspace Aliases? [y/N]: "
    read -r zsh_q || zsh_q="n"
    if [[ "$zsh_q" =~ ^[Yy]$ ]]; then
        install_productivity
        ZSH_STATUS="Installed"
    fi

    printf "Install Python stack? [y/N]: "
    read -r python_q || python_q="n"
    if [[ "$python_q" =~ ^[Yy]$ ]]; then
        install_python
        PYTHON_STATUS="Installed"
    fi

    printf "Install Docker Suite? [y/N]: "
    read -r docker_q || docker_q="n"
    if [[ "$docker_q" =~ ^[Yy]$ ]]; then
        install_docker
        DOCKER_STATUS="Installed"
    fi

    printf "Install Node.js (LTS)? [y/N]: "
    read -r node_q || node_q="n"
    if [[ "$node_q" =~ ^[Yy]$ ]]; then
        install_node
        NODE_STATUS="Installed"
    fi

    printf "Install Rust (rustup)? [y/N]: "
    read -r rust_q || rust_q="n"
    if [[ "$rust_q" =~ ^[Yy]$ ]]; then
        install_rust
        RUST_STATUS="Installed"
    fi

    printf "Install Golang? [y/N]: "
    read -r go_q || go_q="n"
    if [[ "$go_q" =~ ^[Yy]$ ]]; then
        install_go
        GO_STATUS="Installed"
    fi

    printf "Install Databases (Postgres/Redis)? [y/N]: "
    read -r db_q || db_q="n"
    if [[ "$db_q" =~ ^[Yy]$ ]]; then
        install_databases
        DB_STATUS="Installed"
    fi

    printf "Install Nginx Server? [y/N]: "
    read -r nginx_q || nginx_q="n"
    if [[ "$nginx_q" =~ ^[Yy]$ ]]; then
        install_nginx
        NGINX_STATUS="Installed"
    fi

    printf "Install Security (UFW/Fail2Ban)? [y/N]: "
    read -r security_q || security_q="n"
    if [[ "$security_q" =~ ^[Yy]$ ]]; then
        install_security
        SECURITY_STATUS="Installed"
    fi

    printf "Install Neovim & Tmux? [y/N]: "
    read -r tools_q || tools_q="n"
    if [[ "$tools_q" =~ ^[Yy]$ ]]; then
        install_editor_tools
        TOOLS_STATUS="Installed"
    fi

    printf "Install Git/Curl/Wget/Unzip? [y/N]: "
    read -r utils_q || utils_q="n"
    if [[ "$utils_q" =~ ^[Yy]$ ]]; then
        install_utils
        UTILS_STATUS="Installed"
    fi

    cleanup

    clear
    printf "\n"
    printf "${GREEN}        linuxInit COMPLETE                ${NC}\n"
    printf "\n"
    printf "%-22s %s\n" "Update Status:" "Success"
    printf "%-22s %s\n" "Swap File:" "$SWAP_STATUS"
    printf "%-22s %s\n" "Zsh & Aliases:" "$ZSH_STATUS"
    printf "%-22s %s\n" "Python stack:" "$PYTHON_STATUS"
    printf "%-22s %s\n" "Docker Engine:" "$DOCKER_STATUS"
    printf "%-22s %s\n" "Node.js (LTS):" "$NODE_STATUS"
    printf "%-22s %s\n" "Rust (rustup):" "$RUST_STATUS"
    printf "%-22s %s\n" "Golang:" "$GO_STATUS"
    printf "%-22s %s\n" "Databases:" "$DB_STATUS"
    printf "%-22s %s\n" "Nginx Server:" "$NGINX_STATUS"
    printf "%-22s %s\n" "Security Suite:" "$SECURITY_STATUS"
    printf "%-22s %s\n" "Workspace Tools:" "$TOOLS_STATUS"
    printf "%-22s %s\n" "Utility Tools:" "$UTILS_STATUS"
    printf "\n"
    printf "${YELLOW}Action: Restart session to apply Zsh/Docker changes.${NC}\n"
    printf "${GREEN}linuxInit execution finished successfully!${NC}\n"
    printf "\n"
}

main "$@"
