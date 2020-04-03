#!/bin/bash

function stopall ()
{
	echo "One or more services has crashed"
	service status mysql
	service status php7.3-fpm
	service status nginx
	echo "Stopping container"
	service stop nginx
	service stop php7.3-fpm
	service stop mysql
	exit 1
}

tee /var/log/nginx/error.log &
tee /var/log/nginx/access.log &
tee /var/log/mysql/error.log &
tee /var/log/php7.3-fpm.log &

echo "Starting services..."
service start php7.3-fpm || stopall
service start mysql || stopall
service start nginx || stopall
echo "Services started !"

while [ 1 ]
do
	service status mysql > /dev/null || stopall
	service status php7.3-fpm > /dev/null || stopall
	service status nginx > /dev/null || stopall
	sleep 10
done
