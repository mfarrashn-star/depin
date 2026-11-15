# Tailscale: depin

> Mengikuti aturan umum di [TAILSCALE.md](../TAILSCALE.md). Baca dokumen ini sebelum menerapkan bagian 4 dokumen umum.

Repo `depin` publik. Hostname, IP Tailscale, nama tailnet, sidik SSH, auth key, dan sandi tidak ditulis di sini.

## Node yang dipakai

Belum ada node untuk repo ini. Belum ada layanan yang berjalan.

Nama untuk node baru, setelah user mengonfirmasi pembuatannya:

- VPS: `VPS`
- Compute: `Grokbox1`, `Grokbox2`, dan seterusnya

MagicDNS menampilkan nama itu dalam huruf kecil. Node lama yang namanya di luar konvensi ini ditanyakan ke user sebelum diganti.

## Framework komputasi

Belum dipasang. Repo ini belum punya beban kerja yang bisa dijadwalkan.

Saat beban kerja muncul, pilih dari tabel bagian 5 di `TAILSCALE.md`. Backtest paralel, tuning parameter, dan simulasi Python mulai dari Ray. Slurm ditambah bila antrian job berantakan atau jumlah node membesar. Dua sampai tiga node dengan kerja sederhana memakai Dask, atau Tailscale SSH bersama GNU Parallel.

Pemasangan Ray, Slurm, atau Dask menunggu beban kerja itu. Pilihan yang mengubah topologi dikonfirmasi ke user dulu.

## Ketersediaan node

Belum ada service depin yang harus tetap hidup.

Saat user meminta setup mesin, ikuti bagian 4 di `TAILSCALE.md`, lalu laporkan:

- `tailscale status`
- `tailscale ping <nama-node>`
- `systemctl is-enabled tailscaled` pada mesin Linux
- uji reboot hanya bila user mengizinkan

`tailscale up` membuat node baru. Jalankan setelah user mengonfirmasi.

## Cara menjalankan / deploy

Belum ada perintah, path kerja, atau service deploy.

## Data dan storage

Belum ada data depin di disk atau di object storage.

Saat data muncul, pilih dari bagian 6 di `TAILSCALE.md`. Parquet dan riset analitik mulai dari MinIO di VPS dan DuckDB di tiap node. Time series yang sering di-query memakai PostgreSQL atau TimescaleDB. Cache ringan memakai Redis. Data besar disimpan dekat node yang membacanya.

Bucket, database, dan share NFS dibuat setelah ada data. Pilihan yang berdampak besar dikonfirmasi ke user dulu.

## Catatan khusus

- Tailscale Funnel tetap mati. Aktifkan hanya setelah persetujuan eksplisit.
- ACL dan `tag:grokbox` diaktifkan setelah konfirmasi, saat jumlah node membuat aturan per mesin sulit diurus.
- Auth key dan tagged key hanya setelah konfirmasi. Nilainya tidak masuk repo, PR, atau log.
- Dokumen ini tidak mengubah prosedur Tailscale di repo lain. Tiap repo memakai `docs/TAILSCALE_REPO.md` sendiri.
- Pemeriksaan 15 November 2026 di komputer agen cloud untuk run ini: biner `tailscale` dan `tailscaled` tidak ada di PATH. Tidak ada node baru yang dibuat.
