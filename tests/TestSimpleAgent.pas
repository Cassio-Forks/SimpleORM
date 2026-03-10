unit TestSimpleAgent;

interface

uses
  TestFramework,
  System.SysUtils,
  System.Generics.Collections,
  SimpleAgent,
  SimpleSkill,
  SimpleInterface,
  SimpleAttributes,
  SimpleTypes,
  MockAIClient;

type
  [Tabela('PEDIDOS')]
  TPedidoAgentTest = class
  private
    FID: Integer;
    FVALOR: Double;
    FSTATUS: String;
    procedure SetID(const Value: Integer);
    procedure SetVALOR(const Value: Double);
    procedure SetSTATUS(const Value: String);
  public
    constructor Create;
    destructor Destroy; override;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write SetID;
    [Campo('VALOR')]
    property VALOR: Double read FVALOR write SetVALOR;
    [Campo('STATUS')]
    property STATUS: String read FSTATUS write SetSTATUS;
  end;

  TTestAgentReactive = class(TTestCase)
  published
    procedure TestReact_MatchingCondition_ExecutesSkills;
    procedure TestReact_NonMatchingCondition_SkipsSkills;
    procedure TestReact_WrongOperation_SkipsSkills;
    procedure TestReact_NilEntity_NoError;
    procedure TestReact_NoCondition_AlwaysExecutes;
  end;

  TTestAgentProactive = class(TTestCase)
  published
    procedure TestPlan_ReturnsDescription;
    procedure TestPlan_NoAIClient_RaisesError;
    procedure TestExecute_SafeMode_RaisesError;
  end;

  TTestAgentResult = class(TTestCase)
  published
    procedure TestResult_ReturnsValues;
  end;

implementation

{ TPedidoAgentTest }

constructor TPedidoAgentTest.Create;
begin
  FID := 0;
  FVALOR := 0;
  FSTATUS := '';
end;

destructor TPedidoAgentTest.Destroy;
begin
  inherited;
end;

procedure TPedidoAgentTest.SetID(const Value: Integer);
begin
  FID := Value;
end;

procedure TPedidoAgentTest.SetVALOR(const Value: Double);
begin
  FVALOR := Value;
end;

procedure TPedidoAgentTest.SetSTATUS(const Value: String);
begin
  FSTATUS := Value;
end;

{ TTestAgentReactive }

procedure TTestAgentReactive.TestReact_MatchingCondition_ExecutesSkills;
var
  LAgent: TSimpleAgent;
  LPedido: TPedidoAgentTest;
  LExecuted: Boolean;
begin
  LExecuted := False;
  LAgent := TSimpleAgent.New;
  LPedido := TPedidoAgentTest.Create;
  try
    LAgent.When(TPedidoAgentTest, aoAfterInsert)
      .Condition(function(aEntity: TObject): Boolean
        begin
          Result := TPedidoAgentTest(aEntity).VALOR > 1000;
        end)
      .Execute(TSkillNotify.New(
        procedure(aObj: TObject)
        begin
          LExecuted := True;
        end));

    LPedido.VALOR := 5000;
    LAgent.React(LPedido, aoAfterInsert);
    CheckTrue(LExecuted, 'Skills should execute when condition matches');
  finally
    FreeAndNil(LPedido);
    FreeAndNil(LAgent);
  end;
end;

procedure TTestAgentReactive.TestReact_NonMatchingCondition_SkipsSkills;
var
  LAgent: TSimpleAgent;
  LPedido: TPedidoAgentTest;
  LExecuted: Boolean;
begin
  LExecuted := False;
  LAgent := TSimpleAgent.New;
  LPedido := TPedidoAgentTest.Create;
  try
    LAgent.When(TPedidoAgentTest, aoAfterInsert)
      .Condition(function(aEntity: TObject): Boolean
        begin
          Result := TPedidoAgentTest(aEntity).VALOR > 1000;
        end)
      .Execute(TSkillNotify.New(
        procedure(aObj: TObject)
        begin
          LExecuted := True;
        end));

    LPedido.VALOR := 500;
    LAgent.React(LPedido, aoAfterInsert);
    CheckFalse(LExecuted, 'Skills should NOT execute when condition does not match');
  finally
    FreeAndNil(LPedido);
    FreeAndNil(LAgent);
  end;
end;

procedure TTestAgentReactive.TestReact_WrongOperation_SkipsSkills;
var
  LAgent: TSimpleAgent;
  LPedido: TPedidoAgentTest;
  LExecuted: Boolean;
begin
  LExecuted := False;
  LAgent := TSimpleAgent.New;
  LPedido := TPedidoAgentTest.Create;
  try
    LAgent.When(TPedidoAgentTest, aoAfterInsert)
      .Execute(TSkillNotify.New(
        procedure(aObj: TObject)
        begin
          LExecuted := True;
        end));

    LPedido.VALOR := 5000;
    LAgent.React(LPedido, aoAfterUpdate);
    CheckFalse(LExecuted, 'Skills should NOT execute for wrong operation');
  finally
    FreeAndNil(LPedido);
    FreeAndNil(LAgent);
  end;
end;

procedure TTestAgentReactive.TestReact_NilEntity_NoError;
var
  LAgent: TSimpleAgent;
begin
  LAgent := TSimpleAgent.New;
  try
    LAgent.React(nil, aoAfterInsert);
    CheckTrue(True, 'Nil entity should not raise error');
  finally
    FreeAndNil(LAgent);
  end;
end;

procedure TTestAgentReactive.TestReact_NoCondition_AlwaysExecutes;
var
  LAgent: TSimpleAgent;
  LPedido: TPedidoAgentTest;
  LExecuted: Boolean;
begin
  LExecuted := False;
  LAgent := TSimpleAgent.New;
  LPedido := TPedidoAgentTest.Create;
  try
    LAgent.When(TPedidoAgentTest, aoAfterInsert)
      .Execute(TSkillNotify.New(
        procedure(aObj: TObject)
        begin
          LExecuted := True;
        end));

    LPedido.VALOR := 1;
    LAgent.React(LPedido, aoAfterInsert);
    CheckTrue(LExecuted, 'Reaction without condition should always execute');
  finally
    FreeAndNil(LPedido);
    FreeAndNil(LAgent);
  end;
end;

{ TTestAgentProactive }

procedure TTestAgentProactive.TestPlan_ReturnsDescription;
var
  LAgent: TSimpleAgent;
  LMock: iSimpleAIClient;
  LPlan: iAgentPlan;
begin
  LMock := TSimpleAIMockClient.New('DESCRICAO: Consultar pedidos pendentes' + #10 +
    'SQL: SELECT * FROM PEDIDOS WHERE STATUS = ''PENDENTE''' + #10 +
    'STEPS: 1');
  LAgent := TSimpleAgent.New(nil, LMock);
  try
    LPlan := LAgent.Plan('Listar pedidos pendentes');
    CheckTrue(Pos('pedidos pendentes', LPlan.Description) > 0,
      'Plan should contain description');
    CheckTrue(LPlan.StepsCount > 0, 'Should have steps');
  finally
    FreeAndNil(LAgent);
  end;
end;

procedure TTestAgentProactive.TestPlan_NoAIClient_RaisesError;
var
  LAgent: TSimpleAgent;
  LRaised: Boolean;
begin
  LAgent := TSimpleAgent.New(nil, nil);
  LRaised := False;
  try
    try
      LAgent.Plan('Qualquer coisa');
    except
      on E: Exception do
        LRaised := True;
    end;
    CheckTrue(LRaised, 'Plan without AI client should raise error');
  finally
    FreeAndNil(LAgent);
  end;
end;

procedure TTestAgentProactive.TestExecute_SafeMode_RaisesError;
var
  LAgent: TSimpleAgent;
  LMock: iSimpleAIClient;
  LRaised: Boolean;
begin
  LMock := TSimpleAIMockClient.New('DESCRICAO: teste');
  LAgent := TSimpleAgent.New(nil, LMock);
  LRaised := False;
  try
    LAgent.SafeMode(True);
    try
      LAgent.Execute('Qualquer coisa');
    except
      on E: Exception do
        LRaised := True;
    end;
    CheckTrue(LRaised, 'Execute with SafeMode should raise error');
  finally
    FreeAndNil(LAgent);
  end;
end;

{ TTestAgentResult }

procedure TTestAgentResult.TestResult_ReturnsValues;
var
  LResult: iAgentResult;
begin
  LResult := TAgentResult.New('3 pedidos processados', 3, True);
  CheckEquals('3 pedidos processados', LResult.Summary);
  CheckEquals(3, LResult.StepsCount);
  CheckTrue(LResult.Success);
end;

initialization
  RegisterTest('Agent', TTestAgentReactive.Suite);
  RegisterTest('Agent', TTestAgentProactive.Suite);
  RegisterTest('Agent', TTestAgentResult.Suite);

end.
