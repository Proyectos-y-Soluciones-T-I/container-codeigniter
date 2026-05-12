FROM php:7.4.33-fpm-alpine

# Instalar dependencias, compilar extensiones y limpiar en un solo RUN
# para reducir capas y tamaño final de la imagen
# 1. Runtime libs: se quedan en la imagen (necesarias para gd.so, zip.so, etc.)
# 2. Build deps: solo para compilar, se borran al final
RUN apk add --no-cache \
        libpng \
        libjpeg-turbo \
        libwebp \
        freetype \
        libzip \
        oniguruma \
        icu \
        curl \
        libxml2 \
        zlib \
        mysql-client \
        fcgi \
    && apk add --no-cache --virtual .build-deps \
        libpng-dev \
        libjpeg-turbo-dev \
        libwebp-dev \
        freetype-dev \
        libzip-dev \
        oniguruma-dev \
        bzip2-dev \
        icu-dev \
        zlib-dev \
        curl-dev \
        openssl-dev \
        libxml2-dev \
        g++ \
        make \
        autoconf \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_mysql \
        mysqli \
        gd \
        zip \
        xml \
        mbstring \
        bcmath \
        opcache \
    && apk del .build-deps

# Instalar Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Healthcheck: verificar que php-fpm responde en el pool por defecto
RUN echo '#!/bin/sh' > /usr/local/bin/php-fpm-healthcheck \
    && echo 'SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000' >> /usr/local/bin/php-fpm-healthcheck \
    && chmod +x /usr/local/bin/php-fpm-healthcheck

# Configuración PHP externalizada (php/custom.ini) — cambiable sin rebuild
COPY php/custom.ini /usr/local/etc/php/conf.d/custom.ini

# Habilitar ping de php-fpm para healthcheck
COPY php/zz-healthcheck.conf /usr/local/etc/php-fpm.d/zz-healthcheck.conf

# Directorio de trabajo por defecto
WORKDIR /var/www/html
