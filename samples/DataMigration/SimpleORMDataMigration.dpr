program SimpleORMDataMigration;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.JSON,
  System.Variants,
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleDataMigration in '..\..\src\SimpleDataMigration.pas';

var
  LMigration: TSimpleDataMigration;
  LReport: TMigrationReport;
  LTableReport: TTableReport;
  LError: TMigrationError;
  LJsonObj: TJSONObject;
  LJsonFile: String;
  LUpperResult: Variant;
  LLowerResult: Variant;
  LTrimResult: Variant;
  LReplaceResult: Variant;
  LSplitResult: Variant;
  LCustomResult: Variant;

begin
  try
    { ================================================================ }
    { Exemplo 1: API Fluent                                            }
    { Demonstra mapeamento fluente com Field, Transform, Replace,      }
    { DefaultValue e Ignore.                                           }
    { ================================================================ }
    Writeln('=== Exemplo 1: API Fluent ===');
    Writeln('');

    LMigration := TSimpleDataMigration.New;
    try
      LMigration
        .BatchSize(500)
        .Validate(True)
        .Map('CLIENTES_ANTIGO', 'CLIENTES_NOVO')
          .Field('ID', 'ID_CLIENTE')
          .Transform('NOME', 'NOME_COMPLETO', TFieldTransform.Upper)
          .Transform('EMAIL', 'EMAIL', TFieldTransform.Replace('@antigo.com', '@novo.com'))
          .DefaultValue('STATUS', 'ATIVO')
          .Ignore('CAMPO_OBSOLETO')
        .&End;

      Writeln('Mapeamento criado com sucesso!');
      Writeln('MapCount: ', LMigration.MapCount);
      Writeln('BatchSize: ', LMigration.GetBatchSize);
      Writeln('Validate: ', BoolToStr(LMigration.GetValidate, True));
      Writeln('');
    finally
      FreeAndNil(LMigration);
    end;

    { ================================================================ }
    { Exemplo 2: Persistencia JSON                                     }
    { Salva o mapeamento em JSON e carrega novamente.                  }
    { ================================================================ }
    Writeln('=== Exemplo 2: Persistencia JSON ===');
    Writeln('');

    LJsonFile := ExtractFilePath(ParamStr(0)) + 'migration_config.json';

    { Salvar mapeamento }
    LMigration := TSimpleDataMigration.New;
    try
      LMigration
        .BatchSize(250)
        .Validate(True)
        .Map('PRODUTOS_V1', 'PRODUTOS_V2')
          .Field('COD', 'ID_PRODUTO')
          .Field('DESCR', 'DESCRICAO')
          .DefaultValue('VERSAO', '2.0')
          .Ignore('CAMPO_TEMP')
        .&End
        .SaveToJSON(LJsonFile);

      Writeln('Mapeamento salvo em: ', LJsonFile);
      Writeln('MapCount antes de salvar: ', LMigration.MapCount);
    finally
      FreeAndNil(LMigration);
    end;

    { Carregar mapeamento }
    LMigration := TSimpleDataMigration.New;
    try
      LMigration.LoadFromJSON(LJsonFile);

      Writeln('Mapeamento carregado do JSON com sucesso!');
      Writeln('MapCount apos carregar: ', LMigration.MapCount);
      Writeln('BatchSize apos carregar: ', LMigration.GetBatchSize);
      Writeln('');
    finally
      FreeAndNil(LMigration);
    end;

    { Limpar arquivo temporario }
    if FileExists(LJsonFile) then
      DeleteFile(LJsonFile);

    { ================================================================ }
    { Exemplo 3: Transformacoes Built-in                               }
    { Demonstra cada tipo de TFieldTransform.                          }
    { ================================================================ }
    Writeln('=== Exemplo 3: Transformacoes Built-in ===');
    Writeln('');

    { Upper }
    LUpperResult := TFieldTransform.Upper()('joao silva');
    Writeln('Upper("joao silva"): ', VarToStr(LUpperResult));

    { Lower }
    LLowerResult := TFieldTransform.Lower()('JOAO SILVA');
    Writeln('Lower("JOAO SILVA"): ', VarToStr(LLowerResult));

    { Trim }
    LTrimResult := TFieldTransform.Trim()('  espacos  ');
    Writeln('Trim("  espacos  "): "', VarToStr(LTrimResult), '"');

    { Replace }
    LReplaceResult := TFieldTransform.Replace('@antigo.com', '@novo.com')('user@antigo.com');
    Writeln('Replace("user@antigo.com"): ', VarToStr(LReplaceResult));

    { Split }
    LSplitResult := TFieldTransform.Split(';', 1)('parte1;parte2;parte3');
    Writeln('Split("parte1;parte2;parte3", index=1): ', VarToStr(LSplitResult));

    { Custom }
    LCustomResult := TFieldTransform.Custom(
      function(aValue: Variant): Variant
      begin
        Result := 'PREFIXO_' + VarToStr(aValue);
      end
    )('valor_original');
    Writeln('Custom("valor_original"): ', VarToStr(LCustomResult));

    Writeln('');

    { ================================================================ }
    { Exemplo 4: Relatorio de Migracao                                 }
    { Cria um TMigrationReport manualmente com dados de exemplo.       }
    { ================================================================ }
    Writeln('=== Exemplo 4: Relatorio de Migracao ===');
    Writeln('');

    LReport := TMigrationReport.Create;
    try
      LReport.MarkStart;

      { Tabela 1: maioria migrada com sucesso }
      LTableReport := LReport.AddTable('CLIENTES_V1', 'CLIENTES_V2');
      LTableReport.TotalRecords := 800;
      LTableReport.Migrated := 797;
      LTableReport.Failed := 2;
      LTableReport.Skipped := 1;

      LError.SourceTable := 'CLIENTES_V1';
      LError.RecordIndex := 150;
      LError.FieldName := 'EMAIL';
      LError.ErrorMessage := 'Email invalido: formato incorreto';
      LError.OriginalValue := 'email_sem_arroba';
      LTableReport.AddError(LError);

      { Tabela 2: migracao perfeita }
      LTableReport := LReport.AddTable('PRODUTOS_V1', 'PRODUTOS_V2');
      LTableReport.TotalRecords := 200;
      LTableReport.Migrated := 198;
      LTableReport.Failed := 1;
      LTableReport.Skipped := 1;

      LReport.MarkEnd;

      { Totais }
      Writeln('--- Totais ---');
      Writeln('Total de registros: ', LReport.TotalRecords);
      Writeln('Migrados: ', LReport.Migrated);
      Writeln('Falhos: ', LReport.Failed);
      Writeln('Ignorados: ', LReport.Skipped);
      Writeln('Erros: ', Length(LReport.Errors));
      Writeln('Duracao (ms): ', LReport.DurationMs);
      Writeln('');

      { CSV }
      Writeln('--- Relatorio CSV ---');
      Writeln(LReport.ToCSV);

      { JSON }
      Writeln('--- Relatorio JSON ---');
      LJsonObj := LReport.ToJSON;
      try
        Writeln(LJsonObj.Format);
      finally
        FreeAndNil(LJsonObj);
      end;
    finally
      FreeAndNil(LReport);
    end;

    Writeln('');
    Writeln('Exemplos concluidos com sucesso!');
  except
    on E: Exception do
      Writeln('Erro: ', E.Message);
  end;

  Writeln('');
  Writeln('Pressione ENTER para sair...');
  Readln;
end.
