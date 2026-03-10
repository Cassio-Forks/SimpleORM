# TSimpleMigration — Design Document

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Framework de migracao de dados entre bancos/sistemas diferentes, facilitando o processo para empresas ERP que precisam transpor dados de um sistema legado para o seu.

**Architecture:** `TSimpleMigration` como orquestrador fluent, `TFieldMap` para mapeamento tabela-a-tabela com transformacoes, `TMigrationBatch` para processamento em lotes com resume, e `TMigrationReport` para relatorio estruturado. Suporta fonte/destino via `iSimpleQuery` (qualquer banco) ou arquivo (CSV/JSON).

**Tech Stack:** Delphi, iSimpleQuery (drivers existentes), System.Classes, System.JSON

---

## Componentes

### 1. TSimpleMigration (em SimpleMigration.pas)

Orquestrador principal com API fluent:

```pascal
TSimpleMigration = class(TInterfacedObject, iSimpleMigration)
private
  FSource: iSimpleQuery;
  FTarget: iSimpleQuery;
  FSourceFile: String;
  FTargetFile: String;
  FMaps: TObjectList<TFieldMap>;
  FBatchSize: Integer;
  FValidate: Boolean;
  FReport: TMigrationReport;
  FOnProgress: TSimpleMigrationProgress;
  FOnError: TSimpleMigrationError;
public
  class function New: TSimpleMigration;
  function Source(aQuery: iSimpleQuery): TSimpleMigration; overload;
  function Source(aFilePath: String; aFormat: TMigrationFormat): TSimpleMigration; overload;
  function Target(aQuery: iSimpleQuery): TSimpleMigration; overload;
  function Target(aFilePath: String; aFormat: TMigrationFormat): TSimpleMigration; overload;
  function Map(aSourceTable, aTargetTable: String): TFieldMap;
  function BatchSize(aSize: Integer): TSimpleMigration;
  function Validate(aEnabled: Boolean = True): TSimpleMigration;
  function OnProgress(aCallback: TSimpleMigrationProgress): TSimpleMigration;
  function OnError(aCallback: TSimpleMigrationError): TSimpleMigration;
  function Execute: TMigrationReport;
  function LoadFromJSON(aFilePath: String): TSimpleMigration;
  function SaveToJSON(aFilePath: String): TSimpleMigration;
end;
```

### 2. TFieldMap (em SimpleMigration.pas)

Mapeamento de campos entre tabela origem e destino:

```pascal
TFieldMap = class
private
  FMigration: TSimpleMigration;
  FSourceTable: String;
  FTargetTable: String;
  FFields: TObjectList<TFieldMapping>;
public
  function Field(aSource, aTarget: String): TFieldMap;
  function Transform(aSource, aTarget: String; aTransform: TFieldTransform): TFieldMap;
  function DefaultValue(aTarget: String; aValue: Variant): TFieldMap;
  function Lookup(aSource, aTarget, aLookupTable, aLookupField, aReturnField: String): TFieldMap;
  function Ignore(aSource: String): TFieldMap;
  function &End: TSimpleMigration;
end;
```

### 3. TFieldTransform (em SimpleMigration.pas)

Transformacoes built-in para campos:

```pascal
TFieldTransform = class
public
  class function Upper: TFieldTransformFunc;
  class function Lower: TFieldTransformFunc;
  class function Trim: TFieldTransformFunc;
  class function DateFormat(aFromFormat, aToFormat: String): TFieldTransformFunc;
  class function Split(aDelimiter: String; aIndex: Integer): TFieldTransformFunc;
  class function Concat(aFields: TArray<String>; aDelimiter: String): TFieldTransformFunc;
  class function Replace(aOld, aNew: String): TFieldTransformFunc;
  class function Custom(aFunc: TFieldTransformFunc): TFieldTransformFunc;
end;
```

Onde: `TFieldTransformFunc = reference to function(aValue: Variant): Variant;`

### 4. TMigrationReport (em SimpleMigration.pas)

Relatorio estruturado da migracao:

```pascal
TMigrationReport = class
private
  FTableReports: TObjectList<TTableReport>;
  FStartTime: TDateTime;
  FEndTime: TDateTime;
public
  function TotalRecords: Integer;
  function Migrated: Integer;
  function Failed: Integer;
  function Skipped: Integer;
  function Errors: TArray<TMigrationError>;
  function Duration: TTimeSpan;
  function ToJSON: TJSONObject;
  function ToCSV: String;
  function Tables: TObjectList<TTableReport>;
end;

TTableReport = class
  SourceTable: String;
  TargetTable: String;
  TotalRecords: Integer;
  Migrated: Integer;
  Failed: Integer;
  Skipped: Integer;
  Errors: TList<TMigrationError>;
end;

TMigrationError = record
  SourceTable: String;
  RecordIndex: Integer;
  FieldName: String;
  ErrorMessage: String;
  OriginalValue: Variant;
end;
```

### 5. TMigrationBatch (em SimpleMigration.pas)

Processamento em lotes com controle de resume:

```pascal
TMigrationBatch = class
private
  FBatchSize: Integer;
  FControlTable: String;
  FQuery: iSimpleQuery;
public
  procedure CreateControlTable;
  function GetLastBatch(aSourceTable: String): Integer;
  procedure SaveBatchProgress(aSourceTable: String; aBatch, aRecords: Integer);
  procedure MarkComplete(aSourceTable: String);
  function CanResume(aSourceTable: String): Boolean;
end;
```

Tabela de controle `MIGRATION_CONTROL`:
- `SOURCE_TABLE` VARCHAR(100) PK
- `LAST_BATCH` INTEGER
- `RECORDS_MIGRATED` INTEGER
- `STATUS` VARCHAR(20) — 'IN_PROGRESS', 'COMPLETED', 'FAILED'
- `STARTED_AT` TIMESTAMP
- `UPDATED_AT` TIMESTAMP

### 6. TMigrationFormat (em SimpleTypes.pas)

```pascal
TMigrationFormat = (mfCSV, mfJSON);
```

### 7. Tipos e Callbacks (em SimpleTypes.pas)

```pascal
TFieldTransformFunc = reference to function(aValue: Variant): Variant;
TSimpleMigrationProgress = reference to procedure(aTable: String; aCurrent, aTotal: Integer);
TSimpleMigrationError = reference to procedure(aError: TMigrationError; var aSkip: Boolean);
```

### 8. Interface (em SimpleInterface.pas)

```pascal
iSimpleMigration = interface
  ['{GUID}']
  function Source(aQuery: iSimpleQuery): iSimpleMigration; overload;
  function Source(aFilePath: String; aFormat: TMigrationFormat): iSimpleMigration; overload;
  function Target(aQuery: iSimpleQuery): iSimpleMigration; overload;
  function Target(aFilePath: String; aFormat: TMigrationFormat): iSimpleMigration; overload;
  function Map(aSourceTable, aTargetTable: String): TFieldMap;
  function BatchSize(aSize: Integer): iSimpleMigration;
  function Validate(aEnabled: Boolean = True): iSimpleMigration;
  function Execute: TMigrationReport;
  function LoadFromJSON(aFilePath: String): iSimpleMigration;
  function SaveToJSON(aFilePath: String): iSimpleMigration;
end;
```

## Fluxo de Execucao

1. Usuario configura Source e Target (Query ou File)
2. Define mapeamentos com Map().Field().Transform().&End
3. Opcionalmente carrega mapeamento de JSON
4. Chama Execute
5. Para cada Map:
   a. Abre SELECT na tabela origem
   b. Verifica resume via TMigrationBatch
   c. Processa em lotes de BatchSize
   d. Para cada registro: aplica transformacoes, lookups, defaults
   e. Se Validate=True, valida antes de inserir
   f. Insere no destino via INSERT parametrizado
   g. Salva progresso no MIGRATION_CONTROL
   h. Chama OnProgress callback
   i. Em caso de erro, chama OnError (aSkip=True pula, False aborta)
6. Retorna TMigrationReport

## Exemplo de Uso

```pascal
// Migracao DB -> DB
LReport := TSimpleMigration.New
  .Source(LQueryOrigem)   // FireDAC conectado ao banco legado
  .Target(LQueryDestino)  // FireDAC conectado ao banco novo
  .Map('CLIENTES', 'CLIENTE')
    .Field('COD_CLI', 'ID_CLIENTE')
    .Field('RAZAO', 'RAZAO_SOCIAL')
    .Transform('NOME', 'NOME', TFieldTransform.Upper)
    .Transform('CPF_CNPJ', 'CPF', TFieldTransform.Custom(
      function(aValue: Variant): Variant
      begin
        Result := SoNumeros(VarToStr(aValue));
      end))
    .DefaultValue('ATIVO', 1)
    .Lookup('COD_CIDADE', 'ID_CIDADE', 'CIDADE', 'COD_ANTIGO', 'ID')
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
  .Validate(True)
  .OnProgress(procedure(aTable: String; aCurrent, aTotal: Integer)
    begin
      Writeln(SysUtils.Format('%s: %d/%d', [aTable, aCurrent, aTotal]));
    end)
  .OnError(procedure(aError: TMigrationError; var aSkip: Boolean)
    begin
      Writeln('Erro: ', aError.ErrorMessage);
      aSkip := True; // pula registro com erro
    end)
  .Execute;

Writeln('Migrados: ', LReport.Migrated);
Writeln('Falhas: ', LReport.Failed);
Writeln('Tempo: ', LReport.Duration.ToString);

// Exportar relatorio
LReport.ToJSON.SaveTo('relatorio.json');
```

```pascal
// Salvar/carregar mapeamento JSON
TSimpleMigration.New
  .Map('CLIENTES', 'CLIENTE')
    .Field('COD_CLI', 'ID_CLIENTE')
  .&End
  .SaveToJSON('mapeamento.json');

// Reusar mapeamento
LReport := TSimpleMigration.New
  .Source(LQueryOrigem)
  .Target(LQueryDestino)
  .LoadFromJSON('mapeamento.json')
  .Execute;
```

```pascal
// Migracao CSV -> DB
LReport := TSimpleMigration.New
  .Source('dados_legado.csv', mfCSV)
  .Target(LQueryDestino)
  .Map('dados_legado', 'CLIENTE')
    .Field('nome', 'NOME')
    .Field('cpf', 'CPF')
  .&End
  .Execute;
```
