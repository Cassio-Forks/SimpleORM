# Changelog

Todas as mudancas notaveis neste projeto serao documentadas neste arquivo.

O formato e baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

> **OBRIGATORIO:** Todo novo recurso, correcao ou modificacao DEVE ser documentado aqui antes do commit.

---

## [Unreleased]

### Added
- **SimpleSerializer** - Serializador Entity <-> JSON via RTTI usando atributos `[Campo]`, sem dependencias externas (`SimpleSerializer.pas`)
- **SimpleHorseRouter** - Auto-geracao de rotas CRUD no Horse a partir de entidades SimpleORM com callbacks opcionais OnBeforeInsert/OnAfterInsert/OnBeforeUpdate/OnBeforeDelete (`SimpleHorseRouter.pas`)
- **SimpleQueryHorse** - Driver REST cliente que implementa `iSimpleQuery` via HTTP, com suporte a Bearer token e hook `OnBeforeRequest` (`SimpleQueryHorse.pas`)
- **Sample horse-integration** - Exemplos de servidor (HorseServer.dpr) e cliente (HorseClient.dpr) usando a integracao Horse

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
