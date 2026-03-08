# SimpleORM MCP Server

Servidor MCP que expoe entidades SimpleORM para AI assistants.

## Configuracao no Claude Code

Adicione ao seu `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "minha-app": {
      "command": "C:\\caminho\\para\\MCPServerStdio.exe",
      "args": []
    }
  }
}
```

## Uso

1. Configure a conexao com o banco de dados no .dpr
2. Registre as entidades com permissoes desejadas
3. Compile o projeto no Delphi IDE
4. Configure como MCP server no Claude Code

## Permissoes Disponiveis

- `mcpRead` — Query, Get, Describe
- `mcpInsert` — Insert com validacao
- `mcpUpdate` — Update com validacao
- `mcpDelete` — Delete (respeita soft delete)
- `mcpCount` — Count com where
- `mcpDDL` — Gerar CREATE TABLE
