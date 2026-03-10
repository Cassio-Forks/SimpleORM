# SimpleAI Entity Enrichment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Permitir preenchimento automatico de propriedades de entidades via LLM usando atributos declarativos durante Insert/Update.

**Architecture:** 3 novas units (SimpleAIClient, SimpleAIAttributes, SimpleAIProcessor) que usam RTTI para detectar atributos AI em entidades, montar prompts contextuais, chamar APIs de LLM e preencher propriedades antes da persistencia. Integracao no TSimpleDAO via campo FAIClient opcional.

**Tech Stack:** Delphi, RTTI, System.Net.HttpClient, System.JSON, DUnit

---

### Task 1: SimpleAIClient.pas — Client HTTP para LLMs

**Files:**
- Modify: `src/SimpleInterface.pas`
- Create: `src/SimpleAIClient.pas`

**Step 1: Adicionar interface iSimpleAIClient em SimpleInterface.pas**

Adicionar antes da linha `implementation` em `SimpleInterface.pas`:

```pascal
  iSimpleAIClient = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function Complete(const aPrompt: String): String;
    function Model(const aValue: String): iSimpleAIClient;
    function MaxTokens(aValue: Integer): iSimpleAIClient;
    function Temperature(aValue: Double): iSimpleAIClient;
  end;
```

**Step 2: Criar a unit SimpleAIClient.pas**

```pascal
unit SimpleAIClient;

interface

uses
  SimpleInterface,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient;

type
  TSimpleAIClient = class(TInterfacedObject, iSimpleAIClient)
  private
    FProvider: String;
    FApiKey: String;
    FModel: String;
    FMaxTokens: Integer;
    FTemperature: Double;
    FTimeoutMs: Integer;
    function CompleteClaude(const aPrompt: String): String;
    function CompleteOpenAI(const aPrompt: String): String;
  public
    constructor Create(const aProvider, aApiKey: String);
    destructor Destroy; override;
    class function New(const aProvider, aApiKey: String): iSimpleAIClient;
    function Complete(const aPrompt: String): String;
    function Model(const aValue: String): iSimpleAIClient;
    function MaxTokens(aValue: Integer): iSimpleAIClient;
    function Temperature(aValue: Double): iSimpleAIClient;
  end;

implementation

{ TSimpleAIClient }

constructor TSimpleAIClient.Create(const aProvider, aApiKey: String);
begin
  FProvider := LowerCase(aProvider);
  FApiKey := aApiKey;
  FMaxTokens := 1024;
  FTemperature := 0.7;
  FTimeoutMs := 30000;

  if FProvider = 'claude' then
    FModel := 'claude-sonnet-4-20250514'
  else if FProvider = 'openai' then
    FModel := 'gpt-4o-mini'
  else
    FModel := 'claude-sonnet-4-20250514';
end;

destructor TSimpleAIClient.Destroy;
begin
  inherited;
end;

class function TSimpleAIClient.New(const aProvider, aApiKey: String): iSimpleAIClient;
begin
  Result := Self.Create(aProvider, aApiKey);
end;

function TSimpleAIClient.Complete(const aPrompt: String): String;
begin
  if FProvider = 'openai' then
    Result := CompleteOpenAI(aPrompt)
  else
    Result := CompleteClaude(aPrompt);
end;

function TSimpleAIClient.CompleteClaude(const aPrompt: String): String;
var
  LHttpClient: THTTPClient;
  LRequestBody: TJSONObject;
  LMessagesArray: TJSONArray;
  LMessageObj: TJSONObject;
  LContent: TStringStream;
  LResponse: IHTTPResponse;
  LResponseJSON: TJSONObject;
  LContentArray: TJSONArray;
  LTextValue: TJSONValue;
begin
  Result := '';
  LHttpClient := THTTPClient.Create;
  LRequestBody := TJSONObject.Create;
  LContent := nil;
  LResponseJSON := nil;
  try
    LHttpClient.ConnectionTimeout := FTimeoutMs;
    LHttpClient.ResponseTimeout := FTimeoutMs;
    LHttpClient.CustomHeaders['x-api-key'] := FApiKey;
    LHttpClient.CustomHeaders['anthropic-version'] := '2023-06-01';
    LHttpClient.ContentType := 'application/json';

    LMessagesArray := TJSONArray.Create;
    LMessageObj := TJSONObject.Create;
    LMessageObj.AddPair('role', 'user');
    LMessageObj.AddPair('content', aPrompt);
    LMessagesArray.AddElement(LMessageObj);

    LRequestBody.AddPair('model', FModel);
    LRequestBody.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));
    LRequestBody.AddPair('temperature', TJSONNumber.Create(FTemperature));
    LRequestBody.AddPair('messages', LMessagesArray);

    LContent := TStringStream.Create(LRequestBody.ToJSON, TEncoding.UTF8);

    LResponse := LHttpClient.Post(
      'https://api.anthropic.com/v1/messages',
      LContent,
      nil,
      [TNetHeader.Create('Content-Type', 'application/json'),
       TNetHeader.Create('x-api-key', FApiKey),
       TNetHeader.Create('anthropic-version', '2023-06-01')]
    );

    if LResponse.StatusCode >= 400 then
      raise Exception.CreateFmt('Claude API error: %d - %s',
        [LResponse.StatusCode, LResponse.ContentAsString]);

    LResponseJSON := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    if LResponseJSON = nil then
      raise Exception.Create('Invalid JSON response from Claude API');

    LContentArray := LResponseJSON.GetValue<TJSONArray>('content');
    if (LContentArray <> nil) and (LContentArray.Count > 0) then
    begin
      LTextValue := (LContentArray.Items[0] as TJSONObject).GetValue('text');
      if LTextValue <> nil then
        Result := LTextValue.Value;
    end;
  finally
    FreeAndNil(LResponseJSON);
    FreeAndNil(LContent);
    FreeAndNil(LRequestBody);
    FreeAndNil(LHttpClient);
  end;
end;

function TSimpleAIClient.CompleteOpenAI(const aPrompt: String): String;
var
  LHttpClient: THTTPClient;
  LRequestBody: TJSONObject;
  LMessagesArray: TJSONArray;
  LMessageObj: TJSONObject;
  LContent: TStringStream;
  LResponse: IHTTPResponse;
  LResponseJSON: TJSONObject;
  LChoicesArray: TJSONArray;
  LMessageResult: TJSONObject;
  LContentValue: TJSONValue;
begin
  Result := '';
  LHttpClient := THTTPClient.Create;
  LRequestBody := TJSONObject.Create;
  LContent := nil;
  LResponseJSON := nil;
  try
    LHttpClient.ConnectionTimeout := FTimeoutMs;
    LHttpClient.ResponseTimeout := FTimeoutMs;
    LHttpClient.ContentType := 'application/json';

    LMessagesArray := TJSONArray.Create;
    LMessageObj := TJSONObject.Create;
    LMessageObj.AddPair('role', 'user');
    LMessageObj.AddPair('content', aPrompt);
    LMessagesArray.AddElement(LMessageObj);

    LRequestBody.AddPair('model', FModel);
    LRequestBody.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));
    LRequestBody.AddPair('temperature', TJSONNumber.Create(FTemperature));
    LRequestBody.AddPair('messages', LMessagesArray);

    LContent := TStringStream.Create(LRequestBody.ToJSON, TEncoding.UTF8);

    LResponse := LHttpClient.Post(
      'https://api.openai.com/v1/chat/completions',
      LContent,
      nil,
      [TNetHeader.Create('Content-Type', 'application/json'),
       TNetHeader.Create('Authorization', 'Bearer ' + FApiKey)]
    );

    if LResponse.StatusCode >= 400 then
      raise Exception.CreateFmt('OpenAI API error: %d - %s',
        [LResponse.StatusCode, LResponse.ContentAsString]);

    LResponseJSON := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    if LResponseJSON = nil then
      raise Exception.Create('Invalid JSON response from OpenAI API');

    LChoicesArray := LResponseJSON.GetValue<TJSONArray>('choices');
    if (LChoicesArray <> nil) and (LChoicesArray.Count > 0) then
    begin
      LMessageResult := (LChoicesArray.Items[0] as TJSONObject).GetValue<TJSONObject>('message');
      if LMessageResult <> nil then
      begin
        LContentValue := LMessageResult.GetValue('content');
        if LContentValue <> nil then
          Result := LContentValue.Value;
      end;
    end;
  finally
    FreeAndNil(LResponseJSON);
    FreeAndNil(LContent);
    FreeAndNil(LRequestBody);
    FreeAndNil(LHttpClient);
  end;
end;

function TSimpleAIClient.Model(const aValue: String): iSimpleAIClient;
begin
  Result := Self;
  FModel := aValue;
end;

function TSimpleAIClient.MaxTokens(aValue: Integer): iSimpleAIClient;
begin
  Result := Self;
  FMaxTokens := aValue;
end;

function TSimpleAIClient.Temperature(aValue: Double): iSimpleAIClient;
begin
  Result := Self;
  FTemperature := aValue;
end;

end.
```

**Step 3: Commit**

```bash
git add src/SimpleInterface.pas src/SimpleAIClient.pas
git commit -m "feat: add iSimpleAIClient interface and TSimpleAIClient HTTP client for Claude and OpenAI"
```

---

### Task 2: SimpleAIAttributes.pas — Atributos AI

**Files:**
- Create: `src/SimpleAIAttributes.pas`
- Modify: `src/SimpleRTTIHelper.pas`

**Step 1: Criar a unit SimpleAIAttributes.pas**

```pascal
unit SimpleAIAttributes;

interface

uses
  System.Rtti;

type
  AIGenerated = class(TCustomAttribute)
  private
    FPrompt: String;
  public
    constructor Create(const aPrompt: String);
    property Prompt: String read FPrompt;
  end;

  AISummarize = class(TCustomAttribute)
  private
    FSourceField: String;
  public
    constructor Create(const aSourceField: String);
    property SourceField: String read FSourceField;
  end;

  AITranslate = class(TCustomAttribute)
  private
    FTargetLang: String;
    FSourceField: String;
  public
    constructor Create(const aTargetLang, aSourceField: String);
    property TargetLang: String read FTargetLang;
    property SourceField: String read FSourceField;
  end;

  AIClassify = class(TCustomAttribute)
  private
    FCategories: String;
  public
    constructor Create(const aCategories: String);
    property Categories: String read FCategories;
  end;

  AIValidate = class(TCustomAttribute)
  private
    FRule: String;
  public
    constructor Create(const aRule: String);
    property Rule: String read FRule;
  end;

implementation

{ AIGenerated }

constructor AIGenerated.Create(const aPrompt: String);
begin
  FPrompt := aPrompt;
end;

{ AISummarize }

constructor AISummarize.Create(const aSourceField: String);
begin
  FSourceField := aSourceField;
end;

{ AITranslate }

constructor AITranslate.Create(const aTargetLang, aSourceField: String);
begin
  FTargetLang := aTargetLang;
  FSourceField := aSourceField;
end;

{ AIClassify }

constructor AIClassify.Create(const aCategories: String);
begin
  FCategories := aCategories;
end;

{ AIValidate }

constructor AIValidate.Create(const aRule: String);
begin
  FRule := aRule;
end;

end.
```

**Step 2: Adicionar RTTI helpers em SimpleRTTIHelper.pas**

Adicionar ao `TRttiPropertyHelper`:

```pascal
    function IsAIGenerated: Boolean;
    function IsAISummarize: Boolean;
    function IsAITranslate: Boolean;
    function IsAIClassify: Boolean;
    function IsAIValidate: Boolean;
    function HasAIAttribute: Boolean;
```

Adicionar `SimpleAIAttributes` ao uses clause do interface.

Implementacao:

```pascal
function TRttiPropertyHelper.IsAIGenerated: Boolean;
begin
  Result := Tem<AIGenerated>
end;

function TRttiPropertyHelper.IsAISummarize: Boolean;
begin
  Result := Tem<AISummarize>
end;

function TRttiPropertyHelper.IsAITranslate: Boolean;
begin
  Result := Tem<AITranslate>
end;

function TRttiPropertyHelper.IsAIClassify: Boolean;
begin
  Result := Tem<AIClassify>
end;

function TRttiPropertyHelper.IsAIValidate: Boolean;
begin
  Result := Tem<AIValidate>
end;

function TRttiPropertyHelper.HasAIAttribute: Boolean;
begin
  Result := IsAIGenerated or IsAISummarize or IsAITranslate or IsAIClassify or IsAIValidate;
end;
```

**Step 3: Commit**

```bash
git add src/SimpleAIAttributes.pas src/SimpleRTTIHelper.pas
git commit -m "feat: add AI attributes (AIGenerated, AISummarize, AITranslate, AIClassify, AIValidate) and RTTI helpers"
```

---

### Task 3: SimpleAIProcessor.pas — Processador de entidades

**Files:**
- Create: `src/SimpleAIProcessor.pas`

**Step 1: Criar a unit SimpleAIProcessor.pas**

```pascal
unit SimpleAIProcessor;

interface

uses
  SimpleInterface,
  SimpleAIAttributes,
  SimpleAttributes,
  SimpleRTTIHelper,
  SimpleValidator,
  System.SysUtils,
  System.Rtti,
  System.TypInfo;

type
  TSimpleAIProcessor = class
  public
    class procedure Process(aEntity: TObject; aAIClient: iSimpleAIClient);
    class procedure ProcessAIGenerated(aEntity: TObject; aProp: TRttiProperty;
      aAttr: AIGenerated; aAIClient: iSimpleAIClient; const aContext: String);
    class procedure ProcessAISummarize(aEntity: TObject; aProp: TRttiProperty;
      aAttr: AISummarize; aAIClient: iSimpleAIClient; const aContext: String);
    class procedure ProcessAITranslate(aEntity: TObject; aProp: TRttiProperty;
      aAttr: AITranslate; aAIClient: iSimpleAIClient; const aContext: String);
    class procedure ProcessAIClassify(aEntity: TObject; aProp: TRttiProperty;
      aAttr: AIClassify; aAIClient: iSimpleAIClient; const aContext: String);
    class procedure ProcessAIValidate(aEntity: TObject; aProp: TRttiProperty;
      aAttr: AIValidate; aAIClient: iSimpleAIClient; const aContext: String);
    class function BuildEntityContext(aEntity: TObject): String;
  end;

implementation

{ TSimpleAIProcessor }

class procedure TSimpleAIProcessor.Process(aEntity: TObject; aAIClient: iSimpleAIClient);
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LAttr: TCustomAttribute;
  LEntityContext: String;
begin
  if not Assigned(aEntity) then
    Exit;
  if not Assigned(aAIClient) then
    Exit;

  LEntityContext := BuildEntityContext(aEntity);

  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(aEntity.ClassType);
    for LProp in LType.GetProperties do
    begin
      if not LProp.HasAIAttribute then
        Continue;

      for LAttr in LProp.GetAttributes do
      begin
        if LAttr is AIGenerated then
        begin
          try
            ProcessAIGenerated(aEntity, LProp, AIGenerated(LAttr), aAIClient, LEntityContext);
          except
            // AI failure should not block CRUD operations
          end;
        end
        else if LAttr is AISummarize then
        begin
          try
            ProcessAISummarize(aEntity, LProp, AISummarize(LAttr), aAIClient, LEntityContext);
          except
            // AI failure should not block CRUD operations
          end;
        end
        else if LAttr is AITranslate then
        begin
          try
            ProcessAITranslate(aEntity, LProp, AITranslate(LAttr), aAIClient, LEntityContext);
          except
            // AI failure should not block CRUD operations
          end;
        end
        else if LAttr is AIClassify then
        begin
          try
            ProcessAIClassify(aEntity, LProp, AIClassify(LAttr), aAIClient, LEntityContext);
          except
            // AI failure should not block CRUD operations
          end;
        end
        else if LAttr is AIValidate then
        begin
          // AIValidate CAN raise ESimpleValidator — this is intentional
          ProcessAIValidate(aEntity, LProp, AIValidate(LAttr), aAIClient, LEntityContext);
        end;
      end;
    end;
  finally
    LContext.Free;
  end;
end;

class procedure TSimpleAIProcessor.ProcessAIGenerated(aEntity: TObject;
  aProp: TRttiProperty; aAttr: AIGenerated; aAIClient: iSimpleAIClient;
  const aContext: String);
var
  LPrompt: String;
  LResult: String;
begin
  LPrompt := aAttr.Prompt + #13#10 +
    'Contexto da entidade:' + #13#10 +
    aContext + #13#10 +
    'Responda APENAS com o conteudo gerado, sem explicacoes.';

  LResult := aAIClient.Complete(LPrompt);

  if LResult <> '' then
    aProp.SetValue(aEntity, TValue.From<String>(Trim(LResult)));
end;

class procedure TSimpleAIProcessor.ProcessAISummarize(aEntity: TObject;
  aProp: TRttiProperty; aAttr: AISummarize; aAIClient: iSimpleAIClient;
  const aContext: String);
var
  LPrompt: String;
  LResult: String;
  LSourceContext: TRttiContext;
  LSourceType: TRttiType;
  LSourceProp: TRttiProperty;
  LSourceValue: String;
begin
  LSourceContext := TRttiContext.Create;
  try
    LSourceType := LSourceContext.GetType(aEntity.ClassType);
    LSourceProp := LSourceType.GetProperty(aAttr.SourceField);
    if LSourceProp = nil then
      Exit;

    LSourceValue := LSourceProp.GetValue(aEntity).AsString;
    if LSourceValue = '' then
      Exit;

    LPrompt := 'Resuma o seguinte texto de forma concisa:' + #13#10 +
      LSourceValue + #13#10 +
      'Responda APENAS com o resumo, sem explicacoes.';

    LResult := aAIClient.Complete(LPrompt);

    if LResult <> '' then
      aProp.SetValue(aEntity, TValue.From<String>(Trim(LResult)));
  finally
    LSourceContext.Free;
  end;
end;

class procedure TSimpleAIProcessor.ProcessAITranslate(aEntity: TObject;
  aProp: TRttiProperty; aAttr: AITranslate; aAIClient: iSimpleAIClient;
  const aContext: String);
var
  LPrompt: String;
  LResult: String;
  LSourceContext: TRttiContext;
  LSourceType: TRttiType;
  LSourceProp: TRttiProperty;
  LSourceValue: String;
begin
  LSourceContext := TRttiContext.Create;
  try
    LSourceType := LSourceContext.GetType(aEntity.ClassType);
    LSourceProp := LSourceType.GetProperty(aAttr.SourceField);
    if LSourceProp = nil then
      Exit;

    LSourceValue := LSourceProp.GetValue(aEntity).AsString;
    if LSourceValue = '' then
      Exit;

    LPrompt := 'Traduza o seguinte texto para ' + aAttr.TargetLang + ':' + #13#10 +
      LSourceValue + #13#10 +
      'Responda APENAS com a traducao, sem explicacoes.';

    LResult := aAIClient.Complete(LPrompt);

    if LResult <> '' then
      aProp.SetValue(aEntity, TValue.From<String>(Trim(LResult)));
  finally
    LSourceContext.Free;
  end;
end;

class procedure TSimpleAIProcessor.ProcessAIClassify(aEntity: TObject;
  aProp: TRttiProperty; aAttr: AIClassify; aAIClient: iSimpleAIClient;
  const aContext: String);
var
  LPrompt: String;
  LResult: String;
begin
  LPrompt := 'Classifique a seguinte entidade em uma das categorias: ' +
    aAttr.Categories + #13#10 +
    'Contexto da entidade:' + #13#10 +
    aContext + #13#10 +
    'Responda APENAS com o nome da categoria, sem explicacoes.';

  LResult := aAIClient.Complete(LPrompt);

  if LResult <> '' then
    aProp.SetValue(aEntity, TValue.From<String>(Trim(LResult)));
end;

class procedure TSimpleAIProcessor.ProcessAIValidate(aEntity: TObject;
  aProp: TRttiProperty; aAttr: AIValidate; aAIClient: iSimpleAIClient;
  const aContext: String);
var
  LPrompt: String;
  LResult: String;
  LFieldName: String;
  LFieldValue: String;
begin
  LFieldName := aProp.FieldName;
  LFieldValue := aProp.GetValue(aEntity).AsString;

  LPrompt := 'Valide o seguinte valor do campo "' + LFieldName + '":' + #13#10 +
    'Valor: ' + LFieldValue + #13#10 +
    'Regra de validacao: ' + aAttr.Rule + #13#10 +
    'Contexto da entidade:' + #13#10 +
    aContext + #13#10 +
    'Responda APENAS com VALID se o valor passa na validacao, ou INVALID:motivo se nao passar.';

  LResult := Trim(aAIClient.Complete(LPrompt));

  if LResult.StartsWith('INVALID') then
  begin
    if Pos(':', LResult) > 0 then
      raise ESimpleValidator.Create('Validacao AI falhou para ' + LFieldName + ': ' +
        Copy(LResult, Pos(':', LResult) + 1, Length(LResult)))
    else
      raise ESimpleValidator.Create('Validacao AI falhou para ' + LFieldName);
  end;
end;

class function TSimpleAIProcessor.BuildEntityContext(aEntity: TObject): String;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LValue: TValue;
  LFieldName: String;
  LLines: TStringBuilder;
begin
  LLines := TStringBuilder.Create;
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(aEntity.ClassType);
    for LProp in LType.GetProperties do
    begin
      if LProp.IsIgnore then
        Continue;
      if not LProp.EhCampo then
        Continue;

      LFieldName := LProp.FieldName;
      LValue := LProp.GetValue(aEntity);

      case LProp.PropertyType.TypeKind of
        tkInteger, tkInt64:
          LLines.AppendLine(LFieldName + '=' + IntToStr(LValue.AsInteger));
        tkFloat:
          LLines.AppendLine(LFieldName + '=' + FloatToStr(LValue.AsExtended));
        tkUString, tkString, tkLString, tkWString:
          LLines.AppendLine(LFieldName + '=' + LValue.AsString);
        tkEnumeration:
        begin
          if LProp.PropertyType.Handle = TypeInfo(Boolean) then
            LLines.AppendLine(LFieldName + '=' + BoolToStr(LValue.AsBoolean, True))
          else
            LLines.AppendLine(LFieldName + '=' + IntToStr(LValue.AsOrdinal));
        end;
      end;
    end;
    Result := LLines.ToString;
  finally
    FreeAndNil(LLines);
    LContext.Free;
  end;
end;

end.
```

**Step 2: Commit**

```bash
git add src/SimpleAIProcessor.pas
git commit -m "feat: add TSimpleAIProcessor for RTTI-based AI enrichment of entities"
```

---

### Task 4: Integrar no SimpleDAO

**Files:**
- Modify: `src/SimpleInterface.pas`
- Modify: `src/SimpleDAO.pas`

**Step 1: Adicionar metodo AIClient na interface iSimpleDAO em SimpleInterface.pas**

Adicionar na interface `iSimpleDAO<T>`, antes do fechamento:

```pascal
    function AIClient(aValue: iSimpleAIClient): iSimpleDAO<T>;
```

**Step 2: Adicionar campo e metodo em SimpleDAO.pas**

Adicionar campo privado:

```pascal
    FAIClient: iSimpleAIClient;
```

Adicionar `SimpleAIProcessor` ao uses clause da secao implementation:

```pascal
    SimpleAIProcessor;
```

Adicionar metodo publico na declaracao da classe:

```pascal
    function AIClient(aValue: iSimpleAIClient): iSimpleDAO<T>;
```

Implementacao do metodo:

```pascal
function TSimpleDAO<T>.AIClient(aValue: iSimpleAIClient): iSimpleDAO<T>;
begin
  Result := Self;
  FAIClient := aValue;
end;
```

Modificar `Insert(aValue: T)` — adicionar antes de `TSimpleSQL<T>.New(aValue).Insert(aSQL)`:

```pascal
    if Assigned(FAIClient) then
      TSimpleAIProcessor.Process(TObject(aValue), FAIClient);
```

Modificar `Update(aValue: T)` — adicionar antes de `TSimpleSQL<T>.New(aValue).Update(aSQL)`:

```pascal
    if Assigned(FAIClient) then
      TSimpleAIProcessor.Process(TObject(aValue), FAIClient);
```

**Step 3: Commit**

```bash
git add src/SimpleInterface.pas src/SimpleDAO.pas
git commit -m "feat: integrate AI enrichment into TSimpleDAO Insert and Update"
```

---

### Task 5: Testes DUnit

**Files:**
- Create: `tests/Mocks/MockAIClient.pas`
- Create: `tests/TestSimpleAIProcessor.pas`
- Modify: `tests/SimpleORMTests.dpr`

**Step 1: Criar mock do AI client em tests/Mocks/MockAIClient.pas**

```pascal
unit MockAIClient;

interface

uses
  SimpleInterface,
  System.SysUtils,
  System.Generics.Collections;

type
  TSimpleAIMockClient = class(TInterfacedObject, iSimpleAIClient)
  private
    FModel: String;
    FMaxTokens: Integer;
    FTemperature: Double;
    FCannedResponse: String;
    FLastPrompt: String;
    FCallCount: Integer;
  public
    constructor Create(const aCannedResponse: String);
    destructor Destroy; override;
    class function New(const aCannedResponse: String): iSimpleAIClient;
    function Complete(const aPrompt: String): String;
    function Model(const aValue: String): iSimpleAIClient;
    function MaxTokens(aValue: Integer): iSimpleAIClient;
    function Temperature(aValue: Double): iSimpleAIClient;
    property LastPrompt: String read FLastPrompt;
    property CallCount: Integer read FCallCount;
    property CannedResponse: String read FCannedResponse write FCannedResponse;
  end;

implementation

{ TSimpleAIMockClient }

constructor TSimpleAIMockClient.Create(const aCannedResponse: String);
begin
  FCannedResponse := aCannedResponse;
  FCallCount := 0;
  FMaxTokens := 1024;
  FTemperature := 0.7;
  FModel := 'mock-model';
end;

destructor TSimpleAIMockClient.Destroy;
begin
  inherited;
end;

class function TSimpleAIMockClient.New(const aCannedResponse: String): iSimpleAIClient;
begin
  Result := Self.Create(aCannedResponse);
end;

function TSimpleAIMockClient.Complete(const aPrompt: String): String;
begin
  FLastPrompt := aPrompt;
  Inc(FCallCount);
  Result := FCannedResponse;
end;

function TSimpleAIMockClient.Model(const aValue: String): iSimpleAIClient;
begin
  Result := Self;
  FModel := aValue;
end;

function TSimpleAIMockClient.MaxTokens(aValue: Integer): iSimpleAIClient;
begin
  Result := Self;
  FMaxTokens := aValue;
end;

function TSimpleAIMockClient.Temperature(aValue: Double): iSimpleAIClient;
begin
  Result := Self;
  FTemperature := aValue;
end;

end.
```

**Step 2: Criar tests/TestSimpleAIProcessor.pas**

```pascal
unit TestSimpleAIProcessor;

interface

uses
  TestFramework,
  System.SysUtils,
  System.Classes,
  SimpleAttributes,
  SimpleAIAttributes,
  SimpleAIProcessor,
  SimpleInterface,
  MockAIClient;

type
  { Test entity with AI attributes }
  [Tabela('PRODUTO_AI')]
  TProdutoAITest = class
  private
    FID: Integer;
    FNOME: String;
    FDESCRICAO: String;
    FTAGS: String;
    FRESUMO: String;
    FNOME_EN: String;
    FCONTEUDO: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull]
    property NOME: String read FNOME write FNOME;
    [Campo('DESCRICAO'), AIGenerated('Gere descricao de marketing baseado no nome')]
    property DESCRICAO: String read FDESCRICAO write FDESCRICAO;
    [Campo('TAGS'), AIClassify('eletronico,vestuario,alimento,outro')]
    property TAGS: String read FTAGS write FTAGS;
    [Campo('RESUMO'), AISummarize('CONTEUDO')]
    property RESUMO: String read FRESUMO write FRESUMO;
    [Campo('NOME_EN'), AITranslate('English', 'NOME')]
    property NOME_EN: String read FNOME_EN write FNOME_EN;
    [Campo('CONTEUDO')]
    property CONTEUDO: String read FCONTEUDO write FCONTEUDO;
  end;

  { Test entity with AIValidate }
  [Tabela('COMENTARIO_AI')]
  TComentarioAITest = class
  private
    FID: Integer;
    FTEXTO: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('TEXTO'), AIValidate('Verifique se o texto nao contem linguagem ofensiva')]
    property TEXTO: String read FTEXTO write FTEXTO;
  end;

  { Test entity without AI attributes }
  [Tabela('SIMPLES')]
  TSimplesTest = class
  private
    FID: Integer;
    FNOME: String;
  published
    [Campo('ID'), PK]
    property ID: Integer read FID write FID;
    [Campo('NOME')]
    property NOME: String read FNOME write FNOME;
  end;

  TTestBuildEntityContext = class(TTestCase)
  published
    procedure TestBuildEntityContext_ReturnsFieldValuePairs;
    procedure TestBuildEntityContext_IgnoresIgnoredFields;
    procedure TestBuildEntityContext_HandlesEmptyStrings;
  end;

  TTestProcessAIGenerated = class(TTestCase)
  published
    procedure TestProcessAIGenerated_SetsPropertyValue;
    procedure TestProcessAIGenerated_EmptyResponse_DoesNotOverwrite;
  end;

  TTestProcessAIClassify = class(TTestCase)
  published
    procedure TestProcessAIClassify_SetsCategory;
    procedure TestProcessAIClassify_TrimsWhitespace;
  end;

  TTestProcessAISummarize = class(TTestCase)
  published
    procedure TestProcessAISummarize_SetsResumo;
    procedure TestProcessAISummarize_EmptySource_Skips;
  end;

  TTestProcessAITranslate = class(TTestCase)
  published
    procedure TestProcessAITranslate_SetsTranslation;
    procedure TestProcessAITranslate_EmptySource_Skips;
  end;

  TTestProcessAIValidate = class(TTestCase)
  published
    procedure TestProcessAIValidate_Valid_NoException;
    procedure TestProcessAIValidate_Invalid_RaisesException;
  end;

  TTestProcess = class(TTestCase)
  published
    procedure TestProcess_SkipsEntitiesWithoutAIAttributes;
    procedure TestProcess_NilEntity_NoError;
    procedure TestProcess_NilClient_NoError;
    procedure TestProcess_ProcessesMultipleAIAttributes;
  end;

implementation

uses
  SimpleValidator;

{ TTestBuildEntityContext }

procedure TTestBuildEntityContext.TestBuildEntityContext_ReturnsFieldValuePairs;
var
  LEntity: TProdutoAITest;
  LResult: String;
begin
  LEntity := TProdutoAITest.Create;
  try
    LEntity.ID := 1;
    LEntity.NOME := 'Notebook Gamer';
    LEntity.DESCRICAO := '';
    LEntity.TAGS := '';
    LResult := TSimpleAIProcessor.BuildEntityContext(LEntity);
    CheckTrue(Pos('ID=1', LResult) > 0, 'Should contain ID=1');
    CheckTrue(Pos('NOME=Notebook Gamer', LResult) > 0, 'Should contain NOME=Notebook Gamer');
  finally
    FreeAndNil(LEntity);
  end;
end;

procedure TTestBuildEntityContext.TestBuildEntityContext_IgnoresIgnoredFields;
var
  LEntity: TPedidoIgnoreTest;
  LResult: String;
begin
  LEntity := TPedidoIgnoreTest.Create;
  try
    LEntity.ID := 1;
    LEntity.NOME := 'Test';
    LEntity.TEMP := 'should not appear';
    LResult := TSimpleAIProcessor.BuildEntityContext(LEntity);
    CheckTrue(Pos('NOME=Test', LResult) > 0, 'Should contain NOME');
    CheckFalse(Pos('TEMP', LResult) > 0, 'Should not contain TEMP (Ignore attribute)');
  finally
    FreeAndNil(LEntity);
  end;
end;

procedure TTestBuildEntityContext.TestBuildEntityContext_HandlesEmptyStrings;
var
  LEntity: TSimplesTest;
  LResult: String;
begin
  LEntity := TSimplesTest.Create;
  try
    LEntity.ID := 0;
    LEntity.NOME := '';
    LResult := TSimpleAIProcessor.BuildEntityContext(LEntity);
    CheckTrue(Pos('ID=0', LResult) > 0, 'Should contain ID=0');
    CheckTrue(Pos('NOME=', LResult) > 0, 'Should contain NOME= (empty)');
  finally
    FreeAndNil(LEntity);
  end;
end;

{ TTestProcessAIGenerated }

procedure TTestProcessAIGenerated.TestProcessAIGenerated_SetsPropertyValue;
var
  LEntity: TProdutoAITest;
  LMock: TSimpleAIMockClient;
  LClient: iSimpleAIClient;
begin
  LEntity := TProdutoAITest.Create;
  try
    LEntity.NOME := 'Notebook Gamer';
    LMock := TSimpleAIMockClient.Create('Descricao gerada pela IA');
    LClient := LMock;
    TSimpleAIProcessor.Process(LEntity, LClient);
    CheckEquals('Descricao gerada pela IA', LEntity.DESCRICAO,
      'DESCRICAO should be set by AI');
    CheckTrue(LMock.CallCount > 0, 'AI client should have been called');
  finally
    FreeAndNil(LEntity);
  end;
end;

procedure TTestProcessAIGenerated.TestProcessAIGenerated_EmptyResponse_DoesNotOverwrite;
var
  LEntity: TProdutoAITest;
  LClient: iSimpleAIClient;
begin
  LEntity := TProdutoAITest.Create;
  try
    LEntity.NOME := 'Notebook';
    LEntity.DESCRICAO := 'Original';
    LClient := TSimpleAIMockClient.New('');
    TSimpleAIProcessor.Process(LEntity, LClient);
    CheckEquals('Original', LEntity.DESCRICAO,
      'DESCRICAO should not be overwritten with empty response');
  finally
    FreeAndNil(LEntity);
  end;
end;

{ TTestProcessAIClassify }

procedure TTestProcessAIClassify.TestProcessAIClassify_SetsCategory;
var
  LEntity: TProdutoAITest;
  LClient: iSimpleAIClient;
begin
  LEntity := TProdutoAITest.Create;
  try
    LEntity.NOME := 'Notebook Gamer';
    LClient := TSimpleAIMockClient.New('eletronico');
    TSimpleAIProcessor.Process(LEntity, LClient);
    CheckEquals('eletronico', LEntity.TAGS,
      'TAGS should be set to the classified category');
  finally
    FreeAndNil(LEntity);
  end;
end;

procedure TTestProcessAIClassify.TestProcessAIClassify_TrimsWhitespace;
var
  LEntity: TProdutoAITest;
  LClient: iSimpleAIClient;
begin
  LEntity := TProdutoAITest.Create;
  try
    LEntity.NOME := 'Camiseta';
    LClient := TSimpleAIMockClient.New('  vestuario  ');
    TSimpleAIProcessor.Process(LEntity, LClient);
    CheckEquals('vestuario', LEntity.TAGS,
      'TAGS should be trimmed');
  finally
    FreeAndNil(LEntity);
  end;
end;

{ TTestProcessAISummarize }

procedure TTestProcessAISummarize.TestProcessAISummarize_SetsResumo;
var
  LEntity: TProdutoAITest;
  LClient: iSimpleAIClient;
begin
  LEntity := TProdutoAITest.Create;
  try
    LEntity.CONTEUDO := 'Este e um texto longo que precisa ser resumido pela inteligencia artificial para gerar um resumo conciso.';
    LClient := TSimpleAIMockClient.New('Resumo do texto');
    TSimpleAIProcessor.Process(LEntity, LClient);
    CheckEquals('Resumo do texto', LEntity.RESUMO,
      'RESUMO should be set by AI summarization');
  finally
    FreeAndNil(LEntity);
  end;
end;

procedure TTestProcessAISummarize.TestProcessAISummarize_EmptySource_Skips;
var
  LEntity: TProdutoAITest;
  LMock: TSimpleAIMockClient;
  LClient: iSimpleAIClient;
  LInitialCallCount: Integer;
begin
  LEntity := TProdutoAITest.Create;
  try
    LEntity.CONTEUDO := '';
    LEntity.RESUMO := 'Original';
    LMock := TSimpleAIMockClient.Create('Should not be used');
    LClient := LMock;
    LInitialCallCount := LMock.CallCount;
    TSimpleAIProcessor.Process(LEntity, LClient);
    // The summarize call should be skipped for empty source,
    // but other AI attributes may still call the client
    CheckEquals('Original', LEntity.RESUMO,
      'RESUMO should not be changed when source is empty');
  finally
    FreeAndNil(LEntity);
  end;
end;

{ TTestProcessAITranslate }

procedure TTestProcessAITranslate.TestProcessAITranslate_SetsTranslation;
var
  LEntity: TProdutoAITest;
  LClient: iSimpleAIClient;
begin
  LEntity := TProdutoAITest.Create;
  try
    LEntity.NOME := 'Notebook Gamer';
    LClient := TSimpleAIMockClient.New('Gaming Notebook');
    TSimpleAIProcessor.Process(LEntity, LClient);
    CheckEquals('Gaming Notebook', LEntity.NOME_EN,
      'NOME_EN should be set by AI translation');
  finally
    FreeAndNil(LEntity);
  end;
end;

procedure TTestProcessAITranslate.TestProcessAITranslate_EmptySource_Skips;
var
  LEntity: TProdutoAITest;
  LClient: iSimpleAIClient;
begin
  LEntity := TProdutoAITest.Create;
  try
    LEntity.NOME := '';
    LEntity.NOME_EN := 'Original';
    LClient := TSimpleAIMockClient.New('Should not be used');
    TSimpleAIProcessor.Process(LEntity, LClient);
    CheckEquals('Original', LEntity.NOME_EN,
      'NOME_EN should not be changed when source NOME is empty');
  finally
    FreeAndNil(LEntity);
  end;
end;

{ TTestProcessAIValidate }

procedure TTestProcessAIValidate.TestProcessAIValidate_Valid_NoException;
var
  LEntity: TComentarioAITest;
  LClient: iSimpleAIClient;
begin
  LEntity := TComentarioAITest.Create;
  try
    LEntity.ID := 1;
    LEntity.TEXTO := 'Este e um comentario educado e respeitoso.';
    LClient := TSimpleAIMockClient.New('VALID');
    TSimpleAIProcessor.Process(LEntity, LClient);
    // No exception means the test passed
    CheckTrue(True, 'Should not raise exception for VALID response');
  finally
    FreeAndNil(LEntity);
  end;
end;

procedure TTestProcessAIValidate.TestProcessAIValidate_Invalid_RaisesException;
var
  LEntity: TComentarioAITest;
  LClient: iSimpleAIClient;
  LRaised: Boolean;
begin
  LEntity := TComentarioAITest.Create;
  try
    LEntity.ID := 1;
    LEntity.TEXTO := 'Texto com linguagem ofensiva.';
    LClient := TSimpleAIMockClient.New('INVALID:Contem linguagem ofensiva');
    LRaised := False;
    try
      TSimpleAIProcessor.Process(LEntity, LClient);
    except
      on E: ESimpleValidator do
        LRaised := True;
    end;
    CheckTrue(LRaised, 'Should raise ESimpleValidator for INVALID response');
  finally
    FreeAndNil(LEntity);
  end;
end;

{ TTestProcess }

procedure TTestProcess.TestProcess_SkipsEntitiesWithoutAIAttributes;
var
  LEntity: TSimplesTest;
  LMock: TSimpleAIMockClient;
  LClient: iSimpleAIClient;
begin
  LEntity := TSimplesTest.Create;
  try
    LEntity.ID := 1;
    LEntity.NOME := 'Test';
    LMock := TSimpleAIMockClient.Create('Should not be called');
    LClient := LMock;
    TSimpleAIProcessor.Process(LEntity, LClient);
    CheckEquals(0, LMock.CallCount,
      'AI client should not be called for entities without AI attributes');
  finally
    FreeAndNil(LEntity);
  end;
end;

procedure TTestProcess.TestProcess_NilEntity_NoError;
var
  LClient: iSimpleAIClient;
begin
  LClient := TSimpleAIMockClient.New('test');
  TSimpleAIProcessor.Process(nil, LClient);
  CheckTrue(True, 'Should not raise exception for nil entity');
end;

procedure TTestProcess.TestProcess_NilClient_NoError;
var
  LEntity: TProdutoAITest;
begin
  LEntity := TProdutoAITest.Create;
  try
    LEntity.NOME := 'Test';
    TSimpleAIProcessor.Process(LEntity, nil);
    CheckTrue(True, 'Should not raise exception for nil client');
  finally
    FreeAndNil(LEntity);
  end;
end;

procedure TTestProcess.TestProcess_ProcessesMultipleAIAttributes;
var
  LEntity: TProdutoAITest;
  LMock: TSimpleAIMockClient;
  LClient: iSimpleAIClient;
begin
  LEntity := TProdutoAITest.Create;
  try
    LEntity.NOME := 'Notebook Gamer';
    LEntity.CONTEUDO := 'Um texto sobre notebooks gamers com placas de video potentes.';
    LMock := TSimpleAIMockClient.Create('resposta mock');
    LClient := LMock;
    TSimpleAIProcessor.Process(LEntity, LClient);
    // Multiple AI attributes should result in multiple calls
    CheckTrue(LMock.CallCount > 1,
      'AI client should be called multiple times for entity with multiple AI attributes');
  finally
    FreeAndNil(LEntity);
  end;
end;

type
  { Helper test entity with Ignore attribute }
  [Tabela('PEDIDO_IGNORE')]
  TPedidoIgnoreTest = class
  private
    FID: Integer;
    FNOME: String;
    FTEMP: String;
  published
    [Campo('ID'), PK]
    property ID: Integer read FID write FID;
    [Campo('NOME')]
    property NOME: String read FNOME write FNOME;
    [Ignore]
    property TEMP: String read FTEMP write FTEMP;
  end;

initialization
  RegisterTest('AI.Processor', TTestBuildEntityContext.Suite);
  RegisterTest('AI.Processor', TTestProcessAIGenerated.Suite);
  RegisterTest('AI.Processor', TTestProcessAIClassify.Suite);
  RegisterTest('AI.Processor', TTestProcessAISummarize.Suite);
  RegisterTest('AI.Processor', TTestProcessAITranslate.Suite);
  RegisterTest('AI.Processor', TTestProcessAIValidate.Suite);
  RegisterTest('AI.Processor', TTestProcess.Suite);

end.
```

**Step 3: Adicionar ao SimpleORMTests.dpr**

Adicionar no uses clause:

```pascal
  SimpleAIAttributes in '..\src\SimpleAIAttributes.pas',
  SimpleAIProcessor in '..\src\SimpleAIProcessor.pas',
  SimpleAIClient in '..\src\SimpleAIClient.pas',
  MockAIClient in 'Mocks\MockAIClient.pas',
  TestSimpleAIProcessor in 'TestSimpleAIProcessor.pas';
```

**Step 4: Commit**

```bash
git add tests/Mocks/MockAIClient.pas tests/TestSimpleAIProcessor.pas tests/SimpleORMTests.dpr
git commit -m "test: add DUnit tests for TSimpleAIProcessor with mock AI client"
```

---

### Task 6: Sample project

**Files:**
- Create: `samples/AIEnrichment/SimpleORMAIEnrichment.dpr`
- Create: `samples/AIEnrichment/README.md`

**Step 1: Criar samples/AIEnrichment/SimpleORMAIEnrichment.dpr**

```pascal
program SimpleORMAIEnrichment;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  SimpleAttributes in '..\..\src\SimpleAttributes.pas',
  SimpleAIAttributes in '..\..\src\SimpleAIAttributes.pas',
  SimpleAIProcessor in '..\..\src\SimpleAIProcessor.pas',
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleRTTIHelper in '..\..\src\SimpleRTTIHelper.pas',
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleLogger in '..\..\src\SimpleLogger.pas';

type
  { Mock AI Client para demonstracao sem API real }
  TDemoAIClient = class(TInterfacedObject, iSimpleAIClient)
  private
    FModel: String;
    FMaxTokens: Integer;
    FTemperature: Double;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: iSimpleAIClient;
    function Complete(const aPrompt: String): String;
    function Model(const aValue: String): iSimpleAIClient;
    function MaxTokens(aValue: Integer): iSimpleAIClient;
    function Temperature(aValue: Double): iSimpleAIClient;
  end;

  { Entidade com atributos AI }
  [Tabela('PRODUTOS')]
  TProduto = class
  private
    FID: Integer;
    FNOME: String;
    FDESCRICAO: String;
    FTAGS: String;
    FRESUMO: String;
    FNOME_EN: String;
    FDETALHES: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull]
    property NOME: String read FNOME write FNOME;
    [Campo('DESCRICAO'), AIGenerated('Gere descricao de marketing baseado no nome do produto')]
    property DESCRICAO: String read FDESCRICAO write FDESCRICAO;
    [Campo('TAGS'), AIClassify('eletronico,vestuario,alimento,outro')]
    property TAGS: String read FTAGS write FTAGS;
    [Campo('RESUMO'), AISummarize('DETALHES')]
    property RESUMO: String read FRESUMO write FRESUMO;
    [Campo('NOME_EN'), AITranslate('English', 'NOME')]
    property NOME_EN: String read FNOME_EN write FNOME_EN;
    [Campo('DETALHES')]
    property DETALHES: String read FDETALHES write FDETALHES;
  end;

{ TDemoAIClient }

constructor TDemoAIClient.Create;
begin
  FModel := 'demo-model';
  FMaxTokens := 1024;
  FTemperature := 0.7;
end;

destructor TDemoAIClient.Destroy;
begin
  inherited;
end;

class function TDemoAIClient.New: iSimpleAIClient;
begin
  Result := Self.Create;
end;

function TDemoAIClient.Complete(const aPrompt: String): String;
begin
  // Simula respostas de IA baseado no conteudo do prompt
  if Pos('descricao', LowerCase(aPrompt)) > 0 then
    Result := 'Produto de alta qualidade, perfeito para quem busca performance e durabilidade.'
  else if Pos('classifique', LowerCase(aPrompt)) > 0 then
    Result := 'eletronico'
  else if Pos('resuma', LowerCase(aPrompt)) > 0 then
    Result := 'Notebook gamer com GPU dedicada e tela 144Hz.'
  else if Pos('traduza', LowerCase(aPrompt)) > 0 then
    Result := 'Gaming Notebook Pro'
  else
    Result := 'Resposta simulada da IA';
end;

function TDemoAIClient.Model(const aValue: String): iSimpleAIClient;
begin
  Result := Self;
  FModel := aValue;
end;

function TDemoAIClient.MaxTokens(aValue: Integer): iSimpleAIClient;
begin
  Result := Self;
  FMaxTokens := aValue;
end;

function TDemoAIClient.Temperature(aValue: Double): iSimpleAIClient;
begin
  Result := Self;
  FTemperature := aValue;
end;

{ Main }

var
  LProduto: TProduto;
  LAIClient: iSimpleAIClient;
begin
  try
    Writeln('=== SimpleORM AI Enrichment Demo ===');
    Writeln('');

    // Criar mock AI client
    LAIClient := TDemoAIClient.New;

    // Criar produto com dados basicos
    LProduto := TProduto.Create;
    try
      LProduto.ID := 1;
      LProduto.NOME := 'Notebook Gamer Pro';
      LProduto.DETALHES := 'Notebook gamer com processador Intel i9, GPU NVIDIA RTX 4090, ' +
        '32GB RAM DDR5, SSD NVMe 2TB, tela IPS 17 polegadas 144Hz, ' +
        'teclado mecanico RGB, bateria de longa duracao.';

      Writeln('--- Antes do processamento AI ---');
      Writeln('NOME:      ', LProduto.NOME);
      Writeln('DESCRICAO: ', LProduto.DESCRICAO);
      Writeln('TAGS:      ', LProduto.TAGS);
      Writeln('RESUMO:    ', LProduto.RESUMO);
      Writeln('NOME_EN:   ', LProduto.NOME_EN);
      Writeln('DETALHES:  ', LProduto.DETALHES);
      Writeln('');

      // Processar atributos AI
      TSimpleAIProcessor.Process(LProduto, LAIClient);

      Writeln('--- Depois do processamento AI ---');
      Writeln('NOME:      ', LProduto.NOME);
      Writeln('DESCRICAO: ', LProduto.DESCRICAO);
      Writeln('TAGS:      ', LProduto.TAGS);
      Writeln('RESUMO:    ', LProduto.RESUMO);
      Writeln('NOME_EN:   ', LProduto.NOME_EN);
      Writeln('DETALHES:  ', LProduto.DETALHES);
      Writeln('');

      Writeln('--- Contexto da entidade (usado nos prompts) ---');
      Writeln(TSimpleAIProcessor.BuildEntityContext(LProduto));
    finally
      FreeAndNil(LProduto);
    end;

    Writeln('=== Demo finalizada com sucesso ===');
  except
    on E: Exception do
      Writeln('Erro: ', E.Message);
  end;

  Writeln('');
  Writeln('Pressione ENTER para sair...');
  Readln;
end.
```

**Step 2: Criar samples/AIEnrichment/README.md**

```markdown
# SimpleORM AI Enrichment - Sample

## Descricao

Este sample demonstra o uso do recurso de AI Enrichment do SimpleORM,
que permite preencher automaticamente propriedades de entidades via LLM
usando atributos declarativos.

## Como executar

1. Abra `SimpleORMAIEnrichment.dpr` na IDE Delphi
2. A IDE ira gerar os arquivos `.dproj` e `.res` automaticamente
3. Compile e execute (F9)

## O que o sample demonstra

- Criacao de entidade com atributos AI (`AIGenerated`, `AIClassify`, `AISummarize`, `AITranslate`)
- Uso de um mock AI client para simular respostas de LLM
- Processamento automatico de atributos AI via `TSimpleAIProcessor.Process`
- Visualizacao do contexto da entidade usado nos prompts

## Para usar com API real

Substitua `TDemoAIClient` por `TSimpleAIClient`:

```pascal
LAIClient := TSimpleAIClient.New('claude', 'sua-api-key-aqui');
```

Ou para OpenAI:

```pascal
LAIClient := TSimpleAIClient.New('openai', 'sua-api-key-aqui');
```
```

**Step 3: Commit**

```bash
git add samples/AIEnrichment/SimpleORMAIEnrichment.dpr samples/AIEnrichment/README.md
git commit -m "feat: add AI Enrichment sample project"
```

---

### Task 7: Documentacao

**Files:**
- Modify: `docs/index.html`
- Modify: `CHANGELOG.md`

**Step 1: Adicionar secao AI Enrichment em docs/index.html**

Adicionar link no `<nav>`:

```html
<a href="#ai-enrichment">AI Enrichment</a>
```

Adicionar secao antes do fechamento do `<main>`:

```html
<section id="ai-enrichment">
  <h2>AI Enrichment <span class="badge badge-new">NEW</span></h2>
  <p>O SimpleORM permite preencher propriedades de entidades automaticamente via LLM (Claude, OpenAI) durante operacoes de Insert/Update.</p>

  <h3>Atributos AI</h3>
  <table>
    <thead>
      <tr><th>Atributo</th><th>Parametros</th><th>Descricao</th></tr>
    </thead>
    <tbody>
      <tr><td>AIGenerated</td><td>prompt: String</td><td>Gera conteudo baseado no prompt + dados da entidade</td></tr>
      <tr><td>AISummarize</td><td>sourceField: String</td><td>Resume o conteudo de outra property</td></tr>
      <tr><td>AITranslate</td><td>targetLang, sourceField: String</td><td>Traduz de outra property para o idioma alvo</td></tr>
      <tr><td>AIClassify</td><td>categories: String</td><td>Classifica em uma das categorias (separadas por virgula)</td></tr>
      <tr><td>AIValidate</td><td>rule: String</td><td>Validacao semantica via LLM</td></tr>
    </tbody>
  </table>

  <h3>Exemplo de uso</h3>
  <pre><code>// Configurar AI client no DAO
DAOProduto := TSimpleDAO&lt;TProduto&gt;.New(Query)
  .AIClient(TSimpleAIClient.New('claude', 'sk-ant-xxx'));

// Na entidade:
[Tabela('PRODUTOS')]
TProduto = class
published
  [Campo('NOME')]
  property Nome: String read FNome write FNome;
  [Campo('DESCRICAO'), AIGenerated('Gere descricao de marketing baseado no nome')]
  property Descricao: String read FDescricao write FDescricao;
  [Campo('TAGS'), AIClassify('eletronico,vestuario,alimento,outro')]
  property Tags: String read FTags write FTags;
end;

// Insert automaticamente processa AI antes de persistir
DAOProduto.Insert(LProduto);</code></pre>

  <p class="note">Se a chamada AI falhar, a operacao de CRUD continua normalmente sem preencher o campo. A excecao e <code>AIValidate</code>, que lanca <code>ESimpleValidator</code> se a validacao falhar.</p>
</section>
```

**Step 2: Atualizar CHANGELOG.md**

Adicionar na secao `[Unreleased]`:

```markdown
### Added
- **AI Enrichment** - Preenchimento automatico de propriedades via LLM com atributos declarativos (SimpleAIClient.pas, SimpleAIAttributes.pas, SimpleAIProcessor.pas)
- **iSimpleAIClient** - Interface para clientes de LLM com suporte a Claude e OpenAI (SimpleInterface.pas)
- **TSimpleAIClient** - Client HTTP para APIs Claude e OpenAI (SimpleAIClient.pas)
- **Atributos AI** - AIGenerated, AISummarize, AITranslate, AIClassify, AIValidate (SimpleAIAttributes.pas)
- **TSimpleAIProcessor** - Processador RTTI que detecta atributos AI e enriquece entidades (SimpleAIProcessor.pas)
- **RTTI Helpers AI** - IsAIGenerated, IsAISummarize, IsAITranslate, IsAIClassify, IsAIValidate, HasAIAttribute (SimpleRTTIHelper.pas)
- **DAO.AIClient** - Metodo para configurar AI client no TSimpleDAO (SimpleDAO.pas)
- **Sample AIEnrichment** - Projeto demonstrando AI Enrichment com mock client
```

**Step 3: Commit**

```bash
git add docs/index.html CHANGELOG.md
git commit -m "docs: add AI Enrichment documentation and changelog"
```
