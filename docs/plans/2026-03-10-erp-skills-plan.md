# ERP Skills Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Adicionar atributos de validacao brasileira (CPF/CNPJ) e 4 Skills ERP (Sequence, CalcTotal, StockMove, Duplicate) ao SimpleORM.

**Architecture:** Atributos `[CPF]`/`[CNPJ]` em `SimpleAttributes.pas`, helpers em `SimpleRTTIHelper.pas`, validacao em `SimpleValidator.pas`. Skills ERP em `SimpleSkill.pas`. Testes em `tests/TestSimpleValidator.pas` e `tests/TestSimpleSkill.pas`.

**Tech Stack:** Delphi Object Pascal, RTTI (`System.Rtti`), DUnit (`TestFramework`), `System.Math` (arredondamento)

---

### Task 1: Atributos [CPF] e [CNPJ] + Helpers RTTI

**Files:**
- Modify: `src/SimpleAttributes.pas`
- Modify: `src/SimpleRTTIHelper.pas`
- Modify: `tests/Entities/TestEntities.pas`

**Step 1: Add attributes to SimpleAttributes.pas**

Adicionar apos `CascadeDelete = class(TCustomAttribute) end;` (linha 167):

```pascal
  CPF = class(TCustomAttribute)
  end;

  CNPJ = class(TCustomAttribute)
  end;
```

**Step 2: Add RTTI helpers to SimpleRTTIHelper.pas**

Adicionar na declaracao de `TRttiPropertyHelper` (interface), apos `function HasAIAttribute: Boolean;`:

```pascal
    function IsCPF: Boolean;
    function IsCNPJ: Boolean;
```

Adicionar na implementation, apos `TRttiPropertyHelper.HasAIAttribute`:

```pascal
function TRttiPropertyHelper.IsCPF: Boolean;
begin
  Result := Tem<CPF>
end;

function TRttiPropertyHelper.IsCNPJ: Boolean;
begin
  Result := Tem<CNPJ>
end;
```

**Step 3: Add test entity to TestEntities.pas**

Adicionar apos `TTestTimestampEntity`:

```pascal
  { Entidade com CPF e CNPJ }
  [Tabela('PESSOA')]
  TPessoaTest = class
  private
    FID: Integer;
    FNOME: String;
    FCPF: String;
    FCNPJ: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull]
    property NOME: String read FNOME write FNOME;
    [Campo('CPF'), CPF]
    property CPF: String read FCPF write FCPF;
    [Campo('CNPJ'), CNPJ]
    property CNPJ: String read FCNPJ write FCNPJ;
  end;
```

**Step 4: Commit**

```bash
git add src/SimpleAttributes.pas src/SimpleRTTIHelper.pas tests/Entities/TestEntities.pas
git commit -m "feat: add [CPF] and [CNPJ] attributes with RTTI helpers"
```

---

### Task 2: Validacao CPF/CNPJ no SimpleValidator

**Files:**
- Modify: `src/SimpleValidator.pas`
- Modify: `tests/TestSimpleValidator.pas`

**Step 1: Write the failing tests**

Adicionar em `tests/TestSimpleValidator.pas`. Na declaracao da classe de teste existente, adicionar metodos published:

```pascal
    procedure TestValidateCPF_Valid;
    procedure TestValidateCPF_Invalid;
    procedure TestValidateCPF_Empty_NoError;
    procedure TestValidateCPF_WithMask_Valid;
    procedure TestValidateCPF_AllSameDigits_Invalid;
    procedure TestValidateCNPJ_Valid;
    procedure TestValidateCNPJ_Invalid;
    procedure TestValidateCNPJ_Empty_NoError;
    procedure TestValidateCNPJ_WithMask_Valid;
    procedure TestValidateCNPJ_AllSameDigits_Invalid;
```

Adicionar implementacao. NOTA: o arquivo de teste usa `TPessoaTest` da `TestEntities.pas`:

```pascal
procedure TTestSimpleValidator.TestValidateCPF_Valid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CPF := '52998224725';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckEquals(0, LErrors.Count, 'Valid CPF should pass: ' + LErrors.Text);
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestSimpleValidator.TestValidateCPF_Invalid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CPF := '12345678901';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckTrue(LErrors.Count > 0, 'Invalid CPF should fail');
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestSimpleValidator.TestValidateCPF_Empty_NoError;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CPF := '';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckEquals(0, LErrors.Count, 'Empty CPF should not validate');
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestSimpleValidator.TestValidateCPF_WithMask_Valid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CPF := '529.982.247-25';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckEquals(0, LErrors.Count, 'Masked valid CPF should pass: ' + LErrors.Text);
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestSimpleValidator.TestValidateCPF_AllSameDigits_Invalid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CPF := '11111111111';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckTrue(LErrors.Count > 0, 'All same digits CPF should fail');
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestSimpleValidator.TestValidateCNPJ_Valid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CNPJ := '11222333000181';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckEquals(0, LErrors.Count, 'Valid CNPJ should pass: ' + LErrors.Text);
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestSimpleValidator.TestValidateCNPJ_Invalid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CNPJ := '12345678000199';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckTrue(LErrors.Count > 0, 'Invalid CNPJ should fail');
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestSimpleValidator.TestValidateCNPJ_Empty_NoError;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CNPJ := '';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckEquals(0, LErrors.Count, 'Empty CNPJ should not validate');
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestSimpleValidator.TestValidateCNPJ_WithMask_Valid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CNPJ := '11.222.333/0001-81';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckEquals(0, LErrors.Count, 'Masked valid CNPJ should pass: ' + LErrors.Text);
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestSimpleValidator.TestValidateCNPJ_AllSameDigits_Invalid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CNPJ := '11111111111111';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckTrue(LErrors.Count > 0, 'All same digits CNPJ should fail');
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;
```

**Step 2: Implement validation in SimpleValidator.pas**

Add error message constants after existing constants:

```pascal
  sMSG_CPF = 'O campo %s n' + #227 + 'o cont' + #233 + 'm um CPF v' + #225 + 'lido!';
  sMSG_CNPJ = 'O campo %s n' + #227 + 'o cont' + #233 + 'm um CNPJ v' + #225 + 'lido!';
```

Add method declarations in the `private` section of `TSimpleValidator`:

```pascal
    class procedure ValidateCPF(const aErrors: TStrings; const aObject:
      TObject; const aProperty: TRttiProperty); static;
    class procedure ValidateCNPJ(const aErrors: TStrings; const aObject:
      TObject; const aProperty: TRttiProperty); static;
```

Add calls in the `Validate` method loop, after the `ValidateRegex` call (around line 85):

```pascal
    if prpRtti.IsCPF then
      ValidateCPF(aErrors, aObject, prpRtti);
    if prpRtti.IsCNPJ then
      ValidateCNPJ(aErrors, aObject, prpRtti);
```

Add helper function and implementations before the final `end.`:

```pascal
function StripMask(const aValue: String): String;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(aValue) do
    if CharInSet(aValue[I], ['0'..'9']) then
      Result := Result + aValue[I];
end;

function AllSameDigits(const aValue: String): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 2 to Length(aValue) do
    if aValue[I] <> aValue[1] then
      Exit(False);
end;

class procedure TSimpleValidator.ValidateCPF(const aErrors: TStrings; const aObject:
  TObject; const aProperty: TRttiProperty);
var
  Value: TValue;
  LCPF: String;
  LSum, LRest, I: Integer;
begin
  Value := aProperty.GetValue(aObject);
  if not (Value.Kind in [tkUString, tkString, tkLString, tkWString]) then
    Exit;

  LCPF := Value.AsString;
  if LCPF = '' then
    Exit;

  LCPF := StripMask(LCPF);

  if (Length(LCPF) <> 11) or AllSameDigits(LCPF) then
  begin
    aErrors.Add(SysUtils.Format(sMSG_CPF, [aProperty.DisplayName]));
    Exit;
  end;

  // First check digit
  LSum := 0;
  for I := 1 to 9 do
    LSum := LSum + StrToInt(LCPF[I]) * (11 - I);
  LRest := (LSum * 10) mod 11;
  if LRest = 10 then
    LRest := 0;
  if LRest <> StrToInt(LCPF[10]) then
  begin
    aErrors.Add(SysUtils.Format(sMSG_CPF, [aProperty.DisplayName]));
    Exit;
  end;

  // Second check digit
  LSum := 0;
  for I := 1 to 10 do
    LSum := LSum + StrToInt(LCPF[I]) * (12 - I);
  LRest := (LSum * 10) mod 11;
  if LRest = 10 then
    LRest := 0;
  if LRest <> StrToInt(LCPF[11]) then
    aErrors.Add(SysUtils.Format(sMSG_CPF, [aProperty.DisplayName]));
end;

class procedure TSimpleValidator.ValidateCNPJ(const aErrors: TStrings; const aObject:
  TObject; const aProperty: TRttiProperty);
var
  Value: TValue;
  LCNPJ: String;
  LSum, LRest, I: Integer;
const
  WEIGHTS1: array[1..12] of Integer = (5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2);
  WEIGHTS2: array[1..13] of Integer = (6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2);
begin
  Value := aProperty.GetValue(aObject);
  if not (Value.Kind in [tkUString, tkString, tkLString, tkWString]) then
    Exit;

  LCNPJ := Value.AsString;
  if LCNPJ = '' then
    Exit;

  LCNPJ := StripMask(LCNPJ);

  if (Length(LCNPJ) <> 14) or AllSameDigits(LCNPJ) then
  begin
    aErrors.Add(SysUtils.Format(sMSG_CNPJ, [aProperty.DisplayName]));
    Exit;
  end;

  // First check digit
  LSum := 0;
  for I := 1 to 12 do
    LSum := LSum + StrToInt(LCNPJ[I]) * WEIGHTS1[I];
  LRest := LSum mod 11;
  if LRest < 2 then
    LRest := 0
  else
    LRest := 11 - LRest;
  if LRest <> StrToInt(LCNPJ[13]) then
  begin
    aErrors.Add(SysUtils.Format(sMSG_CNPJ, [aProperty.DisplayName]));
    Exit;
  end;

  // Second check digit
  LSum := 0;
  for I := 1 to 13 do
    LSum := LSum + StrToInt(LCNPJ[I]) * WEIGHTS2[I];
  LRest := LSum mod 11;
  if LRest < 2 then
    LRest := 0
  else
    LRest := 11 - LRest;
  if LRest <> StrToInt(LCNPJ[14]) then
    aErrors.Add(SysUtils.Format(sMSG_CNPJ, [aProperty.DisplayName]));
end;
```

**Step 3: Commit**

```bash
git add src/SimpleValidator.pas tests/TestSimpleValidator.pas
git commit -m "feat: add CPF and CNPJ validation to TSimpleValidator"
```

---

### Task 3: TSkillSequence

**Files:**
- Modify: `src/SimpleSkill.pas`
- Modify: `tests/TestSimpleSkill.pas`

**Step 1: Write the failing tests**

Adicionar em `tests/TestSimpleSkill.pas`:

```pascal
  TTestSkillSequence = class(TTestCase)
  published
    procedure TestSequence_Name;
    procedure TestSequence_RunAtIsAlwaysBeforeInsert;
    procedure TestSequence_NilEntity_NoError;
    procedure TestSequence_NilQuery_NoError;
  end;
```

```pascal
{ TTestSkillSequence }

procedure TTestSkillSequence.TestSequence_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillSequence.New('NUMERO', 'NUMERACAO', 'PEDIDO');
  CheckEquals('sequence', LSkill.Name, 'Should return sequence');
end;

procedure TTestSkillSequence.TestSequence_RunAtIsAlwaysBeforeInsert;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillSequence.New('NUMERO', 'NUMERACAO', 'PEDIDO');
  CheckTrue(LSkill.RunAt = srBeforeInsert, 'Should always be srBeforeInsert');
end;

procedure TTestSkillSequence.TestSequence_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillSequence.New('NUMERO', 'NUMERACAO', 'PEDIDO');
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Should not raise error for nil entity');
end;

procedure TTestSkillSequence.TestSequence_NilQuery_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
begin
  LEntity := TPedidoTest.Create;
  try
    LSkill := TSkillSequence.New('NUMERO', 'NUMERACAO', 'PEDIDO');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Should not raise error when query is nil');
  finally
    LEntity.Free;
  end;
end;
```

Registration: `RegisterTest('Skills', TTestSkillSequence.Suite);`

**Step 2: Implement TSkillSequence**

Adicionar em `src/SimpleSkill.pas` na secao `type`, apos `TSkillWebhook`:

```pascal
  { Built-in: TSkillSequence }
  TSkillSequence = class(TInterfacedObject, iSimpleSkill)
  private
    FFieldName: String;
    FControlTable: String;
    FSerie: String;
  public
    constructor Create(const aFieldName, aControlTable, aSerie: String);
    destructor Destroy; override;
    class function New(const aFieldName, aControlTable, aSerie: String): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

Implementacao:

```pascal
{ TSkillSequence }

constructor TSkillSequence.Create(const aFieldName, aControlTable, aSerie: String);
begin
  FFieldName := aFieldName;
  FControlTable := aControlTable;
  FSerie := aSerie;
end;

destructor TSkillSequence.Destroy;
begin
  inherited;
end;

class function TSkillSequence.New(const aFieldName, aControlTable, aSerie: String): iSimpleSkill;
begin
  Result := Self.Create(aFieldName, aControlTable, aSerie);
end;

function TSkillSequence.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LNextNumber: Integer;
begin
  Result := Self;
  if (aEntity = nil) or (aContext.Query = nil) then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);
  LProp := LType.GetProperty(FFieldName);
  if LProp = nil then
    Exit;

  // Try to get current number
  aContext.Query.SQL.Clear;
  aContext.Query.SQL.Add('SELECT ULTIMO_NUMERO FROM ' + FControlTable + ' WHERE SERIE = :pSerie');
  aContext.Query.Params.ParamByName('pSerie').Value := FSerie;
  aContext.Query.Open;
  try
    if aContext.Query.DataSet.IsEmpty then
    begin
      aContext.Query.DataSet.Close;
      // Insert first record
      LNextNumber := 1;
      aContext.Query.SQL.Clear;
      aContext.Query.SQL.Add('INSERT INTO ' + FControlTable + ' (SERIE, ULTIMO_NUMERO) VALUES (:pSerie, :pNumero)');
      aContext.Query.Params.ParamByName('pSerie').Value := FSerie;
      aContext.Query.Params.ParamByName('pNumero').Value := LNextNumber;
      aContext.Query.ExecSQL;
    end
    else
    begin
      LNextNumber := aContext.Query.DataSet.Fields[0].AsInteger + 1;
      aContext.Query.DataSet.Close;
      // Update existing record
      aContext.Query.SQL.Clear;
      aContext.Query.SQL.Add('UPDATE ' + FControlTable + ' SET ULTIMO_NUMERO = :pNumero WHERE SERIE = :pSerie');
      aContext.Query.Params.ParamByName('pNumero').Value := LNextNumber;
      aContext.Query.Params.ParamByName('pSerie').Value := FSerie;
      aContext.Query.ExecSQL;
    end;
  except
    on E: Exception do
    begin
      aContext.Query.DataSet.Close;
      raise;
    end;
  end;

  LProp.SetValue(aEntity, TValue.From<Integer>(LNextNumber));
end;

function TSkillSequence.Name: String;
begin
  Result := 'sequence';
end;

function TSkillSequence.RunAt: TSkillRunAt;
begin
  Result := srBeforeInsert;
end;
```

**Step 3: Commit**

```bash
git add src/SimpleSkill.pas tests/TestSimpleSkill.pas
git commit -m "feat: add TSkillSequence built-in skill"
```

---

### Task 4: TSkillCalcTotal

**Files:**
- Modify: `src/SimpleSkill.pas`
- Modify: `tests/TestSimpleSkill.pas`
- Modify: `tests/Entities/TestEntities.pas`

**Step 1: Add test entity**

Adicionar em `tests/Entities/TestEntities.pas`:

```pascal
  { Entidade para teste de CalcTotal }
  [Tabela('ITEM_CALC')]
  TItemCalcTest = class
  private
    FID: Integer;
    FQUANTIDADE: Double;
    FPRECO_UNITARIO: Double;
    FDESCONTO: Double;
    FVALOR_TOTAL: Double;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('QUANTIDADE')]
    property QUANTIDADE: Double read FQUANTIDADE write FQUANTIDADE;
    [Campo('PRECO_UNITARIO')]
    property PRECO_UNITARIO: Double read FPRECO_UNITARIO write FPRECO_UNITARIO;
    [Campo('DESCONTO')]
    property DESCONTO: Double read FDESCONTO write FDESCONTO;
    [Campo('VALOR_TOTAL')]
    property VALOR_TOTAL: Double read FVALOR_TOTAL write FVALOR_TOTAL;
  end;
```

**Step 2: Write the failing tests**

```pascal
  TTestSkillCalcTotal = class(TTestCase)
  published
    procedure TestCalcTotal_CalculatesCorrectly;
    procedure TestCalcTotal_WithDiscount;
    procedure TestCalcTotal_WithoutDiscount;
    procedure TestCalcTotal_NilEntity_NoError;
    procedure TestCalcTotal_Name;
    procedure TestCalcTotal_RunAt;
  end;
```

```pascal
{ TTestSkillCalcTotal }

procedure TTestSkillCalcTotal.TestCalcTotal_CalculatesCorrectly;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TItemCalcTest;
begin
  LEntity := TItemCalcTest.Create;
  try
    LEntity.QUANTIDADE := 10;
    LEntity.PRECO_UNITARIO := 25.50;
    LEntity.DESCONTO := 5.00;
    LSkill := TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO', 'DESCONTO');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ITEM', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals(250.00, LEntity.VALOR_TOTAL, 0.01, 'Should be 10 * 25.50 - 5.00 = 250.00');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillCalcTotal.TestCalcTotal_WithDiscount;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TItemCalcTest;
begin
  LEntity := TItemCalcTest.Create;
  try
    LEntity.QUANTIDADE := 3;
    LEntity.PRECO_UNITARIO := 100.00;
    LEntity.DESCONTO := 50.00;
    LSkill := TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO', 'DESCONTO');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ITEM', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals(250.00, LEntity.VALOR_TOTAL, 0.01, 'Should be 3 * 100 - 50 = 250');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillCalcTotal.TestCalcTotal_WithoutDiscount;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TItemCalcTest;
begin
  LEntity := TItemCalcTest.Create;
  try
    LEntity.QUANTIDADE := 5;
    LEntity.PRECO_UNITARIO := 10.00;
    LSkill := TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO', '');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ITEM', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals(50.00, LEntity.VALOR_TOTAL, 0.01, 'Should be 5 * 10 = 50');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillCalcTotal.TestCalcTotal_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO');
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'ITEM', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Should not raise error for nil entity');
end;

procedure TTestSkillCalcTotal.TestCalcTotal_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO');
  CheckEquals('calc-total', LSkill.Name, 'Should return calc-total');
end;

procedure TTestSkillCalcTotal.TestCalcTotal_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO', '', srBeforeUpdate);
  CheckTrue(LSkill.RunAt = srBeforeUpdate, 'Should return configured RunAt');
end;
```

Registration: `RegisterTest('Skills', TTestSkillCalcTotal.Suite);`

**Step 3: Implement TSkillCalcTotal**

Add `System.Math` to the interface uses of `src/SimpleSkill.pas`.

Declaracao:

```pascal
  { Built-in: TSkillCalcTotal }
  TSkillCalcTotal = class(TInterfacedObject, iSimpleSkill)
  private
    FTargetField: String;
    FQtyField: String;
    FPriceField: String;
    FDiscountField: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aTargetField, aQtyField, aPriceField: String;
      const aDiscountField: String = ''; aRunAt: TSkillRunAt = srBeforeInsert);
    destructor Destroy; override;
    class function New(const aTargetField, aQtyField, aPriceField: String;
      const aDiscountField: String = ''; aRunAt: TSkillRunAt = srBeforeInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

Implementacao:

```pascal
{ TSkillCalcTotal }

constructor TSkillCalcTotal.Create(const aTargetField, aQtyField, aPriceField: String;
  const aDiscountField: String; aRunAt: TSkillRunAt);
begin
  FTargetField := aTargetField;
  FQtyField := aQtyField;
  FPriceField := aPriceField;
  FDiscountField := aDiscountField;
  FRunAt := aRunAt;
end;

destructor TSkillCalcTotal.Destroy;
begin
  inherited;
end;

class function TSkillCalcTotal.New(const aTargetField, aQtyField, aPriceField: String;
  const aDiscountField: String; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aTargetField, aQtyField, aPriceField, aDiscountField, aRunAt);
end;

function TSkillCalcTotal.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LTargetProp, LQtyProp, LPriceProp, LDiscountProp: TRttiProperty;
  LQty, LPrice, LDiscount, LTotal: Double;
begin
  Result := Self;
  if aEntity = nil then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);

  LTargetProp := LType.GetProperty(FTargetField);
  LQtyProp := LType.GetProperty(FQtyField);
  LPriceProp := LType.GetProperty(FPriceField);

  if (LTargetProp = nil) or (LQtyProp = nil) or (LPriceProp = nil) then
    Exit;

  LQty := LQtyProp.GetValue(aEntity).AsExtended;
  LPrice := LPriceProp.GetValue(aEntity).AsExtended;

  LDiscount := 0;
  if FDiscountField <> '' then
  begin
    LDiscountProp := LType.GetProperty(FDiscountField);
    if LDiscountProp <> nil then
      LDiscount := LDiscountProp.GetValue(aEntity).AsExtended;
  end;

  LTotal := SimpleRoundTo(LQty * LPrice - LDiscount, -2);
  LTargetProp.SetValue(aEntity, TValue.From<Double>(LTotal));
end;

function TSkillCalcTotal.Name: String;
begin
  Result := 'calc-total';
end;

function TSkillCalcTotal.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;
```

**Step 4: Commit**

```bash
git add src/SimpleSkill.pas tests/TestSimpleSkill.pas tests/Entities/TestEntities.pas
git commit -m "feat: add TSkillCalcTotal built-in skill"
```

---

### Task 5: TSkillStockMove

**Files:**
- Modify: `src/SimpleSkill.pas`
- Modify: `tests/TestSimpleSkill.pas`

**Step 1: Write the failing tests**

```pascal
  TTestSkillStockMove = class(TTestCase)
  published
    procedure TestStockMove_Name;
    procedure TestStockMove_RunAt;
    procedure TestStockMove_NilEntity_NoError;
    procedure TestStockMove_NilQuery_NoError;
  end;
```

```pascal
{ TTestSkillStockMove }

procedure TTestSkillStockMove.TestStockMove_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillStockMove.New('MOV_ESTOQUE', 'PRODUTO_ID', 'QUANTIDADE');
  CheckEquals('stock-move', LSkill.Name, 'Should return stock-move');
end;

procedure TTestSkillStockMove.TestStockMove_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillStockMove.New('MOV_ESTOQUE', 'PRODUTO_ID', 'QUANTIDADE', srAfterDelete);
  CheckTrue(LSkill.RunAt = srAfterDelete, 'Should return configured RunAt');
end;

procedure TTestSkillStockMove.TestStockMove_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillStockMove.New('MOV_ESTOQUE', 'PRODUTO_ID', 'QUANTIDADE');
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'ITEM', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Should not raise error for nil entity');
end;

procedure TTestSkillStockMove.TestStockMove_NilQuery_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TItemCalcTest;
begin
  LEntity := TItemCalcTest.Create;
  try
    LEntity.QUANTIDADE := 10;
    LSkill := TSkillStockMove.New('MOV_ESTOQUE', 'ID', 'QUANTIDADE');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ITEM', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Should not raise error when query is nil');
  finally
    LEntity.Free;
  end;
end;
```

Registration: `RegisterTest('Skills', TTestSkillStockMove.Suite);`

**Step 2: Implement TSkillStockMove**

```pascal
  { Built-in: TSkillStockMove }
  TSkillStockMove = class(TInterfacedObject, iSimpleSkill)
  private
    FMoveTable: String;
    FProductField: String;
    FQtyField: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aMoveTable, aProductField, aQtyField: String;
      aRunAt: TSkillRunAt = srAfterInsert);
    destructor Destroy; override;
    class function New(const aMoveTable, aProductField, aQtyField: String;
      aRunAt: TSkillRunAt = srAfterInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

```pascal
{ TSkillStockMove }

constructor TSkillStockMove.Create(const aMoveTable, aProductField, aQtyField: String;
  aRunAt: TSkillRunAt);
begin
  FMoveTable := aMoveTable;
  FProductField := aProductField;
  FQtyField := aQtyField;
  FRunAt := aRunAt;
end;

destructor TSkillStockMove.Destroy;
begin
  inherited;
end;

class function TSkillStockMove.New(const aMoveTable, aProductField, aQtyField: String;
  aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aMoveTable, aProductField, aQtyField, aRunAt);
end;

function TSkillStockMove.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProductProp, LQtyProp: TRttiProperty;
  LProductId: Variant;
  LQuantity: Double;
  LTipo: String;
  LSQL: String;
begin
  Result := Self;
  if (aEntity = nil) or (aContext.Query = nil) then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);

  LProductProp := LType.GetProperty(FProductField);
  LQtyProp := LType.GetProperty(FQtyField);
  if (LProductProp = nil) or (LQtyProp = nil) then
    Exit;

  LProductId := LProductProp.GetValue(aEntity).AsVariant;
  LQuantity := Abs(LQtyProp.GetValue(aEntity).AsExtended);

  if FRunAt in [srAfterDelete] then
    LTipo := 'ENTRADA'
  else
    LTipo := 'SAIDA';

  LSQL := 'INSERT INTO ' + FMoveTable +
    ' (PRODUTO_ID, QUANTIDADE, TIPO, ENTITY_NAME, CREATED_AT)' +
    ' VALUES (:pProdutoId, :pQuantidade, :pTipo, :pEntity, :pCreatedAt)';

  aContext.Query.SQL.Clear;
  aContext.Query.SQL.Add(LSQL);
  aContext.Query.Params.ParamByName('pProdutoId').Value := LProductId;
  aContext.Query.Params.ParamByName('pQuantidade').Value := LQuantity;
  aContext.Query.Params.ParamByName('pTipo').Value := LTipo;
  aContext.Query.Params.ParamByName('pEntity').Value := aContext.EntityName;
  aContext.Query.Params.ParamByName('pCreatedAt').Value := Now;
  aContext.Query.ExecSQL;
end;

function TSkillStockMove.Name: String;
begin
  Result := 'stock-move';
end;

function TSkillStockMove.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;
```

**Step 3: Commit**

```bash
git add src/SimpleSkill.pas tests/TestSimpleSkill.pas
git commit -m "feat: add TSkillStockMove built-in skill"
```

---

### Task 6: TSkillDuplicate

**Files:**
- Modify: `src/SimpleSkill.pas`
- Modify: `tests/TestSimpleSkill.pas`

**Step 1: Write the failing tests**

```pascal
  TTestSkillDuplicate = class(TTestCase)
  published
    procedure TestDuplicate_Name;
    procedure TestDuplicate_RunAtIsAlwaysAfterInsert;
    procedure TestDuplicate_NilEntity_NoError;
    procedure TestDuplicate_NilQuery_NoError;
    procedure TestDuplicate_ZeroTotal_NoError;
  end;
```

```pascal
{ TTestSkillDuplicate }

procedure TTestSkillDuplicate.TestDuplicate_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillDuplicate.New('PARCELA', 'VALORTOTAL', 3, 30);
  CheckEquals('duplicate', LSkill.Name, 'Should return duplicate');
end;

procedure TTestSkillDuplicate.TestDuplicate_RunAtIsAlwaysAfterInsert;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillDuplicate.New('PARCELA', 'VALORTOTAL', 3, 30);
  CheckTrue(LSkill.RunAt = srAfterInsert, 'Should always be srAfterInsert');
end;

procedure TTestSkillDuplicate.TestDuplicate_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillDuplicate.New('PARCELA', 'VALORTOTAL', 3, 30);
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Should not raise error for nil entity');
end;

procedure TTestSkillDuplicate.TestDuplicate_NilQuery_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
begin
  LEntity := TPedidoTest.Create;
  try
    LEntity.VALORTOTAL := 300;
    LSkill := TSkillDuplicate.New('PARCELA', 'VALORTOTAL', 3, 30);
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Should not raise error when query is nil');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillDuplicate.TestDuplicate_ZeroTotal_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
begin
  LEntity := TPedidoTest.Create;
  try
    LEntity.VALORTOTAL := 0;
    LSkill := TSkillDuplicate.New('PARCELA', 'VALORTOTAL', 3, 30);
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Zero total should not generate installments');
  finally
    LEntity.Free;
  end;
end;
```

Registration: `RegisterTest('Skills', TTestSkillDuplicate.Suite);`

**Step 2: Implement TSkillDuplicate**

```pascal
  { Built-in: TSkillDuplicate }
  TSkillDuplicate = class(TInterfacedObject, iSimpleSkill)
  private
    FInstallmentTable: String;
    FTotalField: String;
    FCount: Integer;
    FIntervalDays: Integer;
  public
    constructor Create(const aInstallmentTable, aTotalField: String;
      aCount, aIntervalDays: Integer);
    destructor Destroy; override;
    class function New(const aInstallmentTable, aTotalField: String;
      aCount, aIntervalDays: Integer): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

```pascal
{ TSkillDuplicate }

constructor TSkillDuplicate.Create(const aInstallmentTable, aTotalField: String;
  aCount, aIntervalDays: Integer);
begin
  FInstallmentTable := aInstallmentTable;
  FTotalField := aTotalField;
  FCount := aCount;
  FIntervalDays := aIntervalDays;
end;

destructor TSkillDuplicate.Destroy;
begin
  inherited;
end;

class function TSkillDuplicate.New(const aInstallmentTable, aTotalField: String;
  aCount, aIntervalDays: Integer): iSimpleSkill;
begin
  Result := Self.Create(aInstallmentTable, aTotalField, aCount, aIntervalDays);
end;

function TSkillDuplicate.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LRttiContext: TRttiContext;
  LType: TRttiType;
  LTotalProp: TRttiProperty;
  LPKProp: TRttiProperty;
  LTotal: Double;
  LEntityId: Variant;
  LInstallmentValue: Double;
  LSumPrevious: Double;
  LDueDate: TDateTime;
  LSQL: String;
  I: Integer;
begin
  Result := Self;
  if (aEntity = nil) or (aContext.Query = nil) then
    Exit;

  LRttiContext := TRttiContext.Create;
  LType := LRttiContext.GetType(aEntity.ClassType);

  LTotalProp := LType.GetProperty(FTotalField);
  LPKProp := LType.GetPKField;
  if (LTotalProp = nil) or (LPKProp = nil) then
    Exit;

  LTotal := LTotalProp.GetValue(aEntity).AsExtended;
  if LTotal <= 0 then
    Exit;

  LEntityId := LPKProp.GetValue(aEntity).AsVariant;

  LSQL := 'INSERT INTO ' + FInstallmentTable +
    ' (ENTITY_ID, NUMERO, VALOR, VENCIMENTO, STATUS, CREATED_AT)' +
    ' VALUES (:pEntityId, :pNumero, :pValor, :pVencimento, :pStatus, :pCreatedAt)';

  LSumPrevious := 0;
  for I := 1 to FCount do
  begin
    if I < FCount then
    begin
      LInstallmentValue := Trunc(LTotal / FCount * 100) / 100;
      LSumPrevious := LSumPrevious + LInstallmentValue;
    end
    else
      LInstallmentValue := LTotal - LSumPrevious;

    LDueDate := Now + (I * FIntervalDays);

    aContext.Query.SQL.Clear;
    aContext.Query.SQL.Add(LSQL);
    aContext.Query.Params.ParamByName('pEntityId').Value := LEntityId;
    aContext.Query.Params.ParamByName('pNumero').Value := I;
    aContext.Query.Params.ParamByName('pValor').Value := LInstallmentValue;
    aContext.Query.Params.ParamByName('pVencimento').Value := LDueDate;
    aContext.Query.Params.ParamByName('pStatus').Value := 'ABERTO';
    aContext.Query.Params.ParamByName('pCreatedAt').Value := Now;
    aContext.Query.ExecSQL;
  end;
end;

function TSkillDuplicate.Name: String;
begin
  Result := 'duplicate';
end;

function TSkillDuplicate.RunAt: TSkillRunAt;
begin
  Result := srAfterInsert;
end;
```

**Step 3: Commit**

```bash
git add src/SimpleSkill.pas tests/TestSimpleSkill.pas
git commit -m "feat: add TSkillDuplicate built-in skill"
```

---

### Task 7: Sample Project

**Files:**
- Create: `samples/ERPSkills/SimpleORMErpSkills.dpr`
- Create: `samples/ERPSkills/README.md`

**Step 1: Create sample .dpr**

Console app demonstrating CPF/CNPJ validation and TSkillCalcTotal (the two that don't require database). See sample pattern from `samples/BuiltinSkills/SimpleORMSkills.dpr`.

**Step 2: Create README.md**

Instructions to run + list of ERP Skills with notes about which require database.

**Step 3: Commit**

```bash
git add samples/ERPSkills/SimpleORMErpSkills.dpr samples/ERPSkills/README.md
git commit -m "feat: add ERP skills sample project"
```

---

### Task 8: Documentation and CHANGELOG

**Files:**
- Modify: `docs/index.html`
- Modify: `docs/en/index.html`
- Modify: `CHANGELOG.md`

**Step 1: Update Portuguese documentation**

Add nav link `<li><a href="#erp-skills">Skills ERP</a> <span class="badge badge-new">NEW</span></li>` and new section `#erp-skills` after `#builtin-skills` with:
- Tabela de referencia dos atributos `[CPF]`/`[CNPJ]`
- Tabela de referencia das 4 Skills ERP
- Exemplos de codigo para cada
- DDLs para TSkillSequence, TSkillStockMove, TSkillDuplicate

**Step 2: Update English documentation**

Same content in English.

**Step 3: Update CHANGELOG.md**

Add entries under `[Unreleased]` > `Added`:

```markdown
- **[CPF]** - Atributo de validacao de CPF brasileiro com algoritmo completo (`SimpleAttributes.pas`)
- **[CNPJ]** - Atributo de validacao de CNPJ brasileiro com algoritmo completo (`SimpleAttributes.pas`)
- **TSkillSequence** - Skill ERP para numeracao sequencial via tabela de controle (`SimpleSkill.pas`)
- **TSkillCalcTotal** - Skill ERP para calculo de total (qtd * preco - desconto) via RTTI (`SimpleSkill.pas`)
- **TSkillStockMove** - Skill ERP para movimentacao de estoque (entrada/saida) (`SimpleSkill.pas`)
- **TSkillDuplicate** - Skill ERP para geracao de parcelas financeiras (`SimpleSkill.pas`)
- **Sample ERPSkills** - Projeto demonstrando Skills ERP e validacao CPF/CNPJ (`samples/ERPSkills/`)
```

**Step 4: Commit**

```bash
git add docs/index.html docs/en/index.html CHANGELOG.md
git commit -m "docs: add ERP skills documentation and changelog"
```
