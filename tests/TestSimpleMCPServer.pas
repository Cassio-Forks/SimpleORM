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
