#!/bin/sh
# Build an iocage jail under FreeNAS 11.1 using the current release of Nextcloud 13
# https://github.com/danb35/freenas-iocage-nextcloud

# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privileges"
   exit 1
fi

# Initialize defaults
JAIL_IP=""
DEFAULT_GW_IP=""
INTERFACE=""
VNET="off"
POOL_PATH=""
JAIL_NAME="nextcloud"
TIME_ZONE=""
HOST_NAME=""
DB_PATH=""
FILES_PATH=""
PORTS_PATH=""
STANDALONE_CERT=0
DNS_CERT=0
TEST_CERT="--test"
C_NAME="US"
ST_NAME=""
L_NAME=""
O_NAME=""
OU_NAME=""
EMAIL_NAME=""

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. $SCRIPTPATH/nextcloud-config
CONFIGS_PATH=$SCRIPTPATH/configs
DB_ROOT_PASSWORD=$(openssl rand -base64 16)
DB_PASSWORD=$(openssl rand -base64 16)
ADMIN_PASSWORD=$(openssl rand -base64 12)

# Check for nextcloud-config and set configuration
if ! [ -e $SCRIPTPATH/nextcloud-config ]; then
  echo "$SCRIPTPATH/nextcloud-config must exist."
  exit 1
fi

# Check that necessary variables were set by nextcloud-config
if [ -z $JAIL_IP ]; then
  echo 'Configuration error: JAIL_IP must be set'
  exit 1
fi
if [ -z $DEFAULT_GW_IP ]; then
  echo 'Configuration error: DEFAULT_GW_IP must be set'
  exit 1
fi
if [ -z $INTERFACE ]; then
  echo 'Configuration error: INTERFACE must be set'
  exit 1
fi
if [ -z $POOL_PATH ]; then
  echo 'Configuration error: POOL_PATH must be set'
  exit 1
fi
if [ -z $TIME_ZONE ]; then
  echo 'Configuration error: TIME_ZONE must be set'
  exit 1
fi
if [ -z $HOST_NAME ]; then
  echo 'Configuration error: HOST_NAME must be set'
  exit 1
fi
if [ $STANDALONE_CERT -eq 0 ] && [ $DNS_CERT -eq 0 ]; then
  echo 'Configuration error: Either STANDALONE_CERT or DNS_CERT'
  echo 'must be set to 1.'
  exit 1
fi
if [ $DNS_CERT -eq 1 ] && ! [ -x $CONFIGS_PATH/acme_dns_issue.sh ]; then
  echo 'If DNS_CERT is set to 1, configs/acme_dns_issue.sh must exist'
  echo 'and be executable.'
  exit 1
fi

# If DB_PATH, FILES_PATH, and PORTS_PATH weren't set in nextcloud-config, set them
if [ -z $DB_PATH ]; then
  DB_PATH="${POOL_PATH}/db"
fi
if [ -z $FILES_PATH ]; then
  FILES_PATH="${POOL_PATH}/files"
fi
if [ -z $PORTS_PATH ]; then
  PORTS_PATH="${POOL_PATH}/portsnap"
fi

# Sanity check DB_PATH, FILES_PATH, and PORTS_PATH -- they all have to be different,
# and can't be the same as POOL_PATH
if [ "${DB_PATH}" = "${FILES_PATH}" ] || [ "${FILES_PATH}" = "${PORTS_PATH}" ] || [ "${PORTS_PATH}" = "${DB_PATH}" ]
then
  echo "DB_PATH, FILES_PATH, and PORTS_PATH must all be different!"
  exit 1
fi

if [ "${DB_PATH}" = "${POOL_PATH}" ] || [ "${FILES_PATH}" = "${POOL_PATH}" ] || [ "${PORTS_PATH}" = "${POOL_PATH}" ] 
then
  echo "DB_PATH, FILES_PATH, and PORTS_PATH must all be different"
  echo "from POOL_PATH!"
  exit 1
fi

# Make sure DB_PATH is empty -- if not, MariaDB will choke
if [ "$(ls -A $DB_PATH)" ]; then
  echo "$DB_PATH is not empty!"
  echo "DB_PATH must be empty, otherwise this script will break your existing database."
  exit 1
fi
#openssl parameters
if [ -z $C_NAME ]; then
echo 'Configuration error: C_NAME must be set'
exit 1
fi
    
if [ -z $ST_NAME ]; then
echo 'Configuration error: ST_NAME must be set'
exit 1
fi
        
if [ -z $L_NAME ]; then
echo 'Configuration error: L_NAME must be set'
exit 1
fi
            
if [ -z $O_NAME ]; then
echo 'Configuration error: O_NAME must be set'
exit 1
fi
                
if [ -z $OU_NAME ]; then
echo 'Configuration error: OU_NAME must be set'
exit 1
fi

if [ -z $EMAIL_NAME ]; then
echo 'Configuration error: OU_NAME must be set'
exit 1
fi

#echo '{"pkgs":["nano","openssl","py27-certbot","nginx","mariadb101-server","redis","php70-bz2","php70-ctype","php70-curl","php70-dom","php70-exif","php70-fileinfo","php70-filter","php70-gd","php70-hash","php70-iconv","php70-intl","php70-json","php70-mbstring","php70-mcrypt","php70-pdo_mysql","php70-openssl","php70-posix","php70-session","php70-simplexml","php70-xml","php70-xmlreader","php70-xmlwriter","php70-xsl","php70-wddx","php70-zip","php70-zlib","php70-opcache"]}' > /tmp/pkg.json

echo '{"pkgs":["nano","openssl","py27-certbot","nginx","mariadb101-server","redis","php72-ctype","php72-dom","php72-gd","php72-iconv","php72-json","php72-mbstring","php72-posix","php72-simplexml","","php72-xmlreader","php72-xmlwriter","php72-zip","php72-zlib","php72-pdo_mysql","php72-hash","php72-xml","php72-session","php72-mysqli","php72-wddx","php72-xsl","php72-filter","php72-curl","php72-fileinfo","php72-bz2","php72-intl","php72-openssl","php72-ldap","php72-ftp","php72-imap","php72-exif","php72-gmp","php72-memcache","php72-opcache","php72-pcntl","php72","mod_php72"]}' > /tmp/pkg.json
iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r 11.1-RELEASE ip4_addr="${INTERFACE}|${JAIL_IP}/24" defaultrouter="${DEFAULT_GW_IP}" boot="on" host_hostname="${JAIL_NAME}" vnet="${VNET}"

rm /tmp/pkg.json

#mkdir -p ${DB_PATH}/
chown -R 88:88 ${DB_PATH}/
#mkdir -p ${FILES_PATH}
chown -R 80:80 ${FILES_PATH}
##mkdir -p ${PORTS_PATH}/ports
mkdir -p ${PORTS_PATH}/db
iocage exec ${JAIL_NAME} mkdir -p /mnt/files
iocage exec ${JAIL_NAME} mkdir -p /var/db/mysql
iocage exec ${JAIL_NAME} mkdir -p /mnt/configs
#iocage fstab -a ${JAIL_NAME} ${PORTS_PATH}/ports /usr/ports nullfs rw 0 0
#iocage fstab -a ${JAIL_NAME} ${PORTS_PATH}/db /var/db/portsnap nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${FILES_PATH} /mnt/files nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${DB_PATH} /var/db/mysql  nullfs  rw  0  0
iocage fstab -a ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0
iocage exec ${JAIL_NAME} chown -R www:www /mnt/files
iocage exec ${JAIL_NAME} chmod -R 770 /mnt/files
#iocage exec ${JAIL_NAME} "if [ -z /usr/ports ]; then portsnap fetch extract; else portsnap auto; fi"
#iocage exec ${JAIL_NAME} chsh -s /usr/local/bin/bash root
iocage exec ${JAIL_NAME} fetch -o /tmp https://download.nextcloud.com/server/releases/latest.tar.bz2
#iocage exec ${JAIL_NAME} fetch -o /tmp https://download.nextcloud.com/server/releases/latest-12.tar.bz2
iocage exec ${JAIL_NAME} tar xjf /tmp/latest.tar.bz2 -C /usr/local/www/
#iocage exec ${JAIL_NAME} tar xjf /tmp/latest-12.tar.bz2 -C /usr/local/www/
iocage exec ${JAIL_NAME} rm /tmp/latest.tar.bz2
iocage exec ${JAIL_NAME} chown -R www:www /usr/local/www/nextcloud/
iocage exec ${JAIL_NAME} sysrc nginx_enable="YES"
iocage exec ${JAIL_NAME} sysrc mysql_enable="YES"
iocage exec ${JAIL_NAME} sysrc redis_enable="YES"
iocage exec ${JAIL_NAME} sysrc php_fpm_enable="YES"
iocage exec ${JAIL_NAME} -- mkdir -p /usr/local/etc/nginx/ssl/

iocage exec ${JAIL_NAME} 'echo 'DEFAULT_VERSIONS+=ssl=openssl' >> /etc/make.conf'
iocage exec ${JAIL_NAME} portsnap fetch extract
iocage exec ${JAIL_NAME} make -C /usr/ports/databases/pecl-redis clean install BATCH=yes
iocage exec ${JAIL_NAME} make -C /usr/ports/devel/pecl-APCu clean install BATCH=yes

echo "before copy ssl directory"
# Copy and edit pre-written config files
#iocage exec ${JAIL_NAME} pkg install openssl -y
iocage exec ${JAIL_NAME} mkdir -p /usr/local/etc/nginx/ssl/
echo "make directory /usr/local/etc/nginx/ssl/"
iocage exec ${JAIL_NAME} -- openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /usr/local/etc/nginx/ssl/nginx-selfsigned.key -out /usr/local/etc/nginx/ssl/nginx-selfsigned.crt -subj "/C=${C_NAME}/ST=$P{ST_NAME}/L=${L_NAME}/O=${O_NAME}/OU={OU_NAME}/CN={HOST_NAME}"
echo "openssl key generated"
iocage exec ${JAIL_NAME} -- openssl dhparam -out /usr/local/etc/nginx/ssl/dhparam.pem 2048
echo "dhparam done"
iocage exec ${JAIL_NAME} cp -f /mnt/configs/nginx.conf /usr/local/etc/nginx/nginx.conf
iocage exec ${JAIL_NAME} cp -f /mnt/configs/php.ini /usr/local/etc/php.ini
iocage exec ${JAIL_NAME} cp -f /mnt/configs/redis.conf /usr/local/etc/redis.conf      
iocage exec ${JAIL_NAME} cp -f /mnt/configs/www.conf /usr/local/etc/php-fpm.d/
iocage exec ${JAIL_NAME} cp -f /usr/local/share/mysql/my-small.cnf /var/db/mysql/my.cnf
iocage exec ${JAIL_NAME} sed -i '' "s/yourhostnamehere/${HOST_NAME}/" /usr/local/etc/nginx/nginx.conf
iocage exec ${JAIL_NAME} sed -i '' "s/youripaddress/${JAIL_IP}/" /usr/local/etc/nginx/nginx.conf
#iocage exec ${JAIL_NAME} sed -i '' "s/#skip-networking/skip-networking/" /var/db/mysql/my.cnf
#iocage exec ${JAIL_NAME} sed -i '' "s|mytimezone|${TIME_ZONE}|" /usr/local/etc/php.ini
# iocage exec ${JAIL_NAME} openssl dhparam -out /usr/local/etc/pki/tls/private/dhparams_4096.pem 4096
iocage restart ${JAIL_NAME}

#iocage exec ${JAIL_NAME} -- certbot certonly --webroot -w /usr/local/www -d ${HOST_NAME} -d ${HOST_NAME} --agree-tos -m ${EMAIL_NAME} --no-eff-email
iocage exec ${JAIL_NAME} -- certbot certonly --staging --webroot -w /usr/local/www -d ${HOST_NAME} -d ${HOST_NAME} --agree-tos -m ${EMAIL_NAME} --no-eff-email
echo "certbot done"

#*****************delete this section after staging complete to copy ssl certificate from another jail
iocage exec ${JAIL_NAME} mkdir -p /usr/local/etc/letsencrypt/live/${HOST_NAME}/
cp -r /mnt/iocage/jails/nextcloud2/root/usr/local/etc/letsencrypt/archive/${HOST_NAME}/ /mnt/iocage/jails/${JAIL_NAME}/root/usr/local/etc/letsencrypt/live/${HOST_NAME}/
#iocage exec ${JAIL_NAME} sed -i '' "s/fullchain/fullchain1/" /usr/local/etc/nginx/nginx.conf
#iocage exec ${JAIL_NAME} sed -i '' "s/chain/chain1/" /usr/local/etc/nginx/nginx.conf
#iocage exec ${JAIL_NAME} sed -i '' "s/privkey/privkey1/" /usr/local/etc/nginx/nginx.conf
#iocage exec ${JAIL_NAME} sed -i '' "s/fullchain/fullchain1/" /usr/local/etc/nginx/nginx.conf
iocage exec ${JAIL_NAME} mv /usr/local/etc/letsencrypt/live/${HOST_NAME}/fullchain1.pem /usr/local/etc/letsencrypt/live/${HOST_NAME}/fullchain.pem
iocage exec ${JAIL_NAME} mv /usr/local/etc/letsencrypt/live/${HOST_NAME}/chain1.pem /usr/local/etc/letsencrypt/live/${HOST_NAME}/chain.pem
iocage exec ${JAIL_NAME} mv /usr/local/etc/letsencrypt/live/${HOST_NAME}/privkey1.pem /usr/local/etc/letsencrypt/live/${HOST_NAME}/privkey.pem

# Secure database, set root password, create Nextcloud DB, user, and password
iocage exec ${JAIL_NAME} mysql -u root -e "CREATE DATABASE nextcloud;"
iocage exec ${JAIL_NAME} mysql -u root -e "GRANT ALL ON nextcloud.* TO nextcloud@localhost IDENTIFIED BY '${DB_PASSWORD}';"
iocage exec ${JAIL_NAME} mysql -u root -e "DELETE FROM mysql.user WHERE User='';"
iocage exec ${JAIL_NAME} mysql -u root -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
iocage exec ${JAIL_NAME} mysql -u root -e "DROP DATABASE IF EXISTS test;"
iocage exec ${JAIL_NAME} mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
iocage exec ${JAIL_NAME} mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('${DB_ROOT_PASSWORD}') WHERE User='root';"
iocage exec ${JAIL_NAME} mysqladmin reload
iocage exec ${JAIL_NAME} cp -f /mnt/configs/my.cnf /root/.my.cnf
iocage exec ${JAIL_NAME} sed -i '' "s|mypassword|${DB_ROOT_PASSWORD}|" /root/.my.cnf

# Save passwords for later reference
iocage exec ${JAIL_NAME} echo "MySQL root password is ${DB_ROOT_PASSWORD}" > /root/db_password.txt
iocage exec ${JAIL_NAME} echo "Nextcloud database password is ${DB_PASSWORD}" >> /root/db_password.txt
iocage exec ${JAIL_NAME} echo "Nextcloud Administrator password is ${ADMIN_PASSWORD}" >> /root/db_password.txt
iocage exec ${JAIL_NAME} echo "Data folder = /mnt/files, Database host = localhost:/tmp/mysql.sock" >> /root/db_password.txt

# If standalone mode was used to issue certificate, reissue using webroot
#if [ $STANDALONE_CERT -eq 1 ]; then
#  iocage exec ${JAIL_NAME} /root/.acme.sh/acme.sh --issue ${TEST_CERT} --home "/root/.acme.sh" -d ${HOST_NAME} -w /usr/local/www/apache24/data -k 4096 --fullchain-file /usr/local/etc/pki/tls/certs/fullchain.pem --key-file /usr/local/etc/pki/tls/private/privkey.pem --reloadcmd "service apache24 reload"
#fi


# Don't need /mnt/configs any more, so unmount it
iocage fstab -r ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0
iocage exec ${JAIL_NAME} service nginx restart


# Done!
echo "Installation complete!"
echo "Using your web browser, go to https://${HOST_NAME} to log in"
echo "Default user is admin, password is ${ADMIN_PASSWORD}"
echo ""
echo "Database Information"
echo "--------------------"
echo "Database user = nextcloud"
echo "Database password = ${DB_PASSWORD}"
echo "The MariaDB root password is ${DB_ROOT_PASSWORD}"
echo ""
echo "All passwords are saved in /root/db_password.txt"
echo "to start run https://${JAIL_IP}/nextcloud and enter info, Data folder = /mnt/files, Database host = localhost:/tmp/mysql.sock"
