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
