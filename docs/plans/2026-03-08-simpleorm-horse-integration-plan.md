# SimpleORM + ExpxHorse Integration — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integração completa SimpleORM ↔ ExpxHorse com serializer RTTI, router automático e driver REST cliente.

**Architecture:** 3 novas units (SimpleSerializer, SimpleHorseRouter, SimpleQueryHorse) que compartilham o RTTI do SimpleORM para Entity↔JSON, auto-geração de rotas CRUD no Horse, e driver REST que implementa iSimpleQuery.

**Tech Stack:** Delphi, RTTI, System.JSON, System.Net.HttpClient, Horse (ExpxHorse)

---

### Task 1: SimpleSerializer — EntityToJSON

**Files:**
- Create: `src/SimpleSerializer.pas`

**Context:** Esta é a base de toda a integração. O serializer converte entidades Delphi para JSON usando os mesmos atributos RTTI que o SimpleORM já usa (`[Campo]`, `[Ignore]`, `[PK]`).

**Step 1: Criar a unit SimpleSerializer.pas com a estrutura base**

Criar a unit com uses necessários e a classe `TSimpleSerializer`:

```pascal
unit SimpleSerializer;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Rtti,
  System.Generics.Collections, System.TypInfo,
  SimpleAttributes;

type
  TSimpleSerializer = class
  public
    class function EntityToJSON<T: class>(aEntity: T): TJSONObject;
  end;

implementation

class function TSimpleSerializer.EntityToJSON<T>(aEntity: T): TJSONObject;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LAttr: TCustomAttribute;
  LFieldName: string;
  LValue: TValue;
  LIgnore: Boolean;
begin
  Result := TJSONObject.Create;
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(aEntity.ClassType);
    for LProp in LType.GetProperties do
    begin
      LIgnore := False;
      LFieldName := '';

      for LAttr in LProp.GetAttributes do
      begin
        if LAttr is Ignore then
        begin
          LIgnore := True;
          Break;
        end;
        if LAttr is Campo then
          LFieldName := Campo(LAttr).Name;
      end;

      if LIgnore then
        Continue;

      if LFieldName.IsEmpty then
        Continue;

      LValue := LProp.GetValue(TObject(aEntity));

      case LProp.PropertyType.TypeKind of
        tkInteger, tkInt64:
          Result.AddPair(LFieldName, TJSONNumber.Create(LValue.AsInteger));
        tkFloat:
        begin
          if LProp.PropertyType.Handle = TypeInfo(TDateTime) then
            Result.AddPair(LFieldName, DateToISO8601(LValue.AsExtended))
          else
            Result.AddPair(LFieldName, TJSONNumber.Create(LValue.AsExtended));
        end;
        tkUString, tkString, tkLString, tkWString:
          Result.AddPair(LFieldName, LValue.AsString);
        tkEnumeration:
        begin
          if LProp.PropertyType.Handle = TypeInfo(Boolean) then
            Result.AddPair(LFieldName, TJSONBool.Create(LValue.AsBoolean))
          else
            Result.AddPair(LFieldName, TJSONNumber.Create(LValue.AsOrdinal));
        end;
      end;
    end;
  finally
    LContext.Free;
  end;
end;

end.
```

**Notes:**
- `DateToISO8601` de `System.DateUtils` para converter TDateTime
- Só serializa propriedades que têm `[Campo]` — propriedades sem atributo são ignoradas
- Adicionar `System.DateUtils` ao uses

**Step 2: Commit**

```bash
git add src/SimpleSerializer.pas
git commit -m "feat: add SimpleSerializer with EntityToJSON"
```

---

### Task 2: SimpleSerializer — JSONToEntity

**Files:**
- Modify: `src/SimpleSerializer.pas`

**Context:** Método inverso — pega um TJSONObject e popula uma entidade, mapeando pelos nomes `[Campo]`.

**Step 1: Adicionar JSONToEntity à classe**

Adicionar na seção public:
```pascal
class function JSONToEntity<T: class, constructor>(aJSON: TJSONObject): T;
```

Implementação:
```pascal
class function TSimpleSerializer.JSONToEntity<T>(aJSON: TJSONObject): T;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LAttr: TCustomAttribute;
  LFieldName: string;
  LIgnore: Boolean;
  LJSONValue: TJSONValue;
begin
  Result := T.Create;
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TObject(Result).ClassType);
    for LProp in LType.GetProperties do
    begin
      LIgnore := False;
      LFieldName := '';

      for LAttr in LProp.GetAttributes do
      begin
        if LAttr is Ignore then
        begin
          LIgnore := True;
          Break;
        end;
        if LAttr is Campo then
          LFieldName := Campo(LAttr).Name;
      end;

      if LIgnore or LFieldName.IsEmpty then
        Continue;

      LJSONValue := aJSON.GetValue(LFieldName);
      if LJSONValue = nil then
        Continue;

      case LProp.PropertyType.TypeKind of
        tkInteger, tkInt64:
          LProp.SetValue(TObject(Result), TValue.From<Integer>(LJSONValue.AsType<Integer>));
        tkFloat:
        begin
          if LProp.PropertyType.Handle = TypeInfo(TDateTime) then
            LProp.SetValue(TObject(Result), TValue.From<TDateTime>(ISO8601ToDate(LJSONValue.Value)))
          else
            LProp.SetValue(TObject(Result), TValue.From<Double>(LJSONValue.AsType<Double>));
        end;
        tkUString, tkString, tkLString, tkWString:
          LProp.SetValue(TObject(Result), LJSONValue.Value);
        tkEnumeration:
        begin
          if LProp.PropertyType.Handle = TypeInfo(Boolean) then
            LProp.SetValue(TObject(Result), TValue.From<Boolean>(LJSONValue.AsType<Boolean>))
          else
            LProp.SetValue(TObject(Result), TValue.FromOrdinal(LProp.PropertyType.Handle, LJSONValue.AsType<Integer>));
        end;
      end;
    end;
  finally
    LContext.Free;
  end;
end;
```

**Step 2: Commit**

```bash
git add src/SimpleSerializer.pas
git commit -m "feat: add JSONToEntity to SimpleSerializer"
```

---

### Task 3: SimpleSerializer — List methods

**Files:**
- Modify: `src/SimpleSerializer.pas`

**Context:** Métodos para converter listas de entidades ↔ JSONArray.

**Step 1: Adicionar EntityListToJSONArray e JSONArrayToEntityList**

Declaração:
```pascal
class function EntityListToJSONArray<T: class>(aList: TObjectList<T>): TJSONArray;
class function JSONArrayToEntityList<T: class, constructor>(aArray: TJSONArray): TObjectList<T>;
```

Implementação:
```pascal
class function TSimpleSerializer.EntityListToJSONArray<T>(aList: TObjectList<T>): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := 0 to aList.Count - 1 do
    Result.AddElement(EntityToJSON<T>(aList[I]));
end;

class function TSimpleSerializer.JSONArrayToEntityList<T>(aArray: TJSONArray): TObjectList<T>;
var
  I: Integer;
begin
  Result := TObjectList<T>.Create;
  for I := 0 to aArray.Count - 1 do
    Result.Add(JSONToEntity<T>(aArray.Items[I] as TJSONObject));
end;
```

**Step 2: Commit**

```bash
git add src/SimpleSerializer.pas
git commit -m "feat: add list serialization to SimpleSerializer"
```

---

### Task 4: SimpleHorseRouter — Estrutura base e registro de rotas

**Files:**
- Create: `src/SimpleHorseRouter.pas`

**Context:** Esta unit auto-gera rotas CRUD no Horse. Depende de `Horse` e `SimpleSerializer`. Usa o atributo `[Tabela]` para derivar o path padrão.

**Step 1: Criar SimpleHorseRouter.pas com RegisterEntity**

```pascal
unit SimpleHorseRouter;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Rtti,
  System.Generics.Collections,
  Horse,
  SimpleInterface, SimpleAttributes, SimpleSerializer;

type
  TEntityCallback = reference to procedure(aEntity: TObject; var aContinue: Boolean);
  TEntityAfterCallback = reference to procedure(aEntity: TObject);
  TDeleteCallback = reference to procedure(aId: string; var aContinue: Boolean);

  TSimpleHorseRouterConfig = class
  private
    FOnBeforeInsert: TEntityCallback;
    FOnAfterInsert: TEntityAfterCallback;
    FOnBeforeUpdate: TEntityCallback;
    FOnBeforeDelete: TDeleteCallback;
  public
    function OnBeforeInsert(aProc: TEntityCallback): TSimpleHorseRouterConfig;
    function OnAfterInsert(aProc: TEntityAfterCallback): TSimpleHorseRouterConfig;
    function OnBeforeUpdate(aProc: TEntityCallback): TSimpleHorseRouterConfig;
    function OnBeforeDelete(aProc: TDeleteCallback): TSimpleHorseRouterConfig;
  end;

  TSimpleHorseRouter = class
  public
    class function RegisterEntity<T: class, constructor>(
      aApp: THorse;
      aQuery: iSimpleQuery;
      aPath: string = ''
    ): TSimpleHorseRouterConfig;
  end;

implementation

uses
  SimpleDAO, SimpleRTTI;

{ TSimpleHorseRouterConfig }

function TSimpleHorseRouterConfig.OnBeforeInsert(aProc: TEntityCallback): TSimpleHorseRouterConfig;
begin
  FOnBeforeInsert := aProc;
  Result := Self;
end;

function TSimpleHorseRouterConfig.OnAfterInsert(aProc: TEntityAfterCallback): TSimpleHorseRouterConfig;
begin
  FOnAfterInsert := aProc;
  Result := Self;
end;

function TSimpleHorseRouterConfig.OnBeforeUpdate(aProc: TEntityCallback): TSimpleHorseRouterConfig;
begin
  FOnBeforeUpdate := aProc;
  Result := Self;
end;

function TSimpleHorseRouterConfig.OnBeforeDelete(aProc: TDeleteCallback): TSimpleHorseRouterConfig;
begin
  FOnBeforeDelete := aProc;
  Result := Self;
end;

{ TSimpleHorseRouter }

class function TSimpleHorseRouter.RegisterEntity<T>(
  aApp: THorse; aQuery: iSimpleQuery; aPath: string): TSimpleHorseRouterConfig;
var
  LTableName: string;
  LPath: string;
  LConfig: TSimpleHorseRouterConfig;
begin
  LConfig := TSimpleHorseRouterConfig.Create;
  Result := LConfig;

  // Derive path from Tabela attribute if not provided
  if aPath.IsEmpty then
  begin
    TSimpleRTTI<T>.New(nil).TableName(LTableName);
    LPath := '/' + LowerCase(LTableName);
  end
  else
    LPath := aPath;

  // GET /path - List all
  aApp.Get(LPath,
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LList: TObjectList<T>;
      LArray: TJSONArray;
      LResult: TJSONObject;
      LSkip, LTake: Integer;
      LDAO: iSimpleDAO<T>;
    begin
      try
        LDAO := TSimpleDAO<T>.New(aQuery);

        LSkip := StrToIntDef(Req.Query['skip'], 0);
        LTake := StrToIntDef(Req.Query['take'], 0);

        LList := TObjectList<T>.Create;
        try
          if (LSkip > 0) or (LTake > 0) then
            LDAO.SQL.Skip(LSkip).Take(LTake).&End.Find(LList)
          else
            LDAO.Find(LList);

          LArray := TSimpleSerializer.EntityListToJSONArray<T>(LList);
          LResult := TJSONObject.Create;
          LResult.AddPair('data', LArray);
          LResult.AddPair('count', TJSONNumber.Create(LList.Count));

          Res.Send<TJSONObject>(LResult).Status(200);
        finally
          LList.Free;
        end;
      except
        on E: Exception do
          Res.Send(TJSONObject.Create.AddPair('error', E.Message)).Status(500);
      end;
    end
  );

  // GET /path/:id - Find by ID
  aApp.Get(LPath + '/:id',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LEntity: T;
      LJSON: TJSONObject;
      LDAO: iSimpleDAO<T>;
    begin
      try
        LDAO := TSimpleDAO<T>.New(aQuery);
        LEntity := T.Create;
        try
          LDAO.Find(Req.Params['id'], LEntity);
          LJSON := TSimpleSerializer.EntityToJSON<T>(LEntity);
          Res.Send<TJSONObject>(LJSON).Status(200);
        finally
          LEntity.Free;
        end;
      except
        on E: Exception do
          Res.Send(TJSONObject.Create.AddPair('error', E.Message)).Status(500);
      end;
    end
  );

  // POST /path - Insert
  aApp.Post(LPath,
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LEntity: T;
      LJSON: TJSONObject;
      LContinue: Boolean;
      LDAO: iSimpleDAO<T>;
    begin
      try
        LJSON := TJSONObject.ParseJSONValue(Req.Body) as TJSONObject;
        try
          LEntity := TSimpleSerializer.JSONToEntity<T>(LJSON);
        finally
          LJSON.Free;
        end;

        try
          LContinue := True;
          if Assigned(LConfig.FOnBeforeInsert) then
            LConfig.FOnBeforeInsert(LEntity, LContinue);

          if not LContinue then
          begin
            Res.Send(TJSONObject.Create.AddPair('error', 'Operation cancelled')).Status(400);
            Exit;
          end;

          LDAO := TSimpleDAO<T>.New(aQuery);
          LDAO.Insert(LEntity);

          if Assigned(LConfig.FOnAfterInsert) then
            LConfig.FOnAfterInsert(LEntity);

          LJSON := TSimpleSerializer.EntityToJSON<T>(LEntity);
          Res.Send<TJSONObject>(LJSON).Status(201);
        finally
          LEntity.Free;
        end;
      except
        on E: Exception do
          Res.Send(TJSONObject.Create.AddPair('error', E.Message)).Status(500);
      end;
    end
  );

  // PUT /path/:id - Update
  aApp.Put(LPath + '/:id',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LEntity: T;
      LJSON: TJSONObject;
      LContinue: Boolean;
      LDAO: iSimpleDAO<T>;
    begin
      try
        LJSON := TJSONObject.ParseJSONValue(Req.Body) as TJSONObject;
        try
          LEntity := TSimpleSerializer.JSONToEntity<T>(LJSON);
        finally
          LJSON.Free;
        end;

        try
          LContinue := True;
          if Assigned(LConfig.FOnBeforeUpdate) then
            LConfig.FOnBeforeUpdate(LEntity, LContinue);

          if not LContinue then
          begin
            Res.Send(TJSONObject.Create.AddPair('error', 'Operation cancelled')).Status(400);
            Exit;
          end;

          LDAO := TSimpleDAO<T>.New(aQuery);
          LDAO.Update(LEntity);

          LJSON := TSimpleSerializer.EntityToJSON<T>(LEntity);
          Res.Send<TJSONObject>(LJSON).Status(200);
        finally
          LEntity.Free;
        end;
      except
        on E: Exception do
          Res.Send(TJSONObject.Create.AddPair('error', E.Message)).Status(500);
      end;
    end
  );

  // DELETE /path/:id - Delete
  aApp.Delete(LPath + '/:id',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LEntity: T;
      LContinue: Boolean;
      LDAO: iSimpleDAO<T>;
      LPK: string;
    begin
      try
        LContinue := True;
        if Assigned(LConfig.FOnBeforeDelete) then
          LConfig.FOnBeforeDelete(Req.Params['id'], LContinue);

        if not LContinue then
        begin
          Res.Send(TJSONObject.Create.AddPair('error', 'Operation cancelled')).Status(400);
          Exit;
        end;

        LDAO := TSimpleDAO<T>.New(aQuery);
        TSimpleRTTI<T>.New(nil).PrimaryKey(LPK);
        LDAO.Delete(LPK, Req.Params['id']);

        Res.Status(204);
      except
        on E: Exception do
          Res.Send(TJSONObject.Create.AddPair('error', E.Message)).Status(500);
      end;
    end
  );
end;

end.
```

**Notes:**
- `RegisterEntity` recebe `iSimpleQuery` em vez de `iSimpleDAO` para que cada request crie seu próprio DAO (thread safety)
- Callbacks são referências anônimas armazenadas no `TSimpleHorseRouterConfig`
- O `TSimpleHorseRouterConfig` retornado permite encadear callbacks após o registro

**Step 2: Commit**

```bash
git add src/SimpleHorseRouter.pas
git commit -m "feat: add SimpleHorseRouter with auto CRUD route generation"
```

---

### Task 5: SimpleQueryHorse — Estrutura base e HTTP client

**Files:**
- Create: `src/SimpleQueryHorse.pas`

**Context:** Driver REST que implementa `iSimpleQuery`. Intercepta o SQL gerado e traduz em chamadas HTTP. Usa `THTTPClient` nativo do Delphi.

**Step 1: Criar SimpleQueryHorse.pas**

```pascal
unit SimpleQueryHorse;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.HttpClient,
  System.Net.URLClient, System.Generics.Collections,
  Data.DB, Datasnap.DBClient,
  SimpleInterface, SimpleAttributes;

type
  TSimpleQueryHorse = class(TInterfacedObject, iSimpleQuery)
  private
    FBaseURL: string;
    FToken: string;
    FOnBeforeRequest: TProc<TStrings>;
    FSQL: TStringList;
    FParams: TParams;
    FDataSet: TClientDataSet;
    FHTTPClient: THTTPClient;
    FSQLType: TSQLType;

    function DoGet(const aURL: string): string;
    function DoPost(const aURL: string; const aBody: string): string;
    function DoPut(const aURL: string; const aBody: string): string;
    function DoDelete(const aURL: string): string;
    procedure ApplyHeaders(aHeaders: TNetHeaders; var aResult: TNetHeaders);
    procedure JSONArrayToDataSet(aArray: TJSONArray);
    procedure JSONObjectToDataSet(aObj: TJSONObject);
  public
    constructor Create(aBaseURL: string; aToken: string = '');
    destructor Destroy; override;
    class function New(aBaseURL: string; aToken: string = ''): iSimpleQuery;

    // iSimpleQuery
    function SQL: TStrings;
    function Params: TParams;
    function ExecSQL: iSimpleQuery;
    function DataSet: TDataSet;
    function Open(aSQL: string): iSimpleQuery; overload;
    function Open: iSimpleQuery; overload;
    function StartTransaction: iSimpleQuery;
    function Commit: iSimpleQuery;
    function Rollback: iSimpleQuery;
    function EndTransaction: iSimpleQuery;
    function InTransaction: Boolean;
    function SQLType: TSQLType;

    // Extras
    function Token(aValue: string): iSimpleQuery;
    function OnBeforeRequest(aProc: TProc<TStrings>): iSimpleQuery;
  end;

implementation

uses
  System.StrUtils, System.DateUtils, System.TypInfo;

{ TSimpleQueryHorse }

constructor TSimpleQueryHorse.Create(aBaseURL: string; aToken: string);
begin
  FBaseURL := aBaseURL.TrimRight(['/']);
  FToken := aToken;
  FSQL := TStringList.Create;
  FParams := TParams.Create(nil);
  FDataSet := TClientDataSet.Create(nil);
  FHTTPClient := THTTPClient.Create;
  FHTTPClient.ContentType := 'application/json';
  FSQLType := TSQLType.stMySQL; // REST doesn't have a real DB type
end;

destructor TSimpleQueryHorse.Destroy;
begin
  FSQL.Free;
  FParams.Free;
  FDataSet.Free;
  FHTTPClient.Free;
  inherited;
end;

class function TSimpleQueryHorse.New(aBaseURL: string; aToken: string): iSimpleQuery;
begin
  Result := Create(aBaseURL, aToken);
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
  Result := FDataSet;
end;

function TSimpleQueryHorse.SQLType: TSQLType;
begin
  Result := FSQLType;
end;

function TSimpleQueryHorse.Token(aValue: string): iSimpleQuery;
begin
  FToken := aValue;
  Result := Self;
end;

function TSimpleQueryHorse.OnBeforeRequest(aProc: TProc<TStrings>): iSimpleQuery;
begin
  FOnBeforeRequest := aProc;
  Result := Self;
end;

procedure TSimpleQueryHorse.ApplyHeaders(aHeaders: TNetHeaders; var aResult: TNetHeaders);
var
  LCustomHeaders: TStringList;
  I: Integer;
begin
  aResult := aHeaders;
  if not FToken.IsEmpty then
  begin
    SetLength(aResult, Length(aResult) + 1);
    aResult[High(aResult)] := TNameValuePair.Create('Authorization', 'Bearer ' + FToken);
  end;

  if Assigned(FOnBeforeRequest) then
  begin
    LCustomHeaders := TStringList.Create;
    try
      FOnBeforeRequest(LCustomHeaders);
      for I := 0 to LCustomHeaders.Count - 1 do
      begin
        SetLength(aResult, Length(aResult) + 1);
        aResult[High(aResult)] := TNameValuePair.Create(
          LCustomHeaders.Names[I],
          LCustomHeaders.ValueFromIndex[I]
        );
      end;
    finally
      LCustomHeaders.Free;
    end;
  end;
end;

function TSimpleQueryHorse.DoGet(const aURL: string): string;
var
  LHeaders: TNetHeaders;
  LResponse: IHTTPResponse;
begin
  ApplyHeaders(nil, LHeaders);
  LResponse := FHTTPClient.Get(aURL, nil, LHeaders);
  Result := LResponse.ContentAsString;
end;

function TSimpleQueryHorse.DoPost(const aURL: string; const aBody: string): string;
var
  LHeaders: TNetHeaders;
  LResponse: IHTTPResponse;
  LStream: TStringStream;
begin
  ApplyHeaders(nil, LHeaders);
  LStream := TStringStream.Create(aBody, TEncoding.UTF8);
  try
    LResponse := FHTTPClient.Post(aURL, LStream, nil, LHeaders);
    Result := LResponse.ContentAsString;
  finally
    LStream.Free;
  end;
end;

function TSimpleQueryHorse.DoPut(const aURL: string; const aBody: string): string;
var
  LHeaders: TNetHeaders;
  LResponse: IHTTPResponse;
  LStream: TStringStream;
begin
  ApplyHeaders(nil, LHeaders);
  LStream := TStringStream.Create(aBody, TEncoding.UTF8);
  try
    LResponse := FHTTPClient.Put(aURL, LStream, nil, LHeaders);
    Result := LResponse.ContentAsString;
  finally
    LStream.Free;
  end;
end;

function TSimpleQueryHorse.DoDelete(const aURL: string): string;
var
  LHeaders: TNetHeaders;
  LResponse: IHTTPResponse;
begin
  ApplyHeaders(nil, LHeaders);
  LResponse := FHTTPClient.Delete(aURL, LHeaders);
  Result := LResponse.ContentAsString;
end;

procedure TSimpleQueryHorse.JSONObjectToDataSet(aObj: TJSONObject);
var
  LPair: TJSONPair;
begin
  FDataSet.Close;
  FDataSet.FieldDefs.Clear;

  for LPair in aObj do
  begin
    if LPair.JsonValue is TJSONNumber then
      FDataSet.FieldDefs.Add(LPair.JsonString.Value, ftFloat)
    else if LPair.JsonValue is TJSONBool then
      FDataSet.FieldDefs.Add(LPair.JsonString.Value, ftBoolean)
    else
      FDataSet.FieldDefs.Add(LPair.JsonString.Value, ftString, 255);
  end;

  FDataSet.CreateDataSet;
  FDataSet.Append;
  for LPair in aObj do
    FDataSet.FieldByName(LPair.JsonString.Value).AsString := LPair.JsonValue.Value;
  FDataSet.Post;
  FDataSet.First;
end;

procedure TSimpleQueryHorse.JSONArrayToDataSet(aArray: TJSONArray);
var
  I: Integer;
  LObj: TJSONObject;
  LPair: TJSONPair;
begin
  FDataSet.Close;
  FDataSet.FieldDefs.Clear;

  if aArray.Count = 0 then
    Exit;

  // Define fields from first object
  LObj := aArray.Items[0] as TJSONObject;
  for LPair in LObj do
  begin
    if LPair.JsonValue is TJSONNumber then
      FDataSet.FieldDefs.Add(LPair.JsonString.Value, ftFloat)
    else if LPair.JsonValue is TJSONBool then
      FDataSet.FieldDefs.Add(LPair.JsonString.Value, ftBoolean)
    else
      FDataSet.FieldDefs.Add(LPair.JsonString.Value, ftString, 255);
  end;

  FDataSet.CreateDataSet;

  for I := 0 to aArray.Count - 1 do
  begin
    LObj := aArray.Items[I] as TJSONObject;
    FDataSet.Append;
    for LPair in LObj do
      FDataSet.FieldByName(LPair.JsonString.Value).AsString := LPair.JsonValue.Value;
    FDataSet.Post;
  end;

  FDataSet.First;
end;

function TSimpleQueryHorse.Open(aSQL: string): iSimpleQuery;
var
  LResponse: string;
  LJSON: TJSONValue;
  LData: TJSONArray;
begin
  Result := Self;
  FSQL.Text := aSQL;
  Open;
end;

function TSimpleQueryHorse.Open: iSimpleQuery;
var
  LResponse: string;
  LJSON: TJSONValue;
  LData: TJSONValue;
  LURL: string;
  LSQLText: string;
  LTableName: string;
  LWhereValue: string;
begin
  Result := Self;

  // Parse the SQL to extract table name and WHERE clause
  LSQLText := FSQL.Text.Trim;

  // Extract table name from SELECT ... FROM TABLE_NAME
  LTableName := ExtractTableFromSQL(LSQLText);
  LURL := FBaseURL + '/' + LowerCase(LTableName);

  // Check for WHERE with PK (single record lookup)
  LWhereValue := ExtractWhereValueFromParams;
  if not LWhereValue.IsEmpty then
    LURL := LURL + '/' + LWhereValue;

  // Add pagination params
  LURL := LURL + ExtractPaginationFromSQL(LSQLText);

  LResponse := DoGet(LURL);
  LJSON := TJSONObject.ParseJSONValue(LResponse);
  try
    if LJSON is TJSONObject then
    begin
      LData := TJSONObject(LJSON).GetValue('data');
      if (LData <> nil) and (LData is TJSONArray) then
        JSONArrayToDataSet(TJSONArray(LData))
      else
        JSONObjectToDataSet(TJSONObject(LJSON));
    end
    else if LJSON is TJSONArray then
      JSONArrayToDataSet(TJSONArray(LJSON));
  finally
    LJSON.Free;
  end;
end;

function TSimpleQueryHorse.ExecSQL: iSimpleQuery;
var
  LSQLText: string;
  LTableName: string;
  LURL: string;
  LBody: string;
  LParamValue: string;
begin
  Result := Self;
  LSQLText := FSQL.Text.Trim.ToUpper;
  LTableName := ExtractTableFromSQL(FSQL.Text.Trim);
  LURL := FBaseURL + '/' + LowerCase(LTableName);

  // Build JSON body from params
  LBody := ParamsToJSON;

  if LSQLText.StartsWith('INSERT') then
    DoPost(LURL, LBody)
  else if LSQLText.StartsWith('UPDATE') then
  begin
    LParamValue := ExtractWhereValueFromParams;
    if not LParamValue.IsEmpty then
      LURL := LURL + '/' + LParamValue;
    DoPut(LURL, LBody);
  end
  else if LSQLText.StartsWith('DELETE') then
  begin
    LParamValue := ExtractWhereValueFromParams;
    if not LParamValue.IsEmpty then
      LURL := LURL + '/' + LParamValue;
    DoDelete(LURL);
  end;
end;

// Transaction stubs (REST is stateless)
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

end.
```

**Notes:**
- Helper functions `ExtractTableFromSQL`, `ExtractWhereValueFromParams`, `ExtractPaginationFromSQL`, `ParamsToJSON` need to be implemented as private methods that parse the SQL string
- These parse the SQL generated by `TSimpleSQL` to derive: table name, WHERE pk value, pagination params
- Transaction methods are no-ops (REST is stateless)

**Step 2: Implement SQL parsing helpers**

Add these private methods:

```pascal
function ExtractTableFromSQL(const aSQL: string): string;
// Extracts table name from "SELECT ... FROM TABLE_NAME" or "INSERT INTO TABLE_NAME" etc.
// Uses simple string parsing since SQL format from TSimpleSQL is predictable

function ExtractWhereValueFromParams: string;
// Looks at FParams for the PK parameter and returns its value

function ExtractPaginationFromSQL(const aSQL: string): string;
// Returns "?skip=N&take=N" if FIRST/SKIP or LIMIT/OFFSET present in SQL

function ParamsToJSON: string;
// Converts FParams to a JSON object string { "FIELD": value, ... }
```

**Step 3: Commit**

```bash
git add src/SimpleQueryHorse.pas
git commit -m "feat: add SimpleQueryHorse REST client driver"
```

---

### Task 6: Registrar novas units no SimpleORM.dpk

**Files:**
- Modify: `SimpleORM.dpk`

**Context:** Adicionar as 3 novas units ao package.

**Step 1: Adicionar ao contains do .dpk**

Adicionar:
```pascal
SimpleSerializer in 'src\SimpleSerializer.pas',
SimpleHorseRouter in 'src\SimpleHorseRouter.pas',
SimpleQueryHorse in 'src\SimpleQueryHorse.pas';
```

**Notes:**
- `SimpleHorseRouter` depende de `Horse`, que pode não estar disponível em todos os projetos. Considerar usar `{$IFDEF HORSE}` ou manter em unit separada que o developer inclui manualmente.
- Decisão: manter as 3 units no package mas `SimpleHorseRouter` e `SimpleQueryHorse` são opcionais — o developer inclui no uses apenas o que precisa.

**Step 2: Commit**

```bash
git add SimpleORM.dpk
git commit -m "feat: register Horse integration units in SimpleORM.dpk"
```

---

### Task 7: Atualizar SimpleORM.dpr

**Files:**
- Modify: `SimpleORM.dpr`

**Step 1: Adicionar novas units ao uses**

```pascal
SimpleSerializer in 'src\SimpleSerializer.pas',
SimpleQueryHorse in 'src\SimpleQueryHorse.pas',
SimpleHorseRouter in 'src\SimpleHorseRouter.pas';
```

**Step 2: Commit**

```bash
git add SimpleORM.dpr
git commit -m "feat: add Horse integration units to SimpleORM.dpr"
```

---

### Task 8: Criar sample servidor Horse

**Files:**
- Create: `samples/horse-integration/Server/HorseServer.dpr`
- Create: `samples/horse-integration/Server/Controller.Setup.pas`

**Context:** Exemplo funcional de servidor Horse com rotas auto-geradas. Mostra como registrar entidades com 3 linhas.

**Step 1: Criar Controller.Setup.pas**

```pascal
unit Controller.Setup;

interface

uses
  Horse, SimpleInterface, SimpleQueryFiredac, SimpleHorseRouter,
  Model.Produto;

procedure SetupRoutes(aApp: THorse; aConnection: TFDConnection);

implementation

procedure SetupRoutes(aApp: THorse; aConnection: TFDConnection);
var
  LQuery: iSimpleQuery;
begin
  LQuery := TSimpleQueryFiredac.New(aConnection);

  TSimpleHorseRouter.RegisterEntity<TProduto>(aApp, LQuery);

  // With custom path and callbacks:
  // TSimpleHorseRouter.RegisterEntity<TCliente>(aApp, LQuery, '/api/clientes')
  //   .OnBeforeInsert(
  //     procedure(aEntity: TObject; var aContinue: Boolean)
  //     begin
  //       // Custom validation
  //       aContinue := True;
  //     end
  //   );
end;

end.
```

**Step 2: Criar HorseServer.dpr**

```pascal
program HorseServer;

uses
  Horse,
  Controller.Setup;

begin
  // SetupRoutes(THorse, Connection);
  THorse.Listen(9000);
end.
```

**Step 3: Commit**

```bash
git add samples/horse-integration/
git commit -m "feat: add Horse integration server sample"
```

---

### Task 9: Criar sample cliente

**Files:**
- Create: `samples/horse-integration/Client/HorseClient.dpr`
- Create: `samples/horse-integration/Client/Form.Main.pas`

**Context:** Exemplo de frontend usando SimpleQueryHorse. Mostra que o código é idêntico ao uso com banco local, mudando apenas a linha do driver.

**Step 1: Criar Form.Main.pas**

```pascal
unit Form.Main;

interface

uses
  Vcl.Forms, Vcl.StdCtrls, Vcl.Grids, Vcl.DBGrids, Data.DB,
  System.Classes, System.Generics.Collections,
  SimpleDAO, SimpleInterface, SimpleQueryHorse,
  Model.Produto;

type
  TFormMain = class(TForm)
    btnFind: TButton;
    btnInsert: TButton;
    procedure btnFindClick(Sender: TObject);
    procedure btnInsertClick(Sender: TObject);
  private
    FDAO: iSimpleDAO<TProduto>;
  public
    procedure AfterConstruction; override;
  end;

implementation

{$R *.dfm}

procedure TFormMain.AfterConstruction;
begin
  inherited;
  // Only difference from direct DB usage: use TSimpleQueryHorse instead of TSimpleQueryFiredac
  FDAO := TSimpleDAO<TProduto>.New(
    TSimpleQueryHorse.New('http://localhost:9000', 'my-token')
  );
end;

procedure TFormMain.btnFindClick(Sender: TObject);
var
  LList: TObjectList<TProduto>;
begin
  LList := TObjectList<TProduto>.Create;
  try
    FDAO.Find(LList);
    // Use LList...
  finally
    LList.Free;
  end;
end;

procedure TFormMain.btnInsertClick(Sender: TObject);
var
  LProduto: TProduto;
begin
  LProduto := TProduto.Create;
  try
    LProduto.Nome := 'Novo Produto';
    LProduto.Preco := 29.90;
    FDAO.Insert(LProduto);
  finally
    LProduto.Free;
  end;
end;

end.
```

**Step 2: Commit**

```bash
git add samples/horse-integration/
git commit -m "feat: add Horse integration client sample"
```

---

### Task 10: Atualizar CHANGELOG.md

**Files:**
- Modify: `CHANGELOG.md`

**Step 1: Adicionar entrada na seção [Unreleased]**

```markdown
## [Unreleased]

### Added
- **SimpleSerializer** - Serializador Entity ↔ JSON via RTTI usando atributos `[Campo]`, sem dependências externas
- **SimpleHorseRouter** - Auto-geração de rotas CRUD no Horse a partir de entidades SimpleORM com callbacks opcionais
- **SimpleQueryHorse** - Driver REST cliente que implementa `iSimpleQuery` via HTTP, com suporte a Bearer token e hook `OnBeforeRequest`
- **Sample horse-integration** - Exemplos de servidor e cliente usando a integração Horse
```

**Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: update CHANGELOG with Horse integration features"
```

---

### Task 11: Atualizar CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Adicionar seção sobre integração Horse**

Adicionar informações sobre as novas units e o fluxo servidor/cliente na documentação do projeto.

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with Horse integration info"
```
