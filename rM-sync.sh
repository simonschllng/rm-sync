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
MAINDIR="$HOME/rM"
BACKUPDIR="$MAINDIR/backup/"             # rotating backups of all rM contents
UPLOADDIR="$MAINDIR/upload/"             # all files here will be sent to rM
OUTPUTDIR="$MAINDIR/files/"              # PDFs of everything on the rM
LOG="sync.log"                           # Log file name in $MAINDIR
BACKUPLIST="files.json"

# Behaviour
notification() {
  if [ "$(uname)" == "Linux" ]; then
    /usr/bin/notify-send $1 $2           # Notification script
  elif [ "$(uname)" == "Darwin" ]; then
    osascript -e "display notification \"$2\" with title \"$1\""
  fi
}

LOG="$MAINDIR/$(date +%y%m%d)-$LOG"

# Create MAINDIR if it does not exist
mkdir -p $MAINDIR

echo $'\n' >> $LOG
date >> $LOG


S="ssh -p $SSHPORT -l $RMUSER";

# check for rM
$S $RMIP -q exit

if [ $? == "0" ]; then

  TODAY=$(date +%y%m%d)


  while getopts bdu opt
  do
     case $opt in
       b)
          # Backup files
          echo "BEGIN BACKUP" | tee -a $LOG
          mkdir -p "$BACKUPDIR$TODAY"
          echo "scp \"$RMUSER@$RMIP:$RMDIR\" $BACKUPDIR$TODAY"  >> $LOG
          scp -r "$RMUSER@$RMIP:\"$RMDIR\"*" "$BACKUPDIR"$TODAY >> $LOG 2>&1
          if [ $? -ne 0 ]; then
            ERRORREASON=$ERRORREASON$'\n scp command failed'
            ERROR=1
          fi
          # sed -s does not work on macOS (https://unix.stackexchange.com/a/131940)
          if [ "$(uname)" == "Linux" ]; then
            echo "[" > "$BACKUPDIR$TODAY$BACKUPLIST"
            find "$BACKUPDIR$TODAY" -name *.metadata -type f -exec sed -s '$a,' {} + | sed '$d' >> "$BACKUPDIR$TODAY$BACKUPLIST"
            echo "]" >> "$BACKUPDIR$TODAY$BACKUPLIST"
          fi
          echo "BACKUP END" | tee -a $LOG
          ;;

        d)
          # Download files
          echo "BEGIN DOWNLOAD" | tee -a $LOG
          mkdir -p "$OUTPUTDIR"
          ls -1 "$BACKUPDIR$TODAY" | sed -e 's/\..*//g' | awk '!a[$0]++' > "$OUTPUTDIR/index"

          echo "[" > "$OUTPUTDIR/index.json";
          for file in "$BACKUPDIR$TODAY"/*.metadata;
          do
              [ -e "$file" ] || continue
              echo "{" >> "$OUTPUTDIR/index.json";
              echo "    \"id\": \"$(basename "$file" .metadata)\"," >> "$OUTPUTDIR/index.json";
              tail --lines=+2 "$file" >> "$OUTPUTDIR/index.json";
              echo "," >> "$OUTPUTDIR/index.json";
          done
          truncate -s-2 "$OUTPUTDIR/index.json"; #Remove last koma
          echo "]" >> "$OUTPUTDIR/index.json";


          echo "Downloading" $(wc -l < "$OUTPUTDIR/index") "files." | tee -a $LOG
          # http://$RMIP/download/$FILEUID/placeholder
          while read -r line
          do
              FILEUID="$line"
              #curl -s -O -J -L "http://$RMIP/download/$FILEUID/placeholder"
              if [ $? -ne 0 ]; then
                ERRORREASON=$ERRORREASON$'\n Download failed'
                ERROR=1
              fi
          done < "$OUTPUTDIR/index"
        echo "DOWNLOAD END" | tee -a $LOG
        ;;

      u)
        # Upload files
        echo "BEGIN UPLOAD" | tee -a $LOG
        for file in "$UPLOADDIR"/*;
        do
            [ -e "$file" ] || continue
            echo -n $(basename "$file") ": "
            curl --form "file=@\"$file\"" http://$RMIP/upload
            echo "."
            if [ 0 -eq $? ]; then rm "$file"; fi;
        done
        if [ $? -ne 0 ]; then
          ERRORREASON=$ERRORREASON$'\n Upload failed'
          ERROR=1
        fi
        echo "UPLOAD END" | tee -a $LOG
        ;;
    esac
  done

else
  echo "reMarkable not connected" | tee -a $LOG
  ERRORREASON=$ERRORREASON$'\n reMarkable not connected'
  ERROR=1
fi
$DATE >> $LOG
if typeset -f notification > /dev/null; then
  if [ $ERROR ]; then
    notification "ERROR in rM Sync!" "$ERRORREASON"
  else
    notification "rM Sync Successfull"
  fi
fi
