# SimpleMCPServer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Criar um servidor MCP embutido no SimpleORM que permite AI assistants interagir com o banco de dados via ORM, com permissoes granulares e dois transportes (stdio + HTTP).

**Architecture:** O core (TSimpleMCPServer) processa JSON-RPC 2.0, registra entidades com permissoes, e gera tools MCP automaticamente. Dois transportes plugaveis: stdio (ReadLn/WriteLn) para uso local e HTTP+SSE via Horse para acesso remoto. Cada tool mapeia para operacoes do SimpleDAO/SimpleSQL/SimpleMigration existentes.

**Tech Stack:** Delphi, JSON-RPC 2.0, MCP Protocol 2025-03-26, System.JSON, Horse (HTTP transport), SimpleORM (DAO/Serializer/Migration)

---

## Task 1: SimpleMCPTypes.pas — Types e constantes do protocolo

**Files:**
- Create: `src/SimpleMCPTypes.pas`

### Step 1: Criar a unit de tipos

**File:** `src/SimpleMCPTypes.pas`

```pascal
unit SimpleMCPTypes;

interface

uses
  System.JSON, System.Generics.Collections, System.SysUtils;

type
  TMCPPermission = (mcpRead, mcpInsert, mcpUpdate, mcpDelete, mcpCount, mcpDDL);
  TMCPPermissions = set of TMCPPermission;

  TMCPToolHandler = reference to function(const aArguments: TJSONObject): TJSONObject;

  TMCPTool = record
    Name: String;
    Description: String;
    InputSchema: TJSONObject;
    Handler: TMCPToolHandler;
  end;

  TMCPEntityInfo = record
    TableName: String;
    Permissions: TMCPPermissions;
    Tools: TArray<TMCPTool>;
  end;

  TMCPError = record
    Code: Integer;
    Message: String;
    class function Create(aCode: Integer; const aMessage: String): TMCPError; static;
  end;

const
  MCP_PROTOCOL_VERSION = '2025-03-26';
  MCP_SERVER_NAME = 'SimpleORM MCP Server';
  MCP_SERVER_VERSION = '1.0.0';

  // JSON-RPC error codes
  MCP_PARSE_ERROR = -32700;
  MCP_INVALID_REQUEST = -32600;
  MCP_METHOD_NOT_FOUND = -32601;
  MCP_INVALID_PARAMS = -32602;
  MCP_INTERNAL_ERROR = -32603;
  MCP_UNAUTHORIZED = -32001;

implementation

class function TMCPError.Create(aCode: Integer; const aMessage: String): TMCPError;
begin
  Result.Code := aCode;
  Result.Message := aMessage;
end;

end.
```

### Step 2: Commit

```bash
git add src/SimpleMCPTypes.pas
git commit -m "feat(mcp): add SimpleMCPTypes with MCP protocol types and constants"
```

---

## Task 2: SimpleMCPServer.pas — Core JSON-RPC e registro de entidades

**Files:**
- Create: `src/SimpleMCPServer.pas`

### Step 1: Criar o core do MCP Server

O core e responsavel por: registrar entidades, gerar tools, processar JSON-RPC, e dispatch para handlers.

**File:** `src/SimpleMCPServer.pas`

```pascal
unit SimpleMCPServer;

interface

uses
  System.JSON, System.SysUtils, System.Classes, System.Generics.Collections,
  System.Rtti, System.TypInfo,
  SimpleInterface, SimpleTypes, SimpleMCPTypes;

type
  TSimpleMCPServer = class
  private
    FTools: TDictionary<String, TMCPTool>;
    FEntityInfos: TList<TMCPEntityInfo>;
    FToken: String;
    FInitialized: Boolean;

    function ProcessInitialize(const aId: TJSONValue): TJSONObject;
    function ProcessToolsList(const aId: TJSONValue): TJSONObject;
    function ProcessToolsCall(const aId: TJSONValue; const aParams: TJSONObject): TJSONObject;

    function BuildJsonRpcResponse(const aId: TJSONValue; aResult: TJSONValue): TJSONObject;
    function BuildJsonRpcError(const aId: TJSONValue; aCode: Integer; const aMessage: String): TJSONObject;
    function BuildToolResult(const aText: String; aIsError: Boolean = False): TJSONObject;

    procedure RegisterTool(const aTool: TMCPTool);
  public
    constructor Create;
    destructor Destroy; override;
    class function New: TSimpleMCPServer;

    function RegisterEntity<T: class, constructor>(
      aQuery: iSimpleQuery;
      aPermissions: TMCPPermissions): TSimpleMCPServer;

    function Token(const aValue: String): TSimpleMCPServer;
    function ProcessMessage(const aJSON: String): String;
    function ValidateToken(const aRequestToken: String): Boolean;

    procedure StartStdio;
    procedure StartHttp(aPort: Integer);

    property Tools: TDictionary<String, TMCPTool> read FTools;
    property IsInitialized: Boolean read FInitialized;
  end;

implementation

uses
  SimpleAttributes, SimpleRTTIHelper, SimpleDAO, SimpleRTTI,
  SimpleSerializer, SimpleMigration, SimpleValidator;

{ TSimpleMCPServer }

constructor TSimpleMCPServer.Create;
begin
  FTools := TDictionary<String, TMCPTool>.Create;
  FEntityInfos := TList<TMCPEntityInfo>.Create;
  FToken := '';
  FInitialized := False;
end;

destructor TSimpleMCPServer.Destroy;
begin
  FTools.Free;
  FEntityInfos.Free;
  inherited;
end;

class function TSimpleMCPServer.New: TSimpleMCPServer;
begin
  Result := TSimpleMCPServer.Create;
end;

function TSimpleMCPServer.Token(const aValue: String): TSimpleMCPServer;
begin
  Result := Self;
  FToken := aValue;
end;

function TSimpleMCPServer.ValidateToken(const aRequestToken: String): Boolean;
begin
  if FToken = '' then
    Exit(True);
  Result := FToken = aRequestToken;
end;

procedure TSimpleMCPServer.RegisterTool(const aTool: TMCPTool);
begin
  FTools.AddOrSetValue(LowerCase(aTool.Name), aTool);
end;

function TSimpleMCPServer.RegisterEntity<T>(
  aQuery: iSimpleQuery;
  aPermissions: TMCPPermissions): TSimpleMCPServer;
var
  LCtx: TRttiContext;
  LType: TRttiType;
  LTableName, LPrefix: String;
  LProp: TRttiProperty;
  LEntityInfo: TMCPEntityInfo;
  LTool: TMCPTool;
  LSchema: TJSONObject;
  LProps: TJSONObject;
  LRequired: TJSONArray;
  LFieldName, LFieldType: String;
begin
  Result := Self;

  LCtx := TRttiContext.Create;
  try
    LType := LCtx.GetType(TypeInfo(T));
    LTableName := LType.GetAttribute<Tabela>.Name;
    LPrefix := LowerCase(LTableName);

    LEntityInfo.TableName := LTableName;
    LEntityInfo.Permissions := aPermissions;

    // --- Tool: describe ---
    if mcpRead in aPermissions then
    begin
      LTool.Name := LPrefix + '_describe';
      LTool.Description := 'Describe the schema of ' + LTableName + ' entity (fields, types, constraints)';
      LTool.InputSchema := TJSONObject.Create;
      LTool.InputSchema.AddPair('type', 'object');
      LTool.InputSchema.AddPair('properties', TJSONObject.Create);
      LTool.Handler :=
        function(const aArguments: TJSONObject): TJSONObject
        var
          LDescCtx: TRttiContext;
          LDescType: TRttiType;
          LDescProp: TRttiProperty;
          LFields: TJSONArray;
          LField: TJSONObject;
        begin
          LDescCtx := TRttiContext.Create;
          try
            LDescType := LDescCtx.GetType(TypeInfo(T));
            LFields := TJSONArray.Create;
            for LDescProp in LDescType.GetProperties do
            begin
              if LDescProp.IsIgnore then Continue;
              if not LDescProp.EhCampo then Continue;
              LField := TJSONObject.Create;
              LField.AddPair('name', LDescProp.FieldName);
              LField.AddPair('property', LDescProp.Name);
              case LDescProp.PropertyType.TypeKind of
                tkInteger: LField.AddPair('type', 'integer');
                tkInt64: LField.AddPair('type', 'int64');
                tkFloat: LField.AddPair('type', 'float');
                tkEnumeration: LField.AddPair('type', 'boolean');
              else
                LField.AddPair('type', 'string');
              end;
              if LDescProp.EhChavePrimaria then LField.AddPair('pk', TJSONTrue.Create);
              if LDescProp.IsAutoInc then LField.AddPair('autoInc', TJSONTrue.Create);
              if LDescProp.IsNotNull then LField.AddPair('notNull', TJSONTrue.Create);
              LFields.AddElement(LField);
            end;
            Result := BuildToolResult(LFields.ToJSON);
            LFields.Free;
          finally
            LDescCtx.Free;
          end;
        end;
      RegisterTool(LTool);
    end;

    // --- Tool: query ---
    if mcpRead in aPermissions then
    begin
      LTool.Name := LPrefix + '_query';
      LTool.Description := 'Query ' + LTableName + ' records with optional where, orderBy, skip, take';
      LSchema := TJSONObject.Create;
      LSchema.AddPair('type', 'object');
      LProps := TJSONObject.Create;
      LProps.AddPair('where', TJSONObject.Create
        .AddPair('type', 'string')
        .AddPair('description', 'SQL WHERE clause (without WHERE keyword). Use :param syntax for parameters.'));
      LProps.AddPair('orderBy', TJSONObject.Create
        .AddPair('type', 'string')
        .AddPair('description', 'ORDER BY clause (e.g. "NAME ASC")'));
      LProps.AddPair('skip', TJSONObject.Create
        .AddPair('type', 'integer')
        .AddPair('description', 'Number of records to skip'));
      LProps.AddPair('take', TJSONObject.Create
        .AddPair('type', 'integer')
        .AddPair('description', 'Maximum number of records to return'));
      LSchema.AddPair('properties', LProps);
      LTool.InputSchema := LSchema;
      LTool.Handler :=
        function(const aArguments: TJSONObject): TJSONObject
        var
          LDAO: iSimpleDAO<T>;
          LList: TObjectList<T>;
          LJSONArray: TJSONArray;
          LWhere, LOrderBy: String;
          LSkip, LTake: Integer;
        begin
          LDAO := TSimpleDAO<T>.New(aQuery);
          LList := TObjectList<T>.Create;
          try
            if (aArguments <> nil) and (aArguments.FindValue('where') <> nil) then
            begin
              LWhere := aArguments.GetValue<String>('where', '');
              if LWhere <> '' then
                LDAO.SQL.Where(LWhere);
            end;
            if (aArguments <> nil) and (aArguments.FindValue('orderBy') <> nil) then
            begin
              LOrderBy := aArguments.GetValue<String>('orderBy', '');
              if LOrderBy <> '' then
                LDAO.SQL.OrderBy(LOrderBy);
            end;
            if (aArguments <> nil) and (aArguments.FindValue('skip') <> nil) then
            begin
              LSkip := aArguments.GetValue<Integer>('skip', 0);
              if LSkip > 0 then
                LDAO.SQL.Skip(LSkip);
            end;
            if (aArguments <> nil) and (aArguments.FindValue('take') <> nil) then
            begin
              LTake := aArguments.GetValue<Integer>('take', 0);
              if LTake > 0 then
                LDAO.SQL.Take(LTake);
            end;
            LDAO.SQL.&End.Find(LList);
            LJSONArray := TSimpleSerializer.EntityListToJSONArray<T>(LList);
            try
              Result := BuildToolResult(LJSONArray.ToJSON);
            finally
              LJSONArray.Free;
            end;
          finally
            LList.Free;
          end;
        end;
      RegisterTool(LTool);
    end;

    // --- Tool: get (by ID) ---
    if mcpRead in aPermissions then
    begin
      LTool.Name := LPrefix + '_get';
      LTool.Description := 'Get a single ' + LTableName + ' record by ID';
      LSchema := TJSONObject.Create;
      LSchema.AddPair('type', 'object');
      LProps := TJSONObject.Create;
      LProps.AddPair('id', TJSONObject.Create
        .AddPair('type', 'integer')
        .AddPair('description', 'Primary key value'));
      LSchema.AddPair('properties', LProps);
      LRequired := TJSONArray.Create;
      LRequired.Add('id');
      LSchema.AddPair('required', LRequired);
      LTool.InputSchema := LSchema;
      LTool.Handler :=
        function(const aArguments: TJSONObject): TJSONObject
        var
          LDAO: iSimpleDAO<T>;
          LEntity: T;
          LEntityJSON: TJSONObject;
          LId: Integer;
        begin
          LId := aArguments.GetValue<Integer>('id', 0);
          if LId = 0 then
            Exit(BuildToolResult('Error: id is required', True));

          LDAO := TSimpleDAO<T>.New(aQuery);
          LEntity := LDAO.Find(LId);
          try
            LEntityJSON := TSimpleSerializer.EntityToJSON<T>(LEntity);
            try
              Result := BuildToolResult(LEntityJSON.ToJSON);
            finally
              LEntityJSON.Free;
            end;
          finally
            TObject(LEntity).Free;
          end;
        end;
      RegisterTool(LTool);
    end;

    // --- Tool: insert ---
    if mcpInsert in aPermissions then
    begin
      LTool.Name := LPrefix + '_insert';
      LTool.Description := 'Insert a new ' + LTableName + ' record';
      LSchema := TJSONObject.Create;
      LSchema.AddPair('type', 'object');
      LProps := TJSONObject.Create;
      LProps.AddPair('data', TJSONObject.Create
        .AddPair('type', 'object')
        .AddPair('description', 'JSON object with field values to insert'));
      LSchema.AddPair('properties', LProps);
      LRequired := TJSONArray.Create;
      LRequired.Add('data');
      LSchema.AddPair('required', LRequired);
      LTool.InputSchema := LSchema;
      LTool.Handler :=
        function(const aArguments: TJSONObject): TJSONObject
        var
          LDAO: iSimpleDAO<T>;
          LEntity: T;
          LData: TJSONObject;
          LEntityJSON: TJSONObject;
        begin
          LData := aArguments.GetValue<TJSONObject>('data', nil);
          if LData = nil then
            Exit(BuildToolResult('Error: data object is required', True));

          LEntity := TSimpleSerializer.JSONToEntity<T>(LData);
          try
            try
              TSimpleValidator.Validate(TObject(LEntity));
            except
              on E: Exception do
                Exit(BuildToolResult('Validation error: ' + E.Message, True));
            end;

            LDAO := TSimpleDAO<T>.New(aQuery);
            LDAO.Insert(LEntity);

            LEntityJSON := TSimpleSerializer.EntityToJSON<T>(LEntity);
            try
              Result := BuildToolResult(LEntityJSON.ToJSON);
            finally
              LEntityJSON.Free;
            end;
          finally
            TObject(LEntity).Free;
          end;
        end;
      RegisterTool(LTool);
    end;

    // --- Tool: update ---
    if mcpUpdate in aPermissions then
    begin
      LTool.Name := LPrefix + '_update';
      LTool.Description := 'Update an existing ' + LTableName + ' record';
      LSchema := TJSONObject.Create;
      LSchema.AddPair('type', 'object');
      LProps := TJSONObject.Create;
      LProps.AddPair('data', TJSONObject.Create
        .AddPair('type', 'object')
        .AddPair('description', 'JSON object with field values to update (must include PK)'));
      LSchema.AddPair('properties', LProps);
      LRequired := TJSONArray.Create;
      LRequired.Add('data');
      LSchema.AddPair('required', LRequired);
      LTool.InputSchema := LSchema;
      LTool.Handler :=
        function(const aArguments: TJSONObject): TJSONObject
        var
          LDAO: iSimpleDAO<T>;
          LEntity: T;
          LData: TJSONObject;
          LEntityJSON: TJSONObject;
        begin
          LData := aArguments.GetValue<TJSONObject>('data', nil);
          if LData = nil then
            Exit(BuildToolResult('Error: data object is required', True));

          LEntity := TSimpleSerializer.JSONToEntity<T>(LData);
          try
            try
              TSimpleValidator.Validate(TObject(LEntity));
            except
              on E: Exception do
                Exit(BuildToolResult('Validation error: ' + E.Message, True));
            end;

            LDAO := TSimpleDAO<T>.New(aQuery);
            LDAO.Update(LEntity);

            LEntityJSON := TSimpleSerializer.EntityToJSON<T>(LEntity);
            try
              Result := BuildToolResult(LEntityJSON.ToJSON);
            finally
              LEntityJSON.Free;
            end;
          finally
            TObject(LEntity).Free;
          end;
        end;
      RegisterTool(LTool);
    end;

    // --- Tool: delete ---
    if mcpDelete in aPermissions then
    begin
      LTool.Name := LPrefix + '_delete';
      LTool.Description := 'Delete a ' + LTableName + ' record by ID';
      LSchema := TJSONObject.Create;
      LSchema.AddPair('type', 'object');
      LProps := TJSONObject.Create;
      LProps.AddPair('id', TJSONObject.Create
        .AddPair('type', 'string')
        .AddPair('description', 'Primary key value of the record to delete'));
      LSchema.AddPair('properties', LProps);
      LRequired := TJSONArray.Create;
      LRequired.Add('id');
      LSchema.AddPair('required', LRequired);
      LTool.InputSchema := LSchema;
      LTool.Handler :=
        function(const aArguments: TJSONObject): TJSONObject
        var
          LDAO: iSimpleDAO<T>;
          LId, LPK: String;
        begin
          LId := aArguments.GetValue<String>('id', '');
          if LId = '' then
            Exit(BuildToolResult('Error: id is required', True));

          TSimpleRTTI<T>.New(nil).PrimaryKey(LPK);
          LDAO := TSimpleDAO<T>.New(aQuery);
          LDAO.Delete(LPK, LId);
          Result := BuildToolResult('Deleted ' + LTableName + ' with id ' + LId);
        end;
      RegisterTool(LTool);
    end;

    // --- Tool: count ---
    if mcpCount in aPermissions then
    begin
      LTool.Name := LPrefix + '_count';
      LTool.Description := 'Count ' + LTableName + ' records with optional where clause';
      LSchema := TJSONObject.Create;
      LSchema.AddPair('type', 'object');
      LProps := TJSONObject.Create;
      LProps.AddPair('where', TJSONObject.Create
        .AddPair('type', 'string')
        .AddPair('description', 'Optional WHERE clause'));
      LSchema.AddPair('properties', LProps);
      LTool.InputSchema := LSchema;
      LTool.Handler :=
        function(const aArguments: TJSONObject): TJSONObject
        var
          LDAO: iSimpleDAO<T>;
          LWhere: String;
          LCount: Integer;
        begin
          LDAO := TSimpleDAO<T>.New(aQuery);
          if (aArguments <> nil) and (aArguments.FindValue('where') <> nil) then
          begin
            LWhere := aArguments.GetValue<String>('where', '');
            if LWhere <> '' then
              LDAO.SQL.Where(LWhere).&End;
          end;
          LCount := LDAO.Count;
          Result := BuildToolResult(IntToStr(LCount));
        end;
      RegisterTool(LTool);
    end;

    // --- Tool: ddl ---
    if mcpDDL in aPermissions then
    begin
      LTool.Name := LPrefix + '_ddl';
      LTool.Description := 'Generate CREATE TABLE DDL for ' + LTableName;
      LTool.InputSchema := TJSONObject.Create;
      LTool.InputSchema.AddPair('type', 'object');
      LTool.InputSchema.AddPair('properties', TJSONObject.Create);
      LTool.Handler :=
        function(const aArguments: TJSONObject): TJSONObject
        var
          LDDL: String;
        begin
          LDDL := TSimpleMigration.GenerateCreateTable<T>(aQuery.SQLType);
          Result := BuildToolResult(LDDL);
        end;
      RegisterTool(LTool);
    end;

    FEntityInfos.Add(LEntityInfo);
  finally
    LCtx.Free;
  end;
end;

// --- JSON-RPC Processing ---

function TSimpleMCPServer.ProcessMessage(const aJSON: String): String;
var
  LJSONValue: TJSONValue;
  LRequest: TJSONObject;
  LMethod: String;
  LId: TJSONValue;
  LParams: TJSONObject;
  LResponse: TJSONObject;
begin
  LJSONValue := TJSONObject.ParseJSONValue(aJSON);
  if LJSONValue = nil then
  begin
    LResponse := BuildJsonRpcError(nil, MCP_PARSE_ERROR, 'Parse error');
    try
      Result := LResponse.ToJSON;
    finally
      LResponse.Free;
    end;
    Exit;
  end;

  try
    if not (LJSONValue is TJSONObject) then
    begin
      LResponse := BuildJsonRpcError(nil, MCP_INVALID_REQUEST, 'Invalid request');
      try
        Result := LResponse.ToJSON;
      finally
        LResponse.Free;
      end;
      Exit;
    end;

    LRequest := LJSONValue as TJSONObject;
    LMethod := LRequest.GetValue<String>('method', '');
    LId := LRequest.FindValue('id');
    LParams := LRequest.GetValue<TJSONObject>('params', nil);

    // Notifications (no id) — just acknowledge
    if (LId = nil) then
    begin
      // notifications/initialized — no response needed
      Result := '';
      Exit;
    end;

    if LMethod = 'initialize' then
    begin
      LResponse := ProcessInitialize(LId);
      FInitialized := True;
    end
    else if LMethod = 'tools/list' then
      LResponse := ProcessToolsList(LId)
    else if LMethod = 'tools/call' then
      LResponse := ProcessToolsCall(LId, LParams)
    else if LMethod = 'ping' then
      LResponse := BuildJsonRpcResponse(LId, TJSONObject.Create)
    else
      LResponse := BuildJsonRpcError(LId, MCP_METHOD_NOT_FOUND, 'Method not found: ' + LMethod);

    try
      Result := LResponse.ToJSON;
    finally
      LResponse.Free;
    end;
  finally
    LJSONValue.Free;
  end;
end;

function TSimpleMCPServer.ProcessInitialize(const aId: TJSONValue): TJSONObject;
var
  LResult: TJSONObject;
  LCapabilities: TJSONObject;
  LServerInfo: TJSONObject;
begin
  LResult := TJSONObject.Create;
  LResult.AddPair('protocolVersion', MCP_PROTOCOL_VERSION);

  LCapabilities := TJSONObject.Create;
  LCapabilities.AddPair('tools', TJSONObject.Create);
  LResult.AddPair('capabilities', LCapabilities);

  LServerInfo := TJSONObject.Create;
  LServerInfo.AddPair('name', MCP_SERVER_NAME);
  LServerInfo.AddPair('version', MCP_SERVER_VERSION);
  LResult.AddPair('serverInfo', LServerInfo);

  Result := BuildJsonRpcResponse(aId, LResult);
end;

function TSimpleMCPServer.ProcessToolsList(const aId: TJSONValue): TJSONObject;
var
  LResult: TJSONObject;
  LToolsArray: TJSONArray;
  LToolObj: TJSONObject;
  LTool: TMCPTool;
  LPair: TPair<String, TMCPTool>;
begin
  LToolsArray := TJSONArray.Create;

  for LPair in FTools do
  begin
    LTool := LPair.Value;
    LToolObj := TJSONObject.Create;
    LToolObj.AddPair('name', LTool.Name);
    LToolObj.AddPair('description', LTool.Description);
    if Assigned(LTool.InputSchema) then
      LToolObj.AddPair('inputSchema', LTool.InputSchema.Clone as TJSONObject)
    else
      LToolObj.AddPair('inputSchema', TJSONObject.Create.AddPair('type', 'object'));
    LToolsArray.AddElement(LToolObj);
  end;

  LResult := TJSONObject.Create;
  LResult.AddPair('tools', LToolsArray);
  Result := BuildJsonRpcResponse(aId, LResult);
end;

function TSimpleMCPServer.ProcessToolsCall(const aId: TJSONValue; const aParams: TJSONObject): TJSONObject;
var
  LToolName: String;
  LArguments: TJSONObject;
  LTool: TMCPTool;
  LToolResult: TJSONObject;
begin
  if aParams = nil then
    Exit(BuildJsonRpcError(aId, MCP_INVALID_PARAMS, 'Missing params'));

  LToolName := LowerCase(aParams.GetValue<String>('name', ''));
  if LToolName = '' then
    Exit(BuildJsonRpcError(aId, MCP_INVALID_PARAMS, 'Missing tool name'));

  if not FTools.TryGetValue(LToolName, LTool) then
    Exit(BuildJsonRpcError(aId, MCP_INVALID_PARAMS, 'Unknown tool: ' + LToolName));

  LArguments := aParams.GetValue<TJSONObject>('arguments', nil);

  try
    LToolResult := LTool.Handler(LArguments);
    Result := BuildJsonRpcResponse(aId, LToolResult);
  except
    on E: Exception do
      Result := BuildJsonRpcResponse(aId, BuildToolResult('Error: ' + E.Message, True));
  end;
end;

// --- Helpers ---

function TSimpleMCPServer.BuildJsonRpcResponse(const aId: TJSONValue; aResult: TJSONValue): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('jsonrpc', '2.0');
  if aId <> nil then
    Result.AddPair('id', aId.Clone as TJSONValue)
  else
    Result.AddPair('id', TJSONNull.Create);
  Result.AddPair('result', aResult);
end;

function TSimpleMCPServer.BuildJsonRpcError(const aId: TJSONValue; aCode: Integer; const aMessage: String): TJSONObject;
var
  LError: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('jsonrpc', '2.0');
  if aId <> nil then
    Result.AddPair('id', aId.Clone as TJSONValue)
  else
    Result.AddPair('id', TJSONNull.Create);
  LError := TJSONObject.Create;
  LError.AddPair('code', TJSONNumber.Create(aCode));
  LError.AddPair('message', aMessage);
  Result.AddPair('error', LError);
end;

function TSimpleMCPServer.BuildToolResult(const aText: String; aIsError: Boolean): TJSONObject;
var
  LContent: TJSONArray;
  LItem: TJSONObject;
begin
  Result := TJSONObject.Create;
  LContent := TJSONArray.Create;
  LItem := TJSONObject.Create;
  LItem.AddPair('type', 'text');
  LItem.AddPair('text', aText);
  LContent.AddElement(LItem);
  Result.AddPair('content', LContent);
  if aIsError then
    Result.AddPair('isError', TJSONTrue.Create);
end;

// --- Transport stubs (implemented in separate units) ---

procedure TSimpleMCPServer.StartStdio;
begin
  // Implemented in SimpleMCPTransport.Stdio.pas helper
  raise Exception.Create('Call SimpleMCPTransport.Stdio.RunStdioLoop(Self) instead');
end;

procedure TSimpleMCPServer.StartHttp(aPort: Integer);
begin
  // Implemented in SimpleMCPTransport.Http.pas helper
  raise Exception.Create('Call SimpleMCPTransport.Http.StartHttpTransport(Self, aPort) instead');
end;

end.
```

### Step 2: Commit

```bash
git add src/SimpleMCPServer.pas
git commit -m "feat(mcp): add SimpleMCPServer core with JSON-RPC processing and entity registration"
```

---

## Task 3: Global tools — list_entities e raw_query

**Files:**
- Modify: `src/SimpleMCPServer.pas`

### Step 1: Adicionar tools globais no constructor

No `constructor Create`, apos inicializar FTools e FEntityInfos, registrar as duas tools globais:

```pascal
// Em Create, apos FInitialized := False:

// Tool: list_entities
var LListTool: TMCPTool;
LListTool.Name := 'list_entities';
LListTool.Description := 'List all registered entities with their permissions';
LListTool.InputSchema := TJSONObject.Create;
LListTool.InputSchema.AddPair('type', 'object');
LListTool.InputSchema.AddPair('properties', TJSONObject.Create);
LListTool.Handler :=
  function(const aArguments: TJSONObject): TJSONObject
  var
    LArray: TJSONArray;
    LInfo: TMCPEntityInfo;
    LObj: TJSONObject;
    LPerms: TJSONArray;
    LPerm: TMCPPermission;
  begin
    LArray := TJSONArray.Create;
    for LInfo in FEntityInfos do
    begin
      LObj := TJSONObject.Create;
      LObj.AddPair('table', LInfo.TableName);
      LPerms := TJSONArray.Create;
      for LPerm in LInfo.Permissions do
        LPerms.Add(GetEnumName(TypeInfo(TMCPPermission), Ord(LPerm)));
      LObj.AddPair('permissions', LPerms);
      LArray.AddElement(LObj);
    end;
    Result := BuildToolResult(LArray.ToJSON);
    LArray.Free;
  end;
RegisterTool(LListTool);
```

### Step 2: Adicionar raw_query tool

Tambem no constructor, ou como metodo separado `EnableRawQuery(aQuery: iSimpleQuery)`:

```pascal
function TSimpleMCPServer.EnableRawQuery(aQuery: iSimpleQuery): TSimpleMCPServer;
var
  LTool: TMCPTool;
  LSchema, LProps: TJSONObject;
  LRequired: TJSONArray;
begin
  Result := Self;
  LTool.Name := 'raw_query';
  LTool.Description := 'Execute a read-only SQL query (SELECT only) and return results as JSON';
  LSchema := TJSONObject.Create;
  LSchema.AddPair('type', 'object');
  LProps := TJSONObject.Create;
  LProps.AddPair('sql', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'SQL SELECT query to execute'));
  LSchema.AddPair('properties', LProps);
  LRequired := TJSONArray.Create;
  LRequired.Add('sql');
  LSchema.AddPair('required', LRequired);
  LTool.InputSchema := LSchema;
  LTool.Handler :=
    function(const aArguments: TJSONObject): TJSONObject
    var
      LSQL: String;
      LSQLUpper: String;
      LField: TField;
      LRow: TJSONObject;
      LRows: TJSONArray;
    begin
      LSQL := aArguments.GetValue<String>('sql', '');
      if LSQL = '' then
        Exit(BuildToolResult('Error: sql is required', True));

      // Security: only allow SELECT
      LSQLUpper := UpperCase(Trim(LSQL));
      if not LSQLUpper.StartsWith('SELECT') then
        Exit(BuildToolResult('Error: only SELECT queries are allowed', True));

      // Block dangerous keywords even in subqueries
      if LSQLUpper.Contains('INSERT ') or LSQLUpper.Contains('UPDATE ') or
         LSQLUpper.Contains('DELETE ') or LSQLUpper.Contains('DROP ') or
         LSQLUpper.Contains('ALTER ') or LSQLUpper.Contains('CREATE ') or
         LSQLUpper.Contains('TRUNCATE ') then
        Exit(BuildToolResult('Error: only SELECT queries are allowed', True));

      try
        aQuery.SQL.Clear;
        aQuery.SQL.Add(LSQL);
        aQuery.Open;

        LRows := TJSONArray.Create;
        try
          aQuery.DataSet.First;
          while not aQuery.DataSet.Eof do
          begin
            LRow := TJSONObject.Create;
            for LField in aQuery.DataSet.Fields do
            begin
              if LField.IsNull then
                LRow.AddPair(LField.FieldName, TJSONNull.Create)
              else
                LRow.AddPair(LField.FieldName, LField.AsString);
            end;
            LRows.AddElement(LRow);
            aQuery.DataSet.Next;
          end;
          Result := BuildToolResult(LRows.ToJSON);
        finally
          LRows.Free;
        end;
      except
        on E: Exception do
          Result := BuildToolResult('Query error: ' + E.Message, True);
      end;
    end;
  RegisterTool(LTool);
end;
```

Adicionar `EnableRawQuery` na declaracao publica da classe e na interface.

### Step 3: Commit

```bash
git add src/SimpleMCPServer.pas
git commit -m "feat(mcp): add list_entities and raw_query global tools"
```

---

## Task 4: SimpleMCPTransport.Stdio.pas — Transporte stdio

**Files:**
- Create: `src/SimpleMCPTransport.Stdio.pas`

### Step 1: Implementar o loop stdio

```pascal
unit SimpleMCPTransport.Stdio;

interface

uses
  SimpleMCPServer;

procedure RunStdioLoop(aServer: TSimpleMCPServer);

implementation

uses
  System.SysUtils;

procedure RunStdioLoop(aServer: TSimpleMCPServer);
var
  LLine: String;
  LResponse: String;
begin
  while not Eof(Input) do
  begin
    ReadLn(LLine);
    LLine := Trim(LLine);
    if LLine = '' then
      Continue;

    LResponse := aServer.ProcessMessage(LLine);

    // Notifications return empty string — no response needed
    if LResponse <> '' then
      WriteLn(LResponse);
  end;
end;

end.
```

### Step 2: Atualizar StartStdio no SimpleMCPServer.pas

Mudar `StartStdio` para usar o transporte diretamente:

```pascal
procedure TSimpleMCPServer.StartStdio;
begin
  SimpleMCPTransport.Stdio.RunStdioLoop(Self);
end;
```

Adicionar `SimpleMCPTransport.Stdio` ao uses da implementation.

### Step 3: Commit

```bash
git add src/SimpleMCPTransport.Stdio.pas src/SimpleMCPServer.pas
git commit -m "feat(mcp): add stdio transport for local MCP communication"
```

---

## Task 5: SimpleMCPTransport.Http.pas — Transporte HTTP via Horse

**Files:**
- Create: `src/SimpleMCPTransport.Http.pas`

### Step 1: Implementar transporte HTTP

```pascal
unit SimpleMCPTransport.Http;

interface

uses
  SimpleMCPServer;

procedure StartHttpTransport(aServer: TSimpleMCPServer; aPort: Integer; const aPath: String = '/mcp');

implementation

uses
  System.SysUtils, System.JSON, System.Classes,
  Horse, SimpleMCPTypes;

procedure StartHttpTransport(aServer: TSimpleMCPServer; aPort: Integer; const aPath: String);
begin
  THorse.Post(aPath,
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LBody: String;
      LResponse: String;
      LAuthHeader: String;
      LToken: String;
    begin
      // Check authentication
      LAuthHeader := Req.Headers['Authorization'];
      if LAuthHeader.StartsWith('Bearer ', True) then
        LToken := Copy(LAuthHeader, 8, MaxInt)
      else
        LToken := '';

      if not aServer.ValidateToken(LToken) then
      begin
        Res.Send('{"jsonrpc":"2.0","id":null,"error":{"code":-32001,"message":"Unauthorized"}}')
          .Status(401);
        Exit;
      end;

      LBody := Req.Body;
      if LBody = '' then
      begin
        Res.Send('{"jsonrpc":"2.0","id":null,"error":{"code":-32700,"message":"Empty body"}}')
          .Status(400);
        Exit;
      end;

      LResponse := aServer.ProcessMessage(LBody);

      if LResponse = '' then
        Res.Status(202)
      else
        Res.Send(LResponse).ContentType('application/json').Status(200);
    end
  );

  THorse.Listen(aPort);
end;

end.
```

### Step 2: Atualizar StartHttp no SimpleMCPServer.pas

```pascal
procedure TSimpleMCPServer.StartHttp(aPort: Integer);
begin
  SimpleMCPTransport.Http.StartHttpTransport(Self, aPort);
end;
```

Adicionar `SimpleMCPTransport.Http` ao uses da implementation.

### Step 3: Commit

```bash
git add src/SimpleMCPTransport.Http.pas src/SimpleMCPServer.pas
git commit -m "feat(mcp): add HTTP transport via Horse with Bearer token authentication"
```

---

## Task 6: Sample — Console MCP Server (stdio)

**Files:**
- Create: `samples/MCPServer/MCPServerStdio.dpr`
- Create: `samples/MCPServer/README.md`

### Step 1: Criar sample stdio

**File:** `samples/MCPServer/MCPServerStdio.dpr`

```pascal
program MCPServerStdio;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  SimpleMCPServer in '..\..\src\SimpleMCPServer.pas',
  SimpleMCPTypes in '..\..\src\SimpleMCPTypes.pas',
  SimpleMCPTransport.Stdio in '..\..\src\SimpleMCPTransport.Stdio.pas',
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleDAO in '..\..\src\SimpleDAO.pas',
  SimpleRTTI in '..\..\src\SimpleRTTI.pas',
  SimpleSQL in '..\..\src\SimpleSQL.pas',
  SimpleAttributes in '..\..\src\SimpleAttributes.pas',
  SimpleRTTIHelper in '..\..\src\SimpleRTTIHelper.pas',
  SimpleSerializer in '..\..\src\SimpleSerializer.pas',
  SimpleMigration in '..\..\src\SimpleMigration.pas',
  SimpleValidator in '..\..\src\SimpleValidator.pas',
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleQueryFiredac in '..\..\src\SimpleQueryFiredac.pas',
  SimpleEntity in '..\..\src\SimpleEntity.pas',
  SimpleDAOSQLAttribute in '..\..\src\SimpleDAOSQLAttribute.pas',
  Entidade.Produto in '..\Entidades\Entidade.Produto.pas',
  Entidade.Cliente in '..\Entidades\Entidade.Cliente.pas';

var
  Server: TSimpleMCPServer;
  // Query: iSimpleQuery; // Configure with your database connection
begin
  try
    Server := TSimpleMCPServer.New;
    try
      // Register entities with permissions
      // Server.RegisterEntity<TProduto>(Query, [mcpRead, mcpInsert, mcpUpdate, mcpDelete, mcpCount, mcpDDL]);
      // Server.RegisterEntity<TCliente>(Query, [mcpRead, mcpCount]);
      // Server.EnableRawQuery(Query);

      // Start stdio transport (reads from stdin, writes to stdout)
      Server.StartStdio;
    finally
      Server.Free;
    end;
  except
    on E: Exception do
    begin
      // Write errors to stderr (not stdout — that's for MCP protocol)
      WriteLn(ErrOutput, 'Error: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
```

### Step 2: Criar README

**File:** `samples/MCPServer/README.md`

```markdown
# SimpleORM MCP Server (stdio)

Servidor MCP que expoe entidades SimpleORM para AI assistants.

## Configuracao no Claude Code

Adicione ao seu `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "minha-app": {
      "command": "C:\\caminho\\para\\MCPServerStdio.exe",
      "args": []
    }
  }
}
```

## Uso

1. Configure a conexao com o banco de dados no .dpr
2. Registre as entidades com permissoes desejadas
3. Compile o projeto no Delphi IDE
4. Configure como MCP server no Claude Code

## Permissoes Disponiveis

- `mcpRead` — Query, Get, Describe
- `mcpInsert` — Insert com validacao
- `mcpUpdate` — Update com validacao
- `mcpDelete` — Delete (respeita soft delete)
- `mcpCount` — Count com where
- `mcpDDL` — Gerar CREATE TABLE
```

### Step 3: Commit

```bash
git add samples/MCPServer/MCPServerStdio.dpr samples/MCPServer/README.md
git commit -m "feat(mcp): add stdio MCP server sample project"
```

---

## Task 7: Sample — HTTP MCP Server (via Horse)

**Files:**
- Create: `samples/MCPServer/MCPServerHttp.dpr`

### Step 1: Criar sample HTTP

**File:** `samples/MCPServer/MCPServerHttp.dpr`

```pascal
program MCPServerHttp;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Horse,
  SimpleMCPServer in '..\..\src\SimpleMCPServer.pas',
  SimpleMCPTypes in '..\..\src\SimpleMCPTypes.pas',
  SimpleMCPTransport.Http in '..\..\src\SimpleMCPTransport.Http.pas',
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleDAO in '..\..\src\SimpleDAO.pas',
  SimpleRTTI in '..\..\src\SimpleRTTI.pas',
  SimpleSQL in '..\..\src\SimpleSQL.pas',
  SimpleAttributes in '..\..\src\SimpleAttributes.pas',
  SimpleRTTIHelper in '..\..\src\SimpleRTTIHelper.pas',
  SimpleSerializer in '..\..\src\SimpleSerializer.pas',
  SimpleMigration in '..\..\src\SimpleMigration.pas',
  SimpleValidator in '..\..\src\SimpleValidator.pas',
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleQueryFiredac in '..\..\src\SimpleQueryFiredac.pas',
  SimpleEntity in '..\..\src\SimpleEntity.pas',
  SimpleDAOSQLAttribute in '..\..\src\SimpleDAOSQLAttribute.pas',
  Entidade.Produto in '..\Entidades\Entidade.Produto.pas',
  Entidade.Cliente in '..\Entidades\Entidade.Cliente.pas';

var
  Server: TSimpleMCPServer;
  // Query: iSimpleQuery; // Configure with your database connection
begin
  try
    Server := TSimpleMCPServer.New;

    // Register entities
    // Server.RegisterEntity<TProduto>(Query, [mcpRead, mcpInsert, mcpUpdate, mcpDelete, mcpCount, mcpDDL]);
    // Server.RegisterEntity<TCliente>(Query, [mcpRead, mcpCount]);
    // Server.EnableRawQuery(Query);

    // Set authentication token for HTTP
    Server.Token('my-secret-token');

    WriteLn('SimpleORM MCP Server starting on port 9000...');
    WriteLn('Endpoint: POST http://localhost:9000/mcp');

    // Start HTTP transport (blocks — runs Horse listener)
    Server.StartHttp(9000);
  except
    on E: Exception do
    begin
      WriteLn('Error: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
```

### Step 2: Commit

```bash
git add samples/MCPServer/MCPServerHttp.dpr
git commit -m "feat(mcp): add HTTP MCP server sample project"
```

---

## Task 8: Testes DUnit

**Files:**
- Create: `tests/TestSimpleMCPServer.pas`
- Modify: `tests/SimpleORMTests.dpr`

### Step 1: Criar testes

**File:** `tests/TestSimpleMCPServer.pas`

```pascal
unit TestSimpleMCPServer;

interface

uses
  TestFramework, System.JSON, System.SysUtils,
  SimpleMCPServer, SimpleMCPTypes;

type
  TTestSimpleMCPServer = class(TTestCase)
  private
    FServer: TSimpleMCPServer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestInitialize_ShouldReturnProtocolVersion;
    procedure TestInitialize_ShouldReturnServerInfo;
    procedure TestToolsList_EmptyServer_ShouldReturnListEntitiesOnly;
    procedure TestToolsCall_UnknownTool_ShouldReturnError;
    procedure TestPing_ShouldReturnEmptyResult;
    procedure TestInvalidJSON_ShouldReturnParseError;
    procedure TestNotification_ShouldReturnEmptyString;
    procedure TestValidateToken_EmptyToken_ShouldAlwaysPass;
    procedure TestValidateToken_WithToken_ShouldRequireMatch;
  end;

implementation

procedure TTestSimpleMCPServer.SetUp;
begin
  FServer := TSimpleMCPServer.New;
end;

procedure TTestSimpleMCPServer.TearDown;
begin
  FServer.Free;
end;

procedure TTestSimpleMCPServer.TestInitialize_ShouldReturnProtocolVersion;
var
  LResponse: String;
  LJSON: TJSONObject;
begin
  LResponse := FServer.ProcessMessage(
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}');
  LJSON := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
  try
    CheckEquals('2025-03-26', LJSON.GetValue('result').FindValue('protocolVersion').Value);
  finally
    LJSON.Free;
  end;
end;

procedure TTestSimpleMCPServer.TestInitialize_ShouldReturnServerInfo;
var
  LResponse: String;
  LJSON: TJSONObject;
begin
  LResponse := FServer.ProcessMessage(
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}');
  LJSON := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
  try
    CheckEquals(MCP_SERVER_NAME, LJSON.GetValue('result').FindValue('serverInfo').FindValue('name').Value);
  finally
    LJSON.Free;
  end;
end;

procedure TTestSimpleMCPServer.TestToolsList_EmptyServer_ShouldReturnListEntitiesOnly;
var
  LResponse: String;
  LJSON: TJSONObject;
  LTools: TJSONArray;
begin
  LResponse := FServer.ProcessMessage(
    '{"jsonrpc":"2.0","id":2,"method":"tools/list"}');
  LJSON := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
  try
    LTools := LJSON.GetValue('result').FindValue('tools') as TJSONArray;
    CheckTrue(LTools.Count >= 1, 'Deve ter pelo menos list_entities');
  finally
    LJSON.Free;
  end;
end;

procedure TTestSimpleMCPServer.TestToolsCall_UnknownTool_ShouldReturnError;
var
  LResponse: String;
  LJSON: TJSONObject;
begin
  LResponse := FServer.ProcessMessage(
    '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"nonexistent","arguments":{}}}');
  LJSON := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
  try
    CheckNotNull(LJSON.FindValue('error'), 'Deve retornar erro');
  finally
    LJSON.Free;
  end;
end;

procedure TTestSimpleMCPServer.TestPing_ShouldReturnEmptyResult;
var
  LResponse: String;
  LJSON: TJSONObject;
begin
  LResponse := FServer.ProcessMessage(
    '{"jsonrpc":"2.0","id":4,"method":"ping"}');
  LJSON := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
  try
    CheckNotNull(LJSON.FindValue('result'), 'Deve retornar result');
  finally
    LJSON.Free;
  end;
end;

procedure TTestSimpleMCPServer.TestInvalidJSON_ShouldReturnParseError;
var
  LResponse: String;
  LJSON: TJSONObject;
begin
  LResponse := FServer.ProcessMessage('not valid json {{{');
  LJSON := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
  try
    CheckEquals(MCP_PARSE_ERROR, LJSON.GetValue('error').FindValue('code').GetValue<Integer>);
  finally
    LJSON.Free;
  end;
end;

procedure TTestSimpleMCPServer.TestNotification_ShouldReturnEmptyString;
var
  LResponse: String;
begin
  LResponse := FServer.ProcessMessage(
    '{"jsonrpc":"2.0","method":"notifications/initialized"}');
  CheckEquals('', LResponse, 'Notifications nao devem gerar resposta');
end;

procedure TTestSimpleMCPServer.TestValidateToken_EmptyToken_ShouldAlwaysPass;
begin
  CheckTrue(FServer.ValidateToken(''), 'Sem token configurado deve aceitar tudo');
  CheckTrue(FServer.ValidateToken('anything'), 'Sem token configurado deve aceitar tudo');
end;

procedure TTestSimpleMCPServer.TestValidateToken_WithToken_ShouldRequireMatch;
begin
  FServer.Token('secret123');
  CheckTrue(FServer.ValidateToken('secret123'), 'Token correto deve passar');
  CheckFalse(FServer.ValidateToken('wrong'), 'Token errado deve falhar');
  CheckFalse(FServer.ValidateToken(''), 'Token vazio deve falhar');
end;

initialization
  RegisterTest('MCP.Server', TTestSimpleMCPServer.Suite);

end.
```

### Step 2: Registrar no test runner

**File:** `tests/SimpleORMTests.dpr` — adicionar ao uses:

```pascal
TestSimpleMCPServer in 'TestSimpleMCPServer.pas',
SimpleMCPServer in '..\src\SimpleMCPServer.pas',
SimpleMCPTypes in '..\src\SimpleMCPTypes.pas',
```

### Step 3: Commit

```bash
git add tests/TestSimpleMCPServer.pas tests/SimpleORMTests.dpr
git commit -m "feat(mcp): add DUnit tests for MCP server core (JSON-RPC, auth, tools)"
```

---

## Resumo da Execucao

| Task | Componente | Complexidade | Arquivos |
|------|-----------|-------------|----------|
| 1 | SimpleMCPTypes.pas | Baixa | 1 novo |
| 2 | SimpleMCPServer.pas (Core) | Alta | 1 novo |
| 3 | Global tools (list_entities, raw_query) | Media | 1 modificado |
| 4 | Transporte Stdio | Baixa | 1 novo + 1 mod |
| 5 | Transporte HTTP | Media | 1 novo + 1 mod |
| 6 | Sample Stdio | Baixa | 2 novos |
| 7 | Sample HTTP | Baixa | 1 novo |
| 8 | Testes DUnit | Media | 1 novo + 1 mod |

**Ordem:** 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8
