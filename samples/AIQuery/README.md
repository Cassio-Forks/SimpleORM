# SimpleORM AI Query - Sample

## Descricao

Este sample demonstra o uso do recurso AI Query do SimpleORM,
que permite fazer perguntas em linguagem natural ao banco de dados.

## Como executar

1. Abra `SimpleORMAIQuery.dpr` na IDE Delphi
2. A IDE ira gerar os arquivos `.dproj` e `.res` automaticamente
3. Compile e execute (F9)

## O que o sample demonstra

- Registro de entidades para gerar contexto de schema automaticamente
- `SuggestQuery` - LLM sugere SQL baseado em um objetivo descrito em linguagem natural
- `ExplainQuery` - LLM explica uma query SQL em linguagem natural
- Validacao de seguranca SQL (apenas SELECT permitido)

## Metodos disponiveis (requerem iSimpleQuery real)

- `NaturalLanguageQuery(pergunta)` - Traduz para SQL, executa, retorna TDataSet
- `AskQuestion(pergunta)` - Traduz para SQL, executa, LLM responde em linguagem natural

## Para usar com API e banco reais

```pascal
LAIQuery := TSimpleAIQuery.New(
  TSimpleQueryFiredac.New(FDConnection),  // conexao real
  TSimpleAIClient.New('claude', 'sua-api-key')  // API real
);
LAIQuery
  .RegisterEntity<TCliente>
  .RegisterEntity<TPedido>;

// Pergunta em linguagem natural
LDataSet := LAIQuery.NaturalLanguageQuery('Top 5 clientes por valor de compras');
```
