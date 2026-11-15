# Tailscale: Arsitektur Jaringan dan Komputasi Terdistribusi

> **Catatan untuk agent:** Dokumen ini bersifat **umum** (general) dan berlaku untuk semua repo, termasuk repo baru ke depannya.
> Jangan menaruh konfigurasi spesifik repo di sini. Lihat bagian [Dokumentasi per Repo](#8-dokumentasi-per-repo).
> Bagian panduan (komputasi, database, storage) bersifat **saran**: agent memilih sendiri sesuai kebutuhan repo.

Dokumen ini mendefinisikan konfigurasi Tailscale dan infrastruktur pendukung untuk pengembangan proyek dan eksekusi komputasi terdistribusi (termasuk trading kuantitatif). Dokumen ini berfungsi sebagai konteks utama bagi AI Agent (Cursor Web) saat menganalisis kode.

## 1. Topologi Jaringan dan Peran Node

| Node | Peran |
|------|-------|
| **VPS** | Subnet Router (menjangkau jaringan lokal) dan Exit Node (mengamankan lalu lintas internet). Konvensi namanya tetap `VPS`. VPS yang ada sekarang adalah mesin Windows dengan hostname `WIN-T65VC2J9G31` (nama di MagicDNS bisa masih mengikuti hostname itu sampai diubah). |
| **Grokbox1, Grokbox2, dst.** | Compute node berupa Linux VPS (ada systemd). Semua terhubung dalam satu jaringan mesh untuk komputasi terdistribusi. Skala bisa sampai sekitar 30 node. |
| **komputerboxN** | Compute node di komputer Grok Bot. Node pertama yang dipakai: `komputerbox10`. Jangan memakai nama `GrokboxN` untuk komputer Grok Bot. |

## 2. Fitur Tailscale

**Aktif**
- **MagicDNS**: nama host otomatis untuk tiap perangkat, mempermudah komunikasi antar-node.

**Direkomendasikan (aktifkan sesuai kebutuhan dan jenis mesin)**
- **Tailscale SSH**: untuk Linux VPS dan Grokbox. Jangan mengandalkannya di VPS Windows yang ada sekarang: SSH ke mesin itu memakai OpenSSH biasa plus kata sandi, bukan Tailscale SSH.
- **Access Control Lists (ACL)**: batasi akses antar node seperlunya (mis. hanya laptop yang boleh SSH ke semua node; komputerbox tidak perlu menjangkau VPS kecuali untuk tugas operasi). Untuk banyak node, gunakan **tag** (mis. `tag:grokbox`, `tag:komputerbox`) agar tidak mengatur satu per satu.
- **Tags**: kelompokkan node berdasarkan peran, dipakai bersama ACL.
- **Auth key / tagged key**: untuk menambah node baru secara otomatis (tetap wajib konfirmasi ke user dulu).

**Tidak digunakan**
- **Tailscale Funnel**: sengaja tidak diaktifkan agar layanan tetap privat. Jangan mengaktifkannya tanpa persetujuan eksplisit.
- **Connector Tailscale terkelola di Grok Bot**: hanya meneruskan HTTP(S). Jangan dipakai untuk SSH. Gejala jika dipaksa: HTTP 500 atau gagal membaca SSH protocol banner.

## 3. Konvensi Penamaan Node

Semua agent **wajib** mematuhi konvensi ini dan **melakukan konfirmasi ke user sebelum membuat node baru**.

- VPS: `VPS` (mesin yang ada masih memakai hostname Windows `WIN-T65VC2J9G31`)
- Compute nodes Linux VPS: `Grokbox1`, `Grokbox2`, dan seterusnya
- Compute nodes di komputer Grok Bot: `komputerboxN` (node pertama: `komputerbox10`). Konfirmasi nomor `N` ke user sebelum menambah node baru.

Catatan: MagicDNS menampilkan nama host dalam huruf kecil (mis. `vps`, `grokbox1`, `komputerbox10`). Jika ada node lama dengan nama di luar konvensi, tanyakan ke user sebelum mengganti nama atau mencabutnya.

## 4. Ketersediaan Node (Wajib saat Setup)

Setiap mesin harus **selalu hidup dan selalu terhubung ke tailnet**. User mensyaratkan semua node `komputerbox` nyala otomatis, **tanpa bergantung pada agent atau routine**. Node yang mati, tidur, atau kehilangan koneksi membuat kluster tidak bisa dipakai (gejalanya: status "Not connected" dan ping timeout).

Langkah systemd di [bagian 4.1](#41-linux-vps-dan-grokbox-systemd) hanya berlaku untuk **Linux VPS dan Grokbox**. Jangan menjalankannya di VPS Windows, dan jangan menganggapnya tersedia di komputer Grok Bot.

### 4.1 Linux VPS dan Grokbox (systemd)

Saat agent men-setup atau menyiapkan mesin Linux VPS / Grokbox, pastikan hal berikut:

1. **Tailscale jalan otomatis saat boot**
   - `sudo systemctl enable --now tailscaled`
2. **Mesin tidak boleh sleep/suspend/hibernate**
   - `sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`
   - Untuk laptop: abaikan penutupan lid (`HandleLidSwitch=ignore` di `/etc/systemd/logind.conf`), dan pastikan terhubung ke daya.
3. **Key tidak boleh kedaluwarsa untuk node server**
   - Matikan key expiry untuk VPS, Grokbox, dan komputerbox di admin console Tailscale (atau gunakan tagged auth key, yang tidak kedaluwarsa seperti key user).
4. **Gabung ke tailnet**
   - `sudo tailscale up --ssh` (tambahkan `--advertise-tags=tag:grokbox` bila memakai tag dan ACL). Flag `--ssh` untuk Linux VPS / Grokbox, bukan untuk VPS Windows.
5. **Proses kerja berjalan sebagai service**
   - Gunakan `systemd` (atau tmux/screen untuk sementara) supaya Ray worker, MinIO, dan service lain hidup kembali setelah reboot dan tidak mati saat sesi SSH ditutup.
6. **Koneksi internet stabil**
   - Pastikan jaringan mesin tersambung otomatis setelah reboot atau putus.

### 4.2 VPS Windows

VPS Windows tidak memakai systemd. Autostart mengikuti layanan Windows dan tugas terjadwal yang sudah ada di mesin itu. Jangan menambahkan unit systemd. SSH tetap OpenSSH biasa plus kata sandi, bukan Tailscale SSH. Restart mesin VPS hanya boleh dilakukan owner.

### 4.3 Komputer Grok Bot (komputerbox)

Komputer Grok Bot **tidak punya systemd**. Rantai boot adalah `/tini` → `/pod-daemon` (keduanya biner platform). `systemctl` tidak tersedia. Langkah di bagian 4.1 tidak berlaku di sini. **Tidak ada hook boot yang bisa dikontrol.**

Tailscale di komputer ini dijalankan lewat skrip, bukan layanan systemd:

- Pintu masuk: `/home/box/bin/compute-start.sh` (memegang `flock`, lalu menyalakan `/home/box/bin/compute-watchdog.sh --loop 30`). Aman dipanggil berkali-kali.
- Watchdog memeriksa Tailscale dan service komputasi setiap 30 detik, lalu menyalakan ulang yang mati. Log: `/home/box/logs/compute-watchdog.log`.
- Join / pulihkan Tailscale: `/home/box/bin/tailscale-up.sh`.
- Mode jaringan yang dipakai sekarang di `komputerbox10`: **kernel TUN** pada antarmuka `tailscale0`. Root punya `CAP_NET_ADMIN`. Flag: `--netfilter-mode=off` dan `--accept-dns=false`.
- Jika `/dev/net/tun` atau hak itu tidak ada, skrip jatuh ke `--tun=userspace-networking`. Mode userspace membatasi lalu lintas inbound: node lain sering tidak bisa membuka TCP ke port layanan (misalnya Ray).
- Proxy SOCKS5 tetap di `localhost:1055` pada kedua mode, dipakai SSH ke VPS Windows.
- Sambungkan ke VPS dengan IP Tailscale, bukan nama MagicDNS, kecuali dokumen per repo secara eksplisit memakai nama `.ts.net`.
- Tipe NAT box adalah `MappingVariesByDestIP`, jadi koneksi ke peer cenderung lewat relay DERP (sekitar 200 ms), meskipun mode sudah TUN.

**Autostart tanpa agent tidak dijamin** di komputer Grok Bot. Temuan 15 November 2026 (WIB) di `komputerbox10`:

- Tidak ada crontab, dan tidak ada hook pada rantai `/tini` → `/pod-daemon` yang bisa dijamin bertahan antar sesi.
- Cadangan hanya hook shell interaktif di `/etc/bash.bashrc`, `/home/box/.bashrc`, dan `/etc/profile.d/compute-autostart.sh`. Hook itu hanya jalan ketika sebuah shell interaktif dimulai, jadi tetap bergantung pada adanya sesi.
- Setelah box di-restart atau di-pause di luar kendali, stack baru hidup lagi saat ada shell interaktif, atau saat agent menjalankan `compute-start.sh`.

Karena itu, node yang **wajib** nyala otomatis 24 jam tanpa agent harus berupa **Linux VPS dengan systemd**, mengikuti bagian 4.1. Templat bootstrap untuk mesin itu ada di komputer Grok Bot, di `/workspace/compute/node-bootstrap/` (jangan men-commit skrip atau berkas yang berisi secret). Komputerbox adalah node tambahan yang bisa cepat dipulihkan lewat skrip, bukan node inti ketersediaan.

### 4.4 Verifikasi setelah setup

Agent wajib menjalankan dan melaporkan hasilnya ke user:

- `tailscale status`: node muncul dan berstatus terhubung.
- `tailscale ping <nama-node>`: balasan sukses dari node lain (boleh lewat DERP).
- `systemctl is-enabled tailscaled`: hasilnya `enabled` — **hanya** di Linux VPS / Grokbox. Jangan dijalankan di VPS Windows atau komputer Grok Bot.
- Uji reboot bila memungkinkan, dan hanya pada mesin yang boleh di-reboot: setelah restart, node kembali online sendiri tanpa tindakan manual. Jangan merestart VPS Windows tanpa perintah owner.

**Jika node terlihat offline**, urutan pengecekan:

1. Cek mesin menyala dan punya internet.
2. Linux VPS / Grokbox: `sudo systemctl status tailscaled`, jalankan ulang bila mati. Komputer Grok Bot: jalankan `/home/box/bin/compute-start.sh` (atau `/home/box/bin/tailscale-up.sh` jika hanya Tailscale yang perlu dipulihkan).
3. Cek di admin console apakah ada "Key expired", jika ya re-auth (Linux: `sudo tailscale up`; komputer Grok Bot: `tailscale-up.sh` dengan auth key yang diberikan user).
4. Jika tidak ada akses lagi, SSH ke VPS (OpenSSH biasa, bukan connector terkelola) lalu `tailscale ping <nama-node>`, dan beri tahu user bila butuh akses fisik atau lewat panel penyedia mesin.

## 5. Panduan Memilih Framework Komputasi Terdistribusi

Agent memilih sesuai kebutuhan repo. Pedoman umum:

| Kondisi | Pilihan |
|---------|---------|
| Backtest paralel, tuning parameter, simulasi Python | **Ray** (default yang disarankan) |
| Job batch banyak dan antri, node dipakai bareng, perlu jatah resource | **Slurm** |
| Skala besar (puluhan node) dengan campuran job panjang dan paralel | **Slurm + Ray** (Slurm membagi node, Ray berjalan di dalamnya) |
| Hanya 2 sampai 3 node, kerjaan sederhana | **Dask**, atau **Tailscale SSH + GNU Parallel** (hindari Slurm, overhead besar; Tailscale SSH hanya di Linux) |

Saran: mulai dari Ray, tambahkan Slurm bila antrean job mulai berantakan atau jumlah node bertambah banyak. Jika head atau worker Ray diletakkan di komputerbox, pakai mode TUN (bagian 4.3) dan perhitungkan latensi DERP. **TODO keamanan:** sebelum menambah worker, batasi akses dengan ACL tag di tailnet dan/atau `RAY_AUTH_MODE=token` di semua node; head yang ada belum memakai token auth.

## 6. Opsi Database dan Storage

Konfigurasi penyimpanan disesuaikan dengan kebutuhan tiap repo. Opsi umum:

- **MinIO (object storage) di VPS + DuckDB di tiap node**: cocok untuk data Parquet dan riset analitik. Akses lewat jaringan Tailscale.
- **S3 / R2 / S3FS**: akses object storage dari Python di tiap node.
- **NFS**: sederhana untuk berbagi file antar node, cocok untuk skala kecil sampai menengah. Untuk 30 node, pertimbangkan storage yang lebih serius.
- **PostgreSQL / TimescaleDB**: untuk data time series terstruktur yang sering di-query atau butuh transaksi.
- **Redis**: cache dan antrean ringan antar node.

Untuk repo dengan banyak node yang membaca data besar, pertimbangkan jarak jaringan dan throughput: simpan data dekat dengan node yang memprosesnya. Pilihan konkret (R2, Supabase, disk VPS, dan sebagainya) ditulis di dokumen per repo, bukan di sini.

## 7. Konteks bagi Agent

- Saat file ini ada di repo, agent memahami topologi komputasi yang tersedia, termasuk akses SSH ke VPS dan pemanfaatan kluster Grokbox / komputerbox.
- Pilihan akhir framework dan storage ditentukan oleh agent berdasarkan kebutuhan repo yang sedang dikerjakan. Jika ragu atau pilihan berdampak besar, konfirmasi ke user.
- Jangan menulis auth key Tailscale, kata sandi SSH, atau rahasia lain ke repo, isu, PR, atau log.

## 8. Dokumentasi per Repo

Setiap repo punya kasus dan konfigurasi berbeda, jadi detailnya dipisah dari dokumen umum ini.

Saat agent membuka sebuah repo:

1. Cek apakah sudah ada dokumen Tailscale khusus repo tersebut (default: `docs/TAILSCALE_REPO.md`).
2. **Jika sudah ada**, baca dan ikuti.
3. **Jika belum ada**, buat satu dokumen baru dengan nama di atas, isi sesuai kebutuhan repo itu.

Template minimal dokumen per repo:

```markdown
# Tailscale: <nama-repo>

> Mengikuti aturan umum di TAILSCALE.md

## Node yang dipakai
- (mis. VPS Windows WIN-T65VC2J9G31, komputerbox10, Grokbox1)

## Framework komputasi
- (Ray / Slurm / gabungan / lainnya, beserta alasannya)

## Ketersediaan node
- (service apa yang harus hidup terus di tiap node, dan cara cek statusnya)

## Cara menjalankan / deploy
- (perintah, path kerja di tiap node; SSH OpenSSH atau Tailscale SSH)

## Data dan storage
- (lokasi data, pilihan database/storage, alasannya)

## Catatan khusus
- (port, service, Funnel, connector HTTP-only, batasan, hal yang perlu dikonfirmasi)
```
