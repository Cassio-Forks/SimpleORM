# AI Skills Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Adicionar 7 Skills baseadas em IA ao SimpleORM em `SimpleAISkill.pas`, cobrindo enriquecimento, validacao/moderacao e analise de sentimento via LLM.

**Architecture:** Todas as 7 Skills ficam em `SimpleAISkill.pas` (novo arquivo). Cada Skill implementa `iSimpleSkill`, usa `aContext.AIClient.Complete(prompt)` para LLM, e le/escreve properties via RTTI. Testes usam `TSimpleAIMockClient` com respostas fixas. Exception `ESimpleAIModeration` para Skills que bloqueiam.

**Tech Stack:** Delphi Object Pascal, RTTI (`System.Rtti`), DUnit (`TestFramework`), `TSimpleAIMockClient` (mock de `iSimpleAIClient`)

---

### Task 1: Estrutura base do SimpleAISkill.pas + TSkillAIEnrich

**Files:**
- Create: `src/SimpleAISkill.pas`
- Create: `tests/TestSimpleAISkill.pas`
- Modify: `tests/SimpleORMTests.dpr`
- Modify: `tests/Entities/TestEntities.pas`

**Step 1: Add test entity to TestEntities.pas**

Adicionar antes de `implementation`:

```pascal
  { Entidade para teste de AI Skills }
  [Tabela('ARTIGO')]
  TArtigoTest = class
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
```

**Step 2: Create SimpleAISkill.pas with ESimpleAIModeration + TSkillAIEnrich**

```pascal
unit SimpleAISkill;

interface

uses
  SimpleInterface,
  SimpleAttributes,
  SimpleRTTIHelper,
  SimpleTypes,
  System.SysUtils,
  System.Rtti;

type
  ESimpleAIModeration = class(Exception);

  { AI Skill: TSkillAIEnrich }
  TSkillAIEnrich = class(TInterfacedObject, iSimpleSkill)
  private
    FTargetField: String;
    FPromptTemplate: String;
    FRunAt: TSkillRunAt;
    function ResolveTemplate(aEntity: TObject): String;
  public
    constructor Create(const aTargetField, aPromptTemplate: String;
      aRunAt: TSkillRunAt = srBeforeInsert);
    destructor Destroy; override;
    class function New(const aTargetField, aPromptTemplate: String;
      aRunAt: TSkillRunAt = srBeforeInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;

implementation

{ TSkillAIEnrich }

constructor TSkillAIEnrich.Create(const aTargetField, aPromptTemplate: String;
  aRunAt: TSkillRunAt);
begin
  FTargetField := aTargetField;
  FPromptTemplate := aPromptTemplate;
  FRunAt := aRunAt;
end;

destructor TSkillAIEnrich.Destroy;
begin
  inherited;
end;

class function TSkillAIEnrich.New(const aTargetField, aPromptTemplate: String;
  aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aTargetField, aPromptTemplate, aRunAt);
end;

function TSkillAIEnrich.ResolveTemplate(aEntity: TObject): String;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LResult: String;
begin
  LResult := FPromptTemplate;
  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);
  for LProp in LType.GetProperties do
  begin
    if Pos('{' + LProp.Name + '}', LResult) > 0 then
      LResult := StringReplace(LResult, '{' + LProp.Name + '}',
        LProp.GetValue(aEntity).AsVariant, [rfReplaceAll]);
  end;
  Result := LResult;
end;

function TSkillAIEnrich.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LPrompt: String;
  LResponse: String;
begin
  Result := Self;
  if (aEntity = nil) or (aContext.AIClient = nil) then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);
  LProp := LType.GetProperty(FTargetField);
  if LProp = nil then
    Exit;

  LPrompt := ResolveTemplate(aEntity);
  LResponse := aContext.AIClient.Complete(LPrompt);
  LProp.SetValue(aEntity, TValue.From<String>(LResponse));
end;

function TSkillAIEnrich.Name: String;
begin
  Result := 'ai-enrich';
end;

function TSkillAIEnrich.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;

end.
```

**Step 3: Create TestSimpleAISkill.pas with TSkillAIEnrich tests**

```pascal
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
```

**Step 4: Register in SimpleORMTests.dpr**

Adicionar na uses clause:

```pascal
  SimpleAISkill in '..\src\SimpleAISkill.pas',
  TestSimpleAISkill in 'TestSimpleAISkill.pas',
```

**Step 5: Commit**

```bash
git add src/SimpleAISkill.pas tests/TestSimpleAISkill.pas tests/SimpleORMTests.dpr tests/Entities/TestEntities.pas
git commit -m "feat: add SimpleAISkill.pas with TSkillAIEnrich and ESimpleAIModeration"
```

---

### Task 2: TSkillAITranslate

**Files:**
- Modify: `src/SimpleAISkill.pas`
- Modify: `tests/TestSimpleAISkill.pas`

**Step 1: Add TSkillAITranslate declaration to SimpleAISkill.pas**

Na secao `type`, apos TSkillAIEnrich:

```pascal
  { AI Skill: TSkillAITranslate }
  TSkillAITranslate = class(TInterfacedObject, iSimpleSkill)
  private
    FSourceField: String;
    FTargetField: String;
    FTargetLanguage: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aSourceField, aTargetField, aTargetLanguage: String;
      aRunAt: TSkillRunAt = srBeforeInsert);
    destructor Destroy; override;
    class function New(const aSourceField, aTargetField, aTargetLanguage: String;
      aRunAt: TSkillRunAt = srBeforeInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

**Step 2: Add implementation**

```pascal
{ TSkillAITranslate }

constructor TSkillAITranslate.Create(const aSourceField, aTargetField, aTargetLanguage: String;
  aRunAt: TSkillRunAt);
begin
  FSourceField := aSourceField;
  FTargetField := aTargetField;
  FTargetLanguage := aTargetLanguage;
  FRunAt := aRunAt;
end;

destructor TSkillAITranslate.Destroy;
begin
  inherited;
end;

class function TSkillAITranslate.New(const aSourceField, aTargetField, aTargetLanguage: String;
  aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aSourceField, aTargetField, aTargetLanguage, aRunAt);
end;

function TSkillAITranslate.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LSourceProp, LTargetProp: TRttiProperty;
  LSourceText: String;
  LPrompt: String;
  LResponse: String;
begin
  Result := Self;
  if (aEntity = nil) or (aContext.AIClient = nil) then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);

  LSourceProp := LType.GetProperty(FSourceField);
  LTargetProp := LType.GetProperty(FTargetField);
  if (LSourceProp = nil) or (LTargetProp = nil) then
    Exit;

  LSourceText := LSourceProp.GetValue(aEntity).AsString;
  if LSourceText = '' then
    Exit;

  LPrompt := 'Translate the following text to ' + FTargetLanguage +
    '. Return only the translation, nothing else.' + sLineBreak + sLineBreak +
    'Text: ' + LSourceText;

  LResponse := aContext.AIClient.Complete(LPrompt);
  LTargetProp.SetValue(aEntity, TValue.From<String>(LResponse));
end;

function TSkillAITranslate.Name: String;
begin
  Result := 'ai-translate';
end;

function TSkillAITranslate.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;
```

**Step 3: Add tests**

```pascal
  TTestSkillAITranslate = class(TTestCase)
  published
    procedure TestTranslate_Name;
    procedure TestTranslate_RunAt;
    procedure TestTranslate_TranslatesField;
    procedure TestTranslate_EmptySource_NoAction;
    procedure TestTranslate_NilAIClient_NoError;
    procedure TestTranslate_NilEntity_NoError;
  end;
```

```pascal
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
```

Registration: `RegisterTest('AISkills', TTestSkillAITranslate.Suite);`

**Step 4: Commit**

```bash
git add src/SimpleAISkill.pas tests/TestSimpleAISkill.pas
git commit -m "feat: add TSkillAITranslate AI skill"
```

---

### Task 3: TSkillAISummarize

**Files:**
- Modify: `src/SimpleAISkill.pas`
- Modify: `tests/TestSimpleAISkill.pas`

**Step 1: Add TSkillAISummarize declaration**

```pascal
  { AI Skill: TSkillAISummarize }
  TSkillAISummarize = class(TInterfacedObject, iSimpleSkill)
  private
    FSourceField: String;
    FTargetField: String;
    FMaxLength: Integer;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aSourceField, aTargetField: String;
      aMaxLength: Integer = 0; aRunAt: TSkillRunAt = srBeforeInsert);
    destructor Destroy; override;
    class function New(const aSourceField, aTargetField: String;
      aMaxLength: Integer = 0; aRunAt: TSkillRunAt = srBeforeInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

**Step 2: Add implementation**

```pascal
{ TSkillAISummarize }

constructor TSkillAISummarize.Create(const aSourceField, aTargetField: String;
  aMaxLength: Integer; aRunAt: TSkillRunAt);
begin
  FSourceField := aSourceField;
  FTargetField := aTargetField;
  FMaxLength := aMaxLength;
  FRunAt := aRunAt;
end;

destructor TSkillAISummarize.Destroy;
begin
  inherited;
end;

class function TSkillAISummarize.New(const aSourceField, aTargetField: String;
  aMaxLength: Integer; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aSourceField, aTargetField, aMaxLength, aRunAt);
end;

function TSkillAISummarize.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LSourceProp, LTargetProp: TRttiProperty;
  LSourceText: String;
  LPrompt: String;
  LResponse: String;
begin
  Result := Self;
  if (aEntity = nil) or (aContext.AIClient = nil) then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);

  LSourceProp := LType.GetProperty(FSourceField);
  LTargetProp := LType.GetProperty(FTargetField);
  if (LSourceProp = nil) or (LTargetProp = nil) then
    Exit;

  LSourceText := LSourceProp.GetValue(aEntity).AsString;
  if LSourceText = '' then
    Exit;

  if FMaxLength > 0 then
    LPrompt := 'Summarize the following text in at most ' + IntToStr(FMaxLength) +
      ' characters. Return only the summary, nothing else.' + sLineBreak + sLineBreak +
      'Text: ' + LSourceText
  else
    LPrompt := 'Summarize the following text. Return only the summary, nothing else.' +
      sLineBreak + sLineBreak + 'Text: ' + LSourceText;

  LResponse := aContext.AIClient.Complete(LPrompt);
  LTargetProp.SetValue(aEntity, TValue.From<String>(LResponse));
end;

function TSkillAISummarize.Name: String;
begin
  Result := 'ai-summarize';
end;

function TSkillAISummarize.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;
```

**Step 3: Add tests**

```pascal
  TTestSkillAISummarize = class(TTestCase)
  published
    procedure TestSummarize_Name;
    procedure TestSummarize_RunAt;
    procedure TestSummarize_SummarizesField;
    procedure TestSummarize_WithMaxLength_IncludesInPrompt;
    procedure TestSummarize_EmptySource_NoAction;
    procedure TestSummarize_NilAIClient_NoError;
  end;
```

```pascal
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
```

Registration: `RegisterTest('AISkills', TTestSkillAISummarize.Suite);`

**Step 4: Commit**

```bash
git add src/SimpleAISkill.pas tests/TestSimpleAISkill.pas
git commit -m "feat: add TSkillAISummarize AI skill"
```

---

### Task 4: TSkillAITags

**Files:**
- Modify: `src/SimpleAISkill.pas`
- Modify: `tests/TestSimpleAISkill.pas`

**Step 1: Add TSkillAITags declaration**

```pascal
  { AI Skill: TSkillAITags }
  TSkillAITags = class(TInterfacedObject, iSimpleSkill)
  private
    FSourceField: String;
    FTargetField: String;
    FMaxTags: Integer;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aSourceField, aTargetField: String;
      aMaxTags: Integer = 5; aRunAt: TSkillRunAt = srBeforeInsert);
    destructor Destroy; override;
    class function New(const aSourceField, aTargetField: String;
      aMaxTags: Integer = 5; aRunAt: TSkillRunAt = srBeforeInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

**Step 2: Add implementation**

```pascal
{ TSkillAITags }

constructor TSkillAITags.Create(const aSourceField, aTargetField: String;
  aMaxTags: Integer; aRunAt: TSkillRunAt);
begin
  FSourceField := aSourceField;
  FTargetField := aTargetField;
  FMaxTags := aMaxTags;
  FRunAt := aRunAt;
end;

destructor TSkillAITags.Destroy;
begin
  inherited;
end;

class function TSkillAITags.New(const aSourceField, aTargetField: String;
  aMaxTags: Integer; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aSourceField, aTargetField, aMaxTags, aRunAt);
end;

function TSkillAITags.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LSourceProp, LTargetProp: TRttiProperty;
  LSourceText: String;
  LPrompt: String;
  LResponse: String;
begin
  Result := Self;
  if (aEntity = nil) or (aContext.AIClient = nil) then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);

  LSourceProp := LType.GetProperty(FSourceField);
  LTargetProp := LType.GetProperty(FTargetField);
  if (LSourceProp = nil) or (LTargetProp = nil) then
    Exit;

  LSourceText := LSourceProp.GetValue(aEntity).AsString;
  if LSourceText = '' then
    Exit;

  LPrompt := 'Extract at most ' + IntToStr(FMaxTags) +
    ' keywords from the following text. Return only the keywords separated by commas, nothing else.' +
    sLineBreak + sLineBreak + 'Text: ' + LSourceText;

  LResponse := aContext.AIClient.Complete(LPrompt);
  LTargetProp.SetValue(aEntity, TValue.From<String>(LResponse));
end;

function TSkillAITags.Name: String;
begin
  Result := 'ai-tags';
end;

function TSkillAITags.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;
```

**Step 3: Add tests**

```pascal
  TTestSkillAITags = class(TTestCase)
  published
    procedure TestTags_Name;
    procedure TestTags_RunAt;
    procedure TestTags_GeneratesTags;
    procedure TestTags_IncludesMaxTagsInPrompt;
    procedure TestTags_EmptySource_NoAction;
    procedure TestTags_NilAIClient_NoError;
  end;
```

```pascal
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
```

Registration: `RegisterTest('AISkills', TTestSkillAITags.Suite);`

**Step 4: Commit**

```bash
git add src/SimpleAISkill.pas tests/TestSimpleAISkill.pas
git commit -m "feat: add TSkillAITags AI skill"
```

---

### Task 5: TSkillAIModerate

**Files:**
- Modify: `src/SimpleAISkill.pas`
- Modify: `tests/TestSimpleAISkill.pas`

**Step 1: Add TSkillAIModerate declaration**

```pascal
  { AI Skill: TSkillAIModerate }
  TSkillAIModerate = class(TInterfacedObject, iSimpleSkill)
  private
    FField: String;
    FPolicy: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aField: String;
      const aPolicy: String = ''; aRunAt: TSkillRunAt = srBeforeInsert);
    destructor Destroy; override;
    class function New(const aField: String;
      const aPolicy: String = ''; aRunAt: TSkillRunAt = srBeforeInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

**Step 2: Add implementation**

```pascal
{ TSkillAIModerate }

constructor TSkillAIModerate.Create(const aField: String;
  const aPolicy: String; aRunAt: TSkillRunAt);
begin
  FField := aField;
  FPolicy := aPolicy;
  FRunAt := aRunAt;
end;

destructor TSkillAIModerate.Destroy;
begin
  inherited;
end;

class function TSkillAIModerate.New(const aField: String;
  const aPolicy: String; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aField, aPolicy, aRunAt);
end;

function TSkillAIModerate.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LContent: String;
  LPrompt: String;
  LResponse: String;
begin
  Result := Self;
  if aContext.AIClient = nil then
    raise ESimpleAIModeration.Create('AIClient is required for content moderation');

  if aEntity = nil then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);
  LProp := LType.GetProperty(FField);
  if LProp = nil then
    Exit;

  LContent := LProp.GetValue(aEntity).AsString;
  if LContent = '' then
    Exit;

  if FPolicy <> '' then
    LPrompt := 'Analyze the following content and determine if it violates this policy: ' +
      FPolicy + sLineBreak + sLineBreak +
      'Content: ' + LContent + sLineBreak + sLineBreak +
      'Respond with exactly APPROVED if the content is acceptable, or REJECTED: reason if it violates the policy.'
  else
    LPrompt := 'Analyze the following content for offensive, inappropriate, or harmful material.' +
      sLineBreak + sLineBreak +
      'Content: ' + LContent + sLineBreak + sLineBreak +
      'Respond with exactly APPROVED if the content is acceptable, or REJECTED: reason if it contains problematic content.';

  LResponse := aContext.AIClient.Complete(LPrompt);

  if LResponse.StartsWith('REJECTED') then
  begin
    if Pos(':', LResponse) > 0 then
      raise ESimpleAIModeration.Create(Trim(Copy(LResponse, Pos(':', LResponse) + 1, MaxInt)))
    else
      raise ESimpleAIModeration.Create('Content rejected by moderation');
  end;
end;

function TSkillAIModerate.Name: String;
begin
  Result := 'ai-moderate';
end;

function TSkillAIModerate.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;
```

**Step 3: Add tests**

```pascal
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
```

```pascal
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
```

Registration: `RegisterTest('AISkills', TTestSkillAIModerate.Suite);`

**Step 4: Commit**

```bash
git add src/SimpleAISkill.pas tests/TestSimpleAISkill.pas
git commit -m "feat: add TSkillAIModerate AI skill"
```

---

### Task 6: TSkillAIValidate + TSkillAISentiment

**Files:**
- Modify: `src/SimpleAISkill.pas`
- Modify: `tests/TestSimpleAISkill.pas`

**Step 1: Add TSkillAIValidate declaration**

```pascal
  { AI Skill: TSkillAIValidate }
  TSkillAIValidate = class(TInterfacedObject, iSimpleSkill)
  private
    FRule: String;
    FErrorMessage: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aRule: String;
      const aErrorMessage: String = ''; aRunAt: TSkillRunAt = srBeforeInsert);
    destructor Destroy; override;
    class function New(const aRule: String;
      const aErrorMessage: String = ''; aRunAt: TSkillRunAt = srBeforeInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

**Step 2: Add TSkillAIValidate implementation**

```pascal
{ TSkillAIValidate }

constructor TSkillAIValidate.Create(const aRule: String;
  const aErrorMessage: String; aRunAt: TSkillRunAt);
begin
  FRule := aRule;
  FErrorMessage := aErrorMessage;
  FRunAt := aRunAt;
end;

destructor TSkillAIValidate.Destroy;
begin
  inherited;
end;

class function TSkillAIValidate.New(const aRule: String;
  const aErrorMessage: String; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aRule, aErrorMessage, aRunAt);
end;

function TSkillAIValidate.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LRttiContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LEntityData: String;
  LPrompt: String;
  LResponse: String;
begin
  Result := Self;
  if aContext.AIClient = nil then
    raise ESimpleAIModeration.Create('AIClient is required for AI validation');

  if aEntity = nil then
    Exit;

  LRttiContext := TRttiContext.Create;
  LType := LRttiContext.GetType(aEntity.ClassType);

  LEntityData := '';
  for LProp in LType.GetProperties do
  begin
    if LProp.IsIgnore then
      Continue;
    if not LProp.EhCampo then
      Continue;
    LEntityData := LEntityData + LProp.FieldName + ' = ' +
      LProp.GetValue(aEntity).AsVariant + sLineBreak;
  end;

  LPrompt := 'Validate the following entity data against this rule: ' + FRule +
    sLineBreak + sLineBreak + 'Entity data:' + sLineBreak + LEntityData + sLineBreak +
    'Respond with exactly VALID if the data satisfies the rule, or INVALID: reason if it does not.';

  LResponse := aContext.AIClient.Complete(LPrompt);

  if LResponse.StartsWith('INVALID') then
  begin
    if FErrorMessage <> '' then
      raise ESimpleAIModeration.Create(FErrorMessage)
    else if Pos(':', LResponse) > 0 then
      raise ESimpleAIModeration.Create(Trim(Copy(LResponse, Pos(':', LResponse) + 1, MaxInt)))
    else
      raise ESimpleAIModeration.Create('AI validation failed');
  end;
end;

function TSkillAIValidate.Name: String;
begin
  Result := 'ai-validate';
end;

function TSkillAIValidate.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;
```

**Step 3: Add TSkillAISentiment declaration**

```pascal
  { AI Skill: TSkillAISentiment }
  TSkillAISentiment = class(TInterfacedObject, iSimpleSkill)
  private
    FSourceField: String;
    FTargetField: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aSourceField, aTargetField: String;
      aRunAt: TSkillRunAt = srBeforeInsert);
    destructor Destroy; override;
    class function New(const aSourceField, aTargetField: String;
      aRunAt: TSkillRunAt = srBeforeInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;
```

**Step 4: Add TSkillAISentiment implementation**

```pascal
{ TSkillAISentiment }

constructor TSkillAISentiment.Create(const aSourceField, aTargetField: String;
  aRunAt: TSkillRunAt);
begin
  FSourceField := aSourceField;
  FTargetField := aTargetField;
  FRunAt := aRunAt;
end;

destructor TSkillAISentiment.Destroy;
begin
  inherited;
end;

class function TSkillAISentiment.New(const aSourceField, aTargetField: String;
  aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aSourceField, aTargetField, aRunAt);
end;

function TSkillAISentiment.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LSourceProp, LTargetProp: TRttiProperty;
  LSourceText: String;
  LPrompt: String;
  LResponse: String;
begin
  Result := Self;
  if (aEntity = nil) or (aContext.AIClient = nil) then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);

  LSourceProp := LType.GetProperty(FSourceField);
  LTargetProp := LType.GetProperty(FTargetField);
  if (LSourceProp = nil) or (LTargetProp = nil) then
    Exit;

  LSourceText := LSourceProp.GetValue(aEntity).AsString;
  if LSourceText = '' then
    Exit;

  LPrompt := 'Analyze the sentiment of the following text. ' +
    'Respond with exactly one word: POSITIVO, NEGATIVO, or NEUTRO.' +
    sLineBreak + sLineBreak + 'Text: ' + LSourceText;

  LResponse := aContext.AIClient.Complete(LPrompt);
  LTargetProp.SetValue(aEntity, TValue.From<String>(LResponse));
end;

function TSkillAISentiment.Name: String;
begin
  Result := 'ai-sentiment';
end;

function TSkillAISentiment.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;
```

**Step 5: Add tests for both**

```pascal
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
```

```pascal
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
```

Registration:
```pascal
  RegisterTest('AISkills', TTestSkillAIValidate.Suite);
  RegisterTest('AISkills', TTestSkillAISentiment.Suite);
```

**Step 6: Commit**

```bash
git add src/SimpleAISkill.pas tests/TestSimpleAISkill.pas
git commit -m "feat: add TSkillAIValidate and TSkillAISentiment AI skills"
```

---

### Task 7: Sample Project

**Files:**
- Create: `samples/AISkills/SimpleORMAISkills.dpr`
- Create: `samples/AISkills/README.md`

**Step 1: Create sample .dpr**

Console app demonstrating all 7 AI Skills with mock client (nao requer API key real):

```pascal
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
```

**Step 2: Create README.md**

```markdown
# SimpleORM - AI Skills Sample

Demonstracao das 7 Skills baseadas em IA do SimpleORM.

## Como executar

1. Abra `SimpleORMAISkills.dpr` no Delphi
2. Compile e execute (F9)

## O que demonstra

Este sample usa um mock de IA para demonstrar todas as Skills sem precisar de API key.

### Skills de Enriquecimento
- **TSkillAIEnrich** - Gera conteudo com prompt template (`{TITULO}`)
- **TSkillAITranslate** - Traduz campo para outro idioma
- **TSkillAISummarize** - Resume texto longo
- **TSkillAITags** - Gera keywords/tags automaticas

### Skills de Validacao/Moderacao
- **TSkillAIModerate** - Verifica conteudo ofensivo (bloqueia se detectar)
- **TSkillAIValidate** - Valida dados com regra em linguagem natural (bloqueia se falhar)

### Skills de Analise
- **TSkillAISentiment** - Analisa sentimento (POSITIVO/NEGATIVO/NEUTRO)

## Em producao

Substitua o mock por `TSimpleAIClient`:

```pascal
LAI := TSimpleAIClient.New('claude', 'sua-api-key');
// ou
LAI := TSimpleAIClient.New('openai', 'sua-api-key');
```
```

**Step 3: Commit**

```bash
git add samples/AISkills/SimpleORMAISkills.dpr samples/AISkills/README.md
git commit -m "feat: add AI skills sample project"
```

---

### Task 8: Documentation and CHANGELOG

**Files:**
- Modify: `docs/index.html`
- Modify: `docs/en/index.html`
- Modify: `CHANGELOG.md`

**Step 1: Update CHANGELOG.md**

Add entries under `[Unreleased]` > `### Added`:

```markdown
- **SimpleAISkill.pas** - Nova unit com 7 Skills baseadas em IA
- **TSkillAIEnrich** - Skill AI para gerar conteudo via prompt template com `{PropertyName}` (`SimpleAISkill.pas`)
- **TSkillAITranslate** - Skill AI para traducao automatica entre campos (`SimpleAISkill.pas`)
- **TSkillAISummarize** - Skill AI para resumo automatico de texto (`SimpleAISkill.pas`)
- **TSkillAITags** - Skill AI para geracao automatica de tags/keywords (`SimpleAISkill.pas`)
- **TSkillAIModerate** - Skill AI para moderacao de conteudo com bloqueio (`SimpleAISkill.pas`)
- **TSkillAIValidate** - Skill AI para validacao de dados com regra em linguagem natural (`SimpleAISkill.pas`)
- **TSkillAISentiment** - Skill AI para analise de sentimento (POSITIVO/NEGATIVO/NEUTRO) (`SimpleAISkill.pas`)
- **ESimpleAIModeration** - Exception para bloqueio por moderacao/validacao AI (`SimpleAISkill.pas`)
- **Sample AISkills** - Projeto demonstrando as 7 Skills AI com mock client (`samples/AISkills/`)
```

**Step 2: Update Portuguese documentation (docs/index.html)**

Add nav link `<li><a href="#ai-skills">Skills AI</a> <span class="badge badge-new">NEW</span></li>` and new section `#ai-skills` after `#erp-skills` with:
- Tabela de referencia das 7 Skills AI (nome, tipo, comportamento sem AIClient, RunAt default)
- Exemplos de codigo para cada
- Nota sobre `ESimpleAIModeration`

**Step 3: Update English documentation (docs/en/index.html)**

Same content in English.

**Step 4: Commit**

```bash
git add docs/index.html docs/en/index.html CHANGELOG.md
git commit -m "docs: add AI skills documentation and changelog"
```
