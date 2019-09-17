#!/usr/bin/env bash
# Run this as root
# redirect stdout/stderr to a file
#exec &> logfile.txt

echo '>> Updating the OS'
yum update -y
yum install wget unzip lsof strace htop vim -y
echo '>> Done! >>'

echo '>> Updating system Time & some tools'
timedatectl set-timezone America/New_York
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
echo '>> Done! >>'

echo '>> Installing EPEL & IUS yum repository'
yum install -y epel-release
RELEASEVER=$(rpm --eval %rhel)

if [[ $RELEASEVER -ne 6 ]] && [[ $RELEASEVER -ne 7 ]]; then
	echo "unsupported OS version"
	exit 1
fi

rpm --import https://repo.ius.io/RPM-GPG-KEY-IUS-$RELEASEVER
yum --assumeyes install https://repo.ius.io/ius-release-el$RELEASEVER.rpm

echo '>> Repository installation Done! >>'

echo '>> Installing Apache v2.4'
yum -y install httpd24u httpd24u-mod_ssl
echo '>> Done! >>'

echo '>> Securing Apache Instation >>'
cat <<EOF >> /etc/httpd/conf/httpd.conf
#
ServerSignature Off
ServerTokens Prod

Header append X-FRAME-OPTIONS "SAMEORIGIN"
#
<IfModule mod_headers.c>
    Header set X-XSS-Protection "1; mode=block"
</IfModule>
#
<IfModule mod_headers.c>
    Header edit Set-Cookie ^(.*)$ $1;HttpOnly;Secure
</IfModule>

FileETag None
TraceEnable off
EOF


cat <<EOF > /etc/httpd/conf.d/00-default.conf
#Default Vhost
<VirtualHost *:80>
ServerName default
UseCanonicalName Off
DocumentRoot /var/www/html
</VirtualHost>
EOF
sed -i '/mod_info/s/^/#/g' /etc/httpd/conf.modules.d/00-base.conf
sed -i '/mod_userdir/s/^/#/g' /etc/httpd/conf.modules.d/00-base.conf
systemctl enable httpd
systemctl start httpd
echo '>> Done! >>'


echo -n "Choose your php version:
1) php71
2) php72
3) php73
-> "

read opzione

if [ "$opzione" == "1" ]; 
then
yum -y install mod_php71u php71u-{cli,common,gd,intl,mbstring,pdo,process,json,xml,mysqlnd,bcmath,opcache,ioncube-loader,soap,imap,pecl-memcached,pecl-imagick,pecl-geoip, pecl-redis,pecl-igbinary}
elif [ "$opzione" == "2" ]; 
then
    yum -y install mod_php72u php72u-{cli,common,gd,intl,mbstring,pdo,process,json,xml,mysqlnd,bcmath,opcache,ioncube-loader,soap,imap,pecl-memcached,pecl-imagick,pecl-geoip,pecl-redis,pecl-igbinary}
elif [ "$opzione" == "3" ]; 
then
    yum -y install mod_php73 php73-{cli,common,gd,intl,mbstring,pdo,process,json,xml,mysqlnd,bcmath,opcache,soap,imap,pecl-memcached,pecl-imagick,pecl-geoip,pecl-redis,pecl-igbinary}
fi

echo '>>Modifying php.ini >>'
sed -i 's/memory_limit = 128M/memory_limit = 256M/g' /etc/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 32M/g' /etc/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 32M/g' /etc/php.ini
sed -i 's/short_open_tag = Off/short_open_tag = On/g' /etc/php.ini
sed -i 's/expose_php = On/expose_php = Off/g' /etc/php.ini
echo '>>Modifying php.ini done>>'

echo '>> Starting MySQL Installation >>'
yum -y remove mariadb-libs
yum -y install mariadb103-server postfix
systemctl enable mariadb
systemctl start mariadb
echo '>> Securing MySQL Installation >>'
mysql_secure_installation <<EOF

y
4d2pnMnmWR5rvQxD
4d2pnMnmWR5rvQxD
y
y
y
y
EOF
echo '>> Done! >>'
echo '>> Starting PhpMyAdmin Installation >>'
yum -y install phpMyAdmin49 phpMyAdmin49-httpd
read -s -p "Enter Password: " phpmyadminpass
htpasswd -bcm /usr/share/phpMyAdmin/passwd phpmyadmin $phpmyadminpass
sed -i '/AddDefaultCharset UTF-8/a AllowOverride None\nAuthType Basic\nAuthName "Restricted Access"\nAuthUserFile /usr/share/phpMyAdmin/passwd\nRequire valid-user' /etc/httpd/conf.d/phpMyAdmin.conf
systemctl restart httpd
