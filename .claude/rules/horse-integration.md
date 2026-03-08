---
description: Regras obrigatorias para integracao Horse/ExpxHorse com SimpleORM. Aplicavel a SimpleHorseRouter, SimpleQueryHorse, e endpoints Horse.
globs: ["src/SimpleHorse*.pas", "src/SimpleQueryHorse.pas", "src/SimpleSerializer.pas", "samples/horse-integration/**/*.pas"]
---

# Regras de Integracao Horse

## Thread Safety

- `RegisterEntity` DEVE receber `iSimpleQuery` (NUNCA `iSimpleDAO`) — cada request cria seu proprio DAO
- NUNCA compartilhar instancia de `TSimpleDAO` entre requests
- Cada handler de request DEVE criar sua propria instancia de `TSimpleDAO<T>`

## Serializacao

- SEMPRE usar `TSimpleSerializer` para conversao Entity/JSON — NUNCA `TJson`, `DataSetConverter4D`, ou conversao manual
- Chave JSON = valor de `[Campo]` (NUNCA nome da property Delphi)
- `[Ignore]` DEVE ser respeitado na serializacao

## Error Handling em Handlers

- SEMPRE envolver handlers Horse em try/except
- Formato de erro: `Res.Send<TJSONObject>(TJSONObject.Create.AddPair('error', E.Message)).Status(code)`
- SEMPRE verificar nil apos `ParseJSONValue` do body antes de usar
- Status codes: 200 (OK), 201 (Created), 204 (Deleted), 400 (Cancelled/Invalid), 404 (Not Found), 500 (Error)

## QueryHorse (Cliente REST)

- Transacoes sao no-ops — NUNCA depender de transacoes em codigo cliente REST
- Verificar `StatusCode >= 400` e lancar excecao — NUNCA aceitar erro HTTP silenciosamente
- Bearer token via construtor ou metodo `Token()` — NUNCA hardcodar credenciais

## Rotas

- Path padrao = `[Tabela]` lowercased com `/` prefixo
- Para path customizado, usar 3o parametro de `RegisterEntity`
- GET list aceita `?skip=N&take=N` para paginacao
