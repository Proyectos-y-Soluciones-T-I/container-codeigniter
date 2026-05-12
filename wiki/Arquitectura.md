# Arquitectura

Estructura del proyecto, servicios, redes y cómo encaja todo.

---

## Diagrama de servicios

```
┌─────────────────────────────────────────────────────┐
│                  localhost:8888                       │
│  ┌──────────┐                                        │
│  │  Nginx   │ :80 ──► PHP-FPM :9000                 │
│  │  stable  │                                        │
│  └────┬─────┘      ┌──────────┐    ┌─────────────┐  │
│       │            │ PHP-FPM  │    │  MariaDB    │  │
│       │            │ 7.4.33   │───►│  10.5:3306  │  │
│       │            └──────────┘    └──────┬──────┘  │
│  src/ │                │                  │         │
│  ─────┼────────────────┼──────────────────┼────     │
│       │                │                  │         │
│  localhost:8081 ───────┼──────────────────┼────     │
│       │           ┌────┴─────┐            │         │
│       │           │phpMyAdmin│            │         │
│       │           └──────────┘    dbdata  │         │
│       │                         (volumen) │         │
│       └───────────────────────────────────┘         │
│              Red: ci-network (bridge)                │
└─────────────────────────────────────────────────────┘
```

---

## Servicios

### Nginx (`nginx-ci`)

- **Imagen:** `nginx:stable-alpine`
- **Puerto host:** `8888 → 80`
- **Función:** Servidor web. Sirve archivos estáticos directamente y pasa `.php` a PHP-FPM.
- **Configuración:** `nginx/default.conf` — montado como bind-mount, cambiable sin rebuild.
- **Healthcheck:** `wget --spider http://localhost:80`

**Ubicación de archivos servidos:** `./src` en el host → `/var/www/html` en el contenedor.

### PHP-FPM (`php-ci`)

- **Imagen:** `php:7.4.33-fpm-alpine` (compilada localmente si usás Dockerfile, o `versionamientopys/container-codeigniter` desde Docker Hub)
- **Función:** Procesa archivos PHP. Incluye Composer y extensiones compiladas.
- **Configuración PHP:** `php/custom.ini` — montado como bind-mount. Cambiable sin rebuild.
- **Healthcheck:** ping real a php-fpm via `cgi-fcgi` al endpoint `/ping`.
- **Dependencia:** espera a que MariaDB esté healthy antes de arrancar.

**Extensiones incluidas:**
`pdo` · `pdo_mysql` · `mysqli` · `gd` · `zip` · `xml` · `mbstring` · `bcmath` · `opcache`

### MariaDB (`db-ci`)

- **Imagen:** `mariadb:10.5`
- **Puerto host:** `3307 → 3306`
- **Función:** Base de datos. Datos persistentes en volumen `dbdata`.
- **Configuración:** `my.cnf` — montado como read-only.
- **Healthcheck:** `mysqladmin ping` autenticado.

### phpMyAdmin (`phpmyadmin-ci`)

- **Imagen:** `phpmyadmin/phpmyadmin`
- **Puerto host:** `8081 → 80`
- **Función:** Administración visual de MariaDB.
- **Dependencia:** espera a que MariaDB esté healthy.

---

## Red interna

Todos los servicios comparten la red `ci-network` (bridge). Los nombres de servicio funcionan como hostnames:

- `php` resuelve a la IP del contenedor PHP
- `db` resuelve a la IP del contenedor MariaDB

**Por eso en `database.php` de CodeIgniter el hostname es `db`, NO `localhost`.**

---

## Volúmenes y persistencia

| Origen (host) | Destino (contenedor) | Servicio | Modo |
|--------------|---------------------|----------|------|
| `./src` | `/var/www/html` | nginx, php | `:cached` |
| `./nginx/default.conf` | `/etc/nginx/conf.d/default.conf` | nginx | `:ro` |
| `./php/custom.ini` | `/usr/local/etc/php/conf.d/custom.ini` | php | `:ro` |
| `./php/zz-healthcheck.conf` | `/usr/local/etc/php-fpm.d/zz-healthcheck.conf` | php | `:ro` |
| `./my.cnf` | `/etc/mysql/conf.d/my.cnf` | db | `:ro` |
| `dbdata` (volumen) | `/var/lib/mysql` | db | — |

- **`:cached`** — optimización para Windows/Mac (mejora I/O)
- **`:ro`** — read-only: el contenedor no puede modificar estos archivos
- **`dbdata`** — volumen nombrado de Docker: los datos de MariaDB sobreviven a `docker compose down`

---

## Ciclo de vida de los contenedores

```
docker compose up -d
  │
  ├─► db-ci arranca
  │   └─► healthcheck: mysqladmin ping cada 10s
  │       └─► Healthy (~5-15s)
  │
  ├─► php-ci espera a db healthy (depends_on)
  │   └─► arranca cuando db está listo
  │       └─► healthcheck: cgi-fcgi ping cada 10s
  │           └─► Healthy (~2-5s)
  │
  ├─► phpmyadmin-ci espera a db healthy
  │   └─► arranca inmediatamente
  │
  └─► nginx-ci espera a php + db healthy
      └─► arranca cuando ambos están listos
          └─► healthcheck: wget spider cada 10s
              └─► Healthy (~1s)
```

---

## Directorios importantes

```
container-codeigniter/
├── src/                     ← tus proyectos PHP (gitignored)
│   ├── dashboard.php        ← dashboard visual de proyectos
│   └── mi-proyecto/         ← un proyecto (repo Git independiente)
│       ├── index.php
│       ├── application/
│       └── vendor/
├── nginx/
│   └── default.conf         ← configuración de Nginx
├── php/
│   ├── custom.ini           ← configuración PHP (editable sin rebuild)
│   └── zz-healthcheck.conf  ← habilita endpoint /ping para healthcheck
├── Dockerfile               ← definición de la imagen PHP
├── docker-compose.yml       ← orquestación de servicios
├── my.cnf                   ← configuración de MariaDB
├── .env                     ← variables de entorno (gitignored)
└── CHANGELOG.md             ← historial de versiones
```

---

## Ruteo de URLs

Nginx enruta por el primer segmento de la URL:

```
http://localhost:8888/mi-proyecto/usuarios/lista
                           │
                           └─► src/mi-proyecto/index.php?... (CI3)

http://localhost:8888/otro-proyecto/admin/dashboard
                           │
                           └─► src/otro-proyecto/index.php?... (CI3)
```

El rewrite lo maneja Nginx automáticamente. **No se necesita `.htaccess`.** Ver [Nginx y Seguridad](Nginx-y-Seguridad) para más detalles.

---

## Logs y rotación

Todos los servicios tienen logging con rotación automática:

- **Driver:** `json-file` (logs capturables con `docker compose logs`)
- **Tamaño máximo:** 10 MB por archivo
- **Archivos retenidos:** 3

```bash
# Ver logs de todos los servicios (en tiempo real)
docker compose logs -f

# Ver logs de un servicio específico
docker compose logs -f php
docker compose logs -f nginx
docker compose logs -f db
```
