FROM debian:buster


ENV DEBIAN_FRONTEND noninteractive
ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE 1

RUN apt-get update -q && apt-get upgrade -y -q
RUN apt-get install -y -q wget openssl
RUN apt-get install -y -q nginx
RUN apt-get install -y -q php7.3-fpm php7.3-mysql

RUN cd /tmp && \
wget -q https://repo.mysql.com/mysql-apt-config_0.8.9-1_all.deb && \
apt-get install -y -q ./mysql-apt-config_0.8.9-1_all.deb 
RUN apt-key adv --keyserver keys.gnupg.net --receive-keys 8C718D3B5072E1F5
RUN apt-get update -q

RUN apt-get install -y -q mysql-server mysql-client

RUN cd /tmp && \
wget https://files.phpmyadmin.net/phpMyAdmin/\
5.0.2/phpMyAdmin-5.0.2-all-languages.tar.gz && \
tar xf phpMyAdmin-5.0.2-all-languages.tar.gz -C /var/www && \
mv /var/www/phpMyAdmin-5.0.2-all-languages /var/www/phpmyadmin

RUN cd /tmp && \
wget https://wordpress.org/wordpress-5.4.tar.gz && \
tar xf wordpress-5.4.tar.gz -C /var/www

RUN rm -rf /tmp/*


COPY ./srcs/nginx/phpmyadmin /etc/nginx/sites-enabled/phpmyadmin
#COPY ./srcs/nginx/wordpress /etc/nginx/sites-enabled/wordpress
COPY ./srcs/nginx/nginx.conf /etc/nginx/nginx.conf


VOLUME /etc/ssl
#VOLUME /data

#ENV USEINDEX true

EXPOSE 80
EXPOSE 443

COPY ./srcs/run.sh /root/run.sh

WORKDIR /root
ENTRYPOINT bash
EXEC ./run.sh
