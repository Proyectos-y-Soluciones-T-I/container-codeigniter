# Imagen Docker Hub

La imagen precompilada `versionamientopys/container-codeigniter` disponible en Docker Hub.

---

## Docker Hub

[https://hub.docker.com/r/versionamientopys/container-codeigniter](https://hub.docker.com/r/versionamientopys/container-codeigniter)

---

## Tags disponibles

| Tag | Descripción |
|-----|-------------|
| `latest` | Última build estable desde `main` |
| `v1.1.0` | Opcache, gzip, healthcheck real, config PHP externalizada |
| `v1.0.2` | Fix output_buffering |
| `v1.0.1` | Scripts de setup interactivos |
| `v1.0.0` | Versión inicial |

Usar un tag específico para entornos que requieren estabilidad:

```yaml
php:
    image: versionamientopys/container-codeigniter:v1.1.0
```

---

## Plataformas soportadas

| Arquitectura | Plataformas |
|-------------|-------------|
| `linux/amd64` | Intel / AMD (x86-64) |
| `linux/arm64` | Apple Silicon (M1/M2/M3), AWS Graviton |
| `linux/arm/v7` | Raspberry Pi 3/4 |

La imagen es **multi-arch** — Docker selecciona automáticamente la correcta para tu máquina.

---

## Qué incluye la imagen

- **PHP 7.4.33** (Alpine Linux)
- **Composer** (última versión estable de Composer 2)
- **Extensiones:** `pdo`, `pdo_mysql`, `mysqli`, `gd`, `zip`, `xml`, `mbstring`, `bcmath`, `opcache`
- **`cgi-fcgi`** — para healthcheck real de php-fpm
- **`mysql-client`** — para conectarse a MariaDB desde el contenedor PHP
- **Configuración PHP:** timezone America/Bogota, opcache activado, límites de 1GB, sesiones configuradas

---

## Uso mínimo

```yaml
# docker-compose.yml
services:
  nginx:
    image: nginx:stable-alpine
    ports:
      - 8888:80
    volumes:
      - ./src:/var/www/html:cached
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      php:
        condition: service_healthy

  php:
    image: versionamientopys/container-codeigniter:latest
    container_name: php-ci
    restart: always
    env_file:
      - .env
    volumes:
      - ./src:/var/www/html:cached
    depends_on:
      db:
        condition: service_healthy

  db:
    image: mariadb:10.5
    env_file:
      - .env
    ports:
      - 3307:3306
    volumes:
      - dbdata:/var/lib/mysql

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    ports:
      - '8081:80'
    env_file:
      - .env
    environment:
      PMA_HOST: db
      PMA_PORT: 3306

networks:
  ci-network:
    driver: bridge

volumes:
  dbdata:
```

Para el archivo completo con healthchecks, logging, headers de seguridad y gzip, ver [Inicio Rápido](Inicio-Rapido) o el `docker-compose.yml` del repositorio.

---

## Descargar la imagen

```bash
docker pull versionamientopys/container-codeigniter:latest
```

---

## Actualizar a una nueva versión

```bash
docker compose pull php
docker compose up -d
```

---

## Construir la imagen vos mismo

Si preferís construir localmente:

```bash
git clone https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter.git
cd container-codeigniter
docker compose build php
```

O construir y pushear a tu propio registro:

```bash
docker build -t tu-registro/container-codeigniter:v1.1.0 .
docker push tu-registro/container-codeigniter:v1.1.0
```

---

## Variables de entorno disponibles

La imagen expone estas variables para usar en tu código PHP:

| Variable | Valor | Fuente |
|----------|-------|--------|
| `DB_HOST` | `db` | Definido en `environment:` del compose |
| `DB_PORT` | `3306` | Definido en `environment:` del compose |
| `MYSQL_ROOT_PASSWORD` | (tu valor) | Del archivo `.env` |
| `MYSQL_DATABASE` | (tu valor) | Del archivo `.env` |
| `MYSQL_USER` | (tu valor) | Del archivo `.env` |
| `MYSQL_PASSWORD` | (tu valor) | Del archivo `.env` |

Acceso desde PHP:

```php
$dbHost = getenv('DB_HOST');     // 'db'
$dbPort = getenv('DB_PORT');     // '3306'
// o
$dbHost = $_ENV['DB_HOST'];
```
