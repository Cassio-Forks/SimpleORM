---
name: changelog-format
description: CHANGELOG.md format reference and examples for the SimpleORM project.
user-invocable: false
---

# CHANGELOG Format for SimpleORM

> **Rules are in `.claude/rules/changelog.md`** — this skill provides format reference and examples.

## Structure

```markdown
# Changelog

## [Unreleased]

### Added
- **FeatureName** - Descricao breve da feature (`arquivo.pas`)

### Changed
- **ChangeName** - Descricao da mudanca

### Deprecated
- **DeprecatedName** - Descricao e alternativa

### Removed
- **RemovedName** - O que foi removido

### Fixed
- **BugName** - Descricao do que foi corrigido

---

## [X.Y.Z] - YYYY-MM-DD
...
```

## Section Mapping

| Type of Change | Section |
|---------------|---------|
| New files/features/attributes | Added |
| Behavior changes / refactoring | Changed |
| Deprecated code | Deprecated |
| Deleted code | Removed |
| Bug fixes | Fixed |

## Examples

```markdown
### Added
- **SimpleSerializer** - Serializador Entity <-> JSON via RTTI usando atributos `[Campo]` (`SimpleSerializer.pas`)
- **Unique** - Novo atributo de validacao para impedir valores duplicados (`SimpleValidator.pas`)

### Fixed
- **SQL Injection** - Metodo `Delete(aField, aValue)` agora usa query parametrizada

### Changed
- **EndTransaction** - Agora delega para `Commit` em todos os drivers
```
