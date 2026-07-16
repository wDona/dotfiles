#!/usr/bin/env bash
# Emite JSON con stats de hardware para el dashboard eww.
# CPU% (delta /proc/stat), RAM, DISK, temps CPU/GPU, uptime, host.

# ── CPU % (delta entre dos lecturas cacheadas) ──
STAT="${XDG_RUNTIME_DIR:-/tmp}/eww_cpu_stat"
read -r _ u n s i io irq sirq st _ < /proc/stat
idle=$((i + io))
total=$((u + n + s + i + io + irq + sirq + st))
cpu=0
if [ -f "$STAT" ]; then
    read -r pidle ptotal < "$STAT"
    dt=$((total - ptotal)); di=$((idle - pidle))
    [ "$dt" -gt 0 ] && cpu=$(( (100 * (dt - di)) / dt ))
fi
echo "$idle $total" > "$STAT"
[ "$cpu" -lt 0 ] && cpu=0; [ "$cpu" -gt 100 ] && cpu=100

# ── RAM ──
read -r mtot mavail < <(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print t, a}' /proc/meminfo)
mused=$((mtot - mavail))
mem=$(( 100 * mused / mtot ))
mem_used=$(awk "BEGIN{printf \"%.1f\", $mused/1048576}")
mem_total=$(awk "BEGIN{printf \"%.1f\", $mtot/1048576}")

# ── DISCOS (todos los fisicos; muestra uso del montaje principal) ──
DISK_ICON=$'\Uf02ca'
gb() { awk "BEGIN{printf \"%.0f\", $1/1073741824}"; }
di=0
while read -r dname dsize; do
    [ "$di" -ge 4 ] && break
    mounts=$(lsblk -nro MOUNTPOINT "/dev/$dname" 2>/dev/null | grep -v '^\[' | grep -v '^[[:space:]]*$')
    if grep -qx '/' <<<"$mounts"; then mp="/"; else mp=$(head -1 <<<"$mounts"); fi
    if [ -n "$mp" ]; then
        read -r dpct dused dtot < <(df -B1 --output=pcent,used,size "$mp" 2>/dev/null | tail -1 | tr -d '%')
        eval "d${di}_name=\"$dname  $mp\" d${di}_val=\"$(gb "$dused") / $(gb "$dtot") GB\" d${di}_pct=${dpct:-0}"
    else
        eval "d${di}_name=\"$dname\" d${di}_val=\"$dsize · sin montar\" d${di}_pct=0"
    fi
    eval "d${di}_show=true"
    di=$((di+1))
done < <(lsblk -dnro NAME,SIZE,TYPE 2>/dev/null | awk '$3=="disk"{print $1, $2}')
while [ "$di" -lt 4 ]; do eval "d${di}_show=false d${di}_name='' d${di}_val='' d${di}_pct=0"; di=$((di+1)); done

# ── Temps ──
cputemp=$(sensors -j 2>/dev/null | python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except: print(0); sys.exit()
v=d.get('k10temp-pci-00c3',{}).get('Tctl',{}).get('temp1_input',0)
print(round(v))" 2>/dev/null)
gputemp=$(sensors -j 2>/dev/null | python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except: print(0); sys.exit()
e=d.get('amdgpu-pci-0300',{}).get('edge',{})
v=next((e[k] for k in e if k.endswith('_input')),0)
print(round(v))" 2>/dev/null)
[ -z "$cputemp" ] && cputemp=0
[ -z "$gputemp" ] && gputemp=0

# ── Uso de GPUs (gpu_busy_percent de cada tarjeta DRM) ──
GPU_ICON=$'\Uf0379'
gi=0
for busy in /sys/class/drm/card[0-9]/device/gpu_busy_percent; do
    [ -f "$busy" ] || continue
    [ "$gi" -ge 2 ] && break
    use=$(cat "$busy" 2>/dev/null); eval "g${gi}_show=true g${gi}_use=${use:-0}"
    gi=$((gi+1))
done
while [ "$gi" -lt 2 ]; do eval "g${gi}_show=false g${gi}_use=0"; gi=$((gi+1)); done

# ── Red (delta rx/tx del iface por defecto) ──
iface=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
net_down="0 B/s"; net_up="0 B/s"; net_ip=""; net_state="down"; net_icon="󰪪"
if [ -n "$iface" ]; then
    net_state="up"
    net_ip=$(ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
    case "$iface" in
        wl*) net_icon="󰖩" ;;
        *)   net_icon="󰈀" ;;
    esac
    rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null)
    tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null)
    NET="${XDG_RUNTIME_DIR:-/tmp}/eww_net_stat"
    now=$(date +%s%N)
    if [ -f "$NET" ]; then
        read -r prx ptx pnow < "$NET"
        dt=$(awk "BEGIN{print ($now-$pnow)/1000000000}")
        hum() { awk "BEGIN{b=$1; if(b<0)b=0; u=\"B\"; if(b>=1073741824){b/=1073741824;u=\"GB\"}else if(b>=1048576){b/=1048576;u=\"MB\"}else if(b>=1024){b/=1024;u=\"KB\"}; printf \"%.1f %s/s\", b, u}"; }
        rate_d=$(awk "BEGIN{print ($rx-$prx)/$dt}" 2>/dev/null)
        rate_u=$(awk "BEGIN{print ($tx-$ptx)/$dt}" 2>/dev/null)
        net_down=$(hum "$rate_d"); net_up=$(hum "$rate_u")
    fi
    echo "$rx $tx $now" > "$NET"
fi

# ── Uptime ──
up=$(awk '{s=int($1); d=int(s/86400); h=int((s%86400)/3600); m=int((s%3600)/60); if(d>0) printf "%dd %dh", d, h; else printf "%dh %dm", h, m}' /proc/uptime)

host=$(uname -n)

printf '{"cpu":%d,"mem":%d,"mem_used":%s,"mem_total":%s,"disk_icon":"%s","d0_show":%s,"d0_name":"%s","d0_val":"%s","d0_pct":%d,"d1_show":%s,"d1_name":"%s","d1_val":"%s","d1_pct":%d,"d2_show":%s,"d2_name":"%s","d2_val":"%s","d2_pct":%d,"d3_show":%s,"d3_name":"%s","d3_val":"%s","d3_pct":%d,"cputemp":%d,"gputemp":%d,"gpu_icon":"%s","g0_show":%s,"g0_use":%d,"g1_show":%s,"g1_use":%d,"net_down":"%s","net_up":"%s","net_ip":"%s","net_icon":"%s","net_state":"%s","uptime":"%s","host":"%s"}\n' \
    "$cpu" "$mem" "$mem_used" "$mem_total" \
    "$DISK_ICON" \
    "$d0_show" "$d0_name" "$d0_val" "$d0_pct" "$d1_show" "$d1_name" "$d1_val" "$d1_pct" \
    "$d2_show" "$d2_name" "$d2_val" "$d2_pct" "$d3_show" "$d3_name" "$d3_val" "$d3_pct" \
    "$cputemp" "$gputemp" \
    "$GPU_ICON" "$g0_show" "$g0_use" "$g1_show" "$g1_use" \
    "$net_down" "$net_up" "$net_ip" "$net_icon" "$net_state" "$up" "$host"
