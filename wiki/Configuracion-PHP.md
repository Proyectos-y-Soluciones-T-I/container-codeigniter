# Configuración PHP

Guía completa de la configuración PHP del contenedor `php-ci`.

---

## Archivo de configuración: `php/custom.ini`

Toda la configuración PHP está en **`php/custom.ini`**, montado como volumen en el contenedor.

```ini
; 📍 php/custom.ini
; Este archivo se monta en /usr/local/etc/php/conf.d/custom.ini
; Cualquier cambio toma efecto al reiniciar el contenedor (sin rebuild)
```

**Aplicar cambios:**

```bash
docker compose restart php
```

---

## Configuración actual

### Límites

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `post_max_size` | 1024M | Tamaño máximo de datos POST |
| `upload_max_filesize` | 1024M | Tamaño máximo de archivo subido |
| `memory_limit` | 1024M | Memoria máxima por script |
| `max_execution_time` | 900 | Tiempo máximo de ejecución (segundos) |
| `max_input_time` | 900 | Tiempo máximo para parsear input |

### Zona horaria

```ini
date.timezone = America/Bogota
```

**Cambiar a tu zona:**

```ini
date.timezone = America/Argentina/Buenos_Aires
date.timezone = America/Mexico_City
date.timezone = America/Lima
date.timezone = Europe/Madrid
```

> Lista completa: [PHP Timezones](https://www.php.net/manual/es/timezones.php)

### Sesiones

| Parámetro | Valor | Significado |
|-----------|-------|-------------|
| `session.save_handler` | `files` | Archivos en disco |
| `session.save_path` | `/tmp` | Carpeta dentro del contenedor |
| `session.cookie_httponly` | `1` | Cookie no accesible por JS |
| `session.cookie_secure` | `0` | HTTP permitido (dev local) |
| `session.use_strict_mode` | `1` | Solo acepta IDs de sesión del servidor |
| `session.sid_length` | `48` | Longitud del ID de sesión |

> **Nota:** Las sesiones se pierden al reiniciar el contenedor (se guardan en `/tmp`). Si necesitás persistir sesiones, montá un volumen para `/tmp`.

### Errores

```ini
display_errors = Off          ; No mostrar en pantalla
display_startup_errors = Off  ; No mostrar errores de arranque
log_errors = On               ; Registrar en log
error_reporting = E_ALL & ~E_DEPRECATED & ~E_NOTICE
error_log = /dev/stderr       ; Capturado por Docker logs
```

**Para desarrollo, ver errores en pantalla:**

```ini
display_errors = On
```

### Seguridad

```ini
expose_php = Off   ; No expone versión de PHP en headers HTTP
```

---

## Opcache

Opcache acelera PHP guardando bytecode compilado en memoria.

```ini
[opcache]
opcache.enable = 1
opcache.enable_cli = 0
opcache.memory_consumption = 256        ; MB de memoria para opcache (aumentado)
opcache.interned_strings_buffer = 32    ; MB para strings internos (aumentado)
opcache.max_accelerated_files = 20000   ; Máximo de archivos en caché (aumentado)
opcache.validate_timestamps = 0         ; No validar timestamps (modo producción)
opcache.revalidate_freq = 0
opcache.fast_shutdown = 1
opcache.file_update_protection = 2
opcache.huge_code_pages = 1
opcache.optimization_level = 0x7FFEBFFF
```

### Modo producción (actual)

Opcache está configurado para **modo producción** con `validate_timestamps=0`. Esto da máximo rendimiento pero **requiere reiniciar el contenedor** después de cada cambio en archivos PHP:

```bash
docker compose restart php
```

Si necesitás **modo desarrollo** (detectar cambios sin reiniciar), cambiá en `php/custom.ini`:

```ini
; 🔧 DESARROLLO — detecta cambios sin reiniciar
opcache.validate_timestamps = 1
opcache.revalidate_freq = 2
```

**Verificar que opcache está funcionando:**

```bash
docker exec -it php-ci php -r "var_dump(opcache_get_status());"
```

---

## PHP-FPM Pool (`php/www-pool.conf`)

El archivo `php/www-pool.conf` se monta como `zzz-www-pool.conf` y sobrescribe la configuración por defecto del pool `www`.

```ini
[www]
pm = dynamic
pm.min_spare_servers = 10
pm.max_spare_servers = 20
pm.start_servers = 15
pm.max_children = 100        ; Hasta 100 workers concurrentes
pm.max_requests = 1000       ; Recicla cada 1000 requests (previene memory leaks)
pm.process_idle_timeout = 10s
request_terminate_timeout = 900s
slowlog = /dev/null
request_slowlog_timeout = 10s
pm.status_path = /status
catch_workers_output = yes
clear_env = no
```

**Ajustar según memoria disponible:**

| `pm.max_children` | Memoria PHP-FPM estimada |
|-------------------|--------------------------|
| 20 (default viejo) | ~1-2 GB |
| 100 (actual) | ~5-10 GB |
| 50 (recomendado para 4GB) | ~2-4 GB |

Si el servidor tiene poca RAM, reducir `pm.max_children` en `php/www-pool.conf` y reiniciar:

```bash
docker compose restart php
```

---

## Cambiar parámetros sin rebuild

1. Editá `php/custom.ini`
2. Reiniciá el contenedor:

```bash
docker compose restart php
```

**NO necesitás** `docker compose build` ni `docker compose up --build`. El archivo se monta como volumen y se relee al reiniciar.

---

## Configuración avanzada

### Aumentar `memory_limit`

```ini
memory_limit = 2048M   ; 2 GB
```

### Habilitar `xdebug` (debugging)

No incluido por defecto. Agregar al `Dockerfile`:

```dockerfile
RUN pecl install xdebug-3.1.6 \
    && docker-php-ext-enable xdebug
```

Y configurar en `php/custom.ini`:

```ini
[xdebug]
xdebug.mode = debug
xdebug.client_host = host.docker.internal
xdebug.client_port = 9003
xdebug.start_with_request = yes
```

Después reconstruir:

```bash
docker compose up -d --build
```

### Agregar extensiones PHP

Editar `Dockerfile` (línea `docker-php-ext-install`) y agregar la extensión deseada, por ejemplo `intl`, `soap`, `exif`:

```dockerfile
    && docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_mysql \
        ...
        intl \
        exif \
```

Reconstruir:

```bash
docker compose up -d --build
```

---

## Healthcheck de PHP-FPM

El healthcheck usa `cgi-fcgi` para hacer un ping real al pool de php-fpm.

**Archivo:** `php/zz-healthcheck.conf`

```ini
[www]
ping.path = /ping
ping.response = pong
```

**Script:** `/usr/local/bin/php-fpm-healthcheck` (generado en el Dockerfile)

```bash
SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000
```

Esto permite detectar pools colgados que el viejo `ps | grep php-fpm` no detectaba.
