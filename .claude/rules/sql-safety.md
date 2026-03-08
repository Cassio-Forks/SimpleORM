---
description: Regras obrigatorias para geracao e execucao de SQL no SimpleORM. Aplicavel a SimpleSQL, SimpleDAO, e drivers.
globs: ["src/SimpleSQL.pas", "src/SimpleDAO.pas", "src/SimpleQuery*.pas", "src/SimpleRTTI.pas"]
---

# Regras de SQL

## Parametrizacao

- SEMPRE usar queries parametrizadas (`:fieldname`) — NUNCA concatenar valores
- Param names DEVEM corresponder ao nome do `[Campo]` ou usar prefixo `p`
- CORRETO: `WHERE FIELD = :pValue` + `Params.ParamByName('pValue').Value := x`
- ERRADO: `WHERE FIELD = ''' + value + ''''`

## AutoInc

- INSERT NUNCA deve incluir campos `[AutoInc]` — `FieldsInsert` do RTTI ja exclui
- NUNCA inserir manualmente um campo auto-incremento

## Field Names

- SEMPRE usar nome do atributo `[Campo]` (via `FieldName` helper) no SQL
- NUNCA usar nome da property Delphi diretamente como nome de coluna

## WHERE Clause

- UPDATE e DELETE DEVEM ter WHERE com PK — NUNCA fazer UPDATE/DELETE sem WHERE
- `TSimpleRTTI.Where` gera `PK_FIELD = :PK_FIELD` automaticamente

## Soft Delete

- `[SoftDelete]` na classe: DELETE gera `UPDATE SET campo = 1` (NUNCA `DELETE FROM`)
- SELECT DEVE auto-filtrar `WHERE campo = 0` quando soft delete esta ativo
- `ForceDelete` ignora soft delete e usa `DELETE FROM` real

## Paginacao

- DEVE respeitar o dialeto do banco (`TSQLType`)
- Firebird: `FIRST/SKIP` apos SELECT
- MySQL/SQLite: `LIMIT/OFFSET` no fim
- Oracle: `OFFSET ROWS FETCH NEXT` no fim
- NUNCA usar sintaxe de um banco em outro

## Transacoes

- Batch operations DEVEM usar `StartTransaction/Commit` com try/except `Rollback`
- SEMPRE verificar `InTransaction` antes de `StartTransaction`
- NUNCA iniciar transacao se ja existe uma ativa
