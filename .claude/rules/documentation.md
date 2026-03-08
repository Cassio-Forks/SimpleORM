---
description: Regras obrigatorias para atualizacao da documentacao publica HTML. Aplicavel a toda nova feature implementada.
globs: ["docs/index.html", "src/**/*.pas"]
---

# Regras de Documentacao

## Regra Fundamental

Toda implementacao de novo recurso no SimpleORM OBRIGATORIAMENTE DEVE atualizar a documentacao publica em `docs/index.html`. Sem atualizacao da documentacao, o recurso NAO esta completo.

## O Que Atualizar

Ao implementar um novo recurso, adicionar em `docs/index.html`:

1. **Nova secao** se for feature nova (com `id` para ancoragem e link no indice `<nav>`)
2. **Exemplo de codigo** mostrando uso pratico (em bloco `<pre><code>`)
3. **Tabela de referencia** se tiver metodos/atributos novos
4. **Entrada no indice** (nav no topo da pagina)

## Estrutura do HTML

O arquivo usa HTML semantico puro para maxima legibilidade por IAs e crawlers:

- `<section id="nome">` para cada feature
- `<h2>` para titulo de secao
- `<h3>` para subtitulos
- `<pre><code>` para exemplos de codigo
- `<table>` para referencias de API
- `<nav>` no topo com links para todas as secoes
- Sem JavaScript — conteudo 100% estatico

## Regras de Formato

- Idioma: Portugues sem acentos (consistente com CHANGELOG)
- Codigo Delphi em blocos `<pre><code>`
- HTML entities para caracteres especiais: `&lt;` `&gt;` `&amp;`
- Badge `<span class="badge badge-new">NEW</span>` para features recentes
- Classe `.note` para observacoes importantes
- Classe `.warning` para avisos

## O Que NAO Fazer

- NUNCA adicionar JavaScript — o HTML deve ser parseable sem JS
- NUNCA usar frameworks CSS externos — estilos embutidos no `<style>`
- NUNCA remover secoes existentes ao adicionar novas
- NUNCA esquecer de adicionar link no `<nav>` para nova secao
