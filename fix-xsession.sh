
#!/bin/bash

# Script untuk Fix .xsession dan masalah layar blank pada RDP
# Untuk Ubuntu/Debian VPS dengan XRDP

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cek apakah script dijalankan sebagai root atau user biasa
if [[ $EUID -eq 0 ]]; then
    RUN_AS_ROOT=true
else
    RUN_AS_ROOT=false
fi

# Fungsi untuk menjalankan perintah dengan sudo jika perlu
run_cmd() {
    if [ "$RUN_AS_ROOT" = true ]; then
        bash -c "$1"
    else
        sudo bash -c "$1"
    fi
}

# Fungsi untuk meminta username
ask_username() {
    echo ""
    print_status "Masukkan username yang akan diperbaiki untuk RDP:"
    read -rp "Username: " TARGET_USER
    
    # Validasi username
    while [[ -z "$TARGET_USER" || ! "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; do
        print_error "Username tidak valid. Harus dimulai huruf kecil dan hanya mengandung huruf kecil, angka, underscore atau strip."
        read -rp "Username: " TARGET_USER
    done
    
    # Cek apakah user ada
    if ! id -u "$TARGET_USER" >/dev/null 2>&1; then
        print_error "User $TARGET_USER tidak ditemukan di sistem!"
        exit 1
    fi
    
    print_success "User $TARGET_USER ditemukan."
}

# Fungsi untuk pilih desktop environment
choose_desktop() {
    echo ""
    echo "Pilih Desktop Environment yang terinstall:"
    echo "1) XFCE (startxfce4)"
    echo "2) LXDE (startlxde)"
    echo "3) GNOME (gnome-session)"
    echo "4) KDE Plasma (startkde)"
    echo "5) MATE (mate-session)"
    echo "6) Cinnamon (cinnamon-session)"
    read -rp "Masukkan pilihan (1-6): " desktop_choice
    
    case $desktop_choice in
        1)
            DESKTOP_CMD="startxfce4"
            print_status "Desktop: XFCE (startxfce4)"
            ;;
        2)
            DESKTOP_CMD="startlxde"
            print_status "Desktop: LXDE (startlxde)"
            ;;
        3)
            DESKTOP_CMD="gnome-session"
            print_status "Desktop: GNOME (gnome-session)"
            ;;
        4)
            DESKTOP_CMD="startkde"
            print_status "Desktop: KDE Plasma (startkde)"
            ;;
        5)
            DESKTOP_CMD="mate-session"
            print_status "Desktop: MATE (mate-session)"
            ;;
        6)
            DESKTOP_CMD="cinnamon-session"
            print_status "Desktop: Cinnamon (cinnamon-session)"
            ;;
        *)
            print_warning "Pilihan tidak valid, menggunakan XFCE sebagai default"
            DESKTOP_CMD="startxfce4"
            ;;
    esac
}

# Fungsi untuk backup file lama
backup_old_files() {
    print_status "Backup file konfigurasi lama..."
    
    # Backup .xsession jika ada
    if [ -f "/home/$TARGET_USER/.xsession" ]; then
        cp "/home/$TARGET_USER/.xsession" "/home/$TARGET_USER/.xsession.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "File .xsession lama di-backup"
    fi
    
    # Backup startwm.sh jika ada
    if [ -f "/etc/xrdp/startwm.sh" ]; then
        cp "/etc/xrdp/startwm.sh" "/etc/xrdp/startwm.sh.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "File startwm.sh lama di-backup"
    fi
}

# Fungsi untuk membuat .xsession yang benar
create_xsession() {
    print_status "Membuat file .xsession untuk user $TARGET_USER..."
    
    # Buat file .xsession
    cat > "/home/$TARGET_USER/.xsession" << EOF
#!/bin/sh
# Fix untuk RDP blank screen
export XDG_SESSION_DESKTOP=xfce
export XDG_DATA_DIRS=/usr/share/xfce4:/usr/share/xfce4:/usr/local/share/:/usr/share/:/var/lib/snapd/desktop
export XDG_CONFIG_DIRS=/etc/xdg/xfce4:/etc/xdg:/etc/xdg

if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi

# Start desktop environment
$DESKTOP_CMD
EOF
    
    # Set permission dan ownership
    chmod +x "/home/$TARGET_USER/.xsession"
    chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.xsession"
    
    print_success "File .xsession berhasil dibuat"
}

# Fungsi untuk memperbaiki startwm.sh XRDP
fix_startwm() {
    print_status "Memperbaiki file startwm.sh XRDP..."
    
    cat > "/etc/xrdp/startwm.sh" << EOF
#!/bin/sh
# xrdp X session start script (c) 2015, 2017, 2021 mirabilos
# published under The MirOS Licence

# Rely on /etc/pam.d/xrdp-sesman using pam_env to load both
# /etc/environment and /etc/default/locale to initialise the
# locale and the user environment properly.

if test -r /etc/profile; then
        . /etc/profile
fi

if test -r /etc/default/locale; then
  . /etc/default/locale
  export LANG LANGUAGE
fi

test -x /etc/X11/Xsession && exec /etc/X11/Xsession
exec /bin/sh /etc/X11/Xsession
EOF
    
    chmod +x "/etc/xrdp/startwm.sh"
    
    print_success "File startwm.sh berhasil diperbaiki"
}

# Fungsi untuk install paket pendukung jika belum ada
install_missing_packages() {
    print_status "Mengecek dan menginstall paket pendukung..."
    
    # Update package list
    run_cmd "apt update"
    
    # Install basic X11 packages
    run_cmd "apt install -y dbus-x11 x11-xserver-utils"
    
    # Install desktop environment jika belum ada
    case $desktop_choice in
        1)
            run_cmd "apt install -y xfce4 xfce4-goodies"
            ;;
        2)
            run_cmd "apt install -y lxde-core lxde"
            ;;
        3)
            run_cmd "apt install -y gnome-session gnome-shell"
            ;;
        4)
            run_cmd "apt install -y kde-plasma-desktop"
            ;;
        5)
            run_cmd "apt install -y mate-session mate-desktop"
            ;;
        6)
            run_cmd "apt install -y cinnamon-session cinnamon"
            ;;
    esac
    
    print_success "Paket pendukung berhasil diinstall/diupdate"
}

# Fungsi untuk restart services
restart_services() {
    print_status "Restart layanan XRDP..."
    
    run_cmd "systemctl restart xrdp"
    run_cmd "systemctl restart xrdp-sesman"
    
    print_success "Layanan XRDP berhasil di-restart"
}

# Fungsi untuk mengecek status XRDP
check_xrdp_status() {
    print_status "Mengecek status XRDP..."
    
    if systemctl is-active --quiet xrdp; then
        print_success "XRDP service berjalan"
    else
        print_warning "XRDP service tidak berjalan, mencoba menjalankan..."
        run_cmd "systemctl start xrdp"
        run_cmd "systemctl enable xrdp"
    fi
    
    if systemctl is-active --quiet xrdp-sesman; then
        print_success "XRDP-sesman service berjalan"
    else
        print_warning "XRDP-sesman service tidak berjalan, mencoba menjalankan..."
        run_cmd "systemctl start xrdp-sesman"
        run_cmd "systemctl enable xrdp-sesman"
    fi
}

# Fungsi untuk fix permission
fix_permissions() {
    print_status "Memperbaiki permission file dan folder..."
    
    # Fix home directory permissions
    chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER"
    
    # Create .cache directory if not exists
    if [ ! -d "/home/$TARGET_USER/.cache" ]; then
        mkdir -p "/home/$TARGET_USER/.cache"
        chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.cache"
    fi
    
    # Create .config directory if not exists
    if [ ! -d "/home/$TARGET_USER/.config" ]; then
        mkdir -p "/home/$TARGET_USER/.config"
        chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.config"
    fi
    
    print_success "Permission berhasil diperbaiki"
}

# Fungsi untuk membuat script test koneksi RDP
create_test_script() {
    print_status "Membuat script test untuk user $TARGET_USER..."
    
    cat > "/home/$TARGET_USER/test-rdp.sh" << EOF
#!/bin/bash
echo "=== RDP Connection Test ==="
echo "Server IP: \$(curl -s ifconfig.me)"
echo "RDP Port: 3389"
echo "Username: $TARGET_USER"
echo ""
echo "Desktop Environment: $DESKTOP_CMD"
echo "Session file: ~/.xsession exists: \$([ -f ~/.xsession ] && echo 'YES' || echo 'NO')"
echo ""
echo "XRDP Status:"
systemctl status xrdp --no-pager -l
echo ""
echo "XRDP-Sesman Status:"
systemctl status xrdp-sesman --no-pager -l
EOF
    
    chmod +x "/home/$TARGET_USER/test-rdp.sh"
    chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/test-rdp.sh"
    
    print_success "Script test RDP dibuat di /home/$TARGET_USER/test-rdp.sh"
}

# Main function
main() {
    echo ""
    echo "=============================================="
    echo "      SCRIPT FIX .XSESSION DAN RDP BLANK     "
    echo "=============================================="
    echo ""
    
    ask_username
    choose_desktop
    backup_old_files
    install_missing_packages
    create_xsession
    fix_startwm
    fix_permissions
    check_xrdp_status
    restart_services
    create_test_script
    
    echo ""
    echo "=============================================="
    print_success "PROSES FIX SELESAI!"
    echo "=============================================="
    echo ""
    print_status "Informasi koneksi RDP:"
    echo "IP Server: $(curl -s ifconfig.me 2>/dev/null || echo 'Tidak dapat mendeteksi IP')"
    echo "Port: 3389"
    echo "Username: $TARGET_USER"
    echo "Desktop: $DESKTOP_CMD"
    echo ""
    print_warning "CATATAN PENTING:"
    echo "1. Coba koneksi RDP sekarang untuk test"
    echo "2. Jika masih blank, coba restart VPS"
    echo "3. Pastikan port 3389 terbuka di firewall"
    echo "4. Gunakan script test: /home/$TARGET_USER/test-rdp.sh"
    echo ""
    
    read -rp "Apakah Anda ingin restart VPS sekarang? (y/n): " restart_choice
    if [[ $restart_choice == "y" || $restart_choice == "Y" ]]; then
        print_status "Restarting VPS..."
        run_cmd "reboot"
    else
        print_warning "Silakan restart VPS secara manual untuk hasil terbaik!"
    fi
}

# Jalankan script
main
