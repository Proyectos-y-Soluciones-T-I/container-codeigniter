# Proyectos CodeIgniter 3

Guía para configurar y correr proyectos CodeIgniter 3 dentro de este entorno.

---

## Estructura esperada

```
src/
└── mi-proyecto/
    ├── index.php              ← punto de entrada
    ├── application/
    │   ├── config/
    │   │   ├── config.php     ← base_url, etc.
    │   │   └── database.php   ← conexión a MariaDB
    │   ├── controllers/
    │   ├── models/
    │   └── views/
    ├── system/                ← core de CI3
    └── vendor/                ← dependencias de Composer
```

---

## Clonar un proyecto existente

```bash
cd src/
git clone https://github.com/tu-usuario/mi-proyecto.git
```

El proyecto queda disponible en `http://localhost:8888/mi-proyecto/`

---

## Configurar `config.php`

```php
// application/config/config.php
$config['base_url'] = 'http://localhost:8888/mi-proyecto/';

// Si usás sesiones con base de datos:
$config['sess_driver'] = 'files';       // o 'database'
$config['sess_save_path'] = '/tmp';     // o nombre de tabla ci_sessions

// Timezone
date_default_timezone_set('America/Bogota');
```

---

## Configurar `database.php`

```php
// application/config/database.php
$db['default'] = array(
    'dsn'      => '',
    'hostname' => 'db',              // ← nombre del servicio Docker
    'username' => 'mi_usuario',      // ← del .env
    'password' => 'mi_password',     // ← del .env
    'database' => 'mi_proyecto',
    'dbdriver' => 'mysqli',
    'dbprefix' => '',
    'pconnect' => FALSE,
    'db_debug' => TRUE,
    'cache_on' => FALSE,
    'cachedir' => '',
    'char_set' => 'utf8mb4',
    'dbcollat' => 'utf8mb4_general_ci',
    'swap_pre' => '',
    'encrypt'  => FALSE,
    'compress' => FALSE,
    'stricton' => FALSE,
    'failover' => array(),
);
```

> **CRÍTICO:** `hostname` debe ser `db` (nombre del servicio en `docker-compose.yml`), **NO** `localhost`.

---

## Instalar dependencias con Composer

```bash
# Entrar al contenedor PHP
docker exec -it php-ci sh

# Ir al proyecto
cd /var/www/html/mi-proyecto

# Instalar dependencias
composer install
```

O en una sola línea:

```bash
docker exec -it php-ci sh -c "cd /var/www/html/mi-proyecto && composer install"
```

### Errores comunes con Composer

#### Paquetes que requieren PHP 8+

Si tu proyecto usa paquetes que requieren PHP 8.2+, pero el contenedor tiene PHP 7.4:

```bash
# Forzar ignorando requisitos de plataforma (riesgoso)
docker exec -it php-ci sh -c "cd /var/www/html/mi-proyecto && composer update --ignore-platform-req=php"
```

#### Advisories de seguridad (PHPUnit 4/5)

Si composer bloquea paquetes viejos por advisories de seguridad:

```bash
# Ignorar auditoría
docker exec -it php-ci sh -c "cd /var/www/html/mi-proyecto && composer update --ignore-platform-req=php --no-audit"
```

O agregar en `composer.json`:

```json
{
    "config": {
        "audit": {
            "abandoned": "ignore",
            "block-insecure": false
        }
    }
}
```

---

## Migraciones de base de datos

Si tu proyecto CI3 usa migraciones:

```php
// application/config/migration.php
$config['migration_enabled'] = TRUE;
$config['migration_type'] = 'sequential'; // o 'timestamp'
$config['migration_table'] = 'migrations';
```

Ejecutar migraciones (accediendo a un controlador):

```
http://localhost:8888/mi-proyecto/migrate
```

---

## Logs de CI3

Los logs de CodeIgniter se escriben en `application/logs/`. Estos están **bloqueados desde Nginx** (no accesibles por HTTP). Para verlos:

```bash
# Desde el host
cat src/mi-proyecto/application/logs/log-2026-05-12.php

# O entrando al contenedor
docker exec -it php-ci sh -c "cat /var/www/html/mi-proyecto/application/logs/log-*.php"
```

---

## Configurar entorno de desarrollo en CI3

```php
// index.php — al principio del archivo
define('ENVIRONMENT', isset($_SERVER['CI_ENV']) ? $_SERVER['CI_ENV'] : 'development');
```

Para cambiar a producción:

```php
define('ENVIRONMENT', 'production');
```

Esto afecta el nivel de errores mostrados y el comportamiento del profiler.

---

## .htaccess en CI3

**No se necesita.** Nginx maneja el rewrite automáticamente con la regla `@project_fallback`. Si tu proyecto tiene `.htaccess`, no se usa — Nginx lo ignora, y además está bloqueado por la regla `location ~ /\.`.

---

## Probar la instalación

Crear un archivo de prueba:

```php
// src/mi-proyecto/application/controllers/Welcome.php
<?php
defined('BASEPATH') OR exit('No direct script access allowed');

class Welcome extends CI_Controller {
    public function index() {
        phpinfo();
    }
}
```

Abrir: `http://localhost:8888/mi-proyecto/welcome`

Debe mostrar la salida de `phpinfo()`.
