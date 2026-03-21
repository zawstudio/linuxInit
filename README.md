# linuxInit

A high-performance, expert-grade Bash script designed to configure and harden fresh Ubuntu or Debian systems. `linuxInit` automates everything from system performance tuning and security hardening to the installation of modern development stacks.

## ✨ Advanced Features

- **🚀 System Optimization**: Automated **Swap File**, **Sysctl Tuning**, and **Hardware Analysis**.
- **🛡️ Security Hardening**: **SSH Hardening**, **User Management** (Non-root sudo), **UFW**, and **Fail2Ban**.
- **⚡ Productivity Stack**:
  - **Premium Shell**: Optional **Zsh** installation.
  - **Expert Aliases**: Shortcuts for logs (`logssh`), listeners (`ports`), and monitoring.
- **🛠️ Modular Engines**:
  - **Languages**: Python, Node.js, Rust, and Go.
  - **Infrastructure**: Docker Engine & **Compose Templates**, Nginx (SSL via Certbot).
  - **Databases**: PostgreSQL and Redis with automated **daily backups**.
- **📊 Professional Monitoring**: Includes `htop`, `btop`, `glances`, and `sysstat`.
- **🏥 Maintenance**: Automated **Auto-Heal** healthchecks and **Unattended Upgrades**.
- **🎨 Automation**: **Visual Select Menu** (whiptail) and Unattended mode (`-y`).

## 🚀 Quick Usage

Perfect for fresh VPS or local VM installations:

```bash
wget -O setup.sh https://raw.githubusercontent.com/zawstudio/linuxInit/main/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

## 📜 Repository Structure

- `setup.sh`: The core `linuxInit` logic.
- `README.md`: Documentation and features.
- `LICENSE`: MIT Open Source license.

## ⚖️ License

Distributed under the MIT License. See `LICENSE` for more information.
