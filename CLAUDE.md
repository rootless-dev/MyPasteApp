# MyPasteApp — instruções do projeto

## Board no Obsidian — regra obrigatória

O acompanhamento do roadmap vive num board do plugin Kanban do Obsidian,
acessado pelo MCP `mcp-tools-istefox`. **Todo agente — o principal e qualquer
subagente — atualiza o board ao concluir uma unidade de trabalho.** Não é
opcional e não espera o fim da fase: o board é o painel em tempo real do Carlos,
e atualizá-lo só no fim o transforma em registro histórico.

**Arquivos:**

- `MyPasteApp/Board.md` — colunas `📥 Backlog` · `📝 Spec` · `🛠 Implementando` ·
  `🔍 Revisão` · `⤴ Merge` · `✅ Concluído`
- `MyPasteApp/Base.md` — fatos do código que atravessam o roadmap
- `MyPasteApp/itens/<NN> <nome>.md` — um card por item ou tarefa, com frontmatter
  `item`, `fase`, `status`, `branch`, `depende_de`

**Como atualizar:**

1. Mover o link `[[nome do card]]` para a coluna nova em `Board.md`
2. Atualizar `status` no frontmatter do card correspondente
3. Os dois passos sempre juntos — board e card fora de sincronia é pior que
   nenhum dos dois

**Quando mover:**

| Momento | Coluna |
|---|---|
| Tarefa despachada / implementação começou | `🛠 Implementando` |
| Implementação pronta com suíte verde e revisão limpa | `🔍 Revisão` |
| Branch mergeada | `✅ Concluído` |

Se o card ainda não existe, crie-o em `MyPasteApp/itens/` no mesmo formato dos
que já estão lá, antes de mover.

**Ferramentas:** `mcp__mcp-tools-istefox__get_vault_file`,
`create_vault_file`, `patch_vault_file`, `list_vault_files`. Se estiverem
deferidas, carregue com `ToolSearch` numa única chamada.

## Testes

A suíte cobre **lógica pura** — nada em `Views/` ou `Window/` tem teste
automatizado. Comando completo:

```bash
set -o pipefail && NSUnbufferedIO=YES xcodebuild test \
  -project MyPasteApp.xcodeproj -scheme MyPasteApp \
  -configuration Debug -destination 'platform=macOS'
```

Uma suíte só: acrescente `-only-testing:MyPasteAppTests/<NomeDaSuite>`.

Nenhuma fase fecha sem o Carlos exercitar a GUI à mão — a suíte verde é
condição necessária, nunca suficiente.

## Commits

Nunca commitar sem autorização explícita do Carlos, exceto quando ele autorizar
a branch inteira de uma fase. Mensagens em inglês, Conventional Commits, blocos
por funcionalidade. Nunca `git add -A` nem `git add .`: `ROADMAP.md`,
`DESIGN.md` e `design-refs/` são documentos de trabalho local, excluídos via
`.git/info/exclude`.

## Estrutura do projeto

`PBXFileSystemSynchronizedRootGroup`: arquivos novos entram no alvo por
existirem no diretório. Não há `project.pbxproj` para editar ao criar um arquivo.

Specs e planos das fases ficam em `docs/superpowers/`.
