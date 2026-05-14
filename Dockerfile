# Multi-stage build for production optimization
# Stage 1: Builder — compiles PHP extensions and installs dependencies
FROM php:7.4.33-fpm-alpine AS builder

# Install runtime dependencies needed in final image
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
        fcgi

# Install build dependencies (only in builder, discarded in final image)
RUN apk add --no-cache --virtual .build-deps \
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
        autoconf

# Configure and compile PHP extensions
# NOTE: PHP 7.4 gd uses --with-freetype-dir / --with-jpeg-dir / --with-webp-dir
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_mysql \
        mysqli \
        gd \
        zip \
        xml \
        mbstring \
        bcmath \
        opcache

# Clean up build dependencies
RUN apk del .build-deps

# Stage 2: Production image — minimal runtime-only image
FROM php:7.4.33-fpm-alpine

# Add non-root user for security
RUN addgroup -g 1000 appuser && adduser -u 1000 -G appuser -s /sbin/nologin -D appuser

# Install runtime dependencies only
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
        fcgi

# Copy compiled PHP extensions from builder
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php /usr/local/etc/php

# Copy Composer from official image
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

# Create healthcheck script
RUN echo '#!/bin/sh' > /usr/local/bin/php-fpm-healthcheck \
    && echo 'SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000' >> /usr/local/bin/php-fpm-healthcheck \
    && chmod +x /usr/local/bin/php-fpm-healthcheck

# Copy PHP configuration files
COPY php/custom.ini /usr/local/etc/php/conf.d/custom.ini
COPY php/zz-healthcheck.conf /usr/local/etc/php-fpm.d/zz-healthcheck.conf

# Set working directory
WORKDIR /var/www/html

# Switch to non-root user
USER appuser

# Add health check directive for the image
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=10s \
    CMD php-fpm-healthcheck
