# Tailscale: Arsitektur Jaringan dan Komputasi Terdistribusi

> **Catatan untuk agent:** Dokumen ini bersifat **umum** dan berlaku untuk semua repo, termasuk repo baru.
> Jangan menaruh konfigurasi yang hanya berlaku di satu repo di sini. Lihat [Dokumentasi per Repo](#11-dokumentasi-per-repo).
> Dokumen ini sengaja cukup lengkap supaya agent di akun Grok lain bisa bekerja sendiri: menambah node, memasang tag, dan mengikuti aturan yang sama, tanpa menunggu instruksi ulang.

Dokumen ini mendefinisikan topologi Tailscale, pembagian peran, prioritas compute, dan cara bergabung ke kluster. Isi berkas ini **harus identik** di semua repo. Fakta per repo ada di `docs/TAILSCALE_REPO.md`.

Diperbarui 16 November 2026, 00.48 WIB.

## 1. Topologi Jaringan dan Peran Node

Tailnet: MagicDNS `tail7d94e8.ts.net`. Skala awal masih kecil, tetapi desainnya harus mudah ditambah node baru.

| Node | IP Tailscale | Tag | Peran |
|------|----------------|-----|-------|
| VPS Windows `WIN-T65VC2J9G31` | `100.103.231.61` | `tag:vps` (sudah dipasang; key expiry dimatikan) | **Koordinator saja.** Antrean Redis, dashboard, exit node, situs aduhkerja, live/paper QT, login. Bukan mesin hitungan berat. |
| `komputerbox10` | `100.116.213.30` | `tag:compute` (sudah dipasang; key expiry dimatikan) | Node compute pertama (komputer Grok Bot). Ray lokal + heartbeat + worker antrean. Bukan head Ray default. |
| `komputerboxN` berikutnya | — | `tag:compute` | Komputer Grok Bot tambahan. Konfirmasi nomor `N` ke owner sebelum join. |
| `GrokboxN` (rencana) | — | `tag:compute` | Linux VPS/KVM 24/7 dengan systemd. Belum ada. Konfirmasi nama ke owner sebelum join. |
| `grokbot-box` | `100.107.153.80` | — | Nama lama. **Jangan disentuh, diganti namanya, atau dicabut** tanpa perintah eksplisit owner. |
| Perangkat owner (HP, laptop) | — | tanpa tag | Akses penuh milik owner. Jangan menag-nya. |

### 1.1 VPS adalah koordinator, bukan mesin hitungan

VPS Windows hanya mengerjakan hal yang memang harus tinggal di mesin produksi:

- antrean job Redis (layanan **ComputeQueue**, `100.103.231.61:6379`) dan **pembagian data**: node mengambil data job dan input lewat VPS
- dashboard node (layanan **ComputeDashboard**, `http://100.103.231.61:8787/`) dan agen heartbeat VPS (layanan **ComputeNodeAgent**)
- pemanggil wake (layanan **ComputeWakeCaller**, aktif sejak 00.22 WIB, 16 November 2026): memantau heartbeat node dan memicu webhook bot watchdog
- website aduhkerja
- quantitative-trading **live dan paper** (butuh login broker / MT5)
- tempat login yang tidak bisa dipindah, misalnya login provider Akash di masa depan
- exit node (sudah diiklankan dan disetujui; dipakai perangkat owner bila perlu, **bukan** oleh komputerbox)

VPS **tidak** dipakai untuk hitungan berat, storage terdistribusi, atau bandwidth DePIN. Jangan menaruh backtest, training, riset berat, atau penyimpanan hasil besar di VPS. Data aplikasi aduhkerja tetap di Supabase, bukan di storage node.

### 1.2 komputerbox dan Grokbox mengerjakan compute, bandwidth, dan storage

Node `tag:compute` mengerjakan hitungan, bandwidth, dan storage. Contoh: backtest, training, riset, dan (nanti) kapasitas sisa untuk DePIN. Hasil berat tidak disimpan permanen di VPS.

### 1.3 Exit node dan subnet router

**Exit node sudah aktif.** VPS mengiklankannya, dan kebijakan ACL memuat `autoApprovers.exitNode = ["tag:vps"]`. Owner (dan anggota tailnet) boleh memakai internet lewat VPS, misalnya untuk IP tetap / whitelist broker. Exit node memakai bandwidth VPS, jadi **jangan dijadikan default semua perangkat**. Node `komputerbox` **tidak** memakai exit node (`tailscale-up.sh` tidak memasang `--exit-node`).

**Subnet router tidak dipasang.** Jangan mengiklankan subnet kecuali nanti ada perangkat LAN di VPS yang benar-benar perlu diakses dan tidak bisa dipasangi Tailscale. Perubahan jaringan di VPS tetap butuh izin owner; cek aduhkerja sebelum dan sesudah perubahan.

### 1.4 Spek komputerbox

Diukur di `komputerbox10` pada 16 November 2026. Catatan lengkap: [`docs/BENCHMARK-komputerbox.md`](docs/BENCHMARK-komputerbox.md). Node baru mungkin berbeda, jadi ulangi benchmark-nya.

- **CPU:** Xeon generasi ke-5 (Emerald Rapids), 8 vCPU tanpa SMT, turbo sekitar 3,9 GHz. 7-Zip: 1 thread **6.642** MIPS, 8 thread **57.130** MIPS. Setara PC kelas **Core i5-13400 / Ryzen 5 7600**.
- **RAM:** 15 GiB, bandwidth sekitar 80–95 GB/s, setara DDR5-5600 dual-channel.
- **Disk:** 125 GB (sisa sekitar 100 GB), baca/tulis 2,9 / 2,3 GB/s, setara NVMe Gen3.
- **Lainnya:** tidak ada GPU; KVM tersedia.
- **Setara cloud:** AWS `c7i.2xlarge`, sekitar **$0,357/jam** atau **$261/bulan** (us-east-1, on-demand).

**Armada 30 node** sejenis (bukan satu mesin raksasa): total 240 vCPU, sekitar 450 GiB RAM, dan 3,75 TB disk; setara cloud sekitar **$7.818/bulan**. Dengan cap pemakaian 85%, kapasitas terpakai sekitar **204 vCPU / 383 GiB**. Satu job tetap terbatas sekitar 15 GiB di satu mesin; RAM 30 node tidak bisa digabung.

## 2. Fitur Tailscale

**Aktif**
- **MagicDNS** di tailnet. Di komputer Grok Bot, Tailscale dijalankan dengan `--accept-dns=false`, jadi dari box pakai **IP Tailscale**, bukan nama `.ts.net`, kecuali dokumen per repo secara eksplisit memakai nama itu.
- **ACL + tag** `tag:compute` dan `tag:vps`. Kebijakan **sudah diterapkan**. Salinan tanpa rahasia: [`docs/tailnet-policy.hujson`](docs/tailnet-policy.hujson). Lihat [bagian 8](#8-tag-acl-dan-cara-menambah-node).
- **Tailscale SSH** di `komputerbox10` (`--ssh`): hanya owner, mode **check** dengan masa `12h`, user `box` / `root` / `autogroup:nonroot`. Kebijakan `ssh` ada di berkas ACL. Tailscale SSH tidak membangunkan box yang sedang tidur.
- **Exit node** di VPS (`tag:vps`), sudah disetujui (lihat bagian 1.3).

**Direkomendasikan (aktifkan sesuai jenis mesin)**
- **Tailscale SSH** untuk Linux VPS / Grokbox, bila disepakati, mengikuti kebijakan yang sama (owner, check 12h). Jangan mengandalkannya di VPS Windows: SSH ke mesin itu memakai OpenSSH biasa plus kata sandi, bukan Tailscale SSH.
- **Auth key / tagged key**: untuk menambah node baru. Tetap wajib konfirmasi ke owner sebelum membuat node atau auth key baru. Pakai reusable auth key yang sudah membawa `tag:compute`.

**Tidak digunakan**
- **Tailscale Funnel**: tetap mati. Jangan diaktifkan tanpa persetujuan eksplisit owner.
- **Connector Tailscale terkelola di Grok Bot**: hanya meneruskan HTTP(S). Jangan dipakai untuk SSH. Gejala jika dipaksa: HTTP 500 atau gagal membaca SSH protocol banner.
- **Subnet router**: tidak dipasang, lihat bagian 1.3.
- Exit node di komputerbox: tidak dipakai.
- Alarm chat saat node mati: **tidak dipasang** (keputusan owner). Status dilihat di dashboard node. Downtime komputerbox dicatat di `/home/box/logs/downtime.log` dan dilaporkan bot watchdog.

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

Penegakan di antrean: prioritas 0 (QT, kritis) dan 1 (normal) hanya diambil jika CPU < 85% dan RAM < 85%. Prioritas 2 (sisa, DePIN) hanya jika CPU < 60% dan RAM < 70%.

## 5. Ketersediaan Node

Idealnya setiap mesin selalu hidup dan selalu terhubung ke tailnet. Kenyataan per jenis mesin berbeda. Langkah systemd di [bagian 5.1](#51-linux-vps-dan-grokbox-systemd) hanya berlaku untuk **Linux VPS dan Grokbox**. Jangan menjalankannya di VPS Windows, dan jangan menganggapnya tersedia di komputer Grok Bot.

### 5.1 Linux VPS dan Grokbox (systemd)

Ini jalur node 24/7 yang benar-benar nyala sendiri setelah reboot. Saat men-setup mesin Linux VPS / Grokbox:

1. **Tailscale jalan otomatis saat boot:** `sudo systemctl enable --now tailscaled`
2. **Mesin tidak boleh sleep/suspend/hibernate:** `sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`. Untuk laptop: `HandleLidSwitch=ignore` di `/etc/systemd/logind.conf`, dan pastikan terhubung ke daya.
3. **Key tidak boleh kedaluwarsa** untuk node server: matikan key expiry di admin console setelah node di-tag, atau pakai tagged auth key.
4. **Gabung ke tailnet** dengan hostname yang sudah disetujui owner. Tag `tag:compute` dipasang lewat reusable auth key yang sudah membawa tag itu (lihat bagian 8). Flag `--ssh` hanya untuk Linux bila disepakati, bukan untuk VPS Windows. Funnel tetap mati.
5. **Proses kerja sebagai service systemd** (`Restart=always`): unit `cq-heartbeat` dan `cq-worker` dipasang bootstrap (default `RAY_MODE=queue`). Templat: `/workspace/compute/node-bootstrap/` di komputer Grok Bot (jangan men-commit secret).
6. Pastikan jaringan mesin tersambung otomatis setelah reboot atau putus.

### 5.2 VPS Windows

VPS Windows tidak memakai systemd. Autostart mengikuti layanan Windows (WinSW) dan tugas terjadwal yang sudah ada, termasuk **ComputeQueue**, **ComputeDashboard**, **ComputeNodeAgent**, dan **ComputeWakeCaller** (aktif sejak 00.22 WIB, 16 November 2026; BelowNormal, sekitar 20 MB RAM, autostart delayed, restart otomatis). Semuanya autostart delayed, restart otomatis; antrean dan pemanggil wake memakai prioritas proses BelowNormal. Jangan menambahkan unit systemd. SSH tetap OpenSSH biasa plus kata sandi, bukan Tailscale SSH. **Restart mesin VPS dan perubahan di VPS hanya boleh setelah izin owner.**

### 5.3 Komputer Grok Bot (komputerbox)

Komputer Grok Bot **tidak punya systemd**. Rantai boot adalah `/tini` → `/pod-daemon` (keduanya biner platform). `systemctl` tidak tersedia. **Tidak ada hook boot yang bisa dikontrol.**

Tailscale, Ray, heartbeat, dan worker antrean di komputer ini dijalankan lewat skrip. Menjaga box tetap hidup memakai **empat lapisan**:

1. **Watchdog loop di dalam box**, setiap **30 detik**. Pintu masuk: `/home/box/bin/compute-start.sh` (memegang `flock`, lalu menyalakan `/home/box/bin/compute-watchdog.sh --loop 30`). Aman dipanggil berkali-kali. Setiap putaran menyalakan ulang Tailscale, heartbeat, worker, dan Ray lokal bila perlu; head Ray bersama hanya jika `CQ_RAY_HEAD=1`. **Auto re-auth:** watchdog (lewat `/home/box/bin/tailscale-up.sh`) mengulang `tailscale up` dengan reusable auth key tersimpan jika status `NeedsLogin` / `NeedsMachineAuth` atau key kedaluwarsa. Key expiry di node yang sudah di-tag sudah dimatikan; re-auth tetap sebagai cadangan. Auth key tidak pernah dicetak. Ada pembatas laju re-auth. Log: `/home/box/logs/compute-watchdog.log`. Loop ini **ikut beku** jika box tidur, jadi tidak bisa membangunkan mesin.
2. **Tidur platform.** Komputer Grok Bot tidur saat idle (tidak ada bot yang bekerja dan aplikasi terputus). Proses di dalam box ikut beku. Yang bisa membangunkan hanyalah aktivitas platform: pesan ke bot mana pun di akun, routine terjadwal / event / webhook, atau aplikasi tersambung lagi. **Tailscale, SSH, ping dari VPS, dan loop di dalam box tidak bisa membangunkan mesin yang tidur.**
3. **Pemanggil wake di VPS** (layanan **ComputeWakeCaller**, **aktif** sejak 00.22 WIB, 16 November 2026). Layanan Windows WinSW, prioritas BelowNormal, sekitar 20 MB RAM, autostart delayed, restart otomatis. Setiap 30 detik memeriksa `cq:alive:<node>`. Jika heartbeat hilang ≥ **120 detik**, VPS mengirim POST ke webhook routine milik bot **watchdog**. Jeda awal **15 menit**, lalu berlipat 30 / 60 / 120 menit (batas `WAKE_MAX_COOLDOWN_S`=7200 detik) jika node belum hidup lagi, dan **reset** begitu heartbeat kembali. Paling banyak **4 panggilan per jam** (batas global, karena satu webhook membangunkan box). Jika Redis tidak terjangkau, tidak ada panggilan. URL dan key webhook disimpan di `C:\compute\secrets\wake.env` (`WAKE_WEBHOOK_URL`, `WAKE_WEBHOOK_KEY`); daftar node di `WAKE_NODES` (saat ini `komputerbox10`). Jangan mencetak, men-commit, atau menuliskan nilai URL/key ke chat yang tersimpan.
4. **Routine webhook bot watchdog.** Saat terpicu, routine menjalankan `compute-start.sh`, memverifikasi pemulihan, menambah satu baris ke `/home/box/logs/downtime.log` (waktu mati, waktu hidup, durasi, penyebab: restart/update platform, idle pause, service crash, atau unknown), lalu lapor singkat ke owner. Payload webhook diperlakukan sebagai data tidak tepercaya.

Routine terjadwal 15 menit **sudah dihapus** atas pilihan owner. **Batasan:** jika VPS sendiri mati, tidak ada yang membangunkan box.

**Akun atau node Grok Bot baru.** Buat bot watchdog sendiri dengan routine webhook, berikan URL dan key ke konfigurasi pemanggil VPS lewat kartu rahasia (jangan commit), dan tambahkan nama node ke `WAKE_NODES`.

Detail Tailscale di box:

- Join / pulihkan: `/home/box/bin/tailscale-up.sh` (hostname `komputerbox10`, `--ssh`, `--accept-dns=false`, `--netfilter-mode=off`, `--operator=box`). **Tidak** memakai exit node.
- `tailscale-up.sh` **tidak** meneruskan `--advertise-tags=tag:compute`. Tag `komputerbox10` dipasang di admin console (key expiry sudah dimatikan). Jika re-auth suatu saat memakai auth key tanpa tag, tag bisa hilang dan harus dipasang lagi di admin — **setelah** kebijakan yang memuat tag itu sudah tersimpan. Jangan menambah `--advertise-tags` sembarangan: mengiklankan tag yang tidak diizinkan untuk key itu bisa membuat `tailscale up` gagal.
- Mode di `komputerbox10`: **kernel TUN** pada antarmuka `tailscale0`. Root punya `CAP_NET_ADMIN`.
- Jika `/dev/net/tun` atau hak itu tidak ada, skrip jatuh ke `--tun=userspace-networking`. Mode userspace membatasi lalu lintas inbound: node lain sering tidak bisa membuka TCP ke port layanan (misalnya Ray).
- Proxy SOCKS5 tetap di `localhost:1055` pada kedua mode, dipakai SSH ke VPS Windows.
- Tipe NAT box adalah `MappingVariesByDestIP`, jadi koneksi ke peer cenderung lewat relay DERP (sekitar 200 ms), meskipun mode sudah TUN.
- Heartbeat dan worker antrean di box: `/home/box/compute/{heartbeat,worker}.py`, dijaga `/home/box/bin/compute-services.sh`. Setelan tanpa rahasia: `/home/box/.config/compute/node.env`. Log: `/home/box/logs/cq-*.log`. Sebelum menyalakan worker lagi, `compute-services.sh` membersihkan agen Ray yatim (`ray::DashboardAgent` / `RuntimeEnvAgent`, plus GCS/raylet sesi lokal selain port 6379). Head bersama (GCS 6379) tidak disentuh.

**Autostart tanpa agent atau shell interaktif tidak dijamin oleh platform.** Temuan 15–16 November 2026 (WIB) di `komputerbox10`:

- Tidak ada crontab, dan tidak ada hook pada rantai `/tini` → `/pod-daemon` yang bisa dijamin bertahan antar sesi.
- Ada hook shell interaktif di `/etc/bash.bashrc`, `/home/box/.bashrc`, dan `/etc/profile.d/compute-autostart.sh`. Hook itu hanya jalan ketika shell interaktif dimulai.
- Setelah box di-restart, di-pause, atau tidur di luar kendali, stack baru hidup lagi saat ada shell interaktif, saat agent menjalankan `compute-start.sh`, atau saat pemanggil wake VPS memicu webhook bot watchdog (target: sekitar 2 menit setelah heartbeat hilang, dengan jeda awal 15 menit yang berlipat jika belum hidup).

Karena itu, node yang **wajib** nyala otomatis 24 jam tanpa bergantung pada VPS harus berupa **Linux VPS dengan systemd**, mengikuti bagian 5.1. `komputerbox10` adalah tenaga tambahan yang bisa cepat dipulihkan, bukan satu-satunya tumpuan ketersediaan.

### 5.4 Heartbeat dan dashboard node

Sudah hidup:

- Setiap node mengirim heartbeat ke VPS **setiap 5 detik** (`cq:alive:<node>`, TTL 30 detik). Jika sebuah node tidak lapor selama **30 detik**, dashboard menandainya offline. VPS juga mem-`ping` tiap node lewat Tailscale **setiap 30 detik** (menjaga jalur WireGuard; ping ini **tidak** membangunkan box yang tidur). Hasil ping disimpan di `cq:node:<node>` (`ping_ok`, `ping_ms`, `ping_via`, `ping_at_ms`, `ping_fail_streak`) dan terlihat di kolom dashboard **Ping dari VPS**. Log: `C:\compute\logs\ComputeNodeAgent.out.log`. Sukses dinilai dari baris `pong from`, bukan exit code: `tailscale ping` bisa exit 1 lewat DERP meskipun pong diterima.
- Jika node mati, lease job-nya kedaluwarsa dan reaper (di setiap klaim worker, plus dashboard VPS tiap 10 detik) mengembalikan job ke antrean untuk diambil node lain. Lihat [bagian 6.2](#62-antrean-job-di-vps). Job yang memanggil `checkpoint()` bisa dilanjutkan, lihat [bagian 6.3](#63-checkpoint-job-panjang). Lease yang habis karena box tidur juga dihitung sebagai percobaan; setelah `max_attempts` (default 3) job masuk `cq:dead`, jadi job panjang perlu `max_attempts` lebih besar plus checkpoint.
- **Dashboard:** `http://100.103.231.61:8787/` (hanya tailnet, bukan internet). Di VPS juga `http://127.0.0.1:8787/`. Dilayani layanan Windows **ComputeDashboard** dan **ComputeNodeAgent**. Shortcut desktop **Compute Nodes** ada di desktop Publik VPS (`C:\Users\Public\Desktop\Compute Nodes.url`) dan membuka alamat loopback itu.
- Isi dashboard: node yang aktif atau mati, plus CPU, RAM, storage, bandwidth, dan kolom **Ping dari VPS** (ms, jalur, umur) per node (termasuk VPS) serta totalnya. Jika layanan restart (±2 detik), halaman tetap menampilkan data terakhir, menulis "Menyambung ulang…", dan mencoba lagi tiap 2 detik.
- **Tidak ada alarm chat** saat node mati (keputusan owner). Bot watchdog tetap lapor ke owner setiap kali webhook wake berjalan, dan mencatat ke `downtime.log`.

Firewall VPS hanya membolehkan TCP 6379 dan 8787 dari CGNAT Tailscale `100.64.0.0/10`.

### 5.5 Verifikasi setelah setup

Agent wajib menjalankan dan melaporkan hasilnya ke owner:

- `tailscale status`: node muncul, berstatus terhubung, dan tag-nya benar (`tag:compute` atau `tag:vps`).
- `tailscale ping <nama-atau-ip-node>`: balasan sukses dari node lain (boleh lewat DERP).
- Node baru muncul di `http://100.103.231.61:8787/` dalam beberapa detik.
- `systemctl is-enabled tailscaled` (dan `cq-heartbeat`, `cq-worker`): hasilnya `enabled` — **hanya** di Linux VPS / Grokbox. Jangan dijalankan di VPS Windows atau komputer Grok Bot.
- Uji reboot hanya pada mesin yang boleh di-reboot: setelah restart, node kembali online sendiri. Jangan merestart VPS Windows tanpa perintah owner.

**Jika node terlihat offline:**

1. Cek mesin menyala dan punya internet. Cek dashboard `http://100.103.231.61:8787/`.
2. Linux VPS / Grokbox: `sudo systemctl status tailscaled cq-heartbeat cq-worker`, jalankan ulang bila mati. Komputer Grok Bot: jika box sudah bangun, jalankan `/home/box/bin/compute-start.sh` (atau `/home/box/bin/tailscale-up.sh` jika hanya Tailscale yang perlu dipulihkan). Jika box tidur, tunggu pemanggil wake VPS (sekitar 2 menit setelah heartbeat hilang) atau kirim pesan ke bot agar platform membangunkan mesin. Jangan mengandalkan SSH atau `tailscale ping` untuk membangunkan box.
3. Cek di admin console apakah ada "Key expired" atau tag hilang. Key expiry `komputerbox10` dan VPS sudah dimatikan; node baru perlu dimatikan expiry-nya setelah di-tag. Re-auth di box: `tailscale-up.sh` (auth key dari owner, jangan dicetak).
4. Jika tidak ada akses lagi, SSH ke VPS (OpenSSH biasa, bukan connector terkelola) lalu `tailscale ping`, dan beri tahu owner bila butuh akses fisik atau lewat panel penyedia mesin.

## 6. Framework Komputasi Terdistribusi

Pola yang sudah diputuskan owner, dan yang harus diikuti repo baru kecuali ada keputusan baru:

- **Di dalam tiap node:** Ray **lokal**. Default: `CQ_RAY_ADDRESS=local` / `RAY_MODE=queue`, dan `CQ_RAY_HEAD=0`. Node mengambil job dari antrean VPS dan mengerjakannya dengan Ray miliknya sendiri. Tidak ada node yang bergantung pada head di `komputerbox10`.
- **Antar node:** antrean job Redis di VPS. Pembagian kerja antar mesin diatur antrean, bukan cluster Ray. Data dan input job diambil lewat VPS (pembagian data), hitungannya tetap di komputerbox / Grokbox.
- **Mode cluster (opt-in):** hanya untuk job raksasa yang perlu dipecah ke banyak node sekaligus. Setel `CQ_RAY_HEAD=1` agar watchdog menyalakan head bersama di `100.116.213.30:6379` (token auth), dan `CQ_RAY_ADDRESS=100.116.213.30:6379` (atau `RAY_MODE=cluster` di bootstrap). `ray-head-up.sh` hanya menghentikan sesi head lama (GCS 6379); jangan `ray stop --force` (itu ikut membunuh Ray lokal worker).

### 6.1 Ray

- Versi acuan: Ray 2.60.0, Python 3.13. Worker yang join head bersama (`RAY_MODE=cluster`) **harus** memakai versi Python dan Ray yang sama dengan head.
- Default tiap node: Ray lokal, hanya `127.0.0.1`, dibatasi `CQ_RAY_CPUS`, `CQ_RAY_MEMORY_MB`, `CQ_RAY_OBJECT_STORE_MB`. Di `komputerbox10`: 6 CPU, memori 8 GiB, object store 2 GiB (sisa untuk proses lain, dan agar pemakaian tidak 100%). Setelan: `/home/box/.config/compute/node.env` (tanpa rahasia).
- Head bersama (opt-in): `100.116.213.30:6379` (`komputerbox10`). Klien dari node lain: `ray://100.116.213.30:10001`.
- Dashboard Ray: hanya `127.0.0.1:8265`, tidak diekspos ke tailnet. Jangan tertukar dengan dashboard node di `:8787`.
- Port tetap (mode cluster): GCS 6379, client 10001, node-manager 6380, object-manager 6381, dashboard-agent 52365, metrics 8090, worker 10002–10200. Port 6379 di **VPS** adalah Redis antrean, bukan Ray.
- **Token auth wajib untuk head bersama / mode cluster.** `RAY_AUTH_MODE=token`. Token disimpan di berkas mode `600` (di head: `/home/box/.config/ray/auth_token`; di node systemd mode cluster: `/etc/ray/auth_token`). Jangan `cat` isinya, jangan menulisnya ke chat, PR, log, atau repo, dan jangan men-commit berkas itu. Koneksi tanpa token atau dengan token salah harus ditolak. Salin token antar node lewat tailnet (misalnya `scp`), bukan lewat chat. Mode `queue` (default) tidak perlu menyalin token Ray.
- Karena default sudah Ray per node, kluster tidak bergantung pada `komputerbox10` yang tidak dijamin 24/7. Jika nanti butuh head bersama yang 24/7, pindahkan ke Grokbox Linux pertama (izin owner).
- Latensi antar-node sering lewat DERP (~200 ms). Cocok untuk job yang lumayan besar per potong (misalnya backtest per set parameter), bukan tugas yang sangat chatty.

### 6.2 Antrean job di VPS

Sudah hidup. Rincian pemakaian: [`docs/QUEUE.md`](docs/QUEUE.md). Salinan kerja di komputer Grok Bot: `/workspace/compute/QUEUE.md`.

- Redis 5.0.14.1 (port Windows) di `C:\compute\redis`, layanan **ComputeQueue**: `100.103.231.61:6379` dan `127.0.0.1:6379`. Password ada di `queue.env` (di box: `/home/box/.config/compute/queue.env` mode `600`; di VPS: `C:\compute\secrets\`, hanya SYSTEM + Administrators). **Jangan dicetak atau di-commit.** Batas memori 384 MB `noeviction`, AOF everysec, prioritas proses BelowNormal, autostart delayed + restart otomatis (WinSW).
- Klaim job = **lease 60 detik** (`cq:leased`). Worker memperpanjang tiap 15 detik. Jika node mati, lease kedaluwarsa dan reaper mengembalikan job ke `cq:pending` (`attempts+1`; setelah `max_attempts`, default 3, → `cq:dead`). Hasil worker dengan lease basi ditolak. Lease yang habis karena box tidur juga dihitung sebagai percobaan, jadi job panjang di node yang sering tidur harus di-submit dengan `max_attempts` lebih besar dan memakai `checkpoint()`.
- Worker tetap jalan jika terjadi error selain error jaringan (dicatat, koneksi ditutup, coba lagi 5 detik; lease job yang sedang jalan tetap diperpanjang).
- Prioritas: **0** kritis (QT), **1** normal, **2** sisa (DePIN). Ambang pengambilan: prioritas 0–1 hanya jika CPU < 85% dan RAM < 85%; prioritas 2 hanya jika CPU < 60% dan RAM < 70%.
- Jangan menjalankan antrean di `komputerbox10` sebagai lokasi tetap; itu membuat antrean ikut mati saat box tidur.

Dari Python di node tailnet (box; di node bootstrap, modulnya di `/opt/compute` dan env di `/etc/compute/queue.env`):

```python
import sys; sys.path.insert(0, "/home/box/compute")
from cq import Queue, PRIO_CRITICAL, PRIO_NORMAL, PRIO_LEFTOVER
q = Queue.from_env()  # baca queue.env; jangan mencetak isinya
jid = q.submit("cq_tasks:square", [7], priority=PRIO_CRITICAL, num_cpus=1, timeout_s=600)
print(q.wait(jid))
print(q.stats())
```

Fungsi = `"modul:fungsi"` yang bisa di-import di worker. Modul harus sama dengan prefix di `CQ_ALLOWED_PREFIXES` atau submodulnya (`cq_tasks`, `cq_tasks.x`); nama yang hanya berawalan sama (`cq_tasks_evil`) ditolak. Default `cq_tasks`. Untuk backtest QT, tambahkan prefiks yang sesuai plus `CQ_PYTHONPATH`. Uji: `/workspace/compute/kill_test.sh heartbeat|worker|tailscale` (jangan `ray stop --force`); `python3 /workspace/compute/tests/test_worker_policy.py`; `/workspace/compute/tests/e2e_queue.py [--kill-at N]`; `/workspace/compute/tests/e2e_gating.py`.

Slurm belum dipakai. Pertimbangkan nanti bila jumlah node dan antrean sudah besar (~10 node atau antrean mulai berantakan).

### 6.3 Checkpoint job panjang

Job yang bisa memakan waktu lama harus memanggil `checkpoint()` sendiri. Kalau node mati dan job di-requeue, percobaan berikutnya melanjutkan dari state tersimpan, bukan mengulang dari awal. Worker menghapus checkpoint setelah job sukses. Contoh: `cq_tasks:resumable_count`.

```python
from cq_checkpoint import checkpoint
ck = checkpoint()                      # job id dari CQ_JOB_ID (diset worker)
st = ck.load() or {"step": 0}
for step in range(st["step"], N):
    ...
    ck.save({"step": step + 1})
```

Backend `CQ_CHECKPOINT_BACKEND=auto`:

- R2 (API S3, SigV4, tanpa boto3) otomatis dipakai jika variabel `R2_ACCOUNT_ID` (atau `R2_ENDPOINT`), `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, dan `R2_BUCKET` ada di env atau di berkas `CQ_CHECKPOINT_ENV_FILE` (di `komputerbox10`: `/home/box/.config/compute/r2.env`, mode `600`; di node bootstrap: `/etc/compute/r2.env`). Objek: `cq-checkpoints/<job_id>.json`.
- Jika berkas itu belum ada, checkpoint tersimpan di disk lokal (`/home/box/compute-checkpoints`, atau `/var/lib/compute/checkpoints` di node systemd). Checkpoint lokal hanya bisa dilanjutkan di node yang sama.

Jangan menulis nilai variabel R2 ke repo, PR, log, atau chat. Berkas `r2.env` tidak di-commit. Ini terpisah dari bucket R2 artefak QT yang hanya dioperasikan CHIEF di VPS (lihat dokumen per repo).

## 7. Data, Storage, dan Bandwidth

- VPS adalah **titik pembagian data**, bukan gudang hasil berat. Node mengambil input job lewat VPS, mengerjakannya di node compute, dan menyimpan hasil jangka panjang di tempat yang ditentukan dokumen per repo (bukan disk VPS untuk artefak besar).
- aduhkerja: data aplikasi di **Supabase**. Jangan memasukkan storage aduhkerja ke skema storage terdistribusi di komputerbox.
- quantitative-trading: bucket R2 artefak/hasil hanya dioperasikan CHIEF di VPS. Checkpoint job (`cq_checkpoint`) boleh memakai `r2.env` di node (mode `600`) begitu kredensialnya ada; jangan men-commit atau mencetak isinya.
- Object store Ray hanya untuk data antar-task, bukan penyimpanan jangka panjang.
- Storage dan bandwidth komputerbox boleh dipakai workload yang memang untuk itu (termasuk DePIN nanti), dengan tetap mengikuti [kebijakan prioritas](#4-kebijakan-prioritas-compute) dan tidak sampai 100%.

Pilihan konkret per repo ditulis di `docs/TAILSCALE_REPO.md`, bukan di sini.

## 8. Tag, ACL, dan Cara Menambah Node

Tag yang dipakai:

- `tag:compute` — komputerbox, Grokbox, dan node hitungan lain. Sudah dipasang di `komputerbox10`.
- `tag:vps` — VPS Windows koordinator. Sudah dipasang di VPS. Key expiry di kedua node itu sudah dimatikan.
- perangkat owner tetap tanpa tag

Kebijakan **sudah diterapkan**. Salinan tanpa rahasia: [`docs/tailnet-policy.hujson`](docs/tailnet-policy.hujson). Salinan kerja di komputer Grok Bot: `/workspace/compute/tailnet-policy.hujson`. Auth key node **tidak bisa** menulis ACL; perubahan kebijakan butuh admin console atau API key Tailscale yang diberikan owner.

Isi kebijakan secara ringkas:

- Hanya owner yang boleh memasang `tag:compute` dan `tag:vps`.
- Owner (dan admin) tetap punya akses penuh. Owner dan anggota boleh memakai exit node (`autogroup:internet`).
- `tag:compute` boleh saling menjangkau port Ray (plus ICMP).
- `tag:compute` (dan IP `komputerbox10`) boleh menjangkau VPS: SSH 22, RDP 3389, Redis 6379, dashboard 8787, rentang 8000–8099, plus ICMP.
- VPS boleh menjangkau node compute untuk ping, SSH, dan port Ray.
- Tailscale SSH: owner → `tag:compute`, mode check 12 jam.
- Funnel tidak diizinkan (tidak ada atribut `funnel`). `autoApprovers.exitNode` = `tag:vps`.

**Wajib:** simpan kebijakan yang memuat tag itu **sebelum** menag node baru. Setelah perangkat di-tag, identitas usernya hilang dan hanya tag yang berlaku. Menag lebih dulu pada kebijakan yang belum mengenal tag itu, atau re-auth dengan key tanpa tag, bisa memutus akses (termasuk SSH dari box ke VPS).

### 8.1 Mengubah ACL atau menag node

1. Buka [Access Controls](https://login.tailscale.com/admin/acls) (atau pakai API key yang diberikan owner).
2. Salin kebijakan lama ke cadangan (di box, cadangan lama ada di `/home/box/backups/tailscale/`).
3. Tempel atau terapkan kebijakan yang sudah memuat tag dan grant yang dibutuhkan, lalu Save.
4. **Baru setelah itu** pasang tag di halaman Machines, atau join node baru dengan reusable auth key yang sudah membawa `tag:compute`. Jangan menag perangkat owner. Jangan menag ulang `grokbot-box` kecuali owner meminta secara eksplisit.
5. Untuk node server, matikan key expiry setelah tag terpasang.

### 8.2 Menambah node compute baru (Linux, systemd)

Konfirmasi dulu ke owner: nama (`GrokboxN` atau `komputerboxN`), OS, dan bahwa node itu boleh gabung. Default bootstrap adalah `RAY_MODE=queue` (Ray lokal + `cq-heartbeat` + `cq-worker`). `RAY_MODE=cluster` hanya opt-in untuk join head bersama.

1. Pastikan kebijakan ACL yang memuat `tag:compute` sudah tersimpan (sudah berlaku sekarang).
2. Minta atau buat **reusable auth key** yang sudah membawa `tag:compute`, dan matikan key expiry untuk node server. Jangan menulis nilai key ke repo, isu, PR, log, atau chat yang tersimpan. Bootstrap secara default menambahkan `--advertise-tags=tag:compute` dan Tailscale SSH (`--ssh`). Ubah dengan `TS_TAGS=...` atau `TS_SSH=0`. Kebijakan ACL yang memuat tag itu harus sudah tersimpan (langkah 1). Ini berbeda dari `tailscale-up.sh` di komputer Grok Bot, yang **tidak** meneruskan `--advertise-tags`.
3. Salin `/home/box/.config/compute/queue.env` dari `komputerbox10` ke file sementara mode `600` di node baru (lewat tailnet, jangan `cat`/chat/commit). `export CQ_ENV_SRC=/path/ke/salinan`.
4. Opsional: jika checkpoint harus bisa dilanjutkan di node mana pun, salin `r2.env` (mode `600`) dan `export R2_ENV_SRC=/path/ke/salinan`. Tanpa itu, checkpoint tetap di disk lokal node itu.
5. Jika `RAY_MODE=cluster`, salin juga berkas token Ray dari head (`/home/box/.config/ray/auth_token`) ke file sementara mode `600`. Head bersama hanya hidup jika `CQ_RAY_HEAD=1` di `komputerbox10`.
6. Di node baru, sebagai root, jalankan templat `/workspace/compute/node-bootstrap/bootstrap.sh`:

```bash
export NODE_NAME=Grokbox1            # nama yang sudah disetujui owner
export TS_AUTHKEY=...                # dari secret, jangan ditulis ke file
export CQ_ENV_SRC=/path/ke/salinan-queue.env
export RAY_MODE=queue                # default; pakai cluster hanya jika join head
# default: Tailscale SSH nyala, tag:compute (--advertise-tags)
# export TS_SSH=0                     # matikan Tailscale SSH
# export TS_TAGS=tag:compute          # default; ganti hanya jika owner menyetujui tag lain
# opsional: export R2_ENV_SRC=/path/ke/salinan-r2.env
# jika cluster: export RAY_HEAD=100.116.213.30:6379 RAY_AUTH_TOKEN_FILE=/path/ke/salinan-token
bash bootstrap.sh
```

7. Cek: `tailscale status` (tag `tag:compute` terlihat), `systemctl status cq-heartbeat cq-worker`, Funnel tetap mati. Node muncul di `http://100.103.231.61:8787/`. Jika mode cluster: `systemctl status ray-worker`, dan di head `RAY_AUTH_MODE=token RAY_AUTH_TOKEN_PATH=/home/box/.config/ray/auth_token ray status`.
8. Versi Python dan Ray harus sama dengan acuan (Python 3.13, Ray 2.60.0), wajib jika join head.
9. Node Windows (misalnya PC rumah ber-GPU) **tidak** memakai bootstrap systemd ini; siapkan installer terpisah setelah OS-nya disetujui owner.

Node baru yang sudah gabung akan muncul di dashboard tanpa di-hardcode di dokumen ini. Cukup ikuti templat; jangan hardcode hostname baru ke skrip bersama. Jika node baru adalah komputer Grok Bot, ikuti juga [bagian 5.3](#53-komputer-grok-bot-komputerbox) (bot watchdog + webhook + `WAKE_NODES`).

## 9. Arah DePIN

DePIN hanya memakai kapasitas sisa, dan bisa dikunci atau dikurangi kapan saja agar prioritas di bagian 4 tetap terjaga. Di antrean, itu prioritas 2 (hanya diambil jika CPU < 60% dan RAM < 70%). Login provider yang harus menetap (misalnya Akash nanti) boleh di VPS; hitungannya tetap di node compute.

Arah yang realistis dengan node yang ada sekarang:

- **Grass** atau **Mysterium**: bandwidth, cocok untuk node rumahan di belakang NAT, bisa dijeda. Grass biasanya hanya membayar IP residensial, jadi bukan untuk VPS atau `komputerbox10`.
- **Golem**: compute di node Linux, dengan batas core dan RAM yang bisa diatur agar QT tetap punya ruang. Cocok untuk Grokbox Linux berikutnya, bukan langkah pertama di `komputerbox10`.
- **Salad**: lebih cocok jika node berikutnya adalah PC Windows ber-GPU.

Ditunda dulu:

- **Akash** dan jaringan storage (Filecoin, Arweave, dan sejenisnya): butuh IP publik, port terbuka, dan/atau nyala 24/7, plus sering butuh disk/RAM besar. Belum cocok untuk node kita yang sekarang.

Langkah DePIN pertama yang masuk akal menunggu node rumahan atau Linux 24/7 pertama gabung. Jangan memasang klien DePIN di VPS, dan jangan memakan jatah aduhkerja atau QT.

## 10. Aturan Wajib bagi Agent

- Funnel tetap mati.
- Jangan menulis auth key Tailscale, token Ray, password Redis / isi `queue.env`, isi `r2.env` / kredensial R2, kata sandi SSH, token GitHub, URL atau key webhook wake, atau rahasia lain ke repo, isu, PR, log, atau chat yang tersimpan. Berkas secret mode `600` dan tidak di-commit.
- Jangan men-commit `vps_ssh.py` atau skrip pembantu yang memuat kredensial.
- Jangan menyentuh `grokbot-box`.
- Perubahan di VPS (jaringan, layanan produksi, restart, exit node, antrean, dashboard, pemanggil wake) butuh izin owner. Cek aduhkerja sebelum dan sesudah perubahan yang disetujui.
- Jangan push ke `main`/`master` dan jangan menggabungkan PR. Untuk quantitative-trading, **CHIEF adalah satu-satunya merger**.
- Konfirmasi ke owner sebelum membuat node tailnet baru, membuat auth key baru, atau mengganti nama node lama.
- Simpan kebijakan ACL **sebelum** menag node baru.
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
- (Ray lokal di node, antrean di VPS, cluster opt-in, atau mengapa repo ini tidak memakai keduanya)

## Prioritas
- (bagaimana kebijakan prioritas umum berlaku di repo ini)

## Ketersediaan node
- (service apa yang harus hidup terus; dashboard http://100.103.231.61:8787/; webhook wake jika node itu komputer Grok Bot)

## Cara menjalankan / deploy
- (perintah, path kerja; SSH OpenSSH atau Tailscale SSH)

## Data dan storage
- (lokasi data, apa yang diambil lewat VPS, apa yang tidak boleh di VPS, checkpoint jika relevan)

## Catatan khusus
- (port, Funnel, batasan, hal yang perlu dikonfirmasi)
```
