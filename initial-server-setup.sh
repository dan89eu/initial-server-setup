#!/bin/bash

DLPATH='https://github.com/kostin/initial-server-setup/raw/master'
RPAF_IPS=`ip a | grep inet | awk '{print $2}' | awk -F/ '{print $1}' | sort -u | tr '\n' ' '`

if [ -a /root/mysql-root-password.txt ]
then
	echo 'Already set up'
	exit 0
fi

if [ ! `cat /etc/redhat-release | grep 'CentOS release 6'` ]
then
        echo 'Wrong OS!'
        exit 0
fi

echo 'Installing software...'

echo 'nameserver 8.8.8.8' > /etc/resolv.conf
killall -9 httpd

rpm -Uvh http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm
yum -y install epel-release
sed -i "s/mirrorlist=https/mirrorlist=http/" /etc/yum.repos.d/epel.repo
yum -y update
yum -y install nano git mc mailx pwgen nginx mysql-server phpMyAdmin proftpd psmisc net-tools httpd-itk mod_ssl php
rpm -Uvh http://centalt.prounixadmin.ru/repository/centos/6/x86_64/mod_rpaf-0.6-2.el6.x86_64.rpm

sed -i "s/#HTTPD=\/usr\/sbin\/httpd.worker/HTTPD=\/usr\/sbin\/httpd.itk/" /etc/sysconfig/httpd
MYSQLPASS=`pwgen 16 1`

wget -O /etc/httpd/conf.d/rpaf.conf $DLPATH/rpaf.conf
wget -O /etc/httpd/conf.d/php.conf $DLPATH/php.conf
wget -O /etc/httpd/conf.d/phpMyAdmin.conf $DLPATH/phpMyAdmin.conf
wget -O /etc/httpd/conf/httpd.conf $DLPATH/httpd.conf
wget -O /etc/php.ini $DLPATH/php.ini
wget -O /etc/my.cnf $DLPATH/my.cnf
wget -O /etc/proftpd.conf $DLPATH/proftpd.conf
wget -O /etc/nginx/nginx.conf $DLPATH/nginx.conf
wget -O /etc/logrotate.d/httpd $DLPATH/httpd

mkdir /opt/scripts
mkdir -p /backups/.deleted

wget -O /opt/scripts/backup.sh $DLPATH/backup.sh
wget -O /opt/scripts/hostadd.sh $DLPATH/hostadd.sh
wget -O /opt/scripts/hostdel.sh $DLPATH/hostdel.sh
wget -O /opt/scripts/vhost_template $DLPATH/vhost_template
chmod +x /opt/scripts/*.sh

mkdir /etc/httpd/conf/vhosts
sed -i "s/IPS/$RPAF_IPS/" /etc/httpd/conf.d/rpaf.conf
rm -f /etc/nginx/conf.d/*.conf

service httpd start
service mysqld start
service nginx start
service proftpd start
chkconfig httpd on
chkconfig mysqld on
chkconfig nginx on
chkconfig proftpd on

iptables -F
service iptables save

mysqladmin -u root password $MYSQLPASS
mysql -p$MYSQLPASS -B -N -e "drop database test"
echo $MYSQLPASS > /root/.mysql-root-password
echo "MySQL root password is $MYSQLPASS and it stored in /root/.mysql-root-password"

echo '05 03 * * * /opt/scripts/backup.sh' >> /var/spool/cron/root

mkdir /etc/www.skel
mkdir /etc/www.skel/public
mkdir /etc/www.skel/dev
mkdir /etc/www.skel/logs
mkdir /etc/www.skel/tmp

#DEVPASS=`pwgen 16 1`
DEVPASS='4389'
htpasswd -b -c /opt/scripts/.htpasswd 269 $DEVPASS
echo "Password (.htpasswd) for user 269 is $DEVPASS"

/opt/scripts/hostadd.sh 000default
echo "<?php print rand(); ?>" > /var/www/000default/public/index.php
