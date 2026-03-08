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
