#!/bin/bash

normal_mode() {
  stty echo icanon
  tput cnorm
}

special_mode() {
  stty -echo -icanon min 0 time 0
  tput civis
}

T_BOLD=$(tput bold)
T_WHITE_BACKGROUND=$(tput setab 7)
T_GREEN_BACKGROUND=$(tput setab 2)
T_BLUE_BACKGROUND=$(tput setab 4)
T_EXIT_ATTRIBUTE_MODE=$(tput sgr0)
T_EL=$(tput el)

trap 'stty sane; tput cnorm; clear' EXIT

read_battery_capacity() {
  capacity=$(</sys/class/power_supply/BAT1/capacity)
}

print_uptime() {
  read us _ \
    </proc/uptime
  us=${us%.*}
  printf "%d dni, %02d:%02d:%02d\n" \
    $((us/86400)) $((us/3600%24)) $((us/60%60)) $((us%60))
}

print_unit() {
  local b=$1 kb=1024 mb=$((1024*1024))
  if (( b >= mb )); then
    printf "%d.%02d MB" $((b/mb)) $((b%mb*100/mb))
  elif (( b >= kb )); then
    printf "%d.%02d kB" $((b/kb)) $((b%kb*100/kb))
  else
    printf "%d B" $b
  fi
}

read_load() {
  read load_1_min load_5_min load_15_min _ \
    < /proc/loadavg
}

read_meminfo() {
  {
    # całkowity użyteczny RAM
    read _ mem_total _
    # wolny RAM
    read _ mem_free _
    # szacowana pamięć RAM dostępna dla uruchomienia nowych aplikacji
    read _ mem_available _
  } < /proc/meminfo
}

declare -A last_cpu_total last_cpu_busy cpu_usage_percent cpu_freq

cpu_usage() {
  local cpu user nice system idle iowait irq softirq steal rest
  local current_cpu_total current_cpu_busy delta_cpu_total delta_cpu_busy

  while read -r cpu user nice system idle iowait irq softirq steal rest; do
    [[ $cpu == cpu[0-9]* ]] || continue

    current_cpu_total=$(( user + nice + system + idle + iowait + irq + softirq + steal ))
    current_cpu_busy=$(( current_cpu_total - idle - iowait ))

    if [[ -n ${last_cpu_total[$cpu]} ]]; then
      delta_cpu_total=$(( current_cpu_total - last_cpu_total[$cpu] ))
      delta_cpu_busy=$(( current_cpu_busy - last_cpu_busy[$cpu] ))
      if (( delta_cpu_total > 0 )); then
        cpu_usage_percent[$cpu]=$(( (100 * delta_cpu_busy + delta_cpu_total / 2) / delta_cpu_total ))
      fi
    fi

    cpu_freq[$cpu]=$(</sys/devices/system/cpu/${cpu}/cpufreq/scaling_cur_freq)
    last_cpu_total[$cpu]=$current_cpu_total
    last_cpu_busy[$cpu]=$current_cpu_busy
  done < /proc/stat
}

declare -a upload_speeds download_speeds

read_network_info() {
  local curr_received_total curr_transmitted_total \
    curr_received curr_transmitted curr_time_net \
    upload_speed download_speed
  curr_received_total=0
  curr_transmitted_total=0
  while read -r _ curr_received _ _ _ _ _ _ _ curr_transmitted _; do
    (( curr_received_total += curr_received))
    (( curr_transmitted_total += curr_transmitted ))
  done < <(awk 'NR == 1 || NR == 2 { next } { print }' /proc/net/dev)
  # sprawdzam osobno czas, bo inne dzialania mogą spowalniać
  curr_time_net=${EPOCHREALTIME/[.,]/}
  if [[ -n $prev_time_net ]]; then
    upload_speeds+=( $(( (curr_transmitted_total-prev_transmitted_total)*1000000/(curr_time_net - prev_time_net) )) )
    download_speeds+=( $(( (curr_received_total-prev_received_total)*1000000/(curr_time_net - prev_time_net) )) )
    if ((${#upload_speeds[@]} > 10 )); then
      upload_speeds=( "${upload_speeds[@]: -10}" )
      download_speeds=( "${download_speeds[@]: -10}" )
    fi
    min_up_speed=${upload_speeds[0]}
    max_up_speed=${upload_speeds[0]}
    for upload_speed in ${upload_speeds[@]:1}; do
      (( upload_speed > max_up_speed )) && max_up_speed=$upload_speed
      (( upload_speed < min_up_speed )) && min_up_speed=$upload_speed
    done
    min_down_speed=${download_speeds[0]}
    max_down_speed=${download_speeds[0]}
    for download_speed in ${download_speeds[@]:1}; do
      (( download_speed > max_down_speed )) && max_down_speed=$download_speed
      (( download_speed < min_down_speed )) && min_down_speed=$download_speed
    done
  fi
  prev_received_total=$curr_received_total
  prev_transmitted_total=$curr_transmitted_total
  prev_time_net=$curr_time_net
}

move_to_center() {
  columns=$(tput cols)
  length=${#1}
  col=$(( (columns - length)/2 ))
  tput hpa $col
}

print_header() {
  move_to_center "$1"
  echo "$T_BOLD$1$T_EXIT_ATTRIBUTE_MODE$T_EL"
}

print_header_left() {
   echo "$T_BOLD$1$T_EXIT_ATTRIBUTE_MODE$T_EL"
}

print_bars() {
  local color=$1 min=$2 max=$3 row speed height
  shift 3
  for (( row = 5; row >= 1; row-- )); do
    tput hpa 30
    for speed in "$@"; do
      height=1
      (( max > min )) && height=$(( 1 + (speed - min) * 4 / (max - min) ))
      if (( height >= row )); then
        printf "%s  %s " "$color" "$T_EXIT_ATTRIBUTE_MODE"
      else
        printf "   "
      fi
    done
    tput hpa 62
    (( row == 5 )) && printf "max: %s/s" "$(print_unit $max)"
    (( row == 1 )) && printf "min: %s/s" "$(print_unit $min)"
    echo "$T_EL"
  done
}

show_network() {
  (( ${#upload_speeds[@]} > 0 )) || return
  tput hpa 30
  print_header_left "DOWNLOAD: $(print_unit ${download_speeds[-1]})/s"
  print_bars "$T_GREEN_BACKGROUND" $min_down_speed $max_down_speed "${download_speeds[@]}"
  tput hpa 30
  print_header_left "UPLOAD: $(print_unit ${upload_speeds[-1]})/s"
  print_bars "$T_BLUE_BACKGROUND" $min_up_speed $max_up_speed "${upload_speeds[@]}"
}

show_info() {
  print_header "AKTUALNY UPTIME: $(print_uptime)"
  print_header "AKTUALNY STAN BATERII: $capacity"
  print_header "LOAD: 1min: $load_1_min 5min: $load_5_min 15min: $load_15_min"

  tput sc

  for (( i = 0; i < ${#cpu_freq[@]}; i++ )); do
    cpu=cpu$i
    echo "$cpu ${cpu_usage_percent[$cpu]:-0}% $(( cpu_freq[$cpu] / 1000 ))MHz"
  done | column -t -N CPU,UZYCIE,FREQ \
    | awk -v el="$T_EL" '{ print $0 el }'

  tput rc
  show_network

  tput rc
  rows=$(( ${#cpu_freq[@]} + 2 ))
  (( rows < 13 )) && rows=13
  tput cud $rows
  print_header_left "RAM:"
  echo "CALKOWITY: $mem_total kB$T_EL"
  echo "WOLNY: $mem_free kB$T_EL"
  echo "DOSTEPNY: $mem_available kB$T_EL"
  tput ed
}

read_info() {
  read_battery_capacity
  read_network_info
  cpu_usage
  read_load
  read_meminfo
}

special_mode
clear

while [ 1 ]; do
  if (( EPOCHSECONDS - last >= 1 )); then
    read_info
    show_info
    last=$EPOCHSECONDS
  fi
  sleep 0.2
  tput cup 0 0
done
