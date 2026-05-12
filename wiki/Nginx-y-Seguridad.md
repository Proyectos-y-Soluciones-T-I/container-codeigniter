# Nginx y Seguridad

Configuración de Nginx, ruteo de URLs, compresión gzip, headers de seguridad y bloqueo de archivos sensibles.

---

## Archivo de configuración: `nginx/default.conf`

Montado en `/etc/nginx/conf.d/default.conf` como read-only. Cambios toman efecto al recargar Nginx:

```bash
docker compose restart nginx
```

---

## Ruteo de URLs (project_fallback)

El sistema de ruteo mapea el primer segmento de la URL a un proyecto en `src/`.

```
http://localhost:8888/mi-proyecto/usuarios/lista
                           │            └─► CI3: controlador + método
                           └─► src/mi-proyecto/index.php
```

### Cómo funciona

```nginx
# Intenta servir el archivo/directorio directamente
location / {
    try_files $uri $uri/ @project_fallback;
}

# Si no existe, asume que es un proyecto CI3
location @project_fallback {
    rewrite ^(/[^/?]+) $1/index.php?$args last;
}
```

**Ejemplos:**

| URL | Resultado |
|-----|-----------|
| `/` | `src/dashboard.php` (dashboard visual) |
| `/mi-proyecto/` | `src/mi-proyecto/index.php` |
| `/mi-proyecto/usuarios/lista` | `src/mi-proyecto/index.php` con argumentos de CI3 |
| `/mi-proyecto/css/style.css` | Sirve el archivo directamente (existe en disco) |

---

## Compresión Gzip

Nginx comprime automáticamente respuestas de texto. Reduce el tamaño de transferencia entre **60-80%**.

```nginx
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_types
    text/plain
    text/css
    text/xml
    text/javascript
    application/json
    application/javascript
    application/xml+rss
    application/rss+xml
    application/atom+xml
    image/svg+xml
    font/woff2;
```

### Verificar que gzip funciona

```bash
curl -H "Accept-Encoding: gzip" -I http://localhost:8888/dashboard.php | grep Content-Encoding
```

Debe mostrar: `Content-Encoding: gzip`

---

## Caché de assets estáticos

Archivos CSS, JS, imágenes y fuentes se cachean **30 días**:

```nginx
location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot|pdf)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
    access_log off;
}
```

**Forzar recarga después de cambios:**

```html
<link rel="stylesheet" href="/mi-proyecto/css/style.css?v=2">
```

---

## Headers de seguridad

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

| Header | Protege contra |
|--------|---------------|
| `X-Frame-Options: SAMEORIGIN` | Clickjacking |
| `X-Content-Type-Options: nosniff` | MIME sniffing |
| `X-XSS-Protection: 1; mode=block` | XSS reflejado |
| `Referrer-Policy` | Fuga de información en Referer |

---

## Bloqueo de archivos y rutas sensibles

### Archivos ocultos

```nginx
location ~ /\. {
    deny all;
    access_log off;
    log_not_found off;
}
```

Bloquea cualquier ruta que empiece con `.` (`.env`, `.git`, `.htaccess`, etc.).

### Archivos específicos

```nginx
location ~* /(composer\.(json|lock|phar)|package\.json|\.git|\.env|vendor/|application/config/|application/logs/) {
    deny all;
    return 404;
}
```

Bloquea acceso HTTP a:

| Ruta bloqueada | Motivo |
|---------------|--------|
| `composer.json`, `composer.lock` | Información de dependencias |
| `package.json` | Información de paquetes npm |
| `.git/` | Historial del repositorio |
| `.env` | Credenciales de base de datos |
| `vendor/` | Código de dependencias |
| `application/config/` | Configuración de CI3 |
| `application/logs/` | Logs de CI3 |

---

## FastCGI optimización

```nginx
fastcgi_buffer_size 128k;
fastcgi_buffers 4 256k;
fastcgi_busy_buffers_size 256k;
fastcgi_read_timeout 900;
fastcgi_send_timeout 900;
```

Estos buffers previenen errores con respuestas grandes (reportes, exports) y los timeouts extendidos soportan scripts de larga duración.

---

## Subida de archivos grandes

```nginx
client_max_body_size 1024M;
```

Permite subir archivos de hasta **1 GB**.

---

## Configuración completa

```nginx
server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    index index.php index.html index.htm;

    error_log  /var/log/nginx/error.log warn;
    access_log /var/log/nginx/access.log;
    client_max_body_size 1024M;

    # Compresión gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript application/xml+rss
               application/rss+xml application/atom+xml image/svg+xml font/woff2;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Caché de assets (30 días)
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot|pdf)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Dashboard
    location = / {
        rewrite ^ /dashboard.php last;
    }

    # Ruteo de proyectos
    location / {
        try_files $uri $uri/ @project_fallback;
    }

    location @project_fallback {
        rewrite ^(/[^/?]+) $1/index.php?$args last;
    }

    # PHP
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

    # Bloquear archivos ocultos
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Bloquear archivos sensibles
    location ~* /(composer\.(json|lock|phar)|package\.json|\.git|\.env|vendor/|application/config/|application/logs/) {
        deny all;
        return 404;
    }
}
```
