unit TestSimpleAIProcessor;

interface

uses
  TestFramework,
  System.SysUtils,
  System.Rtti,
  SimpleAttributes,
  SimpleAIAttributes,
  SimpleAIProcessor,
  SimpleInterface,
  MockAIClient;

type
  { Test entity with AI attributes }
  [Tabela('PRODUTOS')]
  TProdutoAITest = class
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
    [Campo('SLOGAN'), AIGenerated('Crie um slogan curto para o produto {NOME}')]
    property SLOGAN: String read FSLOGAN write SetSLOGAN;
  end;

  { Test entity with AIValidate }
  [Tabela('EMAILS')]
  TEmailAITest = class
  private
    FEMAIL: String;
    procedure SetEMAIL(const Value: String);
  public
    constructor Create;
    destructor Destroy; override;
  published
    [Campo('EMAIL'), AIValidate('Deve ser um endereco de email valido')]
    property EMAIL: String read FEMAIL write SetEMAIL;
  end;

  TTestAIProcessor = class(TTestCase)
  published
    procedure TestAIGenerated_SetsPropertyValue;
    procedure TestAISummarize_SetsPropertyValue;
    procedure TestAISummarize_EmptySource_Skips;
    procedure TestAITranslate_SetsPropertyValue;
    procedure TestAIClassify_SetsPropertyValue;
    procedure TestAIValidate_Valid_NoException;
    procedure TestAIValidate_Invalid_RaisesException;
    procedure TestProcess_NilObject_NoError;
    procedure TestAISummarize_TruncatesIfMaxLength;
  end;

  TTestAIAttributes = class(TTestCase)
  published
    procedure TestAIGeneratedConstructor;
    procedure TestAISummarizeConstructor;
    procedure TestAISummarizeDefaultMaxLength;
    procedure TestAITranslateConstructor;
    procedure TestAIClassifyConstructor;
    procedure TestAIValidateConstructor;
    procedure TestAIValidateDefaultErrorMessage;
  end;

implementation

{ TProdutoAITest }

constructor TProdutoAITest.Create;
begin
  FID := 0;
end;

destructor TProdutoAITest.Destroy;
begin
  inherited;
end;

procedure TProdutoAITest.SetID(const Value: Integer);
begin
  FID := Value;
end;

procedure TProdutoAITest.SetNOME(const Value: String);
begin
  FNOME := Value;
end;

procedure TProdutoAITest.SetDESCRICAO(const Value: String);
begin
  FDESCRICAO := Value;
end;

procedure TProdutoAITest.SetRESUMO(const Value: String);
begin
  FRESUMO := Value;
end;

procedure TProdutoAITest.SetCATEGORIA(const Value: String);
begin
  FCATEGORIA := Value;
end;

procedure TProdutoAITest.SetDESCRICAO_EN(const Value: String);
begin
  FDESCRICAO_EN := Value;
end;

procedure TProdutoAITest.SetSLOGAN(const Value: String);
begin
  FSLOGAN := Value;
end;

{ TEmailAITest }

constructor TEmailAITest.Create;
begin
  FEMAIL := '';
end;

destructor TEmailAITest.Destroy;
begin
  inherited;
end;

procedure TEmailAITest.SetEMAIL(const Value: String);
begin
  FEMAIL := Value;
end;

{ TTestAIProcessor }

procedure TTestAIProcessor.TestAIGenerated_SetsPropertyValue;
var
  LMockClient: iSimpleAIClient;
  LProcessor: TSimpleAIProcessor;
  LProduto: TProdutoAITest;
begin
  LMockClient := TSimpleAIMockClient.New('Slogan gerado pela IA');
  LProcessor := TSimpleAIProcessor.New(LMockClient);
  LProduto := TProdutoAITest.Create;
  try
    LProduto.NOME := 'Notebook Ultra';
    LProduto.DESCRICAO := 'Um notebook potente';
    LProcessor.Process(LProduto);
    CheckEquals('Slogan gerado pela IA', LProduto.SLOGAN,
      'AIGenerated should set property with LLM response');
  finally
    FreeAndNil(LProduto);
    FreeAndNil(LProcessor);
  end;
end;

procedure TTestAIProcessor.TestAISummarize_SetsPropertyValue;
var
  LMockClient: iSimpleAIClient;
  LProcessor: TSimpleAIProcessor;
  LProduto: TProdutoAITest;
begin
  LMockClient := TSimpleAIMockClient.New('Resumo do produto');
  LProcessor := TSimpleAIProcessor.New(LMockClient);
  LProduto := TProdutoAITest.Create;
  try
    LProduto.DESCRICAO := 'Descricao longa do produto com muitos detalhes';
    LProcessor.Process(LProduto);
    CheckEquals('Resumo do produto', LProduto.RESUMO,
      'AISummarize should set property with summary');
  finally
    FreeAndNil(LProduto);
    FreeAndNil(LProcessor);
  end;
end;

procedure TTestAIProcessor.TestAISummarize_EmptySource_Skips;
var
  LMockClient: iSimpleAIClient;
  LProcessor: TSimpleAIProcessor;
  LProduto: TProdutoAITest;
begin
  LMockClient := TSimpleAIMockClient.New('Should not be called');
  LProcessor := TSimpleAIProcessor.New(LMockClient);
  LProduto := TProdutoAITest.Create;
  try
    LProduto.DESCRICAO := '';
    LProcessor.Process(LProduto);
    CheckEquals('', LProduto.RESUMO,
      'AISummarize should skip when source is empty');
  finally
    FreeAndNil(LProduto);
    FreeAndNil(LProcessor);
  end;
end;

procedure TTestAIProcessor.TestAITranslate_SetsPropertyValue;
var
  LMockClient: iSimpleAIClient;
  LProcessor: TSimpleAIProcessor;
  LProduto: TProdutoAITest;
begin
  LMockClient := TSimpleAIMockClient.New('Product description in English');
  LProcessor := TSimpleAIProcessor.New(LMockClient);
  LProduto := TProdutoAITest.Create;
  try
    LProduto.DESCRICAO := 'Descricao do produto em portugues';
    LProcessor.Process(LProduto);
    CheckEquals('Product description in English', LProduto.DESCRICAO_EN,
      'AITranslate should set translated value');
  finally
    FreeAndNil(LProduto);
    FreeAndNil(LProcessor);
  end;
end;

procedure TTestAIProcessor.TestAIClassify_SetsPropertyValue;
var
  LMockClient: iSimpleAIClient;
  LProcessor: TSimpleAIProcessor;
  LProduto: TProdutoAITest;
begin
  LMockClient := TSimpleAIMockClient.New('Eletronico');
  LProcessor := TSimpleAIProcessor.New(LMockClient);
  LProduto := TProdutoAITest.Create;
  try
    LProduto.DESCRICAO := 'Um notebook com processador Intel i7';
    LProcessor.Process(LProduto);
    CheckEquals('Eletronico', LProduto.CATEGORIA,
      'AIClassify should set category');
  finally
    FreeAndNil(LProduto);
    FreeAndNil(LProcessor);
  end;
end;

procedure TTestAIProcessor.TestAIValidate_Valid_NoException;
var
  LMockClient: iSimpleAIClient;
  LProcessor: TSimpleAIProcessor;
  LEmail: TEmailAITest;
begin
  LMockClient := TSimpleAIMockClient.New('VALIDO');
  LProcessor := TSimpleAIProcessor.New(LMockClient);
  LEmail := TEmailAITest.Create;
  try
    LEmail.EMAIL := 'test@example.com';
    LProcessor.Process(LEmail);
    // No exception = passed
    CheckTrue(True, 'Valid value should not raise exception');
  finally
    FreeAndNil(LEmail);
    FreeAndNil(LProcessor);
  end;
end;

procedure TTestAIProcessor.TestAIValidate_Invalid_RaisesException;
var
  LMockClient: iSimpleAIClient;
  LProcessor: TSimpleAIProcessor;
  LEmail: TEmailAITest;
  LRaised: Boolean;
begin
  LMockClient := TSimpleAIMockClient.New('INVALIDO: nao e um email valido');
  LProcessor := TSimpleAIProcessor.New(LMockClient);
  LEmail := TEmailAITest.Create;
  LRaised := False;
  try
    LEmail.EMAIL := 'not-an-email';
    try
      LProcessor.Process(LEmail);
    except
      on E: ESimpleAIValidation do
        LRaised := True;
    end;
    CheckTrue(LRaised, 'Invalid value should raise ESimpleAIValidation');
  finally
    FreeAndNil(LEmail);
    FreeAndNil(LProcessor);
  end;
end;

procedure TTestAIProcessor.TestProcess_NilObject_NoError;
var
  LMockClient: iSimpleAIClient;
  LProcessor: TSimpleAIProcessor;
begin
  LMockClient := TSimpleAIMockClient.New('');
  LProcessor := TSimpleAIProcessor.New(LMockClient);
  try
    LProcessor.Process(nil);
    CheckTrue(True, 'Process(nil) should not raise exception');
  finally
    FreeAndNil(LProcessor);
  end;
end;

procedure TTestAIProcessor.TestAISummarize_TruncatesIfMaxLength;
var
  LMockClient: iSimpleAIClient;
  LProcessor: TSimpleAIProcessor;
  LProduto: TProdutoAITest;
begin
  // Return a response longer than MaxLength (100)
  LMockClient := TSimpleAIMockClient.New(StringOfChar('A', 200));
  LProcessor := TSimpleAIProcessor.New(LMockClient);
  LProduto := TProdutoAITest.Create;
  try
    LProduto.DESCRICAO := 'Texto longo para resumir';
    LProcessor.Process(LProduto);
    CheckTrue(Length(LProduto.RESUMO) <= 100,
      'AISummarize should truncate to MaxLength');
  finally
    FreeAndNil(LProduto);
    FreeAndNil(LProcessor);
  end;
end;

{ TTestAIAttributes }

procedure TTestAIAttributes.TestAIGeneratedConstructor;
var
  LAttr: AIGenerated;
begin
  LAttr := AIGenerated.Create('Generate a description for {NOME}');
  try
    CheckEquals('Generate a description for {NOME}', LAttr.PromptTemplate,
      'AIGenerated should store prompt template');
  finally
    FreeAndNil(LAttr);
  end;
end;

procedure TTestAIAttributes.TestAISummarizeConstructor;
var
  LAttr: AISummarize;
begin
  LAttr := AISummarize.Create('DESCRICAO', 150);
  try
    CheckEquals('DESCRICAO', LAttr.SourceProperty);
    CheckEquals(150, LAttr.MaxLength);
  finally
    FreeAndNil(LAttr);
  end;
end;

procedure TTestAIAttributes.TestAISummarizeDefaultMaxLength;
var
  LAttr: AISummarize;
begin
  LAttr := AISummarize.Create('DESCRICAO');
  try
    CheckEquals(0, LAttr.MaxLength, 'Default MaxLength should be 0');
  finally
    FreeAndNil(LAttr);
  end;
end;

procedure TTestAIAttributes.TestAITranslateConstructor;
var
  LAttr: AITranslate;
begin
  LAttr := AITranslate.Create('DESCRICAO', 'English');
  try
    CheckEquals('DESCRICAO', LAttr.SourceProperty);
    CheckEquals('English', LAttr.TargetLanguage);
  finally
    FreeAndNil(LAttr);
  end;
end;

procedure TTestAIAttributes.TestAIClassifyConstructor;
var
  LAttr: AIClassify;
begin
  LAttr := AIClassify.Create('DESCRICAO', 'Cat1,Cat2,Cat3');
  try
    CheckEquals('DESCRICAO', LAttr.SourceProperty);
    CheckEquals('Cat1,Cat2,Cat3', LAttr.Categories);
  finally
    FreeAndNil(LAttr);
  end;
end;

procedure TTestAIAttributes.TestAIValidateConstructor;
var
  LAttr: AIValidate;
begin
  LAttr := AIValidate.Create('Must be valid', 'Custom error');
  try
    CheckEquals('Must be valid', LAttr.Rule);
    CheckEquals('Custom error', LAttr.ErrorMessage);
  finally
    FreeAndNil(LAttr);
  end;
end;

procedure TTestAIAttributes.TestAIValidateDefaultErrorMessage;
var
  LAttr: AIValidate;
begin
  LAttr := AIValidate.Create('Must be valid');
  try
    CheckEquals('', LAttr.ErrorMessage, 'Default ErrorMessage should be empty');
  finally
    FreeAndNil(LAttr);
  end;
end;

initialization
  RegisterTest('AI.Processor', TTestAIProcessor.Suite);
  RegisterTest('AI.Attributes', TTestAIAttributes.Suite);

end.
