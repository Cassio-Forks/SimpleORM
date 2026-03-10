program SimpleORMErpSkills;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  SimpleAttributes in '..\..\src\SimpleAttributes.pas',
  SimpleRTTIHelper in '..\..\src\SimpleRTTIHelper.pas',
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleValidator in '..\..\src\SimpleValidator.pas',
  SimpleSkill in '..\..\src\SimpleSkill.pas',
  SimpleLogger in '..\..\src\SimpleLogger.pas',
  SimpleSerializer in '..\..\src\SimpleSerializer.pas',
  SimpleAIAttributes in '..\..\src\SimpleAIAttributes.pas';

type
  { Entidade com CPF e CNPJ }
  [Tabela('PESSOA')]
  TPessoa = class
  private
    FID: Integer;
    FNOME: String;
    FCPF: String;
    FCNPJ: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull]
    property NOME: String read FNOME write FNOME;
    [Campo('CPF'), CPF]
    property CPF: String read FCPF write FCPF;
    [Campo('CNPJ'), CNPJ]
    property CNPJ: String read FCNPJ write FCNPJ;
  end;

  { Entidade para calculo de total }
  [Tabela('ITEM_PEDIDO')]
  TItemPedido = class
  private
    FID: Integer;
    FQUANTIDADE: Double;
    FPRECO_UNITARIO: Double;
    FDESCONTO: Double;
    FVALOR_TOTAL: Double;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('QUANTIDADE')]
    property QUANTIDADE: Double read FQUANTIDADE write FQUANTIDADE;
    [Campo('PRECO_UNITARIO')]
    property PRECO_UNITARIO: Double read FPRECO_UNITARIO write FPRECO_UNITARIO;
    [Campo('DESCONTO')]
    property DESCONTO: Double read FDESCONTO write FDESCONTO;
    [Campo('VALOR_TOTAL')]
    property VALOR_TOTAL: Double read FVALOR_TOTAL write FVALOR_TOTAL;
  end;

procedure DemoCPFValidation;
var
  LPessoa: TPessoa;
  LErrors: TStringList;
begin
  Writeln('=== Validacao CPF ===');
  Writeln;

  LPessoa := TPessoa.Create;
  LErrors := TStringList.Create;
  try
    { CPF valido }
    LPessoa.NOME := 'Joao Silva';
    LPessoa.CPF := '529.982.247-25';
    TSimpleValidator.Validate(LPessoa, LErrors);
    if LErrors.Count = 0 then
      Writeln('[OK] CPF 529.982.247-25 e valido')
    else
      Writeln('[ERRO] ' + LErrors.Text);

    { CPF invalido }
    LErrors.Clear;
    LPessoa.CPF := '123.456.789-01';
    TSimpleValidator.Validate(LPessoa, LErrors);
    if LErrors.Count > 0 then
      Writeln('[OK] CPF 123.456.789-01 corretamente rejeitado: ' + LErrors[0])
    else
      Writeln('[ERRO] CPF invalido deveria ter sido rejeitado');

    { CPF com digitos iguais }
    LErrors.Clear;
    LPessoa.CPF := '111.111.111-11';
    TSimpleValidator.Validate(LPessoa, LErrors);
    if LErrors.Count > 0 then
      Writeln('[OK] CPF 111.111.111-11 corretamente rejeitado')
    else
      Writeln('[ERRO] CPF com digitos iguais deveria ter sido rejeitado');
  finally
    LErrors.Free;
    LPessoa.Free;
  end;

  Writeln;
end;

procedure DemoCNPJValidation;
var
  LPessoa: TPessoa;
  LErrors: TStringList;
begin
  Writeln('=== Validacao CNPJ ===');
  Writeln;

  LPessoa := TPessoa.Create;
  LErrors := TStringList.Create;
  try
    { CNPJ valido }
    LPessoa.NOME := 'Empresa XYZ';
    LPessoa.CNPJ := '11.222.333/0001-81';
    TSimpleValidator.Validate(LPessoa, LErrors);
    if LErrors.Count = 0 then
      Writeln('[OK] CNPJ 11.222.333/0001-81 e valido')
    else
      Writeln('[ERRO] ' + LErrors.Text);

    { CNPJ invalido }
    LErrors.Clear;
    LPessoa.CNPJ := '12.345.678/0001-99';
    TSimpleValidator.Validate(LPessoa, LErrors);
    if LErrors.Count > 0 then
      Writeln('[OK] CNPJ 12.345.678/0001-99 corretamente rejeitado: ' + LErrors[0])
    else
      Writeln('[ERRO] CNPJ invalido deveria ter sido rejeitado');
  finally
    LErrors.Free;
    LPessoa.Free;
  end;

  Writeln;
end;

procedure DemoCalcTotal;
var
  LItem: TItemPedido;
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  Writeln('=== TSkillCalcTotal ===');
  Writeln;

  LItem := TItemPedido.Create;
  try
    { Calculo com desconto }
    LItem.QUANTIDADE := 10;
    LItem.PRECO_UNITARIO := 25.50;
    LItem.DESCONTO := 5.00;

    LSkill := TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO', 'DESCONTO');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'ITEM_PEDIDO', 'INSERT');
    LSkill.Execute(LItem, LContext);

    Writeln(SysUtils.Format('Quantidade: %.0f', [LItem.QUANTIDADE]));
    Writeln(SysUtils.Format('Preco Unitario: %.2f', [LItem.PRECO_UNITARIO]));
    Writeln(SysUtils.Format('Desconto: %.2f', [LItem.DESCONTO]));
    Writeln(SysUtils.Format('Total Calculado: %.2f (esperado: 250.00)', [LItem.VALOR_TOTAL]));
    Writeln;

    { Calculo sem desconto }
    LItem.QUANTIDADE := 5;
    LItem.PRECO_UNITARIO := 10.00;
    LItem.DESCONTO := 0;
    LItem.VALOR_TOTAL := 0;

    LSkill := TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO', '');
    LSkill.Execute(LItem, LContext);

    Writeln(SysUtils.Format('Quantidade: %.0f', [LItem.QUANTIDADE]));
    Writeln(SysUtils.Format('Preco Unitario: %.2f', [LItem.PRECO_UNITARIO]));
    Writeln(SysUtils.Format('Total Calculado: %.2f (esperado: 50.00)', [LItem.VALOR_TOTAL]));
  finally
    LItem.Free;
  end;

  Writeln;
end;

begin
  try
    Writeln('SimpleORM - ERP Skills Demo');
    Writeln('===========================');
    Writeln;

    DemoCPFValidation;
    DemoCNPJValidation;
    DemoCalcTotal;

    Writeln('Nota: TSkillSequence, TSkillStockMove e TSkillDuplicate');
    Writeln('requerem conexao com banco de dados para funcionar.');
    Writeln;
    Writeln('Pressione ENTER para sair...');
    Readln;
  except
    on E: Exception do
    begin
      Writeln('Erro: ', E.Message);
      Readln;
    end;
  end;
end.
