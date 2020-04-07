#!/bin/bash

trap stopall SIGHUP SIGINT SIGQUIT SIGABRT SIGKILL

c=$(printf '\033')

main_prefix="$c[1m$c[36m=>$c[0m"
nginx_error_prefix="[$c[1m$c[32mNGINX_ERR$c[0m] "
nginx_access_prefix="[$c[1m$c[92mNGINX_ACC$c[0m] "
mysql_error_prefix="[$c[1m$c[93m  MYSQL  $c[0m] "
php_prefix="[$c[1m$c[94m PHP_FPM $c[0m] "

function stopall ()
{
	echo "$main_prefix One or more services has crashed. Status :"
	service mysql status | sed "s/^/$main_prefix /"
	service php7.3-fpm status | sed "s/^/$main_prefix /"
	service nginx status | sed "s/^/$main_prefix /"
	echo "$main_prefix Stopping container..."
	service nginx stop | sed "s/^/$main_prefix /"
	service php7.3-fpm stop | sed "s/^/$main_prefix /"
	service mysql stop | sed "s/^/$main_prefix /"
	killall tail | sed "s/^/$main_prefix /"
	echo "$main_prefix Good bye."
	exit 1
}

function checkconfig ()
{
	if [ -z "$ADMIN_PASSWORD" ]
	then
		echo "$main_prefix You must set ADMIN_PASSWORD to access phpmyadmin."
		echo "$main_prefix Exiting..."
		exit 1
	fi
	
	if [ -z "$WORDPRESS_PASSWORD" ]
	then
		export WORDPRESS_PASSWORD=$(pwgen -s -y -1)
	fi

	echo "$main_prefix Use index is set to $USEINDEX"	
}

function initssl()
{
	if [[ -f /etc/ssl/certs/main.pem && -f /etc/ssl/private/main.key ]];
	then
		export USESSL=1
		echo "$main_prefix SSL certs found !"
	else
		export USESSL=0

		if [ $GENERATESSL == 1 ];
		then
			echo "$main_prefix Generating SSL certs..."
			openssl req -newkey rsa:4096 -days 365 -batch -nodes -x509\
				-keyout /etc/ssl/private/main.key \
				-out /etc/ssl/certs/main.pem || exit 1
			export USESSL=1
			echo "$main_prefix Using generated SSL certs"
		fi
	fi
}

function initmysql ()
{
	echo "$main_prefix Initiating MySQL..."
	gpp	-DWORDPRESS_PASSOWRD=$WORDPRESS_PASSWORD \
		-DADMIN_PASSWORD=$ADMIN_PASSWORD \
		./mysql.sql.template > /tmp/mysqld-init-file
	sudo -u mysql mysqld --init-file=/tmp/mysqld-init-file || exit 1
	rm /tmp/mysqld-init-file
}

function initnginxconfig ()
{
	echo "$main_prefix Writing nginx config..."
	gpp -DUSEINDEX=$USEINDEX -DUSESSL=$USESSL \
		/etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
}

function initwordpressconfig ()
{
	echo "$main_prefix Initiating wordpress config..."
	if [ ! -f ~/persistant/wordpresssalt ]
	then
		wget -O ~/persistant/wordpresssalt \
			https://api.wordpress.org/secret-key/1.1/salt/ || exit 1
	fi

	gpp	-DWORDPRESS_PASSOWRD=$WORDPRESS_PASSWORD \
		./wp-config.php.template > /var/www/wordpress/wp-config.php
	cat ~/persistant/wordpresssalt >>  /var/www/wordpress/wp-config.php
	cat ./wp-config.php.footer >> /var/www/wordpress/wp-config.php
}

function printlogs ()
{
	echo "$main_prefix Starting logs..."
	touch /var/log/nginx/error.log
	touch /var/log/nginx/access.log
	touch /var/log/mysql/error.log
	touch /var/log/php7.3-fpm.log
	tail -f -n 0 /var/log/nginx/error.log | sed "s/^/$nginx_error_prefix/" &
	tail -f -n 0 /var/log/nginx/access.log | sed "s/^/$nginx_access_prefix/" &
	tail -f -n 0 /var/log/mysql/error.log | sed "s/^/$mysql_error_prefix/" &
	tail -f -n 0 /var/log/php7.3-fpm.log | sed "s/^/$php_prefix/" &
}

function runall ()
{
	echo "$main_prefix Starting services..."
	service mysql start | sed "s/^/$main_prefix /" || stopall
	service php7.3-fpm start | sed "s/^/$main_prefix /" || stopall
	service nginx start | sed "s/^/$main_prefix /" || stopall
	echo "$main_prefix All services started !"
}

checkconfig
initssl
initnginxconfig
initwordpressconfig
initmysql

printlogs
runall

while [ 1 ]
do
	service mysql status > /dev/null || stopall
	service php7.3-fpm status > /dev/null || stopall
	service nginx status > /dev/null || stopall
	sleep 10
done
