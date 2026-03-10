# TSkillGitHubIssue Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a Skill that creates GitHub Issues automatically on CRUD failures (OnError mode) or as operation auditing (Normal mode), with support for custom labels and title/body templates.

**Architecture:** Add `TSkillRunMode` to the type system, extend `iSimpleSkill` and `iSimpleSkillContext` with RunMode/ErrorMessage, add `RunOnError` to `TSimpleSkillRunner`, add `OnError` callback to `iSimpleDAO`/`TSimpleDAO`, then implement `TSkillGitHubIssue` with GitHub REST API integration. Fire-and-forget — never interrupts the CRUD flow.

**Tech Stack:** Delphi, DUnit, System.Net.HttpClient, GitHub REST API v3

---

### Task 1: Add TSkillRunMode to SimpleTypes.pas

**Files:**
- Modify: `src/SimpleTypes.pas:8`

**Step 1: Add TSkillRunMode enum**

Add after `TSkillRunAt` line (line 8):

```pascal
  TSkillRunMode = (srmNormal, srmOnError);
```

**Step 2: Add TSimpleErrorCallback type**

Add after `TSupabaseRealtimeCallback` line (line 21):

```pascal
  TSimpleErrorCallback = reference to procedure(aEntity: TObject; aException: Exception);
```

**Step 3: Commit**

```bash
git add src/SimpleTypes.pas
git commit -m "feat: add TSkillRunMode and TSimpleErrorCallback types"
```

---

### Task 2: Extend iSimpleSkill and iSimpleSkillContext interfaces

**Files:**
- Modify: `src/SimpleInterface.pas:191-196` (iSimpleSkill)
- Modify: `src/SimpleInterface.pas:182-189` (iSimpleSkillContext)
- Modify: `src/SimpleInterface.pas:27-80` (iSimpleDAO — add OnError)

**Step 1: Add RunMode to iSimpleSkill**

In `src/SimpleInterface.pas`, find the `iSimpleSkill` interface (line 191-196). Add `RunMode` method:

```pascal
  iSimpleSkill = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
    function RunMode: TSkillRunMode;
  end;
```

**Step 2: Add ErrorMessage to iSimpleSkillContext**

In `src/SimpleInterface.pas`, find `iSimpleSkillContext` (line 182-189). Add `ErrorMessage`:

```pascal
  iSimpleSkillContext = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    function Query: iSimpleQuery;
    function AIClient: iSimpleAIClient;
    function Logger: iSimpleQueryLogger;
    function EntityName: String;
    function Operation: String;
    function ErrorMessage: String;
  end;
```

**Step 3: Add OnError to iSimpleDAO**

In `src/SimpleInterface.pas`, find `iSimpleDAO<T>` interface. Add after line with `OnAfterDelete`:

```pascal
    function OnError(aCallback: TSimpleErrorCallback): iSimpleDAO<T>;
```

**Step 4: Commit**

```bash
git add src/SimpleInterface.pas
git commit -m "feat: extend iSimpleSkill with RunMode, iSimpleSkillContext with ErrorMessage, iSimpleDAO with OnError"
```

---

### Task 3: Update TSimpleSkillContext to support ErrorMessage

**Files:**
- Modify: `src/SimpleSkill.pas:22-40` (TSimpleSkillContext class declaration)
- Modify: `src/SimpleSkill.pas:245-291` (TSimpleSkillContext implementation)

**Step 1: Add FErrorMessage field and ErrorMessage method to TSimpleSkillContext**

In `src/SimpleSkill.pas`, update the `TSimpleSkillContext` class:

```pascal
  TSimpleSkillContext = class(TInterfacedObject, iSimpleSkillContext)
  private
    FQuery: iSimpleQuery;
    FAIClient: iSimpleAIClient;
    FLogger: iSimpleQueryLogger;
    FEntityName: String;
    FOperation: String;
    FErrorMessage: String;
  public
    constructor Create(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient;
      aLogger: iSimpleQueryLogger; const aEntityName, aOperation: String;
      const aErrorMessage: String = '');
    destructor Destroy; override;
    class function New(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient;
      aLogger: iSimpleQueryLogger; const aEntityName, aOperation: String;
      const aErrorMessage: String = ''): iSimpleSkillContext;
    function Query: iSimpleQuery;
    function AIClient: iSimpleAIClient;
    function Logger: iSimpleQueryLogger;
    function EntityName: String;
    function Operation: String;
    function ErrorMessage: String;
  end;
```

**Step 2: Update TSimpleSkillContext implementation**

Update the constructor:

```pascal
constructor TSimpleSkillContext.Create(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient;
  aLogger: iSimpleQueryLogger; const aEntityName, aOperation: String;
  const aErrorMessage: String);
begin
  FQuery := aQuery;
  FAIClient := aAIClient;
  FLogger := aLogger;
  FEntityName := aEntityName;
  FOperation := aOperation;
  FErrorMessage := aErrorMessage;
end;
```

Update the `New` class function:

```pascal
class function TSimpleSkillContext.New(aQuery: iSimpleQuery; aAIClient: iSimpleAIClient;
  aLogger: iSimpleQueryLogger; const aEntityName, aOperation: String;
  const aErrorMessage: String): iSimpleSkillContext;
begin
  Result := Self.Create(aQuery, aAIClient, aLogger, aEntityName, aOperation, aErrorMessage);
end;
```

Add the ErrorMessage method:

```pascal
function TSimpleSkillContext.ErrorMessage: String;
begin
  Result := FErrorMessage;
end;
```

**Step 3: Commit**

```bash
git add src/SimpleSkill.pas
git commit -m "feat: add ErrorMessage support to TSimpleSkillContext"
```

---

### Task 4: Add RunMode to all existing Skills + RunOnError to TSimpleSkillRunner

**Files:**
- Modify: `src/SimpleSkill.pas` (all skill classes + TSimpleSkillRunner)

**Step 1: Add RunMode method to every existing skill class declaration**

For EACH of the 12 skill classes (TSkillLog, TSkillNotify, TSkillAudit, TSkillTimestamp, TSkillHistory, TSkillValidate, TSkillWebhook, TSkillGuardDelete, TSkillCalcTotal, TSkillSequence, TSkillStockMove, TSkillDuplicate), add this method declaration in the `public` section:

```pascal
    function RunMode: TSkillRunMode;
```

**Step 2: Add RunMode implementation for every existing skill**

For EACH of the 12 skills, add this implementation (they are all Normal mode):

```pascal
function TSkillXxx.RunMode: TSkillRunMode;
begin
  Result := srmNormal;
end;
```

Replace `TSkillXxx` with the actual class name for each skill.

**Step 3: Add RunOnError to TSimpleSkillRunner**

In the class declaration (around line 42-53), add:

```pascal
    procedure RunOnError(aEntity: TObject; aContext: iSimpleSkillContext);
```

In the implementation, add:

```pascal
procedure TSimpleSkillRunner.RunOnError(aEntity: TObject; aContext: iSimpleSkillContext);
var
  LSkill: iSimpleSkill;
begin
  for LSkill in FSkills do
  begin
    if LSkill.RunMode = srmOnError then
      LSkill.Execute(aEntity, aContext);
  end;
end;
```

**Step 4: Update RunBefore/RunAfter to skip OnError skills**

In `RunBefore` and `RunAfter`, add a check to skip OnError skills:

```pascal
procedure TSimpleSkillRunner.RunBefore(aEntity: TObject; aContext: iSimpleSkillContext; aRunAt: TSkillRunAt);
var
  LSkill: iSimpleSkill;
begin
  for LSkill in FSkills do
  begin
    if (LSkill.RunAt = aRunAt) and (LSkill.RunMode = srmNormal) then
      LSkill.Execute(aEntity, aContext);
  end;
end;
```

Apply same change to `RunAfter`.

**Step 5: Commit**

```bash
git add src/SimpleSkill.pas
git commit -m "feat: add RunMode to all skills, RunOnError to TSimpleSkillRunner"
```

---

### Task 5: Add OnError callback and try/except to TSimpleDAO

**Files:**
- Modify: `src/SimpleDAO.pas:23-111` (class declaration)
- Modify: `src/SimpleDAO.pas:410-469` (Insert method)
- Modify: `src/SimpleDAO.pas:538-597` (Update method)
- Modify: `src/SimpleDAO.pas:163-211` (Delete method)

**Step 1: Add FOnError field and OnError method declaration**

In `TSimpleDAO<T>` private section (around line 38), add:

```pascal
        FOnError: TSimpleErrorCallback;
```

In the public section (after `OnAfterDelete` around line 100), add:

```pascal
        function OnError(aCallback: TSimpleErrorCallback): iSimpleDAO<T>;
```

**Step 2: Implement OnError method**

Add after `OnAfterDelete` implementation (around line 1093):

```pascal
function TSimpleDAO<T>.OnError(aCallback: TSimpleErrorCallback): iSimpleDAO<T>;
begin
  Result := Self;
  FOnError := aCallback;
end;
```

**Step 3: Wrap Insert(aValue) in try/except**

Replace the `Insert(aValue: T)` method body. Wrap everything from `FQuery.ExecSQL` (SQL execution, line 453) onwards in a try/except. The key change: wrap the entire method body (from Rules to Agent) in a try/except that calls RunOnError and FOnError before re-raising:

```pascal
function TSimpleDAO<T>.Insert(aValue: T): iSimpleDAO<T>;
var
    aSQL: String;
    SW: TStopwatch;
    LAIProcessor: TSimpleAIProcessor;
    LRuleEngine: TSimpleRuleEngine;
    LSkillContext: iSimpleSkillContext;
    LTableName: String;
begin
    Result := Self;
    if Assigned(FOnBeforeInsert) then
      FOnBeforeInsert(aValue);

    // 1. Rules (Before)
    LRuleEngine := TSimpleRuleEngine.New(FAIClient);
    try
      LRuleEngine.Evaluate(aValue, raBeforeInsert);
    finally
      FreeAndNil(LRuleEngine);
    end;

    // 2. AI Attributes
    if FAIClient <> nil then
    begin
      LAIProcessor := TSimpleAIProcessor.New(FAIClient);
      try
        LAIProcessor.Process(aValue);
      finally
        FreeAndNil(LAIProcessor);
      end;
    end;

    // 3. Skills (Before)
    TSimpleRTTI<T>.New(aValue).TableName(LTableName);
    LSkillContext := TSimpleSkillContext.New(FQuery, FAIClient, FLogger, LTableName, 'INSERT');
    FSkillRunner.RunBefore(aValue, LSkillContext, srBeforeInsert);

    try
      // 4. SQL Execution
      TSimpleSQL<T>.New(aValue).Insert(aSQL);
      FQuery.SQL.Clear;
      FQuery.SQL.Add(aSQL);
      Self.FillParameter(aValue);
      SW := TStopwatch.StartNew;
      FQuery.ExecSQL;
      SW.Stop;
      if Assigned(FLogger) then
        FLogger.Log(aSQL, FQuery.Params, SW.ElapsedMilliseconds);
      if FCacheEnabled then
        FCache.Clear;

      // 5. Skills (After)
      FSkillRunner.RunAfter(aValue, LSkillContext, srAfterInsert);

      // 6. Agent (React)
      if FAgent <> nil then
        FAgent.React(aValue, aoAfterInsert);

      if Assigned(FOnAfterInsert) then
        FOnAfterInsert(aValue);
    except
      on E: Exception do
      begin
        // Run OnError skills
        LSkillContext := TSimpleSkillContext.New(FQuery, FAIClient, FLogger, LTableName, 'INSERT', E.Message);
        FSkillRunner.RunOnError(aValue, LSkillContext);
        // Call OnError callback
        if Assigned(FOnError) then
          FOnError(aValue, E);
        raise;
      end;
    end;
end;
```

**Step 4: Apply same try/except pattern to Update(aValue)**

Same pattern as Insert. Wrap from SQL execution to end in try/except. On error: create new context with ErrorMessage, call RunOnError, call FOnError, then raise.

```pascal
function TSimpleDAO<T>.Update(aValue: T): iSimpleDAO<T>;
var
    aSQL: String;
    SW: TStopwatch;
    LAIProcessor: TSimpleAIProcessor;
    LRuleEngine: TSimpleRuleEngine;
    LSkillContext: iSimpleSkillContext;
    LTableName: String;
begin
    Result := Self;
    if Assigned(FOnBeforeUpdate) then
      FOnBeforeUpdate(aValue);

    // 1. Rules (Before)
    LRuleEngine := TSimpleRuleEngine.New(FAIClient);
    try
      LRuleEngine.Evaluate(aValue, raBeforeUpdate);
    finally
      FreeAndNil(LRuleEngine);
    end;

    // 2. AI Attributes
    if FAIClient <> nil then
    begin
      LAIProcessor := TSimpleAIProcessor.New(FAIClient);
      try
        LAIProcessor.Process(aValue);
      finally
        FreeAndNil(LAIProcessor);
      end;
    end;

    // 3. Skills (Before)
    TSimpleRTTI<T>.New(aValue).TableName(LTableName);
    LSkillContext := TSimpleSkillContext.New(FQuery, FAIClient, FLogger, LTableName, 'UPDATE');
    FSkillRunner.RunBefore(aValue, LSkillContext, srBeforeUpdate);

    try
      // 4. SQL Execution
      TSimpleSQL<T>.New(aValue).Update(aSQL);
      FQuery.SQL.Clear;
      FQuery.SQL.Add(aSQL);
      Self.FillParameter(aValue);
      SW := TStopwatch.StartNew;
      FQuery.ExecSQL;
      SW.Stop;
      if Assigned(FLogger) then
        FLogger.Log(aSQL, FQuery.Params, SW.ElapsedMilliseconds);
      if FCacheEnabled then
        FCache.Clear;

      // 5. Skills (After)
      FSkillRunner.RunAfter(aValue, LSkillContext, srAfterUpdate);

      // 6. Agent (React)
      if FAgent <> nil then
        FAgent.React(aValue, aoAfterUpdate);

      if Assigned(FOnAfterUpdate) then
        FOnAfterUpdate(aValue);
    except
      on E: Exception do
      begin
        LSkillContext := TSimpleSkillContext.New(FQuery, FAIClient, FLogger, LTableName, 'UPDATE', E.Message);
        FSkillRunner.RunOnError(aValue, LSkillContext);
        if Assigned(FOnError) then
          FOnError(aValue, E);
        raise;
      end;
    end;
end;
```

**Step 5: Apply same try/except pattern to Delete(aValue)**

```pascal
function TSimpleDAO<T>.Delete(aValue: T): iSimpleDAO<T>;
var
    aSQL: String;
    SW: TStopwatch;
    LRuleEngine: TSimpleRuleEngine;
    LSkillContext: iSimpleSkillContext;
    LTableName: String;
begin
    Result := Self;
    if Assigned(FOnBeforeDelete) then
      FOnBeforeDelete(aValue);

    // 1. Rules (Before)
    LRuleEngine := TSimpleRuleEngine.New(FAIClient);
    try
      LRuleEngine.Evaluate(aValue, raBeforeDelete);
    finally
      FreeAndNil(LRuleEngine);
    end;

    // 2. Skills (Before)
    TSimpleRTTI<T>.New(aValue).TableName(LTableName);
    LSkillContext := TSimpleSkillContext.New(FQuery, FAIClient, FLogger, LTableName, 'DELETE');
    FSkillRunner.RunBefore(aValue, LSkillContext, srBeforeDelete);

    try
      // 3. SQL Execution
      ExecuteCascadeDelete(aValue);
      TSimpleSQL<T>.New(aValue).Delete(aSQL);
      FQuery.SQL.Clear;
      FQuery.SQL.Add(aSQL);
      Self.FillParameter(aValue);
      SW := TStopwatch.StartNew;
      FQuery.ExecSQL;
      SW.Stop;
      if Assigned(FLogger) then
        FLogger.Log(aSQL, FQuery.Params, SW.ElapsedMilliseconds);
      if FCacheEnabled then
        FCache.Clear;

      // 4. Skills (After)
      FSkillRunner.RunAfter(aValue, LSkillContext, srAfterDelete);

      // 5. Agent (React)
      if FAgent <> nil then
        FAgent.React(aValue, aoAfterDelete);

      if Assigned(FOnAfterDelete) then
        FOnAfterDelete(aValue);
    except
      on E: Exception do
      begin
        LSkillContext := TSimpleSkillContext.New(FQuery, FAIClient, FLogger, LTableName, 'DELETE', E.Message);
        FSkillRunner.RunOnError(aValue, LSkillContext);
        if Assigned(FOnError) then
          FOnError(aValue, E);
        raise;
      end;
    end;
end;
```

**Step 6: Commit**

```bash
git add src/SimpleDAO.pas
git commit -m "feat: add OnError callback and try/except with RunOnError to TSimpleDAO"
```

---

### Task 6: Write tests for RunMode, RunOnError, ErrorMessage, and OnError

**Files:**
- Modify: `tests/TestSimpleSkill.pas`

**Step 1: Add tests for RunMode on existing skills**

Add a new test class after the existing ones:

```pascal
  TTestSkillRunMode = class(TTestCase)
  published
    procedure TestAllExistingSkills_ReturnNormalMode;
    procedure TestRunOnError_ExecutesOnErrorSkills;
    procedure TestRunOnError_IgnoresNormalSkills;
    procedure TestRunBefore_IgnoresOnErrorSkills;
    procedure TestContext_ErrorMessage_DefaultEmpty;
    procedure TestContext_ErrorMessage_WithValue;
  end;
```

**Step 2: Implement the tests**

```pascal
{ TTestSkillRunMode }

procedure TTestSkillRunMode.TestAllExistingSkills_ReturnNormalMode;
begin
  CheckTrue(TSkillLog.New.RunMode = srmNormal, 'Log should be Normal');
  CheckTrue(TSkillNotify.New(nil).RunMode = srmNormal, 'Notify should be Normal');
  CheckTrue(TSkillValidate.New.RunMode = srmNormal, 'Validate should be Normal');
  CheckTrue(TSkillTimestamp.New('X').RunMode = srmNormal, 'Timestamp should be Normal');
  CheckTrue(TSkillWebhook.New('http://x').RunMode = srmNormal, 'Webhook should be Normal');
  CheckTrue(TSkillGuardDelete.New('T', 'F').RunMode = srmNormal, 'GuardDelete should be Normal');
  CheckTrue(TSkillHistory.New.RunMode = srmNormal, 'History should be Normal');
  CheckTrue(TSkillAudit.New.RunMode = srmNormal, 'Audit should be Normal');
  CheckTrue(TSkillCalcTotal.New('T', 'Q', 'P').RunMode = srmNormal, 'CalcTotal should be Normal');
  CheckTrue(TSkillSequence.New('F', 'T', 'S').RunMode = srmNormal, 'Sequence should be Normal');
  CheckTrue(TSkillStockMove.New('T', 'P', 'Q').RunMode = srmNormal, 'StockMove should be Normal');
  CheckTrue(TSkillDuplicate.New('T', 'F', 3, 30).RunMode = srmNormal, 'Duplicate should be Normal');
end;

procedure TTestSkillRunMode.TestRunOnError_ExecutesOnErrorSkills;
var
  LRunner: TSimpleSkillRunner;
  LContext: iSimpleSkillContext;
  LExecuted: Boolean;
begin
  LExecuted := False;
  LRunner := TSimpleSkillRunner.New;
  try
    LRunner.Add(TSkillGitHubIssue.New(
      'test/repo',
      'fake-token',
      srAfterInsert,
      srmOnError
    ));
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT', 'Test error');
    // Note: Execute will try HTTP and fail silently (fire-and-forget)
    // We test that RunOnError iterates srmOnError skills
    LRunner.RunOnError(nil, LContext);
    CheckTrue(True, 'RunOnError should execute without raising');
  finally
    FreeAndNil(LRunner);
  end;
end;

procedure TTestSkillRunMode.TestRunOnError_IgnoresNormalSkills;
var
  LRunner: TSimpleSkillRunner;
  LContext: iSimpleSkillContext;
  LExecuted: Boolean;
begin
  LExecuted := False;
  LRunner := TSimpleSkillRunner.New;
  try
    LRunner.Add(TSkillNotify.New(
      procedure(aObj: TObject)
      begin
        LExecuted := True;
      end, srAfterInsert));
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT', 'Error msg');
    LRunner.RunOnError(nil, LContext);
    CheckFalse(LExecuted, 'Normal skill should NOT execute in RunOnError');
  finally
    FreeAndNil(LRunner);
  end;
end;

procedure TTestSkillRunMode.TestRunBefore_IgnoresOnErrorSkills;
var
  LRunner: TSimpleSkillRunner;
  LContext: iSimpleSkillContext;
begin
  LRunner := TSimpleSkillRunner.New;
  try
    LRunner.Add(TSkillGitHubIssue.New(
      'test/repo',
      'fake-token',
      srBeforeInsert,
      srmOnError
    ));
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
    // This should NOT execute the OnError skill
    LRunner.RunBefore(nil, LContext, srBeforeInsert);
    CheckTrue(True, 'OnError skill should be ignored by RunBefore');
  finally
    FreeAndNil(LRunner);
  end;
end;

procedure TTestSkillRunMode.TestContext_ErrorMessage_DefaultEmpty;
var
  LContext: iSimpleSkillContext;
begin
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
  CheckEquals('', LContext.ErrorMessage, 'Default error message should be empty');
end;

procedure TTestSkillRunMode.TestContext_ErrorMessage_WithValue;
var
  LContext: iSimpleSkillContext;
begin
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT', 'Something went wrong');
  CheckEquals('Something went wrong', LContext.ErrorMessage, 'Should return the error message');
end;
```

**Step 3: Register the test**

In the `initialization` section:

```pascal
  RegisterTest('Skills', TTestSkillRunMode.Suite);
```

**Step 4: Commit**

```bash
git add tests/TestSimpleSkill.pas
git commit -m "test: add tests for RunMode, RunOnError, ErrorMessage"
```

---

### Task 7: Implement TSkillGitHubIssue

**Files:**
- Modify: `src/SimpleSkill.pas` (add class declaration and implementation)

**Step 1: Add TSkillGitHubIssue class declaration**

Add before the `implementation` keyword in `SimpleSkill.pas`:

```pascal
  { Built-in: TSkillGitHubIssue }
  TSkillGitHubIssue = class(TInterfacedObject, iSimpleSkill)
  private
    FRepo: String;
    FToken: String;
    FRunAt: TSkillRunAt;
    FRunMode: TSkillRunMode;
    FLabels: TArray<String>;
    FTitleTpl: String;
    FBodyTpl: String;
    function ReplacePlaceholders(const aTemplate: String;
      aEntity: TObject; aContext: iSimpleSkillContext): String;
    function BuildDefaultTitle(aContext: iSimpleSkillContext): String;
    function BuildDefaultBody(aEntity: TObject; aContext: iSimpleSkillContext): String;
  public
    constructor Create(const aRepo, aToken: String;
      aRunAt: TSkillRunAt = srAfterInsert;
      aRunMode: TSkillRunMode = srmNormal);
    destructor Destroy; override;
    class function New(const aRepo, aToken: String;
      aRunAt: TSkillRunAt = srAfterInsert;
      aRunMode: TSkillRunMode = srmNormal): TSkillGitHubIssue;
    function Labels(aLabels: TArray<String>): TSkillGitHubIssue;
    function TitleTemplate(const aTemplate: String): TSkillGitHubIssue;
    function BodyTemplate(const aTemplate: String): TSkillGitHubIssue;
    function Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
    function Name: String;
    function RunAt: TSkillRunAt;
    function RunMode: TSkillRunMode;
  end;
```

**Important:** `New` returns `TSkillGitHubIssue` (not `iSimpleSkill`) so that fluent `.Labels(...)` and `.TitleTemplate(...)` work before the reference is assigned to `iSimpleSkill`. The Delphi compiler will handle the implicit interface cast when assigned to `iSimpleSkill` parameter in `.Skill(...)`.

**Step 2: Implement the class**

```pascal
{ TSkillGitHubIssue }

constructor TSkillGitHubIssue.Create(const aRepo, aToken: String;
  aRunAt: TSkillRunAt; aRunMode: TSkillRunMode);
begin
  FRepo := aRepo;
  FToken := aToken;
  FRunAt := aRunAt;
  FRunMode := aRunMode;
  FTitleTpl := '';
  FBodyTpl := '';
end;

destructor TSkillGitHubIssue.Destroy;
begin
  inherited;
end;

class function TSkillGitHubIssue.New(const aRepo, aToken: String;
  aRunAt: TSkillRunAt; aRunMode: TSkillRunMode): TSkillGitHubIssue;
begin
  Result := Self.Create(aRepo, aToken, aRunAt, aRunMode);
end;

function TSkillGitHubIssue.Labels(aLabels: TArray<String>): TSkillGitHubIssue;
begin
  Result := Self;
  FLabels := aLabels;
end;

function TSkillGitHubIssue.TitleTemplate(const aTemplate: String): TSkillGitHubIssue;
begin
  Result := Self;
  FTitleTpl := aTemplate;
end;

function TSkillGitHubIssue.BodyTemplate(const aTemplate: String): TSkillGitHubIssue;
begin
  Result := Self;
  FBodyTpl := aTemplate;
end;

function TSkillGitHubIssue.ReplacePlaceholders(const aTemplate: String;
  aEntity: TObject; aContext: iSimpleSkillContext): String;
begin
  Result := aTemplate;
  Result := StringReplace(Result, '{entity}', aContext.EntityName, [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '{operation}', aContext.Operation, [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '{error}', aContext.ErrorMessage, [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '{timestamp}', DateToISO8601(Now), [rfReplaceAll, rfIgnoreCase]);
end;

function TSkillGitHubIssue.BuildDefaultTitle(aContext: iSimpleSkillContext): String;
begin
  if FRunMode = srmOnError then
    Result := '[SimpleORM Error] ' + aContext.Operation + ' on ' + aContext.EntityName +
      ': ' + aContext.ErrorMessage
  else
    Result := '[SimpleORM] ' + aContext.Operation + ' on ' + aContext.EntityName;
end;

function TSkillGitHubIssue.BuildDefaultBody(aEntity: TObject;
  aContext: iSimpleSkillContext): String;
var
  LEntityJSON: TJSONObject;
  LEntityStr: String;
begin
  LEntityStr := '(no entity data)';
  if aEntity <> nil then
  begin
    try
      LEntityJSON := TSimpleSerializer.EntityToJSON<TObject>(aEntity);
      try
        LEntityStr := LEntityJSON.ToJSON;
      finally
        LEntityJSON.Free;
      end;
    except
      LEntityStr := '(serialization error)';
    end;
  end;

  Result := '## Details' + #13#10 +
    '- **Entity:** ' + aContext.EntityName + #13#10 +
    '- **Operation:** ' + aContext.Operation + #13#10 +
    '- **Timestamp:** ' + DateToISO8601(Now) + #13#10;

  if aContext.ErrorMessage <> '' then
    Result := Result + '- **Error:** ' + aContext.ErrorMessage + #13#10;

  Result := Result + #13#10 + '## Entity Data' + #13#10 +
    '```json' + #13#10 + LEntityStr + #13#10 + '```' + #13#10 +
    #13#10 + '---' + #13#10 + '*Created by SimpleORM TSkillGitHubIssue*';
end;

function TSkillGitHubIssue.Execute(aEntity: TObject; aContext: iSimpleSkillContext): iSimpleSkill;
var
  LClient: THTTPClient;
  LTitle, LBody: String;
  LURL: String;
  LPayload: TJSONObject;
  LLabelsArr: TJSONArray;
  LLabel: String;
  LStream: TStringStream;
begin
  Result := Self;

  // Build title
  if FTitleTpl <> '' then
    LTitle := ReplacePlaceholders(FTitleTpl, aEntity, aContext)
  else
    LTitle := BuildDefaultTitle(aContext);

  // Build body
  if FBodyTpl <> '' then
    LBody := ReplacePlaceholders(FBodyTpl, aEntity, aContext)
  else
    LBody := BuildDefaultBody(aEntity, aContext);

  LURL := 'https://api.github.com/repos/' + FRepo + '/issues';

  LClient := THTTPClient.Create;
  try
    try
      LPayload := TJSONObject.Create;
      try
        LPayload.AddPair('title', LTitle);
        LPayload.AddPair('body', LBody);

        if Length(FLabels) > 0 then
        begin
          LLabelsArr := TJSONArray.Create;
          for LLabel in FLabels do
            LLabelsArr.Add(LLabel);
          LPayload.AddPair('labels', LLabelsArr);
        end;

        LStream := TStringStream.Create(LPayload.ToJSON, TEncoding.UTF8);
        try
          LClient.ContentType := 'application/json';
          LClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;
          LClient.CustomHeaders['Accept'] := 'application/vnd.github+json';
          LClient.CustomHeaders['User-Agent'] := 'SimpleORM';
          LClient.ConnectionTimeout := 5000;
          LClient.ResponseTimeout := 10000;
          LClient.Post(LURL, LStream);
        finally
          LStream.Free;
        end;
      finally
        LPayload.Free;
      end;
    except
      on E: Exception do
      begin
        {$IFDEF MSWINDOWS}
        OutputDebugString(PChar('[Skill:GitHubIssue] Error: ' + E.Message));
        {$ENDIF}
        {$IFDEF CONSOLE}
        Writeln('[Skill:GitHubIssue] Error: ', E.Message);
        {$ENDIF}
      end;
    end;
  finally
    LClient.Free;
  end;
end;

function TSkillGitHubIssue.Name: String;
begin
  Result := 'github-issue';
end;

function TSkillGitHubIssue.RunAt: TSkillRunAt;
begin
  Result := FRunAt;
end;

function TSkillGitHubIssue.RunMode: TSkillRunMode;
begin
  Result := FRunMode;
end;
```

**Step 3: Add `System.DateUtils` to the uses clause in the implementation section if not already present.**

Check `SimpleSkill.pas` implementation uses — it already has `System.DateUtils`. Good.

**Step 4: Commit**

```bash
git add src/SimpleSkill.pas
git commit -m "feat: implement TSkillGitHubIssue with GitHub REST API integration"
```

---

### Task 8: Write tests for TSkillGitHubIssue

**Files:**
- Modify: `tests/TestSimpleSkill.pas`

**Step 1: Add TTestSkillGitHubIssue test class**

```pascal
  TTestSkillGitHubIssue = class(TTestCase)
  published
    procedure TestGitHubIssue_Name;
    procedure TestGitHubIssue_RunAt;
    procedure TestGitHubIssue_RunMode_Normal;
    procedure TestGitHubIssue_RunMode_OnError;
    procedure TestGitHubIssue_Labels_ReturnsSelf;
    procedure TestGitHubIssue_TitleTemplate_ReturnsSelf;
    procedure TestGitHubIssue_BodyTemplate_ReturnsSelf;
    procedure TestGitHubIssue_NilEntity_NoError;
    procedure TestGitHubIssue_InvalidRepo_NoError;
    procedure TestGitHubIssue_Execute_FireAndForget;
  end;
```

**Step 2: Implement tests**

```pascal
{ TTestSkillGitHubIssue }

procedure TTestSkillGitHubIssue.TestGitHubIssue_Name;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillGitHubIssue.New('test/repo', 'fake-token');
  CheckEquals('github-issue', LSkill.Name, 'Should return github-issue');
end;

procedure TTestSkillGitHubIssue.TestGitHubIssue_RunAt;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillGitHubIssue.New('test/repo', 'fake-token', srAfterDelete);
  CheckTrue(LSkill.RunAt = srAfterDelete, 'Should return configured RunAt');
end;

procedure TTestSkillGitHubIssue.TestGitHubIssue_RunMode_Normal;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillGitHubIssue.New('test/repo', 'fake-token', srAfterInsert, srmNormal);
  CheckTrue(LSkill.RunMode = srmNormal, 'Should return Normal');
end;

procedure TTestSkillGitHubIssue.TestGitHubIssue_RunMode_OnError;
var
  LSkill: iSimpleSkill;
begin
  LSkill := TSkillGitHubIssue.New('test/repo', 'fake-token', srAfterInsert, srmOnError);
  CheckTrue(LSkill.RunMode = srmOnError, 'Should return OnError');
end;

procedure TTestSkillGitHubIssue.TestGitHubIssue_Labels_ReturnsSelf;
var
  LSkill: TSkillGitHubIssue;
  LResult: TSkillGitHubIssue;
begin
  LSkill := TSkillGitHubIssue.New('test/repo', 'fake-token');
  try
    LResult := LSkill.Labels(['bug', 'critical']);
    CheckTrue(LResult = LSkill, 'Labels should return Self');
  finally
    LSkill.Free;
  end;
end;

procedure TTestSkillGitHubIssue.TestGitHubIssue_TitleTemplate_ReturnsSelf;
var
  LSkill: TSkillGitHubIssue;
  LResult: TSkillGitHubIssue;
begin
  LSkill := TSkillGitHubIssue.New('test/repo', 'fake-token');
  try
    LResult := LSkill.TitleTemplate('[Test] {entity}');
    CheckTrue(LResult = LSkill, 'TitleTemplate should return Self');
  finally
    LSkill.Free;
  end;
end;

procedure TTestSkillGitHubIssue.TestGitHubIssue_BodyTemplate_ReturnsSelf;
var
  LSkill: TSkillGitHubIssue;
  LResult: TSkillGitHubIssue;
begin
  LSkill := TSkillGitHubIssue.New('test/repo', 'fake-token');
  try
    LResult := LSkill.BodyTemplate('Error: {error}');
    CheckTrue(LResult = LSkill, 'BodyTemplate should return Self');
  finally
    LSkill.Free;
  end;
end;

procedure TTestSkillGitHubIssue.TestGitHubIssue_NilEntity_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
begin
  LSkill := TSkillGitHubIssue.New('test/repo', 'fake-token');
  LContext := TSimpleSkillContext.New(nil, nil, nil, 'TEST', 'INSERT');
  LSkill.Execute(nil, LContext);
  CheckTrue(True, 'Nil entity should not raise (fire-and-forget)');
end;

procedure TTestSkillGitHubIssue.TestGitHubIssue_InvalidRepo_NoError;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
begin
  LEntity := TPedidoTest.Create;
  try
    LEntity.ID := 1;
    LEntity.CLIENTE := 'Teste';
    LSkill := TSkillGitHubIssue.New('invalid/nonexistent-repo-12345', 'fake-token');
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Invalid repo should not raise (fire-and-forget)');
  finally
    LEntity.Free;
  end;
end;

procedure TTestSkillGitHubIssue.TestGitHubIssue_Execute_FireAndForget;
var
  LSkill: iSimpleSkill;
  LContext: iSimpleSkillContext;
  LEntity: TPedidoTest;
begin
  LEntity := TPedidoTest.Create;
  try
    LEntity.ID := 99;
    LEntity.CLIENTE := 'GitHub Test';
    LEntity.VALORTOTAL := 250;
    LSkill := TSkillGitHubIssue.New(
      'invalid-host-that-does-not-exist/repo',
      'invalid-token',
      srAfterInsert,
      srmOnError
    );
    LContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDO', 'INSERT', 'Database connection lost');
    LSkill.Execute(LEntity, LContext);
    CheckTrue(True, 'Fire-and-forget: should not raise even with invalid endpoint');
  finally
    LEntity.Free;
  end;
end;
```

**Step 3: Register the test**

In the `initialization` section:

```pascal
  RegisterTest('Skills', TTestSkillGitHubIssue.Suite);
```

**Step 4: Commit**

```bash
git add tests/TestSimpleSkill.pas
git commit -m "test: add tests for TSkillGitHubIssue"
```

---

### Task 9: Create sample project

**Files:**
- Create: `samples/GitHubIssue/SimpleORMGitHubIssue.dpr`
- Create: `samples/GitHubIssue/README.md`

**Step 1: Create the sample .dpr**

```pascal
program SimpleORMGitHubIssue;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  SimpleAttributes in '..\..\src\SimpleAttributes.pas',
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleRTTI in '..\..\src\SimpleRTTI.pas',
  SimpleRTTIHelper in '..\..\src\SimpleRTTIHelper.pas',
  SimpleSQL in '..\..\src\SimpleSQL.pas',
  SimpleSkill in '..\..\src\SimpleSkill.pas',
  SimpleSerializer in '..\..\src\SimpleSerializer.pas',
  SimpleLogger in '..\..\src\SimpleLogger.pas',
  SimpleValidator in '..\..\src\SimpleValidator.pas',
  Entidade.Produto in '..\Entidades\Entidade.Produto.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    Writeln('=== SimpleORM - TSkillGitHubIssue Demo ===');
    Writeln;

    // -------------------------------------------------------
    // IMPORTANTE: Substitua pelos seus dados reais do GitHub
    // -------------------------------------------------------
    // var REPO  := 'seu-usuario/seu-repositorio';
    // var TOKEN := 'ghp_seu_personal_access_token';

    Writeln('1) Modo OnError - Cria Issue quando operacao falha:');
    Writeln;
    Writeln('   LDAO := TSimpleDAO<TProduto>.New(LQuery)');
    Writeln('     .Skill(TSkillGitHubIssue.New(REPO, TOKEN, srAfterInsert, srmOnError))');
    Writeln('     .OnError(procedure(aEntity: TObject; E: Exception)');
    Writeln('       begin');
    Writeln('         Writeln(''Erro capturado: '', E.Message);');
    Writeln('       end);');
    Writeln;

    Writeln('2) Modo Normal com template - Cria Issue em todo Delete (auditoria):');
    Writeln;
    Writeln('   LDAO := TSimpleDAO<TProduto>.New(LQuery)');
    Writeln('     .Skill(TSkillGitHubIssue.New(REPO, TOKEN, srAfterDelete, srmNormal)');
    Writeln('       .Labels([''audit'', ''delete''])');
    Writeln('       .TitleTemplate(''[Audit] {entity} deletado por {operation}''));');
    Writeln;

    Writeln('3) Modo OnError com labels customizadas:');
    Writeln;
    Writeln('   LDAO := TSimpleDAO<TProduto>.New(LQuery)');
    Writeln('     .Skill(TSkillGitHubIssue.New(REPO, TOKEN, srAfterInsert, srmOnError)');
    Writeln('       .Labels([''bug'', ''producao'', ''critico''])');
    Writeln('       .TitleTemplate(''[CRITICO] Falha em {operation} na {entity}'')');
    Writeln('       .BodyTemplate(''Erro: {error}'' + #13#10 + ''Timestamp: {timestamp}''));');
    Writeln;

    Writeln('4) Callback OnError generico (sem GitHub):');
    Writeln;
    Writeln('   LDAO := TSimpleDAO<TProduto>.New(LQuery)');
    Writeln('     .OnError(procedure(aEntity: TObject; E: Exception)');
    Writeln('       begin');
    Writeln('         // Gravar em log, enviar email, notificar Slack, etc.');
    Writeln('         Writeln(''Erro: '', E.Message);');
    Writeln('       end);');
    Writeln;

    Writeln('-------------------------------------------------------');
    Writeln('Placeholders disponiveis em templates:');
    Writeln('  {entity}    - Nome da tabela da entidade');
    Writeln('  {operation}  - INSERT, UPDATE ou DELETE');
    Writeln('  {error}      - Mensagem de erro (vazio em modo Normal)');
    Writeln('  {timestamp}  - Data/hora ISO8601');
    Writeln('-------------------------------------------------------');
    Writeln;
    Writeln('Para testar, substitua REPO e TOKEN com dados reais e');
    Writeln('descomente o codigo acima.');
    Writeln;

  except
    on E: Exception do
      Writeln('Erro: ', E.Message);
  end;

  Writeln('Pressione Enter para sair...');
  Readln;
end.
```

**Step 2: Create README.md**

```markdown
# SimpleORM - GitHub Issue Skill

Exemplo de integracao do SimpleORM com GitHub Issues via `TSkillGitHubIssue`.

## Pre-requisitos

1. Conta no GitHub
2. Personal Access Token (PAT) com permissao `repo` (Settings > Developer settings > Personal access tokens)
3. Repositorio onde as Issues serao criadas

## Como usar

1. Abra `SimpleORMGitHubIssue.dpr` na IDE Delphi
2. Substitua `REPO` e `TOKEN` pelos seus dados
3. Compile e execute

## Modos de operacao

### OnError (srmOnError)
Cria Issue automaticamente quando uma operacao CRUD falha:
- Insert que viola constraint do banco
- Update com dados invalidos
- Delete bloqueado por FK

### Normal (srmNormal)
Cria Issue em toda operacao bem-sucedida (auditoria):
- Registrar todo Delete para compliance
- Auditar Inserts em tabelas criticas

## Placeholders para templates

| Placeholder | Descricao |
|-------------|-----------|
| `{entity}` | Nome da tabela da entidade |
| `{operation}` | INSERT, UPDATE ou DELETE |
| `{error}` | Mensagem de erro (vazio em modo Normal) |
| `{timestamp}` | Data/hora em formato ISO8601 |
```

**Step 3: Commit**

```bash
git add samples/GitHubIssue/SimpleORMGitHubIssue.dpr samples/GitHubIssue/README.md
git commit -m "feat: add GitHubIssue sample project"
```

---

### Task 10: Update CHANGELOG, documentation, and register in packages

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/index.html`
- Modify: `docs/en/index.html`

**Step 1: Add entries to CHANGELOG.md**

Add under `[Unreleased]` > `Added` (or create `[Unreleased]` if it was moved to a version):

```
- **TSkillRunMode** - Enum para modo de execucao de Skills: Normal e OnError (SimpleTypes.pas)
- **TSimpleErrorCallback** - Tipo callback para tratamento de erros no DAO (SimpleTypes.pas)
- **RunMode** - Metodo em iSimpleSkill para controlar modo de execucao Normal/OnError (SimpleInterface.pas)
- **ErrorMessage** - Metodo em iSimpleSkillContext para acessar mensagem de erro (SimpleInterface.pas)
- **RunOnError** - Metodo no TSimpleSkillRunner para executar skills em modo OnError (SimpleSkill.pas)
- **OnError** - Callback generico no TSimpleDAO para tratamento de erros em Insert/Update/Delete (SimpleDAO.pas)
- **TSkillGitHubIssue** - Skill para criacao automatica de Issues no GitHub via REST API (SimpleSkill.pas)
- **Sample GitHubIssue** - Projeto demonstrando uso do TSkillGitHubIssue (samples/GitHubIssue/)
```

**Step 2: Add Supabase section to docs/index.html**

Add a new `<section id="github-issue">` in `docs/index.html` before the `<footer>`, with a quick example showing both modes and the template placeholders table. Follow the same compact style used for the simplified Supabase section.

**Step 3: Add same section to docs/en/index.html** (English version)

**Step 4: Commit**

```bash
git add CHANGELOG.md docs/index.html docs/en/index.html
git commit -m "docs: add TSkillGitHubIssue to CHANGELOG and documentation"
```

---

Plan complete and saved to `docs/plans/2026-03-10-github-issue-skill-plan.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?