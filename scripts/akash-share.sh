#!/usr/bin/env bash
# Share math for an Akash slice on a Linux Grokbox.
# optimal is 10% CPU and 10% RAM. The 25 and 50 shares are the larger caps.
# At least 2 GB of RAM stays outside the Akash cap.
# Sourcing this file does not install packages and does not write /etc.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Source this file. Run scripts/setup-akash-grokbox.sh." >&2
  exit 1
fi

# 2 * 1024 * 1024 * 1024. The 2 GB reserve outside the Akash RAM cap.
readonly AKASH_RAM_RESERVE_BYTES=2147483648

akash_share_canonical() {
  local raw=${1:-}
  local key=${raw,,}
  case "$key" in
    optimal) printf '%s\n' optimal ;;
    25|25%) printf '%s\n' 25 ;;
    50|50%) printf '%s\n' 50 ;;
    *)
      echo "unknown share: ${raw}" >&2
      return 1
      ;;
  esac
}

akash_share_percent() {
  local name
  name=$(akash_share_canonical "$1") || return 1
  case "$name" in
    optimal) printf '%s\n' 10 ;;
    25) printf '%s\n' 25 ;;
    50) printf '%s\n' 50 ;;
    *)
      echo "unknown share: ${name}" >&2
      return 1
      ;;
  esac
}

akash_share_cpu_percent() {
  akash_share_percent "$1"
}

akash_share_ram_percent() {
  akash_share_percent "$1"
}

akash_cpu_count_ok() {
  local ncpu=${1:-}
  local n
  [[ "$ncpu" =~ ^[0-9]+$ ]] || return 1
  n=$((10#$ncpu))
  [[ "$n" -ge 1 && "$n" -le 4096 ]]
}

# systemd CPUQuota is a percent of one CPU. 10% of 4 CPUs is 40.
akash_cpu_quota_percent() {
  local ncpu=${1:-}
  local percent=${2:-}
  local quota full
  akash_cpu_count_ok "$ncpu" || return 2
  [[ "$percent" =~ ^(10|25|50)$ ]] || return 2
  quota=$((10#$ncpu * 10#$percent))
  full=$((10#$ncpu * 100))
  if [[ "$quota" -ge "$full" ]]; then
    echo "cpu cap would cover the whole machine" >&2
    return 2
  fi
  printf '%s\n' "$quota"
}

# Docker --cpus value, three decimal places.
akash_docker_cpus() {
  local ncpu=${1:-}
  local percent=${2:-}
  local milli
  akash_cpu_count_ok "$ncpu" || return 2
  [[ "$percent" =~ ^(10|25|50)$ ]] || return 2
  milli=$((10#$ncpu * 10#$percent * 10))
  printf '%d.%03d\n' $((milli / 1000)) $((milli % 1000))
}

# RAM bytes for the Akash slice. Never above the chosen percent.
# When the percent would leave less than the 2 GB reserve, the cap shrinks.
akash_ram_cap_bytes() {
  local total=${1:-}
  local percent=${2:-}
  local requested max_allowed cap
  [[ "$total" =~ ^[0-9]+$ ]] || return 2
  [[ "$percent" =~ ^(10|25|50)$ ]] || return 2
  requested=$((10#$total * 10#$percent / 100))
  if [[ "$((10#$total))" -le "$AKASH_RAM_RESERVE_BYTES" ]]; then
    max_allowed=0
  else
    max_allowed=$((10#$total - AKASH_RAM_RESERVE_BYTES))
  fi
  if [[ "$requested" -lt "$max_allowed" ]]; then
    cap=$requested
  else
    cap=$max_allowed
  fi
  printf '%s\n' "$cap"
}

# Fields: name percent cap outside quota cpus clamped
akash_share_row() {
  local share=${1:-}
  local ncpu=${2:-}
  local total=${3:-}
  local name percent cap outside quota cpus requested clamped
  name=$(akash_share_canonical "$share") || return 1
  percent=$(akash_share_percent "$name") || return 1
  cap=$(akash_ram_cap_bytes "$total" "$percent") || return 1
  outside=$((10#$total - 10#$cap))
  quota=$(akash_cpu_quota_percent "$ncpu" "$percent") || return 1
  cpus=$(akash_docker_cpus "$ncpu" "$percent") || return 1
  requested=$((10#$total * 10#$percent / 100))
  if [[ "$cap" -lt "$requested" ]]; then
    clamped=yes
  else
    clamped=no
  fi
  printf '%s %s %s %s %s %s %s\n' \
    "$name" "$percent" "$cap" "$outside" "$quota" "$cpus" "$clamped"
}

akash_print_share_fields() {
  local ncpu=${1:?} total=${2:?}
  local name row rname percent cap outside quota cpus clamped
  for name in optimal 25 50; do
    row=$(akash_share_row "$name" "$ncpu" "$total") || return 1
    read -r rname percent cap outside quota cpus clamped <<<"$row"
    printf 'akash.share.%s.cpu_percent=%s\n' "$rname" "$percent"
    printf 'akash.share.%s.ram_percent=%s\n' "$rname" "$percent"
    printf 'akash.share.%s.cpu_quota_percent=%s\n' "$rname" "$quota"
    printf 'akash.share.%s.docker_cpus=%s\n' "$rname" "$cpus"
    printf 'akash.share.%s.ram_cap_bytes=%s\n' "$rname" "$cap"
    printf 'akash.share.%s.ram_outside_bytes=%s\n' "$rname" "$outside"
    printf 'akash.share.%s.ram_cap_clamped=%s\n' "$rname" "$clamped"
  done
}

akash_render_share_conf() {
  local share=${1:?} ncpu=${2:?} total=${3:?}
  local row name percent cap outside quota cpus clamped
  row=$(akash_share_row "$share" "$ncpu" "$total") || return 1
  read -r name percent cap outside quota cpus clamped <<<"$row"
  cat <<EOF
# Akash slice only. Website and quantitative-trading stay outside this cap.
# The 2 GB reserve is ram_reserve_bytes. VPS is not a provider.
# This file does not mean Akash is installed.
share=${name}
cpu_percent=${percent}
ram_percent=${percent}
cpu_count=${ncpu}
ram_total_bytes=${total}
ram_cap_bytes=${cap}
ram_outside_bytes=${outside}
ram_reserve_bytes=${AKASH_RAM_RESERVE_BYTES}
ram_cap_clamped=${clamped}
cpu_quota_percent=${quota}
docker_cpus=${cpus}
docker_memory_bytes=${cap}
docker_memory_swap_bytes=${cap}
docker_cgroup_parent=akash.slice
EOF
}

akash_render_slice_unit() {
  local quota=${1:?}
  local mem=${2:?}
  [[ "$quota" =~ ^[0-9]+$ ]] || return 2
  [[ "$mem" =~ ^[0-9]+$ ]] || return 2
  if [[ "$((10#$mem))" -le 0 || "$((10#$quota))" -le 0 ]]; then
    echo "slice cap must be positive" >&2
    return 2
  fi
  cat <<EOF
[Unit]
Description=CPU and memory cap for the Akash slice
Documentation=file:///etc/depin/akash-share.conf

[Slice]
# Website and quantitative-trading must not run in this slice.
CPUAccounting=yes
MemoryAccounting=yes
CPUQuota=${quota}%
MemoryMax=${mem}
EOF
}

akash_hostname_is_grokbox() {
  local name=${1,,}
  name=${name%.}
  [[ "$name" == grokbox* ]]
}

akash_os_is_linux() {
  [[ "$1" == Linux ]]
}

akash_live_hostname() {
  local name
  name=$(hostname -s 2>/dev/null || true)
  if [[ -z "$name" ]]; then
    name=$(hostname 2>/dev/null || true)
  fi
  name=${name//$'\n'/}
  printf '%s\n' "$name"
}

akash_live_os() {
  uname -s
}

# Reasons, in order: bad-host, bad-share, no-ram, bad-cpu, need-root.
# Prints the reason or ok. Returns 0 only for ok.
akash_apply_gate() {
  local host=${1:-}
  local os=${2:-}
  local euid=${3:-}
  local share=${4:-}
  local ram_cap=${5:-}
  local ncpu=${6:-}
  if ! akash_os_is_linux "$os" || ! akash_hostname_is_grokbox "$host"; then
    printf '%s\n' bad-host
    return 1
  fi
  if ! akash_share_canonical "$share" >/dev/null 2>&1; then
    printf '%s\n' bad-share
    return 1
  fi
  if [[ ! "$ram_cap" =~ ^[0-9]+$ ]] || [[ "$((10#$ram_cap))" -le 0 ]]; then
    printf '%s\n' no-ram
    return 1
  fi
  if ! akash_cpu_count_ok "$ncpu"; then
    printf '%s\n' bad-cpu
    return 1
  fi
  if [[ ! "$euid" =~ ^[0-9]+$ ]] || [[ "$((10#$euid))" -ne 0 ]]; then
    printf '%s\n' need-root
    return 1
  fi
  printf '%s\n' ok
  return 0
}

akash_write_atomic() {
  local dest=${1:?}
  local dir tmp
  dir=$(dirname -- "$dest") || return 2
  mkdir -p -- "$dir" || return 2
  tmp=$(mktemp "${dir}/.tmp.XXXXXX") || return 2
  if ! cat >"$tmp"; then
    rm -f -- "$tmp"
    return 2
  fi
  chmod 644 -- "$tmp" || {
    rm -f -- "$tmp"
    return 2
  }
  mv -f -- "$tmp" "$dest" || {
    rm -f -- "$tmp"
    return 2
  }
}

# Write the share config and the systemd slice under "$root".
# A root of / is refused unless the live machine passes the Grokbox gate
# and the caller passes --system. The dry path must not call this.
akash_write_cap_files() {
  local root=${1:?}
  local share=${2:?}
  local ncpu=${3:?}
  local total=${4:?}
  local system=${5:-}
  local resolved row name percent cap outside quota cpus clamped
  local conf slice conf_path slice_path live_host live_os decision

  if [[ "$root" != /* ]]; then
    echo "cap root must be an absolute path" >&2
    return 2
  fi
  case "$root" in
    *..*)
      echo "cap root must not contain .." >&2
      return 2
      ;;
  esac
  if [[ -d "$root" ]]; then
    resolved=$(cd -- "$root" && pwd -P) || return 2
  else
    resolved=$root
  fi

  if [[ "$resolved" == "/" ]]; then
    if [[ "$system" != "--system" ]]; then
      echo "refusing to write /etc without --system" >&2
      return 2
    fi
    live_host=$(akash_live_hostname)
    live_os=$(akash_live_os)
    row=$(akash_share_row "$share" "$ncpu" "$total") || return 2
    read -r name percent cap outside quota cpus clamped <<<"$row"
    if ! decision=$(akash_apply_gate "$live_host" "$live_os" "$EUID" "$share" "$cap" "$ncpu"); then
      echo "refusing system write: ${decision}" >&2
      return 2
    fi
  fi

  row=$(akash_share_row "$share" "$ncpu" "$total") || return 2
  read -r name percent cap outside quota cpus clamped <<<"$row"
  if [[ "$cap" -le 0 ]]; then
    echo "ram cap is zero; not writing" >&2
    return 2
  fi
  if [[ "$outside" -lt "$AKASH_RAM_RESERVE_BYTES" ]]; then
    echo "ram outside the cap is below the 2 GB reserve; not writing" >&2
    return 2
  fi

  conf=$(akash_render_share_conf "$name" "$ncpu" "$total") || return 2
  slice=$(akash_render_slice_unit "$quota" "$cap") || return 2
  conf_path="${resolved%/}/etc/depin/akash-share.conf"
  slice_path="${resolved%/}/etc/systemd/system/akash.slice"
  akash_write_atomic "$conf_path" <<<"$conf" || return 2
  if ! akash_write_atomic "$slice_path" <<<"$slice"; then
    rm -f -- "$conf_path"
    return 2
  fi
}
