#!/usr/bin/env bash
# Instala (o actualiza) el plugin desde esta copia del repo, para desarrollarlo.
# El shell recarga el widget al cambiar los archivos; el servicio y el panel ya
# abierto pueden necesitar `omarchy-restart-shell`.
#
#   scripts/instalar-local.sh
set -euo pipefail

id="page.doro.pomodoro"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
destino="$HOME/.config/omarchy/plugins/$id"

mkdir -p "$destino"
rsync -a --delete --exclude .git --exclude .github "$repo/" "$destino/"
omarchy plugin validate "$destino"

if ! omarchy plugin list --json | jq -e --arg id "$id" '.[] | select(.id == $id and .enabled)' >/dev/null; then
  omarchy-shell shell rescanPlugins
  omarchy plugin enable "$id"
fi
