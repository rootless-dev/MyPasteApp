# Verificação manual — Fase 6 (Conteúdo)

Branch `feature/fase-6-conteudo`. Rode com `⌘R` no Xcode.

> **Esta fase não fecha com a suíte verde.** A suíte cobre lógica pura —
> `ColorCode`, `ImagePixel`, `ImageRotation`, `DragPayload`, `TempFileCleanup`,
> `OpenWith`, `TextStats`, `RichText.toggling`/`stripped`. **Nada do que esta
> fase construiu em `Views/` ou `Window/` tem teste automatizado**: nem o
> conta-gotas no preview, nem o Live Text, nem o botão de girar no editor, nem
> `.onDrag` no card, nem o submenu "Abrir com", nem a barra de formatação. Das
> cinco fases anteriores, quatro tiveram seu pior defeito achado só aqui,
> nunca na suíte — e a primeira verificação desta fase (bloco A, abaixo) é a
> que decide se o resto do roteiro faz sentido rodar. Até você rodar este
> roteiro os itens 19–22 estão **"implementados e com suíte verde"**, não
> **"concluídos"**.

⚠️ = falha **em silêncio**: sem erro, sem log, sem nada na tela. Se não
conferir de propósito, passa batido.

🔴 = pode destruir dados sem desfazer (regrava um blob no lugar do original).
Use uma imagem de teste, não algo insubstituível.

Anote o que achar estranho mesmo que pareça irrelevante.

---

## A. Live Text — eliminatório, rode isto primeiro

`ItemPreviewPanel` só sobrevive hoje porque nada nele precisa de foco de
teclado: ele nasce com `becomesKeyOnlyIfNeeded = true`, e a gaveta por baixo
(`OverlayView`/`OverlayWindowController`) está com `windowDidResignKey` ligado
a `hide()` — perder o status de key window fecha a gaveta. Selecionar texto
com Live Text é exatamente o tipo de interação que pode pedir status de key
window para o painel. **Se ligar o Live Text fechar a gaveta por baixo, pare
aqui**: o resto deste roteiro depende da gaveta continuar aberta durante o
uso do painel, e não faz sentido continuar até isso ser resolvido.

- [ ] **A1 ⚠️ 🔴-adjacente, o passo mais importante do bloco.** Abra o preview
      de uma imagem com texto reconhecível (`Espaço` com o card selecionado).
      Ligue o Live Text (botão com o ícone `text.viewfinder`, ao lado do
      conta-gotas). **Critério:** a gaveta continua aberta embaixo do painel.
      Se ela fechar sozinha, anote e pare — os passos A2–A6 e todo o resto do
      roteiro (blocos B a I) ficam sem sentido até isso ser corrigido.

- [ ] **A2** Com o Live Text ligado, confirme que a seleção de texto cai **em
      cima do texto de verdade** na imagem, não deslocada. É mais fácil de
      pegar num texto perto da borda do painel, onde a imagem pode estar
      *letterboxed* (sobra vazia lateral por causa do ajuste de aspecto).

- [ ] **A3** Selecione um trecho de texto e copie (`⌘C` ou o menu de
      contexto do próprio VisionKit).

- [ ] **A4** Botão direito sobre a imagem → "Copy All" (ou equivalente do
      menu de contexto do VisionKit) e confirme que todo o texto reconhecido
      foi copiado.

- [ ] **A5** Ligue o conta-gotas (bloco C usa o mesmo botão) com o Live Text
      ainda ligado. **Critério:** o Live Text desliga sozinho — os dois modos
      são mutuamente exclusivos por design (um único `mode` para os dois).

- [ ] **A6** Abra o preview de uma imagem **sem** texto nenhum e ligue o Live
      Text. **Critério:** nada quebra; a análise simplesmente não encontra
      texto para selecionar.

- [ ] **A7 ⚠️** Ao clicar sobre a imagem com Live Text ligado, preste atenção
      se o clique se comporta como um clique normal (por exemplo, se também
      dispara alguma ação do conta-gotas por baixo). O `.onTapGesture` do
      SwiftUI convive com os reconhecedores de gesto próprios do
      `ImageAnalysisOverlayView` do VisionKit, e o único jeito de saber se eles
      conflitam é observando em uso real — sem sintoma esperado definido,
      então qualquer coisa que pareça "o clique fez duas coisas" vale anotar
      aqui.

---

## B. Cor

Preparação: tenha à mão os textos `#3A86FF`, `rgb(58, 134, 255)` e uma folha
de CSS inteira (copiada de um arquivo `.css` de verdade, várias linhas) para
colar/copiar em sequência.

- [ ] **B1** Copie `#3A86FF` e confirme que o card mostra a amostra de cor
      (`ColorSwatchView`, quadriculado + cor + código), não o texto cru.
      Copie `rgb(58, 134, 255)`: mesma coisa. Copie a folha de CSS inteira:
      **não** aparece amostra — o texto é longo demais para ser só um código
      de cor, e o card mostra o texto normal.

- [ ] **B2** Pelo menu da barra de status, "Pick Color from Screen" (o
      conta-gotas do sistema). Capture qualquer cor da tela. **Critério:** um
      item novo nasce no histórico com **o ícone do próprio MyPasteApp** no
      cabeçalho — não sem ícone, não com o ícone de outro app. Esse é o
      `makeCapturedItem`/`sourceAppBundleID` do app mesmo, não `nil`.

- [ ] **B3** Abra o preview de uma cor reconhecida e clique no conta-gotas
      (ícone de mira) para amostrar um pixel **dentro da imagem** (ex.:
      preview de uma imagem qualquer com cor sólida, ou abra o preview de um
      item de cor e amostre dentro dele). Confirme o aviso "Copied #RRGGBB"
      aparecendo. **Critério a conferir com atenção:** confira se um item
      **novo** aparece no histórico depois dessa amostra ou não — o
      comportamento pretendido é que não apareça (a amostra dentro do preview
      seria "só copiar", não "criar item novo"); se um item novo nascer aqui,
      **anote exatamente isso** — é a diferença entre o comportamento
      pretendido e o que o código realmente faz hoje, e vale registrar sem
      tentar adivinhar qual dos dois está certo.

- [ ] **B4** No card ou no preview de um item de cor, use o submenu "Copy
      Color as" (menu de contexto → escolha um formato diferente do
      original). **Critério:** desta vez **nasce** um item novo no histórico,
      com o texto convertido no formato escolhido.

- [ ] **B5** Depois de B3, mexa o mouse levemente sem sair da imagem (sem
      cruzar a borda do painel). **Critério:** a mira do cursor volta ao
      normal quase na hora, não só quando o mouse sai da imagem.

- [ ] **B6** Clique no conta-gotas **sem** o modo ligado (ou na faixa vazia
      ao lado da imagem, fora dela): nada é copiado, nenhum item novo nasce.

- [ ] **B7** Durante todo o bloco B, confirme que a gaveta embaixo continua
      aberta.

---

## C. Rotação

🔴 Use uma imagem de teste — rotacionar e salvar regrava o PNG por cima do
original, sem desfazer.

- [ ] **C1 🔴** Abra o editor de uma imagem (botão "Edit" no preview), gire
      90°, salve. **Critério:** **o card** no histórico mostra a imagem já
      girada, **sem reiniciar o app** — é o teste de que o cache de thumbnail
      foi invalidado, não só o `imageData`.

- [ ] **C2** Gire e cancele (feche o editor sem salvar). **Critério:** a
      imagem continua na orientação original — nada foi regravado.

- [ ] **C3 ⚠️** Gire quatro vezes (volta à orientação original) e salve.
      **Critério, dois juntos:** a imagem **visualmente não muda** (girar 4×
      90° é a orientação original) — **mas o item sobe para o topo do
      histórico mesmo assim**. Isso é esperado, não um bug: `Save` promove o
      item sempre, pelo mesmo caminho (`applyLabel`) que já promovia um
      "Rename" sem mudança nenhuma antes desta fase. Se o item **não** subir,
      isso é que seria a surpresa a anotar.

- [ ] **C4** Renomeie (rótulo) e gire no mesmo `Save`. **Critério:** as duas
      mudanças valem — o rótulo novo aparece e a imagem sai girada.

- [ ] **C5 ⚠️** Com uma imagem **não quadrada**, gire dentro do editor (antes
      de salvar) e observe a prévia. **Comportamento conhecido, não é bug:**
      a prévia pode extrapolar a moldura do editor enquanto girada — o
      `rotationEffect` da prévia não redimensiona nem recorta seu quadro. A
      direção do giro em si está correta; só a moldura da prévia (antes de
      salvar) que pode não acompanhar. Confirme que, **depois de salvar**, a
      imagem final está corretamente dimensionada e sem corte.

---

## D. Arrastar

Preparação: tenha um card de imagem, um de texto simples, um de texto
formatado (copiado de um editor com RTF nativo, tipo TextEdit/Pages/Word — e
separadamente um copiado de uma página web, que carrega só HTML), um de
arquivo, e — se possível — um item com **mais de um arquivo** copiado junto
(ex. selecionar 2+ arquivos no Finder e `⌘C`).

- [ ] **D1** Arraste um card de **imagem** para o Finder. **Critério:** nasce
      um `.png` com nome razoável (baseado no rótulo/data, não um UUID cru).

- [ ] **D2** Arraste o mesmo card de imagem para o Word (ou outro app que
      aceite imagem colada/arrastada). **Critério:** a imagem é inserida.

- [ ] **D3** Arraste para o navegador. **Critério:** abre em visualização
      (nova aba ou preview da imagem).

- [ ] **D4** Arraste um card de **texto simples** para um campo de texto de
      outro app.

- [ ] **D5** Arraste um card de **texto formatado** para o Word — teste os
      **dois** casos: o item com RTF nativo e o item capturado só como HTML
      (do navegador). **Critério, os dois:** a formatação chega ao destino,
      não só o texto puro. Os dois passam por caminhos de UTI diferentes
      (`RichTextFormat.rtf` vs `.html`); um funcionando não garante o outro.

- [ ] **D6** Arraste um card de **arquivo** para outra pasta do Finder.
      Confirme que o arquivo chega íntegro (abra-o).

- [ ] **D7 (comportamento conhecido, não é bug a investigar)** Arraste um
      card **multi-arquivo**. **Critério:** só o **primeiro** arquivo chega
      ao destino — é deliberado e documentado no código: `.onDrag` do
      SwiftUI só entrega um `NSItemProvider`, e carregar N arquivos de
      verdade exigiria uma sessão de arrasto do AppKit (`NSDraggingItem`),
      fora do escopo desta fase. Não anote como defeito; confirme só que o
      primeiro arquivo chega corretamente.

- [ ] **D8** Em **cada** arrasto acima, anote se a gaveta fecha ao soltar, e
      em qual destino. Não há um único comportamento esperado documentado
      para todos — é para registrar o que acontece em cada um.

- [ ] **D9 ⚠️** Comece um arrasto e solte **fora** de qualquer destino válido
      (ex.: solte no meio do Desktop vazio, ou cancele com `Esc` no meio).
      **Critério:** nenhum arquivo fica para trás em
      `$TMPDIR/MyPasteApp-drags` — confira com
      `ls -la "$TMPDIR/MyPasteApp-drags"` no Terminal logo depois.

---

## E. Abrir com

- [ ] **E1** Selecione um card de **arquivo** (que ainda existe no disco) e
      aperte `⌘O`. **Critério:** abre no aplicativo padrão do sistema para
      aquele tipo de arquivo.

- [ ] **E2** Selecione um card de **URL** e aperte `⌘O`. **Critério:** abre
      no navegador padrão.

- [ ] **E3** Selecione um card de **texto** (sem arquivo, sem URL) e aperte
      `⌘O`. **Critério:** nada acontece — e o app não trava nem mostra erro.

- [ ] **E4** Abra o submenu "Abrir com" pelo menu de contexto de um card de
      arquivo ou URL. **Critério:** lista os apps candidatos instalados, sem
      duplicatas; escolher um deles abre o item nesse app especificamente.

- [ ] **E5** Ache (ou simule) um item cujo arquivo foi apagado do disco
      depois de copiado. **Critério:** o menu mostra uma entrada
      **desabilitada** com o texto "Open with — file not found: `<caminho>`"
      em vez de simplesmente omitir a opção ou falhar em silêncio.

- [ ] **E6** Repare se um caminho bem longo nessa entrada desabilitada
      espreme ou quebra a linha do menu — não é um critério pass/fail restrito,
      mas vale anotar se incomodar visualmente.

---

## F. Gate de teclado

- [ ] **F1 🔴 O passo mais importante do bloco.** Com a gaveta aberta, crie
      um pinboard novo ou dê duplo clique no nome de um pinboard existente
      para abrir o campo de renomeação — **deixe o campo aberto**. Com o
      campo ainda em edição, aperte `⌘O`. **Critério:** absolutamente nada
      acontece — nenhum app abre, e a digitação no campo continua normal
      depois. Este é o mesmo bug de Fase 5, por uma porta nova: lá, `⌫`
      sobre o campo de renomeação aberto apagava o card selecionado em vez de
      apagar uma letra, porque o handler de teclado não checava se um campo
      de texto estava consumindo a tecla. Se `⌘O` abrir alguma coisa aqui, é
      exatamente essa classe de bug de volta, desta vez no atalho novo desta
      fase.

---

## G. Editor: contagem e formatação

- [ ] **G1** Abra o editor de um item de texto. **Critério:** o rodapé mostra
      a contagem no formato "N characters · N words · N lines", com singular
      correto quando N = 1 em qualquer um dos três.

- [ ] **G2** Digite e apague texto no editor. **Critério:** a contagem
      atualiza em tempo real, sem esperar salvar.

- [ ] **G3** Selecione uma palavra e aplique negrito, itálico, sublinhado e
      tachado, um de cada vez, pelos botões da barra. **Critério:** cada um
      alterna visivelmente **só na seleção**.

- [ ] **G4** Aperte o mesmo botão duas vezes seguidas na mesma seleção.
      **Critério:** a formatação volta a desligar (é toggle).

- [ ] **G5 ⚠️ O passo mais importante do bloco.** Clique no meio do texto
      (não no início), selecione uma palavra ali e aplique um formato.
      **Critério:** o cursor/seleção **não pula para o início do texto**
      depois — continua onde estava. Esse é justamente o risco que a fase
      documentou por escrito (a sincronização entre o `NSTextView` e o
      `@State` do SwiftUI) e corrigiu em duas rodadas de revisão.

- [ ] **G6** Selecione um trecho misto (ex.: metade já em negrito, metade
      não) e aperte Negrito uma vez. **Critério:** a seleção inteira fica
      **uniformemente** em negrito — não alterna cada metade
      independentemente. Repita para sublinhado e tachado (achado de revisão
      separado do de negrito/itálico).

- [ ] **G7** Aplique vários formatos e aperte "Clear formatting" (ícone de
      borracha). **Critério:** o texto inteiro sobrevive, e **todos** os
      atributos (negrito, itálico, sublinhado, tachado) somem — inclusive
      fora da seleção atual, porque limpar formatação age no documento
      inteiro, não só no trecho selecionado.

- [ ] **G8** Salve o item com formatação aplicada, feche o editor e reabra.
      **Critério:** a formatação persiste.

- [ ] **G9 (comportamento conhecido, não é bug)** Posicione o cursor **sem
      selecionar nada** e aperte um botão de formatação. **Critério:** nada
      visivelmente acontece — é esperado: o editor não tem suporte a
      "typing attributes" (aplicar o estilo ao que for digitado a seguir
      sem seleção prévia). Não é um defeito a reportar.

---

## H. Writing Tools (item 22) — este passo *é* a entrega do item

Nenhuma linha de código foi escrita para isto nesta fase: a suposição desde a
Fase 2 é que Writing Tools aparece de graça no menu de contexto de qualquer
`NSTextView` editável no macOS 15+. Este passo confirma ou derruba essa
suposição — é o critério de "pronto" do item 22 inteiro.

- [ ] **H1** Abra o editor com um texto (idealmente um parágrafo com algo a
      melhorar). Selecione o texto.

- [ ] **H2** Clique com o botão direito na seleção. **Critério a registrar:**
      "Writing Tools" (ou as entradas "Proofread"/"Rewrite"/"Summarize",
      dependendo da versão do sistema) aparece no menu de contexto?

- [ ] **H3** Se aparecer, use **Revisar** (Proofread), **Reescrever**
      (Rewrite) e **Resumir** (Summarize), um de cada vez. **Registre o que
      acontece em cada um** — mesmo que o resultado seja ruim ou estranho, o
      que importa aqui é se a integração funciona, não a qualidade da
      reescrita.

- [ ] **H4** Se **não** aparecer nada, ou se aparecer desabilitado: anote a
      mensagem exata (se houver) e se o hardware/conta usados têm Apple
      Intelligence ativado — a ausência pode ser do dispositivo, não do app.

---

## I. Herdados de fases anteriores

- [ ] **I1 O `⌘M` da Fase 4, nunca verificado.** Com a gaveta aberta e um
      card de texto ou link selecionado, aperte `⌘M`. **Esperado:** o card
      marca para colagem múltipla (aparece um chip), nada minimiza. O risco
      documentado desde a Fase 4 é o menu Window ▸ Minimize que o AppKit
      monta para a cena `Settings` engolir `⌘M` antes da gaveta ver a tecla.
      Se falhar, o conserto é de escopo da Fase 4 (trocar o atalho), não
      desta — só registre o resultado aqui.

- [ ] **I2 🔴 O bug do `⌘1` (crash com perda de histórico), ainda sem
      diagnóstico.** Não é desta fase e não deveria bloquear o fechamento
      dela, mas se reproduzir durante este roteiro, **pare e capture a stack
      trace** com um Exception Breakpoint em vez de tentar reproduzir de novo
      sem registrar nada. Suspeitos até agora (investigação nunca concluída):
      `prune()`, `QuickPaste` e `ClipboardWriter` — código das Fases 1 e 2,
      não tocado por esta.

---

## Decisões e comportamentos conhecidos — não são pass/fail

Não são bugs a marcar certo/errado — são escolhas já tomadas de propósito, ou
limitações documentadas no código.

1. **Um card multi-arquivo arrasta só o primeiro arquivo.** `.onDrag` do
   SwiftUI entrega exatamente um `NSItemProvider`; carregar N arquivos de
   verdade exige uma sessão de arrasto do AppKit, fora de escopo. Deliberado
   e documentado no código (ver bloco D, item D7).

2. **Apertar um botão de formatação sem seleção não faz nada.** O editor não
   implementa "typing attributes" — não há como pré-armar um estilo para o
   próximo caractere digitado. Ver bloco G, item G9.

3. **Girar uma imagem regrava em sRGB.** Uma imagem de origem em gama largo
   (P3) é convertida para sRGB ao salvar uma rotação — consequência do
   contexto de desenho usado para regravar o PNG, não um defeito a corrigir
   nesta fase. Não há um roteiro específico para detectar isso à mão (exige
   uma imagem fonte comprovadamente P3 e comparação de perfil de cor antes/
   depois); registrado aqui para constar.
