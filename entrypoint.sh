#!/bin/bash
set -e

PUID=${PUID:-1000}
PGID=${PGID:-1000}
OPENCODE_VERSION=${OPENCODE_VERSION:-latest}

# --- Validación PUID/PGID ---
case "$PUID$PGID" in *[!0-9]*) echo "[entrypoint] PUID/PGID deben ser numéricos" >&2; exit 1;; esac
if [ "$PUID" = "0" ] || [ "$PGID" = "0" ]; then
  echo "[entrypoint] PUID/PGID=0 no permitido: opencode nunca se ejecuta como root" >&2; exit 1
fi

# --- Auto-update (solo si OPENCODE_VERSION=latest) ---
get_ver() { opencode --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1; }

if [ "$OPENCODE_VERSION" = "latest" ]; then
  current="$(get_ver)"
  latest="$(timeout 20 npm view @opencode/cli version 2>/dev/null || true)"
  if [ -z "$latest" ]; then
    echo "[opencode] WARN: no se pudo consultar la última versión, se mantiene ${current}"
  elif [ "$latest" != "$current" ] && \
       [ "$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -1)" = "$latest" ]; then
    echo "[opencode] Actualizando ${current} -> ${latest}"
    if timeout 300 npm i -g "@opencode/cli@${latest}"; then
      echo "[opencode] Versión actual: $(get_ver)"
    else
      echo "[opencode] WARN: fallo al actualizar, se mantiene ${current}"
    fi
  else
    echo "[opencode] Al día (${current})"
  fi
else
  echo "[opencode] Versión fija ${OPENCODE_VERSION}, sin auto-update"
fi

# --- Remapeo PUID/PGID ---
groupmod -o -g "$PGID" opencode
usermod  -o -u "$PUID" opencode

# Solo cambia propietario si difiere (arranques rápidos)
for d in /home/opencode/.config/opencode \
         /home/opencode/.local/share/opencode \
         /home/opencode/.local/state/opencode \
         /workspace; do
  mkdir -p "$d"
  [ "$(stat -c %u:%g "$d")" = "$PUID:$PGID" ] || chown -R "$PUID:$PGID" "$d"
done

exec gosu opencode "$@"
