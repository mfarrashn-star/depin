#!/usr/bin/env bash
# Explain or apply an Akash CPU/RAM cap on a Linux Grokbox.
# Without --confirm this script only explains and exits non-zero.
# It does not install packages. The VPS is not a provider.

set -euo pipefail

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Run this script; do not source it." >&2
  return 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=akash-share.sh
source "${SCRIPT_DIR}/akash-share.sh"

usage() {
  cat <<EOF
Pemakaian:
  ${0} [--share optimal|25|50]
  ${0} --share optimal|25|50 --confirm

Tanpa --confirm, skrip menjelaskan jatah Akash lalu keluar dengan status bukan nol.
Tidak ada berkas yang ditulis. Tidak ada paket yang dipasang.

--confirm menerapkan batas hanya di Linux yang hostname-nya diawali grokbox.
Pilihan tersimpan di /etc/depin/akash-share.conf.
Batas cgroup ada di /etc/systemd/system/akash.slice.

Jatah irisan Akash saja:
  optimal  10% CPU dan 10% RAM
  25       25% CPU dan 25% RAM
  50       50% CPU dan 50% RAM

Minimal 2 GB RAM tetap di luar batas itu. VPS bukan provider.
EOF
}

share=""
share_set=no
confirm=no

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --confirm)
      confirm=yes
      shift
      ;;
    --share)
      if [[ $# -lt 2 ]]; then
        echo "Butuh nilai setelah --share: optimal, 25, atau 50." >&2
        exit 1
      fi
      if [[ "$share_set" == yes ]]; then
        echo "--share hanya boleh sekali." >&2
        exit 1
      fi
      share=$2
      share_set=yes
      shift 2
      ;;
    --share=*)
      if [[ "$share_set" == yes ]]; then
        echo "--share hanya boleh sekali." >&2
        exit 1
      fi
      share=${1#--share=}
      share_set=yes
      shift
      ;;
    *)
      echo "Argumen tidak dikenal: $1" >&2
      exit 1
      ;;
  esac
done

host=$(akash_live_hostname)
os=$(akash_live_os)
if akash_hostname_is_grokbox "$host" && akash_os_is_linux "$os"; then
  host_ok=yes
else
  host_ok=no
fi

read_cpu_count() {
  local n
  n=$(nproc 2>/dev/null || true)
  if [[ ! "$n" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  printf '%s\n' "$((10#$n))"
}

read_ram_total_bytes() {
  local kb
  kb=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)
  if [[ ! "$kb" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  printf '%s\n' "$((10#$kb * 1024))"
}

selected=none
if [[ "$share_set" == yes ]]; then
  if selected=$(akash_share_canonical "$share" 2>/dev/null); then
    :
  else
    selected=invalid
  fi
fi

print_machine_fields() {
  local status=$1
  local write_flag=$2
  local reason=${3:-}
  printf 'akash.status=%s\n' "$status"
  printf 'akash.confirm=%s\n' "$confirm"
  printf 'akash.hostname=%s\n' "$host"
  printf 'akash.os=%s\n' "$os"
  printf 'akash.host_ok=%s\n' "$host_ok"
  printf 'akash.write=%s\n' "$write_flag"
  printf 'akash.reserve_bytes=%s\n' "$AKASH_RAM_RESERVE_BYTES"
  printf 'akash.selected=%s\n' "$selected"
  if [[ -n "$reason" ]]; then
    printf 'akash.reason=%s\n' "$reason"
  fi
  if akash_cpu_count_ok "${cpu_count}" && [[ "${ram_total}" =~ ^[0-9]+$ ]]; then
    printf 'akash.cpu_count=%s\n' "$cpu_count"
    printf 'akash.ram_total_bytes=%s\n' "$ram_total"
    akash_print_share_fields "$cpu_count" "$ram_total"
  else
    printf '%s\n' "akash.math=unavailable"
  fi
}

cpu_count=$(read_cpu_count || true)
ram_total=$(read_ram_total_bytes || true)
if [[ -z "$cpu_count" ]]; then
  cpu_count=0
fi
if [[ -z "$ram_total" ]]; then
  ram_total=0
fi

explain_dry() {
  local example
  print_machine_fields dry no
  cat <<EOF

Ini penjelasan saja. Tidak ada berkas yang ditulis. Tidak ada paket yang dipasang.

Akash hanya untuk satu irisan di Grokbox Linux. VPS bukan provider.
Website dan quantitative-trading tetap di luar irisan ini.
Akash tidak pernah mendapat 100% CPU atau RAM.

Pilihan, untuk irisan Akash saja:
  optimal  10% CPU dan 10% RAM. Jatah kecil. Sisanya untuk website dan trading.
  25       25% CPU dan 25% RAM.
  50       50% CPU dan 50% RAM. Batas atas di skrip ini.

Minimal 2 GB RAM tetap di luar batas RAM Akash.
Kalau persentase memotong cadangan itu, batas RAM Akash diturunkan.
Persentase CPU tetap pada pilihan itu.
Proses Akash harus masuk slice akash.slice. Website dan trading tidak masuk slice itu.

Hostname mesin ini: ${host}. OS: ${os}.
EOF
  if [[ "$host_ok" == yes ]]; then
    echo "Hostname ini diawali grokbox. Batas belum diterapkan karena --confirm tidak ada."
  else
    echo "Mesin ini bukan Grokbox Linux. Jalur terapkan akan menolak."
  fi
  if [[ "$selected" == invalid ]]; then
    echo "Pilihan share tidak dikenal. Pakai optimal, 25, atau 50."
  fi
  if [[ "$selected" == none || "$selected" == invalid ]]; then
    example=optimal
  else
    example=$selected
  fi
  cat <<EOF
Berkas ini ditulis hanya saat --confirm di Grokbox:
  /etc/depin/akash-share.conf
  /etc/systemd/system/akash.slice
Contoh nanti, sebagai root di Grokbox:
  sudo ${0} --share ${example} --confirm
EOF
}

refusal_text() {
  local reason=$1
  case "$reason" in
    bad-host)
      echo "Menolak: hostname atau OS ini bukan Grokbox Linux."
      ;;
    bad-share)
      echo "Menolak: pilih --share optimal, 25, atau 50."
      ;;
    no-ram)
      echo "Menolak: RAM tidak cukup untuk menyisakan 2 GB di luar batas Akash."
      ;;
    bad-cpu)
      echo "Menolak: jumlah CPU tidak terbaca."
      ;;
    need-root)
      echo "Menolak: jalankan sebagai root di Grokbox."
      ;;
    *)
      echo "Menolak: ${reason}."
      ;;
  esac
  echo "Tidak ada berkas yang ditulis. Tidak ada paket yang dipasang."
  echo "VPS bukan provider."
}

apply_caps() {
  local decision="" cap=0 canonical="" percent="" quota
  if [[ "$selected" != invalid && "$selected" != none ]]; then
    canonical=$selected
    percent=$(akash_share_percent "$canonical")
    if ! cap=$(akash_ram_cap_bytes "$ram_total" "$percent"); then
      cap=0
    fi
  fi
  if ! decision=$(akash_apply_gate "$host" "$os" "$EUID" "$share" "$cap" "$cpu_count"); then
    print_machine_fields refused no "$decision"
    echo
    refusal_text "$decision"
    return 1
  fi
  if [[ -z "$canonical" || -z "${percent:-}" ]]; then
    print_machine_fields refused no bad-share
    echo
    refusal_text bad-share
    return 1
  fi
  if ! akash_write_cap_files / "$canonical" "$cpu_count" "$ram_total" --system; then
    print_machine_fields refused no not-applied
    echo
    echo "Menolak: batas tidak ditulis."
    echo "Tidak ada paket yang dipasang."
    return 1
  fi
  if ! command -v systemctl >/dev/null 2>&1; then
    print_machine_fields refused yes systemd-missing
    echo
    echo "Berkas batas sudah ditulis, tetapi systemd tidak ada. Slice belum aktif."
    return 1
  fi
  quota=$(akash_cpu_quota_percent "$cpu_count" "$percent")
  if ! systemctl daemon-reload; then
    print_machine_fields refused yes slice-not-started
    echo
    echo "Berkas batas sudah ditulis, tetapi slice belum aktif."
    return 1
  fi
  if systemctl is-active --quiet akash.slice; then
    if ! systemctl set-property --runtime akash.slice "CPUQuota=${quota}%" "MemoryMax=${cap}"; then
      print_machine_fields refused yes slice-not-started
      echo
      echo "Berkas batas sudah ditulis, tetapi cgroup yang hidup belum memakai angka baru."
      return 1
    fi
  elif ! systemctl start akash.slice; then
    print_machine_fields refused yes slice-not-started
    echo
    echo "Berkas batas sudah ditulis, tetapi slice belum aktif."
    return 1
  fi
  print_machine_fields applied yes
  echo
  echo "Batas irisan Akash diterapkan. Website dan quantitative-trading tetap di luar slice ini."
  echo "Tidak ada paket yang dipasang."
}

if [[ "$confirm" != yes ]]; then
  explain_dry
  exit 2
fi

apply_caps
exit 0
