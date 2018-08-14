#!/usr/local/bin/bash

#
# Bash script for restoring backups of Nextcloud.
# Usage: /usr/NextcloudRestore.sh <dbPassword>
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

# Must be run in the jail
echo "This script must be run in the iocage jail of nextcloud"
read iocage_jail
if [ "${iocage_jail}" == "Y" ]; then
  echo "you can continue"
else
 echo "must run cmd 'iocage console nextcloud'"
 echo "the run /usr/NextcloudRestore.sh <dbPassword>"
 exit 1
fi

# Variables
# TODO: The directory where you store the Nextcloud backups
mainBackupDir="/mnt/NextcloudBackups"

#
# Pick the restore directory *don't edit this section*
#
cd $mainBackupDir
shopt -s dotglob
shopt -s nullglob
array=(*)
for dir in "${array[@]}"; do echo; done
 
for dir in */; do echo; done
 
echo "There are ${#array[@]} backups available pick the one to restore"; \
select dir in "${array[@]}"; do echo; break; done

echo "You choose ${dir}"


# More Variables
restore=$dir
currentRestoreDir="${mainBackupDir}/${restore}"
#echo $currentRestoreDir
# TODO: The directory of your Nextcloud installation (this is a directory under your web root)
nextcloudFileDir="/usr/local/www/nextcloud"
#echo $nextcloudFileDir
# TODO: The directory of your Nextcloud data directory (outside the Nextcloud file directory)
# If your data directory is located under Nextcloud's file directory (somewhere in the web root), the data directory should not be restored separately
nextcloudDataDir="/mnt/files"
#echo $nextcloudDataDir
# TODO: The service name of the web server. Used to start/stop web server (e.g. 'service <webserverServiceName> start')
webserverServiceName="nginx"
# TODO: Your Nextcloud database name
nextcloudDatabase="nextcloud"
# TODO: Your Nextcloud database user
dbUser="nextcloud"
#echo "dbUser is $dbUser"
# TODO: The password of the Nextcloud database user supply by user input
dbPassword=$1
#echo "your passord is: $dbPassword"
# TODO: Your web server user
webserverUser="www"

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
     echo "ERROR: No $nextcloudDatabase database password to restore given!"
     echo "for example ${0} <dbPassword>"
exit 1
fi


#
# Check for root
#
if [ "$(id -u)" != "0" ]
then
    echo "ERROR: This script has to be run as root!"
    exit 1
fi

#
# Check if backup dir exists
#
if [ ! -d "${currentRestoreDir}" ]
then
	 echo "ERROR: Backup ${restore} not found!"
    exit 1
fi

#
# Set maintenance mode
#
echo "Set maintenance mode for Nextcloud..."
cd "${nextcloudFileDir}"
su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:mode --on'
#sudo -u "${webserverUser}" php occ maintenance:mode --on
cd ~
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
# Copy config.php to /mnt/NextcloudBackups
#
cp $nextcloudFileDir/config/config.php $mainBackupDir/
echo "copy config.php"
echo "done"
echo

#
# Delete old Nextcloud direcories
#
echo "Deleting old Nextcloud file directory..."
rm -r "${nextcloudFileDir}"
mkdir -p "${nextcloudFileDir}"
echo "Done"
echo

echo "Deleting old Nextcloud data directory..."
rm -r "${nextcloudDataDir}"
mkdir -p "${nextcloudDataDir}"
echo "Done"
echo

#
# Restore file and data directory
#
echo "Restoring Nextcloud file directory..."
tar -xpzf "${currentRestoreDir}/${fileNameBackupFileDir}" -C "${nextcloudFileDir}"
echo "tar -xpzf "${currentRestoreDir}/${fileNameBackupFileDir}" -C ${nextcloudFileDir}"
#echo "rsync -Aax "${currentRestoreDir}/nextcloud/" ${nextcloudFileDir}"
#rsync -Aax "${currentRestoreDir}/nextcloud/" ${nextcloudFileDir}
echo "Done"
echo

echo "Restoring Nextcloud data directory..."
tar -xpzf "${currentRestoreDir}/${fileNameBackupDataDir}" -C "${nextcloudDataDir}"
echo "tar -xpzf "${currentRestoreDir}/${fileNameBackupDataDir}" -C ${nextcloudDataDir}"
#echo "rsync -Aax "${currentRestoreDir}/files/" ${nextcloudDataDir}"
#rsync -Aax ${currentRestoreDir}/files/ ${nextcloudDataDir}
echo "Done"
echo

#
# Restore database
#
echo "Dropping old Nextcloud DB..."
mysql -h localhost -u "${dbUser}" -p"${dbPassword}" -e "DROP DATABASE ${nextcloudDatabase}"
echo "Done"
echo

echo "Creating new DB for Nextcloud..."
mysql -h localhost -u "${dbUser}" -p"${dbPassword}" -e "CREATE DATABASE ${nextcloudDatabase}"
echo "Done"
echo

echo "Restoring backup DB..."
mysql -h localhost -u "${dbUser}" -p"${dbPassword}" "${nextcloudDatabase}" < "${currentRestoreDir}/${fileNameBackupDb}"
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
# Set directory permissions
#
echo "Setting directory permissions..."
chown -R "${webserverUser}":"${webserverUser}" "${nextcloudFileDir}"
chown -R "${webserverUser}":"${webserverUser}" "${nextcloudDataDir}"
echo "Done"
echo

#
# Change the Database user and password back to the original not the backup
# Doesn't work yet- to be used if backup you restore has a different database dbuser and dbpassword
#
#sed -i '' "s/'dbuser' => [^[:space:]]*/'dbuser' => '${dbUser}'/" /usr/local/www/nextcloud/config/config.php
#sed -i '' "s/'dbpassword' => [^[:space:]]*/'dbpassword' => '${dbPassword}'/" /usr/local/www/nextcloud/config/config.php
#su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set dbuser --value="${dbUser}"'
#su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set dbpassword --value="${dbPassword}"'

#echo "changed the Database user and password"

#
# Copy config.php back to original location
#
cp $mainBackupDir/config.php "${nextcloudFileDir}/config/"
rm $mainBackupDir/config.php
echo "replace with original config.php"
echo "done"
echo


#
# Update the system data-fingerprint (see https://docs.nextcloud.com/server/13/admin_manual/configuration_server/occ_command.html#maintenance-commands-label)
#
echo "Updating the system data-fingerprint..."
cd "${nextcloudFileDir}"
su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:data-fingerprint'
#sudo -u "${webserverUser}" php occ maintenance:data-fingerprint
echo "Done"
echo

#
# Disable 2 factor authentication and repair DB to fix and restore all shares
#
su -m www -c 'php /usr/local/www/nextcloud/occ twofactor:disable admin'
su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:repair'


#
# Disbale maintenance mode
#
echo "Switching off maintenance mode..."
cd "${nextcloudFileDir}"
su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:mode --off'
#sudo -u "${webserverUser}" php occ maintenance:mode --off
echo "Done"
echo

#
# Reset nextcloud admin password
#
echo "reset admin password"
su -m www -c 'php /usr/local/www/nextcloud/occ user:resetpassword admin'
echo

#echo "If you receive errors with the last 2 commands you have to edit the config.php dbuser and dbpassword and run the last 2 commands manually"
#echo "su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:data-fingerprint'"
#echo "su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:mode --off'"
echo
echo "DONE!"
echo "Backup ${restore} successfully restored."

