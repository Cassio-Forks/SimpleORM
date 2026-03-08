---
description: Regras obrigatorias de qualidade de codigo Delphi para o projeto SimpleORM. Aplicavel a TODA modificacao de codigo .pas.
globs: ["src/**/*.pas", "samples/**/*.pas"]
---

# Regras de Qualidade de Codigo

Estas regras sao OBRIGATORIAS. Violacoes devem ser corrigidas antes de qualquer commit.

## Nomenclatura

- Units: `SimpleXxx.pas`
- Classes: `TSimpleXxx`
- Interfaces: `iSimpleXxx` (i minusculo, NUNCA `ISimpleXxx`)
- Excecoes: `ESimpleXxx`
- Campos privados: prefixo `F` (ex: `FQuery`, `FParams`)
- Parametros: prefixo `a` (ex: `aValue`, `aSQL`)
- Variaveis locais (codigo novo): prefixo `L` (ex: `LResult`)
- Novos helpers RTTI: SEMPRE em ingles com prefixos `Is`, `Has`, `Get`

## Estrutura de Classe

- SEMPRE herdar de `TInterfacedObject` para classes com interface
- `New` DEVE chamar `Self.Create(...)` — NUNCA `TSimpleXxx.Create(...)`
- `New` DEVE retornar tipo interface (ex: `iSimpleQuery`), NUNCA o tipo classe
- Todos metodos publicos retornam `Self` (fluent interface), exceto getters puros

## Interfaces

- TODAS as interfaces ficam em `SimpleInterface.pas` — NUNCA declarar em outra unit
- Toda interface DEVE ter GUID: `['{GUID}']`
- Palavras reservadas usam `&` escape: `function &End`, `function &EndTransaction`

## Compilacao Condicional

- NUNCA colocar logica de negocio dentro de IFDEFs de UI (`{$IFDEF FMX}`, `{$IFDEF VCL}`)
- Codigo UI envolto em `{$IFNDEF CONSOLE}`
- Recursos novos do Delphi protegidos com `{$IF RTLVERSION > 31.0}`

## Uses Clause

Ordem obrigatoria:
1. Units SimpleORM (`SimpleInterface, SimpleTypes, ...`)
2. Units System (`System.SysUtils, System.Classes, ...`)
3. Units Data (`Data.DB, ...`)
4. Units UI condicionais (`{$IFNDEF CONSOLE}...`)
5. Units driver-specific por ultimo

## Destrutor

- SEMPRE usar `FreeAndNil` para campos owned (nunca `Free` solto em destrutores)
- NUNCA chamar Free em referencias de interface (auto-managed)
- SEMPRE chamar `inherited` ao final do destrutor

## Gerais

- NUNCA usar `with` statements — obscurece ownership e dificulta debug
- NUNCA engolir excecoes silenciosamente — SEMPRE `raise` apos cleanup
- `SysUtils.Format` DEVE ser fully qualified quando `SimpleAttributes.Format` estiver no uses
