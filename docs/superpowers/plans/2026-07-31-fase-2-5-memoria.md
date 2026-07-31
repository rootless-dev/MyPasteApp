# Fase 2.5 — Memória: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer o app parar de crescer de ~60 MB para ~434 MB conforme é usado,
corrigindo as três causas medidas: o preview de texto rasterizando o documento
inteiro, os cards decodificando imagens em resolução plena a cada frame, e o
painel de preview que nunca solta o que carregou.

**Architecture:** Oito entregas em sequência sobre `develop`. A ferramenta de
medição entra primeiro, porque sem baseline reproduzível não há como afirmar
que a fase atingiu o objetivo. Depois vêm as duas correções estruturais de
maior ganho (preview de texto, liberação do painel), então a base testável
(dimensões sem decodificar) que o cache de thumbnails consome, e por fim as
duas menores. A lógica nova sai das views para tipos puros (`ImageMetadata`,
`ImageThumbnailCache.downsample`), no mesmo padrão que a Fase 1 estabeleceu com
`ClipboardMonitor.shouldCapture` — é o que torna testável um app cuja suíte não
alcança AppKit.

**Tech Stack:** Swift 5, SwiftUI, AppKit, SwiftData, ImageIO, Swift Testing.
Xcode 26.6, SDK macOS 26.5, deployment target 26.2.

**Spec:** `docs/superpowers/specs/2026-07-31-fase-2-5-memoria-design.md`

## Global Constraints

- **Branch:** `feature/fase-2-5-memoria`, criada a partir de `develop`.
- **Commits autorizados nesta branch.** Carlos autorizou em 2026-07-31 que os
  subagentes commitem em `feature/fase-2-5-memoria` sem pedir OK a cada tarefa,
  já que este plano foi revisado e aprovado por ele e cada tarefa traz a
  mensagem pronta. A autorização **não** cobre `develop`, `main`, `git push`
  nem abrir PR — nada disso acontece sem pedido explícito dele.
- **Ao terminar cada tarefa, o board é atualizado** (pedido dele em
  2026-07-31): o card `2.5.N` em `MyPasteApp/itens/` no vault do Obsidian vai
  para `🛠 Implementando` no despacho e para `🔍 Revisão` quando o review sai
  limpo. Quem faz isso é o controlador, não o implementador.
- **Commitar apenas os arquivos da própria tarefa.** Nunca `git add -A` nem
  `git add .`: há documentos não versionados na árvore (`ROADMAP.md`,
  `DESIGN.md`, `design-refs/`).
- Mensagens de commit em **inglês**, seguindo Conventional Commits.
- Comentários e nomes de código em inglês, seguindo o que já existe no
  repositório. Rótulos de interface visíveis ao usuário seguem o idioma já
  usado em cada view.
- `PBXFileSystemSynchronizedRootGroup`: arquivos novos entram no alvo por
  existirem no diretório. Não há `project.pbxproj` para editar.
- **Comando de teste completo:**
  ```bash
  set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
    -project MyPasteApp.xcodeproj -scheme MyPasteApp \
    -configuration Debug -destination 'platform=macOS'
  ```
- **Comando de teste de uma suíte:** acrescente
  `-only-testing:MyPasteAppTests/<NomeDaSuite>`.
- Testes cobrem **lógica pura**. Nada em `Views/` ou `Window/` tem teste
  automatizado — essas entregas terminam com verificação manual, listada no fim
  deste plano.
- **A regra que atravessa a fase inteira:** nunca acessar
  `NSTextView.layoutManager`. Esse acesso derruba a view de TextKit 2 para
  TextKit 1, que rasteriza o documento inteiro — exatamente o bug de 240 MB que
  a Tarefa 2 corrige. Use `textView.string` para conteúdo e
  `textView.textLayoutManager != nil` para confirmar em qual modo a view está.

---

## Estrutura de arquivos

**Criados:**

| Arquivo | Responsabilidade |
|---|---|
| `scripts/memwatch.sh` | Amostra `footprint -p` por categoria; roteiro guiado de 10 passos |
| `docs/memory-profiling.md` | Como rodar o roteiro e o que cada marco discrimina |
| `MyPasteApp/Services/ImageMetadata.swift` | Tamanho em pixels lido do cabeçalho, sem decodificar |
| `MyPasteApp/Services/ImageThumbnailCache.swift` | Downsample via ImageIO + `NSCache` com teto |
| `MyPasteApp/Views/Preview/ThumbnailImage.swift` | A view que consome o cache; um só lugar com o par cache-síncrono/`task` |
| `MyPasteApp/Views/Preview/TextPreviewView.swift` | `NSTextView` somente-leitura em TextKit 2 |
| `MyPasteAppTests/ImageMetadataTests.swift` | Testes de `ImageMetadata` |
| `MyPasteAppTests/ImageThumbnailCacheTests.swift` | Testes de `downsample` e da chave de cache |

**Modificados:**

| Arquivo | Mudança |
|---|---|
| `MyPasteApp/Views/ItemPreviewView.swift` | Texto via `TextPreviewView`; imagem via `ThumbnailImage`; rodapé via `ImageMetadata` |
| `MyPasteApp/Views/ClipboardCardView.swift` | Imagem via `ThumbnailImage`; rodapé via `ImageMetadata`; remove `imageDimensions` |
| `MyPasteApp/Views/Preview/LinkPreviewView.swift` | Banner e favicon via `ThumbnailImage` |
| `MyPasteApp/Window/OverlayWindowController.swift` | `hidePreviewPanel()` solta o conteúdo; um só caminho de fechamento |
| `MyPasteApp/Views/OverlayView.swift` | `cardFrames` sai do `@State` para `CardFrameStore` |
| `MyPasteApp/Services/FileThumbnailService.swift` | Dicionário sem teto vira `NSCache` |

---

## Task 1: Ferramenta de medição no repositório

**Files:**
- Create: `scripts/memwatch.sh`
- Create: `docs/memory-profiling.md`

**Interfaces:**
- Consumes: nada
- Produces: `scripts/memwatch.sh guided` — roteiro de 10 passos usado como gate
  na Tarefa 8; `scripts/memwatch.sh report` — reimprime o último relatório

**Esta tarefa já foi executada e commitada em 2026-07-31**, na mesma sessão que
produziu a spec. O script é o mesmo que gerou as duas rodadas registradas nela,
com `BASE` já apontando para fora do repositório. Os passos abaixo continuam
valendo como conferência antes de usar a ferramenta no gate da Tarefa 8 — se
algum falhar, houve regressão.

- [ ] **Step 1: Conferir que estão lá e que o script roda**

```bash
ls -l scripts/memwatch.sh docs/memory-profiling.md
zsh -n scripts/memwatch.sh && echo "sintaxe ok"
./scripts/memwatch.sh
```

Expected: os dois arquivos existem, `scripts/memwatch.sh` é executável,
`sintaxe ok`, e a mensagem
`uso: ./scripts/memwatch.sh {guided|report|start|mark <rótulo>|stop}` com
saída 1.

- [ ] **Step 2: Conferir que o script não grava dentro do repositório**

```bash
grep -n '^BASE=' scripts/memwatch.sh
```

Expected: `BASE="${MEMWATCH_DATA:-${TMPDIR:-/tmp}/memwatch-data}"`. Se
apontar para `${0:A:h}/memwatch-data`, corrija — cada sessão grava dezenas de
snapshots e um `raw.log` de centenas de KB.

- [ ] **Step 3: Fazer uma rodada de fumaça**

```bash
./scripts/memwatch.sh start && sleep 3 && ./scripts/memwatch.sh mark fumaca && ./scripts/memwatch.sh stop
```

Expected: uma linha de marco com valores plausíveis e a tabela de relatório.
Se `ImageIO` vier `0.0` num app que tem imagens no histórico, o parser
regrediu — a categoria é `ImageIO`, sem espaço.

- [x] **Step 4: Commit** — feito em 2026-07-31

```bash
git add scripts/memwatch.sh docs/memory-profiling.md
git commit -m "chore(tools): add memory profiling script and its playbook"
```

---

## Task 2: Preview de texto com NSTextView

**Files:**
- Create: `MyPasteApp/Views/Preview/TextPreviewView.swift`
- Modify: `MyPasteApp/Views/ItemPreviewView.swift:49-91` (o `content`)

**Interfaces:**
- Consumes: nada
- Produces: `TextPreviewView(text: String)` — uma `View`

Esta é a entrega de maior ganho (~235 MB) e não tem teste automatizado: é
AppKit puro. A verificação é a Tarefa 8.

- [ ] **Step 1: Criar `TextPreviewView`**

```swift
//
//  TextPreviewView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

/// Read-only text, scrollable, for the preview panel.
///
/// Not `ScrollView { Text(...) }`: SwiftUI lays out and rasterizes the *whole*
/// string, not just the visible part. Core Animation can't back a layer that
/// tall, so it splits it into tiles — a long clipboard item measured 240 MB of
/// CoreAnimation across eight of them, for a panel showing 380 points at a
/// time. See docs/superpowers/specs/2026-07-31-fase-2-5-memoria-design.md.
///
/// `NSTextView` has come up in TextKit 2 since macOS 12, which lays out by
/// viewport: only what's on screen is rasterized, so the cost stops depending
/// on the document's length.
///
/// IMPORTANT: never touch `textView.layoutManager` here. Reading that property
/// drops the view back to TextKit 1, which lays out the entire document and
/// reintroduces exactly the bug this file exists to fix. Content goes in
/// through `textView.string`; `textView.textLayoutManager != nil` is how you
/// check which engine is live.
struct TextPreviewView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        textView.isEditable = false
        // Keeps the selection the previous `.textSelection(.enabled)` gave.
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Only rewrite when the model actually diverged: reassigning on every
        // SwiftUI update would throw away the scroll position and whatever the
        // user had selected. Same guard RichTextEditor uses.
        guard textView.string != text else { return }
        textView.string = text
    }
}
```

- [ ] **Step 2: Usar no painel**

Em `ItemPreviewView.content`, o caso `.text, .url` passa de

```swift
case .text, .url:
    ScrollView {
        Text(item.textContent ?? "")
            .font(.system(size: 13))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
    }
```

para

```swift
case .text, .url:
    // The whole thing, scrollable. This is the limitation the item exists to
    // fix: the card truncates at previewTextLength and eight lines, so long
    // text simply isn't readable in the app.
    TextPreviewView(text: item.textContent ?? "")
```

O `.padding(12)` sai: virou `textContainerInset` dentro da view.

- [ ] **Step 3: Compilar**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild build \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Rodar a suíte (nada deve quebrar)**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Expected: PASS. `PauseControllerTests.timedPauseResumesAutomatically()` é flake
conhecido dependente de carga — se falhar sozinho, rode de novo antes de
investigar.

- [ ] **Step 5: Verificação manual dirigida**

Abrir o app, selecionar o item de texto mais longo do histórico, `␣`. Conferir:
o texto inteiro está lá, rola, e dá para selecionar com o mouse. Depois medir:

```bash
./scripts/memwatch.sh start
# abrir o preview do texto longo, esperar 3s
./scripts/memwatch.sh mark preview-texto-longo
./scripts/memwatch.sh stop
```

Expected: `CoreAnim` abaixo de +20 MB em relação à amostra anterior. Era +235.

- [ ] **Step 6: Commit** *(só após autorização)*

```bash
git add MyPasteApp/Views/Preview/TextPreviewView.swift MyPasteApp/Views/ItemPreviewView.swift
git commit -m "perf(preview): lay out long text by viewport instead of rasterizing it whole"
```

---

## Task 3: O painel solta o conteúdo ao fechar

**Files:**
- Modify: `MyPasteApp/Window/OverlayWindowController.swift:242-270` (`hide`, `hideImmediately`), `:313-353` (`hidePreviewPanel`, `updatePreviewSelection`)

**Interfaces:**
- Consumes: nada
- Produces: `hidePreviewPanel()` passa a ser o **único** caminho de fechamento
  do painel; depois desta tarefa, `previewPanel?.orderOut(nil)` não deve
  aparecer em lugar nenhum do arquivo

- [ ] **Step 1: Reescrever `hidePreviewPanel()`**

```swift
    /// Closes just the preview panel, leaving the overlay itself open.
    ///
    /// Used by Escape's "dismiss what's on top" rule (see
    /// `OverlayView.escapeClosesPreview`), by `ItemPreviewView`'s own close
    /// button, and by every other path that hides the panel — this is the only
    /// place that does it.
    ///
    /// Dropping `contentView` is not housekeeping: `orderOut` alone leaves the
    /// `NSHostingView` and every Core Animation layer behind it alive, and a
    /// long text preview measured 240 MB of CoreAnimation that never came back
    /// until the app quit. Clearing `previewDisplayedItemID` is what makes the
    /// next open rebuild the content — `showPreviewPanel()` skips the rebuild
    /// when the id already matches.
    private func hidePreviewPanel() {
        guard let panel = previewPanel else { return }
        panel.orderOut(nil)
        panel.contentView = NSView(
            frame: NSRect(origin: .zero, size: ItemPreviewPanel.defaultSize)
        )
        previewDisplayedItemID = nil
    }
```

- [ ] **Step 2: Passar os outros três caminhos por ele**

Em `hide()`, trocar `previewPanel?.orderOut(nil)` por `hidePreviewPanel()`.
Em `hideImmediately()`, a mesma troca.
Em `updatePreviewSelection(item:anchor:)`, o ramo `guard let item else`:

```swift
        guard let item else {
            // Nothing left to preview (e.g. the last item was deleted, or a
            // search filtered everything out) — closing is the least
            // surprising option, matching what happens when the overlay
            // itself runs out of cards to select.
            hidePreviewPanel()
            return
        }
```

(as duas linhas `panel.orderOut(nil)` e `previewDisplayedItemID = nil` saem;
`hidePreviewPanel()` faz as duas coisas e mais uma.)

- [ ] **Step 3: Confirmar que não sobrou caminho paralelo**

```bash
grep -n "previewPanel?.orderOut\|panel.orderOut" MyPasteApp/Window/OverlayWindowController.swift
```

Expected: uma única ocorrência, a de dentro de `hidePreviewPanel()`.

- [ ] **Step 4: Compilar e rodar a suíte**

Mesmos comandos da Tarefa 2, passos 3 e 4. Expected: BUILD SUCCEEDED e PASS.

- [ ] **Step 5: Verificação manual dirigida**

Abrir o preview de uma imagem (`␣`), fechar com `Esc`, reabrir com `␣`.
Conferir: o painel volta com o conteúdo certo (não vazio, não o item anterior).
Depois: abrir o preview, fechar o overlay inteiro com `Esc`, reabrir e abrir o
preview de **outro** item. Conferir que mostra o item novo.

- [ ] **Step 6: Commit** *(só após autorização)*

```bash
git add MyPasteApp/Window/OverlayWindowController.swift
git commit -m "perf(preview): release the panel's hosted content when it closes"
```

---

## Task 4: Dimensões sem decodificar

**Files:**
- Create: `MyPasteApp/Services/ImageMetadata.swift`
- Create: `MyPasteAppTests/ImageMetadataTests.swift`
- Modify: `MyPasteApp/Views/ClipboardCardView.swift:197-205, 240-243`
- Modify: `MyPasteApp/Views/ItemPreviewView.swift:102-112`

**Interfaces:**
- Consumes: nada
- Produces: `ImageMetadata.pixelSize(of data: Data) -> CGSize?`

- [ ] **Step 1: Escrever o teste que falha**

Crie `MyPasteAppTests/ImageMetadataTests.swift`:

```swift
//
//  ImageMetadataTests.swift
//  MyPasteAppTests
//

import AppKit
import Testing
@testable import MyPasteApp

struct ImageMetadataTests {

    /// A PNG of known dimensions, built in-process so the test carries no
    /// fixture file.
    private func makePNG(width: Int, height: Int) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        )!
        return rep.representation(using: .png, properties: [:])!
    }

    @Test func readsDimensionsFromHeader() {
        let data = makePNG(width: 300, height: 200)
        let size = ImageMetadata.pixelSize(of: data)
        #expect(size == CGSize(width: 300, height: 200))
    }

    @Test func nonSquareDimensionsKeepTheirOrder() {
        let data = makePNG(width: 64, height: 512)
        let size = ImageMetadata.pixelSize(of: data)
        #expect(size?.width == 64)
        #expect(size?.height == 512)
    }

    @Test func garbageDataReturnsNil() {
        let data = Data("not an image".utf8)
        #expect(ImageMetadata.pixelSize(of: data) == nil)
    }

    @Test func emptyDataReturnsNil() {
        #expect(ImageMetadata.pixelSize(of: Data()) == nil)
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/ImageMetadataTests
```

Expected: falha de compilação — `cannot find 'ImageMetadata' in scope`.

- [ ] **Step 3: Implementar**

Crie `MyPasteApp/Services/ImageMetadata.swift`:

```swift
//
//  ImageMetadata.swift
//  MyPasteApp
//

import CoreGraphics
import Foundation
import ImageIO

/// Facts about an image that can be read without decoding it.
///
/// The card and the preview panel both show "3024×1964" in their footer, and
/// both used to build a whole `NSImage` to get those two numbers — decoding
/// every pixel of a screenshot to write a caption. `CGImageSource` reads the
/// header only.
enum ImageMetadata {

    /// The image's size in pixels, read from the file header.
    ///
    /// Returns nil when the data isn't an image ImageIO recognises.
    static func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double
        else { return nil }
        return CGSize(width: width, height: height)
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Mesmo comando do Step 2. Expected: 4 testes PASS.

- [ ] **Step 5: Trocar os dois consumidores**

Em `ClipboardCardView`, o caso `.image` do `footerContent`:

```swift
        case .image:
            if let data = item.imageData, let size = ImageMetadata.pixelSize(of: data) {
```

e **apagar** o método `imageDimensions(_:)` inteiro (linhas 240-243), que era o
único a chamar `NSImage(data:)` ali.

Em `ItemPreviewView.footnote`, o caso `.image`:

```swift
        case .image:
            guard let data = item.imageData,
                  let size = ImageMetadata.pixelSize(of: data) else { return nil }
            return "\(Int(size.width)) × \(Int(size.height))"
```

- [ ] **Step 6: Confirmar que nenhuma decodificação ficou para trás**

```bash
grep -n "NSImage(data:" MyPasteApp/Views/ClipboardCardView.swift MyPasteApp/Views/ItemPreviewView.swift
```

Expected: apenas as ocorrências que **desenham** a imagem (uma em cada
arquivo). As dos rodapés não existem mais. Essas duas restantes saem na
Tarefa 5.

- [ ] **Step 7: Suíte completa e commit** *(commit só após autorização)*

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'

git add MyPasteApp/Services/ImageMetadata.swift MyPasteAppTests/ImageMetadataTests.swift \
        MyPasteApp/Views/ClipboardCardView.swift MyPasteApp/Views/ItemPreviewView.swift
git commit -m "perf(cards): read image dimensions from the header instead of decoding"
```

---

## Task 5: Cache de thumbnails com downsample

**Files:**
- Create: `MyPasteApp/Services/ImageThumbnailCache.swift`
- Create: `MyPasteAppTests/ImageThumbnailCacheTests.swift`
- Create: `MyPasteApp/Views/Preview/ThumbnailImage.swift`
- Modify: `MyPasteApp/Views/ClipboardCardView.swift:149-157`
- Modify: `MyPasteApp/Views/Preview/LinkPreviewView.swift:12-28`
- Modify: `MyPasteApp/Views/ItemPreviewView.swift:63-78`
- Modify: `MyPasteApp/Services/FileThumbnailService.swift:13`

**Interfaces:**
- Consumes: nada
- Produces:
  - `ImageThumbnailCache.shared` (`@MainActor`)
  - `ImageThumbnailCache.downsample(data: Data, maxPixel: Int) -> CGImage?` (`nonisolated static`)
  - `ImageThumbnailCache.key(id: UUID, maxPixel: Int) -> NSString` (`nonisolated static`)
  - `ImageThumbnailCache.pixels(for size: CGSize) -> Int` (`nonisolated static`)
  - `ImageThumbnailCache.pixels(for size: CGSize, scale: CGFloat) -> Int` (`nonisolated static`)
  - `cached(id:maxPixel:) -> NSImage?` e `thumbnail(for:id:maxPixel:) async -> NSImage?`
  - `ThumbnailImage(data:id:maxPixel:contentMode:)` — uma `View`

- [ ] **Step 1: Escrever os testes que falham**

Crie `MyPasteAppTests/ImageThumbnailCacheTests.swift`:

```swift
//
//  ImageThumbnailCacheTests.swift
//  MyPasteAppTests
//

import AppKit
import Testing
@testable import MyPasteApp

struct ImageThumbnailCacheTests {

    private func makePNG(width: Int, height: Int) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        )!
        return rep.representation(using: .png, properties: [:])!
    }

    @Test func downsamplesToTheRequestedLongestSide() {
        let data = makePNG(width: 400, height: 200)
        let thumb = ImageThumbnailCache.downsample(data: data, maxPixel: 100)
        #expect(thumb?.width == 100)
        #expect(thumb?.height == 50)
    }

    /// The point of the whole exercise: a card-sized request must not hand
    /// back a screenshot-sized bitmap.
    @Test func largeImageIsNotDecodedAtFullSize() {
        let data = makePNG(width: 3024, height: 1964)
        let thumb = ImageThumbnailCache.downsample(data: data, maxPixel: 520)
        #expect(thumb?.width == 520)
        #expect((thumb?.height ?? 0) < 400)
    }

    /// ImageIO doesn't upscale, and neither should we — asking for a thumbnail
    /// bigger than the source returns the source's own size.
    @Test func smallImageIsNotUpscaled() {
        let data = makePNG(width: 50, height: 50)
        let thumb = ImageThumbnailCache.downsample(data: data, maxPixel: 200)
        #expect(thumb?.width == 50)
        #expect(thumb?.height == 50)
    }

    @Test func garbageDataReturnsNil() {
        let data = Data("not an image".utf8)
        #expect(ImageThumbnailCache.downsample(data: data, maxPixel: 100) == nil)
    }

    @Test func zeroMaxPixelReturnsNil() {
        let data = makePNG(width: 100, height: 100)
        #expect(ImageThumbnailCache.downsample(data: data, maxPixel: 0) == nil)
    }

    @Test func keyDistinguishesSizesOfTheSameItem() {
        let id = UUID()
        #expect(ImageThumbnailCache.key(id: id, maxPixel: 100)
                != ImageThumbnailCache.key(id: id, maxPixel: 200))
    }

    @Test func keyDistinguishesItemsAtTheSameSize() {
        #expect(ImageThumbnailCache.key(id: UUID(), maxPixel: 100)
                != ImageThumbnailCache.key(id: UUID(), maxPixel: 100))
    }

    /// Points in, pixels out: a 260pt card on a 2x display needs 520px.
    ///
    /// The scale is passed in rather than read from `NSScreen`: a test that
    /// reads the display scale from the same place the implementation does
    /// asserts nothing, and would give a different answer on a non-Retina
    /// machine than in CI.
    @Test func pixelsAccountForTheDisplayScale() {
        #expect(ImageThumbnailCache.pixels(for: CGSize(width: 260, height: 180),
                                           scale: 2) == 520)
        #expect(ImageThumbnailCache.pixels(for: CGSize(width: 260, height: 180),
                                           scale: 1) == 260)
    }

    /// The longest side wins regardless of which one it is.
    @Test func pixelsUseTheLongestSide() {
        #expect(ImageThumbnailCache.pixels(for: CGSize(width: 100, height: 400),
                                           scale: 2) == 800)
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/ImageThumbnailCacheTests
```

Expected: falha de compilação — `cannot find 'ImageThumbnailCache' in scope`.

- [ ] **Step 3: Implementar o cache**

Crie `MyPasteApp/Services/ImageThumbnailCache.swift`:

```swift
//
//  ImageThumbnailCache.swift
//  MyPasteApp
//

import AppKit
import CoreGraphics
import Foundation
import ImageIO

/// Decodes clipboard images already scaled to the size they'll be drawn at,
/// and keeps a bounded cache of the results.
///
/// The card used to build `NSImage(data:)` inside its `body`, which decodes a
/// screenshot at full resolution — ~24 MB for a 3024×1964 image — to fill a
/// 260×180pt card, and did it again on every re-render. Navigating the history
/// measured +138 MB of ImageIO. `CGImageSourceCreateThumbnailAtIndex` decodes
/// straight to the target size instead: the full-resolution bitmap never
/// exists.
@MainActor
final class ImageThumbnailCache {
    static let shared = ImageThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    /// - Parameter totalCostLimit: bytes of decoded bitmap to keep. 32 MB
    ///   holds a screen's worth of cards comfortably; `NSCache` also evicts on
    ///   its own under memory pressure. Injectable for tests.
    init(totalCostLimit: Int = 32 * 1024 * 1024) {
        cache.totalCostLimit = totalCostLimit
    }

    /// The cached thumbnail, if there is one. Synchronous on purpose: views
    /// call this while building their body so a warm entry draws on the first
    /// frame instead of flashing a placeholder.
    func cached(id: UUID, maxPixel: Int) -> NSImage? {
        cache.object(forKey: Self.key(id: id, maxPixel: maxPixel))
    }

    /// The thumbnail, decoding it off the main thread if it isn't cached yet.
    func thumbnail(for data: Data, id: UUID, maxPixel: Int) async -> NSImage? {
        if let hit = cached(id: id, maxPixel: maxPixel) { return hit }

        // Only the CGImage crosses back to the main actor — NSImage is built
        // here, where it will be used.
        let decoded = await Task.detached(priority: .userInitiated) {
            Self.downsample(data: data, maxPixel: maxPixel)
        }.value
        guard let decoded else { return nil }

        let image = NSImage(cgImage: decoded,
                            size: NSSize(width: decoded.width, height: decoded.height))
        cache.setObject(image,
                        forKey: Self.key(id: id, maxPixel: maxPixel),
                        cost: decoded.bytesPerRow * decoded.height)
        return image
    }

    // MARK: - Pure helpers

    /// Decodes `data` with its longest side capped at `maxPixel`.
    ///
    /// ImageIO never upscales: a source smaller than `maxPixel` comes back at
    /// its own size.
    nonisolated static func downsample(data: Data, maxPixel: Int) -> CGImage? {
        guard maxPixel > 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil)
        else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    nonisolated static func key(id: UUID, maxPixel: Int) -> NSString {
        "\(id.uuidString)#\(maxPixel)" as NSString
    }

    /// Longest side of `size`, in points, converted to pixels for this display.
    nonisolated static func pixels(for size: CGSize) -> Int {
        pixels(for: size, scale: NSScreen.main?.backingScaleFactor ?? 2)
    }

    /// The arithmetic on its own, with the display scale as a parameter, so a
    /// test can pin it without depending on the machine it runs on.
    nonisolated static func pixels(for size: CGSize, scale: CGFloat) -> Int {
        Int(max(size.width, size.height) * scale)
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Mesmo comando do Step 2. Expected: 8 testes PASS.

Se `pixelsAccountForTheDisplayScale` falhar num display não-Retina
(`backingScaleFactor == 1`), o teste ainda vale — ele lê a escala do mesmo
lugar que a implementação.

- [ ] **Step 5: Criar `ThumbnailImage`**

Crie `MyPasteApp/Views/Preview/ThumbnailImage.swift`:

```swift
//
//  ThumbnailImage.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

/// An image from a clipboard item, decoded at the size it's drawn at.
///
/// The one place that knows the cache-then-load dance, so the card, the link
/// banner and the preview panel don't each grow their own copy of it.
struct ThumbnailImage: View {
    let data: Data?
    let id: UUID
    /// Longest side, in pixels. Use `ImageThumbnailCache.pixels(for:)`.
    let maxPixel: Int
    var contentMode: ContentMode = .fit

    @State private var loaded: NSImage?

    /// Prefers the cache over `@State` so a warm entry draws on the very first
    /// frame — `.task` wouldn't have run yet, and the placeholder would flash
    /// on every scroll that recycles this view.
    private var image: NSImage? {
        loaded ?? ImageThumbnailCache.shared.cached(id: id, maxPixel: maxPixel)
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color.clear
            }
        }
        .task(id: ImageThumbnailCache.key(id: id, maxPixel: maxPixel)) {
            guard image == nil, let data else { return }
            loaded = await ImageThumbnailCache.shared.thumbnail(
                for: data, id: id, maxPixel: maxPixel
            )
        }
    }
}
```

- [ ] **Step 6: Trocar os três consumidores**

`ClipboardCardView.content`, caso `.image` — o `body` já tem `density` em
escopo (linha 21):

```swift
        case .image:
            if let data = item.imageData {
                ThumbnailImage(
                    data: data,
                    id: item.id,
                    maxPixel: ImageThumbnailCache.pixels(
                        for: CGSize(width: density.width, height: density.height)
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(item.preview).font(.caption)
            }
```

`content` é uma propriedade computada sem acesso a `density`, então passe-a por
parâmetro: troque `private var content: some View` por
`private func content(density: CardDensity) -> some View` e o `content` dentro
de `previewArea` por `content(density: density)` — `previewArea` também vira
`previewArea(density:)`, chamada do `body`, que já tem a densidade.

`LinkPreviewView`, os dois primeiros ramos:

```swift
        if let data = item.linkImageData {
            ThumbnailImage(data: data, id: item.id,
                           maxPixel: ImageThumbnailCache.pixels(
                               for: CGSize(width: 320, height: 240)),
                           contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else if let data = item.linkFaviconData {
            ZStack {
                background
                ThumbnailImage(data: data, id: item.id,
                               maxPixel: ImageThumbnailCache.pixels(
                                   for: CGSize(width: 64, height: 64)))
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
```

**Atenção:** banner e favicon são imagens diferentes do mesmo item, e a chave
do cache é `id + maxPixel`. Os dois `maxPixel` acima são distintos (320pt vs
64pt), então não colidem. Se algum dia coincidirem, a chave precisa de um
discriminador.

`ItemPreviewView.content`, caso `.image`:

```swift
        case .image:
            if let data = item.imageData {
                // Scaled to fit the panel rather than shown at natural size in
                // a ScrollView: a 1920x1080 screenshot filled the panel with
                // its top-left corner and made the reader scroll to see any of
                // it. The point of the preview is seeing the whole thing at
                // once — the dimensions in the header say what was given up.
                ThumbnailImage(
                    data: data,
                    id: item.id,
                    maxPixel: ImageThumbnailCache.pixels(for: ItemPreviewPanel.defaultSize)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CheckerboardBackground())
                .padding(12)
            } else {
                Text(item.preview).font(.caption)
            }
```

- [ ] **Step 7: `FileThumbnailService` ganha teto**

Em `FileThumbnailService`, troque o dicionário por `NSCache`:

```swift
    private let cache = NSCache<NSString, NSImage>()

    init() {
        // Same reason as ImageThumbnailCache: an unbounded dictionary of
        // ~2 MB thumbnails is the very problem this phase corrects.
        cache.totalCostLimit = 16 * 1024 * 1024
    }

    func cached(for path: String, size: CGSize) -> NSImage? {
        cache.object(forKey: key(path: path, size: size) as NSString)
    }
```

Nos dois pontos que gravam (o sucesso e o fallback do `catch`), troque
`cache[cacheKey] = img` por:

```swift
            cache.setObject(img, forKey: cacheKey as NSString,
                            cost: Int(img.size.width * img.size.height * 4))
```

e ajuste a leitura `if let hit = cache[cacheKey]` para
`if let hit = cache.object(forKey: cacheKey as NSString)`.

- [ ] **Step 8: Compilar, suíte, e conferir que sobrou zero `NSImage(data:)`**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'

grep -rn "NSImage(data:" MyPasteApp/Views/
```

Expected: PASS, e o `grep` sem resultado nenhum em `Views/`.

- [ ] **Step 9: Verificação manual dirigida**

Navegar com ← → por todos os cards de imagem, ida e volta duas vezes.
Conferir: as imagens aparecem sem piscar depois da primeira passada, e a
qualidade nos cards está boa (nada borrado). Depois:

```bash
./scripts/memwatch.sh start
# navegar pelos cards de imagem por ~25s
./scripts/memwatch.sh mark scroll-imagem
./scripts/memwatch.sh stop
```

Expected: `ImageIO` abaixo de +40 MB. Era +138.

- [ ] **Step 10: Commit** *(só após autorização)*

```bash
git add MyPasteApp/Services/ImageThumbnailCache.swift \
        MyPasteAppTests/ImageThumbnailCacheTests.swift \
        MyPasteApp/Views/Preview/ThumbnailImage.swift \
        MyPasteApp/Views/ClipboardCardView.swift \
        MyPasteApp/Views/Preview/LinkPreviewView.swift \
        MyPasteApp/Views/ItemPreviewView.swift \
        MyPasteApp/Services/FileThumbnailService.swift
git commit -m "perf(cards): decode images at draw size and cache them with a ceiling"
```

---

## Task 6: `cardFrames` fora do `@State`

**Files:**
- Modify: `MyPasteApp/Views/OverlayView.swift:15-21` (declarações), `:202-211` (os dois handlers), `:353-372` (`preview`, `notifyPreviewSelection`)

**Interfaces:**
- Consumes: nada
- Produces: `CardFrameStore` com `update(_ frames: [UUID: CGRect])` e
  `frame(for id: UUID) -> CGRect?`

- [ ] **Step 1: Criar o store no fim de `OverlayView.swift`**

Junto de `CardFramePreferenceKey`, que já vive lá:

```swift
/// Holds each visible card's on-screen frame.
///
/// Deliberately NOT `@Observable` and NOT an `ObservableObject`: `OverlayView`
/// writes here on every card-frame change, which during a scroll animation is
/// every tick. Publishing those writes would invalidate the body — and with it
/// the entire `ForEach` of cards — on every frame, which is what made image
/// decoding run per frame before this phase. A plain reference type kept in
/// `@State` survives view updates without triggering any.
final class CardFrameStore {
    private var frames: [UUID: CGRect] = [:]

    /// Replaces the whole map: `CardFramePreferenceKey.reduce` already merges
    /// every card's contribution before this is called.
    func update(_ frames: [UUID: CGRect]) {
        self.frames = frames
    }

    func frame(for id: UUID) -> CGRect? {
        frames[id]
    }
}
```

- [ ] **Step 2: Trocar a declaração**

```swift
    /// Each visible card's frame, refreshed continuously by
    /// `CardFramePreferenceKey` as cards appear, scroll, or the window
    /// resizes. Read by `notifyPreviewSelection()` to tell
    /// `OverlayWindowController` where to anchor the preview panel. Lives in a
    /// reference type on purpose — see `CardFrameStore`.
    @State private var cardFrames = CardFrameStore()
```

- [ ] **Step 3: Trocar os três usos**

`onPreferenceChange`:

```swift
                .onPreferenceChange(CardFramePreferenceKey.self) { frames in
                    cardFrames.update(frames)
                    notifyPreviewSelection()
                }
```

`preview(_:)`:

```swift
        onPreviewSelectionChange(item, cardFrames.frame(for: item.id))
```

`notifyPreviewSelection()`:

```swift
        let anchor = selectedID.flatMap { cardFrames.frame(for: $0) }
```

- [ ] **Step 4: Compilar e rodar a suíte**

Mesmos comandos da Tarefa 2, passos 3 e 4. Expected: BUILD SUCCEEDED e PASS.

Se o compilador reclamar de captura não-`Sendable` no closure de
`onPreferenceChange`, **não** transforme o store em `@Observable` — isso
reintroduziria o bug. A alternativa é passar o store por `init` a partir de
`OverlayWindowController.prepare()`, que já constrói a `OverlayView` uma única
vez.

- [ ] **Step 5: Verificação manual dirigida**

Este é o passo que pode quebrar em silêncio: o painel de preview precisa
continuar **seguindo** o card selecionado. Abrir o preview, navegar com ← →
por vários cards e conferir que o painel se reposiciona acima do card certo a
cada mudança, inclusive quando a faixa rola.

- [ ] **Step 6: Commit** *(só após autorização)*

```bash
git add MyPasteApp/Views/OverlayView.swift
git commit -m "perf(overlay): stop invalidating every card when a frame changes"
```

---

## Task 7: Checagem do `RichTextEditor`

**Files:**
- Nenhum, a menos que a checagem falhe.

**Interfaces:**
- Consumes: `scripts/memwatch.sh` (Tarefa 1); o padrão estabelecido pela
  Tarefa 2
- Produces: um resultado registrado, que a Tarefa 8 copia para o `ROADMAP.md`

- [ ] **Step 1: Medir o editor com o mesmo texto longo**

```bash
./scripts/memwatch.sh start
# abrir o overlay, selecionar o texto longo, ⌘E, esperar o editor abrir, 5s
./scripts/memwatch.sh mark editor-texto-longo
# fechar o editor, esperar 5s
./scripts/memwatch.sh mark editor-fechado
./scripts/memwatch.sh stop
```

- [ ] **Step 2: Ler o resultado**

Comparar o `CoreAnim` do marco `editor-texto-longo` com a amostra imediatamente
anterior no relatório.

- Delta abaixo de +20 MB → o editor já está em TextKit 2. **Nada a fazer.**
  Registrar o número.
- Delta na casa das centenas de MB → o editor está em TextKit 1. Registrar o
  número e **parar**: a correção é a mesma da Tarefa 2 (trocar o acesso a
  `textStorage` por `textView.string`, com a ressalva de que ali o texto é
  atribuído e rico, então a troca não é literal), mas isso é escopo novo. Levar
  ao Carlos antes de mexer.

- [ ] **Step 3: Registrar**

Anotar os dois números para a Tarefa 8. Não há commit nesta tarefa.

---

## Task 8: Medição final, gate e fechamento do `ROADMAP.md`

**Files:**
- Modify: `ROADMAP.md` (não versionado — confirme com o Carlos antes de editar)

**Interfaces:**
- Consumes: todas as tarefas anteriores
- Produces: o veredito da fase

- [ ] **Step 1: Rodar o roteiro completo**

```bash
./scripts/memwatch.sh guided
```

Mesmo histórico e mesmo modo de execução (dentro ou fora do Xcode) da rodada de
referência registrada na spec.

- [ ] **Step 2: Conferir os três tetos**

| passo | antes | teto |
|---|---|---|
| 04 scroll por imagens | +100 MB | **< +40 MB** |
| 08 preview de texto longo | +244 MB | **< +20 MB** |
| 10 ocioso ao final | baseline + 215 MB | **< baseline + 20 MB** |

Se algum estourar: a categoria que não cedeu diz qual tarefa revisitar —
`ImageIO` aponta para a Tarefa 5, `CoreAnimation` para a 2 ou a 3, um passo 10
alto para a 3. **Não feche a fase com teto estourado e nota de rodapé.**

- [ ] **Step 3: Rodar a suíte completa uma última vez**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Expected: PASS.

- [ ] **Step 4: Verificação manual completa pelo Carlos**

A suíte não alcança AppKit; nenhuma fase fecha sem isto. Lista no fim deste
plano.

- [ ] **Step 5: Escrever a Fase 2.5 no `ROADMAP.md`**

Três edições:

1. Linha na tabela "Ordem sugerida", entre a Fase 2 e a Fase 3:
   `| ~~2.5 — Memória~~ ✅ | — | Concluída em <data>, branch feature/fase-2-5-memoria. Fase não prevista no plano original — ver a seção abaixo |`
2. Seção `# Fase 2.5 — Memória` depois das pendências da Fase 2, contendo:
   por que a fase existiu (a medição), a tabela antes/depois dos 10 marcos, o
   resultado da checagem da Tarefa 7, e o que ficou de fora (blobs presos no
   `mainContext`, paginação do `@Query`).
3. Na lista de pendências da Fase 2, marcar como resolvida a entrada sobre
   `previewDisplayedItemID` (`ROADMAP.md:466`), apontando para a Tarefa 3.

- [ ] **Step 6: Commit** *(só após autorização)*

```bash
git add ROADMAP.md
git commit -m "docs(roadmap): record phase 2.5 and its measurements"
```

---

## Verificação manual (Carlos)

Nenhuma destas tem teste automatizado. A fase não fecha sem todas.

**Preview de texto (Tarefa 2)**
- [ ] Texto longo abre com `␣` e o conteúdo **inteiro** está lá
- [ ] A rolagem funciona, com o mouse e com as setas
- [ ] Dá para selecionar trechos com o mouse e copiar com ⌘C
- [ ] Um texto curto não fica com rolagem sobrando nem cortado

**Painel (Tarefa 3)**
- [ ] Abrir preview, `Esc`, reabrir: volta com o conteúdo certo
- [ ] Abrir preview de A, `Esc`, abrir preview de B: mostra B, não A
- [ ] Abrir preview, fechar o overlay inteiro, reabrir: nada de painel fantasma
- [ ] Apagar o único item com o preview aberto: o painel fecha junto

**Imagens (Tarefas 4 e 5)**
- [ ] Os cards de imagem mostram a imagem, com boa qualidade em tela Retina
- [ ] O rodapé do card mostra as dimensões corretas
- [ ] O rodapé do painel de preview mostra as mesmas dimensões
- [ ] Preview de imagem grande cabe no painel, com o fundo xadrez atrás
- [ ] Banner e favicon de links continuam aparecendo
- [ ] Card de arquivo continua mostrando a miniatura do QuickLook

**Navegação (Tarefa 6)**
- [ ] Com o preview aberto, ← → reposiciona o painel sobre o card certo
- [ ] Rolar a faixa com o preview aberto mantém o painel acompanhando
- [ ] ⌘1–⌘9, ⌘C, ⌘P, ⌘E, ⌘R, ⌘N e Delete seguem funcionando
- [ ] O menu de contexto do card abre e todas as entradas funcionam

**Geral**
- [ ] Copiar algo novo com o overlay aberto: o card aparece na hora
- [ ] Colar com Enter e com clique continua colando no app certo
