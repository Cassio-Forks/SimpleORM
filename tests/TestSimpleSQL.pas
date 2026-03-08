unit TestSimpleSQL;

interface

uses
  TestFramework, SimpleInterface, SimpleSQL, SimpleTypes;

type
  TTestSimpleSQLInsert = class(TTestCase)
  published
    procedure TestInsertBasic;
    procedure TestInsertExcludesAutoInc;
    procedure TestInsertExcludesIgnored;
  end;

  TTestSimpleSQLUpdate = class(TTestCase)
  published
    procedure TestUpdateBasic;
    procedure TestUpdateExcludesAutoInc;
  end;

  TTestSimpleSQLDelete = class(TTestCase)
  published
    procedure TestDeleteBasic;
    procedure TestDeleteSoftDelete;
  end;

  TTestSimpleSQLSelect = class(TTestCase)
  published
    procedure TestSelectBasic;
    procedure TestSelectWithWhere;
    procedure TestSelectWithOrderBy;
    procedure TestSelectWithGroupBy;
    procedure TestSelectWithJoin;
    procedure TestSelectWithCustomFields;
    procedure TestSelectWithAllClauses;

    { Pagination - Firebird }
    procedure TestSelectPaginationFirebird;
    procedure TestSelectPaginationFirebirdSkipOnly;

    { Pagination - MySQL }
    procedure TestSelectPaginationMySQL;
    procedure TestSelectPaginationMySQLWithSkip;

    { Pagination - SQLite }
    procedure TestSelectPaginationSQLite;

    { Pagination - Oracle }
    procedure TestSelectPaginationOracle;
    procedure TestSelectPaginationOracleWithSkip;

    { SoftDelete auto-filter }
    procedure TestSelectSoftDeleteAutoFilter;
    procedure TestSelectSoftDeleteWithWhere;
  end;

  TTestSimpleSQLSelectId = class(TTestCase)
  published
    procedure TestSelectIdBasic;
  end;

  TTestSimpleSQLLastID = class(TTestCase)
  published
    procedure TestLastID;
  end;

  TTestSimpleSQLLastRecord = class(TTestCase)
  published
    procedure TestLastRecord;
  end;

implementation

uses
  System.SysUtils, TestEntities;

{ TTestSimpleSQLInsert }

procedure TTestSimpleSQLInsert.TestInsertBasic;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.Insert(LSQLStr);
    CheckTrue(Pos('INSERT INTO PEDIDO', LSQLStr) > 0, 'Deve conter INSERT INTO PEDIDO: ' + LSQLStr);
    CheckTrue(Pos('VALUES', LSQLStr) > 0, 'Deve conter VALUES: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLInsert.TestInsertExcludesAutoInc;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.Insert(LSQLStr);
    { ID e AutoInc, nao deve estar na lista de campos do INSERT }
    CheckTrue(Pos('CLIENTE', LSQLStr) > 0, 'Deve conter CLIENTE: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLInsert.TestInsertExcludesIgnored;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.Insert(LSQLStr);
    { OBSERVACAO e Ignore, nao deve estar no INSERT }
    CheckTrue(Pos('OBSERVACAO', LSQLStr) = 0, 'Nao deve conter OBSERVACAO: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

{ TTestSimpleSQLUpdate }

procedure TTestSimpleSQLUpdate.TestUpdateBasic;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.Update(LSQLStr);
    CheckTrue(Pos('UPDATE PEDIDO', LSQLStr) > 0, 'Deve conter UPDATE PEDIDO: ' + LSQLStr);
    CheckTrue(Pos('SET', LSQLStr) > 0, 'Deve conter SET: ' + LSQLStr);
    CheckTrue(Pos('WHERE', LSQLStr) > 0, 'Deve conter WHERE: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLUpdate.TestUpdateExcludesAutoInc;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
  LSetPos, LWherePos: Integer;
  LSetClause: String;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.Update(LSQLStr);
    { Extrair a clausula SET para verificar que ID nao esta nela }
    LSetPos := Pos('SET', LSQLStr);
    LWherePos := Pos('WHERE', LSQLStr);
    if (LSetPos > 0) and (LWherePos > 0) then
    begin
      LSetClause := Copy(LSQLStr, LSetPos, LWherePos - LSetPos);
      CheckTrue(Pos('CLIENTE', LSetClause) > 0, 'SET deve conter CLIENTE: ' + LSetClause);
    end;
  finally
    LPedido.Free;
  end;
end;

{ TTestSimpleSQLDelete }

procedure TTestSimpleSQLDelete.TestDeleteBasic;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.Delete(LSQLStr);
    CheckTrue(Pos('DELETE FROM PEDIDO', LSQLStr) > 0, 'Deve conter DELETE FROM PEDIDO: ' + LSQLStr);
    CheckTrue(Pos('WHERE', LSQLStr) > 0, 'Deve conter WHERE: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLDelete.TestDeleteSoftDelete;
var
  LSQL: iSimpleSQL<TClienteTest>;
  LSQLStr: String;
  LCliente: TClienteTest;
begin
  LCliente := TClienteTest.Create;
  try
    LSQL := TSimpleSQL<TClienteTest>.New(LCliente);
    LSQLStr := '';
    LSQL.Delete(LSQLStr);
    { SoftDelete deve gerar UPDATE em vez de DELETE }
    CheckTrue(Pos('UPDATE CLIENTE', LSQLStr) > 0, 'SoftDelete deve gerar UPDATE: ' + LSQLStr);
    CheckTrue(Pos('EXCLUIDO = 1', LSQLStr) > 0, 'SoftDelete deve setar campo para 1: ' + LSQLStr);
    CheckTrue(Pos('DELETE', LSQLStr) = 0, 'SoftDelete nao deve conter DELETE: ' + LSQLStr);
  finally
    LCliente.Free;
  end;
end;

{ TTestSimpleSQLSelect }

procedure TTestSimpleSQLSelect.TestSelectBasic;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.Select(LSQLStr);
    CheckTrue(Pos('SELECT', LSQLStr) > 0, 'Deve conter SELECT: ' + LSQLStr);
    CheckTrue(Pos('FROM PEDIDO', LSQLStr) > 0, 'Deve conter FROM PEDIDO: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLSelect.TestSelectWithWhere;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.Where('ID > 10').Select(LSQLStr);
    CheckTrue(Pos('WHERE ID > 10', LSQLStr) > 0, 'Deve conter WHERE: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLSelect.TestSelectWithOrderBy;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.OrderBy('CLIENTE').Select(LSQLStr);
    CheckTrue(Pos('ORDER BY CLIENTE', LSQLStr) > 0, 'Deve conter ORDER BY: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLSelect.TestSelectWithGroupBy;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.GroupBy('CLIENTE').Select(LSQLStr);
    CheckTrue(Pos('GROUP BY CLIENTE', LSQLStr) > 0, 'Deve conter GROUP BY: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLSelect.TestSelectWithJoin;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.Join('INNER JOIN CLIENTE ON CLIENTE.ID = PEDIDO.CLIENTE_ID').Select(LSQLStr);
    CheckTrue(Pos('INNER JOIN CLIENTE', LSQLStr) > 0, 'Deve conter JOIN: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLSelect.TestSelectWithCustomFields;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.Fields('ID, CLIENTE').Select(LSQLStr);
    CheckTrue(Pos('SELECT ID, CLIENTE', LSQLStr) > 0, 'Deve conter campos personalizados: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLSelect.TestSelectWithAllClauses;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL
      .Fields('P.ID, P.CLIENTE')
      .Join('INNER JOIN CLIENTE C ON C.ID = P.CLIENTE_ID')
      .Where('P.VALOR_TOTAL > 100')
      .GroupBy('P.CLIENTE')
      .OrderBy('P.ID')
      .Select(LSQLStr);
    CheckTrue(Pos('SELECT P.ID, P.CLIENTE', LSQLStr) > 0, 'Fields: ' + LSQLStr);
    CheckTrue(Pos('INNER JOIN CLIENTE C', LSQLStr) > 0, 'Join: ' + LSQLStr);
    CheckTrue(Pos('WHERE P.VALOR_TOTAL > 100', LSQLStr) > 0, 'Where: ' + LSQLStr);
    CheckTrue(Pos('GROUP BY P.CLIENTE', LSQLStr) > 0, 'GroupBy: ' + LSQLStr);
    CheckTrue(Pos('ORDER BY P.ID', LSQLStr) > 0, 'OrderBy: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

{ Pagination Tests }

procedure TTestSimpleSQLSelect.TestSelectPaginationFirebird;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL
      .DatabaseType(TSQLType.Firebird)
      .Take(10)
      .Skip(20)
      .Select(LSQLStr);
    CheckTrue(Pos('FIRST 10', LSQLStr) > 0, 'Firebird deve usar FIRST: ' + LSQLStr);
    CheckTrue(Pos('SKIP 20', LSQLStr) > 0, 'Firebird deve usar SKIP: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLSelect.TestSelectPaginationFirebirdSkipOnly;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL
      .DatabaseType(TSQLType.Firebird)
      .Take(5)
      .Select(LSQLStr);
    CheckTrue(Pos('FIRST 5', LSQLStr) > 0, 'Deve ter FIRST 5: ' + LSQLStr);
    CheckTrue(Pos('SKIP', LSQLStr) = 0, 'Nao deve ter SKIP sem valor: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLSelect.TestSelectPaginationMySQL;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL
      .DatabaseType(TSQLType.MySQL)
      .Take(10)
      .Select(LSQLStr);
    CheckTrue(Pos('LIMIT 10', LSQLStr) > 0, 'MySQL deve usar LIMIT: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLSelect.TestSelectPaginationMySQLWithSkip;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL
      .DatabaseType(TSQLType.MySQL)
      .Take(10)
      .Skip(5)
      .Select(LSQLStr);
    CheckTrue(Pos('LIMIT 10', LSQLStr) > 0, 'MySQL deve usar LIMIT: ' + LSQLStr);
    CheckTrue(Pos('OFFSET 5', LSQLStr) > 0, 'MySQL deve usar OFFSET: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLSelect.TestSelectPaginationSQLite;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL
      .DatabaseType(TSQLType.SQLite)
      .Take(15)
      .Skip(30)
      .Select(LSQLStr);
    CheckTrue(Pos('LIMIT 15', LSQLStr) > 0, 'SQLite deve usar LIMIT: ' + LSQLStr);
    CheckTrue(Pos('OFFSET 30', LSQLStr) > 0, 'SQLite deve usar OFFSET: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLSelect.TestSelectPaginationOracle;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL
      .DatabaseType(TSQLType.Oracle)
      .Take(10)
      .Select(LSQLStr);
    CheckTrue(Pos('FETCH NEXT 10 ROWS ONLY', LSQLStr) > 0, 'Oracle deve usar FETCH NEXT: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

procedure TTestSimpleSQLSelect.TestSelectPaginationOracleWithSkip;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL
      .DatabaseType(TSQLType.Oracle)
      .Take(10)
      .Skip(20)
      .Select(LSQLStr);
    CheckTrue(Pos('OFFSET 20 ROWS', LSQLStr) > 0, 'Oracle deve usar OFFSET ROWS: ' + LSQLStr);
    CheckTrue(Pos('FETCH NEXT 10 ROWS ONLY', LSQLStr) > 0, 'Oracle deve usar FETCH NEXT: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

{ SoftDelete auto-filter }

procedure TTestSimpleSQLSelect.TestSelectSoftDeleteAutoFilter;
var
  LSQL: iSimpleSQL<TClienteTest>;
  LSQLStr: String;
  LCliente: TClienteTest;
begin
  LCliente := TClienteTest.Create;
  try
    LSQL := TSimpleSQL<TClienteTest>.New(LCliente);
    LSQLStr := '';
    LSQL.Select(LSQLStr);
    CheckTrue(Pos('EXCLUIDO = 0', LSQLStr) > 0, 'SoftDelete deve filtrar automaticamente: ' + LSQLStr);
  finally
    LCliente.Free;
  end;
end;

procedure TTestSimpleSQLSelect.TestSelectSoftDeleteWithWhere;
var
  LSQL: iSimpleSQL<TClienteTest>;
  LSQLStr: String;
  LCliente: TClienteTest;
begin
  LCliente := TClienteTest.Create;
  try
    LSQL := TSimpleSQL<TClienteTest>.New(LCliente);
    LSQLStr := '';
    LSQL.Where('NOME LIKE ''%JOAO%''').Select(LSQLStr);
    CheckTrue(Pos('EXCLUIDO = 0', LSQLStr) > 0, 'SoftDelete deve estar presente: ' + LSQLStr);
    CheckTrue(Pos('JOAO', LSQLStr) > 0, 'Where original deve estar presente: ' + LSQLStr);
  finally
    LCliente.Free;
  end;
end;

{ TTestSimpleSQLSelectId }

procedure TTestSimpleSQLSelectId.TestSelectIdBasic;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.SelectId(LSQLStr);
    CheckTrue(Pos('SELECT', LSQLStr) > 0, 'Deve conter SELECT: ' + LSQLStr);
    CheckTrue(Pos('FROM PEDIDO', LSQLStr) > 0, 'Deve conter FROM PEDIDO: ' + LSQLStr);
    CheckTrue(Pos('WHERE', LSQLStr) > 0, 'Deve conter WHERE com PK: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

{ TTestSimpleSQLLastID }

procedure TTestSimpleSQLLastID.TestLastID;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.LastID(LSQLStr);
    CheckTrue(Pos('first(1)', LSQLStr) > 0, 'Deve usar first(1): ' + LSQLStr);
    CheckTrue(Pos('order by', LSQLStr) > 0, 'Deve ter ORDER BY: ' + LSQLStr);
    CheckTrue(Pos('desc', LSQLStr) > 0, 'Deve ordenar DESC: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

{ TTestSimpleSQLLastRecord }

procedure TTestSimpleSQLLastRecord.TestLastRecord;
var
  LSQL: iSimpleSQL<TPedidoTest>;
  LSQLStr: String;
  LPedido: TPedidoTest;
begin
  LPedido := TPedidoTest.Create;
  try
    LSQL := TSimpleSQL<TPedidoTest>.New(LPedido);
    LSQLStr := '';
    LSQL.LastRecord(LSQLStr);
    CheckTrue(Pos('first(1)', LSQLStr) > 0, 'Deve usar first(1): ' + LSQLStr);
    CheckTrue(Pos('from PEDIDO', LSQLStr) > 0, 'Deve ter FROM PEDIDO: ' + LSQLStr);
    CheckTrue(Pos('desc', LSQLStr) > 0, 'Deve ordenar DESC: ' + LSQLStr);
  finally
    LPedido.Free;
  end;
end;

initialization
  RegisterTest('SQL.Insert', TTestSimpleSQLInsert.Suite);
  RegisterTest('SQL.Update', TTestSimpleSQLUpdate.Suite);
  RegisterTest('SQL.Delete', TTestSimpleSQLDelete.Suite);
  RegisterTest('SQL.Select', TTestSimpleSQLSelect.Suite);
  RegisterTest('SQL.SelectId', TTestSimpleSQLSelectId.Suite);
  RegisterTest('SQL.LastID', TTestSimpleSQLLastID.Suite);
  RegisterTest('SQL.LastRecord', TTestSimpleSQLLastRecord.Suite);

end.
