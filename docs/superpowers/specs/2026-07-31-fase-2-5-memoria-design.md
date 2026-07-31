# Fase 2.5 — Memória

Design aprovado em 2026-07-31. Fase não prevista no `ROADMAP.md` original:
nasceu de uma medição feita entre a Fase 2 e a Fase 3, depois que o app foi
observado saindo de ~60 MB para ~300 MB de uso normal.

Numeração fracionária de propósito — os itens 11 a 25 mantêm seus números.

Ambiente de referência: Xcode 26.6, SDK macOS 26.5, deployment target 26.2,
Swift 5. O projeto usa `PBXFileSystemSynchronizedRootGroup`, então arquivos
novos entram no alvo pelo simples fato de existirem no diretório — não há
`project.pbxproj` para editar.

Branch: `feature/fase-2-5-memoria`, criada a partir de `develop`.

## A medição

Duas rodadas com `footprint -p`, que reporta o mesmo `phys_footprint` que o
medidor de memória do Xcode, quebrado por categoria de alocação. O roteiro e a
ferramenta entram no repositório nesta fase (entrega 1).

Segunda rodada, marcos em MB:

| marco | TOTAL | ImageIO | MALLOC | CoreAnimation |
|---|---|---|---|---|
| 01 baseline (overlay fechado) | 219 | 105 | 54,6 | 41,0 |
| 02 overlay abre/fecha | 210 | 96 | 54,6 | 42,0 |
| 03 scroll por texto | 203 | 88 | 54,6 | 42,0 |
| **04 scroll por imagens** | **303** | **226** | 50,6 | 5,7 |
| 05 preview de imagem | 204 | 126 | 51,6 | 5,3 |
| 06 preview fechado | 204 | 126 | 51,6 | 5,3 |
| 07 preview 5× | 190 | 112 | 52,6 | 5,0 |
| **08 preview de texto longo** | **434** | 119 | 57,6 | **240,0** |
| 09 overlay fechado | 434 | 119 | 57,6 | 240,0 |
| 10 ocioso por 60s | 434 | 119 | 57,6 | 240,0 |

Três fatos, cada um com sua causa isolada:

**O preview de um texto longo custa +235 MB de CoreAnimation, de uma vez.** O
snapshot mostra as regiões de CoreAnimation indo de 66 para 74 — oito regiões
novas de ~29 MB cada. A causa é `ItemPreviewView.swift:56-62`: um `ScrollView`
com um `Text` dentro faz o SwiftUI rasterizar o texto **inteiro**, não só a
parte visível. O Core Animation não consegue uma layer única desse tamanho e
particiona em tiles — daí os oito blocos. Pela aritmética inversa (520pt de
largura, @2x, 4 bytes por pixel), isso equivale a ~29.000 pontos de altura
rasterizados para exibir 380.

**Navegar pelos cards de imagem custa +138 MB de ImageIO.** É o cenário que
motivou a investigação. `ClipboardCardView.swift:150` cria um `NSImage(data:)`
dentro do `body`, e `ClipboardCardView.swift:198` cria **outro**, só para ler
largura e altura no rodapé. Nenhum cache, nenhum downsample: um screenshot de
3024×1964 ocupa ~24 MB descomprimido, e o card tem ~260×180 pontos. Pior,
`OverlayView.swift:208-211` grava os frames dos cards em `@State`, o que
invalida o `body` inteiro — durante o scroll animado isso acontece a cada tick,
refazendo as decodificações.

**Nada é liberado, nunca.** Fechar o preview (05→06), fechar o overlay (09) e
ficar ocioso por um minuto (10) deram delta exatamente zero nos três casos.
`OverlayWindowController.swift:319` só faz `orderOut`, mantendo vivos o
`NSHostingView` e suas layers. O baseline desta rodada — 219 MB, com 105 MB de
ImageIO **antes de abrir o overlay** — é resíduo da sessão anterior de uso; na
primeira rodada, com o app recém-iniciado, o baseline era 61 MB.

## O que a medição corrigiu na análise de código

A leitura inicial do código, feita antes de medir, apontou como causa dominante
a decodificação de imagens e listou o preview de texto como um problema menor
("um texto de alguns MB vira um layout TextKit caríssimo"). A medição inverteu
a ordem: o preview de texto sozinho custa mais que todo o resto somado, e é a
única frente cujo custo **nunca** é devolvido.

Também apareceu, e não estava na análise, que o próprio baseline é contaminado
— o app não volta ao patamar de partida depois de usado.

## Decisões tomadas

| Decisão | Escolha | Por quê |
|---|---|---|
| Posição no roadmap | **Fase 2.5**, entre a 2 e a 3 | Fase própria, com o mesmo peso das outras, sem renumerar os itens 11 a 25 nem invalidar referências a "Fase 3 — Busca" nas specs anteriores |
| Preview de texto longo | **`NSTextView` com TextKit 2** | Layout por viewport: a memória passa a independer do tamanho do texto, e o painel continua cumprindo o que o comentário no código diz ser sua razão de existir — ler o texto que o card trunca |
| Truncar o texto exibido? | **Não** | Truncar resolveria a memória desistindo da funcionalidade. Um teto duro de segurança também não entra: o TextKit 2 já trata o caso patológico |
| Dimensões da imagem | **`CGImageSourceCopyPropertiesAtIndex`**, sem campos novos no modelo | Lê o cabeçalho do arquivo sem decodificar pixels. Persistir no `ClipboardItem` exigiria migração de schema e um caminho de preenchimento para os itens já salvos, para ganhar a leitura de um cabeçalho |
| Tamanho do cache de thumbnails | **`NSCache` com teto de 32 MB** | O dicionário sem teto do `FileThumbnailService` é parte do problema que esta fase corrige; repeti-lo seria trocar um vazamento por outro |
| Critério de aceite | **Gate por delta de cada passo do roteiro** | Cada número amarra numa causa específica, então uma falha aponta qual correção não pegou. Um alvo absoluto único não distingue isso, e ainda é contaminado por baseline herdado |
| Escopo do `RichTextEditor` | **Checagem, não mudança** | O editor abre o mesmo texto longo e tem o mesmo risco. Confirmar em qual TextKit ele está é barato; mexer nele sem evidência de que está errado, não |

## Ordem de execução

| # | Entrega | Por que nesta posição |
|---|---|---|
| 1 | `memwatch.sh` no repositório | Sem ferramenta versionada não há baseline reproduzível para comparar depois |
| 2 | Preview de texto com `NSTextView` | Maior ganho isolado (~235 MB) e maior risco técnico |
| 3 | Painel solta o conteúdo ao fechar | Pequena, e é o que transforma qualquer resíduo restante em temporário |
| 4 | Dimensões sem decodificar | Base para a entrega 5 e a única com teste de unidade de verdade |
| 5 | Cache de thumbnails com downsample | Maior ganho na navegação (~138 MB); consome a entrega 4 |
| 6 | `cardFrames` fora do `@State` | Depois do cache, porque é ele que torna o re-render barato mesmo se algo escapar |
| 7 | Checagem do `RichTextEditor` | Só faz sentido depois que a entrega 2 estabelecer o que "certo" significa |
| 8 | Medição final e gate | Fecha a fase |

**Fora de escopo, com o lugar marcado:** blobs de imagem presos no
`mainContext` (o `MALLOC` oscila entre 50 e 58 MB — real, mas uma ordem de
grandeza menor que as três frentes acima, e a solução mexeria no ciclo de vida
do `ModelContext`); paginação do `@Query`; e qualquer mudança no `RichTextEditor`
além da checagem da entrega 7.

---

## 1. `memwatch.sh` no repositório

**Arquivos novos:** `scripts/memwatch.sh` e `docs/memory-profiling.md`.

O script já existe e foi usado para produzir as duas rodadas acima. Entra no
repositório como ferramenta de verificação, não como conveniência: o gate desta
fase (entrega 8) depende de rodar exatamente o mesmo roteiro.

Modos:

- `guided` — roteiro cronometrado de dez passos, ~3,5 minutos. Anuncia cada
  passo em texto e por voz, e marca o footprint sozinho ao fim de cada um
- `start` / `mark <rótulo>` / `stop` — modo manual
- `report` — reimprime o relatório da última sessão

**Por que o modo guiado existe:** clicar no terminal para disparar um `mark`
tira o foco do overlay, que se fecha (`windowDidResignKey` → `hide()`). O
roteiro manual era, na prática, impossível de executar sem destruir o estado
sendo medido — a primeira rodada saiu sem marco nenhum por causa disso.

Três armadilhas já resolvidas, que precisam continuar resolvidas:

- a categoria do `footprint` é `ImageIO`, sem espaço. Procurar por `Image IO`
  joga silenciosamente ~90 MB no balde de "outros"
- no zsh, `local` dentro de um subshell (que não é uma função) age como
  `typeset` e **ecoa a variável**, soterrando as mensagens do roteiro
- em locale pt-BR, `%.1f` produz vírgula decimal, que trunca as contas de
  delta no `awk`. O script força `LC_NUMERIC=C`

`docs/memory-profiling.md` traz o roteiro, o que cada par de marcos discrimina,
e a tabela de referência desta spec como linha de base.

## 2. Preview de texto com `NSTextView`

**Arquivo novo:** `Views/Preview/TextPreviewView.swift`.
**Arquivo alterado:** `Views/ItemPreviewView.swift`.

Um `NSViewRepresentable` somente-leitura, seguindo o padrão que
`RichTextEditor.swift` já estabeleceu no projeto:

```swift
let scrollView = NSTextView.scrollableTextView()
textView.isEditable = false
textView.isSelectable = true      // preserva o .textSelection(.enabled) de hoje
textView.drawsBackground = false
textView.font = .systemFont(ofSize: 13)
textView.textContainerInset = NSSize(width: 12, height: 12)
textView.string = text
```

Substitui o `ScrollView { Text(...) }` nos casos `.text` e `.url` de
`ItemPreviewView.content`.

**A regra que faz isso funcionar, e que precisa estar comentada no código:**
desde o macOS 12 o `NSTextView` nasce em TextKit 2, cujo layout é por viewport
— só o que está visível é rasterizado, e é daí que vem a memória constante.
**Acessar `textView.layoutManager` derruba a view para TextKit 1**, que
rasteriza o documento inteiro e reintroduz exatamente o bug que esta entrega
existe para corrigir. Por isso o texto entra por `textView.string`, e nada no
arquivo pode tocar em `layoutManager`.

A forma de confirmar em qual modo a view está: `textView.textLayoutManager`
é não-nulo em TextKit 2 e nulo depois do fallback.

`updateNSView` compara antes de escrever (`guard textView.string != text`),
como o `RichTextEditor` já faz — reescrever a cada update do SwiftUI jogaria
fora a posição de rolagem e a seleção do usuário.

## 3. O painel solta o conteúdo ao fechar

**Arquivo alterado:** `Window/OverlayWindowController.swift`.

`hidePreviewPanel()` passa a, além do `orderOut`, zerar o `contentView` do
painel e limpar `previewDisplayedItemID`.

Os outros dois caminhos que hoje escondem o painel por fora desse método —
`hide()` e `hideImmediately()`, ambos com `previewPanel?.orderOut(nil)` — passam
a chamá-lo, assim como o ramo de `updatePreviewSelection(item:anchor:)` que
fecha o painel quando não sobra nada para mostrar. Uma só forma de fechar.

Limpar o id não é higiene: é o que garante que a reabertura reconstrua o
conteúdo, já que `showPreviewPanel()` decide pular o rebuild comparando
`previewDisplayedItemID != item.id`.

Isto resolve a pendência registrada em `ROADMAP.md:466` — *"`previewDisplayedItemID`
só é seguro porque `previewPanel` nunca é liberado — vale limpar o id em
`hidePreviewPanel()`, antes que algum refactor futuro libere o painel sem
lembrar da suposição"*. A medição mostrou que a suposição já custava MB.

## 4. Dimensões sem decodificar

**Arquivo novo:** `Services/ImageMetadata.swift`.
**Arquivos alterados:** `Views/ClipboardCardView.swift`, `Views/ItemPreviewView.swift`.

```swift
enum ImageMetadata {
    /// Tamanho em pixels lido do cabeçalho do arquivo, sem decodificar.
    static func pixelSize(of data: Data) -> CGSize?
}
```

Via `CGImageSourceCreateWithData` + `CGImageSourceCopyPropertiesAtIndex`, lendo
`kCGImagePropertyPixelWidth` e `kCGImagePropertyPixelHeight`.

Substitui `ClipboardCardView.imageDimensions` (linha 240) e o `NSImage(data:)`
de `ItemPreviewView.footnote` (linha 107) — os dois existem só para escrever
"3024×1964" num rodapé, e hoje pagam uma decodificação completa por isso.

Função pura sobre `Data`, então é a única entrega desta fase com teste de
unidade de verdade: `MyPasteAppTests/ImageMetadataTests.swift`, com um PNG
pequeno gerado no próprio teste, mais o caso de `Data` inválido retornando
`nil`.

## 5. Cache de thumbnails com downsample

**Arquivo novo:** `Services/ImageThumbnailCache.swift`.
**Arquivos alterados:** `Views/ClipboardCardView.swift`,
`Views/Preview/LinkPreviewView.swift`, `Views/ItemPreviewView.swift`,
`Services/FileThumbnailService.swift`.

Espelha o `FileThumbnailService` existente, com as correções que ele também
recebe:

- `NSCache<NSString, NSImage>` com `totalCostLimit` de 32 MB e `cost` igual aos
  bytes do bitmap gerado (`bytesPerRow * height`)
- chave: id do item mais o lado máximo em pixels do destino
- geração por `CGImageSourceCreateThumbnailAtIndex` com
  `kCGImageSourceThumbnailMaxPixelSize` = maior lado do destino × escala da
  tela, `kCGImageSourceCreateThumbnailFromImageAlways` e
  `kCGImageSourceCreateThumbnailWithTransform`. **A imagem é decodificada já no
  tamanho final** — nunca em resolução plena
- o downsample roda fora da main thread e devolve um `CGImage`; o `NSImage` é
  montado no `MainActor`. Passar `CGImage` entre as duas pontas evita trafegar
  `NSImage`, que não é seguro para isso

Consumidores e seus tamanhos: o card (`CardDensity`), o banner de link
(mesma largura do card) e o painel de preview (520×380).

Nas views, o mesmo desenho de `FilePreviewView.swift:30-42`: leitura síncrona
do cache primeiro — para não piscar quando já está quente — e `.task(id:)` para
o caso frio.

`FileThumbnailService` troca seu `[String: NSImage]` sem teto pelo mesmo
`NSCache`. Um dicionário que nunca é purgado, guardando miniaturas de ~2 MB, é
a mesma classe de problema que esta fase corrige.

## 6. `cardFrames` fora do `@State`

**Arquivo alterado:** `Views/OverlayView.swift`.

Os frames dos cards passam a viver numa classe simples — **não** `@Observable`,
**não** `ObservableObject`, e essa é a questão: mutá-la não invalida o `body`.
A instância é mantida em `@State` (que preserva a referência entre updates sem
observar o conteúdo).

`onPreferenceChange` passa a gravar no store e chamar `notifyPreviewSelection()`
como já faz. `notifyPreviewSelection()` e `preview(_:)` leem do store no momento
da chamada, em vez de do dicionário em `@State`.

O efeito: o `onPreferenceChange` continua disparando a cada tick de scroll — é
o SwiftUI quem decide isso — mas deixa de reconstruir o `ForEach` inteiro
junto, que é o que multiplicava as decodificações de imagem por frame.

## 7. Checagem do `RichTextEditor`

**Nenhum arquivo alterado, a menos que a checagem falhe.**

O editor (`⌘E`) abre o mesmo texto longo que o preview, e usa `textStorage` em
`makeNSView`/`updateNSView`. Acessar `textStorage` **não** força o fallback para
TextKit 1 — só `layoutManager` força — mas isso precisa ser confirmado, não
suposto.

A checagem: abrir o editor com o mesmo texto longo usado no passo 8 do roteiro
e comparar o delta de CoreAnimation. Se o editor exibir o mesmo salto que o
preview exibia, ele está em TextKit 1 e a correção é a mesma da entrega 2.

Resultado registrado na seção de descobertas da fase, seja qual for.

## 8. Medição final e gate

Rodar `scripts/memwatch.sh guided` com o mesmo histórico e o mesmo modo de
execução (dentro ou fora do Xcode) da rodada de referência.

**A fase só fecha com os três deltas abaixo dos tetos:**

| passo | antes | teto |
|---|---|---|
| 04 scroll por imagens | +100 MB | **< +40 MB** |
| 08 preview de texto longo | +244 MB | **< +20 MB** |
| 10 ocioso ao final | baseline + 215 MB | **< baseline + 20 MB** |

Mais: suíte verde, e verificação manual da GUI pelo Carlos — o preview de texto
com rolagem e seleção, o preview de imagem, a navegação por setas e o menu de
contexto, que são os caminhos que estas cinco entregas atravessam.

**Se um teto não for atingido**, a entrega correspondente volta à investigação
com os dados da própria medição em mãos — a categoria que não cedeu diz onde
procurar. A fase não fecha com teto estourado e nota de rodapé explicando por
quê; ou o número cai, ou a entrega sai da fase e volta ao roadmap com o
resultado registrado.

**`ROADMAP.md` fechado junto:** linha da Fase 2.5 na tabela "Ordem sugerida",
seção "Fase 2.5 — Memória" com o que a fase descobriu (incluindo o resultado da
checagem da entrega 7 e a tabela antes/depois), e as pendências que ela deixar.
A pendência de `ROADMAP.md:466` é marcada como resolvida pela entrega 3.

## Riscos

**Fallback silencioso para TextKit 1.** É a falha mais provável e a mais
difícil de notar: nada quebra, nada avisa, a memória só volta a subir. Mitigado
pelo comentário no arquivo e por conferir `textLayoutManager != nil`.

**`NSCache` purgando cedo demais.** O sistema pode esvaziar o cache sob pressão
de memória, fazendo thumbnails piscarem durante o scroll. O teto de 32 MB é um
palpite inicial; se piscar, sobe. O caminho frio já tem placeholder, então o
pior caso é cosmético.

**Qualidade visual do thumbnail.** O downsample precisa considerar
`backingScaleFactor`, senão os cards ficam borrados em tela Retina — trocar
memória por imagem feia não é o negócio desta fase.

**A entrega 6 depende de um detalhe de SwiftUI.** Se a classe simples em
`@State` não se comportar como esperado, a alternativa é passar o store por
`init` a partir do `OverlayWindowController`, que já constrói a `OverlayView`
uma única vez em `prepare()`.
