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
