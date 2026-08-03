#!/bin/zsh
# memwatch.sh — amostra o footprint de memória do MyPasteApp por categoria.
#
#   ./memwatch.sh guided     # roteiro cronometrado: só olhe a tela e siga
#   ./memwatch.sh report     # reimprime o relatório da última sessão
#
#   ./memwatch.sh start / mark <rótulo> / stop    # modo manual
#
# O modo guiado existe porque clicar no terminal tira o foco do overlay, que
# fecha sozinho (windowDidResignKey → hide()). Aqui o script anuncia cada
# passo, espera, e marca por conta própria — você nunca toca no terminal.
#
# Variáveis:
#   MEMWATCH_SAY=0     desliga a narração por voz
#   MEMWATCH_HEAP=1    salva `heap` em cada marco (pausa o app por alguns
#                      segundos; útil para contar NSImage/NSBitmapImageRep)

set -u
# Números com ponto decimal, para que o awk consiga somar/subtrair as colunas
# num locale pt-BR (onde %.1f sairia com vírgula e truncaria nas contas).
export LC_NUMERIC=C

APP="${MEMWATCH_APP:-MyPasteApp}"
# Fora da árvore do git de propósito: cada sessão grava dezenas de snapshots
# e um raw.log de centenas de KB, que não têm por que virar diff.
BASE="${MEMWATCH_DATA:-${TMPDIR:-/tmp}/memwatch-data}"
SESSION="$BASE/current"
CSV="$SESSION/samples.csv"
RAW="$SESSION/raw.log"
SNAPS="$SESSION/snapshots"
PIDFILE="$SESSION/sampler.pid"
INTERVAL="${MEMWATCH_INTERVAL:-1}"
SAY="${MEMWATCH_SAY:-1}"
WANT_HEAP="${MEMWATCH_HEAP:-0}"

# ---------------------------------------------------------------- helpers

app_pid() { pgrep -x "$APP" | head -1 }

# Lê `footprint -p PID` → total;imageio;malloc;coreanim;gpu;cgimage (em MB)
#
#   imageio   ImageIO ................. buffers de decodificação de imagem.
#                                       É aqui que aparece cada NSImage(data:)
#   malloc    MALLOC_* ............... heap: Data dos blobs, objetos SwiftData
#   coreanim  CoreAnimation .......... camadas do compositor
#   gpu       IOSurface, IOAccelerator  texturas
#   cgimage   CG image, CoreUI image .. bitmaps já entregues ao CoreGraphics
#
# Só categorias dirty reais entram — a soma NÃO reproduz o total, porque o
# phys_footprint desconta regiões compartilhadas. O total vem do cabeçalho.
parse_footprint() {
  awk '
    function tomb(n, u) {
      if (u == "GB") return n * 1024
      if (u == "MB") return n
      if (u == "KB") return n / 1024
      return n / 1048576
    }
    /Footprint:/ && /\[/ {
      for (i = 1; i <= NF; i++) if ($i == "Footprint:") total = tomb($(i+1), $(i+2))
      next
    }
    NF >= 8 && $2 ~ /^(B|KB|MB|GB)$/ {
      mb = tomb($1, $2)
      cat = ""
      for (i = 8; i <= NF; i++) cat = cat (i > 8 ? " " : "") $i
      if (cat == "ImageIO")                                    imageio  += mb
      else if (cat ~ /^MALLOC/)                                malloc   += mb
      else if (cat ~ /CoreAnimation/)                          coreanim += mb
      else if (cat ~ /IOSurface|IOAccelerator|graphics/)       gpu      += mb
      else if (cat ~ /CG image|CoreUI image|image backing|CoreImage|^CoreGraphics/) cgimage += mb
    }
    END { printf "%.0f;%.1f;%.1f;%.1f;%.1f;%.1f\n", total, imageio, malloc, coreanim, gpu, cgimage }
  '
}

announce() {
  [[ "$SAY" == "1" ]] && say -r 220 "$1" >/dev/null 2>&1 &
  return 0
}

write_mark() {
  local label="$1" pid out parsed
  pid="$(app_pid)" || return
  [[ -z "$pid" ]] && return
  out="$(footprint -p "$pid" 2>/dev/null)"
  parsed="$(print -r -- "$out" | parse_footprint)"
  print -r -- "MARK;$parsed;$label" >> "$CSV"
  print -r -- "$out" > "$SNAPS/${label//[^a-zA-Z0-9._-]/_}.footprint.txt"
  if [[ "$WANT_HEAP" == "1" ]]; then
    heap "$pid" > "$SNAPS/${label//[^a-zA-Z0-9._-]/_}.heap.txt" 2>/dev/null
  fi
  local total imageio malloc coreanim
  IFS=';' read -r total imageio malloc coreanim _ <<< "$parsed"
  printf "\r  ✓ %-26s total %4s MB · ImageIO %6s · MALLOC %6s · CoreAnim %6s\n" \
    "$label" "$total" "$imageio" "$malloc" "$coreanim"
}

start_sampler() {
  rm -rf "$SESSION"
  mkdir -p "$SNAPS"
  echo "elapsed_s;total_mb;imageio_mb;malloc_mb;coreanim_mb;gpu_mb;cgimage_mb;mark" > "$CSV"
  # Sem `local` aqui dentro: em zsh, `local` fora de uma função (este bloco é
  # um subshell, não uma função) age como `typeset` e ECOA a variável no
  # terminal a cada iteração — o que soterra as mensagens do roteiro guiado.
  # O stdout do subshell também vai para /dev/null por garantia; tudo que
  # importa é escrito nos arquivos.
  (
    _start=$SECONDS
    while true; do
      _p="$(app_pid)"
      if [[ -n "$_p" ]]; then
        _out="$(footprint -p "$_p" 2>/dev/null)"
        if [[ -n "$_out" ]]; then
          print -r -- "$((SECONDS - _start));$(print -r -- "$_out" | parse_footprint);" >> "$CSV"
          { print -r -- "===== t=$((SECONDS - _start))s pid=$_p"; print -r -- "$_out" } >> "$RAW"
        fi
      fi
      sleep "$INTERVAL"
    done
  ) >/dev/null 2>&1 &
  echo $! > "$PIDFILE"
}

stop_sampler() {
  [[ -f "$PIDFILE" ]] || return
  kill "$(cat "$PIDFILE")" 2>/dev/null
  rm -f "$PIDFILE"
}

# Passo do roteiro: rótulo | segundos | instrução
step() {
  local label="$1" secs="$2" text="$3"
  print -r -- ""
  print -r -- "▶ $text"
  announce "$text"
  local i
  for ((i = secs; i > 0; i--)); do
    printf "\r  %2ds restantes " "$i"
    sleep 1
  done
  printf "\r                    "
  write_mark "$label"
}

# ---------------------------------------------------------------- guided

cmd_guided() {
  local pid
  pid="$(app_pid)"
  if [[ -z "$pid" ]]; then
    echo "!! $APP não está rodando. Inicie o app e rode de novo." >&2
    exit 1
  fi

  cat <<'EOF'
──────────────────────────────────────────────────────────────────────
 Roteiro guiado — não toque no terminal daqui em diante.
 Cada passo é anunciado (por voz também) e marcado sozinho no fim.
 Se um passo acabar antes de você terminar, tudo bem: o que importa
 é o estado no momento da marcação.
──────────────────────────────────────────────────────────────────────
EOF
  print -r -- ""
  printf "Começando em "
  local i
  for ((i = 5; i > 0; i--)); do printf "%d… " "$i"; sleep 1; done
  print -r -- ""
  announce "Começando. Não toque em nada."

  start_sampler

  step 01-baseline 15 \
    "Passo 1: não toque em nada. Overlay fechado."

  step 02-overlay-abre-fecha 12 \
    "Passo 2: abra o overlay e feche com Escape. Sem navegar. Repita duas vezes."

  step 03-scroll-texto 20 \
    "Passo 3: abra o overlay e navegue com as setas apenas pelos cards de texto."

  step 04-scroll-imagem 25 \
    "Passo 4: continue navegando, agora passando por todos os cards de imagem. Ida e volta, duas vezes."

  step 05-preview-imagem 12 \
    "Passo 5: selecione uma imagem grande e abra o preview com espaço. Deixe aberto."

  step 06-preview-fechado 12 \
    "Passo 6: feche só o preview com Escape. Mantenha o overlay aberto. Não navegue."

  step 07-preview-5x 25 \
    "Passo 7: abra e feche o preview de cinco imagens diferentes."

  step 08-preview-texto-longo 12 \
    "Passo 8: abra o preview do texto mais longo do histórico."

  step 09-overlay-fechado 15 \
    "Passo 9: feche o overlay com Escape e não toque em mais nada."

  step 10-idle-60s 60 \
    "Passo 10: último. Deixe o app parado por um minuto."

  announce "Medição concluída."
  stop_sampler
  cmd_report
}

# ---------------------------------------------------------------- report

cmd_report() {
  [[ -f "$CSV" ]] || { echo "!! nenhuma sessão em $SESSION" >&2; exit 1; }
  print -r -- ""
  print -r -- "=== Marcos (MB) ================================================================"
  printf "%-26s %7s %9s %9s %10s %7s %9s\n" \
    "marco" "TOTAL" "ImageIO" "MALLOC" "CoreAnim" "gpu" "CG image"
  awk -F';' '$1 == "MARK" {
    printf "%-26s %7s %9s %9s %10s %7s %9s\n", $8, $2, $3, $4, $5, $6, $7
  }' "$CSV"

  print -r -- ""
  print -r -- "=== Variação entre marcos ======================================================"
  awk -F';' '$1 == "MARK" {
    if (prev != "") printf "%-26s %+7.0f %+9.1f %+9.1f %+10.1f\n", $8, $2-p2, $3-p3, $4-p4, $5-p5
    else            printf "%-26s %7s %9s %9s %10s\n", $8, "—", "—", "—", "—"
    prev = $8; p2 = $2; p3 = $3; p4 = $4; p5 = $5
  }' "$CSV"

  print -r -- ""
  print -r -- "Pico observado na série completa:"
  awk -F';' 'NR > 1 && $1 != "MARK" && $2+0 > max { max = $2+0; line = $0 }
             END { split(line, f, ";"); printf "  t=%ss  total=%s MB  ImageIO=%s  MALLOC=%s  CoreAnim=%s\n", f[1], f[2], f[3], f[4], f[5] }' "$CSV"
  print -r -- ""
  print -r -- "Dados brutos: $SESSION"
}

# ---------------------------------------------------------------- manual

cmd_start() {
  [[ -z "$(app_pid)" ]] && { echo "!! $APP não está rodando." >&2; exit 1; }
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "!! já há amostragem rodando. Use 'stop'." >&2; exit 1
  fi
  start_sampler
  echo "Amostrando $APP a cada ${INTERVAL}s → $CSV"
}

cmd_stop() { stop_sampler; echo "Amostragem encerrada."; cmd_report }

case "${1:-}" in
  guided) cmd_guided ;;
  start)  cmd_start ;;
  mark)   shift; write_mark "${1:-sem-rotulo}" ;;
  stop)   cmd_stop ;;
  report) cmd_report ;;
  *)      echo "uso: $0 {guided|report|start|mark <rótulo>|stop}" >&2; exit 1 ;;
esac
