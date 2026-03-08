# CLAUDE.md — samples/

Regras e padroes para projetos de exemplo do SimpleORM.

## Estrutura de Projeto Delphi

Um projeto Delphi e composto por varios tipos de arquivo com propositos distintos. E FUNDAMENTAL entender a diferenca entre eles:

### Arquivos de um Projeto Delphi

| Arquivo | Proposito | Quem cria |
|---------|-----------|-----------|
| `.dpr` | **Program file** — ponto de entrada do executavel. Contem `program`, `uses`, `{$R *.res}`, `begin`/`end` | Desenvolvedor/Claude |
| `.dproj` | **Project file** — configuracao MSBuild XML (compilador, plataformas, paths, packages). ~50KB | **IDE Delphi** (NUNCA criar manualmente) |
| `.res` | **Resource file** — icones, versao, manifesto compilados. Binario | **IDE Delphi** (NUNCA criar manualmente) |
| `.pas` | **Unit file** — codigo fonte. Contem `unit`, `interface`, `implementation` | Desenvolvedor/Claude |
| `.dfm` | **Form file** — layout visual de formularios VCL/FMX | **IDE Delphi** (NUNCA criar manualmente) |
| `.groupproj` | **Group file** — agrupa multiplos .dproj para abrir juntos | **IDE Delphi** |

### Regras Criticas

- **NUNCA criar `.dproj` manualmente** — sao gerados pela IDE Delphi ao abrir o `.dpr`
- **NUNCA criar `.res` manualmente** — sao binarios gerados pela IDE
- **NUNCA criar `.dfm` manualmente** — sao gerados pelo designer visual da IDE
- Claude DEVE criar: `.dpr`, `.pas`, `README.md`
- O desenvolvedor abre o `.dpr` na IDE para gerar `.dproj` e `.res`

## Estrutura do .dpr (Program File)

O `.dpr` e o arquivo principal de um projeto Delphi. Sua estrutura e FIXA:

### Console Application
```pascal
program NomeProjeto;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Generics.Collections,
  SimpleDAO,
  SimpleInterface,
  SimpleQueryFiredac,
  FireDAC.Comp.Client,
  Entidade.Pedido in '..\Entidades\Entidade.Pedido.pas';

var
  LConn: TFDConnection;
  LDAO: iSimpleDAO<TPEDIDO>;
begin
  // Setup e demonstracao
  Readln;
end.
```

### VCL Application
```pascal
program NomeProjeto;

uses
  Vcl.Forms,
  Principal in 'Principal.pas' {FormPrincipal},
  Entidade.Pedido in '..\Entidades\Entidade.Pedido.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormPrincipal, FormPrincipal);
  Application.Run;
end.
```

### Elementos obrigatorios do .dpr

1. `program NomeProjeto;` — DEVE ser a primeira linha (sem `unit`!)
2. `{$APPTYPE CONSOLE}` — OBRIGATORIO para apps console (antes de `uses`)
3. `{$R *.res}` — OBRIGATORIO em todo projeto (link de resources)
4. `uses` — lista TODAS as units com `in 'caminho'` para units nao instaladas
5. `begin`/`end.` — bloco principal (com ponto final!)

### .dpr NAO e uma unit .pas

| `.dpr` (program) | `.pas` (unit) |
|-------------------|---------------|
| Comeca com `program` | Comeca com `unit` |
| Tem `begin`/`end.` executavel | Tem `interface`/`implementation` |
| Um por projeto | Multiplos por projeto |
| Lista units no `uses` com paths `in '...'` | Lista units no `uses` sem paths |
| NAO tem `interface`/`implementation` | SEMPRE tem `interface`/`implementation` |
| `{$R *.res}` obrigatorio | Sem `{$R *.res}` |

## Estrutura de Samples

```
samples/
  NomeSample/
    NomeSample.dpr         — Program file (ponto de entrada)
    [NomeSample.dproj]     — Project file (gerado pela IDE)
    [NomeSample.res]       — Resources (gerado pela IDE)
    [Principal.pas]        — Form unit (VCL apps)
    [Principal.dfm]        — Form layout (gerado pela IDE)
    [README.md]            — Como executar o sample
  Entidades/               — Entidades compartilhadas
    Entidade.Pedido.pas
  Database/                — Bancos de teste
    MEUBANCO.FDB
```

### Nomenclatura de Projeto

- Prefixo `SimpleORM` + feature: `SimpleORMFiredac`, `SimpleORMHorse`, `SimpleORMValidation`
- O nome do `.dpr` DEVE ser igual ao nome do diretorio ou descrever claramente o sample
- Para sub-projetos (server/client): usar subdiretorios com nomes descritivos

### Referencia a Entidades Compartilhadas

```pascal
// No .dpr — path relativo com in
Entidade.Pedido in '..\Entidades\Entidade.Pedido.pas'
```

- SEMPRE reutilizar entidades de `samples/Entidades/`
- NUNCA duplicar entidades entre samples
- Se precisa de entidade especifica, criar em `Entidades/` e compartilhar

## Demonstracao de Features

Cada sample DEVE demonstrar no minimo:
1. **Setup** — Criacao de conexao e DAO
2. **Insert** — Inserir uma entidade
3. **Find** — Buscar lista e por ID
4. **Update** — Atualizar entidade (se aplicavel ao recurso)
5. **Delete** — Deletar entidade (se aplicavel ao recurso)

Para console apps: usar `Writeln` para mostrar resultados.
Para VCL apps: botoes com event handlers demonstrando operacoes.

## Conexao com Banco

- Configurar conexao inline no sample (nao depender de configs externas)
- Comentar caminhos de banco para indicar que o usuario deve ajustar:
  ```pascal
  LConn.Params.Database := 'C:\database\MEUBANCO.FDB'; // Ajustar caminho
  ```

## Regra: Todo Novo Recurso DEVE Ter Sample

Toda implementacao de novo recurso no SimpleORM OBRIGATORIAMENTE deve incluir um projeto sample demonstrando o recurso. O sample faz parte da entrega — sem sample, o recurso nao esta completo.
