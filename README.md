
---

# Setup VPS to RDP

Script otomatis untuk meremot VPS Linux menggunakan RDP (Remote Desktop Protocol) berbasis desktop environment menggunakan xrdp.

## Fitur

- Instalasi otomatis desktop environment (XFCE)
- Instalasi dan konfigurasi xrdp
- Mendukung berbagai distribusi Linux (Ubuntu, Debian, dll)
- Mudah digunakan, hanya dengan satu perintah

## Prasyarat

- VPS dengan akses root (atau sudo)
- Sistem operasi berbasis Debian/Ubuntu (direkomendasikan)
- Koneksi internet yang stabil

## Cara Penggunaan

### 1. Jalankan Script Instalasi

Jalankan perintah berikut di VPS Anda:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/ghostinbyte/Setup-vps-to-rdp/main/setup.sh)
```

Tunggu proses instalasi selesai.

### 2. (Opsional) Perbaiki Masalah Xsession

Jika Anda mengalami masalah saat login RDP (misal: layar hitam atau gagal masuk), jalankan script perbaikan berikut:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/ghostinbyte/Setup-vps-to-rdp/main/fix-xsession.sh)
```

### 3. Akses VPS melalui RDP

- Gunakan aplikasi Remote Desktop (misal: Remote Desktop Connection di Windows)
- Masukkan IP VPS dan login menggunakan username serta password VPS Anda

## Catatan

- Pastikan port 3389 (default RDP) terbuka di firewall VPS Anda.
- Script ini hanya menginstal desktop environment dan xrdp, **tidak mengubah sistem menjadi Windows**.
- Untuk keamanan, ganti password user VPS Anda secara berkala.

---
