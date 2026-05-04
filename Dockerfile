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

# Instalar healthcheck script y configurar PHP en un solo RUN
RUN curl -sSL https://raw.githubusercontent.com/renatomefi/php-fpm-healthcheck/master/healthcheck.sh | sed 's/\r$//' \
    > /usr/local/bin/php-fpm-healthcheck \
    && chmod +x /usr/local/bin/php-fpm-healthcheck \
    && { \
        echo "post_max_size=1024M"; \
        echo "upload_max_filesize=1024M"; \
        echo "memory_limit=1024M"; \
        echo "max_input_time=900"; \
        echo "max_execution_time=900"; \
        echo "session.save_path=/tmp"; \
        echo "expose_php=Off"; \
        echo "display_errors=Off"; \
        echo "display_startup_errors=Off"; \
        echo "log_errors=On"; \
        echo "error_log=/dev/stderr"; \
        echo "session.cookie_httponly=1"; \
        echo "session.cookie_secure=0"; \
        echo "session.use_strict_mode=1"; \
        echo "session.sid_length=48"; \
    } >> /usr/local/etc/php/conf.d/custom.ini
