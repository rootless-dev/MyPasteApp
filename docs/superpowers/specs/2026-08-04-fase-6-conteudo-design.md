# Fase 6 — Conteúdo

Design aprovado em 2026-08-04. Cobre os **itens 20, 21 e 22** do `ROADMAP.md`
(ferramentas de imagem e cor, arrastar como arquivo e abrir com, Writing Tools)
— a fase inteira numa branch só, por decisão explícita do Carlos depois de a
alternativa de fatiar em duas ter sido apresentada. O item 19 da mesma fase já
tinha sido entregue na Fase 2.

Duas entregas **não previstas no ROADMAP** entram por decisão tomada durante o
design, a partir de capturas do Paste que o Carlos enviou: seleção de texto na
imagem (Live Text) e o acabamento do editor de texto (contagem e barra de
formatação). Ver "Escopo" abaixo.

Ambiente de referência: deployment target macOS 26.2, Swift 5. O projeto usa
`PBXFileSystemSynchronizedRootGroup`, então arquivos novos entram no alvo pelo
simples fato de existirem no diretório — não há `project.pbxproj` para editar.

Branch: `feature/fase-6-conteudo`, criada a partir de `develop`.

## O que a fase entrega

| Item | Entrega |
|---|---|
| 20 (cor) | Conta-gotas do sistema na barra de status, criando um item com o hex. Qualquer item de texto que **seja** um código de cor mostra a amostra no card e no preview, e ganha "Copiar cor como… ▸ Hex / RGB / HSL". Dentro do preview de imagem, um modo de amostragem lê o pixel do dado original e copia a cor |
| 20 (rotação) | Editor de imagem na mesma janela do editor de item: girar à esquerda e à direita, com `Cancel`/`Save`. Salvar regrava a imagem, o hash, o preview e invalida o thumbnail em cache |
| 21 | Arrastar qualquer card: texto e URL saem como texto, arquivo sai como as URLs que ainda existem, imagem sai como PNG materializado sob demanda. "Abrir com ▸" para arquivo e URL, com `⌘O` |
| 22 | Verificação de que Writing Tools funciona no editor, com evidência registrada. Sem código novo, salvo se a verificação falhar |
| — | **Live Text** no preview de imagem, via VisionKit: seleção de texto, "Copiar Tudo" e detecção de dados vindos do sistema |
| — | **Editor de texto**: contagem de caracteres, palavras e linhas no rodapé, e barra com negrito, itálico, sublinhado, tachado e limpar formatação |

## Escopo e o que fica de fora

Fora de escopo, com o lugar marcado:

- **Conta-gotas por atalho global.** O gatilho é o menu da barra de status, ao
  lado de "New Text Item". Um terceiro atalho configurável é fácil de
  acrescentar depois e impossível de remover sem quebrar quem já o usa
- **"Abrir com" para imagem.** Exigiria escrever o arquivo sem nenhum destino
  que o tenha pedido — escrita imediata a cada abertura de menu, em vez da
  materialização sob demanda do arrasto. Volta ao ROADMAP como item aberto
- **Arrastar um card até a pílula de um pinboard.** É o gesto que a Fase 5
  deixou marcado para esta fase. Continua fora: o arrasto desta fase tem
  destino externo, e distinguir os dois pelo alvo do drop é trabalho por si só,
  que só faz sentido depois de o arrasto externo estar verificado em uso real
- **Compartilhar (share sheet)** no cabeçalho do preview, que aparece nas
  capturas do Paste. Não está no ROADMAP e não foi pedido
- **Barras de rolagem no preview de imagem.** O Paste mostra a imagem em
  tamanho natural com rolagem; nós escalamos para caber, por decisão consciente
  registrada em `ItemPreviewView` — uma captura de 1920×1080 preenchia o painel
  com o próprio canto superior esquerdo. Não muda nesta fase
- **O bico do painel de preview**, pendência parcial da mudança derivada 13 do
  `DESIGN.md`. Continua sem seta apontando para o card
- **O bug do `⌘1`** (crash com perda de histórico): segue sem diagnóstico. Esta
  fase não o resolve nem o agrava

## Decisões tomadas

| Decisão | Escolha | Por quê |
|---|---|---|
| Escopo da fase | **Itens 20, 21 e 22 numa branch**, mais Live Text e o acabamento do editor | Decisão do Carlos, tomada depois de a alternativa (duas branches sequenciais, com a GUI exercitada no meio) ter sido apresentada com o argumento de que são 13 tarefas e quatro superfícies novas verificáveis só à mão. A contrapartida está em "Riscos" |
| Leitura de "cor" do item 20 | **Conta-gotas de tela**, com reconhecimento de cor em texto vindo junto | O ROADMAP recomendava a outra leitura (só detector em texto). O Carlos escolheu o conta-gotas; o reconhecimento entra porque, sem ele, a cor capturada é um texto qualquer com cara de código. O submenu "Copiar cor como…" completa a conversão entre formatos, que era o resto da leitura descartada |
| Custo do conta-gotas | **`NSColorSampler`, do AppKit** | É literalmente o "native color picker" que o changelog do Paste cita. A captura roda no processo do sistema: nenhuma permissão de gravação de tela, nenhum código de captura nosso. **Correção de premissa:** a primeira leitura deste design supôs permissão de captura, e estava errada |
| Como a cor vive no histórico | **Item de texto com o código**, sem tipo novo | Um quinto caso em `ClipboardItemType` obrigaria a mexer em `ItemSearch.facets`, `SearchToken`, `ClipboardWriter`, nos rótulos de tipo e nos gates de edição e multi-paste — e um `#3A86FF` copiado do Figma continuaria sendo texto, ou seja, dois tipos de cor no mesmo app. Derivar a cor de `textContent` faz a amostra valer para os dois casos |
| O que o parser aceita | **A string aparada precisa ser inteiramente a cor** | Procurar cores *dentro* do texto faria toda folha de CSS no histórico virar "item de cor", e o submenu de conversão não teria o que responder a "qual das trinta?" |
| Formatos do submenu | **Hex (padrão), RGB, HSL** | Os três que qualquer CSS aceita. Swift e HSB foram oferecidos e recusados por YAGNI |
| Conta-gotas: quem cria o item | **O app cria explicitamente**, com `ignoreNextChange` ligado na cópia | Deixar o monitor capturar parece mais simples e produz um item errado: a origem é resolvida pelo app em primeiro plano, e o nosso não está em primeiro plano quando a lupa fecha — o item nasceria carimbado com o ícone e a cor do app de baixo |
| Amostragem no preview: cria item? | **Não. Só copia**, com `ignoreNextChange` ligado | Explorar uma imagem clicando em vários pixels encheria o histórico de itens que ninguém pediu. A assimetria com o conta-gotas é deliberada: capturar da tela traz algo de fora para dentro do app; amostrar é olhar de perto o que já está dentro |
| "Copiar cor como…" | **Sem `ignoreNextChange`**: o resultado entra no histórico | O formato convertido é conteúdo novo, pedido explicitamente. Vale a mesma regra de qualquer cópia feita pelo app |
| Amostragem: clique ou modo | **Modo, ligado por botão**, que se desliga na primeira amostra | Sem modo, um clique casual no painel sobrescreve a área de transferência sem que nada na tela tenha dito que isso aconteceria. O botão também é o que ensina que o recurso existe |
| Onde se gira uma imagem | **Num editor com `Cancel`/`Save`**, aberto pelo "Editar" do preview | Aplicar direto no preview faria cada clique regravar o blob em `.externalStorage`, recalcular o hash, invalidar o thumbnail e promover o item ao topo — quatro efeitos por clique, com o card pulando de posição enquanto o usuário ainda decide. E não haveria como desistir |
| Onde vive esse editor | **Na janela do editor de item que já existe** | `ItemEditorView` já abre para imagem (só com o campo Label, porque `hasEditableBody` é falso). Ganha um corpo. Uma janela nova duplicaria posicionamento, fechamento e o par Cancel/Save — dois lugares para o mesmo comportamento divergir. É o "componente reutilizável" que o item 8 pediu |
| Rotação e `contentHash` | **Recalcular**, tratando rotação como edição | Coerente com `ItemEdit.apply`. Não recalcular deixaria a deduplicação inconsistente; o vínculo com a cópia original se rompe, e é isso que se quer dizer com "este item foi editado" |
| Rotação e o thumbnail | **Invalidar a entrada de `ImageThumbnailCache`** | O cache é chaveado por `(item.id, maxPixel)`. Com o mesmo `id`, a entrada antiga continua válida e o card seguiria desenhando a imagem não girada até o app reiniciar. Não é visível olhando só para `imageData` |
| Rotação e o `preview` | **Recalcular** | O `preview` de uma imagem é a string `"Imagem 1920×1080"`, montada em `ClipboardMonitor`. Girar troca as dimensões, e um preview estagnado descreveria a imagem errada |
| Cabeçalho × botões do preview | **Ações da janela no cabeçalho; modos sobre a imagem** | `✕ · Imagem · … · Editar · 256 × 165` no cabeçalho, com "Editar" **só no preview de imagem** — para texto e URL a entrada seria um segundo caminho para o `⌘E` que já existe. Conta-gotas e Live Text no canto inferior direito, sobre a imagem, cinza desligados e coloridos ligados — que é onde o Paste põe o Live Text, e o lugar honesto para um botão cujo efeito é mudar o significado do próximo clique |
| Conta-gotas × Live Text | **Mutuamente exclusivos**: ligar um desliga o outro | São dois modos disputando o mesmo clique sobre a mesma imagem |
| Live Text: como | **`ImageAnalysisOverlayView`, do VisionKit** | Seleção real, "Copiar Tudo", detecção de dados e tradução vêm prontas. A alternativa barata — mostrar o `ocrText` que já temos num painel selecionável — não é seleção sobre a imagem, é o texto ao lado dela |
| Live Text × OCR existente | **Coexistem, sem se tocar** | `OCRService` extrai `ocrText` para alimentar a busca: texto sem posição, para achar a imagem. O Live Text é interação sobre a imagem aberta. Nenhum dos dois substitui o outro |
| Live Text: sobre qual imagem | **Sobre o dado original**, não sobre o thumbnail desenhado | Texto pequeno desaparece no downsample, e o recurso falharia justamente nas capturas de tela, que é o caso mais comum |
| Quais tipos podem ser arrastados | **Todos** | Texto e URL saem como texto e caem em qualquer campo que aceite texto, que é o comportamento do Paste. Arquivo sai como URL. Imagem sai como arquivo, para o Word inserir a imagem e o navegador abri-la |
| Texto rico no arrasto | **Reaproveita `RichText.payload`** | A mesma função que a colagem usa. Arrastar e colar não podem divergir sobre o que é o conteúdo do item |
| Materialização da imagem | **`NSItemProvider` com representação de arquivo preguiçosa**, mais faxina por idade | Nada é escrito até o destino pedir o arquivo, que é o essencial da promessa. **Correção de premissa:** a apresentação inicial disse que o sistema limparia o temporário sozinho — não há garantia documentada disso para um arquivo que nós criamos, então a faxina por idade fica, reduzida a uma rede de segurança. O `NSFilePromiseProvider` completo exigiria trocar a origem do arrasto por uma `NSView` própria, numa fase que já mexe em três janelas; fica registrado como plano B se o Finder se comportar mal |
| Nome do arquivo arrastado | **Label do item quando existe; senão tipo e data** | Sanitizado (barras, dois-pontos, comprimento) e sempre com `.png`. Um nome inválido faz o Finder recusar o arquivo, que é exatamente a falha que o item 21 existe para evitar |
| Arquivo que não existe mais | **Filtrado no arrasto, desabilitado com o motivo em "Abrir com"** | O ROADMAP pede erro claro, não falha silenciosa. Sumir da interface sem explicação é falha silenciosa |
| "Abrir com" para quais tipos | **Arquivo e URL** | Imagem exigiria o temporário eager que a materialização preguiçosa evita; texto pediria um `.txt` para abrir no editor que o app já tem |
| `⌘O` | **Entra, com o wrapper `gated`** | O comentário em `ItemContextMenu` já reservava a tecla para este item. O gate não é opcional: a Fase 5 aprendeu com `⌫` sobre o campo de renomeação, e o compilador não impede um handler que o esqueça |
| Writing Tools | **Verificar e documentar, sem código novo** | O editor é `NSTextView` editável e o macOS injeta as ferramentas nele sozinho — a Fase 2 já registrou isso como fato observado. A degradação em hardware sem Apple Intelligence também vem pronta: o sistema não exibe as entradas, e não há menu morto para tratar. A alternativa (invocar programaticamente para abrir o painel junto com o editor) usa API desenhada para views que não são `NSTextView`, e pode ser tarefa perdida |
| Acabamento do editor | **Contagem no rodapé e barra de formatação** | Pedido do Carlos a partir da captura do editor do Paste. Refinamento do item 8, que está fechado; entra aqui porque a fase já abre essa janela para o corpo de imagem |
| Lógica da barra de formatação | **Em `RichText`, não na view** | `toggling(trait:in:range:)` e `stripped(_:)` são transformações de `NSAttributedString`, testáveis sem abrir janela. Os botões só chamam. Mesma divisão que fez `ItemEdit.apply` ser testável |

## 1. Cor

### `Services/ColorCode.swift`

O tipo puro que sustenta a parte de cor. Guarda os componentes em sRGB e o
alfa; sabe ler e sabe escrever.

- `parse(_ text: String) -> ColorCode?` reconhece `#RGB`, `#RRGGBB`,
  `#RRGGBBAA`, `rgb()`, `rgba()`, `hsl()` e `hsla()`, sem distinguir
  maiúsculas, tolerando espaços internos, e exigindo que a string aparada seja
  inteiramente a cor
- `formatted(as format: ColorFormat) -> String` escreve nos três formatos
  oferecidos. A conversão RGB↔HSL é pura, com o arredondamento fixado por
  teste — a ida e volta não é exata, e o teste é o que impede o valor de andar
  a cada refatoração
- `init(_ color: NSColor)` converte para sRGB antes de ler os componentes; um
  `NSColor` em outro espaço de cor daria números que não batem com o que o
  usuário viu

Nenhum campo novo no modelo. A cor é derivada de `textContent` toda vez, como
`typeLabel` já é derivado do tipo.

### Onde a cor aparece

`ClipboardCardView` e `ItemPreviewView` perguntam ao `ColorCode` antes de
desenhar texto. Reconhecida, a área de preview mostra a amostra ocupando o
espaço, com o código legível por cima. Não reconhecida, nada muda.

### Conta-gotas da barra de status

Entrada "Pick Color from Screen" no menu do status item, ao lado de "New Text
Item" — as duas únicas ações do app que criam um item do nada.
`NSColorSampler().show { color in … }` devolve a cor; o app monta o hex, cria
o item explicitamente e escreve na área de transferência com `ignoreNextChange`
ligado, para poder colar imediatamente sem gerar um segundo item.

### Amostragem dentro do preview de imagem

O botão liga o modo, o cursor vira mira, o clique seguinte lê o pixel e o modo
se desliga. `Services/ImagePixel.swift` faz o mapeamento ponto-na-view →
pixel-no-original, que é a parte pura e a que erra sozinha: a imagem desenhada
é um thumbnail reduzido, e ler a cor dele devolveria um valor interpolado.

### "Copiar cor como…"

Submenu em `ItemContextMenu`, presente apenas quando o item é reconhecido como
cor: Hex, RGB, HSL.

## 2. Imagem

### `Services/ImageRotation.swift`

`rotate(_ data: Data, quarterTurns: Int) -> Data?`, via `CGImage` e
`CGContext`, saída PNG. Puro, e testável por dois caminhos que pegam erros
diferentes: um quarto de volta troca largura e altura; quatro quartos devolvem
o bitmap original, pixel a pixel.

### O editor de imagem

`ItemEditorView` ganha um corpo para o tipo imagem: a imagem sobre xadrez de
transparência e dois botões de girar no topo, entre `Cancel` e `Save`. O campo
Label continua ali, então renomear e girar passam a ser a mesma janela e o
mesmo `Save`.

Enquanto a janela está aberta, girar é estado em memória — quantos quartos de
volta — e a imagem é apenas exibida rotacionada. `Save` faz de uma vez:

1. regrava `imageData` com os bytes rotacionados
2. recalcula `contentHash` sobre esses bytes
3. recalcula `preview` (`"Imagem <largura>×<altura>"`, com as dimensões trocadas)
4. invalida a entrada de `ImageThumbnailCache` para aquele `id`
5. promove o item ao topo, como `ItemEdit.apply` já faz ao editar texto

`Cancel` continua significando "nada aconteceu".

### `Views/Preview/LiveTextOverlay.swift`

`ImageAnalysisOverlayView` embrulhada para SwiftUI. Só aparece se
`ImageAnalyzer.isSupported`. A análise roda sobre o dado original.

**Enquanto o modo está ligado, é ela quem desenha a imagem**, no lugar do
thumbnail: `ImageAnalysisOverlayView` alinha as caixas de texto por uma
`trackingImageView`, e sem uma delas usa o próprio `bounds` — como o preview
escala a imagem para caber, toda a seleção sairia deslocada pela margem vazia.
Hospedar o `NSImageView` dentro do wrapper é o que faz a geometria bater. A
imagem original decodificada é custo pago só enquanto o modo está ligado.

## 3. Arrastar e abrir com

### `Services/DragPayload.swift`

Puro. Dado um item, decide o que o arrasto entrega:

| Tipo | Entrega |
|---|---|
| texto, URL | a string; e o RTF junto quando o item tem `richTextData`, via `RichText.payload` |
| arquivo | as URLs que ainda existem no disco |
| imagem | PNG materializado sob demanda, com nome sugerido e sanitizado |

O PNG é escrito num diretório temporário do app quando o destino pede o
arquivo. `Services/TempFileCleanup.swift` decide, por idade, o que apagar no
lançamento — função pura sobre uma lista de arquivos e datas, testável sem
tocar o disco. É rede de segurança, não o mecanismo principal: se a escrita
preguiçosa funcionar como esperado, ela raramente encontra o que limpar.

### `Services/OpenWith.swift`

Candidatos por `NSWorkspace.urlsForApplications(toOpen:)`, execução por
`open(_:withApplicationAt:configuration:)`. Vale para arquivo e para URL.
Caminho inexistente aparece desabilitado com o motivo à vista.

O menu ganha `⌘O`, e o handler correspondente em `OverlayView` passa pelo
wrapper `gated`.

## 4. Editor de texto

- `Services/TextStats.swift`: caracteres, palavras e linhas. As regras, fixadas
  aqui para não serem decididas de improviso na implementação: caracteres é a
  contagem de `Character`; palavras é a separação por espaços e quebras,
  descartando os vazios; linhas é o número de quebras mais um, de modo que
  texto vazio dá `0 caracteres · 0 palavras · 1 linha` e um texto terminado em
  quebra conta a linha vazia final
- `RichText.toggling(trait:in:range:)` e `RichText.stripped(_:)`: as
  transformações que os botões de negrito, itálico, sublinhado, tachado e
  limpar formatação chamam

## 5. Writing Tools

Tarefa de roteiro, não de código: abrir o editor, selecionar texto, usar
Revisar, Reescrever e Resumir, e registrar a evidência no ROADMAP. Se falhar,
vira trabalho com o defeito à vista em vez de suposto.

## Arquivos

**Novos:** `Services/ColorCode.swift`, `Services/ImagePixel.swift`,
`Services/ImageRotation.swift`, `Services/DragPayload.swift`,
`Services/OpenWith.swift`, `Services/TextStats.swift`,
`Services/TempFileCleanup.swift`,
`Views/Preview/LiveTextOverlay.swift`, e as suítes de teste correspondentes.

**Tocados:** `AppDelegate` (entrada do menu), `ItemContextMenu` ("Copiar cor
como…", "Abrir com"), `ClipboardCardView` (amostra de cor, arrasto),
`ItemPreviewView` e `ItemPreviewPanel` (botões, modos, "Editar"),
`ItemEditorView` (corpo de imagem, rodapé, barra), `RichText`, `OverlayView`
(`⌘O`, com gate), `ImageThumbnailCache` (invalidação).

## Testes

Novas suítes: `ColorCodeTests`, `ImagePixelTests`, `ImageRotationTests`,
`DragPayloadTests`, `OpenWithTests`, `TextStatsTests`, `RichTextFormatTests`,
`TempFileCleanupTests`.

Fica sem cobertura automatizada o que sempre fica: janela, arrasto real, lupa
do sistema e Live Text. É o que o roteiro manual precisa cobrir.

## Riscos

- **Uma branch com 13 tarefas e quatro superfícies novas verificáveis só à
  mão.** A Fase 5 mostrou que a revisão de branch inteira acha o que doze
  revisões por tarefa aprovam; esta fase é maior que aquela. A mitigação é a
  mesma — revisão de branch inteira — e ela chega mais tarde
- **Live Text dentro de um painel não-ativante.** O painel é
  `.nonactivatingPanel` com `becomesKeyOnlyIfNeeded`, e selecionar texto exige
  que a janela aceite teclado. Pode funcionar de graça, pode exigir tornar o
  painel key enquanto o modo está ligado — e aí a overlay embaixo reage. É a
  primeira coisa a testar à mão nessa tarefa, antes de escrever o resto, como
  a Fase 2 fez com o painel
- **Arrastar para fora com a overlay aberta.** O monitor de clique externo
  reage a *mouse-down*, e o down de um arrasto acontece dentro da overlay —
  então não é ele o risco. O risco é o app de destino ativar ao receber o drop,
  disparando `windowDidResignKey` e o `hide()`. Precisa ser exercitado com
  Finder, Word e navegador
- **O Finder pode recusar o arquivo materializado** se o nome ou o tipo não
  agradarem. Verificação manual obrigatória, com o `NSFilePromiseProvider`
  completo como plano B
- **`NSColorSampler` com a overlay aberta.** A lupa é do sistema e o clique
  dela pode ou não chegar aos nossos monitores. O gatilho escolhido é o menu da
  barra de status, com a overlay fechada, o que reduz mas não elimina o caso

## Roteiro de verificação manual

Além dos passos específicos de cada tarefa, o roteiro precisa cobrir:

- copiar `#3A86FF`, `rgb(58, 134, 255)` e uma folha de CSS inteira: os dois
  primeiros mostram amostra, o terceiro não
- capturar uma cor com o conta-gotas e confirmar que o item nasce com o ícone
  do **nosso** app, não do app de baixo
- amostrar dentro do preview e confirmar que **nenhum** item novo aparece
- girar uma imagem, salvar, e confirmar que o card mostra a imagem girada
  **sem reiniciar o app** — é o teste do cache invalidado
- girar e cancelar: a imagem continua como estava
- arrastar imagem para o Finder (PNG com nome razoável), para o Word (imagem
  inserida) e para o navegador (abre em visualização)
- arrastar texto para um campo de texto de outro app
- confirmar se a overlay sobrevive ao drop, e registrar o que acontece
- "Abrir com" num arquivo existente, e num item cujo arquivo foi apagado
- Live Text: ligar, selecionar, "Copiar Tudo"; e confirmar que ligar o
  conta-gotas desliga o Live Text
- Writing Tools no editor: Revisar, Reescrever, Resumir
- **Passos herdados:** o `⌘M` da Fase 4, ainda sem verificação, e o crash do
  `⌘1`, ainda sem diagnóstico

## Pronto quando

- capturar uma cor da tela, vê-la como amostra no card e colá-la em RGB pelo
  submenu
- girar uma imagem no editor, salvar, e colá-la já girada no destino
- arrastar um card de imagem para o Finder e obter um PNG válido com nome
  razoável
- abrir um item de arquivo em outro app pelo "Abrir com"
- selecionar e copiar um texto de dentro de uma imagem no preview
- usar Revisar sobre um texto selecionado no editor, sem sair do app
- a suíte verde, e o Carlos tendo exercitado o roteiro acima à mão
