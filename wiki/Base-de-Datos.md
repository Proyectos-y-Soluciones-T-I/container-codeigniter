# Base de Datos

Gestión de MariaDB: conexión, phpMyAdmin, imports, exports, collations y solución de errores comunes.

---

## Credenciales

Las credenciales se definen en el archivo `.env`:

```env
MYSQL_ROOT_PASSWORD=tu-root-password
MYSQL_DATABASE=mi_base
MYSQL_USER=mi_usuario
MYSQL_PASSWORD=mi_password
```

---

## Conexión desde código PHP

```php
$host = 'db';      // ← nombre del servicio, NO 'localhost'
$port = 3306;      // ← puerto interno de Docker
$user = 'mi_usuario';
$pass = 'mi_password';
$db   = 'mi_base';
```

**¿Por qué `db` y no `localhost`?** Porque dentro de la red Docker, cada servicio se resuelve por su nombre de servicio en `docker-compose.yml`. `localhost` dentro del contenedor PHP es el propio contenedor PHP, no MariaDB.

---

## Configuración de CodeIgniter 3

```php
// application/config/database.php
$db['default'] = array(
    'dsn'      => '',
    'hostname' => 'db',
    'username' => 'mi_usuario',
    'password' => 'mi_password',
    'database' => 'mi_proyecto',
    'dbdriver' => 'mysqli',
    'char_set' => 'utf8mb4',
    'dbcollat' => 'utf8mb4_general_ci',
    'dbprefix' => '',
    'pconnect' => FALSE,
    'db_debug' => TRUE,
);
```

---

## phpMyAdmin

**URL:** `http://localhost:8081`

**Login:**
- Servidor: `db` (ya configurado)
- Usuario: `root`
- Contraseña: la definida en `.env` (`MYSQL_ROOT_PASSWORD`)

### Crear base de datos visualmente

1. Abrir phpMyAdmin
2. Click en "Nueva" (panel izquierdo)
3. Nombre de la base de datos
4. Seleccionar `utf8mb4_general_ci`
5. Click en "Crear"

### Crear usuario

1. Ir a la pestaña "Privilegios"
2. Click en "Agregar cuenta de usuario"
3. Completar nombre, host (`%` = cualquier host), contraseña
4. Seleccionar la base de datos y privilegios
5. Click en "Continuar"

---

## CLI de MariaDB

```bash
# Entrar al CLI
docker exec -it db-ci mysql -u root -p
```

Una vez adentro:

```sql
-- Crear base de datos
CREATE DATABASE mi_proyecto CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Crear usuario
CREATE USER 'mi_usuario'@'%' IDENTIFIED BY 'mi_password';

-- Dar permisos
GRANT ALL PRIVILEGES ON mi_proyecto.* TO 'mi_usuario'@'%';
FLUSH PRIVILEGES;

-- Ver bases de datos
SHOW DATABASES;

-- Salir
EXIT;
```

---

## Importar un dump SQL

### Importación normal

```bash
docker exec -i db-ci mysql -u root -pTU_PASSWORD NOMBRE_DB < dump.sql
```

> **Importante:** la contraseña va PEGADA al `-p`: `-pRootPass`, NO `-p RootPass`.

### Importación con dump grande (cientos de MB)

```bash
docker exec -i db-ci sh -c 'mysql -u root -pTU_PASSWORD --max_allowed_packet=1G NOMBRE_DB' < dump.sql
```

### Importación convirtiendo collations (MySQL 8 → MariaDB 10.5)

Si el dump fue exportado de MySQL 8, puede contener collations `utf8mb4_0900_*` que no existen en MariaDB 10.5:

```bash
sed -e 's/utf8mb4_0900_ai_ci/utf8mb4_unicode_ci/g' \
    -e 's/utf8mb4_0900_as_ci/utf8mb4_unicode_ci/g' \
    dump.sql | docker exec -i db-ci mysql -u root -pTU_PASSWORD NOMBRE_DB
```

> Esto convierte las collations en el stream, sin modificar el archivo original. Seguro usarlo siempre — si no hay collations 0900, simplemente no modifica nada.

---

## Exportar una base de datos

```bash
docker exec db-ci mysqldump -u root -pTU_PASSWORD --max-allowed-packet=1G NOMBRE_DB > backup.sql
```

### Exportar solo estructura

```bash
docker exec db-ci mysqldump -u root -pTU_PASSWORD --no-data NOMBRE_DB > estructura.sql
```

### Exportar solo datos

```bash
docker exec db-ci mysqldump -u root -pTU_PASSWORD --no-create-info NOMBRE_DB > datos.sql
```

---

## Conexión desde cliente externo (DBeaver, TablePlus, HeidiSQL)

```
Host:     127.0.0.1
Puerto:   3307
Usuario:  root
Password: el de .env
```

> Puerto `3307` en el host — evita conflicto con MySQL/XAMPP local en `3306`.

---

## Configuración de MariaDB (`my.cnf`)

```ini
[mysqld]
max_allowed_packet=1G              # Tamaño máximo de paquete
net_buffer_length=32M
bind-address=0.0.0.0
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci

# Timeouts para operaciones largas
wait_timeout=28800                 # 8 horas
interactive_timeout=28800
net_read_timeout=3600
net_write_timeout=3600

# InnoDB tuning
innodb_buffer_pool_size=512M
innodb_log_file_size=256M
innodb_log_buffer_size=64M
innodb_flush_log_at_trx_commit=2  # Performance (no producción)
```

### Cambios en `my.cnf`

El archivo se monta como read-only. Los cambios aplican al reiniciar MariaDB:

```bash
docker compose restart db
```

Para verificar un parámetro:

```bash
docker exec -it db-ci mysql -u root -pTU_PASSWORD -e "SHOW VARIABLES LIKE 'max_allowed_packet';"
```

---

## Volumen de datos

Los datos de MariaDB se guardan en el volumen `dbdata`:

```yaml
volumes:
  dbdata:
```

Esto significa que **los datos sobreviven** a:
- `docker compose down`
- `docker compose restart`
- Reconstrucción de otros servicios

Para **eliminar todos los datos**:

```bash
docker compose down -v   # ⚠️ ELIMINA el volumen dbdata
```

---

## Errores comunes de base de datos

### ERROR 1153: Got a packet bigger than 'max_allowed_packet' bytes

El dump contiene filas más grandes que el límite del servidor. MariaDB 10.5 acepta máximo **1 GB**.

**Solución:**

```bash
docker compose restart db
```

Verificar:

```bash
docker exec -it db-ci mysql -u root -p -e "SHOW VARIABLES LIKE 'max_allowed_packet';"
```

Debe mostrar `1073741824` (= 1 GB). Luego reimportar.

### ERROR 2006: MySQL server has gone away

La importación tardó más que el timeout y la conexión se cerró.

**Solución:** `my.cnf` ya tiene `wait_timeout=28800` (8 horas). Si sigue pasando, reiniciar DB:

```bash
docker compose restart db
```

### ERROR 1273: Unknown collation utf8mb4_0900_ai_ci

El dump usa collations de MySQL 8 que no existen en MariaDB 10.5.

**Solución:** Usar `sed` durante la importación (ver arriba).

### Access denied for user

**Causa:** Credenciales incorrectas o el usuario no existe.

**Verificar:**

```bash
docker exec -it db-ci mysql -u root -pTU_PASSWORD -e "SELECT user, host FROM mysql.user;"
```
