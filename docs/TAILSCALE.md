# Tailscale: Arsitektur Jaringan dan Komputasi Terdistribusi

> **Catatan untuk agent:** Dokumen ini bersifat **umum** (general) dan berlaku untuk semua repo, termasuk repo baru ke depannya.
> Jangan menaruh konfigurasi spesifik repo di sini. Lihat bagian [Dokumentasi per Repo](#8-dokumentasi-per-repo).
> Bagian panduan (komputasi, database, storage) bersifat **saran**: agent memilih sendiri sesuai kebutuhan repo.

Dokumen ini mendefinisikan konfigurasi Tailscale dan infrastruktur pendukung untuk pengembangan proyek dan eksekusi komputasi terdistribusi (termasuk trading kuantitatif). Cursor web memakai dokumen ini untuk membaca aturan. Komputer yang tetap hidup milik Grok Bot, bukan milik sesi Cursor web.

## 1. Topologi Jaringan dan Peran Node

| Node | Peran |
|------|-------|
| **VPS** | Subnet Router (menjangkau jaringan lokal) dan Exit Node (mengamankan lalu lintas internet) |
| **KomputerBox + nomor akun** | Komputer Grok Bot. Satu per akun. Tetap ada berhari-hari, dibuka dari aplikasi Grok Bot, bukan dari Cursor web. Akun ini: `KomputerBox25` |
| **KomputerBox1, KomputerBox2, dst.** | Server fisik lain, bila nanti ada. Mesh dua arah. Skala bisa sampai sekitar 30 node |

Sesi Cursor web mati bersama agen. Sesi itu bukan komputer Grok Bot dan tidak masuk tabel sebagai node yang tetap hidup.

## Pembagian compute

VPS adalah penghubung. CPU di VPS dipakai untuk layanan yang harus tetap hidup, dan untuk pekerjaan yang terikat pada akun di mesin itu. Beban layanan itu juga dibagi ke komputer Grok Bot yang sedang online, dan ke KomputerBox fisik yang sedang online. VPS bukan satu-satunya pekerja, dan VPS bukan pekerja DePIN.

Training dan pekerjaan batch yang tidak terikat akun di VPS dijalankan di komputer Grok Bot. Cursor web tidak menjalankan pekerjaan yang harus tetap hidup.

DePIN menyewakan sisa CPU dan disk, hanya di KomputerBox, dengan buffer, dan tidak pernah memakai 100% CPU atau RAM. Docker atau batas cgroup memisahkan proses DePIN dari layanan sendiri dan dari training, supaya DePIN tidak mengurangi jatah itu. DePIN tidak berjalan di VPS dan tidak berjalan di sesi agen yang ikut mati.

Satu KomputerBox cukup untuk mulai. Node lain ditambahkan kemudian. Node yang akan disambungkan owner tidak dianggap sudah online. Bila KomputerBox putus, layanan di VPS tetap jalan. Training menunggu node yang online.

Bagian 5 di bawah memilih kerangka untuk pekerjaan sendiri. DePIN bukan pengganti tabel itu.

## 2. Fitur Tailscale

**Aktif**
- **Tailscale SSH**: manajemen VPS dan compute nodes dari laptop tanpa kunci SSH tradisional.
- **MagicDNS**: nama host otomatis untuk tiap perangkat, mempermudah komunikasi antar-node.

**Direkomendasikan (aktifkan sesuai kebutuhan)**
- **Access Control Lists (ACL)**: batasi akses antar node seperlunya (mis. hanya laptop yang boleh SSH ke semua node; KomputerBox tidak perlu menjangkau VPS). Untuk banyak node, gunakan **tag** (mis. `tag:komputerbox`) agar tidak mengatur satu per satu. ACL belum dipakai.
- **Tags**: kelompokkan node berdasarkan peran, dipakai bersama ACL.
- **Auth key / tagged key**: untuk menambah node baru secara otomatis (tetap wajib konfirmasi ke user dulu).

**Tidak digunakan**
- **Tailscale Funnel**: sengaja tidak diaktifkan agar layanan tetap privat. Jangan mengaktifkannya tanpa persetujuan eksplisit.

MagicDNS dan Tailscale SSH adalah fitur yang dipakai pada node Linux. ACL, tag, exit node, dan subnet router mengubah siapa yang bisa dijangkau. Sebelum mengaktifkannya, beri tahu user. Jangan mengubah ACL atau menjadikan VPS sebagai exit node di dalam satu langkah yang sama dengan pekerjaan lain.

## 3. Konvensi Penamaan Node

Semua agent **wajib** mematuhi konvensi ini dan **melakukan konfirmasi ke user sebelum membuat node baru**.

- VPS: `VPS`
- Komputer Grok Bot, satu per akun: `KomputerBox` diikuti nomor akun. Akun ini memakai `KomputerBox25`. Komputer itu dibuka di aplikasi Grok Bot
- Server fisik lain, bila ada: `KomputerBox1`, `KomputerBox2`, dan seterusnya
- Sesi Cursor web tidak memakai nama itu

MagicDNS menampilkan nama host dalam huruf kecil (mis. `vps`, `komputerbox25`). Nama di konsol memakai huruf itu, tanpa spasi.

Nama lama `Grokbox1`, `grokbox-p4`, dan `CloudGrokBox25` tidak dipakai untuk node baru. `CloudGrokBox25` bukan komputer Grok Bot. Mesin yang sudah terdaftar diganti hanya bila owner meminta nama baru itu. Owner menetapkan pada 15 November 2026, 22.27 WIB: komputer yang tetap hidup milik Grok Bot, bukan Cursor web.

## 4. Ketersediaan Node (Wajib saat Setup)

Komputer Grok Bot, dan setiap KomputerBox fisik yang dipakai, harus **selalu hidup dan selalu terhubung ke tailnet**. Hubungan itu dua arah: node bisa dihubungi dari tailnet, dan node bisa menghubungi node lain. Node yang mati, tidur, atau kehilangan koneksi membuat kluster tidak bisa dipakai (gejalanya: status "Not connected" dan ping timeout). Menyambungkan komputer Grok Bot dilakukan dari aplikasi Grok Bot. Cursor web tidak menyambungkan sesinya sendiri lalu menghitungnya sebagai komputer itu. Pada 15 November 2026, 22.27 WIB, Grok Bot belum dibuka, jadi komputer itu belum masuk tailnet. Langkah `systemctl` di bawah untuk mesin Linux yang tetap hidup. VPS Windows tidak memakai langkah itu, dan agen tidak me-reboot VPS. Saat Grok Bot menyiapkan komputernya, pastikan hal berikut:

1. **Tailscale jalan otomatis saat boot**
   - `sudo systemctl enable --now tailscaled`
2. **Mesin tidak boleh sleep/suspend/hibernate**
   - `sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`
   - Untuk laptop: abaikan penutupan lid (`HandleLidSwitch=ignore` di `/etc/systemd/logind.conf`), dan pastikan terhubung ke daya.
3. **Key tidak boleh kedaluwarsa untuk node server**
   - Matikan key expiry untuk VPS dan komputer Grok Bot di admin console Tailscale (atau gunakan tagged auth key, yang tidak kedaluwarsa seperti key user).
4. **Gabung ke tailnet dengan Tailscale SSH aktif**
   - `sudo tailscale up --ssh` (tambahkan `--advertise-tags=tag:komputerbox` bila memakai tag dan ACL).
5. **Proses kerja berjalan sebagai service**
   - Gunakan `systemd` (atau tmux/screen untuk sementara) supaya Ray worker, MinIO, dan service lain hidup kembali setelah reboot dan tidak mati saat sesi SSH ditutup.
6. **Koneksi internet stabil**
   - Pastikan jaringan mesin tersambung otomatis setelah reboot atau putus.

**Verifikasi setelah setup** (agent wajib menjalankan dan melaporkan hasilnya ke user):

- `tailscale status`: node muncul dan berstatus terhubung.
- `tailscale ping <nama-node>`: balasan sukses dari node lain.
- `systemctl is-enabled tailscaled`: hasilnya `enabled`.
- Uji reboot bila memungkinkan: setelah restart, node kembali online sendiri tanpa tindakan manual.

**Jika node terlihat offline**, urutan pengecekan:

1. Cek mesin menyala dan punya internet.
2. `sudo systemctl status tailscaled`, jalankan ulang bila mati.
3. Cek di admin console apakah ada "Key expired", jika ya re-auth dengan `sudo tailscale up`.
4. Jika tidak ada akses lagi, SSH ke VPS lalu `tailscale ping <nama-node>`, dan beri tahu user bila butuh akses fisik atau lewat panel penyedia mesin.

## 5. Panduan Memilih Framework Komputasi Terdistribusi

Agent memilih sesuai kebutuhan repo. Pedoman umum:

| Kondisi | Pilihan |
|---------|---------|
| Backtest paralel, tuning parameter, simulasi Python | **Ray** (default yang disarankan) |
| Job batch banyak dan antri, node dipakai bareng, perlu jatah resource | **Slurm** |
| Skala besar (puluhan node) dengan campuran job panjang dan paralel | **Slurm + Ray** (Slurm membagi node, Ray berjalan di dalamnya) |
| Hanya 2 sampai 3 node, kerjaan sederhana | **Dask**, atau **Tailscale SSH + GNU Parallel** (hindari Slurm, overhead besar) |

Saran: mulai dari Ray, tambahkan Slurm bila antrean job mulai berantakan atau jumlah node bertambah banyak.

## 6. Opsi Database dan Storage

Konfigurasi penyimpanan disesuaikan dengan kebutuhan tiap repo. Opsi umum:

- **MinIO (object storage) di VPS + DuckDB di tiap node**: cocok untuk data Parquet dan riset analitik. Akses lewat jaringan Tailscale.
- **S3FS**: akses object storage dari Python di tiap node.
- **NFS**: sederhana untuk berbagi file antar node, cocok untuk skala kecil sampai menengah. Untuk 30 node, pertimbangkan storage yang lebih serius.
- **PostgreSQL / TimescaleDB**: untuk data time series terstruktur yang sering di-query atau butuh transaksi.
- **Redis**: cache dan antrean ringan antar node.

Untuk repo dengan banyak node yang membaca data besar, pertimbangkan jarak jaringan dan throughput: simpan data dekat dengan node yang memprosesnya.

## 7. Konteks bagi Agent

- Saat file ini ada di repo, agent memahami topologi komputasi yang tersedia, termasuk akses SSH ke VPS. Komputer yang tetap hidup adalah komputer Grok Bot. Cursor web tidak menggantikan komputer itu.
- Pilihan akhir framework dan storage ditentukan oleh agent berdasarkan kebutuhan repo yang sedang dikerjakan. Jika ragu atau pilihan berdampak besar, konfirmasi ke user.

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
- (mis. VPS, komputer Grok Bot `KomputerBox25`)

## Framework komputasi
- (Ray / Slurm / gabungan / lainnya, beserta alasannya)

## Ketersediaan node
- (service apa yang harus hidup terus di tiap node, dan cara cek statusnya)

## Cara menjalankan / deploy
- (perintah, path kerja di tiap node)

## Data dan storage
- (lokasi data, pilihan database/storage, alasannya)

## Catatan khusus
- (port, service, batasan, hal yang perlu dikonfirmasi)
```
