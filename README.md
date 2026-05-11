# container-codeigniter

Entorno de desarrollo local equivalente a XAMPP, basado en Docker.
Permite correr múltiples proyectos PHP/CodeIgniter 3 simultáneamente dentro de `src/`,
cada uno en su propio repositorio de GitHub, sin conflictos entre ellos.

> Imagen Docker publicada en Docker Hub: `versionamientopys/container-codeigniter`

---

## Stack

| Servicio    | Imagen                     | Puerto local |
|-------------|----------------------------|--------------|
| Nginx       | nginx:stable-alpine        | 8888         |
| PHP-FPM     | php:7.4.33-fpm-alpine      | interno      |
| MariaDB     | mariadb:10.5               | 3307         |
| PhpMyAdmin  | phpmyadmin/phpmyadmin      | 8081         |
| Composer    | composer:2.8               | utilidad     |

> Puerto 3307 para MariaDB — evita conflicto con XAMPP que ocupa el 3306.

---

## Estructura del repositorio

```
container-codeigniter/
├── src/                  ← equivalente a htdocs/ de XAMPP (gitignored)
│   ├── .gitkeep
│   ├── proyecto-a/       ← repo GitHub independiente
│   └── proyecto-b/       ← repo GitHub independiente
├── nginx/
│   └── default.conf
├── mysql/                ← datos de MariaDB (gitignored)
├── Dockerfile
├── docker-compose.yml
├── my.cnf
└── .env                  ← variables de entorno (gitignored, crear desde .env.example)
```

## Inicio Rápido

Elegí cómo querés empezar:

- **Opción A: Usando la imagen de Docker Hub** — bajá la imagen lista y empezá ya (recomendado si no necesitás modificar PHP).
- **Opción B: Clonar el repositorio (control total)** — compilá la imagen vos mismo y tené control total sobre la configuración.

### Opción A: Usando la imagen de Docker Hub

Si solo querés un entorno de desarrollo funcionando rápido, usá el script de setup.
Crea automáticamente toda la estructura de carpetas, los archivos de configuración y te pregunta las credenciales (o podés dejar los valores por defecto).

**Linux / macOS**

```bash
curl -fsSL https://raw.githubusercontent.com/Proyectos-y-Soluciones-T-I/container-codeigniter/main/setup.sh | bash
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/Proyectos-y-Soluciones-T-I/container-codeigniter/main/setup.ps1 | iex
```

> El script no ejecuta `docker compose up` — primero te muestra lo que generó para que lo revisés.

El script crea:
- `src/` — carpeta donde van tus proyectos PHP
- `nginx/default.conf` — configuración de Nginx lista para CodeIgniter 3
- `my.cnf` — configuración optimizada de MariaDB
- `.env` — con las credenciales que ingresaste
- `docker-compose.yml` — usando la imagen de Docker Hub

Una vez que el script termina:

```bash
# Cloná tus proyectos en src/
cd src && git clone https://github.com/tu-usuario/mi-proyecto.git

# Levantá el stack
docker compose up -d
```

---

#### Configuración manual (sin script)

Si preferís configurar todo a mano, creá un archivo `docker-compose.yml` en una carpeta vacía:

> Este ejemplo incluye healthchecks, logging con rotación y mounts optimizados — refleja la configuración real del repositorio.

```yaml
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

  db:
    image: mariadb:10.5
    container_name: db-ci
    restart: always
    env_file:
      - .env
    ports:
      - 3307:3306
    volumes:
      - dbdata:/var/lib/mysql
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -u root -p\"${MYSQL_ROOT_PASSWORD}\" || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    container_name: phpmyadmin-ci
    ports:
      - '8081:80'
    restart: always
    env_file:
      - .env
    environment:
      PMA_HOST: db
      PMA_PORT: 3306
    depends_on:
      db:
        condition: service_healthy
    networks:
      - ci-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  ci-network:
    driver: bridge

volumes:
  dbdata:
```

#### Variables de entorno

Copiá el archivo `.env.example` a `.env`:

```bash
cp .env.example .env
```

Y ajustá las credenciales. El archivo debe tener al menos:

```env
MYSQL_ROOT_PASSWORD=cambia-esto
MYSQL_DATABASE=mi_base
MYSQL_USER=mi_usuario
MYSQL_PASSWORD=mi_password
```

#### Configuración de Nginx

Creá la carpeta `nginx/` con un archivo `default.conf`. Este es un ejemplo mínimo — el repositorio incluye la versión completa con headers de seguridad adicionales (X-Frame-Options, X-Content-Type-Options, etc.):

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

#### Levantar el stack

```bash
docker compose up -d
```

#### Verificar

| URL | Servicio |
|-----|----------|
| http://localhost:8888 | Lista de proyectos (htdocs) |
| http://localhost:8081 | PhpMyAdmin |

¿Necesitás más detalles? Mirá [DOCKER_HUB.md](DOCKER_HUB.md) para la referencia completa.

---

### Opción B: Clonar el repositorio (control total)

Este es el camino recomendado si necesitás modificar la imagen, customizar PHP, o contribuir al proyecto.

### 1. Requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Git

### 2. Clonar el repositorio

```bash
git clone https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter.git
cd container-codeigniter
```

### 3. Crear el archivo de variables de entorno

Copiar `.env.example` a `.env` en la raíz y ajustar los valores:

```bash
cp .env.example .env
```

> Los valores de abajo son **ejemplos** — cambiálos por tus propias credenciales. El archivo está en `.gitignore` — nunca se sube al repo.

```env
MYSQL_ROOT_PASSWORD=cambia-esto
MYSQL_DATABASE=mi_base
MYSQL_USER=mi_usuario
MYSQL_PASSWORD=mi_password
```

### 4. Levantar los contenedores

```bash
docker-compose up --build
```

Primera vez tarda varios minutos — descarga imágenes y compila PHP.

### 5. Verificar que todo funciona

| URL | Servicio |
|-----|----------|
| http://localhost:8888 | Lista de proyectos (htdocs) |
| http://localhost:8081 | PhpMyAdmin |

---

## Agregar un proyecto nuevo

Cada proyecto vive en su propia carpeta dentro de `src/` y es un repositorio de GitHub independiente.

```bash
cd src/
git clone https://github.com/tu-usuario/mi-proyecto.git
```

Accedé al proyecto en: `http://localhost:8888/mi-proyecto/`

### Configurar CodeIgniter 3 para subdirectorio

En `src/mi-proyecto/application/config/config.php`:

```php
$config['base_url'] = 'http://localhost:8888/mi-proyecto/';
```

### Instalar dependencias con Composer

```bash
docker-compose run --rm composer install --working-dir=/app/mi-proyecto
```

---

## Bases de datos

### Opción A — PhpMyAdmin (visual)

1. Abrir http://localhost:8081
2. Usuario: `root` / Contraseña: la que pusiste en `.env` como `MYSQL_ROOT_PASSWORD`
3. Click en "Nueva base de datos"
4. Ingresar nombre y seleccionar charset `utf8mb4_general_ci`
5. Click en "Crear"

### Opción B — CLI

```bash
docker exec -it db-ci mysql -u root -p
```

```sql
CREATE DATABASE mi_proyecto CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'mi_usuario'@'%' IDENTIFIED BY 'mi_password';
GRANT ALL PRIVILEGES ON mi_proyecto.* TO 'mi_usuario'@'%';
FLUSH PRIVILEGES;
EXIT;
```

### Importar un dump SQL

```bash
docker exec -i db-ci mysql -u root -p<tu-password> <nombre_db> < mi_dump.sql
```

> La contraseña va pegada al `-p` sin espacio: `-proot`, no `-p root`.

Para dumps muy grandes (cientos de MB o más), usar `sh -c` para forzar los límites del cliente:

```bash
docker exec -i db-ci sh -c 'mysql -u root -p<tu-password> --max_allowed_packet=1G <nombre_db>' < mi_dump.sql
```

### Importar un dump con conversión de collation (recomendado)

Si el dump fue exportado desde **MySQL 8**, puede contener collations como `utf8mb4_0900_ai_ci` o `utf8mb4_0900_as_ci` que **no existen en MariaDB 10.5** y causan error al importar.

La solución es convertirlas a `utf8mb4_unicode_ci` en el momento de la importación usando `sed`:

```bash
sed -e 's/utf8mb4_0900_ai_ci/utf8mb4_unicode_ci/g' \
    -e 's/utf8mb4_0900_as_ci/utf8mb4_unicode_ci/g' \
    /ruta/al/archivo.sql | docker exec -i db-ci mysql -u root -p<tu-password> <nombre_db>
```

> Reemplazá `/ruta/al/archivo.sql` por la ruta real del archivo, por ejemplo `./backup.sql` o `C:\dumps\mi_proyecto.sql`.

**¿Por qué este comando?**

MariaDB 10.5 usa `utf8mb4_unicode_ci` como collation equivalente. Las collations `0900` son exclusivas de MySQL 8 y no tienen equivalente directo en versiones anteriores. El `sed` hace la sustitución en el stream, sin modificar el archivo original.

Se puede usar como práctica general para cualquier importación — no hay riesgo si el dump ya usa collations compatibles, simplemente no reemplaza nada.

### Exportar una base de datos

```bash
docker exec db-ci mysqldump -u root -p<tu-password> --max-allowed-packet=1G <nombre_db> > backup.sql
```

### Conectar desde CodeIgniter 3

En `src/mi-proyecto/application/config/database.php`:

```php
$db['default'] = array(
    'dsn'      => '',
    'hostname' => 'db',           // nombre del servicio en docker-compose
    'username' => 'mi_usuario',     // MYSQL_USER del .env
    'password' => 'mi_password',    // MYSQL_PASSWORD del .env
    'database' => 'mi_proyecto',
    'dbdriver' => 'mysqli',
    'dbprefix' => '',
    'pconnect' => FALSE,
    'db_debug' => TRUE,
    'cache_on' => FALSE,
    'cachedir' => '',
    'char_set' => 'utf8mb4',
    'dbcollat' => 'utf8mb4_general_ci',
);
```

> El hostname es `db` (nombre del contenedor en la red interna), NO `localhost`.

### Conectar desde cliente externo (TablePlus, DBeaver, etc.)

```
Host:     127.0.0.1
Puerto:   3307
Usuario:  root  (o devuser)
Password: el que pusiste en .env
```

---

## Comandos útiles

### Contenedores

```bash
# Levantar (primera vez o después de cambios en Dockerfile)
docker-compose up --build

# Levantar en background
docker-compose up -d

# Apagar
docker-compose down

# Reiniciar todo
docker-compose down && docker-compose up --build

# Ver logs en tiempo real
docker-compose logs -f

# Ver logs de un servicio específico
docker-compose logs -f nginx
docker-compose logs -f php
docker-compose logs -f db
```

### Acceder a los contenedores

```bash
# Entrar al contenedor PHP (para debug, artisan, etc.)
docker exec -it php-ci sh

# Entrar a MariaDB CLI
docker exec -it db-ci mysql -u root -p
```

### Composer por proyecto

El servicio de Composer ya no corre como daemon. Se usa con `docker-compose run`:

```bash
# Instalar dependencias
docker-compose run --rm composer install --working-dir=/app/mi-proyecto

# Agregar un paquete
docker-compose run --rm composer require vendor/paquete --working-dir=/app/mi-proyecto

# Actualizar dependencias
docker-compose run --rm composer update --working-dir=/app/mi-proyecto
```

> El flag `--rm` elimina el contenedor después de usarlo para no acumular contenedores detenidos.

---

## Notas importantes

### Git y múltiples proyectos

- `src/` está en `.gitignore` de este repo — los proyectos adentro no se suben acá.
- Cada carpeta en `src/` es un repo independiente con su propio `.git/`.
- No hay conflictos de git entre este repo de infraestructura y los repos de proyectos.

### XAMPP coexistencia

- MariaDB de Docker corre en puerto `3307` (XAMPP usa el `3306`).
- Podés tener XAMPP y Docker corriendo al mismo tiempo sin conflictos.
- PhpMyAdmin de Docker (`:8081`) administra solo la base de datos del contenedor.

### Sesiones PHP

- `session.save_path=/tmp` — las sesiones se guardan dentro del contenedor.
- Si necesitás persistir sesiones entre reinicios, montá un volumen para `/tmp`.

### Healthchecks

Todos los servicios tienen healthchecks configurados:
- **Nginx**: verifica que el servidor responda en puerto 80
- **PHP-FPM**: verifica que el proceso php-fpm esté saludable
- **MariaDB**: verifica que el servidor acepte conexiones
- **phpMyAdmin**: depende de que MariaDB esté healthy antes de arrancar

Esto evita errores 502 al iniciar el stack. El `depends_on` ahora usa `condition: service_healthy`.

### Logging con rotación

Todos los servicios tienen logging configurado con rotación automática:
- Tamaño máximo por archivo: `10MB`
- Archivos retenidos: `3`
- Esto previene que los logs llenen el disco.

### Optimización de volúmenes

Los bind mounts usan el flag `:cached` para mejorar performance en Windows/Mac:
```yaml
volumes:
  - ./src:/var/www/html:cached
```

### Seguridad

**Nginx**:
- Security headers: `X-Frame-Options`, `X-Content-Type-Options`, `X-XSS-Protection`, `Referrer-Policy`
- Caché de assets estáticos (CSS, JS, imágenes) por 30 días
- Bloqueo de acceso a archivos ocultos (`.env`, `.git`, etc.)
- Bloqueo explícito de `composer.json`, `composer.lock`, `package.json`

**PHP**:
- `expose_php=Off` — no expone versión de PHP en headers
- `display_errors=Off` — errores no se muestran en producción (solo logs)
- `log_errors=On` — errores van a stderr (capturados por Docker logs)
- Cookies de sesión con `httponly=1` y `use_strict_mode=1`

**MariaDB**:
- `my.cnf` montado como read-only (`:ro`)
- Variables de entorno para credenciales (nunca hardcodeadas)

### Nginx: caché de assets estáticos

Archivos CSS, JS, imágenes y fuentes se cachean por 30 días con `Cache-Control: public, immutable`. Esto mejora significativamente la velocidad de carga después de la primera visita.

Para forzar recarga de assets después de un deploy, agregar query string:
```html
<link rel="stylesheet" href="/miapp/css/style.css?v=2">
```

---

## Troubleshooting

### ERROR 1153: Got a packet bigger than 'max_allowed_packet' bytes

**Causa**: el dump tiene filas o sentencias más grandes que el límite del servidor.
MariaDB 10.5 acepta máximo **1 GB**. Cualquier valor mayor en `my.cnf` se ignora silenciosamente.

**Solución**: reiniciar el contenedor de DB para que aplique el `my.cnf` actualizado:

```bash
docker-compose restart db
```

Verificar que el límite aplicó:

```bash
docker exec -it db-ci mysql -u root -p<tu-password> -e "SHOW VARIABLES LIKE 'max_allowed_packet';"
```

Debe mostrar `1073741824` (= 1 GB).

Luego reimportar:

```bash
docker exec -i db-ci sh -c 'mysql -u root -p<tu-password> --max_allowed_packet=1G <nombre_db>' < mi_dump.sql
```

---

### ERROR 2006: MySQL server has gone away (durante importación)

**Causa**: la importación tardó más que `wait_timeout` (conexión cerrada por inactividad).

**Solución**: el `my.cnf` ya tiene `wait_timeout=28800` (8 horas). Si sigue pasando, reiniciar DB y reimportar.

---

### PhpMyAdmin no conecta a la base de datos

Verificar que el contenedor `db-ci` está corriendo:

```bash
docker-compose ps
```

Si `db` aparece como "Exit" o "Restarting":

```bash
docker-compose logs db
```

Causa más común: credenciales incorrectas en `.env`.

---

### Cambios en `my.cnf` no aplican

`my.cnf` se monta como volumen. Los cambios aplican al reiniciar el servicio, no con hot-reload:

```bash
docker-compose restart db
```

---

## Licencia

MIT — ver `license.txt`.
