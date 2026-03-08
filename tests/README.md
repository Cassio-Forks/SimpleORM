# SimpleORM Test Suite

Suite de testes unitarios usando DUnit.

## Como executar

1. Abra `SimpleORMTests.dpr` no Delphi IDE
2. Compile o projeto (o IDE gerara os arquivos `.dproj` e `.res` automaticamente)
3. Execute o programa

### Execucao com pausa

```
SimpleORMTests.exe -pause
```

## Estrutura

```
tests/
  SimpleORMTests.dpr          - Test runner (programa principal)
  Entities/
    TestEntities.pas           - Entidades de teste decoradas com atributos
  Mocks/
    (futuros mocks de iSimpleQuery)
  TestSimpleAttributes.pas     - Testes dos atributos
  TestSimpleRTTIHelper.pas     - Testes dos RTTI helpers
  TestSimpleSQL.pas            - Testes de geracao SQL
  TestSimpleValidator.pas      - Testes de validacao
  TestSimpleSerializer.pas     - Testes de serializacao JSON
```

## Cobertura

| Unit | Testes | Status |
|------|--------|--------|
| SimpleAttributes | 22 | Implementado |
| SimpleRTTIHelper | 26 | Implementado |
| SimpleSQL | 20 | Implementado |
| SimpleValidator | 21 | Implementado |
| SimpleSerializer | 10 | Implementado |
| **Total** | **99** | |

## Adicionando novos testes

1. Crie `TestSimpleXxx.pas` seguindo o padrao existente
2. Adicione a unit no `uses` do `SimpleORMTests.dpr`
3. Registre os testes com `RegisterTest('Grupo', TMinhaClasse.Suite)`
4. Mantenha entidades de teste em `TestEntities.pas`
