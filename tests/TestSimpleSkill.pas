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

  TTestSkillTimestamp = class(TTestCase)
  published
    procedure TestTimestamp_SetsPropertyValue;
    procedure TestTimestamp_IgnoresMissingProperty;
    procedure TestTimestamp_Name;
    procedure TestTimestamp_RunAt;
  end;

  TTestSkillGuardDelete = class(TTestCase)
  published
    procedure TestGuardDelete_Name;
    procedure TestGuardDelete_RunAtIsAlwaysBeforeDelete;
    procedure TestGuardDelete_NilEntity_NoError;
    procedure TestGuardDelete_NilQuery_NoError;
  end;

  TTestSkillHistory = class(TTestCase)
  published
    procedure TestHistory_Name;
    procedure TestHistory_RunAt;
    procedure TestHistory_NilEntity_NoError;
    procedure TestHistory_NilQuery_NoError;
  end;

  TTestSkillValidate = class(TTestCase)
  published
    procedure TestValidate_ValidEntity_NoError;
    procedure TestValidate_InvalidEntity_RaisesException;
    procedure TestValidate_NilEntity_NoError;
    procedure TestValidate_Name;
    procedure TestValidate_RunAt;
  end;

  TTestSkillWebhook = class(TTestCase)
  published
    procedure TestWebhook_Name;
    procedure TestWebhook_RunAt;
    procedure TestWebhook_NilEntity_NoError;
    procedure TestWebhook_InvalidURL_NoError;
  end;

  TTestSkillSequence = class(TTestCase)
  published
    procedure TestSequence_Name;
    procedure TestSequence_RunAtIsAlwaysBeforeInsert;
    procedure TestSequence_NilEntity_NoError;
    procedure TestSequence_NilQuery_NoError;
  end;

implementation

uses
  TestEntities,
  SimpleValidator;

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

{ TTestSkillTimestamp }

procedure TTestSkillTimestamp.TestTimestamp_SetsPropertyValue;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TTestTimestampEntity;
begin
  LEntity := TTestTimestampEntity.Create;
  try
    LSkill := TSkillTimestamp.New('DataCriacao', srBeforeInsert);
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ENTITY_TIMESTAMPS', 'INSERT');
    CheckEquals(0, LEntity.DataCriacao, 'Should start at zero');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(LEntity.DataCriacao > 0, 'Should have set datetime value');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillTimestamp.TestTimestamp_IgnoresMissingProperty;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TTestTimestampEntity;
begin
  LEntity := TTestTimestampEntity.Create;
  try
    LSkill := TSkillTimestamp.New('CAMPO_INEXISTENTE', srBeforeInsert);
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Should not raise error for missing property');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillTimestamp.TestTimestamp_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillTimestamp.New('DataCriacao');
  CheckEquals('timestamp', LSkill.Name, 'Should return timestamp');
end;

procedure TTestSkillTimestamp.TestTimestamp_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillTimestamp.New('DataAtualizacao', srBeforeUpdate);
  CheckTrue(LSkill.RunAt = srBeforeUpdate, 'Should return configured RunAt');
end;

{ TTestSkillGuardDelete }

procedure TTestSkillGuardDelete.TestGuardDelete_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillGuardDelete.New('ITEM_PEDIDO', 'ID_PEDIDO');
  CheckEquals('guard-delete', LSkill.Name, 'Should return guard-delete');
end;

procedure TTestSkillGuardDelete.TestGuardDelete_RunAtIsAlwaysBeforeDelete;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillGuardDelete.New('ITEM_PEDIDO', 'ID_PEDIDO');
  CheckTrue(LSkill.RunAt = srBeforeDelete, 'Should always be srBeforeDelete');
end;

procedure TTestSkillGuardDelete.TestGuardDelete_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillGuardDelete.New('ITEM_PEDIDO', 'ID_PEDIDO');
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'DELETE');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Should not raise error for nil entity');
end;

procedure TTestSkillGuardDelete.TestGuardDelete_NilQuery_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
begin
  LEntity := TPedidoTest.Create;
  try
    LEntity.ID := 1;
    LSkill := TSkillGuardDelete.New('ITEM_PEDIDO', 'ID_PEDIDO');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'DELETE');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Should not raise error when query is nil');
  finally
    LEntity.Free;
  end;
end;

{ TTestSkillHistory }

procedure TTestSkillHistory.TestHistory_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillHistory.New;
  CheckEquals('history', LSkill.Name, 'Should return history');
end;

procedure TTestSkillHistory.TestHistory_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillHistory.New('ENTITY_HISTORY', srBeforeDelete);
  CheckTrue(LSkill.RunAt = srBeforeDelete, 'Should return configured RunAt');
end;

procedure TTestSkillHistory.TestHistory_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillHistory.New;
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'UPDATE');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Should not raise error for nil entity');
end;

procedure TTestSkillHistory.TestHistory_NilQuery_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
begin
  LEntity := TPedidoTest.Create;
  try
    LSkill := TSkillHistory.New;
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'UPDATE');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Should not raise error when query is nil');
  finally
    LEntity.Free;
  end;
end;

{ TTestSkillValidate }

procedure TTestSkillValidate.TestValidate_ValidEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
begin
  LEntity := TPedidoTest.Create;
  try
    LEntity.CLIENTE := 'Joao';
    LEntity.VALORTOTAL := 100;
    LSkill := TSkillValidate.New(srBeforeInsert);
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Valid entity should not raise');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillValidate.TestValidate_InvalidEntity_RaisesException;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
  LRaised: Boolean;
begin
  LEntity := TPedidoTest.Create;
  try
    LEntity.CLIENTE := '';
    LEntity.VALORTOTAL := 0;
    LSkill := TSkillValidate.New(srBeforeInsert);
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
    LRaised := False;
    try
      LSkill.Execute(LEntity, LContext);
    except
      on E: ESimpleValidator do
        LRaised := True;
    end;
    CheckTrue(LRaised, 'Invalid entity should raise ESimpleValidator');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillValidate.TestValidate_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillValidate.New;
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Nil entity should not raise');
end;

procedure TTestSkillValidate.TestValidate_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillValidate.New;
  CheckEquals('validate', LSkill.Name, 'Should return validate');
end;

procedure TTestSkillValidate.TestValidate_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillValidate.New(srBeforeUpdate);
  CheckTrue(LSkill.RunAt = srBeforeUpdate, 'Should return configured RunAt');
end;

{ TTestSkillWebhook }

procedure TTestSkillWebhook.TestWebhook_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillWebhook.New('http://localhost:9999/hooks');
  CheckEquals('webhook', LSkill.Name, 'Should return webhook');
end;

procedure TTestSkillWebhook.TestWebhook_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillWebhook.New('http://localhost:9999/hooks', srAfterUpdate);
  CheckTrue(LSkill.RunAt = srAfterUpdate, 'Should return configured RunAt');
end;

procedure TTestSkillWebhook.TestWebhook_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillWebhook.New('http://localhost:9999/hooks');
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Nil entity should not raise');
end;

procedure TTestSkillWebhook.TestWebhook_InvalidURL_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
begin
  LEntity := TPedidoTest.Create;
  try
    LEntity.ID := 1;
    LEntity.CLIENTE := 'Teste';
    LEntity.VALORTOTAL := 100;
    LSkill := TSkillWebhook.New('http://invalid-host-that-does-not-exist:9999/hooks');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Invalid URL should not raise (fire-and-forget)');
  finally
    LEntity.Free;
  end;
end;

{ TTestSkillSequence }

procedure TTestSkillSequence.TestSequence_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillSequence.New('NUMERO', 'NUMERACAO', 'PEDIDO');
  CheckEquals('sequence', LSkill.Name, 'Should return sequence');
end;

procedure TTestSkillSequence.TestSequence_RunAtIsAlwaysBeforeInsert;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillSequence.New('NUMERO', 'NUMERACAO', 'PEDIDO');
  CheckTrue(LSkill.RunAt = srBeforeInsert, 'Should always be srBeforeInsert');
end;

procedure TTestSkillSequence.TestSequence_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillSequence.New('NUMERO', 'NUMERACAO', 'PEDIDO');
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Should not raise error for nil entity');
end;

procedure TTestSkillSequence.TestSequence_NilQuery_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
begin
  LEntity := TPedidoTest.Create;
  try
    LSkill := TSkillSequence.New('NUMERO', 'NUMERACAO', 'PEDIDO');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Should not raise error when query is nil');
  finally
    LEntity.Free;
  end;
end;

initialization
  RegisterTest('Skills', TTestSkillRunner.Suite);
  RegisterTest('Skills', TTestSkillLog.Suite);
  RegisterTest('Skills', TTestSkillNotify.Suite);
  RegisterTest('Skills', TTestSkillContext.Suite);
  RegisterTest('Skills', TTestSkillTimestamp.Suite);
  RegisterTest('Skills', TTestSkillGuardDelete.Suite);
  RegisterTest('Skills', TTestSkillHistory.Suite);
  RegisterTest('Skills', TTestSkillValidate.Suite);
  RegisterTest('Skills', TTestSkillWebhook.Suite);
  RegisterTest('Skills', TTestSkillSequence.Suite);

end.
