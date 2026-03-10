# Built-in Skills Demo

Demonstra as Skills built-in do SimpleORM:

1. **TSkillTimestamp** - Preenche campos de data automaticamente
2. **TSkillValidate** - Validacao automatica de entidades
3. **TSkillLog** - Log de operacoes
4. **TSkillNotify** - Callback de notificacao

## Como executar

1. Abra `SimpleORMSkills.dpr` na IDE Delphi
2. Compile e execute (F9)
3. O console mostrara a execucao de cada Skill

## Skills que requerem banco de dados

- **TSkillGuardDelete** - Precisa de conexao para verificar dependencias
- **TSkillHistory** - Precisa de conexao para gravar historico
- **TSkillAudit** - Precisa de conexao para gravar auditoria

## Skills que requerem servidor HTTP

- **TSkillWebhook** - Precisa de endpoint HTTP para receber POST
