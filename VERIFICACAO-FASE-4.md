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

- [ ] **D2** Marcar 3, apagar um deles com `⌫`, colar: o bloco sai com dois,
      sem erro.

- [ ] **D3** `⎋` com marcação ativa limpa a marcação e mantém a gaveta
      aberta; `⎋` de novo fecha a gaveta.

- [ ] **D4** Com busca **e** marcação ativas ao mesmo tempo: primeiro `⎋`
      larga a busca, segundo `⎋` limpa a marcação, terceiro `⎋` fecha a
      gaveta.

- [ ] **D5** Fechar e reabrir a overlay: nada marcado.

- [ ] **D6** Colar um item avulso (sem usar a marcação) com marcação ativa
      em outros cards, reabrir a gaveta: nada marcado.

- [ ] **D7 ⚠️ A pílula de contagem não pode deslocar a barra do topo — barra
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

- [ ] **D8 ⚠️ A pílula de contagem não pode deslocar a barra do topo — barra
      aberta.** Abra a busca (`⌘F`) e marque um item. Observe o campo de
      busca: ele tem que continuar centralizado e do mesmo tamanho, sem
      encolher nem se mover para a esquerda quando a pílula aparece.
      Desmarque e confirme que nada mudou. Repita marcando 2 ou 3 itens (a
      contagem muda de "1 marked" para "2 marked" etc.) e confirme que o
      texto mais longo da pílula também não afeta a posição do campo.

- [ ] **D9 A pílula não pode sobrepor o campo de busca.** Com a busca aberta
      e pelo menos um item marcado (estado do D8), olhe a margem entre a
      borda direita do campo de busca e a pílula "N marked". Esperado: uma
      folga visível, sem sobreposição nem encostar. *A margem foi calculada
      a partir dos números — campo travado em 470pt dentro de uma barra de
      largura total da tela, pílula alinhada à direita — mas nunca observada
      na tela. Se a janela do app for redimensionada bem estreita, vale
      repetir esta checagem nesse tamanho também.*

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

- [ ] **E2** Marcar 10 itens de texto longo e colar; observar o app com
      `./scripts/memwatch.sh` se houver suspeita de custo.

- [ ] **E3** Se o crash do `⌘1` reproduzir em qualquer ponto: **parar e
      capturar a stack trace** com Exception Breakpoint. É o bug antigo,
      ainda sem diagnóstico, e a stack é a peça que falta.

---

## Decisões e comportamentos conhecidos — não são pass/fail

Não são bugs a marcar certo/errado — são coisas já observadas em revisão de
código, ou escolhas que ninguém tomou de propósito. Leia e diga se algum
incomoda o suficiente para virar tarefa.

1. **Marcar tudo e apagar tudo trava o `↵` até fechar a gaveta.** Marque
   alguns itens e apague **todos eles** com `⌫`, um a um. Depois de o
   último marcado sumir, `↵` para de fazer qualquer coisa pelo resto desta
   sessão da overlay — nem cola, nem cai de volta para "colar o item
   selecionado". A pílula de contagem continua dizendo "1 marked" (ou o que
   sobrou) mesmo sem nenhum chip visível em nenhum card, porque
   `MarkedSelection` só é limpa por `⎋`, por fechar a gaveta ou por um clique
   sem `⌘` — apagar os itens não passa por nenhum desses caminhos. A
   recuperação é `⎋` (limpa a marcação e mantém a gaveta aberta) ou fechar e
   reabrir a overlay. Isso incomoda o suficiente para virar uma tarefa de
   conserto, ou fica documentado como comportamento conhecido?

2. **Painel de filtros modal** (herdado da Fase 3, sem mudança nesta fase).
   Com ele aberto, o primeiro clique em qualquer lugar da gaveta só o fecha.

3. **`←`/`→` pertencem aos cards** (idem, herdado). Com o campo de busca
   focado, as setas navegam os cards em vez do cursor de texto.
