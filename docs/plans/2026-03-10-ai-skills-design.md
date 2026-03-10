# AI Skills - Design

**Goal:** Adicionar 7 Skills baseadas em IA ao SimpleORM, cobrindo enriquecimento de dados, validacao/moderacao e analise de sentimento via LLM.

**Architecture:** Todas as 7 Skills ficam em `SimpleAISkill.pas` (novo arquivo, separado das Skills deterministicas). Cada Skill implementa `iSimpleSkill`, usa `aContext.AIClient.Complete(prompt)` para chamar o LLM, e le/escreve propriedades via RTTI.

**Publico-alvo:** Desenvolvedores que querem adicionar inteligencia artificial automatica ao pipeline CRUD sem escrever codigo de integracao com LLM.

---

## Exception

`ESimpleAIModeration = class(Exception)` — usada por TSkillAIModerate e TSkillAIValidate quando detectam problema.

---

## Skills de Enriquecimento (ignoram se AIClient = nil)

### TSkillAIEnrich

Preenche um campo com conteudo gerado por LLM a partir de um prompt template.

- **RunAt**: configuravel (default `srBeforeInsert`)
- Template suporta `{PropertyName}` — substitui pelo valor da property via RTTI
- Se AIClient for nil, ignora silenciosamente
- Se campo destino nao existir, ignora

```pascal
constructor Create(const aTargetField, aPromptTemplate: String;
  aRunAt: TSkillRunAt = srBeforeInsert);
```

```pascal
DAO.Skill(TSkillAIEnrich.New('DESCRICAO',
  'Gere uma descricao comercial para o produto {NOME} da categoria {CATEGORIA}'));
```

**Prompt enviado ao LLM:**
```
Gere uma descricao comercial para o produto Notebook Dell da categoria Informatica
```

### TSkillAITranslate

Traduz o valor de um campo e salva em outro campo.

- **RunAt**: configuravel (default `srBeforeInsert`)
- Se AIClient for nil, ignora silenciosamente
- Se campo origem estiver vazio, ignora
- Se campo origem ou destino nao existirem, ignora

```pascal
constructor Create(const aSourceField, aTargetField, aTargetLanguage: String;
  aRunAt: TSkillRunAt = srBeforeInsert);
```

```pascal
DAO.Skill(TSkillAITranslate.New('DESCRICAO', 'DESCRIPTION_EN', 'English'))
   .Skill(TSkillAITranslate.New('DESCRICAO', 'DESCRIPCION_ES', 'Spanish', srBeforeUpdate));
```

**Prompt enviado ao LLM:**
```
Translate the following text to English. Return only the translation, nothing else.

Text: Notebook Dell com processador i7 e 16GB RAM
```

### TSkillAISummarize

Resume o conteudo de um campo longo e salva em outro campo.

- **RunAt**: configuravel (default `srBeforeInsert`)
- MaxLength opcional (0 = sem limite)
- Se AIClient for nil, ignora silenciosamente
- Se campo origem estiver vazio, ignora

```pascal
constructor Create(const aSourceField, aTargetField: String;
  aMaxLength: Integer = 0; aRunAt: TSkillRunAt = srBeforeInsert);
```

```pascal
DAO.Skill(TSkillAISummarize.New('TEXTO_COMPLETO', 'RESUMO', 200));
```

**Prompt enviado ao LLM:**
```
Summarize the following text in at most 200 characters. Return only the summary, nothing else.

Text: [conteudo do campo]
```

### TSkillAITags

Gera tags/keywords automaticas e salva como string separada por virgulas.

- **RunAt**: configuravel (default `srBeforeInsert`)
- MaxTags configuravel (default 5)
- Se AIClient for nil, ignora silenciosamente
- Se campo origem estiver vazio, ignora

```pascal
constructor Create(const aSourceField, aTargetField: String;
  aMaxTags: Integer = 5; aRunAt: TSkillRunAt = srBeforeInsert);
```

```pascal
DAO.Skill(TSkillAITags.New('DESCRICAO', 'TAGS', 5));
```

**Prompt enviado ao LLM:**
```
Extract at most 5 keywords from the following text. Return only the keywords separated by commas, nothing else.

Text: [conteudo do campo]
```

---

## Skills de Validacao/Moderacao (lancam exception se AIClient = nil)

### TSkillAIModerate

Verifica se o conteudo de um campo viola politicas. Bloqueia se detectar problema.

- **RunAt**: configuravel (default `srBeforeInsert`)
- Policy opcional (string descrevendo o que bloquear)
- Se AIClient for nil, lanca `ESimpleAIModeration`
- Se campo estiver vazio, ignora
- LLM deve responder `APPROVED` ou `REJECTED: motivo`
- Se `REJECTED`, lanca `ESimpleAIModeration` com motivo

```pascal
constructor Create(const aField: String;
  const aPolicy: String = ''; aRunAt: TSkillRunAt = srBeforeInsert);
```

```pascal
DAO.Skill(TSkillAIModerate.New('COMENTARIO'));

DAO.Skill(TSkillAIModerate.New('DESCRICAO',
  'Rejeitar conteudo com linguagem ofensiva, discriminatoria ou spam',
  srBeforeInsert));
```

**Prompt enviado ao LLM (com policy):**
```
Analyze the following content and determine if it violates this policy: Rejeitar conteudo com linguagem ofensiva, discriminatoria ou spam

Content: [conteudo do campo]

Respond with exactly APPROVED if the content is acceptable, or REJECTED: reason if it violates the policy.
```

**Prompt enviado ao LLM (sem policy):**
```
Analyze the following content for offensive, inappropriate, or harmful material.

Content: [conteudo do campo]

Respond with exactly APPROVED if the content is acceptable, or REJECTED: reason if it contains problematic content.
```

### TSkillAIValidate

Valida dados da entidade contra uma regra em linguagem natural. Bloqueia se falhar.

- **RunAt**: configuravel (default `srBeforeInsert`)
- Envia todos os campos da entidade (properties com `[Campo]`) ao LLM
- ErrorMessage opcional (se vazio, usa motivo do LLM)
- Se AIClient for nil, lanca `ESimpleAIModeration`
- LLM deve responder `VALID` ou `INVALID: motivo`
- Se `INVALID`, lanca `ESimpleAIModeration`

```pascal
constructor Create(const aRule: String;
  const aErrorMessage: String = ''; aRunAt: TSkillRunAt = srBeforeInsert);
```

```pascal
DAO.Skill(TSkillAIValidate.New(
  'O preco deve ser coerente com a categoria do produto'));
```

**Prompt enviado ao LLM:**
```
Validate the following entity data against this rule: O preco deve ser coerente com a categoria do produto

Entity data:
NOME = Notebook Dell
CATEGORIA = Informatica
PRECO = 5000.00

Respond with exactly VALID if the data satisfies the rule, or INVALID: reason if it does not.
```

---

## Skill de Analise (ignora se AIClient = nil)

### TSkillAISentiment

Analisa sentimento de um campo e salva resultado em outro campo.

- **RunAt**: configuravel (default `srBeforeInsert`)
- LLM deve responder exatamente `POSITIVO`, `NEGATIVO` ou `NEUTRO`
- Se AIClient for nil, ignora silenciosamente
- Se campo origem estiver vazio, ignora

```pascal
constructor Create(const aSourceField, aTargetField: String;
  aRunAt: TSkillRunAt = srBeforeInsert);
```

```pascal
DAO.Skill(TSkillAISentiment.New('COMENTARIO', 'SENTIMENTO'));
```

**Prompt enviado ao LLM:**
```
Analyze the sentiment of the following text. Respond with exactly one word: POSITIVO, NEGATIVO, or NEUTRO.

Text: [conteudo do campo]
```

---

## Decisoes

- Todas as Skills AI em `SimpleAISkill.pas` (arquivo separado de `SimpleSkill.pas`)
- Exception unica `ESimpleAIModeration` para Moderate e Validate
- Skills de enriquecimento/analise ignoram silenciosamente se sem AIClient
- Skills de validacao/moderacao lancam exception se sem AIClient (sao criticas)
- Prompts em ingles para melhor compatibilidade com LLMs
- Respostas parseadas por convencao simples (APPROVED/REJECTED, VALID/INVALID, palavras-chave)
- Template `{PropertyName}` usa nome da property Delphi (nao nome do Campo)
- Todas as Skills atomicas — cada uma faz UMA coisa
