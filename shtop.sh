stty -echo -icanon min 0 time 0

T_BOLD=$(tput bold)

read_proc() {
  pids=()
  for pid in $(ls /proc | grep "^[0-9]"); do
    pids+=($pid)
    read -r _ s_comm[$pid] s_state[$pid] s_ppid[$pid] s_pgrp[$pid] s_session[$pid] \
      s_tty_nr[$pid] _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ \
      s_rss[$pid] _ < /proc/$pid/stat
  done;
  curr_pid=pids[0]
}

keyboard_commands() {
  case $1
    q) echo "killed"
      ;;
    *)
  esac
}

show_info() {
  
}

tput civis

while [ 1 ]; do
  if $(( $(date "+%s") - $last )) >= 1; then
    read_proc
    last=$(date "+%s")
  fi;
  # read czeka 0.1 s

  read -t 0.1 key
done
