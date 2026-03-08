---
name: sql-generation
description: SQL generation reference for SimpleORM — how TSimpleSQL builds queries, pagination by dialect, soft delete behavior.
user-invocable: false
---

# SQL Generation in SimpleORM

> **Rules are in `.claude/rules/sql-safety.md`** — this skill provides generation flow reference and examples.

## Generation Flow

```
Entity (RTTI attributes)
  → TSimpleRTTI<T> extracts: TableName, Fields, PK, Where, SoftDeleteField, FieldsInsert, Param
    → TSimpleSQL<T> generates: SELECT, INSERT, UPDATE, DELETE
      → TSimpleDAO<T> fills Params via DictionaryFields
        → iSimpleQuery executes
```

## TSimpleSQL<T> Methods

| Method | Generates |
|--------|-----------|
| `Select(var aSQL)` | `SELECT fields FROM table WHERE ...` |
| `SelectId(var aSQL)` | `SELECT fields FROM table WHERE pk = :pk` |
| `Insert(var aSQL)` | `INSERT INTO table (fields) VALUES (:params)` |
| `Update(var aSQL)` | `UPDATE table SET field=:field WHERE pk=:pk` |
| `Delete(var aSQL)` | `DELETE FROM` or `UPDATE SET soft=1` |
| `LastID(var aSQL)` | `SELECT FIRST(1) pk FROM table ORDER BY pk DESC` |
| `LastRecord(var aSQL)` | `SELECT FIRST(1) fields FROM table ORDER BY pk DESC` |

## Pagination by Database Dialect

| Database | Syntax | Position |
|----------|--------|----------|
| Firebird | `SELECT FIRST n SKIP n fields FROM ...` | After SELECT |
| MySQL | `... LIMIT n OFFSET n` | End of query |
| SQLite | `... LIMIT n OFFSET n` | End of query |
| Oracle | `... OFFSET n ROWS FETCH NEXT n ROWS ONLY` | End of query |

## Soft Delete Behavior

- **SELECT**: Auto-appends `WHERE soft_field = 0`
- **DELETE**: Becomes `UPDATE table SET soft_field = 1 WHERE pk = :pk`
- **ForceDelete**: Ignores soft delete, uses real `DELETE FROM`

## Fluent SQL Building

```pascal
LDAO.SQL
  .Fields('ID, NAME')
  .Where('STATUS = 1')
  .OrderBy('NAME')
  .GroupBy('CATEGORY')
  .Join('INNER JOIN OTHER ON ...')
  .Skip(10)
  .Take(20)
  .&End
  .Find(LList);
```

## Known Limitations

- `LastID`/`LastRecord` hardcoded to Firebird syntax (`SELECT FIRST(1)`) — not dialect-aware
