#!/bin/sh
set -e

for app_dir in /var/www/html/sai-superior /var/www/html/ijuridica; do
    if [ -d "$app_dir" ]; then
        # Install Composer dependencies if vendor/ is missing.
        # Build in /tmp to avoid Windows-volume permission issues with deep trees.
        if [ -f "$app_dir/composer.json" ] && [ ! -f "$app_dir/vendor/autoload.php" ]; then
            echo "[entrypoint] composer install for $app_dir ..."
            tmp_dir=$(mktemp -d)
            cp "$app_dir/composer.json" "$tmp_dir/"
            [ -f "$app_dir/composer.lock" ] && cp "$app_dir/composer.lock" "$tmp_dir/"
            composer install \
                --working-dir="$tmp_dir" \
                --no-dev \
                --prefer-dist \
                --no-interaction \
                --no-progress 2>&1
            mv "$tmp_dir/vendor" "$app_dir/vendor"
            [ -f "$tmp_dir/composer.lock" ] && cp "$tmp_dir/composer.lock" "$app_dir/composer.lock"
            rm -rf "$tmp_dir"
            echo "[entrypoint] composer install done."
        fi

        # Fix upload directory ownership (runs as root before php-fpm drops to appuser).
        mkdir -p "$app_dir/uploads"
        chown -R appuser:appuser "$app_dir/uploads"
        chmod -R 775 "$app_dir/uploads"
    fi
done

exec "$@"
