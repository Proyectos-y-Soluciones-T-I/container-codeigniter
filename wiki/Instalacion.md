# Instalación

Guía detallada para ambos caminos: Docker Hub (imagen precompilada) y clonar el repositorio (control total).

---

## Antes de empezar

### Requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows/Mac) o Docker Engine (Linux)
- [Git](https://git-scm.com/) (solo para clonar proyectos o el repositorio)

### Verificar instalación

```bash
docker --version
docker compose version
git --version
```

---

## Camino A: Imagen de Docker Hub (recomendado)

Usá este camino si querés el entorno corriendo ya, sin necesidad de modificar la imagen PHP.

### A1. Usar el script interactivo de setup

**Linux / macOS:**

```bash
curl -fsSL https://raw.githubusercontent.com/Proyectos-y-Soluciones-T-I/container-codeigniter/main/setup.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/Proyectos-y-Soluciones-T-I/container-codeigniter/main/setup.ps1 | iex
```

El script te guía paso a paso. Crea:
- `docker-compose.yml` usando la imagen de Docker Hub
- `.env` con las credenciales que elijas
- `nginx/default.conf` listo para CodeIgniter 3
- `src/` (carpeta vacía)
- `my.cnf`

Después del script:

```bash
cd src
git clone https://github.com/tu-usuario/mi-proyecto.git
cd ..
docker compose up -d
```

### A2. Manual (sin script)

Seguí los pasos en [Inicio Rápido](Inicio-Rapido). Resumido:

1. Crear `docker-compose.yml` con la imagen `versionamientopys/container-codeigniter:latest`
2. Crear `.env` con credenciales
3. Crear `nginx/default.conf`
4. Crear carpeta `src/`
5. `docker compose up -d`

---

## Camino B: Clonar el repositorio (control total)

Usá este camino si necesitás modificar PHP, personalizar extensiones, o contribuir al proyecto.

### B1. Clonar

```bash
git clone https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter.git
cd container-codeigniter
```

### B2. Variables de entorno

Creá tu `.env` a partir del ejemplo (si existe `.env.example`):

```bash
cp .env.example .env
```

O crealo manualmente:

```env
MYSQL_ROOT_PASSWORD=tu-root-password-seguro
MYSQL_DATABASE=mi_base
MYSQL_USER=mi_usuario
MYSQL_PASSWORD=mi_password
```

### B3. Construir y levantar

```bash
docker compose up -d --build
```

La primera vez:
- Descarga `php:7.4.33-fpm-alpine`
- Compila extensiones PHP (~2-3 minutos)
- Descarga `nginx:stable-alpine` y `mariadb:10.5`
- Crea el volumen de datos de MariaDB

Vas a ver muchas líneas de compilación. Es normal. Solo la primera vez.

### B4. Verificar

```bash
docker compose ps
```

Debe mostrar los 4 servicios como "Up" o "healthy":

```
NAME              STATUS
nginx-ci          Up
php-ci            Up (healthy)
db-ci             Up (healthy)
phpmyadmin-ci     Up
```

Abrí en el navegador:
- `http://localhost:8888` → Dashboard de proyectos
- `http://localhost:8081` → phpMyAdmin

---

## Después de instalar

### Agregar un proyecto

```bash
cd src/
git clone https://github.com/tu-usuario/mi-proyecto.git
```

### Instalar dependencias con Composer

```bash
docker exec -it php-ci sh -c "cd /var/www/html/mi-proyecto && composer install"
```

### Configurar CodeIgniter 3

Ver [Proyectos CodeIgniter 3](Proyectos-CodeIgniter-3).

---

## Actualizar a una nueva versión

### Si usaste Docker Hub

```bash
docker compose pull php
docker compose up -d
```

### Si clonaste el repositorio

```bash
git pull
docker compose up -d --build
```

---

## Plataformas soportadas

| SO | Estado |
|----|--------|
| Windows 10/11 (Docker Desktop) | ✅ |
| macOS (Intel) | ✅ |
| macOS (Apple Silicon M1/M2/M3) | ✅ |
| Linux (x86-64) | ✅ |
| Linux (ARM64) | ✅ |

**Arquitecturas de la imagen Docker:**
- `linux/amd64` — Intel/AMD
- `linux/arm64` — Apple Silicon, AWS Graviton
- `linux/arm/v7` — Raspberry Pi 3/4
