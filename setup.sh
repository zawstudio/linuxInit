#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

FORCE_YES=false
SKIP_UPDATE=false

log_info()    { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[OK]${NC}   %s\n" "$1"; }
log_warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error()   { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -y, --yes      Assume 'yes' to all prompts (unattended mode)"
    echo "  --skip-update  Skip system update and upgrade"
    echo "  -h, --help     Show this help message"
    echo ""
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)         FORCE_YES=true; shift ;;
        --skip-update)    SKIP_UPDATE=true; shift ;;
        -h|--help)        show_help; exit 0 ;;
        *)                POSITIONAL+=("$1"); shift ;;
    esac
done

check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root."
        exit 1
    fi
}

ask_question() {
    local prompt="$1"
    local default="${2:-n}"
    if [[ "$FORCE_YES" == true ]]; then
        return 0
    fi
    printf "${YELLOW}[?]${NC} %s [%s]: " "$prompt" "$default"
    read -r response || response="$default"
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

setup_swap() {
    if ! grep -q "swapfile" /etc/fstab; then
        log_info "Creating 2GB swap file for system stability..."
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        log_success "Swap file created and enabled."
    else
        log_info "Swap file already exists. Skipping."
    fi
}

update_system() {
    if [[ "$SKIP_UPDATE" == true ]]; then
        log_warn "Skipping system update as requested."
        return
    fi
    log_info "Performing full system update and upgrade..."
    apt-get update && apt-get upgrade -y
    apt-get install -y curl gnupg ca-certificates lsb-release
    log_success "System updated."
}

install_monitoring() {
    log_info "Installing mandatory monitoring tools (htop, btop, etc.)..."
    apt-get install -y htop btop iotop sysstat glances net-tools
    log_success "Monitoring tools installed."
}

install_productivity() {
    log_info "Installing Zsh and productivity aliases..."
    apt-get install -y zsh
    if [ -n "${SUDO_USER:-}" ]; then
        BASHRC="/home/$SUDO_USER/.bashrc"
        grep -q "alias ll=" "$BASHRC" || echo "alias ll='ls -lah'" >> "$BASHRC"
        grep -q "alias dc=" "$BASHRC" || echo "alias dc='docker compose'" >> "$BASHRC"
        grep -q "alias update=" "$BASHRC" || echo "alias update='sudo apt update && sudo apt upgrade -y'" >> "$BASHRC"
        grep -q "alias ports=" "$BASHRC" || echo "alias ports='sudo lsof -i -P -n | grep LISTEN'" >> "$BASHRC"
        log_success "Global aliases added to $BASHRC."
    fi
}

install_python() {
    log_info "Installing Python3 development stack..."
    apt-get install -y python3 python3-pip python3-venv
    log_success "Python3 stack installed."
}

install_docker() {
    log_info "Installing Docker Engine and latest Compose..."
    curl -fsSL https://get.docker.com | sh
    if [ -n "${SUDO_USER:-}" ]; then
        usermod -aG docker "$SUDO_USER"
        log_success "User $SUDO_USER added to 'docker' group."
    fi
    log_success "Docker Suite installed."
}

install_node() {
    log_info "Installing Node.js LTS via NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
    log_success "Node.js installed."
}

install_rust() {
    log_info "Installing Rust via rustup.rs..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    log_success "Rust installed."
}

install_go() {
    log_info "Installing Golang..."
    apt-get install -y golang-go
    log_success "Golang installed."
}

install_databases() {
    log_info "Installing Database Suite (PostgreSQL & Redis)..."
    apt-get install -y postgresql postgresql-contrib redis-server
    log_success "Databases installed."
}

install_nginx() {
    log_info "Installing Nginx Web Server..."
    apt-get install -y nginx
    log_success "Nginx installed."
}

install_security() {
    log_info "Installing Security Suite (UFW & Fail2Ban)..."
    apt-get install -y ufw fail2ban
    ufw allow ssh
    ufw --force enable
    log_success "Security Suite configured."
}

install_editor_tools() {
    log_info "Installing Developer Tools (Neovim & Tmux)..."
    apt-get install -y neovim tmux
    log_success "Editor tools installed."
}

install_utils() {
    log_info "Installing essential utilities..."
    apt-get install -y git curl wget unzip build-essential
    log_success "Utilities installed."
}

configure_sysctl() {
    log_info "Applying sysctl optimizations..."
    cat <<EOF > /etc/sysctl.d/99-linuxinit.conf
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
fs.file-max = 2097152
EOF
    sysctl -p /etc/sysctl.d/99-linuxinit.conf
    log_success "Sysctl optimizations applied."
}

configure_ssh() {
    log_info "Hardening SSH configuration..."
    if ask_question "Do you want to change default SSH port?"; then
        printf "${YELLOW}[?]${NC} Enter new SSH port [2222]: "
        read -r ssh_port || ssh_port="2222"
        sed -i "s/#Port 22/Port $ssh_port/" /etc/ssh/sshd_config
        log_success "SSH port changed to $ssh_port."
    fi
    if ask_question "Disable SSH password authentication (require keys)?"; then
        sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
        sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
        log_success "SSH password authentication disabled."
    fi
    systemctl restart ssh
}

setup_motd() {
    log_info "Setting up professional MOTD..."
    cat <<'EOF' > /etc/motd
   linuxInit - Systems Manager
   Status: Hardened & Optimized
EOF
    log_success "MOTD updated."
}

install_certbot() {
    log_info "Installing Certbot and Nginx plugin..."
    apt-get install -y certbot python3-certbot-nginx
    log_success "Certbot installed."
}

setup_backups() {
    log_info "Setting up automated database backups..."
    cat <<'EOF' > /usr/local/bin/linuxinit-backup.sh
#!/bin/bash
BACKUP_DIR="/var/backups/linuxinit"
mkdir -p "$BACKUP_DIR"
if command -v pg_dump > /dev/null; then
    pg_dumpall > "$BACKUP_DIR/postgres_$(date +%F).sql"
fi
if command -v redis-cli > /dev/null; then
    redis-cli save
    cp /var/lib/redis/dump.rdb "$BACKUP_DIR/redis_$(date +%F).rdb"
fi
find "$BACKUP_DIR" -type f -mtime +7 -delete
EOF
    chmod +x /usr/local/bin/linuxinit-backup.sh
    (crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/linuxinit-backup.sh") | crontab -
    log_success "Backup script installed at /usr/local/bin/linuxinit-backup.sh (Cron: 3 AM daily)."
}

setup_healthcheck() {
    log_info "Setting up auto-heal healthchecks..."
    cat <<'EOF' > /usr/local/bin/linuxinit-check.sh
#!/bin/bash
services=("nginx" "docker" "ssh" "postgresql" "redis-server")
for s in "${services[@]}"; do
    if systemctl is-active --quiet "$s"; then
        continue
    fi
    systemctl restart "$s"
done
EOF
    chmod +x /usr/local/bin/linuxinit-check.sh
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/linuxinit-check.sh") | crontab -
    log_success "Healthcheck script installed (Cron: every 5 minutes)."
}

cleanup() {
    log_info "Cleaning up redundant packages..."
    apt-get autoremove -y && apt-get autoclean -y
    log_success "Cleanup complete."
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
    printf "   Expert Configuration for VPS & Homelab  \n"
    printf "\n"

    check_privileges
    update_system
    install_monitoring

    log_info "Starting selection process..."
    
    if ask_question "Create 2GB Swap File?"; then
        setup_swap
        SWAP_STATUS="Created"
    fi

    if ask_question "Install Zsh & Workspace Aliases?"; then
        install_productivity
        ZSH_STATUS="Installed"
    fi

    if ask_question "Install Python stack?"; then
        install_python
        PYTHON_STATUS="Installed"
    fi

    if ask_question "Install Docker Suite?"; then
        install_docker
        DOCKER_STATUS="Installed"
    fi

    if ask_question "Install Node.js (LTS)?"; then
        install_node
        NODE_STATUS="Installed"
    fi

    if ask_question "Install Rust (rustup)?"; then
        install_rust
        RUST_STATUS="Installed"
    fi

    if ask_question "Install Golang?"; then
        install_go
        GO_STATUS="Installed"
    fi

    if ask_question "Install Databases (Postgres/Redis)?"; then
        install_databases
        DB_STATUS="Installed"
    fi

    if ask_question "Install Nginx Server?"; then
        install_nginx
        NGINX_STATUS="Installed"
    fi

    if ask_question "Install Security (UFW/Fail2Ban)?"; then
        install_security
        SECURITY_STATUS="Installed"
    fi

    if ask_question "Install Neovim & Tmux?"; then
        install_editor_tools
        TOOLS_STATUS="Installed"
    fi

    if ask_question "Apply Security Hardening (SSH/Sysctl)?"; then
        configure_sysctl
        configure_ssh
        setup_motd
        SECURITY_STATUS="Hardened"
    fi

    if ask_question "Setup SSL (Certbot) for Nginx?"; then
        install_certbot
    fi

    if ask_question "Enable Automated Backups (Postgres/Redis)?"; then
        setup_backups
    fi

    if ask_question "Enable Auto-Healing Healthchecks?"; then
        setup_healthcheck
    fi

    if ask_question "Install Essential Utils (Git/Curl)?"; then
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
    log_info "Action: Restart session to apply Zsh/Docker changes."
    log_success "linuxInit execution finished successfully!"
    printf "\n"
}

main "$@"
