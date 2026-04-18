# linuxInit

A high-performance, expert-grade Bash script designed to configure and harden fresh Ubuntu or Debian systems. `linuxInit` automates everything from system performance tuning and security hardening to the installation of modern development stacks.

## ✨ Advanced Features

- **🚀 System Optimization**: Automated **Swap File**, **Advanced Tuning**, and **Hardware Analysis**.
- **🛡️ Security System**: **Modern SSH Security**, **User Management**, **UFW**, and **CrowdSec IPS**.
- **⚡ Productivity Stack**:
  - **Premium Shell**: Optional **Zsh** installation.
  - **Expert Aliases**: Shortcuts for logs (`logssh`), listeners (`ports`), and system updates.
- **📊 Professional Monitoring**: Includes `htop`, `btop`, and `atop`.
- **🏥 Maintenance**: **SSH 2FA (MFA)**, **Security Audits (Lynis)**, **Auto-Heal**, and **Secured Nginx**.
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
