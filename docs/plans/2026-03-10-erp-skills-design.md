# ERP Skills - Design

**Goal:** Adicionar Skills e atributos focados em ERPs comerciais brasileiros ao SimpleORM: validacoes BR (CPF/CNPJ), numeracao sequencial, calculo de totais, movimentacao de estoque e geracao de parcelas financeiras.

**Architecture:** Atributos `[CPF]`/`[CNPJ]` em `SimpleAttributes.pas` com helpers RTTI em `SimpleRTTIHelper.pas` e validacao em `SimpleValidator.pas`. Skills de negocio (`TSkillSequence`, `TSkillCalcTotal`, `TSkillStockMove`, `TSkillDuplicate`) em `SimpleSkill.pas`. Tudo nos arquivos existentes.

**Publico-alvo:** Desenvolvedores de ERPs comerciais brasileiros (vendas, estoque, financeiro, fiscal).

---

## Atributos de Validacao BR

### [CPF]

Valida CPF brasileiro no TSimpleValidator.

- Atributo flag (sem campos): `CPF = class(TCustomAttribute)`
- Helper RTTI: `IsCPF: Boolean` em `TRttiPropertyHelper`
- Validacao: remove mascara (`.`, `-`), rejeita sequencias iguais (11111111111), verifica 11 digitos + algoritmo dos 2 digitos verificadores (pesos 10-2 e 11-2, mod 11)
- String vazia e ignorada (nao valida)

### [CNPJ]

Valida CNPJ brasileiro no TSimpleValidator.

- Atributo flag: `CNPJ = class(TCustomAttribute)`
- Helper RTTI: `IsCNPJ: Boolean` em `TRttiPropertyHelper`
- Validacao: remove mascara (`.`, `-`, `/`), rejeita sequencias iguais, verifica 14 digitos + algoritmo dos 2 digitos verificadores (pesos 5-2-9-8-7-6-5-4-3-2, mod 11)
- String vazia e ignorada

**Uso:**
```pascal
[Campo('CPF'), CPF]
property CPF: String read FCPF write FCPF;

[Campo('CNPJ'), CNPJ]
property CNPJ: String read FCNPJ write FCNPJ;
```

---

## Skills ERP

### TSkillSequence

Gera numeracao sequencial via tabela de controle no banco.

- **RunAt**: sempre `srBeforeInsert`
- Fluxo: SELECT ultimo numero → incrementa → UPDATE → seta na property via RTTI
- Se nao encontrar registro na tabela, insere com valor 1

```pascal
constructor Create(const aFieldName, aControlTable, aSerie: String);
```

```pascal
DAO.Skill(TSkillSequence.New('NUMERO', 'NUMERACAO', 'PEDIDO'));
```

**DDL:**
```sql
CREATE TABLE NUMERACAO (
  SERIE         VARCHAR(50) PRIMARY KEY,
  ULTIMO_NUMERO INTEGER DEFAULT 0
);
```

### TSkillCalcTotal

Recalcula campo total: Quantidade * Preco - Desconto.

- **RunAt**: `srBeforeInsert` ou `srBeforeUpdate`
- Opera apenas no objeto em memoria via RTTI (nao depende de banco)
- Desconto e opcional (assume 0 se nao informado)
- Arredondamento: 2 casas decimais

```pascal
constructor Create(const aTargetField, aQtyField, aPriceField: String;
  const aDiscountField: String = ''; aRunAt: TSkillRunAt = srBeforeInsert);
```

```pascal
DAO.Skill(TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO', 'DESCONTO', srBeforeInsert))
   .Skill(TSkillCalcTotal.New('VALOR_TOTAL', 'QUANTIDADE', 'PRECO_UNITARIO', 'DESCONTO', srBeforeUpdate));
```

### TSkillStockMove

Gera registro de movimentacao de estoque apos operacoes em itens.

- **RunAt**: `srAfterInsert` (SAIDA), `srAfterDelete` (ENTRADA/estorno)
- Le PRODUTO_ID e QUANTIDADE da entidade via RTTI
- TIPO determinado pelo RunAt: AfterInsert/AfterUpdate = 'SAIDA', AfterDelete = 'ENTRADA'
- Quantidade sempre positiva — TIPO indica direcao
- Nao atualiza saldo (saldo calculado por query/view)

```pascal
constructor Create(const aMoveTable, aProductField, aQtyField: String;
  aRunAt: TSkillRunAt = srAfterInsert);
```

```pascal
DAO.Skill(TSkillStockMove.New('MOV_ESTOQUE', 'PRODUTO_ID', 'QUANTIDADE', srAfterInsert))
   .Skill(TSkillStockMove.New('MOV_ESTOQUE', 'PRODUTO_ID', 'QUANTIDADE', srAfterDelete));
```

**DDL:**
```sql
CREATE TABLE MOV_ESTOQUE (
  ID          INTEGER PRIMARY KEY,
  PRODUTO_ID  INTEGER,
  QUANTIDADE  DOUBLE PRECISION,
  TIPO        VARCHAR(10),
  ENTITY_NAME VARCHAR(100),
  CREATED_AT  TIMESTAMP
);
```

### TSkillDuplicate

Gera parcelas financeiras (duplicatas) apos insert de pedido/venda.

- **RunAt**: sempre `srAfterInsert`
- Divide valor total pelo numero de parcelas
- Ultima parcela recebe diferenca de arredondamento
- Vencimentos escalonados: data base (Now) + (numero * intervalo em dias)
- STATUS sempre 'ABERTO'
- Se valor total <= 0, nao gera parcelas

```pascal
constructor Create(const aInstallmentTable, aTotalField: String;
  aCount, aIntervalDays: Integer);
```

```pascal
DAO.Skill(TSkillDuplicate.New('DUPLICATA', 'VALOR_TOTAL', 3, 30));
DAO.Skill(TSkillDuplicate.New('PARCELA', 'VALOR_TOTAL', 5, 28));
```

**DDL:**
```sql
CREATE TABLE PARCELA (
  ID          INTEGER PRIMARY KEY,
  ENTITY_ID   INTEGER,
  NUMERO      INTEGER,
  VALOR       DOUBLE PRECISION,
  VENCIMENTO  DATE,
  STATUS      VARCHAR(20),
  CREATED_AT  TIMESTAMP
);
```

**Arredondamento:** cada parcela = `Trunc(total/count * 100) / 100`, ultima = `total - soma_anteriores`

---

## Decisoes

- Atributos `[CPF]`/`[CNPJ]` em `SimpleAttributes.pas` (consistente com `[Email]`)
- Helpers `IsCPF`/`IsCNPJ` em `SimpleRTTIHelper.pas` (consistente com `IsEmail`)
- Validacao em `SimpleValidator.pas` (2 novos metodos: `ValidateCPF`, `ValidateCNPJ`)
- 4 Skills ERP em `SimpleSkill.pas` (consistente com as 8 existentes)
- Todas Skills atomicas — cada uma faz UMA coisa
- 100% deterministicas — sem IA
- TSkillCalcTotal nao depende de banco (opera em memoria)
- TSkillStockMove nao atualiza saldo (apenas registra movimentacao)
- TSkillDuplicate ajusta centavos na ultima parcela
- TSkillSequence assume que transacao e controlada externamente
- DDL documentado — usuario cria tabelas manualmente
