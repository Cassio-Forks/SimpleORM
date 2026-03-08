# SimpleORM Missing Features Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Adicionar os recursos que faltam ao SimpleORM comparado com ORMs maduros (Entity Framework, Hibernate, ActiveRecord, Eloquent, Django ORM), mantendo a simplicidade como principio fundamental.

**Architecture:** Cada feature segue o padrao existente: atributo em SimpleAttributes.pas → helper em SimpleRTTIHelper.pas → integracao em SimpleRTTI/SimpleSQL/SimpleDAO → testes DUnit → sample → docs. Todas as interfaces novas ficam em SimpleInterface.pas.

**Tech Stack:** Delphi, RTTI, FireDAC, DUnit, SimpleORM patterns

---

## Analise: O que falta vs ORMs famosos

| Feature | EF | Hibernate | ActiveRecord | Eloquent | Django | SimpleORM | Prioridade |
|---------|----|-----------|--------------|-----------|----|-----------|------------|
| Timestamps (CreatedAt/UpdatedAt) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | **ALTA** |
| Callbacks (Before/After CRUD) | ✅ | ✅ | ✅ | ✅ | ✅ (signals) | ❌ | **ALTA** |
| Aggregations (Count/Sum/Min/Max/Avg) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | **ALTA** |
| Scopes (Named Queries reutilizaveis) | ✅ | ✅ | ✅ | ✅ | ✅ (managers) | ❌ | **ALTA** |
| FindOrCreate / UpdateOrCreate | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | **MEDIA** |
| Select Specific Columns | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | **MEDIA** |
| Raw SQL com Entity Mapping | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | **MEDIA** |
| Cascade Delete | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | **MEDIA** |
| Auto-Migration (DDL Generation) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | **MEDIA** |
| Simple Cache (Identity Map) | ✅ (L1) | ✅ (L1/L2) | ❌ | ❌ | ❌ | ❌ | **BAIXA** |

---

## Task 1: Timestamps — `[CreatedAt]` e `[UpdatedAt]`

Preenche automaticamente a data de criacao e ultima atualizacao. Presente em TODOS os ORMs maduros.

**Uso esperado:**
```pascal
TUsuario = class
published
  [Campo('DT_CRIACAO')]
  [CreatedAt]
  property DataCriacao: TDateTime read FDataCriacao write FDataCriacao;

  [Campo('DT_ATUALIZACAO')]
  [UpdatedAt]
  property DataAtualizacao: TDateTime read FDataAtualizacao write FDataAtualizacao;
end;

// Insert: DataCriacao e DataAtualizacao preenchidos com Now automaticamente
// Update: DataAtualizacao atualizado com Now automaticamente
// Desenvolvedor NAO precisa fazer nada — e automatico
```

**Files:**
- Modify: `src/SimpleAttributes.pas` — adicionar atributos CreatedAt e UpdatedAt
- Modify: `src/SimpleRTTIHelper.pas` — adicionar helpers IsCreatedAt e IsUpdatedAt
- Modify: `src/SimpleRTTI.pas:~540-600` — preencher timestamps em DictionaryFields
- Test: `tests/TestSimpleAttributes.pas` — testar novos atributos
- Test: `tests/TestSimpleRTTIHelper.pas` — testar novos helpers

### Step 1: Criar atributos CreatedAt e UpdatedAt

**File:** `src/SimpleAttributes.pas`

Adicionar antes de `implementation`:

```pascal
CreatedAt = class(TCustomAttribute)
end;

UpdatedAt = class(TCustomAttribute)
end;
```

### Step 2: Criar helpers RTTI

**File:** `src/SimpleRTTIHelper.pas`

Na declaracao de TRttiPropertyHelper, adicionar:
```pascal
function IsCreatedAt: Boolean;
function IsUpdatedAt: Boolean;
```

Na implementacao:
```pascal
function TRttiPropertyHelper.IsCreatedAt: Boolean;
begin
  Result := Tem<CreatedAt>
end;

function TRttiPropertyHelper.IsUpdatedAt: Boolean;
begin
  Result := Tem<UpdatedAt>
end;
```

### Step 3: Auto-preencher timestamps em DictionaryFields

**File:** `src/SimpleRTTI.pas` — metodo `DictionaryFields`

No loop de propriedades, ANTES do `case prpRtti.PropertyType.TypeKind of`, adicionar:

```pascal
// Auto-fill CreatedAt on Insert (only if value is zero/empty)
if prpRtti.IsCreatedAt then
begin
  if prpRtti.GetValue(Pointer(FInstance)).AsExtended = 0 then
  begin
    aDictionary.Add(prpRtti.FieldName, Now);
    Continue;
  end;
end;

// Auto-fill UpdatedAt always
if prpRtti.IsUpdatedAt then
begin
  aDictionary.Add(prpRtti.FieldName, Now);
  Continue;
end;
```

**Logica:**
- `[CreatedAt]`: preenche com `Now` apenas se o valor atual for 0 (ou seja, no INSERT)
- `[UpdatedAt]`: SEMPRE preenche com `Now` (INSERT e UPDATE)

### Step 4: Excluir CreatedAt de UPDATE (FieldsUpdate)

**File:** `src/SimpleRTTI.pas` — metodo `Update` (que gera SET clause)

Apos o check de `IsIgnoreUpdate`, adicionar:

```pascal
if prpRtti.IsCreatedAt then
  Continue;
```

Isso garante que `[CreatedAt]` nunca e sobrescrito em UPDATE.

### Step 5: Testes DUnit

**File:** `tests/TestSimpleAttributes.pas`

```pascal
procedure TestSimpleAttributesCreatedAt.TestCreatedAtExists;
var Attr: CreatedAt;
begin
  Attr := CreatedAt.Create;
  try
    CheckNotNull(Attr, 'CreatedAt deve ser criado');
  finally
    Attr.Free;
  end;
end;

procedure TestSimpleAttributesUpdatedAt.TestUpdatedAtExists;
var Attr: UpdatedAt;
begin
  Attr := UpdatedAt.Create;
  try
    CheckNotNull(Attr, 'UpdatedAt deve ser criado');
  finally
    Attr.Free;
  end;
end;
```

**File:** `tests/TestSimpleRTTIHelper.pas`

```pascal
procedure TestRTTIHelperTimestamps.TestIsCreatedAt_WithAttribute_ReturnsTrue;
// Precisa de entidade de teste com [CreatedAt]
// Usar RTTI para verificar que IsCreatedAt retorna True
end;

procedure TestRTTIHelperTimestamps.TestIsUpdatedAt_WithAttribute_ReturnsTrue;
// Similar
end;
```

### Step 6: Commit

```bash
git add src/SimpleAttributes.pas src/SimpleRTTIHelper.pas src/SimpleRTTI.pas tests/TestSimpleAttributes.pas tests/TestSimpleRTTIHelper.pas
git commit -m "feat: add [CreatedAt] and [UpdatedAt] automatic timestamp attributes"
```

---

## Task 2: Callbacks — Before/After CRUD Events

Permite executar logica customizada antes e depois de operacoes CRUD. Equivalente a ActiveRecord callbacks, Eloquent events, Hibernate interceptors.

**Uso esperado:**
```pascal
DAO := TSimpleDAO<TUsuario>.New(Query)
  .OnBeforeInsert(
    procedure(aEntity: TObject)
    begin
      Writeln('Antes de inserir: ' + TUsuario(aEntity).Nome);
    end)
  .OnAfterInsert(
    procedure(aEntity: TObject)
    begin
      Writeln('Inserido com sucesso!');
    end)
  .OnBeforeUpdate(
    procedure(aEntity: TObject)
    begin
      // Auditar mudancas, validar regras de negocio
    end)
  .OnBeforeDelete(
    procedure(aEntity: TObject)
    begin
      // Verificar dependencias antes de deletar
    end);
```

**Files:**
- Modify: `src/SimpleInterface.pas` — adicionar metodos de callback na interface iSimpleDAO<T>
- Modify: `src/SimpleDAO.pas` — adicionar campos e implementar disparo de callbacks
- Test: `tests/TestSimpleDAO.pas` — testar callbacks

### Step 1: Definir tipo de callback

**File:** `src/SimpleInterface.pas`

Na secao `type` (antes das interfaces), adicionar:

```pascal
TSimpleCallback = reference to procedure(aEntity: TObject);
```

### Step 2: Adicionar metodos na interface iSimpleDAO<T>

**File:** `src/SimpleInterface.pas`

Na interface `iSimpleDAO<T>`, adicionar:

```pascal
function OnBeforeInsert(aCallback: TSimpleCallback): iSimpleDAO<T>;
function OnAfterInsert(aCallback: TSimpleCallback): iSimpleDAO<T>;
function OnBeforeUpdate(aCallback: TSimpleCallback): iSimpleDAO<T>;
function OnAfterUpdate(aCallback: TSimpleCallback): iSimpleDAO<T>;
function OnBeforeDelete(aCallback: TSimpleCallback): iSimpleDAO<T>;
function OnAfterDelete(aCallback: TSimpleCallback): iSimpleDAO<T>;
```

### Step 3: Implementar no DAO

**File:** `src/SimpleDAO.pas`

Adicionar campos privados:

```pascal
FOnBeforeInsert: TSimpleCallback;
FOnAfterInsert: TSimpleCallback;
FOnBeforeUpdate: TSimpleCallback;
FOnAfterUpdate: TSimpleCallback;
FOnBeforeDelete: TSimpleCallback;
FOnAfterDelete: TSimpleCallback;
```

Implementar setters (fluent, retornam Self):

```pascal
function TSimpleDAO<T>.OnBeforeInsert(aCallback: TSimpleCallback): iSimpleDAO<T>;
begin
  Result := Self;
  FOnBeforeInsert := aCallback;
end;
// ... repetir para os outros 5
```

Disparar nos metodos CRUD existentes. Exemplo no `Insert(aValue: T)`:

```pascal
function TSimpleDAO<T>.Insert(aValue: T): iSimpleDAO<T>;
var
  aSQL: String;
begin
  Result := Self;

  if Assigned(FOnBeforeInsert) then
    FOnBeforeInsert(aValue);

  // ... codigo existente de Insert ...

  if Assigned(FOnAfterInsert) then
    FOnAfterInsert(aValue);
end;
```

Repetir padrao para Update e Delete (incluindo ForceDelete e variantes com valor).

### Step 4: Testes

```pascal
procedure TestDAOCallbacks.TestOnBeforeInsert_ShouldFireBeforeInsert;
var
  LCalled: Boolean;
begin
  LCalled := False;
  FDAO.OnBeforeInsert(
    procedure(aEntity: TObject)
    begin
      LCalled := True;
    end);
  FDAO.Insert(FEntity);
  CheckTrue(LCalled, 'OnBeforeInsert deve ser chamado');
end;
```

### Step 5: Commit

```bash
git add src/SimpleInterface.pas src/SimpleDAO.pas tests/TestSimpleDAO.pas
git commit -m "feat: add Before/After CRUD callback events to iSimpleDAO"
```

---

## Task 3: Aggregations — Count, Sum, Min, Max, Avg

Funcoes de agregacao SQL acessiveis via fluent API. Todo ORM maduro tem isso.

**Uso esperado:**
```pascal
// Contar registros
Total := DAO.SQL.Where('ativo = 1').&End.Count;

// Somar valores
TotalVendas := DAO.SQL.Where('mes = 3').&End.Sum('valor');

// Minimo, maximo, media
Menor := DAO.Min('preco');
Maior := DAO.Max('preco');
Media := DAO.Avg('preco');
```

**Files:**
- Modify: `src/SimpleInterface.pas` — adicionar metodos de agregacao
- Modify: `src/SimpleSQL.pas` — gerar SQL de agregacao
- Modify: `src/SimpleDAO.pas` — executar e retornar resultado
- Test: `tests/TestSimpleSQL.pas` — testar SQL gerado

### Step 1: Adicionar na interface iSimpleDAO<T>

**File:** `src/SimpleInterface.pas`

```pascal
function Count: Integer;
function Sum(const aField: String): Double;
function Min(const aField: String): Double;
function Max(const aField: String): Double;
function Avg(const aField: String): Double;
```

### Step 2: Adicionar na interface iSimpleSQL<T>

**File:** `src/SimpleInterface.pas`

```pascal
function Count(var aSQL: String): iSimpleSQL<T>;
function Aggregate(var aSQL: String; const aFunction, aField: String): iSimpleSQL<T>;
```

### Step 3: Implementar SQL generation

**File:** `src/SimpleSQL.pas`

```pascal
function TSimpleSQL<T>.Count(var aSQL: String): iSimpleSQL<T>;
var
  aClassName: String;
  aSoftDeleteField: String;
begin
  Result := Self;
  aSQL := '';
  TSimpleRTTI<T>.New(FInstance)
    .TableName(aClassName)
    .SoftDeleteField(aSoftDeleteField);

  aSQL := 'select count(*) from ' + aClassName;

  if aSoftDeleteField <> '' then
    aSQL := aSQL + ' where ' + aSoftDeleteField + ' = 0';

  if FWhere <> '' then
  begin
    if aSoftDeleteField <> '' then
      aSQL := aSQL + ' and ' + FWhere
    else
      aSQL := aSQL + ' where ' + FWhere;
  end;
end;

function TSimpleSQL<T>.Aggregate(var aSQL: String; const aFunction, aField: String): iSimpleSQL<T>;
var
  aClassName: String;
  aSoftDeleteField: String;
begin
  Result := Self;
  aSQL := '';
  TSimpleRTTI<T>.New(FInstance)
    .TableName(aClassName)
    .SoftDeleteField(aSoftDeleteField);

  aSQL := 'select ' + aFunction + '(' + aField + ') from ' + aClassName;

  if aSoftDeleteField <> '' then
    aSQL := aSQL + ' where ' + aSoftDeleteField + ' = 0';

  if FWhere <> '' then
  begin
    if aSoftDeleteField <> '' then
      aSQL := aSQL + ' and ' + FWhere
    else
      aSQL := aSQL + ' where ' + FWhere;
  end;

  if FJoin <> '' then
    aSQL := StringReplace(aSQL, ' from ', ' from ' + aClassName + ' ' + FJoin + ' ', []);
end;
```

### Step 4: Implementar no DAO

**File:** `src/SimpleDAO.pas`

```pascal
function TSimpleDAO<T>.Count: Integer;
var
  aSQL: String;
begin
  TSimpleSQL<T>.New(nil)
    .DatabaseType(FQuery.SQLType)
    .Where(FSQL.Where)
    .Join(FSQL.Join)
    .Count(aSQL);

  FQuery.SQL.Clear;
  FQuery.SQL.Add(aSQL);
  FQuery.Open;
  Result := FQuery.DataSet.Fields[0].AsInteger;
end;

function TSimpleDAO<T>.Sum(const aField: String): Double;
var
  aSQL: String;
begin
  TSimpleSQL<T>.New(nil)
    .DatabaseType(FQuery.SQLType)
    .Where(FSQL.Where)
    .Join(FSQL.Join)
    .Aggregate(aSQL, 'SUM', aField);

  FQuery.SQL.Clear;
  FQuery.SQL.Add(aSQL);
  FQuery.Open;
  Result := FQuery.DataSet.Fields[0].AsFloat;
end;

// Min, Max, Avg seguem o mesmo padrao, mudando apenas o nome da funcao SQL
```

### Step 5: Testes

**File:** `tests/TestSimpleSQL.pas`

```pascal
procedure TestSimpleSQLAggregations.TestCount_ShouldGenerateCountSQL;
var SQL: String;
begin
  TSimpleSQL<TTestEntity>.New(nil).Count(SQL);
  CheckTrue(Pos('select count(*) from', LowerCase(SQL)) > 0);
end;

procedure TestSimpleSQLAggregations.TestSum_ShouldGenerateSumSQL;
var SQL: String;
begin
  TSimpleSQL<TTestEntity>.New(nil).Aggregate(SQL, 'SUM', 'valor');
  CheckTrue(Pos('sum(valor)', LowerCase(SQL)) > 0);
end;

procedure TestSimpleSQLAggregations.TestCount_WithSoftDelete_ShouldFilterDeleted;
var SQL: String;
begin
  TSimpleSQL<TTestSoftDeleteEntity>.New(nil).Count(SQL);
  CheckTrue(Pos('where deleted = 0', LowerCase(SQL)) > 0);
end;
```

### Step 6: Commit

```bash
git add src/SimpleInterface.pas src/SimpleSQL.pas src/SimpleDAO.pas tests/TestSimpleSQL.pas
git commit -m "feat: add Count, Sum, Min, Max, Avg aggregation methods"
```

---

## Task 4: Scopes — Named Query Fragments Reutilizaveis

Scopes sao filtros nomeados e reutilizaveis. Equivalente a Rails scopes, Eloquent local scopes, Django managers.

**Uso esperado:**
```pascal
// Definir scopes na entidade
TUsuario = class
published
  [Campo('ATIVO')]
  property Ativo: Integer read FAtivo write FAtivo;

  [Campo('DT_CRIACAO')]
  property DataCriacao: TDateTime read FDataCriacao write FDataCriacao;
end;

// Registrar scopes no DAO
DAO.RegisterScope('ativos', 'ATIVO = 1');
DAO.RegisterScope('recentes', 'DT_CRIACAO >= ' + QuotedStr(FormatDateTime('yyyy-mm-dd', Date - 30)));

// Usar scopes — fluent e combinavel
DAO.Scope('ativos').Find(Lista);                    // WHERE ATIVO = 1
DAO.Scope('ativos').Scope('recentes').Find(Lista);  // WHERE ATIVO = 1 AND DT_CRIACAO >= ...
DAO.Scope('ativos').SQL.OrderBy('NOME').&End.Find(Lista);  // Combinavel com fluent API
```

**Files:**
- Modify: `src/SimpleInterface.pas` — adicionar RegisterScope e Scope
- Modify: `src/SimpleDAO.pas` — implementar dicionario de scopes
- Test: `tests/TestSimpleDAO.pas` — testar scopes

### Step 1: Adicionar na interface iSimpleDAO<T>

**File:** `src/SimpleInterface.pas`

```pascal
function RegisterScope(const aName, aWhere: String): iSimpleDAO<T>;
function Scope(const aName: String): iSimpleDAO<T>;
function ClearScopes: iSimpleDAO<T>;
```

### Step 2: Implementar no DAO

**File:** `src/SimpleDAO.pas`

Adicionar campo privado:

```pascal
FScopes: TDictionary<String, String>;
FActiveScopes: TList<String>;
```

Inicializar no constructor e liberar no destructor.

```pascal
function TSimpleDAO<T>.RegisterScope(const aName, aWhere: String): iSimpleDAO<T>;
begin
  Result := Self;
  FScopes.AddOrSetValue(LowerCase(aName), aWhere);
end;

function TSimpleDAO<T>.Scope(const aName: String): iSimpleDAO<T>;
begin
  Result := Self;
  if FScopes.ContainsKey(LowerCase(aName)) then
    FActiveScopes.Add(FScopes[LowerCase(aName)]);
end;

function TSimpleDAO<T>.ClearScopes: iSimpleDAO<T>;
begin
  Result := Self;
  FActiveScopes.Clear;
end;
```

No metodo `Find`, antes de executar, concatenar scopes ativos ao WHERE:

```pascal
// Dentro de Find, antes de gerar SQL:
LScopeWhere := '';
for LScope in FActiveScopes do
begin
  if LScopeWhere <> '' then
    LScopeWhere := LScopeWhere + ' and ';
  LScopeWhere := LScopeWhere + LScope;
end;

if LScopeWhere <> '' then
begin
  if FSQL.Where <> '' then
    FSQL.Where(FSQL.Where + ' and ' + LScopeWhere)
  else
    FSQL.Where(LScopeWhere);
end;

// Limpar scopes apos uso
FActiveScopes.Clear;
```

### Step 3: Testes

```pascal
procedure TestDAOScopes.TestScope_ShouldApplyWhereClause;
begin
  FDAO.RegisterScope('ativos', 'ATIVO = 1');
  FDAO.Scope('ativos');
  // Verificar que o SQL gerado contem WHERE ATIVO = 1
end;

procedure TestDAOScopes.TestMultipleScopes_ShouldCombineWithAND;
begin
  FDAO.RegisterScope('ativos', 'ATIVO = 1');
  FDAO.RegisterScope('premium', 'TIPO = ''P''');
  FDAO.Scope('ativos').Scope('premium');
  // Verificar que o SQL contem ATIVO = 1 AND TIPO = 'P'
end;
```

### Step 4: Commit

```bash
git add src/SimpleInterface.pas src/SimpleDAO.pas tests/TestSimpleDAO.pas
git commit -m "feat: add named Scopes for reusable query fragments"
```

---

## Task 5: FindOrCreate e UpdateOrCreate

Padroes de upsert presentes em todos os ORMs maduros. Evitam a necessidade de verificar existencia manualmente.

**Uso esperado:**
```pascal
// Busca por campo. Se nao encontrar, cria com os dados fornecidos.
Usuario := DAO.FindOrCreate('EMAIL', 'joao@email.com', UsuarioNovo);

// Busca por campo. Se encontrar, atualiza. Se nao, cria.
Usuario := DAO.UpdateOrCreate('EMAIL', 'joao@email.com', UsuarioNovo);
```

**Files:**
- Modify: `src/SimpleInterface.pas` — adicionar metodos
- Modify: `src/SimpleDAO.pas` — implementar logica
- Test: `tests/TestSimpleDAO.pas`

### Step 1: Adicionar na interface

**File:** `src/SimpleInterface.pas`

```pascal
function FindOrCreate(const aField: String; aValue: Variant; aEntity: T): T;
function UpdateOrCreate(const aField: String; aValue: Variant; aEntity: T): T;
```

### Step 2: Implementar no DAO

**File:** `src/SimpleDAO.pas`

```pascal
function TSimpleDAO<T>.FindOrCreate(const aField: String; aValue: Variant; aEntity: T): T;
var
  aSQL: String;
begin
  // Tentar encontrar
  TSimpleSQL<T>.New(nil)
    .DatabaseType(FQuery.SQLType)
    .Where(aField + ' = :pValue')
    .Select(aSQL);

  FQuery.SQL.Clear;
  FQuery.SQL.Add(aSQL);
  FQuery.Params.ParamByName('pValue').Value := aValue;
  FQuery.Open;

  if FQuery.DataSet.IsEmpty then
  begin
    // Nao encontrou: criar
    Insert(aEntity);
    Result := aEntity;
  end
  else
  begin
    // Encontrou: mapear e retornar
    Result := T.Create;
    TSimpleRTTI<T>.New(nil).DataSetToEntity(FQuery.DataSet, Result);
  end;
end;

function TSimpleDAO<T>.UpdateOrCreate(const aField: String; aValue: Variant; aEntity: T): T;
var
  aSQL: String;
begin
  TSimpleSQL<T>.New(nil)
    .DatabaseType(FQuery.SQLType)
    .Where(aField + ' = :pValue')
    .Select(aSQL);

  FQuery.SQL.Clear;
  FQuery.SQL.Add(aSQL);
  FQuery.Params.ParamByName('pValue').Value := aValue;
  FQuery.Open;

  if FQuery.DataSet.IsEmpty then
    Insert(aEntity)
  else
    Update(aEntity);

  Result := aEntity;
end;
```

### Step 3: Testes e Commit

```bash
git commit -m "feat: add FindOrCreate and UpdateOrCreate upsert methods"
```

---

## Task 6: Select Specific Columns (Projection)

Permite carregar apenas as colunas necessarias em vez de SELECT *. Importante para performance.

**Uso esperado:**
```pascal
// Carregar apenas nome e email (campos leves)
DAO.SQL.Fields('NOME, EMAIL').&End.Find(Lista);

// Isso ja existe parcialmente via FSQL.Fields(), mas o DataSetToEntity
// precisa ser resiliente a campos ausentes (hoje pode dar erro)
```

**Files:**
- Modify: `src/SimpleRTTI.pas:~430-470` — tornar DataSetToEntity resiliente a campos ausentes

### Step 1: Fix DataSetToEntity para campos ausentes

**File:** `src/SimpleRTTI.pas` — metodo `DataSetToEntity`

No loop de propriedades, onde acessa `Field := aDataSet.FindField(...)`, o resultado ja pode ser nil. Verificar que o codigo atual faz `if Field = nil then Continue` corretamente. Se nao, adicionar.

Fazer a mesma verificacao em `DataSetToEntityList`.

**Isso ja pode funcionar** — verificar no codigo se FindField retorna nil e se tem o Continue. Se sim, esta feature ja esta suportada via `.Fields('col1, col2')` existente.

### Step 2: Testes

```pascal
procedure TestProjection.TestFields_WithSpecificColumns_ShouldNotError;
// Simular DataSet com apenas 2 colunas
// Mapear para entidade com 5 propriedades
// Verificar que as 3 propriedades ausentes ficam com valor default
end;
```

### Step 3: Commit

```bash
git commit -m "feat: ensure DataSetToEntity handles partial column projection safely"
```

---

## Task 7: Raw SQL com Entity Mapping

Permite executar SQL customizado e mapear o resultado para entidades. Escape hatch essencial para queries complexas.

**Uso esperado:**
```pascal
// Executar SQL raw e mapear para lista de entidades
Lista := DAO.RawSQL(
  'SELECT u.*, COUNT(p.ID) as TOTAL_PEDIDOS ' +
  'FROM USUARIOS u ' +
  'LEFT JOIN PEDIDOS p ON p.ID_USUARIO = u.ID ' +
  'GROUP BY u.ID ' +
  'HAVING COUNT(p.ID) > :minPedidos',
  ['minPedidos'], [5]
).FindRaw;

// Executar SQL raw sem mapeamento (DDL, procedures, etc)
DAO.ExecRawSQL('CREATE INDEX idx_nome ON USUARIOS(NOME)');
```

**Files:**
- Modify: `src/SimpleInterface.pas`
- Modify: `src/SimpleDAO.pas`

### Step 1: Adicionar na interface

**File:** `src/SimpleInterface.pas`

```pascal
function RawSQL(const aSQL: String): iSimpleDAO<T>; overload;
function RawSQL(const aSQL: String; const aParamNames: array of String; const aParamValues: array of Variant): iSimpleDAO<T>; overload;
function FindRaw: TObjectList<T>;
function ExecRawSQL(const aSQL: String): iSimpleDAO<T>;
```

### Step 2: Implementar no DAO

**File:** `src/SimpleDAO.pas`

```pascal
FRawSQL: String;
FRawParams: TDictionary<String, Variant>;

function TSimpleDAO<T>.RawSQL(const aSQL: String): iSimpleDAO<T>;
begin
  Result := Self;
  FRawSQL := aSQL;
  FRawParams.Clear;
end;

function TSimpleDAO<T>.RawSQL(const aSQL: String; const aParamNames: array of String; const aParamValues: array of Variant): iSimpleDAO<T>;
var
  I: Integer;
begin
  Result := Self;
  FRawSQL := aSQL;
  FRawParams.Clear;
  for I := 0 to High(aParamNames) do
    FRawParams.Add(aParamNames[I], aParamValues[I]);
end;

function TSimpleDAO<T>.FindRaw: TObjectList<T>;
var
  Key: String;
begin
  Result := TObjectList<T>.Create;
  FQuery.SQL.Clear;
  FQuery.SQL.Add(FRawSQL);

  for Key in FRawParams.Keys do
    FQuery.Params.ParamByName(Key).Value := FRawParams[Key];

  FQuery.Open;
  TSimpleRTTI<T>.New(nil).DataSetToEntityList(FQuery.DataSet, Result);
  FRawSQL := '';
  FRawParams.Clear;
end;

function TSimpleDAO<T>.ExecRawSQL(const aSQL: String): iSimpleDAO<T>;
begin
  Result := Self;
  FQuery.SQL.Clear;
  FQuery.SQL.Add(aSQL);
  FQuery.ExecSQL;
end;
```

### Step 3: Commit

```bash
git commit -m "feat: add RawSQL and ExecRawSQL for custom query execution with entity mapping"
```

---

## Task 8: Cascade Delete — `[CascadeDelete]`

Deleta registros filhos automaticamente ao deletar o pai. Presente em Hibernate, EF, ActiveRecord.

**Uso esperado:**
```pascal
TPedido = class
published
  [HasMany('TItemPedido', 'ID_PEDIDO')]
  [CascadeDelete]
  property Itens: TObjectList<TItemPedido> read FItens write FItens;
end;

// Ao deletar Pedido, todos os ItemPedido com ID_PEDIDO = Pedido.ID
// sao deletados automaticamente ANTES do pedido
DAO.Delete(Pedido);  // Deleta itens primeiro, depois o pedido
```

**Files:**
- Modify: `src/SimpleAttributes.pas` — adicionar CascadeDelete
- Modify: `src/SimpleRTTIHelper.pas` — adicionar IsCascadeDelete
- Modify: `src/SimpleDAO.pas` — implementar cascade no Delete

### Step 1: Criar atributo

**File:** `src/SimpleAttributes.pas`

```pascal
CascadeDelete = class(TCustomAttribute)
end;
```

### Step 2: Criar helper

**File:** `src/SimpleRTTIHelper.pas`

```pascal
function IsCascadeDelete: Boolean;
// Implementacao: Result := Tem<CascadeDelete>
```

### Step 3: Implementar cascade no Delete

**File:** `src/SimpleDAO.pas` — metodo `Delete(aValue: T)`

Antes de executar o DELETE do registro pai:

```pascal
// Cascade Delete: deletar filhos primeiro
LCtx := TRttiContext.Create;
try
  LType := LCtx.GetType(TObject(aValue).ClassType);
  for LProp in LType.GetProperties do
  begin
    if not LProp.IsCascadeDelete then
      Continue;

    LRelation := LProp.GetRelationship;
    if LRelation = nil then
      Continue;

    // Gerar DELETE dos filhos usando FK
    LPKProp := LType.GetPKField;
    LPKValue := LPKProp.GetValue(Pointer(aValue));

    FQuery.SQL.Clear;
    FQuery.SQL.Add('delete from ' + LRelation.EntityName +
      ' where ' + LRelation.ForeignKey + ' = :pCascadeFK');
    FQuery.Params.ParamByName('pCascadeFK').Value := LPKValue.AsVariant;
    FQuery.ExecSQL;
  end;
finally
  LCtx.Free;
end;

// ... DELETE do registro pai (codigo existente) ...
```

### Step 4: Commit

```bash
git commit -m "feat: add [CascadeDelete] for automatic child record deletion"
```

---

## Task 9: Auto-Migration — Gerar DDL a partir de Entidades

Gerar CREATE TABLE a partir dos atributos da entidade. Para desenvolvimento e prototipagem rapida. Presente em todos os ORMs maduros (EF migrations, Django makemigrations, ActiveRecord migrations).

**Uso esperado:**
```pascal
// Gerar SQL de criacao da tabela (nao executa, apenas gera)
DDL := TSimpleMigration.GenerateCreateTable<TUsuario>(TSQLType.PostgreSQL);
// Resultado:
// CREATE TABLE IF NOT EXISTS USUARIOS (
//   ID SERIAL PRIMARY KEY,
//   NOME VARCHAR(100) NOT NULL,
//   EMAIL VARCHAR(200),
//   ATIVO INTEGER DEFAULT 0,
//   DT_CRIACAO TIMESTAMP,
//   DT_ATUALIZACAO TIMESTAMP
// );

// Executar diretamente (para dev/testes)
TSimpleMigration.CreateTable<TUsuario>(Query);
```

**Files:**
- Create: `src/SimpleMigration.pas` — nova unit de migracao
- Modify: `src/SimpleInterface.pas` — interface iSimpleMigration
- Test: `tests/TestSimpleMigration.pas`

### Step 1: Definir interface

**File:** `src/SimpleInterface.pas`

```pascal
iSimpleMigration = interface
  ['{GUID}']
  function GenerateCreateTable<T: class, constructor>(aSQLType: TSQLType): String;
  function CreateTable<T: class, constructor>(aQuery: iSimpleQuery): iSimpleMigration;
  function DropTable<T: class, constructor>(aQuery: iSimpleQuery): iSimpleMigration;
end;
```

### Step 2: Implementar SimpleMigration.pas

**File:** `src/SimpleMigration.pas`

```pascal
unit SimpleMigration;

interface

uses
  SimpleInterface, SimpleTypes;

type
  TSimpleMigration = class(TInterfacedObject, iSimpleMigration)
  private
    function MapFieldType(aTypeKind: TTypeKind; aFormat: SimpleAttributes.Format;
      aSQLType: TSQLType; aIsAutoInc, aIsPK: Boolean): String;
  public
    class function New: iSimpleMigration;
    constructor Create;
    function GenerateCreateTable<T: class, constructor>(aSQLType: TSQLType): String;
    function CreateTable<T: class, constructor>(aQuery: iSimpleQuery): iSimpleMigration;
    function DropTable<T: class, constructor>(aQuery: iSimpleQuery): iSimpleMigration;
  end;

implementation

uses
  System.Rtti, System.SysUtils, SimpleAttributes, SimpleRTTIHelper;

function TSimpleMigration.GenerateCreateTable<T>(aSQLType: TSQLType): String;
var
  LCtx: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LTableName, LFields, LFieldDef: String;
begin
  LCtx := TRttiContext.Create;
  try
    LType := LCtx.GetType(TypeInfo(T));
    LTableName := LType.GetAttribute<Tabela>.Name;
    LFields := '';

    for LProp in LType.GetProperties do
    begin
      if LProp.IsIgnore then
        Continue;

      LFieldDef := LProp.FieldName + ' ' +
        MapFieldType(LProp.PropertyType.TypeKind,
          LProp.GetAttribute<SimpleAttributes.Format>,
          aSQLType,
          LProp.IsAutoInc,
          LProp.EhChavePrimaria);

      if LProp.EhChavePrimaria then
        LFieldDef := LFieldDef + ' PRIMARY KEY';

      if LProp.IsNotNull and not LProp.IsAutoInc then
        LFieldDef := LFieldDef + ' NOT NULL';

      if LFields <> '' then
        LFields := LFields + ',' + sLineBreak + '  ';
      LFields := LFields + LFieldDef;
    end;

    Result := 'CREATE TABLE IF NOT EXISTS ' + LTableName + ' (' + sLineBreak +
      '  ' + LFields + sLineBreak + ')';
  finally
    LCtx.Free;
  end;
end;

function TSimpleMigration.MapFieldType(aTypeKind: TTypeKind;
  aFormat: SimpleAttributes.Format; aSQLType: TSQLType;
  aIsAutoInc, aIsPK: Boolean): String;
begin
  // AutoInc com tipo especifico por banco
  if aIsAutoInc then
  begin
    case aSQLType of
      TSQLType.Firebird: Exit('INTEGER GENERATED BY DEFAULT AS IDENTITY');
      TSQLType.MySQL:    Exit('INTEGER AUTO_INCREMENT');
      TSQLType.SQLite:   Exit('INTEGER AUTOINCREMENT');
      TSQLType.Oracle:   Exit('NUMBER GENERATED BY DEFAULT AS IDENTITY');
    else
      Exit('SERIAL'); // PostgreSQL
    end;
  end;

  case aTypeKind of
    tkInteger: Result := 'INTEGER';
    tkInt64: Result := 'BIGINT';
    tkFloat:
    begin
      if Assigned(aFormat) and (aFormat.Precision > 0) then
        Result := SysUtils.Format('NUMERIC(%d,%d)', [aFormat.MaxSize, aFormat.Precision])
      else
        Result := 'DOUBLE PRECISION';
    end;
    tkString, tkWChar, tkLString, tkWString, tkUString:
    begin
      if Assigned(aFormat) and (aFormat.MaxSize > 0) then
        Result := SysUtils.Format('VARCHAR(%d)', [aFormat.MaxSize])
      else
        Result := 'VARCHAR(255)';
    end;
    tkEnumeration: Result := 'INTEGER';
  else
    Result := 'VARCHAR(255)';
  end;
end;

function TSimpleMigration.CreateTable<T>(aQuery: iSimpleQuery): iSimpleMigration;
begin
  Result := Self;
  aQuery.SQL.Clear;
  aQuery.SQL.Add(GenerateCreateTable<T>(aQuery.SQLType));
  aQuery.ExecSQL;
end;

function TSimpleMigration.DropTable<T>(aQuery: iSimpleQuery): iSimpleMigration;
var
  LCtx: TRttiContext;
  LType: TRttiType;
begin
  Result := Self;
  LCtx := TRttiContext.Create;
  try
    LType := LCtx.GetType(TypeInfo(T));
    aQuery.SQL.Clear;
    aQuery.SQL.Add('DROP TABLE IF EXISTS ' + LType.GetAttribute<Tabela>.Name);
    aQuery.ExecSQL;
  finally
    LCtx.Free;
  end;
end;
```

### Step 3: Testes

```pascal
procedure TestMigration.TestGenerateCreateTable_Firebird;
var DDL: String;
begin
  DDL := TSimpleMigration.New.GenerateCreateTable<TTestEntity>(TSQLType.Firebird);
  CheckTrue(Pos('CREATE TABLE IF NOT EXISTS', DDL) > 0);
  CheckTrue(Pos('PRIMARY KEY', DDL) > 0);
  CheckTrue(Pos('NOT NULL', DDL) > 0);
end;

procedure TestMigration.TestGenerateCreateTable_MySQL_AutoInc;
var DDL: String;
begin
  DDL := TSimpleMigration.New.GenerateCreateTable<TTestEntity>(TSQLType.MySQL);
  CheckTrue(Pos('AUTO_INCREMENT', DDL) > 0);
end;
```

### Step 4: Commit

```bash
git add src/SimpleMigration.pas src/SimpleInterface.pas tests/TestSimpleMigration.pas
git commit -m "feat: add SimpleMigration for DDL generation from entity attributes"
```

---

## Task 10: Simple Cache (Identity Map)

Cache de primeiro nivel que evita queries repetidas para o mesmo registro. Presente em Hibernate (L1 cache) e Entity Framework (change tracking).

**Uso esperado:**
```pascal
// Habilitar cache no DAO
DAO.EnableCache;

// Primeira chamada: vai ao banco
Usuario1 := DAO.Find(1);

// Segunda chamada com mesmo ID: retorna do cache (zero queries)
Usuario2 := DAO.Find(1);

// Limpar cache manualmente
DAO.ClearCache;

// Desabilitar cache
DAO.DisableCache;
```

**Files:**
- Modify: `src/SimpleInterface.pas`
- Modify: `src/SimpleDAO.pas`

### Step 1: Adicionar na interface

**File:** `src/SimpleInterface.pas`

```pascal
function EnableCache: iSimpleDAO<T>;
function DisableCache: iSimpleDAO<T>;
function ClearCache: iSimpleDAO<T>;
```

### Step 2: Implementar no DAO

**File:** `src/SimpleDAO.pas`

```pascal
private
  FCacheEnabled: Boolean;
  FCache: TDictionary<String, T>;

function TSimpleDAO<T>.EnableCache: iSimpleDAO<T>;
begin
  Result := Self;
  FCacheEnabled := True;
  if not Assigned(FCache) then
    FCache := TDictionary<String, T>.Create;
end;

function TSimpleDAO<T>.DisableCache: iSimpleDAO<T>;
begin
  Result := Self;
  FCacheEnabled := False;
end;

function TSimpleDAO<T>.ClearCache: iSimpleDAO<T>;
begin
  Result := Self;
  if Assigned(FCache) then
    FCache.Clear;
end;

// Modificar Find(aId: Integer) para usar cache:
function TSimpleDAO<T>.Find(aId: Integer): T;
var
  aSQL: String;
  LCacheKey: String;
begin
  LCacheKey := IntToStr(aId);

  // Check cache first
  if FCacheEnabled and Assigned(FCache) and FCache.ContainsKey(LCacheKey) then
    Exit(FCache[LCacheKey]);

  Result := T.Create;
  TSimpleSQL<T>.New(nil).SelectId(aSQL);
  FQuery.SQL.Clear;
  FQuery.SQL.Add(aSQL);
  Self.FillParameter(Result, aId);
  FQuery.Open;
  TSimpleRTTI<T>.New(nil).DataSetToEntity(FQuery.DataSet, Result);
  LoadRelationships(Result);

  // Store in cache
  if FCacheEnabled and Assigned(FCache) then
    FCache.AddOrSetValue(LCacheKey, Result);
end;
```

**Importante:** O cache deve ser invalidado no Insert/Update/Delete:

```pascal
// Em Insert, Update, Delete:
if FCacheEnabled and Assigned(FCache) then
  FCache.Clear; // Limpa cache inteiro para seguranca
```

### Step 3: Commit

```bash
git commit -m "feat: add simple first-level identity cache for Find operations"
```

---

## Resumo da Execucao

| Task | Feature | Complexidade | Arquivos |
|------|---------|-------------|----------|
| 1 | Timestamps (CreatedAt/UpdatedAt) | Baixa | 3 files |
| 2 | Callbacks (Before/After CRUD) | Media | 2 files |
| 3 | Aggregations (Count/Sum/Min/Max/Avg) | Media | 3 files |
| 4 | Scopes (Named Queries) | Media | 2 files |
| 5 | FindOrCreate / UpdateOrCreate | Baixa | 2 files |
| 6 | Select Specific Columns | Baixa | 1 file (verificacao) |
| 7 | Raw SQL com Entity Mapping | Media | 2 files |
| 8 | Cascade Delete | Media | 3 files |
| 9 | Auto-Migration (DDL Generation) | Alta | 3 files (1 nova unit) |
| 10 | Simple Cache | Media | 2 files |

**Ordem recomendada:** 1 → 2 → 3 → 5 → 4 → 6 → 7 → 8 → 9 → 10

Timestamps e Callbacks primeiro porque sao os mais pedidos e impactam menos o codigo existente. Migration e Cache por ultimo porque sao os mais complexos.
