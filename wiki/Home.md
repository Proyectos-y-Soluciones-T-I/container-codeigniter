# container-codeigniter

> Entorno de desarrollo PHP 7.4 local equivalente a XAMPP, basado en Docker. Soporta múltiples proyectos PHP/CodeIgniter 3 simultáneos en `src/`.

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter/blob/main/LICENSE)
[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-versionamientopys%2Fcontainer--codeigniter-blue)](https://hub.docker.com/r/versionamientopys/container-codeigniter)
[![Latest Tag](https://img.shields.io/badge/tag-v1.1.0-green)](https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter/releases/tag/v1.1.0)

---

## ¿Qué es esto?

Un reemplazo completo de XAMPP basado en Docker. Te permite:

- Correr **múltiples proyectos PHP simultáneamente** en subdirectorios, como hacías con `htdocs`
- Cada proyecto es un **repo Git independiente** — sin conflictos
- Usa **Nginx + PHP-FPM 7.4 + MariaDB 10.5 + phpMyAdmin**
- Optimizado para **CodeIgniter 3**, pero funciona con cualquier proyecto PHP
- Disponible como **imagen precompilada en Docker Hub**

---

## Stack

| Servicio    | Versión          | Puerto local | Puerto interno |
|-------------|------------------|-------------|----------------|
| Nginx       | stable-alpine    | `8888`      | `80`           |
| PHP-FPM     | 7.4.33 (Alpine)  | —           | `9000`         |
| MariaDB     | 10.5             | `3307`      | `3306`         |
| phpMyAdmin  | latest           | `8081`      | `80`           |

**Extensiones PHP:** `pdo` · `pdo_mysql` · `mysqli` · `gd` · `zip` · `xml` · `mbstring` · `bcmath` · `opcache`

**Composer:** incluido en la imagen PHP (no requiere servicio aparte)

---

## Empezar ya

**¿Primera vez?** Elegí tu camino:

| Camino | Para quién | Dónde empezar |
|--------|-----------|---------------|
| 🚀 **Docker Hub** | Quiero el entorno corriendo **ya**, sin modificar nada de PHP | [Inicio Rápido](Inicio-Rapido) |
| 🔧 **Clonar repo** | Quiero control total, modificar PHP, o contribuir | [Instalación](Instalacion) |
| 🐳 **Ya tengo Docker** | Se usar Docker, dame el `docker-compose.yml` | [Imagen Docker Hub](Imagen-Docker-Hub) |

---

## Navegación

| Sección | Contenido |
|---------|-----------|
| [Inicio Rápido](Inicio-Rapido) | Poner todo corriendo en menos de 5 minutos |
| [Instalación](Instalacion) | Guía detallada de instalación (ambos caminos) |
| [Arquitectura](Arquitectura) | Estructura del proyecto, servicios, redes, cómo encaja todo |
| [Configuración PHP](Configuracion-PHP) | `php/custom.ini`, opcache, timezone, memory, sesiones |
| [Nginx y Seguridad](Nginx-y-Seguridad) | Ruteo, gzip, headers de seguridad, bloqueo de archivos |
| [Base de Datos](Base-de-Datos) | MariaDB, phpMyAdmin, imports/exports, collations, troubleshooting |
| [Proyectos CodeIgniter 3](Proyectos-CodeIgniter-3) | Configurar CI3, database.php, base_url, estructura |
| [Imagen Docker Hub](Imagen-Docker-Hub) | Usar la imagen precompilada, tags, plataformas |
| [Solución de Problemas](Solucion-de-Problemas) | Errores comunes y cómo resolverlos |
| [Preguntas Frecuentes](Preguntas-Frecuentes) | FAQ con casos reales |
| [Changelog](Changelog) | Historial de versiones |

---

## URLs después de levantar

| URL | Qué es |
|-----|--------|
| `http://localhost:8888` | Dashboard visual de proyectos |
| `http://localhost:8888/tu-proyecto` | Tu proyecto |
| `http://localhost:8081` | phpMyAdmin |

---

## Créditos

- **Autor:** [Proyectos y Soluciones T.I.](https://github.com/Proyectos-y-Soluciones-T-I)
- **Licencia:** MIT
- **Repositorio:** [container-codeigniter](https://github.com/Proyectos-y-Soluciones-T-I/container-codeigniter)
- **Docker Hub:** [versionamientopys/container-codeigniter](https://hub.docker.com/r/versionamientopys/container-codeigniter)
