unit TestSimpleRTTIHelper;

interface

uses
  TestFramework, System.Rtti, SimpleAttributes, SimpleRTTIHelper;

type
  TTestRttiPropertyHelper = class(TTestCase)
  private
    FContext: TRttiContext;
    FType: TRttiType;
  protected
    procedure SetUp; override;
  published
    { Attribute detection on TPedidoTest }
    procedure TestIsNotNull_ClienteProperty;
    procedure TestIsNotNull_IDProperty;
    procedure TestIsNotZero_ValorTotalProperty;
    procedure TestIsIgnore_ObservacaoProperty;
    procedure TestIsAutoInc_IDProperty;
    procedure TestEhChavePrimaria_IDProperty;
    procedure TestEhChavePrimaria_ClienteProperty;
    procedure TestEhCampo_ClienteProperty;

    { FieldName }
    procedure TestFieldName_WithCampoAttribute;
    procedure TestFieldName_WithoutCampoAttribute;

    { DisplayName }
    procedure TestDisplayName_WithDisplayAttribute;
    procedure TestDisplayName_WithoutDisplayAttribute;

    { EhPermitidoNulo }
    procedure TestEhPermitidoNulo_NotNullField;
    procedure TestEhPermitidoNulo_NullableField;

    { FK }
    procedure TestEhChaveEstrangeira;

    { Email }
    procedure TestIsEmail;

    { Validation attribute checkers }
    procedure TestHasMinValue;
    procedure TestHasMaxValue;
    procedure TestHasRegex;
    procedure TestHasFormat;

    { Relationship }
    procedure TestIsHasOne;
    procedure TestIsBelongsTo;

    { Timestamps }
    procedure TestIsCreatedAt_WithAttribute_ShouldReturnTrue;
    procedure TestIsCreatedAt_WithoutAttribute_ShouldReturnFalse;
    procedure TestIsUpdatedAt_WithAttribute_ShouldReturnTrue;
    procedure TestIsUpdatedAt_WithoutAttribute_ShouldReturnFalse;
  end;

  TTestRttiTypeHelper = class(TTestCase)
  private
    FContext: TRttiContext;
  published
    procedure TestIsTabela;
    procedure TestIsSoftDelete;
    procedure TestIsSoftDelete_NotSoftDelete;
    procedure TestGetSoftDeleteField;
    procedure TestGetSoftDeleteField_Empty;
    procedure TestGetPKField;
  end;

  TTestValueHelper = class(TTestCase)
  published
    procedure TestAsStringNumberOnly;
    procedure TestAsStringNumberOnly_Empty;
    procedure TestAsStringNumberOnly_NoDigits;
    procedure TestAsStringNumberOnly_AllDigits;
  end;

implementation

uses
  TestEntities;

{ TTestRttiPropertyHelper }

procedure TTestRttiPropertyHelper.SetUp;
begin
  FContext := TRttiContext.Create;
  FType := FContext.GetType(TPedidoTest);
end;

procedure TTestRttiPropertyHelper.TestIsNotNull_ClienteProperty;
var
  LProp: TRttiProperty;
begin
  LProp := FType.GetProperty('CLIENTE');
  CheckTrue(LProp.IsNotNull, 'CLIENTE deve ser NotNull');
end;

procedure TTestRttiPropertyHelper.TestIsNotNull_IDProperty;
var
  LProp: TRttiProperty;
begin
  LProp := FType.GetProperty('ID');
  CheckFalse(LProp.IsNotNull, 'ID nao deve ser NotNull');
end;

procedure TTestRttiPropertyHelper.TestIsNotZero_ValorTotalProperty;
var
  LProp: TRttiProperty;
begin
  LProp := FType.GetProperty('VALORTOTAL');
  CheckTrue(LProp.IsNotZero, 'VALORTOTAL deve ser NotZero');
end;

procedure TTestRttiPropertyHelper.TestIsIgnore_ObservacaoProperty;
var
  LProp: TRttiProperty;
begin
  LProp := FType.GetProperty('OBSERVACAO');
  CheckTrue(LProp.IsIgnore, 'OBSERVACAO deve ser Ignore');
end;

procedure TTestRttiPropertyHelper.TestIsAutoInc_IDProperty;
var
  LProp: TRttiProperty;
begin
  LProp := FType.GetProperty('ID');
  CheckTrue(LProp.IsAutoInc, 'ID deve ser AutoInc');
end;

procedure TTestRttiPropertyHelper.TestEhChavePrimaria_IDProperty;
var
  LProp: TRttiProperty;
begin
  LProp := FType.GetProperty('ID');
  CheckTrue(LProp.EhChavePrimaria, 'ID deve ser ChavePrimaria');
end;

procedure TTestRttiPropertyHelper.TestEhChavePrimaria_ClienteProperty;
var
  LProp: TRttiProperty;
begin
  LProp := FType.GetProperty('CLIENTE');
  CheckFalse(LProp.EhChavePrimaria, 'CLIENTE nao deve ser ChavePrimaria');
end;

procedure TTestRttiPropertyHelper.TestEhCampo_ClienteProperty;
var
  LProp: TRttiProperty;
begin
  LProp := FType.GetProperty('CLIENTE');
  CheckTrue(LProp.EhCampo, 'CLIENTE deve ter atributo Campo');
end;

procedure TTestRttiPropertyHelper.TestFieldName_WithCampoAttribute;
var
  LProp: TRttiProperty;
begin
  LProp := FType.GetProperty('CLIENTE');
  CheckEquals('CLIENTE', LProp.FieldName, 'FieldName deve retornar o valor de Campo');
end;

procedure TTestRttiPropertyHelper.TestFieldName_WithoutCampoAttribute;
var
  LTypeCat: TRttiType;
  LProp: TRttiProperty;
begin
  LTypeCat := FContext.GetType(TCategoriaTest);
  LProp := LTypeCat.GetProperty('NOME');
  CheckEquals('NOME', LProp.FieldName, 'FieldName sem Campo deve retornar nome da property');
end;

procedure TTestRttiPropertyHelper.TestDisplayName_WithDisplayAttribute;
var
  LTypeUsr: TRttiType;
  LProp: TRttiProperty;
begin
  LTypeUsr := FContext.GetType(TUsuarioTest);
  LProp := LTypeUsr.GetProperty('NOME');
  CheckEquals('Nome Completo', LProp.DisplayName, 'DisplayName deve retornar valor de Display');
end;

procedure TTestRttiPropertyHelper.TestDisplayName_WithoutDisplayAttribute;
var
  LProp: TRttiProperty;
begin
  LProp := FType.GetProperty('CLIENTE');
  CheckEquals('CLIENTE', LProp.DisplayName, 'DisplayName sem Display deve retornar nome da property');
end;

procedure TTestRttiPropertyHelper.TestEhPermitidoNulo_NotNullField;
var
  LProp: TRttiProperty;
begin
  LProp := FType.GetProperty('CLIENTE');
  CheckFalse(LProp.EhPermitidoNulo, 'CLIENTE NotNull: EhPermitidoNulo deve ser False');
end;

procedure TTestRttiPropertyHelper.TestEhPermitidoNulo_NullableField;
var
  LProp: TRttiProperty;
begin
  LProp := FType.GetProperty('DATAPEDIDO');
  CheckTrue(LProp.EhPermitidoNulo, 'DATAPEDIDO sem NotNull: EhPermitidoNulo deve ser True');
end;

procedure TTestRttiPropertyHelper.TestEhChaveEstrangeira;
var
  LTypeItem: TRttiType;
  LProp: TRttiProperty;
begin
  LTypeItem := FContext.GetType(TItemPedidoTest);
  LProp := LTypeItem.GetProperty('PEDIDO_ID');
  CheckTrue(LProp.EhChaveEstrangeira, 'PEDIDO_ID deve ser FK');
end;

procedure TTestRttiPropertyHelper.TestIsEmail;
var
  LTypeCli: TRttiType;
  LProp: TRttiProperty;
begin
  LTypeCli := FContext.GetType(TClienteTest);
  LProp := LTypeCli.GetProperty('EMAIL');
  CheckTrue(LProp.IsEmail, 'EMAIL deve ter atributo Email');
end;

procedure TTestRttiPropertyHelper.TestHasMinValue;
var
  LTypeProd: TRttiType;
  LProp: TRttiProperty;
begin
  LTypeProd := FContext.GetType(TProdutoTest);
  LProp := LTypeProd.GetProperty('PRECO');
  CheckTrue(LProp.HasMinValue, 'PRECO deve ter MinValue');
end;

procedure TTestRttiPropertyHelper.TestHasMaxValue;
var
  LTypeProd: TRttiType;
  LProp: TRttiProperty;
begin
  LTypeProd := FContext.GetType(TProdutoTest);
  LProp := LTypeProd.GetProperty('PRECO');
  CheckTrue(LProp.HasMaxValue, 'PRECO deve ter MaxValue');
end;

procedure TTestRttiPropertyHelper.TestHasRegex;
var
  LTypeProd: TRttiType;
  LProp: TRttiProperty;
begin
  LTypeProd := FContext.GetType(TProdutoTest);
  LProp := LTypeProd.GetProperty('CODIGO');
  CheckTrue(LProp.HasRegex, 'CODIGO deve ter Regex');
end;

procedure TTestRttiPropertyHelper.TestHasFormat;
var
  LTypeProd: TRttiType;
  LProp: TRttiProperty;
begin
  LTypeProd := FContext.GetType(TProdutoTest);
  LProp := LTypeProd.GetProperty('NOME');
  CheckTrue(LProp.HasFormat, 'NOME deve ter Format');
end;

procedure TTestRttiPropertyHelper.TestIsHasOne;
var
  LProp: TRttiProperty;
begin
  LProp := FType.GetProperty('ID');
  CheckFalse(LProp.IsHasOne, 'ID nao deve ser HasOne');
end;

procedure TTestRttiPropertyHelper.TestIsBelongsTo;
var
  LProp: TRttiProperty;
begin
  LProp := FType.GetProperty('CLIENTE');
  CheckFalse(LProp.IsBelongsTo, 'CLIENTE nao deve ser BelongsTo');
end;

procedure TTestRttiPropertyHelper.TestIsCreatedAt_WithAttribute_ShouldReturnTrue;
var
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  LType := FContext.GetType(TTestTimestampEntity);
  LProp := LType.GetProperty('DataCriacao');
  CheckTrue(LProp.IsCreatedAt, 'DataCriacao deve ter atributo CreatedAt');
end;

procedure TTestRttiPropertyHelper.TestIsCreatedAt_WithoutAttribute_ShouldReturnFalse;
var
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  LType := FContext.GetType(TTestTimestampEntity);
  LProp := LType.GetProperty('Nome');
  CheckFalse(LProp.IsCreatedAt, 'Nome nao deve ter atributo CreatedAt');
end;

procedure TTestRttiPropertyHelper.TestIsUpdatedAt_WithAttribute_ShouldReturnTrue;
var
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  LType := FContext.GetType(TTestTimestampEntity);
  LProp := LType.GetProperty('DataAtualizacao');
  CheckTrue(LProp.IsUpdatedAt, 'DataAtualizacao deve ter atributo UpdatedAt');
end;

procedure TTestRttiPropertyHelper.TestIsUpdatedAt_WithoutAttribute_ShouldReturnFalse;
var
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  LType := FContext.GetType(TTestTimestampEntity);
  LProp := LType.GetProperty('Nome');
  CheckFalse(LProp.IsUpdatedAt, 'Nome nao deve ter atributo UpdatedAt');
end;

{ TTestRttiTypeHelper }

procedure TTestRttiTypeHelper.TestIsTabela;
var
  LType: TRttiType;
begin
  FContext := TRttiContext.Create;
  LType := FContext.GetType(TPedidoTest);
  CheckTrue(LType.IsTabela, 'TPedidoTest deve ter atributo Tabela');
end;

procedure TTestRttiTypeHelper.TestIsSoftDelete;
var
  LType: TRttiType;
begin
  FContext := TRttiContext.Create;
  LType := FContext.GetType(TClienteTest);
  CheckTrue(LType.IsSoftDelete, 'TClienteTest deve ter SoftDelete');
end;

procedure TTestRttiTypeHelper.TestIsSoftDelete_NotSoftDelete;
var
  LType: TRttiType;
begin
  FContext := TRttiContext.Create;
  LType := FContext.GetType(TPedidoTest);
  CheckFalse(LType.IsSoftDelete, 'TPedidoTest nao deve ter SoftDelete');
end;

procedure TTestRttiTypeHelper.TestGetSoftDeleteField;
var
  LType: TRttiType;
begin
  FContext := TRttiContext.Create;
  LType := FContext.GetType(TClienteTest);
  CheckEquals('EXCLUIDO', LType.GetSoftDeleteField, 'SoftDeleteField deve ser EXCLUIDO');
end;

procedure TTestRttiTypeHelper.TestGetSoftDeleteField_Empty;
var
  LType: TRttiType;
begin
  FContext := TRttiContext.Create;
  LType := FContext.GetType(TPedidoTest);
  CheckEquals('', LType.GetSoftDeleteField, 'SoftDeleteField deve ser vazio');
end;

procedure TTestRttiTypeHelper.TestGetPKField;
var
  LType: TRttiType;
  LProp: TRttiProperty;
begin
  FContext := TRttiContext.Create;
  LType := FContext.GetType(TPedidoTest);
  LProp := LType.GetPKField;
  CheckNotNull(LProp, 'PKField nao deve ser nil');
  CheckEquals('ID', LProp.Name, 'PKField deve ser ID');
end;

{ TTestValueHelper }

procedure TTestValueHelper.TestAsStringNumberOnly;
var
  LValue: TValue;
begin
  LValue := TValue.From<string>('(11) 9876-5432');
  CheckEquals('1198765432', LValue.AsStringNumberOnly);
end;

procedure TTestValueHelper.TestAsStringNumberOnly_Empty;
var
  LValue: TValue;
begin
  LValue := TValue.From<string>('');
  CheckEquals('', LValue.AsStringNumberOnly);
end;

procedure TTestValueHelper.TestAsStringNumberOnly_NoDigits;
var
  LValue: TValue;
begin
  LValue := TValue.From<string>('abc-def');
  CheckEquals('', LValue.AsStringNumberOnly);
end;

procedure TTestValueHelper.TestAsStringNumberOnly_AllDigits;
var
  LValue: TValue;
begin
  LValue := TValue.From<string>('12345');
  CheckEquals('12345', LValue.AsStringNumberOnly);
end;

initialization
  RegisterTest('RTTI.PropertyHelper', TTestRttiPropertyHelper.Suite);
  RegisterTest('RTTI.TypeHelper', TTestRttiTypeHelper.Suite);
  RegisterTest('RTTI.ValueHelper', TTestValueHelper.Suite);

end.
