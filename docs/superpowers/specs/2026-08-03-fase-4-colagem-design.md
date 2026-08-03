# Fase 4 — Colagem

Design aprovado em 2026-08-03. Cobre o **item 14** do `ROADMAP.md` (colagem
múltipla em sequência). O item 15 (Paste Stack) **não** entra nesta fase — ver
"Escopo e o que fica de fora".

Ambiente de referência: Xcode 26.6, SDK macOS 26.5, deployment target 26.2,
Swift 5. O projeto usa `PBXFileSystemSynchronizedRootGroup`, então arquivos
novos entram no alvo pelo simples fato de existirem no diretório — não há
`project.pbxproj` para editar.

Branch: `feature/fase-4-colagem`, criada a partir de `develop`.

## O que a fase entrega

| Item | Entrega |
|---|---|
| 14 | Marcar vários itens de texto/URL na overlay, em ordem, e colar os N de uma vez num único destino, concatenados por um separador configurável |
| — | `MarkedSelection`: a coleção ordenada, isolada como primitiva reutilizável. É o que o item 15 consumiria depois, como segundo modo de consumo, sem UI nem estado próprios |

## Escopo e o que fica de fora

O `ROADMAP.md` põe os itens 14 e 15 juntos nesta fase. **Só o 14 entra.** O 15
depende de um modo persistente — estado que sobrevive a trocar de janela,
indicação na status bar, regras de esvaziamento e de captura durante a pilha —
e a decisão de construí-lo fica mais barata depois de o 14 estar em uso real. A
primitiva desta fase é desenhada para recebê-lo sem reescrita.

Fora de escopo, com o lugar marcado:

- **Item 15 (Paste Stack)**, pelo acima. Permanece no backlog do board
- **Marcar imagens e arquivos.** Vários arquivos no pasteboard é operação nativa
  (`writeObjects` com N `NSURL`) e sairia quase de graça, mas exigiria uma
  segunda regra de junção e a proibição explícita de misturar tipos. Fica para
  quando houver demanda
- **Reordenar a marcação depois de feita** (arrastar os marcados). Desmarcar e
  remarcar resolve, e arrastar é superfície de UI desproporcional ao ganho
- **O bug do `⌘1`** (crash + perda de histórico, card no board): não foi
  investigado e continua aberto. Esta fase **não** o resolve nem o agrava — ver
  "Riscos"
- **A verificação manual pendente da Fase 3** (E2–E11, F1–F5, G1, e o C2 que
  falhou)

## Decisões tomadas

| Decisão | Escolha | Por quê |
|---|---|---|
| Escopo da fase | **Só o item 14** | Ver acima |
| Gesto de marcar | **`⌘`+clique e `⌘M`**, mais entrada no menu de contexto | `⌘`+clique é a convenção do Finder; sem equivalente de teclado o recurso ficaria fora do caminho normal de uso numa overlay que é operada por teclado |
| A tecla | **`⌘M`**, sem `⌥` | `⌥` altera o caractere entregue (`⌥M` chega como `µ`), e o caractere alternativo muda com a camada de teclado — não há lista finita a registrar. É a mesma classe da armadilha do `⇧` que matou `⌘⇧K` na Fase 2. `⌘M` é "Minimizar" num app comum, mas este é `LSUIElement` e nunca monta `NSApp.mainMenu`, então não há key equivalent para colidir |
| Tipos marcáveis | **Texto e URL** | Mesmo gate que `⌘E` já usa. Regra de uma linha, sem caso misto a desenhar |
| Ordem do bloco | **Ordem de marcação**, não da lista | É o que o "pronto quando" do item pede. A ordem da lista não seria controlável sem reordenar o histórico |
| O que `↵` faz com marcação ativa | **Cola o bloco** | Havendo marcação, ela *é* a seleção — como `↵` no Finder age sobre o que está selecionado. A alternativa (marcar 3, apertar `↵` por instinto, colar 1 e a overlay fechar levando a marcação) é a falha provável |
| Clique e `⌘1`–`⌘9` com marcação ativa | **Colam aquele item, marcação descartada** | Regra de uma frase: o caminho que nomeia um item cola aquele item. `⌘3` colar cinco itens faria o número do atalho deixar de dizer o que ele faz |
| Promoção ao topo | **Nenhum item muda de posição.** Grava só `lastUsedAt` | Colar 5 itens reescrevendo `createdAt` joga os 5 para a frente da fila e desloca a numeração do `⌘1`–`⌘9` junto. `lastUsedAt` existe no modelo exatamente para registrar uso, e hoje é redundante. **Exceção deliberada** ao comportamento de todo o resto do app — documentada no código |
| Separador | **Preferência com 4 opções nomeadas**, nova linha por padrão | O ROADMAP pede configurável. Opções nomeadas evitam validar entrada livre e decidir como exibir `\n` |
| Formatação do bloco | **Preservada por item** | Fiel ao item 7, que existe para o app parar de achatar o que capturou. `⇧↵` continua entregando plano |
| Onde vive a marcação | **`MarkedSelection` observável, possuída pelo `OverlayWindowController`** | `OverlayView` é construída uma vez em `prepare()` e reusada por todo o processo: `@State` sobreviveria ao fechamento da gaveta e a marcação reapareceria na abertura seguinte. Mesmo motivo, já documentado, pelo qual `SearchState` mora lá |
| O que a marcação guarda | **`[UUID]`, não `[ClipboardItem]`** | `ClipboardItem` é `@Model`; segurar referências fortes a objetos que o contexto pode deletar deixa ponteiros pendurados numa lista invisível. Com ids, um item apagado enquanto marcado some sozinho na resolução, sem código de limpeza |
| Marcação × busca | **A marcação sobrevive a mudanças na busca** | Marcar dois, buscar outra coisa, marcar um terceiro e colar os três é o caso de uso real de juntar trechos de origens diferentes. Obriga a indicação permanente na barra superior, porque pode haver marcados fora da vista |
| Onde a indicação aparece | **Dentro do `OverlayTopBar`**, à direita | Os dois estados da barra já deixam folga à direita (o espaço reservado às pílulas da Fase 5 e a sobra do campo de 470pt). Uma faixa nova comeria altura dos cards e mexeria no layout que a Fase 3 acabou de assentar |
| Chip no card | **Substitui o número do `⌘1`–`⌘9`** enquanto marcado | Um número por card. Enquanto se monta um bloco, a ordem é a informação útil; o atalho volta quando a marcação é limpa |

## Ordem de execução

| # | Entrega | Por que nesta posição |
|---|---|---|
| 1 | `MarkedSelection` e `MultiPasteSeparator` | A primitiva e o enum de separador. 100% testáveis sem GUI, sem depender de nada |
| 2 | `MultiPaste`: resolução e junção | Consome 1. É onde mora a decodificação de texto rico, o risco técnico da fase |
| 3 | `ClipboardWriter.writeJoined` e o caminho até o `⌘V` | Consome 2. Toca `lastUsedAt` sem tocar `createdAt` — a exceção deliberada |
| 4 | Preferência do separador | Independente de 3; separada porque acrescenta chave em `UserDefaults`, que tem teste próprio congelando os nomes |
| 5 | Teclado e marcação na `OverlayView` | Consome 1 e 3. Concentra o risco de regressão nos atalhos das Fases 1–3 |
| 6 | Card, barra superior e menu de contexto | A superfície visual. Depois que o comportamento já está de pé |
| 7 | Verificação manual | Fecha a fase |

---

## 1. `MarkedSelection` e `MultiPasteSeparator`

**Arquivo novo:** `MyPasteApp/Services/MarkedSelection.swift`.

Espelha `SearchState` na forma: `@Observable`, `@MainActor`, instanciada pelo
`OverlayWindowController` e passada à `OverlayView` como um `let` — uma
referência observável basta para as atualizações chegarem, porque ler suas
propriedades durante `body` já registra a dependência.

```swift
@Observable
@MainActor
final class MarkedSelection {
    /// Ids na ordem em que foram marcados. Essa ordem é o contrato: é ela que
    /// o bloco colado respeita, e é dela que sai o número do chip no card.
    private(set) var ids: [UUID] = []

    var isEmpty: Bool { ids.isEmpty }
    var count: Int { ids.count }

    func contains(_ id: UUID) -> Bool { ids.contains(id) }

    /// Marca no fim da fila, ou desmarca. Desmarcar do meio renumera os
    /// seguintes, que é o comportamento correto: a posição 2 sempre é o
    /// segundo item que será colado.
    func toggle(_ id: UUID) {
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.append(id)
        }
    }

    /// Posição 1-based para o chip do card, ou nil se não está marcado.
    func order(of id: UUID) -> Int? {
        ids.firstIndex(of: id).map { $0 + 1 }
    }

    func clear() { ids.removeAll() }
}
```

**Arquivo novo:** `MyPasteApp/Services/MultiPasteSeparator.swift`.

```swift
enum MultiPasteSeparator: String, CaseIterable, Identifiable {
    case newline
    case blankLine
    case space
    case comma

    var id: String { rawValue }

    /// O que efetivamente entra entre dois itens.
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

    /// Lê a preferência, caindo no padrão para valor ausente ou desconhecido —
    /// inclusive um `rawValue` gravado por uma versão futura e depois revertida.
    static func resolve(_ raw: String?) -> MultiPasteSeparator {
        raw.flatMap(MultiPasteSeparator.init(rawValue:)) ?? .newline
    }
}
```

**Testes** (`MarkedSelectionTests`, `MultiPasteSeparatorTests`): marcar acumula
na ordem; marcar duas vezes desmarca; desmarcar do meio renumera os seguintes;
`order` é 1-based e nil para não marcado; `clear` esvazia; `resolve` cai no
padrão para nil, string vazia e `rawValue` desconhecido.

---

## 2. `MultiPaste`: resolução e junção

**Arquivo novo:** `MyPasteApp/Services/MultiPaste.swift`.

Três responsabilidades, deliberadamente separadas por isolamento: o que toca
`ClipboardItem` ou AppKit é `@MainActor`; o resto fica livre, e é onde mora o
grosso dos testes.

```swift
enum MultiPaste {
    /// Os tipos que podem entrar num bloco. Mesmo gate que `⌘E` usa para
    /// decidir o que é editável como texto.
    static func isMarkable(_ type: ClipboardItemType) -> Bool {
        type == .text || type == .url
    }

    /// Resolve os ids marcados contra a lista atual, **na ordem de marcação**.
    ///
    /// Ids que não têm mais item correspondente são descartados em silêncio:
    /// é assim que um item deletado enquanto marcado sai do bloco sem exigir
    /// nenhuma limpeza reativa em `MarkedSelection`. Percorre `items` uma vez
    /// para indexar, em vez de buscar linearmente por id.
    static func resolve(ids: [UUID], in items: [ClipboardItem]) -> [ClipboardItem] {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    /// A representação rica de um item, para entrar no bloco.
    ///
    /// Despacha pelo `richTextFormat` guardado e **nunca adivinha**: decodificar
    /// uma captura só-HTML como RTF devolve nil em silêncio, que foi como a
    /// Fase 2 perdeu formatação no editor. Falha de decodificação cai para o
    /// texto plano — nunca para vazio, que apagaria o item do bloco.
    @MainActor
    static func attributed(for item: ClipboardItem) -> NSAttributedString {
        let plain = item.textContent ?? ""
        guard let data = item.richTextData, let format = item.richTextFormat,
              let decoded = RichText.decode(data: data, format: format)
        else { return NSAttributedString(string: plain) }
        return decoded
    }

    /// Junta as peças com o separador, sem atributos no separador.
    ///
    /// Sem isolamento de ator de propósito: é a regra que mais merece teste, e
    /// nada aqui toca o modelo nem o pasteboard.
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

**Por que o separador entra sem atributos:** herdar os do item anterior faria a
quebra de linha carregar a fonte e a cor do trecho de cima, e o resultado
mudaria conforme a ordem de marcação. Sem atributos, o destino aplica o seu
próprio padrão.

**Testes** (`MultiPasteTests`): `isMarkable` para os quatro tipos; `resolve`
preserva a ordem de marcação e não a da lista; `resolve` descarta id inexistente;
`resolve` com lista vazia; `joined` de zero, um e três pedaços; `joined` não põe
separador antes do primeiro nem depois do último; `joined` com cada um dos
quatro separadores. `attributed` ganha cobertura nos dois ramos (com e sem
`richTextData`) e no ramo de decodificação falha — este último é a lacuna que a
Fase 2.5 anotou como pendência para `RichText.decode` e que aqui não se repete.

---

## 3. `ClipboardWriter.writeJoined` e o caminho até o `⌘V`

**Método novo em `ClipboardWriter`, não um parâmetro no `write` existente.** Os
dois divergem justamente no que salvam: `write` promove ao topo reescrevendo
`createdAt`; este não toca `createdAt` de ninguém. A Fase 2 já pagou por juntar
dois salvamentos de semântica diferente — foi o quase-bug de corrupção que
separou `ItemEdit.apply` de `applyLabel`.

```swift
/// Escreve vários itens no pasteboard como um bloco só.
///
/// Diferente de `write(_:plainText:)` em um ponto que precisa ficar explícito:
/// **não promove nenhum item ao topo**. Colar N itens reescrevendo `createdAt`
/// de cada um jogaria o bloco inteiro para a frente do histórico e deslocaria a
/// numeração do ⌘1–⌘9 junto. `lastUsedAt` registra o uso sem mexer na ordem —
/// é para isso que o campo existe.
func writeJoined(_ items: [ClipboardItem],
                 separator: MultiPasteSeparator,
                 plainText: Bool) {
    guard !items.isEmpty else { return }
    let pb = NSPasteboard.general
    monitor?.ignoreNextChange = true
    pb.clearContents()

    for item in items { item.lastUsedAt = .now }
    try? items.first?.modelContext?.save()

    let joined = MultiPaste.joined(items.map(MultiPaste.attributed(for:)),
                                   separator: separator)
    let plain = joined.string

    if !plainText,
       let rtf = try? joined.data(
           from: NSRange(location: 0, length: joined.length),
           documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
        pb.setData(rtf, forType: .rtf)
    }
    // Sempre presente, mesmo com RTF ao lado: um pasteboard só-RTF quebra a
    // colagem em qualquer campo de texto simples. Ver `RichText.payload`.
    pb.setData(Data(plain.utf8), forType: .string)
}
```

Três pontos que o código acima decide de propósito:

- **`ignoreNextChange` continua bastando.** Ele pula uma única mudança do
  `changeCount`, e isto é **uma** escrita — não um laço. É também por isso que
  não há `pasteDelayMs` entre itens: há um `⌘V` só
- **O bloco é sempre codificado como RTF**, mesmo quando as origens eram HTML. É
  o mesmo formato que `ItemEdit.apply` já grava ao salvar uma edição, e evita
  ter que escolher um formato "vencedor" entre origens heterogêneas
- **O save vai pelo contexto do primeiro item.** Todos vêm do mesmo `@Query`,
  logo do mesmo contexto; salvar uma vez cobre as N mutações

**No `OverlayWindowController`:** entra um `onPickMultiple([ClipboardItem], Bool)`
ao lado do `onPick` existente, com corpo idêntico no que diz respeito à janela —
`hideImmediately()` (nunca `hide()`, cujo fade de 0.18s sobrevive ao delay da
colagem e faria o painel receber o próprio `⌘V`), depois `PasteSimulator` com
`pasteDelayMs`, respeitando `autoPasteEnabled`. No `AppDelegate`, o closure
termina em `writer.writeJoined(...)`, lendo o separador da preferência.

`onPick` **não** é generalizado para receber array. As duas semânticas de
promoção são diferentes, e um único caminho com um `if` dentro é exatamente a
forma que o bug de corrupção da Fase 2 teve.

---

## 4. Preferência do separador

Chave nova em `PreferenceKeys`, acrescentada também ao array `all` — é o array
que `PreferenceKeysTests` congela para que uma renomeação não faça toda
instalação existente cair no padrão em silêncio.

```swift
/// Como os itens de uma colagem múltipla são separados. Nova linha por padrão.
static let multiPasteSeparator = "multiPasteSeparator"
```

Picker em `GeneralSettingsView`, dentro da `Section("Paste items")` que já existe,
abaixo do toggle de texto simples, com uma linha de descrição no mesmo estilo
`.caption`/`.secondary` das outras. Rótulo: "Separate multiple items with".

---

## 5. Teclado e marcação na `OverlayView`

`OverlayView` ganha `let marked: MarkedSelection`, ao lado de `let search`.

**`⌘M` — marcar/desmarcar o card selecionado:**

```swift
.onKeyPress(keys: ["m"]) { press in
    guard press.modifiers.contains(.command) else { return .ignored }
    guard let item = filtered.first(where: { $0.id == selectedID }),
          MultiPaste.isMarkable(item.type) else { return .ignored }
    marked.toggle(item.id)
    return .handled
}
```

Só `"m"` minúsculo: sem `⇧` no atalho, não há a variante maiúscula que a Fase 2
descobriu com `⌘⇧K`. E sem `⌥`, não há caractere alternativo dependente de
camada de teclado.

**`↵` — o bloco quando há marcação:**

```swift
.onKeyPress(.return, phases: .down) { press in
    let plain = ItemActions.resolvePastePlainText(
        alwaysPlainText: alwaysPastePlainText,
        shiftHeld: press.modifiers.contains(.shift))
    if !marked.isEmpty {
        let block = MultiPaste.resolve(ids: marked.ids, in: items)
        guard !block.isEmpty else { return .ignored }
        pickMultiple(block, plainText: plain)
        return .handled
    }
    // ... comportamento atual, item selecionado
}
```

**`resolve` roda contra `items`, a lista completa — nunca contra `filtered`.**
A marcação sobrevive à busca por decisão de design, e resolver contra a lista
filtrada faria o bloco encolher sozinho conforme o usuário digitasse: marcar
três itens e depois digitar qualquer coisa no campo colaria menos do que se
marcou. `filtered` continua sendo o que governa seleção e navegação; a marcação
não é sobre visibilidade.

`pickMultiple` é o par de `pick` para o bloco, com a mesma forma de uma linha:

```swift
private func pickMultiple(_ items: [ClipboardItem], plainText: Bool) {
    onPickMultiple(items, plainText)
}
```

Diferente de `pick`, não passa por `ItemActions`: aquele tipo é "tudo que se
pode fazer com **um** item", e seu `paste` grava `lastUsedAt` de um só. A
gravação dos N acontece dentro de `writeJoined`, num lugar só.

**`⌘`+clique — marcar pelo mouse:**

`onTapGesture` não reporta modificadores, então `⌘` é lido do evento corrente no
momento do clique, exatamente como `pastesPlainText` já faz com `⇧`:

```swift
.onTapGesture {
    if NSEvent.modifierFlags.contains(.command), MultiPaste.isMarkable(item.type) {
        marked.toggle(item.id)
    } else {
        pick(item)
    }
}
```

**`⌘1`–`⌘9` não muda em nada.** O handler existente continua colando o item da
posição, com marcação ou sem. Nenhum código novo, nenhuma condição nova.

**"Marcação descartada" não é uma ação — é consequência.** Colar um item avulso
com marcação ativa não chama `clear()` em lugar nenhum: a overlay fecha, e a
abertura seguinte limpa tudo em `show()`. Limpar explicitamente no `pick`
acrescentaria um segundo lugar que sabe apagar a marcação, e dois lugares
divergem no primeiro caminho de saída que alguém esquecer de cobrir — que é
exatamente por que `show()` é o único ponto de reset, como já é para a busca.

**`⎋` — um degrau novo.** `SearchState.escapeAction` ganha o parâmetro
`hasMarks` e o caso `.clearMarks`, entre `.closeSearch` e `.dismissOverlay`:

```swift
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

A marcação vem **depois** da busca: com os dois ativos, o primeiro `⎋` larga a
busca, o segundo limpa a marcação, o terceiro fecha a gaveta — sempre o mais
volátil primeiro, que é a regra que a função já seguia.

**Limpeza:** `OverlayWindowController.show()` chama `marked.clear()` junto de
`searchState.close()`. É o único lugar que cobre as três formas de a gaveta ir
embora (Escape, colagem via `hideImmediately`, clique fora), nenhuma das quais
roda teardown dentro da `OverlayView`.

**Testes:** a tabela-verdade de `escapeAction` ganha as linhas de `hasMarks` —
inclusive as que provam que ele **não** dispara enquanto há painel de filtros,
preview ou busca com conteúdo.

---

## 6. Card, barra superior e menu de contexto

**Card.** `ClipboardCardView` ganha `var markOrder: Int? = nil`. Quando presente,
o chip do rodapé mostra o número da ordem com estilo cheio em `Color.accentColor`
e texto branco, no lugar do `quickPasteLabel` de contorno; a borda do card usa o
mesmo destaque que `isSelected` já usa. `OverlayView` passa
`markOrder: marked.order(of: item.id)` e mantém `quickPasteLabel` como está — a
substituição acontece dentro do card, num único ponto, em vez de a view de fora
ter que decidir qual dos dois mandar.

**Barra superior.** `OverlayTopBar` recebe a contagem e, quando maior que zero,
desenha à direita uma pílula `3 marked · ⏎ paste · ⎋ clear`. Cabe nos dois
estados sem mexer no layout: em repouso, no espaço reservado às pílulas da Fase
5; com a busca aberta, na sobra à direita do campo de 470pt. É o que impede o
modo de falha que o ROADMAP registra na pausa do item 2 — estado invisível que o
usuário esquece —, e é especialmente necessário aqui porque a marcação sobrevive
à busca e pode ter itens fora da vista.

**Menu de contexto.** `ItemContextMenu` ganha "Mark for Multi-Paste" /
"Unmark", com glifo `⌘M` no fim do rótulo como texto — o mesmo tratamento que as
outras oito entradas usam, e pelo mesmo motivo registrado nas pendências da Fase
2: um `.keyboardShortcut` real daria duas origens à mesma ação. A entrada só
aparece para tipos marcáveis.

---

## 7. Verificação manual

A suíte cobre lógica pura e **nada em `Views/` ou `Window/`**. O roteiro
completo vai para `VERIFICACAO-FASE-4.md`, no formato do da Fase 3. O núcleo:

1. `⌘M` marca o card selecionado; o chip vira o número da ordem; `⌘M` de novo
   desmarca e o número do `⌘1`–`⌘9` volta
2. `⌘M` numa imagem e num arquivo não faz nada
3. `⌘`+clique marca; clique sem `⌘` cola só aquele item
4. Marcar 3, `↵`, e os três chegam no destino na ordem marcada
5. Desmarcar o do meio e conferir que os seguintes renumeram
6. Marcar dois, buscar outra coisa, marcar um terceiro, colar — os três saem, na
   ordem, apesar de dois estarem fora do filtro no momento da colagem
7. Trocar o separador nas preferências e repetir o passo 4
8. Marcar dois itens formatados e conferir a formatação preservada no destino;
   repetir com `⇧↵` e conferir texto plano
9. **Conferir que nenhum card mudou de posição depois da colagem** — o critério
   que distingue esta fase do resto do app
10. Apagar um item marcado e colar: o bloco sai sem ele, sem erro
11. `⎋` com marcação limpa a marcação e mantém a gaveta aberta; `⎋` de novo fecha
12. Fechar e reabrir a overlay: a marcação não reaparece
13. Confirmar que `⌘M` não minimiza nada nem é engolido pelo sistema

**Pronto quando** (critério do item 14): selecionar três itens, colar de uma vez
e ver os três no destino, na ordem escolhida.

---

## Riscos

**`⌘M` pode estar ocupado por algo que a leitura de código não revela.** A
premissa é sólida — `INFOPLIST_KEY_LSUIElement = YES` e nenhum `NSApp.mainMenu`
em lugar nenhum, que é a mesma constatação que explicou por que `⌘B` não
funciona no editor (issue #4) — mas premissas desse tipo já erraram uma vez
nesta base. O passo 13 da verificação existe para isso, e trocar a tecla é
mudança de uma linha.

**A junção de texto rico pode produzir blocos visualmente heterogêneos.** É
consequência aceita da decisão de preservar formatação: três origens diferentes
rendem três fontes diferentes. `⇧↵` é a saída, e o passo 8 exercita as duas.

**`NSAttributedString` de itens longos aloca o documento inteiro.** A Fase 2.5
mostrou que a intuição sobre custo de memória em SwiftUI erra por ordem de
grandeza. Aqui o risco é menor e diferente — a junção é transitória, não uma
layer rasterizada, e é liberada assim que o RTF é gerado —, mas marcar dez itens
longos é o caso que ninguém vai testar por acaso. Se `scripts/memwatch.sh` for
rodado nesta fase, esse é o marco a acrescentar.

**O bug do `⌘1` continua aberto.** A colagem múltipla é um caminho novo até o
`PasteSimulator`, não uma mudança no caminho existente: `pick`, `write` e o
`⌘1`–`⌘9` não são tocados. Se o crash reproduzir durante a verificação desta
fase, é evidência do bug antigo — e uma oportunidade de capturar a stack trace
que falta —, não uma regressão da Fase 4.

**A revisão de branch inteira é obrigatória.** Três fases seguidas (2, 2.5 e 3)
tiveram seus piores defeitos encontrados só com o conjunto à vista, sempre em
costuras entre tarefas escritas a vários commits de distância. As costuras
prováveis desta fase: a resolução de ids contra `items` versus `filtered`, a
limpeza da marcação em `show()`, e a interação entre o chip de ordem e o do
quick paste dentro do card.
