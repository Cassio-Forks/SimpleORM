---
description: Regras de seguranca obrigatorias — SQL injection, memory leaks, exception handling. Aplicavel a TODO codigo .pas.
globs: ["src/**/*.pas", "samples/**/*.pas"]
---

# Regras de Seguranca

Estas regras sao INVIOLAVEIS. Codigo que viole qualquer regra NUNCA deve ser commitado.

## SQL Injection

- NUNCA concatenar valores do usuario em strings SQL
- SEMPRE usar queries parametrizadas com `:fieldname`
- CORRETO: `FQuery.SQL.Add('WHERE FIELD = :pValue'); FQuery.Params.ParamByName('pValue').Value := aValue;`
- ERRADO: `FQuery.SQL.Add('WHERE FIELD = ' + QuotedStr(aValue));`

## Memory Safety

- Objetos criados com `.Create` DEVEM ser liberados por alguem (owner ou try/finally)
- Referencias de interface (`iSimpleXxx`) sao auto-gerenciadas — NUNCA chamar Free nelas
- `TObjectList<T>.Create` assume `OwnsObjects = True` por padrao
- JSON retornado por `ParseJSONValue` DEVE ser liberado pelo caller
- SEMPRE verificar nil apos `ParseJSONValue` antes de usar o resultado
- Objetos retornados por funcoes: caller DEVE liberar (documentar ownership)

## Exception Handling

- `ExecSQL` DEVE ter try/except: em caso de erro, fazer Rollback e `raise`
- NUNCA engolir excecoes (`except // silent end`) — SEMPRE re-raise apos cleanup
- `JSONToEntity`: DEVE ter try/except para liberar objeto em caso de erro de parse
- `JSONArrayToEntityList`: DEVE ter try/except para liberar lista em caso de erro

## Try/Finally vs Try/Except

- `try/finally` para cleanup de recursos (Free, EnableControls, etc.)
- `try/except` para error recovery com re-raise (`raise;`)
- NUNCA misturar: se precisa de ambos, usar blocos aninhados

## DataSet Operations

- SEMPRE usar `DisableControls`/`EnableControls` em par (try/finally)
- NUNCA deixar dataset em estado editando sem Post/Cancel

## HTTP/REST

- Verificar `StatusCode >= 400` e lancar excecao para erros HTTP
- NUNCA confiar em respostas HTTP sem validar status
