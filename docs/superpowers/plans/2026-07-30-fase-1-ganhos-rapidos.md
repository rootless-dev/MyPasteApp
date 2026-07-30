# Fase 1 — Ganhos rápidos: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar os itens 1 a 5 do `ROADMAP.md` — atalhos numerados de colagem rápida, pausa da coleta com durações e feedback visual, ocultação em compartilhamento de tela e respeito aos marcadores de privacidade do pasteboard.

**Architecture:** Toda regra decidível vira função ou tipo puro num arquivo próprio em `MyPasteApp/Services/` (`QuickPaste`, `PauseState`, `PauseDuration`, `WindowPrivacy`, `PasteboardPrivacy`), coberta por testes; as views e o `AppDelegate` apenas consomem essas regras. `HotkeyManager` deixa de ser single-tenant para suportar uma segunda hotkey global.

**Tech Stack:** Swift 5, SwiftUI, AppKit, SwiftData, Carbon HIToolbox (hotkeys globais), Swift Testing.

Spec: `docs/superpowers/specs/2026-07-30-fase-1-ganhos-rapidos-design.md`

## Global Constraints

- Xcode 26.6, SDK macOS 26.5, deployment target 26.2, `SWIFT_VERSION = 5.0`.
- O projeto usa `PBXFileSystemSynchronizedRootGroup`: **arquivos novos entram no alvo por existirem no diretório**. Nunca editar `project.pbxproj`.
- Arquivos de app vão em `MyPasteApp/Services/`, `MyPasteApp/Views/` ou `MyPasteApp/Window/`. Testes vão em `MyPasteAppTests/`.
- Comando de teste (o mesmo da CI):
  ```bash
  xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
    -configuration Debug -destination 'platform=macOS'
  ```
  Para um suite só, acrescentar `-only-testing:MyPasteAppTests/<NomeDoSuite>`.
- Testes usam **Swift Testing** (`import Testing`, `@Test`, `@Suite`, `#expect`), nunca XCTest.
- Testes que leem preferências usam `TestDefaults("<rótulo>")` e passam `defaults.store` explicitamente. Nunca tocar `UserDefaults.standard` num teste.
- **Nenhuma chave de `@AppStorage` existente pode ser renomeada.**
- Texto de menu e de Preferências em **inglês**, como o resto dessas telas. Rótulos dentro do card seguem em português, como já estão.
- Mensagens de commit em inglês, Conventional Commits.
- Branch: `feature/fase-1-ganhos-rapidos`, criada a partir de `develop`.
- Commits desta fase estão **autorizados de antemão** pelo Carlos (2026-07-30):
  cada task commita seu próprio trabalho ao terminar, sem parar para pedir OK.
  A autorização vale só para os commits descritos neste plano, na branch
  `feature/fase-1-ganhos-rapidos`. Nada de `git push`, `gh pr create`, merge ou
  rebase sem pedir.
- Os documentos em `docs/superpowers/` **não** entram em nenhum commit deste
  plano — só arquivos de código e de teste.

## Estrutura de arquivos

**Criados:**

| Arquivo | Responsabilidade |
|---|---|
| `MyPasteApp/Services/QuickPaste.swift` | Mapear dígito pressionado ↔ posição do card, e o rótulo do chip |
| `MyPasteApp/Services/PauseController.swift` | `PauseState`, `PauseDuration` e o controller que detém estado, timer e notificação |
| `MyPasteApp/Services/WindowPrivacy.swift` | Traduzir a preferência de compartilhamento de tela em `NSWindow.SharingType` |
| `MyPasteApp/Services/PasteboardPrivacy.swift` | Decidir se os tipos presentes no pasteboard devem ser ignorados |
| `MyPasteAppTests/QuickPasteTests.swift` | Testes de `QuickPaste` |
| `MyPasteAppTests/PauseTests.swift` | Testes de `PauseState` e `PauseDuration` |
| `MyPasteAppTests/WindowPrivacyTests.swift` | Testes de `WindowPrivacy` |
| `MyPasteAppTests/PasteboardPrivacyTests.swift` | Testes de `PasteboardPrivacy` |

**Modificados:**

| Arquivo | O quê |
|---|---|
| `MyPasteApp/Services/HotkeyManager.swift` | Suporte a N hotkeys: handler compartilhado, instâncias por id |
| `MyPasteApp/Services/KeyCombo.swift` | `load`/`save` por chave, fallback parametrizado, `conflicts`, constantes da pausa |
| `MyPasteApp/Services/ClipboardMonitor.swift` | Consulta o `PauseController`; checagem de privacidade antes de ler o conteúdo |
| `MyPasteApp/AppDelegate.swift` | Segunda hotkey, submenu de pausa, ícone da status bar, política de compartilhamento |
| `MyPasteApp/Window/OverlayWindowController.swift` | `applySharingPolicy()` |
| `MyPasteApp/Views/OverlayView.swift` | `⌘1`–`⌘9`, `ForEach` com índice |
| `MyPasteApp/Views/ClipboardCardView.swift` | Chip do atalho no rodapé |
| `MyPasteApp/Views/PreferencesView.swift` | Seis controles novos, altura 640 |
| `MyPasteAppTests/KeyComboTests.swift` | Testes de chave, fallback, conflito e `userInfo` |
| `MyPasteAppTests/ClipboardPreferencesTests.swift` | Remoção dos dois testes de `isMonitoringPaused` |

## Ajustes em relação à spec

Três diferenças, todas de forma e nenhuma de escopo:

**Seis commits, não cinco.** O commit da pausa foi dividido em dois — o
mecanismo (controller + monitor) e a interface (submenu, ícone, hotkey). São
revisáveis de forma independente, e juntos formariam um commit grande demais
para revisar de uma vez.

**As durações viram um tipo, não um array de `TimeInterval`.** A spec previa
`PauseController.offeredDurations: [TimeInterval]`; o plano usa
`PauseDuration`, com `seconds` e `title`. O título ("15 minutes", "1 hour") é
lógica pura com um plural a acertar, e assim ele fica testado em vez de
enterrado numa função privada do `AppDelegate`.

**A preferência de compartilhamento de tela ganha arquivo próprio.** A spec
não dizia onde morava o leitor. Ele vai para `WindowPrivacy`, e não para um
`static` de `OverlayWindowController`, porque este é `@MainActor` e a regra é
pura — separada, ela é testável sem instanciar janela nenhuma.

---

### Task 1: `HotkeyManager` para mais de uma hotkey

**Files:**
- Modify: `MyPasteApp/Services/KeyCombo.swift:104-131`
- Modify: `MyPasteApp/Services/HotkeyManager.swift` (arquivo inteiro)
- Modify: `MyPasteApp/AppDelegate.swift:47-49,57-65`
- Test: `MyPasteAppTests/KeyComboTests.swift`

**Interfaces:**
- Consumes: nada (primeira task)
- Produces:
  - `KeyCombo.pauseStorageKey: String` (`"pauseHotkey"`)
  - `KeyCombo.pauseDefault: KeyCombo` (⌘⇧P)
  - `KeyCombo.load(from:key:fallback:) -> KeyCombo`
  - `KeyCombo.save(_:to:key:)` — posta `.hotkeyChanged` com `userInfo["key"]`
  - `KeyCombo.conflicts(_:with:) -> Bool`
  - `KeyCombo.storedPause: KeyCombo` (get/set)
  - `HotkeyManager.ID` (`.overlay = 1`, `.pause = 2`)
  - `HotkeyManager.init(id:storageKey:fallback:callback:)`

`HotkeyManager` depende de Carbon e de estado global do processo; não há teste
automatizado viável para ele. A cobertura desta task está em `KeyCombo`, e o
comportamento do manager é verificado manualmente no Step 8.

- [ ] **Step 1: Criar a branch**

```bash
git checkout develop
git pull --ff-only
git checkout -b feature/fase-1-ganhos-rapidos
```

- [ ] **Step 2: Escrever os testes que falham**

Acrescentar ao fim de `MyPasteAppTests/KeyComboTests.swift`, **dentro** do
`struct KeyComboTests` (antes da chave final do struct). O suite é
`.serialized` porque conta posts de `.hotkeyChanged`; manter assim.

```swift
    // MARK: - Multiple hotkeys

    @Test("The pause default is ⌘⇧P")
    func pauseDefaultCombo() {
        #expect(KeyCombo.pauseDefault.keyCode == UInt32(kVK_ANSI_P))
        #expect(KeyCombo.pauseDefault.carbonModifiers == UInt32(cmdKey | shiftKey))
    }

    @Test("Each storage key holds its own combo")
    func keysAreIndependent() {
        let overlay = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_V), nsFlags: [.command, .shift])
        let pause = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_P), nsFlags: [.command, .option])
        KeyCombo.save(overlay, to: defaults.store)
        KeyCombo.save(pause, to: defaults.store, key: KeyCombo.pauseStorageKey)

        #expect(KeyCombo.load(from: defaults.store) == overlay)
        #expect(KeyCombo.load(from: defaults.store, key: KeyCombo.pauseStorageKey) == pause)
    }

    @Test("An empty store yields the fallback that was asked for")
    func loadUsesGivenFallback() {
        // Without a per-call fallback the pause hotkey would come back as ⌘⇧V,
        // silently shadowing the overlay shortcut.
        let loaded = KeyCombo.load(from: defaults.store,
                                   key: KeyCombo.pauseStorageKey,
                                   fallback: .pauseDefault)
        #expect(loaded == .pauseDefault)
    }

    @Test("Identical combos conflict")
    func conflictsWhenIdentical() {
        let a = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_V), nsFlags: [.command, .shift])
        let b = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_V), nsFlags: [.command, .shift])
        #expect(KeyCombo.conflicts(a, with: b))
    }

    @Test("A different key or modifier is not a conflict")
    func doesNotConflictWhenDifferent() {
        let base = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_V), nsFlags: [.command, .shift])
        let otherKey = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_P), nsFlags: [.command, .shift])
        let otherMods = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_V), nsFlags: [.command, .option])
        #expect(!KeyCombo.conflicts(base, with: otherKey))
        #expect(!KeyCombo.conflicts(base, with: otherMods))
    }

    @Test("Saving reports which key changed")
    func savePostsChangedKey() async {
        await confirmation("hotkeyChanged carried the pause key") { posted in
            let token = NotificationCenter.default.addObserver(
                forName: .hotkeyChanged,
                object: nil,
                queue: nil
            ) { note in
                if note.userInfo?["key"] as? String == KeyCombo.pauseStorageKey {
                    posted()
                }
            }
            defer { NotificationCenter.default.removeObserver(token) }

            KeyCombo.save(.pauseDefault, to: defaults.store, key: KeyCombo.pauseStorageKey)
        }
    }
```

- [ ] **Step 3: Rodar os testes e confirmar que falham**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/KeyComboTests
```

Esperado: **falha de compilação** — `pauseStorageKey`, `pauseDefault`,
`conflicts` e os parâmetros `key:`/`fallback:` não existem. Falha de compilação
conta como teste vermelho aqui: o código sob teste ainda não existe.

- [ ] **Step 4: Estender `KeyCombo`**

Substituir o bloco `// MARK: - Persistence` inteiro
(`MyPasteApp/Services/KeyCombo.swift:104-131`) por:

```swift
// MARK: - Persistence

extension KeyCombo {
    /// Storage key of the show/hide-overlay shortcut.
    static let storageKey = "globalHotkey"
    /// Storage key of the pause/resume-capture shortcut.
    static let pauseStorageKey = "pauseHotkey"

    static let pauseDefault = KeyCombo(
        keyCode: UInt32(kVK_ANSI_P),
        carbonModifiers: UInt32(cmdKey | shiftKey)
    )

    /// Reads the combo stored under `key`, falling back to `fallback` when
    /// nothing is stored or the stored data can't be decoded.
    ///
    /// The fallback is a parameter rather than always `.default` because each
    /// shortcut has its own: defaulting the pause shortcut to ⌘⇧V would
    /// shadow the overlay one.
    static func load(from defaults: UserDefaults = .standard,
                     key: String = storageKey,
                     fallback: KeyCombo = .default) -> KeyCombo {
        guard let data = defaults.data(forKey: key),
              let combo = try? JSONDecoder().decode(KeyCombo.self, from: data)
        else { return fallback }
        return combo
    }

    /// Persists `combo` under `key` and posts `.hotkeyChanged` carrying that
    /// key, so only the affected shortcut gets re-registered.
    static func save(_ combo: KeyCombo,
                     to defaults: UserDefaults = .standard,
                     key: String = storageKey) {
        if let data = try? JSONEncoder().encode(combo) {
            defaults.set(data, forKey: key)
        }
        NotificationCenter.default.post(name: .hotkeyChanged,
                                        object: nil,
                                        userInfo: ["key": key])
    }

    /// Two shortcuts can't share a combination: `RegisterEventHotKey` would
    /// either refuse the second one or leave it silently dead.
    static func conflicts(_ combo: KeyCombo, with other: KeyCombo) -> Bool {
        combo == other
    }

    static var stored: KeyCombo {
        get { load() }
        set { save(newValue) }
    }

    static var storedPause: KeyCombo {
        get { load(key: pauseStorageKey, fallback: pauseDefault) }
        set { save(newValue, key: pauseStorageKey) }
    }
}

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("MyPasteApp.hotkeyChanged")
}
```

- [ ] **Step 5: Rodar os testes e confirmar que passam**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/KeyComboTests
```

Esperado: **PASS**, incluindo os testes que já existiam.

- [ ] **Step 6: Reescrever `HotkeyManager`**

Substituir o conteúdo inteiro de `MyPasteApp/Services/HotkeyManager.swift` por:

```swift
//
//  HotkeyManager.swift
//  MyPasteApp
//
//  Registers a global shortcut through Carbon's RegisterEventHotKey.
//

import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
final class HotkeyManager {
    /// Identifies each shortcut inside the shared Carbon event handler.
    ///
    /// The Carbon signature is the same for every shortcut of this app; what
    /// tells them apart is this id. Indexing by signature — as an earlier
    /// version did — meant a second shortcut resolved to the first one's
    /// callback.
    enum ID: UInt32 {
        case overlay = 1
        case pause = 2
    }

    private static let signature: UInt32 = 0x4D5053_56 // 'MPSV'

    /// Installed once for the whole process. Installing one handler per
    /// `register()` call would deliver every hotkey press to every handler,
    /// firing each callback as many times as there are handlers.
    private static var sharedHandler: EventHandlerRef?

    /// Keeps a strong reference for the C callback bridge, keyed by `ID`.
    private static var instances: [UInt32: HotkeyManager] = [:]

    private let id: ID
    private let storageKey: String
    private let fallback: KeyCombo
    private let callback: () -> Void
    private var hotKeyRef: EventHotKeyRef?

    init(id: ID,
         storageKey: String,
         fallback: KeyCombo,
         callback: @escaping () -> Void) {
        self.id = id
        self.storageKey = storageKey
        self.fallback = fallback
        self.callback = callback
    }

    /// The combination this manager is configured with.
    var storedCombo: KeyCombo {
        KeyCombo.load(key: storageKey, fallback: fallback)
    }

    func register(combo: KeyCombo? = nil) {
        let combo = combo ?? storedCombo
        unregister()

        Self.installSharedHandlerIfNeeded()
        Self.instances[id.rawValue] = self

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id.rawValue)
        let status = RegisterEventHotKey(combo.keyCode,
                                         combo.carbonModifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        if status != noErr {
            // Most often another app already owns the combination. Silence
            // here would leave a shortcut that simply never fires, with
            // nothing to diagnose it by.
            NSLog("Failed to register hotkey \(id) (\(combo.displayString)): OSStatus \(status)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        Self.instances.removeValue(forKey: id.rawValue)
    }

    /// Installs the process-wide Carbon handler on first use. Idempotent, and
    /// deliberately never removed: it is shared by every hotkey.
    private static func installSharedHandlerIfNeeded() {
        guard sharedHandler == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hkID)
            let pressedID = hkID.id
            DispatchQueue.main.async {
                HotkeyManager.instances[pressedID]?.callback()
            }
            return noErr
        }, 1, &eventType, nil, &sharedHandler)
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
    }
}
```

- [ ] **Step 7: Ajustar o `AppDelegate` à nova assinatura**

Em `MyPasteApp/AppDelegate.swift`, trocar a construção da hotkey
(linhas 47-49) por:

```swift
        hotkey = HotkeyManager(id: .overlay,
                               storageKey: KeyCombo.storageKey,
                               fallback: .default) { [weak self] in
            self?.overlay.toggle()
        }
```

E o observador (linhas 57-65) por:

```swift
        NotificationCenter.default.addObserver(
            forName: .hotkeyChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Older posts carried no key; treat them as the overlay one.
                let key = note.userInfo?["key"] as? String ?? KeyCombo.storageKey
                if key == KeyCombo.storageKey {
                    self.hotkey.register()
                }
            }
        }
```

- [ ] **Step 8: Rodar a suíte inteira e verificar o app manualmente**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Esperado: **PASS**, sem warnings novos.

Verificação manual — abrir o app pelo Xcode (⌘R) e confirmar:
1. `⌘⇧V` abre e fecha a overlay, **uma vez por pressionada** (se abrisse e
   fechasse instantaneamente, o callback estaria disparando em duplicidade).
2. Em Preferences, gravar outra combinação e confirmar que ela passa a valer
   sem reiniciar o app.
3. Voltar a combinação para `⌘⇧V`.

- [ ] **Step 9: Commit**

```bash
git add MyPasteApp/Services/KeyCombo.swift \
        MyPasteApp/Services/HotkeyManager.swift \
        MyPasteApp/AppDelegate.swift \
        MyPasteAppTests/KeyComboTests.swift
git commit -m "refactor(hotkey): support more than one global hotkey"
```

---

### Task 2: Quick Paste com `⌘1`–`⌘9`

**Files:**
- Create: `MyPasteApp/Services/QuickPaste.swift`
- Create: `MyPasteAppTests/QuickPasteTests.swift`
- Modify: `MyPasteApp/Views/OverlayView.swift:14-16,50-59,91-92`
- Modify: `MyPasteApp/Views/ClipboardCardView.swift:9-16,155-166`
- Modify: `MyPasteApp/Views/PreferencesView.swift:20,55-62,95`

**Interfaces:**
- Consumes: nada da Task 1
- Produces:
  - `QuickPaste.capacity: Int` (9)
  - `QuickPaste.index(for: Character) -> Int?` — posição zero-based
  - `QuickPaste.label(forIndex: Int) -> String?` — `"⌘1"`…`"⌘9"`
  - `ClipboardCardView.init(item:isSelected:quickPasteLabel:onDelete:)`
  - Chave `showQuickPasteNumbers` (Bool, padrão `true`)

- [ ] **Step 1: Escrever o teste que falha**

Criar `MyPasteAppTests/QuickPasteTests.swift`:

```swift
//
//  QuickPasteTests.swift
//  MyPasteAppTests
//

import Testing

@testable import MyPasteApp

@Suite("Quick paste")
struct QuickPasteTests {
    @Test("Digits 1 through 9 map onto zero-based positions", arguments: [
        (Character("1"), 0),
        (Character("2"), 1),
        (Character("5"), 4),
        (Character("9"), 8),
    ])
    func digitsMapToPositions(character: Character, expected: Int) {
        #expect(QuickPaste.index(for: character) == expected)
    }

    @Test("Zero has no card")
    func zeroIsRejected() {
        // ⌘0 must not paste the ninth card, nor crash on index -1.
        #expect(QuickPaste.index(for: "0") == nil)
    }

    @Test("Non-digits are rejected", arguments: [
        Character("a"), Character("-"), Character(" "), Character("½"),
    ])
    func nonDigitsAreRejected(character: Character) {
        #expect(QuickPaste.index(for: character) == nil)
    }

    @Test("The first nine positions get a label", arguments: [
        (0, "⌘1"), (1, "⌘2"), (8, "⌘9"),
    ])
    func labelsForReachablePositions(index: Int, expected: String) {
        #expect(QuickPaste.label(forIndex: index) == expected)
    }

    @Test("Positions past the ninth get no label", arguments: [9, 10, 500])
    func noLabelPastCapacity(index: Int) {
        #expect(QuickPaste.label(forIndex: index) == nil)
    }

    @Test("A negative position gets no label")
    func noLabelForNegative() {
        #expect(QuickPaste.label(forIndex: -1) == nil)
    }

    @Test("index and label agree on every reachable position")
    func indexAndLabelRoundTrip() {
        // Guards the off-by-one that would make ⌘3 paste the card labelled ⌘4.
        for position in 0..<QuickPaste.capacity {
            let label = QuickPaste.label(forIndex: position)
            #expect(label != nil)
            let digit = Character(String(position + 1))
            #expect(QuickPaste.index(for: digit) == position)
        }
    }
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/QuickPasteTests
```

Esperado: falha de compilação — `QuickPaste` não existe.

- [ ] **Step 3: Criar `QuickPaste`**

Criar `MyPasteApp/Services/QuickPaste.swift`:

```swift
//
//  QuickPaste.swift
//  MyPasteApp
//
//  Maps the ⌘1–⌘9 shortcuts onto visible card positions.
//

import Foundation

enum QuickPaste {
    /// How many cards a numbered shortcut can reach.
    static let capacity = 9

    /// Zero-based position for a pressed digit, or `nil` when the character
    /// isn't one this feature answers to.
    ///
    /// "0" is deliberately excluded: there is no zeroth card, and accepting it
    /// would index at -1.
    static func index(for character: Character) -> Int? {
        guard let digit = character.wholeNumberValue,
              (1...capacity).contains(digit)
        else { return nil }
        return digit - 1
    }

    /// Label for the chip drawn on the card at `index`, or `nil` when the
    /// position is out of reach.
    static func label(forIndex index: Int) -> String? {
        guard (0..<capacity).contains(index) else { return nil }
        return "⌘\(index + 1)"
    }
}
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/QuickPasteTests
```

Esperado: **PASS**.

- [ ] **Step 5: Exibir o chip no card**

Em `MyPasteApp/Views/ClipboardCardView.swift`, acrescentar a propriedade logo
depois de `isSelected` (linha 11), **antes** de `onDelete` — a ordem define o
init memberwise que a `OverlayView` vai chamar:

```swift
    let item: ClipboardItem
    let isSelected: Bool
    /// Shown when this card is within reach of a ⌘1–⌘9 shortcut.
    var quickPasteLabel: String? = nil
    var onDelete: () -> Void = {}
```

E substituir `private var footer` (linhas 155-166) por:

```swift
    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 0) {
            footerContent
            Spacer(minLength: 0)
            if let quickPasteLabel {
                Text(quickPasteLabel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                    .accessibilityLabel("Atalho \(quickPasteLabel)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.05))
    }
```

- [ ] **Step 6: Tratar `⌘1`–`⌘9` na overlay**

Em `MyPasteApp/Views/OverlayView.swift`, acrescentar a preferência junto dos
outros `@State` (depois da linha 16):

```swift
    @AppStorage("showQuickPasteNumbers") private var showQuickPasteNumbers = true
```

Substituir o `ForEach` (linhas 51-59) por:

```swift
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                            ClipboardCardView(
                                item: item,
                                isSelected: selectedID == item.id,
                                quickPasteLabel: showQuickPasteNumbers
                                    ? QuickPaste.label(forIndex: index)
                                    : nil,
                                onDelete: { delete(item) }
                            )
                            .id(item.id)
                            .onTapGesture { pick(item) }
                        }
```

Identificar por `\.element.id` e não pelo índice: com o índice, todo card se
reidentificaria a cada mudança de filtro, perdendo animação e estado de hover.

Acrescentar o handler logo depois do `onKeyPress(.rightArrow)` (linha 92):

```swift
        .onKeyPress(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9"]) { press in
            // The index follows `filtered`, not the full list: with a search
            // active, ⌘3 has to paste the third card actually on screen.
            guard press.modifiers.contains(.command),
                  let index = QuickPaste.index(for: press.key.character),
                  index < filtered.count
            else { return .ignored }
            pick(filtered[index])
            return .handled
        }
```

- [ ] **Step 7: Acrescentar a preferência**

Em `MyPasteApp/Views/PreferencesView.swift`, declarar junto dos outros
`@AppStorage` (depois da linha 20):

```swift
    @AppStorage("showQuickPasteNumbers") private var showQuickPasteNumbers: Bool = true
```

E dentro de `Section("Appearance")`, depois de `Toggle("Show link previews"…)`:

```swift
                Toggle("Show quick paste numbers", isOn: $showQuickPasteNumbers)
                Text("⌘1–⌘9 paste the first nine visible cards. The shortcuts keep working with the numbers hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
```

Trocar a altura da janela (linha 95) para acomodar os controles desta fase:

```swift
        .frame(width: 460, height: 640)
```

- [ ] **Step 8: Rodar a suíte e verificar manualmente**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Esperado: **PASS**.

Verificação manual (⌘R):
1. Abrir a overlay: os nove primeiros cards mostram `⌘1`…`⌘9` no rodapé; do
   décimo em diante, nenhum chip.
2. `⌘3` cola o terceiro card.
3. Digitar algo na busca e conferir que `⌘3` cola o terceiro **resultado**.
4. Digitar "3" na busca continua digitando um 3 — o atalho não rouba a tecla
   sem o ⌘.
5. Desligar "Show quick paste numbers": os chips somem e `⌘3` continua colando.

- [ ] **Step 9: Commit**

```bash
git add MyPasteApp/Services/QuickPaste.swift \
        MyPasteAppTests/QuickPasteTests.swift \
        MyPasteApp/Views/OverlayView.swift \
        MyPasteApp/Views/ClipboardCardView.swift \
        MyPasteApp/Views/PreferencesView.swift
git commit -m "feat(overlay): quick paste with ⌘1–⌘9"
```

---

### Task 3: Mecanismo de pausa

**Files:**
- Create: `MyPasteApp/Services/PauseController.swift`
- Create: `MyPasteAppTests/PauseTests.swift`
- Modify: `MyPasteApp/Services/ClipboardMonitor.swift:11-27,58-87,193-196`
- Modify: `MyPasteApp/AppDelegate.swift:12-20,34-37,95-135`
- Modify: `MyPasteAppTests/ClipboardPreferencesTests.swift:61-70`

**Interfaces:**
- Consumes: nada das tasks anteriores
- Produces:
  - `PauseState` (`.active`, `.pausedIndefinitely`, `.pausedUntil(Date)`) com `isPaused(at: Date) -> Bool`
  - `PauseDuration` com `seconds: TimeInterval`, `title: String`, `PauseDuration.offered: [PauseDuration]`
  - `PauseController` (`@MainActor`): `state`, `isPaused`, `pauseIndefinitely()`, `pause(for: PauseDuration)`, `resume()`, `toggle()`, `PauseController.stateChanged`
  - `ClipboardMonitor.pauseController: PauseController?` (weak)

- [ ] **Step 1: Escrever os testes que falham**

Criar `MyPasteAppTests/PauseTests.swift`:

```swift
//
//  PauseTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing

@testable import MyPasteApp

@Suite("Pause state")
struct PauseStateTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Active is never paused")
    func activeIsNotPaused() {
        #expect(PauseState.active.isPaused(at: now) == false)
    }

    @Test("An indefinite pause holds at any instant")
    func indefiniteAlwaysPaused() {
        #expect(PauseState.pausedIndefinitely.isPaused(at: now))
        #expect(PauseState.pausedIndefinitely.isPaused(at: now.addingTimeInterval(86_400)))
    }

    @Test("A timed pause holds before its deadline")
    func timedPauseBeforeDeadline() {
        let state = PauseState.pausedUntil(now.addingTimeInterval(900))
        #expect(state.isPaused(at: now))
        #expect(state.isPaused(at: now.addingTimeInterval(899)))
    }

    @Test("A timed pause is over at the deadline and after it")
    func timedPauseAtAndAfterDeadline() {
        // Decided against the clock rather than against the timer having
        // fired: a machine that sleeps through the pause must wake up
        // collecting again, and its Timer comes back late.
        let deadline = now.addingTimeInterval(900)
        let state = PauseState.pausedUntil(deadline)
        #expect(state.isPaused(at: deadline) == false)
        #expect(state.isPaused(at: deadline.addingTimeInterval(1)) == false)
        #expect(state.isPaused(at: deadline.addingTimeInterval(86_400)) == false)
    }
}

@Suite("Pause durations")
struct PauseDurationTests {
    @Test("The menu offers 15min, 30min, 1h, 3h and 8h, in that order")
    func offeredDurations() {
        #expect(PauseDuration.offered.map(\.seconds)
                == [15 * 60, 30 * 60, 60 * 60, 3 * 60 * 60, 8 * 60 * 60])
    }

    @Test("Titles read naturally", arguments: [
        (15.0 * 60, "15 minutes"),
        (30.0 * 60, "30 minutes"),
        (60.0 * 60, "1 hour"),
        (3.0 * 60 * 60, "3 hours"),
        (8.0 * 60 * 60, "8 hours"),
    ])
    func titles(seconds: TimeInterval, expected: String) {
        #expect(PauseDuration(seconds: seconds).title == expected)
    }
}
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/PauseStateTests \
  -only-testing:MyPasteAppTests/PauseDurationTests
```

Esperado: falha de compilação — `PauseState` e `PauseDuration` não existem.

- [ ] **Step 3: Criar `PauseController.swift`**

Criar `MyPasteApp/Services/PauseController.swift`:

```swift
//
//  PauseController.swift
//  MyPasteApp
//
//  Owns whether clipboard capture is paused, and for how long.
//

import AppKit
import Foundation

/// Whether capture is running, and until when it isn't.
///
/// Deliberately not persisted: an app that comes back silently paused makes
/// the user lose hours of history thinking it broke.
enum PauseState: Equatable {
    case active
    case pausedIndefinitely
    case pausedUntil(Date)

    func isPaused(at now: Date) -> Bool {
        switch self {
        case .active:
            return false
        case .pausedIndefinitely:
            return true
        case .pausedUntil(let deadline):
            return now < deadline
        }
    }
}

/// One of the durations offered in the status menu.
struct PauseDuration: Equatable {
    let seconds: TimeInterval

    var title: String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) minutes" }
        let hours = minutes / 60
        return hours == 1 ? "1 hour" : "\(hours) hours"
    }

    /// Someone pausing for privacy usually wants the whole meeting or the
    /// whole workday, not ten minutes.
    static let offered: [PauseDuration] = [
        PauseDuration(seconds: 15 * 60),
        PauseDuration(seconds: 30 * 60),
        PauseDuration(seconds: 60 * 60),
        PauseDuration(seconds: 3 * 60 * 60),
        PauseDuration(seconds: 8 * 60 * 60),
    ]
}

@MainActor
final class PauseController {
    /// Posted on every transition, so the status bar icon can follow along.
    static let stateChanged = Notification.Name("MyPasteApp.pauseStateChanged")

    private(set) var state: PauseState = .active
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAfterWake() }
        }
    }

    var isPaused: Bool { state.isPaused(at: .now) }

    func pauseIndefinitely() {
        transition(to: .pausedIndefinitely)
    }

    func pause(for duration: PauseDuration) {
        transition(to: .pausedUntil(Date.now.addingTimeInterval(duration.seconds)))
        let timer = Timer.scheduledTimer(withTimeInterval: duration.seconds,
                                         repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func resume() {
        transition(to: .active)
    }

    /// Used by the global shortcut, which has no way to pick a duration.
    func toggle() {
        isPaused ? resume() : pauseIndefinitely()
    }

    private func transition(to newState: PauseState) {
        timer?.invalidate()
        timer = nil
        state = newState
        NotificationCenter.default.post(name: Self.stateChanged, object: self)
    }

    /// A Timer doesn't fire while the machine sleeps and comes back late.
    /// Capture already resumes on its own — `isPaused` is decided against the
    /// clock — but without this the icon would keep claiming the app is
    /// paused while it is in fact collecting.
    private func refreshAfterWake() {
        guard case .pausedUntil = state, !isPaused else { return }
        resume()
    }

    deinit {
        timer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }
}
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/PauseStateTests \
  -only-testing:MyPasteAppTests/PauseDurationTests
```

Esperado: **PASS**.

- [ ] **Step 5: Ligar o monitor ao controller**

Em `MyPasteApp/Services/ClipboardMonitor.swift`, acrescentar a propriedade
depois de `var ignoreNextChange = false` (linha 21):

```swift
    /// Set by the AppDelegate right after construction. Weak because the
    /// delegate owns the controller.
    weak var pauseController: PauseController?
```

Trocar a checagem de pausa em `poll()` (linhas 68-70) por:

```swift
        // Checked *after* lastChangeCount was updated above, so resuming
        // doesn't capture whatever was copied during the pause.
        if pauseController?.isPaused == true {
            return
        }
```

Remover o leitor estático `isMonitoringPaused` (linhas 193-196) inteiro,
inclusive seu comentário de doc — o estado deixou de morar em `UserDefaults`.

- [ ] **Step 6: Remover os testes que cobriam a chave antiga**

Em `MyPasteAppTests/ClipboardPreferencesTests.swift`, apagar os dois testes
`monitoringNotPausedByDefault` e `monitoringPausedStored` (linhas 61-70).
`PauseStateTests` cobre o mesmo comportamento com mais casos.

- [ ] **Step 7: Construir o controller no `AppDelegate`**

Em `MyPasteApp/AppDelegate.swift`, declarar a propriedade junto das outras
(depois de `var monitor: ClipboardMonitor!`, linha 13):

```swift
    var pauseController: PauseController!
```

Em `applicationDidFinishLaunching`, substituir a linha
`monitor = ClipboardMonitor(modelContext: context)` (linha 35) por:

```swift
        pauseController = PauseController()
        monitor = ClipboardMonitor(modelContext: context)
        monitor.pauseController = pauseController

        // The pause used to live in UserDefaults. It doesn't survive a
        // restart any more, so the leftover key is cleared instead of being
        // read by nobody.
        UserDefaults.standard.removeObject(forKey: "monitoringPaused")
```

Substituir o item de menu de pausa em `showStatusMenu` (linhas 103-108) por:

```swift
        let pause = NSMenuItem(title: pauseController.isPaused
                                ? "Resume clipboard monitoring"
                                : "Pause clipboard monitoring",
                               action: #selector(togglePauseAction),
                               keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
```

E substituir `togglePauseAction` (linhas 131-135) por:

```swift
    @objc private func togglePauseAction() {
        pauseController.toggle()
    }
```

- [ ] **Step 8: Rodar a suíte e verificar manualmente**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Esperado: **PASS**.

Verificação manual (⌘R):
1. Menu da status bar → "Pause clipboard monitoring".
2. Copiar dois textos quaisquer.
3. Menu → "Resume clipboard monitoring".
4. Abrir a overlay: **nenhum** dos dois textos aparece — nem o último, que é o
   que apareceria se o `changeCount` não tivesse sido acompanhado durante a
   pausa.
5. Reiniciar o app e confirmar que ele volta coletando.

- [ ] **Step 9: Commit**

```bash
git add MyPasteApp/Services/PauseController.swift \
        MyPasteAppTests/PauseTests.swift \
        MyPasteApp/Services/ClipboardMonitor.swift \
        MyPasteApp/AppDelegate.swift \
        MyPasteAppTests/ClipboardPreferencesTests.swift
git commit -m "feat(monitor): pause and resume clipboard capture"
```

---

### Task 4: Pausa temporizada, ícone e hotkey

**Files:**
- Modify: `MyPasteApp/AppDelegate.swift:12-20,47-55,74-135`
- Modify: `MyPasteApp/Views/PreferencesView.swift:22,38-54`

**Interfaces:**
- Consumes: `HotkeyManager.ID.pause`, `KeyCombo.pauseStorageKey`, `KeyCombo.pauseDefault`, `KeyCombo.conflicts(_:with:)`, `KeyCombo.storedPause` (Task 1); `PauseController`, `PauseDuration.offered` (Task 3)
- Produces: nada consumido por tasks posteriores

- [ ] **Step 1: Registrar a segunda hotkey**

Em `MyPasteApp/AppDelegate.swift`, declarar junto das outras propriedades
(depois de `var hotkey: HotkeyManager!`):

```swift
    var pauseHotkey: HotkeyManager!
```

Depois da construção da hotkey da overlay (Task 1, Step 7), acrescentar:

```swift
        pauseHotkey = HotkeyManager(id: .pause,
                                    storageKey: KeyCombo.pauseStorageKey,
                                    fallback: .pauseDefault) { [weak self] in
            self?.pauseController.toggle()
        }
```

Junto de `hotkey.register()`, acrescentar:

```swift
        pauseHotkey.register()
```

Estender o observador de `.hotkeyChanged` para tratar as duas chaves:

```swift
                let key = note.userInfo?["key"] as? String ?? KeyCombo.storageKey
                switch key {
                case KeyCombo.storageKey: self.hotkey.register()
                case KeyCombo.pauseStorageKey: self.pauseHotkey.register()
                default: break
                }
```

E em `applicationWillTerminate`, acrescentar:

```swift
        pauseHotkey?.unregister()
```

- [ ] **Step 2: Fazer o ícone refletir o estado**

Em `MyPasteApp/AppDelegate.swift`, substituir `setupStatusItem` (linhas 74-82)
por:

```swift
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        refreshStatusIcon()

        NotificationCenter.default.addObserver(
            forName: PauseController.stateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshStatusIcon() }
        }
    }

    /// The icon has to say, unmistakably, that nothing is being collected.
    /// Dimming the same glyph would be too easy to miss — and missing it here
    /// costs hours of lost history.
    private func refreshStatusIcon() {
        guard let button = statusItem?.button else { return }
        let paused = pauseController.isPaused
        button.image = NSImage(
            systemSymbolName: paused ? "pause.circle.fill" : "doc.on.clipboard",
            accessibilityDescription: paused ? "MyPasteApp — paused" : "MyPasteApp"
        )
        button.toolTip = paused ? pauseStatusTitle : "MyPasteApp"
    }

    private var pauseStatusTitle: String {
        switch pauseController.state {
        case .active:
            return "MyPasteApp"
        case .pausedIndefinitely:
            return "Paused"
        case .pausedUntil(let deadline):
            return "Paused until \(deadline.formatted(.dateTime.hour().minute()))"
        }
    }
```

`setupStatusItem` é chamado depois de `pauseController` existir (Task 3,
Step 7 o cria antes do `setupStatusItem()` da linha 51); manter essa ordem.

- [ ] **Step 3: Construir o submenu de durações**

Em `MyPasteApp/AppDelegate.swift`, substituir o bloco do item de pausa dentro
de `showStatusMenu` (o que a Task 3 deixou) por:

```swift
        for item in pauseMenuItems() {
            menu.addItem(item)
        }
```

E acrescentar, depois de `showStatusMenu`:

```swift
    /// Built fresh on every menu opening — `showStatusMenu` rebuilds the whole
    /// NSMenu each time — so there is no state to keep in sync here.
    private func pauseMenuItems() -> [NSMenuItem] {
        guard !pauseController.isPaused else {
            // No target and no action, so NSMenu's automatic enabling leaves
            // this one greyed out as the status line it is.
            let status = NSMenuItem(title: pauseStatusTitle,
                                    action: nil,
                                    keyEquivalent: "")
            let resume = NSMenuItem(title: "Resume clipboard monitoring",
                                    action: #selector(togglePauseAction),
                                    keyEquivalent: "")
            resume.target = self
            return [status, resume]
        }

        let pause = NSMenuItem(title: "Pause clipboard monitoring",
                               action: nil,
                               keyEquivalent: "")
        let submenu = NSMenu()

        let indefinite = NSMenuItem(title: "Pause",
                                    action: #selector(togglePauseAction),
                                    keyEquivalent: "")
        indefinite.target = self
        submenu.addItem(indefinite)
        submenu.addItem(.separator())

        for duration in PauseDuration.offered {
            let item = NSMenuItem(title: duration.title,
                                  action: #selector(pauseForAction(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = duration.seconds
            submenu.addItem(item)
        }

        pause.submenu = submenu
        return [pause]
    }

    @objc private func pauseForAction(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        pauseController.pause(for: PauseDuration(seconds: seconds))
    }
```

- [ ] **Step 4: Acrescentar a hotkey às Preferências**

Em `MyPasteApp/Views/PreferencesView.swift`, declarar junto dos outros
`@State` (depois da linha 22):

```swift
    @State private var pauseHotkey: KeyCombo = KeyCombo.storedPause
    @State private var hotkeyConflict = false
    /// Guards the reassignment inside `onChange` from re-entering it.
    @State private var isRevertingHotkey = false
```

Substituir a `Section("Global shortcut")` inteira (linhas 38-54) por:

```swift
            Section("Global shortcuts") {
                HStack {
                    Text("Show/hide overlay")
                    Spacer()
                    HotkeyRecorderView(combo: $hotkey)
                        .frame(width: 160, height: 24)
                    Button("Reset") {
                        hotkey = .default
                    }
                }
                HStack {
                    Text("Pause/resume capture")
                    Spacer()
                    HotkeyRecorderView(combo: $pauseHotkey)
                        .frame(width: 160, height: 24)
                    Button("Reset") {
                        pauseHotkey = .pauseDefault
                    }
                }
                if hotkeyConflict {
                    Text("Both shortcuts can't use the same combination.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Text("Click the field and press a new shortcut. Esc cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onChange(of: hotkey) { oldValue, newValue in
                applyHotkeyChange(new: newValue,
                                  old: oldValue,
                                  other: pauseHotkey,
                                  key: KeyCombo.storageKey) { hotkey = $0 }
            }
            .onChange(of: pauseHotkey) { oldValue, newValue in
                applyHotkeyChange(new: newValue,
                                  old: oldValue,
                                  other: hotkey,
                                  key: KeyCombo.pauseStorageKey) { pauseHotkey = $0 }
            }
```

E acrescentar o método, junto de `clearHistory` e `toggleLaunchAtLogin`:

```swift
    /// Saves a re-recorded shortcut, or refuses it when it would collide with
    /// the other one — `RegisterEventHotKey` would otherwise leave one of them
    /// silently dead.
    private func applyHotkeyChange(new: KeyCombo,
                                   old: KeyCombo,
                                   other: KeyCombo,
                                   key: String,
                                   revert: (KeyCombo) -> Void) {
        guard !isRevertingHotkey else {
            isRevertingHotkey = false
            return
        }
        if KeyCombo.conflicts(new, with: other) {
            NSSound.beep()
            hotkeyConflict = true
            isRevertingHotkey = true
            revert(old)
            return
        }
        hotkeyConflict = false
        KeyCombo.save(new, key: key)
    }
```

`NSSound` vem do AppKit. Acrescentar ao topo do arquivo, junto dos outros
imports:

```swift
import AppKit
```

- [ ] **Step 5: Rodar a suíte**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Esperado: **PASS**.

- [ ] **Step 6: Verificar manualmente**

Com o app rodando (⌘R):
1. Menu → "Pause clipboard monitoring" mostra o submenu com Pause, 15 minutes,
   30 minutes, 1 hour, 3 hours, 8 hours.
2. Escolher "15 minutes": o ícone da status bar vira `pause.circle.fill`, e
   passar o mouse sobre ele mostra "Paused until HH:MM".
3. Reabrir o menu: aparece a linha cinza "Paused until HH:MM" e o item
   "Resume clipboard monitoring".
4. `⌘⇧P` retoma — o ícone volta a `doc.on.clipboard`.
5. `⌘⇧P` de novo pausa indefinidamente; o tooltip mostra "Paused".
6. Em Preferences → Global shortcuts, tentar gravar `⌘⇧V` no campo da pausa:
   soa o beep, o aviso vermelho aparece e o campo volta ao valor anterior.
7. Gravar `⌥⌘P` na pausa e confirmar que a nova combinação funciona sem
   reiniciar o app; depois voltar para `⌘⇧P` pelo botão Reset.

- [ ] **Step 7: Commit**

```bash
git add MyPasteApp/AppDelegate.swift MyPasteApp/Views/PreferencesView.swift
git commit -m "feat(menu): timed pause with status bar feedback and its own hotkey"
```

---

### Task 5: Ocultar as janelas em compartilhamento de tela

**Files:**
- Create: `MyPasteApp/Services/WindowPrivacy.swift`
- Create: `MyPasteAppTests/WindowPrivacyTests.swift`
- Modify: `MyPasteApp/Window/OverlayWindowController.swift:42-100`
- Modify: `MyPasteApp/AppDelegate.swift:21-66,141-155`
- Modify: `MyPasteApp/Views/PreferencesView.swift:20,72-86`

**Interfaces:**
- Consumes: nada das tasks anteriores
- Produces:
  - `WindowPrivacy.showInScreenSharing(from: UserDefaults) -> Bool`
  - `WindowPrivacy.sharingType(from: UserDefaults) -> NSWindow.SharingType`
  - `OverlayWindowController.applySharingPolicy()`
  - Chave `showInScreenSharing` (Bool, padrão `false`)

- [ ] **Step 1: Escrever o teste que falha**

Criar `MyPasteAppTests/WindowPrivacyTests.swift`:

```swift
//
//  WindowPrivacyTests.swift
//  MyPasteAppTests
//

import AppKit
import Testing

@testable import MyPasteApp

@Suite("Window privacy")
struct WindowPrivacyTests {
    private let defaults = TestDefaults("window-privacy")

    @Test("Windows are hidden from screen sharing by default")
    func hiddenByDefault() {
        // Protection that doesn't depend on the user finding the preference.
        #expect(WindowPrivacy.showInScreenSharing(from: defaults.store) == false)
        #expect(WindowPrivacy.sharingType(from: defaults.store) == .none)
    }

    @Test("Turning the preference on restores the system default")
    func visibleWhenEnabled() {
        defaults.store.set(true, forKey: "showInScreenSharing")
        #expect(WindowPrivacy.showInScreenSharing(from: defaults.store))
        #expect(WindowPrivacy.sharingType(from: defaults.store) == .readWrite)
    }

    @Test("Turning it explicitly off hides the windows")
    func hiddenWhenDisabled() {
        defaults.store.set(false, forKey: "showInScreenSharing")
        #expect(WindowPrivacy.sharingType(from: defaults.store) == .none)
    }
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/WindowPrivacyTests
```

Esperado: falha de compilação — `WindowPrivacy` não existe.

- [ ] **Step 3: Criar `WindowPrivacy`**

Criar `MyPasteApp/Services/WindowPrivacy.swift`:

```swift
//
//  WindowPrivacy.swift
//  MyPasteApp
//
//  Whether this app's windows may be captured by screen sharing.
//

import AppKit
import Foundation

enum WindowPrivacy {
    /// Off by default: the history shouldn't show up in a meeting just
    /// because the user never opened Preferences.
    static func showInScreenSharing(from defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: "showInScreenSharing") as? Bool ?? false
    }

    /// `.readWrite` is the system default for windows, so turning the
    /// preference on gives back exactly today's behaviour — nothing beyond
    /// what was asked for changes.
    static func sharingType(from defaults: UserDefaults = .standard) -> NSWindow.SharingType {
        showInScreenSharing(from: defaults) ? .readWrite : .none
    }
}
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/WindowPrivacyTests
```

Esperado: **PASS**.

- [ ] **Step 5: Aplicar à overlay**

Em `MyPasteApp/Window/OverlayWindowController.swift`, dentro de `prepare()`,
logo depois de `panel.alphaValue = 0` (linha 61):

```swift
        panel.sharingType = WindowPrivacy.sharingType()
```

E acrescentar o método público, depois de `prepare()`:

```swift
    /// Re-reads the screen-sharing preference and applies it. The panel is
    /// private, so the AppDelegate can't do this itself.
    func applySharingPolicy() {
        window?.sharingType = WindowPrivacy.sharingType()
    }
```

Em `show()`, logo depois de `prepare()` (linha 108):

```swift
        applySharingPolicy()
```

- [ ] **Step 6: Aplicar à janela de Preferências e reagir a mudanças**

Em `MyPasteApp/AppDelegate.swift`, dentro de `openPreferences`, antes de
`NSApp.activate(...)`:

```swift
        prefsWindow?.sharingType = WindowPrivacy.sharingType()
```

Aplicar na janela existente a cada abertura, e não só na criação, porque
`prefsWindow` é reaproveitada entre aberturas.

Acrescentar o método, junto dos outros privados:

```swift
    private func applySharingPolicy() {
        overlay?.applySharingPolicy()
        prefsWindow?.sharingType = WindowPrivacy.sharingType()
    }
```

E, no fim de `applicationDidFinishLaunching`, o observador:

```swift
        // The user flips this preference from inside the Preferences window
        // itself; without this the change would only take effect the next time
        // the window opened, which reads as "the toggle did nothing".
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applySharingPolicy() }
        }
```

- [ ] **Step 7: Acrescentar o toggle às Preferências**

Em `MyPasteApp/Views/PreferencesView.swift`, declarar junto dos outros
`@AppStorage`:

```swift
    @AppStorage("showInScreenSharing") private var showInScreenSharing: Bool = false
```

E no topo de `Section("Privacy")`, antes do bloco da lista de apps:

```swift
                Toggle("Show during screen sharing", isOn: $showInScreenSharing)
                Text("When off, the overlay and this window don't appear in screen sharing or recordings — including screenshots you take yourself.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
```

- [ ] **Step 8: Rodar a suíte e verificar manualmente**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Esperado: **PASS**.

Verificação manual (⌘R):
1. Com a preferência desligada (o padrão), abrir a overlay e tentar tirar um
   print dela (`⇧⌘4` e barra de espaço, ou `⇧⌘5`): a janela **não** aparece na
   captura. É o mesmo mecanismo que a esconde de um compartilhamento de tela.
2. Ligar "Show during screen sharing" e repetir **sem reiniciar o app**: a
   overlay volta a aparecer na captura.
3. Se houver com quem testar, confirmar num compartilhamento real (Meet, Zoom
   ou o Compartilhamento de Tela do macOS) que ela aparece localmente e não
   para o outro lado.
4. Desligar a preferência de novo.

- [ ] **Step 9: Commit**

```bash
git add MyPasteApp/Services/WindowPrivacy.swift \
        MyPasteAppTests/WindowPrivacyTests.swift \
        MyPasteApp/Window/OverlayWindowController.swift \
        MyPasteApp/AppDelegate.swift \
        MyPasteApp/Views/PreferencesView.swift
git commit -m "feat(privacy): hide windows from screen sharing"
```

---

### Task 6: Ignorar conteúdo confidencial e transitório

**Files:**
- Create: `MyPasteApp/Services/PasteboardPrivacy.swift`
- Create: `MyPasteAppTests/PasteboardPrivacyTests.swift`
- Modify: `MyPasteApp/Services/ClipboardMonitor.swift:58-87`
- Modify: `MyPasteApp/Views/PreferencesView.swift:20,72-86`

**Interfaces:**
- Consumes: nada das tasks anteriores
- Produces:
  - `PasteboardPrivacy.concealed/.transient/.autoGenerated: NSPasteboard.PasteboardType`
  - `PasteboardPrivacy.Settings` com `current(from: UserDefaults)`
  - `PasteboardPrivacy.shouldIgnore(types:settings:) -> Bool`
  - Chaves `ignoreConcealedContent` (`true`), `ignoreTransientContent` (`true`), `ignoreAutoGeneratedContent` (`false`)

- [ ] **Step 1: Escrever o teste que falha**

Criar `MyPasteAppTests/PasteboardPrivacyTests.swift`:

```swift
//
//  PasteboardPrivacyTests.swift
//  MyPasteAppTests
//

import AppKit
import Testing

@testable import MyPasteApp

@Suite("Pasteboard privacy")
struct PasteboardPrivacyTests {
    private let defaults = TestDefaults("pasteboard-privacy")

    private let plainText = NSPasteboard.PasteboardType("public.utf8-plain-text")
    private let png = NSPasteboard.PasteboardType("public.png")

    private var allOn: PasteboardPrivacy.Settings {
        PasteboardPrivacy.Settings(ignoreConcealed: true,
                                   ignoreTransient: true,
                                   ignoreAutoGenerated: true)
    }

    private var allOff: PasteboardPrivacy.Settings {
        PasteboardPrivacy.Settings(ignoreConcealed: false,
                                   ignoreTransient: false,
                                   ignoreAutoGenerated: false)
    }

    // MARK: - Defaults

    @Test("Concealed and transient are ignored out of the box, auto-generated isn't")
    func defaultSettings() {
        // A missed copy costs far less than a password in the history — but
        // "machine-generated" is too broad to discard uninvited.
        let settings = PasteboardPrivacy.Settings.current(from: defaults.store)
        #expect(settings.ignoreConcealed)
        #expect(settings.ignoreTransient)
        #expect(settings.ignoreAutoGenerated == false)
    }

    @Test("Stored flags are honoured")
    func storedSettings() {
        defaults.store.set(false, forKey: "ignoreConcealedContent")
        defaults.store.set(false, forKey: "ignoreTransientContent")
        defaults.store.set(true, forKey: "ignoreAutoGeneratedContent")

        let settings = PasteboardPrivacy.Settings.current(from: defaults.store)
        #expect(settings.ignoreConcealed == false)
        #expect(settings.ignoreTransient == false)
        #expect(settings.ignoreAutoGenerated)
    }

    // MARK: - Decision

    @Test("Ordinary content is never ignored")
    func ordinaryContentIsKept() {
        #expect(PasteboardPrivacy.shouldIgnore(types: [plainText], settings: allOn) == false)
        #expect(PasteboardPrivacy.shouldIgnore(types: [png], settings: allOn) == false)
        #expect(PasteboardPrivacy.shouldIgnore(types: [], settings: allOn) == false)
    }

    @Test("A marked type is ignored when its toggle is on")
    func markedTypesAreIgnored() {
        #expect(PasteboardPrivacy.shouldIgnore(
            types: [plainText, PasteboardPrivacy.concealed], settings: allOn))
        #expect(PasteboardPrivacy.shouldIgnore(
            types: [plainText, PasteboardPrivacy.transient], settings: allOn))
        #expect(PasteboardPrivacy.shouldIgnore(
            types: [plainText, PasteboardPrivacy.autoGenerated], settings: allOn))
    }

    @Test("A marked type is kept when its toggle is off")
    func markedTypesAreKeptWhenDisabled() {
        #expect(PasteboardPrivacy.shouldIgnore(
            types: [plainText, PasteboardPrivacy.concealed], settings: allOff) == false)
        #expect(PasteboardPrivacy.shouldIgnore(
            types: [plainText, PasteboardPrivacy.transient], settings: allOff) == false)
        #expect(PasteboardPrivacy.shouldIgnore(
            types: [plainText, PasteboardPrivacy.autoGenerated], settings: allOff) == false)
    }

    @Test("Each toggle only governs its own type")
    func togglesAreIndependent() {
        let concealedOnly = PasteboardPrivacy.Settings(ignoreConcealed: true,
                                                       ignoreTransient: false,
                                                       ignoreAutoGenerated: false)
        #expect(PasteboardPrivacy.shouldIgnore(
            types: [PasteboardPrivacy.concealed], settings: concealedOnly))
        #expect(PasteboardPrivacy.shouldIgnore(
            types: [PasteboardPrivacy.transient], settings: concealedOnly) == false)
        #expect(PasteboardPrivacy.shouldIgnore(
            types: [PasteboardPrivacy.autoGenerated], settings: concealedOnly) == false)
    }

    @Test("With several markers present, any enabled one is enough")
    func anyEnabledMarkerWins() {
        let transientOnly = PasteboardPrivacy.Settings(ignoreConcealed: false,
                                                       ignoreTransient: true,
                                                       ignoreAutoGenerated: false)
        #expect(PasteboardPrivacy.shouldIgnore(
            types: [PasteboardPrivacy.concealed, PasteboardPrivacy.transient],
            settings: transientOnly))
    }

    @Test("The marker identifiers follow the nspasteboard.org convention")
    func typeIdentifiers() {
        // These strings are a contract with other apps; a typo would silently
        // disable the whole feature.
        #expect(PasteboardPrivacy.concealed.rawValue == "org.nspasteboard.ConcealedType")
        #expect(PasteboardPrivacy.transient.rawValue == "org.nspasteboard.TransientType")
        #expect(PasteboardPrivacy.autoGenerated.rawValue == "org.nspasteboard.AutoGeneratedType")
    }
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/PasteboardPrivacyTests
```

Esperado: falha de compilação — `PasteboardPrivacy` não existe.

- [ ] **Step 3: Criar `PasteboardPrivacy`**

Criar `MyPasteApp/Services/PasteboardPrivacy.swift`:

```swift
//
//  PasteboardPrivacy.swift
//  MyPasteApp
//
//  Honours the nspasteboard.org convention: apps that copy sensitive or
//  throwaway content mark it with an auxiliary type, asking clipboard
//  managers not to record it.
//
//  It only works when the source app cooperates, so this complements the
//  ignored-apps list rather than replacing it.
//

import AppKit
import Foundation

enum PasteboardPrivacy {
    /// Written by password managers when copying a secret.
    static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    /// Written by automations using the pasteboard as a temporary channel.
    static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    /// Machine-produced content.
    static let autoGenerated = NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")

    struct Settings: Equatable {
        var ignoreConcealed: Bool
        var ignoreTransient: Bool
        var ignoreAutoGenerated: Bool

        /// Concealed and transient default to on — the cost of a missed copy
        /// is much lower than that of a password in the history. Auto-generated
        /// defaults to off: it is broad enough that some apps mark content the
        /// user did mean to copy.
        static func current(from defaults: UserDefaults = .standard) -> Settings {
            Settings(
                ignoreConcealed: defaults.object(forKey: "ignoreConcealedContent") as? Bool ?? true,
                ignoreTransient: defaults.object(forKey: "ignoreTransientContent") as? Bool ?? true,
                ignoreAutoGenerated: defaults.object(forKey: "ignoreAutoGeneratedContent") as? Bool ?? false
            )
        }
    }

    /// Takes the types present on the pasteboard rather than the pasteboard
    /// itself, so the rule can be tested without touching the system one.
    static func shouldIgnore(types: [NSPasteboard.PasteboardType],
                             settings: Settings) -> Bool {
        if settings.ignoreConcealed, types.contains(concealed) { return true }
        if settings.ignoreTransient, types.contains(transient) { return true }
        if settings.ignoreAutoGenerated, types.contains(autoGenerated) { return true }
        return false
    }
}
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:MyPasteAppTests/PasteboardPrivacyTests
```

Esperado: **PASS**.

- [ ] **Step 5: Checar no `poll()`, antes de ler o conteúdo**

Em `MyPasteApp/Services/ClipboardMonitor.swift`, dentro de `poll()`, logo
depois do bloco de pausa que a Task 3 deixou e **antes** de
`guard let item = readCurrentItem()`:

```swift
        // Checked before reading anything: discarding the string afterwards
        // would have let the password travel through the app for no reason.
        if PasteboardPrivacy.shouldIgnore(types: pasteboard.types ?? [],
                                          settings: .current(from: defaults)) {
            return
        }
```

- [ ] **Step 6: Acrescentar os três toggles às Preferências**

Em `MyPasteApp/Views/PreferencesView.swift`, declarar junto dos outros
`@AppStorage`:

```swift
    @AppStorage("ignoreConcealedContent") private var ignoreConcealedContent: Bool = true
    @AppStorage("ignoreTransientContent") private var ignoreTransientContent: Bool = true
    @AppStorage("ignoreAutoGeneratedContent") private var ignoreAutoGeneratedContent: Bool = false
```

E dentro de `Section("Privacy")`, depois do toggle de compartilhamento de tela
da Task 5 e antes do bloco da lista de apps:

```swift
                Divider()
                Toggle("Ignore confidential content", isOn: $ignoreConcealedContent)
                Toggle("Ignore transient content", isOn: $ignoreTransientContent)
                Toggle("Ignore auto-generated content", isOn: $ignoreAutoGeneratedContent)
                Text("Apps can mark what they copy as a password, as throwaway data or as machine-generated. This only works when the source app marks it, so it complements the list below instead of replacing it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
```

- [ ] **Step 7: Rodar a suíte e verificar manualmente**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Esperado: **PASS**.

Verificação manual (⌘R), com `ignoredAppsRaw` **vazio**:
1. Abrir o app Senhas (ou o Acesso às Chaves), copiar uma senha.
2. Abrir a overlay: a senha **não** está no histórico.
3. Copiar um texto comum do mesmo app (o nome de um item, por exemplo) e
   confirmar que **esse** aparece — a regra é por marcador, não por app.
4. Desligar "Ignore confidential content", copiar a senha de novo e confirmar
   que agora ela aparece. Religar o toggle e apagar o item do histórico.

- [ ] **Step 8: Commit**

```bash
git add MyPasteApp/Services/PasteboardPrivacy.swift \
        MyPasteAppTests/PasteboardPrivacyTests.swift \
        MyPasteApp/Services/ClipboardMonitor.swift \
        MyPasteApp/Views/PreferencesView.swift
git commit -m "feat(privacy): skip concealed and transient pasteboard content"
```

---

### Task 7: Fechamento da fase

**Files:** nenhum de código.

- [ ] **Step 1: Verificar o item 5 do roadmap**

Com o app rodando, control+clique no ícone da status bar. Esperado: abre o
mesmo menu do clique direito.

Se **não** abrir, o item volta a ter escopo de código: acrescentar
`.leftMouseDown` ao `sendAction(on:)` de `setupStatusItem`, porque o sistema
entrega control+clique como `leftMouseDown` sem o `leftMouseUp` correspondente.
Nesse caso, commitar em separado com
`fix(menu): open the status menu on control-click`.

- [ ] **Step 2: Verificar as preferências pré-existentes**

Confirmar, uma a uma, que continuam valendo com os dados que já estavam
gravados: hotkey da overlay, densidade dos cards, auto-paste e seu atraso,
comprimento do preview, som ao copiar, previews de link, lista de apps
ignorados, launch at login, max items e retenção.

- [ ] **Step 3: Rodar a suíte completa uma última vez**

```bash
xcodebuild test -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Esperado: **PASS**.

- [ ] **Step 4: Abrir o PR**

```bash
git push -u origin feature/fase-1-ganhos-rapidos
gh pr create --base develop \
  --title "feat: fase 1 do roadmap — ganhos rápidos" \
  --body "$(cat <<'EOF'
Implementa os itens 1 a 5 da Fase 1 do `ROADMAP.md`.

## O que entra

- **Item 1 — Quick Paste:** `⌘1`–`⌘9` colam os nove primeiros cards visíveis,
  com o número exibido no rodapé do card. A numeração segue a lista filtrada,
  então funciona com busca ativa. Preferência para esconder os números sem
  desligar os atalhos.
- **Item 2 — Pausar a coleta:** submenu na status bar com pausa indefinida ou
  por 15min, 30min, 1h, 3h e 8h; ícone que muda de forma inequívoca enquanto
  pausado; hotkey própria (`⌘⇧P` por padrão). A pausa **não** sobrevive a um
  restart, de propósito.
- **Item 3 — Compartilhamento de tela:** overlay e janela de Preferências
  ficam ocultas em compartilhamentos e gravações por padrão, com toggle para
  reverter.
- **Item 4 — Conteúdo confidencial:** respeita os marcadores da convenção
  nspasteboard.org (Concealed e Transient ligados, AutoGenerated desligado),
  checados antes de o conteúdo ser lido.
- **Item 5 — Control+clique:** já estava implementado; verificado.

## Pré-requisito

`HotkeyManager` era single-tenant — assinatura Carbon fixa e um
`InstallEventHandler` novo por registro. Registrar a segunda hotkey dispararia
cada callback duas vezes. Refatorado no primeiro commit, sem mudança de
comportamento.

## Testes

Novos suites de lógica pura: `QuickPasteTests`, `PauseStateTests`,
`PauseDurationTests`, `WindowPrivacyTests`, `PasteboardPrivacyTests`, mais
acréscimos a `KeyComboTests`. Hotkeys Carbon, `sharingType` e teclas na overlay
foram verificados manualmente.

Spec: `docs/superpowers/specs/2026-07-30-fase-1-ganhos-rapidos-design.md`
Plano: `docs/superpowers/plans/2026-07-30-fase-1-ganhos-rapidos.md`
EOF
)"
```

- [ ] **Step 5: Atualizar o Kanban**

No Obsidian (`MyPasteApp/Board.md`), mover os cinco cards da Fase 1 para
🔍 Revisão. Ao merge, movê-los para ⤴ Merge e depois ✅ Concluído.

---

## Notas de execução

**Kanban:** ao **começar** a Task 1, mover os cinco cards de 📝 Spec para
🛠 Implementando. Ao terminar a Task 6, movê-los para 🔍 Revisão.

**Autorização:** os commits deste plano já estão autorizados (ver Global
Constraints). `git push` e a abertura do PR na Task 7 **não** estão — esses
exigem OK explícito na hora.

**Ordem:** a Task 4 depende da 1 e da 3. As tasks 2, 5 e 6 são independentes
entre si e do resto — se algo travar numa delas, as outras seguem.
