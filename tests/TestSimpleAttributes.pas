unit TestSimpleAttributes;

interface

uses
  TestFramework, SimpleAttributes;

type
  TTestSimpleAttributes = class(TTestCase)
  published
    { Tabela }
    procedure TestTabelaCreate;

    { Campo }
    procedure TestCampoCreate;

    { Flag attributes }
    procedure TestPKIsAttribute;
    procedure TestFKIsAttribute;
    procedure TestNotNullIsAttribute;
    procedure TestNotZeroIsAttribute;
    procedure TestIgnoreIsAttribute;
    procedure TestAutoIncIsAttribute;
    procedure TestNumberOnlyIsAttribute;
    procedure TestEmailIsAttribute;

    { Bind }
    procedure TestBindCreate;
    procedure TestBindSetField;

    { Display }
    procedure TestDisplayCreate;
    procedure TestDisplayWritable;

    { Format - size }
    procedure TestFormatCreateSize;
    procedure TestFormatCreateSizeAndPrecision;
    procedure TestFormatCreateMask;
    procedure TestFormatCreateRange;
    procedure TestFormatGetNumericMask;
    procedure TestFormatGetNumericMaskNoPrecision;

    { Relationships }
    procedure TestHasOneCreate;
    procedure TestHasOneCreateWithFK;
    procedure TestBelongsToCreate;
    procedure TestHasManyCreate;
    procedure TestBelongsToManyCreate;

    { SoftDelete }
    procedure TestSoftDeleteCreate;

    { Enumerator }
    procedure TestEnumeratorCreate;

    { MinValue / MaxValue }
    procedure TestMinValueCreate;
    procedure TestMaxValueCreate;

    { Regex }
    procedure TestRegexCreate;
    procedure TestRegexCreateWithMessage;
  end;

implementation

{ TTestSimpleAttributes }

procedure TTestSimpleAttributes.TestTabelaCreate;
var
  LAttr: Tabela;
begin
  LAttr := Tabela.Create('PEDIDO');
  try
    CheckEquals('PEDIDO', LAttr.Name);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestCampoCreate;
var
  LAttr: Campo;
begin
  LAttr := Campo.Create('NOME_CLIENTE');
  try
    CheckEquals('NOME_CLIENTE', LAttr.Name);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestPKIsAttribute;
var
  LAttr: PK;
begin
  LAttr := PK.Create;
  try
    CheckTrue(LAttr is TCustomAttribute);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestFKIsAttribute;
var
  LAttr: FK;
begin
  LAttr := FK.Create;
  try
    CheckTrue(LAttr is TCustomAttribute);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestNotNullIsAttribute;
var
  LAttr: NotNull;
begin
  LAttr := NotNull.Create;
  try
    CheckTrue(LAttr is TCustomAttribute);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestNotZeroIsAttribute;
var
  LAttr: NotZero;
begin
  LAttr := NotZero.Create;
  try
    CheckTrue(LAttr is TCustomAttribute);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestIgnoreIsAttribute;
var
  LAttr: Ignore;
begin
  LAttr := Ignore.Create;
  try
    CheckTrue(LAttr is TCustomAttribute);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestAutoIncIsAttribute;
var
  LAttr: AutoInc;
begin
  LAttr := AutoInc.Create;
  try
    CheckTrue(LAttr is TCustomAttribute);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestNumberOnlyIsAttribute;
var
  LAttr: NumberOnly;
begin
  LAttr := NumberOnly.Create;
  try
    CheckTrue(LAttr is TCustomAttribute);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestEmailIsAttribute;
var
  LAttr: Email;
begin
  LAttr := Email.Create;
  try
    CheckTrue(LAttr is TCustomAttribute);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestBindCreate;
var
  LAttr: Bind;
begin
  LAttr := Bind.Create('CLIENTE');
  try
    CheckEquals('CLIENTE', LAttr.Field);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestBindSetField;
var
  LAttr: Bind;
begin
  LAttr := Bind.Create('ORIGINAL');
  try
    LAttr.Field := 'ALTERADO';
    CheckEquals('ALTERADO', LAttr.Field);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestDisplayCreate;
var
  LAttr: Display;
begin
  LAttr := Display.Create('Nome Completo');
  try
    CheckEquals('Nome Completo', LAttr.Name);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestDisplayWritable;
var
  LAttr: Display;
begin
  LAttr := Display.Create('Original');
  try
    LAttr.Name := 'Alterado';
    CheckEquals('Alterado', LAttr.Name);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestFormatCreateSize;
var
  LAttr: SimpleAttributes.Format;
begin
  LAttr := SimpleAttributes.Format.Create(100);
  try
    CheckEquals(100, LAttr.MaxSize);
    CheckEquals(0, LAttr.Precision);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestFormatCreateSizeAndPrecision;
var
  LAttr: SimpleAttributes.Format;
begin
  LAttr := SimpleAttributes.Format.Create(10, 2);
  try
    CheckEquals(10, LAttr.MaxSize);
    CheckEquals(2, LAttr.Precision);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestFormatCreateMask;
var
  LAttr: SimpleAttributes.Format;
begin
  LAttr := SimpleAttributes.Format.Create('###.###.###-##');
  try
    CheckEquals('###.###.###-##', LAttr.Mask);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestFormatCreateRange;
var
  LAttr: SimpleAttributes.Format;
begin
  LAttr := SimpleAttributes.Format.Create([3, 100]);
  try
    CheckEquals(3, LAttr.MinSize);
    CheckEquals(100, LAttr.MaxSize);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestFormatGetNumericMask;
var
  LAttr: SimpleAttributes.Format;
begin
  LAttr := SimpleAttributes.Format.Create(10, 2);
  try
    CheckEquals('00000000.00', LAttr.GetNumericMask);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestFormatGetNumericMaskNoPrecision;
var
  LAttr: SimpleAttributes.Format;
begin
  LAttr := SimpleAttributes.Format.Create(5, 0);
  try
    CheckEquals('00000.', LAttr.GetNumericMask);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestHasOneCreate;
var
  LAttr: HasOne;
begin
  LAttr := HasOne.Create('TCliente');
  try
    CheckEquals('TCliente', LAttr.EntityName);
    CheckEquals('', LAttr.ForeignKey);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestHasOneCreateWithFK;
var
  LAttr: HasOne;
begin
  LAttr := HasOne.Create('TCliente', 'CLIENTE_ID');
  try
    CheckEquals('TCliente', LAttr.EntityName);
    CheckEquals('CLIENTE_ID', LAttr.ForeignKey);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestBelongsToCreate;
var
  LAttr: BelongsTo;
begin
  LAttr := BelongsTo.Create('TPedido');
  try
    CheckEquals('TPedido', LAttr.EntityName);
    CheckTrue(LAttr is Relationship);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestHasManyCreate;
var
  LAttr: HasMany;
begin
  LAttr := HasMany.Create('TItemPedido', 'PEDIDO_ID');
  try
    CheckEquals('TItemPedido', LAttr.EntityName);
    CheckEquals('PEDIDO_ID', LAttr.ForeignKey);
    CheckTrue(LAttr is Relationship);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestBelongsToManyCreate;
var
  LAttr: BelongsToMany;
begin
  LAttr := BelongsToMany.Create('TTag', 'TAG_ID');
  try
    CheckEquals('TTag', LAttr.EntityName);
    CheckEquals('TAG_ID', LAttr.ForeignKey);
    CheckTrue(LAttr is Relationship);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestSoftDeleteCreate;
var
  LAttr: SoftDelete;
begin
  LAttr := SoftDelete.Create('EXCLUIDO');
  try
    CheckEquals('EXCLUIDO', LAttr.FieldName);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestEnumeratorCreate;
var
  LAttr: Enumerator;
begin
  LAttr := Enumerator.Create('TStatusPedido');
  try
    CheckEquals('TStatusPedido', LAttr.Tipo);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestMinValueCreate;
var
  LAttr: MinValue;
begin
  LAttr := MinValue.Create(0.01);
  try
    CheckEquals(0.01, LAttr.Value, 0.001);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestMaxValueCreate;
var
  LAttr: MaxValue;
begin
  LAttr := MaxValue.Create(99999.99);
  try
    CheckEquals(99999.99, LAttr.Value, 0.001);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestRegexCreate;
var
  LAttr: Regex;
begin
  LAttr := Regex.Create('^\d{3}$');
  try
    CheckEquals('^\d{3}$', LAttr.Pattern);
    CheckEquals('', LAttr.Message);
  finally
    LAttr.Free;
  end;
end;

procedure TTestSimpleAttributes.TestRegexCreateWithMessage;
var
  LAttr: Regex;
begin
  LAttr := Regex.Create('^\d{3}$', 'Deve ter 3 digitos');
  try
    CheckEquals('^\d{3}$', LAttr.Pattern);
    CheckEquals('Deve ter 3 digitos', LAttr.Message);
  finally
    LAttr.Free;
  end;
end;

initialization
  RegisterTest(TTestSimpleAttributes.Suite);

end.
