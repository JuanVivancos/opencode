# `.github/workflows/update-image.yml`

Workflow de GitHub Actions que **construye y publica una imagen multiarquitectura
(amd64 + arm64) cada vez que sale una versión nueva de OpenCode v2**.
Destino: `ghcr.io/<owner>/opencode` y, opcionalmente, `docker.io/<usuario>/opencode`.
No afecta al contenedor local ni hace commits en el repositorio.

## Disparadores y concurrencia

| Elemento | Valor | Efecto |
|---|---|---|
| `schedule` | `0 3 * * *` | Una vez al día, 03:00 UTC (04:00 invierno / 05:00 verano en Madrid). Solo usa el fichero de la rama por defecto. |
| `workflow_dispatch` | input `force` | Manual (ver abajo). `force=true` reconstruye aunque ya esté publicada. |
| `concurrency.group` | `update-docker-image` | Solo una ejecución a la vez. |
| `cancel-in-progress` | `false` | Si hay una en curso, la nueva **espera**. |
| `env.NPM_PACKAGE` | `@opencode/cli` | Paquete npm de OpenCode v2. |
| `vars.DOCKERHUB_USERNAME` | vacío | Si se define (y el secret `DOCKERHUB_TOKEN`), publica también en Docker Hub. |

### Lanzamiento manual

| Desde | Cómo |
|---|---|
| Web | Repo → **Actions** → **Update Docker Image** → **Run workflow** → rama `main` → marcar `force` si procede → **Run workflow**. |
| CLI | `gh workflow run update-image.yml` · forzado: `gh workflow run update-image.yml -f force=true` |
| API | `POST /repos/<owner>/<repo>/actions/workflows/update-image.yml/dispatches` con `{"ref":"main","inputs":{"force":"true"}}` |

## Flujo

```
check ──(needs_update=true)──► build [amd64] ─┐
                                build [arm64] ─┴─► merge ──► GHCR :<versión> + :latest
                                                        └──► Docker Hub (opcional)
check ──(needs_update=false)──► fin (≈10 s)
```

## Job 1 · `check` — ¿hay que publicar?

| Paso | Qué hace |
|---|---|
| Image names | Calcula `ghcr.io/<owner>/opencode` (minúsculas) y, si hay usuario Docker Hub, `docker.io/<usuario>/opencode`. |
| Get latest version | `npm view @opencode/cli version`. Falla si no empieza por `2.`. |
| Login GHCR | Con `GITHUB_TOKEN`, para leer imágenes privadas. |
| Get current image version | Ejecuta `opencode --version` (saltando el entrypoint) en `:latest` y `:<versión>` de GHCR. Comprueba si existe `:<versión>` en Docker Hub. |
| Compare versions | `needs_update=true` si `force`, o si `:latest`/`:<versión>` de GHCR no tienen la versión objetivo, o si falta en Docker Hub. |

| `:latest` | `:<versión>` | Resultado | Caso |
|---|---|---|---|
| 2.3.1 | (vacío) | true | Salió versión nueva |
| 2.3.2 | (vacío) | true | Tag de versión borrado |
| (vacío) | 2.3.2 | true | `:latest` borrado |
| 2.3.2 | 2.3.2 | false | Todo publicado |

## Job 2 · `build` — una imagen por arquitectura

| Paso | Qué hace |
|---|---|
| Prepare | `linux/amd64` → `linux-amd64` (nombre de artefacto). |
| Checkout | Descarga `Dockerfile`, `entrypoint.sh`… |
| Docker meta | Labels OCI + `org.opencontainers.image.version`. |
| QEMU + Buildx | Emulación para compilar arm64 en runner amd64. |
| Build and push by digest | Construye con `OPENCODE_VERSION=<versión>` y sube **sin tag** (solo `sha256`). |
| Export / Upload digest | Guarda el digest como artefacto temporal (1 día). |

`fail-fast: false`: si falla una arquitectura la otra continúa, pero `merge` no se ejecuta.

## Job 3 · `merge` — publicación

| Paso | Qué hace |
|---|---|
| Download digests | Junta los digests. |
| Login GHCR / Docker Hub | Docker Hub solo si está configurado. |
| Create manifest list (GHCR) | `imagetools create` → tags `:<versión>` (nuevo) y `:latest` (se mueve). |
| Copy to Docker Hub | Copia el manifest multiarquitectura a Docker Hub sin recompilar. |
| Inspect image | Verifica el resultado en el log. |

## Qué cambia cuando hay actualización

| Se crea/modifica | No se toca |
|---|---|
| 2 imágenes por digest (amd64/arm64) | Repositorio (sin commits) |
| Tag `:<versión>` | Tags antiguos (no se borran) |
| Tag `:latest` movido | Contenedor en 192.168.10.2 |
| Mismos tags en Docker Hub (opcional) | |

Para aplicar en el Linux: `docker compose pull && docker compose up -d` (o Watchtower).

## Cambios respecto al original (pilinux)

| # | Original | Actualizado | Motivo |
|---|---|---|---|
| 1 | Cron cada 4 h | Diario 03:00 UTC | Petición; menos ejecuciones. |
| 2 | `workflow_dispatch` simple | Input `force` | Reconstruir tras cambiar Dockerfile/entrypoint sin versión nueva. |
| 3 | `getLatestRelease` de `anomalyco/opencode` | `npm view @opencode/cli` | El original sigue releases v1. |
| 4 | — | Validación `2.*` | Evita publicar vacío o v1. |
| 5 | `sed '/^X.Y.Z$/p'` | `grep -oE 'X.Y.Z'` | v2 imprime `opencode vX.Y.Z` ⇒ el original reconstruía siempre. |
| 6 | `docker run IMAGE opencode --version` | `--entrypoint opencode` | Evita ejecutar el auto-update del entrypoint. |
| 7 | `ghcr.io/pilinux/opencode` fijo | `ghcr.io/<owner>/opencode` | Funciona en cualquier cuenta. |
| 8 | — | Docker Hub opcional | Publicación en registro adicional gratuito. |
| 9 | — | `setup-qemu-action` | Emulación explícita para arm64. |
| 10 | `checkout` en `check` | Eliminado | No se usaba. |

## Publicación en Docker Hub (opcional)

1. Docker Hub → Account settings → Personal access tokens → token *Read & Write*.
2. GitHub → repo → Settings → Secrets and variables → Actions:
   - **Variables**: `DOCKERHUB_USERNAME` = tu usuario.
   - **Secrets**: `DOCKERHUB_TOKEN` = el token.

Sin la variable definida, los pasos de Docker Hub se saltan.

## A tener en cuenta

- GitHub puede retrasar u omitir ejecuciones programadas en horas de carga.
- En repos públicos, los cron se desactivan tras 60 días sin actividad.
- La primera publicación en GHCR es privada: hacerla pública o `docker login ghcr.io`.
- arm64 por emulación es lento; en repos públicos se puede usar el runner `ubuntu-24.04-arm`.
