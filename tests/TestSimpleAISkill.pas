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

  TTestSkillAITags = class(TTestCase)
  published
    procedure TestTags_Name;
    procedure TestTags_RunAt;
    procedure TestTags_GeneratesTags;
    procedure TestTags_IncludesMaxTagsInPrompt;
    procedure TestTags_EmptySource_NoAction;
    procedure TestTags_NilAIClient_NoError;
  end;

  TTestSkillAIModerate = class(TTestCase)
  published
    procedure TestModerate_Name;
    procedure TestModerate_RunAt;
    procedure TestModerate_Approved_NoError;
    procedure TestModerate_Rejected_RaisesException;
    procedure TestModerate_NilAIClient_RaisesException;
    procedure TestModerate_EmptyField_NoAction;
    procedure TestModerate_NilEntity_NoError;
    procedure TestModerate_WithPolicy_IncludesInPrompt;
  end;

  TTestSkillAIValidate = class(TTestCase)
  published
    procedure TestAIValidate_Name;
    procedure TestAIValidate_RunAt;
    procedure TestAIValidate_Valid_NoError;
    procedure TestAIValidate_Invalid_RaisesException;
    procedure TestAIValidate_Invalid_CustomMessage;
    procedure TestAIValidate_NilAIClient_RaisesException;
    procedure TestAIValidate_NilEntity_NoError;
    procedure TestAIValidate_IncludesEntityDataInPrompt;
  end;

  TTestSkillAISentiment = class(TTestCase)
  published
    procedure TestSentiment_Name;
    procedure TestSentiment_RunAt;
    procedure TestSentiment_SetsSentiment;
    procedure TestSentiment_EmptySource_NoAction;
    procedure TestSentiment_NilAIClient_NoError;
    procedure TestSentiment_NilEntity_NoError;
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

{ TTestSkillAITags }

procedure TTestSkillAITags.TestTags_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillAITags.New('TEXTO', 'TAGS');
  CheckEquals('ai-tags', LSkill.Name, 'Should return ai-tags');
end;

procedure TTestSkillAITags.TestTags_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillAITags.New('TEXTO', 'TAGS', 5, srBeforeUpdate);
  CheckTrue(LSkill.RunAt = srBeforeUpdate, 'Should return configured RunAt');
end;

procedure TTestSkillAITags.TestTags_GeneratesTags;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := 'Artigo sobre Delphi ORM e banco de dados';
    LSkill := TSkillAITags.New('TEXTO', 'TAGS', 3);
    LContext := TSimpleSkillContext.New(nil,
      TSimpleAIMockClient.New('delphi,orm,database'), nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals('delphi,orm,database', LEntity.TAGS, 'Should set tags from AI');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAITags.TestTags_IncludesMaxTagsInPrompt;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
  LMock: TSimpleAIMockClient;
  LAIClient: iSimpleAIClient;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := 'Texto de teste';
    LMock := TSimpleAIMockClient.Create('tag1,tag2');
    LAIClient := LMock;
    LSkill := TSkillAITags.New('TEXTO', 'TAGS', 7);
    LContext := TSimpleSkillContext.New(nil, LAIClient, nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(Pos('7', LMock.LastPrompt) > 0,
      'Prompt should contain max tags count: ' + LMock.LastPrompt);
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAITags.TestTags_EmptySource_NoAction;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := '';
    LSkill := TSkillAITags.New('TEXTO', 'TAGS');
    LContext := TSimpleSkillContext.New(nil,
      TSimpleAIMockClient.New('should not appear'), nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals('', LEntity.TAGS, 'Should not generate tags for empty source');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAITags.TestTags_NilAIClient_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := 'Texto';
    LSkill := TSkillAITags.New('TEXTO', 'TAGS');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals('', LEntity.TAGS, 'Should ignore when AIClient is nil');
  finally
    LEntity.Free;
  end;
end;

{ TTestSkillAIModerate }

procedure TTestSkillAIModerate.TestModerate_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillAIModerate.New('TEXTO');
  CheckEquals('ai-moderate', LSkill.Name, 'Should return ai-moderate');
end;

procedure TTestSkillAIModerate.TestModerate_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillAIModerate.New('TEXTO', '', srBeforeUpdate);
  CheckTrue(LSkill.RunAt = srBeforeUpdate, 'Should return configured RunAt');
end;

procedure TTestSkillAIModerate.TestModerate_Approved_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := 'Conteudo normal e aceitavel';
    LSkill := TSkillAIModerate.New('TEXTO');
    LContext := TSimpleSkillContext.New(nil,
      TSimpleAIMockClient.New('APPROVED'), nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'APPROVED should not raise exception');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAIModerate.TestModerate_Rejected_RaisesException;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
  LRaised: Boolean;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := 'Conteudo ofensivo';
    LSkill := TSkillAIModerate.New('TEXTO');
    LContext := TSimpleSkillContext.New(nil,
      TSimpleAIMockClient.New('REJECTED: conteudo inapropriado'), nil, 'ARTIGO', 'INSERT');
    LRaised := False;
    try
      LSkill.Execute(LEntity, LContext);
    except
      on E: ESimpleAIModeration do
      begin
        LRaised := True;
        CheckTrue(Pos('inapropriado', E.Message) > 0,
          'Should contain rejection reason: ' + E.Message);
      end;
    end;
    CheckTrue(LRaised, 'REJECTED should raise ESimpleAIModeration');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAIModerate.TestModerate_NilAIClient_RaisesException;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LRaised: Boolean;
begin
  LSkill := TSkillAIModerate.New('TEXTO');
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'ARTIGO', 'INSERT');
  LRaised := False;
  try
    LSkill.Execute(nil, LContext);
  except
    on E: ESimpleAIModeration do
      LRaised := True;
  end;
  CheckTrue(LRaised, 'Nil AIClient should raise ESimpleAIModeration');
end;

procedure TTestSkillAIModerate.TestModerate_EmptyField_NoAction;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := '';
    LSkill := TSkillAIModerate.New('TEXTO');
    LContext := TSimpleSkillContext.New(nil,
      TSimpleAIMockClient.New('REJECTED: should not check'), nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Empty field should skip moderation');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAIModerate.TestModerate_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillAIModerate.New('TEXTO');
  LContext := TSimpleSkillContext.New(nil,
    TSimpleAIMockClient.New('APPROVED'), nil, 'ARTIGO', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Nil entity should not raise error');
end;

procedure TTestSkillAIModerate.TestModerate_WithPolicy_IncludesInPrompt;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
  LMock: TSimpleAIMockClient;
  LAIClient: iSimpleAIClient;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := 'Conteudo para moderar';
    LMock := TSimpleAIMockClient.Create('APPROVED');
    LAIClient := LMock;
    LSkill := TSkillAIModerate.New('TEXTO', 'Sem spam ou propaganda');
    LContext := TSimpleSkillContext.New(nil, LAIClient, nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(Pos('Sem spam ou propaganda', LMock.LastPrompt) > 0,
      'Prompt should contain policy: ' + LMock.LastPrompt);
  finally
    LEntity.Free;
  end;
end;

{ TTestSkillAIValidate }

procedure TTestSkillAIValidate.TestAIValidate_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillAIValidate.New('Preco deve ser positivo');
  CheckEquals('ai-validate', LSkill.Name, 'Should return ai-validate');
end;

procedure TTestSkillAIValidate.TestAIValidate_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillAIValidate.New('Regra', '', srBeforeUpdate);
  CheckTrue(LSkill.RunAt = srBeforeUpdate, 'Should return configured RunAt');
end;

procedure TTestSkillAIValidate.TestAIValidate_Valid_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TProdutoTest;
begin
  LEntity := TProdutoTest.Create;
  try
    LEntity.NOME := 'Notebook';
    LEntity.PRECO := 5000;
    LSkill := TSkillAIValidate.New('Preco deve ser positivo');
    LContext := TSimpleSkillContext.New(nil,
      TSimpleAIMockClient.New('VALID'), nil, 'PRODUTO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'VALID should not raise exception');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAIValidate.TestAIValidate_Invalid_RaisesException;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TProdutoTest;
  LRaised: Boolean;
begin
  LEntity := TProdutoTest.Create;
  try
    LEntity.NOME := 'Notebook';
    LEntity.PRECO := -10;
    LSkill := TSkillAIValidate.New('Preco deve ser positivo');
    LContext := TSimpleSkillContext.New(nil,
      TSimpleAIMockClient.New('INVALID: preco negativo nao permitido'), nil, 'PRODUTO', 'INSERT');
    LRaised := False;
    try
      LSkill.Execute(LEntity, LContext);
    except
      on E: ESimpleAIModeration do
      begin
        LRaised := True;
        CheckTrue(Pos('negativo', E.Message) > 0,
          'Should contain AI reason: ' + E.Message);
      end;
    end;
    CheckTrue(LRaised, 'INVALID should raise ESimpleAIModeration');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAIValidate.TestAIValidate_Invalid_CustomMessage;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TProdutoTest;
  LRaised: Boolean;
begin
  LEntity := TProdutoTest.Create;
  try
    LEntity.NOME := 'Notebook';
    LEntity.PRECO := -10;
    LSkill := TSkillAIValidate.New('Regra', 'Erro customizado');
    LContext := TSimpleSkillContext.New(nil,
      TSimpleAIMockClient.New('INVALID: razao da IA'), nil, 'PRODUTO', 'INSERT');
    LRaised := False;
    try
      LSkill.Execute(LEntity, LContext);
    except
      on E: ESimpleAIModeration do
      begin
        LRaised := True;
        CheckEquals('Erro customizado', E.Message, 'Should use custom error message');
      end;
    end;
    CheckTrue(LRaised, 'INVALID should raise ESimpleAIModeration');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAIValidate.TestAIValidate_NilAIClient_RaisesException;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LRaised: Boolean;
begin
  LSkill := TSkillAIValidate.New('Regra');
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
  LRaised := False;
  try
    LSkill.Execute(nil, LContext);
  except
    on E: ESimpleAIModeration do
      LRaised := True;
  end;
  CheckTrue(LRaised, 'Nil AIClient should raise ESimpleAIModeration');
end;

procedure TTestSkillAIValidate.TestAIValidate_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillAIValidate.New('Regra');
  LContext := TSimpleSkillContext.New(nil,
    TSimpleAIMockClient.New('VALID'), nil, 'TEST', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Nil entity should not raise error');
end;

procedure TTestSkillAIValidate.TestAIValidate_IncludesEntityDataInPrompt;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TProdutoTest;
  LMock: TSimpleAIMockClient;
  LAIClient: iSimpleAIClient;
begin
  LEntity := TProdutoTest.Create;
  try
    LEntity.NOME := 'Notebook';
    LEntity.PRECO := 5000;
    LMock := TSimpleAIMockClient.Create('VALID');
    LAIClient := LMock;
    LSkill := TSkillAIValidate.New('Verificar preco');
    LContext := TSimpleSkillContext.New(nil, LAIClient, nil, 'PRODUTO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(Pos('Notebook', LMock.LastPrompt) > 0,
      'Prompt should contain entity data: ' + LMock.LastPrompt);
    CheckTrue(Pos('5000', LMock.LastPrompt) > 0,
      'Prompt should contain PRECO value: ' + LMock.LastPrompt);
  finally
    LEntity.Free;
  end;
end;

{ TTestSkillAISentiment }

procedure TTestSkillAISentiment.TestSentiment_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillAISentiment.New('TEXTO', 'SENTIMENTO');
  CheckEquals('ai-sentiment', LSkill.Name, 'Should return ai-sentiment');
end;

procedure TTestSkillAISentiment.TestSentiment_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillAISentiment.New('TEXTO', 'SENTIMENTO', srBeforeUpdate);
  CheckTrue(LSkill.RunAt = srBeforeUpdate, 'Should return configured RunAt');
end;

procedure TTestSkillAISentiment.TestSentiment_SetsSentiment;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := 'Produto excelente, adorei!';
    LSkill := TSkillAISentiment.New('TEXTO', 'SENTIMENTO');
    LContext := TSimpleSkillContext.New(nil,
      TSimpleAIMockClient.New('POSITIVO'), nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals('POSITIVO', LEntity.SENTIMENTO, 'Should set sentiment from AI');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAISentiment.TestSentiment_EmptySource_NoAction;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := '';
    LSkill := TSkillAISentiment.New('TEXTO', 'SENTIMENTO');
    LContext := TSimpleSkillContext.New(nil,
      TSimpleAIMockClient.New('POSITIVO'), nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals('', LEntity.SENTIMENTO, 'Should not analyze empty source');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAISentiment.TestSentiment_NilAIClient_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TArtigoTest;
begin
  LEntity := TArtigoTest.Create;
  try
    LEntity.TEXTO := 'Texto';
    LSkill := TSkillAISentiment.New('TEXTO', 'SENTIMENTO');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ARTIGO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals('', LEntity.SENTIMENTO, 'Should ignore when AIClient is nil');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillAISentiment.TestSentiment_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillAISentiment.New('TEXTO', 'SENTIMENTO');
  LContext := TSimpleSkillContext.New(nil,
    TSimpleAIMockClient.New('POSITIVO'), nil, 'TEST', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Nil entity should not raise error');
end;

initialization
  RegisterTest('AISkills', TTestSkillAIEnrich.Suite);
  RegisterTest('AISkills', TTestSkillAITranslate.Suite);
  RegisterTest('AISkills', TTestSkillAISummarize.Suite);
  RegisterTest('AISkills', TTestSkillAITags.Suite);
  RegisterTest('AISkills', TTestSkillAIModerate.Suite);
  RegisterTest('AISkills', TTestSkillAIValidate.Suite);
  RegisterTest('AISkills', TTestSkillAISentiment.Suite);

end.
