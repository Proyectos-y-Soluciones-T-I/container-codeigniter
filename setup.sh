#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# container-codeigniter — Setup script
# For users pulling from Docker Hub (no repo clone needed)
# https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter
# =============================================================================

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║     container-codeigniter — Setup              ║${RESET}"
echo -e "${BOLD}║     PHP 7.4 + Nginx + MariaDB 10.5             ║${RESET}"
echo -e "${BOLD}╚════════════════════════════════════════════════╝${RESET}"
echo ""

# -----------------------------------------------------------------------------
# Helper: prompt with default value
# Usage: prompt_default VAR_NAME "Question" "default_value"
# -----------------------------------------------------------------------------
prompt_default() {
  local var_name="$1"
  local question="$2"
  local default="$3"
  echo -ne "${CYAN}${question}${RESET} [${YELLOW}${default}${RESET}]: "
  read -r input
  if [[ -z "$input" ]]; then
    eval "$var_name=\"$default\""
  else
    eval "$var_name=\"$input\""
  fi
}

# -----------------------------------------------------------------------------
# Step 1: Collect environment variables
# -----------------------------------------------------------------------------
echo -e "${BOLD}── Configuración de base de datos ──────────────────${RESET}"
echo -e "Presioná Enter para aceptar el valor por defecto."
echo ""

prompt_default MYSQL_ROOT_PASSWORD "Contraseña root de MariaDB" "root1234"
prompt_default MYSQL_DATABASE      "Nombre de la base de datos" "mi_base"
prompt_default MYSQL_USER          "Usuario de la base de datos" "devuser"
prompt_default MYSQL_PASSWORD      "Contraseña del usuario"     "dev1234"

echo ""

# -----------------------------------------------------------------------------
# Step 2: Create directory structure
# -----------------------------------------------------------------------------
echo -e "${BOLD}── Creando estructura de carpetas ──────────────────${RESET}"

mkdir -p src nginx
touch src/.gitkeep

echo -e "  ${GREEN}✔${RESET} src/"
echo -e "  ${GREEN}✔${RESET} nginx/"

# -----------------------------------------------------------------------------
# Step 3: Generate .env
# -----------------------------------------------------------------------------
if [[ -f ".env" ]]; then
  echo ""
  echo -e "${YELLOW}⚠  Ya existe un archivo .env — no se sobreescribe.${RESET}"
else
  cat > .env <<EOF
# MariaDB
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=${MYSQL_DATABASE}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}

# phpMyAdmin
PMA_HOST=db
PMA_PORT=3306
PMA_ABSOLUTE_URI=http://localhost:8081/
EOF
  echo -e "  ${GREEN}✔${RESET} .env"
fi

# -----------------------------------------------------------------------------
# Step 4: Generate nginx/default.conf
# -----------------------------------------------------------------------------
if [[ -f "nginx/default.conf" ]]; then
  echo -e "  ${YELLOW}⚠${RESET}  nginx/default.conf ya existe — no se sobreescribe."
else
  cat > nginx/default.conf <<'NGINXCONF'
server {
    listen 80;
    server_name localhost;

    root /var/www/html;
    index index.php index.html index.htm;

    error_log  /var/log/nginx/error.log warn;
    access_log /var/log/nginx/access.log;

    client_max_body_size 1024M;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Caché de assets estáticos (1 mes)
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot|pdf)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Raíz: dashboard visual de proyectos
    location = / {
        rewrite ^ /dashboard.php last;
    }

    location / {
        try_files $uri $uri/ @project_fallback;
    }

    location @project_fallback {
        rewrite ^(/[^/?]+) $1/index.php?$args last;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_read_timeout 900;
        fastcgi_send_timeout 900;
    }

    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    location ~* /(composer\.(json|lock|phar)|package\.json|\.git|\.env) {
        deny all;
        return 404;
    }
}
NGINXCONF
  echo -e "  ${GREEN}✔${RESET} nginx/default.conf"
fi

# -----------------------------------------------------------------------------
# Step 5: Generate my.cnf
# -----------------------------------------------------------------------------
if [[ -f "my.cnf" ]]; then
  echo -e "  ${YELLOW}⚠${RESET}  my.cnf ya existe — no se sobreescribe."
else
  cat > my.cnf <<'MYCNF'
[mysqld]
max_allowed_packet=1G
net_buffer_length=32M
bind-address=0.0.0.0
sql_mode=STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci
skip-host-cache
skip-name-resolve
wait_timeout=28800
interactive_timeout=28800
net_read_timeout=3600
net_write_timeout=3600
innodb_buffer_pool_size=512M
innodb_log_file_size=256M
innodb_log_buffer_size=64M
innodb_flush_log_at_trx_commit=2

[client]
default-character-set=utf8mb4
max_allowed_packet=1G

[mysql]
default-character-set=utf8mb4
max_allowed_packet=1G

[mysqldump]
max_allowed_packet=1G
net_buffer_length=32M
MYCNF
  echo -e "  ${GREEN}✔${RESET} my.cnf"
fi

# -----------------------------------------------------------------------------
# Step 6: Generate docker-compose.yml
# -----------------------------------------------------------------------------
if [[ -f "docker-compose.yml" ]]; then
  echo -e "  ${YELLOW}⚠${RESET}  docker-compose.yml ya existe — no se sobreescribe."
else
  cat > docker-compose.yml <<'DOCKERCOMPOSE'
version: '3.8'
services:
  nginx:
    image: nginx:stable-alpine
    container_name: nginx-ci
    restart: always
    ports:
      - 8888:80
    volumes:
      - ./src:/var/www/html:cached
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      php:
        condition: service_healthy
      db:
        condition: service_healthy
    networks:
      - ci-network
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:80"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 5s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  php:
    image: versionamientopys/container-codeigniter:latest
    container_name: php-ci
    restart: always
    volumes:
      - ./src:/var/www/html:cached
    networks:
      - ci-network
    healthcheck:
      test: ["CMD-SHELL", "ps aux | grep '[p]hp-fpm' || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 10s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  db:
    image: mariadb:10.5
    container_name: db-ci
    restart: always
    command:
      - --max-allowed-packet=1073741824
      - --wait-timeout=28800
      - --interactive-timeout=28800
      - --net-read-timeout=3600
      - --net-write-timeout=3600
      - --innodb-buffer-pool-size=536870912
      - --innodb-log-file-size=268435456
      - --innodb-log-buffer-size=67108864
      - --innodb-flush-log-at-trx-commit=2
    env_file:
      - .env
    ports:
      - 3307:3306
    volumes:
      - dbdata:/var/lib/mysql
      - ./my.cnf:/etc/mysql/conf.d/my.cnf:ro
    networks:
      - ci-network
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin --no-defaults ping -h 127.0.0.1 -u root -p\"${MYSQL_ROOT_PASSWORD}\" || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  phpmyadmin:
    container_name: phpmyadmin-ci
    image: phpmyadmin/phpmyadmin
    ports:
      - '8081:80'
    restart: always
    env_file:
      - .env
    environment:
      PMA_HOST: db
      PMA_PORT: 3306
      PMA_ABSOLUTE_URI: http://localhost:8081/
    depends_on:
      db:
        condition: service_healthy
    networks:
      - ci-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  ci-network:
    driver: bridge

volumes:
  dbdata:
DOCKERCOMPOSE
  echo -e "  ${GREEN}✔${RESET} docker-compose.yml"
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}── Listo ────────────────────────────────────────────${RESET}"
echo ""
echo -e "Siguientes pasos:"
echo ""
echo -e "  1. Revisá ${BOLD}.env${RESET} y ajustá las credenciales si es necesario"
echo -e "  2. Cloná tus proyectos en ${BOLD}src/${RESET}:"
echo -e "     ${CYAN}cd src && git clone https://github.com/tu-usuario/mi-proyecto.git${RESET}"
echo -e "  3. Levantá el stack:"
echo -e "     ${CYAN}docker compose up -d${RESET}"
echo ""
echo -e "Accesos:"
echo -e "  ${GREEN}http://localhost:8888${RESET}  — Dashboard de proyectos"
echo -e "  ${GREEN}http://localhost:8081${RESET}  — phpMyAdmin"
echo ""
