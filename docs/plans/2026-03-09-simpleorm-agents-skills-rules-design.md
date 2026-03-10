# SimpleORM Agents, Skills & Rules — Design Document

**Goal:** Trazer conceitos de Agents, Skills e Rules para o SimpleORM sem perder a essencia de ORM, usando uma arquitetura de Pipeline de Middleware onde cada operacao CRUD passa por camadas encadeadas.

**Architecture:** Pipeline de Middleware inspirado em frameworks web. Rules sao middlewares declarativos (atributos na entidade), Skills sao middlewares plugaveis (fluent API no DAO), Agents sao orquestradores que montam pipelines dinamicamente. Tudo opcional — projetos existentes continuam funcionando sem alteracao.

---

## Rules (Regras)

Regras declarativas na entidade que executam automaticamente durante CRUD. Podem ser deterministicas (codigo Delphi puro) ou inteligentes (via AI).

### Atributos

```pascal
// Regra deterministica — expressao + momento + mensagem
[Rule('VALOR > 0', raBeforeInsert, 'Valor deve ser positivo')]
[Rule('STATUS <> ''CANCELADO''', raBeforeUpdate, 'Pedido cancelado nao pode ser alterado')]

// Regra AI — LLM avalia a regra
[AIRule('Verificar se o endereco do cliente e valido e real', raBeforeInsert)]
[AIRule('Verificar se o preco esta dentro da media de mercado', raBeforeUpdate)]
```

### Comportamento

- `Rule` avalia expressoes simples contra valores das propriedades da entidade (parser leve, sem banco)
- `AIRule` manda contexto da entidade + regra para o LLM avaliar
- Momento de execucao: `raBeforeInsert`, `raBeforeUpdate`, `raBeforeDelete`, `raAfterInsert`, `raAfterUpdate`, `raAfterDelete`
- Se a regra falha, lanca `ESimpleRuleViolation` e bloqueia a operacao

### Exemplo

```pascal
[Tabela('PEDIDOS')]
[Rule('VALOR > 0', raBeforeInsert, 'Valor deve ser positivo')]
[Rule('STATUS <> ''CANCELADO''', raBeforeUpdate, 'Pedido cancelado nao pode ser alterado')]
[AIRule('Verificar se a combinacao de produtos faz sentido comercial', raBeforeInsert)]
TPedido = class
published
  [Campo('VALOR')]
  property VALOR: Currency;
  [Campo('STATUS')]
  property STATUS: String;
end;
```

---

## Skills (Habilidades)

Unidades de comportamento reutilizaveis que se plugam ao DAO via fluent API. Podem ser atomicas (uma acao) ou compostas (sequencia de acoes).

### Interface base

```pascal
iSimpleSkill<T> = interface
  function Execute(aEntity: T; aContext: iSimpleSkillContext): iSimpleSkill<T>;
  function Name: String;
  function RunAt: TSkillRunAt; // srBeforeInsert, srAfterInsert, srBeforeUpdate, etc.
end;

iSimpleSkillContext = interface
  function Query: iSimpleQuery;
  function AIClient: iSimpleAIClient;
  function Logger: iSimpleQueryLogger;
  function EntityName: String;
  function Operation: String; // 'INSERT', 'UPDATE', 'DELETE'
end;
```

### Skill Atomico

```pascal
TSkillEnviarEmail = class(TInterfacedObject, iSimpleSkill<TPedido>)
  function Execute(aEntity: TPedido; aContext: iSimpleSkillContext): iSimpleSkill<TPedido>;
  function Name: String; // 'enviar-email'
  function RunAt: TSkillRunAt; // srAfterInsert
end;
```

### Skill Composto

```pascal
TSkillProcessarVenda = class(TInterfacedObject, iSimpleSkill<TPedido>)
  // Internamente executa sequencia:
  // 1. Validar estoque
  // 2. Atualizar estoque
  // 3. Classificar cliente (AI)
  // 4. Enviar notificacao
end;
```

### Fluent API

```pascal
DAOPedido := TSimpleDAO<TPedido>
  .New(Conn)
  .AIClient(AIClient)
  .Skill(TSkillEnviarEmail.New('smtp.server.com', 'user', 'pass'))
  .Skill(TSkillAtualizarEstoque.New)
  .Skill(TSkillProcessarVenda.New);
```

### Skills built-in

| Skill | Tipo | O que faz |
|-------|------|-----------|
| TSkillLog | Generico | Loga a operacao com detalhes da entidade |
| TSkillNotify | Generico | Dispara callback/evento apos operacao |
| TSkillAIEnrich | AI | Enriquece campos via LLM (evolucao do AIProcessor) |
| TSkillAudit | Generico | Grava registro de auditoria em tabela separada |

---

## Agents (Agentes)

Orquestradores que combinam Rules, Skills e operacoes CRUD. Dois modos: reativo (reage a eventos do DAO) e proativo (recebe objetivo em linguagem natural e decide o que fazer).

### Modo Reativo

```pascal
TAgentVendas = class(TSimpleAgent)
  procedure Configure; override;
end;

procedure TAgentVendas.Configure;
begin
  When(TPedido, aoAfterInsert)
    .Condition(function(aEntity: TObject): Boolean
      begin
        Result := TPedido(aEntity).VALOR > 5000;
      end)
    .Execute(TSkillEnviarEmail.New('gerente@empresa.com'))
    .Execute(TSkillLog.New('Pedido alto valor'));

  When(TPedido, aoAfterUpdate)
    .Condition(function(aEntity: TObject): Boolean
      begin
        Result := TPedido(aEntity).STATUS = 'CANCELADO';
      end)
    .Execute(TSkillEstornarEstoque.New)
    .Execute(TSkillNotificarCliente.New);
end;
```

### Modo Proativo

```pascal
Agent := TSimpleAgent.New(Conn, AIClient);
Agent
  .RegisterEntity<TPedido>
  .RegisterEntity<TCliente>
  .RegisterSkill(TSkillEnviarEmail.New)
  .RegisterSkill(TSkillAtualizarEstoque.New);

LResult := Agent.Execute(
  'Processar todos os pedidos pendentes de hoje, ' +
  'aplicar 10% de desconto para clientes VIP ' +
  'e enviar email de confirmacao'
);

Writeln(LResult.Summary);    // "3 pedidos processados, 1 desconto aplicado, 3 emails enviados"
Writeln(LResult.StepsCount); // 7
```

### Seguranca do modo proativo

SafeMode (padrao: True) exige inspecao antes de executar:

```pascal
Agent.SafeMode(True);

LPlan := Agent.Plan(
  'Deletar todos os clientes inativos ha mais de 2 anos'
);

Writeln(LPlan.Description);  // "DELETE em 47 registros de CLIENTES"
Writeln(LPlan.SQL);          // SELECT dos registros afetados
Writeln(LPlan.Risk);         // 'HIGH' — operacao destrutiva

if Aprovado then
  LPlan.Execute;
```

### Classe base

```pascal
TSimpleAgent = class(TInterfacedObject, iSimpleAgent)
private
  FReactions: TObjectList<TAgentReaction>;
  FSkills: TList<iSimpleSkill>;
  FEntities: TStringList;
  FAIClient: iSimpleAIClient;
public
  procedure Configure; virtual;
  function Execute(const aObjective: String): iAgentResult;
  function Plan(const aObjective: String): iAgentPlan;
  procedure React(aEntity: TObject; aOperation: TAgentOperation);
end;
```

---

## Pipeline — Ordem de Execucao

Quando `DAOPedido.Insert(Pedido)` e chamado:

```
1. Rules (Before)        — [Rule] e [AIRule] com raBeforeInsert
2. AI Attributes         — [AIGenerated], [AISummarize], etc. (ja existe)
3. Skills (Before)       — Skills com srBeforeInsert
4. SQL Execution         — INSERT real no banco (ja existe)
5. Skills (After)        — Skills com srAfterInsert
6. Agent (React)         — Reactions para aoAfterInsert
```

### Tratamento de erros

- Steps 1-3 falham → operacao cancelada, excecao propagada
- Step 4 falha → rollback (ja existe)
- Steps 5-6 falham → SQL ja executou, excecao propagada com log

### Tudo opcional

```pascal
// ORM puro — nada muda
DAOPedido := TSimpleDAO<TPedido>.New(Conn);
DAOPedido.Insert(Pedido);

// So Rules — automatico via RTTI, zero config
DAOPedido.Insert(Pedido);

// Rules + Skills
DAOPedido.Skill(TSkillLog.New).Insert(Pedido);

// Tudo junto
DAOPedido
  .AIClient(AIClient)
  .Skill(TSkillEnviarEmail.New)
  .Skill(TSkillAudit.New)
  .Agent(TAgentVendas.New)
  .Insert(Pedido);
```

---

## Units Novas

| Unit | Conteudo |
|------|----------|
| SimpleRules.pas | TSimpleRuleEngine — parser de expressoes, executor de Rules e AIRules |
| SimpleSkill.pas | TSimpleSkill base, iSimpleSkillContext, skills built-in |
| SimpleAgent.pas | TSimpleAgent, TAgentReaction, iAgentResult, iAgentPlan |

Interfaces novas em `SimpleInterface.pas`, atributos `Rule`/`AIRule` em `SimpleAttributes.pas`.

---

## Dependencias

- iSimpleAIClient (ja existe) — para AIRule e Agent proativo
- iSimpleQuery (ja existe) — para SkillContext e Agent
- RTTI (ja existe) — para deteccao de atributos Rule/AIRule
- TSimpleDAO (ja existe) — integracao do pipeline

## Seguranca

- Agent proativo: SafeMode por padrao, exige Plan + aprovacao antes de Execute
- Agent proativo: ValidateSQL reutilizado para queries geradas por LLM
- AIRule: resposta do LLM validada (VALIDO/INVALIDO pattern, como AIValidate)
- Skills: executam dentro do contexto de transacao do DAO quando possivel
