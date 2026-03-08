---
name: delphi-project-structure
description: Delphi project file structure reference — .dpr vs .pas, .dproj, .res, .dfm. Templates for console and VCL projects.
user-invocable: false
---

# Delphi Project Structure

> **Rules are in `.claude/rules/sample-creation.md`** — this skill provides templates and reference.

## File Types

| File | Purpose | Created by |
|------|---------|-----------|
| `.dpr` | Program file — entry point | Developer/Claude |
| `.pas` | Unit file — source code | Developer/Claude |
| `.dproj` | Project config (MSBuild XML) | IDE only |
| `.res` | Compiled resources (binary) | IDE only |
| `.dfm` | Form layout (visual) | IDE only |
| `.groupproj` | Project group | IDE only |

## .dpr vs .pas — Critical Difference

```
.dpr (PROGRAM)                    .pas (UNIT)
─────────────────                 ─────────────────
program MyApp;                    unit MyUnit;

{$APPTYPE CONSOLE}                interface
{$R *.res}                        uses ...;
                                  type ...;
uses
  Unit1 in 'Unit1.pas';          implementation
                                  uses ...;
begin
  // executable code              // implementation code
end.
                                  end.
```

Key differences:
- `.dpr` starts with `program`, `.pas` starts with `unit`
- `.dpr` has executable `begin/end.` block
- `.pas` has `interface/implementation` sections
- `.dpr` uses `in 'path'` syntax for unit paths
- Only `.dpr` has `{$R *.res}` and `{$APPTYPE CONSOLE}`

## Console Application Template

```pascal
program SimpleORMFeature;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Generics.Collections,
  SimpleDAO,
  SimpleInterface,
  SimpleQueryFiredac,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Phys.FB,
  Entidade.Pedido in '..\Entidades\Entidade.Pedido.pas';

var
  LConn: TFDConnection;
  LDAO: iSimpleDAO<TPEDIDO>;
begin
  try
    LConn := TFDConnection.Create(nil);
    try
      LConn.Params.DriverID := 'FB';
      LConn.Params.Database := 'C:\database\MEUBANCO.FDB'; // Ajustar caminho
      LConn.Params.UserName := 'SYSDBA';
      LConn.Params.Password := 'masterkey';
      LConn.Connected := True;

      LDAO := TSimpleDAO<TPEDIDO>.New(
        TSimpleQueryFiredac.New(LConn)
      );

      // === Demonstracao do recurso ===
      Writeln('=== Feature Demo ===');
      // ...

      Writeln('');
      Writeln('Done! Press Enter to exit...');
    finally
      LConn.Free;
    end;
  except
    on E: Exception do
      Writeln('Error: ', E.Message);
  end;
  Readln;
end.
```

## VCL Application Template

```pascal
program SimpleORMFeature;

uses
  Vcl.Forms,
  Principal in 'Principal.pas' {FormPrincipal},
  Entidade.Pedido in '..\Entidades\Entidade.Pedido.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormPrincipal, FormPrincipal);
  Application.Run;
end.
```

## VCL Form Unit Template (.pas)

```pascal
unit Principal;

interface

uses
  Vcl.Forms, Vcl.StdCtrls, Vcl.Controls, System.Classes,
  Data.DB, FireDAC.Comp.Client, System.Generics.Collections,
  SimpleDAO, SimpleInterface, SimpleQueryFiredac;

type
  TFormPrincipal = class(TForm)
    // Components declared here are created by IDE from .dfm
    // Do NOT manually add component declarations
  private
    FDAO: iSimpleDAO<T>;
  public
    procedure AfterConstruction; override;
  end;

var
  FormPrincipal: TFormPrincipal;

implementation

{$R *.dfm}

procedure TFormPrincipal.AfterConstruction;
begin
  inherited;
  // Initialize DAO here
end;

end.
```

## Sample Directory Structure

```
samples/FeatureName/
├── SimpleORMFeature.dpr     ← Claude creates
├── [SimpleORMFeature.dproj] ← IDE generates (do not create)
├── [SimpleORMFeature.res]   ← IDE generates (do not create)
├── [Principal.pas]          ← Claude creates (VCL only)
├── [Principal.dfm]          ← IDE generates (VCL only)
└── README.md                ← Claude creates
```

## README Template

```markdown
# Feature Name Sample

Demonstrates [feature description].

## Prerequisites

- Delphi 10.3+
- [Database/dependency]
- SimpleORM installed (boss or library path)

## Setup

1. Open `SimpleORMFeature.dpr` in Delphi IDE
2. Configure database connection (adjust path in source)
3. Build and run (F9)

## What It Shows

- [Feature 1]
- [Feature 2]
```

## Uses Clause in .dpr — the `in` Syntax

In `.dpr` files, units that are NOT installed in the IDE need the `in 'path'` syntax:

```pascal
uses
  // Installed units (no path needed)
  System.SysUtils,
  Horse,
  SimpleDAO,

  // Non-installed units (need relative path)
  Entidade.Pedido in '..\Entidades\Entidade.Pedido.pas',
  MyLocalUnit in 'SubDir\MyLocalUnit.pas';
```

The `{FormName}` comment after `in` is for form units only:
```pascal
Principal in 'Principal.pas' {FormPrincipal}
```
