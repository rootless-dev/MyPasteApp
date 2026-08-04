# Fase 5 — Organização: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pinboards (coleções nomeadas e coloridas escolhidas por pílulas no topo da overlay), retenção por item em três estados, e regras de captura por app com filtro por tipo.

**Architecture:** Um `@Model Pinboard` novo com relação `.nullify` para `ClipboardItem`, que ganha `pinboard`, `expiresAt` e `keepForever`. O escopo de navegação vive num `PinboardScope` observável possuído pelo `OverlayWindowController` e resetado a cada abertura, ao lado de `SearchState` e `MarkedSelection`. A sobrevivência à poda vira **uma** função pura (`RetentionPolicy.isProtected`) consultada pelas três passadas da poda e pelo botão de limpar histórico. As regras por app são `Codable` em `UserDefaults`, decididas por funções puras que o `ClipboardMonitor` chama em dois pontos distintos do `poll()`.

**Tech Stack:** Swift 5, SwiftUI + AppKit, SwiftData, Swift Testing, Xcode 26.6, SDK macOS 26.5, deployment target 26.2.

**Spec:** `docs/superpowers/specs/2026-08-03-fase-5-organizacao-design.md`

## Global Constraints

- **Branch:** `feature/fase-5-organizacao`, criada a partir de `develop`.
- **Arquivos novos entram no alvo sozinhos.** O projeto usa `PBXFileSystemSynchronizedRootGroup` — não há `project.pbxproj` para editar ao criar um arquivo.
- **Comando de teste completo:**
  ```bash
  set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
    -project MyPasteApp.xcodeproj -scheme MyPasteApp \
    -configuration Debug -destination 'platform=macOS'
  ```
- **Uma suíte só:** acrescente `-only-testing:MyPasteAppTests/<NomeDaSuite>` ao comando acima.
- **Só compilar** (tarefas de `Views/`, que não têm teste):
  ```bash
  set -o pipefail && xcodebuild build \
    -project MyPasteApp.xcodeproj -scheme MyPasteApp \
    -configuration Debug -destination 'platform=macOS'
  ```
- **A suíte cobre lógica pura.** Nada em `Views/` ou `Window/` tem teste automatizado — essas tarefas fecham com compilação limpa e verificação manual, nunca com teste.
- **Commits:** mensagens em inglês, Conventional Commits, blocos por funcionalidade. **Nunca commitar sem autorização explícita do Carlos**, exceto quando ele autorizar a branch inteira da fase. Nunca `git add -A` nem `git add .`: `ROADMAP.md`, `DESIGN.md` e `design-refs/` são documentos de trabalho local, excluídos via `.git/info/exclude`.
- **Board do Obsidian:** ao começar a implementação, mover `[[16 Pinboards]]`, `[[17 Retenção por item]]` e `[[18 Regras por app]]` para `🛠 Implementando` em `MyPasteApp/Board.md` e atualizar `status` nos três cards — board e card sempre juntos. **Nesta sessão as ferramentas MCP `mcp-tools-istefox` não estavam expostas**, embora o servidor estivesse conectado; o vault está em `~/Documents/Obsidian Vault/MyPasteApp/` e pode ser editado por arquivo. Se nenhum dos dois caminhos funcionar, avisar o Carlos em vez de seguir em silêncio.
- **Idioma da interface:** inglês, como todo o resto do app. Idioma dos comentários de código: inglês.
- **Cada `ModelContainer` de teste precisa listar os dois modelos** a partir da Task 1: `ModelContainer(for: ClipboardItem.self, Pinboard.self, configurations: ...)`. Uma suíte que só liste `ClipboardItem.self` falha ao gravar a relação.
- **Flake conhecido, não desta fase:** `PauseControllerTests.timedPauseResumesAutomatically()` depende de carga da máquina. Se falhar, rodar isolado antes de investigar.
- **Bug aberto, não desta fase:** crash no `⌘1` com perda de histórico, sem diagnóstico. Se aparecer durante a implementação, anotar e seguir — não é regressão desta fase.

## Estrutura de arquivos

| Arquivo | Responsabilidade | Task |
|---|---|---|
| `MyPasteApp/Models/Pinboard.swift` | **Novo.** O modelo da coleção e sua relação com os itens | 1 |
| `MyPasteApp/Models/ClipboardItem.swift` | Modificado: `pinboard`, `expiresAt`, `keepForever` | 1 |
| `MyPasteApp/Services/PinboardPalette.swift` | **Novo.** As 8 cores fixas e a escolha da próxima livre | 1 |
| `MyPasteApp/Views/Support/Color+Hex.swift` | **Novo.** `Color(hex:)`, movido de `LinkPreviewView.swift` | 1 |
| `MyPasteApp/AppDelegate.swift` | Modificado: `Pinboard.self` no container (Task 1); nada mais | 1 |
| `MyPasteApp/Services/ItemRetention.swift` | **Novo.** O tri-estado e as durações oferecidas | 2 |
| `MyPasteApp/Services/RetentionPolicy.swift` | Modificado: `isProtected` e as três passadas | 2 |
| `MyPasteApp/Views/Preferences/HistorySettingsView.swift` | Modificado: "Clear history" com a mesma regra | 2 |
| `MyPasteApp/Services/ItemActions.swift` | Modificado: `makeManualItem` (Task 2), `setRetention`/`assign` (Task 8) | 2, 8 |
| `MyPasteApp/Services/PinboardScope.swift` | **Novo.** O escopo ativo e a regra de pertencimento | 3 |
| `MyPasteApp/Services/SearchState.swift` | Modificado: degrau `.leaveScope` na cadeia do `⎋` | 3 |
| `MyPasteApp/Views/Pinboards/PinboardPill.swift` | **Novo.** Uma pílula, nos seus estados | 4 |
| `MyPasteApp/Views/Pinboards/PinboardBar.swift` | **Novo.** A faixa de pílulas e o botão `+` | 4 |
| `MyPasteApp/Views/Search/OverlayTopBar.swift` | Modificado: hospeda a faixa no `HStack` reservado | 4 |
| `MyPasteApp/Services/PinboardActions.swift` | **Novo.** Criar, renomear, recolorir, excluir | 5 |
| `MyPasteApp/Views/Pinboards/PinboardContextMenu.swift` | **Novo.** Renomear · Excluir · paleta | 5 |
| `MyPasteApp/Views/OverlayView.swift` | Modificado: escopo em `filtered`, `⌃Tab`, estado vazio (Task 6); cor do cabeçalho (Task 7); entradas de menu (Task 8) | 6, 7, 8 |
| `MyPasteApp/Window/OverlayWindowController.swift` | Modificado: possui o `PinboardScope` e o reseta em `show()` | 6 |
| `MyPasteApp/Views/ClipboardCardView.swift` | Modificado: cor sobreposta e ponto de filiação | 7 |
| `MyPasteApp/Views/ItemContextMenu.swift` | Modificado: `Add to Pinboard ▸` e `Keep ▸` | 8 |
| `MyPasteApp/Services/AppRules.swift` | **Novo.** `AppRule`, storage, migração e as duas decisões puras | 9 |
| `MyPasteApp/Services/PreferenceKeys.swift` | Modificado: chave `appRules` | 9 |
| `MyPasteApp/Services/ClipboardMonitor.swift` | Modificado: os dois guards, nas posições novas | 10 |
| `MyPasteApp/Views/Preferences/AppRulesListView.swift` | **Novo.** A lista editável de regras por app | 11 |
| `MyPasteApp/Views/Preferences/PrivacySettingsView.swift` | Modificado: troca o `TextEditor` pela lista | 11 |
| `VERIFICACAO-FASE-5.md` | **Novo.** Roteiro de verificação manual | 12 |

Testes novos: `PinboardPaletteTests`, `PinboardModelTests`, `ItemRetentionTests`, `PinboardScopeTests`, `PinboardActionsTests`, `AppRulesTests`, `AppCaptureRuleTests`.
Testes modificados: `RetentionPolicyTests`, `ManualItemTests`, `SearchStateTests`, `PreferenceKeysTests`, `ClipboardMonitorCaptureDecisionTests`, e toda suíte que constrói um `ModelContainer`.

---

### Task 1: `Pinboard`, campos novos, paleta e container

**Files:**
- Create: `MyPasteApp/Models/Pinboard.swift`
- Create: `MyPasteApp/Services/PinboardPalette.swift`
- Create: `MyPasteApp/Views/Support/Color+Hex.swift`
- Modify: `MyPasteApp/Models/ClipboardItem.swift`
- Modify: `MyPasteApp/Views/Preview/LinkPreviewView.swift` (remover a `extension Color`)
- Modify: `MyPasteApp/AppDelegate.swift:45`
- Test: `MyPasteAppTests/PinboardPaletteTests.swift`, `MyPasteAppTests/PinboardModelTests.swift`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `final class Pinboard` (`@Model`) com `id: UUID`, `name: String`, `colorHex: String`, `createdAt: Date`, `items: [ClipboardItem]`, e `init(id:name:colorHex:createdAt:)`
  - `ClipboardItem.pinboard: Pinboard?`, `ClipboardItem.expiresAt: Date?`, `ClipboardItem.keepForever: Bool`
  - `PinboardPalette.colors: [String]` e `PinboardPalette.nextColor(usedBy: [String]) -> String`
  - `Color(hex: String)` continua existindo com a mesma assinatura, em arquivo novo

- [ ] **Step 1: Escrever os testes da paleta**

Criar `MyPasteAppTests/PinboardPaletteTests.swift`:

```swift
//
//  PinboardPaletteTests.swift
//  MyPasteAppTests
//

import Testing

@testable import MyPasteApp

/// The palette is a storage format as much as a visual choice: `colorHex` is
/// persisted per pinboard, so changing an entry silently recolours boards that
/// already exist. These tests freeze it, the same way `PreferenceKeysTests`
/// freezes the defaults keys.
@Suite("Pinboard palette")
struct PinboardPaletteTests {
    @Test("Has exactly eight colours")
    func hasEightColours() {
        #expect(PinboardPalette.colors.count == 8)
    }

    @Test("Every colour is six hex digits, with no leading hash")
    func coloursAreSixHexDigits() {
        for hex in PinboardPalette.colors {
            #expect(hex.count == 6)
            #expect(UInt32(hex, radix: 16) != nil)
        }
    }

    @Test("With nothing in use, picks the first colour")
    func firstColourWhenNoneUsed() {
        #expect(PinboardPalette.nextColor(usedBy: []) == PinboardPalette.colors[0])
    }

    @Test("Skips colours already in use")
    func skipsUsedColours() {
        let used = [PinboardPalette.colors[0], PinboardPalette.colors[1]]
        #expect(PinboardPalette.nextColor(usedBy: used) == PinboardPalette.colors[2])
    }

    @Test("Wraps back to the first colour once all eight are taken")
    func wrapsWhenAllUsed() {
        #expect(PinboardPalette.nextColor(usedBy: PinboardPalette.colors)
                == PinboardPalette.colors[0])
    }

    @Test("Matching ignores case")
    func matchingIgnoresCase() {
        // A hex written by hand, or round-tripped through a different code
        // path, can come back lowercased. Treating "ff3b30" as a different
        // colour from "FF3B30" would hand two boards the same colour.
        let used = [PinboardPalette.colors[0].lowercased()]
        #expect(PinboardPalette.nextColor(usedBy: used) == PinboardPalette.colors[1])
    }
}
```

- [ ] **Step 2: Rodar os testes da paleta para vê-los falhar**

Run: `set -o pipefail && NSUnbufferedIO=YES xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp -configuration Debug -destination 'platform=macOS' -only-testing:MyPasteAppTests/PinboardPaletteTests`
Expected: FAIL na compilação — `cannot find 'PinboardPalette' in scope`.

- [ ] **Step 3: Escrever a paleta**

Criar `MyPasteApp/Services/PinboardPalette.swift`:

```swift
//
//  PinboardPalette.swift
//  MyPasteApp
//

import Foundation

/// The eight colours a pinboard can take.
///
/// Fixed, and deliberately not a free colour picker: every one of these has to
/// stay legible as a card header over the dark overlay, and a picker would let
/// the set drift into something that no longer reads as one family. Taken from
/// `design-refs/15-pinboard-menu-contexto.png`, in the order shown there.
///
/// These strings are persisted in `Pinboard.colorHex`. Changing an entry
/// recolours every board already using it — `PinboardPaletteTests` freezes the
/// list for that reason.
enum PinboardPalette {
    static let colors: [String] = [
        "FF3B30", // red
        "FF9500", // orange
        "FFCC00", // yellow
        "34C759", // green
        "007AFF", // blue
        "AF52DE", // purple
        "FF2D55", // pink
        "8E8E93", // grey
    ]

    /// The first colour not already taken, or the first of the palette once
    /// all eight are in use.
    ///
    /// Deterministic on purpose: two boards created in a row should never come
    /// up the same colour while a free one exists.
    static func nextColor(usedBy existing: [String]) -> String {
        let used = Set(existing.map { $0.uppercased() })
        return colors.first { !used.contains($0) } ?? colors[0]
    }
}
```

- [ ] **Step 4: Rodar os testes da paleta**

Run: o mesmo comando do Step 2.
Expected: PASS, 6 testes.

- [ ] **Step 5: Escrever o teste do modelo e da relação**

Criar `MyPasteAppTests/PinboardModelTests.swift`:

```swift
//
//  PinboardModelTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

/// A class suite so the in-memory `ModelContainer` stays owned — and therefore
/// alive — for the whole test, as `RetentionPolicyTests` documents.
@MainActor
@Suite("Pinboard model")
final class PinboardModelTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    private func makeItem(_ tag: String) -> ClipboardItem {
        let item = ClipboardItem(type: .text, preview: tag, contentHash: tag, textContent: tag)
        context.insert(item)
        return item
    }

    @Test("Assigning an item to a pinboard fills the inverse relationship")
    func assigningFillsTheInverse() throws {
        let board = Pinboard(name: "Work", colorHex: PinboardPalette.colors[0])
        context.insert(board)
        let item = makeItem("a")

        item.pinboard = board
        try context.save()

        #expect(board.items.count == 1)
        #expect(board.items.first?.preview == "a")
    }

    @Test("Deleting a pinboard keeps its items and clears their board")
    func deletingABoardKeepsItsItems() throws {
        // The central promise of roadmap item 16: a pinboard is a collection,
        // not a container. Deleting it must never delete history.
        let board = Pinboard(name: "Work", colorHex: PinboardPalette.colors[0])
        context.insert(board)
        let kept = makeItem("kept")
        kept.pinboard = board
        try context.save()

        context.delete(board)
        try context.save()

        let items = try context.fetch(FetchDescriptor<ClipboardItem>())
        #expect(items.count == 1)
        #expect(items.first?.pinboard == nil)
    }

    @Test("A new item follows the global policy and belongs to no board")
    func defaultsAreNeutral() {
        let item = makeItem("fresh")

        #expect(item.pinboard == nil)
        #expect(item.expiresAt == nil)
        #expect(item.keepForever == false)
    }
}
```

- [ ] **Step 6: Rodar o teste do modelo para vê-lo falhar**

Run: `set -o pipefail && NSUnbufferedIO=YES xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp -configuration Debug -destination 'platform=macOS' -only-testing:MyPasteAppTests/PinboardModelTests`
Expected: FAIL na compilação — `cannot find 'Pinboard' in scope`.

- [ ] **Step 7: Escrever o modelo `Pinboard`**

Criar `MyPasteApp/Models/Pinboard.swift`:

```swift
//
//  Pinboard.swift
//  MyPasteApp
//

import Foundation
import SwiftData

/// A named, coloured collection of history items.
///
/// Distinct from `ClipboardItem.isPinned`, which stays exactly as it was:
/// pinning is "favourite this quickly" (⌘P, sorted first, spared by the
/// pruner) and a pinboard is "file this under a theme". Phase 5 deliberately
/// kept the two rather than migrating one into the other — see the phase spec.
///
/// The delete rule is the whole promise of the feature: removing a board
/// releases its items back into the history, and never deletes them.
@Model
final class Pinboard {
    @Attribute(.unique) var id: UUID
    var name: String
    /// One of `PinboardPalette.colors`, without a leading "#".
    var colorHex: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ClipboardItem.pinboard)
    var items: [ClipboardItem] = []

    init(id: UUID = UUID(),
         name: String,
         colorHex: String,
         createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    /// The name shown when the user never typed one.
    static let untitledName = "Untitled"
}
```

- [ ] **Step 8: Acrescentar os três campos ao `ClipboardItem`**

Em `MyPasteApp/Models/ClipboardItem.swift`, logo abaixo de `var ocrProcessedAt: Date?`:

```swift
    /// The pinboard this item was filed under, or nil for "history only".
    ///
    /// At most one: the card header takes its colour from the board while that
    /// board is the active scope, and two boards of different colours would
    /// leave that with no single answer. See the Phase 5 spec.
    var pinboard: Pinboard?

    /// When this item should be deleted, whatever the global policy says.
    ///
    /// An absolute date, written at the moment the user chooses a duration —
    /// never a duration evaluated against `createdAt`, which is rewritten on
    /// every paste (see the note at the top of ROADMAP.md) and would restart
    /// the countdown each time the item is used.
    ///
    /// nil means "follow the global policy". Distinct from `keepForever`.
    var expiresAt: Date?

    /// The "never expires" state, set by the user on this item alone.
    ///
    /// Separate from `isPinned` on purpose: pinning also sorts the item to the
    /// front of the list, and "keep this forever" shouldn't have to.
    var keepForever: Bool = false
```

E no `init`, um parâmetro novo com default, imediatamente após `isPinned: Bool = false`:

```swift
        keepForever: Bool = false,
```

com a atribuição correspondente, logo após `self.isPinned = isPinned`:

```swift
        self.keepForever = keepForever
```

`pinboard` e `expiresAt` **não** entram no `init`: são atribuídos depois da criação, por `ItemActions`. Um parâmetro para cada um só daria mais formas de construir o mesmo estado.

- [ ] **Step 9: Rodar o teste do modelo**

Run: o mesmo comando do Step 6.
Expected: PASS, 3 testes.

- [ ] **Step 10: Registrar o modelo no container do app**

Em `MyPasteApp/AppDelegate.swift:45`, trocar:

```swift
            modelContainer = try ModelContainer(for: ClipboardItem.self)
```

por:

```swift
            // Both models, explicitly. SwiftData only infers what it can reach
            // from this list — a `Pinboard` left out here compiles fine and
            // then traps on the first write to the relationship.
            modelContainer = try ModelContainer(for: ClipboardItem.self, Pinboard.self)
```

- [ ] **Step 11: Mover `Color(hex:)` para um arquivo próprio**

Criar `MyPasteApp/Views/Support/Color+Hex.swift` com a extensão **exatamente** como está hoje em `LinkPreviewView.swift:73-83`:

```swift
//
//  Color+Hex.swift
//  MyPasteApp
//

import SwiftUI

/// Moved out of `LinkPreviewView.swift` in Phase 5: pinboard pills and card
/// headers now decode `Pinboard.colorHex` through this, and a shared helper
/// living inside one view's file is a helper nobody finds.
extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
```

E **apagar** a `extension Color { ... }` inteira do fim de `MyPasteApp/Views/Preview/LinkPreviewView.swift` (linhas 73–83), deixando o arquivo terminar na chave da view.

- [ ] **Step 12: Rodar a suíte completa**

Run:
```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```
Expected: PASS. Os 9 testes novos entram; nenhum dos existentes muda de resultado. Se alguma suíte falhar ao gravar por causa do container, é a que precisa listar `Pinboard.self` — ver Global Constraints.

- [ ] **Step 13: Commit**

```bash
git add MyPasteApp/Models/Pinboard.swift \
        MyPasteApp/Models/ClipboardItem.swift \
        MyPasteApp/Services/PinboardPalette.swift \
        MyPasteApp/Views/Support/Color+Hex.swift \
        MyPasteApp/Views/Preview/LinkPreviewView.swift \
        MyPasteApp/AppDelegate.swift \
        MyPasteAppTests/PinboardPaletteTests.swift \
        MyPasteAppTests/PinboardModelTests.swift
git commit -m "feat(pinboards): add the Pinboard model, its palette and the item fields"
```

---

### Task 2: `ItemRetention` e a poda reconciliada

**Files:**
- Create: `MyPasteApp/Services/ItemRetention.swift`
- Modify: `MyPasteApp/Services/RetentionPolicy.swift`
- Modify: `MyPasteApp/Views/Preferences/HistorySettingsView.swift`
- Modify: `MyPasteApp/Services/ItemActions.swift` (`makeManualItem`)
- Test: `MyPasteAppTests/ItemRetentionTests.swift`, `MyPasteAppTests/RetentionPolicyTests.swift`, `MyPasteAppTests/ManualItemTests.swift`

**Interfaces:**
- Consumes: `ClipboardItem.expiresAt`, `ClipboardItem.keepForever`, `ClipboardItem.pinboard` (Task 1).
- Produces:
  - `enum ItemRetention: Equatable` com casos `.global`, `.forever`, `.until(Date)`, `static func of(keepForever:expiresAt:) -> ItemRetention`, `var fields: (keepForever: Bool, expiresAt: Date?)`
  - `enum RetentionOffer: CaseIterable` com `.hour`, `.day`, `.week`, `.month`, `var title: String`, `func date(from: Date) -> Date`
  - `RetentionPolicy.isProtected(_ item: ClipboardItem) -> Bool` (estático)

- [ ] **Step 1: Escrever os testes do tri-estado**

Criar `MyPasteAppTests/ItemRetentionTests.swift`:

```swift
//
//  ItemRetentionTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing

@testable import MyPasteApp

@Suite("Item retention")
struct ItemRetentionTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Nothing set means follow the global policy")
    func neutralIsGlobal() {
        #expect(ItemRetention.of(keepForever: false, expiresAt: nil) == .global)
    }

    @Test("Keep forever reads back as forever")
    func foreverRoundTrips() {
        #expect(ItemRetention.of(keepForever: true, expiresAt: nil) == .forever)
    }

    @Test("A date reads back as until")
    func untilRoundTrips() {
        #expect(ItemRetention.of(keepForever: false, expiresAt: date) == .until(date))
    }

    @Test("A date wins over keep forever")
    func dateWinsOverForever() {
        // The inconsistent state shouldn't be reachable — `fields` always
        // writes both — but if it ever is, the dated choice is the more
        // specific one, and honouring it is the safer failure: an item the
        // user asked to expire does expire.
        #expect(ItemRetention.of(keepForever: true, expiresAt: date) == .until(date))
    }

    @Test("Global clears both fields")
    func globalClearsBoth() {
        let fields = ItemRetention.global.fields
        #expect(fields.keepForever == false)
        #expect(fields.expiresAt == nil)
    }

    @Test("Forever sets the flag and clears the date")
    func foreverClearsTheDate() {
        let fields = ItemRetention.forever.fields
        #expect(fields.keepForever)
        #expect(fields.expiresAt == nil)
    }

    @Test("Until sets the date and clears the flag")
    func untilClearsTheFlag() {
        let fields = ItemRetention.until(date).fields
        #expect(fields.keepForever == false)
        #expect(fields.expiresAt == date)
    }

    @Test("Each offer lands the expected distance in the future")
    func offersResolveToDates() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(RetentionOffer.hour.date(from: now) == now.addingTimeInterval(3600))
        #expect(RetentionOffer.day.date(from: now) == now.addingTimeInterval(86_400))
        #expect(RetentionOffer.week.date(from: now) == now.addingTimeInterval(7 * 86_400))
        #expect(RetentionOffer.month.date(from: now) == now.addingTimeInterval(30 * 86_400))
    }

    @Test("Every offer has a title")
    func offersHaveTitles() {
        for offer in RetentionOffer.allCases {
            #expect(!offer.title.isEmpty)
        }
    }
}
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `set -o pipefail && NSUnbufferedIO=YES xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp -configuration Debug -destination 'platform=macOS' -only-testing:MyPasteAppTests/ItemRetentionTests`
Expected: FAIL na compilação — `cannot find 'ItemRetention' in scope`.

- [ ] **Step 3: Escrever `ItemRetention`**

Criar `MyPasteApp/Services/ItemRetention.swift`:

```swift
//
//  ItemRetention.swift
//  MyPasteApp
//

import Foundation

/// What should happen to one item, independently of the global policy.
///
/// Two stored fields (`keepForever`, `expiresAt`) express three states, so
/// reading and writing them go through here rather than being open-coded at
/// each call site — that's what keeps the fourth, meaningless combination
/// (both set) from being written in the first place.
enum ItemRetention: Equatable {
    /// Follow `retentionDays` and `maxItems`, like everything else.
    case global
    case forever
    case until(Date)

    static func of(keepForever: Bool, expiresAt: Date?) -> ItemRetention {
        // A date first: see `ItemRetentionTests.dateWinsOverForever`.
        if let expiresAt { return .until(expiresAt) }
        if keepForever { return .forever }
        return .global
    }

    /// Both fields, always — writing only the one that changed is how the
    /// inconsistent state would be born.
    var fields: (keepForever: Bool, expiresAt: Date?) {
        switch self {
        case .global: return (false, nil)
        case .forever: return (true, nil)
        case .until(let date): return (false, date)
        }
    }
}

/// The durations offered in the card's "Keep" menu.
///
/// Named durations rather than a date picker: the useful choices are coarse,
/// and a picker inside a context menu inside a non-activating panel is a lot
/// of surface for no extra reach.
enum RetentionOffer: CaseIterable {
    case hour
    case day
    case week
    case month

    var title: String {
        switch self {
        case .hour:  return "Expire in 1 hour"
        case .day:   return "Expire in 1 day"
        case .week:  return "Expire in 1 week"
        case .month: return "Expire in 30 days"
        }
    }

    /// Plain interval arithmetic, not `Calendar`: these are "an hour from
    /// now", not "the same wall-clock time tomorrow", so a DST boundary
    /// shouldn't move them.
    func date(from now: Date) -> Date {
        switch self {
        case .hour:  return now.addingTimeInterval(3600)
        case .day:   return now.addingTimeInterval(86_400)
        case .week:  return now.addingTimeInterval(7 * 86_400)
        case .month: return now.addingTimeInterval(30 * 86_400)
        }
    }
}
```

- [ ] **Step 4: Rodar os testes do tri-estado**

Run: o comando do Step 2.
Expected: PASS, 9 testes.

- [ ] **Step 5: Escrever os testes novos da poda**

Acrescentar a `MyPasteAppTests/RetentionPolicyTests.swift`. Primeiro, o container da suíte precisa dos dois modelos — trocar o `init` existente (linhas 23–28) por:

```swift
    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
```

Depois, estender o helper `insert` e acrescentar os helpers e testes novos, no fim da classe:

```swift
    // MARK: - Helpers (Phase 5)

    private func insertProtected(tag: String,
                                 daysAgo: Int,
                                 pinned: Bool = false,
                                 keepForever: Bool = false,
                                 inBoard board: Pinboard? = nil,
                                 expiresAt: Date? = nil) {
        let createdAt = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let item = ClipboardItem(
            createdAt: createdAt,
            type: .text,
            preview: tag,
            contentHash: tag,
            textContent: tag,
            isPinned: pinned,
            keepForever: keepForever
        )
        item.expiresAt = expiresAt
        item.pinboard = board
        context.insert(item)
    }

    private func makeBoard() -> Pinboard {
        let board = Pinboard(name: "Work", colorHex: PinboardPalette.colors[0])
        context.insert(board)
        return board
    }

    // MARK: - Expiry (roadmap item 17)

    @Test("An item past its expiry date is deleted")
    func expiredItemIsDeleted() throws {
        insertProtected(tag: "expired", daysAgo: 0,
                        expiresAt: Date.now.addingTimeInterval(-60))
        insertProtected(tag: "future", daysAgo: 0,
                        expiresAt: Date.now.addingTimeInterval(3600))

        policy.prune()

        #expect(try remainingTags() == ["future"])
    }

    @Test("Expiry beats pinning")
    func expiryBeatsPinning() throws {
        // An explicit, dated choice by the user outranks an automatic rule.
        // The alternative leaves an item the user marked for deletion alive
        // indefinitely because it happens to be pinned.
        insertProtected(tag: "pinned-expired", daysAgo: 0, pinned: true,
                        expiresAt: Date.now.addingTimeInterval(-60))

        policy.prune()

        #expect(try remainingTags().isEmpty)
    }

    @Test("Expiry beats keep forever")
    func expiryBeatsKeepForever() throws {
        insertProtected(tag: "forever-expired", daysAgo: 0, keepForever: true,
                        expiresAt: Date.now.addingTimeInterval(-60))

        policy.prune()

        #expect(try remainingTags().isEmpty)
    }

    @Test("Expiry beats being in a pinboard")
    func expiryBeatsPinboard() throws {
        let board = makeBoard()
        insertProtected(tag: "board-expired", daysAgo: 0, inBoard: board,
                        expiresAt: Date.now.addingTimeInterval(-60))

        policy.prune()

        #expect(try remainingTags().isEmpty)
    }

    // MARK: - Keep forever

    @Test("Keep forever survives the age pass")
    func keepForeverSurvivesAge() throws {
        defaults.store.set(10, forKey: PreferenceKeys.retentionDays)
        insertProtected(tag: "kept", daysAgo: 900, keepForever: true)
        insertProtected(tag: "dropped", daysAgo: 900)

        policy.prune()

        #expect(try remainingTags() == ["kept"])
    }

    @Test("Keep forever doesn't consume the maxItems budget")
    func keepForeverIsExemptFromTheCap() throws {
        defaults.store.set(1, forKey: PreferenceKeys.maxItems)
        insertProtected(tag: "kept-a", daysAgo: 1, keepForever: true)
        insertProtected(tag: "kept-b", daysAgo: 2, keepForever: true)
        insertProtected(tag: "loose-new", daysAgo: 0)
        insertProtected(tag: "loose-old", daysAgo: 3)

        policy.prune()

        #expect(try remainingTags() == ["kept-a", "kept-b", "loose-new"])
    }

    // MARK: - Pinboards (roadmap item 16)

    @Test("An item in a pinboard survives the age pass")
    func pinboardSurvivesAge() throws {
        // Without this the collection the user curated empties itself in
        // thirty days, with no warning and no undo.
        defaults.store.set(10, forKey: PreferenceKeys.retentionDays)
        let board = makeBoard()
        insertProtected(tag: "filed", daysAgo: 900, inBoard: board)
        insertProtected(tag: "loose", daysAgo: 900)

        policy.prune()

        #expect(try remainingTags() == ["filed"])
    }

    @Test("Items in a pinboard don't push loose items out of the cap")
    func pinboardIsExemptFromTheCap() throws {
        defaults.store.set(3, forKey: PreferenceKeys.maxItems)
        let board = makeBoard()
        insertProtected(tag: "filed-a", daysAgo: 4, inBoard: board)
        insertProtected(tag: "filed-b", daysAgo: 5, inBoard: board)
        insertProtected(tag: "filed-c", daysAgo: 6, inBoard: board)
        insertProtected(tag: "loose-1", daysAgo: 0)
        insertProtected(tag: "loose-2", daysAgo: 1)
        insertProtected(tag: "loose-3", daysAgo: 2)

        policy.prune()

        #expect(try remainingTags() == ["filed-a", "filed-b", "filed-c",
                                        "loose-1", "loose-2", "loose-3"])
    }

    // MARK: - isProtected

    @Test("isProtected covers exactly the three shields")
    func isProtectedCoversTheThree() throws {
        let board = makeBoard()
        insertProtected(tag: "pinned", daysAgo: 0, pinned: true)
        insertProtected(tag: "forever", daysAgo: 0, keepForever: true)
        insertProtected(tag: "filed", daysAgo: 0, inBoard: board)
        insertProtected(tag: "plain", daysAgo: 0)

        let items = try context.fetch(FetchDescriptor<ClipboardItem>())
        let protectedTags = Set(items.filter(RetentionPolicy.isProtected).map(\.preview))

        #expect(protectedTags == ["pinned", "forever", "filed"])
    }
```

- [ ] **Step 6: Rodar a suíte da poda para ver falhar**

Run: `set -o pipefail && NSUnbufferedIO=YES xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp -configuration Debug -destination 'platform=macOS' -only-testing:MyPasteAppTests/RetentionPolicyTests`
Expected: FAIL — `type 'RetentionPolicy' has no member 'isProtected'`, e os testes de expiração falham porque nada apaga por `expiresAt`.

- [ ] **Step 7: Reescrever `prune()` com as três passadas**

Em `MyPasteApp/Services/RetentionPolicy.swift`, substituir `func prune()` inteira (linhas 39–67) por:

```swift
    /// Whether an item survives the two global passes.
    ///
    /// One rule, in one place, consulted by both passes here **and** by the
    /// "Clear history" button in Settings — which used to carry its own
    /// `!isPinned` predicate and would otherwise wipe every pinboard the user
    /// had just filled.
    ///
    /// Deliberately not expressed as a `#Predicate`: `$0.pinboard == nil`
    /// leans on SwiftData's handling of relationships inside predicates, and a
    /// predicate copy of this rule would be a second place for it to drift.
    /// The pruner runs at launch over at most `maxItems` rows (5000 ceiling,
    /// 500 by default), and the heavy fields — `imageData`, `richTextData`,
    /// the link blobs — are `.externalStorage`, so fetching a row doesn't
    /// bring them along.
    static func isProtected(_ item: ClipboardItem) -> Bool {
        item.isPinned || item.keepForever || item.pinboard != nil
    }

    func prune() {
        let now = Date.now
        let all = (try? modelContext.fetch(FetchDescriptor<ClipboardItem>())) ?? []

        // 1) Items the user gave an explicit expiry date, now past. This pass
        //    ignores every shield above: a dated choice outranks pinning,
        //    "keep forever" and pinboard membership alike.
        var survivors: [ClipboardItem] = []
        for item in all {
            if let expiresAt = item.expiresAt, expiresAt < now {
                modelContext.delete(item)
            } else {
                survivors.append(item)
            }
        }

        // 2) Delete old unprotected items — skipped entirely when the user
        //    asked to keep the history forever.
        var prunable = survivors.filter { !Self.isProtected($0) }
        if let days = retentionDays {
            let cutoff = Calendar.current.date(
                byAdding: .day, value: -days, to: now
            ) ?? now
            for item in prunable where item.createdAt < cutoff {
                modelContext.delete(item)
            }
            prunable = prunable.filter { $0.createdAt >= cutoff }
        }

        // 3) Cap at maxItems (keeps the most recent unprotected ones). This
        //    runs even with "keep forever": that setting is about age, not
        //    about quantity, and without this the store grows without bound.
        //    Protected items are outside this count entirely — otherwise a
        //    full pinboard would push the recent history out to make room.
        let ordered = prunable.sorted { $0.createdAt > $1.createdAt }
        if ordered.count > maxItems {
            for item in ordered[maxItems...] { modelContext.delete(item) }
        }

        try? modelContext.save()
    }
```

- [ ] **Step 8: Rodar a suíte da poda**

Run: o comando do Step 6.
Expected: PASS. Os testes antigos (fixados, cap, idempotência, "forever") continuam verdes junto com os nove novos.

- [ ] **Step 9: Escrever o teste do botão de limpar histórico**

`HistorySettingsView` é uma view e não tem teste. O que tem teste é a regra que
ela passa a usar, já coberta em `isProtectedCoversTheThree` (Step 5). Nenhum
teste novo aqui — a verificação é o passo D do roteiro manual (Task 12).

- [ ] **Step 10: Reconciliar "Clear non-pinned history"**

Em `MyPasteApp/Views/Preferences/HistorySettingsView.swift`, trocar o botão:

```swift
            Section {
                Button("Clear history") { clearHistory() }
                Text("Keeps pinned items, items in pinboards, and items set to never expire.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
```

e a função:

```swift
    /// Uses the pruner's own rule rather than a predicate of its own.
    ///
    /// It used to carry `#Predicate { !$0.isPinned }`, which since Phase 5
    /// would have emptied every pinboard the user had just filled — the button
    /// promised "non-pinned" and would have deleted curated collections.
    private func clearHistory() {
        let items = (try? modelContext.fetch(FetchDescriptor<ClipboardItem>())) ?? []
        for item in items where !RetentionPolicy.isProtected(item) {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
```

- [ ] **Step 11: Trocar o paliativo do item manual**

Em `MyPasteApp/Services/ItemActions.swift`, o comentário de tipo da extensão
(linhas 111–115) e o `makeManualItem`. Substituir o comentário por:

```swift
/// Builds an item the user wrote by hand.
///
/// Born with `keepForever` rather than `isPinned`: hand-written items should
/// survive the pruner — that was always the intent — but pinning also sorts
/// them to the front of the history, which nobody asked for. Roadmap item 17
/// gave the app the field that says exactly what was meant.
```

e no corpo de `makeManualItem`, trocar `isPinned: true` por:

```swift
            keepForever: true
```

(o parâmetro `isPinned` some da chamada, voltando ao default `false`).

- [ ] **Step 12: Ajustar `ManualItemTests`**

Em `MyPasteAppTests/ManualItemTests.swift`, o teste da linha 31 afirma
`isPinned`. Substituir o comentário e a asserção por:

```swift
        // Hand-written items have to survive the pruner: they were never on a
        // pasteboard, so there's nothing to copy again if they're lost.
        // `keepForever` says that without also promoting them to the top of
        // the list, which is what `isPinned` did before Phase 5.
        #expect(ItemActions.makeManualItem(text: "note").keepForever)
        #expect(ItemActions.makeManualItem(text: "note").isPinned == false)
```

- [ ] **Step 13: Rodar a suíte completa**

Run:
```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```
Expected: PASS.

- [ ] **Step 14: Commit**

```bash
git add MyPasteApp/Services/ItemRetention.swift \
        MyPasteApp/Services/RetentionPolicy.swift \
        MyPasteApp/Services/ItemActions.swift \
        MyPasteApp/Views/Preferences/HistorySettingsView.swift \
        MyPasteAppTests/ItemRetentionTests.swift \
        MyPasteAppTests/RetentionPolicyTests.swift \
        MyPasteAppTests/ManualItemTests.swift
git commit -m "feat(retention): honour per-item retention and protect pinboards from pruning"
```

---

### Task 3: `PinboardScope` e o degrau do `⎋`

**Files:**
- Create: `MyPasteApp/Services/PinboardScope.swift`
- Modify: `MyPasteApp/Services/SearchState.swift`
- Test: `MyPasteAppTests/PinboardScopeTests.swift`, `MyPasteAppTests/SearchStateTests.swift`

**Interfaces:**
- Consumes: `ClipboardItem.pinboard`, `Pinboard.id` (Task 1).
- Produces:
  - `@Observable @MainActor final class PinboardScope` com `activeID: UUID?` (get público, set por `select`), `func select(_ id: UUID?)`, `func reset()`, `var isScoped: Bool`
  - `static func PinboardScope.contains(item: ClipboardItem, activeID: UUID?) -> Bool`
  - `SearchState.EscapeAction.leaveScope`, e `escapeAction(isFilterPanelOpen:isPreviewOpen:isActive:hasContent:hasMarks:hasScope:)`

- [ ] **Step 1: Escrever os testes do escopo**

Criar `MyPasteAppTests/PinboardScopeTests.swift`:

```swift
//
//  PinboardScopeTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Pinboard scope")
final class PinboardScopeTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    private func makeBoard(_ name: String) -> Pinboard {
        let board = Pinboard(name: name, colorHex: PinboardPalette.colors[0])
        context.insert(board)
        return board
    }

    private func makeItem(_ tag: String, in board: Pinboard? = nil) -> ClipboardItem {
        let item = ClipboardItem(type: .text, preview: tag, contentHash: tag, textContent: tag)
        context.insert(item)
        item.pinboard = board
        return item
    }

    @Test("The history scope contains everything")
    func historyContainsEverything() {
        let board = makeBoard("Work")
        let filed = makeItem("filed", in: board)
        let loose = makeItem("loose")

        #expect(PinboardScope.contains(item: filed, activeID: nil))
        #expect(PinboardScope.contains(item: loose, activeID: nil))
    }

    @Test("A board scope contains only its own items")
    func boardContainsOnlyItsOwn() {
        let work = makeBoard("Work")
        let links = makeBoard("Links")
        let filed = makeItem("filed", in: work)
        let elsewhere = makeItem("elsewhere", in: links)
        let loose = makeItem("loose")

        #expect(PinboardScope.contains(item: filed, activeID: work.id))
        #expect(PinboardScope.contains(item: elsewhere, activeID: work.id) == false)
        #expect(PinboardScope.contains(item: loose, activeID: work.id) == false)
    }

    @Test("Selecting a board scopes, selecting nil goes back to the history")
    func selectAndBack() {
        let scope = PinboardScope()
        let id = UUID()

        #expect(scope.activeID == nil)
        #expect(scope.isScoped == false)

        scope.select(id)
        #expect(scope.activeID == id)
        #expect(scope.isScoped)

        scope.select(nil)
        #expect(scope.activeID == nil)
        #expect(scope.isScoped == false)
    }

    @Test("Reset returns to the history")
    func resetReturnsToHistory() {
        // Called on every `show()`: reopening the drawer must never land in a
        // board, or the user copies something and doesn't see it appear.
        let scope = PinboardScope()
        scope.select(UUID())

        scope.reset()

        #expect(scope.activeID == nil)
    }
}
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `set -o pipefail && NSUnbufferedIO=YES xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp -configuration Debug -destination 'platform=macOS' -only-testing:MyPasteAppTests/PinboardScopeTests`
Expected: FAIL na compilação — `cannot find 'PinboardScope' in scope`.

- [ ] **Step 3: Escrever `PinboardScope`**

Criar `MyPasteApp/Services/PinboardScope.swift`:

```swift
//
//  PinboardScope.swift
//  MyPasteApp
//

import Foundation
import SwiftData

/// Which shelf the overlay is showing: the history, or one pinboard.
///
/// Exclusive by design — one scope at a time, the way `design-refs/13` shows
/// it. A pinboard is not another axis of `SearchFilter`: filters combine and
/// narrow, a scope replaces. Making it a filter axis would give the pills and
/// the filter panel two ways to do overlapping things, and the history would
/// never leave the screen.
///
/// Owned by `OverlayWindowController` and reset on every `show()`, for the
/// same reason `SearchState` and `MarkedSelection` are: `OverlayView` is built
/// once in `prepare()` and reused for the life of the process, so `@State`
/// here would outlive the drawer closing.
@Observable
@MainActor
final class PinboardScope {
    /// The active pinboard, or nil for the history.
    private(set) var activeID: UUID?

    var isScoped: Bool { activeID != nil }

    func select(_ id: UUID?) {
        activeID = id
    }

    func reset() {
        activeID = nil
    }
}

extension PinboardScope {
    /// Whether an item belongs on the shelf currently on screen.
    ///
    /// Applied before `ItemSearch.matches`, never inside it: "is this on this
    /// shelf?" and "does this match what I typed?" are separate questions, and
    /// folding the first into `SearchFilter` would put an exclusive,
    /// non-combinable axis next to three combinable ones.
    static func contains(item: ClipboardItem, activeID: UUID?) -> Bool {
        guard let activeID else { return true }
        return item.pinboard?.id == activeID
    }
}
```

- [ ] **Step 4: Rodar os testes do escopo**

Run: o comando do Step 2.
Expected: PASS, 4 testes.

- [ ] **Step 5: Escrever os testes do `⎋` com escopo**

Acrescentar a `MyPasteAppTests/SearchStateTests.swift`, dentro da suíte que já
cobre `escapeAction`:

```swift
    @Test("Escape leaves the pinboard before closing the drawer")
    func escapeLeavesScopeBeforeClosing() {
        #expect(SearchState.escapeAction(isFilterPanelOpen: false,
                                         isPreviewOpen: false,
                                         isActive: false,
                                         hasContent: false,
                                         hasMarks: false,
                                         hasScope: true) == .leaveScope)
    }

    @Test("Marks are dropped before the scope is left")
    func escapeClearsMarksBeforeScope() {
        // Most volatile first, all the way down: a mark is one keystroke to
        // rebuild, the scope is where the user navigated to.
        #expect(SearchState.escapeAction(isFilterPanelOpen: false,
                                         isPreviewOpen: false,
                                         isActive: false,
                                         hasContent: false,
                                         hasMarks: true,
                                         hasScope: true) == .clearMarks)
    }

    @Test("With nothing open and no scope, escape closes the drawer")
    func escapeWithoutScopeStillDismisses() {
        #expect(SearchState.escapeAction(isFilterPanelOpen: false,
                                         isPreviewOpen: false,
                                         isActive: false,
                                         hasContent: false,
                                         hasMarks: false,
                                         hasScope: false) == .dismissOverlay)
    }

    @Test("The search is let go of before the scope")
    func escapeClosesSearchBeforeScope() {
        #expect(SearchState.escapeAction(isFilterPanelOpen: false,
                                         isPreviewOpen: false,
                                         isActive: true,
                                         hasContent: true,
                                         hasMarks: false,
                                         hasScope: true) == .closeSearch)
    }
```

**Também:** todas as chamadas existentes de `escapeAction` nessa suíte ganham
`hasScope: false`. Sem isso a suíte não compila — e é de propósito: um
parâmetro novo com valor default deixaria os testes antigos passando sem nunca
declarar o que esperam do escopo.

- [ ] **Step 6: Rodar para ver falhar**

Run: `set -o pipefail && NSUnbufferedIO=YES xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp -configuration Debug -destination 'platform=macOS' -only-testing:MyPasteAppTests/SearchStateTests`
Expected: FAIL na compilação — `extra argument 'hasScope' in call`.

- [ ] **Step 7: Acrescentar o degrau em `SearchState`**

Em `MyPasteApp/Services/SearchState.swift`, no `enum EscapeAction`, entre
`.clearMarks` e `.dismissOverlay`:

```swift
        /// Go back to the history, leaving the drawer open.
        case leaveScope
```

E `escapeAction` passa a ser:

```swift
    /// Dismiss what's on top first, as the system does everywhere else.
    ///
    /// An empty search is skipped on purpose: making the user press escape
    /// twice to close a field they never typed into would tax the common case
    /// to serve the rare one.
    ///
    /// Marks come after the search, and the scope after the marks: with all
    /// three live, the first escape lets go of the search, the second clears
    /// the marks, the third returns to the history, the fourth closes the
    /// drawer — most volatile first, all the way down.
    static func escapeAction(isFilterPanelOpen: Bool,
                             isPreviewOpen: Bool,
                             isActive: Bool,
                             hasContent: Bool,
                             hasMarks: Bool,
                             hasScope: Bool) -> EscapeAction {
        if isFilterPanelOpen { return .closeFilterPanel }
        if isPreviewOpen { return .hidePreview }
        if isActive, hasContent { return .closeSearch }
        if hasMarks { return .clearMarks }
        if hasScope { return .leaveScope }
        return .dismissOverlay
    }
```

O call site em `OverlayView` ainda não passa `hasScope` — ele é ajustado na
Task 6, junto com o resto da fiação do escopo. Até lá, passe `hasScope: false`
explicitamente para o projeto compilar.

- [ ] **Step 8: Rodar a suíte completa**

Run:
```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add MyPasteApp/Services/PinboardScope.swift \
        MyPasteApp/Services/SearchState.swift \
        MyPasteApp/Views/OverlayView.swift \
        MyPasteAppTests/PinboardScopeTests.swift \
        MyPasteAppTests/SearchStateTests.swift
git commit -m "feat(pinboards): add the navigation scope and give escape its step"
```

---

### Task 4: A faixa de pílulas

**Files:**
- Create: `MyPasteApp/Views/Pinboards/PinboardPill.swift`
- Create: `MyPasteApp/Views/Pinboards/PinboardBar.swift`
- Modify: `MyPasteApp/Views/Search/OverlayTopBar.swift`
- Test: nenhum. `Views/` não é coberto pela suíte — ver Global Constraints.

**Interfaces:**
- Consumes: `Pinboard` (Task 1), `PinboardScope` (Task 3), `Color(hex:)` (Task 1).
- Produces:
  - `PinboardPill(title:colorHex:isSelected:isCollapsed:action:)` — `colorHex` nil desenha o ícone de relógio do Histórico
  - `PinboardBar(boards:activeID:isCollapsed:onSelect:onCreate:)`
  - `OverlayTopBar` ganha os parâmetros `boards: [Pinboard]`, `activeID: UUID?`, `onSelectScope: (UUID?) -> Void`, `onCreateBoard: () -> Void`

- [ ] **Step 1: Escrever a pílula**

Criar `MyPasteApp/Views/Pinboards/PinboardPill.swift`:

```swift
//
//  PinboardPill.swift
//  MyPasteApp
//

import SwiftUI

/// One entry in the scope strip: the history, or a pinboard.
///
/// Collapses to just its dot or glyph while the search is open — the strip and
/// the search field share the same horizontal band, and this is how the
/// reference resolves the conflict (`design-refs/12-busca-ativa.png`): nothing
/// disappears, it only loses its label.
struct PinboardPill: View {
    let title: String
    /// nil means the history pill, which shows a clock instead of a dot.
    let colorHex: String?
    let isSelected: Bool
    let isCollapsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                marker
                if !isCollapsed {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 120, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, isCollapsed ? 8 : 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color.primary.opacity(isSelected ? 0.15 : 0.06))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(title)
    }

    @ViewBuilder
    private var marker: some View {
        if let colorHex {
            Circle()
                .fill(Color(hex: colorHex) ?? .gray)
                .frame(width: 8, height: 8)
        } else {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .medium))
        }
    }
}
```

- [ ] **Step 2: Escrever a faixa**

Criar `MyPasteApp/Views/Pinboards/PinboardBar.swift`:

```swift
//
//  PinboardBar.swift
//  MyPasteApp
//

import SwiftUI

/// The scope strip: History first, then one pill per pinboard, then `+`.
///
/// History is always present and always first — it's where the drawer opens
/// and where every escape eventually returns to. Boards are ordered by
/// creation; reordering by drag is deliberately out of scope for Phase 5.
struct PinboardBar: View {
    let boards: [Pinboard]
    let activeID: UUID?
    /// True while the search field is open, so the pills give up their labels.
    let isCollapsed: Bool
    let onSelect: (UUID?) -> Void
    let onCreate: () -> Void
    /// Right-clicking a board pill. Wired in Task 5; a no-op until then.
    var contextMenu: (Pinboard) -> AnyView = { _ in AnyView(EmptyView()) }

    var body: some View {
        HStack(spacing: 8) {
            PinboardPill(title: "History",
                         colorHex: nil,
                         isSelected: activeID == nil,
                         isCollapsed: isCollapsed) { onSelect(nil) }

            ForEach(boards) { board in
                PinboardPill(title: board.name,
                             colorHex: board.colorHex,
                             isSelected: board.id == activeID,
                             isCollapsed: isCollapsed) { onSelect(board.id) }
                    .contextMenu { contextMenu(board) }
            }

            Button(action: onCreate) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New pinboard")
        }
    }
}
```

- [ ] **Step 3: Hospedar a faixa no topo**

Em `MyPasteApp/Views/Search/OverlayTopBar.swift`, acrescentar os parâmetros
novos, logo abaixo de `var markedCount: Int = 0`:

```swift
    /// The pinboards to offer as scopes, ordered by creation.
    var boards: [Pinboard] = []
    /// The active scope, or nil for the history.
    var activeScopeID: UUID?
    var onSelectScope: (UUID?) -> Void = { _ in }
    var onCreateBoard: () -> Void = {}
    var boardContextMenu: (Pinboard) -> AnyView = { _ in AnyView(EmptyView()) }
```

E trocar o corpo do `HStack` para hospedar a faixa nos dois estados. A faixa
reservada da Fase 3 (`// Reserved for Phase 5's pinboard pills` + `HStack(spacing: 8) {}`)
some, substituída por:

```swift
        HStack(spacing: 12) {
            if state.isActive {
                SearchFieldView(state: state,
                                focusTarget: $focusTarget,
                                onOpenFilters: onOpenFilters)
                    .frame(maxWidth: 470)
                PinboardBar(boards: boards,
                            activeID: activeScopeID,
                            isCollapsed: true,
                            onSelect: onSelectScope,
                            onCreate: onCreateBoard,
                            contextMenu: boardContextMenu)
            } else {
                Button(action: onActivate) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Search history")

                PinboardBar(boards: boards,
                            activeID: activeScopeID,
                            isCollapsed: false,
                            onSelect: onSelectScope,
                            onCreate: onCreateBoard,
                            contextMenu: boardContextMenu)
            }
        }
```

O comentário longo do `.overlay(alignment: .trailing)` abaixo continua válido e
não deve ser alterado: a pílula de contagem de marcados segue fora do layout do
`HStack`, que é o que impede a barra de se mexer quando a contagem cruza 0↔1.

- [ ] **Step 4: Compilar**

Run:
```bash
set -o pipefail && xcodebuild build \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```
Expected: BUILD SUCCEEDED. `OverlayView` ainda não passa os parâmetros novos — todos têm default, então compila; a fiação real é a Task 6.

- [ ] **Step 5: Rodar a suíte completa**

Run: o comando completo de teste.
Expected: PASS, sem testes novos (é `Views/`).

- [ ] **Step 6: Commit**

```bash
git add MyPasteApp/Views/Pinboards/PinboardPill.swift \
        MyPasteApp/Views/Pinboards/PinboardBar.swift \
        MyPasteApp/Views/Search/OverlayTopBar.swift
git commit -m "feat(pinboards): add the scope strip to the overlay's top bar"
```

---

### Task 5: Criar, renomear, recolorir, excluir

**Files:**
- Create: `MyPasteApp/Services/PinboardActions.swift`
- Create: `MyPasteApp/Views/Pinboards/PinboardContextMenu.swift`
- Modify: `MyPasteApp/Views/Pinboards/PinboardPill.swift` (renomeação inline)
- Test: `MyPasteAppTests/PinboardActionsTests.swift`

**Interfaces:**
- Consumes: `Pinboard`, `PinboardPalette` (Task 1), `PinboardPill` (Task 4).
- Produces:
  - `@MainActor struct PinboardActions(modelContext:)` com `create() -> Pinboard`, `rename(_:to:)`, `recolor(_:to:)`, `delete(_:)`, `allBoards() -> [Pinboard]`
  - `PinboardContextMenu(board:actions:onRename:onDeleted:)`
  - `PinboardPill` ganha `isEditing: Bool` e `onCommitName: (String) -> Void`

- [ ] **Step 1: Escrever os testes das ações**

Criar `MyPasteAppTests/PinboardActionsTests.swift`:

```swift
//
//  PinboardActionsTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Pinboard actions")
final class PinboardActionsTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }
    private var actions: PinboardActions { PinboardActions(modelContext: context) }

    @Test("A new board is untitled and takes the first free colour")
    func createTakesFirstFreeColour() throws {
        let first = actions.create()
        let second = actions.create()

        #expect(first.name == Pinboard.untitledName)
        #expect(first.colorHex == PinboardPalette.colors[0])
        #expect(second.colorHex == PinboardPalette.colors[1])
    }

    @Test("Boards come back in creation order")
    func boardsAreOrderedByCreation() throws {
        let first = actions.create()
        actions.rename(first, to: "First")
        let second = actions.create()
        actions.rename(second, to: "Second")

        #expect(actions.allBoards().map(\.name) == ["First", "Second"])
    }

    @Test("Renaming trims whitespace")
    func renameTrims() {
        let board = actions.create()

        actions.rename(board, to: "  Work  ")

        #expect(board.name == "Work")
    }

    @Test("Renaming to nothing falls back to Untitled")
    func renameToEmptyFallsBack() {
        // A pill with no label is a pill nobody can aim at.
        let board = actions.create()
        actions.rename(board, to: "Work")

        actions.rename(board, to: "   ")

        #expect(board.name == Pinboard.untitledName)
    }

    @Test("Recolouring stores the new hex")
    func recolorStores() {
        let board = actions.create()

        actions.recolor(board, to: PinboardPalette.colors[4])

        #expect(board.colorHex == PinboardPalette.colors[4])
    }

    @Test("Deleting a board keeps its items and releases them")
    func deleteReleasesItems() throws {
        // The promise of item 16, at the level the user actually triggers it.
        let board = actions.create()
        let item = ClipboardItem(type: .text, preview: "kept",
                                 contentHash: "kept", textContent: "kept")
        context.insert(item)
        item.pinboard = board
        try context.save()

        actions.delete(board)

        let items = try context.fetch(FetchDescriptor<ClipboardItem>())
        #expect(items.count == 1)
        #expect(items.first?.pinboard == nil)
        #expect(actions.allBoards().isEmpty)
    }
}
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `set -o pipefail && NSUnbufferedIO=YES xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp -configuration Debug -destination 'platform=macOS' -only-testing:MyPasteAppTests/PinboardActionsTests`
Expected: FAIL na compilação — `cannot find 'PinboardActions' in scope`.

- [ ] **Step 3: Escrever `PinboardActions`**

Criar `MyPasteApp/Services/PinboardActions.swift`:

```swift
//
//  PinboardActions.swift
//  MyPasteApp
//

import Foundation
import SwiftData

/// Everything that can be done to a pinboard, with no interface attached.
///
/// The same shape as `ItemActions`, and for the same reason: the pill's
/// context menu and the `+` button are two callers of one set of rules, and
/// keeping the rules here is what stops them from drifting apart.
@MainActor
struct PinboardActions {
    let modelContext: ModelContext

    /// Every board, in creation order — the order the strip shows them in.
    func allBoards() -> [Pinboard] {
        let descriptor = FetchDescriptor<Pinboard>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Creates an untitled board in the first colour nobody is using.
    ///
    /// The caller selects it and puts its pill straight into inline rename —
    /// see `PinboardBar`. Naming is not required: a board left as "Untitled"
    /// is a board, and cancelling a rename must never delete what was just
    /// created.
    @discardableResult
    func create() -> Pinboard {
        let board = Pinboard(name: Pinboard.untitledName,
                             colorHex: PinboardPalette.nextColor(usedBy: allBoards().map(\.colorHex)))
        modelContext.insert(board)
        try? modelContext.save()
        return board
    }

    func rename(_ pinboard: Pinboard, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        pinboard.name = trimmed.isEmpty ? Pinboard.untitledName : trimmed
        try? modelContext.save()
    }

    func recolor(_ pinboard: Pinboard, to hex: String) {
        pinboard.colorHex = hex
        try? modelContext.save()
    }

    /// Deletes the board. Its items stay in the history — the relationship's
    /// `.nullify` rule does that, and `PinboardActionsTests` holds it down.
    func delete(_ pinboard: Pinboard) {
        modelContext.delete(pinboard)
        try? modelContext.save()
    }
}
```

- [ ] **Step 4: Rodar os testes das ações**

Run: o comando do Step 2.
Expected: PASS, 6 testes.

- [ ] **Step 5: Escrever o menu de contexto da pílula**

Criar `MyPasteApp/Views/Pinboards/PinboardContextMenu.swift`:

```swift
//
//  PinboardContextMenu.swift
//  MyPasteApp
//

import SwiftUI

/// The right-click menu of a pinboard pill: rename, delete, recolour.
///
/// **No confirmation dialog, deliberately.** `OverlayWindowController`
/// dismisses the drawer on `windowDidResignKey`, so an `NSAlert` — which
/// becomes key — would close the overlay out from under the user, taking the
/// search, the marks and the scope with it. The consequence goes in the label
/// instead, which is honest because `.nullify` really does hand the items
/// back rather than delete them.
struct PinboardContextMenu: View {
    let board: Pinboard
    let actions: PinboardActions
    /// Puts the pill into inline rename — the same path the `+` button uses.
    let onRename: () -> Void
    /// Lets the caller drop the scope if the deleted board was the active one.
    let onDeleted: () -> Void

    var body: some View {
        Button("Rename") { onRename() }

        Button(deleteTitle) {
            actions.delete(board)
            onDeleted()
        }

        Divider()

        ForEach(PinboardPalette.colors, id: \.self) { hex in
            Button {
                actions.recolor(board, to: hex)
            } label: {
                // A swatch and its name: a colour-only row is unusable to
                // anyone who can't tell these eight apart, and SwiftUI menus
                // don't render a bare shape reliably anyway.
                Label {
                    Text(colorName(hex))
                } icon: {
                    Image(systemName: board.colorHex == hex
                          ? "largecircle.fill.circle" : "circle.fill")
                        .foregroundStyle(Color(hex: hex) ?? .gray)
                }
            }
        }
    }

    private var deleteTitle: String {
        let count = board.items.count
        guard count > 0 else { return "Delete" }
        return count == 1
            ? "Delete — 1 item returns to the history"
            : "Delete — \(count) items return to the history"
    }

    /// Index-based, so the names track `PinboardPalette.colors` by position
    /// rather than by a second hardcoded mapping of hex to word.
    private func colorName(_ hex: String) -> String {
        let names = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Grey"]
        guard let index = PinboardPalette.colors.firstIndex(of: hex),
              index < names.count else { return "Colour" }
        return names[index]
    }
}
```

- [ ] **Step 6: Dar renomeação inline à pílula**

Em `MyPasteApp/Views/Pinboards/PinboardPill.swift`, acrescentar dois membros
logo abaixo de `let action: () -> Void`:

```swift
    /// While true, the pill shows a text field instead of its label.
    var isEditing: Bool = false
    var onCommitName: (String) -> Void = { _ in }
```

Um `@State` para o texto e um `@FocusState` para o campo, logo abaixo:

```swift
    @State private var draft = ""
    @FocusState private var isFieldFocused: Bool
```

E no `HStack` do corpo, o `if !isCollapsed { Text(title) ... }` passa a:

```swift
                if isEditing {
                    TextField("", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 90)
                        .focused($isFieldFocused)
                        .onSubmit { onCommitName(draft) }
                        .onAppear {
                            draft = title
                            isFieldFocused = true
                        }
                        // Escape leaves the field without renaming. The board
                        // stays exactly as it was — cancelling a rename must
                        // never delete a board that was just created.
                        .onExitCommand { onCommitName(title) }
                } else if !isCollapsed {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 120, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)
                }
```

E `PinboardBar` ganha, junto de `contextMenu`:

```swift
    /// The board currently being renamed inline, if any.
    var editingID: UUID?
    var onCommitName: (Pinboard, String) -> Void = { _, _ in }
```

passando adiante no `ForEach`:

```swift
                PinboardPill(title: board.name,
                             colorHex: board.colorHex,
                             isSelected: board.id == activeID,
                             isCollapsed: isCollapsed,
                             action: { onSelect(board.id) },
                             isEditing: board.id == editingID,
                             onCommitName: { onCommitName(board, $0) })
```

**E `OverlayTopBar` tem que repassar os dois**, senão a renomeação inline nunca
chega à pílula — a Task 6 já os passa para `OverlayTopBar` esperando isso.
Acrescentar aos membros que a Task 4 criou:

```swift
    var editingBoardID: UUID?
    var onCommitBoardName: (Pinboard, String) -> Void = { _, _ in }
```

e aos **dois** call sites de `PinboardBar` no corpo (o do ramo `state.isActive`
e o do ramo em repouso):

```swift
                            editingID: editingBoardID,
                            onCommitName: onCommitBoardName)
```

- [ ] **Step 7: Compilar e rodar a suíte completa**

Run:
```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```
Expected: PASS, com os 6 testes novos.

- [ ] **Step 8: Commit**

```bash
git add MyPasteApp/Services/PinboardActions.swift \
        MyPasteApp/Views/Pinboards/PinboardContextMenu.swift \
        MyPasteApp/Views/Pinboards/PinboardPill.swift \
        MyPasteApp/Views/Pinboards/PinboardBar.swift \
        MyPasteAppTests/PinboardActionsTests.swift
git commit -m "feat(pinboards): create, rename, recolour and delete boards"
```

---

### Task 6: Escopo na lista, teclado e estado vazio

**Files:**
- Modify: `MyPasteApp/Views/OverlayView.swift`
- Modify: `MyPasteApp/Window/OverlayWindowController.swift`
- Test: nenhum novo — as regras já estão cobertas pelas Tasks 3 e 5.

**Interfaces:**
- Consumes: `PinboardScope` (Task 3), `PinboardBar`/`PinboardPill` (Task 4), `PinboardActions`/`PinboardContextMenu` (Task 5).
- Produces: `OverlayView` passa a receber `let scope: PinboardScope` no `init`, na mesma posição em que já recebe `marked`.

- [ ] **Step 1: Dar o escopo ao controller**

Em `MyPasteApp/Window/OverlayWindowController.swift`, ao lado das propriedades
que já guardam `searchState` e `markedSelection`:

```swift
    /// Owned here, not by the view, and reset on every opening — the same rule
    /// as `searchState` and `markedSelection`. Reopening the drawer inside a
    /// pinboard would mean copying something and not seeing it appear, which
    /// is the invisible-state failure the roadmap treats as the worst kind.
    let pinboardScope = PinboardScope()
```

Passar ao construir a `OverlayView` em `prepare()` (junto de `marked:`):

```swift
            scope: pinboardScope,
```

E em `show()`, no mesmo ponto onde `searchState.close()` e a limpeza da
marcação já acontecem:

```swift
        pinboardScope.reset()
```

- [ ] **Step 2: Receber o escopo na view**

Em `MyPasteApp/Views/OverlayView.swift`, ao lado de `let marked: MarkedSelection`:

```swift
    /// Owned by `OverlayWindowController`, like `search` and `marked`, and for
    /// the same reason. The controller resets it on every `show()`.
    let scope: PinboardScope
```

com o parâmetro correspondente no `init` (imediatamente após `marked:`) e a
atribuição `self.scope = scope`.

Acrescentar a query dos boards, abaixo da `@Query` que já existe:

```swift
    @Query(sort: \Pinboard.createdAt, order: .forward)
    private var boards: [Pinboard]
```

e o acesso às ações, ao lado de `itemActions`:

```swift
    private var pinboardActions: PinboardActions {
        PinboardActions(modelContext: modelContext)
    }
```

mais o estado da renomeação inline:

```swift
    /// The board whose pill is in inline rename, if any. View state, not
    /// controller state: it never has to survive the drawer closing.
    @State private var renamingBoardID: UUID?
```

- [ ] **Step 3: Aplicar o escopo em `filtered`**

Trocar a propriedade `filtered` por:

```swift
    private var filtered: [ClipboardItem] {
        let sorted = items.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.createdAt > b.createdAt
        }
        let now = Date.now
        // Scope first, search second: two separate questions, asked in the
        // order the user asked them — "show me this shelf", then "find this on
        // it". See `PinboardScope.contains`.
        return sorted
            .filter { PinboardScope.contains(item: $0, activeID: scope.activeID) }
            .filter {
                ItemSearch.matches(item: $0, query: search.text, filter: search.filter, now: now)
            }
    }
```

- [ ] **Step 4: Ligar a faixa**

Onde `OverlayTopBar` é construída, passar os parâmetros que a Task 4 criou:

```swift
                OverlayTopBar(state: search,
                              focusTarget: $focusTarget,
                              onActivate: activateSearch,
                              onOpenFilters: { search.isFilterPanelOpen.toggle() },
                              markedCount: marked.count,
                              boards: boards,
                              activeScopeID: scope.activeID,
                              onSelectScope: selectScope,
                              onCreateBoard: createBoard,
                              boardContextMenu: { board in
                                  AnyView(PinboardContextMenu(
                                      board: board,
                                      actions: pinboardActions,
                                      onRename: { renamingBoardID = board.id },
                                      onDeleted: {
                                          if scope.activeID == board.id { scope.select(nil) }
                                          if renamingBoardID == board.id { renamingBoardID = nil }
                                      }))
                              },
                              editingBoardID: renamingBoardID,
                              onCommitBoardName: { board, name in
                                  pinboardActions.rename(board, to: name)
                                  renamingBoardID = nil
                              })
```

E os dois métodos que isso chama:

```swift
    private func selectScope(_ id: UUID?) {
        scope.select(id)
        // The selection follows the new list's first card, through the same
        // path a search change already takes.
        selectedID = nil
    }

    /// Creates a board, makes it the active scope and opens its pill for
    /// renaming — the one flow `design-refs/14-pinboard-novo-vazio.png` shows.
    private func createBoard() {
        let board = pinboardActions.create()
        scope.select(board.id)
        renamingBoardID = board.id
        selectedID = nil
    }
```

- [ ] **Step 5: `⌃Tab` e `⌃⇧Tab`**

Junto dos outros `onKeyPress` da lista de cards:

```swift
        // ⌃Tab cycles scopes forward, ⌃⇧Tab back, History included in the
        // cycle. Control rather than Command because the menu bar AppKit
        // builds for the `Settings` scene owns a set of ⌘ keys — Phase 4
        // learned that the hard way with ⌘M. If the system swallows these
        // anyway (step E1 of the manual script), the fallback already chosen
        // is ⌥→ / ⌥←, which is a one-line change here.
        .onKeyPress(.tab) { press in
            guard press.modifiers.contains(.control) else { return .ignored }
            cycleScope(forward: !press.modifiers.contains(.shift))
            return .handled
        }
```

com:

```swift
    /// Steps through History → board 1 → board 2 → … → History.
    private func cycleScope(forward: Bool) {
        let ids: [UUID?] = [nil] + boards.map { Optional($0.id) }
        guard ids.count > 1 else { return }
        let current = ids.firstIndex(of: scope.activeID) ?? 0
        let step = forward ? 1 : -1
        let next = (current + step + ids.count) % ids.count
        selectScope(ids[next])
    }
```

- [ ] **Step 6: Fechar a cadeia do `⎋`**

No handler de Escape, passar o escopo (a Task 3 deixou `hasScope: false` fixo):

```swift
            hasScope: scope.isScoped)
```

e tratar o caso novo no `switch`, junto de `.clearMarks`:

```swift
            case .leaveScope:
                selectScope(nil)
```

- [ ] **Step 7: Estado vazio**

Onde a lista é montada, o ramo de lista vazia passa a distinguir os dois casos:

```swift
                if filtered.isEmpty {
                    // Two different empties: a board nobody filled yet, and a
                    // search that found nothing. Saying "no results" inside an
                    // untouched board would send the user hunting for a filter
                    // that isn't there.
                    Text(scope.isScoped && !search.hasContent ? "Empty Pinboard" : "No results")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
```

Se já existir um ramo de "sem resultados" na view, é **esse** ramo que muda —
não acrescente um segundo.

- [ ] **Step 8: Compilar e rodar a suíte completa**

Run:
```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add MyPasteApp/Views/OverlayView.swift \
        MyPasteApp/Window/OverlayWindowController.swift
git commit -m "feat(pinboards): scope the card list, wire the strip and cycle with ctrl-tab"
```

---

### Task 7: Cor do cabeçalho e ponto de filiação

**Files:**
- Modify: `MyPasteApp/Views/ClipboardCardView.swift`
- Modify: `MyPasteApp/Views/OverlayView.swift`
- Test: nenhum. `Views/`.

**Interfaces:**
- Consumes: `Pinboard.colorHex`, `Color(hex:)` (Task 1), `PinboardScope` (Task 3).
- Produces: `ClipboardCardView` ganha `headerColorOverride: Color?` e `boardDotColor: Color?`.

- [ ] **Step 1: Acrescentar os dois parâmetros ao card**

Em `MyPasteApp/Views/ClipboardCardView.swift`, abaixo de `var anyMarked: Bool = false`:

```swift
    /// Replaces the source app's colour in the header while a pinboard is the
    /// active scope.
    ///
    /// Decided by the caller, not here: `OverlayView` is what knows the scope,
    /// and a card that looked it up itself would be a second home for the same
    /// rule — the mistake `anyMarked` above exists to avoid.
    var headerColorOverride: Color? = nil
    /// A small dot marking which board this item belongs to, shown only in the
    /// history — inside a board, every card is that colour already.
    var boardDotColor: Color? = nil
```

E no início do `body`:

```swift
        let appColor = headerColorOverride ?? AppColorExtractor.color(for: item.sourceAppBundleID)
```

- [ ] **Step 2: Desenhar o ponto de filiação**

No `coloredHeader`, imediatamente antes do `if item.isPinned` que desenha o
alfinete:

```swift
            if let boardDotColor {
                Circle()
                    .fill(boardDotColor)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 0.5))
            }
```

- [ ] **Step 3: Passar as cores a partir da overlay**

Em `MyPasteApp/Views/OverlayView.swift`, dentro do `ForEach` que constrói os
cards, acrescentar os dois argumentos:

```swift
                            headerColorOverride: activeBoardColor,
                            boardDotColor: scope.isScoped
                                ? nil
                                : item.pinboard.flatMap { Color(hex: $0.colorHex) },
```

com:

```swift
    /// The active board's colour, or nil in the history.
    private var activeBoardColor: Color? {
        guard let activeID = scope.activeID else { return nil }
        return boards.first { $0.id == activeID }.flatMap { Color(hex: $0.colorHex) }
    }
```

- [ ] **Step 4: Compilar**

Run:
```bash
set -o pipefail && xcodebuild build \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Rodar a suíte completa**

Run: o comando completo de teste.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add MyPasteApp/Views/ClipboardCardView.swift \
        MyPasteApp/Views/OverlayView.swift
git commit -m "feat(pinboards): colour card headers by board and mark membership in the history"
```

---

### Task 8: As entradas de menu do card

**Files:**
- Modify: `MyPasteApp/Views/ItemContextMenu.swift`
- Modify: `MyPasteApp/Services/ItemActions.swift`
- Modify: `MyPasteApp/Views/OverlayView.swift` (passar os boards ao menu)
- Test: `MyPasteAppTests/ItemRetentionTests.swift` (estendido)

**Interfaces:**
- Consumes: `ItemRetention`, `RetentionOffer` (Task 2), `PinboardActions` (Task 5).
- Produces: `ItemActions.setRetention(_ retention: ItemRetention, on item: ClipboardItem)` e `ItemActions.assign(_ item: ClipboardItem, to board: Pinboard?)`.

- [ ] **Step 1: Escrever os testes das duas ações**

Acrescentar a `MyPasteAppTests/ItemRetentionTests.swift` uma suíte nova no
mesmo arquivo (precisa de contexto, por isso é uma classe):

```swift
@MainActor
@Suite("Item retention actions")
final class ItemRetentionActionTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    private func makeItem() -> ClipboardItem {
        let item = ClipboardItem(type: .text, preview: "a", contentHash: "a", textContent: "a")
        context.insert(item)
        return item
    }

    @Test("Setting forever clears any expiry date")
    func foreverClearsTheDate() {
        let item = makeItem()
        item.expiresAt = .now.addingTimeInterval(3600)

        ItemActions.setRetention(.forever, on: item)

        #expect(item.keepForever)
        #expect(item.expiresAt == nil)
    }

    @Test("Setting a date clears keep forever")
    func dateClearsForever() {
        let item = makeItem()
        item.keepForever = true
        let when = Date.now.addingTimeInterval(3600)

        ItemActions.setRetention(.until(when), on: item)

        #expect(item.keepForever == false)
        #expect(item.expiresAt == when)
    }

    @Test("Going back to global clears both")
    func globalClearsBoth() {
        let item = makeItem()
        item.keepForever = true
        item.expiresAt = .now

        ItemActions.setRetention(.global, on: item)

        #expect(item.keepForever == false)
        #expect(item.expiresAt == nil)
    }

    @Test("Assigning to a board fills the relationship, and nil clears it")
    func assignAndClear() {
        let item = makeItem()
        let board = Pinboard(name: "Work", colorHex: PinboardPalette.colors[0])
        context.insert(board)

        ItemActions.assign(item, to: board)
        #expect(item.pinboard?.id == board.id)

        ItemActions.assign(item, to: nil)
        #expect(item.pinboard == nil)
    }
}
```

O arquivo precisa de `import SwiftData` no topo, que ainda não tem.

- [ ] **Step 2: Rodar para ver falhar**

Run: `set -o pipefail && NSUnbufferedIO=YES xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp -configuration Debug -destination 'platform=macOS' -only-testing:MyPasteAppTests/ItemRetentionActionTests`
Expected: FAIL na compilação — `type 'ItemActions' has no member 'setRetention'`.

- [ ] **Step 3: Escrever as duas ações**

Em `MyPasteApp/Services/ItemActions.swift`, dentro da `extension ItemActions`
que já hospeda `resolvePastePlainText` e `makeManualItem`:

```swift
    /// Writes both retention fields at once.
    ///
    /// Static and free-standing because it needs nothing from an instance —
    /// and because writing the two fields together is the whole point: a
    /// caller that set only the one that changed is how the meaningless
    /// "keep forever **and** expires on Tuesday" state would be born. See
    /// `ItemRetention.fields`.
    static func setRetention(_ retention: ItemRetention, on item: ClipboardItem) {
        let fields = retention.fields
        item.keepForever = fields.keepForever
        item.expiresAt = fields.expiresAt
        try? item.modelContext?.save()
    }

    /// Files an item under a board, or lets it go with nil.
    ///
    /// Doesn't touch `createdAt` or `lastUsedAt`: filing something is not
    /// using it, and promoting it would reshuffle the history the user is
    /// looking at while they organise it.
    static func assign(_ item: ClipboardItem, to board: Pinboard?) {
        item.pinboard = board
        try? item.modelContext?.save()
    }
```

- [ ] **Step 4: Rodar os testes das ações**

Run: o comando do Step 2.
Expected: PASS, 4 testes.

- [ ] **Step 5: Acrescentar as entradas ao menu de contexto**

Em `MyPasteApp/Views/ItemContextMenu.swift`, dois membros novos, abaixo de
`let onDelete: () -> Void`:

```swift
    /// Every board, in strip order, for the "Add to Pinboard" submenu.
    let boards: [Pinboard]
    /// Creates a board and files this item into it, without changing the scope.
    let onFileInNewBoard: () -> Void
```

E, entre a entrada "Show in History" e o `Divider()` que precede "Delete":

```swift
        Divider()

        Menu(item.pinboard == nil ? "Add to Pinboard" : "Move to Pinboard") {
            ForEach(boards) { board in
                Button(board.name) { ItemActions.assign(item, to: board) }
            }
            if !boards.isEmpty { Divider() }
            Button("New Pinboard…") { onFileInNewBoard() }
        }

        if item.pinboard != nil {
            Button("Remove from Pinboard") { ItemActions.assign(item, to: nil) }
        }

        Menu(keepTitle) {
            Button(checked("Follow global policy", when: currentRetention == .global)) {
                ItemActions.setRetention(.global, on: item)
            }
            Button(checked("Never expire", when: currentRetention == .forever)) {
                ItemActions.setRetention(.forever, on: item)
            }
            Divider()
            ForEach(RetentionOffer.allCases, id: \.self) { offer in
                Button(offer.title) {
                    ItemActions.setRetention(.until(offer.date(from: .now)), on: item)
                }
            }
        }
```

com os três helpers, junto de `titled`:

```swift
    private var currentRetention: ItemRetention {
        ItemRetention.of(keepForever: item.keepForever, expiresAt: item.expiresAt)
    }

    /// Names the current state on the parent entry, so the menu can be read as
    /// an answer to "what happens to this item?" without opening the submenu.
    /// A duration chosen yesterday says nothing today, which is why the date
    /// is resolved rather than echoed back as "in 1 hour".
    private var keepTitle: String {
        switch currentRetention {
        case .global: return "Keep"
        case .forever: return "Keep — never expires"
        case .until(let date):
            let formatted = date.formatted(date: .abbreviated, time: .shortened)
            return "Keep — expires \(formatted)"
        }
    }

    /// A leading checkmark as plain text, for the same reason the shortcut
    /// glyphs here are plain text — see the type-level doc comment.
    private func checked(_ title: String, when isCurrent: Bool) -> String {
        isCurrent ? "✓ \(title)" : "   \(title)"
    }
```

- [ ] **Step 6: Passar os boards ao menu, na overlay**

Em `MyPasteApp/Views/OverlayView.swift`, onde `ItemContextMenu` é construída,
acrescentar:

```swift
                        boards: boards,
                        onFileInNewBoard: {
                            let board = pinboardActions.create()
                            ItemActions.assign(item, to: board)
                            renamingBoardID = board.id
                        },
```

O escopo **não** muda aqui: o usuário está olhando um card, não navegando.

- [ ] **Step 7: Compilar e rodar a suíte completa**

Run:
```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add MyPasteApp/Services/ItemActions.swift \
        MyPasteApp/Views/ItemContextMenu.swift \
        MyPasteApp/Views/OverlayView.swift \
        MyPasteAppTests/ItemRetentionTests.swift
git commit -m "feat(items): file items into pinboards and set per-item retention from the menu"
```

---

### Task 9: `AppRule`, storage e migração

**Files:**
- Create: `MyPasteApp/Services/AppRules.swift`
- Modify: `MyPasteApp/Services/PreferenceKeys.swift`
- Test: `MyPasteAppTests/AppRulesTests.swift`, `MyPasteAppTests/PreferenceKeysTests.swift`

**Interfaces:**
- Consumes: `ClipboardItemType` (existente).
- Produces:
  - `struct AppRule: Codable, Equatable, Identifiable` com `bundleID: String`, `allowedTypes: Set<ClipboardItemType>`, `var ignoresEverything: Bool`
  - `AppRules.load(from:) -> [AppRule]`, `AppRules.save(_:to:)`, `AppRules.ignoresEverything(_ bundleID: String?, rules: [AppRule]) -> Bool`, `AppRules.allows(type:from:rules:) -> Bool`, `AppRules.knownPasswordManagers: [String]`
  - `PreferenceKeys.appRules`

- [ ] **Step 1: Escrever os testes**

Criar `MyPasteAppTests/AppRulesTests.swift`:

```swift
//
//  AppRulesTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing

@testable import MyPasteApp

/// Swift Testing builds a fresh instance per test, so one property here gives
/// every test its own `UserDefaults` suite — and, crucially, keeps the
/// `TestDefaults` alive for the whole test. A local `TestDefaults(...).store`
/// would deallocate the owner at the end of the expression, and its `deinit`
/// removes the domain.
@Suite("App rules")
struct AppRulesTests {
    private let defaults = TestDefaults("app-rules")
    private var store: UserDefaults { defaults.store }

    // MARK: - Storage

    @Test("Saved rules come back unchanged")
    func roundTrips() {
        let rules = [
            AppRule(bundleID: "com.apple.Passwords", allowedTypes: []),
            AppRule(bundleID: "com.tinyspeck.slackmacgap", allowedTypes: [.text, .url]),
        ]

        AppRules.save(rules, to: store)

        #expect(AppRules.load(from: store) == rules)
    }

    @Test("An empty store yields no rules")
    func emptyStoreIsEmpty() {
        #expect(AppRules.load(from: store).isEmpty)
    }

    // MARK: - Migration

    @Test("The old one-per-line format becomes ignore-everything rules")
    func migratesTheOldFormat() {
        store.set("com.apple.Passwords\ncom.apple.keychainaccess",
                  forKey: PreferenceKeys.ignoredAppsRaw)

        let rules = AppRules.load(from: store)

        #expect(rules.count == 2)
        #expect(rules.allSatisfy(\.ignoresEverything))
        #expect(Set(rules.map(\.bundleID))
                == ["com.apple.Passwords", "com.apple.keychainaccess"])
    }

    @Test("Blank lines and stray spaces are dropped on migration")
    func migrationIgnoresBlankLines() {
        store.set("\n  com.apple.Passwords  \n\n\n", forKey: PreferenceKeys.ignoredAppsRaw)

        let rules = AppRules.load(from: store)

        #expect(rules.map(\.bundleID) == ["com.apple.Passwords"])
    }

    @Test("Corrupt JSON falls back to the old format, never to nothing")
    func corruptJSONFallsBackToTheOldFormat() {
        // Falling back to an empty list would silently start capturing from a
        // password manager the user excluded — the worst possible regression
        // in this feature, and the reason the old key is kept for a version.
        store.set("not json at all", forKey: PreferenceKeys.appRules)
        store.set("com.apple.Passwords", forKey: PreferenceKeys.ignoredAppsRaw)

        let rules = AppRules.load(from: store)

        #expect(rules.map(\.bundleID) == ["com.apple.Passwords"])
        #expect(rules.allSatisfy(\.ignoresEverything))
    }

    @Test("Saved rules win over the old key")
    func savedRulesWinOverTheOldKey() {
        store.set("com.apple.Passwords", forKey: PreferenceKeys.ignoredAppsRaw)
        AppRules.save([AppRule(bundleID: "com.tinyspeck.slackmacgap",
                               allowedTypes: [.text])], to: store)

        #expect(AppRules.load(from: store).map(\.bundleID) == ["com.tinyspeck.slackmacgap"])
    }

    // MARK: - Decisions

    @Test("An app with no rule is captured in full")
    func unknownAppIsCaptured() {
        let rules = [AppRule(bundleID: "com.apple.Passwords", allowedTypes: [])]

        #expect(AppRules.ignoresEverything("com.tinyspeck.slackmacgap", rules: rules) == false)
        #expect(AppRules.allows(type: .image, from: "com.tinyspeck.slackmacgap", rules: rules))
    }

    @Test("An empty rule ignores everything from that app")
    func emptyRuleIgnoresEverything() {
        let rules = [AppRule(bundleID: "com.apple.Passwords", allowedTypes: [])]

        #expect(AppRules.ignoresEverything("com.apple.Passwords", rules: rules))
    }

    @Test("A typed rule allows only its own types")
    func typedRuleFiltersByType() {
        let rules = [AppRule(bundleID: "com.tinyspeck.slackmacgap", allowedTypes: [.text, .url])]

        #expect(AppRules.allows(type: .text, from: "com.tinyspeck.slackmacgap", rules: rules))
        #expect(AppRules.allows(type: .url, from: "com.tinyspeck.slackmacgap", rules: rules))
        #expect(AppRules.allows(type: .image, from: "com.tinyspeck.slackmacgap", rules: rules) == false)
        #expect(AppRules.allows(type: .file, from: "com.tinyspeck.slackmacgap", rules: rules) == false)
    }

    @Test("A typed rule does not ignore everything")
    func typedRuleIsNotATotalBlock() {
        // The two decisions are asked at different points in poll(): getting
        // this wrong would drop everything from an app the user only wanted
        // narrowed.
        let rules = [AppRule(bundleID: "com.tinyspeck.slackmacgap", allowedTypes: [.text])]

        #expect(AppRules.ignoresEverything("com.tinyspeck.slackmacgap", rules: rules) == false)
    }

    @Test("An item with no source app is always allowed")
    func nilBundleIDIsAllowed() {
        // Hand-written items (roadmap item 10) carry the app's own bundle ID,
        // but anything else without a source has no rule to match and must not
        // be filtered by one.
        let rules = [AppRule(bundleID: "com.apple.Passwords", allowedTypes: [])]

        #expect(AppRules.ignoresEverything(nil, rules: rules) == false)
        #expect(AppRules.allows(type: .text, from: nil, rules: rules))
    }

    @Test("The known password managers list is non-empty and includes Apple's")
    func knownPasswordManagers() {
        #expect(AppRules.knownPasswordManagers.contains("com.apple.Passwords"))
        #expect(AppRules.knownPasswordManagers.count >= 5)
    }
}
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `set -o pipefail && NSUnbufferedIO=YES xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp -configuration Debug -destination 'platform=macOS' -only-testing:MyPasteAppTests/AppRulesTests`
Expected: FAIL na compilação — `cannot find 'AppRule' in scope`.

- [ ] **Step 3: Escrever `AppRules`**

Criar `MyPasteApp/Services/AppRules.swift`:

```swift
//
//  AppRules.swift
//  MyPasteApp
//

import Foundation

/// What the app is allowed to capture from one source app.
///
/// An empty `allowedTypes` means "ignore everything from this app" — the
/// all-or-nothing behaviour that `ignoredAppsRaw` used to provide on its own,
/// kept as the simple case because it covers most of the real use and must not
/// get harder to reach.
struct AppRule: Codable, Equatable, Identifiable {
    let bundleID: String
    var allowedTypes: Set<ClipboardItemType>

    var id: String { bundleID }
    var ignoresEverything: Bool { allowedTypes.isEmpty }

    init(bundleID: String, allowedTypes: Set<ClipboardItemType>) {
        self.bundleID = bundleID
        self.allowedTypes = allowedTypes
    }
}

/// Reading, writing and applying the per-app capture rules.
///
/// Stored as JSON in `UserDefaults` rather than in SwiftData: `ClipboardMonitor`
/// reads its settings without a `ModelContext` and should keep doing so, and a
/// privacy rule has no business inside the store that roadmap item 24 will
/// export.
enum AppRules {
    /// Every rule, migrating the pre-Phase-5 format when needed.
    ///
    /// Reading never falls back to "capture everything": a corrupt payload
    /// re-reads the old key instead of returning nothing, and the old key is
    /// left in place for a version so a decoding failure on any machine is
    /// still recoverable.
    static func load(from defaults: UserDefaults) -> [AppRule] {
        if let data = defaults.data(forKey: PreferenceKeys.appRules),
           let decoded = try? JSONDecoder().decode([AppRule].self, from: data) {
            return decoded
        }
        return migratedFromLegacy(defaults)
    }

    static func save(_ rules: [AppRule], to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: PreferenceKeys.appRules)
    }

    /// Whether nothing at all should be read from this app.
    ///
    /// Takes only a bundle ID — no pasteboard types — on purpose: this is the
    /// decision made *before* the pasteboard is read, and a signature that
    /// can't express content is a signature that can't accidentally start
    /// depending on it.
    static func ignoresEverything(_ bundleID: String?, rules: [AppRule]) -> Bool {
        guard let bundleID, let rule = rules.first(where: { $0.bundleID == bundleID })
        else { return false }
        return rule.ignoresEverything
    }

    /// Whether an item of this type, from this app, may be stored.
    static func allows(type: ClipboardItemType, from bundleID: String?, rules: [AppRule]) -> Bool {
        guard let bundleID, let rule = rules.first(where: { $0.bundleID == bundleID })
        else { return true }
        return rule.allowedTypes.contains(type)
    }

    /// Offered by a button in Settings, closing the gap Phase 1 left open: the
    /// system-level markers many of these don't set, including Apple's own
    /// Passwords app.
    static let knownPasswordManagers: [String] = [
        "com.apple.Passwords",
        "com.apple.keychainaccess",
        "com.1password.1password",
        "com.bitwarden.desktop",
        "com.dashlane.Dashlane",
    ]

    private static func migratedFromLegacy(_ defaults: UserDefaults) -> [AppRule] {
        let raw = defaults.string(forKey: PreferenceKeys.ignoredAppsRaw) ?? ""
        return raw
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { AppRule(bundleID: $0, allowedTypes: []) }
    }
}
```

- [ ] **Step 4: Acrescentar a chave**

Em `MyPasteApp/Services/PreferenceKeys.swift`, junto das outras:

```swift
    /// Per-app capture rules, JSON-encoded. Replaces `ignoredAppsRaw`, which
    /// is kept for a version as the migration source and the safety net.
    static let appRules = "appRules"
```

e no array `all`, acrescentar `appRules` ao fim da última linha.

- [ ] **Step 5: Estender `PreferenceKeysTests`**

Acrescentar `appRules` ao conjunto congelado de chaves, no mesmo formato dos
outros — a suíte existe para que uma chave renomeada quebre o build em vez de
perder a configuração de todo mundo em silêncio.

- [ ] **Step 6: Rodar a suíte completa**

Run:
```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```
Expected: PASS, com os 13 testes novos.

- [ ] **Step 7: Commit**

```bash
git add MyPasteApp/Services/AppRules.swift \
        MyPasteApp/Services/PreferenceKeys.swift \
        MyPasteAppTests/AppRulesTests.swift \
        MyPasteAppTests/PreferenceKeysTests.swift
git commit -m "feat(privacy): add per-app capture rules with migration from the ignored-apps list"
```

---

### Task 10: Os dois guards no `ClipboardMonitor`

**Files:**
- Modify: `MyPasteApp/Services/ClipboardMonitor.swift`
- Test: `MyPasteAppTests/ClipboardMonitorCaptureDecisionTests.swift`

**Interfaces:**
- Consumes: `AppRules` (Task 9).
- Produces: nenhuma API nova para outras tasks — as decisões são as funções puras de `AppRules`, já expostas.

- [ ] **Step 1: Escrever os testes da ordem nova**

Acrescentar a `MyPasteAppTests/ClipboardMonitorCaptureDecisionTests.swift`:

```swift
    // MARK: - Per-app rules (roadmap item 18)

    @Test("An app set to ignore everything is rejected before the pasteboard is read")
    func ignoredAppIsRejectedEarly() {
        // The point of this test is the *signature*, as much as the result:
        // this decision takes a bundle ID and nothing else, so it structurally
        // cannot come to depend on having read the content first. Before
        // Phase 5 the app check ran after readCurrentItem(), which meant a
        // banned app's content was read into memory and only then dropped.
        let rules = [AppRule(bundleID: "com.apple.Passwords", allowedTypes: [])]

        #expect(AppRules.ignoresEverything("com.apple.Passwords", rules: rules))
        #expect(AppRules.ignoresEverything("com.apple.Safari", rules: rules) == false)
    }

    @Test("A text-only app doesn't get its images stored")
    func typedRuleDropsOtherTypes() {
        let rules = [AppRule(bundleID: "com.tinyspeck.slackmacgap", allowedTypes: [.text])]

        #expect(AppRules.allows(type: .text, from: "com.tinyspeck.slackmacgap", rules: rules))
        #expect(AppRules.allows(type: .image, from: "com.tinyspeck.slackmacgap", rules: rules) == false)
    }

    @Test("Pause still wins over everything")
    func pauseStillWins() {
        // The guard order this suite exists to freeze: pause first, privacy
        // markers second, and only then anything app-specific.
        #expect(ClipboardMonitor.shouldCapture(isPaused: true,
                                               types: [plainText],
                                               settings: permissive) == false)
    }
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `set -o pipefail && NSUnbufferedIO=YES xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp -configuration Debug -destination 'platform=macOS' -only-testing:MyPasteAppTests/ClipboardMonitorCaptureDecisionTests`
Expected: PASS já neste passo — as funções vieram da Task 9. Estes testes
documentam o contrato que o Step 3 vai passar a consumir; se falharem aqui, a
Task 9 está incompleta.

- [ ] **Step 3: Reordenar os guards no `poll()`**

Em `MyPasteApp/Services/ClipboardMonitor.swift`, no `poll()`, **antes** de
`guard let item = readCurrentItem()`:

```swift
        // The per-app rules, first half: an app the user banned outright is
        // rejected here, before anything is read off the pasteboard. This used
        // to run *after* readCurrentItem(), which meant a password manager's
        // content was read into a ClipboardItem and only then dropped — never
        // stored, but read. `AppRules.ignoresEverything` takes a bundle ID and
        // nothing else, so this decision can't drift back into depending on
        // the content.
        let rules = AppRules.load(from: defaults)
        let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if AppRules.ignoresEverything(sourceApp, rules: rules) { return }

        guard let item = readCurrentItem() else { return }

        // Second half: filtering by type needs the type, which needs the read.
        // There is no way to bring this one forward.
        guard AppRules.allows(type: item.type, from: item.sourceAppBundleID, rules: rules) else {
            return
        }
```

E **apagar** o bloco antigo que ficava logo abaixo:

```swift
        // Skip ignored source apps.
        if let bundleID = item.sourceAppBundleID,
           Self.ignoredBundleIDs(from: defaults).contains(bundleID) {
            return
        }
```

Apagar também a função `ignoredBundleIDs(from:)` e qualquer teste que a
exercite diretamente — `AppRulesTests` cobre a mesma regra pelo caminho novo.

- [ ] **Step 4: Rodar a suíte completa**

Run:
```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```
Expected: PASS. Se algum teste referenciava `ignoredBundleIDs`, ele some junto
com a função — mas confirme que a regra que ele cobria tem equivalente em
`AppRulesTests` antes de apagá-lo.

- [ ] **Step 5: Commit**

```bash
git add MyPasteApp/Services/ClipboardMonitor.swift \
        MyPasteAppTests/ClipboardMonitorCaptureDecisionTests.swift
git commit -m "feat(privacy): reject banned apps before reading, and filter the rest by type"
```

---

### Task 11: A lista de regras em Ajustes

**Files:**
- Create: `MyPasteApp/Views/Preferences/AppRulesListView.swift`
- Modify: `MyPasteApp/Views/Preferences/PrivacySettingsView.swift`
- Test: nenhum. `Views/`.

**Interfaces:**
- Consumes: `AppRule`, `AppRules` (Task 9).
- Produces: `AppRulesListView()`, autossuficiente — lê e escreve as regras por conta própria.

- [ ] **Step 1: Escrever a lista**

Criar `MyPasteApp/Views/Preferences/AppRulesListView.swift`:

```swift
//
//  AppRulesListView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

/// The per-app capture rules, as an editable list.
///
/// Replaces the bundle-ID `TextEditor`: typing a reverse-DNS string from
/// memory was the part of this feature nobody could use. The rules themselves
/// live in `UserDefaults` through `AppRules` — this view is the only writer.
struct AppRulesListView: View {
    @State private var rules: [AppRule] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($rules) { $rule in
                AppRuleRow(rule: $rule, onRemove: { remove(rule) })
            }

            HStack(spacing: 12) {
                Button("Add App…") { addApp() }
                Button("Add Password Managers") { addPasswordManagers() }
            }
            .padding(.top, 4)

            Text("Nothing is read from an app set to ignore everything — not even into memory. This is the only protection that doesn't depend on the app marking its own content.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { rules = AppRules.load(from: .standard) }
        .onChange(of: rules) { _, newValue in
            AppRules.save(newValue, to: .standard)
        }
    }

    /// The system's own application picker, rather than a scan of
    /// /Applications: scanning means reading an Info.plist per app, and still
    /// misses anything installed elsewhere.
    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier else { return }

        insert(bundleID)
    }

    private func addPasswordManagers() {
        for bundleID in AppRules.knownPasswordManagers { insert(bundleID) }
    }

    /// New rules ignore everything — the safe default, and the case that
    /// covers most of the real use.
    private func insert(_ bundleID: String) {
        guard !rules.contains(where: { $0.bundleID == bundleID }) else { return }
        rules.append(AppRule(bundleID: bundleID, allowedTypes: []))
    }

    private func remove(_ rule: AppRule) {
        rules.removeAll { $0.bundleID == rule.bundleID }
    }
}

/// One app's rule: who it is, whether it's blocked outright, and which types
/// survive when it isn't.
private struct AppRuleRow: View {
    @Binding var rule: AppRule
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 0) {
                    Text(displayName)
                        .font(.system(size: 12, weight: .medium))
                    // Kept visible even when the name resolves: two installed
                    // apps can share a display name, and the bundle ID is what
                    // the rule actually matches on.
                    Text(rule.bundleID)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: modeBinding) {
                    Text("Ignore everything").tag(true)
                    Text("Capture only").tag(false)
                }
                .labelsHidden()
                .frame(width: 160)
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .help("Remove this rule")
            }

            if !rule.ignoresEverything {
                HStack(spacing: 12) {
                    ForEach(ClipboardItemType.canonicalOrder, id: \.self) { type in
                        Toggle(label(for: type), isOn: typeBinding(type))
                            .toggleStyle(.checkbox)
                    }
                }
                .padding(.leading, 26)
            }
        }
    }

    /// Flipping to "Capture only" seeds every type on: the user is narrowing
    /// from there, and a row that starts with nothing checked would be an
    /// "ignore everything" rule wearing the other label.
    private var modeBinding: Binding<Bool> {
        Binding(
            get: { rule.ignoresEverything },
            set: { ignoreAll in
                rule.allowedTypes = ignoreAll ? [] : Set(ClipboardItemType.allCases)
            }
        )
    }

    /// Unchecking the last type would silently mean "ignore everything" while
    /// the picker still says "Capture only" — so the last one can't be
    /// unchecked. The way to block an app entirely is the picker.
    private func typeBinding(_ type: ClipboardItemType) -> Binding<Bool> {
        Binding(
            get: { rule.allowedTypes.contains(type) },
            set: { isOn in
                if isOn {
                    rule.allowedTypes.insert(type)
                } else if rule.allowedTypes.count > 1 {
                    rule.allowedTypes.remove(type)
                }
            }
        )
    }

    private func label(for type: ClipboardItemType) -> String {
        switch type {
        case .text:  return "Text"
        case .url:   return "Links"
        case .image: return "Images"
        case .file:  return "Files"
        }
    }

    private var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleID)
    }

    private var displayName: String {
        guard let url = appURL else { return rule.bundleID }
        return FileManager.default.displayName(atPath: url.path)
    }

    /// A generic icon when the app isn't installed. The rule stays valid
    /// either way — removing it is the user's call, not the app's.
    private var icon: NSImage {
        guard let url = appURL else {
            return NSWorkspace.shared.icon(for: .applicationBundle)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
```

- [ ] **Step 2: Trocar a seção em Ajustes**

Em `MyPasteApp/Views/Preferences/PrivacySettingsView.swift`, substituir a
`Section("Ignored apps")` inteira por:

```swift
            Section("App rules") {
                AppRulesListView()
            }
```

E remover a propriedade `@AppStorage(PreferenceKeys.ignoredAppsRaw) private var ignoredAppsRaw: String = ""`,
que deixa de ser lida aqui. **Não** apagar a chave em si: `AppRules` ainda a lê
como fonte de migração e rede de segurança.

O texto de "Marked content" logo acima menciona "Those have to be listed
below" — continua correto, e a lista abaixo agora é a nova.

- [ ] **Step 3: Compilar**

Run:
```bash
set -o pipefail && xcodebuild build \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Rodar a suíte completa**

Run: o comando completo de teste.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add MyPasteApp/Views/Preferences/AppRulesListView.swift \
        MyPasteApp/Views/Preferences/PrivacySettingsView.swift
git commit -m "feat(settings): replace the bundle-ID editor with an app rules list"
```

---

### Task 12: Roteiro de verificação manual e documentação

**Files:**
- Create: `VERIFICACAO-FASE-5.md`
- Modify: `ROADMAP.md` (documento local, **não** versionado — não entra no commit)
- Test: nenhum.

- [ ] **Step 1: Escrever o roteiro**

Criar `VERIFICACAO-FASE-5.md` no formato de `VERIFICACAO-FASE-4.md`: blocos com
passos numerados, cada um com critério binário de passa/falha. Blocos e
conteúdo mínimo:

**A — Migração do store** (antes de tudo; se falhar, nada mais importa)
1. Com o app da branch instalado, abrir com o banco da versão anterior. O
   histórico aparece completo, com a mesma contagem de antes.
2. Itens fixados continuam fixados e continuam à frente na lista.
3. Nenhum diálogo de erro de store, nenhum histórico vazio.

**B — A faixa de pílulas**
1. `+` cria uma pílula "Untitled" já selecionada e em edição.
2. Digitar um nome e `↵` renomeia; a pílula mostra o nome novo.
3. `+` de novo: a segunda pílula nasce de cor **diferente** da primeira.
4. `⎋` durante a renomeação sai da edição e **a pílula continua existindo**.
5. Botão direito na pílula: Rename, Delete e as oito cores aparecem.
6. Escolher uma cor: a pílula muda de cor na hora.
7. Excluir uma pílula com N itens: o rótulo diz "N items return to the
   history", e depois de excluir esses N itens continuam no Histórico.
8. Abrir a busca: as pílulas perdem o rótulo e mantêm ponto/relógio; nenhuma
   some, e o campo de busca não fica espremido.

**C — Escopo**
1. Clicar numa pílula de pinboard: a lista passa a mostrar só os itens dele.
2. Pinboard vazio mostra "Empty Pinboard" centralizado.
3. Buscar dentro de um pinboard: filtra só dentro dele.
4. Com busca ativa dentro de um pinboard, `⎋` fecha a busca e **continua no
   pinboard**; `⎋` de novo volta ao Histórico; `⎋` de novo fecha a gaveta.
5. Marcar itens (`⌘M`), estar num pinboard e apertar `⎋`: primeiro limpa as
   marcas, só depois sai do pinboard.
6. Fechar e reabrir a gaveta: volta ao Histórico.
7. Dentro de um pinboard, `⌘1` cola o primeiro card visível **dele**.

**D — Retenção**
1. Menu de contexto de um card → `Keep`: o estado atual aparece com `✓`.
2. Marcar "Never expire": a entrada pai passa a dizer "Keep — never expires".
3. Marcar "Expire in 1 hour": a entrada pai passa a mostrar a data e a hora
   resolvidas, não "in 1 hour".
4. Em Ajustes → History, "Clear history": itens fixados, itens em pinboards e
   itens "never expire" continuam lá; o resto some.
5. Item escrito à mão (`Novo item`) sobrevive ao "Clear history" **e** não
   aparece fixado no topo da lista.

**E — Teclado**
1. **E1 (o mais importante):** com a gaveta aberta e mais de um pinboard,
   `⌃Tab` troca de escopo. Se nada acontecer, a tecla está sendo engolida —
   trocar para `⌥→`/`⌥←` em `OverlayView.onKeyPress`, uma linha.
2. `⌃⇧Tab` volta.
3. O ciclo passa pelo Histórico e não pula nenhuma pílula.
4. **Herdado da Fase 4, ainda não verificado:** `⌘M` marca um card para
   colagem múltipla e não é engolido pelo menu Window ▸ Minimize.

**F — Regras por app**
1. Ajustes → Privacy: as exclusões antigas (se havia alguma) aparecem na lista
   nova, cada uma como "Ignore everything".
2. "Add App…" abre o seletor do sistema e a escolha entra na lista com ícone e
   nome.
3. "Add Password Managers" acrescenta os cinco de uma vez, sem duplicar os que
   já estavam.
4. Pôr um app em "Capture only" com só Text marcado; copiar uma **imagem**
   nesse app: nenhum card novo aparece.
5. Copiar um **texto** no mesmo app: o card aparece normalmente.
6. Pôr um app em "Ignore everything" e copiar qualquer coisa nele: nada
   aparece.

Fechar com uma seção "Decisões e comportamentos conhecidos", fora do pass/fail,
listando: arrastar card até a pílula não faz nada (fora de escopo); um item
pertence a um pinboard por vez; a exclusão de pinboard não pede confirmação por
impossibilidade técnica documentada; o bug do `⌘1` continua aberto.

- [ ] **Step 2: Atualizar o board**

Mover os três cards para `🔍 Revisão` em `MyPasteApp/Board.md` e pôr
`status: revisão` nos três frontmatters — os dois passos sempre juntos.

- [ ] **Step 3: Commit**

```bash
git add VERIFICACAO-FASE-5.md
git commit -m "docs(fase-5): add the manual verification script"
```

---

## Revisão final de branch

**Obrigatória antes do PR, e não substituível pelas revisões por tarefa.**
Quatro fases seguidas tiveram seus piores defeitos encontrados exatamente aqui:
as revisões por tarefa olham uma tarefa, e o que falha é a costura entre elas.
Esta fase tem doze tarefas e três itens de roadmap numa branch só, o que torna
essa costura maior que em qualquer fase anterior.

Pontos que a revisão de branch deve olhar especificamente:

1. **A poda.** Três passadas novas que apagam dados sem desfazer. Confirmar que
   nenhuma delas pode apagar um item protegido por engano, e que `isProtected`
   é a única regra consultada — em `RetentionPolicy` **e** em
   `HistorySettingsView`.
2. **O escopo e a marcação.** A marcação resolve contra a lista completa e o
   escopo filtra `filtered`: confirmar que marcar dentro de um pinboard, sair
   dele e colar entrega os itens certos.
3. **Ordem dos guards de captura.** O guard de app banido tem que estar acima
   de `readCurrentItem()`. É a garantia central do app.
4. **A cadeia do `⎋`**, agora com seis degraus, e o `⌃Tab`.
5. **Os defaults dos parâmetros novos de view.** `OverlayTopBar`,
   `PinboardBar`, `PinboardPill`, `ClipboardCardView` e `ItemContextMenu`
   ganharam parâmetros com valor default para compilar entre tarefas.
   Confirmar que nenhum call site real ficou usando o default por esquecimento
   — um `boards: []` esquecido é um submenu vazio que não erra em lugar nenhum.
