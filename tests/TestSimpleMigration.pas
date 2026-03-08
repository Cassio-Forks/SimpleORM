unit TestSimpleMigration;

interface

uses
  TestFramework, SimpleAttributes, SimpleMigration, SimpleTypes;

type
  TTestSimpleMigration = class(TTestCase)
  published
    procedure TestGenerateCreateTable_Firebird_ShouldContainCreateTable;
    procedure TestGenerateCreateTable_MySQL_ShouldContainAutoIncrement;
    procedure TestGenerateCreateTable_ShouldContainPrimaryKey;
    procedure TestGenerateCreateTable_ShouldContainNotNull;
    procedure TestGenerateCreateTable_ShouldContainVarcharWithSize;
    procedure TestGenerateDropTable_ShouldContainDropTable;
  end;

implementation

uses
  System.SysUtils, TestEntities;

procedure TTestSimpleMigration.TestGenerateCreateTable_Firebird_ShouldContainCreateTable;
var DDL: String;
begin
  DDL := TSimpleMigration.GenerateCreateTable<TPedidoTest>(TSQLType.Firebird);
  CheckTrue(Pos('CREATE TABLE IF NOT EXISTS', DDL) > 0, 'Deve conter CREATE TABLE');
end;

procedure TTestSimpleMigration.TestGenerateCreateTable_MySQL_ShouldContainAutoIncrement;
var DDL: String;
begin
  DDL := TSimpleMigration.GenerateCreateTable<TPedidoTest>(TSQLType.MySQL);
  CheckTrue(Pos('AUTO_INCREMENT', DDL) > 0, 'Deve conter AUTO_INCREMENT para MySQL');
end;

procedure TTestSimpleMigration.TestGenerateCreateTable_ShouldContainPrimaryKey;
var DDL: String;
begin
  DDL := TSimpleMigration.GenerateCreateTable<TPedidoTest>(TSQLType.Firebird);
  CheckTrue(Pos('PRIMARY KEY', DDL) > 0, 'Deve conter PRIMARY KEY');
end;

procedure TTestSimpleMigration.TestGenerateCreateTable_ShouldContainNotNull;
var DDL: String;
begin
  DDL := TSimpleMigration.GenerateCreateTable<TClienteTest>(TSQLType.Firebird);
  CheckTrue(Pos('NOT NULL', DDL) > 0, 'Deve conter NOT NULL');
end;

procedure TTestSimpleMigration.TestGenerateCreateTable_ShouldContainVarcharWithSize;
var DDL: String;
begin
  DDL := TSimpleMigration.GenerateCreateTable<TContaTest>(TSQLType.Firebird);
  CheckTrue(Pos('VARCHAR(', DDL) > 0, 'Deve conter VARCHAR com tamanho');
end;

procedure TTestSimpleMigration.TestGenerateDropTable_ShouldContainDropTable;
var DDL: String;
begin
  DDL := TSimpleMigration.GenerateDropTable<TPedidoTest>;
  CheckTrue(Pos('DROP TABLE IF EXISTS', DDL) > 0, 'Deve conter DROP TABLE');
end;

initialization
  RegisterTest('Migration', TTestSimpleMigration.Suite);

end.
