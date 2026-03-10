program SimpleORM;

uses
  Vcl.Forms,
  SimpleDAO in 'src\SimpleDAO.pas',
  SimpleInterface in 'src\SimpleInterface.pas',
  SimpleAttributes in 'src\SimpleAttributes.pas',
  SimpleRTTI in 'src\SimpleRTTI.pas',
  SimpleSQL in 'src\SimpleSQL.pas',
  SimpleQueryFiredac in 'src\SimpleQueryFiredac.pas',
  SimpleQueryRestDW in 'src\SimpleQueryRestDW.pas',
  SimpleSerializer in 'src\SimpleSerializer.pas',
  SimpleQueryHorse in 'src\SimpleQueryHorse.pas',
  SimpleHorseRouter in 'src\SimpleHorseRouter.pas',
  SimpleQuerySupabase in 'src\SimpleQuerySupabase.pas',
  SimpleSupabaseAuth in 'src\SimpleSupabaseAuth.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := True;
  Application.MainFormOnTaskbar := True;
  Application.Run;
end.
