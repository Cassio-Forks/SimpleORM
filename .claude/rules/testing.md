---
description: Regras obrigatorias para testes unitarios com DUnit. Aplicavel a todo codigo de teste e novas implementacoes.
globs: ["tests/**/*.pas", "src/**/*.pas"]
---

# Regras de Testes

## Regra Fundamental

Todo novo recurso implementado no SimpleORM DEVE ter cobertura de testes unitarios com DUnit. Sem testes, o recurso NAO esta completo.

## Estrutura de Testes

- Testes ficam em `tests/`
- Entidades de teste em `tests/Entities/TestEntities.pas`
- Mocks em `tests/Mocks/`
- Test runner: `tests/SimpleORMTests.dpr`
- Nomenclatura: `TestSimpleXxx.pas` para testar `SimpleXxx.pas`

## Framework DUnit

- Unit: `TestFramework`
- Classe base: `TTestCase`
- Metodos de teste: `published procedure`
- Registro: `RegisterTest('Grupo', TMinhaClasse.Suite)` na secao `initialization`

## Convencoes de Teste

- Nome do metodo: `Test[Funcionalidade]_[Cenario]_[Resultado]`
  - Exemplo: `TestNotNull_StringEmpty_ShouldFail`
- Sempre usar try/finally para liberar objetos criados no teste
- Um assert principal por teste (asserts auxiliares sao aceitaveis)
- Testar cenarios positivos E negativos

## Asserts DUnit

- `CheckTrue(condition, message)` — verifica booleano
- `CheckFalse(condition, message)` — verifica falso
- `CheckEquals(expected, actual, message)` — verifica igualdade
- `CheckNotNull(obj, message)` — verifica nao-nulo
- `CheckNull(obj, message)` — verifica nulo
- `Fail(message)` — forca falha

## O Que Testar em Cada Unit

| Unit | O que testar |
|------|-------------|
| SimpleAttributes | Construtores, propriedades, GetNumericMask |
| SimpleRTTIHelper | Helpers (IsNotNull, FieldName, EhChavePrimaria, etc.) com entidades decoradas |
| SimpleSQL | INSERT/UPDATE/DELETE/SELECT gerados, paginacao por dialeto, SoftDelete |
| SimpleValidator | Todas as validacoes (NotNull, NotZero, Format, Email, MinValue, MaxValue, Regex) |
| SimpleSerializer | EntityToJSON, JSONToEntity, listas, roundtrip |
| Novo recurso | Comportamento principal + casos limite |

## O Que NAO Fazer

- NUNCA pular testes para "ir mais rapido"
- NUNCA criar testes que dependem de banco de dados real (usar mocks ou entidades em memoria)
- NUNCA criar testes que dependem de ordem de execucao
- NUNCA deixar memory leaks nos testes (usar try/finally)
