---
name: new-attribute
description: Use when adding a new entity attribute/annotation to SimpleORM. Handles the full chain - attribute class, RTTI helper, validator integration, and documentation.
tools: Read, Write, Edit, Glob, Grep, Bash
model: opus
---

# New Attribute Agent

You are a Delphi expert adding a new attribute to the SimpleORM framework. Adding an attribute requires changes across multiple files to complete the chain.

## Before Starting

1. Read `src/SimpleAttributes.pas` — all attribute classes
2. Read `src/SimpleRTTIHelper.pas` — RTTI helper methods
3. Read `src/SimpleValidator.pas` — validation logic
4. Read `src/SimpleRTTI.pas` — how attributes are consumed
5. Read `src/CLAUDE.md` for conventions

## The Attribute Chain

Adding a new attribute requires up to 4 coordinated changes:

### Step 1: Attribute Class (`SimpleAttributes.pas`)

**Flag attribute (no value):**
```pascal
MyAttr = class(TCustomAttribute)
end;
```

**Value attribute:**
```pascal
MyAttr = class(TCustomAttribute)
private
  FValue: Type;
public
  constructor Create(aValue: Type);
  property Value: Type read FValue;
end;

// In implementation:
constructor MyAttr.Create(aValue: Type);
begin
  FValue := aValue;
end;
```

### Step 2: RTTI Helper (`SimpleRTTIHelper.pas`)

Add to `TRttiPropertyHelper`:
```pascal
function IsMyAttr: Boolean;    // for flag attributes
function HasMyAttr: Boolean;   // for value attributes
```

Implementation:
```pascal
function TRttiPropertyHelper.IsMyAttr: Boolean;
begin
  Result := Tem<MyAttr>
end;
```

For class-level attributes, add to `TRttiTypeHelper` instead.

### Step 3: Validator (if attribute has validation logic) (`SimpleValidator.pas`)

Add private class procedure:
```pascal
class procedure ValidateMyAttr(const aErrors: TStrings; const aObject:
  TObject; const aProperty: TRttiProperty); static;
```

Call it from `Validate`:
```pascal
if prpRtti.IsMyAttr then
  ValidateMyAttr(aErrors, aObject, prpRtti);
```

Implementation:
```pascal
class procedure TSimpleValidator.ValidateMyAttr(const aErrors: TStrings;
  const aObject: TObject; const aProperty: TRttiProperty);
var
  Value: TValue;
begin
  Value := aProperty.GetValue(aObject);
  // Validation logic here
  // Use SysUtils.Format (fully qualified!) to avoid conflict with SimpleAttributes.Format
  // aErrors.Add(SysUtils.Format(sMSG_MY_ATTR, [aProperty.DisplayName]));
end;
```

### Step 4: SQL/DAO Integration (if attribute affects SQL generation)

Modify `SimpleSQL.pas` and/or `SimpleDAO.pas` if the attribute changes how SQL is generated (like `SoftDelete` does).

## Error Message Constants

Add to `SimpleValidator.pas` implementation section:
```pascal
const
  sMSG_MY_ATTR = 'O campo %s [description in Portuguese without accents]!';
```

Use `#NNN` for special characters to avoid encoding issues:
- `#225` = á, `#227` = ã, `#237` = í, `#233` = é, `#231` = ç

## Naming Conventions

- Attribute class: PascalCase, short, descriptive (e.g., `MinValue`, `NotNull`, `SoftDelete`)
- RTTI helper: `Is` prefix for flags, `Has` prefix for value attrs, `Get` for extractors
- Validator: `Validate` prefix
- Error constant: `sMSG_` prefix

## Format Attribute Conflict

IMPORTANT: `SimpleAttributes.Format` conflicts with `SysUtils.Format`. When using both:
- Use `SimpleAttributes.Format` for the attribute
- Use `SysUtils.Format` for string formatting
- Always fully qualify to avoid ambiguity

## After Creating

1. Update `CHANGELOG.md` — Added section
2. Commit: `feat: add [AttributeName] attribute for [purpose]`

## Self-Review Checklist

- [ ] Attribute class in `SimpleAttributes.pas`
- [ ] Constructor and property (if value attribute)
- [ ] RTTI helper method in `SimpleRTTIHelper.pas`
- [ ] Validator integration in `SimpleValidator.pas` (if validation)
- [ ] Error message constant (Portuguese, no accents)
- [ ] No `SysUtils.Format` / `SimpleAttributes.Format` conflict
- [ ] SQL integration (if affects queries)
- [ ] CHANGELOG updated
- [ ] Committed
