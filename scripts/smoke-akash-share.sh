#!/usr/bin/env bash
# Check Akash share math and the non-Grokbox refusal.
# Does not install Akash or Docker and does not write /etc.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
# shellcheck source=akash-share.sh
source "${SCRIPT_DIR}/akash-share.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  local got=$1 want=$2 label=$3
  if [[ "$got" != "$want" ]]; then
    fail "${label}: got '${got}' want '${want}'"
  fi
}

assert_cmd_fails() {
  local label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "${label} succeeded"
  fi
}

if bash "${SCRIPT_DIR}/akash-share.sh" >/dev/null 2>&1; then
  fail "library should not run as a program"
fi

assert_eq "$AKASH_RAM_RESERVE_BYTES" 2147483648 "reserve constant"
assert_eq "$(akash_share_cpu_percent optimal)" 10 "optimal cpu"
assert_eq "$(akash_share_ram_percent optimal)" 10 "optimal ram"
assert_eq "$(akash_share_cpu_percent OPTIMAL)" 10 "OPTIMAL cpu"
assert_eq "$(akash_share_cpu_percent 25)" 25 "25 cpu"
assert_eq "$(akash_share_ram_percent 25%)" 25 "25% ram"
assert_eq "$(akash_share_cpu_percent 50)" 50 "50 cpu"
assert_eq "$(akash_share_ram_percent 50%)" 50 "50% ram"
assert_eq "$(akash_share_canonical optimal)" optimal "canonical optimal"
assert_eq "$(akash_share_canonical 25%)" 25 "canonical 25"
assert_eq "$(akash_share_canonical 50%)" 50 "canonical 50"

assert_cmd_fails "share 10" akash_share_canonical 10
assert_cmd_fails "share 100" akash_share_canonical 100
assert_cmd_fails "share mining" akash_share_canonical mining
assert_cmd_fails "share empty" akash_share_canonical ""
assert_cmd_fails "ram percent 100" akash_ram_cap_bytes 4294967296 100
assert_cmd_fails "cpu percent 100" akash_cpu_quota_percent 4 100

for name in optimal 25 50 Optimal "25%" "50%"; do
  cpu=$(akash_share_cpu_percent "$name")
  ram=$(akash_share_ram_percent "$name")
  assert_eq "$cpu" "$ram" "cpu matches ram for ${name}"
done

gib=$((1024 * 1024 * 1024))
reserve=$AKASH_RAM_RESERVE_BYTES

assert_eq "$(akash_ram_cap_bytes 0 10)" 0 "zero ram"
assert_eq "$(akash_ram_cap_bytes $((reserve - 1)) 50)" 0 "below reserve"
assert_eq "$(akash_ram_cap_bytes "$reserve" 10)" 0 "exactly reserve 10"
assert_eq "$(akash_ram_cap_bytes "$reserve" 25)" 0 "exactly reserve 25"
assert_eq "$(akash_ram_cap_bytes "$reserve" 50)" 0 "exactly reserve 50"

# reserve + 1 byte: every share clamps to 1 byte so 2 GB stays outside.
assert_eq "$(akash_ram_cap_bytes $((reserve + 1)) 10)" 1 "clamp 10"
assert_eq "$(akash_ram_cap_bytes $((reserve + 1)) 25)" 1 "clamp 25"
assert_eq "$(akash_ram_cap_bytes $((reserve + 1)) 50)" 1 "clamp 50"

three_gib=$((3 * gib))
assert_eq "$(akash_ram_cap_bytes "$three_gib" 50)" "$gib" "3 GiB at 50% clamps to 1 GiB"
assert_eq "$(akash_ram_cap_bytes "$three_gib" 10)" $((three_gib * 10 / 100)) "3 GiB at 10% fits"

four_gib=$((4 * gib))
assert_eq "$(akash_ram_cap_bytes "$four_gib" 10)" $((four_gib * 10 / 100)) "4 GiB at 10%"
assert_eq "$(akash_ram_cap_bytes "$four_gib" 25)" $((four_gib * 25 / 100)) "4 GiB at 25%"
assert_eq "$(akash_ram_cap_bytes "$four_gib" 50)" $((four_gib / 2)) "4 GiB at 50% leaves exactly 2 GiB"

sixteen_gib=$((16 * gib))
assert_eq "$(akash_ram_cap_bytes "$sixteen_gib" 10)" $((sixteen_gib * 10 / 100)) "16 GiB optimal"
assert_eq "$(akash_ram_cap_bytes "$sixteen_gib" 25)" $((sixteen_gib * 25 / 100)) "16 GiB 25"
assert_eq "$(akash_ram_cap_bytes "$sixteen_gib" 50)" $((sixteen_gib * 50 / 100)) "16 GiB 50"

totals=(
  0
  1
  $((reserve - 1))
  "$reserve"
  $((reserve + 1))
  "$three_gib"
  "$four_gib"
  "$sixteen_gib"
)
for total in "${totals[@]}"; do
  for percent in 10 25 50; do
    cap=$(akash_ram_cap_bytes "$total" "$percent")
    outside=$((total - cap))
    requested=$((total * percent / 100))
    if [[ "$cap" -gt "$requested" ]]; then
      fail "cap exceeds percent for total=${total} percent=${percent}"
    fi
    if [[ $((cap + outside)) -ne "$total" ]]; then
      fail "cap plus outside != total for total=${total}"
    fi
    if [[ "$total" -gt 0 && "$cap" -ge "$total" ]]; then
      fail "cap took the whole machine for total=${total} percent=${percent}"
    fi
    if [[ "$total" -ge "$reserve" && "$outside" -lt "$reserve" ]]; then
      fail "2 GB reserve broken for total=${total} percent=${percent}"
    fi
  done
done

assert_eq "$(akash_cpu_quota_percent 4 10)" 40 "quota optimal 4 cpu"
assert_eq "$(akash_docker_cpus 4 10)" 0.400 "docker optimal 4 cpu"
assert_eq "$(akash_cpu_quota_percent 4 25)" 100 "quota 25 4 cpu"
assert_eq "$(akash_docker_cpus 4 25)" 1.000 "docker 25 4 cpu"
assert_eq "$(akash_cpu_quota_percent 4 50)" 200 "quota 50 4 cpu"
assert_eq "$(akash_docker_cpus 4 50)" 2.000 "docker 50 4 cpu"
assert_eq "$(akash_cpu_quota_percent 8 25)" 200 "quota 25 8 cpu"
assert_eq "$(akash_docker_cpus 8 50)" 4.000 "docker 50 8 cpu"
assert_eq "$(akash_docker_cpus 1 25)" 0.250 "docker 25 1 cpu"
assert_eq "$(akash_docker_cpus 3 25)" 0.750 "docker 25 3 cpu"
assert_cmd_fails "zero cpu" akash_cpu_quota_percent 0 10
assert_cmd_fails "cpu too wide" akash_cpu_quota_percent 4097 10

for ncpu in 1 3 4 8 32; do
  for percent in 10 25 50; do
    quota=$(akash_cpu_quota_percent "$ncpu" "$percent")
    full=$((ncpu * 100))
    if [[ "$quota" -ge "$full" ]]; then
      fail "cpu quota covers the machine: ncpu=${ncpu} percent=${percent}"
    fi
    assert_eq "$quota" $((ncpu * percent)) "quota ${ncpu} ${percent}"
  done
done

expect_host() {
  local name=$1 want=$2 got
  if akash_hostname_is_grokbox "$name"; then
    got=yes
  else
    got=no
  fi
  assert_eq "$got" "$want" "hostname ${name}"
}

expect_host grokbox25 yes
expect_host Grokbox25 yes
expect_host GROKBOX25 yes
expect_host grokbox-p4 yes
expect_host Grokbox1 yes
expect_host grokbox yes
expect_host "grokbox25.example" yes
expect_host cursor no
expect_host vps no
expect_host VPS no
expect_host notgrokbox no
expect_host xgrokbox no
expect_host grok no
expect_host "" no

assert_gate() {
  local want=$1
  shift
  local got rc
  set +e
  got=$(akash_apply_gate "$@")
  rc=$?
  set -e
  if [[ "$want" == ok ]]; then
    [[ "$rc" -eq 0 ]]
  else
    [[ "$rc" -ne 0 ]]
  fi
  assert_eq "$got" "$want" "gate ${want}"
}

assert_gate bad-host cursor Linux 0 optimal 1000 4
assert_gate bad-host grokbox25 Windows 0 optimal 1000 4
assert_gate bad-host "" Linux 0 optimal 1000 4
assert_gate bad-share grokbox25 Linux 0 mining 1000 4
assert_gate bad-share grokbox25 Linux 1000 mining 0 0
assert_gate bad-host cursor Linux 0 mining 0 0
assert_gate no-ram grokbox25 Linux 0 optimal 0 4
assert_gate bad-cpu grokbox25 Linux 0 optimal 1000 0
assert_gate need-root grokbox25 Linux 1000 optimal 1000 4
assert_gate ok grokbox25 Linux 0 optimal 1000 4
assert_gate ok Grokbox25 Linux 0 25% 1000 8
assert_gate ok grokbox-p4 Linux 0 50 1000 1

live_host=$(akash_live_hostname)
if akash_hostname_is_grokbox "$live_host"; then
  fail "this machine looks like a Grokbox; smoke will not apply a cap"
fi

row=$(akash_share_row optimal 4 "$sixteen_gib")
read -r rname rpercent rcap routside rquota rcpus rclamped <<<"$row"
assert_eq "$rname" optimal "row name"
assert_eq "$rpercent" 10 "row percent"
assert_eq "$rcap" $((sixteen_gib * 10 / 100)) "row cap"
assert_eq "$routside" $((sixteen_gib - rcap)) "row outside"
assert_eq "$rquota" 40 "row quota"
assert_eq "$rcpus" 0.400 "row docker"
assert_eq "$rclamped" no "row clamp"

row=$(akash_share_row 50 4 "$three_gib")
read -r rname rpercent rcap routside rquota rcpus rclamped <<<"$row"
assert_eq "$rpercent" 50 "clamped row keeps 50% label"
assert_eq "$rcap" "$gib" "clamped row ram"
assert_eq "$routside" "$reserve" "clamped row outside"
assert_eq "$rquota" 200 "clamped row cpu stays 50%"
assert_eq "$rclamped" yes "clamped row flag"

root=$(mktemp -d)
trap 'case "${root:-}" in /tmp/*) rm -rf "$root" ;; esac' EXIT
akash_write_cap_files "$root" optimal 4 "$sixteen_gib"
conf="${root}/etc/depin/akash-share.conf"
slice="${root}/etc/systemd/system/akash.slice"
[[ -f "$conf" ]] || fail "missing conf"
[[ -f "$slice" ]] || fail "missing slice"
assert_eq "$(stat -c %a "$conf")" 644 "conf mode"
(
  # shellcheck disable=SC1090
  source "$conf"
  [[ "$share" == optimal ]]
  [[ "$cpu_percent" == 10 ]]
  [[ "$ram_percent" == 10 ]]
  [[ "$ram_reserve_bytes" == "$reserve" ]]
  [[ "$ram_cap_clamped" == no ]]
  [[ "$docker_cgroup_parent" == akash.slice ]]
  [[ "$cpu_quota_percent" == 40 ]]
  [[ "$docker_cpus" == 0.400 ]]
  [[ "$docker_memory_bytes" == "$ram_cap_bytes" ]]
  [[ "$docker_memory_swap_bytes" == "$ram_cap_bytes" ]]
  [[ $((ram_outside_bytes)) -ge "$reserve" ]]
)
grep -F "CPUQuota=40%" "$slice" >/dev/null || fail "slice quota"
grep -F "MemoryMax=$((sixteen_gib * 10 / 100))" "$slice" >/dev/null || fail "slice memory"

akash_write_cap_files "$root" 50 4 "$three_gib"
(
  # shellcheck disable=SC1090
  source "$conf"
  [[ "$share" == 50 ]]
  [[ "$cpu_percent" == 50 ]]
  [[ "$ram_percent" == 50 ]]
  [[ "$ram_cap_bytes" == "$gib" ]]
  [[ "$ram_outside_bytes" == "$reserve" ]]
  [[ "$ram_cap_clamped" == yes ]]
  [[ "$cpu_quota_percent" == 200 ]]
)
grep -F "CPUQuota=200%" "$slice" >/dev/null || fail "clamped slice quota"
grep -F "MemoryMax=${gib}" "$slice" >/dev/null || fail "clamped slice memory"

small=$(mktemp -d)
if akash_write_cap_files "$small" 50 4 "$reserve"; then
  fail "wrote a cap when the 2 GB reserve leaves Akash no RAM"
fi
[[ ! -e "${small}/etc/depin/akash-share.conf" ]] || fail "conf written with zero cap"
rm -rf "$small"

mkdir_log=$(mktemp)
if (
  mkdir() {
    printf '%s\n' "$*" >>"$mkdir_log"
    command mkdir "$@"
  }
  akash_write_cap_files / optimal 4 "$sixteen_gib" --system
); then
  fail "system write on this machine returned 0"
fi
[[ ! -s "$mkdir_log" ]] || fail "system write called mkdir: $(cat "$mkdir_log")"
[[ ! -e /etc/depin/akash-share.conf ]] || fail "/etc config was written"
[[ ! -e /etc/systemd/system/akash.slice ]] || fail "akash.slice was written"
rm -f "$mkdir_log"

if akash_write_cap_files / optimal 4 "$sixteen_gib"; then
  fail "write to / without --system returned 0"
fi

if grep -E -n 'apt-get|apt |dnf |yum |pacman|curl |wget |tailscale|ssh |docker pull|k3s' \
  "${SCRIPT_DIR}/setup-akash-grokbox.sh" "${SCRIPT_DIR}/akash-share.sh"; then
  fail "setup contains a forbidden command"
fi
grep -q '/etc/depin/akash-share.conf' "${SCRIPT_DIR}/setup-akash-grokbox.sh" || fail "missing config path"
grep -q 'akash.slice' "${SCRIPT_DIR}/setup-akash-grokbox.sh" || fail "missing slice path"
grep -q -- '--system' "${SCRIPT_DIR}/setup-akash-grokbox.sh" || fail "missing system write"

parse_fields() {
  local line key
  unset got
  declare -g -A got
  while IFS= read -r line; do
    if [[ "$line" =~ ^akash\.[A-Za-z0-9_.]+= ]]; then
      key=${line%%=*}
      got["$key"]=${line#*=}
    fi
  done <<<"$1"
}

run_setup() {
  local trace out rc
  trace=$(mktemp)
  out=$(mktemp)
  set +e
  bash -x "${SCRIPT_DIR}/setup-akash-grokbox.sh" "$@" >"$out" 2>"$trace"
  rc=$?
  set -e
  if grep -E '(^|[[:space:]])(mkdir|mktemp|mv|systemctl)([[:space:]]|$)' "$trace"; then
    fail "setup invoked a write command: $*"
  fi
  if grep -F 'akash_write_cap_files' "$trace"; then
    fail "setup called the writer: $*"
  fi
  setup_rc=$rc
  setup_out=$(cat "$out")
  rm -f "$trace" "$out"
}

git_before=$(git -C "$ROOT" status --porcelain)

run_setup --share optimal
assert_eq "$setup_rc" 2 "dry exit"
parse_fields "$setup_out"
assert_eq "${got[akash.status]}" dry "dry status"
assert_eq "${got[akash.confirm]}" no "dry confirm"
assert_eq "${got[akash.write]}" no "dry write"
assert_eq "${got[akash.host_ok]}" no "dry host"
assert_eq "${got[akash.hostname]}" "$live_host" "dry hostname"
assert_eq "${got[akash.selected]}" optimal "dry selected"
assert_eq "${got[akash.reserve_bytes]}" 2147483648 "dry reserve"
assert_eq "${got[akash.os]}" Linux "dry os"

live_cpu=$(nproc)
live_ram_kb=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)
live_ram=$((10#$live_ram_kb * 1024))
assert_eq "${got[akash.cpu_count]}" "$live_cpu" "dry cpu count"
assert_eq "${got[akash.ram_total_bytes]}" "$live_ram" "dry ram total"
for name in optimal 25 50; do
  row=$(akash_share_row "$name" "$live_cpu" "$live_ram")
  read -r rname rpercent rcap routside rquota rcpus rclamped <<<"$row"
  assert_eq "${got[akash.share.${name}.cpu_percent]}" "$rpercent" "live cpu percent ${name}"
  assert_eq "${got[akash.share.${name}.ram_percent]}" "$rpercent" "live ram percent ${name}"
  assert_eq "${got[akash.share.${name}.cpu_quota_percent]}" "$rquota" "live quota ${name}"
  assert_eq "${got[akash.share.${name}.docker_cpus]}" "$rcpus" "live docker ${name}"
  assert_eq "${got[akash.share.${name}.ram_cap_bytes]}" "$rcap" "live cap ${name}"
  assert_eq "${got[akash.share.${name}.ram_outside_bytes]}" "$routside" "live outside ${name}"
  assert_eq "${got[akash.share.${name}.ram_cap_clamped]}" "$rclamped" "live clamp ${name}"
  if [[ "$routside" -lt "$reserve" ]]; then
    fail "live outside dropped the 2 GB reserve for ${name}"
  fi
  if [[ "$rquota" -ge $((live_cpu * 100)) ]]; then
    fail "live cpu quota covers the machine for ${name}"
  fi
done
assert_eq "${got[akash.share.optimal.cpu_percent]}" 10 "live optimal cpu"
assert_eq "${got[akash.share.25.cpu_percent]}" 25 "live 25 cpu"
assert_eq "${got[akash.share.50.cpu_percent]}" 50 "live 50 cpu"
[[ "$setup_out" == *"2 GB"* ]] || fail "dry text missing 2 GB"
[[ "$setup_out" == *"VPS bukan provider"* ]] || fail "dry text missing VPS"
[[ "$setup_out" == *"/etc/depin/akash-share.conf"* ]] || fail "dry text missing config path"

run_setup
assert_eq "$setup_rc" 2 "default exit"
parse_fields "$setup_out"
assert_eq "${got[akash.selected]}" none "default selected"
assert_eq "${got[akash.write]}" no "default write"

run_setup --share mining
assert_eq "$setup_rc" 2 "invalid share still dry"
parse_fields "$setup_out"
assert_eq "${got[akash.selected]}" invalid "invalid selected"
assert_eq "${got[akash.write]}" no "invalid write"

run_setup --confirm --share optimal
assert_eq "$setup_rc" 1 "confirm exit on non-grokbox"
parse_fields "$setup_out"
assert_eq "${got[akash.status]}" refused "confirm status"
assert_eq "${got[akash.reason]}" bad-host "confirm reason"
assert_eq "${got[akash.write]}" no "confirm write"
assert_eq "${got[akash.confirm]}" yes "confirm flag"
assert_eq "${got[akash.hostname]}" "$live_host" "confirm hostname"
assert_eq "${got[akash.host_ok]}" no "confirm host"

run_setup --share
assert_eq "$setup_rc" 1 "missing share value"
[[ "$setup_out" != *"akash.write=yes"* ]] || fail "missing share claimed a write"

run_setup --install
assert_eq "$setup_rc" 1 "unknown arg"

help_trace=$(mktemp)
set +e
bash -x "${SCRIPT_DIR}/setup-akash-grokbox.sh" --help >"$help_trace.out" 2>"$help_trace"
help_rc=$?
set -e
[[ "$help_rc" -eq 0 ]] || fail "help exit ${help_rc}"
if grep -F 'akash_write_cap_files' "$help_trace"; then
  fail "help called the writer"
fi
rm -f "$help_trace" "$help_trace.out"

[[ ! -e /etc/depin/akash-share.conf ]] || fail "config appeared after smoke"
[[ ! -e /etc/systemd/system/akash.slice ]] || fail "slice appeared after smoke"

git_after=$(git -C "$ROOT" status --porcelain)
if [[ "$git_before" != "$git_after" ]]; then
  fail "smoke changed the worktree"
fi

echo "smoke ok: shares 10/25/50, 2 GB reserve, non-Grokbox refusal"
