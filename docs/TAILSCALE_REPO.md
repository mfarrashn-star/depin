# Tailscale: depin

> Aturan umum: [TAILSCALE.md](TAILSCALE.md). Baca dokumen ini sebelum menerapkan bagian 4 dokumen umum.

Repo ini publik. Hostname tailnet, IP, sidik SSH, auth key, dan sandi tidak ditulis di sini.

## Node yang dipakai

Target kluster, belum berjalan:

- Satu VPS sebagai penghubung dan titik pusat. Bukan pekerja DePIN.
- Sampai sekitar 30 node `Grokbox1`, `Grokbox2`, dan seterusnya sebagai pekerja komputasi.
- Akun Cursor grup ditambahkan nanti, satu per satu, setelah dicek. Dokumen ini tidak membuat node.

Pemeriksaan tailnet pada 15 November 2026, sekitar 21.13 WIB:

- VPS Windows sedang online.
- Satu node Linux sedang offline. Speknya belum terbaca.
- Satu ponsel sedang offline. Ponsel bukan pekerja DePIN.
- Laptop tidak muncul.
- Belum ada 30 Grokbox.

Nama mesin yang sudah ada dan berada di luar konvensi tidak diganti dari dokumen ini.

## Framework komputasi

Beban repo ini adalah DePIN. Calon jaringan adalah Akash: CPU dan disk disewakan dari Grokbox, bukan dari VPS.

Akash bukan prioritas. Website dan quantitative-trading harus tetap hidup. Akash hanya boleh memakai sisa compute, dengan buffer, dan tidak pernah 100% CPU atau RAM satu mesin.

Docker memisahkan proses website dan trading dari proses DePIN. Mining tidak dipakai, karena mining mengunci CPU di 100%.

Akash belum dipasang. Jangan menyalakannya sebelum satu Grokbox terukur dan, sesudah buffer, masih memenuhi syarat provider di Linux. Angka buffer belum dikunci. Usulan yang menunggu konfirmasi: sisakan minimal 25% CPU, 25% RAM, dan 2 GB terakhir untuk sistem dan layanan sendiri. Jika sisa itu di bawah syarat provider, node itu tidak menjalankan Akash.

## Ketersediaan node

VPS tetap hidup. Putusnya Grokbox tidak boleh mematikan website atau trading.

Bagian 4 dokumen umum berlaku untuk mesin Linux baru setelah konfirmasi. Jangan reboot VPS.

## Cara menjalankan / deploy

Belum ada perintah deploy. Node baru, auth key, tag, dan Funnel butuh konfirmasi. Funnel tetap mati.

## Data dan storage

Disk untuk DePIN ada di Grokbox. Disk VPS tidak dipakai untuk itu. Database website tetap Supabase, di luar repo ini.

## Catatan khusus

- VPS yang terukur pada pemeriksaan ini: 8 vCPU, 16 GB RAM, Windows, disk sistem hampir penuh. Mesin itu tidak menjadi provider.
- Perkalian 30 node belum bisa dihitung. Spek satu Grokbox belum terbaca.
- Permintaan sewa CPU di jaringan semacam Akash tipis. Jangan mengalihkan 30 node sebagai janji pemasukan.
