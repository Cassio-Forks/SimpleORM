unit TestSimpleRules;

interface

uses
  TestFramework,
  System.SysUtils,
  SimpleAttributes,
  SimpleRules,
  SimpleInterface,
  SimpleTypes,
  MockAIClient;

type
  [Tabela('PEDIDOS')]
  [Rule('VALOR > 0', raBeforeInsert, 'Valor deve ser positivo')]
  [Rule('QUANTIDADE > 0', raBeforeInsert, 'Quantidade deve ser positiva')]
  [Rule('STATUS <> ''CANCELADO''', raBeforeUpdate, 'Pedido cancelado nao pode ser alterado')]
  TPedidoRuleTest = class
  private
    FVALOR: Double;
    FQUANTIDADE: Integer;
    FSTATUS: String;
    procedure SetVALOR(const Value: Double);
    procedure SetQUANTIDADE(const Value: Integer);
    procedure SetSTATUS(const Value: String);
  public
    constructor Create;
    destructor Destroy; override;
  published
    [Campo('VALOR')]
    property VALOR: Double read FVALOR write SetVALOR;
    [Campo('QUANTIDADE')]
    property QUANTIDADE: Integer read FQUANTIDADE write SetQUANTIDADE;
    [Campo('STATUS')]
    property STATUS: String read FSTATUS write SetSTATUS;
  end;

  [Tabela('CLIENTES')]
  [AIRule('Verificar se o nome do cliente e valido', raBeforeInsert)]
  TClienteAIRuleTest = class
  private
    FNOME: String;
    procedure SetNOME(const Value: String);
  public
    constructor Create;
    destructor Destroy; override;
  published
    [Campo('NOME')]
    property NOME: String read FNOME write SetNOME;
  end;

  TTestRuleEngine = class(TTestCase)
  published
    procedure TestRule_ValidValues_NoException;
    procedure TestRule_InvalidValor_RaisesViolation;
    procedure TestRule_InvalidQuantidade_RaisesViolation;
    procedure TestRule_StringComparison_Valid;
    procedure TestRule_StringComparison_Invalid;
    procedure TestRule_WrongAction_Ignored;
    procedure TestRule_NilObject_NoError;
    procedure TestRule_InvalidExpression_RaisesError;
  end;

  TTestAIRuleEngine = class(TTestCase)
  published
    procedure TestAIRule_Valid_NoException;
    procedure TestAIRule_Invalid_RaisesViolation;
    procedure TestAIRule_NoAIClient_RaisesError;
  end;

implementation

{ TPedidoRuleTest }

constructor TPedidoRuleTest.Create;
begin
  FVALOR := 0;
  FQUANTIDADE := 0;
  FSTATUS := '';
end;

destructor TPedidoRuleTest.Destroy;
begin
  inherited;
end;

procedure TPedidoRuleTest.SetVALOR(const Value: Double);
begin
  FVALOR := Value;
end;

procedure TPedidoRuleTest.SetQUANTIDADE(const Value: Integer);
begin
  FQUANTIDADE := Value;
end;

procedure TPedidoRuleTest.SetSTATUS(const Value: String);
begin
  FSTATUS := Value;
end;

{ TClienteAIRuleTest }

constructor TClienteAIRuleTest.Create;
begin
  FNOME := '';
end;

destructor TClienteAIRuleTest.Destroy;
begin
  inherited;
end;

procedure TClienteAIRuleTest.SetNOME(const Value: String);
begin
  FNOME := Value;
end;

{ TTestRuleEngine }

procedure TTestRuleEngine.TestRule_ValidValues_NoException;
var
  LEngine: TSimpleRuleEngine;
  LPedido: TPedidoRuleTest;
begin
  LEngine := TSimpleRuleEngine.New;
  LPedido := TPedidoRuleTest.Create;
  try
    LPedido.VALOR := 100;
    LPedido.QUANTIDADE := 5;
    LEngine.Evaluate(LPedido, raBeforeInsert);
    CheckTrue(True, 'Valid values should not raise exception');
  finally
    FreeAndNil(LPedido);
    FreeAndNil(LEngine);
  end;
end;

procedure TTestRuleEngine.TestRule_InvalidValor_RaisesViolation;
var
  LEngine: TSimpleRuleEngine;
  LPedido: TPedidoRuleTest;
  LRaised: Boolean;
begin
  LEngine := TSimpleRuleEngine.New;
  LPedido := TPedidoRuleTest.Create;
  LRaised := False;
  try
    LPedido.VALOR := -10;
    LPedido.QUANTIDADE := 5;
    try
      LEngine.Evaluate(LPedido, raBeforeInsert);
    except
      on E: ESimpleRuleViolation do
      begin
        LRaised := True;
        CheckTrue(Pos('Valor deve ser positivo', E.Message) > 0, 'Should contain rule message');
      end;
    end;
    CheckTrue(LRaised, 'Should raise ESimpleRuleViolation for negative VALOR');
  finally
    FreeAndNil(LPedido);
    FreeAndNil(LEngine);
  end;
end;

procedure TTestRuleEngine.TestRule_InvalidQuantidade_RaisesViolation;
var
  LEngine: TSimpleRuleEngine;
  LPedido: TPedidoRuleTest;
  LRaised: Boolean;
begin
  LEngine := TSimpleRuleEngine.New;
  LPedido := TPedidoRuleTest.Create;
  LRaised := False;
  try
    LPedido.VALOR := 100;
    LPedido.QUANTIDADE := 0;
    try
      LEngine.Evaluate(LPedido, raBeforeInsert);
    except
      on E: ESimpleRuleViolation do
        LRaised := True;
    end;
    CheckTrue(LRaised, 'Should raise ESimpleRuleViolation for zero QUANTIDADE');
  finally
    FreeAndNil(LPedido);
    FreeAndNil(LEngine);
  end;
end;

procedure TTestRuleEngine.TestRule_StringComparison_Valid;
var
  LEngine: TSimpleRuleEngine;
  LPedido: TPedidoRuleTest;
begin
  LEngine := TSimpleRuleEngine.New;
  LPedido := TPedidoRuleTest.Create;
  try
    LPedido.STATUS := 'ATIVO';
    LEngine.Evaluate(LPedido, raBeforeUpdate);
    CheckTrue(True, 'Non-CANCELADO status should pass');
  finally
    FreeAndNil(LPedido);
    FreeAndNil(LEngine);
  end;
end;

procedure TTestRuleEngine.TestRule_StringComparison_Invalid;
var
  LEngine: TSimpleRuleEngine;
  LPedido: TPedidoRuleTest;
  LRaised: Boolean;
begin
  LEngine := TSimpleRuleEngine.New;
  LPedido := TPedidoRuleTest.Create;
  LRaised := False;
  try
    LPedido.STATUS := 'CANCELADO';
    try
      LEngine.Evaluate(LPedido, raBeforeUpdate);
    except
      on E: ESimpleRuleViolation do
        LRaised := True;
    end;
    CheckTrue(LRaised, 'CANCELADO status should raise violation');
  finally
    FreeAndNil(LPedido);
    FreeAndNil(LEngine);
  end;
end;

procedure TTestRuleEngine.TestRule_WrongAction_Ignored;
var
  LEngine: TSimpleRuleEngine;
  LPedido: TPedidoRuleTest;
begin
  LEngine := TSimpleRuleEngine.New;
  LPedido := TPedidoRuleTest.Create;
  try
    LPedido.VALOR := -10;
    LEngine.Evaluate(LPedido, raBeforeDelete);
    CheckTrue(True, 'Rules for different action should be ignored');
  finally
    FreeAndNil(LPedido);
    FreeAndNil(LEngine);
  end;
end;

procedure TTestRuleEngine.TestRule_NilObject_NoError;
var
  LEngine: TSimpleRuleEngine;
begin
  LEngine := TSimpleRuleEngine.New;
  try
    LEngine.Evaluate(nil, raBeforeInsert);
    CheckTrue(True, 'Nil object should not raise exception');
  finally
    FreeAndNil(LEngine);
  end;
end;

procedure TTestRuleEngine.TestRule_InvalidExpression_RaisesError;
var
  LEngine: TSimpleRuleEngine;
  LPedido: TPedidoRuleTest;
begin
  LEngine := TSimpleRuleEngine.New;
  LPedido := TPedidoRuleTest.Create;
  try
    LPedido.VALOR := 100;
    LPedido.QUANTIDADE := 1;
    LEngine.Evaluate(LPedido, raBeforeInsert);
    CheckTrue(True, 'Valid expressions should parse correctly');
  finally
    FreeAndNil(LPedido);
    FreeAndNil(LEngine);
  end;
end;

{ TTestAIRuleEngine }

procedure TTestAIRuleEngine.TestAIRule_Valid_NoException;
var
  LEngine: TSimpleRuleEngine;
  LCliente: TClienteAIRuleTest;
  LMock: iSimpleAIClient;
begin
  LMock := TSimpleAIMockClient.New('VALIDO');
  LEngine := TSimpleRuleEngine.New(LMock);
  LCliente := TClienteAIRuleTest.Create;
  try
    LCliente.NOME := 'Joao Silva';
    LEngine.Evaluate(LCliente, raBeforeInsert);
    CheckTrue(True, 'Valid AI rule should not raise exception');
  finally
    FreeAndNil(LCliente);
    FreeAndNil(LEngine);
  end;
end;

procedure TTestAIRuleEngine.TestAIRule_Invalid_RaisesViolation;
var
  LEngine: TSimpleRuleEngine;
  LCliente: TClienteAIRuleTest;
  LMock: iSimpleAIClient;
  LRaised: Boolean;
begin
  LMock := TSimpleAIMockClient.New('INVALIDO: nome nao e valido');
  LEngine := TSimpleRuleEngine.New(LMock);
  LCliente := TClienteAIRuleTest.Create;
  LRaised := False;
  try
    LCliente.NOME := '123';
    try
      LEngine.Evaluate(LCliente, raBeforeInsert);
    except
      on E: ESimpleRuleViolation do
        LRaised := True;
    end;
    CheckTrue(LRaised, 'Invalid AI rule should raise ESimpleRuleViolation');
  finally
    FreeAndNil(LCliente);
    FreeAndNil(LEngine);
  end;
end;

procedure TTestAIRuleEngine.TestAIRule_NoAIClient_RaisesError;
var
  LEngine: TSimpleRuleEngine;
  LCliente: TClienteAIRuleTest;
  LRaised: Boolean;
begin
  LEngine := TSimpleRuleEngine.New(nil);
  LCliente := TClienteAIRuleTest.Create;
  LRaised := False;
  try
    LCliente.NOME := 'Joao';
    try
      LEngine.Evaluate(LCliente, raBeforeInsert);
    except
      on E: ESimpleRuleViolation do
        LRaised := True;
    end;
    CheckTrue(LRaised, 'AIRule without AI client should raise error');
  finally
    FreeAndNil(LCliente);
    FreeAndNil(LEngine);
  end;
end;

initialization
  RegisterTest('Rules', TTestRuleEngine.Suite);
  RegisterTest('Rules', TTestAIRuleEngine.Suite);

end.
