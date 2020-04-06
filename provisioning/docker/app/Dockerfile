FROM php:7.4-apache

RUN a2enmod rewrite headers

RUN apt-get update && apt-get install -y \
    zlib1g-dev \
    libicu-dev \
    libpq-dev \
    libxml2-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    git \
    unzip \
    wget \
    tar

RUN docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ && \
    docker-php-ext-install -j2 iconv intl pdo_mysql zip gd && \
    pecl install xdebug apcu && \
    docker-php-ext-enable xdebug apcu opcache

RUN mkdir /var/cache/app && \
    chown www-data:www-data /var/cache/app && \
    mkdir /var/log/app && \
    chown www-data:www-data /var/log/app

ENV COMPOSER_ALLOW_SUPERUSER 1
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

#RUN mkdir /usr/local/share/GeoIP && \
#    wget -q -O - http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz > /tmp/geolite.tar.gz && \
#    tar xzf /tmp/geolite.tar.gz --strip=1 -C /usr/local/share/GeoIP GeoLite2-City_20191008/GeoLite2-City.mmdb