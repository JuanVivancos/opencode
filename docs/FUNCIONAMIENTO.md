# Funcionamiento

## 1. Build (Dockerfile)

1. Parte de `node:26.13.1-trixie` (Debian 13 + Node LTS, glibc).
2. Instala `ripgrep`, `gosu`, `jq`, `libatomic1`.
3. Instala `@opencode/cli@${OPENCODE_VERSION}` (vacío ⇒ `latest`).
4. Verifica:
   - la versión instalada empieza por `2.` (evita instalar v1 por error);
   - si la versión es fija, coincide exactamente.
5. Guarda `OPENCODE_VERSION` como `ENV` para que el entrypoint sepa el modo.
6. Elimina el usuario `node` y crea `opencode` con UID/GID 1000.
7. Crea los directorios de datos y `/workspace`.

## 2. Arranque (entrypoint.sh) — se ejecuta como root

```
┌───────────────────────────┐
│ Valida PUID/PGID (≠0, num)│
└─────────────┬─────────────┘
              ▼
   OPENCODE_VERSION == latest ?
      │ sí                    │ no
      ▼                       ▼
 npm view @opencode/cli   "Versión fija, sin auto-update"
      │
 ¿más nueva que la instalada? (sort -V)
      │ sí → npm i -g (timeout 300s); si falla, sigue con la actual
      │ no → "Al día"
      │ sin red → WARN y sigue
              ▼
 groupmod/usermod opencode → PUID/PGID
              ▼
 chown de volúmenes solo si el propietario difiere
              ▼
 exec gosu opencode opencode serve --hostname 0.0.0.0 --port 4096
```

## 3. Ejecución

- `opencode serve` levanta API HTTP + Web UI en el puerto 4096, protegido con HTTP basic
  (`OPENCODE_SERVER_USERNAME` / `OPENCODE_SERVER_PASSWORD`).
- Se ejecuta como usuario no root con el UID/GID del host ⇒ los ficheros creados en
  `/workspace` son editables desde el host y desde las unidades SMB de Windows.

## Volúmenes

| Host | Contenedor | Contenido |
|---|---|---|
| `./data/config` | `/home/opencode/.config/opencode` | `opencode.json` y configuración |
| `./data/share` | `/home/opencode/.local/share/opencode` | `auth.json` (credenciales de proveedores), sesiones |
| `./data/state` | `/home/opencode/.local/state/opencode` | Estado de la aplicación |
| `${WORKSPACE_PATH}` | `/workspace` | Código de los proyectos |

> ⚠️ Rutas heredadas de pilinux (v1). Verificar tras el primer arranque que la v2 escribe
> `auth.json` y sesiones en ellas: `docker compose exec opencode ls -la ~/.local/share/opencode`.

## Limitaciones conocidas

- La actualización en arranque se escribe en la capa del contenedor: al **recrearlo**
  vuelve a la versión de la imagen y se actualiza de nuevo (arranque más lento).
- No hay actualización en caliente: un contenedor 24x7 solo se actualiza al reiniciarse.
- Con `latest`, servidor y cliente Windows pueden desincronizarse de versión.
- Las imágenes publicadas por el workflow llevan versión fija (sin auto-update);
  para activarlo, `OPENCODE_VERSION=latest` en el `environment` del compose.
- Setups endurecidos (`read_only: true`, `cap_drop: [ALL]`) no permiten el remapeo como root:
  usar `user: "<uid>:<gid>"` y `OPENCODE_VERSION` fija.
