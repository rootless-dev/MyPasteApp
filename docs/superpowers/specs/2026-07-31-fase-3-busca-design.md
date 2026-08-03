# Fase 3 — Busca

Design aprovado em 2026-07-31. Cobre os itens 11, 12 e 13 do `ROADMAP.md`, mais
a reorganização do topo da overlay que o `DESIGN.md` registra como mudança
derivada 11 e 16.

Ambiente de referência: Xcode 26.6, SDK macOS 26.5, deployment target 26.2,
Swift 5. O projeto usa `PBXFileSystemSynchronizedRootGroup`, então arquivos
novos entram no alvo pelo simples fato de existirem no diretório — não há
`project.pbxproj` para editar.

Branch: `feature/fase-3-busca`, criada a partir de `develop`.

## O que a fase entrega

| Item | Entrega |
|---|---|
| 11 | OCR local em imagens, alimentando a busca. Automático na captura, com backfill do histórico existente |
| 12 | Power Search: filtros por tipo, app de origem e data, combinados por interseção, acionados por um botão dentro do campo de busca |
| 13 | Jump to History: voltar de um resultado de busca para a posição do item no histórico completo |
| — | O topo da overlay em dois estados: lupa como botão em repouso, campo largo com tokens quando ativa. É o padrão do Paste (`01-barra-principal.png` e `12-busca-ativa.png`) |

## Decisões tomadas

| Decisão | Escolha | Por quê |
|---|---|---|
| Onde a filtragem acontece | **Em memória**, com a regra extraída para um `ItemSearch` puro | O predicado do `@Query` escalaria melhor, mas trocá-lo a cada tecla exige remontar a view, e `#Predicate` não faz comparação case/diacritic-insensitive decente. O custo real ainda não foi medido — a fase mede antes de complicar |
| Quando o OCR roda | **Automático na captura, em fila serial de baixa prioridade, mais backfill automático** | Busca que funciona "só às vezes" é a pior falha possível aqui. A fila serial é o que impede que o backfill vire rajada de CPU |
| Marcador de processado | **`ocrProcessedAt: Date?`**, separado de `ocrText` | Sem ele, uma imagem sem texto seria reprocessada em todo launch, para sempre. `ocrText` nulo não distingue "não tem texto" de "ainda não olhei" |
| Teto do texto reconhecido | **10.000 caracteres** | Um screenshot de tela cheia rende poucos KB; o teto protege a filtragem por tecla do caso patológico, sem afetar o caso real |
| Idiomas do OCR | **`pt-BR` e `en-US` na mesma request** | O padrão só-inglês do Vision degrada muito o reconhecimento de português. É a diferença entre achar e não achar |
| Texto reconhecido visível? | **Não** — só alimenta a busca | O card continua "Imagem 486×388". Expor o texto no painel de preview mexeria justamente onde mora o cuidado de memória da Fase 2.5, para um ganho secundário |
| Desligar o OCR apaga o já reconhecido? | **Não** | Desligar é "pare de gastar CPU", não "destrua dado". Apagar o que já existe é uma ação separada, e não entra nesta fase |
| Filtros ativos, onde aparecem | **Tokens dentro do próprio campo**, antes do texto | Não roubam altura e mantêm o topo como uma faixa única, fiel ao Paste. O modo de falha que o roadmap alerta — filtro esquecido, histórico aparentemente vazio — fica descartado, porque o filtro está sempre à vista |
| Painel de filtros | **Camada dentro da overlay** (`ZStack`), não `.popover` | Um popover abre janela nova, e a overlay é `.transient`: some ao perder foco. A Fase 2 já pagou essa conta com um `NSPanel` inteiro e uma exceção no monitor de clique-fora só para o preview conviver com ela |
| Como a busca é acionada | **Digitar qualquer caractere abre e recebe o caractere**, além de clique na lupa e `⌘F` | É o que o próprio Paste ensina no card de onboarding, e preserva o hábito de abrir a gaveta e sair digitando |
| Semântica do filtro de data | **Sobre `createdAt`**, com a semântica que o app já tem | `ClipboardWriter.write()` reescreve `createdAt` a cada colagem, então "hoje" significa "usado hoje", não "copiado hoje" — é o mesmo campo que ordena os cards. Separar captura de uso é uma mudança de uma linha com efeito em todo o app (fato 1 do roadmap) e merece item próprio, não um efeito colateral desta fase |
| `⌫` com a busca aberta | **Nunca apaga item** | Com um campo que agora pode estar aberto e vazio, manter o apagamento destruiria um item ao tentar apagar uma letra que não existe mais |
| `esc` com busca ativa | **Larga a busca primeiro; com a busca vazia, fecha a gaveta** | Dismiss what's on top, como o sistema faz em todo lugar. O toque duplo só acontece quando há texto ou token para largar |

## Ordem de execução

| # | Entrega | Por que nesta posição |
|---|---|---|
| 1 | `ItemSearch`: a regra pura | Toda a fase depende dela, e é a única parte 100% testável sem GUI. Extrair `OverlayView.matches` para cá é um refactor de risco zero que já vem com cinco testes existentes |
| 2 | OCR: modelo, serviço e fila | Maior risco técnico (API nova do Vision, concorrência, migração de schema) e maior tempo de verificação manual — quanto antes começar a ser exercitado, melhor |
| 3 | Preferência e backfill | Depende de 2; separada porque é onde mora o risco de rajada de CPU |
| 4 | `SearchState` e o topo em dois estados | Muda o layout e o foco inicial do teclado; entra depois que a regra de filtragem já está estável |
| 5 | Campo com tokens e painel de filtros | Consome 1 e 4. É a maior superfície de UI da fase |
| 6 | Teclado: as precedências | Só faz sentido com 4 e 5 no lugar. Concentra o risco de regressão nos atalhos das Fases 1 e 2 |
| 7 | Jump to History | Depende de 5 (precisa de filtro ativo para existir) |
| 8 | Medição de latência e verificação manual | Fecha a fase |

**Fora de escopo, com o lugar marcado:** pinboards e as pílulas do topo (Fase 5
— o lugar delas já nasce reservado no `HStack`); texto reconhecido visível no
painel de preview; ação de apagar texto reconhecido já existente; paginação do
`@Query` (aberta desde a Fase 2.5, e a entrega 8 decide se vira item de roadmap);
o gate formal de memória da Fase 2.5 e a checagem de TextKit do
`RichTextEditor`, ambos ainda abertos.

---

## 1. `ItemSearch`: a regra pura

**Arquivo novo:** `MyPasteApp/Services/ItemSearch.swift`.
**Sai de:** `OverlayView.matches`, que é removido de lá. Os cinco testes de
`ItemSearchTests` acompanham a mudança de chamador — o arquivo de teste já tem o
nome certo, porque a regra sempre pertenceu a este lugar.

```swift
enum AppFacet: Hashable {
    case bundle(String)
    case unknown          // sourceAppBundleID == nil
}

enum DateWindow: Hashable {
    case today, last7Days, last30Days
}

struct SearchFilter: Equatable {
    var types: Set<ClipboardItemType> = []
    var apps: Set<AppFacet> = []
    var dateWindow: DateWindow?

    var isEmpty: Bool { types.isEmpty && apps.isEmpty && dateWindow == nil }
}

enum ItemSearch {
    static func matches(item: ClipboardItem,
                        query: String,
                        filter: SearchFilter,
                        now: Date,
                        calendar: Calendar = .current) -> Bool
}
```

**Combinação.** União dentro de um eixo, interseção entre eixos: tipo ∈ {imagem,
texto} **e** app ∈ {Safari} **e** data = hoje **e** o texto casa. Um eixo vazio
não restringe nada.

**Texto.** Casa contra `preview`, `textContent`, `label` e `ocrText`, com
`range(of:options: [.caseInsensitive, .diacriticInsensitive])`. Substitui o
`lowercased()` atual por dois motivos: não aloca uma cópia da string por item a
cada tecla, e faz "cao" encontrar "cão" — que em português é ganho de uso, não
detalhe.

**Data.** `now` é parâmetro, nunca `Date.now` lido dentro da função. Um teste que
depende do relógio real falha à meia-noite e ninguém entende por quê. "Hoje" é
`calendar.isDateInToday`; as outras duas são janelas a partir de `now`.

**Facetas.** A lista de apps do painel deriva dos itens **atualmente no
histórico**, não dos apps instalados:

```swift
extension ItemSearch {
    struct Facets {
        var types: [ClipboardItemType]      // só os que existem, na ordem canônica
        var apps: [AppFacet]                // ordenados pelo nome exibido
    }
    static func facets(in items: [ClipboardItem]) -> Facets
}
```

Um app desinstalado deixa `NSWorkspace.urlForApplication` retornando `nil`: o
painel usa ícone genérico e o bundle ID como rótulo. Sem isso o filtro teria
botões invisíveis.

---

## 2. OCR: modelo, serviço e fila

**Arquivos novos:** `MyPasteApp/Services/OCRService.swift`,
`MyPasteApp/Services/OCRQueue.swift`.
**Alterados:** `Models/ClipboardItem.swift`, `Services/ClipboardMonitor.swift`.

### Modelo

Dois campos opcionais novos — migração leve do SwiftData, sem versionar schema,
como `richTextData` fez na Fase 2:

```swift
var ocrText: String?
/// Marcador de "já passou pela fila", independente do resultado. Nulo
/// significa "nunca olhei"; preenchido com `ocrText == nil` significa "olhei e
/// não havia texto" — sem essa distinção, toda imagem sem texto seria
/// reprocessada em todo launch.
var ocrProcessedAt: Date?
```

Nenhum dos dois entra em `contentHash` ou em `preview`. A deduplicação continua
derivando exclusivamente do conteúdo capturado, como a Fase 2 fixou para o texto
rico: um texto reconhecido que chega depois não pode transformar um item já
salvo em outro item aos olhos do `insertIfNotDuplicate`.

`ocrText` fica no store (sem `.externalStorage`): o teto de 10.000 caracteres o
mantém na mesma ordem de grandeza de `textContent`, que também não usa storage
externo.

### Serviço

```swift
enum OCRService {
    static let maxCharacters = 10_000
    static func recognize(imageData: Data) async throws -> String
    /// Junta as linhas reconhecidas e aplica o teto. Pura, testável sem Vision.
    static func normalize(_ lines: [String]) -> String
}
```

Usa a API Swift-native do Vision (`RecognizeTextRequest`), disponível no target
26.2, com `recognitionLevel = .accurate` e os dois idiomas. Os bytes vão direto
do `imageData` para o handler, **sem passar por `NSImage`** — a Fase 2.5 mostrou
o que custa decodificar uma imagem inteira sem precisar.

O nome exato dos membros da API nova é a primeira coisa que a implementação
valida contra o SDK; se divergir, o caminho conhecido é `VNRecognizeTextRequest`
com `VNImageRequestHandler(data:)`, que faz o mesmo trabalho com mais cerimônia.

### Fila

```swift
@MainActor
final class OCRQueue {
    init(modelContext: ModelContext, defaults: UserDefaults = .standard)
    func enqueue(_ id: UUID)
    func enqueueBacklog()
}
```

Um único `Task` em execução por vez, prioridade `.utility`, fila FIFO de
**UUIDs, não de referências ao `@Model`**. Dois motivos: o item pode ser apagado
enquanto espera (pela retenção ou pelo usuário), e um `@Model` não é `Sendable`
para atravessar a fronteira de ator. Ao chegar a vez de um id, a fila busca o
item; se ele não existe mais, segue adiante em silêncio.

O reconhecimento roda fora do `MainActor`; o hop de volta serve só para gravar
`ocrText`/`ocrProcessedAt` e salvar. Nada de OCR dentro de `poll()`: rodar Vision
no caminho da cópia trava a cópia e o app inteiro.

### Decisão de enfileirar

Pura e estática, para ser testada sem container nem Vision:

```swift
enum OCRScheduler {
    static func needsOCR(type: ClipboardItemType,
                         ocrProcessedAt: Date?,
                         enabled: Bool) -> Bool
}
```

A decisão deliberadamente **não** olha `imageData`. O campo é
`.externalStorage`: só tocá-lo já carrega os bytes do disco, e decidir se vale a
pena olhar uma imagem não pode custar carregar a imagem. Um item de tipo
`.image` sem bytes é tratado pela fila, que marca `ocrProcessedAt` e segue.

---

## 3. Preferência e backfill

**Alterados:** `Services/PreferenceKeys.swift`,
`Views/Preferences/PrivacySettingsView.swift`, `Services/ClipboardMonitor.swift`.

Chave nova `enableImageOCR`, ligada por padrão, lida com `object(forKey:)` — o
padrão que a Fase 2 estabeleceu para distinguir "chave ausente" de "gravada como
falso". Toggle na aba Privacidade, com descrição sob ele (`SettingsToggle`, como
os demais) dizendo que o reconhecimento é **local** e que nada sai da máquina.

Desligar interrompe fila e backfill; o que já foi reconhecido permanece e
continua pesquisável.

**Backfill.** Em `ClipboardMonitor.start()`, ao lado do `backfillLinkMetadata()`
que já existe: busca imagens com `ocrProcessedAt == nil` e as enfileira. A fila
serial de baixa prioridade é o que transforma 500 imagens antigas numa tarefa de
fundo em vez de uma rajada de CPU no primeiro launch depois da atualização.

**Captura.** Em `poll()`, depois de `insertIfNotDuplicate(item)` e no mesmo
lugar onde `fetchLinkMetadata` já é disparado para URLs. O item é salvo primeiro;
o OCR o alcança depois.

---

## 4. `SearchState` e o topo em dois estados

**Arquivos novos:** `MyPasteApp/Services/SearchState.swift`,
`MyPasteApp/Views/Search/OverlayTopBar.swift`.
**Alterado:** `Views/OverlayView.swift`.

```swift
@Observable @MainActor
final class SearchState {
    private(set) var isActive = false
    var text = ""
    var filter = SearchFilter()
    var isFilterPanelOpen = false

    var hasContent: Bool { !text.isEmpty || !filter.isEmpty }

    func activate(seeding character: Character?)
    func close()   // desativa e limpa texto, tokens e painel
}
```

As regras que decidem comportamento são **estáticas e puras**, para serem
testadas sem montar view nenhuma; os métodos de instância acima só as aplicam
(ver entrega 6).

**Repouso.** A faixa mostra o glifo de lupa centralizado, sem fundo, como em
`01-barra-principal.png`. Sem pinboards ainda, ela fica sozinha; o espaço à
direita já nasce como um `HStack` vazio que a Fase 5 preenche com as pílulas.

**Ativa.** Campo de até 470pt centralizado, cantos totalmente arredondados (raio
= metade da altura), borda de foco em `accentColor`, lupa à esquerda, tokens, o
texto, e o ícone de filtro (`line.3.horizontal.decrease`) à direita.

**O foco deixa de ter um dono fixo.** Hoje `onAppear` faz `searchFocused = true`
e o campo segura o foco a overlay inteira; `onKeyPress` só recebe evento porque
o campo focado é descendente da view que o declara. Com a busca fechada não há
campo para focar, e sem foco nenhum a overlay volta a ser exatamente o que a
Fase 1 encontrou: uma janela que não recebe teclado. O foco passa a ter dois
destinos explícitos:

```swift
enum OverlayFocusTarget: Hashable { case list, search }
```

`onAppear` foca `.list` (a faixa de cards, `.focusable()`), abrir a busca move
para `.search`, largá-la devolve para `.list`. Esse é o ponto de maior risco da
fase inteira, e o passo 3 da verificação manual existe para exercitá-lo.

**Enquanto a entrega 5 não chega**, o estado ativo mostra a `SearchBar` atual
dentro da moldura nova, sem tokens nem botão de filtro. É o que mantém a entrega
4 verificável isoladamente, em vez de deixar a fase com um topo pela metade
entre duas tarefas.

**Sobre a altura.** O `DESIGN.md` afirma que a lupa-que-expande "devolve altura à
área de cards", mas nas duas capturas do Paste a faixa tem a mesma altura nos
dois estados. O ganho medido aqui é de ~10pt (o campo atual são 33pt mais 20 de
padding; um botão de 28pt com padding menor fecha em ~44). A mudança vale pela
limpeza visual e por preparar a faixa para os pinboards — não pela altura, e a
spec registra isso para ninguém cobrar depois um ganho que não existe.

---

## 5. Campo com tokens e painel de filtros

**Arquivos novos:** `Views/Search/SearchFieldView.swift`,
`Views/Search/SearchTokenView.swift`, `Views/Search/FilterPanelView.swift`.
**Removido:** `Views/SearchBar.swift`, absorvido pelo campo novo.

```swift
enum SearchToken: Hashable {
    case type(ClipboardItemType)
    case app(AppFacet)
    case date(DateWindow)
}
```

Cada token é uma pílula pequena com símbolo, rótulo curto e um `×`. Nome de app
longo trunca com `lineLimit(1)` e largura máxima — três tokens num campo de
470pt é o caso apertado previsto, e é o motivo de o rótulo ser curto ("Safari",
não "Safari · aplicativo de origem").

`SearchToken` é derivado de `SearchFilter`, não uma segunda fonte de verdade: a
lista de tokens é uma função do filtro, e remover um token é uma mutação do
filtro. Duas coleções paralelas divergiriam na primeira operação de limpar.

**Painel.** Camada em `ZStack` dentro da overlay, ancorada abaixo do ícone de
filtro, sobre os cards. Três seções — tipo, app, data — com seleção múltipla nos
dois primeiros e escolha única na data. Clicar fora do painel (ainda dentro da
overlay) o fecha; `esc` com o painel aberto fecha o painel antes de qualquer
outra coisa.

O painel exibe apenas as facetas que existem no histórico atual
(`ItemSearch.facets`), com "Desconhecido" para itens sem app de origem —
inclusive os criados pelo item 10, que sem esse grupo ficariam inalcançáveis com
qualquer filtro de app ativo.

---

## 6. Teclado: as precedências

**Alterado:** `Views/OverlayView.swift`, `Services/SearchState.swift`.

| Tecla | Busca fechada | Busca aberta |
|---|---|---|
| Caractere sem `⌘⌃⌥` | abre a busca **semeada com o caractere** | digita |
| `⌘F` | abre e foca | foca |
| `␣` | abre/fecha o preview | campo vazio → preview; com texto → digita |
| `⌫` | apaga o item selecionado | campo vazio + tokens → remove o último token; caso contrário, digita. **Nunca apaga item** |
| `esc` | preview aberto → fecha preview; senão fecha a overlay | painel de filtro aberto → fecha o painel; preview aberto → fecha preview; busca com conteúdo → larga a busca; busca vazia → fecha a overlay |
| `←` `→` `↵` `⇧↵` `⌘1`–`⌘9` `⌘C` `⌘P` `⌘E` `⌘R` `⌘N` | inalterados | inalterados |

As três decisões viram funções estáticas puras, cada uma com sua tabela-verdade
coberta por teste:

```swift
extension SearchState {
    enum EscapeAction { case closeFilterPanel, hidePreview, closeSearch, dismissOverlay }
    enum BackspaceAction { case removeLastToken, passThrough, deleteItem }

    static func escapeAction(isFilterPanelOpen: Bool, isPreviewOpen: Bool,
                             isActive: Bool, hasContent: Bool) -> EscapeAction
    static func backspaceAction(isActive: Bool, textIsEmpty: Bool,
                                hasTokens: Bool) -> BackspaceAction
    /// Nulo quando a tecla não deve abrir a busca.
    static func activationCharacter(_ character: Character,
                                    modifiers: EventModifiers,
                                    isActive: Bool) -> Character?
}
```

**Armadilha herdada da Fase 2:** com Shift pressionado, a letra chega maiúscula
ao handler — `onKeyPress(keys: ["k"])` nunca dispara para `⇧K`. A captura de
ativação por isso não usa lista de teclas, e sim
`onKeyPress(characters:phases:)` sobre um `CharacterSet` de alfanuméricos e
pontuação, com guarda explícita contra `.command`, `.control` e `.option` — sem
essa guarda, `⌘E` abriria a busca com um "e" além de abrir o editor.

**A verificar à mão, porque não dá para provar sem GUI:** hoje `⌫` apaga o item
selecionado enquanto o campo de busca tem foco, o que significa que o `TextField`
deixa a tecla passar quando está vazio. A regra nova depende de continuar assim;
se o campo consumir a tecla, a remoção de token precisa ser tratada dentro do
próprio campo, e não no handler do container.

---

## 7. Jump to History

**Alterados:** `Views/ItemContextMenu.swift`, `Services/ItemActions.swift`,
`Views/OverlayView.swift`.

Entrada "Ver no histórico" no menu de contexto, com `⌘J`, **visível apenas
quando há busca ou filtro ativo** — sem isso ela não faz nada e só polui um menu
que já tem nove entradas.

A ação atravessa `ItemActions` como uma closure, do mesmo jeito que `onPreview`
já faz: limpar a busca e mover a seleção são estado de view, que `ItemActions`
não tem e não deve ter.

A ordem não pode ser trocada — guardar o id alvo, limpar texto e tokens, e só
então rolar. E há a armadilha que o roadmap já mapeou:
`onChange(of: filtered.first?.id)` reatribui a seleção sempre que a lista muda,
e limpar a busca dispara exatamente isso, roubando a seleção do item que se
queria destacar. O id pendente suprime essa reatribuição por um ciclo:

```swift
extension OverlayView {
    /// Nulo em `pending` devolve o comportamento atual.
    static func selectionAfterListChange(pending: UUID?, newFirstID: UUID?) -> UUID?
}
```

A rolagem em si é adiada para depois do re-render (o id ainda não está na lista
renderizada no mesmo ciclo), reaproveitando o `ScrollViewReader` e o
`proxy.scrollTo(id, anchor: .center)` que já existem.

**O mesmo mecanismo serve a `esc`.** Largar a busca também faz a lista voltar ao
tamanho cheio e dispararia a mesma reatribuição, perdendo o card selecionado.
`SearchState.close()` marca o id selecionado como pendente pelo mesmo caminho —
a diferença entre largar a busca e o Jump passa a ser só a rolagem: `⌘J` rola até
o item, `esc` preserva a seleção onde ela estiver. Uma regra, dois usos, em vez
de duas implementações que divergem no primeiro ajuste.

---

## 8. Medição de latência e verificação manual

### Gate de latência

**Arquivo novo:** `MyPasteAppTests/SearchPerformanceTests.swift`.

Filtragem completa sobre 500 itens sintéticos — um terço deles com 10.000
caracteres de `ocrText` —, medida com `ContinuousClock`. **Teto: 16ms**, um
quadro a 60Hz, que é o orçamento real de uma tecla digitada.

O roadmap avisa que `filtered` roda em memória a cada tecla e que o OCR piora
isso. Este teste é o que transforma esse aviso em número. Se estourar, a resposta
**não** é otimizar no escuro: abre-se um item de roadmap para paginação do
`@Query` — já listado como aberto desde a Fase 2.5 — com o número medido junto.

Testes de tempo são sensíveis a carga da máquina (a suíte já tem um flake
conhecido em `PauseControllerTests.timedPauseResumesAutomatically`). O teto
generoso é deliberado: interessa detectar uma regressão de ordem de grandeza,
não medir microssegundos.

### Suíte

| Arquivo | Cobre |
|---|---|
| `ItemSearchTests` (estendido) | Texto sobre `ocrText`; união dentro de um eixo; interseção entre eixos; `AppFacet.unknown`; janelas de data com `now` injetado; facetas derivadas do histórico |
| `SearchStateTests` | Abrir por caractere sem perder o caractere; guarda contra `⌘⌃⌥`; `escapeAction` e `backspaceAction` em todas as combinações; token derivado do filtro |
| `OCRSchedulerTests` | Quem precisa de OCR: já processado, tipo não-imagem, preferência desligada, imagem nova |
| `OCRServiceTests` | `normalize` — junção de linhas e truncamento em 10.000. Mais **um** teste de integração com PNG sintético contendo texto grande, com asserção tolerante |
| `JumpToHistoryTests` | `selectionAfterListChange` com e sem id pendente |
| `SearchPerformanceTests` | O gate acima |

### Verificação manual

É ela que fecha a fase — a suíte cobre lógica pura e não exercita a GUI:

1. Copiar um screenshot com texto, esperar, buscar por uma palavra que só existe
   dentro da imagem → o card aparece **(item 11, "pronto quando")**
2. Com histórico de imagens antigas, reiniciar o app e confirmar que o backfill
   roda sem travar a interface e sem rajada perceptível de CPU
3. Abrir a gaveta e digitar direto → a busca abre e **o primeiro caractere
   aparece**
4. Filtrar por tipo imagem + app + uma palavra que só existe no OCR → exatamente
   o item esperado **(item 12, "pronto quando")**
5. `⌫` no campo vazio remove o último token; `esc` larga a busca; `esc` de novo
   fecha a gaveta; `⌫` com a busca fechada volta a apagar o item selecionado
6. Buscar, achar um item, `⌘J` → lista completa rolada até ele, com ele
   selecionado **(item 13, "pronto quando")**
7. Desligar o OCR em Privacidade: imagens novas não são processadas, as antigas
   mantêm o texto e continuam pesquisáveis
8. Conferir que os atalhos das fases anteriores seguem intactos com a busca
   aberta e fechada: `⌘1`–`⌘9`, `⌘C`, `⌘P`, `⌘E`, `⌘R`, `⌘N`, `⇧↵`, `␣`

## Riscos

**A API nova do Vision.** `RecognizeTextRequest` é a forma Swift-native e é o
que o target 26.2 permite, mas a assinatura exata dos membros precisa ser
validada contra o SDK na primeira tarefa que a toca, não presumida. O caminho de
recuo é `VNRecognizeTextRequest`, que faz o mesmo com mais cerimônia.

**A precedência de teclado entre `TextField` e `onKeyPress` do container.** É a
peça que a fase não consegue provar sem GUI, e a Fase 1 já descobriu do pior
jeito que teclado na overlay falha em silêncio (o painel nunca aceitou teclado
até alguém exercitar à mão). O passo 5 da verificação manual existe por isso.

**Backfill concorrente com a retenção.** Um item pode ser podado enquanto espera
na fila. A fila busca por id e segue adiante quando não encontra — mas isso
precisa continuar verdadeiro se alguém trocar a fila de UUIDs por referências.

**OCR e privacidade.** Reconhecer texto de uma imagem transforma o conteúdo dela
em texto pesquisável no banco — inclusive de um screenshot de documento ou de
tela com senha. Tudo roda localmente e nada sai da máquina, e é isso que a
descrição do toggle precisa dizer. O toggle é o controle; a lista de apps
ignorados e os marcadores de pasteboard da Fase 1 continuam sendo a primeira
linha de defesa.

**Crescimento da `OverlayView`.** O arquivo já tem 456 linhas e esta fase toca
topo, teclado, filtro e jump. As extrações das entregas 1, 4 e 5 são o que
impede que ele passe de 800 — se durante a implementação algo grande for parar
lá "só por enquanto", é sinal de que a fronteira foi desenhada no lugar errado.
