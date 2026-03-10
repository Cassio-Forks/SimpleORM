# SimpleORM - AI Skills Sample

Demonstracao das 7 Skills baseadas em IA do SimpleORM.

## Como executar

1. Abra `SimpleORMAISkills.dpr` no Delphi
2. Compile e execute (F9)

## O que demonstra

Este sample usa um mock de IA para demonstrar todas as Skills sem precisar de API key.

### Skills de Enriquecimento
- **TSkillAIEnrich** - Gera conteudo com prompt template (`{TITULO}`)
- **TSkillAITranslate** - Traduz campo para outro idioma
- **TSkillAISummarize** - Resume texto longo
- **TSkillAITags** - Gera keywords/tags automaticas

### Skills de Validacao/Moderacao
- **TSkillAIModerate** - Verifica conteudo ofensivo (bloqueia se detectar)
- **TSkillAIValidate** - Valida dados com regra em linguagem natural (bloqueia se falhar)

### Skills de Analise
- **TSkillAISentiment** - Analisa sentimento (POSITIVO/NEGATIVO/NEUTRO)

## Em producao

Substitua o mock por `TSimpleAIClient`:

```pascal
LAI := TSimpleAIClient.New('claude', 'sua-api-key');
// ou
LAI := TSimpleAIClient.New('openai', 'sua-api-key');
```
