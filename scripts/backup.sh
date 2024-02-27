#!/bin/bash

if [ "${RCON_ENABLED,,}" = true ]; then
    rcon-cli -c /home/steam/server/rcon.yaml save
fi

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
FILE_PATH="/backups/palworld-save-${DATE}.tar.gz"
cd /saves || exit

echo "Creating backup"
tar -zcf "$FILE_PATH" .

if [ "$(id -u)" -eq 0 ]; then
    chown steam:steam "$FILE_PATH"
fi

echo "Backup created at ${FILE_PATH}"

if [ "${DELETE_OLD_BACKUPS,,}" = true ]; then

    if [ -z "${OLD_BACKUP_DAYS}" ]; then
        echo "Unable to delete old backups, OLD_BACKUP_DAYS is empty."
    elif [[ "${OLD_BACKUP_DAYS}" =~ ^[0-9]+$ ]]; then
        echo "Removing backups older than ${OLD_BACKUP_DAYS} days"
        find /backups/ -mindepth 1 -maxdepth 1 -mtime "+${OLD_BACKUP_DAYS}" -type f -name 'palworld-save-*.tar.gz' -print -delete
    else
        echo "Unable to delete old backups, OLD_BACKUP_DAYS is not an integer. OLD_BACKUP_DAYS=${OLD_BACKUP_DAYS}"
    fi
fi