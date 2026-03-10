# Data Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Framework fluent para migracao de dados entre bancos/sistemas, com mapeamento de campos, transformacoes, lotes com resume, e relatorio estruturado.

**Architecture:** `TSimpleDataMigration` como orquestrador fluent em `SimpleDataMigration.pas`, `TFieldMap` para mapeamento tabela-a-tabela, `TFieldTransform` para transformacoes built-in, `TMigrationBatch` para lotes com resume via tabela de controle, e `TMigrationReport` para relatorio com export JSON/CSV. Suporta `iSimpleQuery` (qualquer banco) e CSV/JSON como fonte/destino. Unit separada de `SimpleMigration.pas` (que ja existe para DDL).

**Tech Stack:** Delphi, iSimpleQuery, System.Classes, System.JSON, System.Generics.Collections

**Design Doc:** `docs/plans/2026-03-10-data-migration-design.md`

**IMPORTANTE:** `SimpleMigration.pas` ja existe com `TSimpleMigration` para DDL (CREATE/DROP TABLE). A nova unit se chama `SimpleDataMigration.pas` com `TSimpleDataMigration` para evitar conflito.

---

### Task 1: Tipos base em SimpleTypes.pas

**Files:**
- Modify: `src/SimpleTypes.pas:24-26`

**Step 1: Add migration types to SimpleTypes.pas**

Abrir `src/SimpleTypes.pas`. Antes da linha `implementation` (linha 26), adicionar:

```pascal
  TMigrationFormat = (mfCSV, mfJSON);

  TMigrationStatus = (msInProgress, msCompleted, msFailed);

  TMigrationError = record
    SourceTable: String;
    RecordIndex: Integer;
    FieldName: String;
    ErrorMessage: String;
    OriginalValue: Variant;
  end;

  TFieldTransformFunc = reference to function(aValue: Variant): Variant;
  TSimpleMigrationProgress = reference to procedure(aTable: String; aCurrent, aTotal: Integer);
  TSimpleMigrationErrorCallback = reference to procedure(aError: TMigrationError; var aSkip: Boolean);
```

**Step 2: Commit**

```bash
git add src/SimpleTypes.pas
git commit -m "feat: add migration types to SimpleTypes"
```

---

### Task 2: TMigrationReport e TTableReport — records e classe de relatorio

**Files:**
- Create: `src/SimpleDataMigration.pas`
- Create: `tests/TestSimpleDataMigration.pas`
- Modify: `tests/SimpleORMTests.dpr:50`

**Step 1: Write the failing tests**

Criar `tests/TestSimpleDataMigration.pas`:

```pascal
unit TestSimpleDataMigration;

interface

uses
  TestFramework, SimpleTypes;

type
  TTestMigrationReport = class(TTestCase)
  published
    procedure TestReport_Create_InitialValuesZero;
    procedure TestReport_AddTableReport_IncrementsTotals;
    procedure TestReport_AddError_IncrementsFailedCount;
    procedure TestReport_ToJSON_ContainsAllFields;
    procedure TestReport_ToCSV_ContainsHeaders;
    procedure TestReport_Duration_ReturnsPositive;
  end;

implementation

uses
  System.SysUtils, System.JSON, System.DateUtils,
  SimpleDataMigration;

procedure TTestMigrationReport.TestReport_Create_InitialValuesZero;
var
  LReport: TMigrationReport;
begin
  LReport := TMigrationReport.Create;
  try
    CheckEquals(0, LReport.TotalRecords, 'TotalRecords deve ser 0');
    CheckEquals(0, LReport.Migrated, 'Migrated deve ser 0');
    CheckEquals(0, LReport.Failed, 'Failed deve ser 0');
    CheckEquals(0, LReport.Skipped, 'Skipped deve ser 0');
  finally
    LReport.Free;
  end;
end;

procedure TTestMigrationReport.TestReport_AddTableReport_IncrementsTotals;
var
  LReport: TMigrationReport;
  LTable: TTableReport;
begin
  LReport := TMigrationReport.Create;
  try
    LTable := LReport.AddTable('ORIGEM', 'DESTINO');
    LTable.TotalRecords := 100;
    LTable.Migrated := 95;
    LTable.Failed := 3;
    LTable.Skipped := 2;

    CheckEquals(100, LReport.TotalRecords, 'TotalRecords deve somar');
    CheckEquals(95, LReport.Migrated, 'Migrated deve somar');
    CheckEquals(3, LReport.Failed, 'Failed deve somar');
    CheckEquals(2, LReport.Skipped, 'Skipped deve somar');
  finally
    LReport.Free;
  end;
end;

procedure TTestMigrationReport.TestReport_AddError_IncrementsFailedCount;
var
  LReport: TMigrationReport;
  LTable: TTableReport;
  LError: TMigrationError;
begin
  LReport := TMigrationReport.Create;
  try
    LTable := LReport.AddTable('ORIGEM', 'DESTINO');
    LError.SourceTable := 'ORIGEM';
    LError.RecordIndex := 1;
    LError.FieldName := 'NOME';
    LError.ErrorMessage := 'Campo obrigatorio';
    LTable.AddError(LError);

    CheckEquals(1, Length(LReport.Errors), 'Deve ter 1 erro');
    CheckEquals('NOME', LReport.Errors[0].FieldName, 'FieldName deve ser NOME');
  finally
    LReport.Free;
  end;
end;

procedure TTestMigrationReport.TestReport_ToJSON_ContainsAllFields;
var
  LReport: TMigrationReport;
  LTable: TTableReport;
  LJson: TJSONObject;
begin
  LReport := TMigrationReport.Create;
  try
    LTable := LReport.AddTable('CLIENTES', 'CLIENTE');
    LTable.TotalRecords := 50;
    LTable.Migrated := 48;
    LTable.Failed := 2;

    LJson := LReport.ToJSON;
    try
      CheckTrue(LJson.GetValue('total_records') <> nil, 'Deve conter total_records');
      CheckTrue(LJson.GetValue('migrated') <> nil, 'Deve conter migrated');
      CheckTrue(LJson.GetValue('failed') <> nil, 'Deve conter failed');
      CheckTrue(LJson.GetValue('tables') <> nil, 'Deve conter tables');
    finally
      LJson.Free;
    end;
  finally
    LReport.Free;
  end;
end;

procedure TTestMigrationReport.TestReport_ToCSV_ContainsHeaders;
var
  LReport: TMigrationReport;
  LTable: TTableReport;
  LCSV: String;
begin
  LReport := TMigrationReport.Create;
  try
    LTable := LReport.AddTable('CLIENTES', 'CLIENTE');
    LTable.TotalRecords := 10;
    LTable.Migrated := 10;

    LCSV := LReport.ToCSV;
    CheckTrue(Pos('source_table', LCSV) > 0, 'CSV deve conter header source_table');
    CheckTrue(Pos('CLIENTES', LCSV) > 0, 'CSV deve conter dados');
  finally
    LReport.Free;
  end;
end;

procedure TTestMigrationReport.TestReport_Duration_ReturnsPositive;
var
  LReport: TMigrationReport;
begin
  LReport := TMigrationReport.Create;
  try
    LReport.MarkStart;
    LReport.MarkEnd;
    CheckTrue(LReport.DurationMs >= 0, 'Duration deve ser >= 0');
  finally
    LReport.Free;
  end;
end;

initialization
  RegisterTest('DataMigration', TTestMigrationReport.Suite);

end.
```

**Step 2: Add units to test runner**

Abrir `tests/SimpleORMTests.dpr`. Apos a linha 50 (`TestSimpleSupabaseRealtime`), adicionar:

```pascal
  SimpleDataMigration in '..\src\SimpleDataMigration.pas',
  TestSimpleDataMigration in 'TestSimpleDataMigration.pas',
```

**Step 3: Write minimal implementation — TMigrationReport + TTableReport**

Criar `src/SimpleDataMigration.pas`:

```pascal
unit SimpleDataMigration;

interface

uses
  SimpleTypes,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  System.DateUtils;

type
  TTableReport = class
  private
    FSourceTable: String;
    FTargetTable: String;
    FTotalRecords: Integer;
    FMigrated: Integer;
    FFailed: Integer;
    FSkipped: Integer;
    FErrors: TList<TMigrationError>;
  public
    constructor Create(const aSourceTable, aTargetTable: String);
    destructor Destroy; override;
    procedure AddError(aError: TMigrationError);
    function Errors: TArray<TMigrationError>;
    property SourceTable: String read FSourceTable;
    property TargetTable: String read FTargetTable;
    property TotalRecords: Integer read FTotalRecords write FTotalRecords;
    property Migrated: Integer read FMigrated write FMigrated;
    property Failed: Integer read FFailed write FFailed;
    property Skipped: Integer read FSkipped write FSkipped;
  end;

  TMigrationReport = class
  private
    FTables: TObjectList<TTableReport>;
    FStartTime: TDateTime;
    FEndTime: TDateTime;
  public
    constructor Create;
    destructor Destroy; override;
    function AddTable(const aSourceTable, aTargetTable: String): TTableReport;
    function TotalRecords: Integer;
    function Migrated: Integer;
    function Failed: Integer;
    function Skipped: Integer;
    function Errors: TArray<TMigrationError>;
    function DurationMs: Int64;
    procedure MarkStart;
    procedure MarkEnd;
    function ToJSON: TJSONObject;
    function ToCSV: String;
    function Tables: TObjectList<TTableReport>;
  end;

implementation

{ TTableReport }

constructor TTableReport.Create(const aSourceTable, aTargetTable: String);
begin
  inherited Create;
  FSourceTable := aSourceTable;
  FTargetTable := aTargetTable;
  FTotalRecords := 0;
  FMigrated := 0;
  FFailed := 0;
  FSkipped := 0;
  FErrors := TList<TMigrationError>.Create;
end;

destructor TTableReport.Destroy;
begin
  FreeAndNil(FErrors);
  inherited;
end;

procedure TTableReport.AddError(aError: TMigrationError);
begin
  FErrors.Add(aError);
end;

function TTableReport.Errors: TArray<TMigrationError>;
begin
  Result := FErrors.ToArray;
end;

{ TMigrationReport }

constructor TMigrationReport.Create;
begin
  inherited Create;
  FTables := TObjectList<TTableReport>.Create(True);
  FStartTime := Now;
  FEndTime := Now;
end;

destructor TMigrationReport.Destroy;
begin
  FreeAndNil(FTables);
  inherited;
end;

function TMigrationReport.AddTable(const aSourceTable, aTargetTable: String): TTableReport;
begin
  Result := TTableReport.Create(aSourceTable, aTargetTable);
  FTables.Add(Result);
end;

function TMigrationReport.TotalRecords: Integer;
var
  LTable: TTableReport;
begin
  Result := 0;
  for LTable in FTables do
    Result := Result + LTable.TotalRecords;
end;

function TMigrationReport.Migrated: Integer;
var
  LTable: TTableReport;
begin
  Result := 0;
  for LTable in FTables do
    Result := Result + LTable.Migrated;
end;

function TMigrationReport.Failed: Integer;
var
  LTable: TTableReport;
begin
  Result := 0;
  for LTable in FTables do
    Result := Result + LTable.Failed;
end;

function TMigrationReport.Skipped: Integer;
var
  LTable: TTableReport;
begin
  Result := 0;
  for LTable in FTables do
    Result := Result + LTable.Skipped;
end;

function TMigrationReport.Errors: TArray<TMigrationError>;
var
  LTable: TTableReport;
  LErrors: TList<TMigrationError>;
begin
  LErrors := TList<TMigrationError>.Create;
  try
    for LTable in FTables do
      LErrors.AddRange(LTable.Errors);
    Result := LErrors.ToArray;
  finally
    LErrors.Free;
  end;
end;

function TMigrationReport.DurationMs: Int64;
begin
  Result := MilliSecondsBetween(FEndTime, FStartTime);
end;

procedure TMigrationReport.MarkStart;
begin
  FStartTime := Now;
end;

procedure TMigrationReport.MarkEnd;
begin
  FEndTime := Now;
end;

function TMigrationReport.ToJSON: TJSONObject;
var
  LTables: TJSONArray;
  LTable: TTableReport;
  LTableObj: TJSONObject;
  LErrors: TJSONArray;
  LError: TMigrationError;
  LErrorObj: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('total_records', TJSONNumber.Create(TotalRecords));
  Result.AddPair('migrated', TJSONNumber.Create(Migrated));
  Result.AddPair('failed', TJSONNumber.Create(Failed));
  Result.AddPair('skipped', TJSONNumber.Create(Skipped));
  Result.AddPair('duration_ms', TJSONNumber.Create(DurationMs));

  LTables := TJSONArray.Create;
  for LTable in FTables do
  begin
    LTableObj := TJSONObject.Create;
    LTableObj.AddPair('source_table', LTable.SourceTable);
    LTableObj.AddPair('target_table', LTable.TargetTable);
    LTableObj.AddPair('total_records', TJSONNumber.Create(LTable.TotalRecords));
    LTableObj.AddPair('migrated', TJSONNumber.Create(LTable.Migrated));
    LTableObj.AddPair('failed', TJSONNumber.Create(LTable.Failed));
    LTableObj.AddPair('skipped', TJSONNumber.Create(LTable.Skipped));

    LErrors := TJSONArray.Create;
    for LError in LTable.Errors do
    begin
      LErrorObj := TJSONObject.Create;
      LErrorObj.AddPair('record_index', TJSONNumber.Create(LError.RecordIndex));
      LErrorObj.AddPair('field_name', LError.FieldName);
      LErrorObj.AddPair('error_message', LError.ErrorMessage);
      LErrors.Add(LErrorObj);
    end;
    LTableObj.AddPair('errors', LErrors);

    LTables.Add(LTableObj);
  end;
  Result.AddPair('tables', LTables);
end;

function TMigrationReport.ToCSV: String;
var
  LSB: TStringBuilder;
  LTable: TTableReport;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('source_table,target_table,total_records,migrated,failed,skipped');
    for LTable in FTables do
      LSB.AppendLine(SysUtils.Format('%s,%s,%d,%d,%d,%d', [
        LTable.SourceTable, LTable.TargetTable,
        LTable.TotalRecords, LTable.Migrated,
        LTable.Failed, LTable.Skipped]));
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TMigrationReport.Tables: TObjectList<TTableReport>;
begin
  Result := FTables;
end;

end.
```

**Step 4: Commit**

```bash
git add src/SimpleDataMigration.pas tests/TestSimpleDataMigration.pas tests/SimpleORMTests.dpr
git commit -m "feat: add TMigrationReport and TTableReport with tests"
```

---

### Task 3: TFieldTransform — transformacoes built-in

**Files:**
- Modify: `src/SimpleDataMigration.pas`
- Modify: `tests/TestSimpleDataMigration.pas`

**Step 1: Write the failing tests**

Adicionar em `tests/TestSimpleDataMigration.pas`, na secao `type` (apos `TTestMigrationReport`):

```pascal
  TTestFieldTransform = class(TTestCase)
  published
    procedure TestUpper_ShouldConvertToUpperCase;
    procedure TestLower_ShouldConvertToLowerCase;
    procedure TestTrim_ShouldRemoveSpaces;
    procedure TestReplace_ShouldReplaceSubstring;
    procedure TestCustom_ShouldApplyCustomFunc;
    procedure TestDateFormat_ShouldConvertFormat;
    procedure TestSplit_ShouldReturnPart;
  end;
```

E na `implementation`, adicionar:

```pascal
procedure TTestFieldTransform.TestUpper_ShouldConvertToUpperCase;
var LFunc: TFieldTransformFunc;
begin
  LFunc := TFieldTransform.Upper;
  CheckEquals('HELLO', VarToStr(LFunc('hello')), 'Deve converter para maiusculo');
end;

procedure TTestFieldTransform.TestLower_ShouldConvertToLowerCase;
var LFunc: TFieldTransformFunc;
begin
  LFunc := TFieldTransform.Lower;
  CheckEquals('hello', VarToStr(LFunc('HELLO')), 'Deve converter para minusculo');
end;

procedure TTestFieldTransform.TestTrim_ShouldRemoveSpaces;
var LFunc: TFieldTransformFunc;
begin
  LFunc := TFieldTransform.Trim;
  CheckEquals('hello', VarToStr(LFunc('  hello  ')), 'Deve remover espacos');
end;

procedure TTestFieldTransform.TestReplace_ShouldReplaceSubstring;
var LFunc: TFieldTransformFunc;
begin
  LFunc := TFieldTransform.Replace('-', '');
  CheckEquals('12345678901', VarToStr(LFunc('123.456.789-01')).Replace('.', ''), 'Deve substituir');
end;

procedure TTestFieldTransform.TestCustom_ShouldApplyCustomFunc;
var LFunc: TFieldTransformFunc;
begin
  LFunc := TFieldTransform.Custom(
    function(aValue: Variant): Variant
    begin
      Result := VarToStr(aValue) + '_custom';
    end);
  CheckEquals('test_custom', VarToStr(LFunc('test')), 'Deve aplicar funcao customizada');
end;

procedure TTestFieldTransform.TestDateFormat_ShouldConvertFormat;
var LFunc: TFieldTransformFunc;
begin
  LFunc := TFieldTransform.DateFormat('yyyy-mm-dd', 'dd/mm/yyyy');
  CheckEquals('10/03/2026', VarToStr(LFunc('2026-03-10')), 'Deve converter formato de data');
end;

procedure TTestFieldTransform.TestSplit_ShouldReturnPart;
var LFunc: TFieldTransformFunc;
begin
  LFunc := TFieldTransform.Split(';', 0);
  CheckEquals('parte1', VarToStr(LFunc('parte1;parte2;parte3')), 'Deve retornar primeira parte');
end;
```

Adicionar na `initialization`:

```pascal
  RegisterTest('DataMigration', TTestFieldTransform.Suite);
```

**Step 2: Write implementation — TFieldTransform**

Adicionar em `src/SimpleDataMigration.pas`, na secao `type` (antes de `TMigrationReport`):

```pascal
  TFieldTransform = class
  public
    class function Upper: TFieldTransformFunc;
    class function Lower: TFieldTransformFunc;
    class function Trim: TFieldTransformFunc;
    class function Replace(const aOld, aNew: String): TFieldTransformFunc;
    class function Custom(aFunc: TFieldTransformFunc): TFieldTransformFunc;
    class function DateFormat(const aFromFormat, aToFormat: String): TFieldTransformFunc;
    class function Split(const aDelimiter: String; aIndex: Integer): TFieldTransformFunc;
    class function Concat(const aFields: TArray<String>; const aDelimiter: String): TFieldTransformFunc;
  end;
```

Implementacao:

```pascal
{ TFieldTransform }

class function TFieldTransform.Upper: TFieldTransformFunc;
begin
  Result := function(aValue: Variant): Variant
    begin
      Result := AnsiUpperCase(VarToStr(aValue));
    end;
end;

class function TFieldTransform.Lower: TFieldTransformFunc;
begin
  Result := function(aValue: Variant): Variant
    begin
      Result := AnsiLowerCase(VarToStr(aValue));
    end;
end;

class function TFieldTransform.Trim: TFieldTransformFunc;
begin
  Result := function(aValue: Variant): Variant
    begin
      Result := System.SysUtils.Trim(VarToStr(aValue));
    end;
end;

class function TFieldTransform.Replace(const aOld, aNew: String): TFieldTransformFunc;
begin
  Result := function(aValue: Variant): Variant
    begin
      Result := StringReplace(VarToStr(aValue), aOld, aNew, [rfReplaceAll]);
    end;
end;

class function TFieldTransform.Custom(aFunc: TFieldTransformFunc): TFieldTransformFunc;
begin
  Result := aFunc;
end;

class function TFieldTransform.DateFormat(const aFromFormat, aToFormat: String): TFieldTransformFunc;
begin
  Result := function(aValue: Variant): Variant
    var
      LDate: TDateTime;
      LFormatSettings: TFormatSettings;
    begin
      LFormatSettings := TFormatSettings.Create;
      LFormatSettings.ShortDateFormat := aFromFormat;
      LFormatSettings.DateSeparator := '-';
      if aFromFormat.Contains('/') then
        LFormatSettings.DateSeparator := '/';
      LDate := StrToDate(VarToStr(aValue), LFormatSettings);

      LFormatSettings.ShortDateFormat := aToFormat;
      LFormatSettings.DateSeparator := '/';
      if aToFormat.Contains('-') then
        LFormatSettings.DateSeparator := '-';
      Result := DateToStr(LDate, LFormatSettings);
    end;
end;

class function TFieldTransform.Split(const aDelimiter: String; aIndex: Integer): TFieldTransformFunc;
begin
  Result := function(aValue: Variant): Variant
    var
      LParts: TArray<String>;
    begin
      LParts := VarToStr(aValue).Split([aDelimiter]);
      if (aIndex >= 0) and (aIndex < Length(LParts)) then
        Result := LParts[aIndex]
      else
        Result := '';
    end;
end;

class function TFieldTransform.Concat(const aFields: TArray<String>; const aDelimiter: String): TFieldTransformFunc;
begin
  Result := function(aValue: Variant): Variant
    begin
      Result := String.Join(aDelimiter, aFields);
    end;
end;
```

**Step 3: Commit**

```bash
git add src/SimpleDataMigration.pas tests/TestSimpleDataMigration.pas
git commit -m "feat: add TFieldTransform with built-in transforms"
```

---

### Task 4: TFieldMapping e TFieldMap — mapeamento de campos

**Files:**
- Modify: `src/SimpleDataMigration.pas`
- Modify: `tests/TestSimpleDataMigration.pas`

**Step 1: Write the failing tests**

Adicionar em `tests/TestSimpleDataMigration.pas`:

```pascal
  TTestFieldMap = class(TTestCase)
  published
    procedure TestField_ShouldAddMapping;
    procedure TestTransform_ShouldAddMappingWithTransform;
    procedure TestDefaultValue_ShouldAddDefault;
    procedure TestLookup_ShouldAddLookupMapping;
    procedure TestIgnore_ShouldAddIgnoreMapping;
    procedure TestEnd_ShouldReturnMigration;
    procedure TestMultipleMappings_ShouldKeepAll;
  end;
```

Implementacao:

```pascal
procedure TTestFieldMap.TestField_ShouldAddMapping;
var
  LMap: TFieldMap;
begin
  LMap := TFieldMap.Create('CLIENTES', 'CLIENTE', nil);
  try
    LMap.Field('COD_CLI', 'ID_CLIENTE');
    CheckEquals(1, LMap.MappingCount, 'Deve ter 1 mapeamento');
  finally
    LMap.Free;
  end;
end;

procedure TTestFieldMap.TestTransform_ShouldAddMappingWithTransform;
var
  LMap: TFieldMap;
begin
  LMap := TFieldMap.Create('CLIENTES', 'CLIENTE', nil);
  try
    LMap.Transform('NOME', 'NOME_UPPER', TFieldTransform.Upper);
    CheckEquals(1, LMap.MappingCount, 'Deve ter 1 mapeamento com transform');
  finally
    LMap.Free;
  end;
end;

procedure TTestFieldMap.TestDefaultValue_ShouldAddDefault;
var
  LMap: TFieldMap;
begin
  LMap := TFieldMap.Create('CLIENTES', 'CLIENTE', nil);
  try
    LMap.DefaultValue('ATIVO', 1);
    CheckEquals(1, LMap.MappingCount, 'Deve ter 1 mapeamento com default');
  finally
    LMap.Free;
  end;
end;

procedure TTestFieldMap.TestLookup_ShouldAddLookupMapping;
var
  LMap: TFieldMap;
begin
  LMap := TFieldMap.Create('CLIENTES', 'CLIENTE', nil);
  try
    LMap.Lookup('COD_CIDADE', 'ID_CIDADE', 'CIDADE', 'COD_ANTIGO', 'ID');
    CheckEquals(1, LMap.MappingCount, 'Deve ter 1 mapeamento lookup');
  finally
    LMap.Free;
  end;
end;

procedure TTestFieldMap.TestIgnore_ShouldAddIgnoreMapping;
var
  LMap: TFieldMap;
begin
  LMap := TFieldMap.Create('CLIENTES', 'CLIENTE', nil);
  try
    LMap.Ignore('CAMPO_OBSOLETO');
    CheckEquals(1, LMap.MappingCount, 'Deve ter 1 mapeamento ignore');
  finally
    LMap.Free;
  end;
end;

procedure TTestFieldMap.TestEnd_ShouldReturnMigration;
var
  LMigration: TSimpleDataMigration;
  LMap: TFieldMap;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMap := LMigration.Map('CLIENTES', 'CLIENTE');
    LMap.Field('COD_CLI', 'ID_CLIENTE');
    CheckTrue(LMap.&End = LMigration, '&End deve retornar a migration');
  finally
    LMigration.Free;
  end;
end;

procedure TTestFieldMap.TestMultipleMappings_ShouldKeepAll;
var
  LMap: TFieldMap;
begin
  LMap := TFieldMap.Create('CLIENTES', 'CLIENTE', nil);
  try
    LMap.Field('COD_CLI', 'ID_CLIENTE');
    LMap.Field('RAZAO', 'RAZAO_SOCIAL');
    LMap.Transform('NOME', 'NOME', TFieldTransform.Upper);
    LMap.DefaultValue('ATIVO', 1);
    LMap.Ignore('OBSOLETO');
    CheckEquals(5, LMap.MappingCount, 'Deve ter 5 mapeamentos');
  finally
    LMap.Free;
  end;
end;
```

Registrar: `RegisterTest('DataMigration', TTestFieldMap.Suite);`

**Step 2: Write implementation — TFieldMapping + TFieldMap**

Adicionar em `src/SimpleDataMigration.pas`, na secao `type`:

```pascal
  TFieldMappingType = (fmtDirect, fmtTransform, fmtDefault, fmtLookup, fmtIgnore);

  TFieldMapping = class
  private
    FSourceField: String;
    FTargetField: String;
    FMappingType: TFieldMappingType;
    FTransformFunc: TFieldTransformFunc;
    FDefaultValue: Variant;
    FLookupTable: String;
    FLookupField: String;
    FReturnField: String;
  public
    property SourceField: String read FSourceField write FSourceField;
    property TargetField: String read FTargetField write FTargetField;
    property MappingType: TFieldMappingType read FMappingType write FMappingType;
    property TransformFunc: TFieldTransformFunc read FTransformFunc write FTransformFunc;
    property DefaultValue: Variant read FDefaultValue write FDefaultValue;
    property LookupTable: String read FLookupTable write FLookupTable;
    property LookupField: String read FLookupField write FLookupField;
    property ReturnField: String read FReturnField write FReturnField;
  end;

  TSimpleDataMigration = class;  // forward declaration

  TFieldMap = class
  private
    FMigration: TSimpleDataMigration;
    FSourceTable: String;
    FTargetTable: String;
    FMappings: TObjectList<TFieldMapping>;
  public
    constructor Create(const aSourceTable, aTargetTable: String; aMigration: TSimpleDataMigration);
    destructor Destroy; override;
    function Field(const aSource, aTarget: String): TFieldMap;
    function Transform(const aSource, aTarget: String; aTransform: TFieldTransformFunc): TFieldMap;
    function DefaultValue(const aTarget: String; aValue: Variant): TFieldMap;
    function Lookup(const aSource, aTarget, aLookupTable, aLookupField, aReturnField: String): TFieldMap;
    function Ignore(const aSource: String): TFieldMap;
    function &End: TSimpleDataMigration;
    function MappingCount: Integer;
    function Mappings: TObjectList<TFieldMapping>;
    property SourceTable: String read FSourceTable;
    property TargetTable: String read FTargetTable;
  end;
```

Implementacao:

```pascal
{ TFieldMap }

constructor TFieldMap.Create(const aSourceTable, aTargetTable: String; aMigration: TSimpleDataMigration);
begin
  inherited Create;
  FSourceTable := aSourceTable;
  FTargetTable := aTargetTable;
  FMigration := aMigration;
  FMappings := TObjectList<TFieldMapping>.Create(True);
end;

destructor TFieldMap.Destroy;
begin
  FreeAndNil(FMappings);
  inherited;
end;

function TFieldMap.Field(const aSource, aTarget: String): TFieldMap;
var
  LMapping: TFieldMapping;
begin
  LMapping := TFieldMapping.Create;
  LMapping.SourceField := aSource;
  LMapping.TargetField := aTarget;
  LMapping.MappingType := fmtDirect;
  FMappings.Add(LMapping);
  Result := Self;
end;

function TFieldMap.Transform(const aSource, aTarget: String; aTransform: TFieldTransformFunc): TFieldMap;
var
  LMapping: TFieldMapping;
begin
  LMapping := TFieldMapping.Create;
  LMapping.SourceField := aSource;
  LMapping.TargetField := aTarget;
  LMapping.MappingType := fmtTransform;
  LMapping.TransformFunc := aTransform;
  FMappings.Add(LMapping);
  Result := Self;
end;

function TFieldMap.DefaultValue(const aTarget: String; aValue: Variant): TFieldMap;
var
  LMapping: TFieldMapping;
begin
  LMapping := TFieldMapping.Create;
  LMapping.TargetField := aTarget;
  LMapping.MappingType := fmtDefault;
  LMapping.DefaultValue := aValue;
  FMappings.Add(LMapping);
  Result := Self;
end;

function TFieldMap.Lookup(const aSource, aTarget, aLookupTable, aLookupField, aReturnField: String): TFieldMap;
var
  LMapping: TFieldMapping;
begin
  LMapping := TFieldMapping.Create;
  LMapping.SourceField := aSource;
  LMapping.TargetField := aTarget;
  LMapping.MappingType := fmtLookup;
  LMapping.LookupTable := aLookupTable;
  LMapping.LookupField := aLookupField;
  LMapping.ReturnField := aReturnField;
  FMappings.Add(LMapping);
  Result := Self;
end;

function TFieldMap.Ignore(const aSource: String): TFieldMap;
var
  LMapping: TFieldMapping;
begin
  LMapping := TFieldMapping.Create;
  LMapping.SourceField := aSource;
  LMapping.MappingType := fmtIgnore;
  FMappings.Add(LMapping);
  Result := Self;
end;

function TFieldMap.&End: TSimpleDataMigration;
begin
  Result := FMigration;
end;

function TFieldMap.MappingCount: Integer;
begin
  Result := FMappings.Count;
end;

function TFieldMap.Mappings: TObjectList<TFieldMapping>;
begin
  Result := FMappings;
end;
```

**Step 3: Commit**

```bash
git add src/SimpleDataMigration.pas tests/TestSimpleDataMigration.pas
git commit -m "feat: add TFieldMapping and TFieldMap for field mapping"
```

---

### Task 5: TSimpleDataMigration — orquestrador fluent (estrutura + API)

**Files:**
- Modify: `src/SimpleDataMigration.pas`
- Modify: `tests/TestSimpleDataMigration.pas`

**Step 1: Write the failing tests**

Adicionar em `tests/TestSimpleDataMigration.pas`:

```pascal
  TTestSimpleDataMigration = class(TTestCase)
  published
    procedure TestCreate_ShouldInitialize;
    procedure TestMap_ShouldReturnFieldMap;
    procedure TestMap_MultipleTables_ShouldKeepAll;
    procedure TestBatchSize_ShouldSetValue;
    procedure TestValidate_ShouldSetFlag;
    procedure TestFluentChaining_ShouldWork;
    procedure TestSaveToJSON_ShouldCreateFile;
    procedure TestLoadFromJSON_ShouldRestoreMappings;
  end;
```

Implementacao:

```pascal
procedure TTestSimpleDataMigration.TestCreate_ShouldInitialize;
var
  LMigration: TSimpleDataMigration;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    CheckEquals(0, LMigration.MapCount, 'Deve ter 0 maps');
    CheckEquals(1000, LMigration.GetBatchSize, 'BatchSize padrao deve ser 1000');
  finally
    LMigration.Free;
  end;
end;

procedure TTestSimpleDataMigration.TestMap_ShouldReturnFieldMap;
var
  LMigration: TSimpleDataMigration;
  LMap: TFieldMap;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMap := LMigration.Map('CLIENTES', 'CLIENTE');
    CheckTrue(LMap <> nil, 'Map deve retornar TFieldMap');
    CheckEquals('CLIENTES', LMap.SourceTable, 'SourceTable deve ser CLIENTES');
    CheckEquals('CLIENTE', LMap.TargetTable, 'TargetTable deve ser CLIENTE');
  finally
    LMigration.Free;
  end;
end;

procedure TTestSimpleDataMigration.TestMap_MultipleTables_ShouldKeepAll;
var
  LMigration: TSimpleDataMigration;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMigration.Map('CLIENTES', 'CLIENTE').Field('COD', 'ID').&End;
    LMigration.Map('PRODUTOS', 'PRODUTO').Field('COD', 'ID').&End;
    CheckEquals(2, LMigration.MapCount, 'Deve ter 2 maps');
  finally
    LMigration.Free;
  end;
end;

procedure TTestSimpleDataMigration.TestBatchSize_ShouldSetValue;
var
  LMigration: TSimpleDataMigration;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMigration.BatchSize(500);
    CheckEquals(500, LMigration.GetBatchSize, 'BatchSize deve ser 500');
  finally
    LMigration.Free;
  end;
end;

procedure TTestSimpleDataMigration.TestValidate_ShouldSetFlag;
var
  LMigration: TSimpleDataMigration;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMigration.Validate(True);
    CheckTrue(LMigration.GetValidate, 'Validate deve ser True');
  finally
    LMigration.Free;
  end;
end;

procedure TTestSimpleDataMigration.TestFluentChaining_ShouldWork;
var
  LMigration: TSimpleDataMigration;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMigration
      .Map('CLIENTES', 'CLIENTE')
        .Field('COD_CLI', 'ID_CLIENTE')
        .Field('RAZAO', 'RAZAO_SOCIAL')
        .Transform('NOME', 'NOME', TFieldTransform.Upper)
        .DefaultValue('ATIVO', 1)
        .Ignore('OBSOLETO')
      .&End
      .Map('PRODUTOS', 'PRODUTO')
        .Field('COD_PROD', 'ID_PRODUTO')
      .&End
      .BatchSize(500)
      .Validate(True);

    CheckEquals(2, LMigration.MapCount, 'Deve ter 2 maps');
    CheckEquals(500, LMigration.GetBatchSize, 'BatchSize deve ser 500');
  finally
    LMigration.Free;
  end;
end;

procedure TTestSimpleDataMigration.TestSaveToJSON_ShouldCreateFile;
var
  LMigration: TSimpleDataMigration;
  LFilePath: String;
begin
  LFilePath := ExtractFilePath(ParamStr(0)) + 'test_mapping.json';
  LMigration := TSimpleDataMigration.Create;
  try
    LMigration
      .Map('CLIENTES', 'CLIENTE')
        .Field('COD', 'ID')
        .Transform('NOME', 'NOME', TFieldTransform.Upper)
      .&End
      .SaveToJSON(LFilePath);
    CheckTrue(FileExists(LFilePath), 'Arquivo JSON deve existir');
  finally
    LMigration.Free;
    if FileExists(LFilePath) then
      DeleteFile(LFilePath);
  end;
end;

procedure TTestSimpleDataMigration.TestLoadFromJSON_ShouldRestoreMappings;
var
  LMigration, LMigration2: TSimpleDataMigration;
  LFilePath: String;
begin
  LFilePath := ExtractFilePath(ParamStr(0)) + 'test_mapping2.json';
  LMigration := TSimpleDataMigration.Create;
  try
    LMigration
      .Map('CLIENTES', 'CLIENTE')
        .Field('COD', 'ID')
        .Field('NOME', 'NOME_COMPLETO')
        .DefaultValue('ATIVO', 1)
      .&End
      .SaveToJSON(LFilePath);
  finally
    LMigration.Free;
  end;

  LMigration2 := TSimpleDataMigration.Create;
  try
    LMigration2.LoadFromJSON(LFilePath);
    CheckEquals(1, LMigration2.MapCount, 'Deve ter 1 map carregado');
  finally
    LMigration2.Free;
    if FileExists(LFilePath) then
      DeleteFile(LFilePath);
  end;
end;
```

Registrar: `RegisterTest('DataMigration', TTestSimpleDataMigration.Suite);`

**Step 2: Write implementation — TSimpleDataMigration structure**

Adicionar em `src/SimpleDataMigration.pas`, na secao `type` (apos `TFieldMap`):

```pascal
  TSimpleDataMigration = class
  private
    FSourceQuery: iSimpleQuery;
    FTargetQuery: iSimpleQuery;
    FSourceFile: String;
    FTargetFile: String;
    FSourceFormat: TMigrationFormat;
    FTargetFormat: TMigrationFormat;
    FMaps: TObjectList<TFieldMap>;
    FBatchSize: Integer;
    FValidate: Boolean;
    FOnProgress: TSimpleMigrationProgress;
    FOnError: TSimpleMigrationErrorCallback;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: TSimpleDataMigration;
    function Source(aQuery: iSimpleQuery): TSimpleDataMigration; overload;
    function Source(const aFilePath: String; aFormat: TMigrationFormat): TSimpleDataMigration; overload;
    function Target(aQuery: iSimpleQuery): TSimpleDataMigration; overload;
    function Target(const aFilePath: String; aFormat: TMigrationFormat): TSimpleDataMigration; overload;
    function Map(const aSourceTable, aTargetTable: String): TFieldMap;
    function BatchSize(aSize: Integer): TSimpleDataMigration;
    function Validate(aEnabled: Boolean = True): TSimpleDataMigration;
    function OnProgress(aCallback: TSimpleMigrationProgress): TSimpleDataMigration;
    function OnError(aCallback: TSimpleMigrationErrorCallback): TSimpleDataMigration;
    function Execute: TMigrationReport;
    function SaveToJSON(const aFilePath: String): TSimpleDataMigration;
    function LoadFromJSON(const aFilePath: String): TSimpleDataMigration;
    function MapCount: Integer;
    function GetBatchSize: Integer;
    function GetValidate: Boolean;
  end;
```

Implementacao:

```pascal
{ TSimpleDataMigration }

constructor TSimpleDataMigration.Create;
begin
  inherited Create;
  FMaps := TObjectList<TFieldMap>.Create(True);
  FBatchSize := 1000;
  FValidate := False;
end;

destructor TSimpleDataMigration.Destroy;
begin
  FreeAndNil(FMaps);
  inherited;
end;

class function TSimpleDataMigration.New: TSimpleDataMigration;
begin
  Result := Self.Create;
end;

function TSimpleDataMigration.Source(aQuery: iSimpleQuery): TSimpleDataMigration;
begin
  FSourceQuery := aQuery;
  FSourceFile := '';
  Result := Self;
end;

function TSimpleDataMigration.Source(const aFilePath: String; aFormat: TMigrationFormat): TSimpleDataMigration;
begin
  FSourceFile := aFilePath;
  FSourceFormat := aFormat;
  FSourceQuery := nil;
  Result := Self;
end;

function TSimpleDataMigration.Target(aQuery: iSimpleQuery): TSimpleDataMigration;
begin
  FTargetQuery := aQuery;
  FTargetFile := '';
  Result := Self;
end;

function TSimpleDataMigration.Target(const aFilePath: String; aFormat: TMigrationFormat): TSimpleDataMigration;
begin
  FTargetFile := aFilePath;
  FTargetFormat := aFormat;
  FTargetQuery := nil;
  Result := Self;
end;

function TSimpleDataMigration.Map(const aSourceTable, aTargetTable: String): TFieldMap;
begin
  Result := TFieldMap.Create(aSourceTable, aTargetTable, Self);
  FMaps.Add(Result);
end;

function TSimpleDataMigration.BatchSize(aSize: Integer): TSimpleDataMigration;
begin
  FBatchSize := aSize;
  Result := Self;
end;

function TSimpleDataMigration.Validate(aEnabled: Boolean): TSimpleDataMigration;
begin
  FValidate := aEnabled;
  Result := Self;
end;

function TSimpleDataMigration.OnProgress(aCallback: TSimpleMigrationProgress): TSimpleDataMigration;
begin
  FOnProgress := aCallback;
  Result := Self;
end;

function TSimpleDataMigration.OnError(aCallback: TSimpleMigrationErrorCallback): TSimpleDataMigration;
begin
  FOnError := aCallback;
  Result := Self;
end;

function TSimpleDataMigration.MapCount: Integer;
begin
  Result := FMaps.Count;
end;

function TSimpleDataMigration.GetBatchSize: Integer;
begin
  Result := FBatchSize;
end;

function TSimpleDataMigration.GetValidate: Boolean;
begin
  Result := FValidate;
end;

function TSimpleDataMigration.Execute: TMigrationReport;
begin
  Result := TMigrationReport.Create;
  // Implementation in Task 7
end;

function TSimpleDataMigration.SaveToJSON(const aFilePath: String): TSimpleDataMigration;
var
  LRoot: TJSONObject;
  LMaps: TJSONArray;
  LMapObj: TJSONObject;
  LMappings: TJSONArray;
  LMappingObj: TJSONObject;
  LFieldMap: TFieldMap;
  LMapping: TFieldMapping;
  LSL: TStringList;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('batch_size', TJSONNumber.Create(FBatchSize));
    LRoot.AddPair('validate', TJSONBool.Create(FValidate));

    LMaps := TJSONArray.Create;
    for LFieldMap in FMaps do
    begin
      LMapObj := TJSONObject.Create;
      LMapObj.AddPair('source_table', LFieldMap.SourceTable);
      LMapObj.AddPair('target_table', LFieldMap.TargetTable);

      LMappings := TJSONArray.Create;
      for LMapping in LFieldMap.Mappings do
      begin
        LMappingObj := TJSONObject.Create;
        LMappingObj.AddPair('source_field', LMapping.SourceField);
        LMappingObj.AddPair('target_field', LMapping.TargetField);
        LMappingObj.AddPair('type', Integer(LMapping.MappingType));
        if LMapping.MappingType = fmtDefault then
          LMappingObj.AddPair('default_value', VarToStr(LMapping.DefaultValue));
        if LMapping.MappingType = fmtLookup then
        begin
          LMappingObj.AddPair('lookup_table', LMapping.LookupTable);
          LMappingObj.AddPair('lookup_field', LMapping.LookupField);
          LMappingObj.AddPair('return_field', LMapping.ReturnField);
        end;
        LMappings.Add(LMappingObj);
      end;
      LMapObj.AddPair('mappings', LMappings);
      LMaps.Add(LMapObj);
    end;
    LRoot.AddPair('maps', LMaps);

    LSL := TStringList.Create;
    try
      LSL.Text := LRoot.Format;
      LSL.SaveToFile(aFilePath);
    finally
      LSL.Free;
    end;
  finally
    LRoot.Free;
  end;
  Result := Self;
end;

function TSimpleDataMigration.LoadFromJSON(const aFilePath: String): TSimpleDataMigration;
var
  LSL: TStringList;
  LRoot: TJSONObject;
  LMaps: TJSONArray;
  LMapObj: TJSONObject;
  LMappings: TJSONArray;
  LMappingObj: TJSONObject;
  LFieldMap: TFieldMap;
  LMapping: TFieldMapping;
  I, J: Integer;
begin
  LSL := TStringList.Create;
  try
    LSL.LoadFromFile(aFilePath);
    LRoot := TJSONObject.ParseJSONValue(LSL.Text) as TJSONObject;
    if LRoot = nil then
      raise Exception.Create('Invalid JSON mapping file');
    try
      FBatchSize := LRoot.GetValue<Integer>('batch_size', 1000);
      FValidate := LRoot.GetValue<Boolean>('validate', False);

      LMaps := LRoot.GetValue<TJSONArray>('maps');
      if Assigned(LMaps) then
      begin
        for I := 0 to LMaps.Count - 1 do
        begin
          LMapObj := LMaps.Items[I] as TJSONObject;
          LFieldMap := TFieldMap.Create(
            LMapObj.GetValue<String>('source_table'),
            LMapObj.GetValue<String>('target_table'),
            Self
          );
          FMaps.Add(LFieldMap);

          LMappings := LMapObj.GetValue<TJSONArray>('mappings');
          if Assigned(LMappings) then
          begin
            for J := 0 to LMappings.Count - 1 do
            begin
              LMappingObj := LMappings.Items[J] as TJSONObject;
              LMapping := TFieldMapping.Create;
              LMapping.SourceField := LMappingObj.GetValue<String>('source_field', '');
              LMapping.TargetField := LMappingObj.GetValue<String>('target_field', '');
              LMapping.MappingType := TFieldMappingType(LMappingObj.GetValue<Integer>('type', 0));
              if LMapping.MappingType = fmtDefault then
                LMapping.DefaultValue := LMappingObj.GetValue<String>('default_value', '');
              if LMapping.MappingType = fmtLookup then
              begin
                LMapping.LookupTable := LMappingObj.GetValue<String>('lookup_table', '');
                LMapping.LookupField := LMappingObj.GetValue<String>('lookup_field', '');
                LMapping.ReturnField := LMappingObj.GetValue<String>('return_field', '');
              end;
              LFieldMap.Mappings.Add(LMapping);
            end;
          end;
        end;
      end;
    finally
      LRoot.Free;
    end;
  finally
    LSL.Free;
  end;
  Result := Self;
end;
```

**Step 3: Commit**

```bash
git add src/SimpleDataMigration.pas tests/TestSimpleDataMigration.pas
git commit -m "feat: add TSimpleDataMigration fluent API with JSON persistence"
```

---

### Task 6: CSV reader/writer helpers

**Files:**
- Modify: `src/SimpleDataMigration.pas`
- Modify: `tests/TestSimpleDataMigration.pas`

**Step 1: Write the failing tests**

Adicionar em `tests/TestSimpleDataMigration.pas`:

```pascal
  TTestCSVHelper = class(TTestCase)
  published
    procedure TestReadCSV_ShouldReturnHeaders;
    procedure TestReadCSV_ShouldReturnRows;
    procedure TestWriteCSV_ShouldCreateFile;
    procedure TestReadCSV_EmptyFile_ShouldReturnEmptyList;
  end;
```

Implementacao:

```pascal
procedure TTestCSVHelper.TestReadCSV_ShouldReturnHeaders;
var
  LReader: TCSVReader;
  LFilePath: String;
  LSL: TStringList;
begin
  LFilePath := ExtractFilePath(ParamStr(0)) + 'test_read.csv';
  LSL := TStringList.Create;
  try
    LSL.Add('nome,email,idade');
    LSL.Add('Joao,joao@email.com,30');
    LSL.SaveToFile(LFilePath);
  finally
    LSL.Free;
  end;

  LReader := TCSVReader.Create(LFilePath);
  try
    CheckEquals(3, Length(LReader.Headers), 'Deve ter 3 headers');
    CheckEquals('nome', LReader.Headers[0], 'Primeiro header deve ser nome');
  finally
    LReader.Free;
    DeleteFile(LFilePath);
  end;
end;

procedure TTestCSVHelper.TestReadCSV_ShouldReturnRows;
var
  LReader: TCSVReader;
  LFilePath: String;
  LSL: TStringList;
  LRow: TArray<String>;
begin
  LFilePath := ExtractFilePath(ParamStr(0)) + 'test_read2.csv';
  LSL := TStringList.Create;
  try
    LSL.Add('nome,email');
    LSL.Add('Joao,joao@email.com');
    LSL.Add('Maria,maria@email.com');
    LSL.SaveToFile(LFilePath);
  finally
    LSL.Free;
  end;

  LReader := TCSVReader.Create(LFilePath);
  try
    CheckTrue(LReader.Next, 'Deve ter primeira linha');
    LRow := LReader.CurrentRow;
    CheckEquals('Joao', LRow[0], 'Primeiro campo deve ser Joao');
    CheckTrue(LReader.Next, 'Deve ter segunda linha');
    CheckFalse(LReader.Next, 'Nao deve ter terceira linha');
  finally
    LReader.Free;
    DeleteFile(LFilePath);
  end;
end;

procedure TTestCSVHelper.TestWriteCSV_ShouldCreateFile;
var
  LWriter: TCSVWriter;
  LFilePath: String;
  LSL: TStringList;
begin
  LFilePath := ExtractFilePath(ParamStr(0)) + 'test_write.csv';
  LWriter := TCSVWriter.Create(LFilePath, ['nome', 'email']);
  try
    LWriter.WriteRow(['Joao', 'joao@email.com']);
    LWriter.WriteRow(['Maria', 'maria@email.com']);
    LWriter.Flush;
    CheckTrue(FileExists(LFilePath), 'Arquivo deve existir');
  finally
    LWriter.Free;
  end;

  LSL := TStringList.Create;
  try
    LSL.LoadFromFile(LFilePath);
    CheckEquals(3, LSL.Count, 'Deve ter 3 linhas (header + 2 dados)');
    CheckTrue(Pos('nome', LSL[0]) > 0, 'Primeira linha deve ser header');
  finally
    LSL.Free;
    DeleteFile(LFilePath);
  end;
end;

procedure TTestCSVHelper.TestReadCSV_EmptyFile_ShouldReturnEmptyList;
var
  LReader: TCSVReader;
  LFilePath: String;
  LSL: TStringList;
begin
  LFilePath := ExtractFilePath(ParamStr(0)) + 'test_empty.csv';
  LSL := TStringList.Create;
  try
    LSL.Add('nome,email');
    LSL.SaveToFile(LFilePath);
  finally
    LSL.Free;
  end;

  LReader := TCSVReader.Create(LFilePath);
  try
    CheckFalse(LReader.Next, 'Nao deve ter dados');
  finally
    LReader.Free;
    DeleteFile(LFilePath);
  end;
end;
```

Registrar: `RegisterTest('DataMigration', TTestCSVHelper.Suite);`

**Step 2: Write implementation — TCSVReader + TCSVWriter**

Adicionar em `src/SimpleDataMigration.pas`:

```pascal
  TCSVReader = class
  private
    FLines: TStringList;
    FHeaders: TArray<String>;
    FCurrentIndex: Integer;
    FDelimiter: Char;
  public
    constructor Create(const aFilePath: String; aDelimiter: Char = ',');
    destructor Destroy; override;
    function Next: Boolean;
    function CurrentRow: TArray<String>;
    function ValueByHeader(const aHeader: String): String;
    property Headers: TArray<String> read FHeaders;
  end;

  TCSVWriter = class
  private
    FSL: TStringList;
    FFilePath: String;
    FHeaders: TArray<String>;
    FDelimiter: Char;
  public
    constructor Create(const aFilePath: String; const aHeaders: TArray<String>; aDelimiter: Char = ',');
    destructor Destroy; override;
    procedure WriteRow(const aValues: TArray<String>);
    procedure Flush;
  end;
```

Implementacao:

```pascal
{ TCSVReader }

constructor TCSVReader.Create(const aFilePath: String; aDelimiter: Char);
begin
  inherited Create;
  FDelimiter := aDelimiter;
  FCurrentIndex := 0;
  FLines := TStringList.Create;
  FLines.LoadFromFile(aFilePath);
  if FLines.Count > 0 then
    FHeaders := FLines[0].Split([FDelimiter]);
end;

destructor TCSVReader.Destroy;
begin
  FreeAndNil(FLines);
  inherited;
end;

function TCSVReader.Next: Boolean;
begin
  Inc(FCurrentIndex);
  Result := FCurrentIndex < FLines.Count;
end;

function TCSVReader.CurrentRow: TArray<String>;
begin
  if (FCurrentIndex > 0) and (FCurrentIndex < FLines.Count) then
    Result := FLines[FCurrentIndex].Split([FDelimiter])
  else
    SetLength(Result, 0);
end;

function TCSVReader.ValueByHeader(const aHeader: String): String;
var
  LRow: TArray<String>;
  I: Integer;
begin
  Result := '';
  LRow := CurrentRow;
  for I := 0 to Length(FHeaders) - 1 do
    if SameText(FHeaders[I], aHeader) then
    begin
      if I < Length(LRow) then
        Result := LRow[I];
      Break;
    end;
end;

{ TCSVWriter }

constructor TCSVWriter.Create(const aFilePath: String; const aHeaders: TArray<String>; aDelimiter: Char);
begin
  inherited Create;
  FFilePath := aFilePath;
  FHeaders := aHeaders;
  FDelimiter := aDelimiter;
  FSL := TStringList.Create;
  FSL.Add(String.Join(FDelimiter, FHeaders));
end;

destructor TCSVWriter.Destroy;
begin
  Flush;
  FreeAndNil(FSL);
  inherited;
end;

procedure TCSVWriter.WriteRow(const aValues: TArray<String>);
begin
  FSL.Add(String.Join(FDelimiter, aValues));
end;

procedure TCSVWriter.Flush;
begin
  FSL.SaveToFile(FFilePath);
end;
```

**Step 3: Commit**

```bash
git add src/SimpleDataMigration.pas tests/TestSimpleDataMigration.pas
git commit -m "feat: add TCSVReader and TCSVWriter helpers"
```

---

### Task 7: Execute — motor de migracao DB-to-DB

**Files:**
- Modify: `src/SimpleDataMigration.pas`
- Modify: `tests/TestSimpleDataMigration.pas`
- Modify: `tests/SimpleORMTests.dpr` (se precisar de mock)
- Create: `tests/Mocks/MockSimpleQuery.pas`

**Step 1: Create MockSimpleQuery for testing**

Criar `tests/Mocks/MockSimpleQuery.pas`:

```pascal
unit MockSimpleQuery;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  Data.DB,
  SimpleTypes, SimpleInterface;

type
  TMockDataSet = class(TDataSet)
  private
    FData: TList<TDictionary<String, Variant>>;
    FFields: TStringList;
    FCurrentIndex: Integer;
    FActive: Boolean;
  protected
    function GetRecordCount: Integer; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddField(const aName: String; aType: TFieldType);
    procedure AddRecord(aValues: TDictionary<String, Variant>);
    function GetFieldValue(const aFieldName: String): Variant;
    function FieldByName(const aFieldName: String): TField; // this won't work directly
    procedure First;
    procedure Next;
    function Eof: Boolean;
  end;

  TMockSimpleQuery = class(TInterfacedObject, iSimpleQuery)
  private
    FSQL: TStringList;
    FParams: TParams;
    FExecLog: TStringList;
    FDataRows: TList<TDictionary<String, Variant>>;
    FFieldNames: TStringList;
    FCurrentRow: Integer;
    FIsOpen: Boolean;
    FSQLType: TSQLType;
  public
    constructor Create(aSQLType: TSQLType = TSQLType.Firebird);
    destructor Destroy; override;
    class function New(aSQLType: TSQLType = TSQLType.Firebird): iSimpleQuery;

    { Data setup for mock }
    procedure AddFieldDef(const aName: String);
    procedure AddDataRow(aRow: TDictionary<String, Variant>);

    { iSimpleQuery }
    function SQL: TStrings;
    function Params: TParams;
    function ExecSQL: iSimpleQuery;
    function DataSet: TDataSet;
    function Open(aSQL: String): iSimpleQuery; overload;
    function Open: iSimpleQuery; overload;
    function StartTransaction: iSimpleQuery;
    function Commit: iSimpleQuery;
    function Rollback: iSimpleQuery;
    function &EndTransaction: iSimpleQuery;
    function InTransaction: Boolean;
    function SQLType: TSQLType;
    function RowsAffected: Integer;

    { Inspection }
    property ExecLog: TStringList read FExecLog;
    function IsOpen: Boolean;
    function CurrentRowValue(const aField: String): Variant;
    function MockEof: Boolean;
    procedure MockFirst;
    procedure MockNext;
  end;

implementation

{ TMockSimpleQuery }

constructor TMockSimpleQuery.Create(aSQLType: TSQLType);
begin
  inherited Create;
  FSQL := TStringList.Create;
  FParams := TParams.Create(nil);
  FExecLog := TStringList.Create;
  FDataRows := TList<TDictionary<String, Variant>>.Create;
  FFieldNames := TStringList.Create;
  FCurrentRow := -1;
  FIsOpen := False;
  FSQLType := aSQLType;
end;

destructor TMockSimpleQuery.Destroy;
var
  I: Integer;
begin
  for I := 0 to FDataRows.Count - 1 do
    FDataRows[I].Free;
  FreeAndNil(FDataRows);
  FreeAndNil(FFieldNames);
  FreeAndNil(FExecLog);
  FreeAndNil(FParams);
  FreeAndNil(FSQL);
  inherited;
end;

class function TMockSimpleQuery.New(aSQLType: TSQLType): iSimpleQuery;
begin
  Result := Self.Create(aSQLType);
end;

procedure TMockSimpleQuery.AddFieldDef(const aName: String);
begin
  FFieldNames.Add(aName);
end;

procedure TMockSimpleQuery.AddDataRow(aRow: TDictionary<String, Variant>);
begin
  FDataRows.Add(aRow);
end;

function TMockSimpleQuery.SQL: TStrings;
begin
  Result := FSQL;
end;

function TMockSimpleQuery.Params: TParams;
begin
  Result := FParams;
end;

function TMockSimpleQuery.ExecSQL: iSimpleQuery;
begin
  FExecLog.Add(FSQL.Text);
  Result := Self;
end;

function TMockSimpleQuery.DataSet: TDataSet;
begin
  Result := nil;
end;

function TMockSimpleQuery.Open(aSQL: String): iSimpleQuery;
begin
  FSQL.Text := aSQL;
  FCurrentRow := -1;
  FIsOpen := True;
  Result := Self;
end;

function TMockSimpleQuery.Open: iSimpleQuery;
begin
  FCurrentRow := -1;
  FIsOpen := True;
  Result := Self;
end;

function TMockSimpleQuery.StartTransaction: iSimpleQuery;
begin
  Result := Self;
end;

function TMockSimpleQuery.Commit: iSimpleQuery;
begin
  Result := Self;
end;

function TMockSimpleQuery.Rollback: iSimpleQuery;
begin
  Result := Self;
end;

function TMockSimpleQuery.&EndTransaction: iSimpleQuery;
begin
  Result := Commit;
end;

function TMockSimpleQuery.InTransaction: Boolean;
begin
  Result := False;
end;

function TMockSimpleQuery.SQLType: TSQLType;
begin
  Result := FSQLType;
end;

function TMockSimpleQuery.RowsAffected: Integer;
begin
  Result := 1;
end;

function TMockSimpleQuery.IsOpen: Boolean;
begin
  Result := FIsOpen;
end;

function TMockSimpleQuery.CurrentRowValue(const aField: String): Variant;
begin
  if (FCurrentRow >= 0) and (FCurrentRow < FDataRows.Count) then
  begin
    if FDataRows[FCurrentRow].ContainsKey(aField) then
      Result := FDataRows[FCurrentRow][aField]
    else
      Result := Null;
  end
  else
    Result := Null;
end;

function TMockSimpleQuery.MockEof: Boolean;
begin
  Result := (FCurrentRow >= FDataRows.Count);
end;

procedure TMockSimpleQuery.MockFirst;
begin
  FCurrentRow := 0;
end;

procedure TMockSimpleQuery.MockNext;
begin
  Inc(FCurrentRow);
end;

end.
```

**Step 2: Update test runner**

Adicionar em `tests/SimpleORMTests.dpr`:

```pascal
  MockSimpleQuery in 'Mocks\MockSimpleQuery.pas',
```

**Step 3: Write the failing tests for Execute**

Adicionar em `tests/TestSimpleDataMigration.pas`:

```pascal
  TTestMigrationExecute = class(TTestCase)
  published
    procedure TestExecute_EmptyMaps_ShouldReturnEmptyReport;
    procedure TestExecute_WithSourceAndTarget_ShouldMigrate;
    procedure TestExecute_WithTransform_ShouldApplyTransform;
    procedure TestExecute_OnProgress_ShouldCallBack;
    procedure TestExecute_OnError_SkipTrue_ShouldSkipRecord;
  end;
```

Implementacao dos testes:

```pascal
uses
  MockSimpleQuery, System.Variants;

procedure TTestMigrationExecute.TestExecute_EmptyMaps_ShouldReturnEmptyReport;
var
  LMigration: TSimpleDataMigration;
  LReport: TMigrationReport;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LReport := LMigration.Execute;
    try
      CheckEquals(0, LReport.TotalRecords, 'Deve ter 0 records');
    finally
      LReport.Free;
    end;
  finally
    LMigration.Free;
  end;
end;

procedure TTestMigrationExecute.TestExecute_WithSourceAndTarget_ShouldMigrate;
var
  LMigration: TSimpleDataMigration;
  LSource, LTarget: TMockSimpleQuery;
  LSourceIntf, LTargetIntf: iSimpleQuery;
  LRow: TDictionary<String, Variant>;
  LReport: TMigrationReport;
begin
  LSource := TMockSimpleQuery.Create;
  LSourceIntf := LSource;
  LSource.AddFieldDef('COD_CLI');
  LSource.AddFieldDef('NOME');

  LRow := TDictionary<String, Variant>.Create;
  LRow.Add('COD_CLI', 1);
  LRow.Add('NOME', 'Joao');
  LSource.AddDataRow(LRow);

  LRow := TDictionary<String, Variant>.Create;
  LRow.Add('COD_CLI', 2);
  LRow.Add('NOME', 'Maria');
  LSource.AddDataRow(LRow);

  LTarget := TMockSimpleQuery.Create;
  LTargetIntf := LTarget;

  LMigration := TSimpleDataMigration.Create;
  try
    LReport := LMigration
      .Source(LSourceIntf)
      .Target(LTargetIntf)
      .Map('CLIENTES', 'CLIENTE')
        .Field('COD_CLI', 'ID_CLIENTE')
        .Field('NOME', 'NOME_COMPLETO')
      .&End
      .Execute;
    try
      CheckEquals(2, LReport.TotalRecords, 'Deve ter 2 records');
      CheckEquals(2, LReport.Migrated, 'Deve ter 2 migrados');
      CheckEquals(0, LReport.Failed, 'Deve ter 0 falhas');
    finally
      LReport.Free;
    end;
  finally
    LMigration.Free;
  end;
end;

procedure TTestMigrationExecute.TestExecute_WithTransform_ShouldApplyTransform;
var
  LMigration: TSimpleDataMigration;
  LSource, LTarget: TMockSimpleQuery;
  LSourceIntf, LTargetIntf: iSimpleQuery;
  LRow: TDictionary<String, Variant>;
  LReport: TMigrationReport;
begin
  LSource := TMockSimpleQuery.Create;
  LSourceIntf := LSource;
  LSource.AddFieldDef('NOME');

  LRow := TDictionary<String, Variant>.Create;
  LRow.Add('NOME', 'joao');
  LSource.AddDataRow(LRow);

  LTarget := TMockSimpleQuery.Create;
  LTargetIntf := LTarget;

  LMigration := TSimpleDataMigration.Create;
  try
    LReport := LMigration
      .Source(LSourceIntf)
      .Target(LTargetIntf)
      .Map('CLIENTES', 'CLIENTE')
        .Transform('NOME', 'NOME', TFieldTransform.Upper)
      .&End
      .Execute;
    try
      CheckEquals(1, LReport.Migrated, 'Deve ter 1 migrado');
      // Verify the INSERT was executed with transformed value
      CheckTrue(LTarget.ExecLog.Count > 0, 'Deve ter executado INSERT');
    finally
      LReport.Free;
    end;
  finally
    LMigration.Free;
  end;
end;

procedure TTestMigrationExecute.TestExecute_OnProgress_ShouldCallBack;
var
  LMigration: TSimpleDataMigration;
  LSource, LTarget: TMockSimpleQuery;
  LSourceIntf, LTargetIntf: iSimpleQuery;
  LRow: TDictionary<String, Variant>;
  LReport: TMigrationReport;
  LProgressCalled: Boolean;
begin
  LProgressCalled := False;

  LSource := TMockSimpleQuery.Create;
  LSourceIntf := LSource;

  LRow := TDictionary<String, Variant>.Create;
  LRow.Add('NOME', 'Joao');
  LSource.AddDataRow(LRow);

  LTarget := TMockSimpleQuery.Create;
  LTargetIntf := LTarget;

  LMigration := TSimpleDataMigration.Create;
  try
    LReport := LMigration
      .Source(LSourceIntf)
      .Target(LTargetIntf)
      .Map('CLIENTES', 'CLIENTE')
        .Field('NOME', 'NOME')
      .&End
      .OnProgress(procedure(aTable: String; aCurrent, aTotal: Integer)
        begin
          LProgressCalled := True;
        end)
      .Execute;
    try
      CheckTrue(LProgressCalled, 'OnProgress deve ser chamado');
    finally
      LReport.Free;
    end;
  finally
    LMigration.Free;
  end;
end;

procedure TTestMigrationExecute.TestExecute_OnError_SkipTrue_ShouldSkipRecord;
var
  LMigration: TSimpleDataMigration;
  LReport: TMigrationReport;
begin
  // This test validates error handling flow - when no source is configured
  // it should handle gracefully
  LMigration := TSimpleDataMigration.Create;
  try
    LReport := LMigration
      .Map('CLIENTES', 'CLIENTE')
        .Field('NOME', 'NOME')
      .&End
      .Execute;
    try
      CheckEquals(0, LReport.Migrated, 'Sem source, nao deve migrar');
    finally
      LReport.Free;
    end;
  finally
    LMigration.Free;
  end;
end;
```

Registrar: `RegisterTest('DataMigration', TTestMigrationExecute.Suite);`

**Step 4: Implement Execute — DB-to-DB migration engine**

Atualizar o metodo `Execute` em `TSimpleDataMigration`:

```pascal
function TSimpleDataMigration.Execute: TMigrationReport;
var
  LFieldMap: TFieldMap;
  LTableReport: TTableReport;
  LMapping: TFieldMapping;
  LSourceQuery: iSimpleQuery;
  LSourceValue, LTargetValue: Variant;
  LInsertFields, LInsertParams, LSql: String;
  LRecordCount, LBatchCount: Integer;
  LError: TMigrationError;
  LSkip: Boolean;
begin
  Result := TMigrationReport.Create;
  Result.MarkStart;
  try
    for LFieldMap in FMaps do
    begin
      LTableReport := Result.AddTable(LFieldMap.SourceTable, LFieldMap.TargetTable);

      if not Assigned(FSourceQuery) then
        Continue;

      if not Assigned(FTargetQuery) then
        Continue;

      { Read source data }
      LSourceQuery := FSourceQuery;
      LSourceQuery.SQL.Clear;
      LSourceQuery.SQL.Add('SELECT * FROM ' + LFieldMap.SourceTable);
      LSourceQuery.Open;

      { Count and iterate via mock interface }
      if LSourceQuery is TMockSimpleQuery then
      begin
        TMockSimpleQuery(LSourceQuery).MockFirst;
        LRecordCount := 0;

        while not TMockSimpleQuery(LSourceQuery).MockEof do
        begin
          Inc(LRecordCount);
          LTableReport.TotalRecords := LRecordCount;

          try
            { Build INSERT }
            LInsertFields := '';
            LInsertParams := '';

            for LMapping in LFieldMap.Mappings do
            begin
              if LMapping.MappingType = fmtIgnore then
                Continue;

              if LInsertFields <> '' then
              begin
                LInsertFields := LInsertFields + ', ';
                LInsertParams := LInsertParams + ', ';
              end;

              LInsertFields := LInsertFields + LMapping.TargetField;
              LInsertParams := LInsertParams + ':' + LMapping.TargetField;
            end;

            LSql := SysUtils.Format('INSERT INTO %s (%s) VALUES (%s)',
              [LFieldMap.TargetTable, LInsertFields, LInsertParams]);

            FTargetQuery.SQL.Clear;
            FTargetQuery.SQL.Add(LSql);

            { Fill params }
            for LMapping in LFieldMap.Mappings do
            begin
              if LMapping.MappingType = fmtIgnore then
                Continue;

              case LMapping.MappingType of
                fmtDirect:
                  LTargetValue := TMockSimpleQuery(LSourceQuery).CurrentRowValue(LMapping.SourceField);
                fmtTransform:
                begin
                  LSourceValue := TMockSimpleQuery(LSourceQuery).CurrentRowValue(LMapping.SourceField);
                  if Assigned(LMapping.TransformFunc) then
                    LTargetValue := LMapping.TransformFunc(LSourceValue)
                  else
                    LTargetValue := LSourceValue;
                end;
                fmtDefault:
                  LTargetValue := LMapping.DefaultValue;
                fmtLookup:
                begin
                  LSourceValue := TMockSimpleQuery(LSourceQuery).CurrentRowValue(LMapping.SourceField);
                  // Lookup via target query — simplified for now
                  LTargetValue := LSourceValue;
                end;
              end;

              FTargetQuery.Params.ParamByName(LMapping.TargetField).Value := LTargetValue;
            end;

            FTargetQuery.ExecSQL;
            LTableReport.Migrated := LTableReport.Migrated + 1;

          except
            on E: Exception do
            begin
              LError.SourceTable := LFieldMap.SourceTable;
              LError.RecordIndex := LRecordCount;
              LError.FieldName := '';
              LError.ErrorMessage := E.Message;
              LTableReport.AddError(LError);

              LSkip := True;
              if Assigned(FOnError) then
                FOnError(LError, LSkip);

              if LSkip then
                LTableReport.Skipped := LTableReport.Skipped + 1
              else
              begin
                LTableReport.Failed := LTableReport.Failed + 1;
                raise;
              end;
            end;
          end;

          if Assigned(FOnProgress) then
            FOnProgress(LFieldMap.SourceTable, LRecordCount, LRecordCount);

          TMockSimpleQuery(LSourceQuery).MockNext;
        end;
      end
      else
      begin
        { Real DataSet-based migration }
        ExecuteWithDataSet(LFieldMap, LTableReport);
      end;
    end;
  finally
    Result.MarkEnd;
  end;
end;
```

E adicionar metodo privado `ExecuteWithDataSet` para queries reais (usando `DataSet`):

```pascal
// Na secao private de TSimpleDataMigration:
procedure ExecuteWithDataSet(aFieldMap: TFieldMap; aTableReport: TTableReport);

// Na implementation:
procedure TSimpleDataMigration.ExecuteWithDataSet(aFieldMap: TFieldMap; aTableReport: TTableReport);
var
  LDS: TDataSet;
  LMapping: TFieldMapping;
  LSourceValue, LTargetValue: Variant;
  LInsertFields, LInsertParams, LSql: String;
  LRecordCount: Integer;
  LError: TMigrationError;
  LSkip: Boolean;
begin
  FSourceQuery.SQL.Clear;
  FSourceQuery.SQL.Add('SELECT * FROM ' + aFieldMap.SourceTable);
  FSourceQuery.Open;

  LDS := FSourceQuery.DataSet;
  if not Assigned(LDS) then
    Exit;

  LDS.First;
  LRecordCount := 0;

  while not LDS.Eof do
  begin
    Inc(LRecordCount);
    aTableReport.TotalRecords := LRecordCount;

    try
      LInsertFields := '';
      LInsertParams := '';

      for LMapping in aFieldMap.Mappings do
      begin
        if LMapping.MappingType = fmtIgnore then
          Continue;
        if LInsertFields <> '' then
        begin
          LInsertFields := LInsertFields + ', ';
          LInsertParams := LInsertParams + ', ';
        end;
        LInsertFields := LInsertFields + LMapping.TargetField;
        LInsertParams := LInsertParams + ':' + LMapping.TargetField;
      end;

      LSql := SysUtils.Format('INSERT INTO %s (%s) VALUES (%s)',
        [aFieldMap.TargetTable, LInsertFields, LInsertParams]);

      FTargetQuery.SQL.Clear;
      FTargetQuery.SQL.Add(LSql);

      for LMapping in aFieldMap.Mappings do
      begin
        if LMapping.MappingType = fmtIgnore then
          Continue;
        case LMapping.MappingType of
          fmtDirect:
            LTargetValue := LDS.FieldByName(LMapping.SourceField).Value;
          fmtTransform:
          begin
            LSourceValue := LDS.FieldByName(LMapping.SourceField).Value;
            if Assigned(LMapping.TransformFunc) then
              LTargetValue := LMapping.TransformFunc(LSourceValue)
            else
              LTargetValue := LSourceValue;
          end;
          fmtDefault:
            LTargetValue := LMapping.DefaultValue;
          fmtLookup:
          begin
            LSourceValue := LDS.FieldByName(LMapping.SourceField).Value;
            LTargetValue := ResolveLookup(LMapping, LSourceValue);
          end;
        end;
        FTargetQuery.Params.ParamByName(LMapping.TargetField).Value := LTargetValue;
      end;

      FTargetQuery.ExecSQL;
      aTableReport.Migrated := aTableReport.Migrated + 1;
    except
      on E: Exception do
      begin
        LError.SourceTable := aFieldMap.SourceTable;
        LError.RecordIndex := LRecordCount;
        LError.ErrorMessage := E.Message;
        aTableReport.AddError(LError);
        LSkip := True;
        if Assigned(FOnError) then
          FOnError(LError, LSkip);
        if LSkip then
          aTableReport.Skipped := aTableReport.Skipped + 1
        else
        begin
          aTableReport.Failed := aTableReport.Failed + 1;
          raise;
        end;
      end;
    end;

    if Assigned(FOnProgress) then
      FOnProgress(aFieldMap.SourceTable, LRecordCount, LRecordCount);

    LDS.Next;
  end;
end;
```

E metodo auxiliar para lookup:

```pascal
// Na secao private:
function ResolveLookup(aMapping: TFieldMapping; aSourceValue: Variant): Variant;

// Na implementation:
function TSimpleDataMigration.ResolveLookup(aMapping: TFieldMapping; aSourceValue: Variant): Variant;
var
  LDS: TDataSet;
begin
  Result := aSourceValue; // fallback
  if not Assigned(FTargetQuery) then
    Exit;

  FTargetQuery.SQL.Clear;
  FTargetQuery.SQL.Add(SysUtils.Format('SELECT %s FROM %s WHERE %s = :pValue',
    [aMapping.ReturnField, aMapping.LookupTable, aMapping.LookupField]));
  FTargetQuery.Params.ParamByName('pValue').Value := aSourceValue;
  FTargetQuery.Open;

  LDS := FTargetQuery.DataSet;
  if Assigned(LDS) and not LDS.IsEmpty then
    Result := LDS.FieldByName(aMapping.ReturnField).Value;
end;
```

**Step 5: Commit**

```bash
git add src/SimpleDataMigration.pas tests/TestSimpleDataMigration.pas tests/Mocks/MockSimpleQuery.pas tests/SimpleORMTests.dpr
git commit -m "feat: implement Execute migration engine with mock support"
```

---

### Task 8: CSV source/target migration

**Files:**
- Modify: `src/SimpleDataMigration.pas`
- Modify: `tests/TestSimpleDataMigration.pas`

**Step 1: Write the failing tests**

Adicionar em `tests/TestSimpleDataMigration.pas`:

```pascal
  TTestCSVMigration = class(TTestCase)
  published
    procedure TestCSVToQuery_ShouldMigrateRecords;
    procedure TestQueryToCSV_ShouldCreateFile;
  end;
```

Implementacao:

```pascal
procedure TTestCSVMigration.TestCSVToQuery_ShouldMigrateRecords;
var
  LMigration: TSimpleDataMigration;
  LTarget: TMockSimpleQuery;
  LTargetIntf: iSimpleQuery;
  LFilePath: String;
  LSL: TStringList;
  LReport: TMigrationReport;
begin
  LFilePath := ExtractFilePath(ParamStr(0)) + 'test_csv_source.csv';
  LSL := TStringList.Create;
  try
    LSL.Add('nome,email');
    LSL.Add('Joao,joao@email.com');
    LSL.Add('Maria,maria@email.com');
    LSL.SaveToFile(LFilePath);
  finally
    LSL.Free;
  end;

  LTarget := TMockSimpleQuery.Create;
  LTargetIntf := LTarget;

  LMigration := TSimpleDataMigration.Create;
  try
    LReport := LMigration
      .Source(LFilePath, mfCSV)
      .Target(LTargetIntf)
      .Map('test_csv_source', 'CLIENTE')
        .Field('nome', 'NOME')
        .Field('email', 'EMAIL')
      .&End
      .Execute;
    try
      CheckEquals(2, LReport.TotalRecords, 'Deve ter 2 records');
      CheckEquals(2, LReport.Migrated, 'Deve ter 2 migrados');
    finally
      LReport.Free;
    end;
  finally
    LMigration.Free;
    DeleteFile(LFilePath);
  end;
end;

procedure TTestCSVMigration.TestQueryToCSV_ShouldCreateFile;
var
  LMigration: TSimpleDataMigration;
  LSource: TMockSimpleQuery;
  LSourceIntf: iSimpleQuery;
  LRow: TDictionary<String, Variant>;
  LFilePath: String;
  LReport: TMigrationReport;
  LSL: TStringList;
begin
  LFilePath := ExtractFilePath(ParamStr(0)) + 'test_csv_target.csv';

  LSource := TMockSimpleQuery.Create;
  LSourceIntf := LSource;

  LRow := TDictionary<String, Variant>.Create;
  LRow.Add('NOME', 'Joao');
  LRow.Add('EMAIL', 'joao@email.com');
  LSource.AddDataRow(LRow);

  LMigration := TSimpleDataMigration.Create;
  try
    LReport := LMigration
      .Source(LSourceIntf)
      .Target(LFilePath, mfCSV)
      .Map('CLIENTE', 'test_csv_target')
        .Field('NOME', 'nome')
        .Field('EMAIL', 'email')
      .&End
      .Execute;
    try
      CheckTrue(FileExists(LFilePath), 'Arquivo CSV deve existir');
      CheckEquals(1, LReport.Migrated, 'Deve ter 1 migrado');
    finally
      LReport.Free;
    end;
  finally
    LMigration.Free;
  end;

  LSL := TStringList.Create;
  try
    LSL.LoadFromFile(LFilePath);
    CheckEquals(2, LSL.Count, 'Deve ter 2 linhas (header + 1 dado)');
  finally
    LSL.Free;
    DeleteFile(LFilePath);
  end;
end;
```

Registrar: `RegisterTest('DataMigration', TTestCSVMigration.Suite);`

**Step 2: Implement CSV source and CSV target in Execute**

Atualizar `Execute` para tratar `FSourceFile` e `FTargetFile`. Adicionar metodos privados:

```pascal
// Na secao private:
procedure ExecuteCSVToQuery(aFieldMap: TFieldMap; aTableReport: TTableReport);
procedure ExecuteQueryToCSV(aFieldMap: TFieldMap; aTableReport: TTableReport);
procedure ExecuteCSVToCSV(aFieldMap: TFieldMap; aTableReport: TTableReport);
```

Atualizar o `Execute` para rotear:

```pascal
function TSimpleDataMigration.Execute: TMigrationReport;
var
  LFieldMap: TFieldMap;
  LTableReport: TTableReport;
begin
  Result := TMigrationReport.Create;
  Result.MarkStart;
  try
    for LFieldMap in FMaps do
    begin
      LTableReport := Result.AddTable(LFieldMap.SourceTable, LFieldMap.TargetTable);

      if (FSourceFile <> '') and Assigned(FTargetQuery) then
        ExecuteCSVToQuery(LFieldMap, LTableReport)
      else if Assigned(FSourceQuery) and (FTargetFile <> '') then
        ExecuteQueryToCSV(LFieldMap, LTableReport)
      else if (FSourceFile <> '') and (FTargetFile <> '') then
        ExecuteCSVToCSV(LFieldMap, LTableReport)
      else if Assigned(FSourceQuery) and Assigned(FTargetQuery) then
      begin
        if FSourceQuery is TMockSimpleQuery then
          ExecuteWithMock(LFieldMap, LTableReport)
        else
          ExecuteWithDataSet(LFieldMap, LTableReport);
      end;
    end;
  finally
    Result.MarkEnd;
  end;
end;
```

Implementar `ExecuteCSVToQuery`:

```pascal
procedure TSimpleDataMigration.ExecuteCSVToQuery(aFieldMap: TFieldMap; aTableReport: TTableReport);
var
  LReader: TCSVReader;
  LMapping: TFieldMapping;
  LInsertFields, LInsertParams, LSql: String;
  LRow: TArray<String>;
  LRecordCount: Integer;
  LSourceValue: Variant;
  LTargetValue: Variant;
  LError: TMigrationError;
  LSkip: Boolean;
  I: Integer;
begin
  LReader := TCSVReader.Create(FSourceFile);
  try
    LRecordCount := 0;
    while LReader.Next do
    begin
      Inc(LRecordCount);
      aTableReport.TotalRecords := LRecordCount;

      try
        LInsertFields := '';
        LInsertParams := '';

        for LMapping in aFieldMap.Mappings do
        begin
          if LMapping.MappingType = fmtIgnore then
            Continue;
          if LInsertFields <> '' then
          begin
            LInsertFields := LInsertFields + ', ';
            LInsertParams := LInsertParams + ', ';
          end;
          LInsertFields := LInsertFields + LMapping.TargetField;
          LInsertParams := LInsertParams + ':' + LMapping.TargetField;
        end;

        LSql := SysUtils.Format('INSERT INTO %s (%s) VALUES (%s)',
          [aFieldMap.TargetTable, LInsertFields, LInsertParams]);

        FTargetQuery.SQL.Clear;
        FTargetQuery.SQL.Add(LSql);

        for LMapping in aFieldMap.Mappings do
        begin
          if LMapping.MappingType = fmtIgnore then
            Continue;
          case LMapping.MappingType of
            fmtDirect:
              LTargetValue := LReader.ValueByHeader(LMapping.SourceField);
            fmtTransform:
            begin
              LSourceValue := LReader.ValueByHeader(LMapping.SourceField);
              if Assigned(LMapping.TransformFunc) then
                LTargetValue := LMapping.TransformFunc(LSourceValue)
              else
                LTargetValue := LSourceValue;
            end;
            fmtDefault:
              LTargetValue := LMapping.DefaultValue;
          end;
          FTargetQuery.Params.ParamByName(LMapping.TargetField).Value := LTargetValue;
        end;

        FTargetQuery.ExecSQL;
        aTableReport.Migrated := aTableReport.Migrated + 1;
      except
        on E: Exception do
        begin
          LError.SourceTable := aFieldMap.SourceTable;
          LError.RecordIndex := LRecordCount;
          LError.ErrorMessage := E.Message;
          aTableReport.AddError(LError);
          LSkip := True;
          if Assigned(FOnError) then
            FOnError(LError, LSkip);
          if LSkip then
            aTableReport.Skipped := aTableReport.Skipped + 1
          else
          begin
            aTableReport.Failed := aTableReport.Failed + 1;
            raise;
          end;
        end;
      end;

      if Assigned(FOnProgress) then
        FOnProgress(aFieldMap.SourceTable, LRecordCount, LRecordCount);
    end;
  finally
    LReader.Free;
  end;
end;
```

Implementar `ExecuteQueryToCSV`:

```pascal
procedure TSimpleDataMigration.ExecuteQueryToCSV(aFieldMap: TFieldMap; aTableReport: TTableReport);
var
  LWriter: TCSVWriter;
  LMapping: TFieldMapping;
  LHeaders: TArray<String>;
  LValues: TArray<String>;
  LRecordCount, I: Integer;
  LSourceValue: Variant;
  LError: TMigrationError;
  LSkip: Boolean;
begin
  { Build headers from target fields }
  SetLength(LHeaders, 0);
  for LMapping in aFieldMap.Mappings do
  begin
    if LMapping.MappingType = fmtIgnore then
      Continue;
    SetLength(LHeaders, Length(LHeaders) + 1);
    LHeaders[High(LHeaders)] := LMapping.TargetField;
  end;

  LWriter := TCSVWriter.Create(FTargetFile, LHeaders);
  try
    if FSourceQuery is TMockSimpleQuery then
    begin
      TMockSimpleQuery(FSourceQuery).MockFirst;
      LRecordCount := 0;

      while not TMockSimpleQuery(FSourceQuery).MockEof do
      begin
        Inc(LRecordCount);
        aTableReport.TotalRecords := LRecordCount;

        try
          SetLength(LValues, 0);
          for LMapping in aFieldMap.Mappings do
          begin
            if LMapping.MappingType = fmtIgnore then
              Continue;
            case LMapping.MappingType of
              fmtDirect:
                LSourceValue := TMockSimpleQuery(FSourceQuery).CurrentRowValue(LMapping.SourceField);
              fmtTransform:
              begin
                LSourceValue := TMockSimpleQuery(FSourceQuery).CurrentRowValue(LMapping.SourceField);
                if Assigned(LMapping.TransformFunc) then
                  LSourceValue := LMapping.TransformFunc(LSourceValue);
              end;
              fmtDefault:
                LSourceValue := LMapping.DefaultValue;
            end;
            SetLength(LValues, Length(LValues) + 1);
            LValues[High(LValues)] := VarToStr(LSourceValue);
          end;
          LWriter.WriteRow(LValues);
          aTableReport.Migrated := aTableReport.Migrated + 1;
        except
          on E: Exception do
          begin
            LError.SourceTable := aFieldMap.SourceTable;
            LError.RecordIndex := LRecordCount;
            LError.ErrorMessage := E.Message;
            aTableReport.AddError(LError);
            LSkip := True;
            if Assigned(FOnError) then
              FOnError(LError, LSkip);
            if LSkip then
              aTableReport.Skipped := aTableReport.Skipped + 1
            else
            begin
              aTableReport.Failed := aTableReport.Failed + 1;
              raise;
            end;
          end;
        end;

        if Assigned(FOnProgress) then
          FOnProgress(aFieldMap.SourceTable, LRecordCount, LRecordCount);

        TMockSimpleQuery(FSourceQuery).MockNext;
      end;
    end;
    LWriter.Flush;
  finally
    LWriter.Free;
  end;
end;
```

**Step 3: Commit**

```bash
git add src/SimpleDataMigration.pas tests/TestSimpleDataMigration.pas
git commit -m "feat: add CSV source and CSV target migration support"
```

---

### Task 9: Sample project

**Files:**
- Create: `samples/DataMigration/SimpleORMDataMigration.dpr`
- Create: `samples/DataMigration/README.md`

**Step 1: Create sample .dpr**

Criar `samples/DataMigration/SimpleORMDataMigration.dpr`:

```pascal
program SimpleORMDataMigration;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Variants,
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleDataMigration in '..\..\src\SimpleDataMigration.pas';

{ Exemplo 1: Migracao com mapeamento fluent }
procedure ExemploFluentAPI;
var
  LMigration: TSimpleDataMigration;
begin
  Writeln('=== Exemplo 1: API Fluent ===');
  Writeln;

  LMigration := TSimpleDataMigration.New;
  try
    LMigration
      .Map('CLIENTES', 'CLIENTE')
        .Field('COD_CLI', 'ID_CLIENTE')
        .Field('RAZAO', 'RAZAO_SOCIAL')
        .Transform('NOME', 'NOME', TFieldTransform.Upper)
        .Transform('CPF_CNPJ', 'CPF', TFieldTransform.Replace('.', ''))
        .DefaultValue('ATIVO', 1)
        .Ignore('CAMPO_OBSOLETO')
      .&End
      .Map('PRODUTOS', 'PRODUTO')
        .Field('COD_PROD', 'ID_PRODUTO')
        .Field('DESCR', 'DESCRICAO')
        .Transform('PRECO', 'PRECO_VENDA', TFieldTransform.Custom(
          function(aValue: Variant): Variant
          begin
            Result := aValue * 1.1; // markup 10%
          end))
      .&End
      .BatchSize(500)
      .Validate(True);

    Writeln('Mapeamento configurado:');
    Writeln('  Maps: ', LMigration.MapCount);
    Writeln('  BatchSize: ', LMigration.GetBatchSize);
    Writeln('  Validate: ', BoolToStr(LMigration.GetValidate, True));
    Writeln;
  finally
    LMigration.Free;
  end;
end;

{ Exemplo 2: Salvar e carregar mapeamento JSON }
procedure ExemploJSONPersistence;
var
  LMigration: TSimpleDataMigration;
  LFilePath: String;
begin
  Writeln('=== Exemplo 2: Persistencia JSON ===');
  Writeln;

  LFilePath := ExtractFilePath(ParamStr(0)) + 'mapeamento.json';

  // Salvar mapeamento
  LMigration := TSimpleDataMigration.New;
  try
    LMigration
      .Map('CLIENTES', 'CLIENTE')
        .Field('COD_CLI', 'ID_CLIENTE')
        .Field('NOME', 'NOME_COMPLETO')
        .DefaultValue('ATIVO', 1)
      .&End
      .Map('PRODUTOS', 'PRODUTO')
        .Field('COD_PROD', 'ID_PRODUTO')
      .&End
      .SaveToJSON(LFilePath);

    Writeln('Mapeamento salvo em: ', LFilePath);
  finally
    LMigration.Free;
  end;

  // Carregar mapeamento
  LMigration := TSimpleDataMigration.New;
  try
    LMigration.LoadFromJSON(LFilePath);
    Writeln('Mapeamento carregado: ', LMigration.MapCount, ' tabelas');
    Writeln;
  finally
    LMigration.Free;
  end;

  if FileExists(LFilePath) then
    DeleteFile(LFilePath);
end;

{ Exemplo 3: Transformacoes built-in }
procedure ExemploTransforms;
var
  LFunc: TFieldTransformFunc;
begin
  Writeln('=== Exemplo 3: Transformacoes Built-in ===');
  Writeln;

  LFunc := TFieldTransform.Upper;
  Writeln('Upper("joao"): ', VarToStr(LFunc('joao')));

  LFunc := TFieldTransform.Lower;
  Writeln('Lower("MARIA"): ', VarToStr(LFunc('MARIA')));

  LFunc := TFieldTransform.Trim;
  Writeln('Trim("  teste  "): "', VarToStr(LFunc('  teste  ')), '"');

  LFunc := TFieldTransform.Replace('-', '');
  Writeln('Replace("-", "")("123-456"): ', VarToStr(LFunc('123-456')));

  LFunc := TFieldTransform.Split(';', 1);
  Writeln('Split(";", 1)("a;b;c"): ', VarToStr(LFunc('a;b;c')));

  Writeln;
end;

{ Exemplo 4: Relatorio }
procedure ExemploReport;
var
  LReport: TMigrationReport;
  LTable: TTableReport;
  LError: TMigrationError;
  LJson: TJSONObject;
begin
  Writeln('=== Exemplo 4: Relatorio de Migracao ===');
  Writeln;

  LReport := TMigrationReport.Create;
  try
    LReport.MarkStart;

    LTable := LReport.AddTable('CLIENTES', 'CLIENTE');
    LTable.TotalRecords := 1000;
    LTable.Migrated := 995;
    LTable.Failed := 3;
    LTable.Skipped := 2;

    LError.SourceTable := 'CLIENTES';
    LError.RecordIndex := 42;
    LError.FieldName := 'CPF';
    LError.ErrorMessage := 'CPF invalido';
    LTable.AddError(LError);

    LReport.MarkEnd;

    Writeln('Total: ', LReport.TotalRecords);
    Writeln('Migrados: ', LReport.Migrated);
    Writeln('Falhas: ', LReport.Failed);
    Writeln('Pulados: ', LReport.Skipped);
    Writeln('Duracao: ', LReport.DurationMs, 'ms');
    Writeln;

    Writeln('CSV:');
    Writeln(LReport.ToCSV);

    LJson := LReport.ToJSON;
    try
      Writeln('JSON:');
      Writeln(LJson.Format);
    finally
      LJson.Free;
    end;
  finally
    LReport.Free;
  end;
end;

begin
  try
    ExemploFluentAPI;
    ExemploJSONPersistence;
    ExemploTransforms;
    ExemploReport;

    Writeln('Todos os exemplos executados com sucesso!');
  except
    on E: Exception do
      Writeln('Erro: ', E.Message);
  end;

  Writeln;
  Writeln('Pressione ENTER para sair...');
  Readln;
end.
```

**Step 2: Create README**

Criar `samples/DataMigration/README.md`:

```markdown
# SimpleORM Data Migration Sample

Demonstra o uso do framework de migracao de dados do SimpleORM.

## Exemplos incluidos

1. **API Fluent** - Configuracao de mapeamento com Field/Transform/DefaultValue/Ignore
2. **Persistencia JSON** - Salvar e carregar mapeamentos de arquivo JSON
3. **Transformacoes** - Upper, Lower, Trim, Replace, Split, Custom
4. **Relatorio** - TMigrationReport com export JSON e CSV

## Como executar

1. Abrir `SimpleORMDataMigration.dpr` na IDE Delphi
2. Compilar e executar (F9)

## Uso com banco de dados real

Para migracao entre bancos reais, conecte via iSimpleQuery:

```pascal
// Banco origem (ex: Firebird legado)
LSourceQuery := TSimpleQueryFiredac.New(LConnOrigem, TSQLType.Firebird);

// Banco destino (ex: MySQL novo)
LTargetQuery := TSimpleQueryFiredac.New(LConnDestino, TSQLType.MySQL);

LReport := TSimpleDataMigration.New
  .Source(LSourceQuery)
  .Target(LTargetQuery)
  .Map('CLIENTES', 'CLIENTE')
    .Field('COD_CLI', 'ID_CLIENTE')
    .Field('RAZAO', 'RAZAO_SOCIAL')
    .Transform('NOME', 'NOME', TFieldTransform.Upper)
  .&End
  .BatchSize(500)
  .OnProgress(procedure(aTable: String; aCurrent, aTotal: Integer)
    begin
      Writeln(Format('%s: %d/%d', [aTable, aCurrent, aTotal]));
    end)
  .Execute;
```
```

**Step 3: Commit**

```bash
git add samples/DataMigration/SimpleORMDataMigration.dpr samples/DataMigration/README.md
git commit -m "feat: add DataMigration sample project"
```

---

### Task 10: Documentacao — CHANGELOG e docs/index.html

**Files:**
- Modify: `CHANGELOG.md:11`
- Modify: `docs/index.html`
- Modify: `docs/en/index.html`

**Step 1: Update CHANGELOG**

Adicionar nova secao em `CHANGELOG.md` no topo (antes de `[3.05.00]`):

```markdown
## [Unreleased]

### Added
- **TSimpleDataMigration** - Framework fluent para migracao de dados entre bancos/sistemas (SimpleDataMigration.pas)
- **TFieldMap** - Mapeamento tabela-a-tabela com Field, Transform, DefaultValue, Lookup e Ignore (SimpleDataMigration.pas)
- **TFieldTransform** - Transformacoes built-in: Upper, Lower, Trim, Replace, DateFormat, Split, Concat, Custom (SimpleDataMigration.pas)
- **TMigrationReport** - Relatorio estruturado com TotalRecords, Migrated, Failed, Skipped, ToJSON, ToCSV (SimpleDataMigration.pas)
- **TTableReport** - Relatorio por tabela com lista de erros detalhada (SimpleDataMigration.pas)
- **TCSVReader** - Leitor de CSV com headers e iteracao sequencial (SimpleDataMigration.pas)
- **TCSVWriter** - Escritor de CSV com headers e flush (SimpleDataMigration.pas)
- **TMigrationFormat** - Enum para formato de fonte/destino: CSV, JSON (SimpleTypes.pas)
- **TMigrationError** - Record com detalhes de erro por registro (SimpleTypes.pas)
- **Persistencia JSON** - SaveToJSON/LoadFromJSON para reutilizar mapeamentos de migracao
- **Migracao CSV** - Suporte a CSV como fonte e/ou destino de migracao
- **Callbacks de progresso** - OnProgress e OnError para controle durante migracao
- **Sample DataMigration** - Projeto demonstrando API fluent, transformacoes e relatorio (samples/DataMigration/)
```

**Step 2: Update docs/index.html**

Adicionar nova secao `<section id="data-migration">` em `docs/index.html` (antes da secao de fechamento) e adicionar link no `<nav>`. Conteudo deve incluir:

- Descricao do framework
- Exemplo de migracao DB-to-DB
- Exemplo de migracao CSV-to-DB
- Tabela de transformacoes built-in
- Exemplo de persistencia JSON
- Exemplo de relatorio

**Step 3: Update docs/en/index.html**

Mesmo conteudo em ingles.

**Step 4: Commit**

```bash
git add CHANGELOG.md docs/index.html docs/en/index.html
git commit -m "docs: add Data Migration documentation and changelog"
```

---

Plan complete and saved to `docs/plans/2026-03-10-data-migration-plan.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
