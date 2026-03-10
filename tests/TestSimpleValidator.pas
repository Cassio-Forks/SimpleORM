unit TestSimpleValidator;

interface

uses
  TestFramework, System.Classes, SimpleValidator;

type
  TTestValidatorNotNull = class(TTestCase)
  published
    procedure TestNotNull_StringEmpty_ShouldFail;
    procedure TestNotNull_StringFilled_ShouldPass;
    procedure TestNotNull_StringWhitespace_ShouldFail;
  end;

  TTestValidatorNotZero = class(TTestCase)
  published
    procedure TestNotZero_CurrencyZero_ShouldFail;
    procedure TestNotZero_CurrencyNonZero_ShouldPass;
    procedure TestNotZero_IntegerZero_ShouldFail;
    procedure TestNotZero_IntegerNonZero_ShouldPass;
  end;

  TTestValidatorEmail = class(TTestCase)
  published
    procedure TestEmail_Valid_ShouldPass;
    procedure TestEmail_Invalid_ShouldFail;
    procedure TestEmail_Empty_ShouldPass;
    procedure TestEmail_NoAt_ShouldFail;
    procedure TestEmail_NoDomain_ShouldFail;
  end;

  TTestValidatorFormat = class(TTestCase)
  published
    procedure TestFormat_MaxSize_Exceeded_ShouldFail;
    procedure TestFormat_MaxSize_Within_ShouldPass;
    procedure TestFormat_MinSize_Below_ShouldFail;
    procedure TestFormat_MinSize_Within_ShouldPass;
  end;

  TTestValidatorMinMaxValue = class(TTestCase)
  published
    procedure TestMinValue_Below_ShouldFail;
    procedure TestMinValue_Equal_ShouldPass;
    procedure TestMinValue_Above_ShouldPass;
    procedure TestMaxValue_Above_ShouldFail;
    procedure TestMaxValue_Equal_ShouldPass;
    procedure TestMaxValue_Below_ShouldPass;
  end;

  TTestValidatorRegex = class(TTestCase)
  published
    procedure TestRegex_Match_ShouldPass;
    procedure TestRegex_NoMatch_ShouldFail;
    procedure TestRegex_Empty_ShouldPass;
    procedure TestRegex_CustomMessage;
  end;

  TTestValidatorRaise = class(TTestCase)
  published
    procedure TestValidate_WithErrors_ShouldRaise;
    procedure TestValidate_NoErrors_ShouldNotRaise;
  end;

  TTestValidatorIgnore = class(TTestCase)
  published
    procedure TestIgnoredField_NotValidated;
  end;

  TTestValidatorCPF = class(TTestCase)
  published
    procedure TestValidateCPF_Valid;
    procedure TestValidateCPF_Invalid;
    procedure TestValidateCPF_Empty_NoError;
    procedure TestValidateCPF_WithMask_Valid;
    procedure TestValidateCPF_AllSameDigits_Invalid;
  end;

  TTestValidatorCNPJ = class(TTestCase)
  published
    procedure TestValidateCNPJ_Valid;
    procedure TestValidateCNPJ_Invalid;
    procedure TestValidateCNPJ_Empty_NoError;
    procedure TestValidateCNPJ_WithMask_Valid;
    procedure TestValidateCNPJ_AllSameDigits_Invalid;
  end;

implementation

uses
  System.SysUtils, TestEntities;

{ TTestValidatorNotNull }

procedure TTestValidatorNotNull.TestNotNull_StringEmpty_ShouldFail;
var
  LCliente: TClienteTest;
  LErrors: TStringList;
begin
  LCliente := TClienteTest.Create;
  LErrors := TStringList.Create;
  try
    LCliente.NOME := '';
    LCliente.EMAIL := 'test@test.com';
    TSimpleValidator.Validate(LCliente, LErrors);
    CheckTrue(LErrors.Count > 0, 'NOME vazio deve gerar erro');
  finally
    LErrors.Free;
    LCliente.Free;
  end;
end;

procedure TTestValidatorNotNull.TestNotNull_StringFilled_ShouldPass;
var
  LCliente: TClienteTest;
  LErrors: TStringList;
begin
  LCliente := TClienteTest.Create;
  LErrors := TStringList.Create;
  try
    LCliente.NOME := 'Joao';
    LCliente.EMAIL := 'joao@test.com';
    TSimpleValidator.Validate(LCliente, LErrors);
    CheckEquals(0, LErrors.Count, 'NOME preenchido nao deve gerar erro: ' + LErrors.Text);
  finally
    LErrors.Free;
    LCliente.Free;
  end;
end;

procedure TTestValidatorNotNull.TestNotNull_StringWhitespace_ShouldFail;
var
  LCliente: TClienteTest;
  LErrors: TStringList;
begin
  LCliente := TClienteTest.Create;
  LErrors := TStringList.Create;
  try
    LCliente.NOME := '   ';
    LCliente.EMAIL := 'test@test.com';
    TSimpleValidator.Validate(LCliente, LErrors);
    CheckTrue(LErrors.Count > 0, 'NOME com espacos deve gerar erro');
  finally
    LErrors.Free;
    LCliente.Free;
  end;
end;

{ TTestValidatorNotZero }

procedure TTestValidatorNotZero.TestNotZero_CurrencyZero_ShouldFail;
var
  LPedido: TPedidoTest;
  LErrors: TStringList;
begin
  LPedido := TPedidoTest.Create;
  LErrors := TStringList.Create;
  try
    LPedido.CLIENTE := 'Teste';
    LPedido.VALORTOTAL := 0;
    TSimpleValidator.Validate(LPedido, LErrors);
    CheckTrue(LErrors.Count > 0, 'VALORTOTAL zero deve gerar erro');
  finally
    LErrors.Free;
    LPedido.Free;
  end;
end;

procedure TTestValidatorNotZero.TestNotZero_CurrencyNonZero_ShouldPass;
var
  LPedido: TPedidoTest;
  LErrors: TStringList;
begin
  LPedido := TPedidoTest.Create;
  LErrors := TStringList.Create;
  try
    LPedido.CLIENTE := 'Teste';
    LPedido.VALORTOTAL := 100.50;
    TSimpleValidator.Validate(LPedido, LErrors);
    CheckEquals(0, LErrors.Count, 'VALORTOTAL nao-zero nao deve gerar erro: ' + LErrors.Text);
  finally
    LErrors.Free;
    LPedido.Free;
  end;
end;

procedure TTestValidatorNotZero.TestNotZero_IntegerZero_ShouldFail;
var
  LItem: TItemPedidoTest;
  LErrors: TStringList;
begin
  LItem := TItemPedidoTest.Create;
  LErrors := TStringList.Create;
  try
    LItem.PEDIDO_ID := 0;
    LItem.PRODUTO_ID := 1;
    LItem.QUANTIDADE := 1;
    LItem.VALOR := 10;
    TSimpleValidator.Validate(LItem, LErrors);
    CheckTrue(LErrors.Count > 0, 'PEDIDO_ID zero deve gerar erro');
  finally
    LErrors.Free;
    LItem.Free;
  end;
end;

procedure TTestValidatorNotZero.TestNotZero_IntegerNonZero_ShouldPass;
var
  LItem: TItemPedidoTest;
  LErrors: TStringList;
begin
  LItem := TItemPedidoTest.Create;
  LErrors := TStringList.Create;
  try
    LItem.PEDIDO_ID := 1;
    LItem.PRODUTO_ID := 2;
    LItem.QUANTIDADE := 3;
    LItem.VALOR := 50;
    TSimpleValidator.Validate(LItem, LErrors);
    CheckEquals(0, LErrors.Count, 'Valores nao-zero nao devem gerar erros: ' + LErrors.Text);
  finally
    LErrors.Free;
    LItem.Free;
  end;
end;

{ TTestValidatorEmail }

procedure TTestValidatorEmail.TestEmail_Valid_ShouldPass;
var
  LCliente: TClienteTest;
  LErrors: TStringList;
begin
  LCliente := TClienteTest.Create;
  LErrors := TStringList.Create;
  try
    LCliente.NOME := 'Teste';
    LCliente.EMAIL := 'usuario@dominio.com';
    TSimpleValidator.Validate(LCliente, LErrors);
    CheckEquals(0, LErrors.Count, 'Email valido nao deve gerar erro: ' + LErrors.Text);
  finally
    LErrors.Free;
    LCliente.Free;
  end;
end;

procedure TTestValidatorEmail.TestEmail_Invalid_ShouldFail;
var
  LCliente: TClienteTest;
  LErrors: TStringList;
begin
  LCliente := TClienteTest.Create;
  LErrors := TStringList.Create;
  try
    LCliente.NOME := 'Teste';
    LCliente.EMAIL := 'email-invalido';
    TSimpleValidator.Validate(LCliente, LErrors);
    CheckTrue(LErrors.Count > 0, 'Email invalido deve gerar erro');
  finally
    LErrors.Free;
    LCliente.Free;
  end;
end;

procedure TTestValidatorEmail.TestEmail_Empty_ShouldPass;
var
  LCliente: TClienteTest;
  LErrors: TStringList;
begin
  LCliente := TClienteTest.Create;
  LErrors := TStringList.Create;
  try
    LCliente.NOME := 'Teste';
    LCliente.EMAIL := '';
    TSimpleValidator.Validate(LCliente, LErrors);
    CheckEquals(0, LErrors.Count, 'Email vazio nao deve gerar erro (nao e NotNull): ' + LErrors.Text);
  finally
    LErrors.Free;
    LCliente.Free;
  end;
end;

procedure TTestValidatorEmail.TestEmail_NoAt_ShouldFail;
var
  LCliente: TClienteTest;
  LErrors: TStringList;
begin
  LCliente := TClienteTest.Create;
  LErrors := TStringList.Create;
  try
    LCliente.NOME := 'Teste';
    LCliente.EMAIL := 'usuario.dominio.com';
    TSimpleValidator.Validate(LCliente, LErrors);
    CheckTrue(LErrors.Count > 0, 'Email sem @ deve gerar erro');
  finally
    LErrors.Free;
    LCliente.Free;
  end;
end;

procedure TTestValidatorEmail.TestEmail_NoDomain_ShouldFail;
var
  LCliente: TClienteTest;
  LErrors: TStringList;
begin
  LCliente := TClienteTest.Create;
  LErrors := TStringList.Create;
  try
    LCliente.NOME := 'Teste';
    LCliente.EMAIL := 'usuario@';
    TSimpleValidator.Validate(LCliente, LErrors);
    CheckTrue(LErrors.Count > 0, 'Email sem dominio deve gerar erro');
  finally
    LErrors.Free;
    LCliente.Free;
  end;
end;

{ TTestValidatorFormat }

procedure TTestValidatorFormat.TestFormat_MaxSize_Exceeded_ShouldFail;
var
  LProduto: TProdutoTest;
  LErrors: TStringList;
begin
  LProduto := TProdutoTest.Create;
  LErrors := TStringList.Create;
  try
    LProduto.NOME := StringOfChar('A', 101);
    LProduto.PRECO := 10;
    LProduto.CODIGO := 'AB1234';
    TSimpleValidator.Validate(LProduto, LErrors);
    CheckTrue(LErrors.Count > 0, 'NOME > 100 chars deve gerar erro');
  finally
    LErrors.Free;
    LProduto.Free;
  end;
end;

procedure TTestValidatorFormat.TestFormat_MaxSize_Within_ShouldPass;
var
  LProduto: TProdutoTest;
  LErrors: TStringList;
begin
  LProduto := TProdutoTest.Create;
  LErrors := TStringList.Create;
  try
    LProduto.NOME := 'Produto Teste';
    LProduto.PRECO := 10;
    LProduto.CODIGO := 'AB1234';
    TSimpleValidator.Validate(LProduto, LErrors);
    CheckEquals(0, LErrors.Count, 'NOME dentro do limite nao deve gerar erro: ' + LErrors.Text);
  finally
    LErrors.Free;
    LProduto.Free;
  end;
end;

procedure TTestValidatorFormat.TestFormat_MinSize_Below_ShouldFail;
var
  LProduto: TProdutoTest;
  LErrors: TStringList;
begin
  LProduto := TProdutoTest.Create;
  LErrors := TStringList.Create;
  try
    LProduto.NOME := 'AB';
    LProduto.PRECO := 10;
    LProduto.CODIGO := 'AB1234';
    TSimpleValidator.Validate(LProduto, LErrors);
    CheckTrue(LErrors.Count > 0, 'NOME < 3 chars deve gerar erro');
  finally
    LErrors.Free;
    LProduto.Free;
  end;
end;

procedure TTestValidatorFormat.TestFormat_MinSize_Within_ShouldPass;
var
  LProduto: TProdutoTest;
  LErrors: TStringList;
begin
  LProduto := TProdutoTest.Create;
  LErrors := TStringList.Create;
  try
    LProduto.NOME := 'ABC';
    LProduto.PRECO := 10;
    LProduto.CODIGO := 'AB1234';
    TSimpleValidator.Validate(LProduto, LErrors);
    CheckEquals(0, LErrors.Count, 'NOME com 3 chars nao deve gerar erro: ' + LErrors.Text);
  finally
    LErrors.Free;
    LProduto.Free;
  end;
end;

{ TTestValidatorMinMaxValue }

procedure TTestValidatorMinMaxValue.TestMinValue_Below_ShouldFail;
var
  LProduto: TProdutoTest;
  LErrors: TStringList;
begin
  LProduto := TProdutoTest.Create;
  LErrors := TStringList.Create;
  try
    LProduto.NOME := 'Produto';
    LProduto.PRECO := 0.001;
    LProduto.CODIGO := 'AB1234';
    TSimpleValidator.Validate(LProduto, LErrors);
    { PRECO com MinValue(0.01) - 0.001 esta abaixo }
    CheckTrue(LErrors.Count > 0, 'PRECO abaixo de MinValue deve gerar erro');
  finally
    LErrors.Free;
    LProduto.Free;
  end;
end;

procedure TTestValidatorMinMaxValue.TestMinValue_Equal_ShouldPass;
var
  LProduto: TProdutoTest;
  LErrors: TStringList;
begin
  LProduto := TProdutoTest.Create;
  LErrors := TStringList.Create;
  try
    LProduto.NOME := 'Produto';
    LProduto.PRECO := 0.01;
    LProduto.CODIGO := 'AB1234';
    TSimpleValidator.Validate(LProduto, LErrors);
    CheckEquals(0, LErrors.Count, 'PRECO igual a MinValue nao deve gerar erro: ' + LErrors.Text);
  finally
    LErrors.Free;
    LProduto.Free;
  end;
end;

procedure TTestValidatorMinMaxValue.TestMinValue_Above_ShouldPass;
var
  LProduto: TProdutoTest;
  LErrors: TStringList;
begin
  LProduto := TProdutoTest.Create;
  LErrors := TStringList.Create;
  try
    LProduto.NOME := 'Produto';
    LProduto.PRECO := 50;
    LProduto.CODIGO := 'AB1234';
    TSimpleValidator.Validate(LProduto, LErrors);
    CheckEquals(0, LErrors.Count, 'PRECO acima de MinValue nao deve gerar erro: ' + LErrors.Text);
  finally
    LErrors.Free;
    LProduto.Free;
  end;
end;

procedure TTestValidatorMinMaxValue.TestMaxValue_Above_ShouldFail;
var
  LProduto: TProdutoTest;
  LErrors: TStringList;
begin
  LProduto := TProdutoTest.Create;
  LErrors := TStringList.Create;
  try
    LProduto.NOME := 'Produto';
    LProduto.PRECO := 100000;
    LProduto.CODIGO := 'AB1234';
    TSimpleValidator.Validate(LProduto, LErrors);
    CheckTrue(LErrors.Count > 0, 'PRECO acima de MaxValue deve gerar erro');
  finally
    LErrors.Free;
    LProduto.Free;
  end;
end;

procedure TTestValidatorMinMaxValue.TestMaxValue_Equal_ShouldPass;
var
  LProduto: TProdutoTest;
  LErrors: TStringList;
begin
  LProduto := TProdutoTest.Create;
  LErrors := TStringList.Create;
  try
    LProduto.NOME := 'Produto';
    LProduto.PRECO := 99999.99;
    LProduto.CODIGO := 'AB1234';
    TSimpleValidator.Validate(LProduto, LErrors);
    CheckEquals(0, LErrors.Count, 'PRECO igual a MaxValue nao deve gerar erro: ' + LErrors.Text);
  finally
    LErrors.Free;
    LProduto.Free;
  end;
end;

procedure TTestValidatorMinMaxValue.TestMaxValue_Below_ShouldPass;
var
  LProduto: TProdutoTest;
  LErrors: TStringList;
begin
  LProduto := TProdutoTest.Create;
  LErrors := TStringList.Create;
  try
    LProduto.NOME := 'Produto';
    LProduto.PRECO := 500;
    LProduto.CODIGO := 'AB1234';
    TSimpleValidator.Validate(LProduto, LErrors);
    CheckEquals(0, LErrors.Count, 'PRECO abaixo de MaxValue nao deve gerar erro: ' + LErrors.Text);
  finally
    LErrors.Free;
    LProduto.Free;
  end;
end;

{ TTestValidatorRegex }

procedure TTestValidatorRegex.TestRegex_Match_ShouldPass;
var
  LProduto: TProdutoTest;
  LErrors: TStringList;
begin
  LProduto := TProdutoTest.Create;
  LErrors := TStringList.Create;
  try
    LProduto.NOME := 'Produto';
    LProduto.PRECO := 10;
    LProduto.CODIGO := 'AB1234';
    TSimpleValidator.Validate(LProduto, LErrors);
    CheckEquals(0, LErrors.Count, 'CODIGO valido nao deve gerar erro: ' + LErrors.Text);
  finally
    LErrors.Free;
    LProduto.Free;
  end;
end;

procedure TTestValidatorRegex.TestRegex_NoMatch_ShouldFail;
var
  LProduto: TProdutoTest;
  LErrors: TStringList;
begin
  LProduto := TProdutoTest.Create;
  LErrors := TStringList.Create;
  try
    LProduto.NOME := 'Produto';
    LProduto.PRECO := 10;
    LProduto.CODIGO := '12ABCD';
    TSimpleValidator.Validate(LProduto, LErrors);
    CheckTrue(LErrors.Count > 0, 'CODIGO invalido deve gerar erro');
  finally
    LErrors.Free;
    LProduto.Free;
  end;
end;

procedure TTestValidatorRegex.TestRegex_Empty_ShouldPass;
var
  LProduto: TProdutoTest;
  LErrors: TStringList;
begin
  LProduto := TProdutoTest.Create;
  LErrors := TStringList.Create;
  try
    LProduto.NOME := 'Produto';
    LProduto.PRECO := 10;
    LProduto.CODIGO := '';
    TSimpleValidator.Validate(LProduto, LErrors);
    CheckEquals(0, LErrors.Count, 'CODIGO vazio nao deve validar regex: ' + LErrors.Text);
  finally
    LErrors.Free;
    LProduto.Free;
  end;
end;

procedure TTestValidatorRegex.TestRegex_CustomMessage;
var
  LProduto: TProdutoTest;
  LErrors: TStringList;
begin
  LProduto := TProdutoTest.Create;
  LErrors := TStringList.Create;
  try
    LProduto.NOME := 'Produto';
    LProduto.PRECO := 10;
    LProduto.CODIGO := 'invalido';
    TSimpleValidator.Validate(LProduto, LErrors);
    CheckTrue(LErrors.Count > 0, 'Deve gerar erro');
    CheckTrue(Pos('2 letras + 4 digitos', LErrors.Text) > 0,
      'Deve usar mensagem customizada do Regex: ' + LErrors.Text);
  finally
    LErrors.Free;
    LProduto.Free;
  end;
end;

{ TTestValidatorRaise }

procedure TTestValidatorRaise.TestValidate_WithErrors_ShouldRaise;
var
  LCliente: TClienteTest;
begin
  LCliente := TClienteTest.Create;
  try
    LCliente.NOME := '';
    try
      TSimpleValidator.Validate(LCliente);
      Fail('Deveria ter lancado ESimpleValidator');
    except
      on E: ESimpleValidator do
        CheckTrue(True, 'ESimpleValidator lancada corretamente');
    end;
  finally
    LCliente.Free;
  end;
end;

procedure TTestValidatorRaise.TestValidate_NoErrors_ShouldNotRaise;
var
  LCliente: TClienteTest;
begin
  LCliente := TClienteTest.Create;
  try
    LCliente.NOME := 'Teste';
    LCliente.EMAIL := 'test@test.com';
    TSimpleValidator.Validate(LCliente);
    CheckTrue(True, 'Nao deveria ter lancado excecao');
  finally
    LCliente.Free;
  end;
end;

{ TTestValidatorIgnore }

procedure TTestValidatorIgnore.TestIgnoredField_NotValidated;
var
  LPedido: TPedidoTest;
  LErrors: TStringList;
begin
  LPedido := TPedidoTest.Create;
  LErrors := TStringList.Create;
  try
    LPedido.CLIENTE := 'Teste';
    LPedido.VALORTOTAL := 100;
    LPedido.OBSERVACAO := '';
    TSimpleValidator.Validate(LPedido, LErrors);
    CheckEquals(0, LErrors.Count, 'Campo Ignore nao deve ser validado: ' + LErrors.Text);
  finally
    LErrors.Free;
    LPedido.Free;
  end;
end;

{ TTestValidatorCPF }

procedure TTestValidatorCPF.TestValidateCPF_Valid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CPF := '52998224725';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckEquals(0, LErrors.Count, 'Valid CPF should pass: ' + LErrors.Text);
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestValidatorCPF.TestValidateCPF_Invalid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CPF := '12345678901';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckTrue(LErrors.Count > 0, 'Invalid CPF should fail');
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestValidatorCPF.TestValidateCPF_Empty_NoError;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CPF := '';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckEquals(0, LErrors.Count, 'Empty CPF should not validate');
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestValidatorCPF.TestValidateCPF_WithMask_Valid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CPF := '529.982.247-25';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckEquals(0, LErrors.Count, 'Masked valid CPF should pass: ' + LErrors.Text);
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestValidatorCPF.TestValidateCPF_AllSameDigits_Invalid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CPF := '11111111111';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckTrue(LErrors.Count > 0, 'All same digits CPF should fail');
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

{ TTestValidatorCNPJ }

procedure TTestValidatorCNPJ.TestValidateCNPJ_Valid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CNPJ := '11222333000181';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckEquals(0, LErrors.Count, 'Valid CNPJ should pass: ' + LErrors.Text);
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestValidatorCNPJ.TestValidateCNPJ_Invalid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CNPJ := '12345678000199';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckTrue(LErrors.Count > 0, 'Invalid CNPJ should fail');
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestValidatorCNPJ.TestValidateCNPJ_Empty_NoError;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CNPJ := '';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckEquals(0, LErrors.Count, 'Empty CNPJ should not validate');
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestValidatorCNPJ.TestValidateCNPJ_WithMask_Valid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CNPJ := '11.222.333/0001-81';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckEquals(0, LErrors.Count, 'Masked valid CNPJ should pass: ' + LErrors.Text);
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

procedure TTestValidatorCNPJ.TestValidateCNPJ_AllSameDigits_Invalid;
var
  LPessoa: TPessoaTest;
  LErrors: TStringList;
begin
  LPessoa := TPessoaTest.Create;
  LErrors := TStringList.Create;
  try
    LPessoa.NOME := 'Teste';
    LPessoa.CNPJ := '11111111111111';
    TSimpleValidator.Validate(LPessoa, LErrors);
    CheckTrue(LErrors.Count > 0, 'All same digits CNPJ should fail');
  finally
    LErrors.Free;
    LPessoa.Free;
  end;
end;

initialization
  RegisterTest('Validator.NotNull', TTestValidatorNotNull.Suite);
  RegisterTest('Validator.NotZero', TTestValidatorNotZero.Suite);
  RegisterTest('Validator.Email', TTestValidatorEmail.Suite);
  RegisterTest('Validator.Format', TTestValidatorFormat.Suite);
  RegisterTest('Validator.MinMaxValue', TTestValidatorMinMaxValue.Suite);
  RegisterTest('Validator.Regex', TTestValidatorRegex.Suite);
  RegisterTest('Validator.Raise', TTestValidatorRaise.Suite);
  RegisterTest('Validator.Ignore', TTestValidatorIgnore.Suite);
  RegisterTest('Validator.CPF', TTestValidatorCPF.Suite);
  RegisterTest('Validator.CNPJ', TTestValidatorCNPJ.Suite);

end.
