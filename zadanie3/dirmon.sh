#!/bin/bash

DIR=${1:-.}
LOG_FILE="monitor.log"


RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
RESET='\e[0m'

added=0
deleted=0
modified=0
renamed=0

show_statistics() {
  echo "Statystki:"
  printf "%d %d %d %d" \
    $added $deleted $modified \
    $renamed | column -t -N "dodanie,usuniecie,modyfikacja,zmiana nazwy"
}

while read event_date hour event file; do
  case "$event" in
    STATS)
      show_statistics ;;
    *CREATE*)
      info_text="[$event_date $hour] Dodano: $file"
      echo -e "${GREEN}${info_text}${RESET}"
      echo "${info_text}" >> "$LOG_FILE"
      (( added++ )) ;;
    *DELETE*)
      info_text="[$event_date $hour] Usunięto: $file"
      echo -e "${RED}${info_text}${RESET}"
      echo "${info_text}" >> "$LOG_FILE"
      (( deleted++ )) ;;
    *MODIFY*)
      info_text="[$event_date $hour] Zmodyfikowano: $file"
      echo -e "${YELLOW}${info_text}${RESET}"
      echo "${info_text}" >> "$LOG_FILE"
      (( modified++ )) ;;
    *MOVED_FROM*)
      old_name="$file" ;;
    *MOVED_TO*)
      info_text="[$event_date $hour] Zmieniono nazwę: $old_name -> $file"
      echo -e "${BLUE}${info_text}${RESET}"
      echo "${info_text}" >> "$LOG_FILE"
      (( renamed++ )) ;;
    esac
  done <  <(
    # m - monitor
    # r - recursive
    # q - quiet mode
    # e - event
    inotifywait -m -r -q \
      -e create -e delete -e modify \
      -e moved_from -e moved_to \
      --exclude "$LOG_FILE" \
      --timefmt '%d-%m-%Y %H:%M:%S' \
      --format '%T %e %w%f' \
      "$DIR" &
    while sleep 10; do
      echo "- - STATS"
    done
    )
