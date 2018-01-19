#!/bin/bash

# Sync script for the reMarkable reader
# Version: 0.1
# Author: Simon Schilling
# Licence: MIT

# Remote configuration
RMDIR="/home/root/.local/share/remarkable/xochitl/"
RMUSER="root"
RMIP="10.11.99.1"
SSHPORT="22"

# Local configuration
MAINDIR="/home/simon/rM"
BACKUPDIR="$MAINDIR/backup/"             # rotating backups of all rM contents
UPLOADDIR="$MAINDIR/upload/"             # all files here will be sent to rM
OUTPUTDIR="$MAINDIR/files/"              # PDFs of everything on the rM
LOG="sync.log"                          # Log file name in $MAINDIR

# Behaviour
NOTIFICATION="/usr/bin/notify-send"     # Notification script

LOG="$MAINDIR/$(date +%y%m%d)-$LOG"

echo $'\n' >> $LOG
date >> $LOG


if [ "$RMUSER" ] && [ "$SSHPORT" ]; then
  S="ssh -p $SSHPORT -l $RMUSER";
fi

# check for rM
$S $RMIP -q exit

if [ $? == "0" ]; then

  TODAY=$(date +%y%m%d)

  # Backup files
  echo "BEGIN BACKUP" >> $LOG
  mkdir -p "$BACKUPDIR$TODAY"
  echo "scp \"$RMUSER@$RMIP:$RMDIR\" $BACKUPDIR$TODAY"  >> $LOG
  scp -r "$RMUSER@$RMIP:\"$RMDIR\"*" "$BACKUPDIR"$TODAY >> $LOG 2>&1
  if [ $? -ne 0 ]; then
    ERRORREASON=$ERRORREASON$'\n scp command failed'
    ERROR=1
  fi
  echo "BACKUP END" >> $LOG



  # Download files
  echo "BEGIN DOWNLOAD" >> $LOG
  mkdir -p "$OUTPUTDIR"
  ls -1 "$BACKUPDIR$TODAY" | sed -e 's/\..*//g' | awk '!a[$0]++' > "$OUTPUTDIR/index"
  echo "Downloading" $(wc -l "$OUTPUTDIR/index") "files." >> $LOG
  # http://$RMIP/download/$FILEUID/placeholder
  while read -r line
  do
      FILEUID="$line"
      curl -s -O -J -L "http://$RMIP/download/$FILEUID/placeholder"
      if [ $? -ne 0 ]; then
        ERRORREASON=$ERRORREASON$'\n Download failed'
        ERROR=1
      fi
  done < "$OUTPUTDIR/index"
  echo "DOWNLOAD END" >> $LOG


  # Upload files
  echo "BEGIN UPLOAD" >> $LOG
  # TODO
  if [ $? -ne 0 ]; then
    ERRORREASON=$ERRORREASON$'\n Upload failed'
    ERROR=1
  fi
  echo "UPLOAD END" >> $LOG


else
  echo "reMarkable not connected" >> $LOG
  ERRORREASON=$ERRORREASON$'\n reMarkable not connected'
  ERROR=1
fi
$DATE >> $LOG
if [ -n "$NOTIFICATION" ]; then
  if [ $ERROR ];then
    $NOTIFICATION "ERROR in rM Sync!" "$ERRORREASON"
  else
    $NOTIFICATION "rM Sync Successfull"
  fi
fi
