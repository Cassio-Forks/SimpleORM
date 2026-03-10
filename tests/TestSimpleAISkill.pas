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

initialization
  RegisterTest('AISkills', TTestSkillAIEnrich.Suite);

end.
