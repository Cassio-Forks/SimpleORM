# SimpleAIQuery Design

## Objetivo

Permitir que aplicacoes Delphi facam perguntas em linguagem natural ao banco de dados, com o SimpleORM traduzindo para SQL via LLM, executando de forma segura, e retornando resultados.

## Arquitetura

```
[App Delphi]
        | NaturalLanguageQuery('pergunta')
[TSimpleAIQuery]
        | monta contexto (schema das entidades)
[iSimpleAIClient] -> Claude API / OpenAI API
        | retorna SQL
[Validacao de seguranca (SELECT only)]
        |
[iSimpleQuery.Open(SQL)]
        |
[Resultado como JSON ou DataSet]
```

## Componentes

| Unit | Responsabilidade |
|------|-----------------|
| SimpleAIQuery.pas | Core: NaturalLanguageQuery, AskQuestion, ExplainQuery, SuggestQuery. Usa RTTI para extrair schema e montar contexto |
| SimpleAIClient.pas | Compartilhado com AI Enrichment — mesmo client HTTP |

## Metodos

| Metodo | Input | Output | Descricao |
|--------|-------|--------|-----------|
| NaturalLanguageQuery | pergunta: String | TDataSet | Traduz para SQL, executa, retorna resultado |
| AskQuestion | pergunta: String | String | Traduz para SQL, executa, LLM responde em linguagem natural |
| ExplainQuery | sql: String | String | Explica SQL em linguagem natural |
| SuggestQuery | objetivo: String | String | Sugere SQL baseado no objetivo |

## Registro e Uso

```pascal
var
  AIQuery: TSimpleAIQuery;
begin
  AIQuery := TSimpleAIQuery.New(Query, AIClient);
  AIQuery
    .RegisterEntity<TUsuario>
    .RegisterEntity<TPedido>
    .RegisterEntity<TProduto>;

  // Natural Language Query
  LDataSet := AIQuery.NaturalLanguageQuery('Top 5 clientes por valor de compras em 2025');

  // Ask Question (resposta em texto)
  LResposta := AIQuery.AskQuestion('Qual o ticket medio de vendas?');

  // Explain SQL
  LExplicacao := AIQuery.ExplainQuery('SELECT ...');

  // Suggest SQL
  LSQL := AIQuery.SuggestQuery('Encontrar clientes inativos ha mais de 90 dias');
end;
```

## Geracao de Contexto Schema

O TSimpleAIQuery gera automaticamente o schema das entidades registradas para usar como contexto no prompt:

```
Voce e um assistente SQL. O banco de dados tem as seguintes tabelas:

Tabela: USUARIOS
Colunas: ID (integer, PK, AutoInc), NOME (string, NotNull), EMAIL (string), ATIVO (boolean), DATA_CADASTRO (datetime)

Tabela: PEDIDOS
Colunas: ID (integer, PK, AutoInc), ID_USUARIO (integer, FK), VALOR (float), DATA (datetime), STATUS (string)

Tabela: PRODUTOS
Colunas: ID (integer, PK, AutoInc), NOME (string), PRECO (float), CATEGORIA (string)
```

## Seguranca

- SQL gerado pelo LLM passa por validacao rigorosa (SELECT only)
- Semicolons bloqueados
- Keywords perigosos bloqueados (INSERT, UPDATE, DELETE, DROP, ALTER, CREATE, TRUNCATE, EXEC, GRANT, REVOKE)
- Schema enviado ao LLM contem apenas estrutura (nomes de tabelas/colunas, tipos) — NUNCA dados
- MaxRows configuravel para limitar resultados (padrao: 100)
- Tipo de banco (TSQLType) informado ao LLM para gerar SQL no dialeto correto

## Fluxo NaturalLanguageQuery

1. Monta schema context via RTTI de entidades registradas
2. Envia prompt: schema + pergunta + instrucoes ("Gere APENAS o SQL SELECT, sem explicacao")
3. Recebe SQL do LLM
4. Valida seguranca (SELECT only, sem keywords perigosos)
5. Executa via iSimpleQuery.Open
6. Retorna DataSet

## Fluxo AskQuestion

1-5. Igual ao NaturalLanguageQuery
6. Converte resultado do DataSet para JSON
7. Envia novo prompt: pergunta original + dados JSON + "Responda em linguagem natural"
8. Retorna texto do LLM
