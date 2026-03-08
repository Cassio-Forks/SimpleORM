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
  SimpleEntity in '..\..\src\SimpleEntity.pas',
  SimpleDAOSQLAttribute in '..\..\src\SimpleDAOSQLAttribute.pas';

var
  Server: TSimpleMCPServer;
  // Query: iSimpleQuery; // Configure with your database connection
begin
  try
    Server := TSimpleMCPServer.New;
    try
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
    finally
      Server.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('Error: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
