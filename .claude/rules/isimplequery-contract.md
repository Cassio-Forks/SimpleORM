---
description: Regras obrigatorias para implementacao de drivers iSimpleQuery. Aplicavel a SimpleQueryXxx.pas.
globs: ["src/SimpleQuery*.pas"]
---

# Regras do Contrato iSimpleQuery

Todo driver que implementa `iSimpleQuery` DEVE seguir TODAS estas regras sem excecao.

## Metodos Obrigatorios

Todo driver DEVE implementar TODOS os 12 metodos:
1. `SQL: TStrings`
2. `Params: TParams`
3. `ExecSQL: iSimpleQuery`
4. `DataSet: TDataSet`
5. `Open(aSQL: String): iSimpleQuery`
6. `Open: iSimpleQuery`
7. `StartTransaction: iSimpleQuery`
8. `Commit: iSimpleQuery`
9. `Rollback: iSimpleQuery`
10. `&EndTransaction: iSimpleQuery`
11. `InTransaction: Boolean`
12. `SQLType: TSQLType`

## Regras de Implementacao

- `ExecSQL` DEVE fazer try/except: Rollback em caso de erro, depois `raise` — NUNCA engolir excecao
- `&EndTransaction` DEVE delegar para `Commit`: `Result := Commit;`
- `StartTransaction` DEVE verificar se ja esta ativa antes de iniciar (`if not InTransaction then ...`)
- `Commit`/`Rollback` DEVEM verificar se transacao esta ativa antes de agir
- `Params` pode usar lazy creation (criar TParams no primeiro acesso)
- `Open` (sem parametro) DEVE atribuir params ao query ANTES de abrir

## Regras de Retorno

- Metodos que retornam `iSimpleQuery` DEVEM retornar `Self` (fluent interface)
- NUNCA retornar `nil` de metodo que retorna `iSimpleQuery`
- `DataSet`, `SQL`, `Params` retornam o componente interno (nao Self)
- `InTransaction` retorna Boolean
- `SQLType` retorna `TSQLType`

## Construtor

- DEVE aceitar connection + `aSQLType: TSQLType = TSQLType.Firebird`
- `New` class function DEVE chamar `Self.Create(...)` e retornar `iSimpleQuery`

## Drivers REST

- Transacoes sao no-ops que retornam Self (REST e stateless)
- `InTransaction` retorna False
- `SQLType` retorna valor padrao (tipicamente `TSQLType.MySQL`)

## Registro

- DEVE ser registrado em `SimpleORM.dpk` (contains) e `SimpleORM.dpr` (uses)
