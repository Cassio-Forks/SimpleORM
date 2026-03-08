---
name: entity-mapping
description: SimpleORM entity-to-database mapping via RTTI attributes. Complete reference for all attributes, property types, and relationship setup.
user-invocable: false
---

# Entity Mapping in SimpleORM

> **Rules are in `.claude/rules/entity-mapping.md`** — this skill provides reference and templates.

## Entity Template

```pascal
[Tabela('TABLE_NAME')]
TMyEntity = class
private
  FId: Integer;
  FName: String;
  procedure SetId(const Value: Integer);
  procedure SetName(const Value: String);
public
  constructor Create;
  destructor Destroy; override;
published
  [Campo('ID'), PK, AutoInc]
  property Id: Integer read FId write SetId;
  [Campo('NAME'), NotNull]
  property Name: String read FName write SetName;
end;
```

## All Available Attributes (SimpleAttributes.pas)

### Table & Column
| Attribute | Target | Purpose |
|-----------|--------|---------|
| `Tabela('NAME')` | class | Maps to database table |
| `Campo('NAME')` | property | Maps to column name |

### Keys
| Attribute | Purpose |
|-----------|---------|
| `PK` | Primary key (exactly one) |
| `FK` | Foreign key |
| `AutoInc` | Auto-increment (excluded from INSERT) |

### Constraints & Validation
| Attribute | Purpose |
|-----------|---------|
| `NotNull` | Required field |
| `NotZero` | Numeric cannot be zero |
| `Ignore` | Skip in all SQL operations |
| `Email` | Validates email format |
| `MinValue(n)` | Minimum numeric value |
| `MaxValue(n)` | Maximum numeric value |
| `Regex('pattern', 'msg')` | Custom regex validation |
| `Format(maxSize, precision)` | Size/precision constraints |

### Display & Binding
| Attribute | Purpose |
|-----------|---------|
| `Display('Label')` | Display name for grids/forms |
| `Bind('FIELD')` | Binds form component |
| `NumberOnly` | Numeric-only input |

### Relationships
| Attribute | Cardinality | Loading |
|-----------|------------|---------|
| `HasOne('Entity', 'FK')` | 1:1 | Eager |
| `BelongsTo('Entity', 'FK')` | N:1 | Eager |
| `HasMany('Entity', 'FK')` | 1:N | Lazy (TSimpleLazyLoader) |
| `BelongsToMany('Entity', 'FK')` | M:N | Manual |

### Special
| Attribute | Purpose |
|-----------|---------|
| `SoftDelete('FIELD')` | On class — logical deletion |
| `Enumerator('TYPE')` | PostgreSQL enum cast |

## Supported Property Types

| Delphi Type | JSON Serialization | DB Param Type |
|-------------|-------------------|---------------|
| `String` | string | ftString |
| `Integer` | number | ftInteger |
| `Int64` | number | ftLargeint |
| `Double` | number | ftFloat |
| `TDateTime` | ISO8601 string | ftDateTime |
| `Boolean` | true/false | ftBoolean |

## Relationship Setup Examples

HasOne/BelongsTo — eager loaded by DAO:
```pascal
[HasOne('PEDIDO', 'ID_PEDIDO')]
property Pedido: TPedido read FPedido write SetPedido;
```

HasMany — lazy loaded:
```pascal
uses SimpleProxy;
FItens := TSimpleLazyLoader<TItemPedido>.Create(Query, 'ID_PEDIDO', Self.Id);
```

## RTTI Flow

```
Entity class → TSimpleRTTI<T> extracts:
  .TableName → reads [Tabela] attribute
  .Fields → iterates published properties with [Campo]
  .PrimaryKey → finds property with [PK]
  .Where → builds PK = :PK condition
  .FieldsInsert → Fields minus [AutoInc]
  .SoftDeleteField → reads [SoftDelete] from class
```
