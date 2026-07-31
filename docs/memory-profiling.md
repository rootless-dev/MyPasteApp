# Medindo a memória do MyPasteApp

`scripts/memwatch.sh` amostra o consumo do app por categoria de alocação e
guia um roteiro de dez passos, cada um desenhado para isolar uma causa
diferente. Foi a ferramenta que produziu o diagnóstico da Fase 2.5 e é o gate
que a fecha.

## Por que não o medidor do Xcode

O medidor do Xcode mostra um número só. Ele diz *que* subiu, nunca *o quê*
subiu — e as três causas encontradas na Fase 2.5 pedem correções que não têm
nada a ver umas com as outras. `footprint -p <pid>`, que é o que este script
usa, reporta o mesmo `phys_footprint` do Xcode já quebrado por categoria, e
custa 0,12s por amostra.

| coluna | o que agrupa | o que acusa |
|---|---|---|
| `TOTAL` | `phys_footprint` | o número que o Xcode mostra |
| `ImageIO` | `ImageIO` | buffers de decodificação de imagem |
| `MALLOC` | `MALLOC_*` | heap: `Data` dos blobs, objetos SwiftData |
| `CoreAnim` | `CoreAnimation` | camadas do compositor — inclusive texto rasterizado |
| `gpu` | `IOSurface`, `IOAccelerator` | texturas |
| `CG image` | `CG image`, `CoreUI image data` | bitmaps já entregues ao CoreGraphics |

A soma das colunas **não** reproduz o `TOTAL`: o `phys_footprint` desconta
regiões compartilhadas. O total vem do cabeçalho do `footprint`, não da soma.

## Preparação

1. No histórico, antes de começar:
   - **5 ou mais screenshots de tela cheia** (⇧⌘4) — é o caso que dói;
   - 20 ou mais itens de texto;
   - um texto bem longo, de alguns milhares de caracteres.
2. Deixe o app parado por ~15s antes de iniciar.
3. Deixe o Terminal visível num canto. **Você não vai clicar nele.**

## Rodar

```bash
./scripts/memwatch.sh guided
```

São ~3,5 minutos. O script anuncia cada passo em texto e por voz, mostra a
contagem regressiva, marca o footprint sozinho ao fim de cada um e imprime o
relatório no final.

Variáveis:

- `MEMWATCH_SAY=0` — desliga a narração por voz
- `MEMWATCH_HEAP=1` — salva um `heap` em cada marco: a contagem de objetos
  vivos por classe (`NSImage`, `NSBitmapImageRep`). Mais lento, pausa o app
  alguns segundos a cada marcação
- `MEMWATCH_DATA=<dir>` — onde gravar (padrão: `$TMPDIR/memwatch-data`)
- `MEMWATCH_INTERVAL=<s>` — intervalo entre amostras (padrão: 1s)

Modo manual, para investigar algo pontual:
`./scripts/memwatch.sh start`, `mark <rótulo>`, `stop`, `report`.

## Por que o modo guiado existe

O overlay se fecha ao perder o foco (`windowDidResignKey` → `hide()`). Clicar
no Terminal para disparar um `mark` destrói exatamente o estado que se quer
medir — a primeira rodada de medição saiu sem marco nenhum por causa disso. No
modo guiado o script marca por conta própria; você só olha a tela.

## Os dez passos

| # | ação | duração |
|---|---|---|
| 1 | nada — overlay fechado | 15s |
| 2 | abrir o overlay e fechar (Esc), 2×, sem navegar | 12s |
| 3 | navegar com ← → só pelos cards de **texto** | 20s |
| 4 | navegar por todos os cards de **imagem**, ida e volta 2× | 25s |
| 5 | abrir o preview (␣) de uma imagem grande e deixar aberto | 12s |
| 6 | fechar **só** o preview (Esc), overlay aberto, sem navegar | 12s |
| 7 | abrir e fechar o preview de 5 imagens diferentes | 25s |
| 8 | abrir o preview do texto mais longo | 12s |
| 9 | fechar o overlay (Esc) | 15s |
| 10 | app parado | 60s |

## O que cada par discrimina

- **3 → 4** separa o custo de texto do custo de imagem.
- **4 sozinho**: a segunda passada pelos mesmos cards deveria ser de graça. Se
  `ImageIO` continua subindo, há re-decodificação a cada render, não "carregou
  e ficou".
- **5 → 6**: se nada cai ao fechar o preview, o painel não está soltando o
  conteúdo hospedado.
- **6 → 7**: crescimento acumulado aqui significa que cada abertura de preview
  deixa lixo para trás.
- **8**: isola o custo do texto longo. Bate em `CoreAnim` quando o texto está
  sendo rasterizado inteiro, e em `MALLOC` quando é só o `String` na memória.
- **9 → 10**: se nada cai com o app ocioso, não há purga nenhuma.

## Linha de base — 2026-07-31, antes da Fase 2.5

Medição de referência. Valores em MB.

| marco | TOTAL | ImageIO | MALLOC | CoreAnim |
|---|---|---|---|---|
| 01 baseline | 219 | 105 | 54,6 | 41,0 |
| 02 overlay abre/fecha | 210 | 96 | 54,6 | 42,0 |
| 03 scroll por texto | 203 | 88 | 54,6 | 42,0 |
| 04 scroll por imagens | **303** | **226** | 50,6 | 5,7 |
| 05 preview de imagem | 204 | 126 | 51,6 | 5,3 |
| 06 preview fechado | 204 | 126 | 51,6 | 5,3 |
| 07 preview 5× | 190 | 112 | 52,6 | 5,0 |
| 08 preview de texto longo | **434** | 119 | 57,6 | **240,0** |
| 09 overlay fechado | 434 | 119 | 57,6 | 240,0 |
| 10 ocioso por 60s | 434 | 119 | 57,6 | 240,0 |

Numa medição feita com o app recém-iniciado, o baseline era 61 MB — os 219 MB
acima são resíduo de uma sessão de uso anterior, e são um resultado por si só.

Para comparar com uma rodada nova, use o **mesmo histórico** e o **mesmo modo
de execução**: rodar pelo Xcode adiciona overhead de alocação e infla os
números absolutos. Os deltas entre marcos continuam comparáveis nos dois casos;
os valores absolutos, não.

## Três armadilhas já resolvidas no script

Se algum dia ele for reescrito, elas voltam:

- a categoria do `footprint` chama-se `ImageIO`, **sem espaço**. Procurar por
  `Image IO` joga ~90 MB silenciosamente no balde de "outros";
- no zsh, `local` dentro de um subshell (que não é uma função) age como
  `typeset` e **ecoa a variável** — o sampler soterrava as mensagens do
  roteiro a cada segundo;
- em locale pt-BR, `%.1f` produz vírgula decimal, que o `awk` trunca ao fazer
  contas. O script força `LC_NUMERIC=C`.
