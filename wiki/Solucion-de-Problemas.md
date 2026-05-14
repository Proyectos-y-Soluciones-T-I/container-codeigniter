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
- [CodeIgniter 3: errores E_DEPRECATED (dynamic property)](#ci3-deprecated-dynamic-property)
- [Unknown database](#unknown-database)
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

**Archivos PHP:** opcache ahora usa `validate_timestamps=0` (modo producción). Para ver cambios, reiniciar:

```bash
docker compose restart php
```

**Nginx config:** requiere reload:

```bash
docker compose restart nginx
```

**Dockerfile:** requiere rebuild:

```bash
docker compose build --no-cache php
docker compose up -d
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

## <a id="ci3-deprecated-dynamic-property"></a>CodeIgniter 3: errores E_DEPRECATED (dynamic property)

```
Severity: 8192
Message: Creation of dynamic property CI_URI::$config is deprecated
Filename: core/URI.php
```

y decenas más en `CI_Router`, `Controller.php`, `Loader.php`, `Driver.php`.

**Causa:** El contenedor está corriendo **PHP 8.x**. CodeIgniter 3 fue escrito para PHP 5.x/7.x — en PHP 8.0+ las propiedades dinámicas sin declaración explícita generan `E_DEPRECATED`. En PHP 8.2+ estos errores rompen `session_start()`, causan `headers already sent`, y pueden dejar la aplicación inoperable.

**Solución definitiva:**

```bash
docker compose build --no-cache php
docker compose up -d
```

El Dockerfile está fijado en `php:7.4.33-fpm-alpine`. Si lo cambiaron a 8.x manualmente, deben revertirlo.

**Verificar versión de PHP en el contenedor:**

```bash
docker exec -it php-ci php -v
```

Debe mostrar `PHP 7.4.33`. Si muestra 8.x, reconstruir con `--no-cache`.

> **Nota:** `error_reporting = E_ALL & ~E_DEPRECATED` en `php/custom.ini` solo oculta los mensajes — NO resuelve errores como `headers already sent`. La única solución real es la versión correcta de PHP.

---

## <a id="unknown-database"></a>Unknown database

```
Type: mysqli_sql_exception
Message: Unknown database 'sicof'
```

**Causa:** El `.env` del contenedor tiene un nombre de base de datos que no coincide con el `database.php` de CodeIgniter.

**Solución:** Verificar que `.env` y `application/config/database.php` usen el mismo nombre:

`.env`:
```
MYSQL_DATABASE=sicof
```

`application/config/database.php`:
```php
'database' => 'sicof',
```

Si el `.env` dice `development` pero `database.php` dice `sicof`, MariaDB crea la base `development` y CodeIgniter intenta conectarse a `sicof` — error.

**Alinear:**
1. Editá `.env` → `MYSQL_DATABASE=sicof` (o el nombre que corresponda)
2. Reiniciá MariaDB:
   ```bash
   docker compose restart db
   ```
3. Si la base de datos anterior ya tenía datos importados, toca reimportar:
   ```bash
   docker exec -i db-ci mysql -u root -proot sicof < dump.sql
   ```

---

## <a id="version-obsolete"></a>Advertencia: "version is obsolete"

```
the attribute `version` is obsolete, it will be ignored
```

**Solución:** Eliminar la línea `version: '3.8'` del `docker-compose.yml`. Es ignorada por Docker Compose moderno.
