FROM node:26.13.1-trixie

# Versión de OpenCode v2 (@opencode/cli). Vacío o "latest" = última + auto-update al arrancar
ARG OPENCODE_VERSION=latest

WORKDIR /app

# check architecture
RUN uname -m

# Runtime extra: ripgrep (búsquedas), gosu (drop de privilegios), jq, libatomic1 (Node >= 25)
RUN apt-get update && apt-get install -y --no-install-recommends \
      ripgrep gosu jq libatomic1 \
 && rm -rf /var/lib/apt/lists/*

# install opencode v2 globally (opencode-ai = v1, @opencode/cli = v2)
RUN VER="${OPENCODE_VERSION:-latest}" && \
  npm i -g "@opencode/cli@${VER}" && \
  installed_version="$(opencode --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)" && \
  echo "Installed opencode version: ${installed_version}" && \
  case "${installed_version}" in 2.*) ;; *) echo "No es v2: ${installed_version}" >&2; exit 1;; esac && \
  if [ "${VER}" != "latest" ] && [ "${installed_version}" != "${VER}" ]; then \
    echo "Expected opencode version ${VER}, got ${installed_version}" >&2; exit 1; \
  fi

# el entrypoint necesita saber si la versión es fija o latest
ENV OPENCODE_VERSION=${OPENCODE_VERSION:-latest}

# non-root user: sustituye al usuario node para que opencode tenga UID/GID 1000
RUN userdel -r node && \
  groupadd -g 1000 opencode && \
  useradd -m -u 1000 -g opencode -s /bin/bash opencode

# directorios de datos y workspace
RUN mkdir -p /home/opencode/.local/share/opencode \
             /home/opencode/.local/state/opencode \
             /home/opencode/.config/opencode \
             /workspace && \
  chown -R opencode:opencode /home/opencode /workspace

# el entrypoint arranca como root, actualiza (si latest), remapea PUID/PGID y baja privilegios
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

WORKDIR /workspace
EXPOSE 4096
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
