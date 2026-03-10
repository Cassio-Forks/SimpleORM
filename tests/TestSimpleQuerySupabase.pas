unit TestSimpleQuerySupabase;

interface

uses
  TestFramework, SimpleInterface, SimpleQuerySupabase, SimpleTypes,
  System.Classes, Data.DB, System.Variants;

type
  { Testable subclass that exposes protected methods }
  TSimpleQuerySupabaseTestable = class(TSimpleQuerySupabase)
  public
    function TestExtractTableName(const aSQL: string): string;
    function TestDetectOperation(const aSQL: string): string;
    function TestExtractPKFieldName(const aSQL: string): string;
    function TestExtractInsertFields(const aSQL: string): TArray<string>;
    function TestExtractSelectFields(const aSQL: string): string;
    function TestExtractPagination(const aSQL: string; out aSkip, aTake: Integer): Boolean;
    function TestExtractUpdateFields(const aSQL: string): TArray<string>;
    function TestBuildSupabaseURL(const aTableName: string): string;
    function TestExtractWhereFilters(const aSQL: string): string;
    function TestParamsToJSON: string; overload;
    function TestParamsToJSON(const aFields: TArray<string>): string; overload;
  end;

  { Test Class 1: SQL Parser tests }
  TTestQuerySupabaseSQLParser = class(TTestCase)
  private
    FQuery: TSimpleQuerySupabaseTestable;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestExtractTableName_Select;
    procedure TestExtractTableName_Insert;
    procedure TestExtractTableName_Update;
    procedure TestExtractTableName_Delete;
    procedure TestDetectOperation_Insert;
    procedure TestDetectOperation_Update;
    procedure TestDetectOperation_Delete;
    procedure TestDetectOperation_Select;
    procedure TestExtractInsertFields_MultipleFields;
    procedure TestExtractSelectFields_Star;
    procedure TestExtractSelectFields_SpecificFields;
    procedure TestExtractPagination_LimitOffset;
    procedure TestExtractPagination_FirstSkip;
    procedure TestExtractPagination_NoPagination;
    procedure TestExtractUpdateFields;
    procedure TestBuildSupabaseURL;
    procedure TestExtractPKFieldName_WithWhere;
    procedure TestExtractPKFieldName_NoWhere;
    procedure TestExtractWhereFilters_SingleCondition;
    procedure TestExtractWhereFilters_NoWhere;
    procedure TestExtractWhereFilters_MultipleConditions;
    procedure TestParamsToJSON_StringValue;
    procedure TestParamsToJSON_IntegerValue;
    procedure TestParamsToJSON_WithFieldFilter;
  end;

  { Test Class 2: iSimpleQuery contract tests }
  TTestQuerySupabaseContract = class(TTestCase)
  published
    procedure TestNew_ReturnsInterface;
    procedure TestNew_WithToken_ReturnsInterface;
    procedure TestSQL_ReturnsTStrings;
    procedure TestParams_ReturnsTParams;
    procedure TestDataSet_ReturnsTDataSet;
    procedure TestStartTransaction_ReturnsSelf;
    procedure TestCommit_ReturnsSelf;
    procedure TestRollback_ReturnsSelf;
    procedure TestEndTransaction_ReturnsSelf;
    procedure TestInTransaction_ReturnsFalse;
    procedure TestSQLType_ReturnsMySQL;
    procedure TestRowsAffected_ReturnsMinusOne;
    procedure TestToken_SetAndReturnsSelf;
  end;

  { Test Class 3: Params JSON tests }
  TTestQuerySupabaseJSON = class(TTestCase)
  published
    procedure TestParams_StringParam;
    procedure TestParams_IntegerParam;
    procedure TestParams_FloatParam;
    procedure TestParams_NullParam;
    procedure TestParams_MultipleParams;
  end;

implementation

uses
  System.SysUtils;

{ TSimpleQuerySupabaseTestable }

function TSimpleQuerySupabaseTestable.TestExtractTableName(const aSQL: string): string;
begin
  Result := ExtractTableName(aSQL);
end;

function TSimpleQuerySupabaseTestable.TestDetectOperation(const aSQL: string): string;
begin
  Result := DetectOperation(aSQL);
end;

function TSimpleQuerySupabaseTestable.TestExtractPKFieldName(const aSQL: string): string;
begin
  Result := ExtractPKFieldName(aSQL);
end;

function TSimpleQuerySupabaseTestable.TestExtractInsertFields(const aSQL: string): TArray<string>;
begin
  Result := ExtractInsertFields(aSQL);
end;

function TSimpleQuerySupabaseTestable.TestExtractSelectFields(const aSQL: string): string;
begin
  Result := ExtractSelectFields(aSQL);
end;

function TSimpleQuerySupabaseTestable.TestExtractPagination(const aSQL: string; out aSkip, aTake: Integer): Boolean;
begin
  Result := ExtractPagination(aSQL, aSkip, aTake);
end;

function TSimpleQuerySupabaseTestable.TestExtractUpdateFields(const aSQL: string): TArray<string>;
begin
  Result := ExtractUpdateFields(aSQL);
end;

function TSimpleQuerySupabaseTestable.TestBuildSupabaseURL(const aTableName: string): string;
begin
  Result := BuildSupabaseURL(aTableName);
end;

function TSimpleQuerySupabaseTestable.TestExtractWhereFilters(const aSQL: string): string;
begin
  Result := ExtractWhereFilters(aSQL);
end;

function TSimpleQuerySupabaseTestable.TestParamsToJSON: string;
begin
  Result := ParamsToJSON;
end;

function TSimpleQuerySupabaseTestable.TestParamsToJSON(const aFields: TArray<string>): string;
begin
  Result := ParamsToJSON(aFields);
end;

{ TTestQuerySupabaseSQLParser }

procedure TTestQuerySupabaseSQLParser.SetUp;
begin
  inherited;
  FQuery := TSimpleQuerySupabaseTestable.Create('https://example.supabase.co', 'test-api-key');
end;

procedure TTestQuerySupabaseSQLParser.TearDown;
begin
  FreeAndNil(FQuery);
  inherited;
end;

procedure TTestQuerySupabaseSQLParser.TestExtractTableName_Select;
begin
  CheckEquals('PRODUTO', FQuery.TestExtractTableName('SELECT ID, NOME FROM PRODUTO'),
    'Deve extrair tabela de SELECT');
end;

procedure TTestQuerySupabaseSQLParser.TestExtractTableName_Insert;
begin
  CheckEquals('PRODUTO', FQuery.TestExtractTableName('INSERT INTO PRODUTO (NOME) VALUES (:NOME)'),
    'Deve extrair tabela de INSERT');
end;

procedure TTestQuerySupabaseSQLParser.TestExtractTableName_Update;
begin
  CheckEquals('PRODUTO', FQuery.TestExtractTableName('UPDATE PRODUTO SET NOME = :NOME'),
    'Deve extrair tabela de UPDATE');
end;

procedure TTestQuerySupabaseSQLParser.TestExtractTableName_Delete;
begin
  CheckEquals('PRODUTO', FQuery.TestExtractTableName('DELETE FROM PRODUTO WHERE ID = :ID'),
    'Deve extrair tabela de DELETE');
end;

procedure TTestQuerySupabaseSQLParser.TestDetectOperation_Insert;
begin
  CheckEquals('INSERT', FQuery.TestDetectOperation('INSERT INTO PRODUTO (NOME) VALUES (:NOME)'),
    'Deve detectar INSERT');
end;

procedure TTestQuerySupabaseSQLParser.TestDetectOperation_Update;
begin
  CheckEquals('UPDATE', FQuery.TestDetectOperation('UPDATE PRODUTO SET NOME = :NOME'),
    'Deve detectar UPDATE');
end;

procedure TTestQuerySupabaseSQLParser.TestDetectOperation_Delete;
begin
  CheckEquals('DELETE', FQuery.TestDetectOperation('DELETE FROM PRODUTO WHERE ID = :ID'),
    'Deve detectar DELETE');
end;

procedure TTestQuerySupabaseSQLParser.TestDetectOperation_Select;
begin
  CheckEquals('SELECT', FQuery.TestDetectOperation('SELECT * FROM PRODUTO'),
    'Deve detectar SELECT');
end;

procedure TTestQuerySupabaseSQLParser.TestExtractInsertFields_MultipleFields;
var
  LFields: TArray<string>;
begin
  LFields := FQuery.TestExtractInsertFields('INSERT INTO PRODUTO (NOME, PRECO, QUANTIDADE) VALUES (:NOME, :PRECO, :QUANTIDADE)');
  CheckEquals(3, Length(LFields), 'Deve extrair 3 campos');
  CheckEquals('NOME', LFields[0], 'Primeiro campo deve ser NOME');
  CheckEquals('PRECO', LFields[1], 'Segundo campo deve ser PRECO');
  CheckEquals('QUANTIDADE', LFields[2], 'Terceiro campo deve ser QUANTIDADE');
end;

procedure TTestQuerySupabaseSQLParser.TestExtractSelectFields_Star;
begin
  CheckEquals('*', FQuery.TestExtractSelectFields('SELECT * FROM PRODUTO'),
    'Deve retornar * para select all');
end;

procedure TTestQuerySupabaseSQLParser.TestExtractSelectFields_SpecificFields;
var
  LResult: string;
begin
  LResult := FQuery.TestExtractSelectFields('SELECT ID, NOME, PRECO FROM PRODUTO');
  CheckTrue(Pos('id', LResult) > 0, 'Deve conter id em lowercase: ' + LResult);
  CheckTrue(Pos('nome', LResult) > 0, 'Deve conter nome em lowercase: ' + LResult);
  CheckTrue(Pos('preco', LResult) > 0, 'Deve conter preco em lowercase: ' + LResult);
end;

procedure TTestQuerySupabaseSQLParser.TestExtractPagination_LimitOffset;
var
  LSkip, LTake: Integer;
  LResult: Boolean;
begin
  LResult := FQuery.TestExtractPagination('SELECT * FROM PRODUTO LIMIT 10 OFFSET 20', LSkip, LTake);
  CheckTrue(LResult, 'Deve detectar paginacao LIMIT/OFFSET');
  CheckEquals(10, LTake, 'Take deve ser 10');
  CheckEquals(20, LSkip, 'Skip deve ser 20');
end;

procedure TTestQuerySupabaseSQLParser.TestExtractPagination_FirstSkip;
var
  LSkip, LTake: Integer;
  LResult: Boolean;
begin
  LResult := FQuery.TestExtractPagination('SELECT FIRST 5 SKIP 10 ID, NOME FROM PRODUTO', LSkip, LTake);
  CheckTrue(LResult, 'Deve detectar paginacao FIRST/SKIP');
  CheckEquals(5, LTake, 'Take deve ser 5');
  CheckEquals(10, LSkip, 'Skip deve ser 10');
end;

procedure TTestQuerySupabaseSQLParser.TestExtractPagination_NoPagination;
var
  LSkip, LTake: Integer;
  LResult: Boolean;
begin
  LResult := FQuery.TestExtractPagination('SELECT * FROM PRODUTO WHERE ID > 0', LSkip, LTake);
  CheckFalse(LResult, 'Nao deve detectar paginacao');
end;

procedure TTestQuerySupabaseSQLParser.TestExtractUpdateFields;
var
  LFields: TArray<string>;
begin
  LFields := FQuery.TestExtractUpdateFields('UPDATE PRODUTO SET NOME = :NOME, PRECO = :PRECO WHERE ID = :ID');
  CheckEquals(2, Length(LFields), 'Deve extrair 2 campos de UPDATE');
  CheckEquals('NOME', LFields[0], 'Primeiro campo deve ser NOME');
  CheckEquals('PRECO', LFields[1], 'Segundo campo deve ser PRECO');
end;

procedure TTestQuerySupabaseSQLParser.TestBuildSupabaseURL;
var
  LURL: string;
begin
  LURL := FQuery.TestBuildSupabaseURL('PRODUTO');
  CheckTrue(Pos('/rest/v1/produto', LURL) > 0, 'URL deve conter /rest/v1/produto: ' + LURL);
  CheckTrue(LURL.StartsWith('https://example.supabase.co'), 'URL deve comecar com base URL: ' + LURL);
end;

procedure TTestQuerySupabaseSQLParser.TestExtractPKFieldName_WithWhere;
begin
  CheckEquals('ID', FQuery.TestExtractPKFieldName('DELETE FROM PRODUTO WHERE ID = :ID'),
    'Deve extrair campo PK do WHERE');
end;

procedure TTestQuerySupabaseSQLParser.TestExtractPKFieldName_NoWhere;
begin
  CheckEquals('', FQuery.TestExtractPKFieldName('SELECT * FROM PRODUTO'),
    'Deve retornar vazio sem WHERE');
end;

procedure TTestQuerySupabaseSQLParser.TestExtractWhereFilters_SingleCondition;
var
  LResult: string;
  LParam: TParam;
begin
  LParam := FQuery.Params.AddParameter;
  LParam.Name := 'ID';
  LParam.DataType := ftInteger;
  LParam.Value := 42;

  LResult := FQuery.TestExtractWhereFilters('DELETE FROM PRODUTO WHERE ID = :ID');
  CheckTrue(Pos('id=eq.42', LResult) > 0, 'Deve gerar filtro id=eq.42: ' + LResult);
end;

procedure TTestQuerySupabaseSQLParser.TestExtractWhereFilters_NoWhere;
var
  LResult: string;
begin
  LResult := FQuery.TestExtractWhereFilters('SELECT * FROM PRODUTO');
  CheckEquals('', LResult, 'Deve retornar vazio sem WHERE');
end;

procedure TTestQuerySupabaseSQLParser.TestExtractWhereFilters_MultipleConditions;
var
  LResult: string;
  LParam: TParam;
begin
  LParam := FQuery.Params.AddParameter;
  LParam.Name := 'NOME';
  LParam.DataType := ftString;
  LParam.Value := 'Teste';

  LParam := FQuery.Params.AddParameter;
  LParam.Name := 'ATIVO';
  LParam.DataType := ftInteger;
  LParam.Value := 1;

  LResult := FQuery.TestExtractWhereFilters('SELECT * FROM PRODUTO WHERE NOME = :NOME and ATIVO = :ATIVO');
  CheckTrue(Pos('nome=eq.Teste', LResult) > 0, 'Deve conter filtro nome: ' + LResult);
  CheckTrue(Pos('ativo=eq.1', LResult) > 0, 'Deve conter filtro ativo: ' + LResult);
end;

procedure TTestQuerySupabaseSQLParser.TestParamsToJSON_StringValue;
var
  LResult: string;
  LParam: TParam;
begin
  LParam := FQuery.Params.AddParameter;
  LParam.Name := 'NOME';
  LParam.DataType := ftString;
  LParam.Value := 'Produto Teste';

  LResult := FQuery.TestParamsToJSON;
  CheckTrue(Pos('"nome"', LResult) > 0, 'JSON deve conter chave nome: ' + LResult);
  CheckTrue(Pos('Produto Teste', LResult) > 0, 'JSON deve conter valor: ' + LResult);
end;

procedure TTestQuerySupabaseSQLParser.TestParamsToJSON_IntegerValue;
var
  LResult: string;
  LParam: TParam;
begin
  LParam := FQuery.Params.AddParameter;
  LParam.Name := 'ID';
  LParam.DataType := ftInteger;
  LParam.Value := 99;

  LResult := FQuery.TestParamsToJSON;
  CheckTrue(Pos('"id"', LResult) > 0, 'JSON deve conter chave id: ' + LResult);
  CheckTrue(Pos('99', LResult) > 0, 'JSON deve conter valor 99: ' + LResult);
end;

procedure TTestQuerySupabaseSQLParser.TestParamsToJSON_WithFieldFilter;
var
  LResult: string;
  LParam: TParam;
  LFields: TArray<string>;
begin
  LParam := FQuery.Params.AddParameter;
  LParam.Name := 'NOME';
  LParam.DataType := ftString;
  LParam.Value := 'Teste';

  LParam := FQuery.Params.AddParameter;
  LParam.Name := 'PRECO';
  LParam.DataType := ftFloat;
  LParam.Value := 10.5;

  LParam := FQuery.Params.AddParameter;
  LParam.Name := 'ID';
  LParam.DataType := ftInteger;
  LParam.Value := 1;

  LFields := TArray<string>.Create('NOME', 'PRECO');
  LResult := FQuery.TestParamsToJSON(LFields);
  CheckTrue(Pos('"nome"', LResult) > 0, 'JSON deve conter nome: ' + LResult);
  CheckTrue(Pos('"preco"', LResult) > 0, 'JSON deve conter preco: ' + LResult);
  CheckFalse(Pos('"id"', LResult) > 0, 'JSON NAO deve conter id (filtrado): ' + LResult);
end;

{ TTestQuerySupabaseContract }

procedure TTestQuerySupabaseContract.TestNew_ReturnsInterface;
var
  LQuery: iSimpleQuery;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  CheckNotNull(LQuery, 'New deve retornar interface nao-nula');
end;

procedure TTestQuerySupabaseContract.TestNew_WithToken_ReturnsInterface;
var
  LQuery: iSimpleQuery;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key', 'test-token');
  CheckNotNull(LQuery, 'New com token deve retornar interface nao-nula');
end;

procedure TTestQuerySupabaseContract.TestSQL_ReturnsTStrings;
var
  LQuery: iSimpleQuery;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  CheckNotNull(LQuery.SQL, 'SQL deve retornar TStrings nao-nulo');
  CheckTrue(LQuery.SQL is TStrings, 'SQL deve ser TStrings');
end;

procedure TTestQuerySupabaseContract.TestParams_ReturnsTParams;
var
  LQuery: iSimpleQuery;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  CheckNotNull(LQuery.Params, 'Params deve retornar TParams nao-nulo');
  CheckTrue(LQuery.Params is TParams, 'Params deve ser TParams');
end;

procedure TTestQuerySupabaseContract.TestDataSet_ReturnsTDataSet;
var
  LQuery: iSimpleQuery;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  CheckNotNull(LQuery.DataSet, 'DataSet deve retornar TDataSet nao-nulo');
  CheckTrue(LQuery.DataSet is TDataSet, 'DataSet deve ser TDataSet');
end;

procedure TTestQuerySupabaseContract.TestStartTransaction_ReturnsSelf;
var
  LQuery: iSimpleQuery;
  LResult: iSimpleQuery;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  LResult := LQuery.StartTransaction;
  CheckTrue(LResult = LQuery, 'StartTransaction deve retornar Self');
end;

procedure TTestQuerySupabaseContract.TestCommit_ReturnsSelf;
var
  LQuery: iSimpleQuery;
  LResult: iSimpleQuery;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  LResult := LQuery.Commit;
  CheckTrue(LResult = LQuery, 'Commit deve retornar Self');
end;

procedure TTestQuerySupabaseContract.TestRollback_ReturnsSelf;
var
  LQuery: iSimpleQuery;
  LResult: iSimpleQuery;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  LResult := LQuery.Rollback;
  CheckTrue(LResult = LQuery, 'Rollback deve retornar Self');
end;

procedure TTestQuerySupabaseContract.TestEndTransaction_ReturnsSelf;
var
  LQuery: iSimpleQuery;
  LResult: iSimpleQuery;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  LResult := LQuery.&EndTransaction;
  CheckTrue(LResult = LQuery, 'EndTransaction deve retornar Self');
end;

procedure TTestQuerySupabaseContract.TestInTransaction_ReturnsFalse;
var
  LQuery: iSimpleQuery;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  CheckFalse(LQuery.InTransaction, 'InTransaction deve retornar False (REST stateless)');
end;

procedure TTestQuerySupabaseContract.TestSQLType_ReturnsMySQL;
var
  LQuery: iSimpleQuery;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  CheckTrue(LQuery.SQLType = TSQLType.MySQL, 'SQLType deve retornar MySQL');
end;

procedure TTestQuerySupabaseContract.TestRowsAffected_ReturnsMinusOne;
var
  LQuery: iSimpleQuery;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  CheckEquals(-1, LQuery.RowsAffected, 'RowsAffected deve retornar -1');
end;

procedure TTestQuerySupabaseContract.TestToken_SetAndReturnsSelf;
var
  LQuery: iSimpleQuery;
  LResult: iSimpleQuery;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  LResult := (LQuery as TSimpleQuerySupabase).Token('new-token');
  CheckTrue(LResult = LQuery, 'Token deve retornar Self');
end;

{ TTestQuerySupabaseJSON }

procedure TTestQuerySupabaseJSON.TestParams_StringParam;
var
  LQuery: iSimpleQuery;
  LParam: TParam;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  LParam := LQuery.Params.AddParameter;
  LParam.Name := 'NOME';
  LParam.DataType := ftString;
  LParam.Value := 'Produto Teste';
  CheckEquals('Produto Teste', LQuery.Params.ParamByName('NOME').AsString,
    'Param string deve manter o valor');
end;

procedure TTestQuerySupabaseJSON.TestParams_IntegerParam;
var
  LQuery: iSimpleQuery;
  LParam: TParam;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  LParam := LQuery.Params.AddParameter;
  LParam.Name := 'ID';
  LParam.DataType := ftInteger;
  LParam.Value := 42;
  CheckEquals(42, LQuery.Params.ParamByName('ID').AsInteger,
    'Param integer deve manter o valor');
end;

procedure TTestQuerySupabaseJSON.TestParams_FloatParam;
var
  LQuery: iSimpleQuery;
  LParam: TParam;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  LParam := LQuery.Params.AddParameter;
  LParam.Name := 'PRECO';
  LParam.DataType := ftFloat;
  LParam.Value := 99.99;
  CheckTrue(Abs(LQuery.Params.ParamByName('PRECO').AsFloat - 99.99) < 0.001,
    'Param float deve manter o valor');
end;

procedure TTestQuerySupabaseJSON.TestParams_NullParam;
var
  LQuery: iSimpleQuery;
  LParam: TParam;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');
  LParam := LQuery.Params.AddParameter;
  LParam.Name := 'DESCRICAO';
  LParam.DataType := ftString;
  LParam.Value := Null;
  CheckTrue(VarIsNull(LQuery.Params.ParamByName('DESCRICAO').Value),
    'Param null deve manter valor nulo');
end;

procedure TTestQuerySupabaseJSON.TestParams_MultipleParams;
var
  LQuery: iSimpleQuery;
  LParam: TParam;
begin
  LQuery := TSimpleQuerySupabase.New('https://example.supabase.co', 'test-key');

  LParam := LQuery.Params.AddParameter;
  LParam.Name := 'ID';
  LParam.DataType := ftInteger;
  LParam.Value := 1;

  LParam := LQuery.Params.AddParameter;
  LParam.Name := 'NOME';
  LParam.DataType := ftString;
  LParam.Value := 'Teste';

  LParam := LQuery.Params.AddParameter;
  LParam.Name := 'PRECO';
  LParam.DataType := ftFloat;
  LParam.Value := 10.5;

  CheckEquals(3, LQuery.Params.Count, 'Deve ter 3 parametros');
end;

initialization
  RegisterTest('SimpleQuerySupabase.SQLParser', TTestQuerySupabaseSQLParser.Suite);
  RegisterTest('SimpleQuerySupabase.Contract', TTestQuerySupabaseContract.Suite);
  RegisterTest('SimpleQuerySupabase.JSON', TTestQuerySupabaseJSON.Suite);

end.
