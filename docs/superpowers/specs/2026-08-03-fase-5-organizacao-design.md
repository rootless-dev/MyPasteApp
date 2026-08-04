# Fase 5 — Organização

Design aprovado em 2026-08-03. Cobre os **itens 16, 17 e 18** do `ROADMAP.md`
(pinboards, retenção por item, regras por app mais ricas) — a fase inteira,
numa branch só, por decisão explícita do Carlos depois de a alternativa de
fatiar ter sido apresentada.

Ambiente de referência: Xcode 26.6, SDK macOS 26.5, deployment target 26.2,
Swift 5. O projeto usa `PBXFileSystemSynchronizedRootGroup`, então arquivos
novos entram no alvo pelo simples fato de existirem no diretório — não há
`project.pbxproj` para editar.

Branch: `feature/fase-5-organizacao`, criada a partir de `develop`.

## O que a fase entrega

| Item | Entrega |
|---|---|
| 16 | Pinboards: coleções nomeadas e coloridas, escolhidas por pílulas no topo da overlay. Um escopo ativo por vez, "Histórico" incluso. Criar, renomear inline, recolorir por paleta fixa de 8 cores, excluir sem perder itens |
| 17 | Retenção por item em três estados — seguir a política global, nunca expirar, ou expirar numa data escolhida — respeitados por `RetentionPolicy` com precedência documentada |
| 18 | Regra por app: ignorar tudo (o comportamento de hoje) ou capturar apenas certos tipos. Lista editável com ícone e nome do app em vez de bundle ID cru, e a lista embutida de gerenciadores de senha que a Fase 1 deixou aberta |

## Escopo e o que fica de fora

Fora de escopo, com o lugar marcado:

- **Retenção específica por app**, que o item 18 do ROADMAP pede. Seria o quarto
  eixo de retenção depois desta fase (global, por item, fixado, pinboard) e não
  tem caso de uso que os outros não cubram — o motivo real para regular um app
  é privacidade, e "não capture" e "capture só texto" bastam. Volta ao ROADMAP
  como item aberto
- **Arrastar um card até a pílula** para adicioná-lo a um pinboard. É o gesto do
  Paste, mas drag and drop em SwiftUI dentro de um `NSPanel` não-ativante é
  território de surpresas, e o item 21 (arrastar como arquivo, Fase 6) vai
  querer o mesmo gesto — os dois precisariam se distinguir pelo alvo do drop.
  Entra depois, com o custo conhecido
- **Reordenar as pílulas** por arrasto. Ordem de criação basta
- **Um item em vários pinboards**. Ver "Decisões tomadas"
- **Migrar `isPinned` para um pinboard "Favoritos"**. Fixar e organizar
  coexistem nesta fase — não há migração de dados de item, o que remove o maior
  risco que o ROADMAP atribuía ao item 16
- **O bug do `⌘1`** (crash + perda de histórico, card no board): segue sem
  diagnóstico. Esta fase não o resolve nem o agrava
- **A verificação manual pendente da Fase 4**, em especial o passo E1

## Decisões tomadas

| Decisão | Escolha | Por quê |
|---|---|---|
| Escopo da fase | **Os três itens numa branch** | Decisão do Carlos, tomada depois de a alternativa (só o 16, com 17 e 18 em fases próprias) ter sido apresentada com o argumento de que a Fase 4, com um item só, deu 26 commits e três defeitos Important. A contrapartida está registrada em "Riscos" |
| `isPinned` × pinboards | **Coexistem** | Fixar é favoritar rápido — `⌘P`, fixados primeiro na lista, protegido da poda — e continua idêntico. Pinboard é organizar por tema. Nenhum dado de item migra, e nenhum comportamento existente muda de significado |
| Navegação | **Escopo exclusivo**, um por vez | Primeira pílula "Histórico", sempre presente e selecionada ao abrir. Fiel a `design-refs/13`, e o estado vazio ("Pinboard Vazio") só faz sentido nesse modelo. A alternativa — pinboard como mais uma faceta do `SearchFilter` — faria as pílulas duplicarem o painel de filtros e o histórico nunca sairia da vista |
| O escopo persiste? | **Não.** Reabrir volta ao Histórico | Mesma classe de falha da pausa da Fase 2: abrir a gaveta e não ver o que acabou de copiar, sem entender por quê. `PinboardScope` é resetada em `show()`, como `SearchState` e `MarkedSelection` já são |
| Cardinalidade | **Um pinboard por item** (`pinboard: Pinboard?`) | A cor do cabeçalho passa a ter dono único, que é o que torna a decisão de cor decidível. Muitos-para-muitos exigiria uma regra arbitrária de desempate e mexeria em dois lados em toda exclusão |
| Item no pinboard sai do histórico? | **Não** | O pinboard é uma segunda vitrine do mesmo item, não uma gaveta que o esconde. Mover para um pinboard e o item sumir do lugar onde o usuário sempre o procura é um movimento invisível |
| Poda × pinboard | **Item em pinboard não expira e sai da contagem de `maxItems`** | "O que você organizou, o app não apaga", em uma frase. Contar no teto faria a poda por volume apagar o histórico recente para caber na coleção, com causa e efeito invisíveis |
| Excluir pinboard | **`.nullify`**, itens voltam ao histórico | O cuidado explícito do ROADMAP. E como nada é destruído, a exclusão dispensa confirmação — ver a linha seguinte |
| Confirmação de exclusão | **Nenhum diálogo. A consequência vai no rótulo** | `OverlayWindowController.windowDidResignKey` chama `hide()`: qualquer `NSAlert` vira key window e fecharia a gaveta inteira, levando junto busca, marcação e escopo. A entrada do menu diz "Excluir — os 12 itens voltam ao histórico" |
| Forma da retenção por item | **Tri-estado**: global (padrão) · nunca · expira em `<data>` | Permanência já tem dois caminhos (fixar, pinboard); a lacuna real que nada cobre hoje é o oposto — um token que deve sumir **antes** dos 30 dias. O tri-estado cobre os dois e ainda dá "permanecer sem ser promovido ao topo da lista", que fixar não dá |
| Âncora da expiração | **`expiresAt: Date?` absoluto**, gravado na escolha | A poda por idade compara `createdAt`, que é reescrito a cada colagem: uma expiração relativa reiniciaria a cada uso, que é exatamente o errado para uma expiração curta |
| Expiração × proteções | **`expiresAt` vencido apaga o item mesmo fixado ou em pinboard; `expiresAt` futuro protege o item das passadas 2 e 3** | Escolha explícita e datada do usuário vence regra automática, **nos dois sentidos**. O contrário deixaria um item marcado para sumir vivendo indefinidamente por estar fixado — e, na outra ponta, faria "expira em 1 hora" significar só um prazo mais curto, com a poda por idade ou por volume levando o item horas antes da data escolhida. *(A metade "futuro protege" foi decidida na revisão de branch, depois da implementação; ver a tabela de passadas na seção 2.)* |
| Cor do cabeçalho | **Dentro do pinboard, a cor do pinboard; no Histórico, a cor do app + ponto de filiação** | A premissa "o cabeçalho identifica a origem" continua valendo onde ela importa, e a filiação fica visível sem ocupar espaço. Não altera a precedência do rótulo (item 9), que segue substituindo tipo + hora |
| Como um item entra num pinboard | **Só pelo menu de contexto** (`Add to Pinboard ▸`) | Escopo mínimo e zero risco novo. O menu já é onde o usuário procura tudo que não é colar |
| Atalho para pôr em pinboard | **Nenhum** | `⌘M`, `⌘P`, `⌘E`, `⌘R`, `⌘C`, `⌘J` estão tomados, e a Fase 4 acabou de descobrir que este app **tem** barra de menus disputando teclas |
| Trocar de escopo pelo teclado | **`⌃Tab` / `⌃⇧Tab`**, com `⌥→` / `⌥←` como plano B | Escolhidos por não colidirem com a barra de menus que a cena `Settings` monta. Depois da lição do `⌘M`, a verificação disso é passo obrigatório do roteiro, não suposição |
| `⎋` dentro de um pinboard | **Volta ao Histórico antes de fechar a gaveta**, e depois das marcas | Ordem completa: painel de filtros → preview → busca → marcas → escopo → fechar. Mais volátil primeiro, como já é |
| Armazenamento das regras por app | **JSON numa chave nova do `UserDefaults`**, não `@Model` | `ClipboardMonitor` lê preferências sem `ModelContext` e deve continuar assim. Regras de privacidade também não deveriam entrar no store que o item 24 vai exportar |
| Migração de `ignoredAppsRaw` | **Uma regra "ignorar tudo" por linha, e a chave antiga fica intocada por uma versão** | Perder exclusões de privacidade em silêncio é a pior regressão possível neste item. Com a chave velha preservada, um erro de decodificação em qualquer máquina ainda é recuperável |
| Ordem dos guards de captura | **"Ignorar tudo" sobe para antes de ler o pasteboard; filtro por tipo depois de ler, antes de persistir** | Filtrar por tipo exige saber o tipo, o que exige ler. **Correção de premissa:** hoje o guard de app ignorado roda *depois* de `readCurrentItem()` (`ClipboardMonitor.swift:100`), então o conteúdo de um app banido já é lido para dentro de um `ClipboardItem` em memória — só não é persistido. Subir esse guard é uma melhoria de privacidade real e barata, e é pré-requisito para o filtro por tipo não piorar a situação |

## Ordem de execução

| # | Entrega | Por que nesta posição |
|---|---|---|
| 1 | `Pinboard`, campos novos em `ClipboardItem`, `PinboardPalette` | O schema. É a tarefa mais arriscada da fase e a que decide se `#Predicate` sobre relação é viável |
| 2 | `ItemRetention` e a `RetentionPolicy` reconciliada | Consome 1. Lógica pura, inteiramente testável, e onde mora o item 17 |
| 3 | `PinboardScope` e a regra de escopo | Consome 1. O estado observável e a regra pura de "que itens esse escopo mostra" |
| 4 | `PinboardBar`: a faixa, em dois estados | Consome 3. Só apresentação e seleção; sem criar nem editar ainda |
| 5 | Criar, renomear inline, recolorir, excluir | Consome 4. Concentra a edição do modelo pela UI num lugar só |
| 6 | Escopo aplicado à lista, teclado e estado vazio | Consome 3 e 4. Onde o risco de regressão nos atalhos das Fases 1–4 se concentra |
| 7 | Card: cor por escopo e ponto de filiação | Depois que a navegação já está de pé |
| 8 | Menu de contexto do card: pinboard e retenção | Consome 2 e 5. A porta de entrada dos itens 16 e 17 |
| 9 | `AppRule`: modelo, storage e migração | Independente de tudo acima. Lógica pura |
| 10 | `ClipboardMonitor`: a ordem nova dos guards | Consome 9. Toca a garantia central do app |
| 11 | Lista de apps em Ajustes, com seletor e gerenciadores de senha | Consome 9. Fecha a lacuna herdada da Fase 1 |
| 12 | Documentação e roteiro de verificação manual | Fecha a fase |

---

## 1. `Pinboard`, campos novos e a paleta

**Arquivos novos:** `MyPasteApp/Models/Pinboard.swift`,
`MyPasteApp/Services/PinboardPalette.swift`.
**Arquivo alterado:** `MyPasteApp/Models/ClipboardItem.swift`.

```swift
@Model
final class Pinboard {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ClipboardItem.pinboard)
    var items: [ClipboardItem]
}
```

`deleteRule: .nullify` é o que cumpre o cuidado do ROADMAP: excluir um pinboard
solta os itens, nunca os apaga.

`ClipboardItem` ganha três campos, todos opcionais ou com default:

```swift
var pinboard: Pinboard?
/// Quando este item deve ser apagado, independente da política global.
/// Data absoluta, gravada no momento da escolha — ver a decisão sobre âncora.
var expiresAt: Date?
/// O estado "nunca expira" do tri-estado. Distinto de `expiresAt == nil`,
/// que significa "siga a política global".
var keepForever: Bool = false
```

**A paleta** é fixa e literal, oito cores derivadas de
`design-refs/15-pinboard-menu-contexto.png`, na ordem em que aparecem lá:
vermelho, laranja, amarelo, verde, azul, roxo, rosa, cinza. Fixa e não color
picker livre pelo motivo do ROADMAP — o conjunto tem que permanecer harmônico e
legível sobre o fundo escuro.

```swift
enum PinboardPalette {
    static let colors: [String]  // 8 hex, sem "#"
    /// A primeira cor ainda não usada, ou a primeira da paleta quando todas
    /// já estão em uso. Determinística: dois pinboards criados em sequência
    /// nunca nascem da mesma cor enquanto houver cor livre.
    static func nextColor(usedBy existing: [String]) -> String
}
```

**O container precisa saber do modelo novo.** `AppDelegate.swift:45` cria o
container com `ModelContainer(for: ClipboardItem.self)` — uma lista literal de
um elemento. `Pinboard.self` entra nela. Sem isso, a relação existe no código,
compila, e falha em tempo de execução na primeira gravação. É uma linha, e é a
linha que mais fácil se esquece.

**Melhoria dirigida ao trabalho:** `Color(hex:)` hoje mora numa `extension`
no fim de `Views/Preview/LinkPreviewView.swift`, um arquivo que nada tem a ver
com pinboards. Passa a `MyPasteApp/Views/Support/Color+Hex.swift`. Movimento
puro, sem mudança de comportamento.

**Sobre a migração de schema.** Só adição de campos opcionais ou com valor
default, mais um modelo novo — o caso que a migração leve automática do
SwiftData cobre sem `VersionedSchema` nem `MigrationPlan`. **Este app nunca
migrou um store de verdade**, então "abrir com o store da versão anterior e
encontrar o histórico intacto" é passo obrigatório do roteiro manual (F1), não
suposição.

**Testes** (`PinboardPaletteTests`): `nextColor` com nenhuma, algumas e todas as
cores em uso; determinismo; e que a paleta tem exatamente oito entradas de seis
dígitos hex — congelar o formato, como `PreferenceKeysTests` faz com as chaves.

---

## 2. `ItemRetention` e a `RetentionPolicy` reconciliada

**Arquivo novo:** `MyPasteApp/Services/ItemRetention.swift`.
**Arquivos alterados:** `MyPasteApp/Services/RetentionPolicy.swift`,
`MyPasteApp/Views/Preferences/HistorySettingsView.swift`.

O tri-estado, como valor puro:

```swift
enum ItemRetention: Equatable {
    case global
    case forever
    case until(Date)

    /// Lê os dois campos do item. Estado inconsistente (`keepForever` e
    /// `expiresAt` ambos preenchidos) resolve para `.until`, porque uma data
    /// escolhida é sempre mais recente e mais específica que o interruptor.
    static func of(keepForever: Bool, expiresAt: Date?) -> ItemRetention

    /// Os dois campos a gravar. Escrever sempre os dois é o que impede o
    /// estado inconsistente de nascer.
    var fields: (keepForever: Bool, expiresAt: Date?)
}
```

As opções oferecidas na UI: 1 hora, 1 dia, 1 semana, 30 dias. Nomeadas como
durações e convertidas para data absoluta no momento da escolha.

`prune()` passa de duas passadas a três, nesta ordem:

| Passada | Regra |
|---|---|
| 1 — expirados | `expiresAt != nil && expiresAt < now` → apaga. **Ignora** `isPinned`, `keepForever` e pinboard: escolha explícita e datada vence |
| 2 — idade | `retentionDays` sobre o resto, excluindo o que é protegido |
| 3 — volume | `maxItems` sobre o resto, excluindo o que é protegido; o protegido **não conta** para o teto |

"Protegido" é uma regra só, escrita uma vez:

```swift
/// Um item sobrevive às podas globais quando está fixado, quando o usuário
/// pediu para mantê-lo, quando está num pinboard, ou quando tem uma data de
/// expiração ainda no futuro. Uma função, porque a mesma condição governa as
/// passadas 2 e 3 — e a Fase 1 já pagou o preço de uma regra de captura
/// escrita em dois lugares.
static func isProtected(_ item: ClipboardItem, now: Date) -> Bool
```

**Decidido na revisão de branch (depois da implementação):** uma `expiresAt`
**no futuro** é a quarta proteção. O princípio que a fase adotou — escolha
explícita e datada vence regra automática — vale nos dois sentidos: a data
manda apagar **depois** dela e manda **não** apagar antes. Sem isso, "expira
em 1 hora" só conseguia encurtar a vida do item, nunca prolongá-la: um item
mais velho que `retentionDays`, ou um histórico já no teto de `maxItems`,
levava o item embora horas antes da data escolhida. É também por isso que
`isProtected` passa a receber `now` — as duas chamadas (`prune()` e o botão
"Clear history") passam a data corrente, e a regra continua num lugar só. O
instante exato `expiresAt == now` não é nem apagado pela passada 1 (`< now`)
nem protegido (`> now`): não sobra futuro para proteger e a próxima passada o
apaga.

**O terceiro lugar que apaga por `!isPinned`** não está em `RetentionPolicy`:
é o botão "Clear non-pinned history" de `HistorySettingsView`, que faz seu
próprio `#Predicate { !$0.isPinned }`. Sem tocá-lo, o usuário limpa o histórico
e leva junto todas as coleções que acabou de montar — a mesma falha da poda,
por um caminho que a poda não cobre. Passa a usar `isProtected`, e o rótulo
passa a **"Clear history"** com uma legenda dizendo o que sobrevive: fixados,
itens em pinboards, itens marcados para nunca expirar e itens com data de
expiração ainda no futuro (esta última entrou com a decisão da revisão de
branch, acima — a legenda é o único texto que o usuário lê antes de apertar um
botão destrutivo, então ela lista as quatro). O rótulo atual promete uma regra
que deixa de ser verdade.

**Um paliativo que esta tarefa remove.** `ItemActions.makeManualItem` cria todo
item escrito à mão com `isPinned: true`, e o comentário ao lado diz por quê:
"`isPinned` é a única coisa que a poda protege hoje; o item 17 é a resposta
certa e substitui isto quando existir". Item 17 é agora. Passa a nascer com
`keepForever: true` e `isPinned: false` — protegido da poda sem ser empurrado
para o topo da lista, que é o que o usuário nunca pediu. `ManualItemTests`
afirma `isPinned` hoje e muda junto.

**O risco técnico da tarefa, e a escolha que o plano fixou.** As passadas 2 e 3
precisariam de `$0.pinboard == nil` dentro de `#Predicate`, e a passada 1
precisaria comparar um `Date?` com uma data — `#Predicate` do SwiftData é
frágil nos dois casos: relações e desempacotamento de opcional. Em vez de
descobrir isso durante a implementação, **as três passadas buscam e filtram em
memória com `isProtected`**:

- é **uma** regra, escrita em Swift puro, num lugar só. Um `#Predicate` que
  duplicasse `isProtected` seria uma segunda cópia da mesma regra, livre para
  divergir — a classe de erro que a Fase 1 já pagou
- `maxItems` tem teto de 5000 e default 500, e a poda roda no launch e a cada
  5 minutos (decidido na revisão de branch — sem um timer, "expira em 1 hora"
  significava "expira no próximo relançamento" num app de barra de status que
  fica semanas ligado), não num laço quente
- `imageData`, `richTextData` e os dados de link são `.externalStorage`: o fetch
  traz os objetos sem carregar esses blobs, então "buscar tudo" não é o que
  parece

O motivo vai num comentário no código — senão alguém "otimiza" isso de volta
para um predicado daqui a três meses.

**Testes** (`ItemRetentionTests`, `RetentionPolicyTests` estendido):

- round-trip `of` ↔ `fields` nos três estados; o estado inconsistente resolvendo
  para `.until`
- item expirado é apagado **mesmo** fixado, mesmo `keepForever`, mesmo em
  pinboard — um teste para cada, porque são três guardas independentes
- item em pinboard sobrevive à poda por idade com `retentionDays` estourado
- item em pinboard sobrevive à poda por volume **e** não empurra outros para
  fora: com `maxItems = 3`, três em pinboard mais três soltos deixam os três
  soltos vivos
- `keepForever` sobrevive às duas
- **"Clear history" preserva o que `isProtected` protege** — o teste que impede
  o botão de Ajustes de voltar a divergir da poda
- os casos que já passavam continuam passando: a suíte existente é a rede

---

## 3. `PinboardScope` e a regra de escopo

**Arquivo novo:** `MyPasteApp/Services/PinboardScope.swift`.

```swift
@Observable @MainActor
final class PinboardScope {
    /// O pinboard ativo, ou nil para o Histórico.
    private(set) var activeID: UUID?
    func select(_ id: UUID?)
    func reset()          // chamada por `show()`, como `SearchState.close()`
}
```

Possuída pelo `OverlayWindowController` e resetada em `show()` — pelo mesmo
motivo já documentado de `SearchState` e `MarkedSelection`: `OverlayView` é
construída uma vez em `prepare()` e reusada por todo o processo, então `@State`
sobreviveria ao fechamento da gaveta.

A regra de pertencimento é pura e vive junto:

```swift
extension PinboardScope {
    /// Um item pertence ao escopo quando o escopo é o Histórico (tudo
    /// pertence) ou quando é o pinboard do item.
    static func contains(item: ClipboardItem, activeID: UUID?) -> Bool
}
```

O escopo é aplicado **antes** de `ItemSearch.matches`, e não dentro dele: são
duas perguntas distintas — "isso está nesta vitrine?" e "isso casa com a
busca?" — e `SearchFilter` ganharia um eixo que se comporta diferente de todos
os outros (exclusivo, não combinável).

**A ordem de escape** ganha um degrau. `SearchState.escapeAction` passa a
receber `hasScope: Bool` e a devolver `.leaveScope` entre `.clearMarks` e
`.dismissOverlay`:

```
painel de filtros → preview → busca → marcas → escopo → fechar a gaveta
```

**Interações que ficam explícitas** (e viram teste ou comentário):

- **`⌘1`–`⌘9`** operam sobre `filtered`, que já é do escopo ativo. Dentro de um
  pinboard, `⌘3` cola o terceiro card visível — a regra do item 1 continua
  valendo sem alteração
- **A marcação de multi-paste resolve contra a lista completa**, nunca contra
  `filtered` — decisão da Fase 4, e ela vale igual para escopo: marcar dois num
  pinboard, voltar ao Histórico, marcar um terceiro e colar os três é o mesmo
  caso de uso que motivou a marcação sobreviver à busca. A pílula de contagem
  já cobre o "há marcados fora da vista"

**Testes** (`PinboardScopeTests`): `contains` com escopo nulo e com escopo
setado, item sem pinboard e com outro pinboard; `reset` voltando ao Histórico;
e `SearchStateTests` estendido com a ordem de escape de seis degraus, incluindo
o caso de escopo ativo **e** marcas — as marcas vão primeiro.

---

## 4. `PinboardBar`: a faixa, em dois estados

**Arquivo novo:** `MyPasteApp/Views/Pinboards/PinboardBar.swift`.
**Arquivo alterado:** `MyPasteApp/Views/Search/OverlayTopBar.swift`.

Ocupa o `HStack` vazio que a Fase 3 deixou reservado, com o comentário
"Reserved for Phase 5's pinboard pills" — a faixa foi desenhada prevendo isto,
e o layout não precisa ser redesenhado.

Dois estados, como `design-refs/13` e `12`:

| Estado | Aparência |
|---|---|
| Em repouso | `[🕘 Histórico] [● Trabalho] [● Links] [+]` — ícone/ponto mais rótulo |
| Busca ativa | As mesmas pílulas colapsadas para **só o ícone e o ponto**. Nada some; só perde o rótulo |

A pílula selecionada usa fundo mais claro, como na referência. Ordenação por
`createdAt`. Esta tarefa é só apresentação e seleção — criar, renomear e
excluir vêm na 5.

Sem teste automatizado: é `Views/`, e a suíte cobre lógica pura. A verificação
é manual (bloco B do roteiro).

---

## 5. Criar, renomear inline, recolorir, excluir

**Arquivos novos:** `MyPasteApp/Views/Pinboards/PinboardPill.swift`,
`MyPasteApp/Services/PinboardActions.swift`.

`PinboardActions` é para o pinboard o que `ItemActions` é para o item: o
comportamento fora da view.

```swift
@MainActor
struct PinboardActions {
    func create() -> Pinboard          // "Sem Título", PinboardPalette.nextColor
    func rename(_ pinboard: Pinboard, to name: String)
    func recolor(_ pinboard: Pinboard, to hex: String)
    func delete(_ pinboard: Pinboard)  // .nullify cuida dos itens
}
```

**Criar** pelo `+`: nasce "Sem Título" com a próxima cor livre, já selecionado e
em renomeação inline na própria pílula (`design-refs/14`). `↵` confirma; `⎋`
sai da edição e **o pinboard continua existindo** como "Sem Título" — cancelar
uma renomeação não pode apagar o que acabou de ser criado. Nome vazio ou só
espaços volta a "Sem Título", nunca a uma pílula sem rótulo.

**Renomear um board que já existe** é duplo clique no nome, ou a entrada
Renomear do menu de contexto. Um clique **navega** — é a operação frequente, e
a que a pílula existe para oferecer.

*(Decidido em uso real, depois da implementação.)* A primeira versão não tinha
como sair do campo a não ser por `↵` ou `⎋`: clicar em qualquer outro lugar
deixava o campo aberto, e como a pílula segue mostrando um campo de texto onde
deveria estar o nome, **o clique seguinte naquela pílula parecia ter aberto a
edição**. Perder o foco agora confirma, como no Finder — o texto já está
digitado e visível, e descartá-lo num clique perdido jogaria fora trabalho que
o usuário está vendo. Isso também obrigou a pílula a deixar de ser um `Button`:
um `Button` consome o clique antes de qualquer `onTapGesture` contá-lo, e sem
isso não há como distinguir um clique de dois.

**Menu de contexto da pílula** (`design-refs/15`): Renomear · Excluir · a
paleta de 8 cores. Sem "Compartilhar Pinboard" — não existe nada disso no app.

**A entrada de exclusão carrega a consequência no rótulo:**
`Excluir — os 12 itens voltam ao histórico` (e só `Excluir` quando vazio). Não
há confirmação porque não pode haver: um `NSAlert` vira key window e
`windowDidResignKey` fecharia a gaveta inteira. O rótulo é honesto porque é
literalmente o que `.nullify` faz.

**Enquanto o pinboard excluído era o escopo ativo**, o escopo volta ao
Histórico no mesmo turno — senão a faixa fica apontando para um id que não
existe mais.

**Teste** (`PinboardActionsTests`, sobre um `ModelContext` em memória, como
`ItemEditTests` já faz): criar dá nome e cor; renomear para vazio volta a "Sem
Título"; excluir um pinboard com itens **preserva os itens** e zera o
`pinboard` de cada um — este é o teste que protege o cuidado central do item 16.

---

## 6. Escopo aplicado à lista, teclado e estado vazio

**Arquivo alterado:** `MyPasteApp/Views/OverlayView.swift`.

`filtered` passa a filtrar por escopo antes da busca:

```swift
sorted
    .filter { PinboardScope.contains(item: $0, activeID: scope.activeID) }
    .filter { ItemSearch.matches(item: $0, query: ..., filter: ..., now: now) }
```

A ordenação não muda: fixados primeiro, depois `createdAt` decrescente — dentro
do pinboard também, porque um item fixado continua fixado onde quer que esteja.

**Teclado:** `⌃Tab` circula os escopos para a frente, `⌃⇧Tab` para trás,
começando e terminando no Histórico. Escolhidos por não colidirem com a barra
de menus que a cena `Settings` monta — **mas a Fase 4 acabou de descobrir que a
leitura estática dessa barra estava errada**, então isto é passo obrigatório do
roteiro (E1), com `⌥→`/`⌥←` como plano B já decidido. Trocar a tecla é mudança
de uma linha.

**A seleção ao trocar de escopo** segue a regra que já existe
(`selectionAfterListChange`): o primeiro card da lista nova. Um escopo vazio
deixa `selectedID` nulo, e nesse estado `↵`, `⌫` e `⌘1`–`⌘9` não têm alvo e não
fazem nada — o mesmo comportamento de um filtro que não casa com nada hoje.

**Estado vazio:** "Pinboard Vazio", centralizado, sem ilustração
(`design-refs/14`). Distinto do estado vazio de busca sem resultado, que já
existe.

---

## 7. Card: cor por escopo e ponto de filiação

**Arquivo alterado:** `MyPasteApp/Views/ClipboardCardView.swift`.

`ClipboardCardView` ganha um parâmetro `headerColorOverride: Color?`. Dentro do
escopo de um pinboard, `OverlayView` passa a cor do pinboard e **todos** os
cards a usam; no Histórico passa `nil` e cada card mantém
`AppColorExtractor.color(for:)`, como hoje.

A decisão fica na chamada, não no card: quem sabe qual é o escopo ativo é a
`OverlayView`, e um card que fosse buscar essa informação sozinho seria um
segundo lugar para a mesma regra divergir — a lição que `anyMarked` já
registra neste mesmo arquivo.

No Histórico, um card que pertence a um pinboard ganha **um ponto colorido
discreto no cabeçalho**, ao lado do indicador de fixado. É a filiação visível
sem ocupar espaço. Não altera a precedência do rótulo (item 9), que segue
substituindo tipo + hora.

O rodapé não muda: `markOrder` e `quickPasteLabel` continuam disputando a mesma
vaga única, com a mesma regra.

---

## 8. Menu de contexto do card: pinboard e retenção

**Arquivos alterados:** `MyPasteApp/Views/ItemContextMenu.swift`,
`MyPasteApp/Services/ItemActions.swift`.

Duas entradas novas, ambas sem atalho — e o arquivo já documenta por que os
atalhos aqui são texto e não `.keyboardShortcut`:

```
Add to Pinboard  ▸  Trabalho
                    Links
                    ──────────
                    New Pinboard…
```

Vira `Remove from Pinboard` quando o item já pertence a um. `New Pinboard…`
cria, move o item para lá e **não** troca o escopo — o usuário está olhando um
card, não navegando.

```
Keep  ▸  Follow global policy   ✓
         Never expire
         ──────────
         Expire in 1 hour
         Expire in 1 day
         Expire in 1 week
         Expire in 30 days
```

O estado atual marcado com `✓`, para o menu poder ser lido como resposta à
pergunta "o que vai acontecer com este item?". Quando há data marcada, a
entrada mostra a data resolvida (`Expira em 3 de agosto, 15:42`) — uma duração
escolhida ontem não diz nada hoje.

`ItemActions` ganha `setRetention(_:on:)`, escrevendo os dois campos juntos via
`ItemRetention.fields` — é o que impede o estado inconsistente de nascer.

**Teste** (`ItemRetentionTests` estendido): `setRetention` para `.forever`
limpa `expiresAt`; para `.until` limpa `keepForever`; para `.global` limpa os
dois.

---

## 9. `AppRule`: modelo, storage e migração

**Arquivo novo:** `MyPasteApp/Services/AppRules.swift`.
**Arquivo alterado:** `MyPasteApp/Services/PreferenceKeys.swift` (chave nova
`appRules`, mais a entrada em `all` que `PreferenceKeysTests` congela).

```swift
struct AppRule: Codable, Equatable {
    let bundleID: String
    /// Vazio significa ignorar tudo — o comportamento de hoje, e o padrão ao
    /// adicionar um app.
    var allowedTypes: Set<ClipboardItemType>
    var ignoresEverything: Bool { allowedTypes.isEmpty }
}

enum AppRules {
    static func load(from defaults: UserDefaults) -> [AppRule]
    static func save(_ rules: [AppRule], to defaults: UserDefaults)
    /// Decide se um item deste tipo, vindo deste app, deve ser capturado.
    static func allows(type: ClipboardItemType, from bundleID: String?, rules: [AppRule]) -> Bool
    /// Só o primeiro guarda, decidível sem ler o pasteboard.
    static func ignoresEverything(_ bundleID: String?, rules: [AppRule]) -> Bool
    /// Gerenciadores de senha conhecidos, para o botão de Ajustes.
    static let knownPasswordManagers: [String]
}
```

**A leitura é tolerante e nunca falha para "capture tudo".** Sem
`appRules` gravado, `load` lê `ignoredAppsRaw` linha a linha e devolve uma regra
"ignorar tudo" por linha. Com `appRules` presente mas corrompido, faz **a mesma
coisa** — cai para o formato antigo em vez de para uma lista vazia. A chave
`ignoredAppsRaw` fica intocada por uma versão, e é essa preservação que torna
qualquer erro recuperável.

`knownPasswordManagers` lista Passwords, Keychain Access, 1Password, Bitwarden e
Dashlane. É a lacuna herdada da Fase 1, que o ROADMAP diz que deve fechar
exatamente aqui.

**Testes** (`AppRulesTests`): round-trip save/load; migração de
`ignoredAppsRaw` com uma, várias e zero linhas, e com linhas em branco e
espaços; JSON corrompido caindo para o formato antigo, **não** para lista
vazia; `allows` para app sem regra (captura tudo), com regra vazia (ignora
tudo) e com tipos parciais; `ignoresEverything` com `bundleID` nulo — o caso
dos itens criados à mão pelo item 10.

---

## 10. `ClipboardMonitor`: a ordem nova dos guards

**Arquivo alterado:** `MyPasteApp/Services/ClipboardMonitor.swift`.

**O estado atual não é o que esta spec afirmou na primeira redação.** O guard de
app ignorado roda em `poll()` **depois** de `readCurrentItem()`
(`ClipboardMonitor.swift:100-104`): o conteúdo de um app banido já é lido para
dentro de um `ClipboardItem` em memória hoje, e só então descartado. A proteção
existente é contra *persistir*, não contra *ler*.

A regra passa a se partir em duas, em pontos diferentes do fluxo — e a primeira
metade **sobe**, corrigindo isso:

| Onde | Guarda | Por quê |
|---|---|---|
| Em `poll()`, antes de `readCurrentItem()` | `ignoresEverything(bundleID)`, lendo o app frontmost direto de `NSWorkspace` | Melhoria de privacidade real: o conteúdo de um app banido deixa de ser lido. Barata, porque `readCurrentItem` já lê exatamente esse valor na primeira linha |
| Depois de `readCurrentItem()`, antes de persistir | `allows(type:from:)` | Filtrar por tipo exige saber o tipo, o que exige ler. Não há como antecipar isso |

`ignoredAppsRaw` deixa de ser lido diretamente aqui; passa por `AppRules.load`.
`ignoredBundleIDs(from:)` some junto.

**Teste** (`ClipboardMonitorCaptureDecisionTests` estendido): o teste que a Fase
1 escreveu para congelar a ordem dos guards passa a cobrir os dois pontos, com
as duas decisões extraídas como funções puras pelo mesmo motivo que
`shouldCapture` foi extraída. Explicitamente: um app com regra "só texto" que
copia uma imagem não gera item, e um app com regra "ignorar tudo" é rejeitado
por uma decisão que só recebe o bundle ID — nenhum tipo de pasteboard, o que
torna estruturalmente impossível que essa decisão dependa de ter lido o
conteúdo.

---

## 11. Lista de apps em Ajustes

**Arquivo novo:** `MyPasteApp/Views/Preferences/AppRulesListView.swift`.
**Arquivo alterado:** `MyPasteApp/Views/Preferences/PrivacySettingsView.swift`.

O `TextEditor` de bundle IDs sai. Entra uma lista, uma linha por app, com ícone
e nome resolvidos por `NSWorkspace` a partir do bundle ID — e o bundle ID cru
como legenda, porque é o que identifica sem ambiguidade quando dois apps têm o
mesmo nome. App não instalado mostra ícone genérico e só o bundle ID; a regra
continua valendo, e apagá-la é decisão do usuário, não do app.

Por linha: um `Picker` entre **Ignorar tudo** (padrão) e **Capturar apenas**,
que revela quatro toggles de tipo. Manter a exclusão total como o caso simples
é requisito explícito do ROADMAP — ela cobre 90% do uso e não pode ficar mais
difícil por causa dos outros 10%.

`+` abre um `NSOpenPanel` restrito a `.application`, começando em
`/Applications`. É a interface que o macOS usa para isso em toda parte, e
evita varrer o disco lendo `Info.plist` — que seria lento e ainda assim
incompleto para apps fora de `/Applications`. O painel é aberto a partir da
janela de Ajustes, que é uma janela comum: não há o problema de foco da
overlay.

Um botão **"Adicionar gerenciadores de senha"** insere de uma vez as regras de
`knownPasswordManagers`, ignorando os que já estão na lista.

---

## 12. Documentação e verificação manual

`VERIFICACAO-FASE-5.md` na raiz, no formato dos roteiros das fases 3 e 4:
passos numerados com critério binário de passa/falha, e nenhum passo que
dependa de interpretação.

Blocos previstos:

| Bloco | Cobre |
|---|---|
| A | **Migração do store**: abrir com o banco da versão anterior, histórico intacto, fixados ainda fixados. Sem isso, nada mais importa |
| B | Faixa de pílulas: criar, renomear, cancelar renomeação, recolorir, excluir com e sem itens, colapso na busca |
| C | Escopo: trocar por clique e por `⌃Tab`, buscar dentro do pinboard, `⎋` percorrendo os seis degraus, reabrir voltando ao Histórico |
| D | Retenção: marcar "nunca", marcar "expira em 1 hora", verificar sobrevivência e morte com o relógio adiantado (inclusive sem reiniciar o app, pelo timer de 5 minutos); e "Clear history" em Ajustes deixando de pé fixados, itens em pinboard, itens "nunca" e itens com data ainda no futuro |
| E | Teclado: **E1 — `⌃Tab` não é engolido pelo sistema nem pela barra de menus.** Mesmo peso do E1 da Fase 4, e pela mesma razão |
| F | Regras por app: adicionar pelo seletor, "só texto", copiar imagem do app regulado e não ver item; e as exclusões antigas ainda valendo depois da migração |

`ROADMAP.md` recebe o bloco da fase; `CHANGELOG.md` segue o release-please.

---

## Riscos

| Risco | Mitigação |
|---|---|
| **Três itens numa branch só.** Quatro fases seguidas tiveram defeitos Important que só a revisão de branch inteira achou, e a Fase 4 tinha **um** item | Decisão consciente do Carlos, com a alternativa apresentada. Mitigação: revisão por tarefa como sempre, mais revisão de branch inteira obrigatória antes do PR — e as 12 tarefas são pequenas e ordenadas para que a mais arriscada (schema) seja a primeira |
| **A primeira migração de schema real do app.** Migração leve automática é o caminho previsto, mas nunca foi exercitada aqui | Só adições opcionais, que é o caso coberto. Bloco A do roteiro, primeiro de todos. Se falhar, o `MigrationPlan` explícito entra como tarefa 1b antes de qualquer outra coisa |
| **`#Predicate` sobre relação e sobre `Date?`** pode não compilar ou filtrar errado | Evitado por construção: as três passadas filtram em memória com `isProtected`, uma regra só. Motivo comentado no código |
| **`⌃Tab` engolido**, como quase aconteceu com `⌘M` | Passo E1 do roteiro. Plano B (`⌥→`/`⌥←`) já escolhido; trocar é uma linha |
| **A poda ganhou um caminho novo que apaga itens** (passada 1, expirados) e apagar do histórico não tem desfazer | A passada só toca itens com `expiresAt` explicitamente gravado por ação do usuário. Coberta por testes que verificam os três casos em que ela **deve** vencer proteções, e pelos testes existentes, que verificam que ela não toca em mais nada |
| **`⌘M` da Fase 4 segue sem verificação** | Herdado, não introduzido. Registrado aqui para não se perder; entra no roteiro da Fase 5 como passo herdado |
