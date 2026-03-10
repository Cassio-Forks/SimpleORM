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

end.
