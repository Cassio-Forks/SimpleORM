# SimpleORM Agents, Skills & Rules - Sample

## Descricao

Este sample demonstra os 3 novos modulos do SimpleORM:
- **Rules** - Regras declarativas na entidade que bloqueiam operacoes invalidas
- **Skills** - Plugins reutilizaveis (Log, Notify, Audit)
- **Agents** - Orquestradores reativos que respondem a eventos do DAO

## Como executar

1. Abra `SimpleORMAgents.dpr` na IDE Delphi
2. A IDE ira gerar os arquivos `.dproj` e `.res` automaticamente
3. Compile e execute (F9)

## O que o sample demonstra

### Rules
- `[Rule('VALOR > 0', raBeforeInsert, 'mensagem')]` - Regra deterministica
- Avaliacao de expressoes contra propriedades da entidade
- Bloqueio automatico com ESimpleRuleViolation

### Skills
- `TSkillLog` - Loga operacoes
- `TSkillNotify` - Dispara callbacks
- `TSkillAudit` - Grava auditoria (requer iSimpleQuery real)

### Agents (Reativo)
- `When(TPedido, aoAfterInsert).Condition(...).Execute(Skill)`
- Reagir a eventos do DAO com condicoes e skills encadeados

## Uso integrado com TSimpleDAO

```pascal
DAOPedido := TSimpleDAO<TPedido>
  .New(Conn)
  .AIClient(AIClient)
  .Skill(TSkillLog.New('app', srAfterInsert))
  .Agent(AgentVendas);

DAOPedido.Insert(Pedido);
// Pipeline: Rules -> AI -> Skills(Before) -> SQL -> Skills(After) -> Agent
```
