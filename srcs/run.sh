#!/bin/bash

function stopall ()
{
	echo "One or more services has crashed"
	service mysql status
	service php7.3-fpm status
	service nginx status
	echo "Stopping container"
	service nginx stop
	service php7.3-fpm stop
	service mysql stop
	exit 1
}

touch /var/log/nginx/error.log
touch /var/log/nginx/access.log
touch /var/log/mysql/error.log
touch /var/log/php7.3-fpm.log
tail -f -n 0 /var/log/nginx/error.log &
tail -f -n 0 /var/log/nginx/access.log &
tail -f -n 0 /var/log/mysql/error.log &
tail -f -n 0 /var/log/php7.3-fpm.log &

echo "Starting services..."
service php7.3-fpm start || stopall
service mysql start || stopall
service nginx start || stopall
echo "Services started !"

while [ 1 ]
do
	service mysql status > /dev/null || stopall
	service php7.3-fpm status > /dev/null || stopall
	service nginx status > /dev/null || stopall
	sleep 10
done
