# Fase 6.5 — O preview vira janela

Design aprovado em 2026-08-04. Cobre o **item 26** do `ROADMAP.md` — os dois
pedidos que sobraram do lote de melhorias do painel de preview, feitos a partir
de capturas do Paste: o **bico ancorado ao card** e **soltar ao arrastar**. O
terceiro pedido do mesmo lote, o zoom, entrou na Fase 6 por ser contido e não
tocar em janela.

O bico é a pendência mais antiga do projeto: prevista na antecipação do item 19,
registrada em `DESIGN.md` (mudança derivada 13) como parcial desde a Fase 2, e
nunca feita.

Ambiente de referência: deployment target macOS 26.2, Swift 5. O projeto usa
`PBXFileSystemSynchronizedRootGroup`, então arquivos novos entram no alvo pelo
simples fato de existirem no diretório — não há `project.pbxproj` para editar.

Branch: `feature/fase-6-5-preview-janela`, criada a partir de `develop`.

## O bloqueio que saiu do caminho

O `ROADMAP.md` condicionava esta fase ao passo **A1** da verificação manual da
Fase 6 — ligar o Live Text no preview de uma imagem não pode fechar a gaveta por
baixo. O motivo do bloqueio: os dois trabalhos mexem no mesmo equilíbrio de
foco, e investigá-los juntos daria duas causas possíveis para um mesmo sintoma.

**O Carlos rodou o A1 em 2026-08-04 e ele passou.** O equilíbrio atual está
sadio: `ItemPreviewPanel` nasce com `becomesKeyOnlyIfNeeded = true`, nada dentro
dele pede status de key window, e a gaveta — que fecha em `windowDidResignKey` —
sobrevive ao Live Text ligado. Esta fase parte de uma base conhecida, e é essa
base que a seção "Riscos" trata como o ativo a não quebrar.

Seguem sem resposta o **C1** (o card redesenha a imagem girada sem reiniciar) e
o passo de amostrar cor com a imagem ampliada. Nenhum dos dois toca em janela;
`VERIFICACAO-FASE-6.md` segue válido para eles, sobre `develop`.

## O que a fase entrega

| Entrega | Descrição |
|---|---|
| Bico ancorado | O painel de preview desenha um triângulo na base apontando para o card que está mostrando. Quando o painel é grampeado na borda da tela, o bico desliza pela base até continuar sobre o card; some quando o card sai do alcance |
| Soltar ao arrastar | Arrastar o painel o desprende da gaveta: a gaveta fecha, o painel fica na tela como janela independente, congelado no item que mostrava |
| Painéis soltos múltiplos | Cada arrasto produz uma janela nova. Podem existir vários ao mesmo tempo, cada um com seu item, para comparar lado a lado |
| Teclado no painel solto | Solto, o painel aceita foco: `⌘C` copia a seleção, `⌘W` e `Esc` fecham. O painel ancorado continua sem foco nenhum |
| `PreviewPlacement` testado | O cálculo de posição do painel — que existe desde a Fase 2 e nunca teve teste — sai do controller como função pura, junto com a geometria do bico |
| `PreviewPanelController` | A gestão do preview sai de `OverlayWindowController` para um tipo próprio, que agora tem dois modos e N janelas para cuidar |

## Escopo e o que fica de fora

- **Redimensionar o painel solto.** O painel tem 520×380 fixos desde a Fase 2
  (`ItemPreviewView` carrega o `.frame` e `ItemPreviewPanel.defaultSize` o
  espelha). Redimensionar é um pedido legítimo e independente — entra quando
  for pedido, não de carona
- **Painel solto lembrar posição entre sessões.** Nasce onde foi solto, morre
  quando fechado. Persistir posição exige decidir o que acontece quando a tela
  que o continha some
- **Bico apontando de lado ou de baixo.** O painel sempre fica acima do card,
  como já fica hoje. Quando não cabe acima, ele é grampeado e o bico some — não
  vira um painel abaixo do card com bico invertido
- **`QLPreviewPanel`.** Continua sendo o complemento acessório que o item 19
  descreve, sem dono e sem data
- **Teto para o número de painéis soltos.** Ver "Memória" em Riscos: em vez de
  um número inventado, o roteiro de verificação manual mede
- **O bug do `⌘1`** (crash com perda de histórico): segue sem diagnóstico. Esta
  fase não o resolve nem o agrava

## Decisões tomadas

| Decisão | Escolha | Por quê |
|---|---|---|
| Escopo da fase | **Bico e soltar juntos**, bico primeiro | Os dois passam por reescrever a mesma janela. Separar faria a reescrita acontecer duas vezes; juntar dá uma fase de ~6 tarefas com a verificação manual no meio |
| Forma irregular | **Manter `.titled` e tornar a janela transparente** | Preserva `becomesKeyOnlyIfNeeded` como mecanismo de foco — exatamente o que o A1 acabou de validar. O modo solto sai de graça: basta virar a propriedade para `false` naquele painel, sem subclasse. A alternativa (`.borderless` + subclasse com `canBecomeKey` por estado) reintroduz por outro caminho a classe de risco que o A1 mediu |
| Como saber se `.titled` corta o bico | **Tarefa 1 é um spike verificado à mão** | O AppKit aplica máscara de cantos arredondados em janelas `.titled` e não há como saber sem rodar se ela corta o triângulo. Mesmo formato da Tarefa 19 da Fase 2: responder a pergunta de viabilidade antes de construir em cima |
| Reabrir a gaveta com um painel solto na tela | **Abre um segundo painel, ancorado** | O solto fica onde está, congelado no item dele. É o que justifica o recurso existir: soltar vários e comparar. Reabsorver o solto faria "soltar" significar apenas "mover de lugar temporariamente" |
| Nível do painel solto | **Continua `.floating`, por cima de tudo** | O app é `LSUIElement`: sem ícone no Dock, uma janela que vai para o fundo não tem como ser trazida de volta — a gaveta não sabe nada sobre painéis soltos. Flutuar é também o que faz soltar valer a pena, consultar algo enquanto se digita noutro app |
| Teclado no painel solto | **Sim, vira janela de verdade** | `⌘C` na seleção, `⌘W` e `Esc` para fechar. Só o solto ganha isso; o ancorado segue sem foco. No instante do detach a gaveta já fechou, então não há o que proteger |
| O que exatamente muda na janela ao soltar | Além de `becomesKeyOnlyIfNeeded`, o `styleMask` perde **`.nonactivatingPanel`** e o `collectionBehavior` perde **`.transient`** | Levantado ao escrever o plano, não neste design. `.nonactivatingPanel` impede o clique de ativar o app — e como o app é `LSUIElement`, um painel que nunca ativa pode virar key window e ainda assim não receber tecla nenhuma, porque o teclado vai para o app ativo. `.transient` faz sentido para um painel que morre com a gaveta e nenhum para um que sobrevive a ela |
| De onde se arrasta | **Header ou fundo vazio**, resolvido pelo hit-testing do AppKit | `isMovableByWindowBackground = true` arrasta onde o conteúdo não consome o clique, em vez de uma lista de regiões escrita à mão que teria de ser mantida em paralelo com o layout de cada tipo de item. Ver o cuidado em Riscos: no preview de imagem isso pode reduzir a área de pega ao header |
| Limiar do arrasto | **~10pt de deslocamento** do frame calculado por `PreviewPlacement` | Curto o bastante para o gesto responder, longo o bastante para um tremor não soltar o painel |
| Bico na borda da tela | **Desliza pela base até o card**, respeitando recuo dos cantos; some quando o card sai do alcance | O painel para na margem e o centro dele deixa de coincidir com o card. Um bico fixo no centro apontaria para o card errado — pior que não ter bico |
| Onde vive o cálculo | **`Services/PreviewPlacement.swift`, função pura com teste** | O padrão que `ColorCode` e a luminância da Fase 6 já seguem. Ganho colateral: o grampeamento nas bordas existe desde a Fase 2 e nunca teve teste |
| Onde vive a gestão | **`Window/PreviewPanelController.swift`** | `OverlayWindowController` tem 653 linhas, ~150 delas de preview, e essa parte passa a ter dois modos, N janelas e ciclo de vida próprio |
| Item apagado com painel solto aberto | **O painel fecha sozinho** | Um painel mostrando um item que não existe mais é uma janela que mente. Há seis caminhos de exclusão hoje (`ItemActions`, `HistorySettingsView`, três em `RetentionPolicy`) — a regra é do painel, não de cada caminho |
| Limite de painéis soltos | **Nenhum, por ora** | Um número inventado agora seria arbitrário. O roteiro de verificação manual pede cinco previews de texto longo soltos e a memória medida; se explodir, o teto entra com número vindo de medição — ver Riscos |

## Arquitetura

### `Services/PreviewPlacement.swift` — lógica pura

```swift
enum PreviewPlacement {
    struct Result {
        let frame: CGRect
        /// Posição horizontal da ponta do bico em coordenadas do painel,
        /// ou nil quando o card está fora do alcance.
        let beakOffset: CGFloat?
    }

    static func solve(anchor: CGRect,          // card, coordenadas de tela
                      panelSize: CGSize,
                      visibleFrame: CGRect,
                      cornerRadius: CGFloat,
                      beakWidth: CGFloat) -> Result
}
```

Absorve integralmente o que `OverlayWindowController.positionPreviewPanel` faz
hoje: centralizar sobre o card, grampear nas bordas com `edgeInset`, empurrar
para baixo quando não cabe acima. Acrescenta o `beakOffset`.

`beakOffset` é `nil` quando a ponta não caberia entre os cantos arredondados —
isto é, quando o centro do card, convertido para coordenadas do painel, sai do
intervalo `[cornerRadius + beakWidth/2, largura - cornerRadius - beakWidth/2]`.

O controller continua responsável pela conversão de coordenadas (`convert(_:to:)`
seguido de `convertToScreen`) e pelo caso sem âncora, que centraliza na tela.
Converter coordenadas depende de `NSView` e `NSWindow` vivos; resolver geometria
não depende de nada. Só o segundo vira função pura.

### `Window/PreviewPanelController.swift` — a gestão

```swift
@MainActor
final class PreviewPanelController {
    func updateSelection(item: ClipboardItem?, anchor: CGRect?)
    func showAnchored()
    func hideAnchored()
    var isAnchoredOpen: Bool { get }
    func detachAnchored()
    func owns(_ window: NSWindow?) -> Bool
    func refreshPrivacy()
}
```

`OverlayWindowController` passa a delegar: `showPreviewPanel`,
`hidePreviewPanel`, `updatePreviewSelection`, `applyPreviewContent` e
`positionPreviewPanel` saem dele, junto com `previewPanel`, `previewItem`,
`previewAnchorFrame` e `previewDisplayedItemID`.

O monitor de clique externo muda de forma: hoje `installClickOutsideMonitors`
compara `event.window !== self.previewPanel` (linha 414). Passa a perguntar
`previewController.owns(event.window)`, que responde pelo ancorado **e** por
todos os soltos — um clique num painel solto não pode ser lido como clique fora
da gaveta.

`hide()` e `hideImmediately()` continuam chamando `hideAnchored()`, e continuam
sem tocar nos soltos.

### Os dois modos

| | Ancorado | Solto |
|---|---|---|
| Quantos | 0 ou 1 | ilimitado (ver Riscos) |
| `becomesKeyOnlyIfNeeded` | `true` | `false` |
| Bico | visível, quando `beakOffset != nil` | escondido |
| Segue a seleção | sim | não, congela no item |
| Exceção no monitor de clique | sim | sim |
| Morre com a gaveta | sim | não |
| Fecha com | `Esc`, `X`, gaveta fechando | `X`, `⌘W`, `Esc` |

`ItemPreviewPanel.make()` ganha `isOpaque = false`, `backgroundColor = .clear`,
`hasShadow = false` e `isMovableByWindowBackground = true`. `styleMask` fica como
está.

O conteúdo continua com os 520×380 de hoje; a **janela** é que passa a ter
`380 + beakHeight` (~14pt) de altura, e o triângulo ocupa essa faixa extra. Isso
vale para `ItemPreviewPanel.defaultSize`, para o `.frame` fixo dentro de
`ItemPreviewView` e para o `NSView` vazio que `hideAnchored` deixa no lugar do
`contentView`. Ao soltar, a faixa do bico deixa de ser desenhada **e** a janela
encolhe de volta para 380 — sem isso, o painel solto carregaria 14pt de área
transparente na base, com a sombra desencontrada da forma.

A forma inteira passa a ser desenhada pelo conteúdo: um `Shape` no SwiftUI
(retângulo arredondado + triângulo na base, deslocado por `beakOffset`), com a
sombra desenhada por ele — a janela perdeu a do sistema.

### O detach

O controller observa `NSWindow.didMoveNotification` do painel ancorado. Passados
~10pt do frame que `PreviewPlacement` calculou, chama `detachAnchored()`.

**A ordem dentro do detach é a parte fácil de errar:**

1. O painel sai do campo do ancorado e entra na lista de soltos
2. `becomesKeyOnlyIfNeeded = false`, bico escondido, `didMove` desobservado
3. **Só então** a gaveta fecha

Invertido, `hide()` → `hideAnchored()` mataria o painel que o usuário acabou de
soltar.

### Ciclo de vida do painel solto

- Fecha pelo `X` do header, por `⌘W` e por `Esc`
- Fechar **limpa o `contentView`**, como `hidePreviewPanel` já faz hoje. Não é
  arrumação: a Fase 2.5 mediu 240 MB de CoreAnimation num preview de texto longo
  que não voltava até o app sair, e esse custo agora se multiplica por painel
- Se o item deixar de existir, o painel fecha sozinho. O mecanismo é um só: o
  controller observa o `didSave` do `ModelContext` e, a cada notificação, fecha
  os painéis soltos cujo item já não pertence a um contexto
  (`item.modelContext == nil`). O que **não** serve é espalhar a
  responsabilidade pelos seis caminhos de exclusão — a regra é do painel
- `refreshPrivacy()` percorre os soltos também. Hoje a linha 171 de
  `OverlayWindowController` atualiza `previewPanel?.sharingType` no singular, e
  um painel solto fora dessa varredura vazaria numa gravação de tela

## Testes

A suíte cobre lógica pura — nada em `Views/` ou `Window/` tem teste automatizado
neste projeto, e esta fase não muda isso.

`PreviewPlacementTests`:

- card no centro da tela: painel centralizado sobre ele, bico no meio
- card na ponta esquerda: painel grampeado em `visibleFrame.minX + edgeInset`,
  bico deslocado para a esquerda, ainda sobre o card
- card na ponta direita: simétrico
- card tão na ponta que o bico não caberia entre os cantos: `beakOffset == nil`
- painel não cabe acima do card: grampeado no topo, comportamento de hoje
  preservado
- tela menor que o painel: frame dentro de `visibleFrame`, sem coordenada
  negativa
- `beakOffset`, quando não-nil, sempre dentro de
  `[cornerRadius + beakWidth/2, largura - cornerRadius - beakWidth/2]`

Comando completo em `CLAUDE.md`. Uma suíte só:
`-only-testing:MyPasteAppTests/PreviewPlacementTests`.

## Riscos

**O equilíbrio de foco é o ativo desta fase, e ela mexe nele de propósito.** O
A1 acabou de validar que a gaveta sobrevive ao painel. A abordagem escolhida
(`.titled` transparente) foi escolhida justamente para preservar o mecanismo,
mas o modo solto introduz, pela primeira vez, um painel nosso que **pode** virar
key window. A mitigação é que ele só ganha essa capacidade depois de a gaveta já
ter fechado. O que precisa ser verificado à mão: reabrir a gaveta com um painel
solto na tela, e clicar entre os dois.

**A máscara de cantos do `.titled` pode cortar o bico.** É o risco que a Tarefa 1
existe para medir. Se cortar, a fase migra para `.borderless` + subclasse
`PreviewPanel` com `canBecomeKey` decidido por estado, ao custo de uma tarefa; o
bico e o soltar são construídos sobre a mesma forma SwiftUI nos dois caminhos, e
nada do resto do plano muda.

**A área de arrasto fica pequena demais sem uma faixa explícita — confirmado na
leitura do código.** Com `isMovableByWindowBackground`, arrasta-se onde o
conteúdo não consome o clique. O preview de imagem tem `.contentShape(Rectangle())`
e dois `.simultaneousGesture` (zoom e pan da Fase 6) no container inteiro, e o de
texto hospeda uma `NSTextView` selecionável: os dois consomem o clique, e sobram
o header e as faixas de 12pt de padding. A faixa de arrasto explícita entra
**dentro** da tarefa do detach, não como remendo posterior.

**O teclado do painel solto pode funcionar e depois parar.** Se o `styleMask`
mantiver `.nonactivatingPanel`, o comportamento provável é `⌘C`/`⌘W`/`Esc`
funcionarem logo após o detach, enquanto o app ainda está ativo, e pararem
assim que o usuário clica noutro app e volta. É um bug intermitente, e a
verificação manual testa o retorno explicitamente em vez de parar no primeiro
sucesso.

**Memória com vários painéis soltos.** Cada painel guarda uma
`NSHostingView` viva. O roteiro de verificação manual pede cinco previews de
texto longo soltos ao mesmo tempo, com a memória observada; um teto entra depois,
com número medido, se for preciso.

**O painel solto some do alcance do usuário.** Sem Dock e sem menu de janelas, um
painel solto que fique atrás de algo, ou numa Space que o usuário não visita, não
tem como ser reencontrado. `.canJoinAllSpaces` e `.floating` cobrem a maior parte
disso; o resto é verificação manual.

**Extrair `PreviewPanelController` é refatoração no meio de mudança de
comportamento.** Fica numa tarefa própria, sem mudança de comportamento junto, e
antes das tarefas que dependem dela.

## Verificação manual

`VERIFICACAO-FASE-6-5.md`, escrito junto com a implementação, no formato dos
anteriores. Blocos previstos: o bico (posição, bordas de tela, cards das pontas,
troca de seleção), o detach (gesto por tipo de item, limiar, gaveta fechando na
ordem certa), a convivência (reabrir a gaveta com solto na tela, clicar entre os
dois, `Esc` em cada um), o ciclo de vida (fechar por três caminhos, apagar o item
com painel solto aberto, memória com cinco soltos) e a privacidade (`sharingType`
num painel solto durante gravação de tela).

Nenhuma fase fecha sem o Carlos exercitar a GUI à mão — a suíte verde é condição
necessária, nunca suficiente. Nesta fase mais do que nas outras: quase tudo o que
ela entrega vive em `Views/` e `Window/`, fora do alcance da suíte.

## Tarefas previstas

1. **Spike da janela transparente.** `.titled` com fundo claro, sem sombra do
   sistema, forma desenhada em SwiftUI com o triângulo na base. Verificado à mão:
   o bico aparece inteiro?
2. **`PreviewPlacement`**, com a bateria de testes acima, substituindo
   `positionPreviewPanel`
3. **Bico ligado ao painel real**, seguindo a seleção e as bordas de tela
4. **Extração do `PreviewPanelController`**, sem mudança de comportamento
5. **Detach e os dois modos**: gesto, limiar, ordem do detach, teclado no solto
6. **Ciclo de vida dos soltos**: fechar por três caminhos, item apagado,
   `refreshPrivacy`, limpeza do `contentView`

## Documentos a atualizar ao fim da fase

- `DESIGN.md`, mudança derivada 13: de ⚠️ parcial para ✅, com o que o bico
  virou de fato
- `ROADMAP.md`: bloco da Fase 6.5 e item 26, com o registro de que o A1 passou
- `CHANGELOG.md`, pelo fluxo de commits de sempre
- Board do Obsidian, a cada tarefa concluída — regra do `CLAUDE.md`
