unit TestSimpleSerializer;

interface

uses
  TestFramework, System.JSON, System.Generics.Collections, SimpleSerializer;

type
  TTestEntityToJSON = class(TTestCase)
  published
    procedure TestEntityToJSON_StringField;
    procedure TestEntityToJSON_IntegerField;
    procedure TestEntityToJSON_FloatField;
    procedure TestEntityToJSON_IgnoredField_Excluded;
    procedure TestEntityToJSON_OnlyCampoFields;
    procedure TestEntityToJSON_FieldNamesFromCampo;
  end;

  TTestJSONToEntity = class(TTestCase)
  published
    procedure TestJSONToEntity_AllFields;
    procedure TestJSONToEntity_MissingField;
    procedure TestJSONToEntity_IgnoredField_Skipped;
  end;

  TTestEntityListSerialization = class(TTestCase)
  published
    procedure TestEntityListToJSONArray;
    procedure TestEntityListToJSONArray_Empty;
    procedure TestJSONArrayToEntityList;
    procedure TestRoundTrip_EntityListJSON;
  end;

implementation

uses
  System.SysUtils, System.DateUtils, TestEntities;

{ TTestEntityToJSON }

procedure TTestEntityToJSON.TestEntityToJSON_StringField;
var
  LPedido: TPedidoTest;
  LJSON: TJSONObject;
begin
  LPedido := TPedidoTest.Create;
  try
    LPedido.CLIENTE := 'Joao Silva';
    LJSON := TSimpleSerializer.EntityToJSON<TPedidoTest>(LPedido);
    try
      CheckEquals('Joao Silva', LJSON.GetValue<string>('CLIENTE'));
    finally
      LJSON.Free;
    end;
  finally
    LPedido.Free;
  end;
end;

procedure TTestEntityToJSON.TestEntityToJSON_IntegerField;
var
  LPedido: TPedidoTest;
  LJSON: TJSONObject;
begin
  LPedido := TPedidoTest.Create;
  try
    LPedido.ID := 42;
    LJSON := TSimpleSerializer.EntityToJSON<TPedidoTest>(LPedido);
    try
      CheckEquals(42, LJSON.GetValue<Integer>('ID'));
    finally
      LJSON.Free;
    end;
  finally
    LPedido.Free;
  end;
end;

procedure TTestEntityToJSON.TestEntityToJSON_FloatField;
var
  LPedido: TPedidoTest;
  LJSON: TJSONObject;
begin
  LPedido := TPedidoTest.Create;
  try
    LPedido.VALORTOTAL := 199.99;
    LJSON := TSimpleSerializer.EntityToJSON<TPedidoTest>(LPedido);
    try
      CheckTrue(Abs(199.99 - LJSON.GetValue<Double>('VALOR_TOTAL')) < 0.01,
        'VALOR_TOTAL deve ser 199.99');
    finally
      LJSON.Free;
    end;
  finally
    LPedido.Free;
  end;
end;

procedure TTestEntityToJSON.TestEntityToJSON_IgnoredField_Excluded;
var
  LPedido: TPedidoTest;
  LJSON: TJSONObject;
begin
  LPedido := TPedidoTest.Create;
  try
    LPedido.OBSERVACAO := 'Nota importante';
    LPedido.CLIENTE := 'Test';
    LJSON := TSimpleSerializer.EntityToJSON<TPedidoTest>(LPedido);
    try
      CheckNull(LJSON.FindValue('OBSERVACAO'), 'Campo Ignore nao deve estar no JSON');
    finally
      LJSON.Free;
    end;
  finally
    LPedido.Free;
  end;
end;

procedure TTestEntityToJSON.TestEntityToJSON_OnlyCampoFields;
var
  LCategoria: TCategoriaTest;
  LJSON: TJSONObject;
begin
  LCategoria := TCategoriaTest.Create;
  try
    LCategoria.ID := 1;
    LCategoria.NOME := 'Eletronicos';
    LCategoria.ATIVO := 1;
    LJSON := TSimpleSerializer.EntityToJSON<TCategoriaTest>(LCategoria);
    try
      { TCategoriaTest nao tem [Campo] nas properties, serializer deve pular }
      CheckEquals(0, LJSON.Count, 'Sem [Campo] nenhuma property deve ser serializada');
    finally
      LJSON.Free;
    end;
  finally
    LCategoria.Free;
  end;
end;

procedure TTestEntityToJSON.TestEntityToJSON_FieldNamesFromCampo;
var
  LPedido: TPedidoTest;
  LJSON: TJSONObject;
begin
  LPedido := TPedidoTest.Create;
  try
    LPedido.DATAPEDIDO := EncodeDate(2026, 1, 15);
    LPedido.CLIENTE := 'Test';
    LJSON := TSimpleSerializer.EntityToJSON<TPedidoTest>(LPedido);
    try
      { O nome no JSON deve ser DATA_PEDIDO (valor do Campo) e nao DATAPEDIDO (nome da property) }
      CheckNotNull(LJSON.FindValue('DATA_PEDIDO'),
        'Nome do campo JSON deve vir do atributo Campo');
    finally
      LJSON.Free;
    end;
  finally
    LPedido.Free;
  end;
end;

{ TTestJSONToEntity }

procedure TTestJSONToEntity.TestJSONToEntity_AllFields;
var
  LJSON: TJSONObject;
  LPedido: TPedidoTest;
begin
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('ID', TJSONNumber.Create(1));
    LJSON.AddPair('CLIENTE', 'Maria');
    LJSON.AddPair('VALOR_TOTAL', TJSONNumber.Create(250.50));
    LPedido := TSimpleSerializer.JSONToEntity<TPedidoTest>(LJSON);
    try
      CheckEquals(1, LPedido.ID);
      CheckEquals('Maria', LPedido.CLIENTE);
      CheckTrue(Abs(250.50 - Double(LPedido.VALORTOTAL)) < 0.01, 'VALORTOTAL deve ser 250.50');
    finally
      LPedido.Free;
    end;
  finally
    LJSON.Free;
  end;
end;

procedure TTestJSONToEntity.TestJSONToEntity_MissingField;
var
  LJSON: TJSONObject;
  LPedido: TPedidoTest;
begin
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('ID', TJSONNumber.Create(1));
    { CLIENTE ausente }
    LPedido := TSimpleSerializer.JSONToEntity<TPedidoTest>(LJSON);
    try
      CheckEquals(1, LPedido.ID);
      CheckEquals('', LPedido.CLIENTE, 'Campo ausente deve manter valor default');
    finally
      LPedido.Free;
    end;
  finally
    LJSON.Free;
  end;
end;

procedure TTestJSONToEntity.TestJSONToEntity_IgnoredField_Skipped;
var
  LJSON: TJSONObject;
  LPedido: TPedidoTest;
begin
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('ID', TJSONNumber.Create(1));
    LJSON.AddPair('CLIENTE', 'Test');
    LJSON.AddPair('OBSERVACAO', 'Nota');
    LPedido := TSimpleSerializer.JSONToEntity<TPedidoTest>(LJSON);
    try
      CheckEquals('', LPedido.OBSERVACAO, 'Campo Ignore nao deve ser populado do JSON');
    finally
      LPedido.Free;
    end;
  finally
    LJSON.Free;
  end;
end;

{ TTestEntityListSerialization }

procedure TTestEntityListSerialization.TestEntityListToJSONArray;
var
  LList: TObjectList<TPedidoTest>;
  LArray: TJSONArray;
  LPedido: TPedidoTest;
begin
  LList := TObjectList<TPedidoTest>.Create;
  try
    LPedido := TPedidoTest.Create;
    LPedido.ID := 1;
    LPedido.CLIENTE := 'Cliente 1';
    LPedido.VALORTOTAL := 100;
    LList.Add(LPedido);

    LPedido := TPedidoTest.Create;
    LPedido.ID := 2;
    LPedido.CLIENTE := 'Cliente 2';
    LPedido.VALORTOTAL := 200;
    LList.Add(LPedido);

    LArray := TSimpleSerializer.EntityListToJSONArray<TPedidoTest>(LList);
    try
      CheckEquals(2, LArray.Count, 'Array deve ter 2 elementos');
    finally
      LArray.Free;
    end;
  finally
    LList.Free;
  end;
end;

procedure TTestEntityListSerialization.TestEntityListToJSONArray_Empty;
var
  LList: TObjectList<TPedidoTest>;
  LArray: TJSONArray;
begin
  LList := TObjectList<TPedidoTest>.Create;
  try
    LArray := TSimpleSerializer.EntityListToJSONArray<TPedidoTest>(LList);
    try
      CheckEquals(0, LArray.Count, 'Array vazio deve ter 0 elementos');
    finally
      LArray.Free;
    end;
  finally
    LList.Free;
  end;
end;

procedure TTestEntityListSerialization.TestJSONArrayToEntityList;
var
  LArray: TJSONArray;
  LObj: TJSONObject;
  LList: TObjectList<TPedidoTest>;
begin
  LArray := TJSONArray.Create;
  try
    LObj := TJSONObject.Create;
    LObj.AddPair('ID', TJSONNumber.Create(1));
    LObj.AddPair('CLIENTE', 'Teste 1');
    LObj.AddPair('VALOR_TOTAL', TJSONNumber.Create(100));
    LArray.AddElement(LObj);

    LObj := TJSONObject.Create;
    LObj.AddPair('ID', TJSONNumber.Create(2));
    LObj.AddPair('CLIENTE', 'Teste 2');
    LObj.AddPair('VALOR_TOTAL', TJSONNumber.Create(200));
    LArray.AddElement(LObj);

    LList := TSimpleSerializer.JSONArrayToEntityList<TPedidoTest>(LArray);
    try
      CheckEquals(2, LList.Count, 'Lista deve ter 2 items');
      CheckEquals('Teste 1', LList[0].CLIENTE);
      CheckEquals('Teste 2', LList[1].CLIENTE);
    finally
      LList.Free;
    end;
  finally
    LArray.Free;
  end;
end;

procedure TTestEntityListSerialization.TestRoundTrip_EntityListJSON;
var
  LOriginal, LRestored: TObjectList<TPedidoTest>;
  LArray: TJSONArray;
  LPedido: TPedidoTest;
begin
  LOriginal := TObjectList<TPedidoTest>.Create;
  try
    LPedido := TPedidoTest.Create;
    LPedido.ID := 10;
    LPedido.CLIENTE := 'Round Trip';
    LPedido.VALORTOTAL := 999.99;
    LOriginal.Add(LPedido);

    LArray := TSimpleSerializer.EntityListToJSONArray<TPedidoTest>(LOriginal);
    try
      LRestored := TSimpleSerializer.JSONArrayToEntityList<TPedidoTest>(LArray);
      try
        CheckEquals(1, LRestored.Count);
        CheckEquals(10, LRestored[0].ID);
        CheckEquals('Round Trip', LRestored[0].CLIENTE);
        CheckTrue(Abs(999.99 - Double(LRestored[0].VALORTOTAL)) < 0.01);
      finally
        LRestored.Free;
      end;
    finally
      LArray.Free;
    end;
  finally
    LOriginal.Free;
  end;
end;

initialization
  RegisterTest('Serializer.EntityToJSON', TTestEntityToJSON.Suite);
  RegisterTest('Serializer.JSONToEntity', TTestJSONToEntity.Suite);
  RegisterTest('Serializer.ListSerialization', TTestEntityListSerialization.Suite);

end.
