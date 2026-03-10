program SimpleORMAISkills;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  SimpleAttributes in '..\..\src\SimpleAttributes.pas',
  SimpleRTTIHelper in '..\..\src\SimpleRTTIHelper.pas',
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleSkill in '..\..\src\SimpleSkill.pas',
  SimpleAISkill in '..\..\src\SimpleAISkill.pas',
  SimpleLogger in '..\..\src\SimpleLogger.pas',
  SimpleSerializer in '..\..\src\SimpleSerializer.pas',
  SimpleValidator in '..\..\src\SimpleValidator.pas',
  SimpleAIAttributes in '..\..\src\SimpleAIAttributes.pas',
  SimpleAIClient in '..\..\src\SimpleAIClient.pas';

type
  [Tabela('ARTIGO')]
  TArtigo = class
  private
    FID: Integer;
    FTITULO: String;
    FDESCRICAO: String;
    FTEXTO: String;
    FRESUMO: String;
    FTAGS: String;
    FSENTIMENTO: String;
    FTITULO_EN: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('TITULO'), NotNull]
    property TITULO: String read FTITULO write FTITULO;
    [Campo('DESCRICAO')]
    property DESCRICAO: String read FDESCRICAO write FDESCRICAO;
    [Campo('TEXTO')]
    property TEXTO: String read FTEXTO write FTEXTO;
    [Campo('RESUMO')]
    property RESUMO: String read FRESUMO write FRESUMO;
    [Campo('TAGS')]
    property TAGS: String read FTAGS write FTAGS;
    [Campo('SENTIMENTO')]
    property SENTIMENTO: String read FSENTIMENTO write FSENTIMENTO;
    [Campo('TITULO_EN')]
    property TITULO_EN: String read FTITULO_EN write FTITULO_EN;
  end;

{ Mock simples para demonstracao }
type
  TMockAI = class(TInterfacedObject, iSimpleAIClient)
  public
    function Complete(const aPrompt: String): String;
    function Model(const aValue: String): iSimpleAIClient;
    function MaxTokens(aValue: Integer): iSimpleAIClient;
    function Temperature(aValue: Double): iSimpleAIClient;
  end;

function TMockAI.Complete(const aPrompt: String): String;
begin
  if Pos('Translate', aPrompt) > 0 then
    Result := 'Introduction to Delphi ORM'
  else if Pos('Summarize', aPrompt) > 0 then
    Result := 'Artigo sobre como usar SimpleORM em projetos Delphi'
  else if Pos('keywords', aPrompt) > 0 then
    Result := 'delphi,orm,database,pascal,simpleorm'
  else if Pos('sentiment', aPrompt) > 0 then
    Result := 'POSITIVO'
  else if Pos('APPROVED', aPrompt) > 0 then
    Result := 'APPROVED'
  else if Pos('VALID', aPrompt) > 0 then
    Result := 'VALID'
  else
    Result := 'Descricao gerada pela IA para o artigo sobre Delphi ORM';
end;

function TMockAI.Model(const aValue: String): iSimpleAIClient;
begin
  Result := Self;
end;

function TMockAI.MaxTokens(aValue: Integer): iSimpleAIClient;
begin
  Result := Self;
end;

function TMockAI.Temperature(aValue: Double): iSimpleAIClient;
begin
  Result := Self;
end;

var
  LArtigo: TArtigo;
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LAI: iSimpleAIClient;
begin
  try
    Writeln('SimpleORM - AI Skills Demo');
    Writeln('==========================');
    Writeln;
    Writeln('Nota: Este sample usa um mock de IA. Em producao,');
    Writeln('use TSimpleAIClient.New(''claude'', ''sua-api-key'')');
    Writeln;

    LAI := TMockAI.Create;
    LContext := TSimpleSkillContext.New(nil, LAI, nil, 'ARTIGO', 'INSERT');

    LArtigo := TArtigo.Create;
    try
      LArtigo.TITULO := 'Introducao ao Delphi ORM';
      LArtigo.TEXTO := 'O SimpleORM e um framework ORM para Delphi que simplifica operacoes CRUD. ' +
        'Com ele voce mapeia classes para tabelas usando atributos RTTI. ' +
        'Suporta FireDAC, UniDAC, Zeos e Horse.';

      { 1. TSkillAIEnrich }
      Writeln('=== TSkillAIEnrich ===');
      LSkill := TSkillAIEnrich.New('DESCRICAO', 'Gere uma descricao para {TITULO}');
      LSkill.Execute(LArtigo, LContext);
      Writeln('DESCRICAO: ' + LArtigo.DESCRICAO);
      Writeln;

      { 2. TSkillAITranslate }
      Writeln('=== TSkillAITranslate ===');
      LSkill := TSkillAITranslate.New('TITULO', 'TITULO_EN', 'English');
      LSkill.Execute(LArtigo, LContext);
      Writeln('TITULO_EN: ' + LArtigo.TITULO_EN);
      Writeln;

      { 3. TSkillAISummarize }
      Writeln('=== TSkillAISummarize ===');
      LSkill := TSkillAISummarize.New('TEXTO', 'RESUMO', 200);
      LSkill.Execute(LArtigo, LContext);
      Writeln('RESUMO: ' + LArtigo.RESUMO);
      Writeln;

      { 4. TSkillAITags }
      Writeln('=== TSkillAITags ===');
      LSkill := TSkillAITags.New('TEXTO', 'TAGS', 5);
      LSkill.Execute(LArtigo, LContext);
      Writeln('TAGS: ' + LArtigo.TAGS);
      Writeln;

      { 5. TSkillAISentiment }
      Writeln('=== TSkillAISentiment ===');
      LSkill := TSkillAISentiment.New('TEXTO', 'SENTIMENTO');
      LSkill.Execute(LArtigo, LContext);
      Writeln('SENTIMENTO: ' + LArtigo.SENTIMENTO);
      Writeln;

      { 6. TSkillAIModerate }
      Writeln('=== TSkillAIModerate ===');
      LSkill := TSkillAIModerate.New('TEXTO', 'Sem conteudo ofensivo');
      LSkill.Execute(LArtigo, LContext);
      Writeln('Moderacao: APPROVED');
      Writeln;

      { 7. TSkillAIValidate }
      Writeln('=== TSkillAIValidate ===');
      LSkill := TSkillAIValidate.New('Titulo deve ser descritivo');
      LSkill.Execute(LArtigo, LContext);
      Writeln('Validacao AI: VALID');
      Writeln;

    finally
      LArtigo.Free;
    end;

    Writeln('Pressione ENTER para sair...');
    Readln;
  except
    on E: Exception do
    begin
      Writeln('Erro: ', E.Message);
      Readln;
    end;
  end;
end.
