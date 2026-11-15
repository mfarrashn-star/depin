# Tailscale: Arsitektur Jaringan dan Komputasi Terdistribusi

> **Catatan untuk agent:** Dokumen ini bersifat **umum** dan berlaku untuk semua repo, termasuk repo baru.
> Jangan menaruh konfigurasi yang hanya berlaku di satu repo di sini. Lihat [Dokumentasi per Repo](#11-dokumentasi-per-repo).
> Dokumen ini sengaja cukup lengkap supaya agent di akun Grok lain bisa bekerja sendiri: menambah node, memasang tag, dan mengikuti aturan yang sama, tanpa menunggu instruksi ulang.

Dokumen ini mendefinisikan topologi Tailscale, pembagian peran, prioritas compute, dan cara bergabung ke kluster. Isi berkas ini **harus identik** di semua repo. Fakta per repo ada di `docs/TAILSCALE_REPO.md`.

Diperbarui 15 November 2026, 23.55 WIB.

## 1. Topologi Jaringan dan Peran Node

Tailnet: MagicDNS `tail7d94e8.ts.net`. Skala awal masih kecil, tetapi desainnya harus mudah ditambah node baru.

| Node | IP Tailscale | Tag | Peran |
|------|----------------|-----|-------|
| VPS Windows `WIN-T65VC2J9G31` | `100.103.231.61` | `tag:vps` (sudah dipasang; key expiry dimatikan) | **Koordinator saja.** Antrean Redis, dashboard, exit node, situs aduhkerja, live/paper QT, login. Bukan mesin hitungan berat. |
| `komputerbox10` | `100.116.213.30` | `tag:compute` (sudah dipasang; key expiry dimatikan) | Node compute pertama (komputer Grok Bot). Head Ray saat ini, plus heartbeat dan worker antrean. |
| `komputerboxN` berikutnya | — | `tag:compute` | Komputer Grok Bot tambahan. Konfirmasi nomor `N` ke owner sebelum join. |
| `GrokboxN` (rencana) | — | `tag:compute` | Linux VPS/KVM 24/7 dengan systemd. Belum ada. Konfirmasi nama ke owner sebelum join. |
| `grokbot-box` | `100.107.153.80` | — | Nama lama. **Jangan disentuh, diganti namanya, atau dicabut** tanpa perintah eksplisit owner. |
| Perangkat owner (HP, laptop) | — | tanpa tag | Akses penuh milik owner. Jangan menag-nya. |

### 1.1 VPS adalah koordinator, bukan mesin hitungan

VPS Windows hanya mengerjakan hal yang memang harus tinggal di mesin produksi:

- antrean job Redis (layanan **ComputeQueue**, `100.103.231.61:6379`) dan **pembagian data**: node mengambil data job dan input lewat VPS
- dashboard node (layanan **ComputeDashboard**, `http://100.103.231.61:8787/`) dan agen heartbeat VPS (layanan **ComputeNodeAgent**)
- website aduhkerja
- quantitative-trading **live dan paper** (butuh login broker / MT5)
- tempat login yang tidak bisa dipindah, misalnya login provider Akash di masa depan
- exit node (sudah diiklankan dan disetujui)

VPS **tidak** dipakai untuk hitungan berat, storage terdistribusi, atau bandwidth DePIN. Jangan menaruh backtest, training, riset berat, atau penyimpanan hasil besar di VPS. Data aplikasi aduhkerja tetap di Supabase, bukan di storage node.

### 1.2 komputerbox dan Grokbox mengerjakan compute, bandwidth, dan storage

Node `tag:compute` mengerjakan hitungan, bandwidth, dan storage. Contoh: backtest, training, riset, dan (nanti) kapasitas sisa untuk DePIN. Hasil berat tidak disimpan permanen di VPS.

### 1.3 Exit node dan subnet router

**Exit node sudah aktif.** VPS mengiklankannya, dan kebijakan ACL memuat `autoApprovers.exitNode = ["tag:vps"]`. Owner (dan anggota tailnet) boleh memakai internet lewat VPS, misalnya untuk IP tetap / whitelist broker. Exit node memakai bandwidth VPS, jadi **jangan dijadikan default semua perangkat**.

**Subnet router tidak dipasang.** Jangan mengiklankan subnet kecuali nanti ada perangkat LAN di VPS yang benar-benar perlu diakses dan tidak bisa dipasangi Tailscale. Perubahan jaringan di VPS tetap butuh izin owner; cek aduhkerja sebelum dan sesudah perubahan.

## 2. Fitur Tailscale

**Aktif**
- **MagicDNS** di tailnet. Di komputer Grok Bot, Tailscale dijalankan dengan `--accept-dns=false`, jadi dari box pakai **IP Tailscale**, bukan nama `.ts.net`, kecuali dokumen per repo secara eksplisit memakai nama itu.
- **ACL + tag** `tag:compute` dan `tag:vps`. Kebijakan **sudah diterapkan**. Salinan tanpa rahasia: [`docs/tailnet-policy.hujson`](docs/tailnet-policy.hujson). Lihat [bagian 8](#8-tag-acl-dan-cara-menambah-node).
- **Tailscale SSH** di `komputerbox10` (`--ssh`): hanya owner, mode **check** dengan masa `12h`, user `box` / `root` / `autogroup:nonroot`. Kebijakan `ssh` ada di berkas ACL.
- **Exit node** di VPS (`tag:vps`), sudah disetujui (lihat bagian 1.3).

**Direkomendasikan (aktifkan sesuai jenis mesin)**
- **Tailscale SSH** untuk Linux VPS / Grokbox, bila disepakati, mengikuti kebijakan yang sama (owner, check 12h). Jangan mengandalkannya di VPS Windows: SSH ke mesin itu memakai OpenSSH biasa plus kata sandi, bukan Tailscale SSH.
- **Auth key / tagged key**: untuk menambah node baru. Tetap wajib konfirmasi ke owner sebelum membuat node atau auth key baru. Pakai reusable auth key yang sudah membawa `tag:compute`.

**Tidak digunakan**
- **Tailscale Funnel**: tetap mati. Jangan diaktifkan tanpa persetujuan eksplisit owner.
- **Connector Tailscale terkelola di Grok Bot**: hanya meneruskan HTTP(S). Jangan dipakai untuk SSH. Gejala jika dipaksa: HTTP 500 atau gagal membaca SSH protocol banner.
- **Subnet router**: tidak dipasang, lihat bagian 1.3.
- Alarm chat saat node mati: **tidak dipasang** (keputusan owner). Status dilihat di dashboard node.

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

VPS Windows tidak memakai systemd. Autostart mengikuti layanan Windows (WinSW) dan tugas terjadwal yang sudah ada, termasuk **ComputeQueue**, **ComputeDashboard**, dan **ComputeNodeAgent** (autostart delayed, restart otomatis, prioritas proses BelowNormal untuk antrean). Jangan menambahkan unit systemd. SSH tetap OpenSSH biasa plus kata sandi, bukan Tailscale SSH. **Restart mesin VPS dan perubahan di VPS hanya boleh setelah izin owner.**

### 5.3 Komputer Grok Bot (komputerbox)

Komputer Grok Bot **tidak punya systemd**. Rantai boot adalah `/tini` → `/pod-daemon` (keduanya biner platform). `systemctl` tidak tersedia. **Tidak ada hook boot yang bisa dikontrol.**

Tailscale, Ray, heartbeat, dan worker antrean di komputer ini dijalankan lewat skrip:

- Pintu masuk: `/home/box/bin/compute-start.sh` (memegang `flock`, lalu menyalakan `/home/box/bin/compute-watchdog.sh --loop 30`). Aman dipanggil berkali-kali.
- Watchdog lokal memeriksa Tailscale dan service komputasi setiap **30 detik**, lalu menyalakan ulang yang mati. Log: `/home/box/logs/compute-watchdog.log`.
- **Auto re-auth:** watchdog (lewat `/home/box/bin/tailscale-up.sh`) mengulang `tailscale up` dengan auth key jika status `NeedsLogin` / `NeedsMachineAuth` atau key kedaluwarsa. Auth key tidak pernah dicetak. Ada pembatas laju re-auth.
- Cadangan: bot **watchdog** menjalankan routine setiap **15 menit** (memanggil `compute-start.sh`, lalu memeriksa Tailscale dan Ray). Ia diam jika sehat, dan hanya perlu diperhatikan jika ada yang mati lalu dihidupkan lagi, atau gagal dihidupkan.
- Join / pulihkan Tailscale: `/home/box/bin/tailscale-up.sh` (hostname `komputerbox10`, `--ssh`, `--accept-dns=false`, `--netfilter-mode=off`, `--operator=box`).
- **Catatan:** `tailscale-up.sh` **tidak** meneruskan `--advertise-tags=tag:compute`. Tag `komputerbox10` dipasang di admin console (key expiry sudah dimatikan). Jika re-auth suatu saat memakai auth key tanpa tag, tag bisa hilang dan harus dipasang lagi di admin — **setelah** kebijakan yang memuat tag itu sudah tersimpan. Jangan menambah `--advertise-tags` sembarangan: mengiklankan tag yang tidak diizinkan untuk key itu bisa membuat `tailscale up` gagal.
- Mode di `komputerbox10`: **kernel TUN** pada antarmuka `tailscale0`. Root punya `CAP_NET_ADMIN`.
- Jika `/dev/net/tun` atau hak itu tidak ada, skrip jatuh ke `--tun=userspace-networking`. Mode userspace membatasi lalu lintas inbound: node lain sering tidak bisa membuka TCP ke port layanan (misalnya Ray).
- Proxy SOCKS5 tetap di `localhost:1055` pada kedua mode, dipakai SSH ke VPS Windows.
- Tipe NAT box adalah `MappingVariesByDestIP`, jadi koneksi ke peer cenderung lewat relay DERP (sekitar 200 ms), meskipun mode sudah TUN.
- Heartbeat dan worker antrean di box: `/home/box/compute/{heartbeat,worker}.py`, dijaga `/home/box/bin/compute-services.sh`. Log: `/home/box/logs/cq-*.log`.

**Autostart tanpa agent atau shell interaktif tidak dijamin.** Temuan 15 November 2026 (WIB) di `komputerbox10`:

- Tidak ada crontab, dan tidak ada hook pada rantai `/tini` → `/pod-daemon` yang bisa dijamin bertahan antar sesi.
- Ada hook shell interaktif di `/etc/bash.bashrc`, `/home/box/.bashrc`, dan `/etc/profile.d/compute-autostart.sh`. Hook itu hanya jalan ketika shell interaktif dimulai.
- Setelah box di-restart atau di-pause di luar kendali, stack baru hidup lagi saat ada shell interaktif, saat agent menjalankan `compute-start.sh`, atau saat routine bot watchdog (paling lama sekitar 15 menit) sempat jalan.

Karena itu, node yang **wajib** nyala otomatis 24 jam tanpa agent harus berupa **Linux VPS dengan systemd**, mengikuti bagian 5.1. `komputerbox10` adalah tenaga tambahan yang bisa cepat dipulihkan, bukan satu-satunya tumpuan ketersediaan.

### 5.4 Heartbeat dan dashboard node

Sudah hidup:

- Setiap node mengirim heartbeat ke VPS **setiap 5 detik**. Jika sebuah node tidak lapor selama **30 detik**, dashboard menandainya offline. VPS juga mem-`ping` tiap node lewat Tailscale **setiap 30 detik** (menjaga jalur WireGuard).
- Jika node mati, lease job-nya kedaluwarsa dan reaper (di setiap klaim worker, plus dashboard VPS tiap 10 detik) mengembalikan job ke antrean untuk diambil node lain. Lihat [bagian 6.2](#62-antrean-job-di-vps).
- **Dashboard:** `http://100.103.231.61:8787/` (hanya tailnet, bukan internet). Di VPS juga `http://127.0.0.1:8787/`. Dilayani layanan Windows **ComputeDashboard** dan **ComputeNodeAgent**. Shortcut desktop **Compute Nodes** ada di desktop Publik VPS (`C:\Users\Public\Desktop\Compute Nodes.url`) dan membuka alamat loopback itu.
- Isi dashboard: node yang aktif atau mati, plus CPU, RAM, storage, dan bandwidth per node (termasuk VPS) serta totalnya.
- **Tidak ada alarm chat** saat node mati (keputusan owner).

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
2. Linux VPS / Grokbox: `sudo systemctl status tailscaled cq-heartbeat cq-worker`, jalankan ulang bila mati. Komputer Grok Bot: jalankan `/home/box/bin/compute-start.sh` (atau `/home/box/bin/tailscale-up.sh` jika hanya Tailscale yang perlu dipulihkan).
3. Cek di admin console apakah ada "Key expired" atau tag hilang. Key expiry `komputerbox10` dan VPS sudah dimatikan; node baru perlu dimatikan expiry-nya setelah di-tag. Re-auth di box: `tailscale-up.sh` (auth key dari owner, jangan dicetak).
4. Jika tidak ada akses lagi, SSH ke VPS (OpenSSH biasa, bukan connector terkelola) lalu `tailscale ping`, dan beri tahu owner bila butuh akses fisik atau lewat panel penyedia mesin.

## 6. Framework Komputasi Terdistribusi

Pola yang sudah diputuskan owner, dan yang harus diikuti repo baru kecuali ada keputusan baru:

- **Di dalam tiap node:** Ray. Default node baru: `RAY_MODE=queue` (Ray lokal di node itu, job diambil dari antrean VPS). `RAY_MODE=cluster` adalah mode lama: worker juga join ke head di `komputerbox10`.
- **Antar node:** antrean job Redis di VPS. Node compute mengambil job, mengerjakannya, lalu mengembalikan hasilnya. Data dan input job diambil lewat VPS (pembagian data), hitungannya tetap di komputerbox / Grokbox.

### 6.1 Ray

- Versi acuan: Ray 2.60.0, Python 3.13. Worker yang join head (`RAY_MODE=cluster`) **harus** memakai versi Python dan Ray yang sama dengan head.
- Head saat ini: `100.116.213.30:6379` (`komputerbox10`). Klien dari node lain: `ray://100.116.213.30:10001`.
- Dashboard Ray: hanya `127.0.0.1:8265`, tidak diekspos ke tailnet. Jangan tertukar dengan dashboard node di `:8787`.
- Batas resource head di `komputerbox10`: 6 CPU, memori 8 GiB, object store 2 GiB (sisa untuk proses lain di box yang sama, dan agar pemakaian tidak 100%).
- Port tetap: GCS 6379, client 10001, node-manager 6380, object-manager 6381, dashboard-agent 52365, metrics 8090, worker 10002–10200. Port 6379 di **VPS** adalah Redis antrean, bukan Ray.
- **Token auth wajib.** `RAY_AUTH_MODE=token`. Token disimpan di berkas mode `600` (di head: `/home/box/.config/ray/auth_token`; di node systemd mode cluster: `/etc/ray/auth_token`). Jangan `cat` isinya, jangan menulisnya ke chat, PR, log, atau repo, dan jangan men-commit berkas itu. Koneksi tanpa token atau dengan token salah harus ditolak. Salin token antar node lewat tailnet (misalnya `scp`), bukan lewat chat. Mode `queue` (default) tidak wajib menyalin token Ray, kecuali node itu juga join head.
- Karena head sekarang di `komputerbox10` yang tidak dijamin 24/7, untuk kluster 24/7 nanti head bisa dipindah ke Grokbox Linux pertama. Itu perubahan tersendiri dan perlu izin owner.
- Latensi antar-node sering lewat DERP (~200 ms). Cocok untuk job yang lumayan besar per potong (misalnya backtest per set parameter), bukan tugas yang sangat chatty.

### 6.2 Antrean job di VPS

Sudah hidup. Rincian pemakaian: [`docs/QUEUE.md`](docs/QUEUE.md). Salinan kerja di komputer Grok Bot: `/workspace/compute/QUEUE.md`.

- Redis 5.0.14.1 (port Windows) di `C:\compute\redis`, layanan **ComputeQueue**: `100.103.231.61:6379` dan `127.0.0.1:6379`. Password ada di `queue.env` (di box: `/home/box/.config/compute/queue.env` mode `600`; di VPS: `C:\compute\secrets\`, hanya SYSTEM + Administrators). **Jangan dicetak atau di-commit.** Batas memori 384 MB `noeviction`, AOF everysec, prioritas proses BelowNormal, autostart delayed + restart otomatis (WinSW).
- Klaim job = **lease 60 detik** (`cq:leased`). Worker memperpanjang tiap 15 detik. Jika node mati, lease kedaluwarsa dan reaper mengembalikan job ke `cq:pending` (`attempts+1`; setelah `max_attempts` → `cq:dead`). Hasil worker dengan lease basi ditolak.
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

Fungsi = `"modul:fungsi"` yang bisa di-import di worker dan diizinkan `CQ_ALLOWED_PREFIXES` (default `cq_tasks`). Untuk backtest QT, tambahkan prefiks yang sesuai plus `CQ_PYTHONPATH`.

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

Konfirmasi dulu ke owner: nama (`GrokboxN` atau `komputerboxN`), OS, dan bahwa node itu boleh gabung. Default bootstrap adalah `RAY_MODE=queue` (Ray lokal + `cq-heartbeat` + `cq-worker`). `RAY_MODE=cluster` hanya jika node itu juga harus join head Ray di `komputerbox10`.

1. Pastikan kebijakan ACL yang memuat `tag:compute` sudah tersimpan (sudah berlaku sekarang).
2. Minta atau buat **reusable auth key** yang sudah membawa `tag:compute`, dan matikan key expiry untuk node server. Jangan menulis nilai key ke repo, isu, PR, log, atau chat yang tersimpan. Bootstrap **tidak** menambahkan `--advertise-tags`; tag diharapkan datang dari auth key itu.
3. Salin `/home/box/.config/compute/queue.env` dari `komputerbox10` ke file sementara mode `600` di node baru (lewat tailnet, jangan `cat`/chat/commit). `export CQ_ENV_SRC=/path/ke/salinan`.
4. Jika `RAY_MODE=cluster`, salin juga berkas token Ray dari head (`/home/box/.config/ray/auth_token`) ke file sementara mode `600`.
5. Di node baru, sebagai root, jalankan templat `/workspace/compute/node-bootstrap/bootstrap.sh`:

```bash
export NODE_NAME=Grokbox1            # nama yang sudah disetujui owner
export TS_AUTHKEY=...                # dari secret, jangan ditulis ke file
export CQ_ENV_SRC=/path/ke/salinan-queue.env
export RAY_MODE=queue                # default; pakai cluster hanya jika join head
# jika cluster: export RAY_HEAD=100.116.213.30:6379 RAY_AUTH_TOKEN_FILE=/path/ke/salinan-token
bash bootstrap.sh
```

6. Cek: `tailscale status` (tag `tag:compute` terlihat), `systemctl status cq-heartbeat cq-worker`, Funnel tetap mati. Node muncul di `http://100.103.231.61:8787/`. Jika mode cluster: `systemctl status ray-worker`, dan di head `RAY_AUTH_MODE=token RAY_AUTH_TOKEN_PATH=/home/box/.config/ray/auth_token ray status`.
7. Versi Python dan Ray harus sama dengan acuan (Python 3.13, Ray 2.60.0), wajib jika join head.
8. Node Windows (misalnya PC rumah ber-GPU) **tidak** memakai bootstrap systemd ini; siapkan installer terpisah setelah OS-nya disetujui owner.

Node baru yang sudah gabung akan muncul di dashboard tanpa di-hardcode di dokumen ini. Cukup ikuti templat; jangan hardcode hostname baru ke skrip bersama.

## 9. Arah DePIN

DePIN hanya memakai kapasitas sisa, dan bisa dikunci atau dikurangi kapan saja agar prioritas di bagian 4 tetap terjaga. Di antrean, itu prioritas 2 (hanya diambil jika CPU < 60% dan RAM < 70%). Login provider yang harus menetap (misalnya Akash nanti) boleh di VPS; hitungannya tetap di node compute.

Arah yang realistis dengan node yang ada sekarang:

- **Grass** atau **Mysterium**: bandwidth, cocok untuk node rumahan di belakang NAT, bisa dijeda. Grass biasanya hanya membayar IP residensial, jadi bukan untuk VPS atau `komputerbox10`.
- **Golem**: compute di node Linux, dengan batas core dan RAM yang bisa diatur agar QT tetap punya ruang. Cocok untuk Grokbox Linux berikutnya, bukan untuk head Ray yang sekarang.
- **Salad**: lebih cocok jika node berikutnya adalah PC Windows ber-GPU.

Ditunda dulu:

- **Akash** dan jaringan storage (Filecoin, Arweave, dan sejenisnya): butuh IP publik, port terbuka, dan/atau nyala 24/7, plus sering butuh disk/RAM besar. Belum cocok untuk node kita yang sekarang.

Langkah DePIN pertama yang masuk akal menunggu node rumahan atau Linux 24/7 pertama gabung. Jangan memasang klien DePIN di VPS, dan jangan memakan jatah aduhkerja atau QT.

## 10. Aturan Wajib bagi Agent

- Funnel tetap mati.
- Jangan menulis auth key Tailscale, token Ray, password Redis / isi `queue.env`, kata sandi SSH, token GitHub, atau rahasia lain ke repo, isu, PR, log, atau chat yang tersimpan. Berkas secret mode `600` dan tidak di-commit.
- Jangan menyentuh `grokbot-box`.
- Perubahan di VPS (jaringan, layanan produksi, restart, exit node, antrean, dashboard) butuh izin owner. Cek aduhkerja sebelum dan sesudah perubahan yang disetujui.
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
- (Ray di node, antrean di VPS, atau mengapa repo ini tidak memakai keduanya)

## Prioritas
- (bagaimana kebijakan prioritas umum berlaku di repo ini)

## Ketersediaan node
- (service apa yang harus hidup terus; dashboard http://100.103.231.61:8787/)

## Cara menjalankan / deploy
- (perintah, path kerja; SSH OpenSSH atau Tailscale SSH)

## Data dan storage
- (lokasi data, apa yang diambil lewat VPS, apa yang tidak boleh di VPS)

## Catatan khusus
- (port, Funnel, batasan, hal yang perlu dikonfirmasi)
```
