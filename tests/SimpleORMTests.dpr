program SimpleORMTests;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  TestFramework,
  TextTestRunner,
  SimpleAttributes in '..\src\SimpleAttributes.pas',
  SimpleTypes in '..\src\SimpleTypes.pas',
  SimpleInterface in '..\src\SimpleInterface.pas',
  SimpleRTTIHelper in '..\src\SimpleRTTIHelper.pas',
  SimpleRTTI in '..\src\SimpleRTTI.pas',
  SimpleSQL in '..\src\SimpleSQL.pas',
  SimpleValidator in '..\src\SimpleValidator.pas',
  SimpleSerializer in '..\src\SimpleSerializer.pas',
  TestEntities in 'Entities\TestEntities.pas',
  TestSimpleAttributes in 'TestSimpleAttributes.pas',
  TestSimpleRTTIHelper in 'TestSimpleRTTIHelper.pas',
  TestSimpleSQL in 'TestSimpleSQL.pas',
  TestSimpleValidator in 'TestSimpleValidator.pas',
  TestSimpleSerializer in 'TestSimpleSerializer.pas',
  SimpleMigration in '..\src\SimpleMigration.pas',
  TestSimpleMigration in 'TestSimpleMigration.pas';

var
  ExitBehavior: TRunnerExitBehavior;
begin
  ReportMemoryLeaksOnShutdown := True;
  ExitBehavior := rxbHaltOnFailures;
  try
    if FindCmdLineSwitch('pause') then
      ExitBehavior := rxbPause;
    TextTestRunner.RunRegisteredTests(ExitBehavior);
  except
    on E: Exception do
    begin
      Writeln('Erro: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
