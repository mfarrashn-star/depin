# Tailscale: depin

> Mengikuti aturan umum di [`TAILSCALE.md`](../TAILSCALE.md)

Diperbarui 15 November 2026. Repo ini masih hampir kosong. Isi di bawah adalah kerangka, plus fakta tailnet yang sudah ada. Yang belum diputuskan untuk repo ini ditandai **belum ditentukan**. Jangan menulis auth key, kata sandi, atau rahasia lain di berkas ini.

## Node yang dipakai

Fakta tailnet yang sudah ada (milik bersama, bukan keputusan khusus repo ini):

- VPS Windows `WIN-T65VC2J9G31`, IP Tailscale `100.103.231.61`, user SSH `Administrator`
- `komputerbox10`, komputer Grok Bot, IP Tailscale `100.116.213.30`
- Nama lama `grokbot-box` mungkin masih ada di tailnet; jangan dicabut tanpa konfirmasi

Peran node khusus untuk DePIN: **belum ditentukan**.

## Framework komputasi

**Belum ditentukan.** Pedoman umum ada di `TAILSCALE.md` bagian 5. Head Ray yang sedang disiapkan di `komputerbox10` bukan keputusan repo ini.

## Ketersediaan node

Mengikuti `TAILSCALE.md` bagian 4. Autostart tanpa agent tidak dijamin di komputer Grok Bot. Node yang wajib 24/7 tanpa agent harus Linux VPS dengan systemd. Syarat ketersediaan khusus DePIN: **belum ditentukan**.

## Cara menjalankan / deploy

**Belum ditentukan.**

SSH ke VPS Windows memakai OpenSSH biasa plus kata sandi, bukan Tailscale SSH. Connector Tailscale terkelola di Grok Bot hanya HTTP, jangan dipakai untuk SSH.

## Data dan storage

**Belum ditentukan.**

## Catatan khusus

- Funnel tetap mati, kecuali ada keputusan baru dari pemilik.
- Jangan menulis rahasia ke repo.
- Setelah keputusan DePIN ada, ganti penanda “belum ditentukan” di dokumen ini pada PR yang sama.
