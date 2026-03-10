# SimpleORM AI Entity Enrichment - Sample

## Descricao

Este sample demonstra o uso do recurso AI Entity Enrichment do SimpleORM,
que permite preenchimento automatico de propriedades via LLM usando atributos declarativos.

## Como executar

1. Abra `SimpleORMAIEnrichment.dpr` na IDE Delphi
2. A IDE ira gerar os arquivos `.dproj` e `.res` automaticamente
3. Compile e execute (F9)

## Atributos AI demonstrados

- `[AISummarize('DESCRICAO', 100)]` - Resume a descricao em ate 100 caracteres
- `[AIClassify('DESCRICAO', 'Eletronico,Vestuario,Alimento,Outros')]` - Classifica o produto
- `[AITranslate('DESCRICAO', 'English')]` - Traduz a descricao para ingles
- `[AIGenerated('Crie um slogan para {NOME}')]` - Gera slogan baseado no nome

## Para usar com API real

Substitua o mock client:

```pascal
LAIClient := TSimpleAIClient.New('claude', 'sua-api-key');
// ou
LAIClient := TSimpleAIClient.New('openai', 'sua-api-key');
```

## Integracao com TSimpleDAO

```pascal
DAOProduto := TSimpleDAO<TProduto>
  .New(Conn)
  .AIClient(TSimpleAIClient.New('claude', 'sua-api-key'));

// AI processa automaticamente antes de Insert/Update
DAOProduto.Insert(Produto);
```
