# Tailscale: depin

> Mengikuti aturan umum di [`TAILSCALE.md`](../TAILSCALE.md)

Diperbarui 16 November 2026, 22.20 WIB. Repo ini masih hampir kosong, tetapi arah DePIN, antrean, dan batasannya sudah diputuskan. Jangan menulis auth key, token Ray, password Redis, URL/key webhook, kata sandi, private key WireGuard / isi `snet.conf`, atau rahasia lain di berkas ini.

## Node yang dipakai

| Node | IP Tailscale | Tag | Peran di repo ini |
|---|---|---|---|
| VPS Windows `WIN-T65VC2J9G31` | `100.103.231.61` | `tag:vps` (sudah dipasang; key expiry dimatikan) | Koordinator saja. Antrean Redis, dashboard, dan pemanggil wake (**ComputeWakeCaller**, aktif sejak 00.22 WIB, 16 November 2026) milik bersama, plus tempat login provider yang harus menetap (misalnya Akash nanti). Bukan tempat klien DePIN, bukan hitungan, bukan storage/bandwidth DePIN. |
| `komputerbox10` | `100.116.213.30` | `tag:compute` (sudah dipasang; key expiry dimatikan) | Node compute bersama dengan Ray lokal dan worker antrean. Boleh memakai **kapasitas sisa** saja (antrean prioritas 2). Saat ini lebih tepat sebagai tenaga QT, bukan klien DePIN. |
| `GrokboxN` (rencana) | — | `tag:compute` | Calon node Linux 24/7 (Golem dan sejenisnya). Belum ada. Bootstrap default `RAY_MODE=queue`. |
| Node rumahan (rencana) | — | `tag:compute` atau tag yang lebih sempit nanti | Calon node residensial untuk bandwidth (Grass/Mysterium) atau GPU Windows (Salad). Belum ada. |
| `grokbot-box` | `100.107.153.80` | — | Nama lama. Jangan dicabut tanpa konfirmasi pemilik. |

Spek `komputerbox10` (termasuk hitungan armada 30 node dan batasannya) ada di `TAILSCALE.md` bagian 1.4; catatan lengkap: [`BENCHMARK-komputerbox.md`](BENCHMARK-komputerbox.md). Semua node di atas milik bersama. Jangan mengaku sebagai pemilik tunggal VPS atau `komputerbox10`.

## Framework komputasi

DePIN **tidak** mengambil alih Ray. Pola kluster: Ray **lokal di tiap node** (default `CQ_RAY_ADDRESS=local`, `CQ_RAY_HEAD=0`), antrean Redis di VPS (`100.103.231.61:6379`, lihat [`QUEUE.md`](QUEUE.md) dan `TAILSCALE.md` bagian 6). Mode cluster hanya opt-in untuk job raksasa. Workload DePIN dikirim sebagai job prioritas **2** (`PRIO_LEFTOVER`) atau sebagai klien terpisah di node yang cocok, dan hanya boleh memakai sisa CPU, RAM, disk, dan bandwidth.

Jangan menjalankan klien DePIN di VPS. Jangan memindahkan Ray ke mode yang membuat QT kelaparan.

## Prioritas

Mengikuti `TAILSCALE.md` bagian 4:

- aduhkerja dan QT (live/paper di VPS; backtest/training/riset di komputerbox, antrean prioritas 0–1) lebih dahulu.
- DePIN hanya memakai kapasitas sisa: di antrean, prioritas 2 diambil hanya jika CPU < 60% dan RAM < 70%. Jatahnya fleksibel (bukan persentase tetap), dan harus bisa dijeda atau dikurangi kapan saja.
- Tidak ada node yang boleh mencapai 100%.

## Arah jaringan

Sudah diputuskan sebagai arah, belum dipasang:

- **Grass** atau **Mysterium**: bandwidth di node rumahan (IP residensial, bisa di belakang NAT, bisa dijeda). Bukan untuk VPS, dan bukan langkah pertama di `komputerbox10`.
- **Golem**: compute di node Linux 24/7, dengan batas core dan RAM. Cocok untuk `GrokboxN` nanti.
- **Salad**: jika node berikutnya adalah PC Windows ber-GPU.

Ditunda: **Akash** dan jaringan storage (Filecoin, Arweave, dan sejenisnya). Mereka butuh IP publik, port terbuka, dan/atau nyala 24/7, plus sering butuh disk/RAM besar. Login provider Akash, jika suatu saat dipasang, tinggal di VPS; hitungannya tetap di node compute.

Langkah pertama yang realistis menunggu node rumahan atau Linux 24/7 pertama gabung. Jangan mulai pemasangan klien tanpa izin pemilik dan tanpa cek bahwa QT serta aduhkerja tidak terganggu.

## Ketersediaan node

Mengikuti `TAILSCALE.md` bagian 5. Komputer Grok Bot bisa tidur saat idle; yang membangunkan adalah aktivitas platform atau pemanggil wake VPS ke webhook bot watchdog (aktif sejak 00.22 WIB, 16 November 2026; jeda awal 15 menit, lalu 30/60/120 menit sampai `WAKE_MAX_COOLDOWN_S`=7200, reset saat heartbeat kembali, maks 4/jam; Redis tidak terjangkau → tidak menembak). Watchdog loop 30 detik (termasuk auto re-auth) hanya memperbaiki service setelah mesin bangun. Routine terjadwal 15 menit sudah dihapus. Jika VPS mati, tidak ada yang membangunkan box. `tailscale-up.sh` tidak meneruskan `--advertise-tags` dan tidak memakai exit node. Node yang wajib 24/7 tanpa bergantung pada VPS harus Linux VPS dengan systemd (`/workspace/compute/node-bootstrap/`, unit `cq-heartbeat` dan `cq-worker`; default bootstrap memasang `tag:compute` dan Tailscale SSH, bisa diubah `TS_TAGS` / `TS_SSH=0`).

Banyak jaringan DePIN mengharapkan uptime tinggi. Jangan memasang klien yang menghukum downtime di `komputerbox10`. Dashboard: `http://100.103.231.61:8787/` (tailnet saja, termasuk storage, bandwidth, dan kolom **Ping dari VPS**, shortcut **Compute Nodes** di desktop Publik VPS). Heartbeat tiap 5 detik, offline setelah 30 detik, VPS mem-ping node tiap 30 detik (hasil di `cq:node:<node>`; `tailscale ping` bisa exit 1 lewat DERP meskipun sukses). Jika layanan restart, halaman menampilkan data terakhir dan "Menyambung ulang…". Tidak ada alarm chat saat node mati.

## Cara menjalankan / deploy

Belum ada klien yang dipasang. Jika suatu saat memasang:

- Ikuti `TAILSCALE.md` bagian 8 untuk join node baru (`tag:compute`; salin `queue.env`, default `RAY_MODE=queue`; token Ray hanya jika `RAY_MODE=cluster`). Simpan kebijakan ACL sebelum menag.
- Job ke antrean memakai prioritas 2. Cara pakai: [`QUEUE.md`](QUEUE.md). Jangan memakai prioritas 0.
- SSH ke VPS Windows memakai OpenSSH biasa plus kata sandi, bukan Tailscale SSH, dan hanya untuk urusan koordinator (misalnya login provider), bukan untuk menjalankan klien DePIN.
- Connector Tailscale terkelola di Grok Bot hanya HTTP, jangan dipakai untuk SSH.
- Funnel tetap mati. Jangan membuka port publik demi DePIN tanpa keputusan pemilik.

## Data dan storage

Storage dan bandwidth yang boleh dijual atau dibagi adalah milik **komputerbox / Grokbox / node rumahan**, bukan disk VPS, dan bukan data aduhkerja (Supabase) atau artefak QT yang seharusnya masuk R2.

Jangan menaruh kredensial provider DePIN atau password Redis di repo. Jangan memakai storage VPS sebagai backend DePIN.

## Catatan khusus

- Jalur Tailscale box↔VPS sekarang langsung lewat IP publik S-Network (`TAILSCALE.md` bagian 1.5): `direct 8.215.14.48:41641`, latensi stabil sekitar 200 ms, cadangan DERP otomatis. Bandwidth langsung 5–10 Mbps; perpanjang langganan sebelum 16 Desember 2026.
- Funnel tetap mati, kecuali ada keputusan baru dari pemilik.
- Kebijakan ACL sudah diterapkan: [`tailnet-policy.hujson`](tailnet-policy.hujson). Simpan kebijakan **sebelum** menag node baru.
- Exit node VPS sudah aktif; subnet router tidak dipasang. Komputerbox tidak memakai exit node.
- Jangan menulis rahasia ke repo, termasuk URL/key webhook dan private key WireGuard / isi `snet.conf`.
- Jangan menyentuh `grokbot-box`. Perubahan di VPS butuh izin pemilik.
- Agen tidak menggabungkan PR.
