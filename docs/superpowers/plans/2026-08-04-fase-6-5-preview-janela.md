# Fase 6.5 — O preview vira janela: plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIA: use `superpowers:subagent-driven-development`
> (recomendado) ou `superpowers:executing-plans` para executar tarefa a tarefa.
> Os passos usam checkbox (`- [ ]`).

**Objetivo:** o painel de preview aponta para o card que está mostrando, e
arrastá-lo o solta da gaveta como janela própria, que permanece depois de a
gaveta fechar.

**Arquitetura:** a janela do preview vira transparente e passa a ter a forma
desenhada pelo conteúdo (retângulo arredondado + bico), mantendo `.titled` e com
isso o `becomesKeyOnlyIfNeeded` que protege a gaveta. O cálculo de posição sai
do controller como função pura testada (`PreviewPlacement`), a gestão dos
painéis sai para um tipo próprio (`PreviewPanelController`), e o arrasto promove
o painel ancorado a solto — um modo em que ele congela no item, aceita teclado e
sobrevive à gaveta.

**Stack:** Swift 5, SwiftUI + AppKit, SwiftData, Swift Testing. macOS 26.2.

**Spec:** `docs/superpowers/specs/2026-08-04-fase-6-5-preview-janela-design.md`

## Global Constraints

- Deployment target macOS 26.2, Swift 5
- `PBXFileSystemSynchronizedRootGroup`: arquivo novo entra no alvo por existir no
  diretório. **Não há `project.pbxproj` para editar ao criar um arquivo**
- Branch: `feature/fase-6-5-preview-janela`, a partir de `develop`
- A suíte cobre **lógica pura**. Nada em `Views/` ou `Window/` tem teste
  automatizado neste projeto, e este plano não muda isso
- Suíte completa:
  ```bash
  set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
    -project MyPasteApp.xcodeproj -scheme MyPasteApp \
    -configuration Debug -destination 'platform=macOS'
  ```
- Uma suíte só: acrescente `-only-testing:MyPasteAppTests/<NomeDaSuite>`
- Commits: **mensagens em inglês, Conventional Commits**, blocos por
  funcionalidade. **Nunca `git add -A` nem `git add .`** — `ROADMAP.md`,
  `DESIGN.md` e `design-refs/` são documentos locais excluídos via
  `.git/info/exclude`
- **Commit exige autorização explícita do Carlos.** Os passos de commit deste
  plano descrevem o que commitar; execute-os apenas com a branch autorizada
- Board do Obsidian atualizado a cada tarefa concluída — ver "Board", no fim

## Uma nota sobre o formato deste plano

A Fase 6 registrou, com números, que **cinco Importants nasceram do plano e não
da implementação**: código completo escrito no plano foi transcrito fielmente
pelos implementadores, com os erros junto, e nenhum quebrava teste. Este plano
responde a isso deliberadamente:

- **Testes vêm com código completo.** São verificáveis pela suíte, e é onde a
  precisão se paga.
- **Código de `Views/` e `Window/` vem como comportamento exigido, pontos de
  ancoragem exatos e assinaturas** — não como corpo pronto para colar. Onde uma
  API do SDK está em jogo, o passo manda **verificar contra o SDK instalado
  antes de escrever**. A Fase 6 perdeu tempo com `.pointerStyle(.crosshair)` e
  com um overload de `ImageAnalyzer.analyze` que o plano supôs e não existiam.

## Ordem das tarefas — e por que ela difere da spec

A spec lista a extração do `PreviewPanelController` como tarefa 4. Aqui ela vem
antes do bico, e depois de `PreviewPlacement`. O motivo é só de execução, sem
mudança de escopo: `PreviewPlacement` **remove** ~40 linhas do controller, então
extrair depois dela move código já enxuto; e fazer o bico depois da extração
evita escrevê-lo num arquivo para movê-lo em seguida.

1. Spike: a janela transparente com a forma (verificação manual do Carlos)
2. `PreviewPlacement` — função pura com testes
3. Extração do `PreviewPanelController` — sem mudança de comportamento
4. O bico ligado ao painel real
5. Detach: os dois modos
6. Ciclo de vida dos painéis soltos

## Estrutura de arquivos

| Arquivo | Responsabilidade |
|---|---|
| `MyPasteApp/Services/PreviewPlacement.swift` | **Criar.** Geometria pura: onde a janela fica e onde a ponta do bico cai. Sem AppKit |
| `MyPasteAppTests/PreviewPlacementTests.swift` | **Criar.** A bateria da spec |
| `MyPasteApp/Views/PreviewPanelShape.swift` | **Criar.** O `Shape` da janela: retângulo arredondado + triângulo na base |
| `MyPasteApp/Views/PreviewChrome.swift` | **Criar.** `@Observable` que liga o controller à view sem reconstruir a `NSHostingView`: `beakOffset` e `isDetached` |
| `MyPasteApp/Window/PreviewPanelController.swift` | **Criar.** Toda a gestão do preview: painel ancorado, painéis soltos, posicionamento, detach, ciclo de vida |
| `MyPasteApp/Window/ItemPreviewPanel.swift` | **Modificar.** Transparência, tamanho com bico, `isMovableByWindowBackground` |
| `MyPasteApp/Views/ItemPreviewView.swift` | **Modificar.** Desenha a forma e a sombra; faixa de arrasto; oculta o bico quando solto |
| `MyPasteApp/Window/OverlayWindowController.swift` | **Modificar.** Delega ao `PreviewPanelController`; o monitor de clique pergunta `owns(_:)` |
| `VERIFICACAO-FASE-6-5.md` | **Criar.** Roteiro de verificação manual (Tarefa 6) |

---

## Tarefa 1: Spike — a janela transparente com a forma

**Objetivo:** responder uma pergunta que não tem resposta sem rodar: **a máscara
de cantos arredondados que o AppKit aplica a janelas `.titled` corta o
triângulo?** Nada mais desta tarefa precisa ficar bonito.

Se cortar, a fase migra para `.borderless` + subclasse `PreviewPanel` com
`canBecomeKey` decidido por estado, e o resto do plano segue igual — a forma é
desenhada em SwiftUI nos dois caminhos.

**Files:**
- Create: `MyPasteApp/Views/PreviewPanelShape.swift`
- Modify: `MyPasteApp/Window/ItemPreviewPanel.swift`
- Modify: `MyPasteApp/Views/ItemPreviewView.swift:61-79` (o `body` e o `.frame`)

**Interfaces:**
- Produces:
  - `struct PreviewPanelShape: Shape` com
    `init(beakOffset: CGFloat?, beakHeight: CGFloat, cornerRadius: CGFloat)` e
    `func path(in rect: CGRect) -> Path`
  - `ItemPreviewPanel.contentSize: NSSize` (520×380, o que hoje se chama
    `defaultSize`), `ItemPreviewPanel.beakHeight: CGFloat` (12),
    `ItemPreviewPanel.cornerRadius: CGFloat` (12),
    `ItemPreviewPanel.windowSize: NSSize` (520×392)

- [ ] **Passo 1: renomear `defaultSize` para `contentSize` e acrescentar as constantes**

Em `ItemPreviewPanel`, `defaultSize` passa a se chamar `contentSize` e ganha três
vizinhas. O motivo do rename está no que **não** pode mudar: `ItemPreviewView`
passa `ItemPreviewPanel.defaultSize` para
`ImageThumbnailCache.pixels(for:)` (`ItemPreviewView.swift:164`), que dimensiona
o thumbnail decodificado. Somar o bico a esse valor mudaria silenciosamente a
resolução de decodificação de toda imagem do preview. `contentSize` é o que a
área de conteúdo mede; `windowSize` é `contentSize` mais o bico, e é só a janela
que o usa.

```swift
static let contentSize = NSSize(width: 520, height: 380)
static let beakHeight: CGFloat = 12
static let cornerRadius: CGFloat = 12
static var windowSize: NSSize {
    NSSize(width: contentSize.width, height: contentSize.height + beakHeight)
}
```

Atualize todas as referências a `ItemPreviewPanel.defaultSize`. Encontre-as com:

```bash
grep -rn "ItemPreviewPanel.defaultSize" MyPasteApp/
```

Regra para decidir qual usar em cada ocorrência: **`contentSize` em tudo que
mede conteúdo** (o cálculo de thumbnail em `ItemPreviewView`, o `.frame` do
`ItemPreviewView`); **`windowSize` em tudo que mede janela** (`contentRect` do
`NSPanel`, o `frame` da `NSHostingView`, o `NSView` vazio que
`hidePreviewPanel` deixa no lugar do `contentView`).

- [ ] **Passo 2: escrever `PreviewPanelShape`**

Criar `MyPasteApp/Views/PreviewPanelShape.swift`.

Contrato exato:

- `path(in rect:)` recebe o retângulo da **janela inteira**, bico incluído
- O corpo arredondado ocupa `rect` menos `beakHeight` na base
- Quando `beakOffset == nil`, o resultado é só o corpo arredondado, e a faixa de
  `beakHeight` na base fica vazia — quem chama é responsável por encolher a
  janela nesse caso (Tarefa 5); esta forma não decide tamanho de janela
- Quando `beakOffset != nil`, um triângulo isósceles desce da base do corpo até
  `rect.maxY`, com a ponta em `x = beakOffset` e base de `beakWidth` centrada
  nesse x
- `beakWidth` vem de `PreviewPlacement.beakWidth` a partir da Tarefa 2; **neste
  spike**, use uma constante local de 22 e troque na Tarefa 4

Cuidado que decide se a forma fica boa ou remendada: a junção entre o triângulo
e a borda inferior do retângulo arredondado precisa ser um caminho **contínuo**,
não duas figuras sobrepostas. Uma sobreposição aparece como costura quando a
forma é usada em `.fill` com material translúcido, que é exatamente o uso aqui.
Construa um único `Path`: canto inferior esquerdo → base até o início do bico →
sobe/desce o triângulo → base até o canto inferior direito → cantos e lados
restantes.

- [ ] **Passo 3: tornar a janela transparente**

Em `ItemPreviewPanel.make()`, acrescentar:

```swift
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = false
```

`styleMask` **não muda** — é a decisão registrada na spec, e o que preserva o
`becomesKeyOnlyIfNeeded`. O `contentRect` passa a usar `windowSize`.

`hasShadow = false` porque a sombra do sistema segue o retângulo da janela, não a
forma desenhada: mantida, ela desenharia uma sombra retangular ao redor da região
transparente. A sombra passa a ser do conteúdo, no passo seguinte.

- [ ] **Passo 4: o conteúdo desenha a forma**

Em `ItemPreviewView.body`, o `VStack` existente passa a:

- ter altura `ItemPreviewPanel.contentSize.height` e um `Spacer`/padding inferior
  de `beakHeight`, de modo que o conteúdo ocupe só o corpo e a faixa do bico
  fique livre
- receber `.background { PreviewPanelShape(...).fill(.regularMaterial) }`
- receber `.clipShape(PreviewPanelShape(...))`, com os **mesmos** parâmetros do
  background — se os dois divergirem, o conteúdo vaza para fora da forma
- receber a sombra por cima da forma, não do conteúdo:
  `.shadow(radius: 12, y: 4)` aplicado ao mesmo `PreviewPanelShape` no background

**Neste spike, passe `beakOffset` fixo em `ItemPreviewPanel.contentSize.width / 2`.**
Ligar o valor real é a Tarefa 4.

`.regularMaterial` é a escolha inicial porque é o que mais se aproxima do fundo
atual herdado do `.titled`. Se ficar visivelmente diferente do painel de hoje,
anote no relatório da tarefa — a decisão de aparência é do Carlos, na verificação.

- [ ] **Passo 5: compilar**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild build \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Esperado: BUILD SUCCEEDED.

- [ ] **Passo 6: rodar a suíte completa**

Comando completo em "Global Constraints". Esperado: todas as suítes passando.
Nenhum teste desta tarefa é novo — o que se verifica aqui é que o rename de
`defaultSize` não quebrou nada.

- [ ] **Passo 7: parar e pedir a verificação manual do Carlos**

**Esta tarefa não termina sem resposta humana.** Rode o app, abra o preview de um
item (`Espaço` com um card selecionado) e peça ao Carlos que responda:

1. O triângulo aparece **inteiro**, ou a máscara de cantos do `.titled` o corta?
2. O corpo do painel tem os cantos arredondados desenhados pela forma, sem uma
   segunda borda ou sombra retangular por trás?
3. O fundo ficou parecido com o painel de antes, ou visivelmente diferente?

Se a resposta 1 for "cortado", **pare** e relate: a fase precisa da tarefa de
migração para `.borderless` + subclasse `PreviewPanel` com `canBecomeKey`
decidido por estado, antes de seguir para a Tarefa 2.

- [ ] **Passo 8: commit** (com autorização)

```bash
git add MyPasteApp/Views/PreviewPanelShape.swift \
        MyPasteApp/Window/ItemPreviewPanel.swift \
        MyPasteApp/Views/ItemPreviewView.swift
git commit -m "feat(preview): draw the panel's own shape on a transparent window"
```

---

## Tarefa 2: `PreviewPlacement` — geometria pura com testes

**Objetivo:** tirar do controller o cálculo de onde a janela fica, acrescentar o
cálculo do bico, e dar teste ao grampeamento de bordas que existe desde a Fase 2
e nunca teve nenhum.

**Files:**
- Create: `MyPasteApp/Services/PreviewPlacement.swift`
- Create: `MyPasteAppTests/PreviewPlacementTests.swift`
- Modify: `MyPasteApp/Window/OverlayWindowController.swift:540-589`
  (`positionPreviewPanel`)

**Interfaces:**
- Consumes: `ItemPreviewPanel.windowSize`, `.cornerRadius` (Tarefa 1)
- Produces:
  ```swift
  enum PreviewPlacement {
      static let margin: CGFloat
      static let edgeInset: CGFloat
      static let beakWidth: CGFloat
      struct Result: Equatable {
          let frame: CGRect
          let beakOffset: CGFloat?
      }
      static func solve(anchor: CGRect,
                        panelSize: CGSize,
                        visibleFrame: CGRect,
                        cornerRadius: CGFloat,
                        beakWidth: CGFloat) -> Result
  }
  ```

- [ ] **Passo 1: escrever os testes que falham**

Criar `MyPasteAppTests/PreviewPlacementTests.swift`. Os números saem de uma tela
1440×900 com `visibleFrame` de altura 875 (barra de menu descontada) e do painel
de 520×392.

```swift
//
//  PreviewPlacementTests.swift
//  MyPasteAppTests
//

import CoreFoundation
import Testing

@testable import MyPasteApp

@Suite("Preview placement")
struct PreviewPlacementTests {
    // A 1440x900 screen with the menu bar taken off the top, and the panel
    // as ItemPreviewPanel.windowSize measures it.
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)
    private let panel = CGSize(width: 520, height: 392)
    private let corner: CGFloat = 12
    private let beak: CGFloat = 22

    private func solve(anchor: CGRect) -> PreviewPlacement.Result {
        PreviewPlacement.solve(anchor: anchor,
                               panelSize: panel,
                               visibleFrame: screen,
                               cornerRadius: corner,
                               beakWidth: beak)
    }

    @Test("A card in the middle centres the panel and puts the beak dead centre")
    func centredCard() {
        let card = CGRect(x: 700, y: 100, width: 200, height: 220)
        let result = solve(anchor: card)
        #expect(result.frame.minX == 540)
        #expect(result.frame.minY == card.maxY + PreviewPlacement.margin)
        #expect(result.beakOffset == 260)
    }

    @Test("A card at the left edge clamps the panel and slides the beak left")
    func leftEdgeCard() {
        // The panel would start at -150, which is off-screen; it stops at the
        // inset instead, and the beak has to travel to stay over the card.
        let card = CGRect(x: 10, y: 100, width: 200, height: 220)
        let result = solve(anchor: card)
        #expect(result.frame.minX == PreviewPlacement.edgeInset)
        #expect(result.beakOffset == card.midX - PreviewPlacement.edgeInset)
    }

    @Test("A card at the right edge clamps the panel and slides the beak right")
    func rightEdgeCard() {
        let card = CGRect(x: 1230, y: 100, width: 200, height: 220)
        let result = solve(anchor: card)
        let expectedX = screen.maxX - panel.width - PreviewPlacement.edgeInset
        #expect(result.frame.minX == expectedX)
        #expect(result.beakOffset == card.midX - expectedX)
    }

    @Test("A card too far into the corner for the beak to reach loses the beak")
    func cardOutOfBeakReach() {
        // The beak's tip can't sit inside the rounded corner: with the panel
        // clamped at x=8, this card's centre lands at 12, and the nearest
        // legal tip is cornerRadius + beakWidth/2 = 23.
        let card = CGRect(x: 0, y: 100, width: 40, height: 220)
        let result = solve(anchor: card)
        #expect(result.frame.minX == PreviewPlacement.edgeInset)
        #expect(result.beakOffset == nil)
    }

    @Test("A panel that can't fit above the card is pushed down and loses the beak")
    func noRoomAbove() {
        // Phase 2's behaviour, preserved: the panel is clamped to the top of
        // the screen. The beak goes because the panel now overlaps the card —
        // a beak here would point into the panel's own body.
        let card = CGRect(x: 700, y: 600, width: 200, height: 220)
        let result = solve(anchor: card)
        #expect(result.frame.maxY <= screen.maxY - PreviewPlacement.edgeInset)
        #expect(result.frame.minY < card.maxY)
        #expect(result.beakOffset == nil)
    }

    @Test("A screen smaller than the panel still produces a frame inside it")
    func screenSmallerThanPanel() {
        let tiny = CGRect(x: 0, y: 0, width: 400, height: 300)
        let card = CGRect(x: 100, y: 40, width: 200, height: 100)
        let result = PreviewPlacement.solve(anchor: card,
                                            panelSize: panel,
                                            visibleFrame: tiny,
                                            cornerRadius: corner,
                                            beakWidth: beak)
        #expect(result.frame.minX >= tiny.minX)
        #expect(result.frame.minY >= tiny.minY)
    }

    @Test("A beak that exists is always far enough from both rounded corners")
    func beakStaysOffTheCorners() {
        // Swept across the whole strip of card positions the drawer can
        // produce, because the beak's legal range is the invariant that keeps
        // the tip from being drawn inside a corner's curve.
        for midX in stride(from: CGFloat(0), through: 1440, by: 20) {
            let card = CGRect(x: midX - 100, y: 100, width: 200, height: 220)
            let result = solve(anchor: card)
            guard let offset = result.beakOffset else { continue }
            #expect(offset >= corner + beak / 2)
            #expect(offset <= panel.width - corner - beak / 2)
        }
    }

    @Test("The beak, when it exists, sits over the card it points at")
    func beakPointsAtTheCard() {
        for midX in stride(from: CGFloat(0), through: 1440, by: 20) {
            let card = CGRect(x: midX - 100, y: 100, width: 200, height: 220)
            let result = solve(anchor: card)
            guard let offset = result.beakOffset else { continue }
            let tipOnScreen = result.frame.minX + offset
            #expect(tipOnScreen >= card.minX)
            #expect(tipOnScreen <= card.maxX)
        }
    }
}
```

- [ ] **Passo 2: rodar os testes e ver falhar**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/PreviewPlacementTests
```

Esperado: falha de compilação — `cannot find 'PreviewPlacement' in scope`.

- [ ] **Passo 3: escrever `PreviewPlacement`**

Criar `MyPasteApp/Services/PreviewPlacement.swift`. Importa apenas `CoreGraphics`
e `Foundation` — **nada de AppKit**, que é o que torna a suíte capaz de exercitá-lo.

```swift
enum PreviewPlacement {
    /// Gap between the top of the card and the bottom of the panel.
    static let margin: CGFloat = 12
    /// How close the panel is allowed to get to the edge of the screen.
    static let edgeInset: CGFloat = 8
    /// Width of the beak's base.
    static let beakWidth: CGFloat = 22

    struct Result: Equatable {
        let frame: CGRect
        /// The beak's tip, in the panel's own coordinates, or nil when the
        /// panel can't point at the card.
        let beakOffset: CGFloat?
    }

    static func solve(anchor: CGRect,
                      panelSize: CGSize,
                      visibleFrame: CGRect,
                      cornerRadius: CGFloat,
                      beakWidth: CGFloat) -> Result
}
```

A regra de posição é **transcrita do que `positionPreviewPanel` já faz** (linhas
577-587 de `OverlayWindowController`), sem alteração de comportamento: centralizar
em `anchor.midX`, grampear em `[visibleFrame.minX + edgeInset,
visibleFrame.maxX - panelSize.width - edgeInset]`, empilhar acima do card em
`anchor.maxY + margin`, puxar para baixo se estourar o topo, empurrar para cima se
furar a base.

A regra do bico é nova, e são duas condições, ambas necessárias:

1. **O painel tem que estar de fato acima do card.** Se `frame.minY < anchor.maxY`
   — o caso "não coube acima" — o bico é `nil`. Um bico aqui apontaria para
   dentro do próprio corpo do painel.
2. **A ponta tem que caber entre os cantos arredondados.** Com
   `tip = anchor.midX - frame.minX`, o bico existe apenas quando `tip` está em
   `[cornerRadius + beakWidth/2, panelSize.width - cornerRadius - beakWidth/2]`.
   Fora disso, `nil` — é a decisão "desliza pela base, some quando o card sai do
   alcance".

`tip` funciona sem conversão de eixo porque `x` cresce para a direita tanto em
coordenadas de tela quanto nas do painel; é só o eixo vertical que difere entre
AppKit e SwiftUI, e ele não entra nesta conta.

- [ ] **Passo 4: rodar os testes e ver passar**

Mesmo comando do Passo 2. Esperado: 8 testes passando.

- [ ] **Passo 5: ligar o controller à função nova**

Em `OverlayWindowController.positionPreviewPanel(_:)`, o miolo do cálculo
(linhas 574-588) é substituído por uma chamada a `PreviewPlacement.solve`. O que
**fica** no controller, porque depende de `NSView`/`NSWindow` vivos:

- a conversão de `previewAnchorFrame` para coordenadas de tela
  (`contentView.convert(anchor, to: nil)` seguido de `convertToScreen`)
- o caso sem âncora, que centraliza em `screen.frame` — comportamento de hoje,
  preservado
- o `panel.setFrame(...)`

O `beakOffset` devolvido é **descartado nesta tarefa**; a Tarefa 4 é quem o
consome. Não invente um caminho provisório para ele.

- [ ] **Passo 6: rodar a suíte completa**

Esperado: tudo passando, incluindo a suíte nova.

- [ ] **Passo 7: commit** (com autorização)

```bash
git add MyPasteApp/Services/PreviewPlacement.swift \
        MyPasteAppTests/PreviewPlacementTests.swift \
        MyPasteApp/Window/OverlayWindowController.swift
git commit -m "refactor(preview): extract panel placement as a tested pure function"
```

---

## Tarefa 3: extrair o `PreviewPanelController`

**Objetivo:** mover a gestão do preview para um tipo próprio, **sem nenhuma
mudança de comportamento**. A tarefa existe separada justamente para que a
revisão possa aprovar a mudança de forma sem ter que julgar comportamento novo
junto.

**Files:**
- Create: `MyPasteApp/Window/PreviewPanelController.swift`
- Modify: `MyPasteApp/Window/OverlayWindowController.swift`

**Interfaces:**
- Consumes: `PreviewPlacement.solve` (Tarefa 2), `ItemPreviewPanel` (Tarefa 1)
- Produces:
  ```swift
  @MainActor
  final class PreviewPanelController {
      init(writer: ClipboardWriter, itemEditor: ItemEditorWindowController)
      func updateSelection(item: ClipboardItem?, anchor: CGRect?)
      func showAnchored()
      func hideAnchored()
      var isAnchoredOpen: Bool { get }
      func owns(_ window: NSWindow?) -> Bool
      func refreshPrivacy()
      /// The overlay window, needed to convert the card's frame to screen
      /// coordinates. Set by OverlayWindowController.prepare().
      var overlayWindow: NSPanel?
  }
  ```

- [ ] **Passo 1: criar o arquivo com o estado e os métodos movidos**

Movem-se, **sem reescrever a lógica**:

| De `OverlayWindowController` | Linhas |
|---|---|
| `previewPanel`, `previewItem`, `previewAnchorFrame`, `previewDisplayedItemID` | 42-60 |
| `showPreviewPanel()` | 428-443 |
| `hidePreviewPanel()` | 458-465 |
| `updatePreviewSelection(item:anchor:)` | 474-497 |
| `applyPreviewContent(to:item:)` | 508-538 |
| `positionPreviewPanel(_:)` | 556-589 |

Os nomes públicos mudam conforme a interface acima (`showPreviewPanel` →
`showAnchored`, etc.); os comentários de doc **vão junto** — eles carregam o
porquê de decisões que custaram medição (o vazamento de 240 MB que justifica
limpar o `contentView`, o `previewDisplayedItemID` que evita reconstruir a cada
tick de scroll). Perder esses comentários na mudança de casa é perder o motivo.

`applyPreviewContent` precisa de `writer` (para `onCopyColor`) e de `itemEditor`
(para `onEdit`); é por isso que eles entram no `init`. Confira as capturas reais
lendo o corpo do método antes de escrever o `init`.

- [ ] **Passo 2: `owns(_:)`**

```swift
func owns(_ window: NSWindow?) -> Bool
```

Nesta tarefa responde apenas pelo painel ancorado — é a tradução exata do
`event.window !== self.previewPanel` de hoje. A Tarefa 6 é quem a estende para os
soltos. Escrevê-la já agora é o que faz a Tarefa 5 não precisar tocar no monitor.

- [ ] **Passo 3: religar `OverlayWindowController`**

- Um campo `private let previewController: PreviewPanelController`, construído no
  `init` com `writer` e `itemEditor`
- `prepare()` atribui `previewController.overlayWindow = panel` **depois** de
  `window = panel`
- Os quatro closures de `OverlayView` (linhas 135-140) passam a delegar:
  `updateSelection`, `showAnchored`, `hideAnchored`, `isAnchoredOpen`
- `hide()` (linha 293) e `hideImmediately()` (linha 363) chamam `hideAnchored()`
- `applySharingPolicy()` (linha 171) chama `previewController.refreshPrivacy()`
  em vez de tocar em `previewPanel` diretamente
- `installClickOutsideMonitors` (linha 414) passa a
  `if event.window !== self.window && !self.previewController.owns(event.window)`

- [ ] **Passo 4: compilar e rodar a suíte completa**

Esperado: BUILD SUCCEEDED e todas as suítes passando. Nenhum teste novo — é
refatoração, e a rede aqui é a suíte inteira mais o passo seguinte.

- [ ] **Passo 5: verificação manual rápida**

Refatoração de janela não é coberta por teste neste projeto. Rode o app e
confirme os quatro comportamentos que a Fase 2 validou à mão e que esta tarefa
poderia ter quebrado sem aviso:

1. `Espaço` com um card selecionado abre o painel, e a gaveta **continua aberta**
2. As setas continuam navegando com o painel aberto, e o painel acompanha
3. Clicar dentro do painel não fecha nada
4. Clicar fora dos dois fecha os dois; primeiro `Esc` fecha só o painel, segundo
   fecha a gaveta

Se algum falhar, é regressão desta tarefa — corrija antes de seguir.

- [ ] **Passo 6: commit** (com autorização)

```bash
git add MyPasteApp/Window/PreviewPanelController.swift \
        MyPasteApp/Window/OverlayWindowController.swift
git commit -m "refactor(preview): move panel management into PreviewPanelController"
```

---

## Tarefa 4: o bico ligado ao painel real

**Objetivo:** o triângulo aponta para o card que o painel está mostrando, e
acompanha a seleção e as bordas de tela.

O problema a resolver é de fluxo de dados: `beakOffset` muda a cada troca de
seleção e a cada tick de scroll, e `applyPreviewContent` **deliberadamente não
reconstrói** a `NSHostingView` nesses momentos (é o que `previewDisplayedItemID`
protege — reconstruir jogava fora a rolagem e a seleção de texto do painel, e
alocava uma hospedagem por quadro). O valor precisa chegar à view sem reconstruí-la.

**Files:**
- Create: `MyPasteApp/Views/PreviewChrome.swift`
- Modify: `MyPasteApp/Views/ItemPreviewView.swift`
- Modify: `MyPasteApp/Window/PreviewPanelController.swift`
- Modify: `MyPasteApp/Views/PreviewPanelShape.swift` (usar `PreviewPlacement.beakWidth`)

**Interfaces:**
- Consumes: `PreviewPlacement.Result.beakOffset` (Tarefa 2),
  `PreviewPanelShape` (Tarefa 1), `PreviewPanelController` (Tarefa 3)
- Produces:
  ```swift
  @Observable
  @MainActor
  final class PreviewChrome {
      var beakOffset: CGFloat?
      var isDetached: Bool   // usado a partir da Tarefa 5; nasce false
  }
  ```
  e `ItemPreviewView.init(..., chrome: PreviewChrome)`

- [ ] **Passo 1: criar `PreviewChrome`**

Criar `MyPasteApp/Views/PreviewChrome.swift`. Uma instância **por painel** — o
controller a guarda ao lado do `NSPanel`, e a mesma instância é passada para o
`ItemPreviewView` hospedado nele. Painéis soltos (Tarefa 5) terão cada um a sua.

`@Observable` e não `ObservableObject`: é o que o resto do projeto usa em modelos
de estado de view. Confirme lendo `SearchState` ou `PinboardScope` antes de
escrever, e siga o que estiver lá.

- [ ] **Passo 2: `ItemPreviewView` consome o chrome**

- Novo parâmetro `chrome: PreviewChrome`
- `PreviewPanelShape(beakOffset: chrome.beakOffset, ...)` no `.background` e no
  `.clipShape`, substituindo o valor fixo do spike
- `beakWidth` passa a vir de `PreviewPlacement.beakWidth`, e a constante local do
  spike sai

- [ ] **Passo 3: o controller alimenta o chrome**

Em `positionPreviewPanel`, o `beakOffset` que a Tarefa 2 descartava passa a ser
escrito no `PreviewChrome` do painel. `applyPreviewContent` passa a mesma
instância ao construir o `ItemPreviewView`.

**Ponto de atenção**, e é o que decide se esta tarefa fica correta: `beakOffset`
vem de `PreviewPlacement` em coordenadas cuja origem é `frame.minX` — a **borda
esquerda da janela**. `PreviewPanelShape` desenha num `rect` cuja origem também é
a borda esquerda. Os dois coincidem por construção, e **não deve haver nenhuma
conversão entre eles**. Se durante a implementação parecer necessário somar ou
subtrair algo, a causa é outra (um padding externo à forma, tipicamente) e a
correção é lá, não na conta do bico.

- [ ] **Passo 4: compilar e rodar a suíte completa**

Esperado: BUILD SUCCEEDED, tudo passando. `PreviewPlacementTests` continua sendo
a única rede automatizada aqui; o resto é o passo seguinte.

- [ ] **Passo 5: verificação manual**

Rode o app e confirme, anotando o que vir:

1. O bico aponta para o card selecionado
2. Setas para o lado: o painel acompanha e o bico continua sobre o card certo
3. Card na ponta esquerda e na ponta direita: o painel para na margem e o bico
   desliza, permanecendo sobre o card
4. Card tão na ponta que o bico sumiria: ele some, e o painel não fica com um
   triângulo apontando para o vazio nem com uma falha na borda

- [ ] **Passo 6: commit** (com autorização)

```bash
git add MyPasteApp/Views/PreviewChrome.swift \
        MyPasteApp/Views/ItemPreviewView.swift \
        MyPasteApp/Views/PreviewPanelShape.swift \
        MyPasteApp/Window/PreviewPanelController.swift
git commit -m "feat(preview): point the panel's beak at the card it is showing"
```

---

## Tarefa 5: detach — os dois modos

**Objetivo:** arrastar o painel o solta da gaveta. A gaveta fecha, o painel fica
na tela, congelado no item, aceitando teclado.

**Files:**
- Modify: `MyPasteApp/Window/PreviewPanelController.swift`
- Modify: `MyPasteApp/Window/ItemPreviewPanel.swift`
- Modify: `MyPasteApp/Views/ItemPreviewView.swift`

**Interfaces:**
- Consumes: `PreviewChrome.isDetached` (Tarefa 4), `ItemPreviewPanel.windowSize`
  e `.contentSize` (Tarefa 1)
- Produces:
  - `PreviewPanelController.detachAnchored()`
  - `PreviewPanelController.onDetach: (() -> Void)?` — o controller **não** conhece
    a gaveta; quem fecha a gaveta é `OverlayWindowController`, através deste closure

- [ ] **Passo 1: tornar o painel arrastável**

Em `ItemPreviewPanel.make()`: `panel.isMovableByWindowBackground = true`.

- [ ] **Passo 2: a faixa de arrasto**

Uma leitura de `ItemPreviewView` feita antes deste plano mostra que
`isMovableByWindowBackground` sozinho **não** basta para cumprir "header ou fundo
vazio":

- o preview de imagem tem `.contentShape(Rectangle())` e dois
  `.simultaneousGesture` (zoom e pan, da Fase 6) no container inteiro
- o preview de texto hospeda uma `NSTextView` selecionável

Os dois consomem o clique, e sobra o header mais as faixas de 12pt de padding —
área pequena demais para um gesto que o usuário precisa descobrir.

Acrescente uma **faixa de arrasto explícita**: o header inteiro (fora dos botões)
mais uma borda de ~10pt nas laterais e na base do corpo, marcada com
`.contentShape(Rectangle())` e sem gestos concorrentes. **Verifique contra o SDK
instalado** antes de escolher o mecanismo: `WindowDragGesture` existe no SwiftUI
para macOS e é o caminho direto, mas confirme a disponibilidade no
`.swiftinterface` do SDK em uso em vez de assumir — a Fase 6 perdeu duas rodadas
com APIs supostas (`.pointerStyle(.crosshair)`, um overload de
`ImageAnalyzer.analyze`) que não existiam. Se não existir, o fallback é deixar o
AppKit arrastar pela janela e apenas garantir que a faixa não tenha gesto nenhum
por cima.

Registre no relatório da tarefa qual dos dois caminhos foi usado e por quê.

- [ ] **Passo 3: detectar o arrasto**

O controller observa `NSWindow.didMoveNotification` do painel ancorado e compara
o `frame.origin` atual com o que `PreviewPlacement` calculou por último. Passados
**10pt** de distância, chama `detachAnchored()`.

Guarde o último frame calculado num campo próprio; **não** o recalcule a partir da
âncora dentro do observador — o painel ancorado é reposicionado a cada tick de
scroll, e recalcular dentro do observador cria uma corrida entre o
reposicionamento e a medição do arrasto.

Cancele a observação assim que o detach acontecer: o painel solto se move o tempo
todo, de propósito.

- [ ] **Passo 4: `detachAnchored()` — e a ordem, que é a parte fácil de errar**

Exatamente nesta sequência:

1. O painel sai do campo do ancorado e entra na lista de soltos, junto com o seu
   `PreviewChrome` e o item que mostra
2. `chrome.isDetached = true` e `chrome.beakOffset = nil`
3. A janela encolhe de `windowSize` para `contentSize` de altura, **mantendo a
   borda superior no lugar** — encolher pela base é o que faz a faixa do bico sumir
   sem o painel "pular" na tela
4. `panel.becomesKeyOnlyIfNeeded = false`, **e o `styleMask` perde
   `.nonactivatingPanel`** — ver o passo 7, que explica por que sem isso o
   teclado nunca chega
5. `collectionBehavior` perde `.transient`. O painel ancorado o tem porque morre
   com a gaveta; um painel solto com `.transient` desapareceria junto com o resto
   do app em situações que o usuário não pediu. `.canJoinAllSpaces` e
   `.fullScreenAuxiliary` ficam
6. A observação de `didMove` é cancelada
7. `previewDisplayedItemID` é limpo, para que o próximo `showAnchored()` construa
   conteúdo novo em vez de se achar já carregado
8. **Só então** `onDetach?()`, que é o que fecha a gaveta

Invertido — fechar a gaveta antes de o painel sair do campo do ancorado —
`hide()` chama `hideAnchored()` e mata o painel que o usuário acabou de soltar.
Este é o defeito que a ordem existe para impedir; escreva o comentário que diz
isso, ao lado do código.

- [ ] **Passo 5: `ItemPreviewView` reage a `isDetached`**

- Sem bico: já sai de `chrome.beakOffset == nil`
- A altura do conteúdo passa a ocupar a janela inteira (não há mais faixa de bico
  a reservar)
- A faixa de arrasto **continua existindo** — mover uma janela solta é normal

- [ ] **Passo 6: `OverlayWindowController` fecha a gaveta**

No `init` ou no `prepare()`, `previewController.onDetach = { [weak self] in
self?.hide() }`.

- [ ] **Passo 7: teclado no painel solto**

`becomesKeyOnlyIfNeeded = false` **não basta**, e esta é a parte do plano com
maior chance de ser descoberta tarde se ficar implícita.

O app é `LSUIElement` (accessory) e o painel nasce `.nonactivatingPanel`. Essa
flag existe justamente para que um clique no painel **não ative o app** — é o que
protege a gaveta hoje. Mas o teclado vai para o app **ativo**: um painel que
nunca ativa o app pode virar key window e ainda assim não receber tecla nenhuma.

Por isso o passo 4 tira `.nonactivatingPanel` do `styleMask` no detach
(`NSWindow.styleMask` é gravável depois da criação — **confirme isso contra o
SDK instalado antes de escrever**, em vez de confiar nesta frase). Sem tirar, o
comportamento provável é: `⌘C`, `⌘W` e `Esc` funcionam enquanto o app estiver
ativo logo após o detach, e param de funcionar assim que o usuário clica noutro
app e volta — um bug intermitente, do tipo caro de diagnosticar depois.

Verifique explicitamente na verificação manual o **retorno**: clicar noutro app,
voltar, clicar no painel solto e testar `⌘C`. Se o teclado não voltar, o caminho
seguinte a tentar é `NSApp.activate()` no clique do painel solto — mas só depois
de medir, não preventivamente.

O painel ancorado **não muda**: continua `.nonactivatingPanel` e
`becomesKeyOnlyIfNeeded = true`. É o que o passo A1 da Fase 6 validou, e é o que
esta fase não pode quebrar.

Falta ainda responder a `⌘W` e `Esc`.

**Verifique contra o SDK antes de escolher o mecanismo.** O caminho mais provável
é sobrescrever `cancelOperation(_:)` e `performClose(_:)` numa subclasse, ou
tratar em `keyDown`. O que **não** serve é um monitor global de eventos: já há
dois no projeto (`OverlayWindowController.installClickOutsideMonitors`), e um
terceiro competindo por `Esc` é a classe de bug que a Fase 5 documentou com a
gaveta.

`⌘C` sobre uma seleção de texto deve funcionar sem código novo — é a `NSTextView`
respondendo, agora que a janela pode ser key. Confirme na verificação manual em
vez de presumir.

- [ ] **Passo 8: compilar e rodar a suíte completa**

Esperado: BUILD SUCCEEDED, tudo passando.

- [ ] **Passo 9: verificação manual**

1. Arrastar pelo header solta o painel; a gaveta fecha; o painel **fica**
2. Arrastar num preview de **imagem** e num de **texto**: a faixa de arrasto dá
   pega em ambos, e o arrasto não dispara pan de zoom nem seleção de texto
3. Um tremor de poucos pixels **não** solta o painel
4. Solto: o bico sumiu, a janela não ficou com faixa transparente na base, a
   sombra acompanha a forma nova
5. Solto: `⌘C` copia uma seleção de texto; `⌘W` fecha; `Esc` fecha
6. Solto: o painel continua por cima ao usar outro app
7. **O retorno do teclado**, que o passo 7 explica: clicar noutro app, voltar,
   clicar no painel solto e testar `⌘C` de novo. Se falhar aqui e tiver
   funcionado no item 5, o diagnóstico é a ativação do app, não a key window
8. **A gaveta continua sadia depois de tudo isso**: reabrir a gaveta, abrir um
   preview ancorado, ligar o Live Text (o passo A1 da Fase 6) e confirmar que ela
   não fecha por baixo

- [ ] **Passo 10: commit** (com autorização)

```bash
git add MyPasteApp/Window/PreviewPanelController.swift \
        MyPasteApp/Window/ItemPreviewPanel.swift \
        MyPasteApp/Views/ItemPreviewView.swift \
        MyPasteApp/Window/OverlayWindowController.swift
git commit -m "feat(preview): drag the panel off the drawer into its own window"
```

---

## Tarefa 6: ciclo de vida dos painéis soltos

**Objetivo:** os painéis soltos fecham por três caminhos, não sobrevivem ao item
que mostram, não vazam memória e não vazam numa gravação de tela.

**Files:**
- Modify: `MyPasteApp/Window/PreviewPanelController.swift`
- Create: `VERIFICACAO-FASE-6-5.md`

**Interfaces:**
- Consumes: a lista de soltos e `detachAnchored()` (Tarefa 5), `owns(_:)` (Tarefa 3)

- [ ] **Passo 1: `owns(_:)` passa a responder pelos soltos**

Hoje responde só pelo ancorado. Passa a varrer a lista de soltos também: um
clique num painel solto não pode ser lido pelo monitor como clique fora da
gaveta, ou reabrir a gaveta e clicar num painel solto a fecharia.

- [ ] **Passo 2: fechar um painel solto**

Um método único de fechamento, chamado pelos três caminhos (`X` do header, `⌘W`,
`Esc`), que faz, nesta ordem:

1. `panel.orderOut(nil)`
2. `panel.contentView = NSView(frame: ...)` — **não é arrumação.** A Fase 2.5
   mediu 240 MB de CoreAnimation num preview de texto longo que não voltava até o
   app sair, e é isto que `hidePreviewPanel` já faz hoje pelo painel ancorado.
   Com N painéis soltos o custo se multiplica
3. Remover o painel (e o seu `PreviewChrome`) da lista

O `onClose` que `applyPreviewContent` passa ao `ItemPreviewView` precisa levar ao
fechamento **daquele** painel — hoje ele chama `hideAnchored()`, que é o painel
ancorado. Um painel solto cujo `X` fechasse o ancorado é um defeito silencioso e
plausível; resolva capturando a identidade do painel no closure.

- [ ] **Passo 3: o item deixou de existir**

O controller observa o `didSave` do `ModelContext` e, a cada notificação, fecha os
painéis soltos cujo item já não pertence a um contexto (`item.modelContext == nil`).

Um mecanismo só, no controller. **Não** espalhe a responsabilidade pelos seis
caminhos de exclusão que existem hoje — `ItemActions.swift:81`,
`HistorySettingsView.swift:48` e três em `RetentionPolicy.swift` (83, 97, 109) —
porque um sétimo caminho futuro nasceria sem a regra.

**Verifique contra o SDK** o nome exato da notificação de `didSave` do SwiftData
antes de escrever; confirme também qual propriedade responde de forma confiável
"este modelo foi apagado" na versão em uso, em vez de assumir a que este plano
sugere.

- [ ] **Passo 4: privacidade**

`refreshPrivacy()` percorre os soltos além do ancorado. Um painel fora dessa
varredura continuaria visível numa gravação de tela depois de o usuário ligar a
preferência — o oposto exato do que a preferência promete.

- [ ] **Passo 5: compilar e rodar a suíte completa**

Esperado: BUILD SUCCEEDED, tudo passando.

- [ ] **Passo 6: escrever `VERIFICACAO-FASE-6-5.md`**

No formato de `VERIFICACAO-FASE-6.md`: blocos, checkboxes, critério explícito por
passo, marcação de gravidade, e um aviso no topo sobre o que é eliminatório.

Blocos, com os passos das Tarefas 1, 3, 4 e 5 recolhidos:

- **A — Convivência com a gaveta (eliminatório).** Reabrir a gaveta com um painel
  solto na tela: abre um **segundo** painel, ancorado, e o solto fica onde está.
  Clicar entre os dois. `Esc` em cada um. Clicar fora de todos
- **B — O bico.** Posição sobre o card; setas; cards das duas pontas; card fora
  do alcance; painel sem espaço acima
- **C — O detach.** Gesto no header e na faixa, em imagem, texto e arquivo;
  limiar; a gaveta fechando **depois** de o painel ser promovido; o painel
  encolhendo sem pular
- **D — Ciclo de vida.** Fechar pelos três caminhos; apagar o item de um painel
  solto por dois caminhos diferentes (excluir na gaveta e "Clear history");
  **cinco previews de texto longo soltos ao mesmo tempo, com a memória observada
  no Activity Monitor** — é a medição que decide se um teto é necessário, e o
  resultado vai para o ROADMAP
- **E — Privacidade.** Ligar "ocultar em compartilhamento de tela" com um painel
  solto aberto e confirmar que ele some da gravação

- [ ] **Passo 7: atualizar os documentos**

- `DESIGN.md`, mudança derivada 13: de ⚠️ parcial para ✅, dizendo o que o bico
  virou de fato e o que ficou de fora (não aponta de lado nem de baixo)
- `ROADMAP.md`: bloco da Fase 6.5 e item 26, registrando que o A1 passou, o que a
  fase entregou, o que ficou fora e o que a medição de memória disse

Os dois são documentos locais **excluídos do git** via `.git/info/exclude`. Não
entram em nenhum `git add`.

- [ ] **Passo 8: commit** (com autorização)

```bash
git add MyPasteApp/Window/PreviewPanelController.swift \
        VERIFICACAO-FASE-6-5.md
git commit -m "feat(preview): give detached panels a life cycle of their own"
```

---

## Board do Obsidian

Regra do `CLAUDE.md`, obrigatória para o agente principal **e** para qualquer
subagente. A cada tarefa concluída, os dois passos **juntos**:

1. Em `MyPasteApp/Board.md`, mover `[[26 Preview vira janela]]` para a coluna nova
2. Em `MyPasteApp/itens/26 Preview vira janela.md`, atualizar o `status` do
   frontmatter

| Momento | Coluna |
|---|---|
| Tarefa 1 despachada | `🛠 Implementando` |
| Suíte verde e revisão limpa, todas as tarefas prontas | `🔍 Revisão` |
| Branch mergeada | `✅ Concluído` |

Ferramentas: `mcp__mcp-tools-istefox__get_vault_file`, `patch_vault_file`. Se
estiverem deferidas, carregue com `ToolSearch` numa única chamada.

## Fechamento da fase

Nenhuma fase fecha sem o Carlos exercitar a GUI à mão — a suíte verde é condição
necessária, nunca suficiente. Nesta fase mais do que nas outras: quase tudo o que
ela entrega vive em `Views/` e `Window/`, fora do alcance da suíte.

Antes do PR: revisão de branch inteira. Nas seis fases anteriores ela achou o que
a revisão por tarefa aprovou — na Fase 6, 1 Critical e 6 Importants.
