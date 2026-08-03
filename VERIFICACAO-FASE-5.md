# Verificação manual — Fase 5 (Organização)

Branch `feature/fase-5-organizacao`. Rode com `⌘R` no Xcode.

> **Esta fase não fecha com a suíte verde.** A suíte cobre lógica pura —
> `Pinboard`, `PinboardActions`, `PinboardScope`, `RetentionPolicy`,
> `AppRules`. Nada em `Views/` ou `Window/` tem teste automatizado: nem a
> faixa de pílulas, nem o menu de contexto do card, nem os atalhos de
> teclado, nem a poda rodando de verdade contra um relógio adiantado. Quatro
> das cinco fases anteriores tiveram seus piores defeitos encontrados só
> aqui, nunca na suíte. Até você rodar este roteiro os itens da Fase 5 estão
> **"implementados e revisados"**, não **"concluídos"**.

⚠️ = falha **em silêncio**: sem erro, sem log, sem nada na tela. Se não
conferir de propósito, passa batido.

🔴 = pode destruir dados sem desfazer. Não pule, e não rode contra um store
que importa se algo der errado.

Anote o que achar estranho mesmo que pareça irrelevante.

---

## A. Migração do store — eliminatório, rode isto primeiro

Esta fase acrescenta um `@Model` inteiro (`Pinboard`) e três campos novos em
`ClipboardItem` (`pinboard`, `expiresAt`, `keepForever`). O app nunca migrou
um store de verdade — até agora só rodou contra bancos criados do zero pela
própria build em desenvolvimento. **Se este bloco falhar, pare: nada mais no
roteiro importa, porque não sobra histórico para testar em cima.**

O store fica em `~/Library/Application Support/default.store` (mais
`default.store-wal` e `default.store-shm`, quando existirem) — não é
sandboxado, não há um container por bundle ID.

- [ ] **A1 🔴 Abrir com o banco de antes da fase.** Feche o app (menu da
      barra de status → Quit). Restaure, por cima do `default.store` atual,
      uma cópia de backup feita **antes** de qualquer build da branch
      `feature/fase-5-organizacao` ter rodado contra dados reais — Time
      Machine ou uma cópia manual anterior servem; uma cópia feita depois de
      abrir esta branch já pode ter sido migrada e não prova nada. Sem essa
      cópia, este bloco não pode ser executado — pare e providencie uma antes
      de seguir. Abra o app buildado desta branch. **Critério:** o histórico
      aparece completo, com a mesma contagem de itens que o store tinha antes
      de qualquer build da Fase 5 abri-lo.

- [ ] **A2** Itens que estavam fixados (`⌘P`) no store antigo continuam
      fixados (borda/indicador de pin) e continuam à frente da lista, na
      mesma ordem relativa entre si.

- [ ] **A3** Nenhum diálogo de erro de store aparece, nem no app nem no
      Console.app filtrando por `MyPasteApp`. O histórico não fica vazio em
      nenhum momento — nem por um instante antes de popular.

---

## B. A faixa de pílulas

- [ ] **B1** `+` cria uma pílula "Untitled" já selecionada como escopo ativo
      e em edição inline (campo de texto no lugar do rótulo, foco já nele).

- [ ] **B2** Digitar um nome e `↵`: a pílula sai da edição e mostra o nome
      novo.

- [ ] **B3** `+` de novo: a segunda pílula nasce de cor **diferente** da
      primeira — o app escolhe a primeira cor da paleta de oito ainda não
      usada por nenhum board.

- [ ] **B4** `⎋` durante a renomeação sai da edição sem aplicar nada digitado
      e **a pílula continua existindo**, com o nome que tinha antes de entrar
      em edição (ex.: ainda "Untitled" se você não tinha confirmado nome
      nenhum).

- [ ] **B5** Botão direito numa pílula de pinboard: aparecem "Rename",
      "Delete" e as oito cores, cada uma com nome (Red, Orange, Yellow,
      Green, Blue, Purple, Pink, Grey) e não só o quadrado colorido.

- [ ] **B6** Escolher uma cor no menu: a pílula muda de cor na hora, sem
      precisar fechar e reabrir a gaveta.

- [ ] **B7** Excluir uma pílula **vazia**: o item do menu mostra só "Delete",
      sem contagem nenhuma. Coloque 2 ou mais itens num board (menu do card →
      Add to Pinboard) e exclua esse board pelo menu da pílula: o rótulo diz
      "Delete — N items return to the history" (com exatamente 1 item, o
      texto é singular: "Delete — 1 item returns to the history"). Não há
      diálogo de confirmação — a exclusão acontece no clique. Depois de
      excluir, os N itens continuam no Histórico, sem pinboard atribuído.

- [ ] **B8** Abrir a busca (`⌘F`): todas as pílulas perdem o rótulo de texto
      e ficam só com o ponto colorido (ou o ícone de relógio, no caso do
      "History") — nenhuma pílula some da faixa, e o campo de busca não fica
      espremido nem muda de tamanho por causa disso.

---

## C. Escopo

- [ ] **C1** Clicar numa pílula de pinboard: a lista passa a mostrar só os
      itens filiados a ele.

- [ ] **C2** Um pinboard vazio mostra o texto "Empty Pinboard" centralizado
      na área de cards, no lugar da lista.

- [ ] **C3** Buscar (`⌘F`) com um pinboard como escopo ativo: o filtro de
      texto/tipo/app/data se aplica só dentro dos itens desse board, nunca
      trazendo itens de fora dele.

- [ ] **C4** Com a busca ativa dentro de um pinboard: primeiro `⎋` fecha a
      busca e **continua no pinboard** (a lista completa do board volta);
      segundo `⎋` volta ao Histórico; terceiro `⎋` fecha a gaveta.

- [ ] **C5** Marque um ou mais itens (`⌘M`) estando dentro de um pinboard e
      aperte `⎋`: o primeiro `⎋` limpa as marcas e **continua no pinboard**
      — só o `⎋` seguinte é que sai dele para o Histórico.

- [ ] **C6** Feche a gaveta com um pinboard ativo como escopo (hotkey de
      novo, ou clicar fora) e reabra: o escopo volta a ser o Histórico, não o
      pinboard que estava selecionado antes de fechar.

- [ ] **C7** Dentro de um pinboard, `⌘1` cola o primeiro card **visível
      dentro dele** — não o primeiro card do Histórico inteiro, mesmo que
      esse card mais recente esteja fora do board.

---

## D. Retenção

- [ ] **D1** Menu de contexto de um card → "Keep": a entrada correspondente
      ao estado atual do item vem marcada com `✓` (por padrão, "Follow
      global policy").

- [ ] **D2** Escolher "Never expire": a entrada pai do submenu passa a
      mostrar "Keep — never expires" (em vez de só "Keep").

- [ ] **D3** Escolher "Expire in 1 hour": a entrada pai mostra a data e a
      hora **resolvidas** (ex. "Keep — expires 8/3/26, 4:12 PM"), nunca o
      texto "in 1 hour" ecoado de volta.

- [ ] **D4 🔴 A poda ignora as três proteções quando há data de expiração —
      teste isto com o relógio adiantado, não só lendo o código.** A primeira
      passada da poda (`RetentionPolicy.prune`) apaga qualquer item cuja
      `expiresAt` já passou **antes** de olhar se ele está fixado, arquivado
      num pinboard ou marcado "never expire" — as três proteções só valem
      contra a segunda e a terceira passada (idade e `maxItems`), não contra
      esta. **Roteiro:**
      1. Pegue um item e dê as três proteções ao mesmo tempo: fixe-o (`⌘P`),
         arquive-o num pinboard (menu → "Add to Pinboard"), e no mesmo item
         escolha "Keep → Expire in 1 hour". Confirme antes de seguir que as
         três estão realmente ativas: o item aparece fixado (à frente da
         lista, indicador de pin), aparece dentro do pinboard escolhido, e o
         menu "Keep" mostra a data resolvida de expiração em ~1h.
      2. Adiante o relógio do sistema pelo menos 2 horas (Ajustes do Sistema
         → Data e Hora, desligue "Definir automaticamente" para poder mexer
         na hora manualmente).
      3. **A poda só roda no lançamento do app — não há timer periódico.**
         Feche o app pelo menu da barra de status → Quit, e abra de novo.
      4. **Critério:** o item sumiu do Histórico e sumiu do pinboard, apesar
         de estar fixado, arquivado e ter passado por "Keep". Se ele
         continuar em qualquer uma das duas listas, a poda está respeitando
         uma proteção que a data de expiração deveria anular — anote qual das
         três (pin, pinboard ou nenhuma, já que "never expire" é mutuamente
         exclusivo de ter uma data) e em qual lista o item sobreviveu.
      5. Volte o relógio do sistema ao normal ("Definir automaticamente")
         antes de continuar o roteiro — os passos seguintes assumem hora
         correta.

- [ ] **D5** Em Ajustes → History, o botão que antes era "Clear non-pinned
      history" agora é **"Clear history"**, com a legenda "Keeps pinned
      items, items in pinboards, and items set to never expire." Clique
      nele: itens fixados, itens em qualquer pinboard e itens "never expire"
      continuam na lista depois; todo o resto (sem nenhuma das três marcas)
      some.

- [ ] **D6** Crie um item escrito à mão (`⌘N` → digite um texto → salve).
      Ele nasce "never expire" por baixo dos panos, então sobrevive ao "Clear
      history" do D5 — mas **não** nasce fixado: ele não aparece à frente da
      lista, e sim na posição normal por data de criação.

---

## E. Teclado

- [ ] **E1 🔴 `⌃Tab` é o passo mais importante deste bloco — não pule.** Com
      a gaveta aberta e pelo menos dois pinboards criados, aperte `⌃Tab`
      (Control, não Command — Command foi evitado de propósito nesta tecla
      porque a Fase 4 já mostrou que o menu que o AppKit monta para a cena
      `Settings` come atalhos `⌘` antes da gaveta ver a tecla). **Esperado:**
      o escopo avança para o próximo pinboard na faixa. **Se nada
      acontecer** — nem a pílula ativa muda, nem a lista filtra — a tecla
      está sendo engolida pelo sistema ou pela mesma barra de menus que
      capturou o `⌘M` na Fase 4. Nesse caso o conserto é trocar `.tab` por
      `⌥→`/`⌥←` em `OverlayView.onKeyPress` — mudança de uma linha, já
      identificada no código-fonte, sem redesenho.

- [ ] **E2** `⌃⇧Tab` anda para trás no mesmo ciclo — volta ao pinboard
      anterior.

- [ ] **E3** O ciclo passa pelo Histórico (não só pelos pinboards) e não
      pula nenhuma pílula: com N pinboards, são N+1 escopos no total, e
      `⌃Tab` repetido N+1 vezes devolve o escopo ao ponto de partida.

- [ ] **E4 Herdado da Fase 4, ainda sem verificação — não é desta fase.**
      `⌘M` marca um card para colagem múltipla; o risco documentado desde a
      Fase 4 é o mesmo de sempre, o menu Window ▸ Minimize que o AppKit monta
      para a cena `Settings` pode engolir `⌘M` antes da gaveta. Ninguém
      rodou este passo até hoje — `VERIFICACAO-FASE-4.md` registra isso
      textualmente como pendência. Teste: gaveta aberta, card de texto ou
      link selecionado, `⌘M`. Esperado: o card marca (chip aparece), nada
      minimiza. Se falhar, o conserto é da Fase 4 (trocar o atalho de
      marcação), não desta — só registre o resultado aqui.

---

## F. Regras por app

- [ ] **F1** Ajustes → Privacy: se havia exclusões da lista antiga (o campo
      de texto livre de bundle IDs), elas aparecem migradas automaticamente
      na lista nova, cada uma como "Ignore everything".

- [ ] **F2** "Add App…" abre o seletor de aplicativos do sistema (janela
      padrão do Finder/`NSOpenPanel`, partindo de `/Applications`); escolher
      um app o acrescenta à lista, com ícone e nome de exibição corretos.

- [ ] **F3** "Add Password Managers" acrescenta os cinco de uma vez
      (Passwords, Keychain Access, 1Password, Bitwarden, Dashlane — os que
      estiverem instalados mostram ícone próprio, os outros um ícone
      genérico). Clicar de novo não duplica os que já estavam na lista.

- [ ] **F4** Ponha um app em "Capture only" com só "Text" marcado. Copie uma
      **imagem** nesse app: nenhum card novo aparece no histórico.

- [ ] **F5** No mesmo app do F4, ainda com só "Text" marcado, copie um
      **texto**: o card aparece normalmente.

- [ ] **F6** Ponha um app em "Ignore everything" e copie qualquer coisa nele
      (texto, imagem, link): nada aparece no histórico.

---

## Decisões e comportamentos conhecidos — não são pass/fail

Não são bugs a marcar certo/errado — são escolhas já tomadas de propósito, ou
limitações documentadas no código. Leia e diga se algum incomoda o
suficiente para virar tarefa.

1. **Arrastar um card até uma pílula não faz nada.** Não há `onDrop` nem
   `.draggable` ligando `ClipboardCardView` a `PinboardPill` — filiar um item
   a um board só acontece pelo menu de contexto do card ("Add to Pinboard").
   Reordenar ou arquivar por arrastar ficou fora do escopo desta fase.

2. **Um item pertence a um pinboard por vez.** `ClipboardItem.pinboard` é uma
   relação opcional simples, não uma lista — escolher "Move to Pinboard" para
   outro board tira o item do anterior.

3. **A exclusão de pinboard não pede confirmação, por impossibilidade
   técnica, não por descuido.** `OverlayWindowController` fecha a gaveta
   assim que ela perde o foco de janela (`windowDidResignKey`), e um
   `NSAlert` de confirmação vira a janela-chave ao aparecer — o que fecharia
   a própria gaveta por baixo do diálogo, levando busca, marcas e escopo
   junto. O rótulo do menu ("Delete — N items return to the history") existe
   para compensar isso, dizendo a consequência antes do clique em vez de
   confirmar depois dele.

4. **Trocar "Capture only" → "Ignore everything" → "Capture only" no mesmo
   app perde a seleção de tipos anterior.** Voltar para "Capture only" marca
   **todos** os tipos de novo (Text, Links, Images, Files), não os que
   estavam marcados antes de trocar para "Ignore everything". Não há memória
   da seleção anterior.

5. **O bug do `⌘1` (crash com perda de histórico) continua aberto.**
   Registrado desde a Fase 4, sem diagnóstico completo — a investigação foi
   interrompida pela metade e apurou até agora que `prune()`, `QuickPaste` e
   `ClipboardWriter` (código das Fases 1 e 2, não tocado nesta fase) são os
   suspeitos mais prováveis. Não é desta fase e não deveria bloquear o
   fechamento dela, mas se reproduzir durante este roteiro, pare e capture a
   stack trace com um Exception Breakpoint em vez de tentar reproduzir de
   novo sem registrar nada.
