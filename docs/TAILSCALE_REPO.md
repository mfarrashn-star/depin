# Tailscale: depin

> Aturan umum: [TAILSCALE.md](TAILSCALE.md). Baca dokumen ini sebelum menerapkan bagian 4 dokumen umum.

Repo ini publik. Hostname tailnet, IP, sidik SSH, auth key, dan sandi tidak ditulis di sini.

## Node yang dipakai

Target kluster, belum berjalan:

- Satu VPS sebagai penghubung. CPU-nya untuk layanan yang harus tetap hidup dan untuk pekerjaan yang terikat akun di mesin itu. Bukan pekerja DePIN.
- Komputer yang tetap hidup adalah komputer Grok Bot, satu per akun. Nama yang direncanakan untuk akun ini: `KomputerBox25`. Pada 15 November 2026, 22.27 WIB, Grok Bot belum dibuka, jadi komputer itu tidak disambungkan.
- Cursor web bukan komputer itu. Sesi Cursor web mati bersama agen dan tidak diberi nama `KomputerBox25`.
- Nama lama `grokbox-p4` dan `CloudGrokBox25` tidak dipakai. Node lain ditambahkan kemudian.

Pemeriksaan tailnet pada 15 November 2026, 22.17 WIB:

- VPS Windows sedang online pada pemeriksaan 22.17 WIB.
- Komputer Grok Bot belum masuk, karena aplikasinya belum dibuka pada 22.27 WIB.
- Laptop tidak muncul.
- Belum ada 30 KomputerBox.

Sesi Cursor web dibiarkan. Sesi itu bukan komputer Grok Bot.

## Framework komputasi

Beban repo ini adalah DePIN. Calon jaringan adalah Akash: CPU dan disk disewakan dari KomputerBox, bukan dari VPS.

Akash bukan prioritas. Website dan quantitative-trading harus tetap hidup. Akash hanya boleh memakai sisa compute, dengan buffer, dan tidak pernah 100% CPU atau RAM satu mesin.

Batas per KomputerBox:

- Saat agen AI sedang berjalan, bandwidth dan storage untuk DePIN paling besar 80%.
- Saat agen AI diam, bandwidth dan storage boleh naik sampai 95%.
- Jika beban 80% saat agen berjalan membuat agen tidak responsif, turunkan jatah DePIN otomatis sampai compute untuk agen longgar. Naikkan lagi ketika beban mereda.
- VPS (FPS) tidak ikut DePIN sama sekali: tidak ada disk, CPU, maupun bandwidth.

Docker memisahkan proses website dan trading dari proses DePIN. Mining tidak dipakai, karena mining mengunci CPU di 100%.

Akash belum dipasang. Pasang di `KomputerBox25` setelah mesin itu online, terukur, dan sisa compute sesudah batas di atas masih memenuhi syarat provider di Linux. Jika sisa itu di bawah syarat provider, node itu tidak menjalankan Akash. Sesi agen yang ikut mati tidak menjalankan Akash.

## Ketersediaan node

VPS tetap hidup. Putusnya KomputerBox tidak boleh mematikan website atau trading.

Bagian 4 dokumen umum berlaku untuk mesin Linux baru setelah konfirmasi. Jangan reboot VPS.

## Cara menjalankan / deploy

Belum ada perintah deploy. Node baru, auth key, tag, dan Funnel butuh konfirmasi. Funnel tetap mati.

## Data dan storage

Disk dan bandwidth untuk DePIN ada di KomputerBox, dengan batas di bagian Framework komputasi. VPS (FPS) tidak menyewakan disk, CPU, atau bandwidth. Database website tetap Supabase, di luar repo ini.

## Catatan khusus

- VPS yang terukur pada pemeriksaan ini: 8 vCPU, 16 GB RAM, Windows, disk sistem hampir penuh. Mesin itu tidak menjadi provider.
- Perkalian 30 node belum bisa dihitung. Spek satu KomputerBox belum terbaca.
- Permintaan sewa CPU di jaringan semacam Akash tipis. Jangan mengalihkan 30 node sebagai janji pemasukan.
