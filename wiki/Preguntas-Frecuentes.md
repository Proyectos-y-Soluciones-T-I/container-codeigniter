# Preguntas Frecuentes

---

## ¿Esto reemplaza XAMPP completamente?

**Sí.** Nginx reemplaza Apache, PHP-FPM reemplaza el módulo PHP de Apache, MariaDB reemplaza MySQL, y phpMyAdmin está incluido.

Podés tener XAMPP y este stack corriendo al mismo tiempo — MariaDB usa el puerto `3307` para no chocar con el `3306` de XAMPP.

---

## ¿Puedo correr múltiples proyectos a la vez?

**Sí.** Cada carpeta dentro de `src/` es un proyecto independiente:

```
src/
├── proyecto-a/   → http://localhost:8888/proyecto-a/
├── proyecto-b/   → http://localhost:8888/proyecto-b/
└── proyecto-c/   → http://localhost:8888/proyecto-c/
```

Cada uno puede tener su propio repo Git, sus propias dependencias de Composer, y su propia base de datos.

---

## ¿Necesito .htaccess?

**No.** Nginx maneja el rewrite automáticamente con la regla `@project_fallback`. Cualquier `.htaccess` en tu proyecto es ignorado (y bloqueado por Nginx).

---

## ¿Por qué el hostname de la BD es `db` y no `localhost`?

Porque dentro de la red de Docker (`ci-network`), cada servicio se resuelve por su **nombre de servicio**. `db` es el nombre del servicio MariaDB en `docker-compose.yml`. `localhost` dentro del contenedor PHP es el propio contenedor PHP.

---

## ¿Puedo cambiar la configuración de PHP sin reconstruir?

**Sí.** Editá `php/custom.ini` y reiniciá:

```bash
docker compose restart php
```

No necesitás `docker compose build`.

---

## ¿Cómo activo los errores en pantalla?

En `php/custom.ini`:

```ini
display_errors = On
```

Reiniciar:

```bash
docker compose restart php
```

---

## ¿Qué hago si un paquete de Composer pide PHP 8+?

El contenedor usa PHP 7.4. Si tu proyecto necesita PHP 8.2+:

1. **Temporal:** `composer update --ignore-platform-req=php --no-audit` (puede romper)
2. **Permanente:** cambiar `FROM php:7.4.33-fpm-alpine` a `FROM php:8.2-fpm-alpine` en el `Dockerfile`

---

## ¿Puedo cambiar la versión de MariaDB?

**Sí.** Cambiá la línea en `docker-compose.yml`:

```yaml
db:
    image: mariadb:10.11   # o mariadb:11.4
```

> **Ojo:** Downgrades de versión mayor pueden requerir migración de datos. Hacé backup antes.

---

## ¿Los datos de la base de datos se pierden al apagar?

**No.** Los datos están en el volumen `dbdata`, que persiste entre reinicios. Solo se pierden si ejecutás:

```bash
docker compose down -v   # ⚠️ Esto ELIMINA el volumen
```

---

## ¿Cómo conecto mi cliente SQL (DBeaver, TablePlus) a MariaDB?

```
Host:     127.0.0.1
Puerto:   3307
Usuario:  root (o el que definiste en .env)
Password: la del .env
```

---

## ¿Puedo usar PostgreSQL en vez de MariaDB?

No es el diseño de este stack, pero podés modificar `docker-compose.yml` para agregar PostgreSQL como servicio adicional (o reemplazar MariaDB).

---

## ¿Cómo hago backup de la base de datos?

```bash
docker exec db-ci mysqldump -u root -pTU_PASSWORD --max-allowed-packet=1G NOMBRE_DB > backup.sql
```

---

## ¿El stack funciona en producción?

**No está diseñado para producción.** Es un entorno de **desarrollo local**. Para producción necesitarías:

- SSL/TLS (HTTPS)
- `display_errors = Off` (ya está)
- `opcache.validate_timestamps = 0`
- Secretos gestionados con Docker Secrets o Vault
- Sin phpMyAdmin expuesto
- Sin puertos de base de datos expuestos al host

---

## ¿Puedo agregar más extensiones PHP?

**Sí.** Con el control total (clonando el repo):

1. Editá el `Dockerfile`
2. Agregá la extensión en la línea `docker-php-ext-install`
3. Reconstruí: `docker compose up -d --build`

---

## ¿Qué hago si Docker me dice que el puerto está en uso?

Cambiá los puertos en `docker-compose.yml`:

```yaml
nginx:
    ports:
      - 8889:80     # en vez de 8888

db:
    ports:
      - 3308:3306   # en vez de 3307

phpmyadmin:
    ports:
      - 8082:80     # en vez de 8081
```

---

## ¿Cómo actualizo a la última versión del stack?

### Con imagen de Docker Hub:

```bash
docker compose pull php
docker compose up -d
```

### Con clon del repositorio:

```bash
git pull
docker compose up -d --build
```

---

## ¿Puedo usar este stack con Laravel, Symfony, o WordPress?

**Sí**, con ajustes:

- **Laravel:** requiere PHP 8.1+. Actualizar el `Dockerfile` y agregar `nginx/default.conf` con el rewrite de Laravel.
- **Symfony:** similar a Laravel.
- **WordPress:** funciona con PHP 7.4. Crear una carpeta en `src/` y listo.
- **PHP vanilla:** solo creá un `index.php` en una carpeta de `src/`.
