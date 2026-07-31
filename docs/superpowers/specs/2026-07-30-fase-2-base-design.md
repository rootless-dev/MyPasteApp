# Fase 2 — Base (itens 6 a 10, mais o 19 antecipado)

Design aprovado em 2026-07-30. Cobre os itens 6, 7, 8, 9, 10 e 19 do
`ROADMAP.md`, mais duas pendências herdadas da Fase 1 e um item não numerado
que a fase força (o menu de contexto do card).

Ambiente de referência: Xcode 26.6, SDK macOS 26.5, deployment target 26.2,
Swift 5. O projeto usa `PBXFileSystemSynchronizedRootGroup`, então arquivos
novos entram no alvo pelo simples fato de existirem no diretório — não há
`project.pbxproj` para editar.

Branch: `feature/fase-2-base`, criada a partir de `develop`.

## O que o levantamento mudou em relação ao roadmap

Cinco correções, todas apuradas contra o código ou contra as capturas em
`design-refs/`.

**O item 7 não é uma escolha entre rico e plano — são três camadas.** O
`ROADMAP.md` fala em "preferência para qual dos dois é o padrão", o que sugere
uma decisão binária. A captura `06-config-geral.png` mostra o que o Paste faz:
cola como foi copiado por padrão, oferece "Colar como Texto Sem Formatação"
(`⇧↵`) no menu de contexto para o caso pontual, e tem um toggle
**"Sempre Colar como Texto Sem Formatação"** desligado por padrão, dentro do
bloco "Colar Itens". As três coexistem.

**A seção Backup não entra.** O roadmap lista seis seções para a sidebar,
incluindo Backup — que é o item 24, da Fase 7. Não existe hoje uma única
preferência para pôr nela, e uma entrada morta na sidebar é pior que a ausência
dela. Cinco seções: Geral, Histórico, Aparência, Atalhos, Privacidade.

**O item 8 pode preservar formatação, ao contrário do que o roadmap sugeriu.**
Lá está escrito que editar texto rico exige "decidir entre editor rico ou
degradar para texto plano ao salvar. Sugestão: degradar — editor rico é um
projeto à parte". Essa premissa vale para o `TextEditor` do SwiftUI, mas não
para o caminho que esta fase toma: o editor abre em janela própria, e o
controle natural ali é um `NSTextView`, que edita texto rico por padrão e traz
`⌘B`/`⌘I` e o menu Formatar do sistema sem código nosso. Degradar seria apagar
formatação na mesma fase cujo item 7 existe para parar de destruí-la.

**O gatilho do item 19 conflita com a busca de um jeito que o roadmap não
previu.** Lá se lê que `Espaço` "precisa ser ignorada enquanto a `SearchBar`
tem foco". Mas `OverlayView.swift:81` faz `searchFocused = true` no `onAppear`:
o foco está **sempre** na busca, e pela regra como escrita o atalho nunca
dispararia. No Paste o conflito não existe porque a busca lá é uma lupa que só
vira campo ao ser acionada (`03-preview-web.png` mostra a gaveta sem campo
algum aberto). Não vamos mudar a busca nesta fase — ver a decisão registrada
abaixo.

**O painel do item 19 não é efêmero.** As capturas `03-preview-web.png` e
`04-preview-imagem.png` mostram barra de título própria, com `×` circular à
esquerda para fechar, e a gaveta viva embaixo. O roadmap sugere `.popover()`
pelo bico que vem de graça; o bico continua valendo como alvo visual, mas o
comportamento a atingir é o de um painel que o usuário fecha, não o de um
popover que some ao perder foco.

## Decisões tomadas

| Decisão | Escolha | Por quê |
|---|---|---|
| Granularidade da entrega | **Uma spec, um plano, uma branch, um PR** para a fase inteira | Mantém a regra de uma branch por fase ao pé da letra |
| Pendências da Fase 1 | Entram as duas de hotkey; **não** entra a lista embutida de apps de senha | A lista espera o seletor de apps do item 18, que resolve o mesmo problema com interface própria |
| Padrão de colagem | Rico por padrão; `⇧` cola plano; preferência global força plano | É o que `⌘C`/`⌘V` do sistema faz, e o que a captura `06-config-geral.png` mostra |
| `⇧` com a preferência global ligada | **Não inverte** — continua significando "plano" | Rótulo do menu fica fixo e o modificador tem um só sentido. Quem quer o rico de volta desliga a preferência |
| Seções da sidebar | Cinco: Geral, Histórico, Aparência, Atalhos, Privacidade | Backup não tem conteúdo até a Fase 7; separar Histórico de Geral porque temos quatro controles de histórico contra um do Paste |
| Ações novas sobre o item | **Menu de contexto no card** | Quatro ações novas não cabem como botões de hover, e o menu é onde o usuário descobre os atalhos |
| Onde o editor abre | **Janela própria**, a overlay fecha | Não briga com `.transient` nem com os monitores de clique externo, e é a mesma janela que o `⌘N` do item 10 abre vazia |
| Editor preserva formatação? | **Sim**, `NSTextView` com `isRichText` | Ver a correção acima |
| Gatilho do preview | `Espaço` **só com a busca vazia** | Um espaço inicial numa busca não tem uso; "foo bar" continua funcionando porque aí o campo não está vazio |
| Busca vira lupa-que-expande? | **Não nesta fase** | É mudança de layout da overlay que nenhum item do roadmap pede, dentro de uma fase que já tem oito entregas. Fica registrada como item 11 da lista derivada do `DESIGN.md` |
| Item criado por `⌘N` | Nasce **fixado** | É a única proteção contra a poda que existe hoje, e vale nas duas passadas de `prune()`. O item 16 desembaraça o duplo sentido de `isPinned` quando pinboards existirem |
| Editar promove ao topo? | **Sim** | Coerente com o que colar já faz. `createdAt` já não é cronológico — ver a nota de topo do `ROADMAP.md` |

## Ordem de execução

| # | Entrega | Por que nesta posição |
|---|---|---|
| 0a | `PreferenceKeys` | Todo o resto grava preferências; fazer depois é reescrever o que veio antes |
| 0b | Falha de registro de hotkey propagada (2 pendências da Fase 1) | Pequenas, e a seção Atalhos do item 6 já encosta nelas |
| 6 | Settings reconstruída | Cada item seguinte acrescenta preferência |
| 7 | Texto rico e colar como texto simples | Muda schema; quanto mais cedo, menos código escrito sobre o modelo antigo |
| 0c | Menu de contexto no card | Chassi das ações; nasce já com "Colar como texto sem formatação" do item 7 |
| 8 | Editor em janela própria | Pendura `⌘E` no menu que acabou de existir |
| 9 | Rótulos | Reusa o editor do 8 para `⌘R` |
| 10 | Criar item do zero | Mesma janela, aberta vazia |
| 19 | Painel de preview ancorado | Independente dos demais e o de maior risco técnico |

**Limite do item 19.** A primeira tarefa desse bloco é confirmar que um painel
ancorado sobrevive à overlay `.transient` e aos monitores de clique externo de
`installClickOutsideMonitors()`. Se não se sustentar em duas tentativas, o item
sai da fase e volta ao roadmap com o resultado registrado. As outras sete
entregas não dependem dele.

**Fora de escopo, com o lugar marcado:** lista embutida de apps de senha
(item 18), seção Backup (item 24), `⌘O Abrir` no menu de contexto (item 21),
busca como lupa que expande (`DESIGN.md`, mudança derivada 11).

---

## 0a. `PreferenceKeys` — centralizar as chaves

**Arquivo novo:** `Services/PreferenceKeys.swift`.

Um `enum` sem casos, só com constantes estáticas, uma por chave existente:
`maxItems`, `retentionDays`, `previewTextLength`, `enableSoundFeedback`,
`ignoredAppsRaw`, `autoPasteEnabled`, `pasteDelayMs`, `showLinkPreviews`,
`cardDensity`, `showQuickPasteNumbers`, `showInScreenSharing`,
`ignoreConcealedContent`, `ignoreTransientContent`,
`ignoreAutoGeneratedContent`, mais a nova `alwaysPastePlainText`.

**Consumidores a migrar:** `PreferencesView` (e as views que a substituem),
`ClipboardMonitor` (linhas 225–251), `RetentionPolicy` (linhas 15 e 20),
`OverlayView` (linha 17), `ClipboardCardView` (linha 15),
`OverlayWindowController` (linhas 78 e 80), `WindowPrivacy`.

**Invariante:** os **valores** das strings não mudam, apenas deixam de ser
literais duplicados. Renomear um valor apaga a configuração de qualquer
instalação existente, em silêncio e sem erro. Coberto por teste (ver seção de
testes).

`KeyCombo.storageKey` e `KeyCombo.pauseStorageKey` já são constantes nomeadas
dentro do próprio tipo e ficam onde estão — movê-las não ganharia nada.

---

## 0b. Falha de registro de hotkey

**Arquivos:** `Services/HotkeyManager.swift`, `AppDelegate.swift`.

Duas pendências da Fase 1, da mesma classe: o app anuncia um atalho que pode
não estar registrado.

`register()` chama `RegisterEventHotKey` e apenas loga o `OSStatus`. Passa a
devolver o sucesso ao chamador. `AppDelegate` deixa de marcar
`pauseHotkeyRegistered = true` sem checagem e passa a refletir o resultado
real.

O item "Show history" do menu interpola `KeyCombo.stored.displayString`
(`AppDelegate.swift:195`) sem checar se aquela combinação chegou a ser
registrada. Com o estado real disponível, o menu passa a omitir o atalho
quando ele não está valendo — o mesmo tratamento que os itens de pausa já
recebem através de `comboSuffix`.

**Pronto quando:** com outro app dono da combinação, o menu não anuncia o
atalho morto.

---

## 6. Janela de Settings reconstruída

**Arquivos novos, em `Views/Preferences/`:** `SettingsView.swift`,
`GeneralSettingsView.swift`, `HistorySettingsView.swift`,
`AppearanceSettingsView.swift`, `ShortcutsSettingsView.swift`,
`PrivacySettingsView.swift`, `RetentionSlider.swift`,
`SettingsToggle.swift`.

**Arquivo removido:** `Views/PreferencesView.swift`.

`SettingsView` é um `NavigationSplitView` com a sidebar de cinco entradas
(ícone + rótulo) e a área de conteúdo à direita, seguindo `06-config-geral.png`
e a seção 7 do `DESIGN.md`. A janela dimensiona por conteúdo em vez do
`frame(minWidth: 460, minHeight: 640)` fixo de hoje.

### Distribuição das preferências

| Seção | Controles |
|---|---|
| **Geral** | Abrir no login · Efeitos sonoros · bloco "Colar itens": radio *Para o app ativo* / *Para a área de transferência* (`autoPasteEnabled`), atraso da colagem, e o toggle **Sempre colar como texto sem formatação** |
| **Histórico** | Slider de retenção com paradas nomeadas · Máximo de itens · Tamanho do preview · Apagar histórico não fixado |
| **Aparência** | Densidade do card · Previews de link · Números do quick paste |
| **Atalhos** | Overlay · Pausar/retomar, com a lógica de conflito de hoje |
| **Privacidade** | Mostrar durante compartilhamento de tela · os três marcadores do nspasteboard.org · lista de apps ignorados |

O radio de "Colar itens" substitui o `Toggle("Auto-paste on selection")` atual,
que obriga o usuário a deduzir o que acontece quando desligado. A chave
`autoPasteEnabled` e sua semântica continuam idênticas — muda só a
apresentação.

Todo toggle não óbvio ganha uma linha de descrição abaixo, conforme a seção 7
do `DESIGN.md`.

### O slider de retenção e a armadilha do zero

Paradas: **Dia (1) · Semana (7) · Mês (30) · Ano (365) · Para Sempre (0)**.

`RetentionPolicy.retentionDays` (linha 20) faz hoje:

```swift
let v = defaults.integer(forKey: "retentionDays")
return v > 0 ? v : 30
```

`integer(forKey:)` devolve `0` tanto para chave ausente quanto para zero
gravado. Se "Para Sempre" for gravado como `0` — a escolha natural —, o leitor
o interpreta como ausente, volta a 30 dias e `prune()` **apaga exatamente o
histórico que o usuário mandou guardar para sempre**. Falha silenciosa, sem
erro, e só perceptível quando o dado já se foi.

Correção: ler com `defaults.object(forKey:) as? Int`, onde `nil` é ausente
(padrão 30) e `0` é Para Sempre. É o mesmo padrão que
`ClipboardMonitor.showLinkPreviews` (linha 231) já usa para booleanos.

`prune()` passa a pular a **primeira** passada quando o valor é Para Sempre. A
segunda passada, que corta por `maxItems`, **continua valendo** — sem ela o
banco cresce sem teto. A tela diz isso explicitamente, abaixo do slider: Para
Sempre desliga o corte por idade, não o limite de quantidade.

Um valor fora das paradas (uma instalação com 45 dias) é exibido na parada mais
próxima e só é regravado quando o usuário arrasta o slider. Nada muda de
configuração sozinho.

**Pronto quando:** todas as preferências anteriores continuam funcionando após
a reconstrução, verificadas uma a uma com dados pré-existentes.

---

## 7. Texto rico e colar como texto simples

**Arquivo novo:** `Services/RichText.swift`.
**Arquivos alterados:** `Models/ClipboardItem.swift`,
`Services/ClipboardMonitor.swift`, `Services/ClipboardWriter.swift`,
`Views/OverlayView.swift`.

### Modelo

```swift
@Attribute(.externalStorage) var richTextData: Data?
var richTextTypeRaw: String?   // "rtf" | "html"
```

Campos opcionais permitem migração leve do SwiftData, sem versionamento manual
de schema. `.externalStorage` mantém o RTF de documentos longos fora do banco,
como já é feito com `imageData`.

### Captura

`readCurrentItem()` (linha 139) hoje lê apenas `pasteboard.string(forType:
.string)`. Passa a procurar também `.rtf` e `.html`, guardando o primeiro
encontrado nessa ordem de prioridade, junto do tipo correspondente.

RTF antes de HTML porque é o formato canônico do macOS: `NSAttributedString`
converte nos dois sentidos sem WebKit, enquanto o HTML que um browser coloca no
pasteboard costuma carregar markup de layout e referências de CSS externo, que
recolado dá resultado imprevisível.

**`contentHash` e `preview` continuam derivados do texto plano.** É a
invariante central deste item. Derivar o hash do RTF quebraria a deduplicação —
o mesmo texto copiado de dois apps gera bytes de formatação diferentes e viraria
um item novo a cada cópia. E o `preview` com marcação seria ilegível no card.

O corpo do card permanece como está; a decisão de renderizar formatação no
preview do card não faz parte desta fase.

### Escrita

`ClipboardWriter.write()` ganha um parâmetro `plainText: Bool = false`, e o
chamador o resolve como `alwaysPastePlainText || shiftPressed`. O `case .text,
.url` (linha 28), hoje um `pb.setString(text, forType: .string)`, passa a
resolver entre três caminhos:

| Situação | O que vai ao pasteboard |
|---|---|
| Padrão e o item tem rico | tipo rico primeiro, `.string` em seguida |
| `⇧` acionado, ou `alwaysPastePlainText` ligada | só `.string` |
| Item sem rico | só `.string` (comportamento atual) |

**`.string` é escrito sempre.** Um pasteboard só com RTF quebra a colagem em
qualquer campo de texto plano — barra de endereço, terminal, campo de busca.

A ordem importa: o primeiro tipo declarado é o que o app de destino prefere.

Para que isso seja testável sem um `NSPasteboard` real, quem decide **o que**
escrever é uma função pura em `RichText`, que recebe o item e o modo e devolve
a lista ordenada de pares tipo/dados. `ClipboardWriter` apenas percorre essa
lista chamando `setData(_:forType:)`. O teste de "`.string` está sempre
presente" incide sobre a lista, não sobre o pasteboard.

### O modificador

`⇧` + Enter e `⇧` + clique colam plano. `onTapGesture` não expõe modificadores,
então o estado da tecla sai de `NSEvent.modifierFlags` lido dentro de `pick()`,
no instante do clique.

Com `alwaysPastePlainText` ligada, `⇧` **não inverte**: as duas colagens
entregam plano, e o rótulo do menu de contexto permanece fixo.

**Interação com o item 1, já implementado:** `⌘1`–`⌘9` continuam colando no
modo padrão. `⇧⌘1`–`⇧⌘9` não são tratados nesta fase — o quick paste é atalho
de velocidade, e o caso "quero este item, mas limpo" tem o menu de contexto e o
`⇧↵` sobre a seleção.

**Pronto quando:** copiar texto formatado, colar preservando formatação, e
colar o mesmo item como texto simples pelo modificador.

---

## 0c. Menu de contexto no card

**Arquivos novos:** `Views/ItemContextMenu.swift`,
`Services/ItemActions.swift`.

Não é item numerado do roadmap. Entra porque a fase acrescenta quatro ações
sobre um item existente (colar plano, editar, renomear, pré-visualizar), e o
card hoje só tem o `×` de hover e o clique para colar. A sugestão do item 8 —
"um segundo botão circular no hover, ao lado do X" — não escala para quatro, e
cada fase seguinte acrescenta mais.

Estrutura, seguindo a seção 4 do `DESIGN.md` e `02-menu-contexto-tile.png`:
ícone SF Symbol à esquerda, rótulo, atalho alinhado à direita em cinza, com os
grupos separados por divisória.

```
  ↵    Colar em <App de destino>
  ⇧↵   Colar como texto sem formatação
  ⌘C   Copiar
 ────────────────────────────────────
  ⌘E   Editar
  ⌘R   Renomear
  ⌫    Excluir
 ────────────────────────────────────
  ⌘P   Fixar
  ␣    Pré-visualização
```

"Colar em `<App>`" nomeia o app de destino em vez de dizer só "colar" — o
destino já é conhecido quando a gaveta abre (`OverlayWindowController` guarda
`previousApp` na linha 119). Quando não houver app anterior, o rótulo degrada
para "Colar".

"Copiar" escreve no pasteboard sem simular `⌘V`, independentemente da
preferência de colagem automática. Passa pelo mesmo `ClipboardWriter.write()`,
então herda dele duas coisas: o `ignoreNextChange` que impede o monitor de
recapturar a própria escrita, e a promoção ao topo. Copiar **conta como uso**,
igual a colar.

`⌘O Abrir` fica reservado para o item 21 (Fase 6); a divisória de cima do menu
é o lugar dele.

**O menu nasce parcial e cresce.** Na entrega 0c ele tem colar, colar plano,
copiar, excluir e fixar — as ações que já existem. `⌘E`, `⌘R` e `␣` entram
junto com os itens 8, 9 e 19. Um menu com entradas mortas seria pior que um
menu curto.

**As ações vivem em `ItemActions`, não na view.** Sem essa separação
`OverlayView` — hoje 169 linhas — vira um monólito de closures, e o mesmo
conjunto de ações precisa servir ao card e ao painel de preview do item 19.

`ItemActions` é `@MainActor`, construído com o `ModelContext` e com as closures
que a overlay já possui (`onPick`, `onDismiss`). Expõe um método por ação, cada
um recebendo o `ClipboardItem` como argumento. Nenhuma delas desenha nada: o
menu e os atalhos de teclado são dois chamadores do mesmo conjunto, e é isso
que impede que as duas entradas divirjam.

---

## 8. Editar um item sem sair do app

**Arquivos novos:** `Window/ItemEditorWindowController.swift`,
`Views/ItemEditorView.swift`, `Views/RichTextEditor.swift`.

`NSWindow` titulada e redimensionável, no mesmo padrão da janela de
Preferências (`AppDelegate.openPreferences`, linha 286). A overlay fecha ao
abrir o editor.

`RichTextEditor` é um `NSViewRepresentable` sobre `NSTextView` com `isRichText`
ligado. `⌘B`, `⌘I` e o menu Formatar vêm do sistema. Writing Tools também — o
item 22 suspeitava disso ("é possível que este item venha praticamente de graça
junto com o item 8"), e a suspeita se confirma: no macOS 15+ um `NSTextView`
editável recebe Writing Tools no menu de contexto sem código. Isso **não**
transforma o item 22 em entrega desta fase; apenas registra que a base estará
posta.

A janela tem **campo de rótulo no topo e corpo abaixo**. `⌘E` abre com foco no
corpo, `⌘R` com foco no rótulo (item 9), `⌘N` abre vazia (item 10). Três
atalhos, uma tela.

### Ao salvar

1. `textContent` recebe o texto plano do attributed string
2. `richTextData` recebe o RTF serializado, e `richTextTypeRaw` vira `"rtf"`
   — mesmo que a origem tenha sido HTML, porque é o que o editor produz
3. `preview` é recalculado como `String(texto.prefix(previewTextLength))`, lendo
   a preferência, não um 200 fixo
4. `contentHash` é recalculado sobre o texto plano
5. `createdAt = .now`, promovendo ao topo

Sem o passo 4 o item editado colide com o original na deduplicação e some na
próxima cópia idêntica. Sem o passo 3 o card mostra o texto antigo enquanto a
colagem entrega o novo.

**Caso de borda aceito:** editar um item até ele ficar idêntico a outro já
existente produz dois itens com o mesmo `contentHash`. Nada quebra —
`contentHash` não é `@Attribute(.unique)`, e `insertIfNotDuplicate` só roda no
caminho de captura, não no de edição. O efeito prático é um card duplicado no
histórico, que o usuário exclui se incomodar. Deduplicar na edição exigiria
decidir qual dos dois sobrevive e o que fazer com o rótulo e o estado de fixado
do descartado — desproporcional para um caso que exige digitar exatamente o
conteúdo de outro item.

Itens de tipo imagem e arquivo não são editáveis por texto: `⌘E` e a entrada de
menu não aparecem para eles. (O item 20 dá a imagens outra forma de edição, na
Fase 6.)

**Pronto quando:** editar um item, fechar o editor, ver o card atualizado e a
colagem entregando o texto novo, com a formatação preservada.

---

## 9. Rótulos em itens

**Arquivos alterados:** `Models/ClipboardItem.swift`,
`Views/ClipboardCardView.swift`, `Views/OverlayView.swift`.

```swift
var label: String?
```

Quando presente, o rótulo **substitui** `typeLabel` e `relativeTime` no
cabeçalho colorido do card. Isso vem de `13-pinboard-links-uteis.png`, onde os
cards mostram "Bem-vindo a Bordo", "Introdução" no lugar de "Imagem / há 2
minutos" — confirmando que os dois recursos ocupam o mesmo espaço sem disputa.

O cabeçalho já divide espaço com o ícone do app (64×64, deslocado 21pt à
direita) e o indicador de fixado. O rótulo leva `lineLimit(1)` e truncamento por
cauda.

`OverlayView.filtered` (linha 35) passa a buscar também em `label`. Rótulo que
não é pesquisável derrota o propósito de nomear.

Edição pelo `⌘R` do editor do item 8. Rótulo vazio equivale a ausente: o
cabeçalho volta a mostrar tipo e tempo relativo.

**Pronto quando:** rotular um item, ver o rótulo no card e encontrá-lo buscando
pelo rótulo em vez do conteúdo.

---

## 10. Criar um item do zero

**Arquivos alterados:** `Views/OverlayView.swift`, `AppDelegate.swift`,
`Services/AppColorExtractor.swift`, `Views/ClipboardCardView.swift`.

`⌘N` abre o editor vazio, tanto na overlay quanto pelo menu da barra de status —
"Novo item de texto ⌘N", como em `05-menu-status-bar.png`.

Ao salvar:

- tipo detectado entre `.text` e `.url` pela mesma regra do monitor
  (`ClipboardMonitor.swift:171`)
- `contentHash` calculado sobre o texto
- `sourceAppBundleID` fica `nil`
- `isPinned = true`

**Identidade visual.** É de `sourceAppBundleID` que saem a cor do cabeçalho
(`AppColorExtractor`) e o ícone do card. Com ele nulo, o card nasceria sem cor e
sem ícone, com cara de quebrado. O item criado à mão passa a usar a cor e o
ícone do **próprio MyPasteApp** — é o único item cuja origem verdadeiramente é
este app. `AppColorExtractor` ganha esse caso para entrada nula, e
`ClipboardCardView.appIcon` idem.

**Por que nasce fixado.** `RetentionPolicy.prune()` protege da poda uma única
coisa: `isPinned == true`, nas duas passadas. Sem isso, um snippet escrito à
mão e não usado por 30 dias é apagado — o único caso desta fase em que o app
destruiria trabalho autoral. `expiresAt` (item 17, Fase 5) é a solução
conceitualmente correta e substituirá esta quando existir; o duplo sentido de
`isPinned` fica registrado como dívida para o item 16.

**Pronto quando:** `⌘N`, digitar um texto, salvar, e o item aparecer no
histórico e colar corretamente.

---

## 19. Painel de preview do item

**Arquivos novos:** `Window/ItemPreviewPanel.swift`,
`Views/ItemPreviewView.swift`.

### Spike de viabilidade — primeira tarefa do bloco

A overlay é `.nonactivatingPanel` e `.transient`, e
`installClickOutsideMonitors()` (linha 229) a esconde a qualquer clique fora
dela. Um painel novo pode roubar foco ou disparar esses monitores, fechando a
overlay por baixo de si.

Antes de qualquer trabalho de conteúdo, confirmar que um painel ancorado
sobrevive a isso — provavelmente exigindo que os monitores passem a ignorar
cliques cujo `event.window` seja o painel de preview, do mesmo modo que já
ignoram os da própria overlay.

**Se não se sustentar em duas tentativas, o item sai da fase** e volta ao
roadmap com o resultado registrado. As outras sete entregas não dependem dele.

### Comportamento

`Espaço` abre o painel **quando o campo de busca está vazio**; com texto no
campo, `Espaço` digita normalmente. Um espaço inicial numa busca não tem uso, e
"foo bar" continua funcionando porque nesse ponto o campo não está vazio. Com a
busca preenchida, o preview continua acessível pelo menu de contexto.

Isso é regra pura sobre `searchText.isEmpty` e é coberta por teste sem GUI.

### Aparência

Segue `03-preview-web.png` e `04-preview-imagem.png`: barra de título própria
com `×` circular à esquerda, o tipo ao lado, ações à direita; cantos
arredondados generosos e sombra forte; bico apontando para o card selecionado.

O painel **não fecha ao perder foco** — fecha pelo `×`, por `Espaço` de novo ou
por `Esc`. As capturas mostram a gaveta viva embaixo do painel aberto.

**O painel não toma o foco de teclado.** Quem continua recebendo as teclas é a
overlay, que já é a key window; o painel é conteúdo ancorado a ela. Sem isso,
`Espaço` e `Esc` teriam de ser tratados em dois lugares, e as setas deixariam
de navegar entre cards enquanto o preview estivesse aberto — quando o
comportamento desejável é o oposto: navegar com as setas e ver o painel
acompanhar a seleção.

**`Esc` passa a ser ambíguo e precisa de precedência.** Hoje
`OverlayView.onKeyPress(.escape)` (linha 87) chama `onDismiss()` e fecha a
overlay inteira. Com o painel aberto, `Esc` fecha **o painel** e a overlay
permanece; só um segundo `Esc` fecha a overlay. É a convenção do sistema —
fechar primeiro o que está por cima — e sem essa regra explícita o usuário perde
a gaveta ao tentar fechar o preview.

Conteúdo por tipo:

- **Texto:** conteúdo completo, com rolagem. É o que resolve a limitação de
  hoje, em que texto longo é truncado em `previewTextLength` e `lineLimit(8)` e
  simplesmente não é legível no app
- **Imagem:** ampliada sobre fundo xadrez indicando transparência, com as
  dimensões no rodapé
- **Arquivo:** thumbnail grande e metadados, reusando `FileThumbnailService`
- **URL:** o resumo que `LinkPreviewView` já monta. `WKWebView` é o item 25 e
  não entra aqui

**Pronto quando:** selecionar um item de texto longo, apertar `Espaço` e ler o
conteúdo inteiro sem sair da overlay — com ela permanecendo aberta.

---

## Testes

A suíte cobre **lógica pura**, em `MyPasteAppTests`, com Swift Testing. Cada
teste abaixo é escrito sem GUI e sem `NSPasteboard` real, no padrão que a Fase 1
estabeleceu com `ClipboardMonitor.shouldCapture`.

| Alvo | O que cobre |
|---|---|
| `PreferenceKeys` | Lista congelada dos valores das chaves. Impede a regressão mais cara do item 6: uma renomeação que apaga a configuração de todos, sem erro |
| `RichText` | Prioridade RTF > HTML; a decisão rico-vs-plano nas três situações; e que `.string` está sempre presente no resultado |
| `RetentionPolicy` | Os três casos de `retentionDays` (ausente / `0` / N); que Para Sempre pula a poda por idade; e que **não** desliga o corte por `maxItems` |
| `RetentionSlider` | Mapeamento entre as cinco paradas e o valor gravado, incluindo o arredondamento de um valor fora das paradas |
| Item criado | Detecção url-vs-text e `isPinned == true` |
| Recálculo ao salvar | `preview` respeitando `previewTextLength`, e `contentHash` derivado do texto plano — não do RTF |
| Busca | `filtered` encontrando por `label` |
| Preview | `Espaço` abre só com a busca vazia, e a precedência do `Esc` (fecha o painel antes da overlay) |
| `HotkeyManager` | Falha de registro propagada ao chamador |

## Verificação manual

**Entrega própria, não etapa final.** Na Fase 1, seis revisões limpas e 92
testes verdes não pegaram que o teclado da overlay nunca havia funcionado —
`NSPanel` `.borderless` não vira key window, e setas, Enter, Esc e `⌘P`
estavam mortos desde que a overlay foi escrita. A suíte não cobre fiação
AppKit/SwiftUI, e nenhum agente consegue exercitar a GUI.

O plano de implementação traz o roteiro detalhado por entrega. Os pontos que
nenhum teste desta fase alcança:

1. **Item 6 — cada preferência pré-existente, uma a uma, com dados já
   gravados.** É o `pronto quando` do item, e o risco mais caro da fase
2. **Migração do SwiftData** — abrir o app com o banco que já existe e conferir
   que os três campos novos não impediram a abertura
3. **Item 7 de ponta a ponta** — copiar de um app com formatação, colar em
   outro preservando, colar o mesmo item com `⇧` e obter texto limpo, e ligar a
   preferência global confirmando que as duas colagens passam a vir limpas
4. **Editor** — foco inicial correto por atalho (`⌘E` no corpo, `⌘R` no
   rótulo), undo funcionando, e o card refletindo o que foi salvo
5. **`⌘N`** — item nasce com cor e ícone próprios, e sobrevive a um `prune()`
6. **Preview** — overlay permanece aberta com o painel aberto; `Espaço` digita
   normalmente quando há texto na busca; as setas continuam navegando entre
   cards com o painel aberto; o primeiro `Esc` fecha o painel e o segundo fecha
   a overlay
7. **Menu de contexto** — cada entrada faz o que diz, e o atalho anunciado ao
   lado dela funciona de fato quando acionado pelo teclado. Foi exatamente esse
   tipo de divergência — atalho anunciado, atalho morto — que a Fase 1
   descobriu tarde

## Riscos

| Risco | Mitigação |
|---|---|
| O item 6 toca em todas as preferências, e uma chave errada não quebra nada visivelmente — só faz o app esquecer a configuração | Teste de chaves congeladas e conferência manual uma a uma |
| O painel de preview pode não coexistir com a overlay `.transient` | Spike como primeira tarefa do bloco, com saída definida em duas tentativas |
| `NSTextView` dentro de SwiftUI: first responder, undo e o momento do salvamento | Envelope isolado em `RichTextEditor`, verificado à mão |
| Migração do SwiftData com três campos novos | Campos opcionais, e conferência com banco pré-existente antes do PR |
