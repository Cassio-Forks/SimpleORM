---
description: Regras obrigatorias para criacao de entidades mapeadas ao banco de dados. Aplicavel a Entidade.*.pas.
globs: ["samples/Entidades/**/*.pas", "samples/**/Entidade.*.pas", "src/Entidade.*.pas"]
---

# Regras de Mapeamento de Entidades

Toda entidade SimpleORM DEVE seguir estas regras para funcionar com RTTI e DAO.

## Obrigatorio

- `[Tabela('TABLE_NAME')]` no class — OBRIGATORIO, sem isso o DAO nao sabe a tabela
- `[Campo('COLUMN_NAME')]` em toda published property — OBRIGATORIO para mapeamento SQL
- Exatamente UM `[PK]` por entidade — NUNCA zero, NUNCA multiplos
- Properties DEVEM estar na secao `published` — RTTI nao enxerga `public` properties
- Toda property DEVE ter getter/setter explicitos — NUNCA acesso direto ao field
- `constructor Create` e `destructor Destroy; override` DEVEM estar presentes

## Nomenclatura

- Unit: `Entidade.NomeDaEntidade.pas`
- Classe: `TNomeDaEntidade`
- Nomes de coluna `[Campo]`: UPPERCASE por convencao (ex: `'ID_PEDIDO'`)

## AutoInc

- `[AutoInc]` em campos auto-incremento — estes sao EXCLUIDOS do INSERT automaticamente
- NUNCA marcar campo `[AutoInc]` sem que ele seja realmente auto-incremento no banco

## Relationships

- FK property DEVE existir como published property separada para todo relacionamento
- `[HasOne]`/`[BelongsTo]`: carregamento eager (automatico no Find)
- `[HasMany]`: carregamento lazy via `TSimpleLazyLoader<T>` — NUNCA eager

## SoftDelete

- `[SoftDelete('FIELD')]` vai na CLASSE (nao na property)
- Valor: 0 = ativo, 1 = deletado
- NUNCA aplicar SoftDelete como atributo de property

## Ignore

- `[Ignore]` pula a property em TODAS operacoes SQL e serializacao JSON
- Usar para properties computadas ou transientes
