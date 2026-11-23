# Variables

## Variables de entorno (`.env` → contenedor)

| Variable | Default | Obligatoria | Uso | Descripción |
|---|---|---|---|---|
| `OPENCODE_VERSION` | `latest` | No | Build + runtime | Versión de `@opencode/cli`. Vacío/`latest`: instala la última y **comprueba actualizaciones en cada arranque**. Valor fijo (`2.3.2`): instala esa versión, valida que coincide y **no** actualiza. También etiqueta la imagen local (`local/opencode:<versión>`). |
| `TZ` | `Europe/Madrid` | No | Runtime | Zona horaria de logs y fechas. |
| `PUID` | `1000` | No | Runtime | UID con el que corre OpenCode. Usar el del usuario del host/Samba propietario del código (`id -u`). Numérico y ≠ 0. |
| `PGID` | `1000` | No | Runtime | GID con el que corre OpenCode (`id -g`). Numérico y ≠ 0. |
| `OPENCODE_SERVER_USERNAME` | `opencode` | No | Runtime | Usuario de la autenticación HTTP basic del servidor. |
| `OPENCODE_SERVER_PASSWORD` | — | **Sí** | Runtime | Contraseña de la autenticación HTTP basic. Compose no arranca sin ella. Los clientes (`opencode attach`, Desktop) deben usar la misma. |
| `OPENCODE_PORT` | `4096` | No | Compose | Puerto publicado en el host (el interno siempre es 4096). |
| `WORKSPACE_PATH` | `./workspace` | No | Compose | Carpeta del host montada en `/workspace` (p. ej. la compartida por SMB). |

## Build args (Dockerfile)

| ARG | Default | Descripción |
|---|---|---|
| `OPENCODE_VERSION` | `latest` | Igual que arriba. Compose lo pasa desde `.env`. Una cadena vacía se trata como `latest`. |

## Variables internas del entrypoint

| Variable | Descripción |
|---|---|
| `current` | Versión instalada (`opencode --version` → `X.Y.Z`). |
| `latest` | Última versión publicada (`npm view @opencode/cli version`, timeout 20 s). |

## Configuración del workflow (GitHub → Settings → Secrets and variables → Actions)

| Nombre | Tipo | Obligatoria | Descripción |
|---|---|---|---|
| `GITHUB_TOKEN` | Secret automático | — | Lo genera GitHub en cada ejecución; publica en GHCR. |
| `DOCKERHUB_USERNAME` | Variable | No | Usuario de Docker Hub. Vacía = no publica en Docker Hub. |
| `DOCKERHUB_TOKEN` | Secret | Si hay `DOCKERHUB_USERNAME` | Personal access token de Docker Hub (Read & Write). |
| `force` | Input manual | No | `true` = reconstruye aunque la versión ya esté publicada. |

## Ejemplos de `.env`

**Siempre al día**
```env
OPENCODE_VERSION=
OPENCODE_SERVER_PASSWORD=clave-larga
WORKSPACE_PATH=/srv/code
```

**Versión controlada (recomendado si el cliente Windows debe coincidir)**
```env
OPENCODE_VERSION=2.3.2
OPENCODE_SERVER_PASSWORD=clave-larga
WORKSPACE_PATH=/srv/code
```
