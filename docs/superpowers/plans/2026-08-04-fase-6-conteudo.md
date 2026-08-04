# Fase 6 — Conteúdo: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ferramentas sobre o conteúdo do item — cor (conta-gotas do sistema, reconhecimento em texto, conversão entre formatos), imagem (rotação num editor com Cancel/Save, amostragem de pixel, seleção de texto por Live Text), saída (arrastar qualquer card, abrir arquivo e URL em outro app) e o acabamento do editor de texto.

**Architecture:** Cada peça nova nasce como um tipo puro em `Services/` que não conhece janela: `ColorCode` lê e escreve códigos de cor, `ImagePixel` mapeia ponto-de-view para pixel-do-original, `ImageRotation` transforma bytes em bytes, `DragPayload` decide o que cada tipo de card entrega, `OpenWith` resolve alvo e candidatos, `TextStats` conta, `RichText` ganha as transformações de formatação. As views chamam essas funções e não decidem nada. O que não dá para testar — a lupa do sistema, o arrasto real, o Live Text e o painel — fica confinado a arquivos finos e é coberto pelo roteiro manual.

**Tech Stack:** Swift 5, SwiftUI + AppKit, SwiftData, Swift Testing, VisionKit, ImageIO/CoreGraphics, deployment target macOS 26.2.

**Spec:** `docs/superpowers/specs/2026-08-04-fase-6-conteudo-design.md`

## Global Constraints

- **Branch:** `feature/fase-6-conteudo`, criada a partir de `develop`.
- **Arquivos novos entram no alvo sozinhos.** O projeto usa `PBXFileSystemSynchronizedRootGroup` — não há `project.pbxproj` para editar ao criar um arquivo.
- **Comando de teste completo:**
  ```bash
  set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
    -project MyPasteApp.xcodeproj -scheme MyPasteApp \
    -configuration Debug -destination 'platform=macOS'
  ```
- **Uma suíte só:** acrescente `-only-testing:MyPasteAppTests/<NomeDaSuite>` ao comando acima.
- **Só compilar** (tarefas de `Views/` e `Window/`, que não têm teste):
  ```bash
  set -o pipefail && xcodebuild build \
    -project MyPasteApp.xcodeproj -scheme MyPasteApp \
    -configuration Debug -destination 'platform=macOS'
  ```
- **A suíte cobre lógica pura.** Nada em `Views/` ou `Window/` tem teste automatizado — essas tarefas fecham com compilação limpa e um passo escrito no roteiro manual, nunca com teste.
- **Commits:** mensagens em inglês, Conventional Commits, blocos por funcionalidade. **Nunca commitar sem autorização explícita do Carlos**, exceto quando ele autorizar a branch inteira da fase. Nunca `git add -A` nem `git add .`: `ROADMAP.md`, `DESIGN.md` e `design-refs/` são documentos de trabalho local, excluídos via `.git/info/exclude`.
- **Idioma:** interface e comentários de código em inglês, como todo o resto do app. Este plano e a spec estão em português.
- **Board do Obsidian:** ao começar a implementação, mover os cards dos itens 20, 21 e 22 para `🛠 Implementando` em `MyPasteApp/Board.md` e atualizar `status` nos cards — board e card sempre juntos. **Nesta sessão o servidor MCP `mcp-tools-istefox` não estava conectado**; o vault fica em `~/Documents/Obsidian Vault/MyPasteApp/` e pode ser editado por arquivo. Se nenhum dos dois caminhos funcionar, avisar o Carlos em vez de seguir em silêncio.
- **Toda cor é sRGB.** `NSColor` fora desse espaço dá componentes que não batem com o que o usuário viu; converta com `usingColorSpace(.sRGB)` antes de ler qualquer componente.
- **Todo `onKeyPress` novo em `OverlayView` passa pelo wrapper `gated`.** O compilador não impede o contrário, e um handler solto dispara sobre o campo de renomeação de pinboard — foi assim que `⌫` apagou um card na Fase 5.
- **Flake conhecido, não desta fase:** `PauseControllerTests.timedPauseResumesAutomatically()` depende de carga da máquina. Se falhar, rodar isolado antes de investigar.
- **Bug aberto, não desta fase:** crash no `⌘1` com perda de histórico, sem diagnóstico. Se aparecer durante a implementação, anotar e seguir.

## Estrutura de arquivos

| Arquivo | Responsabilidade | Task |
|---|---|---|
| `MyPasteApp/Services/ColorCode.swift` | **Novo.** Ler, converter e escrever códigos de cor | 1 |
| `MyPasteApp/Services/ClipboardWriter.swift` | Modificado: `writeText(_:silently:)` | 2 |
| `MyPasteApp/Services/ItemActions.swift` | Modificado: `makeCapturedItem` (Task 2), `copyColor` (Task 3), `openWith` (Task 11) | 2, 3, 11 |
| `MyPasteApp/AppDelegate.swift` | Modificado: entrada "Pick Color from Screen" (Task 2), faxina de temporários (Task 10) | 2, 10 |
| `MyPasteApp/Views/Preview/ColorSwatchView.swift` | **Novo.** A amostra de cor no card e no preview | 3 |
| `MyPasteApp/Views/ClipboardCardView.swift` | Modificado: amostra de cor (Task 3), arrasto (Task 10) | 3, 10 |
| `MyPasteApp/Views/ItemContextMenu.swift` | Modificado: "Copy Color as ▸" (Task 3), "Open with ▸" (Task 11) | 3, 11 |
| `MyPasteApp/Services/ImagePixel.swift` | **Novo.** Ponto-na-view → pixel-no-original, e a cor desse pixel | 4 |
| `MyPasteApp/Views/ItemPreviewView.swift` | Modificado: modos, botões, "Editar" | 5, 7, 8 |
| `MyPasteApp/Window/OverlayWindowController.swift` | Modificado: liga os callbacks do preview | 5, 7 |
| `MyPasteApp/Services/ImageRotation.swift` | **Novo.** Girar bytes de imagem em quartos de volta | 6 |
| `MyPasteApp/Services/ImageThumbnailCache.swift` | Modificado: `invalidate(id:)` | 7 |
| `MyPasteApp/Services/ItemActions.swift` (`ImageEdit`) | Modificado: `ImageEdit.apply` | 7 |
| `MyPasteApp/Views/ItemEditorView.swift` | Modificado: corpo de imagem (Task 7), rodapé (Task 12), barra (Task 13) | 7, 12, 13 |
| `MyPasteApp/Views/Preview/LiveTextOverlay.swift` | **Novo.** `ImageAnalysisOverlayView` para SwiftUI | 8 |
| `MyPasteApp/Services/DragPayload.swift` | **Novo.** O que cada tipo de card entrega, e com que nome | 9 |
| `MyPasteApp/Services/TempFileCleanup.swift` | **Novo.** Quais temporários já podem ser apagados | 9 |
| `MyPasteApp/Services/DragItemProvider.swift` | **Novo.** Monta o `NSItemProvider` a partir do `DragPayload` | 10 |
| `MyPasteApp/Services/OpenWith.swift` | **Novo.** Alvo, candidatos e abertura | 11 |
| `MyPasteApp/Views/OverlayView.swift` | Modificado: `⌘O` com gate | 11 |
| `MyPasteApp/Services/TextStats.swift` | **Novo.** Caracteres, palavras e linhas | 12 |
| `MyPasteApp/Services/RichText.swift` | Modificado: `toggling`, `stripped` | 13 |
| `MyPasteApp/Views/RichTextEditor.swift` | Modificado: canal de comandos de formatação | 13 |
| `VERIFICACAO-FASE-6.md` | **Novo.** Roteiro de verificação manual | 14 |

Testes novos: `ColorCodeTests`, `CapturedItemTests`, `ImagePixelTests`, `ImageRotationTests`, `ThumbnailInvalidationTests`, `ImageEditTests`, `DragPayloadTests`, `TempFileCleanupTests`, `OpenWithTests`, `TextStatsTests`, `RichTextFormatTests`.

---

### Task 1: `ColorCode` — ler, converter e escrever cor

**Files:**
- Create: `MyPasteApp/Services/ColorCode.swift`
- Test: `MyPasteAppTests/ColorCodeTests.swift`

**Interfaces:**
- Consumes: nada.
- Produces: `struct ColorCode` com `red`, `green`, `blue`, `alpha` (`Double`, 0...1, sRGB); `static func parse(_ text: String) -> ColorCode?`; `init?(_ color: NSColor)`; `func formatted(as format: ColorFormat) -> String`; `enum ColorFormat: String, CaseIterable { case hex, rgb, hsl }` com `var title: String`.

- [ ] **Step 1: Write the failing test**

Create `MyPasteAppTests/ColorCodeTests.swift`:

```swift
//
//  ColorCodeTests.swift
//  MyPasteAppTests
//

import AppKit
import Testing
@testable import MyPasteApp

@Suite("ColorCode")
struct ColorCodeTests {

    // MARK: - Parsing

    @Test("six-digit hex")
    func sixDigitHex() throws {
        let color = try #require(ColorCode.parse("#3A86FF"))
        #expect(color.byteComponents == (58, 134, 255))
        #expect(color.alpha == 1)
    }

    @Test("three-digit hex expands each digit")
    func threeDigitHex() throws {
        let color = try #require(ColorCode.parse("#abc"))
        #expect(color.byteComponents == (170, 187, 204))
    }

    @Test("eight-digit hex carries alpha")
    func eightDigitHex() throws {
        let color = try #require(ColorCode.parse("#3A86FF80"))
        #expect(color.byteComponents == (58, 134, 255))
        #expect(abs(color.alpha - 128.0 / 255.0) < 0.001)
    }

    @Test("rgb with and without spaces")
    func rgbFunction() throws {
        let spaced = try #require(ColorCode.parse("rgb(58, 134, 255)"))
        let tight = try #require(ColorCode.parse("RGB(58,134,255)"))
        #expect(spaced == tight)
        #expect(spaced.byteComponents == (58, 134, 255))
    }

    @Test("rgba carries alpha")
    func rgbaFunction() throws {
        let color = try #require(ColorCode.parse("rgba(58, 134, 255, 0.5)"))
        #expect(color.alpha == 0.5)
    }

    @Test("hsl round-trips close to the rgb it came from")
    func hslFunction() throws {
        // hsl→rgb is not the exact inverse of rgb→hsl at integer precision:
        // #3A86FF reports as hsl(217, 100%, 61%), and that hsl parses back to
        // (56, 132, 255). Both numbers are pinned here on purpose — a change
        // to the rounding shows up as a failure instead of drifting quietly.
        let color = try #require(ColorCode.parse("hsl(217, 100%, 61%)"))
        #expect(color.byteComponents == (56, 132, 255))
    }

    @Test("leading and trailing whitespace is ignored")
    func trimsWhitespace() {
        #expect(ColorCode.parse("  #3A86FF \n") != nil)
    }

    @Test("text that merely contains a colour is not a colour")
    func rejectsEmbeddedColour() {
        // The whole point of the rule: a stylesheet in the history must not
        // turn into a colour item, or "Copy Color as" has no single answer.
        #expect(ColorCode.parse("body { color: #3A86FF; }") == nil)
        #expect(ColorCode.parse("#3A86FF is the accent") == nil)
    }

    @Test("malformed input is rejected")
    func rejectsGarbage() {
        #expect(ColorCode.parse("") == nil)
        #expect(ColorCode.parse("#12345") == nil)
        #expect(ColorCode.parse("#GGGGGG") == nil)
        #expect(ColorCode.parse("rgb(58, 134)") == nil)
        #expect(ColorCode.parse("rgb(300, 0, 0)") == nil)
        #expect(ColorCode.parse("hsl(217, 100, 61%)") == nil)
    }

    // MARK: - Formatting

    @Test("hex is upper case and drops alpha when opaque")
    func formatsHex() throws {
        let color = try #require(ColorCode.parse("rgb(58, 134, 255)"))
        #expect(color.formatted(as: .hex) == "#3A86FF")
    }

    @Test("hex keeps alpha when translucent")
    func formatsHexWithAlpha() throws {
        let color = try #require(ColorCode.parse("rgba(58, 134, 255, 0.5)"))
        #expect(color.formatted(as: .hex) == "#3A86FF80")
    }

    @Test("rgb and hsl formatting")
    func formatsFunctions() throws {
        let color = try #require(ColorCode.parse("#3A86FF"))
        #expect(color.formatted(as: .rgb) == "rgb(58, 134, 255)")
        #expect(color.formatted(as: .hsl) == "hsl(217, 100%, 61%)")
    }

    @Test("translucent colours use the a-suffixed functions")
    func formatsFunctionsWithAlpha() throws {
        let color = try #require(ColorCode.parse("#3A86FF80"))
        #expect(color.formatted(as: .rgb) == "rgba(58, 134, 255, 0.5)")
        #expect(color.formatted(as: .hsl) == "hsla(217, 100%, 61%, 0.5)")
    }

    @Test("grey has no meaningful hue and reports zero saturation")
    func formatsGrey() throws {
        let color = try #require(ColorCode.parse("#808080"))
        #expect(color.formatted(as: .hsl) == "hsl(0, 0%, 50%)")
    }

    // MARK: - NSColor

    @Test("reads an NSColor through sRGB")
    func fromNSColor() throws {
        let color = try #require(ColorCode(NSColor(srgbRed: 58.0 / 255,
                                                  green: 134.0 / 255,
                                                  blue: 1,
                                                  alpha: 1)))
        #expect(color.formatted(as: .hex) == "#3A86FF")
    }
}

private extension ColorCode {
    /// The three channels as 0...255 integers, for readable expectations.
    var byteComponents: (Int, Int, Int) {
        (Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/ColorCodeTests
```
Expected: FAIL — `cannot find 'ColorCode' in scope`.

- [ ] **Step 3: Write the implementation**

Create `MyPasteApp/Services/ColorCode.swift`:

```swift
//
//  ColorCode.swift
//  MyPasteApp
//

import AppKit
import Foundation

/// The formats a colour can be written back out as.
enum ColorFormat: String, CaseIterable {
    case hex
    case rgb
    case hsl

    var title: String {
        switch self {
        case .hex: return "Hex"
        case .rgb: return "RGB"
        case .hsl: return "HSL"
        }
    }
}

/// A colour the app recognised in an item's text, or sampled from the screen.
///
/// Components are sRGB, 0...1. Nothing is stored on the model: an item is a
/// colour item when — and only when — its whole text parses as one, the same
/// way `typeLabel` is derived rather than persisted.
struct ColorCode: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Reads a colour, converting to sRGB first.
    ///
    /// Returns nil when the conversion isn't possible (pattern colours, for
    /// instance). Reading components off a colour in another space would give
    /// numbers that don't match what the user saw on screen.
    init?(_ color: NSColor) {
        guard let srgb = color.usingColorSpace(.sRGB) else { return nil }
        self.init(red: Double(srgb.redComponent),
                  green: Double(srgb.greenComponent),
                  blue: Double(srgb.blueComponent),
                  alpha: Double(srgb.alphaComponent))
    }

    // MARK: - Parsing

    /// Reads a colour out of text, or returns nil.
    ///
    /// The trimmed string has to be a colour from end to end. Searching for a
    /// colour *inside* the text would turn every stylesheet in the history
    /// into a colour item, and leave "Copy Color as" with no single answer.
    static func parse(_ text: String) -> ColorCode? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("#") { return parseHex(trimmed) }
        return parseFunction(trimmed)
    }

    private static func parseHex(_ text: String) -> ColorCode? {
        let digits = String(text.dropFirst())
        guard digits.allSatisfy({ $0.isHexDigit }) else { return nil }

        func value(_ substring: Substring) -> Double {
            Double(Int(substring, radix: 16) ?? 0) / 255.0
        }

        switch digits.count {
        case 3, 4:
            // #RGB and #RGBA: each digit stands for the pair it repeats.
            let doubled = digits.map { "\($0)\($0)" }.joined()
            return parseHex("#" + doubled)
        case 6, 8:
            let chars = Array(digits)
            let pairs = stride(from: 0, to: chars.count, by: 2).map {
                Substring(String(chars[$0...$0 + 1]))
            }
            return ColorCode(red: value(pairs[0]),
                             green: value(pairs[1]),
                             blue: value(pairs[2]),
                             alpha: pairs.count == 4 ? value(pairs[3]) : 1)
        default:
            return nil
        }
    }

    private static func parseFunction(_ text: String) -> ColorCode? {
        guard let open = text.firstIndex(of: "("), text.hasSuffix(")") else { return nil }
        let name = text[text.startIndex..<open].lowercased()
        let inside = text[text.index(after: open)..<text.index(before: text.endIndex)]
        // Commas and spaces are both accepted as separators: CSS allows both,
        // and a pasted colour arrives in whichever style its source used.
        let parts = inside
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .map(String.init)

        switch name {
        case "rgb", "rgba":
            guard parts.count == (name == "rgb" ? 3 : 4) else { return nil }
            guard let r = channel(parts[0]), let g = channel(parts[1]), let b = channel(parts[2])
            else { return nil }
            let a = parts.count == 4 ? Double(parts[3]) : 1
            guard let alpha = a, (0...1).contains(alpha) else { return nil }
            return ColorCode(red: r, green: g, blue: b, alpha: alpha)
        case "hsl", "hsla":
            guard parts.count == (name == "hsl" ? 3 : 4) else { return nil }
            guard let h = Double(parts[0]),
                  let s = percentage(parts[1]),
                  let l = percentage(parts[2])
            else { return nil }
            let a = parts.count == 4 ? Double(parts[3]) : 1
            guard let alpha = a, (0...1).contains(alpha) else { return nil }
            return ColorCode(hue: h, saturation: s, lightness: l, alpha: alpha)
        default:
            return nil
        }
    }

    /// A 0...255 channel as 0...1, rejecting out-of-range values.
    private static func channel(_ text: String) -> Double? {
        guard let value = Double(text), (0...255).contains(value) else { return nil }
        return value / 255.0
    }

    /// A `50%` string as 0...1. The percent sign is required: `hsl(217, 100, 61%)`
    /// isn't valid CSS, and accepting it would make the parser guess.
    private static func percentage(_ text: String) -> Double? {
        guard text.hasSuffix("%"),
              let value = Double(text.dropLast()),
              (0...100).contains(value)
        else { return nil }
        return value / 100.0
    }

    // MARK: - HSL

    private init(hue: Double, saturation: Double, lightness: Double, alpha: Double) {
        let c = (1 - abs(2 * lightness - 1)) * saturation
        let hp = hue.truncatingRemainder(dividingBy: 360) / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let m = lightness - c / 2

        let (r, g, b): (Double, Double, Double)
        switch hp {
        case ..<1: (r, g, b) = (c, x, 0)
        case ..<2: (r, g, b) = (x, c, 0)
        case ..<3: (r, g, b) = (0, c, x)
        case ..<4: (r, g, b) = (0, x, c)
        case ..<5: (r, g, b) = (x, 0, c)
        default:   (r, g, b) = (c, 0, x)
        }
        self.init(red: r + m, green: g + m, blue: b + m, alpha: alpha)
    }

    private var hsl: (hue: Double, saturation: Double, lightness: Double) {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue
        let lightness = (maxValue + minValue) / 2

        guard delta > 0 else { return (0, 0, lightness) }

        let saturation = delta / (1 - abs(2 * lightness - 1))
        let hue: Double
        switch maxValue {
        case red:   hue = 60 * (((green - blue) / delta).truncatingRemainder(dividingBy: 6))
        case green: hue = 60 * (((blue - red) / delta) + 2)
        default:    hue = 60 * (((red - green) / delta) + 4)
        }
        return (hue < 0 ? hue + 360 : hue, saturation, lightness)
    }

    // MARK: - Formatting

    func formatted(as format: ColorFormat) -> String {
        let opaque = alpha >= 1
        switch format {
        case .hex:
            let base = String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
            return opaque ? base : base + String(format: "%02X", byte(alpha))
        case .rgb:
            let base = "\(byte(red)), \(byte(green)), \(byte(blue))"
            return opaque ? "rgb(\(base))" : "rgba(\(base), \(alphaText))"
        case .hsl:
            let (h, s, l) = hsl
            let base = "\(Int(h.rounded())), \(percent(s))%, \(percent(l))%"
            return opaque ? "hsl(\(base))" : "hsla(\(base), \(alphaText))"
        }
    }

    private func byte(_ value: Double) -> Int { Int((value * 255).rounded()) }
    private func percent(_ value: Double) -> Int { Int((value * 100).rounded()) }

    /// Alpha with at most two decimals and no trailing zeros — `0.5`, not `0.50`.
    private var alphaText: String {
        let rounded = (alpha * 100).rounded() / 100
        return rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%g", rounded)
    }
}
```

- [ ] **Step 4: Run the tests**

Run the `-only-testing:MyPasteAppTests/ColorCodeTests` command from Step 2.
Expected: PASS, 14 tests.

If `formatsHexWithAlpha` fails by one unit (`#3A86FF7F` instead of `#3A86FF80`), the cause is `0.5 * 255 = 127.5` rounding down — `rounded()` uses "away from zero" and gives 128. Don't change the expectation; fix the rounding.

- [ ] **Step 5: Run the full suite**

Run the full test command. Expected: everything green, nothing else touched.

- [ ] **Step 6: Commit**

```bash
git add MyPasteApp/Services/ColorCode.swift MyPasteAppTests/ColorCodeTests.swift
git commit -m "feat(color): read, convert and write colour codes"
```

---

### Task 2: Conta-gotas na barra de status

**Files:**
- Modify: `MyPasteApp/Services/ClipboardWriter.swift`
- Modify: `MyPasteApp/Services/ItemActions.swift`
- Modify: `MyPasteApp/AppDelegate.swift`
- Test: `MyPasteAppTests/CapturedItemTests.swift`

**Interfaces:**
- Consumes: `ColorCode` (Task 1).
- Produces: `ItemActions.makeCapturedItem(text:) -> ClipboardItem`; `ClipboardWriter.writeText(_ text: String, silently: Bool)`.

- [ ] **Step 1: Write the failing test**

Create `MyPasteAppTests/CapturedItemTests.swift`:

```swift
//
//  CapturedItemTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing
@testable import MyPasteApp

@Suite("Captured items")
@MainActor
struct CapturedItemTests {

    @Test("a captured colour is an ordinary text item")
    func capturedColourIsText() {
        let item = ItemActions.makeCapturedItem(text: "#3A86FF")
        #expect(item.type == .text)
        #expect(item.textContent == "#3A86FF")
        #expect(item.preview == "#3A86FF")
    }

    @Test("a captured item is not permanent")
    func capturedItemFollowsGlobalPolicy() {
        // Unlike `makeManualItem`, which is born `keepForever` because someone
        // typed it out by hand. A sampled colour is cheap to sample again, and
        // pinning every sample would silently fill the protected set.
        let item = ItemActions.makeCapturedItem(text: "#3A86FF")
        #expect(item.keepForever == false)
        #expect(item.isPinned == false)
    }

    @Test("a captured item is credited to this app")
    func capturedItemComesFromUs() {
        // This is the whole reason the app creates the item itself instead of
        // letting the monitor pick it up: the monitor credits the frontmost
        // app, and ours is not frontmost when the system sampler closes.
        let item = ItemActions.makeCapturedItem(text: "#3A86FF")
        #expect(item.sourceAppBundleID == Bundle.main.bundleIdentifier)
    }

    @Test("the hash matches what the monitor would compute")
    func capturedItemHashesLikeACopy() {
        // A colour sampled twice must deduplicate against itself, and against
        // the same string arriving through the pasteboard.
        let item = ItemActions.makeCapturedItem(text: "#3A86FF")
        #expect(item.contentHash == ClipboardMonitor.hash("#3A86FF"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run with `-only-testing:MyPasteAppTests/CapturedItemTests`.
Expected: FAIL — `type 'ItemActions' has no member 'makeCapturedItem'`.

- [ ] **Step 3: Add `makeCapturedItem`**

In `MyPasteApp/Services/ItemActions.swift`, inside the `extension ItemActions` that already holds `makeManualItem`, add right above it:

```swift
    /// Builds an item the app itself captured — today, a colour from the
    /// screen sampler.
    ///
    /// Separate from `makeManualItem` on one axis only: this one is **not**
    /// born `keepForever`. Something typed by hand exists nowhere else and
    /// deserves protection; a sampled colour can be sampled again, and
    /// protecting every sample would quietly grow the set the pruner may
    /// never touch.
    ///
    /// The app builds this itself rather than letting `ClipboardMonitor` pick
    /// the write up, because the monitor credits the frontmost application —
    /// and ours isn't frontmost when the system sampler closes. The item
    /// would be stamped with the icon and colour of whatever was underneath.
    static func makeCapturedItem(text: String) -> ClipboardItem {
        ClipboardItem(
            type: .text,
            preview: String(text.prefix(ClipboardMonitor.previewTextLength())),
            contentHash: ClipboardMonitor.hash(text),
            textContent: text,
            sourceAppBundleID: Bundle.main.bundleIdentifier
        )
    }
```

- [ ] **Step 4: Run the tests**

Run with `-only-testing:MyPasteAppTests/CapturedItemTests`. Expected: PASS, 4 tests.

- [ ] **Step 5: Add `writeText` to the writer**

In `MyPasteApp/Services/ClipboardWriter.swift`, after `write(_:plainText:)`:

```swift
    /// Puts a plain string on the pasteboard.
    ///
    /// `silently` suppresses the capture of our own write: pass true when the
    /// string is already in the history (the colour sampler inserts its item
    /// itself) and false when the string is new content the user asked for
    /// (converting a colour to another format), which belongs in the history
    /// like any other copy.
    func writeText(_ text: String, silently: Bool) {
        let pb = NSPasteboard.general
        if silently { monitor?.ignoreNextChange = true }
        pb.clearContents()
        pb.setData(Data(text.utf8), forType: .string)
    }
```

- [ ] **Step 6: Add the menu entry**

In `MyPasteApp/AppDelegate.swift`, in `showStatusMenu()`, right after the `newItem` block and before `prefs`:

```swift
        let pickColor = NSMenuItem(title: "Pick Color from Screen",
                                   action: #selector(pickColorAction),
                                   keyEquivalent: "")
        pickColor.target = self
        menu.addItem(pickColor)
```

And next to `newItemAction`, add:

```swift
    /// Opens the system colour sampler and files the result.
    ///
    /// `NSColorSampler` is the "native color picker": the magnifier runs in
    /// the system's own process, so this needs no screen-recording permission
    /// and no capture code of ours. The handler receives nil when the user
    /// dismisses the loupe with Escape — nothing should happen then.
    @objc private func pickColorAction() {
        NSColorSampler().show { [weak self] picked in
            guard let self, let picked, let color = ColorCode(picked) else { return }
            let text = color.formatted(as: .hex)
            let item = ItemActions.makeCapturedItem(text: text)
            self.modelContainer.mainContext.insert(item)
            try? self.modelContainer.mainContext.save()
            // Silently: the item above is already the history's copy of this
            // colour, and letting the monitor capture the write would file a
            // second one credited to whatever app is frontmost.
            self.writer.writeText(text, silently: true)
        }
    }
```

If `modelContainer` or `writer` are named differently in `AppDelegate`, use the existing names — read the surrounding code rather than adding new stored properties.

- [ ] **Step 7: Build**

Run the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 8: Run the full suite**

Expected: everything green.

- [ ] **Step 9: Commit**

```bash
git add MyPasteApp/Services/ItemActions.swift MyPasteApp/Services/ClipboardWriter.swift \
        MyPasteApp/AppDelegate.swift MyPasteAppTests/CapturedItemTests.swift
git commit -m "feat(color): sample a colour from the screen into the history"
```

---

### Task 3: Amostra de cor no card e no preview, e "Copy Color as"

**Files:**
- Create: `MyPasteApp/Views/Preview/ColorSwatchView.swift`
- Modify: `MyPasteApp/Views/ClipboardCardView.swift`
- Modify: `MyPasteApp/Views/ItemPreviewView.swift`
- Modify: `MyPasteApp/Views/ItemContextMenu.swift`
- Modify: `MyPasteApp/Services/ItemActions.swift`

**Interfaces:**
- Consumes: `ColorCode.parse`, `ColorCode.formatted(as:)`, `ColorFormat` (Task 1); `ClipboardWriter.writeText` (Task 2).
- Produces: `ColorSwatchView(color:code:)`; `ItemActions.copyColor(_ color: ColorCode, as format: ColorFormat)`.

No automated tests: everything here is `Views/`. The logic it leans on is already covered by `ColorCodeTests`.

- [ ] **Step 1: Create the swatch view**

Create `MyPasteApp/Views/Preview/ColorSwatchView.swift`:

```swift
//
//  ColorSwatchView.swift
//  MyPasteApp
//

import SwiftUI

/// A recognised colour, filling the space it's given, with its code on top.
///
/// Used by the card and by the preview panel, so the two can't drift on what
/// "this item is a colour" looks like. The checkerboard shows through a
/// translucent colour, the same way it does behind an image with transparency.
struct ColorSwatchView: View {
    let color: ColorCode
    /// The text to print over the swatch — the item's own code, as written.
    let code: String

    var body: some View {
        ZStack {
            CheckerboardBackground()
            Color(.sRGB,
                  red: color.red,
                  green: color.green,
                  blue: color.blue,
                  opacity: color.alpha)
            Text(code)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(legibleForeground)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(legibleForeground == .white ? .black.opacity(0.25) : .white.opacity(0.55))
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// Black text on light colours, white on dark ones.
    ///
    /// Relative luminance, not plain brightness: pure green reads far lighter
    /// than pure blue at the same numeric value, and averaging the channels
    /// would put white text on a colour nobody can read it against.
    private var legibleForeground: Color {
        let luminance = 0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue
        return luminance > 0.55 ? .black : .white
    }
}
```

- [ ] **Step 2: Show it on the card**

In `MyPasteApp/Views/ClipboardCardView.swift`, in `content(density:)`, replace the `case .text:` branch with:

```swift
        case .text:
            if let code = item.textContent, let color = ColorCode.parse(code) {
                ColorSwatchView(color: color, code: code)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(item.preview)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
```

- [ ] **Step 3: Show it in the preview panel**

In `MyPasteApp/Views/ItemPreviewView.swift`, in `content`, replace the `case .text, .url:` branch with:

```swift
        case .text, .url:
            if let code = item.textContent, let color = ColorCode.parse(code) {
                ColorSwatchView(color: color, code: code)
                    .padding(12)
            } else {
                // The whole thing, scrollable. This is the limitation the item exists to
                // fix: the card truncates at previewTextLength and eight lines, so long
                // text simply isn't readable in the app.
                TextPreviewView(text: item.textContent ?? "")
            }
```

- [ ] **Step 4: Add the copy action**

In `MyPasteApp/Services/ItemActions.swift`, inside the `ItemActions` class (next to `copy`):

```swift
    /// Copies a recognised colour in the format the user picked.
    ///
    /// Not silent, unlike the sampler's own write: the converted string is new
    /// content the user asked for, and belongs in the history like any other
    /// copy. `ClipboardWriter` is still the path, so the write goes through
    /// the same place every other write does.
    func copyColor(_ color: ColorCode, as format: ColorFormat) {
        writer.writeText(color.formatted(as: format), silently: false)
    }
```

- [ ] **Step 5: Add the submenu**

In `MyPasteApp/Views/ItemContextMenu.swift`, right after the `Copy` button:

```swift
        if let code = item.textContent, let color = ColorCode.parse(code) {
            Menu("Copy Color as") {
                ForEach(ColorFormat.allCases, id: \.self) { format in
                    // The format's own rendering is the label: seeing
                    // "rgb(58, 134, 255)" before choosing beats reading "RGB"
                    // and finding out afterwards.
                    Button(color.formatted(as: format)) { actions.copyColor(color, as: format) }
                }
            }
        }
```

- [ ] **Step 6: Build**

Run the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Run the full suite**

Expected: everything green.

- [ ] **Step 8: Commit**

```bash
git add MyPasteApp/Views/Preview/ColorSwatchView.swift MyPasteApp/Views/ClipboardCardView.swift \
        MyPasteApp/Views/ItemPreviewView.swift MyPasteApp/Views/ItemContextMenu.swift \
        MyPasteApp/Services/ItemActions.swift
git commit -m "feat(color): show recognised colours and convert between formats"
```

---

### Task 4: `ImagePixel` — do ponto na view ao pixel no original

**Files:**
- Create: `MyPasteApp/Services/ImagePixel.swift`
- Test: `MyPasteAppTests/ImagePixelTests.swift`

**Interfaces:**
- Consumes: `ColorCode` (Task 1).
- Produces: `ImagePixel.pixel(at:viewSize:imageSize:) -> (x: Int, y: Int)?`; `ImagePixel.color(in data: Data, x: Int, y: Int) -> ColorCode?`.

- [ ] **Step 1: Write the failing test**

Create `MyPasteAppTests/ImagePixelTests.swift`:

```swift
//
//  ImagePixelTests.swift
//  MyPasteAppTests
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import MyPasteApp

@Suite("Image pixel sampling")
struct ImagePixelTests {

    // MARK: - Mapping

    @Test("a click in the centre maps to the centre pixel")
    func centre() throws {
        let pixel = try #require(ImagePixel.pixel(at: CGPoint(x: 100, y: 100),
                                                  viewSize: CGSize(width: 200, height: 200),
                                                  imageSize: CGSize(width: 100, height: 50)))
        #expect(pixel.x == 50)
        #expect(pixel.y == 25)
    }

    @Test("a click in the letterbox maps to nothing")
    func letterbox() {
        // A 100×50 image inside a 200×200 view is drawn at 200×100, leaving
        // 50pt of empty space above and below. A click there is a click on the
        // panel's background, not on a pixel.
        #expect(ImagePixel.pixel(at: CGPoint(x: 100, y: 10),
                                 viewSize: CGSize(width: 200, height: 200),
                                 imageSize: CGSize(width: 100, height: 50)) == nil)
        #expect(ImagePixel.pixel(at: CGPoint(x: 100, y: 190),
                                 viewSize: CGSize(width: 200, height: 200),
                                 imageSize: CGSize(width: 100, height: 50)) == nil)
    }

    @Test("the top-left corner of the drawn image is pixel zero")
    func topLeft() throws {
        let pixel = try #require(ImagePixel.pixel(at: CGPoint(x: 0, y: 50),
                                                  viewSize: CGSize(width: 200, height: 200),
                                                  imageSize: CGSize(width: 100, height: 50)))
        #expect(pixel.x == 0)
        #expect(pixel.y == 0)
    }

    @Test("the last pixel is inside the image, not one past it")
    func bottomRight() throws {
        let pixel = try #require(ImagePixel.pixel(at: CGPoint(x: 199.9, y: 149.9),
                                                  viewSize: CGSize(width: 200, height: 200),
                                                  imageSize: CGSize(width: 100, height: 50)))
        #expect(pixel.x == 99)
        #expect(pixel.y == 49)
    }

    @Test("an image smaller than the view is scaled up, not centred at 1:1")
    func scalesUp() throws {
        let pixel = try #require(ImagePixel.pixel(at: CGPoint(x: 150, y: 150),
                                                  viewSize: CGSize(width: 200, height: 200),
                                                  imageSize: CGSize(width: 10, height: 10)))
        #expect(pixel.x == 7)
        #expect(pixel.y == 7)
    }

    // MARK: - Reading

    @Test("reads the colour of a known pixel, right way up")
    func readsQuadrants() throws {
        // A 2×2 image: red top-left, green top-right, blue bottom-left,
        // white bottom-right. Four different colours in four corners is what
        // makes this catch a flipped or transposed axis — a symmetric test
        // image would pass with the y axis upside down.
        let data = try #require(ImagePixelTests.quadrantPNG())

        #expect(ImagePixel.color(in: data, x: 0, y: 0)?.formatted(as: .hex) == "#FF0000")
        #expect(ImagePixel.color(in: data, x: 1, y: 0)?.formatted(as: .hex) == "#00FF00")
        #expect(ImagePixel.color(in: data, x: 0, y: 1)?.formatted(as: .hex) == "#0000FF")
        #expect(ImagePixel.color(in: data, x: 1, y: 1)?.formatted(as: .hex) == "#FFFFFF")
    }

    @Test("a pixel outside the image reads as nothing")
    func outOfBounds() throws {
        let data = try #require(ImagePixelTests.quadrantPNG())
        #expect(ImagePixel.color(in: data, x: 2, y: 0) == nil)
        #expect(ImagePixel.color(in: data, x: 0, y: -1) == nil)
    }

    @Test("data that isn't an image reads as nothing")
    func notAnImage() {
        #expect(ImagePixel.color(in: Data("not a png".utf8), x: 0, y: 0) == nil)
    }

    // MARK: - Fixture

    /// A 2×2 PNG with one distinct colour per pixel, built without touching
    /// the disk. Shared with `ImageRotationTests`.
    static func quadrantPNG() -> Data? {
        let width = 2, height = 2
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // CGContext's origin is bottom-left, so the "top" row is drawn last.
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))          // bottom-left
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 1, y: 0, width: 1, height: 1))          // bottom-right
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 1, width: 1, height: 1))          // top-left
        context.setFillColor(CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
        context.fill(CGRect(x: 1, y: 1, width: 1, height: 1))          // top-right

        guard let image = context.makeImage() else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run with `-only-testing:MyPasteAppTests/ImagePixelTests`.
Expected: FAIL — `cannot find 'ImagePixel' in scope`.

- [ ] **Step 3: Write the implementation**

Create `MyPasteApp/Services/ImagePixel.swift`:

```swift
//
//  ImagePixel.swift
//  MyPasteApp
//

import CoreGraphics
import Foundation
import ImageIO

/// Reads a single pixel out of a stored image.
///
/// The preview panel draws a *downsampled* thumbnail (see
/// `ImageThumbnailCache`), so sampling what's on screen would return an
/// interpolated value rather than the colour that's actually in the file.
/// Everything here works against the original data; the only thing the view
/// contributes is where the click landed.
enum ImagePixel {

    /// Maps a point in a view to a pixel in the image that view is drawing.
    ///
    /// Assumes aspect-fit — the image scaled to fit and centred, which is what
    /// `ItemPreviewView` does. Returns nil when the point falls in the empty
    /// space beside or above the image: that's a click on the panel, not on a
    /// pixel, and pretending otherwise would copy the colour of the nearest
    /// edge.
    static func pixel(at point: CGPoint,
                      viewSize: CGSize,
                      imageSize: CGSize) -> (x: Int, y: Int)? {
        guard imageSize.width > 0, imageSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else { return nil }

        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let drawnWidth = imageSize.width * scale
        let drawnHeight = imageSize.height * scale
        let originX = (viewSize.width - drawnWidth) / 2
        let originY = (viewSize.height - drawnHeight) / 2

        let x = Int(((point.x - originX) / scale).rounded(.down))
        let y = Int(((point.y - originY) / scale).rounded(.down))

        guard x >= 0, y >= 0,
              x < Int(imageSize.width), y < Int(imageSize.height) else { return nil }
        return (x, y)
    }

    /// The colour of one pixel, in sRGB.
    ///
    /// Draws the image into a 1×1 context positioned so the wanted pixel lands
    /// on it, instead of decoding the whole bitmap and indexing into it: the
    /// image may be a 24 MB screenshot, and this runs on every sample.
    static func color(in data: Data, x: Int, y: Int) -> ColorCode? {
        guard x >= 0, y >= 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              x < image.width, y < image.height
        else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = pixel.withUnsafeMutableBytes({ buffer -> CGContext? in
            CGContext(data: buffer.baseAddress,
                      width: 1,
                      height: 1,
                      bitsPerComponent: 8,
                      bytesPerRow: 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        }) else { return nil }

        // CGContext counts rows from the bottom, the image's y counts from the
        // top: row `y` of the image sits at `height - 1 - y` in context space.
        context.draw(image,
                     in: CGRect(x: -x,
                                y: -(image.height - 1 - y),
                                width: image.width,
                                height: image.height))

        let alpha = Double(pixel[3]) / 255
        guard alpha > 0 else {
            return ColorCode(red: 0, green: 0, blue: 0, alpha: 0)
        }
        // The context is premultiplied; undo it so a translucent pixel reports
        // the colour it was authored as rather than a darkened version of it.
        return ColorCode(red: Double(pixel[0]) / 255 / alpha,
                         green: Double(pixel[1]) / 255 / alpha,
                         blue: Double(pixel[2]) / 255 / alpha,
                         alpha: alpha)
    }
}
```

- [ ] **Step 4: Run the tests**

Run with `-only-testing:MyPasteAppTests/ImagePixelTests`. Expected: PASS, 8 tests.

- [ ] **Step 5: Run the full suite**

Expected: everything green.

- [ ] **Step 6: Commit**

```bash
git add MyPasteApp/Services/ImagePixel.swift MyPasteAppTests/ImagePixelTests.swift
git commit -m "feat(image): read the colour of a pixel from the original data"
```

---

### Task 5: Modo conta-gotas dentro do preview

**Files:**
- Modify: `MyPasteApp/Views/ItemPreviewView.swift`
- Modify: `MyPasteApp/Window/OverlayWindowController.swift`

**Interfaces:**
- Consumes: `ImagePixel` (Task 4), `ColorCode` (Task 1), `ClipboardWriter.writeText` (Task 2).
- Produces: `enum PreviewImageMode { case none, sampler }` in `ItemPreviewView.swift`; `ItemPreviewView(item:onClose:onCopyColor:)` — the third parameter is `(ColorCode) -> Void`.

No automated tests: `Views/` and `Window/`.

- [ ] **Step 1: Add the mode and the sampler button**

In `MyPasteApp/Views/ItemPreviewView.swift`, above `struct ItemPreviewView`:

```swift
/// Which mode the image preview is in.
///
/// One at a time, always: two modes armed over the same image would leave a
/// click on it with two meanings. Task 8 adds `.liveText` to this enum, and
/// the exclusivity comes for free from it being one value rather than two
/// booleans.
enum PreviewImageMode {
    case none
    case sampler
}
```

Then change the view's stored properties and body:

```swift
struct ItemPreviewView: View {
    let item: ClipboardItem
    let onClose: () -> Void
    /// Copies a sampled colour. Owned by `OverlayWindowController`, which is
    /// what holds the `ClipboardWriter` — this view has no business knowing
    /// about pasteboards.
    var onCopyColor: (ColorCode) -> Void = { _ in }

    @State private var mode: PreviewImageMode = .none
    @State private var copiedText: String?
```

In `content`, replace the `case .image:` branch's `ThumbnailImage(...)` block with a version that carries the sampling layer:

```swift
        case .image:
            if let data = item.imageData {
                GeometryReader { geometry in
                    ThumbnailImage(
                        data: data,
                        id: item.id,
                        maxPixel: ImageThumbnailCache.pixels(for: ItemPreviewPanel.defaultSize)
                    ) {
                        Text(item.preview).font(.caption)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(CheckerboardBackground())
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        sample(at: location, in: geometry.size, data: data)
                    }
                }
                .padding(12)
                .overlay(alignment: .bottomTrailing) { modeButtons }
                .overlay(alignment: .top) { copiedBanner }
            } else {
                Text(item.preview).font(.caption)
            }
```

Add, at the bottom of the struct:

```swift
    // MARK: - Sampling

    /// Turns a click into a colour, then turns the mode off.
    ///
    /// One sample per arming, on purpose: a mode that stays on is a mode the
    /// user forgets is on, and every later click silently replaces the
    /// pasteboard.
    private func sample(at location: CGPoint, in viewSize: CGSize, data: Data) {
        guard mode == .sampler else { return }
        guard let size = ImageMetadata.pixelSize(of: data),
              let pixel = ImagePixel.pixel(at: location, viewSize: viewSize, imageSize: size),
              let color = ImagePixel.color(in: data, x: pixel.x, y: pixel.y)
        else { return }

        onCopyColor(color)
        mode = .none
        show(copied: color.formatted(as: .hex))
    }

    private func show(copied text: String) {
        copiedText = text
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            if copiedText == text { copiedText = nil }
        }
    }

    // MARK: - Overlays

    private var modeButtons: some View {
        HStack(spacing: 6) {
            modeButton(systemName: "eyedropper",
                       help: "Sample a colour from this image",
                       isOn: mode == .sampler) {
                mode = mode == .sampler ? .none : .sampler
            }
        }
        .padding(18)
    }

    private func modeButton(systemName: String,
                            help: String,
                            isOn: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? .white : .primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(isOn ? Color.accentColor : Color.black.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private var copiedBanner: some View {
        if let copiedText {
            Text("Copied \(copiedText)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.black.opacity(0.7)))
                .foregroundStyle(.white)
                .padding(.top, 18)
                .transition(.opacity)
        }
    }
```

- [ ] **Step 2: Point the cursor at the mode**

Still in the `case .image:` branch, add to the `ThumbnailImage` modifier chain, right after `.contentShape(Rectangle())`:

```swift
                    .onHover { inside in
                        // The cursor is the only thing on screen saying that
                        // the next click has an effect.
                        if mode == .sampler && inside {
                            NSCursor.crosshair.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
```

- [ ] **Step 3: Wire the callback in the controller**

In `MyPasteApp/Window/OverlayWindowController.swift`, in `applyPreviewContent(to:item:)`:

```swift
        let host = NSHostingView(rootView: ItemPreviewView(
            item: item,
            onClose: { [weak self] in self?.hidePreviewPanel() },
            onCopyColor: { [weak self] color in
                // Not silent: a sampled colour the user asked to copy is new
                // content, and belongs in the history like any other copy.
                self?.writer.writeText(color.formatted(as: .hex), silently: false)
            }
        ))
```

- [ ] **Step 4: Build**

Run the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Write down what has to be checked by hand**

Append to the task's report (the roteiro in Task 14 collects these):

- ligar o conta-gotas, clicar na imagem, confirmar o aviso "Copied #RRGGBB"
- confirmar que o modo se desliga sozinho depois de uma amostra
- confirmar que clicar **sem** o modo ligado não copia nada
- confirmar que clicar na faixa vazia ao lado da imagem não copia nada
- confirmar que a overlay embaixo continua aberta durante tudo isso

- [ ] **Step 6: Run the full suite**

Expected: everything green.

- [ ] **Step 7: Commit**

```bash
git add MyPasteApp/Views/ItemPreviewView.swift MyPasteApp/Window/OverlayWindowController.swift
git commit -m "feat(image): sample a colour from the preview panel"
```

---

### Task 6: `ImageRotation` — girar bytes

**Files:**
- Create: `MyPasteApp/Services/ImageRotation.swift`
- Test: `MyPasteAppTests/ImageRotationTests.swift`

**Interfaces:**
- Consumes: `ImagePixel.color` (Task 4) — for the tests only.
- Produces: `ImageRotation.rotate(_ data: Data, quarterTurns: Int) -> Data?`.

- [ ] **Step 1: Write the failing test**

Create `MyPasteAppTests/ImageRotationTests.swift`:

```swift
//
//  ImageRotationTests.swift
//  MyPasteAppTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MyPasteApp

@Suite("Image rotation")
struct ImageRotationTests {

    @Test("a quarter turn swaps width and height")
    func swapsDimensions() throws {
        let original = try #require(ImagePixelTests.quadrantPNG())
        let wide = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        let size = try #require(ImageMetadata.pixelSize(of: wide))
        // The fixture is square, so this alone proves nothing — see
        // `rectangularImageSwapsDimensions` below, which is the real check.
        #expect(size == CGSize(width: 2, height: 2))
    }

    @Test("a rectangular image comes back transposed")
    func rectangularImageSwapsDimensions() throws {
        let original = try #require(ImageRotationTests.stripePNG(width: 4, height: 2))
        let turned = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        let size = try #require(ImageMetadata.pixelSize(of: turned))
        #expect(size == CGSize(width: 2, height: 4))
    }

    @Test("one turn clockwise moves the top-left pixel to the top-right")
    func turnsClockwise() throws {
        // The direction is the thing that silently inverts. Red starts at
        // top-left; after one clockwise turn it must be at top-right.
        let original = try #require(ImagePixelTests.quadrantPNG())
        let turned = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        #expect(ImagePixel.color(in: turned, x: 1, y: 0)?.formatted(as: .hex) == "#FF0000")
        #expect(ImagePixel.color(in: turned, x: 1, y: 1)?.formatted(as: .hex) == "#00FF00")
        #expect(ImagePixel.color(in: turned, x: 0, y: 0)?.formatted(as: .hex) == "#0000FF")
        #expect(ImagePixel.color(in: turned, x: 0, y: 1)?.formatted(as: .hex) == "#FFFFFF")
    }

    @Test("a negative turn goes the other way")
    func turnsCounterClockwise() throws {
        let original = try #require(ImagePixelTests.quadrantPNG())
        let turned = try #require(ImageRotation.rotate(original, quarterTurns: -1))
        // Red top-left goes to bottom-left when turning left.
        #expect(ImagePixel.color(in: turned, x: 0, y: 1)?.formatted(as: .hex) == "#FF0000")
    }

    @Test("four turns come back to the original, pixel by pixel")
    func fourTurnsAreIdentity() throws {
        let original = try #require(ImagePixelTests.quadrantPNG())
        var data = original
        for _ in 0..<4 {
            data = try #require(ImageRotation.rotate(data, quarterTurns: 1))
        }
        // Compares pixels, not bytes: re-encoding a PNG is allowed to produce
        // different bytes for the same image, so a data equality check here
        // would fail for a reason that doesn't matter.
        for x in 0..<2 {
            for y in 0..<2 {
                #expect(ImagePixel.color(in: data, x: x, y: y)
                        == ImagePixel.color(in: original, x: x, y: y))
            }
        }
    }

    @Test("zero turns returns the data untouched")
    func zeroTurnsIsANoOp() throws {
        let original = try #require(ImagePixelTests.quadrantPNG())
        #expect(ImageRotation.rotate(original, quarterTurns: 0) == original)
    }

    @Test("turn counts wrap around")
    func wrapsTurnCounts() throws {
        let original = try #require(ImagePixelTests.quadrantPNG())
        let five = try #require(ImageRotation.rotate(original, quarterTurns: 5))
        let one = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        for x in 0..<2 {
            for y in 0..<2 {
                #expect(ImagePixel.color(in: five, x: x, y: y)
                        == ImagePixel.color(in: one, x: x, y: y))
            }
        }
    }

    @Test("data that isn't an image rotates to nothing")
    func notAnImage() {
        #expect(ImageRotation.rotate(Data("not a png".utf8), quarterTurns: 1) == nil)
    }

    /// A PNG whose left half is red and right half is blue, for dimension
    /// checks on non-square images.
    static func stripePNG(width: Int, height: Int) -> Data? {
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        guard let image = context.makeImage() else { return nil }
        return ImageRotation.encodePNG(image)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run with `-only-testing:MyPasteAppTests/ImageRotationTests`.
Expected: FAIL — `cannot find 'ImageRotation' in scope`.

- [ ] **Step 3: Write the implementation**

Create `MyPasteApp/Services/ImageRotation.swift`:

```swift
//
//  ImageRotation.swift
//  MyPasteApp
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Turns an image by quarter turns, bytes in and bytes out.
///
/// Always writes PNG, whatever the input was: that's the format
/// `ClipboardMonitor` already stores images in, so a rotated image stays
/// interchangeable with a captured one.
enum ImageRotation {

    /// - Parameter quarterTurns: positive turns clockwise, negative
    ///   anticlockwise. Wraps, so 5 is the same as 1.
    /// - Returns: nil when the data isn't an image ImageIO recognises.
    static func rotate(_ data: Data, quarterTurns: Int) -> Data? {
        let turns = ((quarterTurns % 4) + 4) % 4
        // Zero is not "re-encode with no change": handing back the same bytes
        // keeps the hash, the blob on disk and the cached thumbnail exactly as
        // they were, which is what "the user turned it and turned it back"
        // should mean.
        guard turns != 0 else { return data }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let width = image.width
        let height = image.height
        let swapped = turns % 2 == 1
        let outWidth = swapped ? height : width
        let outHeight = swapped ? width : height

        guard let context = CGContext(data: nil,
                                      width: outWidth,
                                      height: outHeight,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        // Rotate about the centre of the output, then draw the original
        // centred on that same point. CGContext rotates anticlockwise for a
        // positive angle, and its y axis points up — so a clockwise turn on
        // screen is a negative angle here.
        context.translateBy(x: CGFloat(outWidth) / 2, y: CGFloat(outHeight) / 2)
        context.rotate(by: -CGFloat(turns) * .pi / 2)
        context.draw(image, in: CGRect(x: -CGFloat(width) / 2,
                                       y: -CGFloat(height) / 2,
                                       width: CGFloat(width),
                                       height: CGFloat(height)))

        guard let rotated = context.makeImage() else { return nil }
        return encodePNG(rotated)
    }

    /// PNG bytes for a `CGImage`. Internal rather than private: the rotation
    /// tests build their fixtures with it, and a second copy there would be a
    /// second thing to keep in step.
    static func encodePNG(_ image: CGImage) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
```

- [ ] **Step 4: Run the tests**

Run with `-only-testing:MyPasteAppTests/ImageRotationTests`. Expected: PASS, 8 tests.

If `turnsClockwise` fails with red landing at bottom-left instead of top-right, the rotation direction is inverted — flip the sign in `context.rotate(by:)`. Do **not** change the test: the expectation encodes what "clockwise" means to the person clicking the button.

- [ ] **Step 5: Run the full suite**

Expected: everything green.

- [ ] **Step 6: Commit**

```bash
git add MyPasteApp/Services/ImageRotation.swift MyPasteAppTests/ImageRotationTests.swift
git commit -m "feat(image): rotate image data by quarter turns"
```

---

### Task 7: Editor de imagem, invalidação do thumbnail e o botão "Edit"

**Files:**
- Modify: `MyPasteApp/Services/ImageThumbnailCache.swift`
- Modify: `MyPasteApp/Services/ItemActions.swift`
- Modify: `MyPasteApp/Views/ItemEditorView.swift`
- Modify: `MyPasteApp/Views/ItemPreviewView.swift`
- Modify: `MyPasteApp/Window/OverlayWindowController.swift`
- Test: `MyPasteAppTests/ThumbnailInvalidationTests.swift`
- Test: `MyPasteAppTests/ImageEditTests.swift`

**Interfaces:**
- Consumes: `ImageRotation.rotate` (Task 6), `ImageMetadata.pixelSize`.
- Produces: `ImageThumbnailCache.invalidate(id:)`; `ImageEdit.apply(to:imageData:)`; `ItemPreviewView(item:onClose:onCopyColor:onEdit:)`.

- [ ] **Step 1: Write the failing cache test**

Create `MyPasteAppTests/ThumbnailInvalidationTests.swift`:

```swift
//
//  ThumbnailInvalidationTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing
@testable import MyPasteApp

@Suite("Thumbnail invalidation")
@MainActor
struct ThumbnailInvalidationTests {

    @Test("an invalidated id has no cached thumbnail at any size")
    func invalidateDropsEverySize() async throws {
        // The cache is keyed by (id, maxPixel), and the card and the preview
        // panel ask for different sizes. Dropping only the size you happen to
        // know about leaves the other one drawing the image before the edit.
        let cache = ImageThumbnailCache()
        let data = try #require(ImagePixelTests.quadrantPNG())
        let id = UUID()

        _ = await cache.thumbnail(for: data, id: id, maxPixel: 64)
        _ = await cache.thumbnail(for: data, id: id, maxPixel: 256)
        #expect(cache.cached(id: id, maxPixel: 64) != nil)
        #expect(cache.cached(id: id, maxPixel: 256) != nil)

        cache.invalidate(id: id)

        #expect(cache.cached(id: id, maxPixel: 64) == nil)
        #expect(cache.cached(id: id, maxPixel: 256) == nil)
    }

    @Test("invalidating one id leaves the others alone")
    func invalidateIsScoped() async throws {
        let cache = ImageThumbnailCache()
        let data = try #require(ImagePixelTests.quadrantPNG())
        let kept = UUID()
        let dropped = UUID()

        _ = await cache.thumbnail(for: data, id: kept, maxPixel: 64)
        _ = await cache.thumbnail(for: data, id: dropped, maxPixel: 64)

        cache.invalidate(id: dropped)

        #expect(cache.cached(id: kept, maxPixel: 64) != nil)
        #expect(cache.cached(id: dropped, maxPixel: 64) == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run with `-only-testing:MyPasteAppTests/ThumbnailInvalidationTests`.
Expected: FAIL — `value of type 'ImageThumbnailCache' has no member 'invalidate'`.

- [ ] **Step 3: Implement the invalidation**

In `MyPasteApp/Services/ImageThumbnailCache.swift`, add a stored property next to `cache`:

```swift
    /// Which sizes were ever handed out for each id.
    ///
    /// `NSCache` can't be enumerated, and the key includes the pixel size the
    /// caller asked for — so without this record, invalidating means guessing
    /// which sizes exist. The card and the preview panel use different ones,
    /// and a missed size means a card still drawing the image from before the
    /// edit until the app restarts.
    private var issuedSizes: [UUID: Set<Int>] = [:]
```

In `thumbnail(for:id:maxPixel:)`, right after the successful `cache.setObject(...)` call:

```swift
        issuedSizes[id, default: []].insert(maxPixel)
```

And add:

```swift
    /// Drops every cached size for one item.
    ///
    /// Called whenever an item's `imageData` is rewritten — the id stays the
    /// same, so nothing else would tell the cache its entry is stale.
    func invalidate(id: UUID) {
        for maxPixel in issuedSizes[id] ?? [] {
            cache.removeObject(forKey: Self.key(id: id, maxPixel: maxPixel))
        }
        issuedSizes[id] = nil
    }
```

- [ ] **Step 4: Run the cache tests**

Run with `-only-testing:MyPasteAppTests/ThumbnailInvalidationTests`. Expected: PASS, 2 tests.

- [ ] **Step 5: Write the failing `ImageEdit` test**

Create `MyPasteAppTests/ImageEditTests.swift`:

```swift
//
//  ImageEditTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftData
import Testing
@testable import MyPasteApp

@Suite("ImageEdit")
@MainActor
struct ImageEditTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func makeImageItem(data: Data) -> ClipboardItem {
        ClipboardItem(type: .image,
                      preview: "Imagem 2×2",
                      contentHash: ClipboardMonitor.hash(data),
                      imageData: data)
    }

    @Test("applying new bytes rewrites the data, the hash and the preview")
    func rewritesDerivedFields() throws {
        let context = try makeContext()
        let original = try #require(ImageRotationTests.stripePNG(width: 4, height: 2))
        let item = makeImageItem(data: original)
        context.insert(item)

        let rotated = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        ImageEdit.apply(to: item, imageData: rotated)

        #expect(item.imageData == rotated)
        #expect(item.contentHash == ClipboardMonitor.hash(rotated))
        // The preview is the string the card falls back to, and it names the
        // dimensions — which just swapped.
        #expect(item.preview == "Imagem 2×4")
    }

    @Test("the hash actually changes, so deduplication doesn't collide")
    func hashChanges() throws {
        let context = try makeContext()
        let original = try #require(ImageRotationTests.stripePNG(width: 4, height: 2))
        let item = makeImageItem(data: original)
        context.insert(item)
        let before = item.contentHash

        let rotated = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        ImageEdit.apply(to: item, imageData: rotated)

        #expect(item.contentHash != before)
    }

    @Test("editing an image promotes it, like editing text does")
    func promotesTheItem() throws {
        let context = try makeContext()
        let original = try #require(ImagePixelTests.quadrantPNG())
        let item = makeImageItem(data: original)
        item.createdAt = .distantPast
        context.insert(item)

        let rotated = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        ImageEdit.apply(to: item, imageData: rotated)

        #expect(item.createdAt.timeIntervalSinceNow > -5)
        #expect(item.lastUsedAt != nil)
    }

    @Test("the cached thumbnail is dropped")
    func dropsTheThumbnail() async throws {
        let context = try makeContext()
        let original = try #require(ImagePixelTests.quadrantPNG())
        let item = makeImageItem(data: original)
        context.insert(item)

        _ = await ImageThumbnailCache.shared.thumbnail(for: original, id: item.id, maxPixel: 64)
        #expect(ImageThumbnailCache.shared.cached(id: item.id, maxPixel: 64) != nil)

        let rotated = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        ImageEdit.apply(to: item, imageData: rotated)

        #expect(ImageThumbnailCache.shared.cached(id: item.id, maxPixel: 64) == nil)
    }
}
```

- [ ] **Step 6: Run test to verify it fails**

Run with `-only-testing:MyPasteAppTests/ImageEditTests`.
Expected: FAIL — `cannot find 'ImageEdit' in scope`.

- [ ] **Step 7: Implement `ImageEdit`**

In `MyPasteApp/Services/ItemActions.swift`, at the end of the file (next to `enum ItemEdit`):

```swift
/// Applies an edit to an image item, recomputing everything derived from its
/// bytes.
///
/// `@MainActor` because of the cache: dropping the stale thumbnail is part of
/// applying the edit, not an extra step a caller might forget. The card and
/// the preview keep drawing the old image otherwise — the cache is keyed by
/// item id, and the id doesn't change when the bytes do.
@MainActor
enum ImageEdit {
    static func apply(to item: ClipboardItem, imageData: Data) {
        item.imageData = imageData
        item.contentHash = ClipboardMonitor.hash(imageData)
        if let size = ImageMetadata.pixelSize(of: imageData) {
            // Same shape ClipboardMonitor writes on capture. Leaving it stale
            // would have the card describing dimensions the image no longer
            // has.
            item.preview = "Imagem \(Int(size.width))×\(Int(size.height))"
        }

        ImageThumbnailCache.shared.invalidate(id: item.id)

        // Editing counts as use, exactly as it does for text — see
        // `ItemEdit.apply`.
        item.createdAt = .now
        item.lastUsedAt = .now

        try? item.modelContext?.save()
    }
}
```

- [ ] **Step 8: Run the tests**

Run with `-only-testing:MyPasteAppTests/ImageEditTests`. Expected: PASS, 4 tests.

- [ ] **Step 9: Give the editor an image body**

In `MyPasteApp/Views/ItemEditorView.swift`, add state and a computed image:

```swift
    /// Quarter turns the user has asked for but not saved yet.
    ///
    /// Rotation is deliberately not applied as it's clicked: every apply would
    /// rewrite the external blob, recompute the hash, drop the thumbnail and
    /// promote the item — four side effects per click, with the card jumping
    /// position while the user is still deciding, and no way to change their
    /// mind. `Save` does it once; `Cancel` still means nothing happened.
    @State private var quarterTurns = 0

    private var editableImage: (item: ClipboardItem, data: Data)? {
        guard case .existing(let item) = mode,
              item.type == .image,
              let data = item.imageData else { return nil }
        return (item, data)
    }
```

In `body`, between the label field and the `hasEditableBody` block:

```swift
            if let editable = editableImage {
                Divider()
                imageBody(data: editable.data)
            }
```

And add:

```swift
    private func imageBody(data: Data) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Spacer()
                Button { quarterTurns -= 1 } label: {
                    Image(systemName: "rotate.left")
                }
                .help("Rotate left")
                Button { quarterTurns += 1 } label: {
                    Image(systemName: "rotate.right")
                }
                .help("Rotate right")
                Spacer()
            }
            .buttonStyle(.plain)
            .font(.system(size: 15))
            .padding(.bottom, 8)

            ZStack {
                CheckerboardBackground()
                if let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        // Display-only: the bytes are rotated once, on Save.
                        .rotationEffect(.degrees(Double(quarterTurns) * 90))
                        .padding(12)
                }
            }
            .frame(minWidth: 480, minHeight: 280)
        }
    }
```

- [ ] **Step 10: Make `Save` apply the rotation**

In `save()`, in the `case .existing(let item):` branch, before the existing `if hasEditableBody` block:

```swift
            if item.type == .image {
                // `rotate` returns the original bytes unchanged for zero turns,
                // so turning right and back left again costs nothing: no new
                // blob, no new hash, no dropped thumbnail.
                if quarterTurns % 4 != 0,
                   let data = item.imageData,
                   let rotated = ImageRotation.rotate(data, quarterTurns: quarterTurns) {
                    ImageEdit.apply(to: item, imageData: rotated)
                }
                ItemEdit.applyLabel(to: item, label: label)
                onClose()
                return
            }
```

- [ ] **Step 11: Add "Edit" to the image preview header**

In `MyPasteApp/Views/ItemPreviewView.swift`, add the callback:

```swift
    /// Opens the item editor. Only offered for images: text and URL already
    /// have ⌘E, and a second path to the same window is a second thing to
    /// keep in step.
    var onEdit: (() -> Void)? = nil
```

In `header`, before the `footnote`:

```swift
            if item.type == .image, let onEdit {
                Button("Edit") { onEdit() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
            }
```

- [ ] **Step 12: Wire it in the controller**

In `applyPreviewContent(to:item:)`, add to the `ItemPreviewView` initialiser:

```swift
            onEdit: { [weak self] in self?.itemEditor.open(item: item, focus: .label) }
```

- [ ] **Step 13: Build**

Run the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 14: Write down what has to be checked by hand**

- girar uma imagem, salvar, e confirmar que **o card** mostra a imagem girada sem reiniciar o app (é o teste do cache invalidado)
- girar e cancelar: a imagem continua como estava
- girar quatro vezes e salvar: nada muda, e o item **não** é promovido
- renomear e girar no mesmo `Save`: as duas coisas valem

- [ ] **Step 15: Run the full suite**

Expected: everything green.

- [ ] **Step 16: Commit**

```bash
git add MyPasteApp/Services/ImageThumbnailCache.swift MyPasteApp/Services/ItemActions.swift \
        MyPasteApp/Views/ItemEditorView.swift MyPasteApp/Views/ItemPreviewView.swift \
        MyPasteApp/Window/OverlayWindowController.swift \
        MyPasteAppTests/ThumbnailInvalidationTests.swift MyPasteAppTests/ImageEditTests.swift
git commit -m "feat(image): rotate images in the item editor"
```

---

### Task 8: Live Text no preview

**Files:**
- Create: `MyPasteApp/Views/Preview/LiveTextOverlay.swift`
- Modify: `MyPasteApp/Views/ItemPreviewView.swift`

**Interfaces:**
- Consumes: `PreviewImageMode` (Task 5).
- Produces: `LiveTextOverlay(data:isActive:)`; `PreviewImageMode.liveText`.

No automated tests. **This is the riskiest task of the phase** — read Step 1 before writing anything.

- [ ] **Step 1: Understand the risk before writing code**

`ItemPreviewPanel.make()` sets `becomesKeyOnlyIfNeeded = true`, and the comment in that file spells out why it works today: the panel's content never *needs* key status, because `TextPreviewView`'s text view is `isEditable = false`. A panel that becomes key sends `windowDidResignKey` to the overlay — which is wired to `hide()`.

`ImageAnalysisOverlayView` with text selection turned on may well ask for key status. If it does, turning Live Text on closes the drawer underneath.

So: build it, then have the Carlos check **that specific thing first**. If the overlay closes, the fallback is to keep the panel from becoming key and accept that selection works only while the panel is clicked into — record what happens rather than guessing now.

- [ ] **Step 2: Create the overlay wrapper**

Create `MyPasteApp/Views/Preview/LiveTextOverlay.swift`:

```swift
//
//  LiveTextOverlay.swift
//  MyPasteApp
//

import AppKit
import SwiftUI
import VisionKit

/// The system's Live Text layer, and the image it reads.
///
/// Not the same thing as `OCRService`, and not a replacement for it: that one
/// extracts `ocrText` to feed the search — text with no position, good for
/// *finding* an image. This is selection *inside* an image that's already
/// open, and it brings "Copy All", data detectors and translation from the
/// system.
///
/// **It draws the image itself**, rather than sitting on top of the SwiftUI
/// one. `ImageAnalysisOverlayView` aligns its text boxes to a
/// `trackingImageView`; with no tracked view it falls back to its own bounds,
/// and since the preview scales the image to fit, every selection box would
/// land offset by the empty margin. Hosting the `NSImageView` here is what
/// makes the geometry exact. The cost — the original image decoded while the
/// mode is on — is paid only while the mode is on.
struct LiveTextOverlay: NSViewRepresentable {
    /// The original image data, never the downsampled thumbnail: small text
    /// disappears in the downsample, and screenshots are the whole point.
    let data: Data

    func makeNSView(context: Context) -> NSView {
        let container = NSView()

        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = NSImage(data: data)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)

        let overlay = ImageAnalysisOverlayView()
        overlay.trackingImageView = imageView
        overlay.preferredInteractionTypes = [.textSelection]
        overlay.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(overlay)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: container.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.analyse(data: data, into: overlay)
        return container
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let overlay = view.subviews.compactMap({ $0 as? ImageAnalysisOverlayView }).first
        else { return }
        // Analysis runs once per image: `updateNSView` fires on every SwiftUI
        // update, and re-analysing each time would throw away the selection
        // the user just made and pay for the analysis again.
        context.coordinator.analyse(data: data, into: overlay)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private let analyzer = ImageAnalyzer()
        private var analysedData: Data?
        private var task: Task<Void, Never>?

        @MainActor
        func analyse(data: Data, into view: ImageAnalysisOverlayView) {
            guard analysedData != data, let image = NSImage(data: data) else { return }
            analysedData = data
            task?.cancel()
            task = Task { [analyzer] in
                let configuration = ImageAnalyzer.Configuration([.text])
                guard let analysis = try? await analyzer.analyze(image, configuration: configuration)
                else { return }
                view.analysis = analysis
            }
        }
    }
}
```

- [ ] **Step 3: Add the mode**

In `MyPasteApp/Views/ItemPreviewView.swift`, extend the enum:

```swift
enum PreviewImageMode {
    case none
    case sampler
    case liveText
}
```

In the image branch, **swap** what draws the image while the mode is on — the Live Text view draws its own, for the alignment reason in its doc comment. Replace the `ThumbnailImage(...)` call inside the `GeometryReader` with:

```swift
                    Group {
                        if mode == .liveText {
                            LiveTextOverlay(data: data)
                        } else {
                            ThumbnailImage(
                                data: data,
                                id: item.id,
                                maxPixel: ImageThumbnailCache.pixels(for: ItemPreviewPanel.defaultSize)
                            ) {
                                Text(item.preview).font(.caption)
                            }
                        }
                    }
```

The modifiers already attached to `ThumbnailImage` (`.frame`, `.background`, `.contentShape`, `.onTapGesture`, `.onHover`) move to this `Group` — the tap gesture stays harmless while Live Text is on, because `sample(at:...)` returns immediately unless `mode == .sampler`.

Add `import VisionKit` at the top of the file.

In `modeButtons`, add the second button after the eyedropper:

```swift
            if ImageAnalyzer.isSupported {
                modeButton(systemName: "text.viewfinder",
                           help: "Select text in this image",
                           isOn: mode == .liveText) {
                    mode = mode == .liveText ? .none : .liveText
                }
            }
```

Because `mode` is a single value, turning one on turns the other off with no extra rule — which is the point.

- [ ] **Step 4: Build**

Run the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Write down what has to be checked by hand, in this order**

1. **primeiro:** abrir o preview de uma imagem com texto, ligar o Live Text, e ver **se a overlay embaixo continua aberta**. Se fechar, parar e relatar — o resto não importa até isso estar resolvido
2. confirmar que a seleção **cai em cima do texto**, e não deslocada — é o que a `trackingImageView` existe para garantir, e o que falha primeiro numa imagem que não preenche o painel
3. selecionar um trecho de texto e copiar
4. clicar com o botão direito e usar "Copy All"
4. ligar o conta-gotas e confirmar que o Live Text desliga
5. abrir uma imagem **sem** texto e confirmar que nada quebra

- [ ] **Step 6: Run the full suite**

Expected: everything green.

- [ ] **Step 7: Commit**

```bash
git add MyPasteApp/Views/Preview/LiveTextOverlay.swift MyPasteApp/Views/ItemPreviewView.swift
git commit -m "feat(image): select text inside an image with Live Text"
```

---

### Task 9: `DragPayload` e `TempFileCleanup`

**Files:**
- Create: `MyPasteApp/Services/DragPayload.swift`
- Create: `MyPasteApp/Services/TempFileCleanup.swift`
- Test: `MyPasteAppTests/DragPayloadTests.swift`
- Test: `MyPasteAppTests/TempFileCleanupTests.swift`

**Interfaces:**
- Consumes: `RichText.payload`.
- Produces: `DragPayload.Kind`; `DragPayload.kind(for:fileExists:) -> Kind`; `DragPayload.imageFileName(label:date:) -> String`; `TempFileCleanup.expired(_:now:maxAge:) -> [URL]`.

- [ ] **Step 1: Write the failing `DragPayload` test**

Create `MyPasteAppTests/DragPayloadTests.swift`:

```swift
//
//  DragPayloadTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing
@testable import MyPasteApp

@Suite("Drag payload")
@MainActor
struct DragPayloadTests {

    private func textItem(_ text: String) -> ClipboardItem {
        ClipboardItem(type: .text,
                      preview: text,
                      contentHash: ClipboardMonitor.hash(text),
                      textContent: text)
    }

    @Test("text drags as text")
    func textDragsAsText() {
        let kind = DragPayload.kind(for: textItem("hello"))
        guard case .text(let string, let rtf) = kind else {
            Issue.record("expected text, got \(kind)")
            return
        }
        #expect(string == "hello")
        #expect(rtf == nil)
    }

    @Test("formatted text carries its formatting too")
    func richTextDragsBoth() throws {
        let attributed = NSAttributedString(
            string: "hello",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
        let rtfData = try #require(try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]))

        let item = textItem("hello")
        item.richTextData = rtfData
        item.richTextFormat = .rtf

        guard case .text(let string, let rtf) = DragPayload.kind(for: item) else {
            Issue.record("expected text")
            return
        }
        // Dragging and pasting must not disagree about what the item is.
        #expect(string == "hello")
        #expect(rtf != nil)
    }

    @Test("a file drags as the urls that still exist")
    func fileDragsExistingURLs() {
        let item = ClipboardItem(type: .file,
                                 preview: "two files",
                                 contentHash: "hash",
                                 fileURLStrings: ["/tmp/here.txt", "/tmp/gone.txt"])
        let kind = DragPayload.kind(for: item, fileExists: { $0 == "/tmp/here.txt" })
        guard case .files(let urls) = kind else {
            Issue.record("expected files, got \(kind)")
            return
        }
        // A path that no longer exists is filtered here rather than discovered
        // by the destination, which would just fail with nothing to show.
        #expect(urls.map(\.path) == ["/tmp/here.txt"])
    }

    @Test("a file item whose paths are all gone drags nothing")
    func fileWithNoExistingPaths() {
        let item = ClipboardItem(type: .file,
                                 preview: "one file",
                                 contentHash: "hash",
                                 fileURLStrings: ["/tmp/gone.txt"])
        #expect(DragPayload.kind(for: item, fileExists: { _ in false }) == .none)
    }

    @Test("an image drags as png bytes plus a name")
    func imageDragsAsFile() throws {
        let data = try #require(ImagePixelTests.quadrantPNG())
        let item = ClipboardItem(type: .image,
                                 preview: "Imagem 2×2",
                                 contentHash: "hash",
                                 imageData: data)
        guard case .image(let png, let name) = DragPayload.kind(for: item) else {
            Issue.record("expected image")
            return
        }
        #expect(png == data)
        #expect(name.hasSuffix(".png"))
    }

    // MARK: - File names

    @Test("the label becomes the file name")
    func labelBecomesName() {
        let name = DragPayload.imageFileName(label: "Logo final", date: .distantPast)
        #expect(name == "Logo final.png")
    }

    @Test("characters a file name can't hold are replaced")
    func sanitisesName() {
        // A slash makes the Finder reject the drop outright, and a colon is
        // still a path separator as far as the file system is concerned.
        let name = DragPayload.imageFileName(label: "before/after: v2", date: .distantPast)
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
        #expect(name.hasSuffix(".png"))
    }

    @Test("a very long label is cut short")
    func truncatesName() {
        let name = DragPayload.imageFileName(label: String(repeating: "a", count: 300),
                                             date: .distantPast)
        #expect(name.count <= 64)
        #expect(name.hasSuffix(".png"))
    }

    @Test("a label of nothing but punctuation falls back to the date")
    func fallsBackWhenLabelIsUseless() {
        let date = Date(timeIntervalSince1970: 1_770_000_000)
        let fromNil = DragPayload.imageFileName(label: nil, date: date)
        let fromSlashes = DragPayload.imageFileName(label: "///", date: date)
        #expect(fromNil == fromSlashes)
        #expect(fromNil.hasPrefix("Image "))
        #expect(fromNil.hasSuffix(".png"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run with `-only-testing:MyPasteAppTests/DragPayloadTests`.
Expected: FAIL — `cannot find 'DragPayload' in scope`.

- [ ] **Step 3: Write `DragPayload`**

Create `MyPasteApp/Services/DragPayload.swift`:

```swift
//
//  DragPayload.swift
//  MyPasteApp
//

import AppKit
import Foundation

/// What dragging a card hands over.
///
/// Pure and free-standing: deciding *what* to give is separable from the
/// AppKit machinery that gives it (`DragItemProvider`), and only this half can
/// be tested.
enum DragPayload {

    enum Kind: Equatable {
        /// Plain text, plus the formatted flavour when the item has one.
        case text(String, rtf: Data?)
        case files([URL])
        case image(png: Data, fileName: String)
        /// Nothing worth dragging — an image with no data, or a file item
        /// whose paths are all gone.
        case none
    }

    static func kind(for item: ClipboardItem,
                     fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) })
    -> Kind {
        switch item.type {
        case .text, .url:
            guard let text = item.textContent else { return .none }
            // The same payload the paste path builds — dragging and pasting
            // can't disagree about what the item's content is.
            let rtf = RichText.payload(text: text,
                                       richTextData: item.richTextData,
                                       format: item.richTextFormat,
                                       plainOnly: false)
                .first { $0.type == .rtf }?
                .data
            return .text(text, rtf: rtf)

        case .file:
            let existing = (item.fileURLStrings ?? [])
                .filter(fileExists)
                .map { URL(fileURLWithPath: $0) }
            return existing.isEmpty ? .none : .files(existing)

        case .image:
            guard let data = item.imageData else { return .none }
            return .image(png: data,
                          fileName: imageFileName(label: item.label, date: item.createdAt))
        }
    }

    /// A file name a destination will accept.
    ///
    /// The Finder rejects a promised file whose name it can't use, and the
    /// failure looks like "the drag didn't work" with nothing explaining why —
    /// which is the exact failure the roadmap item exists to avoid.
    static func imageFileName(label: String?, date: Date) -> String {
        let cleaned = (label ?? "")
            .components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -\t\n"))

        let base: String
        if cleaned.isEmpty {
            base = "Image " + Self.stamp.string(from: date)
        } else {
            base = String(cleaned.prefix(60))
        }
        return base + ".png"
    }

    /// Colons are illegal in file names, so the time uses dashes.
    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return formatter
    }()
}
```

- [ ] **Step 4: Run the tests**

Run with `-only-testing:MyPasteAppTests/DragPayloadTests`. Expected: PASS, 9 tests.

- [ ] **Step 5: Write the failing `TempFileCleanup` test**

Create `MyPasteAppTests/TempFileCleanupTests.swift`:

```swift
//
//  TempFileCleanupTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing
@testable import MyPasteApp

@Suite("Temp file cleanup")
struct TempFileCleanupTests {

    private let now = Date(timeIntervalSince1970: 1_770_000_000)

    @Test("files older than the cutoff are expired")
    func expiresOldFiles() {
        let old = URL(fileURLWithPath: "/tmp/old.png")
        let fresh = URL(fileURLWithPath: "/tmp/fresh.png")
        let expired = TempFileCleanup.expired(
            [(old, now.addingTimeInterval(-7200)), (fresh, now.addingTimeInterval(-60))],
            now: now,
            maxAge: 3600)
        #expect(expired == [old])
    }

    @Test("a file exactly at the cutoff is kept")
    func keepsFilesAtTheBoundary() {
        // The drag that wrote it may still be in flight; deleting a file out
        // from under a destination that's copying it is worse than keeping a
        // few kilobytes an hour longer.
        let url = URL(fileURLWithPath: "/tmp/edge.png")
        #expect(TempFileCleanup.expired([(url, now.addingTimeInterval(-3600))],
                                        now: now,
                                        maxAge: 3600).isEmpty)
    }

    @Test("a file dated in the future is kept")
    func keepsFutureFiles() {
        // Clock changes happen. Deleting on a negative age would wipe files
        // that were just written.
        let url = URL(fileURLWithPath: "/tmp/future.png")
        #expect(TempFileCleanup.expired([(url, now.addingTimeInterval(600))],
                                        now: now,
                                        maxAge: 3600).isEmpty)
    }

    @Test("an empty directory expires nothing")
    func handlesEmptyInput() {
        #expect(TempFileCleanup.expired([], now: now, maxAge: 3600).isEmpty)
    }
}
```

- [ ] **Step 6: Run test to verify it fails**

Run with `-only-testing:MyPasteAppTests/TempFileCleanupTests`.
Expected: FAIL — `cannot find 'TempFileCleanup' in scope`.

- [ ] **Step 7: Write `TempFileCleanup`**

Create `MyPasteApp/Services/TempFileCleanup.swift`:

```swift
//
//  TempFileCleanup.swift
//  MyPasteApp
//

import Foundation

/// Decides which dragged-image temporaries can go.
///
/// A safety net, not the mechanism: `DragItemProvider` only writes a file when
/// a destination asks for one, so this usually finds nothing. It exists
/// because there's no documented guarantee that the system removes a file we
/// created ourselves — and an app that leaves files in the temporary directory
/// forever is an app that fills a disk slowly enough that nobody connects the
/// two.
enum TempFileCleanup {
    /// - Parameter maxAge: how old a file must be to go. One hour by default:
    ///   long enough that no in-flight drag can be affected, short enough that
    ///   nothing accumulates across a session.
    static func expired(_ files: [(url: URL, modified: Date)],
                        now: Date,
                        maxAge: TimeInterval = 3600) -> [URL] {
        files
            .filter { now.timeIntervalSince($0.modified) > maxAge }
            .map(\.url)
    }
}
```

- [ ] **Step 8: Run the tests**

Run with `-only-testing:MyPasteAppTests/TempFileCleanupTests`. Expected: PASS, 4 tests.

- [ ] **Step 9: Run the full suite**

Expected: everything green.

- [ ] **Step 10: Commit**

```bash
git add MyPasteApp/Services/DragPayload.swift MyPasteApp/Services/TempFileCleanup.swift \
        MyPasteAppTests/DragPayloadTests.swift MyPasteAppTests/TempFileCleanupTests.swift
git commit -m "feat(drag): decide what each card hands over, and what to clean up"
```

---

### Task 10: Arrastar o card

**Files:**
- Create: `MyPasteApp/Services/DragItemProvider.swift`
- Modify: `MyPasteApp/Views/ClipboardCardView.swift`
- Modify: `MyPasteApp/AppDelegate.swift`

**Interfaces:**
- Consumes: `DragPayload` and `TempFileCleanup` (Task 9).
- Produces: `DragItemProvider.make(for:) -> NSItemProvider`; `DragItemProvider.cleanUpTemporaries(now:)`.

No automated tests: this is AppKit plumbing, and its decisions were tested in Task 9.

- [ ] **Step 1: Write the provider**

Create `MyPasteApp/Services/DragItemProvider.swift`:

```swift
//
//  DragItemProvider.swift
//  MyPasteApp
//

import AppKit
import Foundation
import UniformTypeIdentifiers

/// Turns a `DragPayload.Kind` into the thing AppKit drags.
///
/// The image case registers a **lazy** file representation: nothing is written
/// until a destination actually asks for the file, so a drag the user abandons
/// costs nothing on disk. A `NSFilePromiseProvider` would let the file be born
/// directly in the destination folder, but it requires replacing SwiftUI's
/// `.onDrag` with an `NSView` of our own as the dragging source — see the
/// spec's decision table.
enum DragItemProvider {

    static func make(for item: ClipboardItem) -> NSItemProvider {
        let provider = NSItemProvider()

        switch DragPayload.kind(for: item) {
        case .text(let string, let rtf):
            if let rtf {
                provider.registerDataRepresentation(forTypeIdentifier: UTType.rtf.identifier,
                                                    visibility: .all) { completion in
                    completion(rtf, nil)
                    return nil
                }
            }
            provider.registerDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier,
                                                visibility: .all) { completion in
                completion(Data(string.utf8), nil)
                return nil
            }

        case .files(let urls):
            // File URLs the system already knows how to hand over — no copy,
            // no temporary, nothing to clean up.
            for url in urls {
                provider.registerFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier,
                                                    fileOptions: [.openInPlace],
                                                    visibility: .all) { completion in
                    completion(url, true, nil)
                    return nil
                }
            }

        case .image(let png, let fileName):
            provider.suggestedName = fileName
            provider.registerFileRepresentation(forTypeIdentifier: UTType.png.identifier,
                                                fileOptions: [],
                                                visibility: .all) { completion in
                do {
                    let url = try writeTemporary(png: png, fileName: fileName)
                    completion(url, false, nil)
                } catch {
                    completion(nil, false, error)
                }
                return nil
            }

        case .none:
            break
        }

        return provider
    }

    // MARK: - Temporaries

    private static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("MyPasteApp-drags",
                                                                      isDirectory: true)
    }

    private static func writeTemporary(png: Data, fileName: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        try png.write(to: url)
        return url
    }

    /// Deletes leftovers from earlier sessions. Called once at launch.
    static func cleanUpTemporaries(now: Date = .now) {
        let manager = FileManager.default
        guard let entries = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]) else { return }

        let dated: [(url: URL, modified: Date)] = entries.compactMap { url in
            guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate else { return nil }
            return (url, modified)
        }

        for url in TempFileCleanup.expired(dated, now: now) {
            try? manager.removeItem(at: url)
        }
    }
}
```

- [ ] **Step 2: Make the card draggable**

In `MyPasteApp/Views/ClipboardCardView.swift`, add to the outermost modifier chain in `body`, right after `.shadow(...)`:

```swift
        // The drag begins with a mouse-down *inside* the overlay, so
        // `OverlayWindowController.installClickOutsideMonitors` — which only
        // watches mouse-down — doesn't read it as a click outside. What can
        // still close the drawer is the destination app activating on drop;
        // that's a manual check, recorded in the phase's roteiro.
        .onDrag { DragItemProvider.make(for: item) }
```

- [ ] **Step 3: Clean up at launch**

In `MyPasteApp/AppDelegate.swift`, in `applicationDidFinishLaunching`, next to the existing startup calls:

```swift
        DragItemProvider.cleanUpTemporaries()
```

- [ ] **Step 4: Build**

Run the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Write down what has to be checked by hand**

- arrastar um card de imagem para o Finder: nasce um PNG com nome razoável
- arrastar o mesmo card para o Word: a imagem é inserida
- arrastar para o navegador: abre em visualização
- arrastar um card de texto para um campo de texto de outro app
- arrastar um card de texto formatado para o Word: a formatação chega
- arrastar um card de arquivo para outra pasta do Finder
- **em todos:** anotar se a overlay fecha ao soltar, e em quais destinos
- arrastar e soltar **fora** de qualquer destino válido: nenhum arquivo aparece em `$TMPDIR/MyPasteApp-drags`

- [ ] **Step 6: Run the full suite**

Expected: everything green.

- [ ] **Step 7: Commit**

```bash
git add MyPasteApp/Services/DragItemProvider.swift MyPasteApp/Views/ClipboardCardView.swift \
        MyPasteApp/AppDelegate.swift
git commit -m "feat(drag): drag any card out of the drawer"
```

---

### Task 11: `OpenWith`, o submenu e `⌘O`

**Files:**
- Create: `MyPasteApp/Services/OpenWith.swift`
- Modify: `MyPasteApp/Services/ItemActions.swift`
- Modify: `MyPasteApp/Views/ItemContextMenu.swift`
- Modify: `MyPasteApp/Views/OverlayView.swift`
- Test: `MyPasteAppTests/OpenWithTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `OpenWith.target(for:fileExists:) -> OpenWith.Target`; `OpenWith.candidates(for:) -> [OpenWith.Candidate]`; `ItemActions.open(_:with:)`.

- [ ] **Step 1: Write the failing test**

Create `MyPasteAppTests/OpenWithTests.swift`:

```swift
//
//  OpenWithTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing
@testable import MyPasteApp

@Suite("Open with")
@MainActor
struct OpenWithTests {

    @Test("a file item resolves to its first existing path")
    func fileTarget() {
        let item = ClipboardItem(type: .file,
                                 preview: "two",
                                 contentHash: "hash",
                                 fileURLStrings: ["/tmp/gone.txt", "/tmp/here.txt"])
        let target = OpenWith.target(for: item, fileExists: { $0 == "/tmp/here.txt" })
        #expect(target == .openable(URL(fileURLWithPath: "/tmp/here.txt")))
    }

    @Test("a file whose path is gone says so, with the path")
    func missingFileTarget() {
        // Not `.unsupported`: the entry has to appear and explain itself.
        // Silently hiding the action is the failure the roadmap calls out.
        let item = ClipboardItem(type: .file,
                                 preview: "one",
                                 contentHash: "hash",
                                 fileURLStrings: ["/tmp/gone.txt"])
        #expect(OpenWith.target(for: item, fileExists: { _ in false })
                == .missing("/tmp/gone.txt"))
    }

    @Test("a url item resolves to its url")
    func urlTarget() {
        let item = ClipboardItem(type: .url,
                                 preview: "https://example.com",
                                 contentHash: "hash",
                                 textContent: "https://example.com")
        #expect(OpenWith.target(for: item) == .openable(URL(string: "https://example.com")!))
    }

    @Test("a url item holding something unopenable is unsupported")
    func brokenURLTarget() {
        let item = ClipboardItem(type: .url,
                                 preview: "not a url",
                                 contentHash: "hash",
                                 textContent: "not a url")
        #expect(OpenWith.target(for: item) == .unsupported)
    }

    @Test("text and image items have nothing to open")
    func unsupportedTypes() {
        let text = ClipboardItem(type: .text,
                                 preview: "hi",
                                 contentHash: "hash",
                                 textContent: "hi")
        let image = ClipboardItem(type: .image, preview: "img", contentHash: "hash")
        #expect(OpenWith.target(for: text) == .unsupported)
        #expect(OpenWith.target(for: image) == .unsupported)
    }

    @Test("candidates come back named and deduplicated")
    func candidatesForAKnownType() {
        // Every macOS install can open an http URL with at least one browser,
        // and the names must be app names, not paths.
        let candidates = OpenWith.candidates(for: URL(string: "https://example.com")!)
        #expect(!candidates.isEmpty)
        #expect(candidates.allSatisfy { !$0.name.isEmpty && !$0.name.contains("/") })
        #expect(Set(candidates.map(\.url)).count == candidates.count)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run with `-only-testing:MyPasteAppTests/OpenWithTests`.
Expected: FAIL — `cannot find 'OpenWith' in scope`.

- [ ] **Step 3: Write `OpenWith`**

Create `MyPasteApp/Services/OpenWith.swift`:

```swift
//
//  OpenWith.swift
//  MyPasteApp
//

import AppKit
import Foundation

/// Opening an item somewhere else.
///
/// Only file and URL items: an image would have to be written out with nobody
/// asking for the file, and text would want a `.txt` to open in the editor
/// this app already has.
enum OpenWith {

    enum Target: Equatable {
        case openable(URL)
        /// The item points at a path that no longer exists. Carries the path
        /// so the menu can say which one.
        case missing(String)
        case unsupported
    }

    struct Candidate: Equatable, Identifiable {
        let url: URL
        let name: String
        var id: URL { url }
    }

    static func target(for item: ClipboardItem,
                       fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) })
    -> Target {
        switch item.type {
        case .file:
            let paths = item.fileURLStrings ?? []
            guard let first = paths.first else { return .unsupported }
            guard let existing = paths.first(where: fileExists) else { return .missing(first) }
            return .openable(URL(fileURLWithPath: existing))
        case .url:
            guard let text = item.textContent,
                  let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                  url.scheme != nil
            else { return .unsupported }
            return .openable(url)
        case .text, .image:
            return .unsupported
        }
    }

    /// The applications that can open this target, by display name.
    static func candidates(for target: URL) -> [Candidate] {
        var seen = Set<URL>()
        return NSWorkspace.shared.urlsForApplications(toOpen: target).compactMap { url in
            guard seen.insert(url).inserted else { return nil }
            let name = FileManager.default.displayName(atPath: url.path)
            // `displayName` keeps the extension on some systems; the menu
            // wants "Safari", not "Safari.app".
            let trimmed = name.hasSuffix(".app") ? String(name.dropLast(4)) : name
            return Candidate(url: url, name: trimmed)
        }
    }

    /// Opens the target, in a specific app or in the default one.
    static func open(_ target: URL, with application: URL? = nil) {
        guard let application else {
            NSWorkspace.shared.open(target)
            return
        }
        NSWorkspace.shared.open([target],
                                withApplicationAt: application,
                                configuration: NSWorkspace.OpenConfiguration())
    }
}
```

- [ ] **Step 4: Run the tests**

Run with `-only-testing:MyPasteAppTests/OpenWithTests`. Expected: PASS, 6 tests.

- [ ] **Step 5: Add the action**

In `MyPasteApp/Services/ItemActions.swift`, inside the class:

```swift
    /// Opens an item in another application.
    ///
    /// Does nothing for an item with no openable target — the menu already
    /// won't offer it, and `⌘O` over such a card should be a no-op rather than
    /// an error nobody can act on.
    func open(_ item: ClipboardItem, with application: URL? = nil) {
        guard case .openable(let target) = OpenWith.target(for: item) else { return }
        OpenWith.open(target, with: application)
    }
```

- [ ] **Step 6: Add the submenu**

In `MyPasteApp/Views/ItemContextMenu.swift`, right before the `Divider()` that precedes the pinboard menu:

```swift
        switch OpenWith.target(for: item) {
        case .openable(let target):
            Menu(titled("Open with", "⌘O")) {
                Button("Default App") { actions.open(item) }
                let candidates = OpenWith.candidates(for: target)
                if !candidates.isEmpty { Divider() }
                ForEach(candidates) { candidate in
                    Button(candidate.name) { actions.open(item, with: candidate.url) }
                }
            }
        case .missing(let path):
            // Disabled and explaining itself. A silently absent entry sends
            // the user looking for a bug in the wrong place.
            Button("Open with — file not found: \(path)") {}
                .disabled(true)
        case .unsupported:
            EmptyView()
        }
```

- [ ] **Step 7: Add the shortcut**

In `MyPasteApp/Views/OverlayView.swift`, in the chain of `onKeyPress` handlers, next to the `"e"` handler:

```swift
        .onKeyPress(keys: ["o"], action: gated { press in
            // `gated` is not optional here: without it this fires while the
            // pinboard rename field has the keyboard. See `handlesKeys`.
            guard press.modifiers.contains(.command) else { return .ignored }
            // Only file and URL items have somewhere to be opened; over any
            // other card the key travels on, rather than being swallowed by a
            // handler that would do nothing with it.
            guard let item = filtered.first(where: { $0.id == selectedID }),
                  case .openable = OpenWith.target(for: item) else {
                return .ignored
            }
            itemActions.open(item)
            // Same as ⌘E: the drawer's job is done, and the app being opened
            // is about to take the foreground anyway.
            onDismiss()
            return .handled
        })
```

The names here are the ones the neighbouring handlers use — `filtered`, `selectedID`, `itemActions`, `onDismiss` — not new ones.

- [ ] **Step 8: Build**

Run the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 9: Write down what has to be checked by hand**

- `⌘O` sobre um card de arquivo abre no app padrão
- `⌘O` sobre um card de URL abre no navegador
- `⌘O` sobre um card de texto não faz nada (e não trava)
- o submenu lista os apps candidatos, e escolher um deles abre nesse app
- um item cujo arquivo foi apagado mostra a entrada desabilitada com o caminho
- **com o campo de renomear pinboard aberto, `⌘O` não faz nada** — o teste do gate

- [ ] **Step 10: Run the full suite**

Expected: everything green.

- [ ] **Step 11: Commit**

```bash
git add MyPasteApp/Services/OpenWith.swift MyPasteApp/Services/ItemActions.swift \
        MyPasteApp/Views/ItemContextMenu.swift MyPasteApp/Views/OverlayView.swift \
        MyPasteAppTests/OpenWithTests.swift
git commit -m "feat(open): open files and links in another app"
```

---

### Task 12: `TextStats` e o rodapé do editor

**Files:**
- Create: `MyPasteApp/Services/TextStats.swift`
- Modify: `MyPasteApp/Views/ItemEditorView.swift`
- Test: `MyPasteAppTests/TextStatsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `TextStats.counts(_:) -> (characters: Int, words: Int, lines: Int)`; `TextStats.summary(_:) -> String`.

- [ ] **Step 1: Write the failing test**

Create `MyPasteAppTests/TextStatsTests.swift`:

```swift
//
//  TextStatsTests.swift
//  MyPasteAppTests
//

import Testing
@testable import MyPasteApp

@Suite("Text stats")
struct TextStatsTests {

    @Test("a plain sentence")
    func sentence() {
        let counts = TextStats.counts("Try Paste for free")
        #expect(counts.characters == 18)
        #expect(counts.words == 4)
        #expect(counts.lines == 1)
    }

    @Test("empty text is one empty line")
    func empty() {
        let counts = TextStats.counts("")
        #expect(counts.characters == 0)
        #expect(counts.words == 0)
        #expect(counts.lines == 1)
    }

    @Test("whitespace has characters but no words")
    func whitespaceOnly() {
        let counts = TextStats.counts("   \t ")
        #expect(counts.characters == 5)
        #expect(counts.words == 0)
        #expect(counts.lines == 1)
    }

    @Test("a trailing newline opens a line")
    func trailingNewline() {
        // "one\n" is two lines: the caret sits on the second one, and a footer
        // saying "1 line" while the caret is on line 2 is just wrong.
        let counts = TextStats.counts("one\n")
        #expect(counts.lines == 2)
        #expect(counts.words == 1)
    }

    @Test("several lines and repeated spaces")
    func multiline() {
        let counts = TextStats.counts("one  two\nthree")
        #expect(counts.words == 3)
        #expect(counts.lines == 2)
    }

    @Test("characters count what the user sees, not bytes")
    func graphemeClusters() {
        // "é" as e + combining accent is one character to a reader.
        let counts = TextStats.counts("cafe\u{0301}")
        #expect(counts.characters == 4)
    }

    @Test("the summary reads as a sentence")
    func summary() {
        #expect(TextStats.summary("Try Paste for free") == "18 characters · 4 words · 1 line")
        #expect(TextStats.summary("one\n") == "4 characters · 1 word · 2 lines")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run with `-only-testing:MyPasteAppTests/TextStatsTests`.
Expected: FAIL — `cannot find 'TextStats' in scope`.

- [ ] **Step 3: Write the implementation**

Create `MyPasteApp/Services/TextStats.swift`:

```swift
//
//  TextStats.swift
//  MyPasteApp
//

import Foundation

/// What the editor's footer says about the text being edited.
enum TextStats {

    /// - characters: `Character` count — grapheme clusters, so an accented
    ///   letter counts once however it was encoded.
    /// - words: runs separated by whitespace or newlines, empties discarded.
    /// - lines: newlines plus one, so empty text is one line and a text ending
    ///   in a newline has opened the next one.
    static func counts(_ text: String) -> (characters: Int, words: Int, lines: Int) {
        let words = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        let newlines = text.filter(\.isNewline).count
        return (text.count, words, newlines + 1)
    }

    static func summary(_ text: String) -> String {
        let counts = counts(text)
        return [
            "\(counts.characters) \(counts.characters == 1 ? "character" : "characters")",
            "\(counts.words) \(counts.words == 1 ? "word" : "words")",
            "\(counts.lines) \(counts.lines == 1 ? "line" : "lines")",
        ].joined(separator: " · ")
    }
}
```

- [ ] **Step 4: Run the tests**

Run with `-only-testing:MyPasteAppTests/TextStatsTests`. Expected: PASS, 7 tests.

- [ ] **Step 5: Show it in the editor**

In `MyPasteApp/Views/ItemEditorView.swift`, in the `HStack` that holds Cancel and Save, before the `Spacer()`:

```swift
                if hasEditableBody {
                    Text(TextStats.summary(attributed.string))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
```

- [ ] **Step 6: Build**

Run the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Run the full suite**

Expected: everything green.

- [ ] **Step 8: Commit**

```bash
git add MyPasteApp/Services/TextStats.swift MyPasteApp/Views/ItemEditorView.swift \
        MyPasteAppTests/TextStatsTests.swift
git commit -m "feat(editor): count characters, words and lines"
```

---

### Task 13: Barra de formatação

**Files:**
- Modify: `MyPasteApp/Services/RichText.swift`
- Modify: `MyPasteApp/Views/RichTextEditor.swift`
- Modify: `MyPasteApp/Views/ItemEditorView.swift`
- Test: `MyPasteAppTests/RichTextFormatTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `RichText.toggling(_:in:range:) -> NSAttributedString`; `RichText.togglingUnderline(in:range:)`; `RichText.togglingStrikethrough(in:range:)`; `RichText.stripped(_:font:)`; `enum RichTextCommand { case bold, italic, underline, strikethrough, clear }`.

- [ ] **Step 1: Write the failing test**

Create `MyPasteAppTests/RichTextFormatTests.swift`:

```swift
//
//  RichTextFormatTests.swift
//  MyPasteAppTests
//

import AppKit
import Testing
@testable import MyPasteApp

@Suite("Rich text formatting")
struct RichTextFormatTests {

    private let base = NSAttributedString(
        string: "hello world",
        attributes: [.font: NSFont.systemFont(ofSize: 13)])

    private func isBold(_ text: NSAttributedString, at location: Int) -> Bool {
        guard let font = text.attribute(.font, at: location, effectiveRange: nil) as? NSFont
        else { return false }
        return font.fontDescriptor.symbolicTraits.contains(.bold)
    }

    @Test("bold applies to the selected range only")
    func boldsTheRange() {
        let result = RichText.toggling(.bold, in: base, range: NSRange(location: 0, length: 5))
        #expect(isBold(result, at: 0))
        #expect(!isBold(result, at: 6))
        // The text itself must survive untouched — this is the failure mode
        // that silently destroys an item.
        #expect(result.string == "hello world")
    }

    @Test("bolding twice returns to plain")
    func boldIsAToggle() {
        let once = RichText.toggling(.bold, in: base, range: NSRange(location: 0, length: 5))
        let twice = RichText.toggling(.bold, in: once, range: NSRange(location: 0, length: 5))
        #expect(!isBold(twice, at: 0))
    }

    @Test("a mixed selection becomes uniformly bold")
    func mixedSelectionBecomesBold() {
        // Half bold, half not: the first press should make it all bold, not
        // flip each half independently.
        let half = RichText.toggling(.bold, in: base, range: NSRange(location: 0, length: 5))
        let all = RichText.toggling(.bold, in: half, range: NSRange(location: 0, length: 11))
        #expect(isBold(all, at: 0))
        #expect(isBold(all, at: 6))
    }

    @Test("underline toggles")
    func underlineToggles() {
        let range = NSRange(location: 0, length: 5)
        let on = RichText.togglingUnderline(in: base, range: range)
        #expect(on.attribute(.underlineStyle, at: 0, effectiveRange: nil) != nil)
        let off = RichText.togglingUnderline(in: on, range: range)
        #expect(off.attribute(.underlineStyle, at: 0, effectiveRange: nil) == nil)
    }

    @Test("strikethrough toggles")
    func strikethroughToggles() {
        let range = NSRange(location: 0, length: 5)
        let on = RichText.togglingStrikethrough(in: base, range: range)
        #expect(on.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) != nil)
        let off = RichText.togglingStrikethrough(in: on, range: range)
        #expect(off.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) == nil)
    }

    @Test("clearing formatting keeps the text and drops the attributes")
    func stripsFormatting() {
        let font = NSFont.systemFont(ofSize: 13)
        let bold = RichText.toggling(.bold, in: base, range: NSRange(location: 0, length: 11))
        let underlined = RichText.togglingUnderline(in: bold,
                                                    range: NSRange(location: 0, length: 11))
        let stripped = RichText.stripped(underlined, font: font)

        #expect(stripped.string == "hello world")
        #expect(!isBold(stripped, at: 0))
        #expect(stripped.attribute(.underlineStyle, at: 0, effectiveRange: nil) == nil)
        #expect(stripped.attribute(.font, at: 0, effectiveRange: nil) as? NSFont == font)
    }

    @Test("an empty range changes nothing")
    func emptyRangeIsANoOp() {
        let result = RichText.toggling(.bold, in: base, range: NSRange(location: 3, length: 0))
        #expect(result.isEqual(to: base))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run with `-only-testing:MyPasteAppTests/RichTextFormatTests`.
Expected: FAIL — `type 'RichText' has no member 'toggling'`.

- [ ] **Step 3: Extend `RichText`**

Append to `MyPasteApp/Services/RichText.swift`:

```swift
/// The formatting commands the editor's toolbar issues.
///
/// A value rather than a closure so `RichTextEditor` can take it as a binding:
/// SwiftUI has no handle on the `NSTextView` inside, and the view's own
/// coordinator is the only thing that knows the current selection.
enum RichTextCommand {
    case bold
    case italic
    case underline
    case strikethrough
    case clear
}

extension RichText {

    /// Adds or removes a font trait across a range.
    ///
    /// Applies uniformly: if any part of the range lacks the trait, the whole
    /// range gains it. Flipping each run independently would make one press on
    /// a half-bold selection leave it half-bold the other way round.
    static func toggling(_ trait: NSFontDescriptor.SymbolicTraits,
                         in attributed: NSAttributedString,
                         range: NSRange) -> NSAttributedString {
        guard range.length > 0 else { return attributed }
        let result = NSMutableAttributedString(attributedString: attributed)

        var everyRunHasIt = true
        result.enumerateAttribute(.font, in: range) { value, _, stop in
            let font = value as? NSFont
            if font?.fontDescriptor.symbolicTraits.contains(trait) != true {
                everyRunHasIt = false
                stop.pointee = true
            }
        }

        result.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = (value as? NSFont) ?? .systemFont(ofSize: NSFont.systemFontSize)
            var traits = font.fontDescriptor.symbolicTraits
            if everyRunHasIt { traits.remove(trait) } else { traits.insert(trait) }
            let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
            if let updated = NSFont(descriptor: descriptor, size: font.pointSize) {
                result.addAttribute(.font, value: updated, range: subrange)
            }
        }
        return result
    }

    static func togglingUnderline(in attributed: NSAttributedString,
                                  range: NSRange) -> NSAttributedString {
        toggling(attribute: .underlineStyle, in: attributed, range: range)
    }

    static func togglingStrikethrough(in attributed: NSAttributedString,
                                      range: NSRange) -> NSAttributedString {
        toggling(attribute: .strikethroughStyle, in: attributed, range: range)
    }

    private static func toggling(attribute key: NSAttributedString.Key,
                                 in attributed: NSAttributedString,
                                 range: NSRange) -> NSAttributedString {
        guard range.length > 0 else { return attributed }
        let result = NSMutableAttributedString(attributedString: attributed)
        let alreadyOn = result.attribute(key, at: range.location, effectiveRange: nil) != nil
        if alreadyOn {
            result.removeAttribute(key, range: range)
        } else {
            result.addAttribute(key, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        return result
    }

    /// Drops every attribute, keeping the characters.
    ///
    /// The whole string, not the selection: "clear formatting" that left half
    /// the item styled would be a worse surprise than not offering it.
    static func stripped(_ attributed: NSAttributedString, font: NSFont) -> NSAttributedString {
        NSAttributedString(string: attributed.string, attributes: [.font: font])
    }
}
```

- [ ] **Step 4: Run the tests**

Run with `-only-testing:MyPasteAppTests/RichTextFormatTests`. Expected: PASS, 7 tests.

- [ ] **Step 5: Give the editor a command channel**

In `MyPasteApp/Views/RichTextEditor.swift`, add a binding and apply it:

```swift
    /// A command the toolbar asked for, consumed and cleared on arrival.
    ///
    /// The selection lives in the `NSTextView`, which SwiftUI can't reach —
    /// so the command travels down instead of the selection travelling up.
    @Binding var command: RichTextCommand?
```

In `updateNSView`, before the existing storage comparison:

```swift
        if let command {
            apply(command, to: textView)
            // Cleared asynchronously: mutating state during a view update is
            // what SwiftUI's "Modifying state during view update" warning is
            // about.
            DispatchQueue.main.async { self.command = nil }
        }
```

And add to the struct:

```swift
    private func apply(_ command: RichTextCommand, to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let current = NSAttributedString(attributedString: storage)
        let range = textView.selectedRange()
        let updated: NSAttributedString

        switch command {
        case .bold:          updated = RichText.toggling(.bold, in: current, range: range)
        case .italic:        updated = RichText.toggling(.italic, in: current, range: range)
        case .underline:     updated = RichText.togglingUnderline(in: current, range: range)
        case .strikethrough: updated = RichText.togglingStrikethrough(in: current, range: range)
        case .clear:
            updated = RichText.stripped(current,
                                        font: textView.font ?? .systemFont(ofSize: 13))
        }

        storage.setAttributedString(updated)
        textView.setSelectedRange(range)
        attributedText = updated
    }
```

Update the two existing call sites that construct `RichTextEditor` — `ItemEditorView` is the only one — to pass the new binding.

- [ ] **Step 6: Add the toolbar**

In `MyPasteApp/Views/ItemEditorView.swift`, add state:

```swift
    @State private var formatCommand: RichTextCommand?
```

Change the editor construction to `RichTextEditor(attributedText: $attributed, command: $formatCommand)`, and put a toolbar above it:

```swift
            if hasEditableBody {
                Divider()

                HStack(spacing: 14) {
                    Spacer()
                    formatButton("bold", .bold, "Bold")
                    formatButton("italic", .italic, "Italic")
                    formatButton("underline", .underline, "Underline")
                    formatButton("strikethrough", .strikethrough, "Strikethrough")
                    formatButton("eraser", .clear, "Clear formatting")
                    Spacer()
                }
                .padding(.vertical, 6)

                RichTextEditor(attributedText: $attributed, command: $formatCommand)
                    .frame(minWidth: 480, minHeight: 280)
            }
```

And the helper:

```swift
    private func formatButton(_ symbol: String,
                              _ command: RichTextCommand,
                              _ help: String) -> some View {
        Button { formatCommand = command } label: {
            Image(systemName: symbol).font(.system(size: 13))
        }
        .buttonStyle(.plain)
        .help(help)
    }
```

- [ ] **Step 7: Build**

Run the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 8: Write down what has to be checked by hand**

- selecionar uma palavra e aplicar negrito, itálico, sublinhado e tachado
- confirmar que o cursor **não** pula para o começo do texto ao aplicar
- limpar formatação e confirmar que o texto continua inteiro
- salvar e reabrir: a formatação persiste

- [ ] **Step 9: Run the full suite**

Expected: everything green.

- [ ] **Step 10: Commit**

```bash
git add MyPasteApp/Services/RichText.swift MyPasteApp/Views/RichTextEditor.swift \
        MyPasteApp/Views/ItemEditorView.swift MyPasteAppTests/RichTextFormatTests.swift
git commit -m "feat(editor): format text from a toolbar"
```

---

### Task 14: Roteiro de verificação, Writing Tools e ROADMAP

**Files:**
- Create: `VERIFICACAO-FASE-6.md`
- Modify: `ROADMAP.md` (documento local, **fora** do commit — ver Global Constraints)

**Interfaces:**
- Consumes: the manual-check notes recorded in Tasks 5, 7, 8, 10, 11 and 13.
- Produces: nothing consumed by code.

- [ ] **Step 1: Write the roteiro**

Create `VERIFICACAO-FASE-6.md`, collecting every "checked by hand" note from the tasks above, in this order:

1. **Live Text primeiro.** Abrir o preview de uma imagem com texto, ligar o Live Text, e confirmar que a overlay embaixo continua aberta. É o risco que pode derrubar o desenho da tarefa 8
2. **Cor:** copiar `#3A86FF`, `rgb(58, 134, 255)` e uma folha de CSS inteira — os dois primeiros mostram amostra, o terceiro não. Capturar uma cor pelo menu e confirmar que o item nasce com o ícone **do nosso app**. Amostrar dentro do preview e confirmar que **nenhum** item novo aparece. Converter pelo submenu e confirmar que aí **nasce** item
3. **Rotação:** girar, salvar e confirmar que o card mostra a imagem girada **sem reiniciar o app**. Girar e cancelar. Girar quatro vezes e salvar — nada muda
4. **Arrastar:** imagem para o Finder, para o Word e para o navegador; texto para um campo de texto; texto formatado para o Word; arquivo para outra pasta. Em cada um, anotar se a overlay fecha ao soltar. Arrasto abandonado não deixa arquivo em `$TMPDIR/MyPasteApp-drags`
5. **Abrir com:** arquivo existente, arquivo apagado (entrada desabilitada com o caminho), URL, e `⌘O` em cada um
6. **Gate de teclado:** com o campo de renomear pinboard aberto, `⌘O` não faz nada
7. **Editor:** contagem no rodapé; negrito, itálico, sublinhado, tachado, limpar; o cursor não pula
8. **Writing Tools (item 22):** abrir o editor com um texto, selecionar, e usar Revisar, Reescrever e Resumir pelo menu de contexto. Registrar o que aparece — este passo **é** a entrega do item 22
9. **Herdados:** o `⌘M` da Fase 4, ainda sem verificação, e o crash do `⌘1`, ainda sem diagnóstico

- [ ] **Step 2: Run the full suite one last time**

Run the complete test command. Expected: everything green. Record the test and suite counts — the phase report cites them.

- [ ] **Step 3: Commit the roteiro**

```bash
git add VERIFICACAO-FASE-6.md
git commit -m "docs(verify): script the manual checks for phase 6"
```

- [ ] **Step 4: Update the ROADMAP (local, not committed)**

In `ROADMAP.md`:

- mark items 20 and 21 as done, with what actually shipped and what didn't
- item 22: record the outcome of Step 1's item 8 — done with evidence, or open with the observed defect
- add the new open items: "Abrir com" for images, share sheet in the preview, `NSFilePromiseProvider` as plan B if the Finder misbehaved, and dragging a card onto a pinboard pill
- add a "O que a Fase 6 descobriu" section, following the shape of phases 1–5

- [ ] **Step 5: Update the Obsidian board**

Move the cards for items 20, 21 and 22 to `🔍 Revisão` and update `status` in each card — board and card together, as CLAUDE.md requires. If the MCP is still unavailable, edit the vault files directly at `~/Documents/Obsidian Vault/MyPasteApp/`; if that fails too, tell the Carlos rather than skipping it.

---

## Depois do plano

Com as 14 tarefas fechadas e a suíte verde, a fase ainda **não** está pronta: falta o Carlos rodar `VERIFICACAO-FASE-6.md` à mão. Só depois disso é que a branch vira PR — e a revisão de branch inteira, que nas cinco fases anteriores achou o que a revisão por tarefa deixou passar, roda antes do merge.
