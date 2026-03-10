unit TestSimpleAIQuery;

interface

uses
  TestFramework,
  System.SysUtils,
  System.Classes,
  System.Rtti,
  SimpleAttributes,
  SimpleRTTIHelper,
  SimpleAIQuery,
  SimpleInterface,
  MockAIClient;

type
  { Test entity for schema generation }
  [Tabela('USUARIOS')]
  TUsuarioSchemaTest = class
  private
    FID: Integer;
    FNOME: String;
    FEMAIL: String;
    FATIVO: Boolean;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull]
    property NOME: String read FNOME write FNOME;
    [Campo('EMAIL')]
    property EMAIL: String read FEMAIL write FEMAIL;
    [Campo('ATIVO')]
    property ATIVO: Boolean read FATIVO write FATIVO;
  end;

  [Tabela('PEDIDOS')]
  TPedidoSchemaTest = class
  private
    FID: Integer;
    FID_USUARIO: Integer;
    FVALOR: Double;
    FSTATUS: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('ID_USUARIO'), FK]
    property ID_USUARIO: Integer read FID_USUARIO write FID_USUARIO;
    [Campo('VALOR')]
    property VALOR: Double read FVALOR write FVALOR;
    [Campo('STATUS')]
    property STATUS: String read FSTATUS write FSTATUS;
  end;

  TTestValidateSQL = class(TTestCase)
  published
    procedure TestValidateSQL_SelectAllowed;
    procedure TestValidateSQL_InsertBlocked;
    procedure TestValidateSQL_UpdateBlocked;
    procedure TestValidateSQL_DeleteBlocked;
    procedure TestValidateSQL_DropBlocked;
    procedure TestValidateSQL_SemicolonBlocked;
    procedure TestValidateSQL_TruncateBlocked;
    procedure TestValidateSQL_ExecBlocked;
    procedure TestValidateSQL_GrantBlocked;
    procedure TestValidateSQL_EmptyBlocked;
    procedure TestValidateSQL_SelectWithJoin;
    procedure TestValidateSQL_SelectWithSubquery;
  end;

  TTestCleanSQLResponse = class(TTestCase)
  published
    procedure TestCleanSQLResponse_StripsFences;
    procedure TestCleanSQLResponse_StripsSqlFences;
    procedure TestCleanSQLResponse_PlainSQL;
    procedure TestCleanSQLResponse_TrimsWhitespace;
    procedure TestCleanSQLResponse_RemovesTrailingSemicolon;
  end;

  TTestBuildSchemaForEntity = class(TTestCase)
  published
    procedure TestBuildSchema_ContainsTableName;
    procedure TestBuildSchema_ContainsColumns;
    procedure TestBuildSchema_ContainsPKAnnotation;
    procedure TestBuildSchema_ContainsFKAnnotation;
    procedure TestBuildSchema_ContainsNotNullAnnotation;
  end;

  TTestExplainQuery = class(TTestCase)
  published
    procedure TestExplainQuery_ReturnsText;
    procedure TestExplainQuery_IncludesSchema;
  end;

implementation

uses
  SimpleTypes;

type
  { Helper class to access private methods for testing }
  TSimpleAIQueryTestHelper = class helper for TSimpleAIQuery
  public
    function TestValidateSQL(const aSQL: String): Boolean;
    function TestCleanSQLResponse(const aResponse: String): String;
    function TestBuildSchemaForEntity(aType: TRttiType): String;
  end;

function TSimpleAIQueryTestHelper.TestValidateSQL(const aSQL: String): Boolean;
begin
  Result := Self.ValidateSQL(aSQL);
end;

function TSimpleAIQueryTestHelper.TestCleanSQLResponse(const aResponse: String): String;
begin
  Result := Self.CleanSQLResponse(aResponse);
end;

function TSimpleAIQueryTestHelper.TestBuildSchemaForEntity(aType: TRttiType): String;
begin
  Result := Self.BuildSchemaForEntity(aType);
end;

{ TTestValidateSQL }

procedure TTestValidateSQL.TestValidateSQL_SelectAllowed;
var
  LAIQuery: TSimpleAIQuery;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    CheckTrue(LAIQuery.TestValidateSQL('SELECT * FROM USUARIOS'),
      'SELECT should be allowed');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_InsertBlocked;
var
  LAIQuery: TSimpleAIQuery;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    CheckFalse(LAIQuery.TestValidateSQL('INSERT INTO USUARIOS VALUES (1)'),
      'INSERT should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_UpdateBlocked;
var
  LAIQuery: TSimpleAIQuery;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    CheckFalse(LAIQuery.TestValidateSQL('UPDATE USUARIOS SET NOME = ''test'''),
      'UPDATE should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_DeleteBlocked;
var
  LAIQuery: TSimpleAIQuery;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    CheckFalse(LAIQuery.TestValidateSQL('DELETE FROM USUARIOS'),
      'DELETE should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_DropBlocked;
var
  LAIQuery: TSimpleAIQuery;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    CheckFalse(LAIQuery.TestValidateSQL('DROP TABLE USUARIOS'),
      'DROP should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_SemicolonBlocked;
var
  LAIQuery: TSimpleAIQuery;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    CheckFalse(LAIQuery.TestValidateSQL('SELECT 1; DROP TABLE USUARIOS'),
      'Semicolons should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_TruncateBlocked;
var
  LAIQuery: TSimpleAIQuery;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    CheckFalse(LAIQuery.TestValidateSQL('TRUNCATE TABLE USUARIOS'),
      'TRUNCATE should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_ExecBlocked;
var
  LAIQuery: TSimpleAIQuery;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    CheckFalse(LAIQuery.TestValidateSQL('EXEC sp_something'),
      'EXEC should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_GrantBlocked;
var
  LAIQuery: TSimpleAIQuery;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    CheckFalse(LAIQuery.TestValidateSQL('GRANT ALL ON USUARIOS TO public'),
      'GRANT should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_EmptyBlocked;
var
  LAIQuery: TSimpleAIQuery;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    CheckFalse(LAIQuery.TestValidateSQL(''),
      'Empty SQL should be blocked');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_SelectWithJoin;
var
  LAIQuery: TSimpleAIQuery;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    CheckTrue(LAIQuery.TestValidateSQL(
      'SELECT U.NOME, COUNT(P.ID) FROM USUARIOS U JOIN PEDIDOS P ON U.ID = P.ID_USUARIO GROUP BY U.NOME'),
      'SELECT with JOIN should be allowed');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestValidateSQL.TestValidateSQL_SelectWithSubquery;
var
  LAIQuery: TSimpleAIQuery;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    CheckTrue(LAIQuery.TestValidateSQL(
      'SELECT * FROM USUARIOS WHERE ID IN (SELECT ID_USUARIO FROM PEDIDOS)'),
      'SELECT with subquery should be allowed');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

{ TTestCleanSQLResponse }

procedure TTestCleanSQLResponse.TestCleanSQLResponse_StripsFences;
var
  LAIQuery: TSimpleAIQuery;
  LResult: String;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    LResult := LAIQuery.TestCleanSQLResponse('```' + #10 + 'SELECT 1' + #10 + '```');
    CheckEquals('SELECT 1', LResult, 'Should strip plain code fences');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestCleanSQLResponse.TestCleanSQLResponse_StripsSqlFences;
var
  LAIQuery: TSimpleAIQuery;
  LResult: String;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    LResult := LAIQuery.TestCleanSQLResponse('```sql' + #10 + 'SELECT * FROM USUARIOS' + #10 + '```');
    CheckEquals('SELECT * FROM USUARIOS', LResult, 'Should strip sql code fences');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestCleanSQLResponse.TestCleanSQLResponse_PlainSQL;
var
  LAIQuery: TSimpleAIQuery;
  LResult: String;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    LResult := LAIQuery.TestCleanSQLResponse('SELECT * FROM USUARIOS');
    CheckEquals('SELECT * FROM USUARIOS', LResult, 'Should return plain SQL as-is');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestCleanSQLResponse.TestCleanSQLResponse_TrimsWhitespace;
var
  LAIQuery: TSimpleAIQuery;
  LResult: String;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    LResult := LAIQuery.TestCleanSQLResponse('  SELECT 1  ' + #13#10);
    CheckEquals('SELECT 1', LResult, 'Should trim whitespace');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestCleanSQLResponse.TestCleanSQLResponse_RemovesTrailingSemicolon;
var
  LAIQuery: TSimpleAIQuery;
  LResult: String;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  try
    LResult := LAIQuery.TestCleanSQLResponse('SELECT 1;');
    CheckEquals('SELECT 1', LResult, 'Should remove trailing semicolon');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

{ TTestBuildSchemaForEntity }

procedure TTestBuildSchemaForEntity.TestBuildSchema_ContainsTableName;
var
  LAIQuery: TSimpleAIQuery;
  LContext: TRttiContext;
  LType: TRttiType;
  LResult: String;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TypeInfo(TUsuarioSchemaTest));
    LResult := LAIQuery.TestBuildSchemaForEntity(LType);
    CheckTrue(Pos('Tabela: USUARIOS', LResult) > 0,
      'Schema should contain table name USUARIOS');
  finally
    LContext.Free;
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestBuildSchemaForEntity.TestBuildSchema_ContainsColumns;
var
  LAIQuery: TSimpleAIQuery;
  LContext: TRttiContext;
  LType: TRttiType;
  LResult: String;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TypeInfo(TUsuarioSchemaTest));
    LResult := LAIQuery.TestBuildSchemaForEntity(LType);
    CheckTrue(Pos('ID', LResult) > 0, 'Schema should contain ID column');
    CheckTrue(Pos('NOME', LResult) > 0, 'Schema should contain NOME column');
    CheckTrue(Pos('EMAIL', LResult) > 0, 'Schema should contain EMAIL column');
    CheckTrue(Pos('ATIVO', LResult) > 0, 'Schema should contain ATIVO column');
  finally
    LContext.Free;
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestBuildSchemaForEntity.TestBuildSchema_ContainsPKAnnotation;
var
  LAIQuery: TSimpleAIQuery;
  LContext: TRttiContext;
  LType: TRttiType;
  LResult: String;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TypeInfo(TUsuarioSchemaTest));
    LResult := LAIQuery.TestBuildSchemaForEntity(LType);
    CheckTrue(Pos('PK', LResult) > 0, 'Schema should contain PK annotation');
  finally
    LContext.Free;
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestBuildSchemaForEntity.TestBuildSchema_ContainsFKAnnotation;
var
  LAIQuery: TSimpleAIQuery;
  LContext: TRttiContext;
  LType: TRttiType;
  LResult: String;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TypeInfo(TPedidoSchemaTest));
    LResult := LAIQuery.TestBuildSchemaForEntity(LType);
    CheckTrue(Pos('FK', LResult) > 0, 'Schema should contain FK annotation');
  finally
    LContext.Free;
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestBuildSchemaForEntity.TestBuildSchema_ContainsNotNullAnnotation;
var
  LAIQuery: TSimpleAIQuery;
  LContext: TRttiContext;
  LType: TRttiType;
  LResult: String;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New(''));
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TypeInfo(TUsuarioSchemaTest));
    LResult := LAIQuery.TestBuildSchemaForEntity(LType);
    CheckTrue(Pos('NotNull', LResult) > 0, 'Schema should contain NotNull annotation');
  finally
    LContext.Free;
    FreeAndNil(LAIQuery);
  end;
end;

{ TTestExplainQuery }

procedure TTestExplainQuery.TestExplainQuery_ReturnsText;
var
  LAIQuery: TSimpleAIQuery;
  LResult: String;
begin
  LAIQuery := TSimpleAIQuery.Create(nil, TSimpleAIMockClient.New('Esta query seleciona todos os usuarios.'));
  try
    LResult := LAIQuery.ExplainQuery('SELECT * FROM USUARIOS');
    CheckEquals('Esta query seleciona todos os usuarios.', LResult,
      'ExplainQuery should return the LLM response');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

procedure TTestExplainQuery.TestExplainQuery_IncludesSchema;
var
  LAIQuery: TSimpleAIQuery;
  LMock: TSimpleAIMockClient;
  LClient: iSimpleAIClient;
  LResult: String;
begin
  LMock := TSimpleAIMockClient.Create('Explicacao da query');
  LClient := LMock;
  LAIQuery := TSimpleAIQuery.Create(nil, LClient);
  try
    LAIQuery.RegisterEntity<TUsuarioSchemaTest>;
    LResult := LAIQuery.ExplainQuery('SELECT * FROM USUARIOS');
    CheckTrue(Pos('USUARIOS', LMock.LastPrompt) > 0,
      'Prompt sent to LLM should include schema context');
  finally
    FreeAndNil(LAIQuery);
  end;
end;

initialization
  RegisterTest('AI.Query', TTestValidateSQL.Suite);
  RegisterTest('AI.Query', TTestCleanSQLResponse.Suite);
  RegisterTest('AI.Query', TTestBuildSchemaForEntity.Suite);
  RegisterTest('AI.Query', TTestExplainQuery.Suite);

end.
