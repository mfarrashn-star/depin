# Estimasi return mining / DePIN — komputerbox (1 node vs 30 node)

**Dibuat:** Senin, 16 November 2026, ±00.40–01.00 WIB (UTC+7)
**Spek per node** (lihat `BENCHMARK-komputerbox10.md`): 8 vCPU Xeon Emerald Rapids (~3,6 GHz all-core, tanpa SMT), 15 GiB RAM, ~100 GB NVMe kelas Gen3, tanpa GPU, KVM ada.
**Kurs:** 1 USD = **Rp18.229** (open.er-api.com, update 15 Nov 2026 00.02 UTC; implied CoinGecko Rp18.235).

> **Kesimpulan singkat:** dengan 30 node penuh pun, return realistis cuma **sekitar $20–60/bulan (Rp0,35–1,1 juta)**, dan hampir semuanya dari mining CPU yang **berisiko melanggar ToS / bikin akun di-suspend**. DePIN "jualan resource" (Golem, Akash, Salad, Storj, bandwidth) praktis **nol** atau **tidak bisa jalan** di box ini. Nilai box sebagai compute (setara ~$261/bln per node di AWS) **~100–400× lebih besar** daripada hasil mining-nya. Rekomendasi: **jangan dipakai mining/DePIN**; pakai buat QT.

---

## 1. Asumsi faktor efektif

| Faktor | Rendah | Tinggi | Alasan |
| --- | --- | --- | --- |
| Batas CPU DePIN | 60% | 60% | Kebijakan: <60% CPU, QT prioritas |
| Waktu tersisa (leftover) | 40% | 60% | Diminta di brief |
| Uptime (sleep/restart) | 80% | 95% | Box tidur saat idle; wake via webhook VPS, ada jeda |
| **Faktor efektif total** | **0,19** | **0,34** | 0,6 × waktu × uptime |

"Kotor" = 8 core 24/7 100%. "Efektif" = kotor × faktor di atas. Listrik = $0 (bukan kita yang bayar), jadi pendapatan = profit.

## 2. Tabel utama

| Opsi | Bisa jalan di box ini? | Kotor/node/hari | Efektif/node/bulan | **Efektif 30 node/bulan** | 30 node/bulan (IDR) |
| --- | --- | --- | --- | --- | --- |
| Monero (XMR), RandomX | Teknis mungkin (outbound saja); **risiko ToS tinggi** | $0,11–0,14 | $0,64–1,46 | **$19–44** | Rp0,35–0,80 jt |
| Koin RandomX lain terbaik (EPIC/ETI) | Sama seperti XMR, likuiditas tipis | $0,16–0,20 | $0,90–2,06 | **$27–62** | Rp0,49–1,13 jt |
| Qubic (CPU-only) | Mungkin; angka **sangat tidak pasti** | $0,06–0,36 | $0,35–3,69 | **$10–111** | Rp0,19–2,0 jt |
| Golem (realistis) | KVM ada, tapi permintaan hampir nol | $0–0,05 | $0–0,55 | **$0–17** | Rp0–0,30 jt |
| Golem (teoretis kalau 100% laku) | Tidak realistis | $0,45 | $2,6–4,6 | ($77–137) | (Rp1,4–2,5 jt) |
| Salad CPU | **Tidak** (Windows saja; Linux closed beta fleet) | ($0,77) | — | **$0** | Rp0 |
| Grass / Honeygain / Nodepay | **Tidak** (IP datacenter/proxy = 0 poin) | $0 | $0 | **$0** | Rp0 |
| Mysterium / EarnFM / Repocket (IP DC) | Sangat terbatas; **egress IP dipakai bersama** | $0–0,17 per IP | $0–1,7 per IP | **$0–1,7** (tidak dikali 30) | Rp0–31 rb |
| Storj | **Tidak** (min 500 GB, butuh port inbound, uptime 99,3%) | ~$0,006 (teoretis 100 GB) | ~$0 | **$0** | Rp0 |
| Filecoin | **Tidak** (butuh rig sealing TB–PB, GPU, RAM besar) | — | — | **$0** | Rp0 |
| Akash | **Tidak** (IP publik + port 80/443/8443/8444, k8s, min 150 GB SSD) | — | — | **$0** | Rp0 |
| *Pembanding: nilai sewa cloud setara (AWS c7i.2xlarge)* | — | $8,57 | $261 | **$7.830** | Rp142,7 jt |

Kalau digabung semua yang "mungkin" (satu CPU hanya bisa dipakai satu miner sekaligus, jadi **tidak dijumlah**), plafon realistis 30 node ≈ **$20–60/bulan**, skenario Qubic optimis sampai ~$110/bulan.

Per hari (30 node, efektif): XMR **$0,64–1,46/hari** (Rp12–27 rb), Qubic $0,35–3,7/hari.

## 3. Detail per opsi

### 3.1 Monero (RandomX)
- **Hashrate (estimasi, tidak di-benchmark):** 3,5–4,5 kH/s per node (8 core). Dasar: hasil XMRig publik untuk Xeon Sapphire/Emerald Rapids sekitar 450 H/s per thread, misalnya Xeon Platinum 8481C (Sapphire Rapids, 8 thread) **3.635 H/s** ([xmrig.com](https://xmrig.com/benchmark/53C33V)) dan Xeon Platinum 8573C (Emerald Rapids, 32 thread) 14.553 H/s = 455 H/s/thread ([xmrig.com](https://xmrig.com/benchmark/2xCSvy)). Core penuh tanpa SMT bisa sedikit lebih tinggi, tapi L3 dibagi dengan VM lain.
- Benchmark xmrig **sengaja tidak dijalankan**: menjalankan binary miner di box yang disediakan platform bisa memicu deteksi penyalahgunaan, dan angka publik sudah cukup buat estimasi.
- **Jaringan (16 Nov 2026):** difficulty 818,6 G, hashrate jaringan 6,82 GH/s, reward blok 0,615 XMR, tinggi 3.807.071 ([xmrchain.net API](https://xmrchain.net/api/networkinfo), [moneroblocks.info](https://moneroblocks.info/api/get_stats)).
- **Harga XMR:** $494,70 (CoinGecko).
- **Kalkulator:** WhatToMine untuk 3,8 kH/s = **0,000246 XMR/hari = $0,12/hari** ([whattomine.com/coins/101](https://whattomine.com/coins/101.json?hr=3.8&p=0&fee=1&cost=0)). Hitungan manual: 720 blok × 0,615 / 6,82 GH/s × 3.800 H/s ≈ 0,000247 XMR. Cocok.
- Koin RandomX lain (EPIC, Etica, XDAG, QRL) di WhatToMine CPU per 15–16 Nov hanya ~1,0–1,4× XMR, dengan likuiditas jauh lebih tipis ([whattomine.com/cpu](https://whattomine.com/cpu.json)).

### 3.2 Qubic
- Nov 2026: mining Qubic melatih jaringan saraf "BPP-9000" (1.024 neuron mulai epoch 239, 11 Nov), dan mulai epoch 240 (18 Nov) dinilai dengan feed BTC live. Bayarannya per **solusi** per epoch mingguan, bukan per it/s. Xeon Scalable baru (AVX-512) dinilai "Good" ([qubic.church](https://qubic.church/mine-qubic)).
- Data terakhir yang ketemu: Ryzen 7950X (~190 it/s) dapat $0,67–0,78/hari pada April 2026 (laporan epoch 206–207, lewat [coinro.io](https://coinro.io/qubic-mining-calculator/)). Harga QUBIC sekarang $0,000000336 (CoinGecko), dan aturan task sudah berubah. Estimasi 60–90 it/s × $0,001–0,004 per it/s per hari = **$0,06–0,36/hari** itu **inferensi kasar**. Angka aslinya cuma bisa diketahui dengan menjalankannya satu epoch.

### 3.3 Golem
- Butuh Linux x86-64 + KVM. Ada, jadi teknisnya memenuhi. Harga default 0,025 GLM/CPU-jam + 0,005 GLM/jam ([docs.golem.network](https://docs.golem.network/docs/providers/configuration/general)). GLM = $0,0907.
- **Permintaan:** sekitar 720 provider online, dan total payout seluruh jaringan **427,58 GLM per 24 jam** (~$57 untuk semua provider), artinya rata-rata ~$0,05–0,08 per provider per hari ([bestcloudmining.net, data API stats per 2 Okt 2026](https://www.bestcloudmining.net/providers/golem/)). API stats Golem (`api.stats.golem.network`) dicoba hari ini dan error (500 dari fetcher, TLS diputus dari box), jadi **utilisasi live tidak terverifikasi**.
- Satu-satunya kabar soal permintaan di 2026 adalah kemitraan dengan Salad (Jan 2026).

### 3.4 Bandwidth (Grass, Honeygain, Mysterium, dll.)
- **Fakta jaringan box (diukur sekarang):** semua outbound lewat proxy/tunnel egress platform (`SAND_EGRESS_TUNNEL_PROXY_ADDR`), DNS diarahkan ke 198.18.0.1, dan IP keluar **berganti-ganti**: 104.28.219.241 / IPv6 AS13335 **Cloudflare**, sebelumnya 182.253.183.12 (Biznet), dan di brief 52.10.95.238 (AWS). Tidak ada IP publik dan tidak ada port inbound.
- **Grass:** IP datacenter/VPN/proxy = Network Quality 0%, tidak dapat poin, dan tidak bisa di-unblock ([grass.io](https://www.grass.io/learn/grass-stuck-on-connecting-here-s-the-fix/)). IP Cloudflare/WARP pasti kena. **$0.**
- **Honeygain, Nodepay, PacketStream, EarnApp, Pawns:** residential-only ([hum.pub, 2026](https://hum.pub/analysis/what-bandwidth-sharing-apps-actually-pay-on-a-datacenter-ip)). **$0.**
- **Yang menerima IP DC:** EarnFM ($0,04/GB DC), Repocket, AntGain, BitPing, sekitar **$1–5/bulan per VPS**, min payout $5–15 (hum.pub). **Mysterium:** IP non-residential dihargai lebih rendah, ada fee 20%, laporan operator VPS <6 MYST/bulan ([docs.mysterium.network](https://docs.mysterium.network/faq), [reddit](https://www.reddit.com/r/MysteriumNetwork/comments/145v9ot/how_much_will_i_earn_with_my_cloud_server/)). 6 MYST × $0,12 = ~$0,72/bulan.
- **Masalah 30 node:** bayaran dihitung per IP, dan 30 node keluar lewat IP egress bersama, jadi pendapatan **tidak dikali 30**. Lebih parah lagi: trafik orang lain keluar lewat IP platform. Ini yang paling mungkin dianggap penyalahgunaan.

### 3.5 Storage
- **Storj:** $1,35/TB/bulan simpan, $1/TB egress (per 1 Sep 2026). Minimum 500 GB, port TCP/UDP 28967 inbound, uptime 99,3% (maks 5 jam mati per bulan) ([storj.dev/payouts](https://storj.dev/node/payouts), [prerequisites](https://storj.dev/node/get-started/prerequisites)). Kita gagal di tiga syarat sekaligus. Kalaupun bisa, 100 GB = ~$0,14/bulan, sedangkan payout L1 minimal ~$50.
- **Filecoin:** butuh hardware sealing berskala TB–PB. Tidak relevan.
- RAM tidak punya pasar sendiri. Nilainya cuma ikut harga paket compute (Golem/Akash).

### 3.6 Akash
- Syarat provider: IP publik statis/DDNS, domain, port 80/443/8443/8444 + NodePort, Kubernetes. Minimum 8 core / 16 GB / **150 GB SSD** ([akash.network](https://akash.network/docs/providers/getting-started/hardware-requirements/)). Box ini gagal di IP publik, port, dan disk (100 GB, RAM 15 GiB). **Tidak bisa.**

### 3.7 Salad
- CPU-only dibayar **$0,004 per vCPU-jam** (naik dari $0,0035 per 12 Sep 2026) ([blog.salad.com](https://blog.salad.com/earning-rate-changes-september-2026/)). Tapi app-nya **Windows 10/11 saja**, Linux closed beta untuk fleet besar, butuh RAM 16 GB ([support.salad.com](https://support.salad.com/faq/compatibility/is-my-machine-compatible-with-salad/)). **Tidak eligible.**

## 4. Penghambat kelayakan (ringkas)

| Penghambat | Dampak |
| --- | --- |
| **ToS / AUP platform** | Saya baca [ToS](https://cursor.com/terms-of-service) (update 3 Sep 2026) dan [AUP](https://cursor.com/acceptable-use-policy) (update 11 Agu 2026): **tidak ada kata "mining" secara eksplisit**. Tapi ToS 1.5(iii) melarang "rent, lease, lend, or sell the Service", dan AUP melarang "leasing, selling, reselling… our Service", "bypassing our systems or protective measures", serta mengakali "usage-metering systems". Menjual compute/bandwidth box (Golem, Akash, Salad, proxy bandwidth) = **menjual ulang Service**, jelas melanggar. Mining tidak disebut eksplisit, tapi memakai compute yang disediakan untuk mencetak koin, ditambah keepalive supaya box tidak tidur, berisiko dianggap abuse. Sanksinya bisa **suspend/terminasi akun**, yang juga mematikan QT dan semua bot. **Risiko tinggi, dan hasilnya tidak sebanding.** |
| IP datacenter/proxy, berganti-ganti, dipakai bersama | Bandwidth app residential = $0; app DC tidak bisa diskalakan ke 30 node |
| NAT keras, tanpa IP publik/port inbound | Storj, Akash, Sia, Mysterium (sebagian) gagal |
| Egress lewat proxy platform (DNS 198.18.x) | Koneksi P2P/stratum bisa diblok atau terlihat oleh platform; API Golem stats sudah gagal TLS dari box |
| Sleep saat idle | Uptime <99%, gagal syarat Storj; Golem/Myst kehilangan sesi |
| Disk ~100 GB | Di bawah minimum Storj (500 GB) dan Akash (150 GB) |
| Kebijakan <60% CPU, QT prioritas | Pendapatan tinggal 19–34% dari kotor |

## 5. Rekomendasi

1. **Jangan pasang miner atau DePIN di komputerbox.** Plafon 30 node ~$20–60/bulan, sedangkan risikonya kehilangan akun beserta seluruh infrastruktur QT. Nilai compute-nya ~$7.830/bulan setara cloud.
2. Kalau tetap mau eksperimen DePIN, lakukan di **hardware sendiri dengan IP residential** (PC/Raspberry Pi di rumah): Grass, Honeygain, Mysterium residential (~$8–25/bulan per node menurut [MystNodes](https://www.mystnodes.com/blog/how-much-can-you-earn-sharing-bandwidth)). Atau di **VPS sendiri** yang ToS-nya mengizinkan.
3. Kalau ingin tahu angka Qubic yang pasti, ukur di mesin milik sendiri selama 1 epoch, jangan di box ini.

## 6. Yang belum terverifikasi
- Hashrate RandomX box ini (estimasi dari benchmark publik CPU sejenis, bukan diukur).
- Utilisasi live Golem (API down/terblokir hari ini; pakai data 2 Okt 2026).
- Bayaran Qubic per solusi untuk CPU-only di epoch 239/240.
- Apakah 30 node benar-benar memakai IP egress yang sama (yang terlihat dari node ini: pool Cloudflare/proxy yang berganti-ganti).
