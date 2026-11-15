# Antrean job pusat (VPS) + monitor node

| Komponen | Lokasi | Detail |
|---|---|---|
| Antrean (Redis 5.0.14.1 Windows port) | VPS `C:\compute\redis`, layanan **ComputeQueue** | `100.103.231.61:6379` + `127.0.0.1:6379`, password, maxmemory 384 MB noeviction, AOF everysec, BelowNormal, autostart (delayed) + restart otomatis (WinSW) |
| Agen heartbeat VPS | `C:\compute\app\heartbeat.py`, layanan **ComputeNodeAgent** | node `vps` (role coordinator), tiap 5 s; juga `tailscale ping` ke tiap node tiap 30 s (jaga jalur WireGuard) |
| Dashboard | `C:\compute\app\dashboard.py`, layanan **ComputeDashboard** | `http://100.103.231.61:8787/` (tailnet) dan `http://127.0.0.1:8787/` (di VPS); juga reaper antrean tiap 10 s |
| Shortcut | `C:\Users\Public\Desktop\Compute Nodes.url` | membuka `http://127.0.0.1:8787/` |
| Firewall | "Compute queue+dashboard allow tailnet" / "... block non-tailnet" | TCP 6379, 8787: allow 100.64.0.0/10, block selain itu (default inbound VPS = Allow!) |
| Secret | box `/home/box/.config/compute/queue.env` (600); VPS `C:\compute\secrets\` (hanya SYSTEM + Administrators) | jangan dicetak/commit |
| Worker + heartbeat komputerbox10 | `/home/box/compute/{worker,heartbeat}.py`, dijaga `/home/box/bin/compute-services.sh` via `compute-watchdog.sh` | log `/home/box/logs/cq-*.log` |

## Pakai dari Python (node mana pun di tailnet)
```python
import sys; sys.path.insert(0, "/home/box/compute")
from cq import Queue, PRIO_CRITICAL, PRIO_NORMAL, PRIO_LEFTOVER
q = Queue.from_env()                      # baca /home/box/.config/compute/queue.env
jid = q.submit("cq_tasks:square", [7], priority=PRIO_CRITICAL, num_cpus=1, timeout_s=600)
print(q.wait(jid))                         # {'x': 7, 'y': 49, ...}
print(q.stats())
```
Fungsi = `"modul:fungsi"` yang bisa di-import di worker dan diizinkan `CQ_ALLOWED_PREFIXES`
(tambahkan mis. `qt_jobs` + `CQ_PYTHONPATH=/path/ke/repo` untuk backtest QT).

## Leasing / node mati
Klaim = lease 60 s (`cq:leased`, skor = deadline). Worker memperpanjang tiap 15 s. Kalau node mati,
lease kedaluwarsa dan reaper (di setiap klaim worker + dashboard VPS tiap 10 s) mengembalikan job ke
`cq:pending` (attempts+1; setelah `max_attempts` → `cq:dead`). Hasil worker dengan lease basi ditolak.
Teruji: kill -9 worker di tengah job → job selesai lagi setelah ±70 s.
Prioritas: 0 kritis (QT), 1 normal, 2 sisa (DePIN). Ambil job dibatasi beban (lihat node-bootstrap/README.md).
