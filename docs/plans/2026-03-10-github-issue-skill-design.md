# TSkillGitHubIssue — Design Document

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Skill que cria Issues no GitHub automaticamente quando operacoes CRUD falham ou como auditoria de operacoes bem-sucedidas.

**Architecture:** Novo `TSkillGitHubIssue` implementando `iSimpleSkill` com dois modos: Normal (auditoria) e OnError (falhas). Adiciona `TSkillRunMode` ao sistema de Skills, `RunOnError` ao runner, e `OnError` callback ao DAO. Fire-and-forget via `System.Net.HttpClient`.

**Tech Stack:** Delphi, System.Net.HttpClient, GitHub REST API v3

---

## Componentes

### 1. TSkillGitHubIssue (em SimpleSkill.pas)

- Construtor: `New(aRepo, aToken, aRunAt, aRunMode)`
  - `aRepo`: `'owner/repo'`
  - `aToken`: Personal Access Token do GitHub
  - `aRunAt`: `TSkillRunAt` (ex: `srAfterInsert`)
  - `aRunMode`: `TSkillRunMode` (srmNormal ou srmOnError)
- Metodos fluent opcionais (retornam `TSkillGitHubIssue`, nao `iSimpleSkill`):
  - `Labels(aLabels: TArray<string>)` — labels customizadas
  - `TitleTemplate(aTemplate: string)` — template com placeholders `{entity}`, `{operation}`, `{error}`, `{timestamp}`
  - `BodyTemplate(aTemplate: string)` — idem para body
- Titulo padrao Normal: `[SimpleORM] {operation} on {entity}`
- Titulo padrao OnError: `[SimpleORM Error] {operation} on {entity}: {error}`
- Body padrao: entity JSON + operation + timestamp + erro (se OnError)
- HTTP: POST `https://api.github.com/repos/{owner}/{repo}/issues`
  - Headers: `Authorization: Bearer {token}`, `Accept: application/vnd.github+json`, `User-Agent: SimpleORM`
- Fire-and-forget: erro HTTP logado via OutputDebugString/Writeln, nunca interrompe o fluxo

### 2. TSkillRunMode (em SimpleTypes.pas)

```pascal
TSkillRunMode = (srmNormal, srmOnError);
```

### 3. Mudanca em iSimpleSkill (SimpleInterface.pas)

Adicionar metodo:
```pascal
function RunMode: TSkillRunMode;
```

Todas as skills existentes retornam `srmNormal` por padrao.

### 4. Mudanca em TSimpleSkillRunner (SimpleSkill.pas)

Novo metodo:
```pascal
procedure RunOnError(aEntity: TObject; aContext: iSimpleSkillContext; aException: Exception);
```

Filtra skills com `RunMode = srmOnError` e executa cada uma. O contexto (iSimpleSkillContext) deve ter a mensagem de erro disponivel.

### 5. Mudanca em iSimpleSkillContext (SimpleInterface.pas)

Adicionar metodo:
```pascal
function ErrorMessage: String;
```

`TSimpleSkillContext` recebe campo `FErrorMessage` opcional, preenchido so no RunOnError.

### 6. Mudanca em iSimpleDAO (SimpleInterface.pas)

```pascal
function OnError(aCallback: TSimpleErrorCallback): iSimpleDAO<T>;
```

Onde:
```pascal
TSimpleErrorCallback = reference to procedure(aEntity: TObject; aException: Exception);
```

### 7. Mudanca em TSimpleDAO (SimpleDAO.pas)

Nos metodos Insert/Update/Delete, adicionar try/except que:
1. Chama `FSkillRunner.RunOnError(aEntity, LContext, E)` para skills OnError
2. Chama `FOnError(aEntity, E)` se callback atribuido
3. Re-raise a excecao original

## Exemplo de uso

```pascal
// Modo OnError — cria Issue quando Insert falha
LDAO := TSimpleDAO<TProduto>.New(LQuery)
  .Skill(TSkillGitHubIssue.New(
    'meuuser/meurepo',
    'ghp_token123',
    srAfterInsert,
    srmOnError
  ))
  .OnError(procedure(aEntity: TObject; E: Exception)
    begin
      Writeln('Erro: ', E.Message);
    end);

// Modo Normal com template — cria Issue em todo Delete (auditoria)
LDAO := TSimpleDAO<TProduto>.New(LQuery)
  .Skill(TSkillGitHubIssue.New(
    'meuuser/meurepo',
    'ghp_token123',
    srAfterDelete,
    srmNormal
  ).Labels(['audit', 'delete'])
   .TitleTemplate('[Audit] {entity} deletado'));
```
