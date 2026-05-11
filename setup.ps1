# =============================================================================
# container-codeigniter — Setup script (Windows PowerShell)
# For users pulling from Docker Hub (no repo clone needed)
# https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter
# =============================================================================

$ErrorActionPreference = "Stop"

function Write-Header {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     container-codeigniter — Setup              ║" -ForegroundColor Cyan
    Write-Host "║     PHP 7.4 + Nginx + MariaDB 10.5             ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Prompt-Default {
    param(
        [string]$Question,
        [string]$Default
    )
    Write-Host -NoNewline "$Question " -ForegroundColor Cyan
    Write-Host -NoNewline "[$Default]" -ForegroundColor Yellow
    Write-Host -NoNewline ": "
    $input = Read-Host
    if ([string]::IsNullOrWhiteSpace($input)) {
        return $Default
    }
    return $input
}

function Write-Ok   { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Skip { param($msg) Write-Host "  [--] $msg" -ForegroundColor Yellow }

# -----------------------------------------------------------------------------
Write-Header

# -----------------------------------------------------------------------------
# Step 1: Collect environment variables
# -----------------------------------------------------------------------------
Write-Host "── Configuración de base de datos ──────────────────" -ForegroundColor White
Write-Host "Presioná Enter para aceptar el valor por defecto."
Write-Host ""

$MYSQL_ROOT_PASSWORD = Prompt-Default "Contraseña root de MariaDB" "root1234"
$MYSQL_DATABASE      = Prompt-Default "Nombre de la base de datos" "mi_base"
$MYSQL_USER          = Prompt-Default "Usuario de la base de datos" "devuser"
$MYSQL_PASSWORD      = Prompt-Default "Contraseña del usuario"      "dev1234"

Write-Host ""

# -----------------------------------------------------------------------------
# Step 2: Create directory structure
# -----------------------------------------------------------------------------
Write-Host "── Creando estructura de carpetas ──────────────────" -ForegroundColor White

New-Item -ItemType Directory -Force -Path "src"   | Out-Null
New-Item -ItemType Directory -Force -Path "nginx" | Out-Null
$null = New-Item -ItemType File -Force -Path "src\.gitkeep"

Write-Ok "src/"
Write-Ok "nginx/"

# -----------------------------------------------------------------------------
# Step 3: Generate .env
# -----------------------------------------------------------------------------
if (Test-Path ".env") {
    Write-Skip ".env ya existe — no se sobreescribe."
} else {
    @"
# MariaDB
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD

# phpMyAdmin
PMA_HOST=db
PMA_PORT=3306
PMA_ABSOLUTE_URI=http://localhost:8081/
"@ | Set-Content -Encoding UTF8 ".env"
    Write-Ok ".env"
}

# -----------------------------------------------------------------------------
# Step 4: Generate nginx/default.conf
# -----------------------------------------------------------------------------
if (Test-Path "nginx\default.conf") {
    Write-Skip "nginx/default.conf ya existe — no se sobreescribe."
} else {
    @'
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
'@ | Set-Content -Encoding UTF8 "nginx\default.conf"
    Write-Ok "nginx/default.conf"
}

# -----------------------------------------------------------------------------
# Step 5: Generate my.cnf
# -----------------------------------------------------------------------------
if (Test-Path "my.cnf") {
    Write-Skip "my.cnf ya existe — no se sobreescribe."
} else {
    @'
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
'@ | Set-Content -Encoding UTF8 "my.cnf"
    Write-Ok "my.cnf"
}

# -----------------------------------------------------------------------------
# Step 6: Generate docker-compose.yml
# -----------------------------------------------------------------------------
if (Test-Path "docker-compose.yml") {
    Write-Skip "docker-compose.yml ya existe — no se sobreescribe."
} else {
    @'
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
'@ | Set-Content -Encoding UTF8 "docker-compose.yml"
    Write-Ok "docker-compose.yml"
}

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "── Listo ────────────────────────────────────────────" -ForegroundColor White
Write-Host ""
Write-Host "Siguientes pasos:"
Write-Host ""
Write-Host "  1. Revisá " -NoNewline; Write-Host ".env" -ForegroundColor White -NoNewline; Write-Host " y ajustá las credenciales si es necesario"
Write-Host "  2. Cloná tus proyectos en " -NoNewline; Write-Host "src\" -ForegroundColor White -NoNewline; Write-Host ":"
Write-Host "     cd src; git clone https://github.com/tu-usuario/mi-proyecto.git" -ForegroundColor Cyan
Write-Host "  3. Levantá el stack:"
Write-Host "     docker compose up -d" -ForegroundColor Cyan
Write-Host ""
Write-Host "Accesos:"
Write-Host "  http://localhost:8888" -ForegroundColor Green -NoNewline; Write-Host "  — Dashboard de proyectos"
Write-Host "  http://localhost:8081" -ForegroundColor Green -NoNewline; Write-Host "  — phpMyAdmin"
Write-Host ""
