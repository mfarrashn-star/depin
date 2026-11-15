# Antrean job pusat (VPS) + monitor node

| Komponen | Lokasi | Detail |
|---|---|---|
| Antrean (Redis 5.0.14.1 Windows port) | VPS `C:\compute\redis`, layanan **ComputeQueue** | `100.103.231.61:6379` + `127.0.0.1:6379`, password, maxmemory 384 MB noeviction, AOF everysec, BelowNormal, autostart (delayed) + restart otomatis (WinSW) |
| Agen heartbeat VPS | `C:\compute\app\heartbeat.py`, layanan **ComputeNodeAgent** | node `vps` (role coordinator), tiap 5 s; juga `tailscale ping` ke tiap node tiap 30 s (jaga jalur WireGuard). Hasil ping disimpan di `cq:node:<node>` (`ping_ok`, `ping_ms`, `ping_via`, `ping_at_ms`, `ping_fail_streak`) dan dicatat di `C:\compute\logs\ComputeNodeAgent.out.log` (saat OK↔GAGAL berubah + ringkasan tiap 10 mnt). Sukses dinilai dari baris `pong from`, bukan exit code (`tailscale ping` exit 1 lewat DERP walau pong diterima) |
| Dashboard | `C:\compute\app\dashboard.py`, layanan **ComputeDashboard** | `http://100.103.231.61:8787/` (tailnet) dan `http://127.0.0.1:8787/` (di VPS); juga reaper antrean tiap 10 s. Kolom **Ping dari VPS** (ms, jalur, umur). Saat layanan restart (±2 s) halaman tetap menampilkan data terakhir, menulis "Menyambung ulang…" dan mencoba lagi tiap 2 s |
| Wake caller | `C:\compute\app\wake_caller.py`, layanan **ComputeWakeCaller** (aktif sejak 00.22 WIB, 16 November 2026; BelowNormal, ~20 MB RAM, restart otomatis) | cek `cq:alive:<node>` tiap 30 s; heartbeat basi ≥120 s → POST webhook bot watchdog. Cooldown awal 15 mnt, lalu 30/60/120 mnt (`WAKE_MAX_COOLDOWN_S`=7200), reset saat heartbeat kembali; maks 4/jam; `WAKE_NODES`. Redis tidak terjangkau → tidak menembak. Secret di `C:\compute\secrets\wake.env` (jangan tulis nilainya). |
| Shortcut | `C:\Users\Public\Desktop\Compute Nodes.url` | membuka `http://127.0.0.1:8787/` |
| Firewall | "Compute queue+dashboard allow tailnet" / "... block non-tailnet" | TCP 6379, 8787: allow 100.64.0.0/10, block selain itu (default inbound VPS = Allow!) |
| Secret | box `/home/box/.config/compute/queue.env` (600); VPS `C:\compute\secrets\` (hanya SYSTEM + Administrators) | jangan dicetak/commit |
| Worker + heartbeat komputerbox10 | `/home/box/compute/{worker,heartbeat}.py`, dijaga `/home/box/bin/compute-services.sh` via `compute-watchdog.sh` | log `/home/box/logs/cq-*.log`; setelan node `/home/box/.config/compute/node.env` (tanpa secret) |

## Pakai dari Python (node mana pun di tailnet)
```python
import sys; sys.path.insert(0, "/home/box/compute")
from cq import Queue, PRIO_CRITICAL, PRIO_NORMAL, PRIO_LEFTOVER
q = Queue.from_env()                      # baca /home/box/.config/compute/queue.env
jid = q.submit("cq_tasks:square", [7], priority=PRIO_CRITICAL, num_cpus=1, timeout_s=600)
print(q.wait(jid))                         # {'x': 7, 'y': 49, ...}
print(q.stats())
```
Fungsi = `"modul:fungsi"` yang bisa di-import di worker. Modul harus sama dengan prefix di `CQ_ALLOWED_PREFIXES` atau submodulnya (`cq_tasks`, `cq_tasks.x`); nama yang hanya berawalan sama (`cq_tasks_evil`) ditolak.
Tambahkan mis. `qt_jobs` + `CQ_PYTHONPATH=/path/ke/repo` untuk backtest QT.

## Leasing / node mati
Klaim = lease 60 s (`cq:leased`, skor = deadline). Worker memperpanjang tiap 15 s. Kalau node mati,
lease kedaluwarsa dan reaper (di setiap klaim worker + dashboard VPS tiap 10 s) mengembalikan job ke
`cq:pending` (attempts+1; setelah `max_attempts`, default 3, → `cq:dead`). Hasil worker dengan lease basi ditolak.
Lease yang habis karena box tidur juga dihitung sebagai percobaan, jadi job panjang di node yang sering tidur
harus di-submit dengan `max_attempts` lebih besar plus checkpoint.
Teruji: kill -9 worker di tengah job → job selesai lagi setelah ±70 s.
Prioritas: 0 kritis (QT), 1 normal, 2 sisa (DePIN). Ambil job dibatasi beban (lihat node-bootstrap/README.md).

## Ray per node (default sejak 2026-11-16)
Worker tiap node menjalankan Ray lokalnya sendiri (`CQ_RAY_ADDRESS=local`), dibatasi `CQ_RAY_CPUS`,
`CQ_RAY_MEMORY_MB`, `CQ_RAY_OBJECT_STORE_MB` (komputerbox10: 6 CPU, 8 GiB, object store 2 GiB). Antar node dibagi
oleh antrean VPS, jadi tidak ada node yang bergantung pada komputerbox10. Aturan beban tetap: prioritas 0–1
diambil bila CPU < 85% dan RAM < 85%; prioritas 2 (sisa/DePIN) bila CPU < 60% dan RAM < 70%.
Head Ray bersama `100.116.213.30:6379` (token auth) **opt-in**: `CQ_RAY_HEAD=1` di `node.env` → watchdog
menyalakannya; job raksasa multi-node pakai `CQ_RAY_ADDRESS=100.116.213.30:6379`. `ray-head-up.sh` hanya
menghentikan sesi head lama (GCS 6379), tidak pernah `ray stop --force` (itu ikut membunuh Ray lokal worker).
Teruji: head dimatikan → job `cq_tasks:square` tetap selesai lewat Ray lokal (±5 s).

## Checkpoint (`cq_checkpoint.py`)
`checkpoint().save(state)` / `.load()` per job id (`CQ_JOB_ID` diset worker). Job yang di-requeue (lease habis,
node mati) melanjutkan dari checkpoint; checkpoint dihapus setelah job sukses. Backend `auto`: R2 (S3 API, SigV4,
tanpa boto3) bila `R2_ACCOUNT_ID`/`R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET` ada di env
atau `CQ_CHECKPOINT_ENV_FILE` (komputerbox10: `/home/box/.config/compute/r2.env`, 600); kalau tidak, disk lokal
`/home/box/compute-checkpoints` (hanya node yang sama). Contoh: `cq_tasks:resumable_count`.
Teruji: kill -9 worker di langkah 10/40 → job di-requeue (attempt 2) dan lanjut dari langkah 11, total benar.
Tes offline: `python3 /workspace/compute/test_cq_checkpoint.py`.


## Pemanggil wake VPS (aktif sejak 00.22 WIB, 16 November 2026)

Layanan Windows **ComputeWakeCaller** (WinSW, `C:\compute\app\wake_caller.py`) sudah aktif sejak 00.22 WIB, 16 November 2026: prioritas BelowNormal, sekitar 20 MB RAM, autostart delayed, restart otomatis. Setiap 30 detik memeriksa `cq:alive:<node>` untuk tiap nama di `WAKE_NODES` (saat ini `komputerbox10`). Jika heartbeat hilang ≥ 120 detik, VPS mengirim POST ke webhook routine milik bot **watchdog** (bukan bot lain). Jeda awal 15 menit, lalu berlipat 30 / 60 / 120 menit (batas `WAKE_MAX_COOLDOWN_S`=7200 detik) jika node belum hidup lagi, dan reset begitu heartbeat kembali. Paling banyak 4 panggilan per jam. Jika Redis tidak terjangkau, tidak ada panggilan. URL dan key (`WAKE_WEBHOOK_URL`, `WAKE_WEBHOOK_KEY`) hanya di `C:\compute\secrets\wake.env`; jangan dicetak, di-commit, atau ditulis nilainya. Routine webhook menjalankan `compute-start.sh`, memverifikasi pemulihan, mencatat `/home/box/logs/downtime.log`, dan lapor ke owner. Routine terjadwal 15 menit sudah dihapus. Jika VPS mati, tidak ada yang membangunkan box. Rincian: `TAILSCALE.md` bagian 5.3.

## Perilaku audit (16 November 2026)

- **Ping VPS → node terlihat** di kolom dashboard **Ping dari VPS**, atau `Get-Content C:\compute\logs\ComputeNodeAgent.out.log -Tail 5` di VPS.
- **Worker tidak mati karena error non-jaringan** (misalnya `RedisError` OOM/NOAUTH, error Ray): dicatat `loop error ...`, koneksi ditutup, coba lagi 5 detik; lease job yang sedang jalan tetap diperpanjang.
- **Allow-list fungsi ketat**: modul harus sama dengan prefix di `CQ_ALLOWED_PREFIXES` atau submodulnya (`cq_tasks`, `cq_tasks.x`), bukan sekadar diawali (`cq_tasks_evil` ditolak).
- **Orphan Ray dibersihkan**: worker yang di-`kill -9` bisa meninggalkan `ray::DashboardAgent` / `RuntimeEnvAgent` (±200 MB). `compute-services.sh` membersihkannya (dan GCS/raylet sesi lokal non-6379) sebelum menyalakan worker lagi. Head bersama (GCS 6379) tidak disentuh. Di node systemd tidak perlu (unit membunuh seluruh cgroup).
- Uji pemulihan: `/workspace/compute/kill_test.sh heartbeat|worker|tailscale` (tidak pernah `ray stop --force`). Tes offline: `python3 /workspace/compute/tests/test_worker_policy.py` (ambang 85/85 dan 60/70 + allow-list). E2E: `/workspace/compute/tests/e2e_queue.py [--kill-at N]`, `/workspace/compute/tests/e2e_gating.py`.
