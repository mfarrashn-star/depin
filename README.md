# depin

Aturan Tailscale untuk repo ini:

- [docs/TAILSCALE.md](docs/TAILSCALE.md) — aturan umum, dipakai semua repo
- [docs/TAILSCALE_REPO.md](docs/TAILSCALE_REPO.md) — peran VPS, Grokbox, dan DePIN untuk repo ini

Repo ini belum menjalankan layanan. Node baru butuh konfirmasi. Hostname tailnet, IP, dan auth key tidak ditulis di dokumen ini.

## Akash nanti, di Grokbox

Pada 15 November 2026, Grokbox25 tidak ada di tailnet. Karena itu tidak ada yang dipasang di node mana pun. Akash belum dipasang.

VPS bukan provider. Jangan menjalankan Akash di VPS.

Setelah satu Grokbox Linux online, pilih jatah Akash di mesin itu. Website dan quantitative-trading tetap di depan. Akash tidak pernah mengambil 100% CPU atau RAM. Mining tidak ada di skrip ini.

- `optimal` memberi Akash 10% CPU dan 10% RAM. Ini jatah kecil. Sisanya untuk website, trading, dan sistem.
- `25` memberi Akash 25% CPU dan 25% RAM.
- `50` memberi Akash 50% CPU dan 50% RAM. Ini batas atas.

Minimal 2 GB (2147483648 byte) RAM tetap di luar batas Akash. Kalau persentase di atas memotong cadangan itu, batas RAM Akash diturunkan. Persentase CPU tetap pada pilihan itu.

Dari repo, di Grokbox, perintah ini hanya menjelaskan. Tidak ada berkas yang ditulis. Statusnya bukan nol.

```bash
scripts/setup-akash-grokbox.sh --share optimal
scripts/setup-akash-grokbox.sh --share 25
scripts/setup-akash-grokbox.sh --share 50
```

Untuk menerapkan batas, sebagai root di Grokbox:

```bash
sudo scripts/setup-akash-grokbox.sh --share optimal --confirm
```

Ganti `optimal` dengan `25` atau `50` bila itu pilihannya. Skrip menolak jika hostname tidak diawali `grokbox`. Pilihan yang diterapkan tersimpan di `/etc/depin/akash-share.conf`. Batas cgroup ada di slice `akash.slice`. Proses Akash harus berjalan di dalam slice itu. Angka Docker untuk slice yang sama ada di berkas itu: `docker_cpus`, `docker_memory_bytes`, dan `docker_cgroup_parent`. Website dan trading tetap di luar slice. Tanpa `--confirm`, berkas itu tidak ditulis.

Skrip ini tidak memasang paket dan tidak memasang Akash. Cek hitungan tanpa memasang apa pun: `scripts/smoke-akash-share.sh`.
