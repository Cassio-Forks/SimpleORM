unit Entidade.Produto;

interface

uses
  SimpleAttributes;

type
  [Tabela('PRODUTO')]
  TProduto = class
  private
    FID: Integer;
    FNOME: String;
    FPRECO: Currency;
    FQUANTIDADE: Integer;
    procedure SetID(const Value: Integer);
    procedure SetNOME(const Value: String);
    procedure SetPRECO(const Value: Currency);
    procedure SetQUANTIDADE(const Value: Integer);
  public
    constructor Create;
    destructor Destroy; override;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write SetID;
    [Campo('NOME'), NotNull]
    property NOME: String read FNOME write SetNOME;
    [Campo('PRECO')]
    property PRECO: Currency read FPRECO write SetPRECO;
    [Campo('QUANTIDADE')]
    property QUANTIDADE: Integer read FQUANTIDADE write SetQUANTIDADE;
  end;

implementation

{ TProduto }

constructor TProduto.Create;
begin

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

procedure TProduto.SetPRECO(const Value: Currency);
begin
  FPRECO := Value;
end;

procedure TProduto.SetQUANTIDADE(const Value: Integer);
begin
  FQUANTIDADE := Value;
end;

end.
