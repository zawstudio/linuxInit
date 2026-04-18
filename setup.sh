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

check_hardware() {
    log_info "Analyzing system resources..."
    CPU_CORES=$(nproc)
    TOTAL_RAM=$(free -m | grep Mem | awk '{print $2}')
    DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    log_info "CPU: $CPU_CORES cores | RAM: ${TOTAL_RAM}MB | Disk usage: ${DISK_USAGE}%"
    if [ "$DISK_USAGE" -gt 80 ]; then
        log_warn "Disk usage is high ($DISK_USAGE%). Cleanup recommended."
    fi
}

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

check_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        log_error "Unsupported distribution."
        exit 1
    fi
    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        log_warn "This script is optimized for Ubuntu/Debian. Continuing with $OS anyway..."
    fi
}

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

setup_basics() {
    log_info "Configuring system basics (Timezone, NTP, Autoupdates)..."
    if ask_question "Update Timezone?"; then
        dpkg-reconfigure tzdata
    fi
    apt-get install -y chrony unattended-upgrades
    systemctl enable --now chrony
    log_info "Enabling automatic security updates..."
    echo 'Unattended-Upgrade::Allowed-Origins { "${distro_id}:${distro_codename}-security"; };' > /etc/apt/apt.conf.d/50unattended-upgrades
    log_success "System basics configured."
}

create_ssh_user() {
    log_info "Setting up a non-root sudo user..."
    printf "${YELLOW}[?]${NC} Enter username for the new user: "
    read -r username
    if id "$username" &>/dev/null; then
        log_warn "User $username already exists. Skipping creation."
    else
        useradd -m -s /bin/bash "$username"
        usermod -aG sudo "$username"
        log_success "User $username created and added to sudoers."
        if [ -d /root/.ssh ]; then
            mkdir -p "/home/$username/.ssh"
            cp /root/.ssh/authorized_keys "/home/$username/.ssh/" || true
            chown -R "$username:$username" "/home/$username/.ssh"
            chmod 700 "/home/$username/.ssh"
            chmod 600 "/home/$username/.ssh/authorized_keys" || true
            log_success "SSH keys mirrored from root to $username."
        fi
    fi
}

install_htop() {
    log_info "Installing htop..."
    apt-get install -y htop
    log_success "htop installed."
}

install_atop() {
    log_info "Installing atop..."
    apt-get install -y atop
    log_success "atop installed."
}

install_btop() {
    log_info "Installing btop..."
    apt-get install -y btop
    log_success "btop installed."
}

run_speedtest() {
    log_info "Running internet speed test..."
    if ! command -v speedtest-cli &>/dev/null; then
        log_warn "speedtest-cli not found. Installing..."
        apt-get install -y speedtest-cli
    fi
    speedtest-cli --simple
}

optimize_logs() {
    log_info "Optimizing system logs..."
    journalctl --vacuum-time=2d
    find /var/log -type f -name "*.log" -exec truncate -s 0 {} +
    log_success "Logs truncated and journal vacuumed (2 days kept)."
}

maintenance_menu() {
    while true; do
        M_CHOICE=$(whiptail --title "linuxInit - Maintenance & Cleanup" --menu \
        "Select maintenance task:" 18 60 8 \
        "SPEED" "Run Speedtest (Check bandwidth)" \
        "CLEAN" "Full Apt & Log Cleanup" \
        "DISK" "Deep Disk Usage Analysis" \
        "BACK" "<- Back to Main Menu" 3>&1 1>&2 2>&3) || break

        case "$M_CHOICE" in
            "SPEED") run_speedtest; read -p "Press Enter to continue..." ;;
            "CLEAN") cleanup; optimize_logs; read -p "Press Enter to continue..." ;;
            "DISK") du -sh /var/log /home /root 2>/dev/null; read -p "Press Enter to continue..." ;;
            "BACK") return ;;
            *) return ;;
        esac
    done
}

install_productivity() {
    log_info "Installing Zsh and productivity aliases..."
    apt-get install -y zsh
    if [ -n "${SUDO_USER:-}" ]; then
        BASHRC="/home/$SUDO_USER/.bashrc"
        grep -q "alias ll=" "$BASHRC" || echo "alias ll='ls -lah'" >> "$BASHRC"
        grep -q "alias update=" "$BASHRC" || echo "alias update='sudo apt update && sudo apt upgrade -y'" >> "$BASHRC"
        grep -q "alias ports=" "$BASHRC" || echo "alias ports='sudo lsof -i -P -n | grep LISTEN'" >> "$BASHRC"
        grep -q "alias logssh=" "$BASHRC" || echo "alias logssh='sudo tail -f /var/log/auth.log'" >> "$BASHRC"
        log_success "Global aliases added to $BASHRC."
    fi
}



configure_logrotate() {
    log_info "Configuring permanent log rotation (max 100MB per file)..."
    cat <<EOF > /etc/logrotate.d/linuxinit
/var/log/*.log {
    size 100M
    rotate 5
    compress
    delaycompress
    missingok
    notifempty
}
EOF
    log_success "Logrotate policy applied."
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

configure_sysctl() {
    log_info "Applying system optimizations..."
    cat <<EOF > /etc/sysctl.d/99-linuxinit.conf
# Network hardening
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
fs.file-max = 2097152

# Security optimizations
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.conf.all.log_martians = 1
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.perf_event_paranoid = 3
EOF
    sysctl -p /etc/sysctl.d/99-linuxinit.conf
    log_success "System security rules applied."
}

configure_ssh() {
    log_info "Hardening SSH configuration..."
    if ask_question "Do you want to change default SSH port?"; then
        printf "${YELLOW}[?]${NC} Enter new SSH port [2222]: "
        read -r ssh_port || ssh_port="2222"
        sed -i "s/#Port 22/Port $ssh_port/" /etc/ssh/sshd_config
        sed -i "s/Port 22/Port $ssh_port/" /etc/ssh/sshd_config
        log_success "SSH port changed to $ssh_port."
    fi
    if ask_question "Apply Advanced SSH security (Hardened Ciphers, Disable Root)?"; then
        # Modern KEX, Ciphers, and MACs
        cat <<EOF >> /etc/ssh/sshd_config
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
EOF
        sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
        sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
        sed -i "s/#MaxAuthTries 6/MaxAuthTries 3/" /etc/ssh/sshd_config
        sed -i "s/#ClientAliveInterval 0/ClientAliveInterval 300/" /etc/ssh/sshd_config
        sed -i "s/#ClientAliveCountMax 3/ClientAliveCountMax 2/" /etc/ssh/sshd_config
        sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
        sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
        log_success "Advanced SSH security applied. RSA keys are now discouraged, use Ed25519."
    fi
    systemctl restart ssh
}

setup_motd() {
    log_info "Setting up professional MOTD..."
    cat <<'EOF' > /etc/motd
   linuxInit - Systems Manager
    Status: Secured & Optimized
EOF
    log_success "MOTD updated."
}





setup_healthcheck() {
    log_info "Setting up auto-heal healthchecks..."
    cat <<'EOF' > /usr/local/bin/linuxinit-check.sh
#!/bin/bash
services=("ssh" "fail2ban" "crowdsec")
for s in "${services[@]}"; do
    if systemctl list-unit-files "$s.service" &>/dev/null && ! systemctl is-active --quiet "$s"; then
        systemctl restart "$s"
    fi
done
EOF
    chmod +x /usr/local/bin/linuxinit-check.sh
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/linuxinit-check.sh") | crontab -
    log_success "Healthcheck script installed (Cron: every 5 minutes)."
}

install_lynis() {
    log_info "Installing Lynis Security Auditor..."
    apt-get install -y lynis
    log_success "Lynis installed."
}

install_crowdsec() {
    log_info "Installing CrowdSec (Modern IPS)..."
    curl -s https://install.crowdsec.net | sh
    apt-get update
    apt-get install -y crowdsec crowdsec-firewall-bouncer-ufw
    log_success "CrowdSec IPS installed and connected to UFW bouncer."
}

setup_mfa() {
    log_info "Setting up 2FA for SSH (Google Authenticator)..."
    apt-get install -y libpam-google-authenticator
    log_warn "CRITICAL: You MUST run 'google-authenticator' as your user after this script!"
    if ! grep -q "pam_google_authenticator.so" /etc/pam.d/sshd; then
        sed -i '1iauth required pam_google_authenticator.so' /etc/pam.d/sshd
    fi
    sed -i "s/KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/" /etc/ssh/sshd_config
    sed -i "s/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/" /etc/ssh/sshd_config
    echo "AuthenticationMethods publickey,keyboard-interactive" >> /etc/ssh/sshd_config
    systemctl restart ssh
    log_success "MFA infrastructure ready. PAM & SSHD configured."
}

install_nginx_hardened() {
    log_info "Installing Hardened Nginx Web Server..."
    apt-get install -y nginx
    log_info "Applying paranoiac security settings for Nginx (TLS 1.3 only, Secure Headers)..."
    cat <<EOF > /etc/nginx/conf.d/hardened.conf
server_tokens off;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
ssl_protocols TLSv1.3;
ssl_prefer_server_ciphers off;
EOF
    log_success "Hardened Nginx installed and configured."
}

install_php() {
    local SELECTED_VER="8.4"
    if [[ "$FORCE_YES" == false ]]; then
        SELECTED_VER=$(whiptail --title "PHP Selection" --menu \
        "Choose PHP version to install (Latest recommended):" 15 60 5 \
        "8.4" "PHP 8.4 (Newest)" \
        "8.3" "PHP 8.3" \
        "8.2" "PHP 8.2" \
        "8.1" "PHP 8.1" \
        "7.4" "PHP 7.4 (Legacy)" 3>&1 1>&2 2>&3) || SELECTED_VER="8.4"
    fi

    log_info "Installing PHP $SELECTED_VER and common extensions..."
    apt-get install -y software-properties-common
    if [[ "$OS" == "ubuntu" ]]; then
        add-apt-repository ppa:ondrej/php -y
    else
        curl -sSL https://packages.sury.org/php/README.txt | bash -x
    fi
    apt-get update
    apt-get install -y php${SELECTED_VER} php${SELECTED_VER}-cli php${SELECTED_VER}-fpm php${SELECTED_VER}-common php${SELECTED_VER}-mysql php${SELECTED_VER}-zip php${SELECTED_VER}-gd php${SELECTED_VER}-mbstring php${SELECTED_VER}-curl php${SELECTED_VER}-xml php${SELECTED_VER}-bcmath php${SELECTED_VER}-redis php${SELECTED_VER}-intl php${SELECTED_VER}-sqlite3
    log_success "PHP $SELECTED_VER installed."
    PHP_STATUS="Installed ($SELECTED_VER)"
}

install_mariadb() {
    log_info "Installing MariaDB Server..."
    apt-get install -y mariadb-server
    systemctl enable --now mariadb
    log_success "MariaDB installed and service enabled."
}

install_redis() {
    log_info "Installing Redis Server..."
    apt-get install -y redis-server
    systemctl enable --now redis-server
    log_success "Redis installed and service enabled."
}

install_composer() {
    log_info "Installing Composer v2..."
    if ! command -v php &>/dev/null; then
        log_warn "PHP not found. Initiating PHP installation for Composer..."
        install_php
    fi
    curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
    log_success "Composer v2 installed globally."
}

install_pnpm() {
    log_info "Installing pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | SHELL=bash sh -
    # Adding to global path for root
    export PNPM_HOME="/root/.local/share/pnpm"
    case ":$PATH:" in
        *":$PNPM_HOME:"*) ;;
        *) export PATH="$PNPM_HOME:$PATH" ;;
    esac
    log_success "pnpm installed."
}

cleanup() {
    log_info "Cleaning up redundant packages..."
    apt-get autoremove -y && apt-get autoclean -y
    log_success "Cleanup complete."
}

SWAP_STATUS="Skipped"
ZSH_STATUS="Skipped"
SECURITY_STATUS="Skipped"
CROWDSEC_STATUS="Skipped"
NGINX_STATUS="Skipped"
MFA_STATUS="Skipped"
TOOLS_STATUS="Skipped"
UTILS_STATUS="Skipped"
PHP_STATUS="Skipped"
MARIADB_STATUS="Skipped"
REDIS_STATUS="Skipped"
COMPOSER_STATUS="Skipped"
PNPM_STATUS="Skipped"

main() {
    while true; do
        clear
        printf "\n"
        printf "${CYAN}   linuxInit - ULTIMATE LINUX SETUP       ${NC}\n"
        printf "   Expert Configuration for VPS & Homelab  \n"
        printf "\n"

        check_privileges
        check_distro
        check_hardware

        if [[ "$FORCE_YES" == false ]] && command -v whiptail >/dev/null; then
            MAIN_MENU=$(whiptail --title "linuxInit - Master Menu" --menu \
            "Navigate the system configuration:" 15 60 5 \
            "INSTALL" "Start Modular Installation" \
            "MAINT" "Maintenance & Cleanup" \
            "HELP" "Show Help" \
            "EXIT" "Exit linuxInit" 3>&1 1>&2 2>&3) || exit 0

            case "$MAIN_MENU" in
                "INSTALL") start_installer ;;
                "MAINT") maintenance_menu ;;
                "HELP") show_help; read -p "Press Enter to return..." ;;
                "EXIT") exit 0 ;;
                *) exit 0 ;;
            esac
        else
            start_linear_installer
            break
        fi
    done
}

start_installer() {
    CHOICES=$(whiptail --title "linuxInit - Installation Selection" --checklist \
    "Select modules to install (Space = select, Enter = confirm)" 25 80 18 \
    "UPDATE" "Full System Update & Upgrade" OFF \
    "HTOP" "System Monitor (htop)" OFF \
    "BTOP" "System Monitor (btop)" OFF \
    "ATOP" "System Monitor (atop)" OFF \
    "BASICS" "Timezone, NTP, Autoupdates" OFF \
    "USER" "Create Non-Root Sudo User" OFF \
    "SWAP" "Create 2GB Swap File" OFF \
    "ZSH" "Install Zsh & Aliases" OFF \
    "HARDEN" "Advanced Security" OFF \
    "CROWDSEC" "Intrusion Prevention (CrowdSec)" OFF \
    "MFA" "SSH 2FA (Google Authenticator)" OFF \
    "NGINX" "Secured Nginx (TLS 1.3)" OFF \
    "AUDIT" "Security Audit (Lynis)" OFF \
    "HEALTH" "Auto-Heal Healthchecks" OFF \
    "LOGROTATE" "Permanent Log Rotation" ON \
    "TOOLS" "Neovim & Tmux" OFF \
    "GIT" "Git Version Control" ON \
    "CURL" "cURL Transfer Tool" ON \
    "WGET" "Wget Downloader" ON \
    "UNZIP" "Unzip Utility" ON \
    "SCREEN" "GNU Screen Multiplexer" ON \
    "SPEEDTEST" "Ookla Speedtest CLI" ON \
    "BUILD" "Build Essential (gcc/make)" OFF \
    "PHP" "PHP Selection Menu" OFF \
    "MARIADB" "MariaDB Server" OFF \
    "REDIS" "Redis Server" OFF \
    "COMPOSER" "Composer v2" OFF \
    "PNPM" "pnpm Package Manager" OFF 3>&1 1>&2 2>&3) || return

    [[ "$CHOICES" == *"UPDATE"* ]] && update_system
    [[ "$CHOICES" == *"HTOP"* ]] && install_htop
    [[ "$CHOICES" == *"BTOP"* ]] && install_btop
    [[ "$CHOICES" == *"ATOP"* ]] && install_atop
    [[ "$CHOICES" == *"BASICS"* ]] && setup_basics
    [[ "$CHOICES" == *"USER"* ]] && create_ssh_user
    [[ "$CHOICES" == *"SWAP"* ]] && { setup_swap; SWAP_STATUS="Created"; }
    [[ "$CHOICES" == *"ZSH"* ]] && { install_productivity; ZSH_STATUS="Installed"; }
    [[ "$CHOICES" == *"HARDEN"* ]] && { configure_sysctl; configure_ssh; setup_motd; SECURITY_STATUS="Hardened"; }
    [[ "$CHOICES" == *"CROWDSEC"* ]] && { install_crowdsec; CROWDSEC_STATUS="Installed"; }
    [[ "$CHOICES" == *"MFA"* ]] && { setup_mfa; MFA_STATUS="Installed"; }
    [[ "$CHOICES" == *"NGINX"* ]] && { install_nginx_hardened; NGINX_STATUS="Installed"; }
    [[ "$CHOICES" == *"AUDIT"* ]] && install_lynis
    [[ "$CHOICES" == *"HEALTH"* ]] && setup_healthcheck
    [[ "$CHOICES" == *"LOGROTATE"* ]] && configure_logrotate
    [[ "$CHOICES" == *"TOOLS"* ]] && { install_editor_tools; TOOLS_STATUS="Installed"; }

    # Individual Utility Logic
    SELECTED_PKGS=()
    [[ "$CHOICES" == *"GIT"* ]] && SELECTED_PKGS+=("git")
    [[ "$CHOICES" == *"CURL"* ]] && SELECTED_PKGS+=("curl")
    [[ "$CHOICES" == *"WGET"* ]] && SELECTED_PKGS+=("wget")
    [[ "$CHOICES" == *"UNZIP"* ]] && SELECTED_PKGS+=("unzip")
    [[ "$CHOICES" == *"SCREEN"* ]] && SELECTED_PKGS+=("screen")
    [[ "$CHOICES" == *"SPEEDTEST"* ]] && SELECTED_PKGS+=("speedtest-cli")
    [[ "$CHOICES" == *"BUILD"* ]] && SELECTED_PKGS+=("build-essential")

    if [ ${#SELECTED_PKGS[@]} -gt 0 ]; then
        log_info "Installing selected utilities: ${SELECTED_PKGS[*]}..."
        apt-get install -y "${SELECTED_PKGS[@]}"
        UTILS_STATUS="Installed (${#SELECTED_PKGS[@]} tools)"
    fi
    [[ "$CHOICES" == *"PHP"* ]] && install_php
    [[ "$CHOICES" == *"MARIADB"* ]] && { install_mariadb; MARIADB_STATUS="Installed"; }
    [[ "$CHOICES" == *"REDIS"* ]] && { install_redis; REDIS_STATUS="Installed"; }
    [[ "$CHOICES" == *"COMPOSER"* ]] && { install_composer; COMPOSER_STATUS="Installed"; }
    [[ "$CHOICES" == *"PNPM"* ]] && { install_pnpm; PNPM_STATUS="Installed"; }

    finalize_installation
}

start_linear_installer() {
    log_info "Starting linear selection process..."
    
    if ask_question "Perform Full System Update & Upgrade?"; then
        update_system
    fi

    if ask_question "Install htop?"; then
        install_htop
    fi

    if ask_question "Install btop?"; then
        install_btop
    fi

    if ask_question "Install atop?"; then
        install_atop
    fi

    if ask_question "Create 2GB Swap File?"; then
        setup_swap
        SWAP_STATUS="Created"
    fi

    if ask_question "Install Zsh & Workspace Aliases?"; then
        install_productivity
        ZSH_STATUS="Installed"
    fi

    if ask_question "Apply Advanced Security (SSH/Sysctl)?"; then
        configure_sysctl
        configure_ssh
        setup_motd
        SECURITY_STATUS="Hardened"
    fi

    if ask_question "Install CrowdSec (Modern IPS)?"; then
        install_crowdsec
        CROWDSEC_STATUS="Installed"
    fi

    if ask_question "Setup SSH 2FA (MFA)?"; then
        setup_mfa
        MFA_STATUS="Installed"
    fi

    if ask_question "Install Secured Nginx (TLS 1.3)?"; then
        install_nginx_hardened
        NGINX_STATUS="Installed"
    fi

    if ask_question "Install Security Auditor (Lynis)?"; then
        install_lynis
    fi

    if ask_question "Enable Auto-Healing Healthchecks?"; then
        setup_healthcheck
    fi

    if ask_question "Configure Permanent Log Rotation?"; then
        configure_logrotate
    fi

    if ask_question "Install Neovim & Tmux?"; then
        install_editor_tools
        TOOLS_STATUS="Installed"
    fi

    # Linear Installer for Utilities
    LIN_PKGS=()
    ask_question "Install Git?" && LIN_PKGS+=("git")
    ask_question "Install Curl?" && LIN_PKGS+=("curl")
    ask_question "Install Wget?" && LIN_PKGS+=("wget")
    ask_question "Install Unzip?" && LIN_PKGS+=("unzip")
    ask_question "Install Screen?" && LIN_PKGS+=("screen")
    ask_question "Install Speedtest-cli?" && LIN_PKGS+=("speedtest-cli")
    ask_question "Install Build-Essential (GCC/Make)?" && LIN_PKGS+=("build-essential")

    if [ ${#LIN_PKGS[@]} -gt 0 ]; then
        log_info "Installing selected utilities: ${LIN_PKGS[*]}..."
        apt-get install -y "${LIN_PKGS[@]}"
        UTILS_STATUS="Installed (${#LIN_PKGS[@]} tools)"
    fi

    if ask_question "Install PHP (Choose version)?"; then
        install_php
    fi

    if ask_question "Install MariaDB Server?"; then
        install_mariadb
        MARIADB_STATUS="Installed"
    fi

    if ask_question "Install Redis Server?"; then
        install_redis
        REDIS_STATUS="Installed"
    fi

    if ask_question "Install Composer v2?"; then
        install_composer
        COMPOSER_STATUS="Installed"
    fi

    if ask_question "Install pnpm Package Manager?"; then
        install_pnpm
        PNPM_STATUS="Installed"
    fi

    finalize_installation
}

finalize_installation() {
    cleanup
    clear
    printf "\n"
    printf "${GREEN}        linuxInit COMPLETE                ${NC}\n"
    printf "\n"
    printf "%-22s %s\n" "Update Status:" "Success"
    printf "%-22s %s\n" "Swap File:" "$SWAP_STATUS"
    printf "%-22s %s\n" "Zsh & Aliases:" "$ZSH_STATUS"
    printf "%-22s %s\n" "Security System:" "$SECURITY_STATUS"
    printf "%-22s %s\n" "CrowdSec IPS:" "$CROWDSEC_STATUS"
    printf "%-22s %s\n" "SSH MFA (2FA):" "$MFA_STATUS"
    printf "%-22s %s\n" "Secured Nginx:" "$NGINX_STATUS"
    printf "%-22s %s\n" "Htop/Btop/Atop:" "Installed"
    printf "%-22s %s\n" "Workspace Tools:" "$TOOLS_STATUS"
    printf "%-22s %s\n" "Utility Tools:" "$UTILS_STATUS"
    printf "%-22s %s\n" "PHP 8.4:" "$PHP_STATUS"
    printf "%-22s %s\n" "MariaDB:" "$MARIADB_STATUS"
    printf "%-22s %s\n" "Redis:" "$REDIS_STATUS"
    printf "%-22s %s\n" "Composer v2:" "$COMPOSER_STATUS"
    printf "%-22s %s\n" "pnpm:" "$PNPM_STATUS"
    printf "\n"
    log_info "Action: Restart session to apply Zsh/Docker changes."
    log_success "linuxInit execution finished successfully!"
    printf "\n"
    read -p "Press Enter to return to main menu..."
}

main "$@"
