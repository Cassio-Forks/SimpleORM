# CLAUDE.md — docs/

Regras para documentacao do projeto.

## Estrutura

```
docs/
  plans/    — Design docs e planos de implementacao
```

## Plans

### Design Docs (`YYYY-MM-DD-<topic>-design.md`)

Criados durante a fase de brainstorming. Contem:
- Goal (1 frase)
- Architecture (2-3 frases)
- Components (descricao tecnica de cada componente)
- Data Flow (diagrama ASCII ou descricao)
- Dependencies

### Implementation Plans (`YYYY-MM-DD-<topic>-plan.md`)

Criados apos aprovacao do design. Contem:
- Header com Goal, Architecture, Tech Stack
- Tasks numeradas com:
  - Files (Create/Modify/Test)
  - Steps com codigo completo
  - Comandos de commit

Regras:
- Cada task e independente o suficiente para ser executada por um subagent
- Codigo nos steps deve ser completo e compilavel (nao usar pseudocodigo)
- Paths de arquivo devem ser exatos
- Mensagens de commit seguem Conventional Commits: `feat:`, `fix:`, `docs:`

## CHANGELOG.md (raiz)

- Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
- Secoes: Added, Fixed, Changed, Deprecated, Removed
- **OBRIGATORIO**: documentar toda mudanca ANTES do commit
- Escrever em portugues sem acentos
- Cada item com **negrito** no nome da feature + descricao breve
- Referenciar nomes de arquivos quando relevante (`SimpleXxx.pas`)

## Convencoes de Escrita

- Portugues sem acentos para evitar problemas de encoding
- Nomes tecnicos em ingles (classes, metodos, atributos)
- Ser conciso — 1 frase por item no CHANGELOG
