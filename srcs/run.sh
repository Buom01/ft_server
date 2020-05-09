#!/bin/bash

trap stopall SIGTERM SIGINT SIGQUIT SIGABRT SIGKILL

c=$(printf '\033')

main_pre="$c[1m$c[36m=>$c[0m"
nginx_error_pre="[$c[1m$c[32mNGINX_ERR$c[0m] "
nginx_access_pre="[$c[1m$c[92mNGINX_ACC$c[0m] "
mysql_error_pre="[$c[1m$c[93m  MYSQL  $c[0m] "
php_pre="[$c[1m$c[94m PHP_FPM $c[0m] "

function stopall ()
{
	echo "$main_pre One or more services has crashed. Status :"
	service mysql status | sed -u "s/^/$main_pre /"
	service php7.3-fpm status | sed -u "s/^/$main_pre /"
	service nginx status | sed -u "s/^/$main_pre /"
	echo "$main_pre Stopping container..."
	service nginx stop | sed -u "s/^/$main_pre /"
	service php7.3-fpm stop | sed -u "s/^/$main_pre /"
	service mysql stop | sed -u "s/^/$main_pre /"
	killall tail | sed -u "s/^/$main_pre /"
	echo "$main_pre Good bye."
	exit 1
}

function checkconfig ()
{
	if [ -z "$ADMIN_PASSWORD" ]
	then
		echo "$main_pre You must set ADMIN_PASSWORD to access phpmyadmin."
		echo "$main_pre Exiting..."
		exit 1
	fi
	
	if [ -z "$WORDPRESS_PASSWORD" ]
	then
		export WORDPRESS_PASSWORD=$(pwgen -s -y -1)
	fi

	echo "$main_pre Use index is set to $USEINDEX"	
}

function initssl()
{
	if [[ -f /etc/ssl/certs/main.pem && -f /etc/ssl/private/main.key ]];
	then
		export USESSL=1
		echo "$main_pre SSL certs found !"
	else
		export USESSL=0

		if [ $GENERATESSL == 1 ];
		then
			echo "$main_pre Generating SSL certs..."
			openssl req -newkey rsa:4096 -days 365 -batch -nodes -x509\
				-keyout /etc/ssl/private/main.key \
				-out /etc/ssl/certs/main.pem || exit 1
			export USESSL=1
			echo "$main_pre Using generated SSL certs"
		fi
	fi
}

function initmysql ()
{
	echo "$main_pre Initiating MySQL..."
	gpp	-DWORDPRESS_PASSOWRD=$WORDPRESS_PASSWORD \
		-DADMIN_PASSWORD=$ADMIN_PASSWORD \
		./mysql.sql.template > /tmp/mysqld-init-file
	sudo -u mysql mysqld --init-file=/tmp/mysqld-init-file || exit 1
	rm /tmp/mysqld-init-file
}

function initnginxconfig ()
{
	echo "$main_pre Writing nginx config..."
	gpp -DUSEINDEX=$USEINDEX -DUSESSL=$USESSL \
		/etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
}

function initwordpressconfig ()
{
	echo "$main_pre Initiating wordpress config..."
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
	echo "$main_pre Starting logs..."
	touch /var/log/nginx/error.log
	touch /var/log/nginx/access.log
	touch /var/log/mysql/error.log
	touch /var/log/php7.3-fpm.log
	tail -f -n 0 /var/log/nginx/error.log | sed -u "s/^/$nginx_error_pre/" &
	tail -f -n 0 /var/log/nginx/access.log | sed -u "s/^/$nginx_access_pre/" &
	tail -f -n 0 /var/log/mysql/error.log | sed -u "s/^/$mysql_error_pre/" &
	tail -f -n 0 /var/log/php7.3-fpm.log | sed -u "s/^/$php_pre/" &
}

function runall ()
{
	echo "$main_pre Starting services..."
	service mysql start | sed -u "s/^/$main_pre /" || stopall
	service php7.3-fpm start | sed -u "s/^/$main_pre /" || stopall
	service nginx start | sed -u "s/^/$main_pre /" || stopall
	echo "$main_pre All services started !"
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
