FROM debian:buster

ENV ADMIN_PASSWORD 42
ENV GENERATESSL 0
ENV USEINDEX 1

ENV DEBIAN_FRONTEND noninteractive
ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE 1


RUN apt-get update -q && apt-get upgrade -y -q
RUN apt-get install -y -q wget openssl gpp pwgen sudo  
RUN apt-get install -y -q nginx
RUN apt-get install -y -q php7.3-fpm php7.3-mysql

COPY ./srcs/mysql-apt-config_0.8.9-1_all.deb /tmp
RUN cd /tmp && \
apt-get install -y -q ./mysql-apt-config_0.8.9-1_all.deb 
RUN apt-key adv --keyserver keys.gnupg.net --receive-keys 8C718D3B5072E1F5
RUN apt-get update -q

RUN apt-get install -y -q mysql-server mysql-client

COPY ./srcs/phpMyAdmin-5.0.2-all-languages.tar.gz /tmp/
RUN cd /tmp && \
tar xf phpMyAdmin-5.0.2-all-languages.tar.gz -C /var/www && \
mv /var/www/phpMyAdmin-5.0.2-all-languages /var/www/phpmyadmin

COPY ./srcs/wordpress-5.4.tar.gz /tmp/
RUN cd /tmp && \
tar xf wordpress-5.4.tar.gz -C /var/www

RUN ln -s /var/www/phpmyadmin /var/www/wordpress/phpmyadmin

RUN rm -rf /tmp/*


COPY ./srcs/nginx.conf.template /etc/nginx/nginx.conf.template
COPY ./srcs/wp-config.php.template /root/wp-config.php.template
COPY ./srcs/wp-config.php.footer /root/wp-config.php.footer
COPY ./srcs/mysql.sql.template /root/mysql.sql.template


VOLUME /etc/ssl
VOLUME /var/lib/mysql
VOLUME /root/persistant


EXPOSE 80
EXPOSE 443

STOPSIGNAL SIGTERM

COPY ./srcs/run.sh /root/run.sh

WORKDIR /root
CMD ["bash", "/root/run.sh"]
