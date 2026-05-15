#!/bin/sh
set -e

# Fix upload directory ownership at container startup (runs as root).
# php-fpm master process starts as root and drops to appuser via its own
# user/group directives — so we do NOT use su-exec here.
for app_dir in /var/www/html/sai-superior /var/www/html/ijuridica; do
    if [ -d "$app_dir" ]; then
        mkdir -p "$app_dir/uploads"
        chown -R appuser:appuser "$app_dir/uploads"
        chmod -R 775 "$app_dir/uploads"
    fi
done

exec "$@"
