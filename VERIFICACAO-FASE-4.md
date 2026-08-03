# Verificação manual — Fase 4 (Colagem múltipla)

Branch `feature/fase-4-colagem`. Rode com `⌘R` no Xcode.

> **Esta fase não fecha com a suíte verde.** A suíte cobre lógica pura —
> `MultiPaste`, `MarkedSelection`, os separadores. Nada em `Views/` ou
> `Window/` tem teste automatizado: nem os atalhos de teclado, nem o card, nem
> a barra do topo, nem o ciclo de vida do painel. As três fases anteriores
> tiveram seus piores defeitos encontrados só aqui, nunca na suíte. Até você
> rodar este roteiro os itens da Fase 4 estão **"implementados e revisados"**,
> não **"concluídos"** — é a mesma distinção que o ROADMAP usa para as fases
> anteriores nesse mesmo estado.

⚠️ = falha **em silêncio**: sem erro, sem log, sem nada na tela. Se não
conferir de propósito, passa batido.

Anote o que achar estranho mesmo que pareça irrelevante.

---

## A. Marcar e desmarcar

- [ ] **A1 `⌘M` marca o card selecionado.** O chip do rodapé, que hoje mostra
      a ordem do `⌘1`–`⌘9`, vira o número da ordem de marcação, em cor de
      destaque, e a borda do card acompanha.

- [ ] **A2 `⌘M` de novo desmarca.** O chip volta a mostrar o número do
      `⌘1`–`⌘9`.

- [ ] **A3 `⌘M` numa imagem não faz nada; `⌘M` num arquivo não faz nada.**
      Nenhum chip aparece, nenhuma borda muda.

- [ ] **A4 ⚠️ `⌘`+clique numa imagem e `⌘`+clique num arquivo não fazem
      nada.** Nem marcam, nem colam, nem fecham a gaveta. *Este é um bug real
      encontrado em revisão: a versão original colava a imagem em vez de
      ignorar o clique — o `⌘` era lido como um clique comum assim que o item
      não passava no filtro de tipo marcável. Se ao testar você ver a gaveta
      fechar ou algo aparecer no destino depois de `⌘`+clique numa imagem ou
      arquivo, é essa regressão de volta.*

- [ ] **A5 `⌘`+clique num item de texto ou link marca; `⌘`+clique de novo
      desmarca.**

- [ ] **A6 Clique sem `⌘` cola só aquele item, mesmo com outros marcados.**

- [ ] **A7 `⌘3` com três itens marcados cola só o terceiro card, não o
      bloco.** A marcação continua intacta depois.

- [ ] **A8 Menu de contexto.** Mostra "Mark for Multi-Paste" em item de
      texto/URL e não mostra em imagem/arquivo. O rótulo vira "Unmark" quando
      o item já está marcado.

## B. Ordem

- [ ] **B1** Marcar A, B, C nessa ordem e conferir os chips 1, 2, 3.

- [ ] **B2** Marcar em ordem diferente da tela (o terceiro card primeiro) e
      conferir que o chip segue a ordem de marcação, não a posição na lista.

- [ ] **B3** Desmarcar o do meio e conferir que o seguinte renumera de 3 para
      2.

## C. Colar

- [ ] **C1** Marcar 3, `↵`, e conferir os três no destino, na ordem marcada,
      separados por nova linha.

- [ ] **C2** Trocar o separador em Ajustes para cada uma das outras três
      opções (linha em branco, espaço, vírgula) e repetir C1 para cada uma.

- [ ] **C3 ⚠️ Conferir que nenhum card mudou de posição no histórico depois
      da colagem** — o critério que distingue esta fase de todo o resto do
      app. A colagem múltipla registra uso (`lastUsedAt`) sem promover
      (`createdAt` intocado); se algum card subir para o topo da lista, a
      regra quebrou.

- [ ] **C4** Marcar 2 itens formatados (de Word, Notion ou uma página web) e
      conferir a formatação preservada no destino.

- [ ] **C5** Repetir C4 com `⇧↵` e conferir texto plano, sem formatação.

- [ ] **C6** Colar num campo de texto simples (a barra de endereço do
      Safari) e conferir que o texto chega — o caso que um pasteboard só-RTF
      quebraria.

## D. Bordas

- [ ] **D1** Marcar 2 itens, buscar outra coisa, marcar um terceiro, `↵`: os
      três saem na ordem, apesar de dois estarem fora do filtro no momento
      de colar.

- [ ] **D2** Marcar 3, apagar um deles pelo botão × ao passar o mouse sobre o
      card (`⌫` não apaga nada enquanto há marcação — ver D13), colar: o
      bloco sai com dois, sem erro.

- [ ] **D3 ⚠️ Apagar pelo menu de contexto também desmarca e mantém `↵`
      vivo.** Marque um único card com `⌘M` (a pílula mostra "1 marked").
      Clique com o botão direito nesse mesmo card e escolha "Delete" no menu
      — não use `⌫`, o teste é especificamente pelo menu. Confira duas
      coisas: a pílula de contagem sai do "1 marked" (volta a mostrar só a
      lupa, ou o número de `⌘1`–`⌘9` se a busca estiver fechada) **e** `↵`
      ainda cola o card que ficou selecionado no lugar do apagado — não fica
      mudo. *Este é o achado da revisão final da fase: o menu de contexto
      sempre chamou `ItemActions.delete` direto, pulando o `delete(_:)` de
      `OverlayView`, que é onde mora tanto o `marked.remove` quanto a escolha
      de quem herda `selectedID`. Sem o primeiro, o card apagado continua
      marcado nos bastidores — `MultiPaste.resolve` devolve uma lista vazia,
      o handler de `↵` recusa a tecla, e nada acontece, enquanto a pílula
      segue dizendo "1 marked ↵ paste ⎋ clear". Sem o segundo,
      `selectedID` aponta para um item que não existe mais. Os outros dois
      caminhos de apagar — `⌫` e o botão de apagar ao passar o mouse sobre o
      card — já passavam por `delete(_:)` antes desta correção; só o menu de
      contexto ficava de fora.*

- [ ] **D4** `⎋` com marcação ativa limpa a marcação e mantém a gaveta
      aberta; `⎋` de novo fecha a gaveta.

- [ ] **D5** Com busca **e** marcação ativas ao mesmo tempo: primeiro `⎋`
      larga a busca, segundo `⎋` limpa a marcação, terceiro `⎋` fecha a
      gaveta.

- [ ] **D6** Fechar e reabrir a overlay: nada marcado.

- [ ] **D7** Colar um item avulso (sem usar a marcação) com marcação ativa
      em outros cards, reabrir a gaveta: nada marcado.

- [ ] **D8 ⚠️ A pílula de contagem não pode deslocar a barra do topo — barra
      fechada.** Com a busca **fechada** (só a lupa aparece), marque um item
      com `⌘M`. Observe a lupa: ela tem que **continuar exatamente onde
      estava**, centralizada na barra. Desmarque (`⌘M` de novo): a lupa
      continua no lugar. *Este é o inverso de um bug de revisão: a pílula
      original usava um `Spacer` que tornava a barra inteira "gulosa",
      empurrando a lupa para a esquerda assim que a contagem saía de zero. O
      conserto foi tirar a pílula do fluxo da `HStack` e sobrepô-la por cima
      (`overlay(alignment: .trailing)`), mas ninguém rodou a GUI para
      confirmar — isto foi raciocinado a partir da semântica de layout do
      SwiftUI, não observado.*

- [ ] **D9 ⚠️ A pílula de contagem não pode deslocar a barra do topo — barra
      aberta.** Abra a busca (`⌘F`) e marque um item. Observe o campo de
      busca: ele tem que continuar centralizado e do mesmo tamanho, sem
      encolher nem se mover para a esquerda quando a pílula aparece.
      Desmarque e confirme que nada mudou. Repita marcando 2 ou 3 itens (a
      contagem muda de "1 marked" para "2 marked" etc.) e confirme que o
      texto mais longo da pílula também não afeta a posição do campo.

- [ ] **D10 A pílula não pode tocar nem sobrepor o campo de busca.** Com a
      busca aberta e pelo menos um item marcado (estado do D9), olhe o
      espaço entre a borda direita do campo de busca e a borda esquerda da
      pílula "N marked". **Critério binário:** as duas bordas se tocam ou se
      cruzam, sim ou não — não precisa medir distância nenhuma, só constatar
      se há contato ou sobreposição. *A folga entre elas foi calculada a
      partir dos números, nunca observada na tela: campo travado em 470pt
      dentro de uma barra cuja largura é a da tela inteira
      (`screen.frame.width`, não um valor fixo — ver
      `OverlayWindowController`), pílula alinhada à direita por cima. Como a
      barra ocupa o monitor inteiro, a folga é proporcionalmente menor em
      telas estreitas; a janela da overlay não é redimensionável pelo
      usuário, então, se houver mais de um monitor à mão, repita a checagem
      no de menor resolução em vez de tentar estreitar a janela.*

- [ ] **D11** Sem nada marcado, o card selecionado mantém a borda de destaque
      de sempre — comportamento inalterado por esta correção.

- [ ] **D12** Marque um item com `⌘M`. A borda de destaque some do card
      selecionado (ele continua selecionado — só não desenha mais a borda) e
      só o(s) card(s) marcado(s) ficam com a borda azul. Marque um segundo e
      um terceiro item: cada um ganha a borda; o card selecionado, se não for
      um deles, segue sem nenhuma.

- [ ] **D13** Com pelo menos um item marcado e a busca **fechada**, aperte
      `⌫`. Nada é apagado — nenhum card some, nenhuma borda muda. *A borda de
      seleção sumiu no D12, e apagar pelo teclado dependia dela para nomear o
      alvo; sem borda, `⌫` foi desligado enquanto durar a marcação. O × ao
      passar o mouse e o "Delete" do menu de contexto continuam funcionando —
      os dois nomeiam o card pelo clique, não pela seleção.*

- [ ] **D14** Com pelo menos um item marcado, abra a busca (`⌘F`). Digite
      algo e aperte `⌫`: apaga um caractere do campo, como sempre. Apague o
      texto todo e, com um filtro de tipo/app/data ativo, aperte `⌫` de novo:
      remove o último token, como sempre. A marcação não muda nada em
      nenhuma das duas.

- [ ] **D15** Com marcação ativa (busca fechada), aperte `⎋` para limpar as
      marcas. Confira que a borda de destaque volta para o card selecionado
      e que `⌫` volta a apagar o item selecionado.

## E. O que pode dar errado

- [ ] **E1 🔴 `⌘M` é o passo mais importante deste roteiro — não pule.** O
      plano desta fase presumiu que `⌘M` estava livre porque o app é
      `LSUIElement` (sem ícone no Dock, sem menu de app visível). Uma
      revisão de código apontou que isso é impreciso: `MyPasteAppApp.swift`
      é um `App` do SwiftUI com uma `Settings` scene, então o AppKit **monta,
      sim,** um menu principal contendo Window > Minimize, cujo atalho é
      `⌘M` — e esse menu recebe a chance de responder ao atalho **antes** da
      cadeia de responders da janela-chave. A leitura estática do código diz
      que isso é inofensivo: o painel da overlay é `.borderless` e não é
      miniaturizável, então o item de menu deveria validar como desabilitado
      e recusar a tecla, deixando-a cair para o handler de `⌘M` da gaveta.
      Mas isso é comportamento de runtime que ninguém verificou até agora.
      **Teste:** abra a gaveta, selecione um card de texto ou link, aperte
      `⌘M`. **Esperado:** o card marca (chip aparece), nada mais acontece.
      **Falha, em qualquer uma destas duas formas:**
      - `⌘M` não faz **nada** — nem marca, nem qualquer outra coisa — porque
        o menu engoliu a tecla antes de ela chegar à gaveta;
      - o app **minimiza alguma coisa** (a própria overlay, a janela de
        Ajustes se estiver aberta, ou qualquer outra janela do processo).
      Se qualquer uma das duas acontecer, o conserto é trocar o atalho de
      marcação para outra combinação — mudança de uma linha em
      `OverlayView.swift`, sem redesenho. Não é motivo para reabrir o plano
      da fase, só para ajustar essa tecla.

- [ ] **E2 Custo de memória de colar 10 itens longos — meça e registre, não
      "observe".** Juntar N `NSAttributedString` num só bloco
      (`MultiPaste.joined`) aloca o bloco inteiro por um instante antes de
      escrevê-lo no pasteboard. Dez itens de texto longo é exatamente o caso
      que ninguém testa sem querer — e a Fase 2.5 já mostrou que a intuição
      sobre custo de memória do SwiftUI erra por ordens de grandeza: um único
      preview de texto longo custou +235MB de CoreAnimation, e só apareceu
      porque alguém mediu. Os dez passos do roteiro guiado
      (`./scripts/memwatch.sh guided`, ver `docs/memory-profiling.md`) cobrem
      navegação e preview; nenhum cobre marcar-e-colar um bloco, então **não
      existe baseline gravada para este cenário específico**. Meça na mão e
      registre o número aqui — isso é o que torna o passo verificável, em vez
      de "observar se tem algo suspeito":

      1. Garanta no histórico pelo menos 10 itens de texto longos (alguns
         milhares de caracteres cada — o mesmo tipo de item da linha "08
         preview de texto longo" na tabela de `docs/memory-profiling.md`).
      2. Com o app parado por uns 15s, rode `./scripts/memwatch.sh start`
         (modo manual — o guiado não tem passo para isto).
      3. `./scripts/memwatch.sh mark antes`, com a gaveta fechada.
      4. Abra a gaveta, marque os 10 itens com `⌘M`, depois
         `./scripts/memwatch.sh mark marcados` (marcados, ainda sem colar).
      5. `↵` para colar o bloco e, imediatamente, `./scripts/memwatch.sh mark
         colado`.
      6. Espere uns 5s parado e `./scripts/memwatch.sh mark colado-mais-5s`.
      7. `./scripts/memwatch.sh stop` para fechar a sessão e ver o relatório.
      8. **Preencha a tabela abaixo** com as colunas TOTAL e MALLOC dos
         quatro marcos, direto do relatório impresso.

      **Aprovado:** TOTAL/MALLOC sobem em `colado` (a junção aloca o bloco
      inteiro por um instante — esperado) e **descem de volta perto do valor
      de `antes`** em `colado-mais-5s`: a alocação era transitória, como se
      espera de um `NSMutableAttributedString` local que não sobrevive à
      função. **Reprovado:** `colado-mais-5s` fica dezenas de MB acima de
      `antes` e não desce — algo do bloco ficou retido depois da colagem, e
      aqui não há nada em tela que justifique reter memória (ao contrário do
      preview, que ao menos mostra algo enquanto está aberto). CoreAnimation
      não deveria se mover nesta ação — colar não rasteriza nada em tela; se
      ele saltar do mesmo jeito que no passo 08 da Fase 2.5, é o mesmo tipo de
      achado se repetindo num lugar novo. Não existe limiar de "normal"
      anterior para este cenário específico: registrar os números é o
      critério de conclusão do passo, e qualquer leitura fora do padrão acima
      é um achado para levar à revisão de branch, não algo para decidir
      sozinho aqui.

      | marco | TOTAL | MALLOC |
      |---|---|---|
      | antes | | |
      | marcados | | |
      | colado | | |
      | colado-mais-5s | | |

- [ ] **E3** Se o crash do `⌘1` reproduzir em qualquer ponto: **parar e
      capturar a stack trace** com Exception Breakpoint. É o bug antigo,
      ainda sem diagnóstico, e a stack é a peça que falta.

---

## Decisões e comportamentos conhecidos — não são pass/fail

Não são bugs a marcar certo/errado — são coisas já observadas em revisão de
código, ou escolhas que ninguém tomou de propósito. Leia e diga se algum
incomoda o suficiente para virar tarefa.

1. **Marcar tudo e apagar tudo trava o `↵` até fechar a gaveta.** Desde esta
   correção `⌫` não apaga mais nada enquanto há marcação (D13), então chegar
   aqui exige o mouse: marque alguns itens e apague **todos eles** pelo botão
   × ao passar o mouse (ou pelo "Delete" do menu de contexto), um a um.
   Depois de o último marcado sumir, `↵` para de fazer qualquer coisa pelo
   resto desta sessão da overlay — nem cola, nem cai de volta para "colar o
   item selecionado". A pílula de contagem continua dizendo "1 marked" (ou o
   que sobrou) mesmo sem nenhum chip visível em nenhum card, porque
   `MarkedSelection` só é limpa por `⎋`, por fechar a gaveta ou por um clique
   sem `⌘` — apagar os itens não passa por nenhum desses caminhos. A
   recuperação é `⎋` (limpa a marcação e mantém a gaveta aberta) ou fechar e
   reabrir a overlay. Isso incomoda o suficiente para virar uma tarefa de
   conserto, ou fica documentado como comportamento conhecido?

2. **Painel de filtros modal** (herdado da Fase 3, sem mudança nesta fase).
   Com ele aberto, o primeiro clique em qualquer lugar da gaveta só o fecha.

3. **`←`/`→` pertencem aos cards** (idem, herdado). Com o campo de busca
   focado, as setas navegam os cards em vez do cursor de texto.
