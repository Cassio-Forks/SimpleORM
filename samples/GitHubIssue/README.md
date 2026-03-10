# SimpleORM - GitHub Issue Skill

Exemplo de integracao do SimpleORM com GitHub Issues via `TSkillGitHubIssue`.

## Pre-requisitos

1. Conta no GitHub
2. Personal Access Token (PAT) com permissao `repo` (Settings > Developer settings > Personal access tokens)
3. Repositorio onde as Issues serao criadas

## Como usar

1. Abra `SimpleORMGitHubIssue.dpr` na IDE Delphi
2. Substitua `REPO` e `TOKEN` pelos seus dados
3. Compile e execute

## Modos de operacao

### OnError (srmOnError)
Cria Issue automaticamente quando uma operacao CRUD falha:
- Insert que viola constraint do banco
- Update com dados invalidos
- Delete bloqueado por FK

### Normal (srmNormal)
Cria Issue em toda operacao bem-sucedida (auditoria):
- Registrar todo Delete para compliance
- Auditar Inserts em tabelas criticas

## Placeholders para templates

| Placeholder | Descricao |
|-------------|-----------|
| `{entity}` | Nome da tabela da entidade |
| `{operation}` | INSERT, UPDATE ou DELETE |
| `{error}` | Mensagem de erro (vazio em modo Normal) |
| `{timestamp}` | Data/hora em formato ISO8601 |
