# SimpleAI Entity Enrichment Design

## Objetivo

Permitir que propriedades de entidades SimpleORM sejam automaticamente preenchidas via LLM (Claude, OpenAI) durante operacoes de Insert/Update, usando atributos declarativos.

## Arquitetura

```
[Entity com atributos AI]
        | Insert/Update
[TSimpleDAO intercepta]
        | detecta properties com [AI*]
[TSimpleAIProcessor]
        | monta prompt + chama API
[TSimpleAIClient] -> Claude API / OpenAI API
        | resposta
[Preenche property automaticamente]
        |
[DAO persiste no banco]
```

## Componentes

| Unit | Responsabilidade |
|------|-----------------|
| SimpleAIClient.pas | Client HTTP generico para LLMs. Interface iSimpleAIClient com metodo Complete(prompt): String. Suporta Claude e OpenAI |
| SimpleAIAttributes.pas | Atributos: AIGenerated, AISummarize, AITranslate, AIClassify, AIValidate |
| SimpleAIProcessor.pas | Processa entidade via RTTI — detecta atributos AI, monta prompts com contexto da entidade, chama client, preenche properties |

## Atributos

| Atributo | Parametros | Descricao |
|----------|-----------|-----------|
| AIGenerated | prompt: String | Gera conteudo baseado no prompt + dados da entidade |
| AISummarize | sourceField: String | Resume o conteudo de outra property |
| AITranslate | targetLang: String; sourceField: String | Traduz de outra property para o idioma |
| AIClassify | categories: String (comma-separated) | Classifica em uma das categorias |
| AIValidate | rule: String | Validacao semantica - retorna erro se nao passar |

## Registro e Uso

```pascal
// Configurar AI client no DAO
DAOProduto := TSimpleDAO<TProduto>.New(Query)
  .AIClient(TSimpleAIClient.New('claude', 'sk-ant-xxx'));

// Na entidade:
[Tabela('PRODUTOS')]
TProduto = class
published
  [Campo('NOME')]
  property Nome: String ...;
  [Campo('DESCRICAO'), AIGenerated('Gere descricao de marketing baseado no nome')]
  property Descricao: String ...;
  [Campo('TAGS'), AIClassify('eletronico,vestuario,alimento,outro')]
  property Tags: String ...;
end;

// Insert automaticamente processa AI antes de persistir
DAOProduto.Insert(LProduto);
```

## iSimpleAIClient Interface

```pascal
iSimpleAIClient = interface
  function Complete(const aPrompt: String): String;
  function Model(const aValue: String): iSimpleAIClient;
  function MaxTokens(aValue: Integer): iSimpleAIClient;
  function Temperature(aValue: Double): iSimpleAIClient;
end;
```

## Fluxo de Dados

1. Dev chama `DAO.Insert(entity)` ou `DAO.Update(entity)`
2. Antes de gerar SQL, `TSimpleAIProcessor.Process(entity, AIClient)` e chamado
3. Processor itera properties via RTTI buscando atributos AI*
4. Para cada atributo encontrado, monta prompt com contexto (valores de outras properties)
5. Chama `AIClient.Complete(prompt)`
6. Preenche a property com o resultado
7. DAO continua normalmente com Insert/Update

## Seguranca

- API keys nunca sao logadas ou serializadas
- Timeout configuravel para chamadas HTTP (padrao: 30s)
- Se a chamada AI falhar, a operacao continua sem preencher (nao bloqueia CRUD)
- AIValidate lanca ESimpleValidator se o LLM retornar que a validacao falhou
