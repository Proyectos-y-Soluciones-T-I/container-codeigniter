# Changelog

Todos los cambios notables de este proyecto están documentados en este archivo.

Formato basado en [Keep a Changelog](https://keepachangelog.com/es/1.1.0/).
Versionado siguiendo [Semantic Versioning](https://semver.org/lang/es/).

---

## [1.1.0] - 2026-05-12

### Added
- **`php/custom.ini`** — configuración PHP externalizada y montada como volumen. Editable sin rebuild de imagen.
- **`php/zz-healthcheck.conf`** — habilita el endpoint `/ping` en el pool de php-fpm para healthcheck real.
- **Opcache activado** — `opcache.validate_timestamps=1` (detecta cambios automáticamente, ideal para desarrollo).
- **Compresión gzip en Nginx** — activo para HTML, CSS, JS, JSON, SVG. Reduce transferencia ~60-80%.
- **Timezone `America/Bogota`** configurada en `php/custom.ini`.
- **`error_reporting`** explícito (`E_ALL & ~E_DEPRECATED & ~E_NOTICE`) en `php/custom.ini`.
- **`session.save_handler = files`** explícito para paridad con entornos de producción.
- **Paquete `fcgi`** agregado a la imagen — requerido por el healthcheck de php-fpm.
- **`WORKDIR /var/www/html`** en el Dockerfile.

### Changed
- **Healthcheck de PHP-FPM** — reemplaza `ps aux | grep php-fpm` por un ping real via `cgi-fcgi` al endpoint `/ping`. Detecta correctamente estados zombie o pools colgados.
- **`docker-compose.yml` — servicio `php`**:
  - Agrega `env_file: .env` — las variables de entorno del `.env` ahora están disponibles en el contenedor PHP (`$_ENV`, `getenv()`).
  - Agrega `environment: DB_HOST=db, DB_PORT=3306` — conexión a la base de datos disponible como variables de entorno.
  - Agrega `depends_on: db: condition: service_healthy` — PHP espera a que MariaDB esté listo antes de arrancar.
  - Agrega bind-mount de `php/custom.ini` y `php/zz-healthcheck.conf`.
- **Nginx — bloqueo de rutas sensibles** — agrega `vendor/`, `application/config/` y `application/logs/` a las rutas denegadas por HTTP.
- **Dockerfile** — la configuración PHP migra de heredoc inline a `COPY php/custom.ini`. Más mantenible y versionable.
- **Sección Composer en README** — corrige los comandos. Composer corre con `docker exec` directamente en el contenedor PHP, no con `docker-compose run --rm composer` (ese servicio no existe en este proyecto).

### Fixed
- **Healthcheck script corrupto** — el script descargado de GitHub devolvía HTML (404) en lugar del script real. Reemplazado por un script generado localmente en el Dockerfile.

---

## [1.0.2] - 2026-05-11

### Fixed
- `output_buffering` habilitado en PHP para igualar comportamiento del servidor de producción.

---

## [1.0.1] - 2026-05-11

### Added
- Scripts interactivos de setup para usuarios de Docker Hub (`setup.sh` para Linux/macOS, `setup.ps1` para Windows).
- Licencia MIT (`LICENSE`).

---

## [1.0.0] - 2026-05-11

### Added
- Stack inicial: Nginx stable-alpine + PHP 7.4.33-fpm-alpine + MariaDB 10.5 + phpMyAdmin.
- Volumen nombrado (`dbdata`) para datos de MariaDB — compatibilidad cross-platform Windows/Mac/Linux.
- Healthchecks en todos los servicios con `depends_on: condition: service_healthy`.
- Logging con rotación automática (10MB, 3 archivos) en todos los servicios.
- `my.cnf` con configuración optimizada para importaciones grandes (1GB max_allowed_packet, timeouts extendidos).
- Extensiones PHP: `pdo`, `pdo_mysql`, `mysqli`, `gd`, `zip`, `xml`, `mbstring`, `bcmath`, `opcache`.
- Composer 2 incluido en la imagen PHP.
- Dashboard visual de proyectos (`src/dashboard.php`) — reemplaza el autoindex de Nginx.
- Security headers en Nginx: `X-Frame-Options`, `X-Content-Type-Options`, `X-XSS-Protection`, `Referrer-Policy`.
- Caché de assets estáticos (30 días) en Nginx.
- Bloqueo de archivos sensibles en Nginx (`.env`, `.git`, `composer.json`, etc.).
- Rewrite automático para proyectos CodeIgniter 3 en subdirectorios (`@project_fallback`).

[1.1.0]: https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter/releases/tag/v1.0.0
