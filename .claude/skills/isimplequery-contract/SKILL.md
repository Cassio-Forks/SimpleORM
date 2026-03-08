---
name: isimplequery-contract
description: The exact iSimpleQuery interface contract that all query drivers must implement. Reference for creating or reviewing drivers.
user-invocable: false
---

# iSimpleQuery Interface Contract

> **Rules are in `.claude/rules/isimplequery-contract.md`** — this skill provides the interface definition and usage reference.

## Interface Definition (SimpleInterface.pas)

```pascal
iSimpleQuery = interface
  ['{6DCCA942-736D-4C66-AC9B-94151F14853A}']
  function SQL: TStrings;
  function Params: TParams;
  function ExecSQL: iSimpleQuery;
  function DataSet: TDataSet;
  function Open(aSQL: String): iSimpleQuery; overload;
  function Open: iSimpleQuery; overload;
  function StartTransaction: iSimpleQuery;
  function Commit: iSimpleQuery;
  function Rollback: iSimpleQuery;
  function &EndTransaction: iSimpleQuery;
  function InTransaction: Boolean;
  function SQLType: TSQLType;
end;
```

## Method-by-Method Reference

| Method | Returns | Purpose |
|--------|---------|---------|
| `SQL` | TStrings | Writable SQL text (DAO writes before Open/ExecSQL) |
| `Params` | TParams | Query parameters (DAO writes before Open/ExecSQL) |
| `ExecSQL` | Self | Executes INSERT/UPDATE/DELETE |
| `DataSet` | TDataSet | Query result after Open |
| `Open(aSQL)` | Self | Sets SQL and opens in one call |
| `Open` | Self | Opens with SQL already set |
| `StartTransaction` | Self | Begins transaction (check InTransaction first) |
| `Commit` | Self | Commits active transaction |
| `Rollback` | Self | Rolls back active transaction |
| `&EndTransaction` | Self | Delegates to Commit |
| `InTransaction` | Boolean | True if transaction is active |
| `SQLType` | TSQLType | Database type (Firebird, MySQL, SQLite, Oracle) |

## Constructor Pattern

```pascal
constructor Create(aConnection: TXxxConnection; aSQLType: TSQLType = TSQLType.Firebird);
class function New(aConnection: TXxxConnection; aSQLType: TSQLType = TSQLType.Firebird): iSimpleQuery;
```

## Existing Drivers

| Driver | Connection Type | File |
|--------|----------------|------|
| FireDAC | `TFDConnection` | `SimpleQueryFiredac.pas` |
| UniDAC | `TUniConnection` | `SimpleQueryUnidac.pas` |
| Zeos | `TZConnection` | `SimpleQueryZeos.pas` |
| RestDW | `TRESTDWClientSQL` | `SimpleQueryRestDW.pas` |
| Horse (REST) | HTTP URL string | `SimpleQueryHorse.pas` |

## How TSimpleDAO Uses iSimpleQuery

1. DAO writes SQL to `query.SQL`
2. DAO writes params to `query.Params`
3. For SELECT: calls `query.Open` then reads `query.DataSet`
4. For INSERT/UPDATE/DELETE: calls `query.ExecSQL`
5. Batch operations: `query.StartTransaction` → operations → `query.Commit` (or Rollback on error)
