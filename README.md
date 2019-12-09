# rM sync

Sync script for the reMarkable paper tablet.

This script will give you sync and backup functionality uver USB. Great if you do not want to sync your rM to the cloud.

_Ongoing work, contributions welcome._

## Usage

This script is written for and tested on linux. Feel free to adopt for mac or win.

 1. Save the script file to `~/bin`
 2. Change the path variable (and other) in the file as needed.
 3. Run with `./rM-sync.sh`
 
### Options

 * `-u` upload: Uploads new files to the reMarkable from local folder _uploads_.
 * `-b` backup: Creates a backup of all user files on the reMarkable.
 * `-d` download: Not yet implemented...

## Planned functionality

 * Download PDFs of everything that changed on the tablet

