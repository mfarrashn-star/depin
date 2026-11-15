# Tailscale: depin

> Mengikuti aturan umum di [`TAILSCALE.md`](../TAILSCALE.md)

Diperbarui 15 November 2026. Repo ini masih hampir kosong, tetapi arah DePIN dan batasannya sudah diputuskan. Jangan menulis auth key, token Ray, kata sandi, atau rahasia lain di berkas ini.

## Node yang dipakai

| Node | IP Tailscale | Tag (setelah ACL diterapkan) | Peran di repo ini |
|---|---|---|---|
| VPS Windows `WIN-T65VC2J9G31` | `100.103.231.61` | `tag:vps` | Koordinator saja. Tempat login provider yang harus menetap (misalnya Akash nanti). Bukan tempat klien DePIN, bukan hitungan, bukan storage/bandwidth DePIN. |
| `komputerbox10` | `100.116.213.30` | `tag:compute` | Node compute bersama. Boleh memakai **kapasitas sisa** saja, dan saat ini lebih tepat sebagai head Ray QT, bukan klien DePIN. |
| `GrokboxN` (rencana) | — | `tag:compute` | Calon node Linux 24/7 (Golem dan sejenisnya). Belum ada. |
| Node rumahan (rencana) | — | `tag:compute` atau tag yang lebih sempit nanti | Calon node residensial untuk bandwidth (Grass/Mysterium) atau GPU Windows (Salad). Belum ada. |
| `grokbot-box` | `100.107.153.80` | — | Nama lama. Jangan dicabut tanpa konfirmasi pemilik. |

Semua node di atas milik bersama. Jangan mengaku sebagai pemilik tunggal VPS atau `komputerbox10`.

## Framework komputasi

DePIN **tidak** mengambil alih Ray head. Pola kluster tetap: Ray di tiap node compute untuk job QT/riset, antrean job di VPS. Workload DePIN adalah klien terpisah di node yang cocok, diatur supaya hanya memakai sisa CPU, RAM, disk, dan bandwidth.

Jangan menjalankan klien DePIN di VPS. Jangan memindahkan head Ray ke mode yang membuat QT kelaparan.

## Prioritas

Mengikuti `TAILSCALE.md` bagian 4:

- aduhkerja dan QT (live/paper di VPS; backtest/training/riset di komputerbox) lebih dahulu.
- DePIN hanya memakai kapasitas sisa, jatahnya fleksibel (bukan persentase tetap), dan harus bisa dijeda atau dikurangi kapan saja.
- Tidak ada node yang boleh mencapai 100%.

## Arah jaringan

Sudah diputuskan sebagai arah, belum dipasang:

- **Grass** atau **Mysterium**: bandwidth di node rumahan (IP residensial, bisa di belakang NAT, bisa dijeda). Bukan untuk VPS, dan bukan langkah pertama di `komputerbox10`.
- **Golem**: compute di node Linux 24/7, dengan batas core dan RAM. Cocok untuk `GrokboxN` nanti.
- **Salad**: jika node berikutnya adalah PC Windows ber-GPU.

Ditunda: **Akash** dan jaringan storage (Filecoin, Arweave, dan sejenisnya). Mereka butuh IP publik, port terbuka, dan/atau nyala 24/7, plus sering butuh disk/RAM besar. Login provider Akash, jika suatu saat dipasang, tinggal di VPS; hitungannya tetap di node compute.

Langkah pertama yang realistis menunggu node rumahan atau Linux 24/7 pertama gabung. Jangan mulai pemasangan klien tanpa izin pemilik dan tanpa cek bahwa QT serta aduhkerja tidak terganggu.

## Ketersediaan node

Mengikuti `TAILSCALE.md` bagian 5. Autostart tanpa agent atau shell interaktif tidak dijamin di komputer Grok Bot (watchdog lokal 30 detik + bot watchdog 15 menit). Node yang wajib 24/7 tanpa agent harus Linux VPS dengan systemd (`/workspace/compute/node-bootstrap/`).

Banyak jaringan DePIN mengharapkan uptime tinggi. Jangan memasang klien yang menghukum downtime di `komputerbox10`. Heartbeat dan dashboard node (tailnet saja, termasuk storage dan bandwidth) akan menampilkan kapasitas sisa; alamatnya belum diisi. Tidak ada alarm chat saat node mati.

## Cara menjalankan / deploy

Belum ada klien yang dipasang. Jika suatu saat memasang:

- Ikuti `TAILSCALE.md` bagian 8 untuk join node baru (`tag:compute`, token Ray hanya jika node itu juga worker Ray).
- SSH ke VPS Windows memakai OpenSSH biasa plus kata sandi, bukan Tailscale SSH, dan hanya untuk urusan koordinator (misalnya login provider), bukan untuk menjalankan klien DePIN.
- Connector Tailscale terkelola di Grok Bot hanya HTTP, jangan dipakai untuk SSH.
- Funnel tetap mati. Jangan membuka port publik demi DePIN tanpa keputusan pemilik.

## Data dan storage

Storage dan bandwidth yang boleh dijual atau dibagi adalah milik **komputerbox / Grokbox / node rumahan**, bukan disk VPS, dan bukan data aduhkerja (Supabase) atau artefak QT yang seharusnya masuk R2.

Jangan menaruh kredensial provider DePIN di repo. Jangan memakai storage VPS sebagai backend DePIN.

## Catatan khusus

- Funnel tetap mati, kecuali ada keputusan baru dari pemilik.
- Draf ACL: [`tailnet-policy.hujson`](tailnet-policy.hujson). Belum diterapkan sampai pemilik menyimpannya di admin console.
- Jangan menulis rahasia ke repo.
- Jangan menyentuh `grokbot-box`. Perubahan di VPS butuh izin pemilik.
- Agen tidak menggabungkan PR.
