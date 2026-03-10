program SimpleORMGitHubIssue;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  SimpleAttributes in '..\..\src\SimpleAttributes.pas',
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleRTTI in '..\..\src\SimpleRTTI.pas',
  SimpleRTTIHelper in '..\..\src\SimpleRTTIHelper.pas',
  SimpleSQL in '..\..\src\SimpleSQL.pas',
  SimpleSkill in '..\..\src\SimpleSkill.pas',
  SimpleSerializer in '..\..\src\SimpleSerializer.pas',
  SimpleLogger in '..\..\src\SimpleLogger.pas',
  SimpleValidator in '..\..\src\SimpleValidator.pas',
  Entidade.Produto in '..\Entidades\Entidade.Produto.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    Writeln('=== SimpleORM - TSkillGitHubIssue Demo ===');
    Writeln;

    // -------------------------------------------------------
    // IMPORTANTE: Substitua pelos seus dados reais do GitHub
    // -------------------------------------------------------
    // var REPO  := 'seu-usuario/seu-repositorio';
    // var TOKEN := 'ghp_seu_personal_access_token';

    Writeln('1) Modo OnError - Cria Issue quando operacao falha:');
    Writeln;
    Writeln('   LDAO := TSimpleDAO<TProduto>.New(LQuery)');
    Writeln('     .Skill(TSkillGitHubIssue.New(REPO, TOKEN, srAfterInsert, srmOnError))');
    Writeln('     .OnError(procedure(aEntity: TObject; E: Exception)');
    Writeln('       begin');
    Writeln('         Writeln(''Erro capturado: '', E.Message);');
    Writeln('       end);');
    Writeln;

    Writeln('2) Modo Normal com template - Cria Issue em todo Delete (auditoria):');
    Writeln;
    Writeln('   LDAO := TSimpleDAO<TProduto>.New(LQuery)');
    Writeln('     .Skill(TSkillGitHubIssue.New(REPO, TOKEN, srAfterDelete, srmNormal)');
    Writeln('       .Labels([''audit'', ''delete''])');
    Writeln('       .TitleTemplate(''[Audit] {entity} deletado por {operation}''));');
    Writeln;

    Writeln('3) Modo OnError com labels customizadas:');
    Writeln;
    Writeln('   LDAO := TSimpleDAO<TProduto>.New(LQuery)');
    Writeln('     .Skill(TSkillGitHubIssue.New(REPO, TOKEN, srAfterInsert, srmOnError)');
    Writeln('       .Labels([''bug'', ''producao'', ''critico''])');
    Writeln('       .TitleTemplate(''[CRITICO] Falha em {operation} na {entity}'')');
    Writeln('       .BodyTemplate(''Erro: {error}'' + #13#10 + ''Timestamp: {timestamp}''));');
    Writeln;

    Writeln('4) Callback OnError generico (sem GitHub):');
    Writeln;
    Writeln('   LDAO := TSimpleDAO<TProduto>.New(LQuery)');
    Writeln('     .OnError(procedure(aEntity: TObject; E: Exception)');
    Writeln('       begin');
    Writeln('         // Gravar em log, enviar email, notificar Slack, etc.');
    Writeln('         Writeln(''Erro: '', E.Message);');
    Writeln('       end);');
    Writeln;

    Writeln('-------------------------------------------------------');
    Writeln('Placeholders disponiveis em templates:');
    Writeln('  {entity}    - Nome da tabela da entidade');
    Writeln('  {operation}  - INSERT, UPDATE ou DELETE');
    Writeln('  {error}      - Mensagem de erro (vazio em modo Normal)');
    Writeln('  {timestamp}  - Data/hora ISO8601');
    Writeln('-------------------------------------------------------');
    Writeln;
    Writeln('Para testar, substitua REPO e TOKEN com dados reais e');
    Writeln('descomente o codigo acima.');
    Writeln;

  except
    on E: Exception do
      Writeln('Erro: ', E.Message);
  end;

  Writeln('Pressione Enter para sair...');
  Readln;
end.
