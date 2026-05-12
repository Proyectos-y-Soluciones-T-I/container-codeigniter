# Changelog

Todos los cambios notables del proyecto. Formato basado en [Keep a Changelog](https://keepachangelog.com/es/1.1.0/).

---

## [v1.1.0] - 2026-05-12

### Added
- **Opcache** activado con `validate_timestamps=1` — PHP detecta cambios sin reiniciar
- **Compresión Gzip** en Nginx — reduce transferencia ~60-80% (HTML/CSS/JS/JSON/SVG)
- **Configuración PHP externalizada** (`php/custom.ini`) — editable sin rebuild
- **`php/zz-healthcheck.conf`** — habilita endpoint `/ping` para healthcheck real
- Zona horaria `America/Bogota` configurada
- `error_reporting` explícito (`E_ALL & ~E_DEPRECATED & ~E_NOTICE`)
- `session.save_handler = files` explícito
- Paquete `fcgi` en la imagen (requerido por `cgi-fcgi`)
- `WORKDIR /var/www/html` en el Dockerfile
- `CHANGELOG.md`

### Changed
- **Healthcheck de PHP-FPM:** reemplaza `ps | grep` por ping real con `cgi-fcgi`
- **Servicio `php`** ahora recibe `.env` como `env_file` y expone `DB_HOST`/`DB_PORT`
- **Servicio `php`** ahora depende de `db: healthy` antes de arrancar
- Nginx bloquea `vendor/`, `application/config/` y `application/logs/`
- Configuración PHP migrada de heredoc en Dockerfile a `COPY php/custom.ini`
- Documentación de Composer corregida (usa `docker exec` en vez de `compose run`)

### Fixed
- Healthcheck script corrupto (descargaba HTML 404 en vez del script)

---

## [v1.0.2] - 2026-05-11

### Fixed
- `output_buffering = On` para igualar comportamiento de producción

---

## [v1.0.1] - 2026-05-11

### Added
- Scripts interactivos de setup (`setup.sh`, `setup.ps1`)
- Licencia MIT (`LICENSE`)

---

## [v1.0.0] - 2026-05-11

### Added
- Stack inicial: Nginx + PHP 7.4 + MariaDB 10.5 + phpMyAdmin
- Volumen nombrado `dbdata` para persistencia cross-platform
- Healthchecks en todos los servicios con `condition: service_healthy`
- Logging con rotación (10MB, 3 archivos)
- `my.cnf` optimizado para imports grandes (1GB max_allowed_packet)
- Extensiones: `pdo`, `pdo_mysql`, `mysqli`, `gd`, `zip`, `xml`, `mbstring`, `bcmath`, `opcache`
- Composer 2 incluido en imagen PHP
- Dashboard visual de proyectos (`dashboard.php`)
- Security headers: X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, Referrer-Policy
- Caché de assets estáticos (30 días)
- Bloqueo de archivos sensibles (.env, .git, composer.*, etc.)
- Rewrite automático para proyectos CodeIgniter 3 en subdirectorios (`@project_fallback`)

[v1.1.0]: https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter/compare/v1.0.2...v1.1.0
[v1.0.2]: https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter/compare/v1.0.1...v1.0.2
[v1.0.1]: https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter/compare/v1.0.0...v1.0.1
[v1.0.0]: https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter/releases/tag/v1.0.0
