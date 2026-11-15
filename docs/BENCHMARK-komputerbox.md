# Benchmark komputerbox10 — setara CPU, RAM, dan SSD

**Mesin:** komputerbox10 (box ini, tamu KVM)  
**Waktu ukur:** Senin, 16 November 2026, 00.30–00.37 WIB (UTC+7)  
**Catatan:** worker compute, Ray, Tailscale, dan layanan lain **tidak dimatikan**. Load awal ~0,2–0,4. Ada proses latar (pod-daemon ~11% CPU, node ~8%, beberapa worker Ray idle ~0,5%). Angka multi-thread sedikit lebih rendah daripada mesin yang benar-benar kosong, tetapi skalanya tetap 7,75× dari 8 thread (efisiensi ~97%).

Dokumen ini memisahkan tiga jenis pernyataan:

1. **Terukur** — angka dari perintah yang dijalankan di box ini.
2. **Dari sumber** — angka atau spesifikasi resmi/publikasi, dengan tautan.
3. **Inferensi** — kesimpulan dari (1) dan (2), bukan fakta yang terbaca langsung di tamu.

Log mentah lengkap ada di `/workspace/bench-results.txt`.

---

## 1. Ringkasan setara (cara baca cepat)

| Bagian | Yang terukur di tamu | Setara yang mudah dipahami | Jenis pernyataan |
| --- | --- | --- | --- |
| CPU (identitas) | 8 vCPU, 1 thread/inti, `GenuineIntel`, family 6, model **207** (0xCF), stepping **2**, CPUID **C06F2**, L3 320 MB, turbo 1T ~3,9 GHz | Intel Xeon Scalable **generasi ke-5 (Emerald Rapids)**. Host hampir pasti SKU 64-inti 320 MB L3: Platinum **8592+ / 8592V / 8593Q**. Bukan Sapphire Rapids. | Terukur + inferensi dari sumber Intel |
| CPU 1 thread | 7-Zip Tot **6.642 MIPS**; sysbench **3.306,94** events/s | Di antara **Core i5-13400** (5.829) dan **Ryzen 5 7600** (7.566); kira-kira 14% di atas i5-13400, 14% di bawah 7600, ~82% Ryzen 7 7700X (8.074). Intinya: inti P-core kelas 13th-gen yang jalan di ~3,9 GHz, bukan 5,1–5,4 GHz desktop. | Terukur + perbandingan sumber |
| CPU 8 thread | 7-Zip Tot **57.130 MIPS**; sysbench **25.636** events/s | Hampir sama dengan **Core i5-13400** penuh (59.510, ~96%). Sekitar 88% Ryzen 5 7600 (64.613) dan **67% Ryzen 7 7700X** 8c/16t (85.707). Bukan setara 8-inti desktop kelas 7700X, karena tamu tidak dapat SMT dan clock-nya lebih rendah. | Terukur + perbandingan sumber |
| RAM | 15 GiB terlihat (`free -h`; MemTotal 16.386.368 KiB ≈ 15,6 GiB). STREAM Triad terbaik **94,99 GB/s**, rata-rata **79,76 GB/s**. Latensi DRAM ~180–206 ns. | **Host:** DDR5 ECC server, sampai DDR5-5600, 8 kanal (Emerald Rapids tidak mendukung DDR4). **Bagian yang didapat VM:** setara **DDR5 dual-channel 5600** (teoritis 89,6 GB/s), jauh di atas DDR4-3200 dual-channel (teoritis 51,2 GB/s). | Terukur + inferensi |
| SSD | Seq 1M QD32: baca **2.917 MB/s**, tulis **2.319 MB/s**. Random 4K QD32: baca **316k IOPS**, tulis **232k IOPS**. | Kelas **NVMe Gen3** (bukan SATA ~550 MB/s, bukan NVMe Gen4 desktop 5.000–7.000 MB/s). Flag `rotational=1` di virtio **menyesatkan** — ini bukan HDD. | Terukur + inferensi |
| Cloud | 8 vCPU, ~16 GiB, tanpa GPU | Bentuknya seperti AWS **c7i.2xlarge** (8 vCPU, 16 GiB). Harga on-demand **US East (N. Virginia):** **$0,3570/jam** ≈ **$260,61/bulan** (730 jam). **Asia Pacific (Jakarta, ap-southeast-3):** **$0,4116/jam** ≈ **$300,47/bulan**. Catatan: c7i memakai Sapphire Rapids; box ini Emerald Rapids (lebih baru, L3 host lebih besar). | Sumber harga 2026 |
| GPU / virtualisasi | Tidak ada GPU. `/dev/kvm` ada, VT-x nyala. | Backtest/riset QT berbasis CPU cocok. Training model besar yang butuh GPU tidak bisa. DePIN yang perlu KVM (misalnya Golem) memungkinkan. | Terukur |

---

## 2. Klaim ringkasan sebelumnya: dikonfirmasi atau dikoreksi

Klaim yang sempat disampaikan sebelum benchmark ini:

| Klaim sebelumnya | Status | Keterangan |
| --- | --- | --- |
| CPU Xeon generasi baru, Sapphire **atau** Emerald Rapids, AVX-512 + AMX, L3 320 MB | **Dikoreksi** | Bukan “salah satu dari dua”. CPUID family 6, model 207 (0xCF), stepping 2 = **Emerald Rapids (Xeon Scalable gen 5)** saja. Sapphire Rapids adalah model 143 (0x8F). Intel menandai 0x06-0xCF-0x02 sebagai EMR-A1. |
| Setara AWS `c7i.2xlarge`, kira-kira **$0,36/jam** atau **$260/bulan** | **Dikonfirmasi, dibulatkan** | On-demand us-east-1 resmi di agregator 2026: **$0,3570/jam**, **$260,61/bulan** (730 jam). Di Jakarta (ap-southeast-3) lebih mahal: **$0,4116/jam**, **$300,47/bulan**. Bentuk 8 vCPU / 16 GiB cocok, tetapi c7i adalah Sapphire Rapids, bukan Emerald Rapids. |
| Performa per inti kuat, kurang lebih PC desktop **8-inti kelas menengah** | **Dikoreksi sebagian** | Single-thread memang kelas menengah 2023 (antara i5-13400 dan Ryzen 5 7600). Multi-thread **lebih dekat ke i5-13400** (6P+4E) daripada ke Ryzen 7 7700X 8-inti/16-thread. 7700X kira-kira 50% lebih kencang di 7-Zip multi-thread karena SMT dan turbo 5,4 GHz. |
| RAM 15 GB, tanpa GPU, disk 125 GB sisa ~102 GB | **Dikonfirmasi** | `free -h` 15 GiB; MemTotal 15,6 GiB; `/dev/vdb` ext4 125 G, terpakai 24 G / sisa 102 G saat diukur. Tidak ada GPU. |
| Fitur KVM nyala, bisa jalanin mesin virtual (berguna untuk DePIN seperti Golem) | **Dikonfirmasi** | `/dev/kvm` ada, flag `vmx`, `Virtualization: VT-x`, hypervisor KVM. |
| RAM host kemungkinan DDR5 server ECC | **Dikonfirmasi sebagai inferensi** | Emerald Rapids **hanya** mendukung DDR5 (sampai 5600 MT/s, 8 kanal, ECC). DMI/dmidecode tidak tersedia di tamu, jadi tipe modul tidak terlihat langsung. Bandwidth yang diukur di VM setara dual-channel DDR5, bukan 8 kanal penuh. |

---

## 3. Identitas CPU

### 3.1 Yang terbaca di tamu (terukur)

Perintah: `lscpu`, `lscpu -C`, `cat /proc/cpuinfo`.

| Item | Nilai |
| --- | --- |
| Model name (tamu) | `Intel(R) Xeon(R) Processor` (SKU asli disembunyikan hypervisor) |
| Vendor | GenuineIntel |
| Architecture | x86_64, hypervisor KVM, virtualization full, VT-x |
| CPU(s) | 8 online (0–7) |
| Thread per core | **1** (SMT/HT tidak diekspos ke tamu) |
| Core per socket / socket | 8 / 1 |
| CPU family / model / stepping | **6 / 207 / 2** (model 207 = 0xCF; 7-Zip menampilkan CPUID **C06F2**) |
| Microcode (tamu) | 0x1 (nilai hypervisor, bukan microcode host) |
| `cpu MHz` di /proc | 2400,000 tetap (ini **frekuensi TSC** yang diiklankan KVM, **bukan** clock nyata) |
| BogoMIPS | 4800,00 |
| Frequency scaling | Tidak ada `cpufreq` di tamu |
| NUMA | 1 node (node0, CPU 0–7) |
| L1d | 48 KiB × 8 = 384 KiB (12-way) |
| L1i | 32 KiB × 8 = 256 KiB |
| L2 | 2 MiB × 8 = 16 MiB |
| L3 | **320 MiB**, 1 instance, 20-way (nilai paket host; lihat catatan cache di bawah) |
| Flag penting | AVX, AVX2, AVX-512 (f/dq/cd/bw/vl/vnni/bf16/fp16/vbmi/vbmi2/bitalg/vpopcntdq/ifma), **AMX** (amx_bf16, amx_tile, amx_int8), avx_vnni, VAES, SHA-NI, VMX |
| Batas cgroup | `cpu.max = max`, `memory.max = max` (tidak ada kuota CPU/RAM di cgroup `/agent`) |
| Address sizes (tamu) | 46 bit fisik, 57 bit virtual (host bare-metal 8592+ biasanya 52 bit fisik; KVM menutup sebagian) |

Clock nyata diukur 7-Zip sendiri (bukan dari `/proc/cpuinfo`):

- 1 thread: **3.808–3.961 MHz** (sekitar **3,9 GHz**)
- 4 thread: ~3.874–3.881 MHz, usage ~397–398%
- 8 thread: ~3.566–3.652 MHz, usage ~738–754%

Jadi inti bisa turbo dekat 3,9 GHz saat 1–4 thread, dan tetap sekitar 3,6 GHz saat 8 thread sibuk.

### 3.2 Generasi dan SKU host (inferensi + sumber Intel)

- CPUID family 6, model **0xCF (207)** adalah **Emerald Rapids**. Kernel Linux memetakannya sebagai `INTEL_FAM6_EMERALDRAPIDS_X`. Intel menandai family-model-stepping **0x06-0xCF-0x02** sebagai **EMR-A1**.
  - [Intel In-Field Scan, EMR-A1 0x06-0xCF-0x02](https://www.intel.com/content/www/us/en/support/products/236644/processors/intel-xeon-processors/5th-gen-intel-xeon-scalable-processors.html)
  - [Coelacanth's Dream: CPUID EMR 0xCF](https://www.coelacanth-dream.com/posts/2022/11/07/intel-emr-cpuid-model/)
- L3 **320 MB** hanya ada di SKU **64-inti** Emerald Rapids (5 MB L3 per inti × 64). Itu bukan cache eksklusif 8 vCPU ini; tamu melihat LLC paket host.
  - [Tom's Hardware: EMR sampai 64 inti, 320 MB L3](https://www.tomshardware.com/pc-components/cpus/intel-5th-gen-xeon-emerald-rapids-pushes-up-to-64-cores-320mb-l3-cache-new-cpus-claim-up-to-14x-higher-performance-than-sapphire-rapids)
- SKU 64-inti 320 MB L3, semua max turbo **3,9 GHz** (cocok dengan ukur 1T ~3,9 GHz):
  - Platinum **8592+**: 64C/128T, base 1,9 GHz, turbo 3,9 GHz, all-core turbo 2,9 GHz, TDP 350 W, DDR5-5600, 8 kanal, ECC
    - [Intel ARK 8592+](https://www.intel.com/content/www/us/en/products/sku/237261/intel-xeon-platinum-8592-processor-320m-cache-1-90-ghz/specifications.html)
    - [Supermicro: all-core turbo 2,9 GHz / max 3,9 GHz](https://www.supermicro.com/en/support/resources/cpu-5th-gen-intel-xeon-scalable)
  - Platinum **8592V**: 64C, base 2,0 GHz, turbo 3,9 GHz, TDP 330 W
    - [Intel ARK 8592V](https://www.intel.com/content/www/us/en/products/sku/237554/intel-xeon-platinum-8592v-processor-320m-cache-2-00-ghz/specifications.html)
  - Platinum **8593Q**: 64C, base 2,2 GHz, turbo 3,9 GHz, TDP 385 W
    - [Intel ARK 8593Q](https://www.intel.com/content/www/us/en/products/sku/237252/intel-xeon-platinum-8593q-processor-320m-cache-2-20-ghz/specifications.html)

**Kesimpulan:** host adalah Xeon Emerald Rapids 64-inti dengan 320 MB L3. SKU pastinya tidak terbaca di tamu. Turbo 3,9 GHz cocok untuk 8592+ / 8592V / 8593Q. Box ini hanya mendapat **8 inti fisik tanpa SMT**.

**Catatan cache (terukur, penting):** meski CPUID mengiklankan L3 320 MB, uji pointer-chase menunjukkan latensi “masih seperti cache” hanya sampai sekitar **32 MB** (~45 ns), lalu loncat ke **136 ns** pada 64 MB (sudah seperti DRAM). Artinya 320 MB itu LLC paket host; bagian yang benar-benar “hangat” bagi VM ini jauh lebih kecil — wajar di host 64-inti yang dibagi banyak tamu, plus latensi mesh antar-tile.

---

## 4. Perintah yang dipakai

Alat: **sysbench 1.0.20**, **7-Zip 26.06** (`7zz` resmi dari 7-zip.org), **fio 3.43** (dikompilasi di box, ioengine libaio), **mbw 1.2.2**, STREAM dan memlat buatan sendiri (gcc -O3 -march=native; STREAM memakai OpenMP 8 thread, array 2,24 GiB agar melebihi L3).

```bash
# CPU
sysbench cpu --cpu-max-prime=10000 --threads=1 --time=30 --events=0 run
sysbench cpu --cpu-max-prime=10000 --threads=8 --time=30 --events=0 run
/workspace/bench-tools/7zip/7zz b -mmt=1
/workspace/bench-tools/7zip/7zz b

# Memori (sysbench often mengukur cache, bukan DRAM — lihat catatan)
sysbench memory --threads=1 --memory-block-size=1M --memory-total-size=200G \
  --memory-oper=write --memory-access-mode=seq run
sysbench memory --threads=8 --memory-block-size=1M --memory-total-size=400G \
  --memory-oper=write --memory-access-mode=seq run
sysbench memory --threads=8 --memory-block-size=1M --memory-total-size=400G \
  --memory-oper=read --memory-access-mode=seq run
sysbench memory --threads=8 --memory-block-size=4K --memory-total-size=100G \
  --memory-oper=write --memory-access-mode=rnd run
mbw -n 3 1024
OMP_NUM_THREADS=8 /workspace/bench-tools/stream
/workspace/bench-tools/memlat

# Disk: berkas uji 2 GiB di /workspace, O_DIRECT, libaio, 25 detik, lalu dihapus
fio --name=seqread-1M-QD32  --filename=/workspace/fio-test.bin --size=2G \
  --rw=read --bs=1M --iodepth=32 --ioengine=libaio --direct=1 \
  --time_based --runtime=25 --group_reporting
fio --name=seqwrite-1M-QD32 --filename=/workspace/fio-test.bin --size=2G \
  --rw=write --bs=1M --iodepth=32 --ioengine=libaio --direct=1 \
  --time_based --runtime=25 --group_reporting
fio --name=randread-4k-QD32 --filename=/workspace/fio-test.bin --size=2G \
  --rw=randread --bs=4k --iodepth=32 --norandommap --ioengine=libaio --direct=1 \
  --time_based --runtime=25 --group_reporting
fio --name=randwrite-4k-QD32 --filename=/workspace/fio-test.bin --size=2G \
  --rw=randwrite --bs=4k --iodepth=32 --norandommap --ioengine=libaio --direct=1 \
  --time_based --runtime=25 --group_reporting
fio --name=randread-4k-QD1 --filename=/workspace/fio-test.bin --size=2G \
  --rw=randread --bs=4k --iodepth=1 --norandommap --ioengine=libaio --direct=1 \
  --time_based --runtime=25 --group_reporting
fio --name=randwrite-4k-QD1 --filename=/workspace/fio-test.bin --size=2G \
  --rw=randwrite --bs=4k --iodepth=1 --norandommap --ioengine=libaio --direct=1 \
  --time_based --runtime=25 --group_reporting
```

Geekbench dilewati (berat, tidak perlu setelah 7-Zip + sysbench).

---

## 5. Hasil CPU (terukur)

### 5.1 sysbench cpu (prime 10.000, 30 detik)

| Thread | Events/s | Events total | Latensi rata-rata | 95th |
| --- | ---: | ---: | ---: | ---: |
| 1 | **3.306,94** | 99.214 | 0,30 ms | 0,34 ms |
| 8 | **25.636,41** | 769.136 | 0,31 ms | 0,35 ms |

Skalanya **7,75×** pada 8 thread (efisiensi 96,9%). Fairness 8 thread sedikit timpang (stddev 827 events) karena ada beban latar.

### 5.2 7-Zip 26.06 — 1 thread (`7zz b -mmt=1`)

Clock 1T yang diukur 7-Zip: 3961, 3939, 3902, 3808, 3869, 3872, 3903 MHz.

```
                       Compressing  |                  Decompressing
Dict     Speed Usage    R/U Rating  |      Speed Usage    R/U Rating
         KiB/s     %   MIPS   MIPS  |      KiB/s     %   MIPS   MIPS
22:       6180   100   6010   6013  |      83324   100   7104   7114
23:       5894   101   5966   6006  |      84081   100   7298   7278
24:       6119   100   6550   6579  |      82650   100   7253   7256
25:       4910   100   5620   5607  |      81807   100   7269   7281
Avr:      5776   100   6037   6051  |      82965   100   7231   7232
Tot:             100   6634   6642
```

**Yang dipakai untuk banding:** Compress **6.051 MIPS**, Decompress **7.232 MIPS**, **Tot 6.642 MIPS**.

### 5.3 7-Zip 26.06 — 8 thread (`7zz b`)

Clock 8T: 738% usage @ 3566 MHz dan 754% @ 3652 MHz.

```
Avr:     58003   686   8808  60528  |     617035   737   7293  53732
Tot:             712   8050  57130
```

**Yang dipakai untuk banding:** Compress **60.528 MIPS**, Decompress **53.732 MIPS**, **Tot 57.130 MIPS**.

---

## 6. Setara CPU konsumen (dari sumber, lalu dibandingkan)

Situs [7-cpu.com](https://www.7-cpu.com/) adalah acuan klasik MIPS 7-Zip, tetapi tabel utamanya tidak memuat SKU desktop 2022–2024 yang relevan (i5-13400, 7600, 7700X, dll.). Perbandingan di bawah memakai angka **7-Zip Single** dan **7-Zip** (semua thread) dari Technical City dan Notebookcheck. Peringatan: mereka sering memakai 7-Zip 18.03, kita memakai **26.06**, jadi beda beberapa persen mungkin berasal dari versi, bukan hanya dari CPU.

| CPU (desktop) | 7-Zip 1 thread (Tot, MIPS) | 7-Zip semua thread (MIPS) | Sumber |
| --- | ---: | ---: | --- |
| **komputerbox10 (8c / 8t, ~3,9 GHz)** | **6.642** | **57.130** | Terukur, 7-Zip 26.06 |
| Intel Core i5-13400 (6P+4E / 16t, turbo 4,6 GHz) | 5.829 | 59.510 | [Technical City: i5-13400 vs Ryzen 5 7600](https://technical.city/en/cpu/Core-i5-13400-vs-Ryzen-5-7600) |
| AMD Ryzen 5 7600 (6c / 12t, turbo 5,1 GHz) | 7.566 | 64.613 | Sumber yang sama |
| AMD Ryzen 7 7700X (8c / 16t, turbo 5,4 GHz) | 8.074 | 85.707 | [Technical City: 7700X vs i7-14700](https://technical.city/en/cpu/Ryzen-7-7700X-vs-Core-i7-14700), [Notebookcheck 7700X](https://www.notebookcheck.net/AMD-Ryzen-7-7700X-Processor-Benchmarks-and-Specs.671261.0.html) (ST rata-rata 8.074; MT rata-rata 85.707) |

Cara bacanya:

- **Satu thread:** komputerbox10 ≈ **di tengah i5-13400 dan Ryzen 5 7600**. 6.642 / 5.829 ≈ **+14%** vs i5-13400; 6.642 / 7.566 ≈ **88%** Ryzen 5 7600; 6.642 / 8.074 ≈ **82%** Ryzen 7 7700X. Ini masuk akal: inti Emerald Rapids memakai arsitektur Raptor Cove (sekeluarga dengan P-core Raptor Lake), tetapi turbo di sini ~3,9 GHz, sedangkan i5-13400 sampai 4,6 GHz dan 7600/7700X sampai 5,1–5,4 GHz.
- **Delapan thread:** 57.130 / 59.510 ≈ **96% i5-13400** — hampir imbang dengan satu PC i5-13400. 57.130 / 64.613 ≈ **88% Ryzen 5 7600**. 57.130 / 85.707 ≈ **67% Ryzen 7 7700X**. Jadi **bukan** “satu PC 8-inti kelas 7700X”. Lebih jujur: **satu PC kelas i5-13400 / Ryzen 5 7600**, dengan 8 inti penuh tanpa hyper-threading.

---

## 7. RAM: bandwidth, latensi, dan setara DDR

### 7.1 Kapasitas (terukur)

- `free -h`: **15 GiB** total, ~11 GiB available saat awal, **tanpa swap**.
- MemTotal: **16.386.368 KiB** ≈ 15,625 GiB (kelas cloud 16 GiB, sebagian dipakai kernel/hypervisor).
- dmidecode dan `/sys/class/dmi` **tidak ada** di tamu, jadi tipe modul (DDR5-xxxx, ECC, jumlah DIMM) tidak terbaca langsung.

### 7.2 Bandwidth DRAM — STREAM (terukur, acuan utama)

Array 3 × 100 juta double = **2,24 GiB**, di atas L3, 8 thread OpenMP, 8 iterasi, GB/s = 10⁹ byte/s.

| Fungsi | Terbaik (GB/s) | Rata-rata (GB/s) |
| --- | ---: | ---: |
| Copy | 87,22 | 78,30 |
| Scale | 83,16 | 75,08 |
| Add | 94,54 | 81,10 |
| **Triad** | **94,99** | **79,76** |

### 7.3 mbw dan sysbench (terukur, dengan catatan)

**mbw** 1024 MiB, 3 jalan, **1 thread**:

| Metode | Rata-rata |
| --- | ---: |
| MEMCPY | 4.862 MiB/s (~5,1 GB/s) |
| DUMB | 9.892 MiB/s |
| MCBLOCK | 9.961 MiB/s (~10,4 GB/s) |

MCBLOCK 1 thread ~10 GB/s konsisten dengan STREAM Copy 87 GB/s / 8 thread ≈ 11 GB/s per thread.

**sysbench memory** (working set kecil, cenderung **cache**, bukan DRAM):

| Uji | MiB/s | Catatan |
| --- | ---: | --- |
| 1T seq write, blok 1 MiB | 33.882 | Masih bisa meraih cache |
| 8T seq write, blok 1 MiB | 114.441 | Campuran cache/DRAM |
| 8T seq read, blok 1 MiB | **325.229** (~341 GB/s) | Ini **bandwidth cache (L3)**, bukan DRAM |
| 8T rnd write, blok 4 KiB | 867 | Tidak dipakai untuk setara DDR |

Jangan memakai 325 GB/s sebagai angka RAM.

### 7.4 Latensi pointer-chase (terukur)

Akses acak berantai, stride 64 byte:

| Ukuran | ns/akses | Kira-kira di mana |
| ---: | ---: | --- |
| 16–48 KiB | **1,27–1,32** | L1d (48 KiB) |
| 128 KiB–1 MiB | **4,06–5,16** | L2 (2 MiB) |
| 2 MiB | 14,25 | Batas L2 |
| 4–32 MiB | 32,5–44,7 | L3 yang “dekat” |
| 64 MiB | **136** | Mulai DRAM / L3 jauh |
| 128–256 MiB | 149–185 | DRAM + virtualisasi |
| 384 MiB–1 GiB | **179–206** | DRAM tamu (EPT/KVM) |

L1 ~5 siklus pada 3,9 GHz; L2 ~16–20 siklus — wajar untuk server modern. Latensi DRAM 180–206 ns lebih tinggi daripada DDR5 bare-metal tipikal (~80–100 ns) karena biaya KVM/EPT.

### 7.5 Setara DDR (sumber + inferensi)

Bandwidth teoritis (lebar 64 bit per kanal):

| Konfigurasi | Rumus | Teoritis |
| --- | --- | ---: |
| DDR4-3200 dual-channel | 3.200 MT/s × 8 B × 2 | **51,2 GB/s** |
| DDR5-4800 dual-channel | 4.800 × 8 × 2 | 76,8 GB/s |
| DDR5-5600 dual-channel | 5.600 × 8 × 2 | **89,6 GB/s** |
| DDR5-5600 8 kanal (satu soket EMR) | 5.600 × 8 × 8 | **358,4 GB/s** |

Sumber rumus: [macmyths, bandwidth per generasi](https://macmyths.com/guide-ddr-ddr2-ddr3-ddr4-and-ddr5-bandwidth-by-generation/); angka yang sama di [systemcheck.live](https://systemcheck.live/memory).

Emerald Rapids resmi: **DDR5 @ 5600 MT/s (1 DPC)**, **8 kanal**, **ECC**. Tidak ada DDR4.
- [Intel ARK 8592+, Memory Specifications](https://www.intel.com/content/www/us/en/products/sku/237261/intel-xeon-platinum-8592-processor-320m-cache-1-90-ghz/specifications.html)
- [Intel newsroom, 5th Gen Xeon](https://www.intel.com/content/www/us/en/newsroom/news/5th-gen-xeon-data-center-news.html)

**Inferensi untuk VM ini:**

- **Tipe host:** DDR5 ECC server, hingga DDR5-5600, 8 kanal. Tidak bisa memastikan kecepatan DIMM persis (5600 vs 4800/5200) dari dalam tamu.
- **Yang terasa di VM:** STREAM Triad rata-rata **80 GB/s** (~89% dari 89,6 GB/s teoritis dual-channel DDR5-5600). Nilai terbaik 95 GB/s sedikit di atas plafon 2 kanal — wajar untuk “best of N” atau karena VM mendapat sedikit lebih dari 2 kanal dari pengontrol 8 kanal host. Ini **jauh di atas** DDR4-3200 dual-channel (STREAM nyata biasanya ~40–45 GB/s, teoritis 51,2).
- Jadi, mudahnya: **RAM yang kamu pakai terasa seperti DDR5 dual-channel 5600 di PC desktop**, meskipun di belakangnya itu irisan dari RAM server 8 kanal. Bukan 8 kanal penuh (itu akan mendekati 250–300+ GB/s STREAM).

---

## 8. Disk: angka fio dan kelas SSD

### 8.1 Identitas (terukur)

| Item | Nilai |
| --- | --- |
| Perangkat | `/dev/vda` dan `/dev/vdb`, masing-masing 128 G, virtio |
| Root | `/dev/vdb` ext4, **125 G** (terpakai 24 G, sisa 102 G saat diukur) |
| `rotational` | 1 (sering **bohong** pada virtio; jangan diartikan sebagai HDD) |
| Scheduler | mq-deadline |
| Sector | 512 B logis/fisik |
| Write cache | write-through |
| Discard | tidak ada (`discard_max_bytes=0`) |

### 8.2 fio 3.43, berkas 2 GiB, `libaio`, `direct=1`, 25 detik (terukur)

| Uji | Bandwidth | IOPS | Latensi khas |
| --- | ---: | ---: | --- |
| Seq baca 1M QD32 | **2.782 MiB/s (2.917 MB/s)** | 2.781 | clat p50 ~10,9 ms (blok 1 MiB) |
| Seq tulis 1M QD32 | **2.211 MiB/s (2.319 MB/s)** | 2.211 | clat p50 ~12,9 ms |
| Random 4K baca QD32 | 1.235 MiB/s (1.295 MB/s) | **316.000** | clat p50 **96 µs** |
| Random 4K tulis QD32 | 907 MiB/s (951 MB/s) | **232.000** | clat p50 **109 µs** |
| Random 4K baca QD1 | 230 MiB/s (241 MB/s) | **58.800** | lat p50 **13 µs** |
| Random 4K tulis QD1 | 186 MiB/s (195 MB/s) | **47.500** | lat p50 **16 µs** |

Penuangan awal berkas 2 GiB: tulis 1.616 MiB/s (1.695 MB/s). Berkas uji sudah dihapus.

**Peringatan:** `direct=1` hanya melewati page cache *tamu*. Hypervisor masih bisa menyimpan 2 GiB di cache host, terutama terlihat pada QD1 yang sangat kencang (13–16 µs, 47–59k IOPS). Angka sequential ~2,3–2,9 GB/s jauh di bawah bandwidth RAM (80–95 GB/s), jadi ini **bukan** ramdisk murni, tetapi random QD1 mungkin dibantu cache host. Anggap sequential dan random QD32 sebagai acuan kelas yang lebih aman.

### 8.3 Kelas SSD (inferensi)

Acuan kasar kelas konsumen/server:

| Kelas | Seq baca/tulis khas | Random 4K QD32 khas |
| --- | --- | --- |
| HDD | 100–250 MB/s | ratusan–beberapa ribu IOPS |
| SATA SSD | ~500–550 MB/s | puluhan ribu–~100k IOPS |
| **NVMe Gen3** | **~2.000–3.500 MB/s** | **~200k–500k IOPS** |
| NVMe Gen4 desktop | ~5.000–7.000 MB/s | ~700k–1.000k+ IOPS |

**Kesimpulan:** `/dev/vdb` kelas **NVMe Gen3** (atau Gen4 yang dibatasi QoS cloud di sekitar 3 GB/s). Jelas bukan SATA dan bukan HDD. Belum mencapai NVMe Gen4 desktop penuh. Di virtio, ini tampil sebagai disk paravirtual, bukan sebagai perangkat NVMe mentah.

---

## 9. Setara cloud dan harga (sumber, 2026)

Bentuk terdekat yang umum: **AWS EC2 c7i.2xlarge** — 8 vCPU, 16 GiB, compute-optimized, Intel (keluarga c7i = **Sapphire Rapids**, bukan Emerald Rapids).

Harga on-demand yang diverifikasi dari beberapa agregator yang diperbarui November 2026 (semua dalam USD, tanpa storage/jaringan tambahan):

| Wilayah | $/jam | $/bulan (730 jam) | Sumber |
| --- | ---: | ---: | --- |
| US East, N. Virginia (**us-east-1**) | **0,3570** | **260,61** | [Holori, update 8 Nov 2026](https://calculator.holori.com/aws/ec2/c7i.2xlarge), [Economize, 13 Nov 2026](https://www.economize.cloud/resources/aws/pricing/ec2/c7i.2xlarge/), [CloudQuell](https://cloud.cloudquell.com/aws/ec2/c7i.2xlarge/), [aws-pricing.com](https://aws-pricing.com/c7i.2xlarge.html) |
| Asia Pacific, **Jakarta (ap-southeast-3)** | **0,4116** | **300,47** | [aws-pricing.com, ap-southeast-3](https://aws-pricing.com/c7i.2xlarge.html) (sama dengan Singapore ap-southeast-1) |

Klaim lama “±$0,36/jam atau ±$260/bulan” adalah pembulatan harga **us-east-1**, dan **benar**. Kalau dibandingkan dengan wilayah pengguna (Jakarta), patokan yang lebih relevan adalah **$0,41/jam / $300/bulan**.

Cadangan 1 tahun no-upfront us-east-1 sekitar $0,2362/jam ($172,40/bulan); spot fluktuatif, bukan harga tetap.

---

## 10. Armada 30 node sejenis komputerbox10

Asumsi: 30 mesin **identik** dengan box ini, dijumlahkan. Ini **bukan** satu komputer besar.

### 10.1 Total kapasitas (kertas)

| Item | Per node | 30 node | Catatan |
| --- | ---: | ---: | --- |
| vCPU (tanpa SMT) | 8 | **240 vCPU** | Inti penuh, bukan 240 thread HT |
| RAM terlihat (`free -h`) | 15 GiB | **450 GiB** | Sesuai patokan “15 GiB” |
| RAM MemTotal | 15,625 GiB | ≈ **469 GiB** | |
| RAM kelas cloud | 16 GiB | **480 GiB** | |
| Disk root terpakai/kapasitas | 125 GB usable | **3,75 TB** (≈ 3,66 TiB) | Mentah 128 G × 30 = 3,84 TB |
| 7-Zip Tot 8-thread | 57.130 MIPS | **1.713.900 MIPS** | Hanya kalau 30 job jalan bersamaan |
| 7-Zip compress 8-thread | 60.528 | 1.815.840 | |
| 7-Zip decompress 8-thread | 53.732 | 1.611.960 | |
| sysbench cpu 8-thread | 25.636 events/s | **769.092** events/s | |
| STREAM Triad (terbaik) | 94,99 GB/s | 2.850 GB/s agregat | **Bukan** satu kumpulan memori |
| fio seq baca | 2.917 MB/s | ≈ 87,5 GB/s agregat | Sama: 30 disk terpisah |

Setelah cap pemakaian **≤85%** (kebijakan node):

- CPU terpakai ≈ **0,85 × 240 = 204 vCPU**
- RAM terpakai ≈ **0,85 × 450 ≈ 383 GiB**

### 10.2 Setara yang mudah dipahami

- **Desktop konsumen:** 30 node ≈ **30 PC setara Core i5-13400** pada 7-Zip multi-thread (57.130 vs 59.510 per mesin, hampir 1:1). Versus Ryzen 7 7700X (85.707 MIPS), 1.713.900 / 85.707 ≈ **20 PC 7700X**. Jadi armada 30 box ≈ 30 PC kelas i5-13400, atau kira-kira 20 PC kelas 7700X, **asal 30 job terpisah** yang tidak perlu berbagi memori.
- **Satu server besar (hanya analogi jumlah inti/thread, bukan arsitektur yang sama):**
  - 240 inti tanpa SMT ≈ **dua server 2-socket 60-inti** (2 × 2 × 60 = 240 inti), atau sedikit di atas satu server 2-socket 64-inti (128 inti).
  - Kalau dihitung thread: dual-socket Xeon 8592+ = 128 inti / **256 thread**; dual-socket EPYC 128-inti (misalnya EPYC 9754/9755) = 256 thread. Angka “256 thread” kira-kira dekat dengan 240 vCPU ini, tetapi sifatnya berbeda (SMT vs inti penuh, satu mesin vs 30 mesin).
- **Biaya cloud 30× c7i.2xlarge, on-demand, 24/7** (harga terverifikasi di atas; belum termasuk disk, IP, dan transfer):

  | Wilayah | Per jam | Per bulan (730 jam) |
  | --- | ---: | ---: |
  | us-east-1 | 30 × $0,3570 = **$10,71/jam** | 30 × $260,61 = **$7.818,30/bulan** |
  | Jakarta ap-southeast-3 | 30 × $0,4116 = **$12,35/jam** | 30 × $300,47 = **$9.014,10/bulan** |

  Itu patokan “kalau 30 instans setara disewa terus-menerus di AWS”. Box sendiri tidak ditagih dengan tarif itu.

### 10.3 Caveat — ini 30 mesin terpisah, bukan satu mesin raksasa

1. **Tidak ada RAM bersama.** Satu job hanya melihat ~15 GiB (praktis lebih kecil setelah cap 85%, OS, Ray, dan cache). Job yang butuh 32–64 GiB **tidak muat** di satu node, dan tidak bisa “menggabungkan” RAM 30 mesin.
2. **Job hanya paralel antar node lewat antrean VPS.** Satu job tidak otomatis dipecah ke 30 mesin. Total 1,7 juta MIPS hanya tercapai jika banyak job berjalan bersamaan. Satu job raksasa tetap terbatas 8 vCPU / ~15 GiB, kecuali mode cluster Ray dinyalakan khusus (dan itu pun beda model, plus dependensi head).
3. **Box bisa tidur saat idle** dan perlu dibangunin (webhook dari VPS ke bot watchdog, atau cadangan lain). Kapasitas “240 vCPU selalu siap” tidak berlaku kalau aplikasi ditutup atau platform menidurkan mesin.
4. **Cap ≤85%** menurunkan kapasitas terpakai ke ≈204 vCPU / ≈383 GiB. Angka benchmark di atas adalah plafon mesin, bukan kuota kerja yang kamu izinkan.
5. **Jaringan ke VPS di-relay, around 190 ms.** Bukan datacenter local 0,2–1 ms. Cocok untuk job kasar (backtest, training CPU, batch), kurang nyaman untuk chatty I/O kecil bolak-balik ke VPS, database jauh, atau lag ketat.
6. Bandwidth memori dan disk **tidak bisa dijumlahkan menjadi satu pool**. 2.850 GB/s atau 87 GB/s disk adalah 30 pipa terpisah.

---

## 11. Cocok untuk apa

**Quantitative trading (backtest, riset, training CPU):** cocok. Delapan inti Raptor Cove di ~3,6–3,9 GHz, skala hampir linear, RAM bandwidth setara DDR5 dual-channel, disk NVMe Gen3. Batas paling ketat adalah **RAM ~15 GiB** (lebih longgar untuk dataset yang masuk memori sebagian atau diproses berbatch) dan **tidak ada GPU**. Training model besar berbasis GPU tidak bisa dijalankan di sini. Satu job training CPU yang butuh RAM atau inti lebih dari satu mesin tidak akan “tumpah” ke node lain tanpa desain khusus (checkpoint + antrean, atau cluster).

**DePIN (Golem dan yang butuh KVM):** `/dev/kvm` dan VT-x tersedia, jadi menjalankan VM tamu untuk workload seperti Golem secara teknis memungkinkan. Batas praktis: 16 GiB RAM, 8 vCPU, tidak ada GPU, disk 125 GB, plus cap 85%, plus mesin yang bisa tidur. Cocok untuk slot DePIN ringan/sedang yang mengisi sisa kapasitas, bukan untuk menjanjikan VM besar atau GPU.

**Armada 30 node:** kekuatan utamanya adalah **banyak job sedang yang jalan bersamaan** (backtest QT, worker antrean), bukan satu supercomputer. Urutan yang sudah disepakati (QT dulu, DePIN mengisi sisa) tetap masuk akal.

---

## 12. Daftar sumber

**Identitas CPU**

- [Intel ARK, Xeon Platinum 8592+](https://www.intel.com/content/www/us/en/products/sku/237261/intel-xeon-platinum-8592-processor-320m-cache-1-90-ghz/specifications.html)
- [Intel ARK, Xeon Platinum 8592V](https://www.intel.com/content/www/us/en/products/sku/237554/intel-xeon-platinum-8592v-processor-320m-cache-2-00-ghz/specifications.html)
- [Intel ARK, Xeon Platinum 8593Q](https://www.intel.com/content/www/us/en/products/sku/237252/intel-xeon-platinum-8593q-processor-320m-cache-2-20-ghz/specifications.html)
- [Intel Support, 5th Gen Xeon, EMR-A1 0x06-0xCF-0x02](https://www.intel.com/content/www/us/en/support/products/236644/processors/intel-xeon-processors/5th-gen-intel-xeon-scalable-processors.html)
- [Intel newsroom, 5th Gen Xeon (DDR5-5600, 8 kanal)](https://www.intel.com/content/www/us/en/newsroom/news/5th-gen-xeon-data-center-news.html)
- [Tom's Hardware, Emerald Rapids 64 inti / 320 MB L3](https://www.tomshardware.com/pc-components/cpus/intel-5th-gen-xeon-emerald-rapids-pushes-up-to-64-cores-320mb-l3-cache-new-cpus-claim-up-to-14x-higher-performance-than-sapphire-rapids)
- [Supermicro, tabel 5th Gen Xeon (all-core vs max turbo)](https://www.supermicro.com/en/support/resources/cpu-5th-gen-intel-xeon-scalable)
- [Coelacanth's Dream, CPUID model 0xCF](https://www.coelacanth-dream.com/posts/2022/11/07/intel-emr-cpuid-model/)
- [OpenBenchmarking, contoh cpuinfo 8592+ family 6 model 207 stepping 2, cache 327680 KB](https://openbenchmarking.org/s/INTEL+XEON+PLATINUM+8592%2B)

**7-Zip / CPU konsumen**

- [Technical City, i5-13400 vs Ryzen 5 7600 (7-Zip Single 5829 / 7566, multi 59510 / 64613)](https://technical.city/en/cpu/Core-i5-13400-vs-Ryzen-5-7600)
- [Technical City, Ryzen 7 7700X vs i7-14700 (7-Zip Single 8074, multi 85707)](https://technical.city/en/cpu/Ryzen-7-7700X-vs-Core-i7-14700)
- [Notebookcheck, Ryzen 7 7700X 7-Zip 18.03 (ST ≈ 8074, MT ≈ 85707 MIPS)](https://www.notebookcheck.net/AMD-Ryzen-7-7700X-Processor-Benchmarks-and-Specs.671261.0.html)
- [7-cpu.com](https://www.7-cpu.com/) — acuan metode MIPS; SKU desktop 2023 tidak ditemukan di tabel utama saat diakses 16 Nov 2026

**RAM**

- [macmyths, bandwidth teoritis DDR4/DDR5](https://macmyths.com/guide-ddr-ddr2-ddr3-ddr4-and-ddr5-bandwidth-by-generation/)
- [systemcheck.live, memory speed tiers](https://systemcheck.live/memory)
- [Fujitsu, memori Sapphire/Emerald Rapids (DDR5 sampai 5600, 8 kanal, ECC)](https://sp.ts.fujitsu.com/dmsp/Publications/public/wp-sapphirerapids-memory-performance-ww-en.pdf)

**Cloud**

- [Holori, c7i.2xlarge $0,3570/jam us-east-1 (update 8 Nov 2026)](https://calculator.holori.com/aws/ec2/c7i.2xlarge)
- [Economize, $0,3570/jam / $260,61/bulan (13 Nov 2026)](https://www.economize.cloud/resources/aws/pricing/ec2/c7i.2xlarge/)
- [CloudQuell, matriks us-east-1 dan regional](https://cloud.cloudquell.com/aws/ec2/c7i.2xlarge/)
- [aws-pricing.com/c7i.2xlarge.html](https://aws-pricing.com/c7i.2xlarge.html) (us-east-1 $0,357; ap-southeast-3 $0,4116; $300,47/bulan)

---

## 13. Catatan pengukuran

- Semua uji dijalankan sebagai user `box` di tamu KVM, kernel `6.12.94+`, Senin 16 Nov 2026 malam (WIB).
- Layanan produksi tidak dihentikan.
- 7-Zip 26.06 vs review yang memakai 18.03: bandingkan tren, bukan selisih 2–3%.
- STREAM adalah implementasi McCalpin-like (Copy/Scale/Add/Triad), array 2,24 GiB, OpenMP 8 thread; satuan GB/s desimal (10⁹ byte).
- fio memakai O_DIRECT di tamu; cache host masih mungkin membantu, terutama QD1.
- TSC 2,4 GHz di `/proc/cpuinfo` jangan dipakai sebagai clock CPU; pakai ukur 7-Zip (~3,9 / ~3,6 GHz).
