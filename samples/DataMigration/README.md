# SimpleORM Data Migration - Sample

Projeto console demonstrando a API de Data Migration do SimpleORM.

## O que demonstra

1. **API Fluent** - Mapeamento de campos com Field, Transform, Replace, DefaultValue e Ignore
2. **Persistencia JSON** - Salvar e carregar configuracoes de migracao em JSON
3. **Transformacoes Built-in** - Upper, Lower, Trim, Replace, Split e Custom
4. **Relatorio** - TMigrationReport com totais, CSV e JSON

## Como executar

1. Abra `SimpleORMDataMigration.dpr` na IDE Delphi
2. A IDE ira gerar os arquivos `.dproj` e `.res` automaticamente
3. Compile e execute (F9)

## Migracao com banco de dados real

Para migrar dados entre dois bancos usando conexoes FireDAC:

```pascal
uses
  SimpleDataMigration,
  SimpleQueryFiredac;

var
  LSourceQuery, LTargetQuery: iSimpleQuery;
  LMigration: TSimpleDataMigration;
  LReport: TMigrationReport;
begin
  // Configurar conexoes FireDAC (ajuste para seu banco)
  LSourceQuery := TSimpleQueryFiredac.New(FDConnectionOrigem);
  LTargetQuery := TSimpleQueryFiredac.New(FDConnectionDestino);

  LMigration := TSimpleDataMigration.New;
  try
    LReport := LMigration
      .Source(LSourceQuery)
      .Target(LTargetQuery)
      .BatchSize(500)
      .Map('CLIENTES_ANTIGO', 'CLIENTES_NOVO')
        .Field('ID', 'ID_CLIENTE')
        .Transform('NOME', 'NOME_COMPLETO', TFieldTransform.Upper)
        .DefaultValue('STATUS', 'ATIVO')
      .&End
      .Execute;
    try
      Writeln('Migrados: ', LReport.Migrated);
      Writeln('Falhos: ', LReport.Failed);
    finally
      LReport.Free;
    end;
  finally
    LMigration.Free;
  end;
end;
```
