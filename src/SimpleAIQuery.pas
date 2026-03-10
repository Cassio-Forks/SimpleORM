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
  ESimpleAIQuery = class(Exception);

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
  inherited Create;
  FQuery := aQuery;
  FAIClient := aAIClient;
  FSchemaContext := '';
  FMaxRows := 100;

  if Assigned(FQuery) then
    FSQLType := FQuery.SQLType
  else
    FSQLType := TSQLType.MySQL;
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
begin
  Result := Self;
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TypeInfo(T));
    if Assigned(LType) then
      FSchemaContext := FSchemaContext + BuildSchemaForEntity(LType);
  finally
    LContext.Free;
  end;
end;

function TSimpleAIQuery.MaxRows(aValue: Integer): TSimpleAIQuery;
begin
  Result := Self;
  FMaxRows := aValue;
end;

function TSimpleAIQuery.BuildSchemaForEntity(aType: TRttiType): String;
var
  LTableName: String;
  LTabela: Tabela;
  LProp: TRttiProperty;
  LFieldName: String;
  LTypeName: String;
  LAnnotations: String;
begin
  Result := '';

  LTabela := aType.GetAttribute<Tabela>;
  if not Assigned(LTabela) then
    Exit;

  LTableName := LTabela.Name;
  Result := 'TABLE: ' + LTableName + sLineBreak;

  for LProp in aType.GetProperties do
  begin
    if LProp.IsIgnore then
      Continue;

    if not LProp.EhCampo then
      Continue;

    LFieldName := LProp.FieldName;

    case LProp.PropertyType.TypeKind of
      tkInteger, tkInt64:
        LTypeName := 'INTEGER';
      tkFloat:
      begin
        if LProp.PropertyType.Handle = TypeInfo(TDateTime) then
          LTypeName := 'DATETIME'
        else if LProp.PropertyType.Handle = TypeInfo(TDate) then
          LTypeName := 'DATE'
        else if LProp.PropertyType.Handle = TypeInfo(TTime) then
          LTypeName := 'TIME'
        else
          LTypeName := 'FLOAT';
      end;
      tkString, tkLString, tkWString, tkUString:
        LTypeName := 'VARCHAR';
      tkEnumeration:
      begin
        if LProp.PropertyType.Handle = TypeInfo(Boolean) then
          LTypeName := 'BOOLEAN'
        else
          LTypeName := 'INTEGER';
      end;
    else
      LTypeName := 'VARCHAR';
    end;

    LAnnotations := '';
    if LProp.EhChavePrimaria then
      LAnnotations := LAnnotations + ' PK';
    if LProp.IsAutoInc then
      LAnnotations := LAnnotations + ' AUTOINC';
    if LProp.EhChaveEstrangeira then
      LAnnotations := LAnnotations + ' FK';
    if LProp.IsNotNull then
      LAnnotations := LAnnotations + ' NOT NULL';

    Result := Result + '  ' + LFieldName + ' ' + LTypeName + LAnnotations + sLineBreak;
  end;

  Result := Result + sLineBreak;
end;

function TSimpleAIQuery.ValidateSQL(const aSQL: String): Boolean;
var
  LUpperSQL: String;
begin
  Result := False;
  LUpperSQL := UpperCase(Trim(aSQL));

  if not LUpperSQL.StartsWith('SELECT') then
    Exit;

  if Pos(';', aSQL) > 0 then
    Exit;

  if (Pos('INSERT ', LUpperSQL) > 0) or
     (Pos('UPDATE ', LUpperSQL) > 0) or
     (Pos('DELETE ', LUpperSQL) > 0) or
     (Pos('DROP ', LUpperSQL) > 0) or
     (Pos('ALTER ', LUpperSQL) > 0) or
     (Pos('CREATE ', LUpperSQL) > 0) or
     (Pos('TRUNCATE ', LUpperSQL) > 0) or
     (Pos('EXEC ', LUpperSQL) > 0) or
     (Pos('EXECUTE ', LUpperSQL) > 0) or
     (Pos('GRANT ', LUpperSQL) > 0) or
     (Pos('REVOKE ', LUpperSQL) > 0) then
    Exit;

  Result := True;
end;

function TSimpleAIQuery.CleanSQLResponse(const aResponse: String): String;
begin
  Result := Trim(aResponse);

  if Result.StartsWith('```sql') then
    Result := Copy(Result, 7, Length(Result))
  else if Result.StartsWith('```') then
    Result := Copy(Result, 4, Length(Result));

  if Result.EndsWith('```') then
    Result := Copy(Result, 1, Length(Result) - 3);

  Result := Trim(Result);

  if Result.EndsWith(';') then
    Result := Copy(Result, 1, Length(Result) - 1);

  Result := Trim(Result);
end;

function TSimpleAIQuery.GetSQLTypeName: String;
begin
  case FSQLType of
    TSQLType.Firebird: Result := 'Firebird';
    TSQLType.MySQL:    Result := 'MySQL';
    TSQLType.SQLite:   Result := 'SQLite';
    TSQLType.Oracle:   Result := 'Oracle';
  else
    Result := 'SQL';
  end;
end;

function TSimpleAIQuery.ApplyMaxRows(const aSQL: String): String;
var
  LUpperSQL: String;
begin
  Result := aSQL;

  if FMaxRows <= 0 then
    Exit;

  LUpperSQL := UpperCase(Trim(aSQL));

  if (Pos('LIMIT ', LUpperSQL) > 0) or
     (Pos('FIRST ', LUpperSQL) > 0) or
     (Pos('FETCH ', LUpperSQL) > 0) or
     (Pos('ROWS ', LUpperSQL) > 0) then
    Exit;

  case FSQLType of
    TSQLType.Firebird:
    begin
      Result := 'SELECT FIRST ' + IntToStr(FMaxRows) + ' ' +
                Copy(Trim(aSQL), 7, Length(Trim(aSQL)));
    end;
    TSQLType.MySQL, TSQLType.SQLite:
    begin
      Result := Trim(aSQL) + ' LIMIT ' + IntToStr(FMaxRows);
    end;
    TSQLType.Oracle:
    begin
      Result := Trim(aSQL) + ' FETCH NEXT ' + IntToStr(FMaxRows) + ' ROWS ONLY';
    end;
  end;
end;

function TSimpleAIQuery.DataSetToJSON(aDataSet: TDataSet): String;
var
  LArray: TJSONArray;
  LObj: TJSONObject;
  LField: TField;
  LCount: Integer;
begin
  LArray := TJSONArray.Create;
  try
    aDataSet.DisableControls;
    try
      LCount := 0;
      aDataSet.First;
      while (not aDataSet.Eof) and (LCount < FMaxRows) do
      begin
        LObj := TJSONObject.Create;
        for LField in aDataSet.Fields do
        begin
          if LField.IsNull then
            LObj.AddPair(LField.FieldName, TJSONNull.Create)
          else
            case LField.DataType of
              ftInteger, ftSmallint, ftWord, ftLargeint, ftAutoInc:
                LObj.AddPair(LField.FieldName, TJSONNumber.Create(LField.AsLargeInt));
              ftFloat, ftCurrency, ftBCD, ftFMTBcd:
                LObj.AddPair(LField.FieldName, TJSONNumber.Create(LField.AsFloat));
              ftBoolean:
                LObj.AddPair(LField.FieldName, TJSONBool.Create(LField.AsBoolean));
            else
              LObj.AddPair(LField.FieldName, LField.AsString);
            end;
        end;
        LArray.AddElement(LObj);
        Inc(LCount);
        aDataSet.Next;
      end;
    finally
      aDataSet.EnableControls;
    end;
    Result := LArray.ToJSON;
  finally
    FreeAndNil(LArray);
  end;
end;

function TSimpleAIQuery.NaturalLanguageQuery(const aQuestion: String): TDataSet;
var
  LPrompt: String;
  LResponse: String;
  LSQL: String;
begin
  LPrompt :=
    'You are a SQL expert. Generate a ' + GetSQLTypeName + ' SELECT query to answer the following question.' + sLineBreak +
    'Return ONLY the SQL query, no explanations.' + sLineBreak +
    sLineBreak +
    'Database schema:' + sLineBreak +
    FSchemaContext + sLineBreak +
    'Question: ' + aQuestion;

  LResponse := FAIClient.Complete(LPrompt);
  LSQL := CleanSQLResponse(LResponse);

  if not ValidateSQL(LSQL) then
    raise ESimpleAIQuery.Create('The AI generated an unsafe or invalid SQL query: ' + LSQL);

  LSQL := ApplyMaxRows(LSQL);

  FQuery.Open(LSQL);
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

  LPrompt :=
    'Based on the following data, answer this question in natural language:' + sLineBreak +
    sLineBreak +
    'Question: ' + aQuestion + sLineBreak +
    sLineBreak +
    'Data: ' + LJSONData + sLineBreak +
    sLineBreak +
    'Provide a clear and concise answer.';

  Result := FAIClient.Complete(LPrompt);
end;

function TSimpleAIQuery.ExplainQuery(const aSQL: String): String;
var
  LPrompt: String;
begin
  LPrompt :=
    'Explain the following SQL query in plain language:' + sLineBreak +
    sLineBreak +
    'SQL: ' + aSQL + sLineBreak +
    sLineBreak +
    'Database schema:' + sLineBreak +
    FSchemaContext + sLineBreak +
    'Provide a clear explanation of what this query does.';

  Result := FAIClient.Complete(LPrompt);
end;

function TSimpleAIQuery.SuggestQuery(const aObjective: String): String;
var
  LPrompt: String;
  LResponse: String;
  LSQL: String;
begin
  LPrompt :=
    'You are a SQL expert. Suggest a ' + GetSQLTypeName + ' SELECT query for the following objective.' + sLineBreak +
    'Return ONLY the SQL query, no explanations.' + sLineBreak +
    sLineBreak +
    'Database schema:' + sLineBreak +
    FSchemaContext + sLineBreak +
    'Objective: ' + aObjective;

  LResponse := FAIClient.Complete(LPrompt);
  LSQL := CleanSQLResponse(LResponse);

  if not ValidateSQL(LSQL) then
    raise ESimpleAIQuery.Create('The AI suggested an unsafe or invalid SQL query: ' + LSQL);

  Result := LSQL;
end;

end.
