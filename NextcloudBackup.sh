#!/usr/local/bin/bash

#
# Bash script for making backups of Nextcloud.
# Usage: ./NextcloudBackup.sh <dbPassword> (e.g. ./NextcloudRestore.sh <dbPassword>)
#
# The script is based on an installation of Nextcloud using nginx and MariaDB, see https://github.com/NasKar2/freenas-iocage-nextcloud
# This script should be run in the nextcloud jail and assumes you have mounted /mnt/v1/NextcloudBackups to /mnt/NextcloudBackups to store backups
# If you ran the install script for nextcloud referenced above it will be done already

# This script was adapted from https://github.com/DecaTec/Nextcloud-Backup-Restore
#

#
# IMPORTANT
# You have to customize this script (directories, users, etc.) for your actual environment.
# All entries which need to be customized are tagged with "TODO".
#


# Variables
currentDate=$(date +"%Y%m%d_%H%M%S")
# TODO: The directory where you store the Nextcloud backups
backupMainDir="/mnt/NextcloudBackups"
# The actual directory of the current backup - this is is subdirectory of the main directory above with a timestamp
backupdir="${backupMainDir}/${currentDate}/"
# TODO: The directory of your Nextcloud installation (this is a directory under your web root)
nextcloudFileDir="/usr/local/www/nextcloud"
# TODO: The directory of your Nextcloud data directory (outside the Nextcloud file directory)
# If your data directory is located under Nextcloud's file directory (somewhere in the web root), the data directory should not be a separate part of the backup
nextcloudDataDir="/mnt/files"
# TODO: The service name of the web server. Used to start/stop web server (e.g. 'service <webserverServiceName> start')
webserverServiceName="nginx"
# TODO: Your Nextcloud database name
nextcloudDatabase="nextcloud"
# TODO: Your Nextcloud database user
dbUser="nextcloud"
# TODO: The password of the Nextcloud database user
dbPassword=$1
# TODO: Your web server user
webserverUser="www"
# TODO: The maximum number of backups to keep (when set to 0, all backups are kept)
maxNrOfBackups=4

# File names for backup files
# If you prefer other file names, you'll also have to change the NextcloudRestore.sh script.
fileNameBackupFileDir="nextcloud-filedir.tar.gz"
fileNameBackupDataDir="nextcloud-datadir.tar.gz"
fileNameBackupDb="nextcloud-db.sql"

# Function for error messages
#errorecho() { cat <<< "$@" 1>&2; }


# File names for backup files
# If you prefer other file names, you'll also have to change the NextcloudBackup.sh script.
fileNameBackupFileDir="nextcloud-filedir.tar.gz"
fileNameBackupDataDir="nextcloud-datadir.tar.gz"
fileNameBackupDb="nextcloud-db.sql"

# Function for error messages
#errorecho() { cat <<< "$@" 1>&2; }


#
# Check if database password parameter given
#
if [ -z "$1" ]
   then
     echo "ERROR: No $nextcloudDatabase database password to backup given!"
     echo "for example ${0} <dbPassword>"
     exit 1
fi



#
# Check for root
#
if [ "$(id -u)" != "0" ]
then
	errorecho "ERROR: This script has to be run as root!"
	exit 1
fi

#
# Check if backup dir already exists
#
if [ ! -d "${backupdir}" ]
then
	mkdir -p "${backupdir}"
else
	errorecho "ERROR: The backup directory ${backupdir} already exists!"
	exit 1
fi

#
# Set maintenance mode
#
echo "Set maintenance mode for Nextcloud..."
#cd "${nextcloudFileDir}"
su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:mode --on'
#su -m "${webserverUser}" php /usr/local/www occ maintenance:mode --on
echo "Done"
echo

#
# Stop web server
#
echo "Stopping web server..."
service "${webserverServiceName}" stop
echo "Done"
echo

#
# Backup file and data directory
#
echo "Creating backup of Nextcloud file directory..."
#tar -cpzf "${backupdir}/${fileNameBackupFileDir}" -C "${nextcloudFileDir}" .
mkdir -p "${backupdir}nextcloud/"
rsync -avx "${nextcloudFileDir}/" "${backupdir}nextcloud/"
#rsync -avx "${nextcloudFileDir}/ "${backupdir}/${fileNameBackupFileDir}"
echo "Done"
echo

echo "Creating backup of Nextcloud data directory..."
#tar -cpzf "${backupdir}/${fileNameBackupDataDir}"  -C "${nextcloudDataDir}" .
mkdir -p "${backupdir}/files/"
rsync -avx "${nextcloudDataDir}/" "${backupdir}files/"
#rsync -avx "${nextcloudDataDir}/ "${backupdir}/${fileNameBackupDataDir}" 
echo "Done"
echo

#
# Backup DB
#
echo "Backing up Nextcloud Database..."
mysqldump --single-transaction -h localhost -u "${dbUser}" -p"${dbPassword}" "${nextcloudDatabase}" > "${backupdir}/${fileNameBackupDb}"
echo "Done"
echo

#
# Start web server
#
echo "Starting web server..."
service "${webserverServiceName}" start
echo "Done"
echo

#
# Disable maintenance mode
#
echo "Switching off maintenance mode..."
su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:mode --off'
#su -m "${webserverUser}" php /usr/local/www occ maintenance:mode --off
echo "Done"
echo

#
# Delete old backups
#
#maxNrOfBackups=3
#nrOfBackups=0
#backupMainDir="/mnt/files/NextcloudBackups/"
#echo "before if"
#echo $maxNrOfBackups
if [ ${maxNrOfBackups} -ne 0 ]
then
     echo "maxNrOfBackups is not 0"
        nrOfBackups="$(ls -l ${backupMainDir} | grep -c ^d)"
     echo "nrOfBackups=" $nrOfBackups
        nDirToRemove="$((nrOfBackups - maxNrOfBackups))"

     echo "nDirToRemove=" $nDirToRemove

while [ $nDirToRemove -gt 0 ]
do
echo
echo "number dir to remove=" $nDirToRemove
dirToRemove="$(ls -t ${backupMainDir} | tail -1)"
echo "Removing Directory ${dirToRemove}"
nDirToRemove="$((nDirToRemove - 1))"
rm -r ${backupMainDir}/${dirToRemove}
done
fi

echo
echo "DONE!"
echo "Backup created: ${backupdir}"
