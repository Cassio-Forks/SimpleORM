# DUnit Test Suite Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Criar suite completa de testes unitarios com DUnit cobrindo todas as units de logica pura do SimpleORM.

**Architecture:** Testes organizados em `tests/` com entidades de teste decoradas com atributos, mock de iSimpleQuery, e test runner console. Foco inicial nas 8 units de logica pura (sem banco de dados).

**Tech Stack:** DUnit (TestFramework), Delphi RTTI, TClientDataSet (mock de DataSet)

---

### Task 1: Infraestrutura — Entidades de Teste

**Files:**
- Create: `tests/Entities/TestEntities.pas`

Entidades de teste com todas as combinacoes de atributos para exercitar RTTI, SQL, validacao e serializacao.

### Task 2: Test Runner

**Files:**
- Create: `tests/SimpleORMTests.dpr`

Programa console DUnit que registra e executa todos os testes.

### Task 3: TestSimpleAttributes

**Files:**
- Create: `tests/TestSimpleAttributes.pas`

Testar criacao de todos os atributos, propriedades, construtores overloaded, GetNumericMask.

### Task 4: TestSimpleRTTIHelper

**Files:**
- Create: `tests/TestSimpleRTTIHelper.pas`

Testar todos os helpers: IsNotNull, IsAutoInc, EhChavePrimaria, FieldName, DisplayName, IsHasOne, IsSoftDelete, etc.

### Task 5: TestSimpleSQL

**Files:**
- Create: `tests/TestSimpleSQL.pas`

Testar geracao de INSERT, UPDATE, DELETE, SELECT. Paginacao por dialeto (Firebird, MySQL, SQLite, Oracle). SoftDelete. Clausulas Where, Join, OrderBy, GroupBy.

### Task 6: TestSimpleValidator

**Files:**
- Create: `tests/TestSimpleValidator.pas`

Testar todas as validacoes: NotNull (string, integer, float, date), NotZero, Format (min/max size), Email, MinValue, MaxValue, Regex.

### Task 7: TestSimpleSerializer

**Files:**
- Create: `tests/TestSimpleSerializer.pas`

Testar EntityToJSON, JSONToEntity, EntityListToJSONArray, JSONArrayToEntityList.

### Task 8: Mock iSimpleQuery

**Files:**
- Create: `tests/Mocks/MockSimpleQuery.pas`

Mock de iSimpleQuery usando TClientDataSet para testes de DAO sem banco de dados.

### Task 9: TestSimpleDAO

**Files:**
- Create: `tests/TestSimpleDAO.pas`

Testar CRUD operations do DAO usando MockSimpleQuery. Insert, Update, Delete, Find.

### Task 10: Regras e Documentacao

**Files:**
- Create: `.claude/rules/testing.md`
- Update: `docs/index.html`
- Update: `CHANGELOG.md`
- Update: `CLAUDE.md`
