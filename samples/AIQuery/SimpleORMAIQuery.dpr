program SimpleORMAIQuery;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  SimpleAttributes in '..\..\src\SimpleAttributes.pas',
  SimpleAIAttributes in '..\..\src\SimpleAIAttributes.pas',
  SimpleAIQuery in '..\..\src\SimpleAIQuery.pas',
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleRTTIHelper in '..\..\src\SimpleRTTIHelper.pas',
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleLogger in '..\..\src\SimpleLogger.pas';

type
  { Mock AI Client }
  TDemoAIClient = class(TInterfacedObject, iSimpleAIClient)
  private
    FModel: String;
    FMaxTokens: Integer;
    FTemperature: Double;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: iSimpleAIClient;
    function Complete(const aPrompt: String): String;
    function Model(const aValue: String): iSimpleAIClient;
    function MaxTokens(aValue: Integer): iSimpleAIClient;
    function Temperature(aValue: Double): iSimpleAIClient;
  end;

  [Tabela('CLIENTES')]
  TCliente = class
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
  TPedido = class
  private
    FID: Integer;
    FID_CLIENTE: Integer;
    FVALOR: Double;
    FDATA: TDateTime;
    FSTATUS: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('ID_CLIENTE'), FK]
    property ID_CLIENTE: Integer read FID_CLIENTE write FID_CLIENTE;
    [Campo('VALOR')]
    property VALOR: Double read FVALOR write FVALOR;
    [Campo('DATA')]
    property DATA: TDateTime read FDATA write FDATA;
    [Campo('STATUS')]
    property STATUS: String read FSTATUS write FSTATUS;
  end;

  [Tabela('PRODUTOS')]
  TProduto = class
  private
    FID: Integer;
    FNOME: String;
    FPRECO: Double;
    FCATEGORIA: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull]
    property NOME: String read FNOME write FNOME;
    [Campo('PRECO')]
    property PRECO: Double read FPRECO write FPRECO;
    [Campo('CATEGORIA')]
    property CATEGORIA: String read FCATEGORIA write FCATEGORIA;
  end;

{ TDemoAIClient }

constructor TDemoAIClient.Create;
begin
  FModel := 'demo-model';
  FMaxTokens := 1024;
  FTemperature := 0.7;
end;

destructor TDemoAIClient.Destroy;
begin
  inherited;
end;

class function TDemoAIClient.New: iSimpleAIClient;
begin
  Result := Self.Create;
end;

function TDemoAIClient.Complete(const aPrompt: String): String;
begin
  if Pos('Suggest', aPrompt) > 0 then
    Result := 'SELECT C.* FROM CLIENTES C WHERE C.ID NOT IN (SELECT DISTINCT P.ID_CLIENTE FROM PEDIDOS P WHERE P.DATA >= CURRENT_DATE - 90)'
  else if Pos('Explain', aPrompt) > 0 then
    Result := 'Esta query seleciona todos os clientes ativos da tabela CLIENTES, filtrando apenas aqueles onde o campo ATIVO e igual a 1 (verdadeiro).'
  else
    Result := 'Resposta simulada do LLM.';
end;

function TDemoAIClient.Model(const aValue: String): iSimpleAIClient;
begin
  Result := Self;
  FModel := aValue;
end;

function TDemoAIClient.MaxTokens(aValue: Integer): iSimpleAIClient;
begin
  Result := Self;
  FMaxTokens := aValue;
end;

function TDemoAIClient.Temperature(aValue: Double): iSimpleAIClient;
begin
  Result := Self;
  FTemperature := aValue;
end;

{ Main }

var
  LAIQuery: TSimpleAIQuery;
  LAIClient: iSimpleAIClient;
  LSQL: String;
  LExplicacao: String;
begin
  try
    Writeln('=== SimpleORM AI Query Demo ===');
    Writeln('');
    Writeln('NOTA: Este demo usa um mock AI client.');
    Writeln('Para uso real, substitua por TSimpleAIClient.New(''claude'', ''sua-api-key'')');
    Writeln('e conecte um iSimpleQuery real (ex: TSimpleQueryFiredac).');
    Writeln('');

    LAIClient := TDemoAIClient.New;
    LAIQuery := TSimpleAIQuery.New(nil, LAIClient);
    try
      LAIQuery
        .RegisterEntity<TCliente>
        .RegisterEntity<TPedido>
        .RegisterEntity<TProduto>;

      Writeln('--- Schema registrado ---');
      Writeln('Entidades: CLIENTES, PEDIDOS, PRODUTOS');
      Writeln('');

      // 1. SuggestQuery
      Writeln('--- SuggestQuery ---');
      Writeln('Objetivo: "Encontrar clientes inativos ha mais de 90 dias"');
      LSQL := LAIQuery.SuggestQuery('Encontrar clientes inativos ha mais de 90 dias');
      Writeln('SQL sugerido: ', LSQL);
      Writeln('');

      // 2. ExplainQuery
      Writeln('--- ExplainQuery ---');
      Writeln('SQL: SELECT * FROM CLIENTES WHERE ATIVO = 1');
      LExplicacao := LAIQuery.ExplainQuery('SELECT * FROM CLIENTES WHERE ATIVO = 1');
      Writeln('Explicacao: ', LExplicacao);
      Writeln('');

      // 3. Demonstracao de validacao SQL
      Writeln('--- Validacao de Seguranca SQL ---');
      Writeln('SELECT * FROM CLIENTES: Permitido');
      Writeln('INSERT INTO CLIENTES: Bloqueado');
      Writeln('DELETE FROM CLIENTES: Bloqueado');
      Writeln('DROP TABLE CLIENTES: Bloqueado');
      Writeln('');

      Writeln('--- Para usar NaturalLanguageQuery e AskQuestion ---');
      Writeln('Conecte um iSimpleQuery real:');
      Writeln('  LAIQuery := TSimpleAIQuery.New(');
      Writeln('    TSimpleQueryFiredac.New(FDConnection),');
      Writeln('    TSimpleAIClient.New(''claude'', ''sua-api-key'')');
      Writeln('  );');
      Writeln('  LDataSet := LAIQuery.NaturalLanguageQuery(''Top 5 clientes'');');
      Writeln('  LResposta := LAIQuery.AskQuestion(''Qual o ticket medio?'');');
    finally
      FreeAndNil(LAIQuery);
    end;

    Writeln('');
    Writeln('=== Demo finalizada com sucesso ===');
  except
    on E: Exception do
      Writeln('Erro: ', E.Message);
  end;

  Writeln('');
  Writeln('Pressione ENTER para sair...');
  Readln;
end.
