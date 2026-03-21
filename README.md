# linuxInit

A high-performance, expert-grade Bash script designed to configure and harden fresh Ubuntu or Debian systems. `linuxInit` automates everything from system performance tuning and security hardening to the installation of modern development stacks.

## ✨ Advanced Features

- **🚀 System Optimization**: Automated **Swap File** (2GB) and **Sysctl Tuning** for low-resource VPS.
- **🛡️ Security Hardening**: **SSH Hardening**, **UFW Firewall**, and **Fail2Ban** protection.
- **⚡ Productivity Stack**:
  - **Premium Shell**: Optional **Zsh** installation.
  - **Quick Aliases**: High-value workspace shortcuts (`ll`, `dc`, `ports`).
- **🛠️ Modular Engines**:
  - **Languages**: Python (Pip/Venv), Node.js (LTS), Rust (rustup), and Go.
  - **Infrastructure**: Docker Engine & Compose, Nginx (SSL via **Certbot**).
  - **Databases**: PostgreSQL and Redis with automated **daily backups**.
- **📊 Professional Monitoring**: Includes `htop`, `btop`, `glances`, and `sysstat`.
- **🏥 Maintenance**: Automated **Auto-Heal** healthchecks (every 5 mins).
- **🎨 Automation**: Unattended mode via `-y` / `--yes` flags.

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
