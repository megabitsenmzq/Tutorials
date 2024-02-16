#!/bin/bash

date_string=$(date +'%Y-%m-%d_%H-%M-%S')

tar --absolute-names --exclude .sync --exclude ZiLi -zcf /mnt/Documents/Backups/Archive/Developer_$date_string.tar.gz /mnt/Documents/Files/Developer
chmod g+rw /mnt/Documents/Backups/Archive/Developer_$date_string.tar.gz
chown megabits:megabits /mnt/Documents/Backups/Archive/Developer_$date_string.tar.gz
backup_files_dev=($(ls -tr "/mnt/Documents/Backups/Archive/Developer_"*.tar.gz))

if [[ ${#backup_files_dev[@]} -gt 7 ]]; then
  num_files_to_delete=$(( ${#backup_files_dev[@]} - 7 ))
  files_to_delete=("${backup_files_dev[@]:0:$num_files_to_delete}")
  rm "${files_to_delete[@]}"
fi

tar --absolute-names --exclude .sync -zcf /mnt/Documents/Backups/Archive/Creator_$date_string.tar.gz /mnt/Documents/Files/Creator
chmod g+rw /mnt/Documents/Backups/Archive/Creator_$date_string.tar.gz
chown megabits:megabits /mnt/Documents/Backups/Archive/Creator_$date_string.tar.gz
backup_files_cre=($(ls -tr "/mnt/Documents/Backups/Archive/Creator_"*.tar.gz))

if [[ ${#backup_files_cre[@]} -gt 7 ]]; then
  num_files_to_delete=$(( ${#backup_files_cre[@]} - 7 ))
  files_to_delete=("${backup_files_cre[@]:0:$num_files_to_delete}")
  rm "${files_to_delete[@]}"
fi
