# Rencana jaringan DePIN (draft diskusi)

**Status:** draft untuk dibahas nanti. Belum ada klien yang dipasang, dan PR ini tidak dimaksudkan untuk digabung sebelum ada keputusan.
**Tanggal:** Senin, 16 November 2026 (WIB, UTC+7)
**Dasar:** [`DEPIN-RETURNS.md`](DEPIN-RETURNS.md) (estimasi return, sumber, dan penghambat) serta catatan benchmark `komputerbox10` (8 vCPU Xeon Emerald Rapids, 15 GiB RAM, ~100 GB NVMe kelas Gen3, tanpa GPU, KVM ada).

Dokumen ini merangkum hasil riset supaya kita bisa memutuskan **jaringan DePIN mana yang akan dipakai**, di **hardware yang mana**, dan **bukan** di komputerbox. Jangan menulis auth key, token, kata sandi, URL/key webhook, atau rahasia lain di berkas ini.

---

## 1. Ringkasan usulan

1. **Jangan pasang mining atau klien DePIN di komputerbox.** Dengan 30 node penuh pun, return realistis cuma sekitar **$20–60/bulan (Rp0,35–1,1 juta)**, hampir semuanya dari mining CPU yang berisiko dianggap menjual ulang layanan platform. Nilai compute setara cloud-nya sekitar **$261/bulan per node**, atau **~$7.830/bulan** untuk 30 node.
2. **DePIN dijalankan di hardware milik kita sendiri, atau di IP residensial** (internet rumah), bukan di box platform dan bukan di VPS koordinator.
3. **Kebijakan tetap:** DePIN hanya memakai **kapasitas sisa**, dan **tidak pernah 100%**. QT serta aduhkerja lebih dulu.
4. Arah jaringan yang masuk akal, *kalau* hardware-nya memenuhi syarat:
   - **Mysterium / Grass** di internet rumah (IP residensial)
   - **Golem** di mesin Linux dengan KVM
   - **Salad** di PC Windows ber-GPU
   - **Storj / Akash** hanya jika ada IP publik dan nyala 24/7

Keputusan rinci (hardware, urutan jaringan, wallet, dan pemantauan) masih terbuka; lihat daftar periksa di bagian 6.

---

## 2. Estimasi return: 1 node vs 30 node

Kurs acuan di sumber: 1 USD = **Rp18.229** (open.er-api.com, update 15 November 2026 00.02 UTC).

Angka di bawah sudah memakai faktor efektif dari riset: batas CPU DePIN **60%**, waktu sisa **40–60%**, uptime box **80–95%** (karena tidur saat idle). Faktor efektif total ≈ **0,19–0,34**. "Kotor" = 8 core 24/7 100%. Listrik komputerbox = $0 (bukan kita yang bayar), jadi pendapatan = profit.

Satu CPU hanya bisa dipakai satu miner sekaligus, jadi baris mining **tidak dijumlah**. Plafon realistis 30 node tetap sekitar **$20–60/bulan**; skenario Qubic yang sangat tidak pasti bisa sampai ~$110/bulan.

| Opsi | Bisa di komputerbox? | Efektif 1 node / bulan | Efektif 30 node / bulan | 30 node / bulan (IDR) | Sumber utama |
| --- | --- | ---: | ---: | ---: | --- |
| Monero (XMR), RandomX | Teknis mungkin (outbound saja); **risiko ToS tinggi** | $0,64–1,46 | **$19–44** | Rp0,35–0,80 jt | Hashrate publik XMRig CPU sejenis ([contoh 8 thread](https://xmrig.com/benchmark/53C33V)); jaringan 16 Nov 2026 di [xmrchain.net](https://xmrchain.net/api/networkinfo); harga CoinGecko; [WhatToMine XMR](https://whattomine.com/coins/101.json?hr=3.8&p=0&fee=1&cost=0) |
| Koin RandomX lain (EPIC / ETI) | Sama seperti XMR, likuiditas tipis | $0,90–2,06 | **$27–62** | Rp0,49–1,13 jt | [WhatToMine CPU](https://whattomine.com/cpu.json) (~1,0–1,4× XMR) |
| Qubic (CPU-only) | Mungkin; angka **sangat tidak pasti** | $0,35–3,69 | **$10–111** | Rp0,19–2,0 jt | Inferensi kasar dari laporan epoch lama dan [qubic.church](https://qubic.church/mine-qubic); bukan pengukuran di box ini |
| Golem (realistis) | KVM ada, tetapi permintaan hampir nol | $0–0,55 | **$0–17** | Rp0–0,30 jt | Harga default [docs.golem.network](https://docs.golem.network/docs/providers/configuration/general); payout jaringan ~$57/hari untuk ~720 provider ([bestcloudmining.net, 2 Okt 2026](https://www.bestcloudmining.net/providers/golem/)) |
| Golem (teoretis kalau 100% laku) | Tidak realistis | $2,6–4,6 | ($77–137) | (Rp1,4–2,5 jt) | Harga default GLM, bukan utilisasi nyata |
| Salad CPU | **Tidak** (Windows saja; Linux closed beta fleet) | — | **$0** | Rp0 | Tarif $0,004/vCPU-jam ([blog Salad, Sep 2026](https://blog.salad.com/earning-rate-changes-september-2026/)); [syarat kompatibilitas](https://support.salad.com/faq/compatibility/is-my-machine-compatible-with-salad/) |
| Grass / Honeygain / Nodepay | **Tidak** (IP datacenter/proxy = 0 poin) | $0 | **$0** | Rp0 | [Grass: IP VPN/proxy tidak dapat poin](https://www.grass.io/learn/grass-stuck-on-connecting-here-s-the-fix/); bandwidth app residential-only ([hum.pub, 2026](https://hum.pub/analysis/what-bandwidth-sharing-apps-actually-pay-on-a-datacenter-ip)) |
| Mysterium / EarnFM / Repocket (IP datacenter) | Sangat terbatas; **egress IP dipakai bersama** | $0–1,7 **per IP** | **$0–1,7** (tidak dikali 30) | Rp0–31 rb | [docs.mysterium.network](https://docs.mysterium.network/faq); laporan operator VPS; app DC ~$1–5/bulan per IP (hum.pub) |
| Storj | **Tidak** (min 500 GB, port inbound, uptime 99,3%) | ~$0 | **$0** | Rp0 | [Syarat node](https://storj.dev/node/get-started/prerequisites) dan [payout](https://storj.dev/node/payouts) |
| Filecoin | **Tidak** (butuh rig sealing TB–PB, GPU, RAM besar) | — | **$0** | Rp0 | Syarat hardware sealing; tidak relevan untuk box ini |
| Akash | **Tidak** (IP publik + port 80/443/8443/8444, k8s, min 150 GB SSD) | — | **$0** | Rp0 | [Syarat hardware provider](https://akash.network/docs/providers/getting-started/hardware-requirements/) |
| *Pembanding: sewa cloud setara (AWS c7i.2xlarge)* | — | $261 | **$7.830** | Rp142,7 jt | Bentuk 8 vCPU / 16 GiB; harga on-demand us-east-1 ≈ $0,3570/jam |

Metodologi, asumsi, dan batas verifikasi lengkap ada di [`DEPIN-RETURNS.md`](DEPIN-RETURNS.md). Hashrate RandomX tidak diukur di box ini (binary miner sengaja tidak dijalankan). Utilisasi live Golem tidak terverifikasi hari riset (API error/terblokir). Bayaran Qubic per solusi di epoch terkini belum diukur.

---

## 3. Penghambat di komputerbox

Alasan utama kita **tidak** memakai komputerbox (satu node maupun 30 node) sebagai host DePIN atau miner:

| Penghambat | Dampak |
| --- | --- |
| **Risiko ToS / menjual ulang layanan** | ToS dan AUP platform tidak menyebut "mining" secara eksplisit, tetapi melarang merental, meminjamkan, atau **menjual ulang Service**. Menjual compute atau bandwidth box (Golem, Akash, Salad, proxy bandwidth) masuk kategori itu. Mining plus trik supaya box tidak tidur juga berisiko dianggap penyalahgunaan. Sanksinya bisa suspend atau terminasi akun, yang ikut mematikan QT dan semua bot. Risikonya tinggi, hasilnya tidak sebanding. |
| **Egress lewat proxy platform, IP berubah-ubah, dipakai bersama** | Semua outbound box lewat proxy/tunnel platform. IP keluar berganti (datacenter/CDN), dan 30 node cenderung keluar lewat IP yang sama. App bandwidth residensial (Grass, Honeygain, Nodepay) dapat 0 poin. App yang menerima IP datacenter dibayar per IP, jadi **tidak dikali 30**. Trafik orang lain yang keluar lewat IP platform juga memperbesar risiko penyalahgunaan. |
| **Tidak ada IP publik dan tidak ada port inbound** | Storj, Akash, Filecoin/Sia, dan sebagian mode Mysterium gagal syarat. Tidak bisa jadi provider yang harus menerima koneksi masuk. |
| **Box bisa tidur saat idle** | Uptime di bawah syarat ketat (Storj minta 99,3%, maks ~5 jam mati per bulan). Sesi Golem/Mysterium bisa putus. Wake dari VPS ada jeda, jadi tetap bukan 24/7 murni. |
| **Disk hanya ~100 GB** | Di bawah minimum Storj (500 GB) dan Akash (150 GB SSD). Sisa disk juga dipakai sistem dan pekerjaan QT, bukan untuk dijual. |

Kesimpulan praktis: komputerbox tetap tenaga backtest dan riset QT. DePIN tidak dipasang di sana.

---

## 4. Rekomendasi: jaringan mana, di hardware mana

**Tidak ada mining atau DePIN di komputerbox.** Kalau proyek DePIN dilanjutkan, memakai hardware milik kita atau IP residensial:

| Jaringan | Tempat yang cocok | Syarat utama | Catatan |
| --- | --- | --- | --- |
| **Mysterium** atau **Grass** | Internet rumah (IP residensial), misalnya PC atau Raspberry Pi | Bukan VPN/datacenter; NAT biasanya boleh | Langkah bandwidth yang paling masuk akal. Perkiraan publik Mysterium residensial sekitar $8–25/bulan per node ([MystNodes](https://www.mystnodes.com/blog/how-much-can-you-earn-sharing-bandwidth)). Grass tidak jalan di IP datacenter. |
| **Golem** | Mesin **Linux** dengan **KVM**, nyala cukup stabil | x86-64, KVM, batas core dan RAM | Permintaan jaringan saat ini hampir nol, jadi ini eksperimen compute, bukan sumber return yang bisa diandalkan. Jangan di VPS koordinator. |
| **Salad** | **PC Windows ber-GPU** | Windows 10/11; GPU jauh lebih berguna daripada CPU-only | App Linux masih closed beta untuk fleet besar. CPU-only di Windows ada tarifnya, tetapi bukan sasaran utama. |
| **Storj** atau **Akash** | Hanya jika ada **IP publik** dan **nyala 24/7** | Storj: ≥500 GB, port inbound, uptime 99,3%. Akash: IP publik/DDNS, domain, port 80/443/8443/8444, Kubernetes, min ~150 GB SSD | Ditunda sampai hardware dan jaringan memenuhi syarat. Kalau suatu saat login provider Akash dibutuhkan, tempat menetapnya di VPS koordinator; hitungannya tetap di node compute milik kita. |
| Mining CPU (XMR, Qubic, dll.) | Tidak disarankan di komputerbox, dan bukan fokus proyek DePIN | — | Return kecil; di box platform risikonya tidak sebanding. Kalau suatu saat diukur, lakukan di mesin milik sendiri. |

Filecoin (sealing skala TB–PB) tidak relevan untuk rencana dekat ini.

VPS tetap koordinator saja (antrean, dashboard, pemanggil wake). Bukan tempat klien DePIN, bukan hitungan, dan bukan storage/bandwidth yang dijual.

---

## 5. Kebijakan kapasitas (pengingat)

Ini sudah menjadi aturan bersama, dan tetap berlaku di hardware mana pun DePIN dipasang:

- DePIN **hanya memakai kapasitas sisa**. Tidak mengambil jatah QT, aduhkerja, atau pekerjaan prioritas lain.
- **Tidak pernah 100%.** Harus ada ruang untuk sistem, antrean, dan lonjakan kerja QT.
- Di antrean compute yang sudah ada, workload sisa (prioritas 2) hanya diambil jika **CPU < 60%** dan **RAM < 70%**. Pekerjaan QT memakai prioritas 0–1 (ambang lebih longgar, tetap di bawah 85%).
- Jatah DePIN fleksibel: bisa dijeda atau dikurangi kapan saja, tanpa merusak pekerjaan lain.
- Jangan memasang klien yang menghukum downtime di mesin yang tidak 24/7.

---

## 6. Pertanyaan terbuka (daftar periksa)

Isi nanti, setelah didiskusikan. Belum perlu dipasang apa pun sebelum kotak ini diputuskan.

### Hardware
- [ ] DePIN memakai hardware mana dulu? (PC rumah, Raspberry Pi, mesin Linux 24/7 milik kita, PC Windows ber-GPU, VPS sendiri yang ToS-nya mengizinkan, atau kombinasi)
- [ ] Di mana fisiknya, dan bagaimana listrik serta internetnya? (rumah, kantor, colocation)
- [ ] Berapa unit tahap pertama, dan apakah akan di-tag di tailnet yang sama sebagai node compute?

### Jaringan yang dipasang lebih dulu
- [ ] Bandwidth residensial: **Mysterium**, **Grass**, keduanya, atau ditunda?
- [ ] Compute: **Golem** mulai setelah ada mesin Linux + KVM, atau ditunda sampai permintaan jaringan lebih jelas?
- [ ] **Salad**: hanya jika ada PC Windows ber-GPU, atau tidak masuk rencana dekat ini?
- [ ] **Storj / Akash**: tetap ditunda sampai ada IP publik dan uptime 24/7, atau ada lokasi yang sudah memenuhi syarat?
- [ ] Apakah mining CPU sepenuhnya di luar cakupan proyek ini?

### Wallet dan kustodi
- [ ] Wallet mana yang dipakai per jaringan, dan atas nama siapa?
- [ ] Siapa yang memegang kunci / seed, dan di mana disimpan? (bukan di repo, bukan di chat, bukan di disk bersama yang tidak terenkripsi)
- [ ] Bagaimana payout dicatat (aset, jaringan, alamat publik saja), dan kapan dicairkan?
- [ ] Apakah ada pemisahan wallet uji dan wallet produksi?

### Pemantauan lewat antrean dan dashboard yang sudah ada
- [ ] Apakah node DePIN masuk antrean compute yang sama (job prioritas 2 / kapasitas sisa) dan terlihat di dashboard node yang sudah ada?
- [ ] Atau klien DePIN jalan di luar antrean, dan dashboard hanya menampilkan heartbeat, uptime, serta pemakaian CPU/RAM/disk/bandwidth?
- [ ] Metrik apa yang wajib kelihatan? (status klien, uptime, pendapatan, error, apakah QT terganggu)
- [ ] Perlu alarm kalau node DePIN mati, atau cukup dipantau manual dulu?

---

## 7. Yang belum terverifikasi

- Hashrate RandomX komputerbox (estimasi dari CPU sejenis, bukan diukur).
- Utilisasi live Golem pada hari riset (API down/terblokir; data payout 2 Oktober 2026).
- Bayaran Qubic per solusi untuk CPU-only di epoch terkini.
- Apakah 30 komputerbox benar-benar memakai IP egress yang sama.

Hal-hal di atas tidak mengubah usulan utama: DePIN tidak dipasang di komputerbox.

