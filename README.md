# OpenCode Docker (v2)

Imagen Docker para ejecutar **OpenCode v2** (`@opencode/cli`) como servidor 24x7 (`opencode serve`),
al que se conectan clientes remotos: OpenCode Desktop, Web UI o TUI (`opencode attach`).

Basado en [pilinux/opencode-docker](https://github.com/pilinux/opencode-docker), con estos cambios:

| Cambio | Original (pilinux) | Este proyecto |
|---|---|---|
| OpenCode | `opencode-ai` (v1) | `@opencode/cli` (v2) |
| Base | `node:24.x-bookworm` | `node:26.13.1-trixie` (LTS) |
| Versión | Solo build | Build + **auto-update al arrancar** si `latest` |
| Validación versión | `${raw#v}` (fallaba con `opencode vX`) | Extrae `X.Y.Z` y exige `2.*` |
| Paquetes extra | — | `ripgrep`, `gosu`, `jq`, `libatomic1` |
| Workspace | — | Volumen `/workspace` configurable |
| Workflow CI | Releases GitHub (v1), cada 4 h, solo GHCR | npm v2, diario, `force` manual, GHCR + Docker Hub opcional |

## Estructura

```
opencode-docker/
├── .github/workflows/update-image.yml   # CI: publica imagen en GHCR (+ Docker Hub opcional)
├── docs/
│   ├── FUNCIONAMIENTO.md                # Ciclo build → arranque → serve
│   ├── VARIABLES.md                     # Todas las variables explicadas
│   └── WORKFLOW.md                      # Qué hace update-image.yml
├── .dockerignore
├── .env.sample
├── .gitattributes                       # Fuerza LF (entrypoint.sh no funciona con CRLF)
├── .gitignore
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
└── README.md
```

## Inicio rápido

```bash
cp .env.sample .env        # editar password, PUID/PGID y WORKSPACE_PATH
docker compose build --pull
docker compose up -d
docker compose logs -f opencode
```

Conexión desde Windows:

```powershell
$env:OPENCODE_SERVER_PASSWORD = 'tu-password'
opencode attach http://192.168.10.2:4096
```

O en navegador: `http://192.168.10.2:4096`.

## Operación

| Acción | Comando |
|---|---|
| Forzar comprobación de actualización | `docker compose restart opencode` |
| Ver versión | `docker compose exec opencode opencode --version` |
| Reconstruir imagen | `docker compose build --pull && docker compose up -d` |
| Fijar versión | `OPENCODE_VERSION=2.3.2` en `.env` + rebuild |

## Imagen publicada (GitHub Actions)

El workflow `update-image.yml` (diario 03:00 UTC + manual) publica en:

```
ghcr.io/<owner-en-minúsculas>/opencode:<versión>
ghcr.io/<owner-en-minúsculas>/opencode:latest
```

Opcional Docker Hub (variable `DOCKERHUB_USERNAME` + secret `DOCKERHUB_TOKEN`):
`docker.io/<usuario>/opencode:<versión>`.

Usar la imagen publicada en lugar de compilar:

```yaml
services:
  opencode:
    image: ghcr.io/<owner>/opencode:2.3.2
```

Si la imagen es privada: `docker login ghcr.io -u <usuario>` con un PAT `read:packages`.

Lanzamiento manual: Actions → *Update Docker Image* → *Run workflow*
o `gh workflow run update-image.yml -f force=true`. Detalle en [`docs/WORKFLOW.md`](docs/WORKFLOW.md).
