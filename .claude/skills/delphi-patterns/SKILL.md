---
name: delphi-patterns
description: Coding conventions and patterns for the SimpleORM Delphi project. Automatically loaded when writing or modifying Delphi code.
user-invocable: false
---

# SimpleORM Delphi Patterns

> **Rules are in `.claude/rules/`** — this skill provides patterns and templates, not rules.

## Class Structure Template

```pascal
TSimpleXxx = class(TInterfacedObject, iSimpleXxx)
private
  FField: Type;
public
  constructor Create(aParam: Type);
  destructor Destroy; override;
  class function New(aParam: Type): iSimpleXxx;
end;
```

## Naming Reference

| Element | Convention | Example |
|---------|-----------|---------|
| Unit | `SimpleXxx.pas` | `SimpleDAO.pas` |
| Class | `TSimpleXxx` | `TSimpleDAO` |
| Interface | `iSimpleXxx` (lowercase i) | `iSimpleQuery` |
| Exception | `ESimpleXxx` | `ESimpleValidator` |
| Field | `F` prefix | `FQuery`, `FParams` |
| Parameter | `a` prefix | `aValue`, `aSQL` |
| Local var | `L` prefix (new code) | `LResult` |

## Conditional Compilation Patterns

```pascal
{$IFNDEF CONSOLE}    // UI code (forms, bindings)
{$IFDEF FMX}         // FireMonkey specific
{$IFDEF VCL}         // VCL specific
{$IF RTLVERSION > 31.0}  // Newer Delphi features
```

## Uses Clause Organization

```pascal
interface
uses
  // 1. SimpleORM units
  SimpleInterface, SimpleTypes,
  // 2. System units
  System.SysUtils, System.Classes, System.Generics.Collections,
  // 3. Data units
  Data.DB,
  // 4. Conditional UI units
  {$IFNDEF CONSOLE}
    {$IFDEF FMX} FMX.Forms, {$ELSE} Vcl.Forms, {$ENDIF}
  {$ENDIF}
  // 5. Driver-specific units last
  FireDAC.Comp.Client;
```

## Error Handling Template

```pascal
try
  FQuery.ExecSQL;
except
  on E: Exception do
  begin
    if FTransaction.Active then
      FTransaction.Rollback;
    raise;
  end;
end;
```

## Destructor Template

```pascal
destructor TSimpleXxx.Destroy;
begin
  FreeAndNil(FOwnedObject1);
  FreeAndNil(FOwnedObject2);
  // Interface fields: do NOT free (auto-managed)
  inherited;
end;
```

## RTTI Helper Methods

Use helpers from `SimpleRTTIHelper.pas`:
- Portuguese (legacy): `EhChavePrimaria`, `EhChaveEstrangeira`, `EhCampo`, `Tem<T>`
- English (new): `IsNotNull`, `IsIgnore`, `IsAutoInc`, `IsHasOne`, `HasFormat`
