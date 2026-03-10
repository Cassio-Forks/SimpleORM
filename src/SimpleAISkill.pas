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

end.
