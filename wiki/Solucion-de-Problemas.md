# Solución de Problemas

Errores comunes, causas y soluciones.

---

## Índice

- [El contenedor PHP no arranca (unhealthy)](#php-unhealthy)
- [Error 502 Bad Gateway](#502-bad-gateway)
- [No encuentra el proyecto (404)](#404-no-encuentra-proyecto)
- [Error de conexión a base de datos](#error-conexion-db)
- [ERROR 1153: max_allowed_packet](#error-1153)
- [ERROR 2006: MySQL server has gone away](#error-2006)
- [ERROR 1273: Unknown collation utf8mb4_0900](#error-1273)
- [Access denied for user](#access-denied)
- [Composer: paquetes requieren PHP 8+](#composer-php-8)
- [Composer: advisories de seguridad](#composer-advisories)
- [phpMyAdmin no conecta](#phpmyadmin-no-conecta)
- [Cambios en archivos no se reflejan](#cambios-no-reflejan)
- [Puerto ya en uso](#puerto-en-uso)
- [El contenedor se llena de logs](#logs-llenan-disco)
- [Advertencia: "version is obsolete"](#version-obsolete)

---

## <a id="php-unhealthy"></a>El contenedor PHP no arranca (unhealthy)

```
dependency failed to start: container php-ci is unhealthy
```

**Causas posibles:**

1. **La imagen no se reconstruyó** después de cambios en el `Dockerfile`
   ```bash
   docker compose build --no-cache php
   docker compose up -d
   ```

2. **El healthcheck script está corrupto**
   ```bash
   # Verificar el contenido del script
   docker run --rm versionamientopys/container-codeigniter:latest cat /usr/local/bin/php-fpm-healthcheck
   ```
   Debe mostrar un script bash, no HTML.

3. **Falta `cgi-fcgi` en la imagen**
   ```bash
   docker run --rm versionamientopys/container-codeigniter:latest which cgi-fcgi
   ```
   Debe mostrar `/usr/bin/cgi-fcgi`.

---

## <a id="502-bad-gateway"></a>Error 502 Bad Gateway

Nginx no puede comunicarse con PHP-FPM.

**Causa:** El contenedor PHP no está listo cuando Nginx intenta forwardear requests.

**Solución:** Esperar a que el healthcheck de PHP esté healthy:

```bash
docker compose ps   # Verificar que php-ci aparece como "healthy"
```

Si Nginx arrancó antes que PHP:

```bash
docker compose restart nginx
```

---

## <a id="404-no-encuentra-proyecto"></a>No encuentra el proyecto (404)

**Causa:** El proyecto no está en `src/`, o la URL no coincide.

**Verificar:**

```bash
ls src/   # ¿Está la carpeta del proyecto?
```

URL correcta: `http://localhost:8888/mi-proyecto/` (la carpeta debe llamarse exactamente igual que el primer segmento de la URL).

---

## <a id="error-conexion-db"></a>Error de conexión a base de datos

```
SQLSTATE[HY000] [2002] Connection refused
```

**Causa:** `hostname` incorrecto en `database.php`.

**Solución:**
```php
'hostname' => 'db',   // NO 'localhost'
```

---

## <a id="error-1153"></a>ERROR 1153: Got a packet bigger than 'max_allowed_packet'

El dump contiene datos más grandes que el límite configurado.

```bash
# Reiniciar DB para aplicar my.cnf
docker compose restart db

# Verificar el valor
docker exec -it db-ci mysql -u root -p -e "SHOW VARIABLES LIKE 'max_allowed_packet';"
```

Debe mostrar `1073741824` (1 GB). Si es menor, verificar `my.cnf`.

---

## <a id="error-2006"></a>ERROR 2006: MySQL server has gone away

La conexión se cerró por timeout durante una importación larga.

**Solución:** El `my.cnf` ya tiene timeouts de 8 horas. Reiniciar DB:

```bash
docker compose restart db
```

Y reimportar forzando el límite:

```bash
docker exec -i db-ci sh -c 'mysql -u root -pTU_PASS --max_allowed_packet=1G NOMBRE_DB' < dump.sql
```

---

## <a id="error-1273"></a>ERROR 1273: Unknown collation utf8mb4_0900_ai_ci

El dump viene de MySQL 8 y usa collations que no existen en MariaDB 10.5.

```bash
sed -e 's/utf8mb4_0900_ai_ci/utf8mb4_unicode_ci/g' \
    -e 's/utf8mb4_0900_as_ci/utf8mb4_unicode_ci/g' \
    dump.sql | docker exec -i db-ci mysql -u root -pTU_PASS NOMBRE_DB
```

---

## <a id="access-denied"></a>Access denied for user

**Verificar credenciales:**

```bash
docker exec -it db-ci mysql -u root -pTU_PASS
```

**Verificar usuarios existentes:**

```sql
SELECT user, host FROM mysql.user;
```

---

## <a id="composer-php-8"></a>Composer: paquetes requieren PHP 8+

```
maennchen/zipstream-php 3.1.2 requires php ^8.2
```

**Causa:** El proyecto fue desarrollado para PHP 8.2+, pero el contenedor tiene PHP 7.4.

**Opciones:**

1. **Temporal (riesgoso):**
   ```bash
   docker exec -it php-ci sh -c "cd /var/www/html/mi-proyecto && composer update --ignore-platform-req=php --no-audit"
   ```

2. **Correcto:** Actualizar el Dockerfile a PHP 8.2:
   ```dockerfile
   FROM php:8.2-fpm-alpine
   ```

---

## <a id="composer-advisories"></a>Composer: advisories de seguridad

```
phpunit/phpunit 4.* found but blocked by security advisories
```

**Solución:**

```bash
docker exec -it php-ci sh -c "cd /var/www/html/mi-proyecto && composer update --no-audit"
```

O agregar en `composer.json`:

```json
"config": {
    "audit": {
        "abandoned": "ignore",
        "block-insecure": false
    }
}
```

---

## <a id="phpmyadmin-no-conecta"></a>phpMyAdmin no conecta

**Verificar:**

```bash
docker compose ps   # ¿db-ci está "healthy"?
docker compose logs db   # ¿Errores en los logs?
```

Causa más común: credenciales incorrectas en `.env`.

---

## <a id="cambios-no-reflejan"></a>Cambios en archivos no se reflejan

**Archivos PHP:** opcache tiene `validate_timestamps=1`, los detecta en 2 segundos. Si no:

```bash
docker compose restart php
```

**Nginx config:** requiere reload:

```bash
docker compose restart nginx
```

**Dockerfile:** requiere rebuild:

```bash
docker compose up -d --build
```

---

## <a id="puerto-en-uso"></a>Puerto ya en uso

```
Error: port 3307 is already allocated
```

**Causa:** XAMPP, otro Docker, o una instancia previa está usando el puerto.

**Identificar:**

```bash
# Windows
netstat -ano | findstr :3307

# Linux/Mac
lsof -i :3307
```

**Solución:** Cambiar el puerto en `docker-compose.yml`:

```yaml
ports:
  - 3308:3306   # Usar 3308 en vez de 3307
```

---

## <a id="logs-llenan-disco"></a>El contenedor se llena de logs

Todos los servicios tienen rotación automática (10 MB, 3 archivos). Si necesitás limpiar:

```bash
docker compose down
docker system prune -f   # ⚠️ Elimina contenedores parados, redes no usadas
```

---

## <a id="version-obsolete"></a>Advertencia: "version is obsolete"

```
the attribute `version` is obsolete, it will be ignored
```

**Solución:** Eliminar la línea `version: '3.8'` del `docker-compose.yml`. Es ignorada por Docker Compose moderno.
