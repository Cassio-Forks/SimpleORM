unit SimpleQuerySupabase;

interface

uses
  SimpleInterface, SimpleTypes, System.Classes, System.Variants, Data.DB,
  System.SysUtils, System.JSON, System.Net.HttpClient, System.Net.URLClient,
  Datasnap.DBClient, System.Generics.Collections;

type
  TSimpleQuerySupabase = class(TInterfacedObject, iSimpleQuery)
  private
    FSQL: TStringList;
    FParams: TParams;
    FDataSet: TClientDataSet;
    FBaseURL: string;
    FAPIKey: string;
    FToken: string;

    { JSON/DataSet conversion helpers }
    function ParamsToJSON: string;
    procedure JSONToDataSet(const aJSON: string);
    procedure JSONArrayToDataSet(aArray: TJSONArray);
    procedure JSONObjectToDataSet(aObj: TJSONObject);
    procedure CreateFieldsFromJSONObject(aObj: TJSONObject);

    { HTTP helpers }
    function DoHTTPRequest(const aMethod, aURL: string; const aBody: string = ''): string;
  protected
    { SQL parsing helpers - protected for testability }
    function ExtractTableName(const aSQL: string): string;
    function DetectOperation(const aSQL: string): string;
    function ExtractPKFieldName(const aSQL: string): string;
    function ExtractPKValue: Variant;
    function ExtractInsertFields(const aSQL: string): TArray<string>;
    function ExtractSelectFields(const aSQL: string): string;
    function ExtractWhereFilters(const aSQL: string): string;
    function ExtractPagination(const aSQL: string; out aSkip, aTake: Integer): Boolean;
    function ExtractUpdateFields(const aSQL: string): TArray<string>;
    function BuildSupabaseURL(const aTableName, aOperation: string): string;
  public
    constructor Create(aBaseURL, aAPIKey: string); overload;
    constructor Create(aBaseURL, aAPIKey, aToken: string); overload;
    destructor Destroy; override;
    class function New(aBaseURL, aAPIKey: string): iSimpleQuery; overload;
    class function New(aBaseURL, aAPIKey, aToken: string): iSimpleQuery; overload;

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

    { Additional public methods }
    function Token(aValue: string): iSimpleQuery;
  end;

implementation

{ TSimpleQuerySupabase }

constructor TSimpleQuerySupabase.Create(aBaseURL, aAPIKey: string);
begin
  Create(aBaseURL, aAPIKey, '');
end;

constructor TSimpleQuerySupabase.Create(aBaseURL, aAPIKey, aToken: string);
begin
  inherited Create;
  FBaseURL := aBaseURL.TrimRight(['/']);
  FAPIKey := aAPIKey;
  FToken := aToken;
  FSQL := TStringList.Create;
  FParams := TParams.Create(nil);
  FDataSet := TClientDataSet.Create(nil);
end;

destructor TSimpleQuerySupabase.Destroy;
begin
  FreeAndNil(FDataSet);
  FreeAndNil(FParams);
  FreeAndNil(FSQL);
  inherited;
end;

class function TSimpleQuerySupabase.New(aBaseURL, aAPIKey: string): iSimpleQuery;
begin
  Result := Self.Create(aBaseURL, aAPIKey);
end;

class function TSimpleQuerySupabase.New(aBaseURL, aAPIKey, aToken: string): iSimpleQuery;
begin
  Result := Self.Create(aBaseURL, aAPIKey, aToken);
end;

{ iSimpleQuery implementation }

function TSimpleQuerySupabase.SQL: TStrings;
begin
  Result := FSQL;
end;

function TSimpleQuerySupabase.Params: TParams;
begin
  Result := FParams;
end;

function TSimpleQuerySupabase.DataSet: TDataSet;
begin
  Result := TDataSet(FDataSet);
end;

function TSimpleQuerySupabase.ExecSQL: iSimpleQuery;
var
  LOp, LTableName, LURL, LBody, LFilters: string;
begin
  Result := Self;
  try
    LOp := DetectOperation(FSQL.Text);
    LTableName := ExtractTableName(FSQL.Text);
    LURL := BuildSupabaseURL(LTableName, LOp);

    if SameText(LOp, 'INSERT') then
    begin
      LBody := ParamsToJSON;
      DoHTTPRequest('POST', LURL, LBody);
    end
    else if SameText(LOp, 'UPDATE') then
    begin
      LFilters := ExtractWhereFilters(FSQL.Text);
      if LFilters <> '' then
        LURL := LURL + '?' + LFilters;
      LBody := ParamsToJSON;
      DoHTTPRequest('PATCH', LURL, LBody);
    end
    else if SameText(LOp, 'DELETE') then
    begin
      LFilters := ExtractWhereFilters(FSQL.Text);
      if LFilters <> '' then
        LURL := LURL + '?' + LFilters;
      DoHTTPRequest('DELETE', LURL);
    end;
  except
    Rollback;
    raise;
  end;
end;

function TSimpleQuerySupabase.Open(aSQL: String): iSimpleQuery;
begin
  Result := Self;
  FSQL.Text := aSQL;
  Open;
end;

function TSimpleQuerySupabase.Open: iSimpleQuery;
var
  LTableName, LURL, LSelect, LFilters, LResponse, LSeparator: string;
  LSkip, LTake: Integer;
  LHasParams: Boolean;
begin
  Result := Self;
  LTableName := ExtractTableName(FSQL.Text);
  LURL := BuildSupabaseURL(LTableName, 'SELECT');
  LHasParams := False;

  LSelect := ExtractSelectFields(FSQL.Text);
  if (LSelect <> '') and (LSelect <> '*') then
  begin
    LURL := LURL + '?select=' + LSelect;
    LHasParams := True;
  end;

  LFilters := ExtractWhereFilters(FSQL.Text);
  if LFilters <> '' then
  begin
    if LHasParams then
      LSeparator := '&'
    else
      LSeparator := '?';
    LURL := LURL + LSeparator + LFilters;
    LHasParams := True;
  end;

  if ExtractPagination(FSQL.Text, LSkip, LTake) then
  begin
    if LHasParams then
      LSeparator := '&'
    else
      LSeparator := '?';
    LURL := LURL + LSeparator + 'limit=' + IntToStr(LTake) + '&offset=' + IntToStr(LSkip);
  end;

  LResponse := DoHTTPRequest('GET', LURL);
  JSONToDataSet(LResponse);
end;

function TSimpleQuerySupabase.StartTransaction: iSimpleQuery;
begin
  Result := Self;
  { REST is stateless - no-op }
end;

function TSimpleQuerySupabase.Commit: iSimpleQuery;
begin
  Result := Self;
  { REST is stateless - no-op }
end;

function TSimpleQuerySupabase.Rollback: iSimpleQuery;
begin
  Result := Self;
  { REST is stateless - no-op }
end;

function TSimpleQuerySupabase.EndTransaction: iSimpleQuery;
begin
  Result := Commit;
end;

function TSimpleQuerySupabase.InTransaction: Boolean;
begin
  Result := False;
end;

function TSimpleQuerySupabase.SQLType: TSQLType;
begin
  Result := TSQLType.MySQL;
end;

function TSimpleQuerySupabase.RowsAffected: Integer;
begin
  Result := -1;
end;

function TSimpleQuerySupabase.Token(aValue: string): iSimpleQuery;
begin
  Result := Self;
  FToken := aValue;
end;

{ SQL parsing helpers }

function TSimpleQuerySupabase.ExtractTableName(const aSQL: string): string;
var
  LWords: TArray<string>;
  I: Integer;
  LUpper: string;
begin
  Result := '';
  LWords := aSQL.Trim.Split([' ', #13, #10, #9], TStringSplitOptions.ExcludeEmpty);

  if Length(LWords) < 2 then
    Exit;

  LUpper := UpperCase(LWords[0]);

  if SameText(LUpper, 'SELECT') or SameText(LUpper, 'DELETE') then
  begin
    for I := 1 to High(LWords) do
    begin
      if SameText(LWords[I], 'FROM') and (I + 1 <= High(LWords)) then
      begin
        Result := LWords[I + 1];
        Exit;
      end;
    end;
  end
  else if SameText(LUpper, 'INSERT') then
  begin
    for I := 1 to High(LWords) do
    begin
      if SameText(LWords[I], 'INTO') and (I + 1 <= High(LWords)) then
      begin
        Result := LWords[I + 1];
        Exit;
      end;
    end;
  end
  else if SameText(LUpper, 'UPDATE') then
  begin
    Result := LWords[1];
  end;
end;

function TSimpleQuerySupabase.DetectOperation(const aSQL: string): string;
var
  LTrimmed: string;
begin
  LTrimmed := aSQL.TrimLeft;
  if LTrimmed.ToUpper.StartsWith('INSERT') then
    Result := 'INSERT'
  else if LTrimmed.ToUpper.StartsWith('UPDATE') then
    Result := 'UPDATE'
  else if LTrimmed.ToUpper.StartsWith('DELETE') then
    Result := 'DELETE'
  else
    Result := 'SELECT';
end;

function TSimpleQuerySupabase.ExtractPKFieldName(const aSQL: string): string;
var
  LWords: TArray<string>;
  I: Integer;
begin
  Result := '';
  LWords := aSQL.Trim.Split([' ', #13, #10, #9, '='], TStringSplitOptions.ExcludeEmpty);
  for I := 0 to High(LWords) do
  begin
    if SameText(LWords[I], 'WHERE') and (I + 1 <= High(LWords)) then
    begin
      Result := LWords[I + 1];
      Exit;
    end;
  end;
end;

function TSimpleQuerySupabase.ExtractPKValue: Variant;
var
  LPKField: string;
  I: Integer;
begin
  Result := Null;
  LPKField := ExtractPKFieldName(FSQL.Text);

  if LPKField = '' then
  begin
    for I := 0 to FParams.Count - 1 do
    begin
      if not VarIsNull(FParams[I].Value) and not VarIsEmpty(FParams[I].Value) then
      begin
        if Pos(':' + FParams[I].Name, FSQL.Text) > 0 then
        begin
          if Pos('WHERE', UpperCase(FSQL.Text)) > 0 then
          begin
            Result := FParams[I].Value;
            Exit;
          end;
        end;
      end;
    end;
    Exit;
  end;

  if LPKField.StartsWith(':') then
    LPKField := LPKField.Substring(1);

  for I := 0 to FParams.Count - 1 do
  begin
    if SameText(FParams[I].Name, LPKField) then
    begin
      Result := FParams[I].Value;
      Exit;
    end;
  end;
end;

function TSimpleQuerySupabase.ExtractInsertFields(const aSQL: string): TArray<string>;
var
  LOpenParen, LCloseParen, I: Integer;
  LFieldsPart: string;
  LRawFields: TArray<string>;
begin
  Result := nil;
  LOpenParen := Pos('(', aSQL);
  LCloseParen := Pos(')', aSQL);

  if (LOpenParen = 0) or (LCloseParen = 0) or (LCloseParen <= LOpenParen) then
    Exit;

  LFieldsPart := Copy(aSQL, LOpenParen + 1, LCloseParen - LOpenParen - 1);
  LRawFields := LFieldsPart.Split([',']);
  SetLength(Result, Length(LRawFields));

  for I := 0 to High(LRawFields) do
    Result[I] := LRawFields[I].Trim;
end;

function TSimpleQuerySupabase.ExtractSelectFields(const aSQL: string): string;
var
  LUpper, LFieldsPart: string;
  LFromPos, LStartPos: Integer;
  LRawFields: TArray<string>;
  LResultList: TStringList;
  I: Integer;
begin
  Result := '*';
  LUpper := UpperCase(aSQL.Trim);

  LFromPos := Pos('FROM', LUpper);
  if LFromPos = 0 then
    Exit;

  { Start after SELECT keyword }
  LStartPos := Pos('SELECT', LUpper);
  if LStartPos = 0 then
    Exit;
  LStartPos := LStartPos + 6; { Length of 'SELECT' }

  { Handle Firebird FIRST/SKIP pagination keywords between SELECT and field list }
  LFieldsPart := Copy(aSQL.Trim, LStartPos, LFromPos - LStartPos).Trim;
  LUpper := UpperCase(LFieldsPart);

  if LUpper.StartsWith('FIRST') then
  begin
    { Skip 'FIRST N SKIP N' — find the end of pagination tokens }
    LRawFields := LFieldsPart.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
    I := 0;
    { Skip FIRST N }
    if (I < Length(LRawFields)) and SameText(LRawFields[I], 'FIRST') then
      Inc(I, 2);
    { Skip SKIP N }
    if (I < Length(LRawFields)) and SameText(LRawFields[I], 'SKIP') then
      Inc(I, 2);
    { Rebuild remaining as field list }
    LResultList := TStringList.Create;
    try
      LResultList.Delimiter := ' ';
      while I <= High(LRawFields) do
      begin
        LResultList.Add(LRawFields[I]);
        Inc(I);
      end;
      LFieldsPart := LResultList.DelimitedText;
    finally
      FreeAndNil(LResultList);
    end;
  end;

  LFieldsPart := LFieldsPart.Trim;

  if (LFieldsPart = '*') or (LFieldsPart = '') then
  begin
    Result := '*';
    Exit;
  end;

  { Split fields by comma and build lowercase comma-separated list }
  LRawFields := LFieldsPart.Split([',']);
  LResultList := TStringList.Create;
  try
    for I := 0 to High(LRawFields) do
      LResultList.Add(LRawFields[I].Trim.ToLower);
    Result := String.Join(',', LResultList.ToStringArray);
  finally
    FreeAndNil(LResultList);
  end;
end;

function TSimpleQuerySupabase.ExtractWhereFilters(const aSQL: string): string;
var
  LUpper, LWherePart, LCondField, LParamName: string;
  LWherePos, LEndPos, I, LEqPos: Integer;
  LConditions: TArray<string>;
  LFilters: TStringList;
  LParamValue: string;
begin
  Result := '';
  LUpper := UpperCase(aSQL);

  LWherePos := Pos('WHERE', LUpper);
  if LWherePos = 0 then
    Exit;

  LWherePart := Copy(aSQL, LWherePos + 5, Length(aSQL));

  { Remove trailing ORDER BY, GROUP BY, LIMIT, OFFSET clauses }
  LUpper := UpperCase(LWherePart);
  LEndPos := Pos('ORDER BY', LUpper);
  if LEndPos > 0 then
    LWherePart := Copy(LWherePart, 1, LEndPos - 1);

  LUpper := UpperCase(LWherePart);
  LEndPos := Pos('GROUP BY', LUpper);
  if LEndPos > 0 then
    LWherePart := Copy(LWherePart, 1, LEndPos - 1);

  LUpper := UpperCase(LWherePart);
  LEndPos := Pos('LIMIT', LUpper);
  if LEndPos > 0 then
    LWherePart := Copy(LWherePart, 1, LEndPos - 1);

  LWherePart := LWherePart.Trim;

  if LWherePart = '' then
    Exit;

  { Split by AND }
  LConditions := LWherePart.Split(['AND'], TStringSplitOptions.ExcludeEmpty);
  LFilters := TStringList.Create;
  try
    for I := 0 to High(LConditions) do
    begin
      { Each condition looks like: FIELD = :PARAM }
      LEqPos := Pos('=', LConditions[I]);
      if LEqPos = 0 then
        Continue;

      LCondField := Copy(LConditions[I], 1, LEqPos - 1).Trim.ToLower;
      LParamName := Copy(LConditions[I], LEqPos + 1, Length(LConditions[I])).Trim;

      { Remove leading colon from param name }
      if LParamName.StartsWith(':') then
        LParamName := LParamName.Substring(1);

      LParamName := LParamName.Trim;

      { Find param value in FParams }
      LParamValue := '';
      if Assigned(FParams) then
      begin
        if FParams.FindParam(LParamName) <> nil then
          LParamValue := VarToStr(FParams.ParamByName(LParamName).Value);
      end;

      LFilters.Add(LCondField + '=eq.' + LParamValue);
    end;

    Result := String.Join('&', LFilters.ToStringArray);
  finally
    FreeAndNil(LFilters);
  end;
end;

function TSimpleQuerySupabase.ExtractPagination(const aSQL: string; out aSkip, aTake: Integer): Boolean;
var
  LUpper: string;
  LWords: TArray<string>;
  I: Integer;
begin
  Result := False;
  aSkip := 0;
  aTake := 0;
  LUpper := UpperCase(aSQL.Trim);
  LWords := LUpper.Split([' ', #13, #10, #9], TStringSplitOptions.ExcludeEmpty);

  { Firebird: SELECT FIRST N SKIP N ... }
  for I := 0 to High(LWords) do
  begin
    if SameText(LWords[I], 'FIRST') and (I + 1 <= High(LWords)) then
    begin
      aTake := StrToIntDef(LWords[I + 1], 0);
      if (I + 2 <= High(LWords)) and SameText(LWords[I + 2], 'SKIP') and (I + 3 <= High(LWords)) then
        aSkip := StrToIntDef(LWords[I + 3], 0);
      Result := aTake > 0;
      if Result then
        Exit;
    end;
  end;

  { MySQL/SQLite: ... LIMIT N OFFSET N }
  for I := 0 to High(LWords) do
  begin
    if SameText(LWords[I], 'LIMIT') and (I + 1 <= High(LWords)) then
    begin
      aTake := StrToIntDef(LWords[I + 1], 0);
      if (I + 2 <= High(LWords)) and SameText(LWords[I + 2], 'OFFSET') and (I + 3 <= High(LWords)) then
        aSkip := StrToIntDef(LWords[I + 3], 0);
      Result := aTake > 0;
      if Result then
        Exit;
    end;
  end;

  { Oracle: ... OFFSET N ROWS FETCH NEXT N ROWS ONLY }
  for I := 0 to High(LWords) do
  begin
    if SameText(LWords[I], 'OFFSET') and (I + 2 <= High(LWords)) and
       SameText(LWords[I + 2], 'ROWS') then
    begin
      aSkip := StrToIntDef(LWords[I + 1], 0);
      { Look for FETCH NEXT N }
      if (I + 3 <= High(LWords)) and SameText(LWords[I + 3], 'FETCH') and
         (I + 5 <= High(LWords)) and SameText(LWords[I + 4], 'NEXT') then
        aTake := StrToIntDef(LWords[I + 5], 0);
      Result := aTake > 0;
      if Result then
        Exit;
    end;
  end;
end;

function TSimpleQuerySupabase.ExtractUpdateFields(const aSQL: string): TArray<string>;
var
  LUpper, LSetPart: string;
  LSetPos, LWherePos, I, LEqPos: Integer;
  LPairs: TArray<string>;
begin
  Result := nil;
  LUpper := UpperCase(aSQL);

  LSetPos := Pos('SET', LUpper);
  if LSetPos = 0 then
    Exit;

  LWherePos := Pos('WHERE', LUpper);
  if LWherePos > 0 then
    LSetPart := Copy(aSQL, LSetPos + 3, LWherePos - LSetPos - 3)
  else
    LSetPart := Copy(aSQL, LSetPos + 3, Length(aSQL));

  LSetPart := LSetPart.Trim;
  LPairs := LSetPart.Split([',']);
  SetLength(Result, Length(LPairs));

  for I := 0 to High(LPairs) do
  begin
    LEqPos := Pos('=', LPairs[I]);
    if LEqPos > 0 then
      Result[I] := Copy(LPairs[I], 1, LEqPos - 1).Trim
    else
      Result[I] := LPairs[I].Trim;
  end;
end;

{ JSON/DataSet conversion helpers }

function TSimpleQuerySupabase.ParamsToJSON: string;
var
  LObj: TJSONObject;
  I: Integer;
  LParam: TParam;
begin
  LObj := TJSONObject.Create;
  try
    for I := 0 to FParams.Count - 1 do
    begin
      LParam := FParams[I];
      if VarIsNull(LParam.Value) or VarIsEmpty(LParam.Value) then
        LObj.AddPair(LParam.Name.ToLower, TJSONNull.Create)
      else
      begin
        case LParam.DataType of
          ftInteger, ftSmallint, ftWord, ftLargeint, ftAutoInc, ftShortint:
            LObj.AddPair(LParam.Name.ToLower, TJSONNumber.Create(LParam.AsInteger));
          ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftExtended, ftSingle:
            LObj.AddPair(LParam.Name.ToLower, TJSONNumber.Create(LParam.AsFloat));
          ftBoolean:
            LObj.AddPair(LParam.Name.ToLower, TJSONBool.Create(LParam.AsBoolean));
        else
          LObj.AddPair(LParam.Name.ToLower, LParam.AsString);
        end;
      end;
    end;
    Result := LObj.ToString;
  finally
    FreeAndNil(LObj);
  end;
end;

procedure TSimpleQuerySupabase.JSONToDataSet(const aJSON: string);
var
  LValue: TJSONValue;
  LArray: TJSONArray;
  LObj: TJSONObject;
begin
  FDataSet.Close;
  FDataSet.FieldDefs.Clear;
  FDataSet.Fields.Clear;

  if aJSON.Trim = '' then
    Exit;

  LValue := TJSONObject.ParseJSONValue(aJSON);
  if not Assigned(LValue) then
    Exit;

  try
    if LValue is TJSONArray then
    begin
      LArray := TJSONArray(LValue);
      JSONArrayToDataSet(LArray);
    end
    else if LValue is TJSONObject then
    begin
      LObj := TJSONObject(LValue);
      if Assigned(LObj.Values['data']) and (LObj.Values['data'] is TJSONArray) then
        JSONArrayToDataSet(TJSONArray(LObj.Values['data']))
      else
        JSONObjectToDataSet(LObj);
    end;
  finally
    LValue.Free;
  end;
end;

procedure TSimpleQuerySupabase.JSONArrayToDataSet(aArray: TJSONArray);
var
  I, J: Integer;
  LObj: TJSONObject;
  LPair: TJSONPair;
begin
  if aArray.Count = 0 then
    Exit;

  if not (aArray.Items[0] is TJSONObject) then
    Exit;

  CreateFieldsFromJSONObject(TJSONObject(aArray.Items[0]));
  FDataSet.CreateDataSet;

  for I := 0 to aArray.Count - 1 do
  begin
    if not (aArray.Items[I] is TJSONObject) then
      Continue;

    LObj := TJSONObject(aArray.Items[I]);
    FDataSet.Append;
    for J := 0 to LObj.Count - 1 do
    begin
      LPair := LObj.Pairs[J];
      if FDataSet.FindField(LPair.JsonString.Value) <> nil then
      begin
        if LPair.JsonValue is TJSONNull then
          FDataSet.FieldByName(LPair.JsonString.Value).Clear
        else if LPair.JsonValue is TJSONNumber then
          FDataSet.FieldByName(LPair.JsonString.Value).AsFloat := TJSONNumber(LPair.JsonValue).AsDouble
        else if LPair.JsonValue is TJSONBool then
          FDataSet.FieldByName(LPair.JsonString.Value).AsBoolean := TJSONBool(LPair.JsonValue).AsBoolean
        else
          FDataSet.FieldByName(LPair.JsonString.Value).AsString := LPair.JsonValue.Value;
      end;
    end;
    FDataSet.Post;
  end;

  FDataSet.First;
end;

procedure TSimpleQuerySupabase.JSONObjectToDataSet(aObj: TJSONObject);
var
  J: Integer;
  LPair: TJSONPair;
begin
  if aObj.Count = 0 then
    Exit;

  CreateFieldsFromJSONObject(aObj);
  FDataSet.CreateDataSet;

  FDataSet.Append;
  for J := 0 to aObj.Count - 1 do
  begin
    LPair := aObj.Pairs[J];
    if FDataSet.FindField(LPair.JsonString.Value) <> nil then
    begin
      if LPair.JsonValue is TJSONNull then
        FDataSet.FieldByName(LPair.JsonString.Value).Clear
      else if LPair.JsonValue is TJSONNumber then
        FDataSet.FieldByName(LPair.JsonString.Value).AsFloat := TJSONNumber(LPair.JsonValue).AsDouble
      else if LPair.JsonValue is TJSONBool then
        FDataSet.FieldByName(LPair.JsonString.Value).AsBoolean := TJSONBool(LPair.JsonValue).AsBoolean
      else
        FDataSet.FieldByName(LPair.JsonString.Value).AsString := LPair.JsonValue.Value;
    end;
  end;
  FDataSet.Post;
  FDataSet.First;
end;

procedure TSimpleQuerySupabase.CreateFieldsFromJSONObject(aObj: TJSONObject);
var
  I: Integer;
  LPair: TJSONPair;
begin
  for I := 0 to aObj.Count - 1 do
  begin
    LPair := aObj.Pairs[I];
    if LPair.JsonValue is TJSONNumber then
      FDataSet.FieldDefs.Add(LPair.JsonString.Value, ftFloat, 0, False)
    else if (LPair.JsonValue is TJSONBool) then
      FDataSet.FieldDefs.Add(LPair.JsonString.Value, ftBoolean, 0, False)
    else
      FDataSet.FieldDefs.Add(LPair.JsonString.Value, ftString, 255, False);
  end;
end;

{ HTTP helpers }

function TSimpleQuerySupabase.DoHTTPRequest(const aMethod, aURL: string; const aBody: string): string;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LContent: TStringStream;
  LAuthToken: string;
begin
  Result := '';
  LClient := THTTPClient.Create;
  try
    LClient.ContentType := 'application/json';
    LClient.CustomHeaders['apikey'] := FAPIKey;

    if FToken <> '' then
      LAuthToken := FToken
    else
      LAuthToken := FAPIKey;
    LClient.CustomHeaders['Authorization'] := 'Bearer ' + LAuthToken;

    LClient.CustomHeaders['Prefer'] := 'return=representation';

    if SameText(aMethod, 'GET') then
    begin
      LResponse := LClient.Get(aURL);
    end
    else if SameText(aMethod, 'POST') then
    begin
      LContent := TStringStream.Create(aBody, TEncoding.UTF8);
      try
        LResponse := LClient.Post(aURL, LContent);
      finally
        FreeAndNil(LContent);
      end;
    end
    else if SameText(aMethod, 'PATCH') then
    begin
      LContent := TStringStream.Create(aBody, TEncoding.UTF8);
      try
        LResponse := LClient.Patch(aURL, LContent);
      finally
        FreeAndNil(LContent);
      end;
    end
    else if SameText(aMethod, 'DELETE') then
    begin
      LResponse := LClient.Delete(aURL);
    end;

    if Assigned(LResponse) then
    begin
      if (LResponse.StatusCode >= 400) then
        raise Exception.CreateFmt('Supabase HTTP %d: %s', [LResponse.StatusCode, LResponse.ContentAsString(TEncoding.UTF8)]);
      Result := LResponse.ContentAsString(TEncoding.UTF8);
    end;
  finally
    FreeAndNil(LClient);
  end;
end;

function TSimpleQuerySupabase.BuildSupabaseURL(const aTableName, aOperation: string): string;
begin
  Result := FBaseURL + '/rest/v1/' + aTableName.ToLower;
end;

end.
