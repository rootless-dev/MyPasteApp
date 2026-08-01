# Verificação manual — Fase 3 (Busca)

Branch `feature/fase-3-busca`, 25 commits. Rode com `⌘R` no Xcode.

⚠️ = falha **em silêncio**: sem erro, sem log, sem nada na tela. Se não conferir
de propósito, passa batido.

Anote o que achar estranho mesmo que pareça irrelevante.

> **Leia antes do bloco A.** Os testes de teclado olham **o que está escrito
> dentro do campo de busca**, não a lista de cards. Se você digitar uma
> sequência que não existe no histórico, a lista fica vazia — e isso está
> certo. O que se confere é se as letras chegaram inteiras à cápsula no topo
> da gaveta.

---

## A. Teclado e foco — o bloco mais importante

Três dos defeitos mais sérios da fase estavam aqui, e a suíte não alcança nenhum.

- [ ] **A1 ⚠️ Digitar abre a busca sem perder letra.** Abra a gaveta e digite
      `ghi` em ritmo normal. **Olhe o campo, não a lista.** Esperado: a cápsula
      no topo contém as três letras, `ghi`. A lista de cards ficar vazia é
      normal — provavelmente não há nada no histórico com esse texto.
      *Falha antiga: o campo mostrava `hi` (primeira letra engolida) ou `gih`
      (embaralhado).*
      Se preferir ver as duas coisas de uma vez, digite as primeiras letras de
      algo que você sabe que está no histórico: aí confere o texto no campo
      **e** o filtro funcionando.

- [ ] **A2 ⚠️ Auto-repeat.** Abra a gaveta e **segure** a tecla `a` por um
      segundo. Esperado: o campo enche de `a`, sem embaralhar. De novo: olhe o
      campo, não a lista.

- [ ] **A3 ⚠️ Teclado vivo depois do `esc`.** Busque algo, `esc` para largar a
      busca, e então aperte `→` e digite uma letra. Esperado: a seta move a
      seleção e a letra reabre a busca. *Falha: nada responde — e a gaveta
      continua bonita na tela.*

- [ ] **A4 ⚠️ Teclado vivo depois do `⌘J`.** Busque, aperte `⌘J`, e então `→` e
      uma letra. Mesma expectativa do A3. *Esta rota morria e ninguém tinha
      testado.*

- [ ] **A5 ⚠️ Reabrir depois de trocar de app.** Abra a gaveta, `⌘Tab` para
      outro app, reabra a gaveta pelo atalho e digite. Esperado: a busca abre
      normalmente.

- [ ] **A6 `esc` em dois tempos.** Com texto na busca: o primeiro `esc` larga a
      busca, o segundo fecha a gaveta. Com a busca vazia: um `esc` só fecha
      tudo.

- [ ] **A7 ⚠️ Seleção continua visível depois do `esc`.** Busque algo que
      devolva poucos resultados, selecione o **terceiro**, aperte `esc`.
      Esperado: a lista completa volta **rolada até aquele card**, com ele
      selecionado. *Falha: o card fica fora da tela e `↵`/`⌘C` agem em algo que
      você não vê.*

- [ ] **A8 A gaveta reabre na lupa.** Aperte `⌘F`, `esc`, e reabra a gaveta.
      Esperado: topo mostrando só a lupa, não o campo aberto.

## B. OCR

- [ ] **B1 Screenshot vira pesquisável.** Copie uma screenshot com texto,
      **espere alguns segundos**, abra a gaveta e busque por uma palavra que só
      existe dentro da imagem. Esperado: o card aparece.

- [ ] **B2 Backfill não trava.** Feche e reabra o app com histórico de imagens
      antigas. Esperado: interface responsiva, sem ventilador. Depois busque
      texto de uma imagem antiga.

- [ ] **B3 O desligar respeita o já feito.** Preferências → Privacidade →
      desligue "Recognise text in images". Copie outra screenshot: não deve
      virar resultado. A anterior continua sendo encontrada.

- [ ] **B4 Acento não atrapalha.** Busque `cao` e veja se acha um item com
      `cão`.

## C. Filtros e tokens

- [ ] **C1 Combinação.** Filtre por tipo **imagem** + um app + uma palavra que
      só existe no OCR. Esperado: exatamente o item certo.

- [ ] **C2 `⌫` remove token.** Com o campo de texto vazio e tokens presentes,
      `⌫` remove o último token.

- [ ] **C3 Painel cabe e rola.** Abra o painel de filtros. Esperado: Tipo, Data
      e "Clear filters" **sempre visíveis**; só a lista de apps rola. Com muitos
      apps no histórico, confira que a rolagem do painel funciona e não é
      roubada pela faixa de cards embaixo.

- [ ] **C4 App desconhecido.** Confira que existe a linha "Unknown" para itens
      sem app de origem (os criados por `⌘N`, por exemplo).

- [ ] **C5 Muitos tokens.** Selecione mais de três filtros. Esperado: três
      tokens no campo e um `+N` que abre o painel — o campo de texto não pode
      sumir.

## D. Jump to History

- [ ] **D1** Busque, ache um item, `⌘J`. Esperado: a lista completa volta rolada
      até ele, com ele selecionado.

- [ ] **D2** Sem busca ativa, a entrada "Show in History" **não** aparece no
      menu de contexto, e `⌘J` não faz nada.

## E. Regressão dos atalhos das Fases 1 e 2

Com a busca **aberta** e com ela **fechada**, confira cada um. Nenhum pode
deixar letra solta no campo de busca.

- [ ] **E1** `⌘1`–`⌘9` (Quick Paste) · **E2** `⌘C` · **E3** `⌘P` (fixar)
- [ ] **E4** `⌘E` (editar) · **E5** `⌘R` (renomear) · **E6** `⌘N` (novo item)
- [ ] **E7** `↵` cola · **E8** `⇧↵` cola como texto simples
- [ ] **E9** `␣` abre/fecha o preview · **E10** `←`/`→` navegam os cards
- [ ] **E11** `⌘F` abre a busca

## F. Só uma tecla humana certifica isto

Nenhum harness consegue: o caminho sintético entrega bytes diferentes do teclado
real.

- [ ] **F1 `⌫`** com um card selecionado e a busca **fechada** — tem que apagar
      o card. Com a busca **aberta**, nunca pode apagar card.
- [ ] **F2 `⌘V`** colando dentro do campo de busca.
- [ ] **F3 Tecla morta** — digite `á` ou `ç` para abrir a busca.
- [ ] **F4 A borda da cápsula** na tecla que abre a busca: ela acende no azul de
      foco, ou fica cinza por um instante?
- [ ] **F5 Arrastar com o mouse** para selecionar texto dentro da query.

## G. Link (a regressão mais fácil de não notar)

- [ ] **G1 ⚠️ Recopiar URL offline.** Copie uma URL **com rede** e espere o
      banner aparecer no card. **Desligue o Wi-Fi.** Copie a mesma URL de novo.
      Esperado: o card **mantém** banner, favicon e cor. *Falha: o card fica
      cinza e vazio, e a informação não volta.*

---

## Decisões que ficaram para você

Não são bugs — são escolhas que ninguém tomou de propósito:

1. **Painel de filtros modal.** Com ele aberto, o primeiro clique em qualquer
   lugar da gaveta só o fecha: o campo, os `✕` dos tokens e o botão de filtro
   ficam inertes até lá. Intencional?

2. **`←`/`→` pertencem aos cards.** Com o campo focado, as setas navegam os
   cards, então não dá para mover o cursor dentro da busca sem o mouse.

3. **31ms por tecla.** Medido. O custo não é a busca (3,7ms) e sim o `sorted`
   (29ms), que relê `isPinned`/`createdAt` pelos accessors do SwiftData ~17 mil
   vezes. Hoistar as chaves uma vez corta para ~2ms **sem paginação**.
