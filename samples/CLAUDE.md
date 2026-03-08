# CLAUDE.md — samples/

Regras e padroes para projetos de exemplo do SimpleORM.

## Estrutura de Samples

Cada sample fica em seu proprio diretorio com nome descritivo:

```
samples/
  Firedac/          — Exemplo com driver FireDAC
  Unidac/           — Exemplo com driver UniDAC
  RestDW/           — Exemplo com driver RestDataware
  horse/            — Exemplo antigo de integracao Horse (legado)
  horse-integration/ — Exemplo novo: servidor + cliente Horse
  Validation/       — Exemplo de validacao de entidades
  FMX/              — Exemplo com FireMonkey
  ActiveRecord_Builder/ — Exemplo com padrao ActiveRecord
  Entidades/        — Entidades compartilhadas entre samples
```

## Entidades Compartilhadas

- Entidades reutilizaveis ficam em `samples/Entidades/`
- Samples referenciam via path relativo: `..\..\Entidades\Entidade.Pedido.pas`
- NUNCA duplicar definicoes de entidade entre samples

## Padrao de Entidade

```pascal
unit Entidade.NomeDaEntidade;

interface

uses
  SimpleAttributes;

type
  [Tabela('NOME_TABELA')]
  TNomeEntidade = class
  private
    FField: Type;
    procedure SetField(const Value: Type);
  public
    constructor Create;
    destructor Destroy; override;
  published
    [Campo('NOME_COLUNA'), PK, AutoInc]
    property Field: Type read FField write SetField;
  end;
```

Regras:
- Classe: `T` + nome da entidade (PascalCase ou UPPERCASE como padrao legado)
- `[Tabela]` na classe, `[Campo]` nas propriedades `published`
- Sempre ter `constructor Create` e `destructor Destroy; override` (mesmo se vazios)
- Propriedades com getter/setter explicitos (nao usar campo direto)

## Padrao de Projeto Sample

### Console Application (preferido para novos samples):
```pascal
program NomeSample;
{$APPTYPE CONSOLE}
uses ...;
begin
  // Setup
  // Demonstracao
  Writeln('Done!');
  Readln;
end.
```

### VCL Application:
- Um form principal com botoes demonstrando operacoes
- DAO criado no `AfterConstruction` ou `FormCreate`
- Operacoes em event handlers dos botoes

## Conexao com Banco

- Configurar conexao no proprio sample (nao depender de configs externas)
- Usar parametros inline quando possivel:
  ```pascal
  LConn.Params.DriverID := 'FB';
  LConn.Params.Database := 'C:\database\MEUBANCO.FDB';
  ```
- Comentar caminhos de banco para que o usuario ajuste

## Demonstracao de Features

Cada sample deve demonstrar no minimo:
1. **Setup** — Criacao de conexao e DAO
2. **Insert** — Inserir uma entidade
3. **Find** — Buscar lista e por ID
4. **Update** — Atualizar entidade (se aplicavel)
5. **Delete** — Deletar entidade (se aplicavel)

### Horse Integration Sample

Diretorio `horse-integration/` com subdiretorios:
- `Server/` — Projeto console com `THorse.Listen`
- `Client/` — Projeto console ou VCL usando `TSimpleQueryHorse`
- `README.md` — Explicacao de como rodar

O servidor mostra `RegisterEntity` com minimo de codigo.
O cliente mostra que trocar de `TSimpleQueryFiredac` para `TSimpleQueryHorse` e a unica mudanca.

## Dependencias

- Samples podem usar `boss.json` para gerenciar dependencias (Horse, etc)
- Reference ao SimpleORM via path relativo ao `src/`
- NUNCA commitar binarios compilados (`.exe`, `.dcu`, etc)
