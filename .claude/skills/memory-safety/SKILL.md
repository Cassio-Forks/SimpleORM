---
name: memory-safety
description: Delphi memory management patterns for SimpleORM - ownership, try/finally, interface refs, and common leak scenarios.
user-invocable: false
---

# Delphi Memory Safety for SimpleORM

> **Rules are in `.claude/rules/security.md`** — this skill provides patterns and examples.

## Ownership Patterns

### Interface References (Auto-managed)
```pascal
var
  LQuery: iSimpleQuery;  // Reference counted
begin
  LQuery := TSimpleQueryFiredac.New(Conn);
  // Do NOT call LQuery.Free — freed automatically when ref count = 0
end;
```

### Object References (Manual management)
```pascal
var
  LList: TObjectList<T>;
begin
  LList := TObjectList<T>.Create;
  try
    // Use LList
  finally
    LList.Free;
  end;
end;
```

## Pattern: Object Created, Used, and Freed

```pascal
LEntity := T.Create;
try
  LDAO.Insert(LEntity);
finally
  LEntity.Free;
end;
```

## Pattern: Object Created and Returned

```pascal
function CreateEntity: T;
begin
  Result := T.Create;
  try
    // Populate Result
  except
    Result.Free;  // Free on error only
    raise;
  end;
  // Caller owns Result — caller must free it
end;
```

## Pattern: List with Error Safety

```pascal
function CreateList: TObjectList<T>;
begin
  Result := TObjectList<T>.Create;
  try
    for I := 0 to N do
      Result.Add(CreateItem);
  except
    Result.Free;  // Frees list AND owned objects
    raise;
  end;
end;
```

## Pattern: Destructor

```pascal
destructor TSimpleXxx.Destroy;
begin
  FreeAndNil(FOwnedComponent1);
  FreeAndNil(FOwnedComponent2);
  // Interface fields: do NOT free (auto-managed)
  inherited;
end;
```

## Common Leak Scenarios in SimpleORM

### JSON Parsing
```pascal
LJSON := TJSONObject.ParseJSONValue(Body) as TJSONObject;
if LJSON = nil then
  raise Exception.Create('Invalid JSON');
try
  // Use LJSON
finally
  LJSON.Free;
end;
```

### TRttiContext
`TRttiContext` is a RECORD (not class). `.Create` and `.Free` are no-ops. Do not treat it as an object.

### DataSet Operations
```pascal
FQuery.DataSet.DisableControls;
try
  // Process dataset
finally
  FQuery.DataSet.EnableControls;
end;
```
