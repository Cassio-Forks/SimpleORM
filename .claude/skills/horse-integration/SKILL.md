---
name: horse-integration
description: Horse/ExpxHorse integration patterns for SimpleORM — server auto-routing, client REST driver, serialization examples.
user-invocable: false
---

# Horse Integration for SimpleORM

> **Rules are in `.claude/rules/horse-integration.md`** — this skill provides architecture reference and examples.

## Architecture

```
Server Side:
  Entity + iSimpleQuery → TSimpleHorseRouter.RegisterEntity<T> → 5 CRUD routes

Client Side:
  TSimpleQueryHorse.New(URL) → iSimpleQuery → TSimpleDAO<T> (identical to DB code)

Shared:
  TSimpleSerializer — Entity ↔ JSON via RTTI [Campo] attributes
```

## Server: Auto-Registration

```pascal
TSimpleHorseRouter.RegisterEntity<T>(THorse, aQuery);
// Generates: GET /tablename, GET /tablename/:id, POST /tablename,
//            PUT /tablename/:id, DELETE /tablename/:id
```

### Generated Routes

| Method | Route | Status | Response |
|--------|-------|--------|----------|
| GET | /path?skip=N&take=N | 200 | `{"data": [...], "count": N}` |
| GET | /path/:id | 200/404 | JSON object or `{"error": "Not found"}` |
| POST | /path | 201 | Created entity JSON |
| PUT | /path/:id | 200 | Updated entity JSON |
| DELETE | /path/:id | 204 | No body |

### Callbacks

```pascal
TSimpleHorseRouter.RegisterEntity<T>(THorse, LQuery)
  .OnBeforeInsert(procedure(aEntity: TObject; var aContinue: Boolean) begin ... end)
  .OnAfterInsert(procedure(aEntity: TObject) begin ... end)
  .OnBeforeUpdate(procedure(aEntity: TObject; var aContinue: Boolean) begin ... end)
  .OnBeforeDelete(procedure(aId: string; var aContinue: Boolean) begin ... end);
```

## Client: TSimpleQueryHorse

```pascal
// Basic
LDAO := TSimpleDAO<T>.New(TSimpleQueryHorse.New('http://server:9000'));

// With Bearer token
LDAO := TSimpleDAO<T>.New(TSimpleQueryHorse.New('http://server:9000', 'my-token'));

// With custom headers
TSimpleQueryHorse(LQuery).OnBeforeRequest(
  procedure(aHeaders: TStrings) begin
    aHeaders.Values['X-Custom'] := 'value';
  end
);
```

### SQL-to-HTTP Mapping
- `INSERT INTO ...` → POST /tablename
- `UPDATE tablename ...` → PUT /tablename/:pk
- `DELETE FROM tablename ...` → DELETE /tablename/:pk
- `SELECT ... FROM tablename ...` → GET /tablename (or /tablename/:pk)

### Limitations
- Transaction methods are no-ops (REST is stateless)
- `InTransaction` always returns False

## TSimpleSerializer Methods

```pascal
TSimpleSerializer.EntityToJSON<T>(entity): TJSONObject;
TSimpleSerializer.JSONToEntity<T>(json): T;
TSimpleSerializer.EntityListToJSONArray<T>(list): TJSONArray;
TSimpleSerializer.JSONArrayToEntityList<T>(array): TObjectList<T>;
```

## Server Project Template

```pascal
program MyServer;
{$APPTYPE CONSOLE}
uses Horse, SimpleInterface, SimpleQueryFiredac, SimpleHorseRouter,
  FireDAC.Comp.Client, Entidade.MinhaEntidade;
var LConn: TFDConnection;
begin
  LConn := TFDConnection.Create(nil);
  // Configure connection...
  TSimpleHorseRouter.RegisterEntity<TMinhaEntidade>(THorse, TSimpleQueryFiredac.New(LConn));
  THorse.Listen(9000);
end.
```
