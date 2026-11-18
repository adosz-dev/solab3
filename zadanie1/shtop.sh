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
T_EXIT_ATTRIBUTE_MODE=$(tput sgr0)
T_EL=$(tput el)

trap 'stty sane; tput cnorm; clear' EXIT

read_proc() {
  pids=()
  for pid in $(ls /proc | grep "^[0-9]"); do
    read -r line 2>/dev/null < /proc/$pid/stat || continue
    comm=${line#*(}; comm=${comm%)*}
    line="$pid (${comm// /_}) ${line##*) }"
    read -r _ s_comm[$pid] s_state[$pid] s_ppid[$pid] s_pgrp[$pid] s_session[$pid] \
      s_tty_nr[$pid] _ _ _ _ _ _ _ _ _ _ _ s_nice[$pid] _ _ _ _ \
      s_rss[$pid] _ <<< "$line"
    pids+=($pid)
  done;
}

kill_commands() {
  local curr_pid=${pids[$sel_idx]}
  case $1 in
    1) kill -STOP $curr_pid ;;
    2) kill -CONT $curr_pid ;;
    3) kill -9 $curr_pid ;;
  esac
}

keyboard_commands() {
  case $1 in
    q) exit ;;
    $'\e[A') (( sel_idx > 0 )) && (( sel_idx-- )) ;;
    $'\e[B') (( sel_idx < ${#pids[@]} - 1 )) && (( sel_idx++ )) ;;
    k)
      tput cup $(( $(tput lines) - 1 )) 0; tput el
      normal_mode
      read -p "kill (stop: 1, cont: 2, kill: 3): " val
      special_mode
      kill_commands "$val"
      ;;
    r)
      tput cup $(( $(tput lines) - 1 )) 0; tput el
      normal_mode
      read -p "nice (teraz ${s_nice[${pids[$sel_idx]}]}): " val
      special_mode
      renice -n "$val" -p ${pids[$sel_idx]} >/dev/null 2>&1
      last=0
      ;;
  esac
}

print_pid_info() {
  printf "%d %s %s %d %d %d %d %d\n" \
    $1 ${s_comm[$1]} ${s_state[$1]} ${s_ppid[$1]} ${s_pgrp[$1]} \
    ${s_session[$1]} ${s_tty_nr[$1]} ${s_rss[$1]}
}

show_info() {
  (( sel_idx >= ${#pids[@]} )) && sel_idx=$(( ${#pids[@]} - 1 ))
  local max_rows=$(( $(tput lines) - 2 ))
  {
    # for tablica[@]:początek:ile
    for pid in "${pids[@]:sel_idx:max_rows}"; do
      print_pid_info $pid
    done
  } | column -t -N PID,COMM,STATE,PPID,PGRP,SID,TTY_NR,RSS \
    | awk -v w="$T_WHITE_BACKGROUND" -v e="$T_EXIT_ATTRIBUTE_MODE" \
        -v b="$T_BOLD" -v el="$T_EL"\
        'NR == 1 { $0 = b $0 e } NR == 2 { $0 = w $0 e } { print $0 el }'
  tput ed
}

sel_idx=0
special_mode

while [ 1 ]; do
  if (( $(date "+%s") - last >= 1 )); then
    read_proc
    last=$(date "+%s")
  fi
  show_info
  read -t 0.1 key
  keyboard_commands "$key"
  tput cup 0 0
done
