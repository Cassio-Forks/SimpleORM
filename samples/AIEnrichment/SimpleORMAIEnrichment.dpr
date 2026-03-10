program SimpleORMAIEnrichment;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  SimpleAttributes in '..\..\src\SimpleAttributes.pas',
  SimpleAIAttributes in '..\..\src\SimpleAIAttributes.pas',
  SimpleAIProcessor in '..\..\src\SimpleAIProcessor.pas',
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleRTTIHelper in '..\..\src\SimpleRTTIHelper.pas',
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleLogger in '..\..\src\SimpleLogger.pas';

type
  { Mock AI Client que simula respostas de LLM }
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

  { Entidade com atributos AI }
  [Tabela('PRODUTOS')]
  TProduto = class
  private
    FID: Integer;
    FNOME: String;
    FDESCRICAO: String;
    FRESUMO: String;
    FCATEGORIA: String;
    FDESCRICAO_EN: String;
    FSLOGAN: String;
    procedure SetID(const Value: Integer);
    procedure SetNOME(const Value: String);
    procedure SetDESCRICAO(const Value: String);
    procedure SetRESUMO(const Value: String);
    procedure SetCATEGORIA(const Value: String);
    procedure SetDESCRICAO_EN(const Value: String);
    procedure SetSLOGAN(const Value: String);
  public
    constructor Create;
    destructor Destroy; override;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write SetID;
    [Campo('NOME')]
    property NOME: String read FNOME write SetNOME;
    [Campo('DESCRICAO')]
    property DESCRICAO: String read FDESCRICAO write SetDESCRICAO;
    [Campo('RESUMO'), AISummarize('DESCRICAO', 100)]
    property RESUMO: String read FRESUMO write SetRESUMO;
    [Campo('CATEGORIA'), AIClassify('DESCRICAO', 'Eletronico,Vestuario,Alimento,Outros')]
    property CATEGORIA: String read FCATEGORIA write SetCATEGORIA;
    [Campo('DESCRICAO_EN'), AITranslate('DESCRICAO', 'English')]
    property DESCRICAO_EN: String read FDESCRICAO_EN write SetDESCRICAO_EN;
    [Campo('SLOGAN'), AIGenerated('Crie um slogan curto e criativo para o produto {NOME}')]
    property SLOGAN: String read FSLOGAN write SetSLOGAN;
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
  // Simula respostas baseado no tipo de prompt
  if Pos('Resuma', aPrompt) > 0 then
    Result := 'Notebook potente com tela 15pol e processador i7.'
  else if Pos('Traduza', aPrompt) > 0 then
    Result := 'Powerful notebook with 15-inch screen and i7 processor.'
  else if Pos('Classifique', aPrompt) > 0 then
    Result := 'Eletronico'
  else if Pos('slogan', LowerCase(aPrompt)) > 0 then
    Result := 'Notebook Ultra: Poder sem limites!'
  else if Pos('Valide', aPrompt) > 0 then
    Result := 'VALIDO'
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

{ TProduto }

constructor TProduto.Create;
begin
  FID := 0;
end;

destructor TProduto.Destroy;
begin
  inherited;
end;

procedure TProduto.SetID(const Value: Integer);
begin
  FID := Value;
end;

procedure TProduto.SetNOME(const Value: String);
begin
  FNOME := Value;
end;

procedure TProduto.SetDESCRICAO(const Value: String);
begin
  FDESCRICAO := Value;
end;

procedure TProduto.SetRESUMO(const Value: String);
begin
  FRESUMO := Value;
end;

procedure TProduto.SetCATEGORIA(const Value: String);
begin
  FCATEGORIA := Value;
end;

procedure TProduto.SetDESCRICAO_EN(const Value: String);
begin
  FDESCRICAO_EN := Value;
end;

procedure TProduto.SetSLOGAN(const Value: String);
begin
  FSLOGAN := Value;
end;

{ Main }

var
  LAIClient: iSimpleAIClient;
  LProcessor: TSimpleAIProcessor;
  LProduto: TProduto;
begin
  try
    Writeln('=== SimpleORM AI Entity Enrichment Demo ===');
    Writeln('');
    Writeln('NOTA: Este demo usa um mock AI client.');
    Writeln('Para uso real, substitua por TSimpleAIClient.New(''claude'', ''sua-api-key'')');
    Writeln('');

    LAIClient := TDemoAIClient.New;

    // Criar produto com dados basicos
    LProduto := TProduto.Create;
    LProcessor := TSimpleAIProcessor.New(LAIClient);
    try
      LProduto.NOME := 'Notebook Ultra';
      LProduto.DESCRICAO := 'Notebook de alto desempenho com tela de 15 polegadas, ' +
        'processador Intel Core i7, 16GB de RAM, SSD de 512GB. ' +
        'Ideal para profissionais e gamers que precisam de potencia e portabilidade.';

      Writeln('--- Dados originais ---');
      Writeln('Nome: ', LProduto.NOME);
      Writeln('Descricao: ', LProduto.DESCRICAO);
      Writeln('Resumo: ', LProduto.RESUMO);
      Writeln('Categoria: ', LProduto.CATEGORIA);
      Writeln('Descricao EN: ', LProduto.DESCRICAO_EN);
      Writeln('Slogan: ', LProduto.SLOGAN);
      Writeln('');

      // Processar atributos AI
      Writeln('--- Processando com AI... ---');
      LProcessor.Process(LProduto);
      Writeln('');

      Writeln('--- Dados enriquecidos pela AI ---');
      Writeln('Nome: ', LProduto.NOME);
      Writeln('Descricao: ', LProduto.DESCRICAO);
      Writeln('Resumo (AISummarize): ', LProduto.RESUMO);
      Writeln('Categoria (AIClassify): ', LProduto.CATEGORIA);
      Writeln('Descricao EN (AITranslate): ', LProduto.DESCRICAO_EN);
      Writeln('Slogan (AIGenerated): ', LProduto.SLOGAN);
      Writeln('');

      Writeln('--- Uso com TSimpleDAO (integracao automatica) ---');
      Writeln('  DAOProduto := TSimpleDAO<TProduto>');
      Writeln('    .New(Conn)');
      Writeln('    .AIClient(TSimpleAIClient.New(''claude'', ''sua-api-key''))');
      Writeln('    .Insert(Produto);');
      Writeln('');
      Writeln('  // AI processa AUTOMATICAMENTE antes do INSERT!');
    finally
      FreeAndNil(LProduto);
      FreeAndNil(LProcessor);
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
