# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SimpleORM is a Delphi ORM library that simplifies CRUD operations. It supports multiple database connection drivers (FireDAC, RestDataware, UniDAC, Zeos) and works with both VCL and FMX frameworks. The project is written in Object Pascal (Delphi).

## Build & Installation

- **Package manager**: [Boss](https://github.com/HashLoad/boss) (`boss install academiadocodigo/SimpleORM`)
- **Manual install**: Add the SimpleORM root directory to the Delphi Library Path
- **Package file**: `SimpleORM.dpk` (design-time package, no component installation required)
- **Project group**: `SimpleORM_Group.groupproj` contains the library and sample projects
- No test suite exists in this repository

## Architecture

### Core Interfaces (`SimpleInterface.pas`)

All core contracts are defined here. Key interfaces:
- **`iSimpleDAO<T>`** - Main DAO interface for CRUD operations (Insert/Update/Delete/Find), batch operations (InsertBatch/UpdateBatch/DeleteBatch), ForceDelete, and Logger
- **`iSimpleDAOSQLAttribute<T>`** - Fluent SQL builder (Fields/Where/Join/OrderBy/GroupBy/Skip/Take), accessed via `iSimpleDAO.SQL` and returned via `.&End`
- **`iSimpleQuery`** - Database connection abstraction (SQL/Params/ExecSQL/Open/DataSet) with transaction control (StartTransaction/Commit/Rollback/InTransaction) and SQLType
- **`iSimpleRTTI<T>`** - RTTI introspection for entity-to-SQL mapping, including SoftDeleteField detection
- **`iSimpleSQL<T>`** - SQL generation from entity metadata, with pagination (Skip/Take/DatabaseType) and soft delete support
- **`iSimpleQueryLogger`** - Query logging interface (`SimpleLogger.pas`), with default `TSimpleQueryLoggerConsole` implementation

### Entity Mapping (`SimpleAttributes.pas`)

Custom attributes for mapping Delphi classes to database tables:
- `Tabela('NAME')` - Maps class to table name
- `Campo('NAME')` - Maps property to column name (optional if property name matches column)
- `PK`, `FK`, `AutoInc`, `NotNull`, `NotZero`, `Ignore`, `NumberOnly` - Field metadata
- `Bind('FIELD')` - Maps form components to entity properties for automatic UI binding
- `Display('NAME')` - Grid column header text
- `Format(size, precision)` - Field formatting and validation constraints (MaxSize/MinSize validated by TSimpleValidator)
- `HasOne('entity', 'fk')`, `BelongsTo('entity', 'fk')` - Eager-loaded relationships (auto-loaded in Find)
- `HasMany('entity', 'fk')`, `BelongsToMany('entity', 'fk')` - Relationship attributes (use `TSimpleLazyLoader<T>` from `SimpleProxy.pas` for lazy loading)
- `SoftDelete('FIELD_NAME')` - Class-level attribute enabling logical deletion (DELETE becomes UPDATE, SELECT auto-filters)
- `Email`, `MinValue(n)`, `MaxValue(n)`, `Regex('pattern', 'message')` - Validation attributes
- `Enumerator('TYPE')` - PostgreSQL-style enum type casting

### Data Flow

1. **Entity class** is annotated with attributes (`SimpleAttributes.pas`)
2. **`TSimpleRTTI<T>`** (`SimpleRTTI.pas`) reads attributes via RTTI to extract table name, fields, PK, and values
3. **`TSimpleSQL<T>`** (`SimpleSQL.pas`) generates SQL statements (INSERT/UPDATE/DELETE/SELECT) using RTTI data
4. **`TSimpleDAO<T>`** (`SimpleDAO.pas`) orchestrates: generates SQL via `TSimpleSQL`, fills parameters via `TSimpleRTTI`, executes via `iSimpleQuery`
5. **Query drivers** (`SimpleQueryFiredac.pas`, `SimpleQueryRestDW.pas`, `SimpleQueryUnidac.pas`, `SimpleQueryZeos.pas`) implement `iSimpleQuery` for their respective connection libraries

### RTTI Helpers (`SimpleRTTIHelper.pas`)

Class helpers on `TRttiProperty`, `TRttiType`, and `TRttiField` that provide attribute-checking methods (e.g., `EhChavePrimaria`, `IsAutoInc`, `FieldName`, `DisplayName`, `IsHasOne`, `IsBelongsTo`, `IsEmail`, `HasFormat`, `IsSoftDelete`). These are used extensively throughout `SimpleRTTI.pas` and `SimpleValidator.pas`.

### Entity Base Class (`SimpleEntity.pas`)

`TSimpleEntity` provides `Parse` (from Form, DataSet, or JSON), `ToJSON`, and `SaveToFileJSON`. `TSimpleEntityList<T>` extends `TObjectList<T>` with similar capabilities.

### Lazy Loading Proxy (`SimpleProxy.pas`)

`TSimpleLazyLoader<T>` extends `TObjectList<T>` and defers query execution until first access (Count/ToArray). Used for HasMany relationships - instantiate in entity constructors.

### Query Logging (`SimpleLogger.pas`)

`iSimpleQueryLogger` interface with `Log(SQL, Params, DurationMs)`. Default implementation `TSimpleQueryLoggerConsole` outputs via OutputDebugString (Windows) or WriteLn (console). Attach via `TSimpleDAO.Logger(...)`.

### Validation (`SimpleValidator.pas`)

`TSimpleValidator.Validate(object)` checks constraints using RTTI: `NotNull`, `NotZero`, `Format` (string length), `Email`, `MinValue`, `MaxValue`, `Regex`. Raises `ESimpleValidator` with accumulated error messages.

### Conditional Compilation

- `{$IFNDEF CONSOLE}` guards all UI-binding code (form bind, VCL/FMX components)
- `{$IFDEF FMX}` / `{$IFDEF VCL}` switches between FMX and VCL component types
- `{$IF RTLVERSION > 31.0}` guards newer RTTI type kinds (`tkMRecord`)

## Conventions

- Portuguese naming in helper methods (e.g., `EhChavePrimaria` = "is primary key", `EhChaveEstrangeira` = "is foreign key", `Tem<T>` = "has attribute")
- Fluent interface pattern throughout: all methods return `Self` for chaining
- All main classes follow `TSimpleXxx.New(...)` constructor pattern returning an interface
- Properties must be declared in the `published` section for RTTI attribute mapping to work
- SQL uses parameterized queries with `:fieldname` syntax
- Transaction control is explicit: call `StartTransaction`/`Commit`/`Rollback` on `iSimpleQuery`
- `TSQLType` (Firebird, MySQL, SQLite, Oracle) is set on the query driver and propagated for database-specific SQL (pagination)
- Pagination uses fluent `.SQL.Skip(n).Take(n).&End.Find` pattern
- Batch operations (`InsertBatch`/`UpdateBatch`/`DeleteBatch`) auto-wrap in transactions
- `SimpleJSON.pas` is deprecated - use `SimpleJSONUtil.pas` for all JSON operations
