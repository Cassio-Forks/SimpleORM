unit TestSimpleAISkill;

interface

uses
  TestFramework,
  System.SysUtils,
  SimpleAISkill,
  SimpleInterface,
  SimpleTypes,
  SimpleSkill;

type
  TTestSkillAIEnrich = class(TTestCase)
  published
    procedure TestEnrich_Name;
    procedure TestEnrich_RunAt;
    procedure TestEnrich_SetsFieldFromAI;
    procedure TestEnrich_ResolvesTemplate;
    procedure TestEnrich_NilEntity_NoError;
    procedure TestEnrich_NilAIClient_NoError;
  end;

  TTestSkillAITranslate = class(TTestCase)
  published
    procedure TestTranslate_Name;
    procedure TestTranslate_RunAt;
    procedure TestTranslate_TranslatesField;
    procedure TestTranslate_EmptySource_NoAction;
    procedure TestTranslate_NilAIClient_NoError;
    procedure TestTranslate_NilEntity_NoError;
  end;

  TTestSkillAISummarize = class(TTestCase)
  published
    procedure TestSummarize_Name;
    procedure TestSummarize_RunAt;
    procedure TestSummarize_SummarizesField;
    procedure TestSummarize_WithMaxLength_IncludesInPrompt;
    procedure TestSummarize_EmptySource_NoAction;
    procedure TestSummarize_NilAIClient_NoError;
  end;

implementation

uses
  TestEntities,
  MockAIClient;

{ TTestSkillAIEnrich }

procedure TTestSkillAIEnrich.TestEnrich_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillAIEnrich.New('DESCRICAO', 'Descreva {TITULO}');
  CheckEquals('ai-enrich', LSkill.Name, 'Should return ai-enrich');
end;

procedure TTestSkillAIEnrich.TestEnrich_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillAIEnrich.New('DESCRICAO', 'Descreva', srBeforeUpdate);
  CheckTrue(LSkill.RunAt = srBeforeUpdate, 'Should return configured RunAt');
end;

procedure TTestSkillAIEnrich.TestEnrich_SetsFieldFromAI;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
  LAIClient: iSimpleAIClient;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TITULO := 'Delphi ORM';
    LAIClient := TSimpleAIMockClient.New('Uma descricao gerada pela IA');
    LSkill := TSkillAIEnrich.New('DESCRICAO', 'Descreva {TITULO}');
    LContext := TSimpleSkillContext.New(nil, LAIClient, nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals('Uma descricao gerada pela IA', LEntity.DESCRICAO, 'Should set AI response');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAIEnrich.TestEnrich_ResolvesTemplate;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
  LMock: TSimpleAIMockClient;
  LAIClient: iSimpleAIClient;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TITULO := 'Meu Artigo';
    LMock := TSimpleAIMockClient.Create('resposta');
    LAIClient := LMock;
    LSkill := TSkillAIEnrich.New('DESCRICAO', 'Gere descricao para {TITULO}');
    LContext := TSimpleSkillContext.New(nil, LAIClient, nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(Pos('Meu Artigo', LMock.LastPrompt) > 0,
      'Template should resolve {TITULO}: ' + LMock.LastPrompt);
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAIEnrich.TestEnrich_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillAIEnrich.New('DESCRICAO', 'Prompt');
  LContext := TSimpleSkillContext.New(nil, TSimpleAIMockClient.New('x'), nil, 'TEST', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Should not raise error for nil entity');
end;

procedure TTestSkillAIEnrich.TestEnrich_NilAIClient_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LSkill := TSkillAIEnrich.New('DESCRICAO', 'Prompt');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals('', LEntity.DESCRICAO, 'Should ignore when AIClient is nil');
  finally
    LEntity.Free;
  end;
end;

{ TTestSkillAITranslate }

procedure TTestSkillAITranslate.TestTranslate_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillAITranslate.New('TITULO', 'TITULO_EN', 'English');
  CheckEquals('ai-translate', LSkill.Name, 'Should return ai-translate');
end;

procedure TTestSkillAITranslate.TestTranslate_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillAITranslate.New('TITULO', 'TITULO_EN', 'English', srBeforeUpdate);
  CheckTrue(LSkill.RunAt = srBeforeUpdate, 'Should return configured RunAt');
end;

procedure TTestSkillAITranslate.TestTranslate_TranslatesField;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TITULO := 'Titulo em Portugues';
    LSkill := TSkillAITranslate.New('TITULO', 'TITULO_EN', 'English');
    LContext := TSimpleSkillContext.New(nil,
      TSimpleAIMockClient.New('Title in English'), nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals('Title in English', LEntity.TITULO_EN, 'Should set translated value');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAITranslate.TestTranslate_EmptySource_NoAction;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TITULO := '';
    LSkill := TSkillAITranslate.New('TITULO', 'TITULO_EN', 'English');
    LContext := TSimpleSkillContext.New(nil,
      TSimpleAIMockClient.New('Should not be called'), nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals('', LEntity.TITULO_EN, 'Should not translate empty source');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAITranslate.TestTranslate_NilAIClient_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TITULO := 'Teste';
    LSkill := TSkillAITranslate.New('TITULO', 'TITULO_EN', 'English');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals('', LEntity.TITULO_EN, 'Should ignore when AIClient is nil');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAITranslate.TestTranslate_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillAITranslate.New('TITULO', 'TITULO_EN', 'English');
  LContext := TSimpleSkillContext.New(nil, TSimpleAIMockClient.New('x'), nil, 'TEST', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Should not raise error for nil entity');
end;

{ TTestSkillAISummarize }

procedure TTestSkillAISummarize.TestSummarize_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillAISummarize.New('TEXTO', 'RESUMO');
  CheckEquals('ai-summarize', LSkill.Name, 'Should return ai-summarize');
end;

procedure TTestSkillAISummarize.TestSummarize_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillAISummarize.New('TEXTO', 'RESUMO', 0, srBeforeUpdate);
  CheckTrue(LSkill.RunAt = srBeforeUpdate, 'Should return configured RunAt');
end;

procedure TTestSkillAISummarize.TestSummarize_SummarizesField;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := 'Um texto muito longo que precisa ser resumido';
    LSkill := TSkillAISummarize.New('TEXTO', 'RESUMO');
    LContext := TSimpleSkillContext.New(nil,
      TSimpleAIMockClient.New('Resumo do texto'), nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals('Resumo do texto', LEntity.RESUMO, 'Should set summary');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAISummarize.TestSummarize_WithMaxLength_IncludesInPrompt;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
  LMock: TSimpleAIMockClient;
  LAIClient: iSimpleAIClient;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := 'Texto para resumir';
    LMock := TSimpleAIMockClient.Create('resumo');
    LAIClient := LMock;
    LSkill := TSkillAISummarize.New('TEXTO', 'RESUMO', 200);
    LContext := TSimpleSkillContext.New(nil, LAIClient, nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(Pos('200', LMock.LastPrompt) > 0,
      'Prompt should contain max length: ' + LMock.LastPrompt);
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAISummarize.TestSummarize_EmptySource_NoAction;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := '';
    LSkill := TSkillAISummarize.New('TEXTO', 'RESUMO');
    LContext := TSimpleSkillContext.New(nil,
      TSimpleAIMockClient.New('should not appear'), nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals('', LEntity.RESUMO, 'Should not summarize empty source');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAISummarize.TestSummarize_NilAIClient_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := 'Texto';
    LSkill := TSkillAISummarize.New('TEXTO', 'RESUMO');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals('', LEntity.RESUMO, 'Should ignore when AIClient is nil');
  finally
    LEntity.Free;
  end;
end;

initialization
  RegisterTest('AISkills', TTestSkillAIEnrich.Suite);
  RegisterTest('AISkills', TTestSkillAITranslate.Suite);
  RegisterTest('AISkills', TTestSkillAISummarize.Suite);

end.
