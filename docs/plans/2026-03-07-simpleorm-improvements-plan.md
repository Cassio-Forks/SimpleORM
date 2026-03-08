# SimpleORM Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix critical security/stability bugs, add transaction support to all drivers, implement pagination, relationships, expanded validation, soft delete, batch operations, query logging, and unify JSON.

**Architecture:** Incremental changes to the existing fluent-interface ORM. Each task modifies specific units, keeping backward compatibility. New features are added as new attributes + logic in existing classes. Driver implementations follow the iSimpleQuery interface contract.

**Tech Stack:** Delphi (Object Pascal), RTTI, FireDAC, RestDataware, UniDAC, Zeos

---

### Task 1: Fix SQL Injection in Delete(aField, aValue)

**Files:**
- Modify: `SimpleDAO.pas:130-149`

**Step 1: Read the current Delete(aField, aValue) method**

Read `SimpleDAO.pas` lines 130-149 to confirm current implementation.

**Step 2: Fix the method to use parameterized query**

Replace the string concatenation with parameterized query:

```pascal
function TSimpleDAO<T>.Delete(aField, aValue: String): iSimpleDAO<T>;
var
    aTableName: string;
    Entity: T;
begin
    Result := Self;
    Entity := T.Create;
    try
        TSimpleRTTI<T>.New(Entity).TableName(aTableName);
        FQuery.SQL.Clear;
        FQuery.SQL.Add('DELETE FROM ' + aTableName + ' WHERE ' + aField + ' = :pValue');
        FQuery.Params.ParamByName('pValue').Value := aValue;
        FQuery.ExecSQL;
    finally
        FreeAndNil(Entity);
    end;
end;
```

**Step 3: Commit**

```bash
git add SimpleDAO.pas
git commit -m "fix: SQL injection vulnerability in Delete(aField, aValue) - use parameterized query"
```

---

### Task 2: Fix swallowed exceptions in SimpleQueryFiredac

**Files:**
- Modify: `SimpleQueryFiredac.pas:67-89`

**Step 1: Read current ExecSQL and EndTransaction**

Read `SimpleQueryFiredac.pas` lines 67-89.

**Step 2: Fix EndTransaction to return Result**

```pascal
function TSimpleQueryFiredac.EndTransaction: iSimpleQuery;
begin
  Result := Self;
  if FTransaction.Active then
    FTransaction.Commit;
end;
```

**Step 3: Fix ExecSQL to re-raise exception after rollback**

```pascal
function TSimpleQueryFiredac.ExecSQL: iSimpleQuery;
begin
  Result := Self;
  if Assigned(FParams) then
    FQuery.Params.Assign(FParams);

  FQuery.Prepare;

  try
    FQuery.ExecSQL;
  except
    on E: Exception do
    begin
      if FTransaction.Active then
        FTransaction.Rollback;
      raise;
    end;
  end;

  if Assigned(FParams) then
    FreeAndNil(FParams);
end;
```

**Step 4: Commit**

```bash
git add SimpleQueryFiredac.pas
git commit -m "fix: re-raise exceptions after rollback and fix EndTransaction return"
```

---

### Task 3: Fix error handling in RestDW, UniDAC, Zeos drivers

**Files:**
- Modify: `SimpleQueryRestDW.pas`
- Modify: `SimpleQueryUnidac.pas`
- Modify: `SimpleQueryZeos.pas`

**Step 1: Read all three driver files**

Read `SimpleQueryRestDW.pas`, `SimpleQueryUnidac.pas`, `SimpleQueryZeos.pas`.

**Step 2: Add try/except with meaningful error handling in ExecSQL for each driver**

For each driver, wrap `ExecSQL` in try/except that re-raises. For RestDW, also check the `aErro` variable.

UniDAC example pattern:
```pascal
function TSimpleQueryUnidac.ExecSQL: iSimpleQuery;
begin
  Result := Self;
  if Assigned(FParams) then
    FQuery.Params.Assign(FParams);

  FQuery.Prepare;

  try
    FQuery.ExecSQL;
  except
    on E: Exception do
      raise;
  end;

  if Assigned(FParams) then
    FreeAndNil(FParams);
end;
```

RestDW: check `aErro` after ExecSQL and raise if not empty.

Zeos: same pattern as UniDAC. Also remove unused variable `a: string`.

**Step 3: Commit**

```bash
git add SimpleQueryRestDW.pas SimpleQueryUnidac.pas SimpleQueryZeos.pas
git commit -m "fix: add proper error handling in RestDW, UniDAC, and Zeos drivers"
```

---

### Task 4: Add NotZero attribute and fix NotNull for Integer

**Files:**
- Modify: `SimpleAttributes.pas`
- Modify: `SimpleValidator.pas`
- Modify: `SimpleRTTIHelper.pas`

**Step 1: Add NotZero attribute in SimpleAttributes.pas**

After `NotNull` class declaration (~line 34):

```pascal
NotZero = class(TCustomAttribute)
end;
```

**Step 2: Add IsNotZero helper in SimpleRTTIHelper.pas**

Add to `TRttiPropertyHelper`:

```pascal
function IsNotZero: Boolean;
```

Implementation:
```pascal
function TRttiPropertyHelper.IsNotZero: Boolean;
begin
  Result := Tem<NotZero>
end;
```

**Step 3: Fix NotNull validation and add NotZero validation in SimpleValidator.pas**

Change `ValidateNotNull` for `tkInteger` case - remove the zero check:

```pascal
tkInteger:
  ; // NotNull for integer: no validation needed (integers always have a value)
```

Add new `ValidateNotZero` method:

```pascal
class procedure TSimpleValidator.ValidateNotZero(const aErrros: TStrings; const
  aObject: TObject; const aProperty: TRttiProperty);
var
  Value: TValue;
begin
  Value := aProperty.GetValue(aObject);
  case Value.Kind of
    tkInteger:
      if Value.AsInteger = 0 then
        aErrros.Add(Format(sMSG_NUMBER_NOT_NULL, [aProperty.DisplayName]));
    tkFloat:
      if Value.AsExtended = 0 then
        aErrros.Add(Format(sMSG_NUMBER_NOT_NULL, [aProperty.DisplayName]));
  end;
end;
```

In `Validate`, add after the NotNull check:

```pascal
if prpRtti.IsNotZero then
  ValidateNotZero(aErrors, aObject, prpRtti);
```

**Step 4: Commit**

```bash
git add SimpleAttributes.pas SimpleValidator.pas SimpleRTTIHelper.pas
git commit -m "feat: add NotZero attribute and fix NotNull for Integer (0 is now valid)"
```

---

### Task 5: Expand iSimpleQuery with transaction methods

**Files:**
- Modify: `SimpleInterface.pas:98-107`

**Step 1: Read SimpleInterface.pas**

Read lines 98-107 for `iSimpleQuery`.

**Step 2: Add transaction and SQLType methods**

```pascal
iSimpleQuery = interface
  ['{6DCCA942-736D-4C66-AC9B-94151F14853A}']
  function SQL : TStrings;
  function Params : TParams;
  function ExecSQL : iSimpleQuery;
  function DataSet : TDataSet;
  function Open(aSQL : String) : iSimpleQuery; overload;
  function Open : iSimpleQuery; overload;
  function StartTransaction: iSimpleQuery;
  function Commit: iSimpleQuery;
  function Rollback: iSimpleQuery;
  function &EndTransaction: iSimpleQuery;
  function InTransaction: Boolean;
  function SQLType: TSQLType;
end;
```

**Step 3: Add `uses SimpleTypes` to the interface section of SimpleInterface.pas**

Add `SimpleTypes` to the uses clause.

**Step 4: Commit**

```bash
git add SimpleInterface.pas
git commit -m "feat: expand iSimpleQuery interface with transaction control and SQLType"
```

---

### Task 6: Implement transaction methods in SimpleQueryFiredac

**Files:**
- Modify: `SimpleQueryFiredac.pas`

**Step 1: Read SimpleQueryFiredac.pas**

Read full file.

**Step 2: Add FSQLType field and constructor parameter**

Add to private section:
```pascal
FSQLType: TSQLType;
```

Update constructor signature:
```pascal
constructor Create(aConnection: TFDConnection; aSQLType: TSQLType = TSQLType.Firebird);
class function New(aConnection: TFDConnection; aSQLType: TSQLType = TSQLType.Firebird): iSimpleQuery;
```

Remove auto-start transaction from constructor. Add `FAutoTransaction` flag:
```pascal
FAutoTransaction: Boolean;
```

**Step 3: Implement StartTransaction, Commit, Rollback, InTransaction, SQLType**

```pascal
function TSimpleQueryFiredac.StartTransaction: iSimpleQuery;
begin
  Result := Self;
  if not FTransaction.Active then
    FTransaction.StartTransaction;
end;

function TSimpleQueryFiredac.Commit: iSimpleQuery;
begin
  Result := Self;
  if FTransaction.Active then
    FTransaction.Commit;
end;

function TSimpleQueryFiredac.Rollback: iSimpleQuery;
begin
  Result := Self;
  if FTransaction.Active then
    FTransaction.Rollback;
end;

function TSimpleQueryFiredac.InTransaction: Boolean;
begin
  Result := FTransaction.Active;
end;

function TSimpleQueryFiredac.SQLType: TSQLType;
begin
  Result := FSQLType;
end;
```

**Step 4: Update EndTransaction to call Commit**

```pascal
function TSimpleQueryFiredac.EndTransaction: iSimpleQuery;
begin
  Result := Commit;
end;
```

**Step 5: Commit**

```bash
git add SimpleQueryFiredac.pas
git commit -m "feat: implement full transaction control in FireDAC driver"
```

---

### Task 7: Implement transaction methods in UniDAC, Zeos, RestDW

**Files:**
- Modify: `SimpleQueryUnidac.pas`
- Modify: `SimpleQueryZeos.pas`
- Modify: `SimpleQueryRestDW.pas`

**Step 1: Read all three files**

**Step 2: Add transaction support to each driver**

Each driver needs:
- A transaction component (native to each library)
- `FSQLType` field with constructor parameter
- Implementation of `StartTransaction`, `Commit`, `Rollback`, `InTransaction`, `SQLType`
- `EndTransaction` as alias for `Commit`

UniDAC: use `TUniTransaction`
Zeos: use `TZConnection.StartTransaction/Commit/Rollback` (connection-level)
RestDW: use `TRESTDWClientSQL` transaction methods if available, or document limitation

**Step 3: Commit**

```bash
git add SimpleQueryUnidac.pas SimpleQueryZeos.pas SimpleQueryRestDW.pas
git commit -m "feat: implement transaction control in UniDAC, Zeos, and RestDW drivers"
```

---

### Task 8: Add pagination to iSimpleDAOSQLAttribute and TSimpleDAOSQLAttribute

**Files:**
- Modify: `SimpleInterface.pas:45-59`
- Modify: `SimpleDAOSQLAttribute.pas`

**Step 1: Read SimpleDAOSQLAttribute.pas**

Read full file.

**Step 2: Add Skip/Take to interface**

In `iSimpleDAOSQLAttribute<T>` add:
```pascal
function Skip(aValue: Integer): iSimpleDAOSQLAttribute<T>;
function Take(aValue: Integer): iSimpleDAOSQLAttribute<T>;
function GetSkip: Integer;
function GetTake: Integer;
```

**Step 3: Implement in TSimpleDAOSQLAttribute**

Add fields `FSkip`, `FTake: Integer` and implement getters/setters. Reset in `Clear`.

**Step 4: Commit**

```bash
git add SimpleInterface.pas SimpleDAOSQLAttribute.pas
git commit -m "feat: add Skip/Take pagination to SQL attribute interface"
```

---

### Task 9: Implement pagination SQL generation

**Files:**
- Modify: `SimpleSQL.pas:131-152`
- Modify: `SimpleDAO.pas:157-171`

**Step 1: Read SimpleSQL.pas Select method**

Read lines 131-152.

**Step 2: Add pagination parameters and SQLType to TSimpleSQL**

Add fields `FSkip`, `FTake: Integer`, `FSQLType: TSQLType`.
Add fluent methods:
```pascal
function Skip(aValue: Integer): iSimpleSQL<T>;
function Take(aValue: Integer): iSimpleSQL<T>;
function DatabaseType(aType: TSQLType): iSimpleSQL<T>;
```

Update interface `iSimpleSQL<T>` in `SimpleInterface.pas` accordingly.

**Step 3: Modify Select to generate pagination SQL**

```pascal
function TSimpleSQL<T>.Select(var aSQL: String): iSimpleSQL<T>;
var
  aFields, aClassName: String;
begin
  Result := Self;
  TSimpleRTTI<T>.New(nil)
    .Fields(aFields)
    .TableName(aClassName);

  // Firebird: SELECT FIRST x SKIP y ...
  if (FSQLType = TSQLType.Firebird) and (FTake > 0) then
  begin
    aSQL := aSQL + ' SELECT';
    aSQL := aSQL + ' FIRST ' + IntToStr(FTake);
    if FSkip > 0 then
      aSQL := aSQL + ' SKIP ' + IntToStr(FSkip);
  end
  else
    aSQL := aSQL + ' SELECT';

  if Trim(FFields) <> '' then
    aSQL := aSQL + ' ' + FFields
  else
    aSQL := aSQL + ' ' + aFields;

  aSQL := aSQL + ' FROM ' + aClassName;

  if Trim(FJoin) <> '' then
    aSQL := aSQL + ' ' + FJoin + ' ';
  if Trim(FWhere) <> '' then
    aSQL := aSQL + ' WHERE ' + FWhere;
  if Trim(FGroupBy) <> '' then
    aSQL := aSQL + ' GROUP BY ' + FGroupBy;
  if Trim(FOrderBy) <> '' then
    aSQL := aSQL + ' ORDER BY ' + FOrderBy;

  // MySQL/SQLite: LIMIT x OFFSET y
  if (FSQLType in [TSQLType.MySQL, TSQLType.SQLite]) and (FTake > 0) then
  begin
    aSQL := aSQL + ' LIMIT ' + IntToStr(FTake);
    if FSkip > 0 then
      aSQL := aSQL + ' OFFSET ' + IntToStr(FSkip);
  end;

  // Oracle: OFFSET x ROWS FETCH NEXT y ROWS ONLY
  if (FSQLType = TSQLType.Oracle) and (FTake > 0) then
  begin
    if FSkip > 0 then
      aSQL := aSQL + ' OFFSET ' + IntToStr(FSkip) + ' ROWS';
    aSQL := aSQL + ' FETCH NEXT ' + IntToStr(FTake) + ' ROWS ONLY';
  end;
end;
```

**Step 4: Update TSimpleDAO.Find to pass SQLType and pagination to TSimpleSQL**

In `SimpleDAO.pas`, `Find` method, propagate `FQuery.SQLType` and `FSQLAttribute.GetSkip/GetTake` to `TSimpleSQL`.

**Step 5: Commit**

```bash
git add SimpleSQL.pas SimpleDAO.pas SimpleInterface.pas
git commit -m "feat: implement pagination SQL generation for Firebird, MySQL, SQLite, Oracle"
```

---

### Task 10: Expand relationship attributes

**Files:**
- Modify: `SimpleAttributes.pas:77-95`

**Step 1: Read current relationship attributes**

Read `SimpleAttributes.pas` lines 77-95.

**Step 2: Add ForeignKey to relationship constructors**

```pascal
Relationship = class abstract(TCustomAttribute)
private
  FEntityName: string;
  FForeignKey: string;
public
  constructor Create(const aEntityName: string); overload;
  constructor Create(const aEntityName, aForeignKey: string); overload;
  property EntityName: string read FEntityName write FEntityName;
  property ForeignKey: string read FForeignKey write FForeignKey;
end;
```

Implementation:
```pascal
constructor Relationship.Create(const aEntityName: string);
begin
  FEntityName := aEntityName;
end;

constructor Relationship.Create(const aEntityName, aForeignKey: string);
begin
  FEntityName := aEntityName;
  FForeignKey := aForeignKey;
end;
```

**Step 3: Commit**

```bash
git add SimpleAttributes.pas
git commit -m "feat: add ForeignKey parameter to relationship attributes"
```

---

### Task 11: Implement HasOne/BelongsTo eager loading

**Files:**
- Modify: `SimpleRTTI.pas` (DataSetToEntityList, DataSetToEntity methods)
- Modify: `SimpleDAO.pas` (Find methods)

**Step 1: Read SimpleRTTI.pas DataSetToEntityList**

Read lines 459-516.

**Step 2: Add relationship detection in RTTI**

Add helper methods to `SimpleRTTIHelper.pas`:
```pascal
function IsHasOne: Boolean;
function IsBelongsTo: Boolean;
function IsHasMany: Boolean;
function GetRelationship: Relationship;
```

**Step 3: Implement eager loading in TSimpleDAO.Find**

After the main query populates the entity list, iterate properties with `HasOne`/`BelongsTo` attributes. For each:
1. Get the FK value from the entity
2. Execute a secondary query: `SELECT * FROM related_table WHERE pk = :fk_value`
3. Map result to the related entity object
4. Assign to the property

This requires the `iSimpleQuery` to be available in the RTTI layer, so pass it as parameter or handle in the DAO layer.

**Step 4: Commit**

```bash
git add SimpleRTTI.pas SimpleRTTIHelper.pas SimpleDAO.pas
git commit -m "feat: implement HasOne/BelongsTo eager loading in Find"
```

---

### Task 12: Implement HasMany lazy loading

**Files:**
- Create: `SimpleProxy.pas`
- Modify: `SimpleRTTI.pas`

**Step 1: Create SimpleProxy class**

```pascal
unit SimpleProxy;

interface

uses
  System.Generics.Collections, SimpleInterface;

type
  TSimpleLazyLoader<T: class, constructor> = class(TObjectList<T>)
  private
    FLoaded: Boolean;
    FQuery: iSimpleQuery;
    FForeignKey: string;
    FForeignValue: Variant;
    procedure EnsureLoaded;
  public
    constructor Create(aQuery: iSimpleQuery; const aForeignKey: string; aForeignValue: Variant);
    function GetEnumerator: TObjectList<T>.TEnumerator;
    function Count: Integer;
  end;

implementation
// EnsureLoaded executes the query on first access
```

**Step 2: Wire lazy loader in RTTI for HasMany properties**

When populating entities, for `HasMany` properties create a `TSimpleLazyLoader` instead of executing immediately.

**Step 3: Commit**

```bash
git add SimpleProxy.pas SimpleRTTI.pas SimpleORM.dpk
git commit -m "feat: implement HasMany lazy loading via TSimpleLazyLoader proxy"
```

---

### Task 13: Expand validation - Format, Email, MinValue, MaxValue, Regex

**Files:**
- Modify: `SimpleAttributes.pas`
- Modify: `SimpleValidator.pas`
- Modify: `SimpleRTTIHelper.pas`

**Step 1: Add new validation attributes to SimpleAttributes.pas**

```pascal
Email = class(TCustomAttribute)
end;

MinValue = class(TCustomAttribute)
private
  FValue: Double;
public
  constructor Create(aValue: Double);
  property Value: Double read FValue;
end;

MaxValue = class(TCustomAttribute)
private
  FValue: Double;
public
  constructor Create(aValue: Double);
  property Value: Double read FValue;
end;

Regex = class(TCustomAttribute)
private
  FPattern: string;
  FMessage: string;
public
  constructor Create(const aPattern: string; const aMessage: string = '');
  property Pattern: string read FPattern;
  property Message: string read FMessage;
end;
```

**Step 2: Add helper methods in SimpleRTTIHelper.pas**

```pascal
function IsEmail: Boolean;
function HasMinValue: Boolean;
function HasMaxValue: Boolean;
function HasRegex: Boolean;
function HasFormat: Boolean;
```

**Step 3: Implement validation methods in SimpleValidator.pas**

Add class procedures:
- `ValidateFormat`: check string length against `Format.MaxSize` and `Format.MinSize`
- `ValidateEmail`: basic regex `^[^@]+@[^@]+\.[^@]+$`
- `ValidateMinValue`: compare numeric value against `MinValue.Value`
- `ValidateMaxValue`: compare numeric value against `MaxValue.Value`
- `ValidateRegex`: use `TRegEx.IsMatch` against `Regex.Pattern`

Add new error message constants:
```pascal
sMSG_FORMAT_MAX = 'O campo %s deve ter no maximo %d caracteres!';
sMSG_FORMAT_MIN = 'O campo %s deve ter no minimo %d caracteres!';
sMSG_EMAIL = 'O campo %s deve ser um e-mail valido!';
sMSG_MIN_VALUE = 'O campo %s deve ser maior ou igual a %s!';
sMSG_MAX_VALUE = 'O campo %s deve ser menor ou igual a %s!';
```

Call all validators in the main `Validate` loop:
```pascal
if prpRtti.HasFormat then
  ValidateFormat(aErrors, aObject, prpRtti);
if prpRtti.IsEmail then
  ValidateEmail(aErrors, aObject, prpRtti);
if prpRtti.HasMinValue then
  ValidateMinValue(aErrors, aObject, prpRtti);
if prpRtti.HasMaxValue then
  ValidateMaxValue(aErrors, aObject, prpRtti);
if prpRtti.HasRegex then
  ValidateRegex(aErrors, aObject, prpRtti);
```

**Step 4: Commit**

```bash
git add SimpleAttributes.pas SimpleValidator.pas SimpleRTTIHelper.pas
git commit -m "feat: add Email, MinValue, MaxValue, Regex, Format validation"
```

---

### Task 14: Soft Delete

**Files:**
- Modify: `SimpleAttributes.pas`
- Modify: `SimpleSQL.pas`
- Modify: `SimpleDAO.pas`
- Modify: `SimpleRTTI.pas`
- Modify: `SimpleRTTIHelper.pas`

**Step 1: Add SoftDelete attribute**

In `SimpleAttributes.pas`:
```pascal
SoftDelete = class(TCustomAttribute)
private
  FFieldName: string;
public
  constructor Create(const aFieldName: string);
  property FieldName: string read FFieldName;
end;
```

**Step 2: Add RTTI helpers**

In `SimpleRTTIHelper.pas`, add to `TRttiTypeHelper`:
```pascal
function IsSoftDelete: Boolean;
function GetSoftDeleteField: string;
```

In `SimpleRTTI.pas`, add method:
```pascal
function SoftDeleteField(var aFieldName: string): iSimpleRTTI<T>;
```

**Step 3: Modify TSimpleSQL.Delete for soft delete**

```pascal
function TSimpleSQL<T>.Delete(var aSQL: String): iSimpleSQL<T>;
var
  aClassName, aWhere, aSoftField: String;
begin
  Result := Self;
  TSimpleRTTI<T>.New(FInstance)
    .TableName(aClassName)
    .Where(aWhere)
    .SoftDeleteField(aSoftField);

  if aSoftField <> '' then
    aSQL := 'UPDATE ' + aClassName + ' SET ' + aSoftField + ' = 1 WHERE ' + aWhere
  else
    aSQL := 'DELETE FROM ' + aClassName + ' WHERE ' + aWhere;
end;
```

**Step 4: Modify TSimpleSQL.Select to filter soft-deleted records**

In the `Select` method, after building `FROM`, check if entity has SoftDelete and add:
```pascal
// Auto-add soft delete filter
TSimpleRTTI<T>.New(nil).SoftDeleteField(aSoftField);
if aSoftField <> '' then
begin
  if Trim(FWhere) <> '' then
    FWhere := '(' + FWhere + ') AND ' + aSoftField + ' = 0'
  else
    FWhere := aSoftField + ' = 0';
end;
```

**Step 5: Add ForceDelete method to iSimpleDAO**

In `SimpleInterface.pas`, add to `iSimpleDAO<T>`:
```pascal
function ForceDelete(aValue: T): iSimpleDAO<T>;
```

Implement in `SimpleDAO.pas` - always generates `DELETE FROM` regardless of SoftDelete attribute.

**Step 6: Commit**

```bash
git add SimpleAttributes.pas SimpleSQL.pas SimpleDAO.pas SimpleRTTI.pas SimpleRTTIHelper.pas SimpleInterface.pas
git commit -m "feat: implement soft delete with SoftDelete attribute and ForceDelete"
```

---

### Task 15: Batch Operations

**Files:**
- Modify: `SimpleInterface.pas`
- Modify: `SimpleDAO.pas`

**Step 1: Add batch methods to iSimpleDAO interface**

```pascal
function InsertBatch(aList: TObjectList<T>): iSimpleDAO<T>;
function UpdateBatch(aList: TObjectList<T>): iSimpleDAO<T>;
function DeleteBatch(aList: TObjectList<T>): iSimpleDAO<T>;
```

**Step 2: Implement in TSimpleDAO**

```pascal
function TSimpleDAO<T>.InsertBatch(aList: TObjectList<T>): iSimpleDAO<T>;
var
  Item: T;
begin
  Result := Self;
  FQuery.StartTransaction;
  try
    for Item in aList do
      Insert(Item);
    FQuery.Commit;
  except
    FQuery.Rollback;
    raise;
  end;
end;

function TSimpleDAO<T>.UpdateBatch(aList: TObjectList<T>): iSimpleDAO<T>;
var
  Item: T;
begin
  Result := Self;
  FQuery.StartTransaction;
  try
    for Item in aList do
      Update(Item);
    FQuery.Commit;
  except
    FQuery.Rollback;
    raise;
  end;
end;

function TSimpleDAO<T>.DeleteBatch(aList: TObjectList<T>): iSimpleDAO<T>;
var
  Item: T;
begin
  Result := Self;
  FQuery.StartTransaction;
  try
    for Item in aList do
      Delete(Item);
    FQuery.Commit;
  except
    FQuery.Rollback;
    raise;
  end;
end;
```

**Step 3: Commit**

```bash
git add SimpleInterface.pas SimpleDAO.pas
git commit -m "feat: add InsertBatch, UpdateBatch, DeleteBatch with transaction wrapping"
```

---

### Task 16: Query Logging

**Files:**
- Create: `SimpleLogger.pas`
- Modify: `SimpleInterface.pas`
- Modify: `SimpleDAO.pas`

**Step 1: Create SimpleLogger.pas**

```pascal
unit SimpleLogger;

interface

uses
  Data.DB, System.Classes;

type
  iSimpleQueryLogger = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    procedure Log(const aSQL: string; aParams: TParams; aDurationMs: Integer);
  end;

  TSimpleQueryLoggerConsole = class(TInterfacedObject, iSimpleQueryLogger)
  public
    class function New: iSimpleQueryLogger;
    procedure Log(const aSQL: string; aParams: TParams; aDurationMs: Integer);
  end;

implementation

uses
  System.SysUtils, System.Diagnostics, Winapi.Windows;

class function TSimpleQueryLoggerConsole.New: iSimpleQueryLogger;
begin
  Result := Self.Create;
end;

procedure TSimpleQueryLoggerConsole.Log(const aSQL: string; aParams: TParams; aDurationMs: Integer);
var
  LogMsg: string;
  I: Integer;
begin
  LogMsg := Format('[SimpleORM] SQL: %s | Duration: %dms', [aSQL, aDurationMs]);
  if Assigned(aParams) and (aParams.Count > 0) then
  begin
    LogMsg := LogMsg + ' | Params: ';
    for I := 0 to aParams.Count - 1 do
      LogMsg := LogMsg + aParams[I].Name + '=' + VarToStr(aParams[I].Value) + '; ';
  end;
  OutputDebugString(PChar(LogMsg));
end;

end.
```

**Step 2: Add Logger property to iSimpleDAO**

In `SimpleInterface.pas`, add to `iSimpleDAO<T>`:
```pascal
function Logger(aLogger: iSimpleQueryLogger): iSimpleDAO<T>;
```

**Step 3: Implement logging in TSimpleDAO**

Add `FLogger: iSimpleQueryLogger` field. Wrap ExecSQL and Open calls with timing:

```pascal
function TSimpleDAO<T>.Insert(aValue: T): iSimpleDAO<T>;
var
  aSQL: String;
  SW: TStopwatch;
begin
  Result := Self;
  TSimpleSQL<T>.New(aValue).Insert(aSQL);
  FQuery.SQL.Clear;
  FQuery.SQL.Add(aSQL);
  Self.FillParameter(aValue);

  SW := TStopwatch.StartNew;
  FQuery.ExecSQL;
  SW.Stop;

  if Assigned(FLogger) then
    FLogger.Log(aSQL, FQuery.Params, SW.ElapsedMilliseconds);
end;
```

Apply same pattern to Update, Delete, Find methods.

**Step 4: Add SimpleLogger to SimpleORM.dpk contains clause**

**Step 5: Commit**

```bash
git add SimpleLogger.pas SimpleInterface.pas SimpleDAO.pas SimpleORM.dpk
git commit -m "feat: add query logging with iSimpleQueryLogger interface"
```

---

### Task 17: Deprecate SimpleJSON.pas in favor of SimpleJSONUtil.pas

**Files:**
- Modify: `SimpleJSON.pas`
- Modify: `SimpleJSONUtil.pas`

**Step 1: Read both files to identify unique features in SimpleJSON.pas**

Read `SimpleJSON.pas` and `SimpleJSONUtil.pas` fully.

**Step 2: Migrate any unique functionality from SimpleJSON to SimpleJSONUtil**

If `SimpleJSON.pas` has features not in `SimpleJSONUtil.pas`, copy them over.

**Step 3: Mark SimpleJSON.pas classes as deprecated**

Add `deprecated 'Use SimpleJSONUtil instead'` to class declarations in `SimpleJSON.pas`.

**Step 4: Commit**

```bash
git add SimpleJSON.pas SimpleJSONUtil.pas
git commit -m "refactor: deprecate SimpleJSON.pas in favor of SimpleJSONUtil.pas"
```

---

### Task 18: Update SimpleORM.dpk and final cleanup

**Files:**
- Modify: `SimpleORM.dpk`

**Step 1: Add new units to package**

Add to `contains` clause:
```pascal
SimpleProxy in 'SimpleProxy.pas',
SimpleLogger in 'SimpleLogger.pas',
SimpleTypes in 'SimpleTypes.pas';
```

**Step 2: Verify all files compile together**

Check for circular dependencies and missing uses clauses.

**Step 3: Commit**

```bash
git add SimpleORM.dpk
git commit -m "chore: update package with new units (SimpleProxy, SimpleLogger)"
```

---

### Task 19: Update CLAUDE.md with new architecture

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Read current CLAUDE.md**

**Step 2: Update with new features documentation**

Add sections for:
- Transaction control API
- Pagination (Skip/Take)
- Relationship attributes with ForeignKey
- Expanded validation attributes
- Soft Delete
- Batch Operations
- Query Logging
- SQLType configuration

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with new features and architecture"
```
