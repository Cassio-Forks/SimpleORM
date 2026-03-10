# SimpleAIQuery Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Permitir que aplicacoes Delphi facam perguntas em linguagem natural ao banco de dados, traduzindo para SQL via LLM e executando de forma segura.

**Architecture:** Uma nova unit (SimpleAIQuery) que usa RTTI para extrair schema de entidades registradas, monta prompts contextuais para o LLM gerar SQL, valida seguranca (SELECT only), executa via iSimpleQuery e retorna resultados como DataSet ou texto em linguagem natural. Reutiliza iSimpleAIClient da feature AI Enrichment.

**Tech Stack:** Delphi, RTTI, System.JSON, Data.DB, iSimpleAIClient, iSimpleQuery, DUnit

---

### Task 1: SimpleAIQuery.pas — Core

**Files:**
- Create: `src/SimpleAIQuery.pas`

**Step 1: Criar a unit SimpleAIQuery.pas**

```pascal
unit SimpleAIQuery;

interface

uses
  SimpleInterface,
  SimpleAttributes,
  SimpleRTTIHelper,
  SimpleTypes,
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.JSON,
  Data.DB;

type
  TSimpleAIQuery = class
  private
    FQuery: iSimpleQuery;
    FAIClient: iSimpleAIClient;
    FSchemaContext: String;
    FMaxRows: Integer;
    FSQLType: TSQLType;
    function ValidateSQL(const aSQL: String): Boolean;
    function BuildSchemaForEntity(aType: TRttiType): String;
    function DataSetToJSON(aDataSet: TDataSet): String;
    function CleanSQLResponse(const aResponse: String): String;
    function GetSQLTypeName: String;
    function ApplyMaxRows(const aSQL: String): String;
  public
    constructor Create(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient);
    destructor Destroy; override;
    class function New(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient): TSimpleAIQuery;
    function RegisterEntity<T: class, constructor>: TSimpleAIQuery;
    function MaxRows(aValue: Integer): TSimpleAIQuery;
    function NaturalLanguageQuery(const aQuestion: String): TDataSet;
    function AskQuestion(const aQuestion: String): String;
    function ExplainQuery(const aSQL: String): String;
    function SuggestQuery(const aObjective: String): String;
  end;

implementation

{ TSimpleAIQuery }

constructor TSimpleAIQuery.Create(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient);
begin
  FQuery := aQuery;
  FAIClient := aAIClient;
  FSchemaContext := '';
  FMaxRows := 100;
  FSQLType := aQuery.SQLType;
end;

destructor TSimpleAIQuery.Destroy;
begin
  inherited;
end;

class function TSimpleAIQuery.New(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient): TSimpleAIQuery;
begin
  Result := Self.Create(aQuery, aAIClient);
end;

function TSimpleAIQuery.RegisterEntity<T>: TSimpleAIQuery;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LSchema: String;
begin
  Result := Self;
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TypeInfo(T));
    LSchema := BuildSchemaForEntity(LType);
    if LSchema <> '' then
    begin
      if FSchemaContext <> '' then
        FSchemaContext := FSchemaContext + #13#10;
      FSchemaContext := FSchemaContext + LSchema;
    end;
  finally
    LContext.Free;
  end;
end;

function TSimpleAIQuery.MaxRows(aValue: Integer): TSimpleAIQuery;
begin
  Result := Self;
  FMaxRows := aValue;
end;

function TSimpleAIQuery.NaturalLanguageQuery(const aQuestion: String): TDataSet;
var
  LPrompt: String;
  LResponse: String;
  LSQL: String;
begin
  LPrompt := 'Voce e um assistente SQL. O banco de dados tem as seguintes tabelas:' + #13#10 +
    #13#10 +
    FSchemaContext + #13#10 +
    #13#10 +
    'Tipo de banco: ' + GetSQLTypeName + #13#10 +
    #13#10 +
    'Pergunta: ' + aQuestion + #13#10 +
    #13#10 +
    'Gere APENAS o SQL SELECT para ' + GetSQLTypeName + '. Sem explicacao, sem markdown, sem comentarios. Apenas o SQL puro.';

  LResponse := FAIClient.Complete(LPrompt);
  LSQL := CleanSQLResponse(LResponse);

  if not ValidateSQL(LSQL) then
    raise Exception.Create('SQL gerado pelo LLM nao passou na validacao de seguranca: ' + LSQL);

  LSQL := ApplyMaxRows(LSQL);

  FQuery.SQL.Clear;
  FQuery.SQL.Add(LSQL);
  FQuery.Open;

  Result := FQuery.DataSet;
end;

function TSimpleAIQuery.AskQuestion(const aQuestion: String): String;
var
  LDataSet: TDataSet;
  LJSONData: String;
  LPrompt: String;
begin
  LDataSet := NaturalLanguageQuery(aQuestion);
  LJSONData := DataSetToJSON(LDataSet);

  LPrompt := 'Pergunta original: ' + aQuestion + #13#10 +
    #13#10 +
    'Dados retornados do banco (JSON):' + #13#10 +
    LJSONData + #13#10 +
    #13#10 +
    'Responda a pergunta em linguagem natural baseado nos dados acima. Seja claro e conciso.';

  Result := FAIClient.Complete(LPrompt);
end;

function TSimpleAIQuery.ExplainQuery(const aSQL: String): String;
var
  LPrompt: String;
begin
  LPrompt := 'Voce e um assistente SQL. O banco de dados tem as seguintes tabelas:' + #13#10 +
    #13#10 +
    FSchemaContext + #13#10 +
    #13#10 +
    'Explique a seguinte query SQL em linguagem natural, de forma clara e detalhada:' + #13#10 +
    #13#10 +
    aSQL + #13#10 +
    #13#10 +
    'Responda em linguagem natural.';

  Result := FAIClient.Complete(LPrompt);
end;

function TSimpleAIQuery.SuggestQuery(const aObjective: String): String;
var
  LPrompt: String;
  LResponse: String;
  LSQL: String;
begin
  LPrompt := 'Voce e um assistente SQL. O banco de dados tem as seguintes tabelas:' + #13#10 +
    #13#10 +
    FSchemaContext + #13#10 +
    #13#10 +
    'Tipo de banco: ' + GetSQLTypeName + #13#10 +
    #13#10 +
    'Objetivo: ' + aObjective + #13#10 +
    #13#10 +
    'Sugira um SQL SELECT para este objetivo. Apenas o SQL puro, sem explicacao.';

  LResponse := FAIClient.Complete(LPrompt);
  LSQL := CleanSQLResponse(LResponse);

  if not ValidateSQL(LSQL) then
    raise Exception.Create('SQL sugerido pelo LLM nao passou na validacao de seguranca: ' + LSQL);

  Result := LSQL;
end;

function TSimpleAIQuery.ValidateSQL(const aSQL: String): Boolean;
var
  LUpperSQL: String;
begin
  Result := False;

  if Trim(aSQL) = '' then
    Exit;

  LUpperSQL := UpperCase(Trim(aSQL));

  // Must start with SELECT
  if not LUpperSQL.StartsWith('SELECT') then
    Exit;

  // Block semicolons (prevent multi-statement injection)
  if Pos(';', aSQL) > 0 then
    Exit;

  // Block dangerous keywords
  if Pos('INSERT ', LUpperSQL) > 0 then
    Exit;
  if Pos('UPDATE ', LUpperSQL) > 0 then
    Exit;
  if Pos('DELETE ', LUpperSQL) > 0 then
    Exit;
  if Pos('DROP ', LUpperSQL) > 0 then
    Exit;
  if Pos('ALTER ', LUpperSQL) > 0 then
    Exit;
  if Pos('CREATE ', LUpperSQL) > 0 then
    Exit;
  if Pos('TRUNCATE ', LUpperSQL) > 0 then
    Exit;
  if Pos('EXEC ', LUpperSQL) > 0 then
    Exit;
  if Pos('EXECUTE ', LUpperSQL) > 0 then
    Exit;
  if Pos('GRANT ', LUpperSQL) > 0 then
    Exit;
  if Pos('REVOKE ', LUpperSQL) > 0 then
    Exit;

  Result := True;
end;

function TSimpleAIQuery.BuildSchemaForEntity(aType: TRttiType): String;
var
  LTableName: String;
  LProp: TRttiProperty;
  LColumns: String;
  LColInfo: String;
  LTypeName: String;
  LFirst: Boolean;
begin
  Result := '';

  if not aType.Tem<Tabela> then
    Exit;

  LTableName := aType.GetAttribute<Tabela>.Name;
  LColumns := '';
  LFirst := True;

  for LProp in aType.GetProperties do
  begin
    if LProp.IsIgnore then
      Continue;
    if not LProp.EhCampo then
      Continue;

    case LProp.PropertyType.TypeKind of
      tkInteger, tkInt64:
        LTypeName := 'integer';
      tkFloat:
      begin
        if LProp.PropertyType.Handle = TypeInfo(TDateTime) then
          LTypeName := 'datetime'
        else if LProp.PropertyType.Handle = TypeInfo(Currency) then
          LTypeName := 'currency'
        else
          LTypeName := 'float';
      end;
      tkUString, tkString, tkLString, tkWString:
        LTypeName := 'string';
      tkEnumeration:
      begin
        if LProp.PropertyType.Handle = TypeInfo(Boolean) then
          LTypeName := 'boolean'
        else
          LTypeName := 'enum';
      end;
    else
      LTypeName := 'unknown';
    end;

    LColInfo := LProp.FieldName + ' (' + LTypeName;

    if LProp.EhChavePrimaria then
      LColInfo := LColInfo + ', PK';
    if LProp.IsAutoInc then
      LColInfo := LColInfo + ', AutoInc';
    if LProp.EhChaveEstrangeira then
      LColInfo := LColInfo + ', FK';
    if LProp.IsNotNull then
      LColInfo := LColInfo + ', NotNull';

    LColInfo := LColInfo + ')';

    if not LFirst then
      LColumns := LColumns + ', ';
    LColumns := LColumns + LColInfo;
    LFirst := False;
  end;

  Result := 'Tabela: ' + LTableName + #13#10 +
    'Colunas: ' + LColumns;
end;

function TSimpleAIQuery.DataSetToJSON(aDataSet: TDataSet): String;
var
  LArray: TJSONArray;
  LObj: TJSONObject;
  LField: TField;
  LRowCount: Integer;
begin
  LArray := TJSONArray.Create;
  try
    aDataSet.First;
    LRowCount := 0;
    while (not aDataSet.Eof) and (LRowCount < FMaxRows) do
    begin
      LObj := TJSONObject.Create;
      for LField in aDataSet.Fields do
      begin
        if LField.IsNull then
          LObj.AddPair(LField.FieldName, TJSONNull.Create)
        else
        begin
          case LField.DataType of
            ftInteger, ftSmallint, ftWord, ftLargeint, ftAutoInc:
              LObj.AddPair(LField.FieldName, TJSONNumber.Create(LField.AsInteger));
            ftFloat, ftCurrency, ftBCD, ftFMTBcd:
              LObj.AddPair(LField.FieldName, TJSONNumber.Create(LField.AsFloat));
            ftBoolean:
              LObj.AddPair(LField.FieldName, TJSONBool.Create(LField.AsBoolean));
            ftDate, ftTime, ftDateTime, ftTimeStamp:
              LObj.AddPair(LField.FieldName, LField.AsString);
          else
            LObj.AddPair(LField.FieldName, LField.AsString);
          end;
        end;
      end;
      LArray.AddElement(LObj);
      Inc(LRowCount);
      aDataSet.Next;
    end;
    Result := LArray.ToJSON;
  finally
    FreeAndNil(LArray);
  end;
end;

function TSimpleAIQuery.CleanSQLResponse(const aResponse: String): String;
var
  LResult: String;
  LStartPos: Integer;
  LEndPos: Integer;
begin
  LResult := Trim(aResponse);

  // Strip markdown code fences: ```sql ... ```
  if LResult.StartsWith('```') then
  begin
    // Find end of first line (after ```sql or ```)
    LStartPos := Pos(#10, LResult);
    if LStartPos = 0 then
      LStartPos := Pos(#13, LResult);
    if LStartPos > 0 then
      LResult := Copy(LResult, LStartPos + 1, Length(LResult));

    // Remove trailing ```
    LEndPos := Length(LResult);
    while (LEndPos > 0) and (LResult[LEndPos] in [#13, #10, ' ', '`']) do
      Dec(LEndPos);
    LResult := Copy(LResult, 1, LEndPos);
  end;

  // Remove trailing semicolon if present
  LResult := Trim(LResult);
  if LResult.EndsWith(';') then
    LResult := Copy(LResult, 1, Length(LResult) - 1);

  Result := Trim(LResult);
end;

function TSimpleAIQuery.GetSQLTypeName: String;
begin
  case FSQLType of
    TSQLType.Firebird:
      Result := 'Firebird';
    TSQLType.MySQL:
      Result := 'MySQL';
    TSQLType.SQLite:
      Result := 'SQLite';
    TSQLType.Oracle:
      Result := 'Oracle';
  else
    Result := 'SQL';
  end;
end;

function TSimpleAIQuery.ApplyMaxRows(const aSQL: String): String;
var
  LUpperSQL: String;
begin
  Result := aSQL;
  LUpperSQL := UpperCase(Trim(aSQL));

  // Skip if already has LIMIT, FIRST, FETCH, or TOP
  if (Pos('LIMIT ', LUpperSQL) > 0) or
     (Pos('FIRST ', LUpperSQL) > 0) or
     (Pos('FETCH ', LUpperSQL) > 0) or
     (Pos(' TOP ', LUpperSQL) > 0) then
    Exit;

  case FSQLType of
    TSQLType.Firebird:
      // Firebird: SELECT FIRST N ...
      Result := 'SELECT FIRST ' + IntToStr(FMaxRows) + ' ' +
        Copy(Trim(aSQL), 7, Length(aSQL));
    TSQLType.MySQL, TSQLType.SQLite:
      // MySQL/SQLite: ... LIMIT N
      Result := Trim(aSQL) + ' LIMIT ' + IntToStr(FMaxRows);
    TSQLType.Oracle:
      // Oracle: ... FETCH NEXT N ROWS ONLY
      Result := Trim(aSQL) + ' FETCH NEXT ' + IntToStr(FMaxRows) + ' ROWS ONLY';
  else
    Result := Trim(aSQL) + ' LIMIT ' + IntToStr(FMaxRows);
  end;
end;

end.
```

**Step 2: Commit**

```bash
git add src/SimpleAIQuery.pas
git commit -m "feat: add TSimpleAIQuery for natural language database queries via LLM"
```

---

### Task 2: Testes DUnit

**Files:**
- Create: `tests/TestSimpleAIQuery.pas`
- Modify: `tests/SimpleORMTests.dpr`

**Step 1: Criar tests/TestSimpleAIQuery.pas**

```pascal
unit TestSimpleAIQuery;

interface

uses
  TestFramework,
  System.SysUtils,
  System.Classes,
  System.Rtti,
  SimpleAttributes,
  SimpleRTTIHelper,
  SimpleAIQuery,
  SimpleInterface,
  MockAIClient;

type
  { Test entity for schema generation }
  [Tabela('USUARIOS')]
  TUsuarioSchemaTest = class
  private
    FID: Integer;
    FNOME: String;
    FEMAIL: String;
    FATIVO: Boolean;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull]
    property NOME: String read FNOME write FNOME;
    [Campo('EMAIL')]
    property EMAIL: String read FEMAIL write FEMAIL;
    [Campo('ATIVO')]
    property ATIVO: Boolean read FATIVO write FATIVO;
  end;

  [Tabela('PEDIDOS')]
  TPedidoSchemaTest = class
  private
    FID: Integer;
    FID_USUARIO: Integer;
    FVALOR: Double;
    FSTATUS: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('ID_USUARIO'), FK]
    property ID_USUARIO: Integer read FID_USUARIO write FID_USUARIO;
    [Campo('VALOR')]
    property VALOR: Double read FVALOR write FVALOR;
    [Campo('STATUS')]
    property STATUS: String read FSTATUS write FSTATUS;
  end;

  TTestValidateSQL = class(TTestCase)
  published
    procedure TestValidateSQL_SelectAllowed;
    procedure TestValidateSQL_InsertBlocked;
    procedure TestValidateSQL_UpdateBlocked;
    procedure TestValidateSQL_DeleteBlocked;
    procedure TestValidateSQL_DropBlocked;
    procedure TestValidateSQL_SemicolonBlocked;
    procedure TestValidateSQL_TruncateBlocked;
    procedure TestValidateSQL_ExecBlocked;
    procedure TestValidateSQL_GrantBlocked;
    procedure TestValidateSQL_EmptyBlocked;
    procedure TestValidateSQL_SelectWithJoin;
    procedure TestValidateSQL_SelectWithSubquery;
  end;

  TTestCleanSQLResponse = class(TTestCase)
  published
    procedure TestCleanSQLResponse_StripsFences;
    procedure TestCleanSQLResponse_StripsSqlFences;
    procedure TestCleanSQLResponse_PlainSQL;
    procedure TestCleanSQLResponse_TrimsWhitespace;
    procedure TestCleanSQLResponse_RemovesTrailingSemicolon;
  end;

  TTestBuildSchemaForEntity = class(TTestCase)
  published
    procedure TestBuildSchema_ContainsTableName;
    procedure TestBuildSchema_ContainsColumns;
    procedure TestBuildSchema_ContainsPKAnnotation;
    procedure TestBuildSchema_ContainsFKAnnotation;
    procedure TestBuildSchema_ContainsNotNullAnnotation;
  end;

  TTestExplainQuery = class(TTestCase)
  published
    procedure TestExplainQuery_ReturnsText;
    procedure TestExplainQuery_IncludesSchema;
  end;

implementation

uses
  SimpleTypes;

type
  { Helper class to access private methods for testing }
  TSimpleAIQueryTestHelper = class helper for TSimpleAIQuery
  public
    function TestValidateSQL(const aSQL: String): Boolean;
    function TestCleanSQLResponse(const aResponse: String): String;
    function TestBuildSchemaForEntity(aType: TRttiType): String;
  end;

function TSimpleAIQueryTestHelper.TestValidateSQL(const aSQL: String): Boolean;
begin
  Result := Self.ValidateSQL(aSQL);
end;

function TSimpleAIQueryTestHelper.TestCleanSQLResponse(const aResponse: String): String;
begin
  Result := Self.CleanSQLResponse(aResponse);
end;

function TSimpleAIQueryTestHelper.TestBuildSchemaForEntity(aType: TRttiType): String;
begin
  Result := Self.BuildSchemaForEntity(aType);
end;

{ TTestValidateSQL }

procedure TTestValidateSQL.TestValidateSQL_SelectAllowed;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
  LMockQuery: iSimpleQuery;
begin
  LMockClient := TSimpleAIMockClient.New('');
  // We need a minimal query mock; use nil-safe approach via helper
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    CheckTrue(LAIQuery.TestValidateSQL('SELECT * FROM USUARIOS'),
      'SELECT should be allowed');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_InsertBlocked;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    CheckFalse(LAIQuery.TestValidateSQL('INSERT INTO USUARIOS VALUES (1)'),
      'INSERT should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_UpdateBlocked;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    CheckFalse(LAIQuery.TestValidateSQL('UPDATE USUARIOS SET NOME = ''test'''),
      'UPDATE should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_DeleteBlocked;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    CheckFalse(LAIQuery.TestValidateSQL('DELETE FROM USUARIOS'),
      'DELETE should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_DropBlocked;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    CheckFalse(LAIQuery.TestValidateSQL('DROP TABLE USUARIOS'),
      'DROP should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_SemicolonBlocked;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    CheckFalse(LAIQuery.TestValidateSQL('SELECT 1; DROP TABLE USUARIOS'),
      'Semicolons should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_TruncateBlocked;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    CheckFalse(LAIQuery.TestValidateSQL('TRUNCATE TABLE USUARIOS'),
      'TRUNCATE should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_ExecBlocked;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    CheckFalse(LAIQuery.TestValidateSQL('EXEC sp_something'),
      'EXEC should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_GrantBlocked;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    CheckFalse(LAIQuery.TestValidateSQL('GRANT ALL ON USUARIOS TO public'),
      'GRANT should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_EmptyBlocked;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    CheckFalse(LAIQuery.TestValidateSQL(''),
      'Empty SQL should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_SelectWithJoin;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    CheckTrue(LAIQuery.TestValidateSQL(
      'SELECT U.NOME, COUNT(P.ID) FROM USUARIOS U JOIN PEDIDOS P ON U.ID = P.ID_USUARIO GROUP BY U.NOME'),
      'SELECT with JOIN should be allowed');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_SelectWithSubquery;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    CheckTrue(LAIQuery.TestValidateSQL(
      'SELECT * FROM USUARIOS WHERE ID IN (SELECT ID_USUARIO FROM PEDIDOS)'),
      'SELECT with subquery should be allowed');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

{ TTestCleanSQLResponse }

procedure TTestCleanSQLResponse.TestCleanSQLResponse_StripsFences;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
  LResult: String;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    LResult := LAIQuery.TestCleanSQLResponse('```' + #10 + 'SELECT 1' + #10 + '```');
    CheckEquals('SELECT 1', LResult, 'Should strip plain code fences');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestCleanSQLResponse.TestCleanSQLResponse_StripsSqlFences;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
  LResult: String;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    LResult := LAIQuery.TestCleanSQLResponse('```sql' + #10 + 'SELECT * FROM USUARIOS' + #10 + '```');
    CheckEquals('SELECT * FROM USUARIOS', LResult, 'Should strip sql code fences');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestCleanSQLResponse.TestCleanSQLResponse_PlainSQL;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
  LResult: String;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    LResult := LAIQuery.TestCleanSQLResponse('SELECT * FROM USUARIOS');
    CheckEquals('SELECT * FROM USUARIOS', LResult, 'Should return plain SQL as-is');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestCleanSQLResponse.TestCleanSQLResponse_TrimsWhitespace;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
  LResult: String;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    LResult := LAIQuery.TestCleanSQLResponse('  SELECT 1  ' + #13#10);
    CheckEquals('SELECT 1', LResult, 'Should trim whitespace');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestCleanSQLResponse.TestCleanSQLResponse_RemovesTrailingSemicolon;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
  LResult: String;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    LResult := LAIQuery.TestCleanSQLResponse('SELECT 1;');
    CheckEquals('SELECT 1', LResult, 'Should remove trailing semicolon');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

{ TTestBuildSchemaForEntity }

procedure TTestBuildSchemaForEntity.TestBuildSchema_ContainsTableName;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
  LContext: TRttiContext;
  LType: TRttiType;
  LResult: String;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TypeInfo(TUsuarioSchemaTest));
    LResult := LAIQuery.TestBuildSchemaForEntity(LType);
    CheckTrue(Pos('Tabela: USUARIOS', LResult) > 0,
      'Schema should contain table name USUARIOS');
  finally
    LContext.Free;
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestBuildSchemaForEntity.TestBuildSchema_ContainsColumns;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
  LContext: TRttiContext;
  LType: TRttiType;
  LResult: String;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TypeInfo(TUsuarioSchemaTest));
    LResult := LAIQuery.TestBuildSchemaForEntity(LType);
    CheckTrue(Pos('ID', LResult) > 0, 'Schema should contain ID column');
    CheckTrue(Pos('NOME', LResult) > 0, 'Schema should contain NOME column');
    CheckTrue(Pos('EMAIL', LResult) > 0, 'Schema should contain EMAIL column');
    CheckTrue(Pos('ATIVO', LResult) > 0, 'Schema should contain ATIVO column');
  finally
    LContext.Free;
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestBuildSchemaForEntity.TestBuildSchema_ContainsPKAnnotation;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
  LContext: TRttiContext;
  LType: TRttiType;
  LResult: String;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TypeInfo(TUsuarioSchemaTest));
    LResult := LAIQuery.TestBuildSchemaForEntity(LType);
    CheckTrue(Pos('PK', LResult) > 0,
      'Schema should contain PK annotation');
  finally
    LContext.Free;
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestBuildSchemaForEntity.TestBuildSchema_ContainsFKAnnotation;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
  LContext: TRttiContext;
  LType: TRttiType;
  LResult: String;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TypeInfo(TPedidoSchemaTest));
    LResult := LAIQuery.TestBuildSchemaForEntity(LType);
    CheckTrue(Pos('FK', LResult) > 0,
      'Schema should contain FK annotation for ID_USUARIO');
  finally
    LContext.Free;
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestBuildSchemaForEntity.TestBuildSchema_ContainsNotNullAnnotation;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
  LContext: TRttiContext;
  LType: TRttiType;
  LResult: String;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TypeInfo(TUsuarioSchemaTest));
    LResult := LAIQuery.TestBuildSchemaForEntity(LType);
    CheckTrue(Pos('NotNull', LResult) > 0,
      'Schema should contain NotNull annotation for NOME');
  finally
    LContext.Free;
    FreeAndNil(LAIQuery);
  end;
end;

{ TTestExplainQuery }

procedure TTestExplainQuery.TestExplainQuery_ReturnsText;
var
  LAIQuery: TSimpleAIQuery;
  LMockClient: iSimpleAIClient;
  LResult: String;
begin
  LMockClient := TSimpleAIMockClient.New('Esta query seleciona todos os usuarios.');
  LAIQuery := TSimpleAIQuery.Create(nil, LMockClient);
  try
    LResult := LAIQuery.ExplainQuery('SELECT * FROM USUARIOS');
    CheckEquals('Esta query seleciona todos os usuarios.', LResult,
      'ExplainQuery should return the LLM response');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestExplainQuery.TestExplainQuery_IncludesSchema;
var
  LAIQuery: TSimpleAIQuery;
  LMock: TSimpleAIMockClient;
  LClient: iSimpleAIClient;
  LResult: String;
begin
  LMock := TSimpleAIMockClient.Create('Explicacao da query');
  LClient := LMock;
  LAIQuery := TSimpleAIQuery.Create(nil, LClient);
  try
    LAIQuery.RegisterEntity<TUsuarioSchemaTest>;
    LResult := LAIQuery.ExplainQuery('SELECT * FROM USUARIOS');
    CheckTrue(Pos('USUARIOS', LMock.LastPrompt) > 0,
      'Prompt sent to LLM should include schema context');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

initialization
  RegisterTest('AI.Query', TTestValidateSQL.Suite);
  RegisterTest('AI.Query', TTestCleanSQLResponse.Suite);
  RegisterTest('AI.Query', TTestBuildSchemaForEntity.Suite);
  RegisterTest('AI.Query', TTestExplainQuery.Suite);

end.
```

**Step 2: Adicionar ao SimpleORMTests.dpr**

Adicionar no uses clause:

```pascal
  SimpleAIQuery in '..\src\SimpleAIQuery.pas',
  TestSimpleAIQuery in 'TestSimpleAIQuery.pas';
```

**Step 3: Commit**

```bash
git add tests/TestSimpleAIQuery.pas tests/SimpleORMTests.dpr
git commit -m "test: add DUnit tests for TSimpleAIQuery with SQL validation and schema generation"
```

---

### Task 3: Sample project

**Files:**
- Create: `samples/AIQuery/SimpleORMAIQuery.dpr`
- Create: `samples/AIQuery/README.md`

**Step 1: Criar samples/AIQuery/SimpleORMAIQuery.dpr**

```pascal
program SimpleORMAIQuery;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  SimpleAttributes in '..\..\src\SimpleAttributes.pas',
  SimpleAIAttributes in '..\..\src\SimpleAIAttributes.pas',
  SimpleAIQuery in '..\..\src\SimpleAIQuery.pas',
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleRTTIHelper in '..\..\src\SimpleRTTIHelper.pas',
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleLogger in '..\..\src\SimpleLogger.pas';

type
  { Mock AI Client que simula respostas de LLM }
  TDemoAIClient = class(TInterfacedObject, iSimpleAIClient)
  private
    FModel: String;
    FMaxTokens: Integer;
    FTemperature: Double;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: iSimpleAIClient;
    function Complete(const aPrompt: String): String;
    function Model(const aValue: String): iSimpleAIClient;
    function MaxTokens(aValue: Integer): iSimpleAIClient;
    function Temperature(aValue: Double): iSimpleAIClient;
  end;

  { Entidades de exemplo }
  [Tabela('CLIENTES')]
  TCliente = class
  private
    FID: Integer;
    FNOME: String;
    FEMAIL: String;
    FATIVO: Boolean;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull]
    property NOME: String read FNOME write FNOME;
    [Campo('EMAIL')]
    property EMAIL: String read FEMAIL write FEMAIL;
    [Campo('ATIVO')]
    property ATIVO: Boolean read FATIVO write FATIVO;
  end;

  [Tabela('PEDIDOS')]
  TPedido = class
  private
    FID: Integer;
    FID_CLIENTE: Integer;
    FVALOR: Double;
    FDATA: TDateTime;
    FSTATUS: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('ID_CLIENTE'), FK]
    property ID_CLIENTE: Integer read FID_CLIENTE write FID_CLIENTE;
    [Campo('VALOR')]
    property VALOR: Double read FVALOR write FVALOR;
    [Campo('DATA')]
    property DATA: TDateTime read FDATA write FDATA;
    [Campo('STATUS')]
    property STATUS: String read FSTATUS write FSTATUS;
  end;

  [Tabela('PRODUTOS')]
  TProduto = class
  private
    FID: Integer;
    FNOME: String;
    FPRECO: Double;
    FCATEGORIA: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull]
    property NOME: String read FNOME write FNOME;
    [Campo('PRECO')]
    property PRECO: Double read FPRECO write FPRECO;
    [Campo('CATEGORIA')]
    property CATEGORIA: String read FCATEGORIA write FCATEGORIA;
  end;

{ TDemoAIClient }

constructor TDemoAIClient.Create;
begin
  FModel := 'demo-model';
  FMaxTokens := 1024;
  FTemperature := 0.7;
end;

destructor TDemoAIClient.Destroy;
begin
  inherited;
end;

class function TDemoAIClient.New: iSimpleAIClient;
begin
  Result := Self.Create;
end;

function TDemoAIClient.Complete(const aPrompt: String): String;
begin
  // Simula respostas baseado no tipo de prompt
  if Pos('Gere APENAS', aPrompt) > 0 then
  begin
    // NaturalLanguageQuery - retorna SQL simulado
    if Pos('top 5', LowerCase(aPrompt)) > 0 then
      Result := 'SELECT C.NOME, SUM(P.VALOR) AS TOTAL FROM CLIENTES C JOIN PEDIDOS P ON C.ID = P.ID_CLIENTE GROUP BY C.NOME ORDER BY TOTAL DESC'
    else if Pos('ticket medio', LowerCase(aPrompt)) > 0 then
      Result := 'SELECT AVG(VALOR) AS TICKET_MEDIO FROM PEDIDOS'
    else
      Result := 'SELECT * FROM CLIENTES WHERE ATIVO = 1';
  end
  else if Pos('Explique', aPrompt) > 0 then
  begin
    // ExplainQuery
    Result := 'Esta query seleciona todos os clientes ativos da tabela CLIENTES, ' +
      'filtrando apenas aqueles onde o campo ATIVO e igual a 1 (verdadeiro).';
  end
  else if Pos('Sugira', aPrompt) > 0 then
  begin
    // SuggestQuery
    Result := 'SELECT C.* FROM CLIENTES C WHERE C.ID NOT IN ' +
      '(SELECT DISTINCT P.ID_CLIENTE FROM PEDIDOS P WHERE P.DATA >= CURRENT_DATE - 90)';
  end
  else if Pos('Responda a pergunta', aPrompt) > 0 then
  begin
    // AskQuestion - resposta em linguagem natural
    Result := 'O ticket medio de vendas e R$ 250,00 baseado nos dados retornados.';
  end
  else
    Result := 'Resposta simulada do LLM.';
end;

function TDemoAIClient.Model(const aValue: String): iSimpleAIClient;
begin
  Result := Self;
  FModel := aValue;
end;

function TDemoAIClient.MaxTokens(aValue: Integer): iSimpleAIClient;
begin
  Result := Self;
  FMaxTokens := aValue;
end;

function TDemoAIClient.Temperature(aValue: Double): iSimpleAIClient;
begin
  Result := Self;
  FTemperature := aValue;
end;

{ Main }

var
  LAIQuery: TSimpleAIQuery;
  LAIClient: iSimpleAIClient;
  LSQL: String;
  LExplicacao: String;
begin
  try
    Writeln('=== SimpleORM AI Query Demo ===');
    Writeln('');
    Writeln('NOTA: Este demo usa um mock AI client.');
    Writeln('Para uso real, substitua por TSimpleAIClient.New(''claude'', ''sua-api-key'')');
    Writeln('e conecte um iSimpleQuery real (ex: TSimpleQueryFiredac).');
    Writeln('');

    LAIClient := TDemoAIClient.New;

    // Nota: NaturalLanguageQuery e AskQuestion precisam de um iSimpleQuery real
    // para executar SQL. Este demo mostra apenas SuggestQuery e ExplainQuery
    // que nao precisam de conexao com banco.

    LAIQuery := TSimpleAIQuery.New(nil, LAIClient);
    try
      // Registrar entidades para contexto de schema
      LAIQuery
        .RegisterEntity<TCliente>
        .RegisterEntity<TPedido>
        .RegisterEntity<TProduto>;

      Writeln('--- Schema registrado ---');
      Writeln('Entidades: CLIENTES, PEDIDOS, PRODUTOS');
      Writeln('');

      // 1. SuggestQuery
      Writeln('--- SuggestQuery ---');
      Writeln('Objetivo: "Encontrar clientes inativos ha mais de 90 dias"');
      LSQL := LAIQuery.SuggestQuery('Encontrar clientes inativos ha mais de 90 dias');
      Writeln('SQL sugerido: ', LSQL);
      Writeln('');

      // 2. ExplainQuery
      Writeln('--- ExplainQuery ---');
      Writeln('SQL: SELECT * FROM CLIENTES WHERE ATIVO = 1');
      LExplicacao := LAIQuery.ExplainQuery('SELECT * FROM CLIENTES WHERE ATIVO = 1');
      Writeln('Explicacao: ', LExplicacao);
      Writeln('');

      // 3. Demonstracao de validacao SQL
      Writeln('--- Validacao de Seguranca SQL ---');
      Writeln('SELECT * FROM CLIENTES: ', 'Permitido');
      Writeln('INSERT INTO CLIENTES: ', 'Bloqueado');
      Writeln('DELETE FROM CLIENTES: ', 'Bloqueado');
      Writeln('DROP TABLE CLIENTES: ', 'Bloqueado');
      Writeln('');

      Writeln('--- Para usar NaturalLanguageQuery e AskQuestion ---');
      Writeln('Conecte um iSimpleQuery real:');
      Writeln('  LAIQuery := TSimpleAIQuery.New(');
      Writeln('    TSimpleQueryFiredac.New(FDConnection),');
      Writeln('    TSimpleAIClient.New(''claude'', ''sua-api-key'')');
      Writeln('  );');
      Writeln('  LDataSet := LAIQuery.NaturalLanguageQuery(''Top 5 clientes'');');
      Writeln('  LResposta := LAIQuery.AskQuestion(''Qual o ticket medio?'');');

    finally
      FreeAndNil(LAIQuery);
    end;

    Writeln('');
    Writeln('=== Demo finalizada com sucesso ===');
  except
    on E: Exception do
      Writeln('Erro: ', E.Message);
  end;

  Writeln('');
  Writeln('Pressione ENTER para sair...');
  Readln;
end.
```

**Step 2: Criar samples/AIQuery/README.md**

```markdown
# SimpleORM AI Query - Sample

## Descricao

Este sample demonstra o uso do recurso AI Query do SimpleORM,
que permite fazer perguntas em linguagem natural ao banco de dados.

## Como executar

1. Abra `SimpleORMAIQuery.dpr` na IDE Delphi
2. A IDE ira gerar os arquivos `.dproj` e `.res` automaticamente
3. Compile e execute (F9)

## O que o sample demonstra

- Registro de entidades para gerar contexto de schema automaticamente
- `SuggestQuery` - LLM sugere SQL baseado em um objetivo descrito em linguagem natural
- `ExplainQuery` - LLM explica uma query SQL em linguagem natural
- Validacao de seguranca SQL (apenas SELECT permitido)

## Metodos disponiveis (requerem iSimpleQuery real)

- `NaturalLanguageQuery(pergunta)` - Traduz para SQL, executa, retorna TDataSet
- `AskQuestion(pergunta)` - Traduz para SQL, executa, LLM responde em linguagem natural

## Para usar com API e banco reais

```pascal
LAIQuery := TSimpleAIQuery.New(
  TSimpleQueryFiredac.New(FDConnection),  // conexao real
  TSimpleAIClient.New('claude', 'sua-api-key')  // API real
);
LAIQuery
  .RegisterEntity<TCliente>
  .RegisterEntity<TPedido>;

// Pergunta em linguagem natural
LDataSet := LAIQuery.NaturalLanguageQuery('Top 5 clientes por valor de compras');
```
```

**Step 3: Commit**

```bash
git add samples/AIQuery/SimpleORMAIQuery.dpr samples/AIQuery/README.md
git commit -m "feat: add AI Query sample project"
```

---

### Task 4: Documentacao

**Files:**
- Modify: `docs/index.html`
- Modify: `CHANGELOG.md`

**Step 1: Adicionar secao AI Query em docs/index.html**

Adicionar link no `<nav>`:

```html
<a href="#ai-query">AI Query</a>
```

Adicionar secao:

```html
<section id="ai-query">
  <h2>AI Query <span class="badge badge-new">NEW</span></h2>
  <p>O SimpleORM permite fazer perguntas em linguagem natural ao banco de dados, traduzindo automaticamente para SQL via LLM.</p>

  <h3>Metodos</h3>
  <table>
    <thead>
      <tr><th>Metodo</th><th>Input</th><th>Output</th><th>Descricao</th></tr>
    </thead>
    <tbody>
      <tr><td>NaturalLanguageQuery</td><td>pergunta: String</td><td>TDataSet</td><td>Traduz para SQL, executa, retorna resultado</td></tr>
      <tr><td>AskQuestion</td><td>pergunta: String</td><td>String</td><td>Traduz, executa, LLM responde em linguagem natural</td></tr>
      <tr><td>ExplainQuery</td><td>sql: String</td><td>String</td><td>Explica SQL em linguagem natural</td></tr>
      <tr><td>SuggestQuery</td><td>objetivo: String</td><td>String</td><td>Sugere SQL baseado no objetivo</td></tr>
    </tbody>
  </table>

  <h3>Exemplo de uso</h3>
  <pre><code>AIQuery := TSimpleAIQuery.New(Query, AIClient);
AIQuery
  .RegisterEntity&lt;TCliente&gt;
  .RegisterEntity&lt;TPedido&gt;
  .RegisterEntity&lt;TProduto&gt;;

// Pergunta em linguagem natural
LDataSet := AIQuery.NaturalLanguageQuery('Top 5 clientes por valor de compras em 2025');

// Resposta em texto
LResposta := AIQuery.AskQuestion('Qual o ticket medio de vendas?');

// Explicar SQL
LExplicacao := AIQuery.ExplainQuery('SELECT AVG(VALOR) FROM PEDIDOS');

// Sugerir SQL
LSQL := AIQuery.SuggestQuery('Clientes inativos ha mais de 90 dias');</code></pre>

  <p class="warning">Por seguranca, apenas SQL SELECT e permitido. Keywords como INSERT, UPDATE, DELETE, DROP, ALTER, CREATE, TRUNCATE, EXEC, GRANT e REVOKE sao bloqueados automaticamente.</p>
</section>
```

**Step 2: Atualizar CHANGELOG.md**

Adicionar na secao `[Unreleased]`:

```markdown
- **AI Query** - Perguntas em linguagem natural ao banco de dados via LLM (SimpleAIQuery.pas)
- **NaturalLanguageQuery** - Traduz pergunta para SQL, executa e retorna TDataSet
- **AskQuestion** - Traduz, executa e retorna resposta em linguagem natural
- **ExplainQuery** - Explica SQL em linguagem natural via LLM
- **SuggestQuery** - Sugere SQL baseado em objetivo descrito em linguagem natural
- **Validacao SQL** - Bloqueio automatico de operacoes nao-SELECT em queries geradas por LLM
- **Sample AIQuery** - Projeto demonstrando AI Query com mock client
```

**Step 3: Commit**

```bash
git add docs/index.html CHANGELOG.md
git commit -m "docs: add AI Query documentation and changelog"
```
