# Built-in Skills Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Adicionar 5 novas Skills deterministicas built-in (TSkillTimestamp, TSkillGuardDelete, TSkillHistory, TSkillValidate, TSkillWebhook) ao SimpleORM.

**Architecture:** Todas as Skills ficam em `src/SimpleSkill.pas` junto com as 3 existentes. Cada Skill implementa `iSimpleSkill` (interface definida em `SimpleInterface.pas`). Testes em `tests/TestSimpleSkill.pas`. Exception nova `ESimpleGuardDelete` declarada em `SimpleSkill.pas`.

**Tech Stack:** Delphi Object Pascal, RTTI (`System.Rtti`), DUnit (`TestFramework`), `System.Net.HttpClient` (TSkillWebhook), `SimpleSerializer` (TSkillWebhook), `SimpleValidator` (TSkillValidate)

---

### Task 1: TSkillTimestamp

**Files:**
- Modify: `src/SimpleSkill.pas`
- Modify: `tests/TestSimpleSkill.pas`

**Step 1: Write the failing tests**

Adicionar em `tests/TestSimpleSkill.pas` na secao `interface`, apos `TTestSkillContext`:

```pascal
  TTestSkillTimestamp = class(TTestCase)
  published
    procedure TestTimestamp_SetsPropertyValue;
    procedure TestTimestamp_IgnoresMissingProperty;
    procedure TestTimestamp_Name;
    procedure TestTimestamp_RunAt;
  end;
```

Adicionar na secao `implementation`, antes do bloco `initialization`:

```pascal
{ TTestSkillTimestamp }

procedure TTestSkillTimestamp.TestTimestamp_SetsPropertyValue;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TTestTimestampEntity;
begin
  LEntity := TTestTimestampEntity.Create;
  try
    LSkill := TSkillTimestamp.New('DataCriacao', srBeforeInsert);
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ENTITY_TIMESTAMPS', 'INSERT');
    CheckEquals(0, LEntity.DataCriacao, 'Should start at zero');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(LEntity.DataCriacao > 0, 'Should have set datetime value');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillTimestamp.TestTimestamp_IgnoresMissingProperty;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TTestTimestampEntity;
begin
  LEntity := TTestTimestampEntity.Create;
  try
    LSkill := TSkillTimestamp.New('CAMPO_INEXISTENTE', srBeforeInsert);
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Should not raise error for missing property');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillTimestamp.TestTimestamp_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillTimestamp.New('DataCriacao');
  CheckEquals('timestamp', LSkill.Name, 'Should return timestamp');
end;

procedure TTestSkillTimestamp.TestTimestamp_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillTimestamp.New('DataAtualizacao', srBeforeUpdate);
  CheckTrue(LSkill.RunAt = srBeforeUpdate, 'Should return configured RunAt');
end;
```

Adicionar no bloco `initialization`:

```pascal
  RegisterTest('Skills', TTestSkillTimestamp.Suite);
```

Adicionar `TestEntities` ao uses da secao `implementation` de `TestSimpleSkill.pas` (necessario para `TTestTimestampEntity`):

```pascal
uses
  TestEntities;
```

**Step 2: Verify tests fail**

Compilar o projeto de testes. Esperado: erro de compilacao pois `TSkillTimestamp` nao existe ainda.

**Step 3: Implement TSkillTimestamp**

Adicionar em `src/SimpleSkill.pas` na secao `type`, apos `TSkillAudit`:

```pascal
  { Built-in: TSkillTimestamp }
  TSkillTimestamp = class(TInterfacedObject, iSimpleSkill)
  private
    FFieldName: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aFieldName: String; aRunAt: TSkillRunAt = srBeforeInsert);
    destructor Destroy; override;
    class function New(const aFieldName: String; aRunAt: TSkillRunAt = srBeforeInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

Adicionar na secao `implementation`, apos `TSkillAudit.RunAt`:

```pascal
{ TSkillTimestamp }

constructor TSkillTimestamp.Create(const aFieldName: String; aRunAt: TSkillRunAt);
begin
  FFieldName := aFieldName;
  FRunAt := aRunAt;
end;

destructor TSkillTimestamp.Destroy;
begin
  inherited;
end;

class function TSkillTimestamp.New(const aFieldName: String; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aFieldName, aRunAt);
end;

function TSkillTimestamp.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  Result := Self;
  if aEntity = nil then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);
  LProp := LType.GetProperty(FFieldName);
  if LProp <> nil then
    LProp.SetValue(aEntity, TValue.From<TDateTime>(Now));
end;

function TSkillTimestamp.Name: String;
begin
  Result := 'timestamp';
end;

function TSkillTimestamp.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;
```

**Step 4: Verify tests pass**

Compilar e executar testes. Esperado: 4 testes passando para TTestSkillTimestamp.

**Step 5: Commit**

```bash
git add src/SimpleSkill.pas tests/TestSimpleSkill.pas
git commit -m "feat: add TSkillTimestamp built-in skill"
```

---

### Task 2: TSkillGuardDelete

**Files:**
- Modify: `src/SimpleSkill.pas`
- Modify: `tests/TestSimpleSkill.pas`

**Step 1: Write the failing tests**

Adicionar em `tests/TestSimpleSkill.pas` na secao `interface`:

```pascal
  TTestSkillGuardDelete = class(TTestCase)
  published
    procedure TestGuardDelete_Name;
    procedure TestGuardDelete_RunAtIsAlwaysBeforeDelete;
    procedure TestGuardDelete_NilEntity_NoError;
    procedure TestGuardDelete_NilQuery_NoError;
  end;
```

Adicionar na secao `implementation`:

```pascal
{ TTestSkillGuardDelete }

procedure TTestSkillGuardDelete.TestGuardDelete_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillGuardDelete.New('ITEM_PEDIDO', 'ID_PEDIDO');
  CheckEquals('guard-delete', LSkill.Name, 'Should return guard-delete');
end;

procedure TTestSkillGuardDelete.TestGuardDelete_RunAtIsAlwaysBeforeDelete;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillGuardDelete.New('ITEM_PEDIDO', 'ID_PEDIDO');
  CheckTrue(LSkill.RunAt = srBeforeDelete, 'Should always be srBeforeDelete');
end;

procedure TTestSkillGuardDelete.TestGuardDelete_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillGuardDelete.New('ITEM_PEDIDO', 'ID_PEDIDO');
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'DELETE');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Should not raise error for nil entity');
end;

procedure TTestSkillGuardDelete.TestGuardDelete_NilQuery_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
begin
  LEntity := TPedidoTest.Create;
  try
    LEntity.ID := 1;
    LSkill := TSkillGuardDelete.New('ITEM_PEDIDO', 'ID_PEDIDO');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'DELETE');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Should not raise error when query is nil');
  finally
    LEntity.Free;
  end;
end;
```

Adicionar no bloco `initialization`:

```pascal
  RegisterTest('Skills', TTestSkillGuardDelete.Suite);
```

**Step 2: Verify tests fail**

Compilar. Esperado: erro de compilacao pois `TSkillGuardDelete` e `ESimpleGuardDelete` nao existem.

**Step 3: Implement TSkillGuardDelete**

Adicionar exception em `src/SimpleSkill.pas` na secao `type`, apos os uses, antes de `TSimpleSkillContext`:

```pascal
  ESimpleGuardDelete = class(Exception);
```

Adicionar classe apos `TSkillTimestamp`:

```pascal
  { Built-in: TSkillGuardDelete }
  TSkillGuardDelete = class(TInterfacedObject, iSimpleSkill)
  private
    FTable: String;
    FFKField: String;
  public
    constructor Create(const aTable, aFKField: String);
    destructor Destroy; override;
    class function New(const aTable, aFKField: String): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

Implementacao:

```pascal
{ TSkillGuardDelete }

constructor TSkillGuardDelete.Create(const aTable, aFKField: String);
begin
  FTable := aTable;
  FFKField := aFKField;
end;

destructor TSkillGuardDelete.Destroy;
begin
  inherited;
end;

class function TSkillGuardDelete.New(const aTable, aFKField: String): iSimpleSkill;
begin
  Result := Self.Create(aTable, aFKField);
end;

function TSkillGuardDelete.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LPKValue: Variant;
  LCount: Integer;
begin
  Result := Self;
  if (aEntity = nil) or (aContext.Query = nil) then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);

  LProp := LType.GetPKField;
  if LProp = nil then
    Exit;

  LPKValue := LProp.GetValue(aEntity).AsVariant;

  aContext.Query.SQL.Clear;
  aContext.Query.SQL.Add('SELECT COUNT(*) FROM ' + FTable + ' WHERE ' + FFKField + ' = :pValue');
  aContext.Query.Params.ParamByName('pValue').Value := LPKValue;
  aContext.Query.Open;
  try
    LCount := aContext.Query.DataSet.Fields[0].AsInteger;
  finally
    aContext.Query.DataSet.Close;
  end;

  if LCount > 0 then
    raise ESimpleGuardDelete.Create('Cannot delete: ' + IntToStr(LCount) +
      ' dependent records found in ' + FTable);
end;

function TSkillGuardDelete.Name: String;
begin
  Result := 'guard-delete';
end;

function TSkillGuardDelete.RunAt: TSkillRunAt;
begin
  Result := srBeforeDelete;
end;
```

**Step 4: Verify tests pass**

Compilar e executar testes. Esperado: 4 testes passando para TTestSkillGuardDelete.

**Step 5: Commit**

```bash
git add src/SimpleSkill.pas tests/TestSimpleSkill.pas
git commit -m "feat: add TSkillGuardDelete built-in skill"
```

---

### Task 3: TSkillHistory

**Files:**
- Modify: `src/SimpleSkill.pas`
- Modify: `tests/TestSimpleSkill.pas`

**Step 1: Write the failing tests**

Adicionar em `tests/TestSimpleSkill.pas` na secao `interface`:

```pascal
  TTestSkillHistory = class(TTestCase)
  published
    procedure TestHistory_Name;
    procedure TestHistory_RunAt;
    procedure TestHistory_NilEntity_NoError;
    procedure TestHistory_NilQuery_NoError;
  end;
```

Adicionar na secao `implementation`:

```pascal
{ TTestSkillHistory }

procedure TTestSkillHistory.TestHistory_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillHistory.New;
  CheckEquals('history', LSkill.Name, 'Should return history');
end;

procedure TTestSkillHistory.TestHistory_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillHistory.New('ENTITY_HISTORY', srBeforeDelete);
  CheckTrue(LSkill.RunAt = srBeforeDelete, 'Should return configured RunAt');
end;

procedure TTestSkillHistory.TestHistory_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillHistory.New;
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'UPDATE');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Should not raise error for nil entity');
end;

procedure TTestSkillHistory.TestHistory_NilQuery_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
begin
  LEntity := TPedidoTest.Create;
  try
    LSkill := TSkillHistory.New;
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'UPDATE');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Should not raise error when query is nil');
  finally
    LEntity.Free;
  end;
end;
```

Adicionar no bloco `initialization`:

```pascal
  RegisterTest('Skills', TTestSkillHistory.Suite);
```

**Step 2: Verify tests fail**

Compilar. Esperado: erro de compilacao.

**Step 3: Implement TSkillHistory**

Adicionar classe em `src/SimpleSkill.pas` apos `TSkillGuardDelete`:

```pascal
  { Built-in: TSkillHistory }
  TSkillHistory = class(TInterfacedObject, iSimpleSkill)
  private
    FHistoryTable: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aHistoryTable: String = 'ENTITY_HISTORY'; aRunAt: TSkillRunAt = srBeforeUpdate);
    destructor Destroy; override;
    class function New(const aHistoryTable: String = 'ENTITY_HISTORY'; aRunAt: TSkillRunAt = srBeforeUpdate): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

Implementacao:

```pascal
{ TSkillHistory }

constructor TSkillHistory.Create(const aHistoryTable: String; aRunAt: TSkillRunAt);
begin
  FHistoryTable := aHistoryTable;
  FRunAt := aRunAt;
end;

destructor TSkillHistory.Destroy;
begin
  inherited;
end;

class function TSkillHistory.New(const aHistoryTable: String; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aHistoryTable, aRunAt);
end;

function TSkillHistory.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LRttiContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LPKProp: TRttiProperty;
  LPKValue: String;
  LValue: TValue;
  LValueStr: String;
  LSQL: String;
begin
  Result := Self;
  if (aEntity = nil) or (aContext.Query = nil) then
    Exit;

  LRttiContext := TRttiContext.Create;
  LType := LRttiContext.GetType(aEntity.ClassType);

  LPKProp := LType.GetPKField;
  if LPKProp = nil then
    Exit;

  LPKValue := LPKProp.GetValue(aEntity).AsVariant;

  LSQL := 'INSERT INTO ' + FHistoryTable +
    ' (ENTITY_NAME, RECORD_ID, FIELD_NAME, OLD_VALUE, OPERATION, CREATED_AT)' +
    ' VALUES (:pEntity, :pRecordId, :pField, :pOldValue, :pOperation, :pCreatedAt)';

  for LProp in LType.GetProperties do
  begin
    if LProp.IsIgnore then
      Continue;
    if not LProp.EhCampo then
      Continue;

    LValue := LProp.GetValue(aEntity);
    if LValue.Kind = tkFloat then
    begin
      if (LValue.TypeInfo = TypeInfo(TDateTime)) or
         (LValue.TypeInfo = TypeInfo(TDate)) or
         (LValue.TypeInfo = TypeInfo(TTime)) then
        LValueStr := DateTimeToStr(LValue.AsExtended)
      else
        LValueStr := FloatToStr(LValue.AsExtended);
    end
    else
      LValueStr := LValue.AsVariant;

    aContext.Query.SQL.Clear;
    aContext.Query.SQL.Add(LSQL);
    aContext.Query.Params.ParamByName('pEntity').Value := aContext.EntityName;
    aContext.Query.Params.ParamByName('pRecordId').Value := LPKValue;
    aContext.Query.Params.ParamByName('pField').Value := LProp.FieldName;
    aContext.Query.Params.ParamByName('pOldValue').Value := LValueStr;
    aContext.Query.Params.ParamByName('pOperation').Value := aContext.Operation;
    aContext.Query.Params.ParamByName('pCreatedAt').Value := Now;
    aContext.Query.ExecSQL;
  end;
end;

function TSkillHistory.Name: String;
begin
  Result := 'history';
end;

function TSkillHistory.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;
```

Nota: `EhCampo` e `FieldName` sao helpers de `SimpleRTTIHelper.pas` que ja existem. `EhCampo` retorna true se a property tem atributo `[Campo]`. `FieldName` retorna o nome do `[Campo]` ou o nome da property como fallback.

**Step 4: Verify tests pass**

Compilar e executar. Esperado: 4 testes passando.

**Step 5: Commit**

```bash
git add src/SimpleSkill.pas tests/TestSimpleSkill.pas
git commit -m "feat: add TSkillHistory built-in skill"
```

---

### Task 4: TSkillValidate

**Files:**
- Modify: `src/SimpleSkill.pas`
- Modify: `tests/TestSimpleSkill.pas`

**Step 1: Write the failing tests**

Adicionar em `tests/TestSimpleSkill.pas` na secao `interface`:

```pascal
  TTestSkillValidate = class(TTestCase)
  published
    procedure TestValidate_ValidEntity_NoError;
    procedure TestValidate_InvalidEntity_RaisesException;
    procedure TestValidate_NilEntity_NoError;
    procedure TestValidate_Name;
    procedure TestValidate_RunAt;
  end;
```

Adicionar na secao `implementation`:

```pascal
{ TTestSkillValidate }

procedure TTestSkillValidate.TestValidate_ValidEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
begin
  LEntity := TPedidoTest.Create;
  try
    LEntity.CLIENTE := 'Joao';
    LEntity.VALORTOTAL := 100;
    LSkill := TSkillValidate.New(srBeforeInsert);
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Valid entity should not raise');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillValidate.TestValidate_InvalidEntity_RaisesException;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
  LRaised: Boolean;
begin
  LEntity := TPedidoTest.Create;
  try
    LEntity.CLIENTE := '';
    LEntity.VALORTOTAL := 0;
    LSkill := TSkillValidate.New(srBeforeInsert);
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
    LRaised := False;
    try
      LSkill.Execute(LEntity, LContext);
    except
      on E: ESimpleValidator do
        LRaised := True;
    end;
    CheckTrue(LRaised, 'Invalid entity should raise ESimpleValidator');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillValidate.TestValidate_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillValidate.New;
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Nil entity should not raise');
end;

procedure TTestSkillValidate.TestValidate_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillValidate.New;
  CheckEquals('validate', LSkill.Name, 'Should return validate');
end;

procedure TTestSkillValidate.TestValidate_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillValidate.New(srBeforeUpdate);
  CheckTrue(LSkill.RunAt = srBeforeUpdate, 'Should return configured RunAt');
end;
```

Adicionar no bloco `initialization`:

```pascal
  RegisterTest('Skills', TTestSkillValidate.Suite);
```

Adicionar `SimpleValidator` ao uses da secao `implementation` de `TestSimpleSkill.pas`:

```pascal
uses
  TestEntities,
  SimpleValidator;
```

**Step 2: Verify tests fail**

Compilar. Esperado: erro de compilacao.

**Step 3: Implement TSkillValidate**

Adicionar `SimpleValidator` ao uses da secao `implementation` de `src/SimpleSkill.pas`:

Na secao `implementation`, adicionar apos os uses existentes:

```pascal
uses
  SimpleValidator;
```

Se ja existir bloco uses na implementation, adicionar `SimpleValidator` a ele. Se nao existir, criar. NOTA: o `SimpleSkill.pas` atual NAO tem uses na secao implementation, entao criar:

```pascal
implementation

uses
  SimpleValidator;
```

Adicionar classe apos `TSkillHistory` na secao `type`:

```pascal
  { Built-in: TSkillValidate }
  TSkillValidate = class(TInterfacedObject, iSimpleSkill)
  private
    FRunAt: TSkillRunAt;
  public
    constructor Create(aRunAt: TSkillRunAt = srBeforeInsert);
    destructor Destroy; override;
    class function New(aRunAt: TSkillRunAt = srBeforeInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

Implementacao:

```pascal
{ TSkillValidate }

constructor TSkillValidate.Create(aRunAt: TSkillRunAt);
begin
  FRunAt := aRunAt;
end;

destructor TSkillValidate.Destroy;
begin
  inherited;
end;

class function TSkillValidate.New(aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aRunAt);
end;

function TSkillValidate.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
begin
  Result := Self;
  if aEntity = nil then
    Exit;

  TSimpleValidator.Validate(aEntity);
end;

function TSkillValidate.Name: String;
begin
  Result := 'validate';
end;

function TSkillValidate.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;
```

**Step 4: Verify tests pass**

Compilar e executar. Esperado: 5 testes passando.

**Step 5: Commit**

```bash
git add src/SimpleSkill.pas tests/TestSimpleSkill.pas
git commit -m "feat: add TSkillValidate built-in skill"
```

---

### Task 5: TSkillWebhook

**Files:**
- Modify: `src/SimpleSkill.pas`
- Modify: `tests/TestSimpleSkill.pas`

**Step 1: Write the failing tests**

Adicionar em `tests/TestSimpleSkill.pas` na secao `interface`:

```pascal
  TTestSkillWebhook = class(TTestCase)
  published
    procedure TestWebhook_Name;
    procedure TestWebhook_RunAt;
    procedure TestWebhook_NilEntity_NoError;
    procedure TestWebhook_InvalidURL_NoError;
  end;
```

Adicionar na secao `implementation`:

```pascal
{ TTestSkillWebhook }

procedure TTestSkillWebhook.TestWebhook_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillWebhook.New('http://localhost:9999/hooks');
  CheckEquals('webhook', LSkill.Name, 'Should return webhook');
end;

procedure TTestSkillWebhook.TestWebhook_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillWebhook.New('http://localhost:9999/hooks', srAfterUpdate);
  CheckTrue(LSkill.RunAt = srAfterUpdate, 'Should return configured RunAt');
end;

procedure TTestSkillWebhook.TestWebhook_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillWebhook.New('http://localhost:9999/hooks');
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Nil entity should not raise');
end;

procedure TTestSkillWebhook.TestWebhook_InvalidURL_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
begin
  LEntity := TPedidoTest.Create;
  try
    LEntity.ID := 1;
    LEntity.CLIENTE := 'Teste';
    LEntity.VALORTOTAL := 100;
    LSkill := TSkillWebhook.New('http://invalid-host-that-does-not-exist:9999/hooks');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Invalid URL should not raise (fire-and-forget)');
  finally
    LEntity.Free;
  end;
end;
```

Adicionar no bloco `initialization`:

```pascal
  RegisterTest('Skills', TTestSkillWebhook.Suite);
```

**Step 2: Verify tests fail**

Compilar. Esperado: erro de compilacao.

**Step 3: Implement TSkillWebhook**

Adicionar ao uses da secao `interface` de `src/SimpleSkill.pas`:

```pascal
  System.Net.HttpClient,
  System.JSON,
  System.DateUtils,
```

Adicionar ao uses da secao `implementation`:

```pascal
  SimpleSerializer;
```

Nota: `SimpleValidator` ja foi adicionado na Task 4. Ficara:

```pascal
implementation

uses
  SimpleValidator,
  SimpleSerializer;
```

Adicionar classe apos `TSkillValidate` na secao `type`:

```pascal
  { Built-in: TSkillWebhook }
  TSkillWebhook = class(TInterfacedObject, iSimpleSkill)
  private
    FURL: String;
    FRunAt: TSkillRunAt;
    FAuthHeader: String;
  public
    constructor Create(const aURL: String; aRunAt: TSkillRunAt = srAfterInsert;
      const aAuthHeader: String = '');
    destructor Destroy; override;
    class function New(const aURL: String; aRunAt: TSkillRunAt = srAfterInsert;
      const aAuthHeader: String = ''): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

Implementacao:

```pascal
{ TSkillWebhook }

constructor TSkillWebhook.Create(const aURL: String; aRunAt: TSkillRunAt;
  const aAuthHeader: String);
begin
  FURL := aURL;
  FRunAt := aRunAt;
  FAuthHeader := aAuthHeader;
end;

destructor TSkillWebhook.Destroy;
begin
  inherited;
end;

class function TSkillWebhook.New(const aURL: String; aRunAt: TSkillRunAt;
  const aAuthHeader: String): iSimpleSkill;
begin
  Result := Self.Create(aURL, aRunAt, aAuthHeader);
end;

function TSkillWebhook.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LClient: THTTPClient;
  LPayload: TJSONObject;
  LEntityJSON: TJSONObject;
  LBody: TStringStream;
begin
  Result := Self;
  if aEntity = nil then
    Exit;

  LClient := THTTPClient.Create;
  try
    try
      LEntityJSON := TSimpleSerializer.EntityToJSON<TObject>(aEntity);
      try
        LPayload := TJSONObject.Create;
        try
          LPayload.AddPair('entity', aContext.EntityName);
          LPayload.AddPair('operation', aContext.Operation);
          LPayload.AddPair('timestamp', DateToISO8601(Now));
          LPayload.AddPair('data', LEntityJSON.Clone as TJSONObject);

          LBody := TStringStream.Create(LPayload.ToJSON, TEncoding.UTF8);
          try
            LClient.ContentType := 'application/json';
            if FAuthHeader <> '' then
              LClient.CustomHeaders['Authorization'] := FAuthHeader;
            LClient.ConnectionTimeout := 5000;
            LClient.ResponseTimeout := 10000;
            LClient.Post(FURL, LBody);
          finally
            LBody.Free;
          end;
        finally
          LPayload.Free;
        end;
      finally
        LEntityJSON.Free;
      end;
    except
      // Fire-and-forget: log error but do not raise
      on E: Exception do
      begin
        {$IFDEF MSWINDOWS}
        OutputDebugString(PChar('[Skill:Webhook] Error: ' + E.Message));
        {$ENDIF}
        {$IFDEF CONSOLE}
        Writeln('[Skill:Webhook] Error: ', E.Message);
        {$ENDIF}
      end;
    end;
  finally
    LClient.Free;
  end;
end;

function TSkillWebhook.Name: String;
begin
  Result := 'webhook';
end;

function TSkillWebhook.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;
```

**Step 4: Verify tests pass**

Compilar e executar. Esperado: 4 testes passando. O teste `TestWebhook_InvalidURL_NoError` confirma o comportamento fire-and-forget.

**Step 5: Commit**

```bash
git add src/SimpleSkill.pas tests/TestSimpleSkill.pas
git commit -m "feat: add TSkillWebhook built-in skill"
```

---

### Task 6: Sample Project

**Files:**
- Create: `samples/BuiltinSkills/SimpleORMSkills.dpr`
- Create: `samples/BuiltinSkills/README.md`

**Step 1: Create the sample .dpr**

```pascal
program SimpleORMSkills;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Generics.Collections,
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleAttributes in '..\..\src\SimpleAttributes.pas',
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleSkill in '..\..\src\SimpleSkill.pas',
  SimpleValidator in '..\..\src\SimpleValidator.pas',
  SimpleRTTIHelper in '..\..\src\SimpleRTTIHelper.pas',
  SimpleLogger in '..\..\src\SimpleLogger.pas';

type
  [Tabela('PRODUTO')]
  TProduto = class
  private
    FID: Integer;
    FNOME: String;
    FPRECO: Double;
    FCREATED_AT: TDateTime;
    FUPDATED_AT: TDateTime;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull]
    property NOME: String read FNOME write FNOME;
    [Campo('PRECO'), NotZero]
    property PRECO: Double read FPRECO write FPRECO;
    [Campo('CREATED_AT')]
    property CREATED_AT: TDateTime read FCREATED_AT write FCREATED_AT;
    [Campo('UPDATED_AT')]
    property UPDATED_AT: TDateTime read FUPDATED_AT write FUPDATED_AT;
  end;

var
  LProduto: TProduto;
  LContext: iSimpleSkillContext;
  LRunner: TSimpleSkillRunner;
begin
  try
    Writeln('=== SimpleORM Built-in Skills Demo ===');
    Writeln;

    { --- TSkillTimestamp --- }
    Writeln('1. TSkillTimestamp');
    LProduto := TProduto.Create;
    try
      LProduto.NOME := 'Notebook';
      LProduto.PRECO := 3500.00;

      LContext := TSimpleSkillContext.New(nil, nil, nil, 'PRODUTO', 'INSERT');
      LRunner := TSimpleSkillRunner.New;
      try
        LRunner.Add(TSkillTimestamp.New('CREATED_AT', srBeforeInsert));
        LRunner.RunBefore(LProduto, LContext, srBeforeInsert);
        Writeln('   CREATED_AT preenchido: ', DateTimeToStr(LProduto.CREATED_AT));
      finally
        FreeAndNil(LRunner);
      end;
    finally
      LProduto.Free;
    end;
    Writeln;

    { --- TSkillValidate --- }
    Writeln('2. TSkillValidate');
    LProduto := TProduto.Create;
    try
      LProduto.NOME := '';  // NotNull - vai falhar
      LProduto.PRECO := 0;  // NotZero - vai falhar

      LContext := TSimpleSkillContext.New(nil, nil, nil, 'PRODUTO', 'INSERT');
      LRunner := TSimpleSkillRunner.New;
      try
        LRunner.Add(TSkillValidate.New(srBeforeInsert));
        try
          LRunner.RunBefore(LProduto, LContext, srBeforeInsert);
          Writeln('   Validacao OK');
        except
          on E: Exception do
            Writeln('   Validacao falhou (esperado): ', E.Message);
        end;
      finally
        FreeAndNil(LRunner);
      end;
    finally
      LProduto.Free;
    end;
    Writeln;

    { --- TSkillLog --- }
    Writeln('3. TSkillLog');
    LProduto := TProduto.Create;
    try
      LProduto.NOME := 'Mouse';
      LContext := TSimpleSkillContext.New(nil, nil, nil, 'PRODUTO', 'INSERT');
      LRunner := TSimpleSkillRunner.New;
      try
        LRunner.Add(TSkillLog.New('Demo', srAfterInsert));
        LRunner.RunAfter(LProduto, LContext, srAfterInsert);
        Writeln('   Log executado com sucesso');
      finally
        FreeAndNil(LRunner);
      end;
    finally
      LProduto.Free;
    end;
    Writeln;

    { --- TSkillNotify --- }
    Writeln('4. TSkillNotify');
    LProduto := TProduto.Create;
    try
      LProduto.NOME := 'Teclado';
      LContext := TSimpleSkillContext.New(nil, nil, nil, 'PRODUTO', 'INSERT');
      LRunner := TSimpleSkillRunner.New;
      try
        LRunner.Add(TSkillNotify.New(
          procedure(aObj: TObject)
          begin
            Writeln('   Callback disparado para: ', TProduto(aObj).NOME);
          end, srAfterInsert));
        LRunner.RunAfter(LProduto, LContext, srAfterInsert);
      finally
        FreeAndNil(LRunner);
      end;
    finally
      LProduto.Free;
    end;
    Writeln;

    Writeln('=== Fim do Demo ===');
    Writeln;
    Writeln('Nota: TSkillGuardDelete, TSkillHistory e TSkillWebhook requerem');
    Writeln('conexao com banco ou servidor HTTP para demonstracao completa.');
    Writeln('Consulte a documentacao para exemplos de uso.');
  except
    on E: Exception do
      Writeln('Erro: ', E.ClassName, ': ', E.Message);
  end;
  Readln;
end.
```

**Step 2: Create README.md**

```markdown
# Built-in Skills Demo

Demonstra as Skills built-in do SimpleORM:

1. **TSkillTimestamp** - Preenche campos de data automaticamente
2. **TSkillValidate** - Validacao automatica de entidades
3. **TSkillLog** - Log de operacoes
4. **TSkillNotify** - Callback de notificacao

## Como executar

1. Abra `SimpleORMSkills.dpr` na IDE Delphi
2. Compile e execute (F9)
3. O console mostrara a execucao de cada Skill

## Skills que requerem banco de dados

- **TSkillGuardDelete** - Precisa de conexao para verificar dependencias
- **TSkillHistory** - Precisa de conexao para gravar historico
- **TSkillAudit** - Precisa de conexao para gravar auditoria

## Skills que requerem servidor HTTP

- **TSkillWebhook** - Precisa de endpoint HTTP para receber POST
```

**Step 3: Commit**

```bash
git add samples/BuiltinSkills/SimpleORMSkills.dpr samples/BuiltinSkills/README.md
git commit -m "feat: add built-in skills sample project"
```

---

### Task 7: Documentation and CHANGELOG

**Files:**
- Modify: `docs/index.html`
- Modify: `docs/en/index.html`
- Modify: `CHANGELOG.md`

**Step 1: Update Portuguese documentation**

Adicionar nova secao em `docs/index.html` apos a secao `#skills` existente. Criar secao `#builtin-skills` com:

- Link no `<nav>` sidebar: `<li><a href="#builtin-skills">Skills Built-in</a> <span class="badge badge-new">NEW</span></li>`
- Secao com tabela de referencia de todas as 8 Skills (3 existentes + 5 novas)
- Exemplo de codigo para cada nova Skill
- DDL para TSkillHistory e TSkillAudit

**Step 2: Update English documentation**

Mesma estrutura em `docs/en/index.html`.

**Step 3: Update CHANGELOG.md**

Adicionar na secao `[Unreleased]` > `Added`:

```markdown
- **TSkillTimestamp** - Skill built-in para preencher campos de data automaticamente via RTTI (`SimpleSkill.pas`)
- **TSkillGuardDelete** - Skill built-in para bloquear delete quando existem registros dependentes (`SimpleSkill.pas`)
- **TSkillHistory** - Skill built-in para gravar snapshot de valores antes de update/delete (`SimpleSkill.pas`)
- **TSkillValidate** - Skill built-in para validacao automatica via TSimpleValidator (`SimpleSkill.pas`)
- **TSkillWebhook** - Skill built-in para HTTP POST fire-and-forget apos operacoes CRUD (`SimpleSkill.pas`)
- **ESimpleGuardDelete** - Exception especifica para bloqueio de delete com dependencias (`SimpleSkill.pas`)
- **Sample BuiltinSkills** - Projeto demonstrando uso das Skills built-in (`samples/BuiltinSkills/`)
```

**Step 4: Commit**

```bash
git add docs/index.html docs/en/index.html CHANGELOG.md
git commit -m "docs: add built-in skills documentation and changelog"
```
