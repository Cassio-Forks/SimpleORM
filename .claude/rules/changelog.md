---
description: Regras obrigatorias para documentacao no CHANGELOG.md. Aplicavel a TODA mudanca de codigo antes de commit.
globs: ["CHANGELOG.md"]
---

# Regras do CHANGELOG

Todo novo recurso, correcao ou modificacao DEVE ser documentado no CHANGELOG.md antes do commit.

## Formato

- Idioma: Portugues SEM acentos (nao usar a, a, e, c — usar a, a, e, c)
- Formato de entrada: `- **NomeBold** - descricao breve`
- Referencia de arquivo: incluir `(NomeArquivo.pas)` quando relevante
- Granularidade: uma linha por mudanca logica (nao por arquivo)

## Secoes

Ordem obrigatoria (incluir apenas secoes com entradas):
1. **Added** — novos arquivos, features, atributos
2. **Changed** — mudancas de comportamento, refatoracoes
3. **Deprecated** — codigo marcado como deprecated
4. **Removed** — codigo removido
5. **Fixed** — correcoes de bugs

## Onde Documentar

- SEMPRE na secao `[Unreleased]`
- Ao fazer release, mover para `[X.Y.Z] - YYYY-MM-DD`

## O Que NAO Documentar

- Mudancas no proprio CHANGELOG.md
- Mudancas em CLAUDE.md, docs/plans/, .claude/
- Mudancas em arquivos de configuracao (.gitignore, .claudeignore)
