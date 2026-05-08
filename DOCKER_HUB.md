# container-codeigniter — Entorno de desarrollo PHP 7.4 tipo XAMPP

> Este archivo se sincroniza automáticamente con la página de Docker Hub. Cualquier cambio acá aparece en la descripción de la imagen.

Reemplazo de XAMPP basado en Docker. Soporta múltiples proyectos PHP/CodeIgniter 3 simultáneos dentro de `src/`, cada uno con su propio repo Git, sin conflictos de puertos ni de dependencias.

## ¿Qué incluye?

| Servicio    | Versión          | Puerto |
|-------------|------------------|--------|
| PHP-FPM     | 7.4.33 (Alpine)  | —      |
| Nginx       | stable-alpine    | 8888   |
| MariaDB     | 10.5             | 3307   |
| phpMyAdmin  | latest           | 8081   |

> Composer 2.8 viene incluido en la imagen PHP.

### Extensiones PHP incluidas

`pdo` · `pdo_mysql` · `mysqli` · `gd` · `zip` · `xml` · `mbstring` · `bcmath` · `opcache`

---

## Inicio rápido

### 1. Bajá la imagen

```bash
docker pull versionamientopys/container-codeigniter:latest
```

### 2. Creá tu `docker-compose.yml`

Copiá este archivo en una carpeta vacía de tu máquina:

```yaml
# Sincronizado con docker-compose.yml raíz. Si cambiás uno, actualizá el otro.
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
    volumes:
      - ./src:/var/www/html:cached
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
    networks:
      - ci-network

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
      - ./mysql:/var/lib/mysql
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
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    networks:
      - ci-network

networks:
  ci-network:
    driver: bridge
```

> El `nginx/default.conf` del repositorio incluye headers de seguridad adicionales (X-Frame-Options, X-Content-Type-Options, etc.) que no se muestran en este ejemplo mínimo.

### 3. Creá tu `.env`

> Los valores de abajo son **ejemplos** — cambiálos por tus propias credenciales. Este archivo no se sube al repo (está en `.gitignore`).

```env
MYSQL_ROOT_PASSWORD=cambia-esto
MYSQL_DATABASE=mi_base
MYSQL_USER=mi_usuario
MYSQL_PASSWORD=mi_password
PMA_ARBITRARY=1
```

### 4. Creá la config de Nginx

Creá el archivo `nginx/default.conf`:

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

### 5. Levantá el stack

```bash
docker compose up -d
```

| URL | Qué es |
|-----|--------|
| http://localhost:8888 | Listado de proyectos (estilo htdocs) |
| http://localhost:8888/miapp | Tu proyecto |
| http://localhost:8081 | phpMyAdmin |

---

## Estructura de carpetas

```
mi-proyecto/
├── docker-compose.yml
├── .env
├── nginx/
│   └── default.conf
├── src/
│   ├── miapp/
│   │   └── index.php
│   └── otro-proyecto/
│       └── index.php
└── mysql/          ← generado automáticamente por MariaDB
```

---

## Ruteo de URLs

Funciona como el `htdocs` de XAMPP. El primer segmento de la URL mapea a la carpeta del proyecto:

```
http://localhost:8888/miapp/usuarios/lista
→ src/miapp/index.php?...
```

Sin `.htaccess` — Nginx maneja el rewrite automáticamente.

---

## Conexión a la base de datos

Desde PHP, usá estas credenciales (red interna de Docker):

```php
$host = 'db';      // nombre del servicio en la red Docker
$port = 3306;      // puerto interno
$user = 'dev';     // MYSQL_USER del .env
$pass = 'secret';  // MYSQL_PASSWORD del .env
$db   = 'mydb';    // MYSQL_DATABASE del .env
```

> **Nota:** MariaDB está expuesto en el puerto `3307` en tu máquina para no chocar con un MySQL/XAMPP local en `3306`.

---

## Usar Composer

Composer 2.8 está incluido en la imagen PHP — no hace falta un servicio separado. Usalo directamente con `docker compose run`:

```bash
docker compose run --rm php composer install --working-dir=/app/mi-proyecto
docker compose run --rm php composer require vendor/paquete --working-dir=/app/mi-proyecto
docker compose run --rm php composer update --working-dir=/app/mi-proyecto
```

---

## Configuración PHP por defecto

| Parámetro             | Valor  |
|-----------------------|--------|
| `post_max_size`       | 1024M  |
| `upload_max_filesize` | 1024M  |
| `memory_limit`        | 1024M  |
| `max_execution_time`  | 900s   |
| `max_input_time`      | 900s   |

---

## Plataformas soportadas

| Arquitectura   | Soporte |
|----------------|---------|
| `linux/amd64`  | ✅ Intel/AMD (x86-64) |
| `linux/arm64`  | ✅ Apple Silicon, AWS Graviton |
| `linux/arm/v7` | ✅ Raspberry Pi 3/4 |

---

## Tags disponibles

| Tag      | Descripción                      |
|----------|----------------------------------|
| `latest` | Última build estable desde main  |
| `1.0.0`  | Versión fija                     |
| `1.0`    | Track de versión menor           |

---

## Código fuente

GitHub: [Proyectos-y-Soluciones-T-I/container-codeigniter](https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter)

---

¿Preferís compilar la imagen vos mismo? Mirá [README.md](README.md) para el setup completo con build local, múltiples proyectos, y troubleshooting.

---

## Licencia

MIT
