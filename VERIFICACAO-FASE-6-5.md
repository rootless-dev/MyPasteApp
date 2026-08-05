# Verificação manual — Fase 6.5 (O preview vira janela)

Branch `feature/fase-6-5-preview-janela`. Rode com `⌘R` no Xcode.

> **Esta fase não fecha com a suíte verde.** A suíte cobre lógica pura —
> `PreviewPlacement` (geometria do bico e do detach) — e mais nada do que a
> fase construiu: `PreviewPanelShape`, `PreviewChrome`, `ItemPreviewPanel` e
> tudo em `PreviewPanelController` que depende de uma janela AppKit real não
> têm teste automatizado. **O bloco A é eliminatório e roda primeiro**: o
> risco central da fase — arrastar o painel ancorado sem derrubar a gaveta
> por baixo — nunca foi exercitado contra um arrasto de verdade, só lido no
> código. Se o passo A1 falhar, o detach é inalcançável e o resto do roteiro
> (blocos B a E) não tem o que testar.

⚠️ = falha **em silêncio**: sem erro, sem log, sem nada na tela. Se não
conferir de propósito, passa batido.

🔴 = risco de perda de estado (um painel solto fecha sem avisar, ou fecha o
errado). Não destrói dados no disco como o 🔴 da Fase 6, mas pode custar o
trabalho de reabrir e reposicionar vários painéis.

Anote o que achar estranho mesmo que pareça irrelevante — inclusive um
comportamento "bom demais" que pode ser sorte de uma corrida específica.

---

## A. Convivência com a gaveta — eliminatório, rode isto primeiro

- [ ] **A1 O passo mais importante do roteiro inteiro.** Abra o preview
      (`Espaço` com um card selecionado) e comece a arrastar o painel pelo
      cabeçalho ou pela faixa ao redor do conteúdo — **solte o botão do mouse
      antes de mover 10pt**, o suficiente para o AppKit começar a sessão de
      arrasto mas pouco demais para `PreviewPanelController.windowDidMove`
      chamar `detachAnchored()`. **Critério:** a gaveta continua aberta
      embaixo do painel depois de soltar. Arrastar uma janela normalmente a
      traz para frente e pode torná-la key window; `becomesKeyOnlyIfNeeded`
      deveria impedir isso, mas nunca foi testado contra um arrasto de
      verdade. **Se a gaveta fechar aqui, pare**: o detach fica inalcançável
      e nada abaixo faz sentido até isso ser corrigido.

- [ ] **A2** Com o painel ancorado ainda aberto, arraste-o de verdade (acima
      do limiar) para soltá-lo da gaveta — ver bloco C para o detach em si.
      Com o painel solto na tela, reabra a gaveta (atalho global). **Critério:**
      abre um **segundo** painel, ancorado, sobre o novo card selecionado; o
      painel solto continua exatamente onde estava, sem se mover nem fechar.

- [ ] **A3 🔴 O outro caso que estava quebrado.** Com os dois painéis na tela
      (um ancorado, um solto), clique dentro de cada um, alternando.
      **Critério:** nenhum clique nos dois fecha a gaveta — nem o clique no
      ancorado, nem o clique no solto, e o painel **ancorado** também continua
      aberto depois do clique no solto. As duas metades falham por motivos
      diferentes: o painel ancorado nunca vira key window (`becomesKeyOnlyIfNeeded`),
      enquanto o solto **vira** de propósito — é o que faz `⌘C`/`⌘W`/`Esc`
      chegarem nele — e tirar o key da gaveta era o que a fechava. Quem segura
      isso agora é a checagem de `owns(_:)` em
      `OverlayWindowController.windowDidResignKey`.

- [ ] **A3b** Logo depois de clicar no painel **solto** (A3), sem clicar em
      mais nada, aperte as setas. **Comportamento esperado, a registrar e não
      um defeito:** a gaveta continua aberta mas **perdeu o teclado** para o
      painel solto, então as setas não navegam mais pelos cards. Clique de
      volta na gaveta. **Critério:** o teclado volta — as setas voltam a
      navegar e o preview ancorado volta a acompanhar a seleção.

- [ ] **A4** `Esc` com o foco no painel ancorado: fecha só ele, gaveta e
      painel solto continuam. `Esc` com o foco no painel solto: fecha só ele,
      gaveta e painel ancorado (se ainda aberto) continuam.

- [ ] **A5** Clique fora de todos (fora da gaveta e de qualquer painel).
      **Critério:** a gaveta e o painel ancorado fecham juntos, como sempre;
      **o painel solto continua na tela** — ele não é "fora", é uma janela
      própria, e o monitor de clique-fora não deve fechá-lo.

- [ ] **A6 A saúde da gaveta depois de tudo isso.** Com um painel solto ainda
      na tela, navegue pela gaveta com as setas. **Critério, dois juntos:** o
      preview **ancorado** continua trocando de card junto com a seleção
      (abra-o de novo se A5 o fechou), e o bico continua apontando para o
      card certo — nada no ciclo de vida do painel solto vazou para o
      ancorado.

- [ ] **A7 ⚠️ A regressão que a correção do A3 poderia ter causado.** Sem
      nenhum painel solto na tela, abra a gaveta e saia do app **pelo teclado**
      (`⌘Tab`), sem clicar em lugar nenhum. **Critério:** a gaveta fecha
      sozinha, como sempre. Repita com um painel **ancorado** aberto e depois
      com um painel **solto** na tela. Este passo existe porque a correção do
      A3 passou a consultar quem virou key window: se essa consulta
      respondesse "é uma janela nossa" quando não há key window nenhuma (o
      caso do `⌘Tab`), a gaveta ficaria aberta atrás do outro app para sempre.

---

## B. O bico

- [ ] **B1** Abra o preview de um card no meio da tira. **Critério:** o
      triângulo do bico aponta exatamente para o centro horizontal do card,
      sem deslocamento visível.

- [ ] **B2** Navegue com as setas por vários cards seguidos. **Critério:** o
      bico acompanha cada novo card em tempo real, sem atraso nem salto para
      a posição errada no meio do caminho.

- [ ] **B3** Selecione o **primeiro** card da tira e o **último**. **Critério
      nos dois:** o painel permanece dentro da tela (não estoura a borda) e o
      bico continua apontando para o card, ainda que próximo do canto.

- [ ] **B4** Role a tira até um card ficar **fora do alcance vertical** do
      painel (perto o bastante da borda da tela para o painel não caber
      acima). **Critério:** o painel se reposiciona (abaixo do card, ou
      centralizado) e o bico some ou aponta de forma condizente — não fica
      apontando para um lugar vazio.

- [ ] **B5** Selecione um card perto de um canto arredondado da gaveta, onde
      o bico não teria como apontar legalmente para ele. **Critério:** o bico
      simplesmente não aparece (corpo do painel sem bico), em vez de desenhar
      torto ou fora do canto.

---

## C. O detach

- [ ] **C1** Repita o gesto de arrastar (acima do limiar de 10pt) pelo
      **cabeçalho** do painel, e separadamente pela **faixa** vazia ao redor
      do conteúdo (fora do cabeçalho, fora da imagem/texto). Faça isso com um
      preview de **imagem**, um de **texto** e um de **arquivo**. **Critério,
      todos:** o painel solta da gaveta e vira janela independente pelos dois
      gestos, nos três tipos de conteúdo.

- [ ] **C2 O pulo de ~12pt.** Observe com atenção o instante exato em que o
      painel solta — é quando ele perde a faixa reservada para o bico
      (`PreviewPlacement.detachedFrame`, `setFrame` chamado de dentro do loop
      modal de arrasto do AppKit). **Critério a registrar, não necessariamente
      um defeito:** o painel encolhe ~12pt verticalmente nesse instante; anote
      se esse encolhimento aparece como um **pulo perceptível** (o painel
      "pisca" ou salta de posição) e se o painel **continua seguindo o
      cursor** normalmente depois do encolhimento, ou se o arrasto trava/
      desalinha por um instante.

- [ ] **C3** Confirme que a gaveta só fecha **depois** de o painel já estar
      promovido a janela independente — não durante o arrasto, não antes.
      **Critério:** não há um instante em que a gaveta já sumiu mas o painel
      ainda não é uma janela solta (o que deixaria o app sem nenhuma janela
      visível por um frame).

- [ ] **C4 ⚠️ Os botões do cabeçalho depois do detach.** O cabeçalho agora
      carrega um `WindowDragGesture` (para arrastar a janela pelo cabeçalho
      inteiro). Num painel **já solto**, clique no ✕ e confirme que fecha o
      painel; reabra outro e clique em "Edit" (se for um preview de imagem) e
      confirme que abre o editor. **Critério:** os dois botões continuam
      clicáveis normalmente — o gesto de arrastar não rouba o clique deles.

---

## D. Ciclo de vida

- [ ] **D1** Feche um painel solto pelos três caminhos, em painéis separados:
      o ✕ do cabeçalho, `⌘W` com o painel em foco, `Esc` com o painel em
      foco. **Critério, os três:** o painel fecha e some da tela.

- [ ] **D2 🔴 O caso que estava quebrado.** Com um painel **ancorado** aberto
      **e** um painel **solto** aberto ao mesmo tempo, clique no ✕ do painel
      **solto**. **Critério:** fecha **só** o solto — o ancorado continua
      exatamente como estava. (Esta é a ordem inversa também vale: ✕ no
      ancorado fecha só o ancorado.)

- [ ] **D3** Solte um painel, mude o foco para outro app (⌘Tab), volte para o
      MyPasteApp e **clique no painel solto** antes de fazer qualquer outra
      coisa, depois aperte `⌘C` (ou copie algo de dentro dele, se aplicável).
      **Critério a registrar com atenção — é onde um bug intermitente
      apareceria:** o teclado responde normalmente. **Anote também se o
      clique foi realmente necessário** para o painel voltar a receber
      teclado, ou se `⌘C` já funcionava assim que o app voltou a ficar
      ativo, sem precisar clicar em nada.

- [ ] **D4** Com um painel solto mostrando um item, apague esse item **na
      gaveta** (menu de contexto do card → Delete, ou `⌫`). **Critério:** o
      painel solto fecha sozinho, sem esperar nenhuma interação nele.

- [ ] **D5** Repita D4, mas apagando o item por **"Clear history"** nas
      Configurações, com o painel solto ainda aberto. **Critério:** o mesmo —
      o painel solto fecha sozinho.

- [ ] **D6 A medição que decide se um teto de painéis é necessário.** Abra
      cinco previews de **texto longo** (o mais extenso que você tiver no
      histórico) e solte todos os cinco como janelas independentes,
      simultaneamente. Abra o Activity Monitor, ache o processo MyPasteApp, e
      observe a memória (coluna "Memory", ou a aba "Memory" do próprio
      Activity Monitor) por pelo menos 30 segundos com os cinco painéis
      parados na tela. **Registre o número absoluto** (em MB) e se ele **sobe
      continuamente** (vazamento) ou **estabiliza** depois do primeiro
      instante. Feche os cinco pelos três caminhos do D1 e confirme se a
      memória **cai** depois de fechados. **O resultado deste passo vai para
      o `ROADMAP.md`** — é ele que decide se a fase precisa de um teto no
      número de painéis soltos ou se cinco (ou mais) é um caso seguro.

---

## E. Privacidade

- [ ] **E1** Com um painel solto aberto mostrando conteúdo reconhecível
      (texto ou imagem específicos), ligue "Ocultar em compartilhamento de
      tela" nas Configurações de Privacidade. Inicie uma gravação de tela (ou
      uma chamada com compartilhamento de tela) incluindo a área do painel
      solto. **Critério:** o painel solto **não aparece** na gravação/
      compartilhamento, exatamente como a gaveta e o painel ancorado já não
      aparecem.

- [ ] **E2** Com a preferência já ligada, abra um **novo** painel solto (a
      partir de um novo detach) enquanto a gravação continua. **Critério:** o
      painel novo também nasce invisível à gravação — `refreshPrivacy()`
      cobre os soltos existentes no momento da mudança, mas o painel que
      nasce depois precisa herdar a política sozinho (todo painel novo lê
      `WindowPrivacy.sharingType()` na criação).

---

## Decisões e comportamentos conhecidos — não são pass/fail

1. **O detach altera o tamanho do painel, sempre pela mesma quantia
   (`ItemPreviewPanel.beakHeight`, 12pt).** Não é ajustável pelo usuário — o
   painel não ganhou uma borda redimensionável nesta fase.
2. **Um painel solto não volta a se ancorar.** `PreviewChrome.isDetached` é
   escrito uma vez e nunca desfeito — fechar e abrir `Espaço` de novo cria um
   painel ancorado novo, não reaproveita o solto.
