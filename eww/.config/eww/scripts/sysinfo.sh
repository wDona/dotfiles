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

# ── DISCOS (particiones montadas; una fila por particion) ──
# Monta jes a ignorar (la ESP es estatica y no aporta). Vacia la variable
# para que aparezcan todos.
DISK_SKIP='^(/boot|/boot/efi|/efi)$'
DISK_ICON=$'\Uf02ca'
# Etiqueta = punto de montaje (cabe en la fila; el nombre del dispositivo
# desbordaba y GTK lo cortaba con "…").
disk_label() {
    case "$1" in
        /) echo "Sistema  /" ;;
        *) echo "$1" ;;
    esac
}
# "usado / total UNIDAD": una sola unidad (la del total) para que la fila quepa.
dpair() {
    awk "BEGIN{u=$1; t=$2
        if(t>=1099511627776){d=1099511627776; n=\"TB\"}
        else if(t>=1073741824){d=1073741824; n=\"GB\"}
        else if(t>=1048576){d=1048576; n=\"MB\"}
        else {d=1024; n=\"KB\"}
        uu=u/d; tt=t/d
        fmt = (tt<10) ? \"%.1f / %.1f %s\" : \"%.0f / %.0f %s\"
        printf fmt, uu, tt, n}"
}
di=0
seen=""
while read -r src mp; do
    [ "$di" -ge 4 ] && break
    # btrfs reporta "/dev/nvme0n1p3[/@]": nos quedamos con el dispositivo.
    dev=${src%%[*}
    # Un mismo dispositivo puede tener varios subvolumenes montados (@, @home,
    # @var_log...): todos comparten el espacio, asi que solo la primera fila.
    case " $seen " in *" $dev "*) continue ;; esac
    [ -n "$DISK_SKIP" ] && [[ $mp =~ $DISK_SKIP ]] && continue
    seen="$seen $dev"
    read -r dpct dused dtot < <(df -B1 --output=pcent,used,size "$mp" 2>/dev/null | tail -1 | tr -d '%')
    [ -n "$dtot" ] || continue
    eval "d${di}_show=true \
          d${di}_name=\"$(disk_label "$mp" "$dev")\" \
          d${di}_val=\"$(dpair "$dused" "$dtot")\" \
          d${di}_pct=${dpct:-0}"
    di=$((di+1))
done < <(findmnt -rno SOURCE,TARGET --real 2>/dev/null | grep '^/dev/')
while [ "$di" -lt 4 ]; do eval "d${di}_show=false d${di}_name='' d${di}_val='' d${di}_pct=0"; di=$((di+1)); done

# ── Temps ──
# Lee sensors por PREFIJO de chip, no por direccion PCI: la direccion cambia
# al mover tarjetas o tras updates de BIOS y dejaba la lectura a 0.
SENSORS_CACHE=$(sensors -u 2>/dev/null)
# $1 = regex de chip, $2 = nombre de la magnitud (edge, Tctl, junction...)
sens() {
    awk -v chipre="$1" -v want="$2" '
        /^[^[:space:]]/ && !/:/     { chip=$0; next }
        /^[^[:space:]].*:$/         { feat=substr($0, 1, length($0)-1); next }
        /_input:/ {
            if (chip ~ chipre && feat == want) { printf "%d\n", $2 + 0.5; exit }
        }' <<<"$SENSORS_CACHE"
}
cputemp=$(sens '^k10temp-' 'Tctl')
[ -z "$cputemp" ] && cputemp=$(sens '^coretemp-' 'Package id 0')
# edge = temperatura del die; junction es el hotspot, como reserva.
gputemp=$(sens '^amdgpu-' 'edge')
[ -z "$gputemp" ] && gputemp=$(sens '^amdgpu-' 'junction')
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
