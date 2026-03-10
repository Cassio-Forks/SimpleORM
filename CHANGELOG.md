# Changelog

Todas as mudancas notaveis neste projeto serao documentadas neste arquivo.

O formato e baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

> **OBRIGATORIO:** Todo novo recurso, correcao ou modificacao DEVE ser documentado aqui antes do commit.

---

## [Unreleased]

### Added
- **Rule** - Atributo declarativo para regras de negocio deterministicas na entidade (SimpleRules.pas)
- **AIRule** - Atributo para regras de negocio inteligentes avaliadas por LLM (SimpleRules.pas)
- **TSimpleRuleEngine** - Motor de avaliacao de regras com parser de expressoes simples
- **ESimpleRuleViolation** - Excecao para violacoes de regras de negocio
- **iSimpleSkill** - Interface para plugins reutilizaveis no pipeline do DAO
- **iSimpleSkillContext** - Contexto com Query, AIClient e Logger disponivel para Skills
- **TSkillLog** - Skill built-in para logging de operacoes
- **TSkillNotify** - Skill built-in para callbacks/notificacoes
- **TSkillAudit** - Skill built-in para auditoria em tabela do banco
- **TSimpleAgent** - Agente com modo reativo (When/Condition/Execute) e proativo (Plan/Execute via LLM)
- **iAgentResult** - Interface para resultados de execucao de agentes
- **iAgentPlan** - Interface para planos de execucao com analise de risco
- **Pipeline DAO** - Integracao de Rules, Skills e Agents no pipeline Insert/Update/Delete do TSimpleDAO
- **Sample AgentsSkillsRules** - Projeto demonstrando Rules, Skills e Agents
- **TSkillTimestamp** - Skill built-in para preencher campos de data automaticamente via RTTI (`SimpleSkill.pas`)
- **TSkillGuardDelete** - Skill built-in para bloquear delete quando existem registros dependentes (`SimpleSkill.pas`)
- **TSkillHistory** - Skill built-in para gravar snapshot de valores antes de update/delete (`SimpleSkill.pas`)
- **TSkillValidate** - Skill built-in para validacao automatica via TSimpleValidator (`SimpleSkill.pas`)
- **TSkillWebhook** - Skill built-in para HTTP POST fire-and-forget apos operacoes CRUD (`SimpleSkill.pas`)
- **ESimpleGuardDelete** - Exception especifica para bloqueio de delete com dependencias (`SimpleSkill.pas`)
- **Sample BuiltinSkills** - Projeto demonstrando uso das Skills built-in (`samples/BuiltinSkills/`)
- **[CPF]** - Atributo de validacao de CPF brasileiro com algoritmo completo (`SimpleAttributes.pas`)
- **[CNPJ]** - Atributo de validacao de CNPJ brasileiro com algoritmo completo (`SimpleAttributes.pas`)
- **TSkillSequence** - Skill ERP para numeracao sequencial via tabela de controle (`SimpleSkill.pas`)
- **TSkillCalcTotal** - Skill ERP para calculo de total (qtd * preco - desconto) via RTTI (`SimpleSkill.pas`)
- **TSkillStockMove** - Skill ERP para movimentacao de estoque (entrada/saida) (`SimpleSkill.pas`)
- **TSkillDuplicate** - Skill ERP para geracao de parcelas financeiras (`SimpleSkill.pas`)
- **Sample ERPSkills** - Projeto demonstrando Skills ERP e validacao CPF/CNPJ (`samples/ERPSkills/`)
- **SimpleAISkill.pas** - Nova unit com 7 Skills baseadas em IA
- **TSkillAIEnrich** - Skill AI para gerar conteudo via prompt template com `{PropertyName}` (`SimpleAISkill.pas`)
- **TSkillAITranslate** - Skill AI para traducao automatica entre campos (`SimpleAISkill.pas`)
- **TSkillAISummarize** - Skill AI para resumo automatico de texto (`SimpleAISkill.pas`)
- **TSkillAITags** - Skill AI para geracao automatica de tags/keywords (`SimpleAISkill.pas`)
- **TSkillAIModerate** - Skill AI para moderacao de conteudo com bloqueio (`SimpleAISkill.pas`)
- **TSkillAIValidate** - Skill AI para validacao de dados com regra em linguagem natural (`SimpleAISkill.pas`)
- **TSkillAISentiment** - Skill AI para analise de sentimento (POSITIVO/NEGATIVO/NEUTRO) (`SimpleAISkill.pas`)
- **ESimpleAIModeration** - Exception para bloqueio por moderacao/validacao AI (`SimpleAISkill.pas`)
- **Sample AISkills** - Projeto demonstrando as 7 Skills AI com mock client (`samples/AISkills/`)
- **AI Query** - Perguntas em linguagem natural ao banco de dados via LLM (SimpleAIQuery.pas)
- **NaturalLanguageQuery** - Traduz pergunta para SQL, executa e retorna TDataSet
- **AskQuestion** - Traduz, executa e retorna resposta em linguagem natural
- **ExplainQuery** - Explica SQL em linguagem natural via LLM
- **SuggestQuery** - Sugere SQL baseado em objetivo descrito em linguagem natural
- **Validacao SQL AIQuery** - Bloqueio automatico de operacoes nao-SELECT em queries geradas por LLM
- **Sample AIQuery** - Projeto demonstrando AI Query com mock client
- **iSimpleAIClient** - Interface generica para comunicacao com LLMs Claude e OpenAI (SimpleAIClient.pas)
- **TSimpleAIClient** - Client HTTP para APIs de LLM com suporte a Claude e OpenAI (SimpleAIClient.pas)
- **AIGenerated** - Atributo para geracao automatica de conteudo via LLM com template de prompt (SimpleAIAttributes.pas)
- **AISummarize** - Atributo para resumo automatico de propriedades via LLM (SimpleAIAttributes.pas)
- **AITranslate** - Atributo para traducao automatica de propriedades via LLM (SimpleAIAttributes.pas)
- **AIClassify** - Atributo para classificacao automatica de conteudo via LLM (SimpleAIAttributes.pas)
- **AIValidate** - Atributo para validacao de conteudo via LLM (SimpleAIAttributes.pas)
- **TSimpleAIProcessor** - Motor de processamento que detecta atributos AI e executa via LLM (SimpleAIProcessor.pas)
- **AIClient** - Metodo no TSimpleDAO para integrar AI automaticamente em Insert/Update
- **Sample AIEnrichment** - Projeto demonstrando AI Entity Enrichment com mock client
- **SimpleSerializer** - Serializador Entity <-> JSON via RTTI usando atributos `[Campo]`, sem dependencias externas (`SimpleSerializer.pas`)
- **SimpleHorseRouter** - Auto-geracao de rotas CRUD no Horse a partir de entidades SimpleORM com callbacks opcionais OnBeforeInsert/OnAfterInsert/OnBeforeUpdate/OnBeforeDelete (`SimpleHorseRouter.pas`)
- **SimpleQueryHorse** - Driver REST cliente que implementa `iSimpleQuery` via HTTP, com suporte a Bearer token e hook `OnBeforeRequest` (`SimpleQueryHorse.pas`)
- **Sample horse-integration** - Exemplos de servidor (HorseServer.dpr) e cliente (HorseClient.dpr) usando a integracao Horse
- **DUnit Test Suite** - Suite completa de testes unitarios com 99 testes cobrindo SimpleAttributes, SimpleRTTIHelper, SimpleSQL, SimpleValidator e SimpleSerializer (`tests/SimpleORMTests.dpr`)
- **Regra de testes obrigatorios** - Toda nova feature deve incluir testes DUnit (`.claude/rules/testing.md`)
- **TSimpleQuerySupabase** - Novo driver `iSimpleQuery` para conexao direta com Supabase via PostgREST API (`SimpleQuerySupabase.pas`)
- **Supabase CRUD** - Suporte completo a INSERT (POST), UPDATE (PATCH), DELETE (DELETE) e SELECT (GET) via REST
- **Supabase Auth** - Suporte a API Key (service_role) e JWT token para Row Level Security
- **Supabase Paginacao** - Traducao automatica de Skip/Take para query params `limit`/`offset`
- **Supabase Sample** - Projeto exemplo demonstrando CRUD com Supabase (`samples/Supabase/`)
- **Entidade.Produto** - Entidade compartilhada TProduto para uso em samples (`samples/Entidades/Entidade.Produto.pas`)
- **TSimpleSupabaseAuth** - Autenticacao Supabase com SignIn, SignUp, SignOut e RefreshToken (`SimpleSupabaseAuth.pas`)
- **Supabase Auto-Refresh** - Token JWT renovado automaticamente quando proximo da expiracao
- **Supabase Auth + Query** - Novo construtor `TSimpleQuerySupabase.New(url, key, auth)` para integrar autenticacao com queries
- **TSimpleSupabaseRealtime** - Monitoramento de mudancas em tabelas Supabase com callbacks (`SimpleSupabaseRealtime.pas`)
- **Supabase Realtime Events** - Callbacks globais (OnInsert/OnUpdate/OnDelete) e por tabela (OnChange)
- **TSupabaseRealtimeEvent** - Record com Table, EventType, OldRecord e NewRecord para notificacoes

## [2.0.0] - 2026-03-08

### Added
- **NotZero** - Novo atributo de validacao para impedir valores zero (separado de NotNull)
- **Controle de transacoes** - Metodos `StartTransaction`, `Commit`, `Rollback`, `InTransaction` em `iSimpleQuery`, implementados nos 4 drivers (FireDAC, UniDAC, Zeos, RestDW)
- **SQLType** - Propriedade em `iSimpleQuery` para identificar o banco (Firebird, MySQL, SQLite, Oracle)
- **Paginacao** - Metodos `Skip(n)` e `Take(n)` em `iSimpleDAOSQLAttribute` com geracao de SQL especifica por banco (FIRST/SKIP, LIMIT/OFFSET, FETCH NEXT)
- **ForeignKey em relacionamentos** - Construtor `Create(aEntityName, aForeignKey)` na classe base `Relationship`
- **Eager loading** - Carregamento automatico de entidades `HasOne`/`BelongsTo` no `Find`
- **Lazy loading** - `TSimpleLazyLoader<T>` em `SimpleProxy.pas` para relacionamentos `HasMany`
- **Validacao expandida** - Novos atributos `Email`, `MinValue`, `MaxValue`, `Regex`; validacao de `Format` (MaxSize/MinSize) agora funcional
- **Soft Delete** - Atributo `SoftDelete('CAMPO')` para exclusao logica; `ForceDelete` para exclusao fisica; filtro automatico no `SELECT`
- **Batch Operations** - Metodos `InsertBatch`, `UpdateBatch`, `DeleteBatch` com transacao automatica
- **Query Logging** - Interface `iSimpleQueryLogger` com implementacao `TSimpleQueryLoggerConsole`; metodo `Logger(...)` em `iSimpleDAO`
- **SimpleProxy.pas** - Nova unit com `TSimpleLazyLoader<T>`
- **SimpleLogger.pas** - Nova unit com `iSimpleQueryLogger` e `TSimpleQueryLoggerConsole`
- **.claudeignore** - Arquivo para excluir binarios e configs do contexto do Claude Code

### Fixed
- **SQL Injection** - Metodo `Delete(aField, aValue)` agora usa query parametrizada em vez de concatenacao
- **Excecoes engolidas** - `SimpleQueryFiredac.ExecSQL` agora re-lanca excecoes apos rollback
- **EndTransaction sem retorno** - `SimpleQueryFiredac.EndTransaction` agora retorna `Result := Self`
- **Error handling nos drivers** - Adicionado tratamento de erro em RestDW (verifica `aErro`), UniDAC e Zeos (try/except com re-raise)
- **NotNull para Integer** - Valor 0 nao e mais tratado como nulo (usar `NotZero` para esse comportamento)
- **Variavel nao utilizada** - Removida variavel `a: string` em `SimpleQueryZeos.pas`

### Changed
- **Transacoes explicitas** - FireDAC nao inicia mais transacao automaticamente no construtor
- **EndTransaction** - Agora delega para `Commit` em todos os drivers
- **Estrutura do repositorio** - Fontes movidos para `src/`, exemplos renomeados de `Sample/` para `samples/`
- **boss.json** - `mainsrc` atualizado de `"./"` para `"./src"`
- **Paths nos projetos** - `.dpk`, `.dpr`, `.dproj`, `.groupproj` atualizados com novos caminhos

### Deprecated
- **SimpleJSON.pas** - Todas as classes marcadas como `deprecated`. Usar `SimpleJSONUtil.pas`

---

## [1.0.0] - Versoes anteriores

Versao original do SimpleORM com suporte a CRUD basico, mapeamento de entidades via atributos RTTI, drivers FireDAC/RestDW/UniDAC/Zeos, bind de formularios VCL/FMX, e validacao NotNull.
