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
  SimpleEntity in '..\..\src\SimpleEntity.pas',
  SimpleDAOSQLAttribute in '..\..\src\SimpleDAOSQLAttribute.pas';

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
