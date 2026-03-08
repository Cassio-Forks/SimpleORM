---
description: Regras obrigatorias para criacao de projetos sample demonstrando features do SimpleORM. Aplicavel a toda nova feature e todo arquivo em samples/.
globs: ["samples/**/*"]
---

# Regras de Criacao de Samples

## Regra Fundamental

Toda implementacao de novo recurso no SimpleORM OBRIGATORIAMENTE DEVE incluir um projeto sample demonstrando o recurso. Sem sample, o recurso NAO esta completo e NAO deve ser commitado.

## Estrutura de Projeto Delphi

### Arquivos que Claude DEVE criar
- `.dpr` — program file (ponto de entrada do executavel)
- `.pas` — units com codigo fonte (quando necessario)
- `README.md` — instrucoes de como executar

### Arquivos que Claude NUNCA deve criar
- `.dproj` — gerado EXCLUSIVAMENTE pela IDE Delphi (MSBuild XML ~50KB)
- `.res` — resource file binario, gerado EXCLUSIVAMENTE pela IDE
- `.dfm` — form layout, gerado EXCLUSIVAMENTE pelo designer visual da IDE
- `.dcu` — units compiladas (NUNCA commitar)
- `.exe` — executaveis (NUNCA commitar)

### Motivo
`.dproj`, `.res` e `.dfm` sao gerados pela IDE Delphi com estrutura complexa, GUIDs, configuracoes de compilador, e dados binarios. Criar manualmente resulta em arquivos invalidos que nao abrem na IDE.

## Regras do .dpr (Program File)

O `.dpr` tem estrutura FIXA e DIFERENTE de um `.pas`:

- DEVE comecar com `program NomeProjeto;` (NUNCA `unit`)
- DEVE conter `{$R *.res}` (link de resources)
- Console apps DEVEM conter `{$APPTYPE CONSOLE}` antes do `uses`
- DEVE terminar com `end.` (com ponto, nao ponto-e-virgula)
- NAO tem secoes `interface`/`implementation` (isso e de `.pas`)
- Uses clause lista units com `in 'caminho\relativo'` para units nao instaladas

### Console .dpr obrigatorio:
```pascal
program NomeProjeto;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Unit1 in 'Unit1.pas',
  Entidade.Xxx in '..\Entidades\Entidade.Xxx.pas';

begin
  // codigo
end.
```

### VCL .dpr obrigatorio:
```pascal
program NomeProjeto;

uses
  Vcl.Forms,
  Principal in 'Principal.pas' {FormPrincipal};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormPrincipal, FormPrincipal);
  Application.Run;
end.
```

## Regras de Conteudo

- SEMPRE reutilizar entidades de `samples/Entidades/` — NUNCA duplicar
- Referencia via path relativo: `Entidade.Pedido in '..\Entidades\Entidade.Pedido.pas'`
- DEVE demonstrar no minimo: Setup + Insert + Find (Update/Delete quando aplicavel)
- Console apps DEVEM usar `Writeln` para mostrar resultados ao usuario
- Console apps DEVEM terminar com `Readln` para nao fechar imediatamente
- Caminhos de banco DEVEM ter comentario indicando ajuste necessario

## Nomenclatura

- Diretorio: nome descritivo do recurso (ex: `Firedac`, `Validation`, `horse-integration`)
- Projeto: `SimpleORM` + Feature (ex: `SimpleORMFiredac.dpr`, `SimpleORMHorse.dpr`)
- Units auxiliares: nomes descritivos sem prefixo obrigatorio

## Apos Criar o Sample

- Documentar no `CHANGELOG.md` secao Added
- O desenvolvedor DEVE abrir o `.dpr` na IDE Delphi para gerar `.dproj` e `.res`
- Apos gerados pela IDE, `.dproj` e `.res` podem ser commitados
