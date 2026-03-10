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
