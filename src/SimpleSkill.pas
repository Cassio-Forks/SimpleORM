unit SimpleSkill;

interface

uses
  SimpleInterface,
  SimpleAttributes,
  SimpleRTTIHelper,
  SimpleTypes,
  SimpleLogger,
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections;

type
  TSimpleSkillContext = class(TInterfacedObject, iSimpleSkillContext)
  private
    FQuery: iSimpleQuery;
    FAIClient: iSimpleAIClient;
    FLogger: iSimpleQueryLogger;
    FEntityName: String;
    FOperation: String;
  public
    constructor Create(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient;
      aLogger: iSimpleQueryLogger; const aEntityName, aOperation: String);
    destructor Destroy; override;
    class function New(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient;
      aLogger: iSimpleQueryLogger; const aEntityName, aOperation: String): iSimpleSkillContext;
    function Query: iSimpleQuery;
    function AIClient: iSimpleAIClient;
    function Logger: iSimpleQueryLogger;
    function EntityName: String;
    function Operation: String;
  end;

  TSimpleSkillRunner = class
  private
    FSkills: TList<iSimpleSkill>;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: TSimpleSkillRunner;
    procedure Add(aSkill: iSimpleSkill);
    procedure RunBefore(aEntity: TObject; aContext: iSimpleSkillContext; aRunAt: TSkillRunAt);
    procedure RunAfter(aEntity: TObject; aContext: iSimpleSkillContext; aRunAt: TSkillRunAt);
    function Count: Integer;
  end;

  { Built-in: TSkillLog }
  TSkillLog = class(TInterfacedObject, iSimpleSkill)
  private
    FPrefix: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aPrefix: String = ''; aRunAt: TSkillRunAt = srAfterInsert);
    destructor Destroy; override;
    class function New(const aPrefix: String = ''; aRunAt: TSkillRunAt = srAfterInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;

  { Built-in: TSkillNotify }
  TSkillNotify = class(TInterfacedObject, iSimpleSkill)
  private
    FCallback: TProc<TObject>;
    FRunAt: TSkillRunAt;
  public
    constructor Create(aCallback: TProc<TObject>; aRunAt: TSkillRunAt = srAfterInsert);
    destructor Destroy; override;
    class function New(aCallback: TProc<TObject>; aRunAt: TSkillRunAt = srAfterInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;

  { Built-in: TSkillAudit }
  TSkillAudit = class(TInterfacedObject, iSimpleSkill)
  private
    FAuditTable: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aAuditTable: String = 'AUDIT_LOG'; aRunAt: TSkillRunAt = srAfterInsert);
    destructor Destroy; override;
    class function New(const aAuditTable: String = 'AUDIT_LOG'; aRunAt: TSkillRunAt = srAfterInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;

  { Built-in: TSkillTimestamp }
  TSkillTimestamp = class(TInterfacedObject, iSimpleSkill)
  private
    FFieldName: String;
    FRunAt: TSkillRunAt;
  public
    constructor Create(const aFieldName: String; aRunAt: TSkillRunAt = srBeforeInsert);
    destructor Destroy; override;
    class function New(const aFieldName: String; aRunAt: TSkillRunAt = srBeforeInsert): iSimpleSkill;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
  end;

implementation

{ TSimpleSkillContext }

constructor TSimpleSkillContext.Create(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient;
  aLogger: iSimpleQueryLogger; const aEntityName, aOperation: String);
begin
  FQuery := aQuery;
  FAIClient := aAIClient;
  FLogger := aLogger;
  FEntityName := aEntityName;
  FOperation := aOperation;
end;

destructor TSimpleSkillContext.Destroy;
begin
  inherited;
end;

class function TSimpleSkillContext.New(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient;
  aLogger: iSimpleQueryLogger; const aEntityName, aOperation: String): iSimpleSkillContext;
begin
  Result := Self.Create(aQuery, aAIClient, aLogger, aEntityName, aOperation);
end;

function TSimpleSkillContext.Query: iSimpleQuery;
begin
  Result := FQuery;
end;

function TSimpleSkillContext.AIClient: iSimpleAIClient;
begin
  Result := FAIClient;
end;

function TSimpleSkillContext.Logger: iSimpleQueryLogger;
begin
  Result := FLogger;
end;

function TSimpleSkillContext.EntityName: String;
begin
  Result := FEntityName;
end;

function TSimpleSkillContext.Operation: String;
begin
  Result := FOperation;
end;

{ TSimpleSkillRunner }

constructor TSimpleSkillRunner.Create;
begin
  FSkills := TList<iSimpleSkill>.Create;
end;

destructor TSimpleSkillRunner.Destroy;
begin
  FreeAndNil(FSkills);
  inherited;
end;

class function TSimpleSkillRunner.New: TSimpleSkillRunner;
begin
  Result := Self.Create;
end;

procedure TSimpleSkillRunner.Add(aSkill: iSimpleSkill);
begin
  FSkills.Add(aSkill);
end;

procedure TSimpleSkillRunner.RunBefore(aEntity: TObject; aContext: iSimpleSkillContext; aRunAt: TSkillRunAt);
var
  LSkill: iSimpleSkill;
begin
  for LSkill in FSkills do
  begin
    if LSkill.RunAt = aRunAt then
      LSkill.Execute(aEntity, aContext);
  end;
end;

procedure TSimpleSkillRunner.RunAfter(aEntity: TObject; aContext: iSimpleSkillContext; aRunAt: TSkillRunAt);
var
  LSkill: iSimpleSkill;
begin
  for LSkill in FSkills do
  begin
    if LSkill.RunAt = aRunAt then
      LSkill.Execute(aEntity, aContext);
  end;
end;

function TSimpleSkillRunner.Count: Integer;
begin
  Result := FSkills.Count;
end;

{ TSkillLog }

constructor TSkillLog.Create(const aPrefix: String; aRunAt: TSkillRunAt);
begin
  FPrefix := aPrefix;
  FRunAt := aRunAt;
end;

destructor TSkillLog.Destroy;
begin
  inherited;
end;

class function TSkillLog.New(const aPrefix: String; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aPrefix, aRunAt);
end;

function TSkillLog.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LMsg: String;
begin
  Result := Self;
  LMsg := '[Skill:Log]';
  if FPrefix <> '' then
    LMsg := LMsg + ' ' + FPrefix;
  LMsg := LMsg + ' ' + aContext.Operation + ' ' + aContext.EntityName;
  if aEntity <> nil then
    LMsg := LMsg + ' (' + aEntity.ClassName + ')';

  if Assigned(aContext.Logger) then
    aContext.Logger.Log(LMsg, nil, 0)
  else
  begin
    {$IFDEF MSWINDOWS}
    OutputDebugString(PChar(LMsg));
    {$ENDIF}
    {$IFDEF CONSOLE}
    Writeln(LMsg);
    {$ENDIF}
  end;
end;

function TSkillLog.Name: String;
begin
  Result := 'log';
end;

function TSkillLog.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;

{ TSkillNotify }

constructor TSkillNotify.Create(aCallback: TProc<TObject>; aRunAt: TSkillRunAt);
begin
  FCallback := aCallback;
  FRunAt := aRunAt;
end;

destructor TSkillNotify.Destroy;
begin
  inherited;
end;

class function TSkillNotify.New(aCallback: TProc<TObject>; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aCallback, aRunAt);
end;

function TSkillNotify.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
begin
  Result := Self;
  if Assigned(FCallback) then
    FCallback(aEntity);
end;

function TSkillNotify.Name: String;
begin
  Result := 'notify';
end;

function TSkillNotify.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;

{ TSkillAudit }

constructor TSkillAudit.Create(const aAuditTable: String; aRunAt: TSkillRunAt);
begin
  FAuditTable := aAuditTable;
  FRunAt := aRunAt;
end;

destructor TSkillAudit.Destroy;
begin
  inherited;
end;

class function TSkillAudit.New(const aAuditTable: String; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aAuditTable, aRunAt);
end;

function TSkillAudit.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LSQL: String;
begin
  Result := Self;
  if aContext.Query = nil then
    Exit;

  LSQL := 'INSERT INTO ' + FAuditTable +
    ' (ENTITY_NAME, OPERATION, CREATED_AT) VALUES (:pEntity, :pOperation, :pCreatedAt)';

  aContext.Query.SQL.Clear;
  aContext.Query.SQL.Add(LSQL);
  aContext.Query.Params.ParamByName('pEntity').Value := aContext.EntityName;
  aContext.Query.Params.ParamByName('pOperation').Value := aContext.Operation;
  aContext.Query.Params.ParamByName('pCreatedAt').Value := Now;
  aContext.Query.ExecSQL;
end;

function TSkillAudit.Name: String;
begin
  Result := 'audit';
end;

function TSkillAudit.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;

{ TSkillTimestamp }

constructor TSkillTimestamp.Create(const aFieldName: String; aRunAt: TSkillRunAt);
begin
  FFieldName := aFieldName;
  FRunAt := aRunAt;
end;

destructor TSkillTimestamp.Destroy;
begin
  inherited;
end;

class function TSkillTimestamp.New(const aFieldName: String; aRunAt: TSkillRunAt): iSimpleSkill;
begin
  Result := Self.Create(aFieldName, aRunAt);
end;

function TSkillTimestamp.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  Result := Self;
  if aEntity = nil then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(aEntity.ClassType);
  LProp := LType.GetProperty(FFieldName);
  if LProp <> nil then
    LProp.SetValue(aEntity, TValue.From<TDateTime>(Now));
end;

function TSkillTimestamp.Name: String;
begin
  Result := 'timestamp';
end;

function TSkillTimestamp.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;

end.
