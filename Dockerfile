FROM ubuntu:10.04
MAINTAINER Brandon Plasters <bmilesp@gmail.com>

RUN apt-get update --fix-missing \
    && apt-get install -y \
        libbz2-dev \
        libpng-dev \
        libcurl4-openssl-dev \
        libltdl-dev \
        libmcrypt-dev \
        libmhash-dev \
        libmysqlclient-dev \
        php5-gd \
        libjpeg-dev \
        libpcre3-dev \
        libxml2-dev \
        make \
        patch \
        xmlstarlet \
        perl \
        libncurses5-dev \
        mailutils \
        postfix \
        autoconf -y

COPY tmp/ /usr/local/src/
RUN gunzip /usr/local/src/*.gz && tar xf /usr/local/src/php-5.2.16.tar -C /usr/local/src

RUN tar xf /usr/local/src/httpd-2.2.29.tar -C /usr/local/src
WORKDIR /usr/local/src/httpd-2.2.29
RUN ./configure \
    --enable-so \
    --enable-module=most \
    --enable-rewrite \
    --enable-ssl
RUN make && make install

RUN tar xf /usr/local/src/mysql-dfsg-5.1_5.1.73.orig.tar -C /usr/local/src

WORKDIR /usr/local/src/php-5.2.16

RUN ln -s /usr/include /opt/include && ln -s /usr/lib64 /opt/lib

# Apply patches
RUN patch -p1 -i ../suhosin-patch-5.2.16-0.9.7.patch
# Configure PHP
RUN ./configure \
    --with-apxs2=/usr/local/apache2/bin/apxs \
    --enable-mbstring \
    --enable-sockets \
    --enable-bcmath \
    --with-gd \
    --with-gettext \
    --with-libdir \
    --with-libdir=lib64 \
    --with-mcrypt \
    --with-mhash \
    --with-mysql \
    --with-pdo-mysql \
    --with-mysql-sock=/tmp/mysql.socket \
    --with-mysqli \
    --with-openssl \
    --with-pcre-regex \
    --with-jpeg-dir=/opt \
    --with-zlib \
    --with-curl \
    --with-pear
# Install
RUN make && make install

# Get out of /usr/local/src
RUN cp /usr/local/src/php-5.2.16/php.ini-dist /usr/local/lib/php.ini

RUN mkdir -p /var/www/html && chmod 755 /var/www/html

#sed for PHP ini
RUN sed -ri -e 's/^display_errors\s*=\s*Off/display_errors = On/g'\
    -e 's/^error_reporting\s*=.*$/error_reporting = E_ALL \& ~E_DEPRECATED \& ~E_NOTICE/g' \
    -e 's/^error_reporting\s*=.*$/error_reporting = E_ALL \& ~E_DEPRECATED \& ~E_NOTICE/g' \
    -e "s/post_max_size = 8M/post_max_size = 2000M/g" \
    -e "s/upload_max_filesize = 2M/upload_max_filesize = 20000M/g" \
    -e "s/max_execution_time = 30/max_execution_time = 30000/g" \
    -e "s/extension_dir =.*/extension_dir = \"\/usr\/local\/lib\/php\/extensions\/no-debug-non-zts-20060613\"/g" \
    -e "s/memory_limit = 128M/memory_limit = 2048M/g" \
    -e "\$aextension=php_pdo.so" \
    -e "\$aextension=php_pdo_mysql.so" \
    -e "\$aextension=mongo.so" \
    -e "\$aextension=php_gd2.so" \
    -e "\$asendmail_path = /usr/sbin/sendmail -t -i" \
    -e "\$asendmail_from = system@undergroundshirts.com" \
     /usr/local/lib/php.ini

#VOLUME ["/usr/local/apache2/htdocs"]

COPY default.conf /etc/apache2/sites-available/default.conf

RUN adduser www-data www-data

RUN chgrp www-data -R /usr/local/apache2/htdocs

#add mongo driver
WORKDIR /usr/local/src

RUN tar xf /usr/local/src/mongo-php-driver-1.5.8.tar -C /usr/local/src
WORKDIR /usr/local/src/mongo-php-driver-1.5.8

RUN phpize \
    && ./configure \
    && make all \
    && make install

RUN sed -i -e "s/Options FollowSymLinks/Options Indexes FollowSymLinks Includes/g" \
    -e "1iServerName localhost" \
    -e "1iNameVirtualHost *:80" \
    -e "1iNameVirtualHost *:443" \
    -e "s/User daemon/User www-data/g" \
    -e "s/Group daemon/Group www-data/g" \
    -e "\$aInclude  /etc/apache2/sites-available/default.conf " \
    -e "\$aAddHandler php5-script .php" \
    -e "\$aAddType text/html .php" \
    -e "\$aDirectoryIndex index.html index.php" \
    /usr/local/apache2/conf/httpd.conf

#Email
#RUN debconf-set-selections <<< "postfix postfix/mailname string your.hostname.com"

COPY run /usr/local/bin/
RUN chmod +x /usr/local/bin/run

ENV TERM xterm
EXPOSE 80 443
CMD ["/usr/local/bin/run"]