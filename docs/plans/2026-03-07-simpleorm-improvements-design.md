# SimpleORM Improvements & New Features - Design Document

**Date:** 2026-03-07
**Scope:** Full overhaul (Approach C)

---

## 1. Correcoes Criticas de Seguranca e Estabilidade

### 1.1 SQL Injection em Delete(aField, aValue)
- Refatorar `SimpleDAO.pas:130-149` para usar query parametrizada
- Seguir padrao de `Find(aKey, aValue)` que usa `:param`

### 1.2 Excecoes engolidas nos drivers
- `SimpleQueryFiredac.pas`: Re-lancar excecao apos rollback no ExecSQL
- Adicionar tratamento de erro em UniDAC, Zeos e RestDW

### 1.3 EndTransaction sem retorno
- `SimpleQueryFiredac.pas:67` deve retornar `Result := Self`

### 1.4 NotNull para Integer
- Criar atributo `NotZero` separado
- `NotNull` em Integer nao trata mais 0 como nulo

---

## 2. Transacoes em todos os drivers

### Interface expandida
```pascal
iSimpleQuery = interface
  function StartTransaction: iSimpleQuery;
  function Commit: iSimpleQuery;
  function Rollback: iSimpleQuery;
  function &EndTransaction: iSimpleQuery; // alias para Commit
  function InTransaction: Boolean;
end;
```

- Implementar nos 4 drivers (FireDAC, RestDW, UniDAC, Zeos)
- Remover auto-start do construtor FireDAC
- Flag `AutoTransaction` default `True` para retrocompatibilidade

---

## 3. Paginacao

### Interface
```pascal
iSimpleDAOSQLAttribute<T> = interface
  function Skip(aValue: Integer): iSimpleDAOSQLAttribute<T>;
  function Take(aValue: Integer): iSimpleDAOSQLAttribute<T>;
end;
```

### SQL por database
| Database | SQL |
|----------|-----|
| MySQL/SQLite | `LIMIT {take} OFFSET {skip}` |
| Firebird | `FIRST {take} SKIP {skip}` (apos SELECT) |
| Oracle | `OFFSET {skip} ROWS FETCH NEXT {take} ROWS ONLY` |

### SQLType propagado
- `TSQLType` como propriedade de `iSimpleQuery`
- DAO le do query e passa ao SQL generator

---

## 4. Relacionamentos

### Atributos expandidos
```pascal
HasOne = class(Relationship)
  constructor Create(const aEntityName, aForeignKey: string);
end;

BelongsTo = class(Relationship)
  constructor Create(const aEntityName, aForeignKey: string);
end;

HasMany = class(Relationship)
  constructor Create(const aEntityName, aForeignKey: string);
end;
```

### Mecanismo
- `HasOne`/`BelongsTo`: query adicional no Find, eager loading
- `HasMany`/`BelongsToMany`: lazy loading via proxy
- Sem cascading delete/update nesta fase
- Sem N+1 optimization nesta fase

---

## 5. Validacao Completa

### Novos atributos
```pascal
Email = class(TCustomAttribute);
MinValue = class(TCustomAttribute);
MaxValue = class(TCustomAttribute);
Regex = class(TCustomAttribute)
  property Pattern: string;
  property Message: string;
end;
```

### Expansao
- `Format(MaxSize, MinSize)` passa a ser validado (comprimento de strings, range de numeros)
- `NotNull` em Integer nao trata 0 como nulo
- `NotZero` criado para quem precisa impedir valor 0

---

## 6. Unificacao JSON

- Manter `SimpleJSONUtil.pas` como implementacao principal
- Deprecar `SimpleJSON.pas` com diretiva `deprecated`
- Migrar funcionalidades unicas para SimpleJSONUtil

---

## 7. Soft Delete

```pascal
SoftDelete = class(TCustomAttribute)
  property FieldName: string;
end;
```

- `Delete` gera `UPDATE SET campo = 1` quando `SoftDelete` presente
- `Find` adiciona `WHERE campo = 0` automaticamente
- `ForceDelete` para exclusao fisica

---

## 8. Batch Operations

```pascal
function InsertBatch(aList: TObjectList<T>): iSimpleDAO<T>;
function UpdateBatch(aList: TObjectList<T>): iSimpleDAO<T>;
function DeleteBatch(aList: TObjectList<T>): iSimpleDAO<T>;
```

- Executa dentro de transacao unica
- Reutiliza metodos individuais internamente

---

## 9. Query Logging

```pascal
iSimpleQueryLogger = interface
  procedure Log(const aSQL: string; aParams: TParams; aDurationMs: Integer);
end;
```

- Propriedade opcional `Logger` em `iSimpleDAO<T>`
- Implementacao default: `TSimpleQueryLoggerConsole` (OutputDebugString)
- Extensivel pelo usuario
