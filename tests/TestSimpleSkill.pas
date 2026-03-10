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

  TTestSkillCalcTotal = class(TTestCase)
  published
    procedure TestCalcTotal_CalculatesCorrectly;
    procedure TestCalcTotal_WithDiscount;
    procedure TestCalcTotal_WithoutDiscount;
    procedure TestCalcTotal_NilEntity_NoError;
    procedure TestCalcTotal_Name;
    procedure TestCalcTotal_RunAt;
  end;

  TTestSkillStockMove = class(TTestCase)
  published
    procedure TestStockMove_Name;
    procedure TestStockMove_RunAt;
    procedure TestStockMove_NilEntity_NoError;
    procedure TestStockMove_NilQuery_NoError;
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

{ TTestSkillCalcTotal }

procedure TTestSkillCalcTotal.TestCalcTotal_CalculatesCorrectly;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TItemCalcTest;
begin
  LEntity := TItemCalcTest.Create;
  try
    LEntity.QUANTIDADE := 10;
    LEntity.PRECO_UNITARIO := 25.50;
    LEntity.DESCONTO := 5.00;
    LSkill := TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO', 'DESCONTO');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ITEM', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals(250.00, LEntity.VALOR_TOTAL, 0.01, 'Should be 10 * 25.50 - 5.00 = 250.00');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillCalcTotal.TestCalcTotal_WithDiscount;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TItemCalcTest;
begin
  LEntity := TItemCalcTest.Create;
  try
    LEntity.QUANTIDADE := 3;
    LEntity.PRECO_UNITARIO := 100.00;
    LEntity.DESCONTO := 50.00;
    LSkill := TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO', 'DESCONTO');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ITEM', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals(250.00, LEntity.VALOR_TOTAL, 0.01, 'Should be 3 * 100 - 50 = 250');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillCalcTotal.TestCalcTotal_WithoutDiscount;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TItemCalcTest;
begin
  LEntity := TItemCalcTest.Create;
  try
    LEntity.QUANTIDADE := 5;
    LEntity.PRECO_UNITARIO := 10.00;
    LSkill := TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO', '');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ITEM', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckEquals(50.00, LEntity.VALOR_TOTAL, 0.01, 'Should be 5 * 10 = 50');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillCalcTotal.TestCalcTotal_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO');
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'ITEM', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Should not raise error for nil entity');
end;

procedure TTestSkillCalcTotal.TestCalcTotal_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO');
  CheckEquals('calc-total', LSkill.Name, 'Should return calc-total');
end;

procedure TTestSkillCalcTotal.TestCalcTotal_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO', '', srBeforeUpdate);
  CheckTrue(LSkill.RunAt = srBeforeUpdate, 'Should return configured RunAt');
end;

{ TTestSkillStockMove }

procedure TTestSkillStockMove.TestStockMove_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillStockMove.New('MOV_ESTOQUE', 'PRODUTO_ID', 'QUANTIDADE');
  CheckEquals('stock-move', LSkill.Name, 'Should return stock-move');
end;

procedure TTestSkillStockMove.TestStockMove_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillStockMove.New('MOV_ESTOQUE', 'PRODUTO_ID', 'QUANTIDADE', srAfterDelete);
  CheckTrue(LSkill.RunAt = srAfterDelete, 'Should return configured RunAt');
end;

procedure TTestSkillStockMove.TestStockMove_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillStockMove.New('MOV_ESTOQUE', 'PRODUTO_ID', 'QUANTIDADE');
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'ITEM', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Should not raise error for nil entity');
end;

procedure TTestSkillStockMove.TestStockMove_NilQuery_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TItemCalcTest;
begin
  LEntity := TItemCalcTest.Create;
  try
    LEntity.QUANTIDADE := 10;
    LSkill := TSkillStockMove.New('MOV_ESTOQUE', 'ID', 'QUANTIDADE');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ITEM', 'INSERT');
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
  RegisterTest('Skills', TTestSkillCalcTotal.Suite);
  RegisterTest('Skills', TTestSkillStockMove.Suite);

end.
