#!/bin/bash
# shellcheck source=/dev/null
source "/home/steam/server/helper_functions.sh"

PARAM=${1:-shutdown}
if [ "${PARAM}" = "autoreboot" ]; then
  AUTOREBOOT=true
fi

function terminate() {
  if [ "${RCON_ENABLED,,}" = true ]; then
    rcon-cli save
    if [ "${BACKUP_BEFORE_EXIT,,}" = true ] && [ "${BACKUP_ENABLED,,}" = true ]; then
      echo "Creating backup before exit"
      backup
    fi
    rcon-cli "shutdown 1"
  else # Does not save
    kill -SIGTERM "$(pidof PalServer-Linux-Test)"
  fi
}

if [ "${RCON_ENABLED,,}" = true ] && [ "${SHUTDOWN_EVEN_IF_PLAYERS_ONLINE,,}" != true ]; then
  players_count=$(get_player_count)

  # Auto reboot skip if players are online
  if [ "${AUTOREBOOT}" = true ] && [ "$players_count" -gt 0 ]; then
    echo "There are ${players_count} players online. Skipping reboot."
    rcon-cli -c /home/steam/server/rcon.yaml "broadcast Auto_Reboot_Skipped"
    exit 1
  fi

  # No players skip
  if [ "$players_count" -eq 0 ]; then
    echo "There are no players online. Shutting down immediately."
    terminate
    exit 0
  fi

  # This is a standard shutdown with players or autoreboot with players
  if [[ "${SHUTDOWN_WARN_SECONDS}" =~ ^[0-9]+$ ]]; then
    MINS="$((SHUTDOWN_WARN_SECONDS / 60))"
    for ((i = "${MINS}" ; i > 0 ; i--)); do
      players_count=$(get_player_count)
      if [ "${players_count}" -eq 0 ]; then
        echo "There are no more players online. Shutting down immediately."
        terminate
        exit 0
      fi

      rcon-cli -c /home/steam/server/rcon.yaml "broadcast The_Server_will_${PARAM}_in_${i}_Minutes"
      sleep "30s"

      players_count=$(get_player_count)
      if [ "${players_count}" -eq 0 ]; then
        echo "There are no more players online. Shutting down immediately."
        terminate
        exit 0
      fi

      sleep "30s"
    done
  elif [ "${AUTOREBOOT}" = true ]; then
    echo "Unable to auto reboot, SHUTDOWN_WARN_SECONDS is not an integer: ${SHUTDOWN_WARN_SECONDS}"
    exit 1
  else
    echo "SHUTDOWN_WARN_SECONDS is not an integer: ${SHUTDOWN_WARN_SECONDS}, shutting down immediately."
  fi
fi

terminate
