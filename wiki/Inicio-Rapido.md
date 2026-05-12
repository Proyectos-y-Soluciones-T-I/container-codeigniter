# Inicio Rápido

> Para poner el entorno corriendo en menos de 5 minutos con la imagen de Docker Hub.

---

## Paso 1: Crear carpeta del proyecto

```bash
mkdir mi-entorno-php
cd mi-entorno-php
```

---

## Paso 2: Crear archivos de configuración

### `docker-compose.yml`

```yaml
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
    networks:
      - ci-network

  php:
    image: versionamientopys/container-codeigniter:latest
    container_name: php-ci
    restart: always
    env_file:
      - .env
    environment:
      DB_HOST: db
      DB_PORT: 3306
    volumes:
      - ./src:/var/www/html:cached
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "/usr/local/bin/php-fpm-healthcheck"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 10s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    networks:
      - ci-network

  db:
    image: mariadb:10.5
    container_name: db-ci
    restart: always
    env_file:
      - .env
    ports:
      - 3307:3306
    volumes:
      - dbdata:/var/lib/mysql
      - ./my.cnf:/etc/mysql/conf.d/my.cnf:ro
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
    networks:
      - ci-network

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    container_name: phpmyadmin-ci
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
```

### `.env`

```env
MYSQL_ROOT_PASSWORD=cambia-esto
MYSQL_DATABASE=mi_base
MYSQL_USER=mi_usuario
MYSQL_PASSWORD=mi_password
```

> **Importante:** cambiá las contraseñas. Este archivo contiene credenciales reales, por eso no se sube al repositorio (está en `.gitignore`).

### `nginx/default.conf`

```nginx
server {
    listen 80;
    index index.php index.html;
    server_name localhost;
    root /var/www/html;
    client_max_body_size 1024M;

    location = / {
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
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
    }

    location ~ /\.ht {
        deny all;
    }
}
```

### `my.cnf` (opcional)

```ini
[mysqld]
max_allowed_packet=1G
net_buffer_length=32M
bind-address=0.0.0.0
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci

[client]
default-character-set=utf8mb4
max_allowed_packet=1G
```

---

## Paso 3: Crear `src/`

```bash
mkdir -p src
```

---

## Paso 4: Levantar el stack

```bash
docker compose up -d
```

La primera vez descarga las imágenes (~3-5 minutos). Después arranca en segundos.

---

## Paso 5: Verificar

| URL | Deberías ver |
|-----|-------------|
| `http://localhost:8888` | Listado de proyectos en `src/` |
| `http://localhost:8081` | Pantalla de login de phpMyAdmin |

---

## Paso 6: Agregar un proyecto

```bash
cd src
git clone https://github.com/tu-usuario/mi-proyecto.git
```

Visitá: `http://localhost:8888/mi-proyecto/`

---

## ¿Stack completo (con dashboard)?

Si querés el dashboard visual en vez de un simple autoindex, y toda la configuración de seguridad (gzip, headers, bloqueo de rutas sensibles, opcache), bajate los archivos completos del [repositorio](https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter).

---

## Siguientes pasos

| Quiero... | Ir a |
|-----------|------|
| Configurar CodeIgniter 3 | [Proyectos CodeIgniter 3](Proyectos-CodeIgniter-3) |
| Importar una base de datos | [Base de Datos](Base-de-Datos) |
| Entender los servicios | [Arquitectura](Arquitectura) |
| Resolver un error | [Solución de Problemas](Solucion-de-Problemas) |
