unit TestEntities;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  SimpleAttributes;

type
  { Entidade basica com todos os atributos principais }
  [Tabela('PEDIDO')]
  TPedidoTest = class
  private
    FID: Integer;
    FCLIENTE: String;
    FDATAPEDIDO: TDateTime;
    FVALORTOTAL: Currency;
    FOBSERVACAO: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('CLIENTE'), NotNull]
    property CLIENTE: String read FCLIENTE write FCLIENTE;
    [Campo('DATA_PEDIDO')]
    property DATAPEDIDO: TDateTime read FDATAPEDIDO write FDATAPEDIDO;
    [Campo('VALOR_TOTAL'), NotZero]
    property VALORTOTAL: Currency read FVALORTOTAL write FVALORTOTAL;
    [Ignore]
    property OBSERVACAO: String read FOBSERVACAO write FOBSERVACAO;
  end;

  { Entidade com SoftDelete }
  [Tabela('CLIENTE')]
  [SoftDelete('EXCLUIDO')]
  TClienteTest = class
  private
    FID: Integer;
    FNOME: String;
    FEMAIL: String;
    FEXCLUIDO: Integer;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull]
    property NOME: String read FNOME write FNOME;
    [Campo('EMAIL'), Email]
    property EMAIL: String read FEMAIL write FEMAIL;
    [Campo('EXCLUIDO')]
    property EXCLUIDO: Integer read FEXCLUIDO write FEXCLUIDO;
  end;

  { Entidade com validacoes completas }
  [Tabela('PRODUTO')]
  TProdutoTest = class
  private
    FID: Integer;
    FNOME: String;
    FPRECO: Double;
    FQUANTIDADE: Integer;
    FCODIGO: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull, Format([3, 100])]
    property NOME: String read FNOME write FNOME;
    [Campo('PRECO'), NotZero, MinValue(0.01), MaxValue(99999.99)]
    property PRECO: Double read FPRECO write FPRECO;
    [Campo('QUANTIDADE'), MinValue(0)]
    property QUANTIDADE: Integer read FQUANTIDADE write FQUANTIDADE;
    [Campo('CODIGO'), Regex('^[A-Z]{2}\d{4}$', 'Codigo deve ser 2 letras + 4 digitos')]
    property CODIGO: String read FCODIGO write FCODIGO;
  end;

  { Entidade com FK e relacionamentos }
  [Tabela('ITEM_PEDIDO')]
  TItemPedidoTest = class
  private
    FID: Integer;
    FPEDIDO_ID: Integer;
    FPRODUTO_ID: Integer;
    FQUANTIDADE: Integer;
    FVALOR: Currency;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('PEDIDO_ID'), FK, NotZero]
    property PEDIDO_ID: Integer read FPEDIDO_ID write FPEDIDO_ID;
    [Campo('PRODUTO_ID'), FK, NotZero]
    property PRODUTO_ID: Integer read FPRODUTO_ID write FPRODUTO_ID;
    [Campo('QUANTIDADE'), NotZero]
    property QUANTIDADE: Integer read FQUANTIDADE write FQUANTIDADE;
    [Campo('VALOR'), NotZero]
    property VALOR: Currency read FVALOR write FVALOR;
  end;

  { Entidade simples sem Campo (usa nome da property) }
  [Tabela('CATEGORIA')]
  TCategoriaTest = class
  private
    FID: Integer;
    FNOME: String;
    FATIVO: Integer;
  published
    [PK, AutoInc]
    property ID: Integer read FID write FID;
    [NotNull]
    property NOME: String read FNOME write FNOME;
    property ATIVO: Integer read FATIVO write FATIVO;
  end;

  { Entidade com Format (tamanho e precisao) }
  [Tabela('CONTA')]
  TContaTest = class
  private
    FID: Integer;
    FDESCRICAO: String;
    FVALOR: Currency;
    FNUMERO: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('DESCRICAO'), NotNull, Format(200)]
    property DESCRICAO: String read FDESCRICAO write FDESCRICAO;
    [Campo('VALOR'), Format(10, 2)]
    property VALOR: Currency read FVALOR write FVALOR;
    [Campo('NUMERO'), NumberOnly]
    property NUMERO: String read FNUMERO write FNUMERO;
  end;

  { Entidade com Display }
  [Tabela('USUARIO')]
  TUsuarioTest = class
  private
    FID: Integer;
    FNOME: String;
    FEMAIL: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull, Display('Nome Completo')]
    property NOME: String read FNOME write FNOME;
    [Campo('EMAIL'), Email, Display('E-mail')]
    property EMAIL: String read FEMAIL write FEMAIL;
  end;

  { Entidade com Timestamps }
  [Tabela('ENTITY_TIMESTAMPS')]
  TTestTimestampEntity = class
  private
    FId: Integer;
    FNome: String;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  published
    [Campo('ID')]
    [PK]
    [AutoInc]
    property Id: Integer read FId write FId;

    [Campo('NOME')]
    property Nome: String read FNome write FNome;

    [Campo('DT_CRIACAO')]
    [CreatedAt]
    property DataCriacao: TDateTime read FCreatedAt write FCreatedAt;

    [Campo('DT_ATUALIZACAO')]
    [UpdatedAt]
    property DataAtualizacao: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  { Entidade com CPF e CNPJ }
  [Tabela('PESSOA')]
  TPessoaTest = class
  private
    FID: Integer;
    FNOME: String;
    FCPF: String;
    FCNPJ: String;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull]
    property NOME: String read FNOME write FNOME;
    [Campo('CPF'), CPF]
    property CPF: String read FCPF write FCPF;
    [Campo('CNPJ'), CNPJ]
    property CNPJ: String read FCNPJ write FCNPJ;
  end;

implementation

end.
