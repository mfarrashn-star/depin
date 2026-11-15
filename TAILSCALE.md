# Tailscale: Arsitektur Jaringan dan Komputasi Terdistribusi

> **Catatan untuk agent:** Dokumen ini bersifat **umum** dan berlaku untuk semua repo, termasuk repo baru.
> Jangan menaruh konfigurasi yang hanya berlaku di satu repo di sini. Lihat [Dokumentasi per Repo](#11-dokumentasi-per-repo).
> Dokumen ini sengaja cukup lengkap supaya agent di akun Grok lain bisa bekerja sendiri: menambah node, memasang tag, dan mengikuti aturan yang sama, tanpa menunggu instruksi ulang.

Dokumen ini mendefinisikan topologi Tailscale, pembagian peran, prioritas compute, dan cara bergabung ke kluster. Isi berkas ini **harus identik** di semua repo. Fakta per repo ada di `docs/TAILSCALE_REPO.md`.

Diperbarui 15 November 2026 (WIB). Yang sudah jalan dan yang baru diputuskan dipisah secara eksplisit di bawah.

## 1. Topologi Jaringan dan Peran Node

Tailnet: MagicDNS `tail7d94e8.ts.net`. Skala awal masih kecil, tetapi desainnya harus mudah ditambah node baru.

| Node | IP Tailscale | Tag | Peran |
|------|----------------|-----|-------|
| VPS Windows `WIN-T65VC2J9G31` | `100.103.231.61` | `tag:vps` (belum dipasang sampai ACL diterapkan) | **Koordinator saja.** Bukan mesin hitungan berat. |
| `komputerbox10` | `100.116.213.30` | `tag:compute` (belum dipasang sampai ACL diterapkan) | Node compute pertama (komputer Grok Bot). Head Ray saat ini. |
| `komputerboxN` berikutnya | — | `tag:compute` | Komputer Grok Bot tambahan. Konfirmasi nomor `N` ke owner sebelum join. |
| `GrokboxN` (rencana) | — | `tag:compute` | Linux VPS/KVM 24/7 dengan systemd. Belum ada. Konfirmasi nama ke owner sebelum join. |
| `grokbot-box` | `100.107.153.80` | — | Nama lama. **Jangan disentuh, diganti namanya, atau dicabut** tanpa perintah eksplisit owner. |
| Perangkat owner (HP, laptop) | — | tanpa tag | Akses penuh milik owner. Jangan menag-nya. |

### 1.1 VPS adalah koordinator, bukan mesin hitungan

VPS Windows hanya mengerjakan hal yang memang harus tinggal di mesin produksi:

- antrean job dan **pembagian data**: node mengambil data job dan input lewat VPS
- website aduhkerja
- quantitative-trading **live dan paper** (butuh login broker / MT5)
- tempat login yang tidak bisa dipindah, misalnya login provider Akash di masa depan

VPS **tidak** dipakai untuk hitungan berat, storage terdistribusi, atau bandwidth DePIN. Jangan menaruh backtest, training, riset berat, atau penyimpanan hasil besar di VPS. Data aplikasi aduhkerja tetap di Supabase, bukan di storage node.

### 1.2 komputerbox dan Grokbox mengerjakan compute, bandwidth, dan storage

Node `tag:compute` mengerjakan hitungan, bandwidth, dan storage. Contoh: backtest, training, riset, dan (nanti) kapasitas sisa untuk DePIN. Hasil berat tidak disimpan permanen di VPS.

### 1.3 Exit node dan subnet router

Keputusan owner: **exit node saja**, subnet router dilewati kecuali nanti ada perangkat LAN di VPS yang benar-benar perlu diakses dan tidak bisa dipasangi Tailscale. Exit node berguna untuk IP tetap (misalnya whitelist broker), tetapi memakai bandwidth VPS, jadi jangan dijadikan default semua perangkat. Perubahan ini menyentuh jaringan mesin produksi: **jangan diterapkan tanpa izin owner**, dan cek aduhkerja tetap jalan sebelum serta sesudahnya. Sampai tertulis di dokumen per repo bahwa sudah aktif, anggap belum dipasang.

## 2. Fitur Tailscale

**Aktif**
- **MagicDNS** di tailnet. Di komputer Grok Bot, Tailscale dijalankan dengan `--accept-dns=false`, jadi dari box pakai **IP Tailscale**, bukan nama `.ts.net`, kecuali dokumen per repo secara eksplisit memakai nama itu.

**Direkomendasikan (aktifkan sesuai jenis mesin)**
- **ACL + tag** `tag:compute` dan `tag:vps`. Draf kebijakan ada di [`docs/tailnet-policy.hujson`](docs/tailnet-policy.hujson). **Belum diterapkan** di admin console (lihat [bagian 8](#8-tag-acl-dan-cara-menambah-node)).
- **Tailscale SSH**: untuk Linux VPS / Grokbox, bila disepakati. Jangan mengandalkannya di VPS Windows: SSH ke mesin itu memakai OpenSSH biasa plus kata sandi.
- **Auth key / tagged key**: untuk menambah node baru. Tetap wajib konfirmasi ke owner sebelum membuat node atau auth key baru.

**Tidak digunakan**
- **Tailscale Funnel**: tetap mati. Jangan diaktifkan tanpa persetujuan eksplisit owner.
- **Connector Tailscale terkelola di Grok Bot**: hanya meneruskan HTTP(S). Jangan dipakai untuk SSH. Gejala jika dipaksa: HTTP 500 atau gagal membaca SSH protocol banner.
- **Subnet router**: dilewati, lihat bagian 1.3.
- Alarm chat saat node mati: **tidak dipasang** (keputusan owner). Status dilihat di dashboard node (tailnet saja) begitu dashboard itu ada.

## 3. Konvensi Penamaan Node

Semua agent **wajib** mematuhi konvensi ini dan **konfirmasi ke owner sebelum membuat node baru atau mengganti nama node lama**.

- VPS: konvensi namanya `VPS`. Mesin yang ada masih memakai hostname Windows `WIN-T65VC2J9G31` (MagicDNS bisa masih mengikuti hostname itu).
- Komputer Grok Bot: `komputerboxN`. Node pertama: `komputerbox10`. Jangan memakai nama `GrokboxN` untuk komputer Grok Bot.
- Linux VPS/KVM 24/7: `Grokbox1`, `Grokbox2`, dan seterusnya.
- MagicDNS menampilkan nama dalam huruf kecil (mis. `vps`, `grokbox1`, `komputerbox10`).

Jika ada node lama di luar konvensi, tanyakan ke owner sebelum mengganti nama atau mencabutnya. Jangan menyentuh `grokbot-box`.

## 4. Kebijakan Prioritas Compute

Berlaku di semua node, termasuk VPS. Jangan dilanggar saat menjadwalkan job atau memasang workload baru.

1. **Server aduhkerja selalu jalan.** Ini prioritas paling atas di VPS.
2. **quantitative-trading juga prioritas atas.** Live dan paper **hanya** di VPS (butuh login). Backtest, training, dan riset dijalankan di komputerbox / Grokbox, dan dihindarkan dari VPS karena berat.
3. **DePIN prioritas kedua.** Hanya memakai **kapasitas sisa**, dan jatahnya menyesuaikan secara dinamis. Tidak ada kuota persentase tetap. Pemakaian QT dan server tidak boleh berkurang karena DePIN.
4. **Tidak ada node, termasuk VPS, yang boleh mencapai pemakaian 100%** (CPU, RAM, disk, atau bandwidth). Sisakan kepala selalu.

## 5. Ketersediaan Node

Idealnya setiap mesin selalu hidup dan selalu terhubung ke tailnet. Kenyataan per jenis mesin berbeda. Langkah systemd di [bagian 5.1](#51-linux-vps-dan-grokbox-systemd) hanya berlaku untuk **Linux VPS dan Grokbox**. Jangan menjalankannya di VPS Windows, dan jangan menganggapnya tersedia di komputer Grok Bot.

### 5.1 Linux VPS dan Grokbox (systemd)

Ini jalur node 24/7 yang benar-benar nyala sendiri setelah reboot. Saat men-setup mesin Linux VPS / Grokbox:

1. **Tailscale jalan otomatis saat boot:** `sudo systemctl enable --now tailscaled`
2. **Mesin tidak boleh sleep/suspend/hibernate:** `sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`. Untuk laptop: `HandleLidSwitch=ignore` di `/etc/systemd/logind.conf`, dan pastikan terhubung ke daya.
3. **Key tidak boleh kedaluwarsa** untuk node server: matikan key expiry di admin console, atau pakai tagged auth key.
4. **Gabung ke tailnet** dengan hostname yang sudah disetujui owner, dan `--advertise-tags=tag:compute` setelah ACL diterapkan. Flag `--ssh` hanya untuk Linux bila disepakati, bukan untuk VPS Windows. Funnel tetap mati.
5. **Proses kerja sebagai service systemd** (`Restart=always`), termasuk Ray worker. Templat: `/workspace/compute/node-bootstrap/` di komputer Grok Bot (jangan men-commit secret).
6. Pastikan jaringan mesin tersambung otomatis setelah reboot atau putus.

### 5.2 VPS Windows

VPS Windows tidak memakai systemd. Autostart mengikuti layanan Windows dan tugas terjadwal yang sudah ada. Jangan menambahkan unit systemd. SSH tetap OpenSSH biasa plus kata sandi, bukan Tailscale SSH. **Restart mesin VPS dan perubahan di VPS hanya boleh setelah izin owner.**

### 5.3 Komputer Grok Bot (komputerbox)

Komputer Grok Bot **tidak punya systemd**. Rantai boot adalah `/tini` → `/pod-daemon` (keduanya biner platform). `systemctl` tidak tersedia. **Tidak ada hook boot yang bisa dikontrol.**

Tailscale dan Ray di komputer ini dijalankan lewat skrip:

- Pintu masuk: `/home/box/bin/compute-start.sh` (memegang `flock`, lalu menyalakan `/home/box/bin/compute-watchdog.sh --loop 30`). Aman dipanggil berkali-kali.
- Watchdog lokal memeriksa Tailscale dan service komputasi setiap **30 detik**, lalu menyalakan ulang yang mati. Log: `/home/box/logs/compute-watchdog.log`.
- Cadangan: bot **watchdog** menjalankan routine setiap **15 menit** (memanggil `compute-start.sh`, lalu memeriksa Tailscale dan Ray). Ia diam jika sehat, dan hanya perlu diperhatikan jika ada yang mati lalu dihidupkan lagi, atau gagal dihidupkan.
- Join / pulihkan Tailscale: `/home/box/bin/tailscale-up.sh`.
- Mode di `komputerbox10`: **kernel TUN** pada antarmuka `tailscale0`. Root punya `CAP_NET_ADMIN`. Flag: `--netfilter-mode=off` dan `--accept-dns=false`.
- Jika `/dev/net/tun` atau hak itu tidak ada, skrip jatuh ke `--tun=userspace-networking`. Mode userspace membatasi lalu lintas inbound: node lain sering tidak bisa membuka TCP ke port layanan (misalnya Ray).
- Proxy SOCKS5 tetap di `localhost:1055` pada kedua mode, dipakai SSH ke VPS Windows.
- Tipe NAT box adalah `MappingVariesByDestIP`, jadi koneksi ke peer cenderung lewat relay DERP (sekitar 200 ms), meskipun mode sudah TUN.

**Autostart tanpa agent atau shell interaktif tidak dijamin.** Temuan 15 November 2026 (WIB) di `komputerbox10`:

- Tidak ada crontab, dan tidak ada hook pada rantai `/tini` → `/pod-daemon` yang bisa dijamin bertahan antar sesi.
- Ada hook shell interaktif di `/etc/bash.bashrc`, `/home/box/.bashrc`, dan `/etc/profile.d/compute-autostart.sh`. Hook itu hanya jalan ketika shell interaktif dimulai.
- Setelah box di-restart atau di-pause di luar kendali, stack baru hidup lagi saat ada shell interaktif, saat agent menjalankan `compute-start.sh`, atau saat routine bot watchdog (paling lama sekitar 15 menit) sempat jalan.

Karena itu, node yang **wajib** nyala otomatis 24 jam tanpa agent harus berupa **Linux VPS dengan systemd**, mengikuti bagian 5.1. `komputerbox10` adalah tenaga tambahan yang bisa cepat dipulihkan, bukan satu-satunya tumpuan ketersediaan.

### 5.4 Heartbeat dan dashboard node

Desain yang disepakati (rincian alamat dan port akan dilengkapi kemudian):

- Setiap node mengirim heartbeat ke VPS secara berkala.
- Jika sebuah node berhenti lapor, VPS menganggapnya mati, menarik kembali job yang sedang dipegangnya (lease dikembalikan ke antrean), dan membagikan job itu ke node lain.
- Ada **dashboard node di VPS**, hanya bisa diakses dari tailnet, bukan dari internet. Isinya dirancang untuk memantau node yang aktif atau mati, plus CPU, RAM, storage, dan bandwidth per node (termasuk VPS) serta totalnya, plus tanda jika ada node yang hampir penuh. Rincian URL, port, dan cara buka shortcut di desktop VPS akan diisi pekerja lain setelah layanan itu berdiri.
- **Tidak ada alarm chat** saat node mati (keputusan owner).

Jangan menganggap heartbeat atau dashboard sudah hidup sampai dokumen per repo menuliskan alamatnya.

### 5.5 Verifikasi setelah setup

Agent wajib menjalankan dan melaporkan hasilnya ke owner:

- `tailscale status`: node muncul dan berstatus terhubung.
- `tailscale ping <nama-atau-ip-node>`: balasan sukses dari node lain (boleh lewat DERP).
- `systemctl is-enabled tailscaled`: hasilnya `enabled` — **hanya** di Linux VPS / Grokbox. Jangan dijalankan di VPS Windows atau komputer Grok Bot.
- Uji reboot hanya pada mesin yang boleh di-reboot: setelah restart, node kembali online sendiri. Jangan merestart VPS Windows tanpa perintah owner.

**Jika node terlihat offline:**

1. Cek mesin menyala dan punya internet.
2. Linux VPS / Grokbox: `sudo systemctl status tailscaled`, jalankan ulang bila mati. Komputer Grok Bot: jalankan `/home/box/bin/compute-start.sh` (atau `/home/box/bin/tailscale-up.sh` jika hanya Tailscale yang perlu dipulihkan).
3. Cek di admin console apakah ada "Key expired"; jika ya, re-auth (Linux: `sudo tailscale up`; komputer Grok Bot: `tailscale-up.sh` dengan auth key yang diberikan owner).
4. Jika tidak ada akses lagi, SSH ke VPS (OpenSSH biasa, bukan connector terkelola) lalu `tailscale ping`, dan beri tahu owner bila butuh akses fisik atau lewat panel penyedia mesin.

## 6. Framework Komputasi Terdistribusi

Pola yang sudah diputuskan owner, dan yang harus diikuti repo baru kecuali ada keputusan baru:

- **Di dalam tiap node:** Ray.
- **Antar node:** antrean job di VPS. Node compute mengambil job, mengerjakannya, lalu mengembalikan hasilnya. Data dan input job diambil lewat VPS (pembagian data), hitungannya tetap di komputerbox / Grokbox.

### 6.1 Ray

- Versi acuan: Ray 2.60.0, Python 3.13. Worker baru **harus** memakai versi Python dan Ray yang sama dengan head.
- Head saat ini: `100.116.213.30:6379` (`komputerbox10`). Klien dari node lain: `ray://100.116.213.30:10001`.
- Dashboard Ray: hanya `127.0.0.1:8265`, tidak diekspos ke tailnet.
- Batas resource head di `komputerbox10`: 6 CPU, memori 8 GiB, object store 2 GiB (sisa untuk proses lain di box yang sama, dan agar pemakaian tidak 100%).
- Port tetap: GCS 6379, client 10001, node-manager 6380, object-manager 6381, dashboard-agent 52365, metrics 8090, worker 10002–10200.
- **Token auth wajib.** `RAY_AUTH_MODE=token`. Token disimpan di berkas mode `600` (di head: `/home/box/.config/ray/auth_token`; di node systemd: `/etc/ray/auth_token`). Jangan `cat` isinya, jangan menulisnya ke chat, PR, log, atau repo, dan jangan men-commit berkas itu. Koneksi tanpa token atau dengan token salah harus ditolak. Salin token antar node lewat tailnet (misalnya `scp`), bukan lewat chat.
- Karena head sekarang di `komputerbox10` yang tidak dijamin 24/7, untuk kluster 24/7 nanti head bisa dipindah ke Grokbox Linux pertama. Itu perubahan tersendiri dan perlu izin owner.
- Latensi antar-node sering lewat DERP (~200 ms). Cocok untuk job yang lumayan besar per potong (misalnya backtest per set parameter), bukan tugas yang sangat chatty.

### 6.2 Antrean job di VPS

Antrean tinggal di VPS agar pembagian tugas tetap jalan meskipun satu komputerbox mati. VPS hanya menyimpan dan membagikan job, dengan pemakaian RAM/CPU kecil dan prioritas proses rendah, supaya aduhkerja dan trading tetap nomor satu.

Perilaku yang disepakati: job memakai **lease**. Jika node pemegang lease mati (heartbeat berhenti), job dikembalikan ke antrean dan diambil node lain. Jangan menjalankan antrean di `komputerbox10` sebagai lokasi tetap; itu membuat antrean ikut mati saat box tidur.

Implementasi antrean (perangkat lunak, port, dan cara ambil data) masih dikerjakan. Jangan menganggap layanan antrean sudah mendengar di VPS sampai dokumen per repo menuliskan cara pakainya. Saat port sudah ada, tambahkan ke `docs/tailnet-policy.hujson` lalu minta owner menyimpan ACL.

Slurm belum dipakai. Pertimbangkan nanti bila jumlah node dan antrean sudah besar (~10 node atau antrean mulai berantakan).

## 7. Data, Storage, dan Bandwidth

- VPS adalah **titik pembagian data**, bukan gudang hasil berat. Node mengambil input job lewat VPS, mengerjakannya di node compute, dan menyimpan hasil jangka panjang di tempat yang ditentukan dokumen per repo (bukan disk VPS untuk artefak besar).
- aduhkerja: data aplikasi di **Supabase**. Jangan memasukkan storage aduhkerja ke skema storage terdistribusi di komputerbox.
- quantitative-trading: bucket R2 dan operasi tulis R2 hanya lewat CHIEF di VPS. Jangan menaruh kredensial R2 di worker.
- Object store Ray hanya untuk data antar-task, bukan penyimpanan jangka panjang.
- Storage dan bandwidth komputerbox boleh dipakai workload yang memang untuk itu (termasuk DePIN nanti), dengan tetap mengikuti [kebijakan prioritas](#4-kebijakan-prioritas-compute) dan tidak sampai 100%.

Pilihan konkret per repo ditulis di `docs/TAILSCALE_REPO.md`, bukan di sini.

## 8. Tag, ACL, dan Cara Menambah Node

Tag yang dipakai:

- `tag:compute` — komputerbox, Grokbox, dan node hitungan lain
- `tag:vps` — VPS Windows koordinator
- perangkat owner tetap tanpa tag

Draf kebijakan (tanpa rahasia) ada di [`docs/tailnet-policy.hujson`](docs/tailnet-policy.hujson). Salinan kerja di komputer Grok Bot: `/workspace/compute/tailnet-policy.hujson`. Auth key node **tidak bisa** menulis ACL. Menerapkan kebijakan ini butuh akses admin console owner, atau API key Tailscale yang diberikan owner khusus untuk itu.

Isi draf secara ringkas:

- Hanya owner yang boleh memasang `tag:compute` dan `tag:vps`.
- Owner (perangkat tanpa tag) tetap punya akses penuh, supaya tidak terkunci saat tag belum selesai dipasang.
- `tag:compute` boleh saling menjangkau port Ray.
- `tag:compute` boleh SSH (TCP 22) ke VPS, karena agen di `komputerbox10` memakai jalur itu untuk operasi. RDP (3389) tetap hanya untuk owner. Port antrean, heartbeat, dan dashboard akan ditambahkan ke draf saat layanan itu berdiri.
- Funnel tidak diizinkan di berkas ini (tidak ada atribut `funnel`).

**Hati-hati:** setelah perangkat di-tag, identitas usernya hilang dan hanya tag yang berlaku. Jangan menag `komputerbox10` dengan `tag:compute` sebelum kebijakan di atas tersimpan. Jika ACL lama tidak memberi `tag:compute` akses TCP 22 ke VPS, SSH dari box ke VPS akan putus.

### 8.1 Menerapkan ACL (sekali, oleh owner atau agen yang diberi API key)

1. Buka [Access Controls](https://login.tailscale.com/admin/acls).
2. Salin kebijakan lama ke cadangan.
3. Tempel isi `docs/tailnet-policy.hujson`, lalu Save.
4. Baru setelah itu pasang tag di halaman Machines: `komputerbox10` → `tag:compute`, VPS Windows → `tag:vps`. Jangan menag perangkat owner. Jangan menag ulang `grokbot-box` kecuali owner meminta secara eksplisit.

### 8.2 Menambah node compute baru (Linux, systemd)

Konfirmasi dulu ke owner: nama (`GrokboxN` atau `komputerboxN`), OS, dan bahwa node itu boleh gabung.

1. Pastikan ACL sudah diterapkan (bagian 8.1).
2. Minta atau buat **reusable auth key** yang sudah membawa `tag:compute`, dan matikan key expiry untuk node server. Jangan menulis nilai key ke repo, isu, PR, log, atau chat yang tersimpan.
3. Salin berkas token Ray dari head (`/home/box/.config/ray/auth_token` di `komputerbox10`) ke file sementara di node baru, mode `600`. Salin lewat tailnet, bukan lewat chat. Jangan `cat` isinya.
4. Di node baru, sebagai root, jalankan templat `/workspace/compute/node-bootstrap/bootstrap.sh`:

```bash
export NODE_NAME=Grokbox1            # nama yang sudah disetujui owner
export TS_AUTHKEY=...                # dari secret, jangan ditulis ke file
export RAY_HEAD=100.116.213.30:6379
export RAY_AUTH_TOKEN_FILE=/path/ke/salinan-token
bash bootstrap.sh
```

5. Cek: `tailscale status`, `tailscale ip -4`, `systemctl status ray-worker`, Funnel tetap mati (`tailscale funnel reset` aman dipanggil). Di head: `RAY_AUTH_MODE=token RAY_AUTH_TOKEN_PATH=/home/box/.config/ray/auth_token ray status`.
6. Versi Python dan Ray harus sama dengan head (Python 3.13, Ray 2.60.0).
7. Node Windows (misalnya PC rumah ber-GPU) **tidak** memakai bootstrap systemd ini; siapkan installer terpisah setelah OS-nya disetujui owner.

Node baru yang sudah gabung akan muncul di dashboard (setelah heartbeat hidup) tanpa di-hardcode di dokumen ini. Cukup ikuti templat; jangan hardcode hostname baru ke skrip bersama.

## 9. Arah DePIN

DePIN hanya memakai kapasitas sisa, dan bisa dikunci atau dikurangi kapan saja agar prioritas di bagian 4 tetap terjaga. Login provider yang harus menetap (misalnya Akash nanti) boleh di VPS; hitungannya tetap di node compute.

Arah yang realistis dengan node yang ada sekarang:

- **Grass** atau **Mysterium**: bandwidth, cocok untuk node rumahan di belakang NAT, bisa dijeda. Grass biasanya hanya membayar IP residensial, jadi bukan untuk VPS atau `komputerbox10`.
- **Golem**: compute di node Linux, dengan batas core dan RAM yang bisa diatur agar QT tetap punya ruang. Cocok untuk Grokbox Linux berikutnya, bukan untuk head Ray yang sekarang.
- **Salad**: lebih cocok jika node berikutnya adalah PC Windows ber-GPU.

Ditunda dulu:

- **Akash** dan jaringan storage (Filecoin, Arweave, dan sejenisnya): butuh IP publik, port terbuka, dan/atau nyala 24/7, plus sering butuh disk/RAM besar. Belum cocok untuk node kita yang sekarang.

Langkah DePIN pertama yang masuk akal menunggu node rumahan atau Linux 24/7 pertama gabung. Jangan memasang klien DePIN di VPS, dan jangan memakan jatah aduhkerja atau QT.

## 10. Aturan Wajib bagi Agent

- Funnel tetap mati.
- Jangan menulis auth key Tailscale, token Ray, kata sandi SSH, token GitHub, atau rahasia lain ke repo, isu, PR, log, atau chat yang tersimpan. Berkas token mode `600` dan tidak di-commit.
- Jangan menyentuh `grokbot-box`.
- Perubahan di VPS (jaringan, layanan produksi, restart, exit node, antrean, dashboard) butuh izin owner. Cek aduhkerja sebelum dan sesudah perubahan yang disetujui.
- Jangan push ke `main`/`master` dan jangan menggabungkan PR. Untuk quantitative-trading, **CHIEF adalah satu-satunya merger**.
- Konfirmasi ke owner sebelum membuat node tailnet baru, membuat auth key baru, atau mengganti nama node lama.
- Jangan membiarkan pemakaian node mencapai 100%.
- Dokumen umum ini harus tetap identik di semua repo. Jika diubah, ubah di semua repo pada PR yang sama nilainya.

## 11. Dokumentasi per Repo

Setiap repo punya kasus berbeda, jadi detailnya dipisah dari dokumen umum ini.

Saat agent membuka sebuah repo:

1. Cek apakah sudah ada dokumen Tailscale khusus repo tersebut (default: `docs/TAILSCALE_REPO.md`).
2. **Jika sudah ada**, baca dan ikuti.
3. **Jika belum ada**, buat satu dokumen baru dengan nama di atas, isi sesuai kebutuhan repo itu, tanpa menyalin ulang seluruh aturan umum.

Template minimal dokumen per repo:

```markdown
# Tailscale: <nama-repo>

> Mengikuti aturan umum di TAILSCALE.md

## Node yang dipakai
- (peran repo ini di VPS, komputerbox, Grokbox; jangan meniru peran repo lain)

## Framework komputasi
- (Ray di node, antrean di VPS, atau mengapa repo ini tidak memakai keduanya)

## Prioritas
- (bagaimana kebijakan prioritas umum berlaku di repo ini)

## Ketersediaan node
- (service apa yang harus hidup terus, heartbeat/dashboard bila sudah ada alamatnya)

## Cara menjalankan / deploy
- (perintah, path kerja; SSH OpenSSH atau Tailscale SSH)

## Data dan storage
- (lokasi data, apa yang diambil lewat VPS, apa yang tidak boleh di VPS)

## Catatan khusus
- (port, Funnel, batasan, hal yang perlu dikonfirmasi)
```
