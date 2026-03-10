# Built-in Skills - Design

**Goal:** Adicionar 5 novas Skills deterministicas built-in ao SimpleORM, cobrindo cenarios comuns de ERP.

**Architecture:** Todas as 5 Skills ficam em `SimpleSkill.pas` junto com as 3 existentes (TSkillLog, TSkillNotify, TSkillAudit). Cada Skill implementa `iSimpleSkill`, e atomica (faz uma unica coisa), e 100% deterministicas (sem IA).

**Publico-alvo:** Desenvolvedores de sistemas comerciais/ERP (vendas, estoque, financeiro) e aplicacoes diversas.

---

## Skills

### 1. TSkillTimestamp

Preenche campos de data automaticamente via RTTI.

- **RunAt**: `srBeforeInsert` (CREATED_AT) ou `srBeforeUpdate` (UPDATED_AT)
- Recebe o nome do campo no construtor
- Busca property pelo nome via RTTI, faz `SetValue` com `Now`
- Se a property nao existir na entidade, ignora silenciosamente

```pascal
constructor Create(const aFieldName: String; aRunAt: TSkillRunAt = srBeforeInsert);
```

```pascal
DAO.Skill(TSkillTimestamp.New('CREATED_AT', srBeforeInsert))
   .Skill(TSkillTimestamp.New('UPDATED_AT', srBeforeUpdate));
```

### 2. TSkillGuardDelete

Bloqueia delete quando existem registros dependentes.

- **RunAt**: sempre `srBeforeDelete`
- Recebe tabela dependente e campo FK
- Monta `SELECT COUNT(*) FROM {tabela} WHERE {fk} = :pValue`
- Pega valor da PK da entidade via RTTI (helper `EhChavePrimaria`)
- Se count > 0, levanta `ESimpleGuardDelete`
- Se count = 0, segue normalmente

```pascal
constructor Create(const aTable, aFKField: String);
```

```pascal
DAO.Skill(TSkillGuardDelete.New('ITEM_PEDIDO', 'ID_PEDIDO'))
   .Skill(TSkillGuardDelete.New('PAGAMENTO', 'ID_PEDIDO'));
```

**Exception:** `ESimpleGuardDelete = class(Exception)`

### 3. TSkillHistory

Grava snapshot dos valores atuais antes de update/delete.

- **RunAt**: `srBeforeUpdate` ou `srBeforeDelete`
- Le valores atuais via RTTI (published properties com `[Campo]`)
- Insere uma linha por campo na tabela de historico
- Converte valores para String

```pascal
constructor Create(const aHistoryTable: String = 'ENTITY_HISTORY'; aRunAt: TSkillRunAt = srBeforeUpdate);
```

```pascal
DAO.Skill(TSkillHistory.New('ENTITY_HISTORY', srBeforeUpdate))
   .Skill(TSkillHistory.New('ENTITY_HISTORY', srBeforeDelete));
```

**SQL de insert:**
```sql
INSERT INTO ENTITY_HISTORY
  (ENTITY_NAME, RECORD_ID, FIELD_NAME, OLD_VALUE, OPERATION, CREATED_AT)
VALUES
  (:pEntity, :pRecordId, :pField, :pOldValue, :pOperation, :pCreatedAt)
```

**DDL esperado:**
```sql
CREATE TABLE ENTITY_HISTORY (
  ID          INTEGER PRIMARY KEY,
  ENTITY_NAME VARCHAR(100),
  RECORD_ID   VARCHAR(50),
  FIELD_NAME  VARCHAR(100),
  OLD_VALUE   VARCHAR(4000),
  OPERATION   VARCHAR(20),
  CREATED_AT  TIMESTAMP
);
```

### 4. TSkillValidate

Chama `TSimpleValidator.Validate` automaticamente.

- **RunAt**: `srBeforeInsert` ou `srBeforeUpdate`
- Delega para `TSimpleValidator.Validate(aEntity)`
- Se falhar, `ESimpleValidator` e lancada naturalmente
- Zero configuracao

```pascal
constructor Create(aRunAt: TSkillRunAt = srBeforeInsert);
```

```pascal
DAO.Skill(TSkillValidate.New(srBeforeInsert))
   .Skill(TSkillValidate.New(srBeforeUpdate));
```

### 5. TSkillWebhook

Faz HTTP POST com dados da entidade em JSON apos operacao.

- **RunAt**: `srAfterInsert`, `srAfterUpdate` ou `srAfterDelete`
- Serializa entidade via `TSimpleSerializer.EntityToJSON`
- Payload: `{ entity, operation, timestamp, data }`
- Usa `THTTPClient` (System.Net.HttpClient nativo)
- Header Authorization opcional
- **Fire-and-forget**: erro HTTP e logado mas nao bloqueia a operacao CRUD

```pascal
constructor Create(const aURL: String; aRunAt: TSkillRunAt = srAfterInsert;
  const aAuthHeader: String = '');
```

```pascal
DAO.Skill(TSkillWebhook.New('https://api.example.com/hooks', srAfterInsert))
   .Skill(TSkillWebhook.New('https://api.example.com/hooks', srAfterUpdate, 'Bearer xyz'));
```

**Payload JSON:**
```json
{
  "entity": "PEDIDO",
  "operation": "INSERT",
  "timestamp": "2026-03-10T14:30:00",
  "data": { "ID": 1, "CLIENTE": "Joao", "VALOR": 150.00 }
}
```

---

## Decisoes

- Todas as Skills em `SimpleSkill.pas` (abordagem 1 — arquivo unico)
- Skills atomicas — cada uma faz UMA coisa
- 100% deterministicas — sem dependencia de IA
- DDL documentado no design e na documentacao publica, usuario cria tabelas manualmente
- `TSkillWebhook` e fire-and-forget (nao bloqueia CRUD em caso de falha HTTP)
- `TSkillTimestamp` ignora silenciosamente se property nao existir
- `TSkillGuardDelete` levanta exception propria `ESimpleGuardDelete`
