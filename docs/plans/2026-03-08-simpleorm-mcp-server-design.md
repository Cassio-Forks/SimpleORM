# SimpleMCPServer Design

## Objetivo

Criar um servidor MCP (Model Context Protocol) embutido no SimpleORM que permite AI assistants (Claude, Cursor, etc.) interagir diretamente com o banco de dados da aplicacao atraves do ORM, com seguranca e permissoes granulares.

## Arquitetura

```
Client AI (Claude/Cursor)
    | JSON-RPC 2.0
[Transporte: Stdio ou HTTP+SSE]
    |
[TSimpleMCPServer - Core]
    | dispatch por tool name
[TSimpleMCPEntityHandler]
    | usa SimpleORM
[iSimpleQuery -> Banco de Dados]
```

Dois transportes plugaveis sobre o mesmo core JSON-RPC:
- **Stdio**: ReadLn/WriteLn, processo local, sem autenticacao
- **HTTP+SSE**: via Horse, Bearer token obrigatorio

## Componentes

| Unit | Responsabilidade |
|------|-----------------|
| SimpleMCPServer.pas | Core: registry de entidades, dispatch de tools, JSON-RPC processing |
| SimpleMCPTransport.Stdio.pas | Transporte stdio (ReadLn/WriteLn) |
| SimpleMCPTransport.Http.pas | Transporte HTTP+SSE via Horse |
| SimpleMCPTypes.pas | Types: TMCPPermission, TMCPTool, JSON-RPC types |

## Registro e Permissoes

```pascal
TMCPPermission = (mcpRead, mcpInsert, mcpUpdate, mcpDelete, mcpCount, mcpDDL);
TMCPPermissions = set of TMCPPermission;

Server := TSimpleMCPServer.New;
Server
  .RegisterEntity<TUsuario>(Query, [mcpRead, mcpInsert, mcpUpdate])
  .RegisterEntity<TLog>(Query, [mcpRead, mcpCount])
  .Token('meu-token-secreto')
  .StartStdio;  // ou .StartHttp(9000)
```

## Tools MCP Geradas

Para cada entidade registrada (ex: TUsuario com [Tabela('USUARIOS')]):

| Tool Name | Permissao | Descricao |
|-----------|-----------|-----------|
| usuarios_query | mcpRead | SELECT com where, orderBy, skip, take |
| usuarios_get | mcpRead | Busca por ID |
| usuarios_insert | mcpInsert | INSERT com validacao |
| usuarios_update | mcpUpdate | UPDATE com validacao |
| usuarios_delete | mcpDelete | DELETE (respeita soft delete) |
| usuarios_count | mcpCount | COUNT com where |
| usuarios_describe | mcpRead | Schema da entidade |
| usuarios_ddl | mcpDDL | Gera CREATE TABLE |

Tools globais:
- list_entities: lista todas as entidades registradas
- raw_query: SQL SELECT customizado (read-only)

## Protocolo JSON-RPC

Request:
```json
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"usuarios_query","arguments":{"where":"ATIVO = 1","orderBy":"NOME","take":10}}}
```

Response:
```json
{"jsonrpc":"2.0","id":1,"result":{"content":[{"type":"text","text":"[{\"ID\":1,\"NOME\":\"Joao\"}]"}]}}
```

## Autenticacao

- Stdio: sem autenticacao (processo local, seguro por natureza)
- HTTP: Bearer token no header Authorization. Sem token valido = erro -32001 Unauthorized

## Seguranca

- Tools so aparecem se a entidade tem a permissao correspondente
- raw_query so executa statements que comecam com SELECT
- Toda operacao passa pelo SimpleORM (queries parametrizadas, validacao)
- Erros do banco nunca expoem stack trace

## Fluxo de Dados

1. Client envia JSON-RPC request
2. Transporte recebe e passa ao Core
3. Core valida autenticacao (se HTTP)
4. Core encontra tool pelo nome
5. Core verifica permissao da entidade
6. Core cria TSimpleDAO com o iSimpleQuery registrado
7. DAO executa operacao
8. Resultado serializado via TSimpleSerializer para JSON
9. Core monta JSON-RPC response
10. Transporte envia response ao client
