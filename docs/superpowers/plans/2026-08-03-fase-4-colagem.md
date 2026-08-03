# Fase 4 — Colagem: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Marcar vários itens de texto/URL na overlay, em ordem, e colar os N de uma vez num único destino, concatenados por um separador configurável.

**Architecture:** Uma coleção ordenada de ids (`MarkedSelection`) vive no `OverlayWindowController`, ao lado de `SearchState`, e é limpa a cada abertura da gaveta. As regras — resolver ids contra a lista, decodificar o texto rico de cada item, juntar com separador, registrar uso sem promover — ficam em funções estáticas puras (`MultiPaste`), testáveis sem renderizar view. A escrita no pasteboard ganha um método próprio em `ClipboardWriter`, separado do de item único porque as semânticas de promoção divergem.

**Tech Stack:** Swift 5, SwiftUI + AppKit, SwiftData, Swift Testing, Xcode 26.6, SDK macOS 26.5, deployment target 26.2.

**Spec:** `docs/superpowers/specs/2026-08-03-fase-4-colagem-design.md`

## Global Constraints

- **Branch:** `feature/fase-4-colagem`, criada a partir de `develop`.
- **Arquivos novos entram no alvo sozinhos.** O projeto usa `PBXFileSystemSynchronizedRootGroup` — não há `project.pbxproj` para editar ao criar um arquivo.
- **Comando de teste completo:**
  ```bash
  set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
    -project MyPasteApp.xcodeproj -scheme MyPasteApp \
    -configuration Debug -destination 'platform=macOS'
  ```
- **Uma suíte só:** acrescente `-only-testing:MyPasteAppTests/<NomeDaSuite>` ao comando acima.
- **A suíte cobre lógica pura.** Nada em `Views/` ou `Window/` tem teste automatizado — essas tarefas fecham com verificação manual, não com teste.
- **Commits:** mensagens em inglês, Conventional Commits, blocos por funcionalidade. **Nunca commitar sem autorização explícita do Carlos**, exceto quando ele autorizar a branch inteira da fase. Nunca `git add -A` nem `git add .`: `ROADMAP.md`, `DESIGN.md` e `design-refs/` são documentos de trabalho local, excluídos via `.git/info/exclude`.
- **Board do Obsidian:** ao começar a implementação, mover `[[14 Colagem múltipla]]` para `🛠 Implementando` em `MyPasteApp/Board.md` e atualizar `status` no card, sempre os dois juntos. Se o MCP `mcp-tools-istefox` estiver fora do ar, avisar o Carlos em vez de seguir em silêncio.
- **Idioma da interface:** inglês, como todo o resto do app (`"Launch at login"`, `"Paste items"`).
- **Flake conhecido, não desta fase:** `PauseControllerTests.timedPauseResumesAutomatically()` depende de carga da máquina. Se falhar, rodar isolado antes de investigar.

## Estrutura de arquivos

| Arquivo | Responsabilidade | Tarefa |
|---|---|---|
| `MyPasteApp/Services/MarkedSelection.swift` | **Novo.** A coleção ordenada de ids marcados e suas mutações | 1 |
| `MyPasteApp/Services/MultiPasteSeparator.swift` | **Novo.** Os quatro separadores e a leitura da preferência | 2 |
| `MyPasteApp/Services/MultiPaste.swift` | **Novo.** Gate de tipo, resolução de ids, junção, registro de uso | 3, 4 |
| `MyPasteApp/Services/ClipboardWriter.swift` | Modificado: método novo para escrever o bloco | 5 |
| `MyPasteApp/Services/PreferenceKeys.swift` | Modificado: chave do separador | 6 |
| `MyPasteApp/Views/Preferences/GeneralSettingsView.swift` | Modificado: Picker do separador | 6 |
| `MyPasteApp/Views/OverlayView.swift` | Modificado: `⌘M`, `↵` do bloco, `⌘`+clique, fiação | 7 |
| `MyPasteApp/Window/OverlayWindowController.swift` | Modificado: possui a `MarkedSelection`, limpa em `show()`, `onPickMultiple` | 7 |
| `MyPasteApp/AppDelegate.swift` | Modificado: closure que chama `writeJoined` | 7 |
| `MyPasteApp/Services/SearchState.swift` | Modificado: `hasMarks` e `.clearMarks` na cadeia do `⎋` | 8 |
| `MyPasteApp/Views/ClipboardCardView.swift` | Modificado: chip de ordem | 9 |
| `MyPasteApp/Views/Search/OverlayTopBar.swift` | Modificado: pílula de contagem | 10 |
| `MyPasteApp/Views/ItemContextMenu.swift` | Modificado: entrada Mark/Unmark | 10 |
| `VERIFICACAO-FASE-4.md` | **Novo.** Roteiro de verificação manual | 11 |

Testes novos: `MarkedSelectionTests`, `MultiPasteSeparatorTests`, `MultiPasteTests`, `MultiPasteUsageTests`. Modificados: `PreferenceKeysTests`, `SearchStateTests`.

---

### Task 1: `MarkedSelection`

**Files:**
- Create: `MyPasteApp/Services/MarkedSelection.swift`
- Test: `MyPasteAppTests/MarkedSelectionTests.swift`

**Interfaces:**
- Consumes: nada.
- Produces: `@MainActor final class MarkedSelection` com `ids: [UUID]` (`private(set)`), `isEmpty: Bool`, `count: Int`, `contains(_ id: UUID) -> Bool`, `toggle(_ id: UUID)`, `order(of id: UUID) -> Int?` (1-based), `clear()`.

- [ ] **Step 1: Write the failing test**

Crie `MyPasteAppTests/MarkedSelectionTests.swift`:

```swift
//
//  MarkedSelectionTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Marked selection")
struct MarkedSelectionTests {
    private let a = UUID()
    private let b = UUID()
    private let c = UUID()

    @Test("Marking accumulates in the order it happened")
    func marksInOrder() {
        let selection = MarkedSelection()
        selection.toggle(c)
        selection.toggle(a)
        selection.toggle(b)
        // The order marked is the contract: it's what the pasted block
        // respects, not the order the cards sit in.
        #expect(selection.ids == [c, a, b])
    }

    @Test("Marking the same id twice unmarks it")
    func togglesOff() {
        let selection = MarkedSelection()
        selection.toggle(a)
        selection.toggle(a)
        #expect(selection.isEmpty)
    }

    @Test("Unmarking from the middle renumbers what follows")
    func renumbersAfterRemoval() {
        let selection = MarkedSelection()
        selection.toggle(a)
        selection.toggle(b)
        selection.toggle(c)
        selection.toggle(b)
        // Position 2 must always be the second item that will be pasted.
        #expect(selection.order(of: c) == 2)
        #expect(selection.order(of: b) == nil)
    }

    @Test("Order is 1-based, and nil for an unmarked id")
    func orderIsOneBased() {
        let selection = MarkedSelection()
        selection.toggle(a)
        #expect(selection.order(of: a) == 1)
        #expect(selection.order(of: b) == nil)
    }

    @Test("Contains and count follow the marks")
    func containsAndCount() {
        let selection = MarkedSelection()
        #expect(selection.count == 0)
        selection.toggle(a)
        selection.toggle(b)
        #expect(selection.count == 2)
        #expect(selection.contains(a))
        #expect(!selection.contains(c))
    }

    @Test("Clear empties everything")
    func clearEmpties() {
        let selection = MarkedSelection()
        selection.toggle(a)
        selection.toggle(b)
        selection.clear()
        #expect(selection.isEmpty)
        #expect(selection.ids.isEmpty)
    }
}
```

- [ ] **Step 2: Run the test and confirm it fails**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/MarkedSelectionTests
```

Esperado: falha de compilação — `cannot find 'MarkedSelection' in scope`.

- [ ] **Step 3: Write the implementation**

Crie `MyPasteApp/Services/MarkedSelection.swift`:

```swift
//
//  MarkedSelection.swift
//  MyPasteApp
//

import Foundation
import SwiftUI

/// The items marked for a multi-item paste, in the order they were marked.
///
/// Owned by `OverlayWindowController`, not by `OverlayView` — the same
/// arrangement, and for the same reason, as `SearchState`: the overlay is
/// built once in `prepare()` and reused for the life of the process, so state
/// held in `@State` would outlive the drawer being closed and the next opening
/// would come back with last time's marks still on.
///
/// Holds ids rather than `ClipboardItem` references on purpose. Those are
/// `@Model` objects the context can delete at any time; a strong reference
/// here would keep a deleted item alive inside an invisible list. With ids, an
/// item deleted while marked simply isn't found at resolve time and drops out
/// of the block on its own — see `MultiPaste.resolve`.
@Observable
@MainActor
final class MarkedSelection {
    /// Ids in the order they were marked. That order is the contract: it's
    /// what the pasted block respects, and where the card's chip number comes
    /// from.
    private(set) var ids: [UUID] = []

    var isEmpty: Bool { ids.isEmpty }
    var count: Int { ids.count }

    func contains(_ id: UUID) -> Bool { ids.contains(id) }

    /// Marks at the end of the queue, or unmarks.
    ///
    /// Unmarking from the middle renumbers everything after it, which is the
    /// correct behaviour: position 2 always means the second item that will be
    /// pasted, never a frozen label.
    func toggle(_ id: UUID) {
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.append(id)
        }
    }

    /// 1-based position for the card's chip, or nil when not marked.
    func order(of id: UUID) -> Int? {
        ids.firstIndex(of: id).map { $0 + 1 }
    }

    func clear() { ids.removeAll() }
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Mesmo comando do Step 2. Esperado: 6 testes passando.

- [ ] **Step 5: Commit**

```bash
git add MyPasteApp/Services/MarkedSelection.swift MyPasteAppTests/MarkedSelectionTests.swift
git commit -m "feat(multi-paste): add the ordered marked selection"
```

---

### Task 2: `MultiPasteSeparator`

**Files:**
- Create: `MyPasteApp/Services/MultiPasteSeparator.swift`
- Test: `MyPasteAppTests/MultiPasteSeparatorTests.swift`

**Interfaces:**
- Consumes: nada.
- Produces: `enum MultiPasteSeparator: String, CaseIterable, Identifiable` com casos `newline`, `blankLine`, `space`, `comma`; propriedades `text: String`, `label: String`, `id: String`; e `static func resolve(_ raw: String?) -> MultiPasteSeparator`.

- [ ] **Step 1: Write the failing test**

Crie `MyPasteAppTests/MultiPasteSeparatorTests.swift`:

```swift
//
//  MultiPasteSeparatorTests.swift
//  MyPasteAppTests
//

import Testing

@testable import MyPasteApp

@Suite("Multi-paste separator")
struct MultiPasteSeparatorTests {
    @Test("Each case carries the text it inserts")
    func textPerCase() {
        #expect(MultiPasteSeparator.newline.text == "\n")
        #expect(MultiPasteSeparator.blankLine.text == "\n\n")
        #expect(MultiPasteSeparator.space.text == " ")
        #expect(MultiPasteSeparator.comma.text == ", ")
    }

    @Test("Every case has a label and they're all distinct")
    func labelsAreDistinct() {
        let labels = MultiPasteSeparator.allCases.map(\.label)
        #expect(labels.allSatisfy { !$0.isEmpty })
        #expect(Set(labels).count == labels.count)
    }

    @Test("A stored value round-trips")
    func roundTrips() {
        for separator in MultiPasteSeparator.allCases {
            #expect(MultiPasteSeparator.resolve(separator.rawValue) == separator)
        }
    }

    @Test("Missing or unknown values fall back to a new line")
    func fallsBackToDefault() {
        // The unknown case isn't hypothetical: a rawValue written by a later
        // version and then rolled back lands here, and must not crash or
        // silently produce an empty separator.
        #expect(MultiPasteSeparator.resolve(nil) == .newline)
        #expect(MultiPasteSeparator.resolve("") == .newline)
        #expect(MultiPasteSeparator.resolve("semicolon") == .newline)
    }
}
```

- [ ] **Step 2: Run the test and confirm it fails**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/MultiPasteSeparatorTests
```

Esperado: falha de compilação — `cannot find 'MultiPasteSeparator' in scope`.

- [ ] **Step 3: Write the implementation**

Crie `MyPasteApp/Services/MultiPasteSeparator.swift`:

```swift
//
//  MultiPasteSeparator.swift
//  MyPasteApp
//

import Foundation

/// What goes between two items of a multi-item paste.
///
/// A closed set of named options rather than a free-text field: free text
/// would mean validating input and deciding how to show `\n` in a settings
/// row, for a flexibility nobody asked for yet.
enum MultiPasteSeparator: String, CaseIterable, Identifiable {
    case newline
    case blankLine
    case space
    case comma

    var id: String { rawValue }

    /// What actually gets inserted between two items.
    var text: String {
        switch self {
        case .newline:   return "\n"
        case .blankLine: return "\n\n"
        case .space:     return " "
        case .comma:     return ", "
        }
    }

    var label: String {
        switch self {
        case .newline:   return "New line"
        case .blankLine: return "Blank line"
        case .space:     return "Space"
        case .comma:     return "Comma"
        }
    }

    /// Reads the stored preference, falling back to the default for a missing
    /// or unrecognised value — including a `rawValue` written by a later
    /// version and then rolled back.
    static func resolve(_ raw: String?) -> MultiPasteSeparator {
        raw.flatMap(MultiPasteSeparator.init(rawValue:)) ?? .newline
    }
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Mesmo comando do Step 2. Esperado: 4 testes passando.

- [ ] **Step 5: Commit**

```bash
git add MyPasteApp/Services/MultiPasteSeparator.swift MyPasteAppTests/MultiPasteSeparatorTests.swift
git commit -m "feat(multi-paste): add the separator options"
```

---

### Task 3: `MultiPaste` — gate de tipo, resolução e junção

**Files:**
- Create: `MyPasteApp/Services/MultiPaste.swift`
- Test: `MyPasteAppTests/MultiPasteTests.swift`

**Interfaces:**
- Consumes: `MultiPasteSeparator` (Task 2); `ClipboardItem`, `ClipboardItemType` (existentes).
- Produces: `enum MultiPaste` com `static func isMarkable(_ type: ClipboardItemType) -> Bool`, `static func resolve(ids: [UUID], in items: [ClipboardItem]) -> [ClipboardItem]`, `static func joined(_ pieces: [NSAttributedString], separator: MultiPasteSeparator) -> NSAttributedString`.

- [ ] **Step 1: Write the failing test**

Crie `MyPasteAppTests/MultiPasteTests.swift`:

```swift
//
//  MultiPasteTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Multi-paste")
final class MultiPasteTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @discardableResult
    private func item(_ text: String, type: ClipboardItemType = .text) -> ClipboardItem {
        let item = ClipboardItem(type: type, preview: text, contentHash: text, textContent: text)
        container.mainContext.insert(item)
        return item
    }

    // MARK: - Type gate

    @Test("Only text and URL can be marked")
    func markableTypes() {
        #expect(MultiPaste.isMarkable(.text))
        #expect(MultiPaste.isMarkable(.url))
        #expect(!MultiPaste.isMarkable(.image))
        #expect(!MultiPaste.isMarkable(.file))
    }

    // MARK: - Resolution

    @Test("Resolves in the order marked, not the order of the list")
    func resolveFollowsMarkOrder() {
        let first = item("one")
        let second = item("two")
        let third = item("three")
        let resolved = MultiPaste.resolve(ids: [third.id, first.id],
                                          in: [first, second, third])
        #expect(resolved.map(\.id) == [third.id, first.id])
    }

    @Test("An id with no item left is dropped")
    func resolveDropsMissing() {
        // This is how an item deleted while marked leaves the block: no
        // reactive cleanup anywhere, it just isn't found.
        let present = item("here")
        let resolved = MultiPaste.resolve(ids: [UUID(), present.id], in: [present])
        #expect(resolved.map(\.id) == [present.id])
    }

    @Test("No marks and no items both resolve to nothing")
    func resolveEmptyCases() {
        let present = item("here")
        #expect(MultiPaste.resolve(ids: [], in: [present]).isEmpty)
        #expect(MultiPaste.resolve(ids: [present.id], in: []).isEmpty)
    }

    // MARK: - Joining

    @Test("Joins three pieces with the separator between them")
    func joinsThree() {
        let pieces = ["a", "b", "c"].map { NSAttributedString(string: $0) }
        #expect(MultiPaste.joined(pieces, separator: .newline).string == "a\nb\nc")
    }

    @Test("No separator before the first or after the last")
    func noTrailingSeparator() {
        let pieces = ["a", "b"].map { NSAttributedString(string: $0) }
        let result = MultiPaste.joined(pieces, separator: .comma).string
        #expect(result == "a, b")
        #expect(!result.hasPrefix(", "))
        #expect(!result.hasSuffix(", "))
    }

    @Test("One piece comes back untouched, zero pieces come back empty")
    func degenerateCases() {
        let single = [NSAttributedString(string: "only")]
        #expect(MultiPaste.joined(single, separator: .blankLine).string == "only")
        #expect(MultiPaste.joined([], separator: .newline).string == "")
    }

    @Test("Each separator produces its own text")
    func everySeparator() {
        let pieces = ["a", "b"].map { NSAttributedString(string: $0) }
        #expect(MultiPaste.joined(pieces, separator: .newline).string == "a\nb")
        #expect(MultiPaste.joined(pieces, separator: .blankLine).string == "a\n\nb")
        #expect(MultiPaste.joined(pieces, separator: .space).string == "a b")
        #expect(MultiPaste.joined(pieces, separator: .comma).string == "a, b")
    }

    @Test("The separator carries no attributes of its own")
    func separatorIsUnstyled() {
        // Inheriting the previous piece's attributes would make the break
        // carry the font and colour of the text above it, so the block would
        // change appearance depending on the order things were marked.
        let styled = NSAttributedString(string: "a",
                                        attributes: [.foregroundColor: NSColor.red])
        let plain = NSAttributedString(string: "b")
        let joined = MultiPaste.joined([styled, plain], separator: .newline)
        var range = NSRange(location: 0, length: 0)
        let attributes = joined.attributes(at: 1, effectiveRange: &range)
        #expect(attributes[.foregroundColor] == nil)
    }
}
```

- [ ] **Step 2: Run the test and confirm it fails**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/MultiPasteTests
```

Esperado: falha de compilação — `cannot find 'MultiPaste' in scope`.

- [ ] **Step 3: Write the implementation**

Crie `MyPasteApp/Services/MultiPaste.swift`:

```swift
//
//  MultiPaste.swift
//  MyPasteApp
//
//  The rules behind pasting several items as one block: which types qualify,
//  which marked ids still have an item, and how the pieces are joined.
//
//  Everything that doesn't touch a `ClipboardItem` or AppKit is left without
//  actor isolation, which is what keeps the bulk of this testable without a
//  view — the same shape as `ItemSearch` and `RichText`.
//

import AppKit
import Foundation

enum MultiPaste {
    /// The types that can go into a block. Same gate `⌘E` uses to decide what
    /// is editable as text.
    static func isMarkable(_ type: ClipboardItemType) -> Bool {
        type == .text || type == .url
    }

    /// Resolves marked ids against the current list, **in the order marked**.
    ///
    /// Ids with no matching item are dropped silently: that's how an item
    /// deleted while marked leaves the block without any reactive cleanup in
    /// `MarkedSelection`. Indexes `items` once instead of scanning it per id.
    static func resolve(ids: [UUID], in items: [ClipboardItem]) -> [ClipboardItem] {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    /// Joins the pieces, with an unstyled separator between them.
    ///
    /// The separator deliberately carries no attributes: inheriting the
    /// previous piece's would make the break take on the font and colour of
    /// the text above it, and the block would look different depending on the
    /// order things were marked in.
    static func joined(_ pieces: [NSAttributedString],
                       separator: MultiPasteSeparator) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, piece) in pieces.enumerated() {
            if index > 0 { result.append(NSAttributedString(string: separator.text)) }
            result.append(piece)
        }
        return result
    }
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Mesmo comando do Step 2. Esperado: 8 testes passando.

- [ ] **Step 5: Commit**

```bash
git add MyPasteApp/Services/MultiPaste.swift MyPasteAppTests/MultiPasteTests.swift
git commit -m "feat(multi-paste): add the type gate, id resolution and joining"
```

---

### Task 4: `MultiPaste.attributed` e `markUsed`

O texto rico de cada item e o registro de uso. São as duas partes que tocam
`ClipboardItem`, e a razão de estarem juntas: as duas são o que `writeJoined`
(Task 5) chama antes de escrever no pasteboard.

**Files:**
- Modify: `MyPasteApp/Services/MultiPaste.swift`
- Test: `MyPasteAppTests/MultiPasteUsageTests.swift`

**Interfaces:**
- Consumes: `RichText.decode(data:format:)` (existente), `ClipboardItem` (existente).
- Produces: `@MainActor static func attributed(for item: ClipboardItem) -> NSAttributedString`, `@MainActor static func markUsed(_ items: [ClipboardItem], now: Date)`.

- [ ] **Step 1: Write the failing test**

Crie `MyPasteAppTests/MultiPasteUsageTests.swift`:

```swift
//
//  MultiPasteUsageTests.swift
//  MyPasteAppTests
//

import AppKit
import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Multi-paste item reading and usage")
final class MultiPasteUsageTests {
    private let container: ModelContainer
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @discardableResult
    private func item(_ text: String,
                      richTextData: Data? = nil,
                      richTextFormat: RichTextFormat? = nil,
                      createdAt: Date? = nil) -> ClipboardItem {
        let item = ClipboardItem(
            type: .text, preview: text, contentHash: text,
            textContent: text, richTextData: richTextData, richTextFormat: richTextFormat
        )
        if let createdAt { item.createdAt = createdAt }
        container.mainContext.insert(item)
        return item
    }

    /// RTF bytes for a piece of text, produced the same way `ItemEdit.apply`
    /// produces them.
    private func rtf(_ text: String) throws -> Data {
        let attributed = NSAttributedString(string: text)
        return try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    // MARK: - Reading

    @Test("An item with no rich text comes back as its plain text")
    func plainItem() {
        #expect(MultiPaste.attributed(for: item("hello")).string == "hello")
    }

    @Test("An item with RTF comes back decoded")
    func richItem() throws {
        let subject = item("styled", richTextData: try rtf("styled"), richTextFormat: .rtf)
        #expect(MultiPaste.attributed(for: subject).string == "styled")
    }

    @Test("An item captured as HTML is decoded as HTML, not as RTF")
    func htmlItem() {
        // The format is dispatched on, never guessed. Decoding HTML bytes as
        // RTF returns nil in silence — the Phase 2 bug — and this item would
        // quietly lose its markup on the way into the block.
        let subject = item("bold",
                           richTextData: Data("<b>bold</b>".utf8),
                           richTextFormat: .html)
        #expect(MultiPaste.attributed(for: subject).string == "bold")
    }

    @Test("Undecodable rich text falls back to the plain text, never to empty")
    func brokenRichTextFallsBack() {
        // Claiming RTF while holding bytes that aren't RTF is exactly the shape
        // of the Phase 2 bug where a HTML-only capture was decoded as RTF,
        // returned nil in silence, and the empty result was written back over
        // the original. Falling back to empty here would drop the item out of
        // the block with no error.
        let subject = item("fallback",
                           richTextData: Data([0x00, 0x01, 0x02]),
                           richTextFormat: .rtf)
        #expect(MultiPaste.attributed(for: subject).string == "fallback")
    }

    @Test("An item with neither rich text nor plain text comes back empty")
    func emptyItem() {
        let subject = ClipboardItem(type: .text, preview: "", contentHash: "x")
        container.mainContext.insert(subject)
        #expect(MultiPaste.attributed(for: subject).string == "")
    }

    // MARK: - Usage

    @Test("Marking used writes lastUsedAt and leaves createdAt alone")
    func markUsedDoesNotPromote() {
        // The whole point of the multi-paste path: pasting five items must not
        // reorder the history, and must not shift the ⌘1–⌘9 numbering with it.
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        let first = item("one", createdAt: old)
        let second = item("two", createdAt: old)

        MultiPaste.markUsed([first, second], now: now)

        #expect(first.createdAt == old)
        #expect(second.createdAt == old)
        #expect(first.lastUsedAt == now)
        #expect(second.lastUsedAt == now)
    }

    @Test("Marking an empty list used does nothing and doesn't crash")
    func markUsedEmpty() {
        MultiPaste.markUsed([], now: now)
    }
}
```

- [ ] **Step 2: Run the test and confirm it fails**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/MultiPasteUsageTests
```

Esperado: falha de compilação — `type 'MultiPaste' has no member 'attributed'`.

- [ ] **Step 3: Write the implementation**

Acrescente ao final de `enum MultiPaste`, em `MyPasteApp/Services/MultiPaste.swift`:

```swift
    /// The rich representation of an item, ready to go into a block.
    ///
    /// Dispatches on the stored `richTextFormat` and **never guesses**:
    /// decoding an HTML-only capture as RTF returns nil in silence, which is
    /// how Phase 2 lost formatting in the editor. A decode failure falls back
    /// to the plain text — never to empty, which would drop the item out of
    /// the block with nothing to show for it.
    ///
    /// Main-actor bound because AppKit's HTML importer requires it, which
    /// `RichText.decode` documents.
    @MainActor
    static func attributed(for item: ClipboardItem) -> NSAttributedString {
        let plain = item.textContent ?? ""
        guard let data = item.richTextData,
              let format = item.richTextFormat,
              let decoded = RichText.decode(data: data, format: format)
        else { return NSAttributedString(string: plain) }
        return decoded
    }

    /// Records that these items were used, **without promoting them**.
    ///
    /// This is the one paste path in the app that doesn't rewrite `createdAt`.
    /// Doing so for N items at once would throw the whole block to the front
    /// of the history and shift the ⌘1–⌘9 numbering along with it. `lastUsedAt`
    /// exists to record use without touching order — see the note at the top
    /// of ROADMAP.md about the two fields.
    ///
    /// Takes `now` rather than reading the clock so the rule can be tested
    /// against a fixed instant.
    @MainActor
    static func markUsed(_ items: [ClipboardItem], now: Date) {
        guard !items.isEmpty else { return }
        for item in items { item.lastUsedAt = now }
        try? items.first?.modelContext?.save()
    }
```

- [ ] **Step 4: Run the test and confirm it passes**

Mesmo comando do Step 2. Esperado: 7 testes passando.

- [ ] **Step 5: Commit**

```bash
git add MyPasteApp/Services/MultiPaste.swift MyPasteAppTests/MultiPasteUsageTests.swift
git commit -m "feat(multi-paste): read rich text per item and record use without promoting"
```

---

### Task 5: `ClipboardWriter.writeJoined`

**Files:**
- Modify: `MyPasteApp/Services/ClipboardWriter.swift`

**Interfaces:**
- Consumes: `MultiPaste.attributed(for:)`, `MultiPaste.joined(_:separator:)`, `MultiPaste.markUsed(_:now:)` (Tasks 3–4); `MultiPasteSeparator` (Task 2).
- Produces: `func writeJoined(_ items: [ClipboardItem], separator: MultiPasteSeparator, plainText: Bool)`.

**Sem teste automatizado nesta tarefa.** `writeJoined` escreve em
`NSPasteboard.general`, que é o pasteboard real do usuário — um teste o
sobrescreveria. Tudo que é decidível já está coberto: a junção na Task 3, a
leitura por item e o `lastUsedAt` na Task 4. O que resta aqui é fiação, e fecha
na verificação manual (Task 11).

- [ ] **Step 1: Write the implementation**

Acrescente a `ClipboardWriter`, depois de `write(_:plainText:)`:

```swift
    /// Writes several items to the pasteboard as a single block.
    ///
    /// Deliberately **not** a parameter on `write(_:plainText:)`. The two
    /// diverge on exactly what they save: `write` promotes to the top by
    /// rewriting `createdAt`, this one doesn't touch `createdAt` at all. Phase
    /// 2 already paid once for folding two saves with different semantics into
    /// one routine — that was the near-miss corruption that split
    /// `ItemEdit.apply` from `ItemEdit.applyLabel`.
    ///
    /// `ignoreNextChange` still suffices: this is one write, not a loop. It's
    /// also why there's no `pasteDelayMs` between items — there's a single ⌘V.
    func writeJoined(_ items: [ClipboardItem],
                     separator: MultiPasteSeparator,
                     plainText: Bool) {
        guard !items.isEmpty else { return }
        let pb = NSPasteboard.general
        monitor?.ignoreNextChange = true
        pb.clearContents()

        MultiPaste.markUsed(items, now: .now)

        // Closure rather than `items.map(MultiPaste.attributed(for:))`: passing
        // a `@MainActor` method as a function value drops the global actor and
        // fails to compile. A closure inherits the isolation instead.
        let joined = MultiPaste.joined(items.map { MultiPaste.attributed(for: $0) },
                                       separator: separator)
        // Always RTF for the block, even when the sources were HTML: it's the
        // format `ItemEdit.apply` already writes, and it avoids having to pick
        // a winner between heterogeneous sources.
        if !plainText,
           let rtf = try? joined.data(
               from: NSRange(location: 0, length: joined.length),
               documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            pb.setData(rtf, forType: .rtf)
        }
        // Always present, even alongside RTF: a pasteboard carrying only RTF
        // breaks pasting into any plain text field. Same rule as
        // `RichText.payload`.
        pb.setData(Data(joined.string.utf8), forType: .string)
    }
```

- [ ] **Step 2: Run the full suite and confirm nothing broke**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Esperado: a suíte inteira verde. Nada aqui muda comportamento existente — o
método é novo e ainda não tem chamador.

- [ ] **Step 3: Commit**

```bash
git add MyPasteApp/Services/ClipboardWriter.swift
git commit -m "feat(multi-paste): write several items to the pasteboard as one block"
```

---

### Task 6: Preferência do separador

**Files:**
- Modify: `MyPasteApp/Services/PreferenceKeys.swift`
- Modify: `MyPasteApp/Views/Preferences/GeneralSettingsView.swift`
- Modify: `MyPasteAppTests/PreferenceKeysTests.swift`

**Interfaces:**
- Consumes: `MultiPasteSeparator` (Task 2).
- Produces: `PreferenceKeys.multiPasteSeparator` (`"multiPasteSeparator"`).

- [ ] **Step 1: Write the failing test**

Em `MyPasteAppTests/PreferenceKeysTests.swift`, acrescente uma linha ao final do
corpo de `keysAreFrozen()`, depois da linha de `enableImageOCR`:

```swift
        #expect(PreferenceKeys.multiPasteSeparator == "multiPasteSeparator")
```

- [ ] **Step 2: Run the test and confirm it fails**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/PreferenceKeysTests
```

Esperado: falha de compilação — `type 'PreferenceKeys' has no member 'multiPasteSeparator'`.

- [ ] **Step 3: Add the key**

Em `MyPasteApp/Services/PreferenceKeys.swift`, depois de `enableImageOCR`:

```swift
    /// How items of a multi-item paste are separated. New line by default.
    static let multiPasteSeparator = "multiPasteSeparator"
```

E acrescente `multiPasteSeparator` ao array `all`, no fim da última linha:

```swift
    static let all: [String] = [
        maxItems, retentionDays, previewTextLength, enableSoundFeedback,
        ignoredAppsRaw, autoPasteEnabled, pasteDelayMs, showLinkPreviews,
        cardDensity, showQuickPasteNumbers, showInScreenSharing,
        ignoreConcealedContent, ignoreTransientContent,
        ignoreAutoGeneratedContent, alwaysPastePlainText, enableImageOCR,
        multiPasteSeparator,
    ]
```

- [ ] **Step 4: Run the test and confirm it passes**

Mesmo comando do Step 2. Esperado: 2 testes passando (`keysAreFrozen` e `keysAreUnique`).

- [ ] **Step 5: Add the picker**

Em `MyPasteApp/Views/Preferences/GeneralSettingsView.swift`, acrescente a
propriedade junto das outras `@AppStorage`:

```swift
    @AppStorage(PreferenceKeys.multiPasteSeparator) private var multiPasteSeparatorRaw: String = MultiPasteSeparator.newline.rawValue
```

E, dentro da `Section("Paste items")`, depois do `SettingsToggle` de
"Always paste as plain text":

```swift
                Divider()
                Picker("Separate multiple items with",
                       selection: $multiPasteSeparatorRaw) {
                    ForEach(MultiPasteSeparator.allCases) { separator in
                        Text(separator.label).tag(separator.rawValue)
                    }
                }
                Text("Used when several marked items are pasted together with ↵.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
```

O `@AppStorage` guarda o `rawValue` como `String`, não o enum: `MultiPasteSeparator`
não é `RawRepresentable`-compatível com `@AppStorage` sem conformidade extra, e
guardar a string é o que `cardDensity` já faz. Quem lê usa
`MultiPasteSeparator.resolve(_:)`, que cobre valor ausente e desconhecido.

- [ ] **Step 6: Run the full suite and confirm nothing broke**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Esperado: suíte inteira verde.

- [ ] **Step 7: Commit**

```bash
git add MyPasteApp/Services/PreferenceKeys.swift \
        MyPasteApp/Views/Preferences/GeneralSettingsView.swift \
        MyPasteAppTests/PreferenceKeysTests.swift
git commit -m "feat(multi-paste): add the separator preference"
```

---

### Task 7: Fiação — `⌘M`, `↵` do bloco, `⌘`+clique e o dono da marcação

A tarefa que junta tudo. Sem teste automatizado: é toda em `Views/` e
`Window/`, que a suíte não cobre por decisão do projeto. Fecha na verificação
manual (Task 11).

**Files:**
- Modify: `MyPasteApp/Window/OverlayWindowController.swift`
- Modify: `MyPasteApp/Views/OverlayView.swift`
- Modify: `MyPasteApp/AppDelegate.swift`

**Interfaces:**
- Consumes: `MarkedSelection` (Task 1), `MultiPaste` (Tasks 3–4), `ClipboardWriter.writeJoined` (Task 5), `PreferenceKeys.multiPasteSeparator` (Task 6).
- Produces: `OverlayView.marked: MarkedSelection`, `OverlayView.onPickMultiple: ([ClipboardItem], Bool) -> Void`. **A Task 8 depende das duas** — é o que permite que o `⎋` chegue já com `marked` disponível, sem placeholder.

**Não toque no handler de `⎋` nesta tarefa.** Ele é inteiro da Task 8, que muda
a assinatura de `escapeAction` e liga o caso novo de uma vez só.

- [ ] **Step 1: Give the controller the marked selection**

Em `MyPasteApp/Window/OverlayWindowController.swift`, ao lado da propriedade
`searchState`, acrescente:

```swift
    /// Owned here, not by `OverlayView`, for the same reason `searchState` is:
    /// the overlay is built once and reused for the life of the process.
    private let markedSelection = MarkedSelection()
```

Acrescente `onPickMultiple` à propriedade e ao `init`, espelhando `onPick`:

```swift
    private let onPickMultiple: ([ClipboardItem], Bool) -> Void
```

Em `show()`, logo depois de `searchState.close()`:

```swift
        // Every opening starts with nothing marked. Same single point of reset
        // as the search, covering all three ways the drawer goes away —
        // Escape, a paste (`hideImmediately`), and a click outside — none of
        // which run any teardown inside `OverlayView`.
        markedSelection.clear()
```

- [ ] **Step 2: Wire the new closure in `prepare()`**

Na construção do `OverlayView` em `prepare()`, passe `marked: markedSelection` e
acrescente o closure novo, com o mesmo corpo de janela do `onPick`:

```swift
            onPickMultiple: { [weak self] items, plainText in
                guard let self else { return }
                self.onPickMultiple(items, plainText)
                let target = self.previousApp
                // Not `hide()`, for the same reason `onPick` isn't: its 0.18s
                // fade outlives the paste delay, and the panel would still be
                // key when the synthetic ⌘V arrives.
                self.hideImmediately()
                let autoPaste = UserDefaults.standard.object(forKey: PreferenceKeys.autoPasteEnabled) as? Bool ?? true
                if autoPaste {
                    let delayMs = UserDefaults.standard.object(forKey: PreferenceKeys.pasteDelayMs) as? Int ?? 50
                    PasteSimulator.paste(activating: target, delay: Double(delayMs) / 1000.0)
                }
            },
```

- [ ] **Step 3: Wire the AppDelegate**

Em `MyPasteApp/AppDelegate.swift`, na construção do `OverlayWindowController`,
acrescente o parâmetro novo ao lado do `onPick` existente:

```swift
            onPickMultiple: { [weak self] items, plainText in
                let separator = MultiPasteSeparator.resolve(
                    UserDefaults.standard.string(forKey: PreferenceKeys.multiPasteSeparator))
                self?.writer.writeJoined(items, separator: separator, plainText: plainText)
            },
```

- [ ] **Step 4: Add the properties to `OverlayView`**

Em `MyPasteApp/Views/OverlayView.swift`, ao lado de `let search: SearchState`:

```swift
    /// Owned by `OverlayWindowController`, like `search` and for the same
    /// reason. The controller clears it on every `show()`.
    let marked: MarkedSelection
    let onPickMultiple: ([ClipboardItem], Bool) -> Void
```

Acrescente os dois ao `init`, na mesma ordem, e atribua-os no corpo.

- [ ] **Step 5: Add the `⌘M` handler**

Junto dos outros `onKeyPress`, depois do handler de `⌘P`:

```swift
        // Marks the selected card for a multi-item paste. Only "m" lowercase:
        // with no ⇧ in the combination there's no uppercase variant to
        // register — the trap that left ⌘⇧K silently dead in Phase 2 — and
        // with no ⌥ there's no layout-dependent alternate character either.
        .onKeyPress(keys: ["m"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            guard let item = filtered.first(where: { $0.id == selectedID }),
                  MultiPaste.isMarkable(item.type) else { return .ignored }
            marked.toggle(item.id)
            return .handled
        }
```

- [ ] **Step 6: Add `pickMultiple` next to `pick`**

Junto de `private func pick(_:plainText:)`:

```swift
    /// The block counterpart of `pick`.
    ///
    /// Doesn't go through `ItemActions`: that type is "everything you can do
    /// to **one** item", and its `paste` records `lastUsedAt` for a single
    /// item. The N-item bookkeeping happens inside `writeJoined`, in one
    /// place — see `MultiPaste.markUsed`.
    private func pickMultiple(_ items: [ClipboardItem], plainText: Bool) {
        onPickMultiple(items, plainText)
    }
```

- [ ] **Step 7: Teach `↵` about the block**

Substitua o corpo do `.onKeyPress(.return, phases: .down)` por:

```swift
        .onKeyPress(.return, phases: .down) { press in
            let plain = ItemActions.resolvePastePlainText(
                alwaysPlainText: alwaysPastePlainText,
                shiftHeld: press.modifiers.contains(.shift)
            )
            // With marks live, they *are* the selection — the same way ↵ in
            // the Finder acts on what's selected. Resolved against `items`,
            // the full list, never `filtered`: marks survive the search by
            // design, and resolving against the filtered list would make the
            // block shrink on its own as the user typed.
            if !marked.isEmpty {
                let block = MultiPaste.resolve(ids: marked.ids, in: items)
                guard !block.isEmpty else { return .ignored }
                pickMultiple(block, plainText: plain)
                return .handled
            }
            guard let item = filtered.first(where: { $0.id == selectedID }) else {
                return .ignored
            }
            pick(item, plainText: plain)
            return .handled
        }
```

- [ ] **Step 8: Teach the click about ⌘**

Substitua o `.onTapGesture { pick(item) }` do card por:

```swift
                                .onTapGesture {
                                    // `onTapGesture` doesn't report modifiers,
                                    // so ⌘ is read from the current event at
                                    // the moment of the click — the same shape
                                    // `pastesPlainText` already uses for ⇧.
                                    if NSEvent.modifierFlags.contains(.command),
                                       MultiPaste.isMarkable(item.type) {
                                        marked.toggle(item.id)
                                    } else {
                                        pick(item)
                                    }
                                }
```

- [ ] **Step 9: Run the full suite**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Esperado: suíte inteira verde. Se `PauseControllerTests.timedPauseResumesAutomatically()`
falhar, rode-a isolada antes de investigar — é o flake pré-existente.

- [ ] **Step 10: Commit**

```bash
git add MyPasteApp/Views/OverlayView.swift \
        MyPasteApp/Window/OverlayWindowController.swift \
        MyPasteApp/AppDelegate.swift
git commit -m "feat(multi-paste): mark with ⌘M or ⌘-click and paste the block with ↵"
```

---

### Task 8: `⎋` ganha o degrau da marcação

**Files:**
- Modify: `MyPasteApp/Services/SearchState.swift`
- Modify: `MyPasteApp/Views/OverlayView.swift` (só o call site de `escapeAction`)
- Modify: `MyPasteAppTests/SearchStateTests.swift`

**Interfaces:**
- Consumes: `OverlayView.marked: MarkedSelection` (Task 7) — já ligada e disponível no `body`, que é por que esta tarefa vem depois da fiação e não antes.
- Produces: `SearchState.EscapeAction.clearMarks`; `escapeAction` passa a receber `hasMarks: Bool` como último parâmetro.

**Atenção:** mudar a assinatura quebra o call site em `OverlayView` e todos os
testes existentes de `escapeAction`. Os dois entram nesta tarefa, e o call site
já pode passar o valor real — não há placeholder a deixar para trás.

- [ ] **Step 1: Write the failing test**

Em `MyPasteAppTests/SearchStateTests.swift`, dentro da suíte existente,
acrescente:

```swift
    @Test("Marks are cleared before the drawer closes")
    func escapeClearsMarksBeforeDismissing() {
        #expect(SearchState.escapeAction(isFilterPanelOpen: false,
                                         isPreviewOpen: false,
                                         isActive: false,
                                         hasContent: false,
                                         hasMarks: true) == .clearMarks)
    }

    @Test("With nothing marked, escape still closes the drawer")
    func escapeDismissesWithoutMarks() {
        #expect(SearchState.escapeAction(isFilterPanelOpen: false,
                                         isPreviewOpen: false,
                                         isActive: false,
                                         hasContent: false,
                                         hasMarks: false) == .dismissOverlay)
    }

    @Test("Marks wait their turn behind the filter panel, the preview and the search")
    func escapeOrderingWithMarks() {
        // Always the most volatile thing first — the rule this function
        // already followed before marks existed.
        #expect(SearchState.escapeAction(isFilterPanelOpen: true,
                                         isPreviewOpen: false,
                                         isActive: false,
                                         hasContent: false,
                                         hasMarks: true) == .closeFilterPanel)
        #expect(SearchState.escapeAction(isFilterPanelOpen: false,
                                         isPreviewOpen: true,
                                         isActive: false,
                                         hasContent: false,
                                         hasMarks: true) == .hidePreview)
        #expect(SearchState.escapeAction(isFilterPanelOpen: false,
                                         isPreviewOpen: false,
                                         isActive: true,
                                         hasContent: true,
                                         hasMarks: true) == .closeSearch)
    }
```

Acrescente também `hasMarks: false` a **todas** as chamadas de `escapeAction`
que já existem no arquivo — elas param de compilar sem isso.

- [ ] **Step 2: Run the test and confirm it fails**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/SearchStateTests
```

Esperado: falha de compilação — `extra argument 'hasMarks' in call`.

- [ ] **Step 3: Write the implementation**

Em `MyPasteApp/Services/SearchState.swift`, acrescente o caso ao enum:

```swift
    enum EscapeAction: Equatable {
        case closeFilterPanel
        case hidePreview
        case closeSearch
        /// Drop the multi-paste marks, leaving the drawer open.
        case clearMarks
        case dismissOverlay
    }
```

E substitua `escapeAction` por:

```swift
    /// Dismiss what's on top first, as the system does everywhere else.
    ///
    /// An empty search is skipped on purpose: making the user press escape
    /// twice to close a field they never typed into would tax the common case
    /// to serve the rare one.
    ///
    /// Marks come after the search: with both live, the first escape lets go
    /// of the search, the second clears the marks, the third closes the
    /// drawer — most volatile first, all the way down.
    static func escapeAction(isFilterPanelOpen: Bool,
                             isPreviewOpen: Bool,
                             isActive: Bool,
                             hasContent: Bool,
                             hasMarks: Bool) -> EscapeAction {
        if isFilterPanelOpen { return .closeFilterPanel }
        if isPreviewOpen { return .hidePreview }
        if isActive, hasContent { return .closeSearch }
        if hasMarks { return .clearMarks }
        return .dismissOverlay
    }
```

- [ ] **Step 4: Fix the call site in `OverlayView`**

Em `MyPasteApp/Views/OverlayView.swift`, no handler `.onKeyPress(.escape)`,
acrescente `hasMarks: !marked.isEmpty` à chamada e trate o caso novo no `switch`:

```swift
        case .clearMarks:
            marked.clear()
            return .handled
```

`marked` já existe na view desde a Task 7, então o valor real vai direto — nada
provisório aqui.

- [ ] **Step 5: Run the test and confirm it passes**

Mesmo comando do Step 2. Esperado: a suíte de `SearchState` verde, incluindo os
3 testes novos.

- [ ] **Step 6: Commit**

```bash
git add MyPasteApp/Services/SearchState.swift \
        MyPasteApp/Views/OverlayView.swift \
        MyPasteAppTests/SearchStateTests.swift
git commit -m "feat(multi-paste): clear marks before escape closes the drawer"
```

---

### Task 9: O chip de ordem no card

**Files:**
- Modify: `MyPasteApp/Views/ClipboardCardView.swift`
- Modify: `MyPasteApp/Views/OverlayView.swift` (só a passagem do parâmetro)

**Interfaces:**
- Consumes: `MarkedSelection.order(of:)` (Task 1).
- Produces: `ClipboardCardView.markOrder: Int?`.

- [ ] **Step 1: Add the property**

Em `MyPasteApp/Views/ClipboardCardView.swift`, junto de `quickPasteLabel`:

```swift
    /// This card's 1-based position in the multi-paste block, when marked.
    ///
    /// Replaces `quickPasteLabel` in the footer while set: one number per
    /// card, always. While a block is being assembled the order is the useful
    /// information; the shortcut comes back the moment the marks are cleared.
    var markOrder: Int? = nil
```

- [ ] **Step 2: Show it in the footer**

Substitua o bloco `if let quickPasteLabel { ... }` de `footer` por:

```swift
            if let markOrder {
                Text("\(markOrder)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
                    .accessibilityLabel("Marked, position \(markOrder)")
            } else if let quickPasteLabel {
                Text(quickPasteLabel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                    .accessibilityLabel("Atalho \(quickPasteLabel)")
            }
```

A substituição acontece **dentro** do card, num ponto só, em vez de a view de
fora ter que decidir qual dos dois mandar.

- [ ] **Step 3: Highlight the border**

Substitua o `.overlay` da borda por:

```swift
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected || markOrder != nil
                                ? Color.accentColor
                                : Color.black.opacity(0.08),
                              lineWidth: isSelected || markOrder != nil ? 2.5 : 1)
        )
```

- [ ] **Step 4: Pass it from `OverlayView`**

Na construção do `ClipboardCardView`, acrescente:

```swift
                                    markOrder: marked.order(of: item.id),
```

- [ ] **Step 5: Build and run the full suite**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Esperado: compila e a suíte segue verde. Nada aqui é coberto por teste — a
aparência fecha na Task 11.

- [ ] **Step 6: Commit**

```bash
git add MyPasteApp/Views/ClipboardCardView.swift MyPasteApp/Views/OverlayView.swift
git commit -m "feat(multi-paste): show the mark order on the card"
```

---

### Task 10: Pílula na barra superior e entrada no menu de contexto

**Files:**
- Modify: `MyPasteApp/Views/Search/OverlayTopBar.swift`
- Modify: `MyPasteApp/Views/ItemContextMenu.swift`
- Modify: `MyPasteApp/Views/OverlayView.swift` (só a passagem dos parâmetros)

**Interfaces:**
- Consumes: `MarkedSelection` (Task 1), `MultiPaste.isMarkable` (Task 3).
- Produces: `OverlayTopBar.markedCount: Int`; `ItemContextMenu.isMarked: Bool` e `ItemContextMenu.onToggleMark: () -> Void`.

- [ ] **Step 1: Add the pill to the top bar**

Em `MyPasteApp/Views/Search/OverlayTopBar.swift`, acrescente a propriedade:

```swift
    /// How many items are marked for a multi-item paste, or zero.
    var markedCount: Int = 0
```

E, dentro do `HStack` principal, **fora** do `if state.isActive`, logo antes do
fechamento:

```swift
            if markedCount > 0 {
                Spacer(minLength: 8)
                // Marks survive the search by design, so some of them can be
                // off-screen. Without this the user would be assembling a
                // block they can't see — the invisible-state failure the
                // roadmap flags for the pause feature.
                Text("\(markedCount) marked    ↵ paste    ⎋ clear")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor))
                    .fixedSize()
            }
```

Cabe nos dois estados sem mexer no layout: em repouso, no espaço reservado às
pílulas da Fase 5; com a busca aberta, na sobra à direita do campo de 470pt.

- [ ] **Step 2: Pass the count from `OverlayView`**

Na construção do `OverlayTopBar`:

```swift
                              markedCount: marked.count,
```

- [ ] **Step 3: Add the context menu entry**

Em `MyPasteApp/Views/ItemContextMenu.swift`, acrescente as propriedades:

```swift
    /// Whether this item is currently marked for a multi-item paste.
    let isMarked: Bool
    let onToggleMark: () -> Void
```

Valores em vez de uma referência à `MarkedSelection`, seguindo o que
`isSearchNarrowed` já faz neste arquivo.

E, depois da entrada "Copy" e antes do `Divider()`:

```swift
        if MultiPaste.isMarkable(item.type) {
            // Same trailing-text glyph as every other entry here — see the
            // type-level doc comment for why these aren't `.keyboardShortcut`.
            Button(titled(isMarked ? "Unmark" : "Mark for Multi-Paste", "⌘M")) {
                onToggleMark()
            }
        }
```

- [ ] **Step 4: Pass the two values from `OverlayView`**

Na construção do `ItemContextMenu`:

```swift
                                    isMarked: marked.contains(item.id),
                                    onToggleMark: { marked.toggle(item.id) }
```

- [ ] **Step 5: Build and run the full suite**

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Esperado: compila e a suíte segue verde.

- [ ] **Step 6: Commit**

```bash
git add MyPasteApp/Views/Search/OverlayTopBar.swift \
        MyPasteApp/Views/ItemContextMenu.swift \
        MyPasteApp/Views/OverlayView.swift
git commit -m "feat(multi-paste): show the marked count and add the context menu entry"
```

---

### Task 11: Roteiro de verificação manual

**Files:**
- Create: `VERIFICACAO-FASE-4.md`

Nenhuma fase fecha sem o Carlos exercitar a GUI à mão. A suíte verde é condição
necessária, nunca suficiente — e três fases seguidas tiveram seus piores
defeitos encontrados fora dela.

- [ ] **Step 1: Write the script**

Crie `VERIFICACAO-FASE-4.md` no formato de `VERIFICACAO-FASE-3.md`, com blocos
nomeados e uma linha por passo, cobrindo:

**Bloco A — marcar e desmarcar**
1. `⌘M` marca o card selecionado; o chip do rodapé vira o número da ordem, em cor de destaque, e a borda acompanha
2. `⌘M` de novo desmarca; o número do `⌘1`–`⌘9` volta ao chip
3. `⌘M` numa imagem não faz nada; `⌘M` num arquivo não faz nada
4. `⌘`+clique marca; `⌘`+clique de novo desmarca
5. Clique sem `⌘` cola só aquele item, mesmo com outros marcados
6. `⌘3` com três itens marcados cola só o terceiro card, não o bloco
7. Menu de contexto mostra "Mark for Multi-Paste" em texto/URL e não mostra em imagem/arquivo; o rótulo vira "Unmark" quando já marcado

**Bloco B — ordem**
8. Marcar A, B, C nessa ordem e conferir os chips 1, 2, 3
9. Marcar em ordem diferente da tela (o terceiro card primeiro) e conferir que o chip segue a ordem de marcação, não a posição
10. Desmarcar o do meio e conferir que o seguinte renumera de 3 para 2

**Bloco C — colar**
11. Marcar 3, `↵`, e conferir os três no destino, na ordem marcada, separados por nova linha
12. Trocar o separador em Ajustes para cada uma das outras três opções e repetir
13. **Conferir que nenhum card mudou de posição no histórico depois da colagem** — o critério que distingue esta fase de todo o resto do app
14. Marcar 2 itens formatados (de Word, Notion ou uma página web) e conferir a formatação preservada no destino
15. Repetir com `⇧↵` e conferir texto plano
16. Colar num campo de texto simples (a barra de endereço do Safari) e conferir que o texto chega — o caso que um pasteboard só-RTF quebraria

**Bloco D — bordas**
17. Marcar 2 itens, buscar outra coisa, marcar um terceiro, `↵`: os três saem na ordem, apesar de dois estarem fora do filtro
18. Marcar 3, apagar um deles com `⌫`, colar: o bloco sai com dois, sem erro
19. `⎋` com marcação limpa a marcação e mantém a gaveta aberta; `⎋` de novo fecha
20. Com busca **e** marcação: primeiro `⎋` larga a busca, segundo limpa a marcação, terceiro fecha
21. Fechar e reabrir a overlay: nada marcado
22. Colar um item avulso com marcação ativa, reabrir: nada marcado
23. A pílula de contagem aparece nos dois estados da barra (busca fechada e aberta) e não empurra o layout

**Bloco E — o que pode dar errado**
24. Confirmar que `⌘M` não minimiza nada nem é engolido pelo sistema
25. Marcar 10 itens de texto longo e colar; observar o app com `./scripts/memwatch.sh` se houver suspeita de custo
26. Se o crash do `⌘1` reproduzir em qualquer ponto: **parar e capturar a stack trace** com Exception Breakpoint. É o bug antigo, ainda sem diagnóstico, e a stack é a peça que falta

- [ ] **Step 2: Commit**

```bash
git add VERIFICACAO-FASE-4.md
git commit -m "docs(multi-paste): add the manual verification script"
```

- [ ] **Step 3: Hand it to the Carlos**

Avisar que a implementação está pronta com a suíte verde, e que a fase **não
fecha** até os blocos A–E serem exercitados à mão. Mover
`[[14 Colagem múltipla]]` para `🔍 Revisão` no board e atualizar o `status` do
card, os dois juntos.

---

## Revisão final de branch

**Obrigatória antes do PR, e não é opcional.** Três fases seguidas (2, 2.5 e 3)
tiveram seus piores defeitos encontrados só com o conjunto à vista — sempre em
costuras entre tarefas escritas a vários commits de distância, sempre aprovadas
pelas revisões tarefa-a-tarefa. Varrer os commits da branch inteira, não cada um
isolado.

As costuras prováveis desta fase:

- **`resolve` contra `items` versus `filtered`** (Tasks 3 e 7, escritas longe uma
  da outra). Contra `filtered`, o bloco encolhe sozinho conforme se digita
- **A limpeza da marcação em `show()`** (Task 7) versus todos os caminhos de
  saída da gaveta. A Fase 3 documentou que `show()` é o único ponto que cobre os
  três; se algum caminho novo escapar, a marcação vaza para a abertura seguinte
- **O chip de ordem contra o do quick paste** (Task 9): o `else if` é o que
  garante um número por card, e um refactor que os separe traz os dois de volta
- **O degrau novo do `⎋`** (Task 8) contra os três que já existiam. Se
  `.clearMarks` subir na ordem, passa a engolir o escape que fecharia o painel
  de filtros ou a busca
- **`markUsed` versus `write`** (Tasks 4 e 5): se alguém "simplificar" juntando
  os dois caminhos de salvamento, a colagem múltipla volta a promover os N ao
  topo
