#!/bin/bash

# Auto Script Install/Uninstall GUI + VNC/RDP for Ubuntu/Debian VPS
# Untuk kemudahan setup dan manajemen remote desktop pada VPS

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

if [[ $EUID -eq 0 ]]; then
    RUN_AS_ROOT=true
else
    RUN_AS_ROOT=false
fi

run_cmd() {
    if [ "$RUN_AS_ROOT" = true ]; then
        bash -c "$1"
    else
        sudo bash -c "$1"
    fi
}

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    print_error "Tidak dapat mendeteksi OS"
    exit 1
fi

print_status "Terdeteksi OS: $OS $VER"

ask_remote_user() {
    echo ""
    print_status "Masukkan username untuk login VNC dan RDP:"
    read -rp "Username: " REMOTE_USER
    while [[ -z "$REMOTE_USER" || ! "$REMOTE_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; do
        print_error "Username tidak valid. Harus dimulai huruf kecil dan hanya mengandung huruf kecil, angka, underscore atau strip."
        read -rp "Username: " REMOTE_USER
    done
    if id -u "$REMOTE_USER" >/dev/null 2>&1; then
        print_warning "User $REMOTE_USER sudah ada."
        print_status "Atur password untuk user $REMOTE_USER (untuk login RDP)..."
        while true; do
            read -rs -p "Masukkan password baru (biarkan kosong jika tidak ingin merubah): " PASS_NEW
            echo
            if [[ -z "$PASS_NEW" ]]; then
                print_warning "Password tidak diubah."
                break
            fi
            read -rs -p "Konfirmasi password baru: " PASS_NEW2
            echo
            if [[ "$PASS_NEW" == "$PASS_NEW2" && -n "$PASS_NEW" ]]; then
                echo "$REMOTE_USER:$PASS_NEW" | run_cmd "chpasswd"
                print_success "Password berhasil diubah."
                break
            else
                print_error "Password tidak cocok atau kosong, silakan coba lagi."
            fi
        done
    else
        print_status "User $REMOTE_USER tidak ditemukan, membuat user baru..."
        while true; do
            read -rs -p "Masukkan password untuk user $REMOTE_USER: " REMOTE_PASS
            echo
            read -rs -p "Konfirmasi password: " REMOTE_PASS2
            echo
            if [[ "$REMOTE_PASS" == "$REMOTE_PASS2" && -n "$REMOTE_PASS" ]]; then
                break
            else
                print_error "Password tidak cocok atau kosong, silakan coba lagi."
            fi
        done
        run_cmd "useradd -m -s /bin/bash $REMOTE_USER"
        echo "$REMOTE_USER:$REMOTE_PASS" | run_cmd "chpasswd"
        print_success "User $REMOTE_USER berhasil dibuat."
    fi
}

# Fungsi untuk menanyakan user yang akan dihapus (khusus uninstall)
ask_user_to_remove() {
    echo ""
    print_status "Masukkan username yang akan dihapus:"
    read -rp "Username: " REMOTE_USER
    if [[ -z "$REMOTE_USER" ]]; then
        print_error "Username tidak boleh kosong!"
        ask_user_to_remove
        return
    fi
    if ! id -u "$REMOTE_USER" >/dev/null 2>&1; then
        print_error "User $REMOTE_USER tidak ditemukan!"
        ask_user_to_remove
        return
    fi
    print_warning "User yang akan dihapus: $REMOTE_USER"
    read -rp "Apakah Anda yakin ingin menghapus user ini? (y/n): " confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        print_status "Batal menghapus user."
        return 1
    fi
}

create_xsession() {
    SESSION_FILE="/home/$REMOTE_USER/.xsession"
    if [ ! -f "$SESSION_FILE" ]; then
        echo -e '#!/bin/sh\nstartxfce4' > "$SESSION_FILE"
        chown "$REMOTE_USER:$REMOTE_USER" "$SESSION_FILE"
        chmod +x "$SESSION_FILE"
        print_success "File $SESSION_FILE dibuat untuk sesi desktop."
    else
        print_warning "File $SESSION_FILE sudah ada."
    fi
}

install_desktop() {
    echo ""
    echo "Pilih Desktop Environment:"
    echo "1) XFCE (Ringan, Direkomendasikan untuk VPS)"
    echo "2) LXDE (Sangat Ringan)"
    echo "3) GNOME (Berat, butuh RAM besar)"
    echo "4) KDE Plasma (Berat, butuh RAM besar)"
    read -p "Masukkan pilihan (1-4): " desktop_choice

    case $desktop_choice in
        1)
            print_status "Menginstall XFCE Desktop..."
            run_cmd "apt install -y xfce4 xfce4-goodies dbus-x11 x11-xserver-utils"
            DESKTOP_SESSION="startxfce4"
            ;;
        2)
            print_status "Menginstall LXDE Desktop..."
            run_cmd "apt install -y lxde-core lxde"
            DESKTOP_SESSION="startlxde"
            ;;
        3)
            print_status "Menginstall GNOME Desktop..."
            run_cmd "apt install -y ubuntu-desktop-minimal"
            DESKTOP_SESSION="gnome-session"
            ;;
        4)
            print_status "Menginstall KDE Plasma Desktop..."
            run_cmd "apt install -y kde-plasma-desktop"
            DESKTOP_SESSION="startkde"
            ;;
        *)
            print_warning "Pilihan tidak valid, menggunakan XFCE sebagai default"
            run_cmd "apt install -y xfce4 xfce4-goodies dbus-x11 x11-xserver-utils"
            DESKTOP_SESSION="startxfce4"
            ;;
    esac
}

# Fungsi untuk uninstall desktop environment
uninstall_desktop() {
    echo ""
    print_status "Menghapus Desktop Environment..."
    
    # Deteksi desktop environment yang terinstall
    DESKTOP_PACKAGES=""
    
    if dpkg -l | grep -q "xfce4"; then
        print_status "Menghapus XFCE Desktop..."
        DESKTOP_PACKAGES="$DESKTOP_PACKAGES xfce4 xfce4-goodies dbus-x11 x11-xserver-utils"
    fi
    
    if dpkg -l | grep -q "lxde"; then
        print_status "Menghapus LXDE Desktop..."
        DESKTOP_PACKAGES="$DESKTOP_PACKAGES lxde-core lxde"
    fi
    
    if dpkg -l | grep -q "ubuntu-desktop"; then
        print_status "Menghapus GNOME Desktop..."
        DESKTOP_PACKAGES="$DESKTOP_PACKAGES ubuntu-desktop-minimal gdm3"
    fi
    
    if dpkg -l | grep -q "kde-plasma-desktop"; then
        print_status "Menghapus KDE Plasma Desktop..."
        DESKTOP_PACKAGES="$DESKTOP_PACKAGES kde-plasma-desktop"
    fi
    
    if [[ -n "$DESKTOP_PACKAGES" ]]; then
        run_cmd "apt remove --purge -y $DESKTOP_PACKAGES"
        run_cmd "apt autoremove -y"
        print_success "Desktop Environment berhasil dihapus."
    else
        print_warning "Tidak ada Desktop Environment yang terdeteksi."
    fi
}

fix_xrdp_xfce_session() {
    # Buat file .xsession agar XRDP tahu sesi desktop mana yang dijalankan
    echo -e "#!/bin/sh\n$DESKTOP_SESSION" > /home/$REMOTE_USER/.xsession
    chown $REMOTE_USER:$REMOTE_USER /home/$REMOTE_USER/.xsession
    chmod +x /home/$REMOTE_USER/.xsession

    # Perbaiki startwm.sh agar XRDP pakai sesi desktop yang dipilih
    cat > /etc/xrdp/startwm.sh << EOF
#!/bin/sh
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi
$DESKTOP_SESSION
EOF
    chmod +x /etc/xrdp/startwm.sh
}

install_vnc() {
    print_status "Menginstall TightVNC Server..."
    run_cmd "apt install -y tightvncserver"

    print_status "Konfigurasi VNC Server untuk user $REMOTE_USER..."
    print_warning "Anda akan diminta membuat password VNC untuk user $REMOTE_USER"

    sudo -u "$REMOTE_USER" vncserver :1
    sudo -u "$REMOTE_USER" vncserver -kill :1

    if [ -f "/home/$REMOTE_USER/.vnc/xstartup" ]; then
        sudo -u "$REMOTE_USER" mv /home/$REMOTE_USER/.vnc/xstartup /home/$REMOTE_USER/.vnc/xstartup.bak
    fi

    sudo -u "$REMOTE_USER" tee /home/$REMOTE_USER/.vnc/xstartup > /dev/null << EOF
#!/bin/bash
xrdb \$HOME/.Xresources
$DESKTOP_SESSION &
EOF

    sudo chmod +x /home/$REMOTE_USER/.vnc/xstartup
    sudo chown $REMOTE_USER:$REMOTE_USER /home/$REMOTE_USER/.vnc/xstartup

    run_cmd "tee /etc/systemd/system/vncserver@.service" > /dev/null << EOF
[Unit]
Description=Start TightVNC server at startup for $REMOTE_USER
After=syslog.target network.target

[Service]
Type=forking
User=$REMOTE_USER
Group=$REMOTE_USER
WorkingDirectory=/home/$REMOTE_USER

PIDFile=/home/$REMOTE_USER/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -depth 24 -geometry 1280x800 :%i
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF

    run_cmd "systemctl daemon-reload"
    run_cmd "systemctl enable vncserver@1.service"
    run_cmd "systemctl start vncserver@1.service"

    print_success "VNC Server berhasil diinstall dan dikonfigurasi untuk user $REMOTE_USER"
    print_status "VNC Server berjalan di port 5901"
}

# Fungsi untuk uninstall VNC
uninstall_vnc() {
    print_status "Menghapus VNC Server..."
    
    # Stop dan disable service VNC
    run_cmd "systemctl stop vncserver@1.service 2>/dev/null"
    run_cmd "systemctl disable vncserver@1.service 2>/dev/null"
    
    # Hapus file service
    run_cmd "rm -f /etc/systemd/system/vncserver@.service"
    run_cmd "systemctl daemon-reload"
    
    # Kill semua proses VNC yang berjalan
    run_cmd "pkill -f vncserver"
    
    # Hapus paket VNC
    run_cmd "apt remove --purge -y tightvncserver"
    
    # Hapus direktori .vnc dari user jika ada
    if [[ -n "$REMOTE_USER" && -d "/home/$REMOTE_USER/.vnc" ]]; then
        run_cmd "rm -rf /home/$REMOTE_USER/.vnc"
        print_status "Direktori VNC user $REMOTE_USER dihapus."
    fi
    
    print_success "VNC Server berhasil dihapus."
}

install_rdp() {
    print_status "Menginstall XRDP Server..."
    run_cmd "apt install -y xrdp"

    fix_xrdp_xfce_session

    run_cmd "systemctl enable xrdp"
    run_cmd "systemctl restart xrdp"

    run_cmd "ufw allow 3389/tcp 2>/dev/null"

    print_success "RDP Server berhasil diinstall dan dikonfigurasi"
    print_status "RDP Server berjalan di port 3389"
}

# Fungsi untuk uninstall RDP
uninstall_rdp() {
    print_status "Menghapus RDP Server..."
    
    # Stop dan disable service XRDP
    run_cmd "systemctl stop xrdp 2>/dev/null"
    run_cmd "systemctl disable xrdp 2>/dev/null"
    
    # Hapus paket XRDP
    run_cmd "apt remove --purge -y xrdp"
    
    # Hapus file konfigurasi XRDP
    run_cmd "rm -rf /etc/xrdp"
    
    # Hapus file .xsession dari user jika ada
    if [[ -n "$REMOTE_USER" && -f "/home/$REMOTE_USER/.xsession" ]]; then
        run_cmd "rm -f /home/$REMOTE_USER/.xsession"
        print_status "File .xsession user $REMOTE_USER dihapus."
    fi
    
    # Tutup port firewall
    run_cmd "ufw delete allow 3389/tcp 2>/dev/null"
    
    print_success "RDP Server berhasil dihapus."
}

install_tools() {
    print_status "Menginstall tools tambahan termasuk Firefox..."
    run_cmd "apt install -y wget curl nano vim htop neofetch firefox"
}

# Fungsi untuk uninstall tools
uninstall_tools() {
    print_status "Menghapus tools tambahan..."
    run_cmd "apt remove --purge -y firefox neofetch"
    print_success "Tools tambahan berhasil dihapus."
    print_status "Tools dasar seperti wget, curl, nano, vim, htop tetap dipertahankan."
}

# Fungsi untuk menghapus user
remove_user() {
    if [[ -n "$REMOTE_USER" ]]; then
        print_status "Menghapus user $REMOTE_USER..."
        # Kill semua proses user
        run_cmd "pkill -u $REMOTE_USER 2>/dev/null"
        # Hapus user beserta home directory
        run_cmd "userdel -r $REMOTE_USER 2>/dev/null"
        print_success "User $REMOTE_USER berhasil dihapus."
    fi
}

update_system() {
    print_status "Mengupdate sistem..."
    run_cmd "apt update && apt upgrade -y"
}

post_install_info() {
    echo ""
    echo "=============================================="
    print_success "OPERASI SELESAI!"
    echo "=============================================="
    echo ""
    print_status "Informasi Koneksi:"
    echo "IP Server: $(curl -s ifconfig.me)"
    echo ""

    if [[ "$1" == "vnc" || "$1" == "vncrdp" ]]; then
        echo "VNC Connection:"
        echo "- Port: 5901"
        echo "- Address: $(curl -s ifconfig.me):5901"
        echo "- Username: $REMOTE_USER"
        echo "- Gunakan aplikasi VNC Viewer"
        echo ""
    fi

    if [[ "$1" == "rdp" || "$1" == "vncrdp" ]]; then
        echo "RDP Connection:"
        echo "- Port: 3389"
        echo "- Address: $(curl -s ifconfig.me):3389"
        echo "- Username: $REMOTE_USER"
        echo "- Gunakan Remote Desktop Connection"
        echo ""
    fi

    print_warning "PENTING:"
    echo "1. Restart VPS setelah instalasi agar konfigurasi berjalan sempurna"
    echo "2. Pastikan port 5901 (VNC) dan/atau 3389 (RDP) dibuka pada firewall VPS dan provider"
    echo "3. Gunakan password yang kuat untuk keamanan"
    echo ""

    print_status "Untuk restart VNC server: systemctl restart vncserver@1.service"
    print_status "Untuk restart RDP server: systemctl restart xrdp"
    echo ""

    read -rp "Apakah Anda ingin restart sekarang? (y/n): " restart_choice
    if [[ $restart_choice == "y" || $restart_choice == "Y" ]]; then
        print_status "Restarting system..."
        run_cmd "reboot"
    else
        print_warning "Jangan lupa restart sistem nanti!"
    fi
}

# Fungsi untuk informasi setelah uninstall
post_uninstall_info() {
    echo ""
    echo "=============================================="
    print_success "UNINSTALL SELESAI!"
    echo "=============================================="
    echo ""
    print_status "Komponen yang telah dihapus:"
    echo "- Desktop Environment"
    echo "- VNC Server (jika terinstall)"
    echo "- RDP Server (jika terinstall)"
    echo "- Tools tambahan (Firefox, neofetch)"
    echo "- User yang dipilih (jika ada)"
    echo ""
    print_warning "Sistem telah dibersihkan. Disarankan untuk restart VPS."
    echo ""
    
    read -rp "Apakah Anda ingin restart sekarang? (y/n): " restart_choice
    if [[ $restart_choice == "y" || $restart_choice == "Y" ]]; then
        print_status "Restarting system..."
        run_cmd "reboot"
    else
        print_warning "Jangan lupa restart sistem nanti!"
    fi
}

# Menu untuk uninstall
uninstall_menu() {
    echo ""
    echo "===== MENU UNINSTALL ====="
    echo "1) Uninstall VNC Server saja"
    echo "2) Uninstall RDP Server saja"
    echo "3) Uninstall VNC & RDP Server"
    echo "4) Uninstall Semua (GUI + VNC + RDP + User)"
    echo "5) Kembali ke menu utama"
    read -rp "Masukkan pilihan (1-5): " UNINSTALL_CHOICE
    
    case $UNINSTALL_CHOICE in
        1)
            ask_user_to_remove
            if [[ $? -eq 0 ]]; then
                uninstall_vnc
                print_success "VNC Server berhasil di-uninstall."
            fi
            ;;
        2)
            ask_user_to_remove
            if [[ $? -eq 0 ]]; then
                uninstall_rdp
                print_success "RDP Server berhasil di-uninstall."
            fi
            ;;
        3)
            ask_user_to_remove
            if [[ $? -eq 0 ]]; then
                uninstall_vnc
                uninstall_rdp
                print_success "VNC & RDP Server berhasil di-uninstall."
            fi
            ;;
        4)
            print_warning "PERINGATAN: Ini akan menghapus SEMUA komponen yang diinstall!"
            read -rp "Apakah Anda yakin? (y/n): " confirm_all
            if [[ $confirm_all == "y" || $confirm_all == "Y" ]]; then
                ask_user_to_remove
                if [[ $? -eq 0 ]]; then
                    uninstall_vnc
                    uninstall_rdp
                    uninstall_desktop
                    uninstall_tools
                    remove_user
                    run_cmd "apt autoremove -y"
                    run_cmd "apt autoclean"
                    post_uninstall_info
                fi
            else
                print_status "Uninstall dibatalkan."
            fi
            ;;
        5)
            main_menu
            ;;
        *)
            print_error "Pilihan tidak valid!"
            uninstall_menu
            ;;
    esac
}

main_menu() {
    echo ""
    echo "===== MENU PILIHAN ====="
    echo "1) Install GUI + VNC Server"
    echo "2) Install GUI + RDP Server"
    echo "3) Install GUI + VNC & RDP Server"
    echo "4) Uninstall Components"
    echo "5) Keluar"
    read -rp "Masukkan pilihan (1-5): " MENU_CHOICE
    case $MENU_CHOICE in
        1)
            ask_remote_user
            update_system
            install_desktop
            create_xsession
            install_vnc
            install_tools
            post_install_info "vnc"
            ;;
        2)
            ask_remote_user
            update_system
            install_desktop
            create_xsession
            install_rdp
            install_tools
            post_install_info "rdp"
            ;;
        3)
            ask_remote_user
            update_system
            install_desktop
            create_xsession
            install_vnc
            install_rdp
            install_tools
            post_install_info "vncrdp"
            ;;
        4)
            uninstall_menu
            ;;
        5)
            print_status "Keluar dari script."
            exit 0
            ;;
        *)
            print_error "Pilihan tidak valid!"
            main_menu
            ;;
    esac
}

# Jalankan menu utama
main_menu