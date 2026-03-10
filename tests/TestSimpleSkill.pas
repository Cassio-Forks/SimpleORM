unit TestSimpleSkill;

interface

uses
  TestFramework,
  System.SysUtils,
  SimpleSkill,
  SimpleInterface,
  SimpleTypes;

type
  TTestSkillRunner = class(TTestCase)
  published
    procedure TestAdd_IncreasesCount;
    procedure TestRunBefore_ExecutesMatchingSkills;
    procedure TestRunAfter_ExecutesMatchingSkills;
    procedure TestRunBefore_IgnoresWrongRunAt;
  end;

  TTestSkillLog = class(TTestCase)
  published
    procedure TestLog_ExecutesWithoutError;
    procedure TestLog_Name;
    procedure TestLog_RunAt;
  end;

  TTestSkillNotify = class(TTestCase)
  published
    procedure TestNotify_CallsCallback;
    procedure TestNotify_NilCallback_NoError;
  end;

  TTestSkillContext = class(TTestCase)
  published
    procedure TestContext_ReturnsValues;
  end;

implementation

{ TTestSkillRunner }

procedure TTestSkillRunner.TestAdd_IncreasesCount;
var
  LRunner: TSimpleSkillRunner;
begin
  LRunner := TSimpleSkillRunner.New;
  try
    CheckEquals(0, LRunner.Count, 'Should start empty');
    LRunner.Add(TSkillLog.New);
    CheckEquals(1, LRunner.Count, 'Should have 1 skill');
    LRunner.Add(TSkillLog.New('prefix', srAfterUpdate));
    CheckEquals(2, LRunner.Count, 'Should have 2 skills');
  finally
    FreeAndNil(LRunner);
  end;
end;

procedure TTestSkillRunner.TestRunBefore_ExecutesMatchingSkills;
var
  LRunner: TSimpleSkillRunner;
  LContext: iSimpleSkillContext;
  LExecuted: Boolean;
begin
  LExecuted := False;
  LRunner := TSimpleSkillRunner.New;
  try
    LRunner.Add(TSkillNotify.New(
      procedure(aObj: TObject)
      begin
        LExecuted := True;
      end, srBeforeInsert));

    LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
    LRunner.RunBefore(nil, LContext, srBeforeInsert);
    CheckTrue(LExecuted, 'Skill should be executed');
  finally
    FreeAndNil(LRunner);
  end;
end;

procedure TTestSkillRunner.TestRunAfter_ExecutesMatchingSkills;
var
  LRunner: TSimpleSkillRunner;
  LContext: iSimpleSkillContext;
  LExecuted: Boolean;
begin
  LExecuted := False;
  LRunner := TSimpleSkillRunner.New;
  try
    LRunner.Add(TSkillNotify.New(
      procedure(aObj: TObject)
      begin
        LExecuted := True;
      end, srAfterInsert));

    LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
    LRunner.RunAfter(nil, LContext, srAfterInsert);
    CheckTrue(LExecuted, 'Skill should be executed after');
  finally
    FreeAndNil(LRunner);
  end;
end;

procedure TTestSkillRunner.TestRunBefore_IgnoresWrongRunAt;
var
  LRunner: TSimpleSkillRunner;
  LContext: iSimpleSkillContext;
  LExecuted: Boolean;
begin
  LExecuted := False;
  LRunner := TSimpleSkillRunner.New;
  try
    LRunner.Add(TSkillNotify.New(
      procedure(aObj: TObject)
      begin
        LExecuted := True;
      end, srAfterInsert));

    LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
    LRunner.RunBefore(nil, LContext, srBeforeInsert);
    CheckFalse(LExecuted, 'Skill with wrong RunAt should be ignored');
  finally
    FreeAndNil(LRunner);
  end;
end;

{ TTestSkillLog }

procedure TTestSkillLog.TestLog_ExecutesWithoutError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillLog.New('Test');
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Log skill should execute without error');
end;

procedure TTestSkillLog.TestLog_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillLog.New;
  CheckEquals('log', LSkill.Name, 'Should return log');
end;

procedure TTestSkillLog.TestLog_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillLog.New('', srAfterUpdate);
  CheckTrue(LSkill.RunAt = srAfterUpdate, 'Should return configured RunAt');
end;

{ TTestSkillNotify }

procedure TTestSkillNotify.TestNotify_CallsCallback;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LCalled: Boolean;
begin
  LCalled := False;
  LSkill := TSkillNotify.New(
    procedure(aObj: TObject)
    begin
      LCalled := True;
    end);
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(LCalled, 'Callback should be called');
end;

procedure TTestSkillNotify.TestNotify_NilCallback_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillNotify.New(nil);
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Nil callback should not raise error');
end;

{ TTestSkillContext }

procedure TTestSkillContext.TestContext_ReturnsValues;
var
  LContext: iSimpleSkillContext;
begin
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
  CheckEquals('PEDIDO', LContext.EntityName, 'Should return entity name');
  CheckEquals('INSERT', LContext.Operation, 'Should return operation');
  CheckNull(LContext.Query, 'Query should be nil');
  CheckNull(LContext.AIClient, 'AIClient should be nil');
end;

initialization
  RegisterTest('Skills', TTestSkillRunner.Suite);
  RegisterTest('Skills', TTestSkillLog.Suite);
  RegisterTest('Skills', TTestSkillNotify.Suite);
  RegisterTest('Skills', TTestSkillContext.Suite);

end.
