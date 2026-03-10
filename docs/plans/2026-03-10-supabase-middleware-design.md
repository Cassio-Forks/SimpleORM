# Supabase Middleware Integration — Design Doc

**Date:** 2026-03-10

## Goal

Criar um driver `TSimpleQuerySupabase` que implementa `iSimpleQuery`, permitindo usar Supabase como backend de banco de dados no SimpleORM, com autenticacao nativa e notificacoes realtime.

## Architecture

Implementacao incremental em 3 fases. O driver converte operacoes SQL do SimpleORM em chamadas REST para a PostgREST API do Supabase (`/rest/v1/`), usando `System.Net.HttpClient` nativo. Auth e um objeto separado (`TSimpleSupabaseAuth`) que gerencia JWT. Realtime usa WebSocket para receber notificacoes de mudancas.

## Decisoes

- HTTP: `System.Net.HttpClient` (nativo Delphi, zero dependencia)
- Filtros Fase 1: apenas `eq` (igualdade)
- Auth: construtor simples (API Key) + construtor com objeto Auth
- Realtime: eventos globais + por entidade, callbacks via `TThread.Synchronize`
- DataSet: `TClientDataSet` (mesmo padrao do `SimpleQueryHorse`)
- Transacoes: no-ops (REST stateless)

## Fase 1 — CRUD Driver

### TSimpleQuerySupabase (`src/SimpleQuerySupabase.pas`)

Implementa `iSimpleQuery`. Converte SQL gerado pelo `TSimpleSQL` em chamadas HTTP:

| SQL                                        | HTTP                                              |
|--------------------------------------------|---------------------------------------------------|
| `INSERT INTO table (fields) VALUES (:p)`   | `POST /rest/v1/table` com body JSON               |
| `UPDATE table SET f=:p WHERE pk=:pk`       | `PATCH /rest/v1/table?pk=eq.valor` com body JSON  |
| `DELETE FROM table WHERE pk=:pk`           | `DELETE /rest/v1/table?pk=eq.valor`               |
| `SELECT fields FROM table WHERE pk=:pk`    | `GET /rest/v1/table?pk=eq.valor&select=fields`    |

Construtores:
- `New(aURL, aAPIKey)` — service_role key, sem RLS
- `New(aURL, aAPIKey, aAuth)` — com Auth para RLS/JWT

Headers obrigatorios:
- `apikey: aAPIKey`
- `Authorization: Bearer <jwt|apikey>`
- `Content-Type: application/json`
- `Prefer: return=representation`

### SQL Parser (metodos privados)

Extrai do SQL gerado pelo SimpleORM:
- Tabela alvo (de `INSERT INTO`, `UPDATE`, `SELECT FROM`, `DELETE FROM`)
- Campos e valores (de `SET`, `VALUES`, `SELECT`)
- Condicao WHERE simples (`campo = :param` → `?campo=eq.valor`)
- Paginacao (`FIRST/SKIP`, `LIMIT/OFFSET` → `?limit=N&offset=N`)

### Response → DataSet

Converte JSON array do Supabase em `TClientDataSet` com campos criados dinamicamente.

## Fase 2 — Auth

### iSimpleSupabaseAuth (em `SimpleInterface.pas`)

```pascal
iSimpleSupabaseAuth = interface
  function SignIn(aEmail, aPassword: String): iSimpleSupabaseAuth;
  function SignUp(aEmail, aPassword: String): iSimpleSupabaseAuth;
  function SignOut: iSimpleSupabaseAuth;
  function RefreshToken: iSimpleSupabaseAuth;
  function Token: String;
  function User: TJSONObject;
  function IsAuthenticated: Boolean;
end;
```

### TSimpleSupabaseAuth (`src/SimpleSupabaseAuth.pas`)

- `POST /auth/v1/token?grant_type=password` para SignIn
- `POST /auth/v1/signup` para SignUp
- Armazena access_token + refresh_token
- Auto-refresh quando token expira (verifica antes de cada request)

## Fase 3 — Realtime

### iSimpleSupabaseRealtime (em `SimpleInterface.pas`)

```pascal
iSimpleSupabaseRealtime = interface
  function Subscribe(aTable: String): iSimpleSupabaseRealtime;
  function Unsubscribe(aTable: String): iSimpleSupabaseRealtime;
  function OnInsert(aCallback: TProc<TSupabaseRealtimeEvent>): iSimpleSupabaseRealtime;
  function OnUpdate(aCallback: TProc<TSupabaseRealtimeEvent>): iSimpleSupabaseRealtime;
  function OnDelete(aCallback: TProc<TSupabaseRealtimeEvent>): iSimpleSupabaseRealtime;
  function OnChange(aTable: String; aCallback: TProc<TSupabaseRealtimeEvent>): iSimpleSupabaseRealtime;
  function Connect: iSimpleSupabaseRealtime;
  function Disconnect: iSimpleSupabaseRealtime;
end;
```

### TSimpleSupabaseRealtime (`src/SimpleSupabaseRealtime.pas`)

- WebSocket: `wss://project.supabase.co/realtime/v1/websocket`
- Protocolo Phoenix Channels (JSON)
- Thread separada para listener
- Callbacks via `TThread.Synchronize` para thread safety

### TSupabaseRealtimeEvent

```pascal
TSupabaseRealtimeEvent = record
  Table: String;
  EventType: TSupabaseEventType; // setInsert, setUpdate, setDelete
  OldRecord: TJSONObject;
  NewRecord: TJSONObject;
end;
```

## Data Flow (Fase 1)

```
App → TSimpleDAO<T>.Insert(Entity)
  → TSimpleSQL<T>.Insert (gera SQL)
  → TSimpleQuerySupabase.SQL.Add(sql)
  → TSimpleQuerySupabase.ExecSQL
    → ParseSQL → extrai tabela, campos, valores
    → Monta JSON body com campos/valores dos Params
    → POST /rest/v1/tabela (via THTTPClient)
    → Headers: apikey + Authorization
    → Verifica StatusCode, raise se >= 400
```

## Dependencies

- `System.Net.HttpClient` — HTTP nativo
- `System.Net.Socket` — WebSocket (Fase 3)
- `System.JSON` — Parse de responses
- `Datasnap.DBClient` — TClientDataSet
