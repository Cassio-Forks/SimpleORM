unit SimpleQueryHorse;

interface

uses
  SimpleInterface, SimpleTypes, System.Classes, Data.DB, System.SysUtils,
  System.JSON, System.Net.HttpClient, System.Net.URLClient,
  Datasnap.DBClient, System.Generics.Collections;

type
  TSimpleQueryHorse = class(TInterfacedObject, iSimpleQuery)
  private
    FSQL: TStringList;
    FParams: TParams;
    FDataSet: TClientDataSet;
    FBaseURL: string;
    FToken: string;
    FOnBeforeRequest: TProc<TStrings>;

    function ExtractTableName(const aSQL: string): string;
    function DetectOperation(const aSQL: string): string;
    function ExtractPKValue: Variant;
    function ExtractPKFieldName(const aSQL: string): string;
    function ParamsToJSON: string;
    procedure JSONToDataSet(const aJSON: string);
    procedure JSONArrayToDataSet(aArray: TJSONArray);
    procedure JSONObjectToDataSet(aObj: TJSONObject);
    procedure CreateFieldsFromJSONObject(aObj: TJSONObject);
    function DoHTTPRequest(const aMethod, aURL: string; const aBody: string = ''): string;
  public
    constructor Create(aBaseURL: string; aToken: string = '');
    destructor Destroy; override;
    class function New(aBaseURL: string; aToken: string = ''): iSimpleQuery;

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

    { Additional public methods }
    function Token(aValue: string): iSimpleQuery;
    function OnBeforeRequest(aProc: TProc<TStrings>): iSimpleQuery;
  end;

implementation

{ TSimpleQueryHorse }

constructor TSimpleQueryHorse.Create(aBaseURL: string; aToken: string);
begin
  inherited Create;
  FBaseURL := aBaseURL.TrimRight(['/']);
  FToken := aToken;
  FSQL := TStringList.Create;
  FParams := TParams.Create(nil);
  FDataSet := TClientDataSet.Create(nil);
end;

destructor TSimpleQueryHorse.Destroy;
begin
  FreeAndNil(FDataSet);
  FreeAndNil(FParams);
  FreeAndNil(FSQL);
  inherited;
end;

class function TSimpleQueryHorse.New(aBaseURL: string; aToken: string): iSimpleQuery;
begin
  Result := Self.Create(aBaseURL, aToken);
end;

function TSimpleQueryHorse.SQL: TStrings;
begin
  Result := FSQL;
end;

function TSimpleQueryHorse.Params: TParams;
begin
  Result := FParams;
end;

function TSimpleQueryHorse.DataSet: TDataSet;
begin
  Result := TDataSet(FDataSet);
end;

function TSimpleQueryHorse.Open(aSQL: String): iSimpleQuery;
begin
  Result := Self;
  FSQL.Text := aSQL;
  Open;
end;

function TSimpleQueryHorse.Open: iSimpleQuery;
var
  LTableName, LURL, LResponse: string;
  LPKValue: Variant;
begin
  Result := Self;
  LTableName := ExtractTableName(FSQL.Text);
  LURL := FBaseURL + '/' + LTableName.ToLower;

  LPKValue := ExtractPKValue;
  if not VarIsNull(LPKValue) and not VarIsEmpty(LPKValue) then
    LURL := LURL + '/' + VarToStr(LPKValue);

  LResponse := DoHTTPRequest('GET', LURL);
  JSONToDataSet(LResponse);
end;

function TSimpleQueryHorse.ExecSQL: iSimpleQuery;
var
  LTableName, LOp, LURL, LBody: string;
  LPKValue: Variant;
begin
  Result := Self;
  LOp := DetectOperation(FSQL.Text);
  LTableName := ExtractTableName(FSQL.Text);
  LURL := FBaseURL + '/' + LTableName.ToLower;

  if SameText(LOp, 'INSERT') then
  begin
    LBody := ParamsToJSON;
    DoHTTPRequest('POST', LURL, LBody);
  end
  else if SameText(LOp, 'UPDATE') then
  begin
    LPKValue := ExtractPKValue;
    if not VarIsNull(LPKValue) and not VarIsEmpty(LPKValue) then
      LURL := LURL + '/' + VarToStr(LPKValue);
    LBody := ParamsToJSON;
    DoHTTPRequest('PUT', LURL, LBody);
  end
  else if SameText(LOp, 'DELETE') then
  begin
    LPKValue := ExtractPKValue;
    if not VarIsNull(LPKValue) and not VarIsEmpty(LPKValue) then
      LURL := LURL + '/' + VarToStr(LPKValue);
    DoHTTPRequest('DELETE', LURL);
  end;
end;

function TSimpleQueryHorse.StartTransaction: iSimpleQuery;
begin
  Result := Self;
end;

function TSimpleQueryHorse.Commit: iSimpleQuery;
begin
  Result := Self;
end;

function TSimpleQueryHorse.Rollback: iSimpleQuery;
begin
  Result := Self;
end;

function TSimpleQueryHorse.EndTransaction: iSimpleQuery;
begin
  Result := Self;
end;

function TSimpleQueryHorse.InTransaction: Boolean;
begin
  Result := False;
end;

function TSimpleQueryHorse.SQLType: TSQLType;
begin
  Result := TSQLType.MySQL;
end;

function TSimpleQueryHorse.Token(aValue: string): iSimpleQuery;
begin
  Result := Self;
  FToken := aValue;
end;

function TSimpleQueryHorse.OnBeforeRequest(aProc: TProc<TStrings>): iSimpleQuery;
begin
  Result := Self;
  FOnBeforeRequest := aProc;
end;

{ Private helpers }

function TSimpleQueryHorse.ExtractTableName(const aSQL: string): string;
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

function TSimpleQueryHorse.DetectOperation(const aSQL: string): string;
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

function TSimpleQueryHorse.ExtractPKFieldName(const aSQL: string): string;
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

function TSimpleQueryHorse.ExtractPKValue: Variant;
var
  LPKField: string;
  I: Integer;
begin
  Result := Null;
  LPKField := ExtractPKFieldName(FSQL.Text);

  if LPKField = '' then
  begin
    // Try to find a param that looks like a PK by checking WHERE clause params
    for I := 0 to FParams.Count - 1 do
    begin
      if not VarIsNull(FParams[I].Value) and not VarIsEmpty(FParams[I].Value) then
      begin
        // Use the first param that matches a WHERE clause parameter
        if Pos(':' + FParams[I].Name, FSQL.Text) > 0 then
        begin
          // Check if this param is in a WHERE clause
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

  // Remove leading colon if present
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

function TSimpleQueryHorse.ParamsToJSON: string;
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
        LObj.AddPair(LParam.Name, TJSONNull.Create)
      else
      begin
        case LParam.DataType of
          ftInteger, ftSmallint, ftWord, ftLargeint, ftAutoInc, ftShortint:
            LObj.AddPair(LParam.Name, TJSONNumber.Create(LParam.AsInteger));
          ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftExtended, ftSingle:
            LObj.AddPair(LParam.Name, TJSONNumber.Create(LParam.AsFloat));
          ftBoolean:
            LObj.AddPair(LParam.Name, TJSONBool.Create(LParam.AsBoolean));
        else
          LObj.AddPair(LParam.Name, LParam.AsString);
        end;
      end;
    end;
    Result := LObj.ToString;
  finally
    LObj.Free;
  end;
end;

procedure TSimpleQueryHorse.JSONToDataSet(const aJSON: string);
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
      // Check for { "data": [...], "count": N } wrapper
      if Assigned(LObj.Values['data']) and (LObj.Values['data'] is TJSONArray) then
        JSONArrayToDataSet(TJSONArray(LObj.Values['data']))
      else
        JSONObjectToDataSet(LObj);
    end;
  finally
    LValue.Free;
  end;
end;

procedure TSimpleQueryHorse.CreateFieldsFromJSONObject(aObj: TJSONObject);
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

procedure TSimpleQueryHorse.JSONArrayToDataSet(aArray: TJSONArray);
var
  I, J: Integer;
  LObj: TJSONObject;
  LPair: TJSONPair;
begin
  if aArray.Count = 0 then
    Exit;

  // Create fields from first object
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

procedure TSimpleQueryHorse.JSONObjectToDataSet(aObj: TJSONObject);
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

function TSimpleQueryHorse.DoHTTPRequest(const aMethod, aURL: string; const aBody: string): string;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LHeaders: TStringList;
  LContent: TStringStream;
begin
  Result := '';
  LClient := THTTPClient.Create;
  LHeaders := TStringList.Create;
  try
    LClient.ContentType := 'application/json';

    if FToken <> '' then
      LClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;

    if Assigned(FOnBeforeRequest) then
    begin
      FOnBeforeRequest(LHeaders);
      var I: Integer;
      for I := 0 to LHeaders.Count - 1 do
        LClient.CustomHeaders[LHeaders.Names[I]] := LHeaders.ValueFromIndex[I];
    end;

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
        LContent.Free;
      end;
    end
    else if SameText(aMethod, 'PUT') then
    begin
      LContent := TStringStream.Create(aBody, TEncoding.UTF8);
      try
        LResponse := LClient.Put(aURL, LContent);
      finally
        LContent.Free;
      end;
    end
    else if SameText(aMethod, 'DELETE') then
    begin
      LResponse := LClient.Delete(aURL);
    end;

    if Assigned(LResponse) then
      Result := LResponse.ContentAsString(TEncoding.UTF8);
  finally
    LHeaders.Free;
    LClient.Free;
  end;
end;

end.
