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
rsync -a --delete --delete-excluded --exclude .git --exclude .github --exclude .claude --exclude .agents "$repo/" "$destino/"
omarchy plugin validate "$destino"

# Lugar en la barra, la primera vez: la misma pregunta que hace `omarchy plugin
# add`, con la opción del manifest marcada. Sin terminal se usa la del manifest.
elegir_seccion() {
  [[ -t 0 && -t 1 ]] || return 0
  # Para Omarchy, el `center` del manifest es al lado del reloj: `centerEnd`.
  local por_defecto
  por_defecto=$(jq -r '.barWidget.defaultSection // "centerEnd" | if . == "center" then "centerEnd" end' "$repo/manifest.json")

  local -A secciones=(
    [left]="Izquierda"
    [centerBegin]="Centro, antes del reloj"
    [center]="Centro"
    [centerEnd]="Centro, después del reloj"
    [tray]="Derecha, junto a los íconos del sistema"
    [right]="Derecha"
  )
  local orden=(left centerBegin center centerEnd tray right)
  local opciones=() clave elegida
  for clave in "${orden[@]}"; do opciones+=("${secciones[$clave]}"); done

  elegida=$(gum choose --header "¿Dónde va Doro en la barra?" --selected "${secciones[$por_defecto]}" "${opciones[@]}") || return 0
  for clave in "${orden[@]}"; do
    [[ ${secciones[$clave]} == "$elegida" ]] && echo "$clave"
  done
}

if ! omarchy plugin list --json | jq -e --arg id "$id" '.[] | select(.id == $id and .enabled)' >/dev/null; then
  omarchy-shell shell rescanPlugins
  seccion=$(elegir_seccion)
  if [[ -n $seccion ]]; then
    omarchy plugin enable "$id" --section "$seccion"
  else
    omarchy plugin enable "$id"
  fi
fi
