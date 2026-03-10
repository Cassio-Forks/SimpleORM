unit TestSimpleDataMigration;

interface

uses
  TestFramework, SimpleTypes, System.SysUtils, System.JSON, System.DateUtils,
  System.Generics.Collections, System.Variants,
  SimpleDataMigration;

type
  TTestMigrationReport = class(TTestCase)
  published
    procedure TestReport_Create_InitialValuesZero;
    procedure TestReport_AddTableReport_IncrementsTotals;
    procedure TestReport_AddError_IncrementsFailedCount;
    procedure TestReport_ToJSON_ContainsAllFields;
    procedure TestReport_ToCSV_ContainsHeaders;
    procedure TestReport_Duration_ReturnsPositive;
  end;

  TTestFieldTransform = class(TTestCase)
  published
    procedure TestUpper_ShouldConvertToUpperCase;
    procedure TestLower_ShouldConvertToLowerCase;
    procedure TestTrim_ShouldRemoveSpaces;
    procedure TestReplace_ShouldReplaceSubstring;
    procedure TestCustom_ShouldApplyCustomFunc;
    procedure TestDateFormat_ShouldConvertFormat;
    procedure TestSplit_ShouldReturnPart;
  end;

  TTestFieldMap = class(TTestCase)
  published
    procedure TestField_ShouldAddMapping;
    procedure TestTransform_ShouldAddMappingWithTransform;
    procedure TestDefaultValue_ShouldAddDefault;
    procedure TestLookup_ShouldAddLookupMapping;
    procedure TestIgnore_ShouldAddIgnoreMapping;
    procedure TestEnd_ShouldReturnMigration;
    procedure TestMultipleMappings_ShouldKeepAll;
  end;

  TTestSimpleDataMigration = class(TTestCase)
  published
    procedure TestCreate_ShouldInitialize;
    procedure TestMap_ShouldReturnFieldMap;
    procedure TestMap_MultipleTables_ShouldKeepAll;
    procedure TestBatchSize_ShouldSetValue;
    procedure TestValidate_ShouldSetFlag;
    procedure TestFluentChaining_ShouldWork;
    procedure TestSaveToJSON_ShouldCreateFile;
    procedure TestLoadFromJSON_ShouldRestoreMappings;
  end;

  TTestCSVHelper = class(TTestCase)
  published
    procedure TestReadCSV_ShouldReturnHeaders;
    procedure TestReadCSV_ShouldReturnRows;
    procedure TestWriteCSV_ShouldCreateFile;
    procedure TestReadCSV_EmptyFile_ShouldReturnEmptyList;
  end;

implementation

{ TTestMigrationReport }

procedure TTestMigrationReport.TestReport_Create_InitialValuesZero;
var
  LReport: TMigrationReport;
begin
  LReport := TMigrationReport.Create;
  try
    CheckEquals(0, LReport.TotalRecords, 'TotalRecords should be 0');
    CheckEquals(0, LReport.Migrated, 'Migrated should be 0');
    CheckEquals(0, LReport.Failed, 'Failed should be 0');
    CheckEquals(0, LReport.Skipped, 'Skipped should be 0');
  finally
    FreeAndNil(LReport);
  end;
end;

procedure TTestMigrationReport.TestReport_AddTableReport_IncrementsTotals;
var
  LReport: TMigrationReport;
  LTable: TTableReport;
begin
  LReport := TMigrationReport.Create;
  try
    LTable := LReport.AddTable('SOURCE', 'TARGET');
    LTable.TotalRecords := 100;
    LTable.Migrated := 90;
    LTable.Failed := 5;
    LTable.Skipped := 5;

    CheckEquals(100, LReport.TotalRecords, 'TotalRecords should be 100');
    CheckEquals(90, LReport.Migrated, 'Migrated should be 90');
    CheckEquals(5, LReport.Failed, 'Failed should be 5');
    CheckEquals(5, LReport.Skipped, 'Skipped should be 5');
  finally
    FreeAndNil(LReport);
  end;
end;

procedure TTestMigrationReport.TestReport_AddError_IncrementsFailedCount;
var
  LReport: TMigrationReport;
  LTable: TTableReport;
  LError: TMigrationError;
begin
  LReport := TMigrationReport.Create;
  try
    LTable := LReport.AddTable('SOURCE', 'TARGET');
    LError.SourceTable := 'SOURCE';
    LError.RecordIndex := 1;
    LError.FieldName := 'NAME';
    LError.ErrorMessage := 'Invalid value';
    LError.OriginalValue := 'test';
    LTable.AddError(LError);

    CheckEquals(1, Length(LReport.Errors), 'Should have 1 error');
    CheckEquals('NAME', LReport.Errors[0].FieldName, 'FieldName should match');
  finally
    FreeAndNil(LReport);
  end;
end;

procedure TTestMigrationReport.TestReport_ToJSON_ContainsAllFields;
var
  LReport: TMigrationReport;
  LTable: TTableReport;
  LJSON: TJSONObject;
begin
  LReport := TMigrationReport.Create;
  try
    LReport.MarkStart;
    LTable := LReport.AddTable('SRC', 'TGT');
    LTable.TotalRecords := 50;
    LTable.Migrated := 45;
    LTable.Failed := 3;
    LTable.Skipped := 2;
    LReport.MarkEnd;

    LJSON := LReport.ToJSON;
    try
      CheckNotNull(LJSON, 'JSON should not be nil');
      CheckTrue(LJSON.GetValue('total_records') <> nil, 'Should have total_records');
      CheckTrue(LJSON.GetValue('migrated') <> nil, 'Should have migrated');
      CheckTrue(LJSON.GetValue('failed') <> nil, 'Should have failed');
      CheckTrue(LJSON.GetValue('skipped') <> nil, 'Should have skipped');
      CheckTrue(LJSON.GetValue('duration_ms') <> nil, 'Should have duration_ms');
      CheckTrue(LJSON.GetValue('tables') <> nil, 'Should have tables');
    finally
      FreeAndNil(LJSON);
    end;
  finally
    FreeAndNil(LReport);
  end;
end;

procedure TTestMigrationReport.TestReport_ToCSV_ContainsHeaders;
var
  LReport: TMigrationReport;
  LCSV: String;
begin
  LReport := TMigrationReport.Create;
  try
    LReport.AddTable('SRC', 'TGT');
    LCSV := LReport.ToCSV;
    CheckTrue(Pos('source_table', LCSV) > 0, 'CSV should contain source_table header');
    CheckTrue(Pos('target_table', LCSV) > 0, 'CSV should contain target_table header');
    CheckTrue(Pos('total_records', LCSV) > 0, 'CSV should contain total_records header');
    CheckTrue(Pos('migrated', LCSV) > 0, 'CSV should contain migrated header');
    CheckTrue(Pos('failed', LCSV) > 0, 'CSV should contain failed header');
    CheckTrue(Pos('skipped', LCSV) > 0, 'CSV should contain skipped header');
  finally
    FreeAndNil(LReport);
  end;
end;

procedure TTestMigrationReport.TestReport_Duration_ReturnsPositive;
var
  LReport: TMigrationReport;
begin
  LReport := TMigrationReport.Create;
  try
    LReport.MarkStart;
    Sleep(10);
    LReport.MarkEnd;
    CheckTrue(LReport.DurationMs >= 0, 'Duration should be >= 0');
  finally
    FreeAndNil(LReport);
  end;
end;

{ TTestFieldTransform }

procedure TTestFieldTransform.TestUpper_ShouldConvertToUpperCase;
var
  LFunc: TFieldTransformFunc;
begin
  LFunc := TFieldTransform.Upper;
  CheckEquals('HELLO', VarToStr(LFunc('hello')), 'Should convert to uppercase');
end;

procedure TTestFieldTransform.TestLower_ShouldConvertToLowerCase;
var
  LFunc: TFieldTransformFunc;
begin
  LFunc := TFieldTransform.Lower;
  CheckEquals('hello', VarToStr(LFunc('HELLO')), 'Should convert to lowercase');
end;

procedure TTestFieldTransform.TestTrim_ShouldRemoveSpaces;
var
  LFunc: TFieldTransformFunc;
begin
  LFunc := TFieldTransform.Trim;
  CheckEquals('hello', VarToStr(LFunc('  hello  ')), 'Should trim spaces');
end;

procedure TTestFieldTransform.TestReplace_ShouldReplaceSubstring;
var
  LFunc: TFieldTransformFunc;
begin
  LFunc := TFieldTransform.Replace('world', 'delphi');
  CheckEquals('hello delphi', VarToStr(LFunc('hello world')), 'Should replace substring');
end;

procedure TTestFieldTransform.TestCustom_ShouldApplyCustomFunc;
var
  LFunc: TFieldTransformFunc;
begin
  LFunc := TFieldTransform.Custom(
    function(aValue: Variant): Variant
    begin
      Result := VarToStr(aValue) + '!';
    end
  );
  CheckEquals('test!', VarToStr(LFunc('test')), 'Should apply custom function');
end;

procedure TTestFieldTransform.TestDateFormat_ShouldConvertFormat;
var
  LFunc: TFieldTransformFunc;
  LResult: String;
begin
  LFunc := TFieldTransform.DateFormat('yyyy-mm-dd', 'dd/mm/yyyy');
  LResult := VarToStr(LFunc('2026-03-10'));
  CheckEquals('10/03/2026', LResult, 'Should convert date format');
end;

procedure TTestFieldTransform.TestSplit_ShouldReturnPart;
var
  LFunc: TFieldTransformFunc;
begin
  LFunc := TFieldTransform.Split(',', 1);
  CheckEquals('world', VarToStr(LFunc('hello,world,test')), 'Should return second part');
end;

{ TTestFieldMap }

procedure TTestFieldMap.TestField_ShouldAddMapping;
var
  LMigration: TSimpleDataMigration;
  LMap: TFieldMap;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMap := LMigration.Map('SRC', 'TGT');
    LMap.Field('ID', 'ID_TARGET');
    CheckEquals(1, LMap.MappingCount, 'Should have 1 mapping');
    CheckTrue(LMap.Mappings[0].MappingType = fmtDirect, 'Should be direct mapping');
  finally
    FreeAndNil(LMigration);
  end;
end;

procedure TTestFieldMap.TestTransform_ShouldAddMappingWithTransform;
var
  LMigration: TSimpleDataMigration;
  LMap: TFieldMap;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMap := LMigration.Map('SRC', 'TGT');
    LMap.Transform('NAME', 'NAME_UPPER', TFieldTransform.Upper);
    CheckEquals(1, LMap.MappingCount, 'Should have 1 mapping');
    CheckTrue(LMap.Mappings[0].MappingType = fmtTransform, 'Should be transform mapping');
  finally
    FreeAndNil(LMigration);
  end;
end;

procedure TTestFieldMap.TestDefaultValue_ShouldAddDefault;
var
  LMigration: TSimpleDataMigration;
  LMap: TFieldMap;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMap := LMigration.Map('SRC', 'TGT');
    LMap.DefaultValue('STATUS', 'ACTIVE');
    CheckEquals(1, LMap.MappingCount, 'Should have 1 mapping');
    CheckTrue(LMap.Mappings[0].MappingType = fmtDefault, 'Should be default mapping');
    CheckEquals('ACTIVE', VarToStr(LMap.Mappings[0].DefaultValue), 'Default value should match');
  finally
    FreeAndNil(LMigration);
  end;
end;

procedure TTestFieldMap.TestLookup_ShouldAddLookupMapping;
var
  LMigration: TSimpleDataMigration;
  LMap: TFieldMap;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMap := LMigration.Map('SRC', 'TGT');
    LMap.Lookup('CITY_CODE', 'CITY_NAME', 'CITIES', 'CODE', 'NAME');
    CheckEquals(1, LMap.MappingCount, 'Should have 1 mapping');
    CheckTrue(LMap.Mappings[0].MappingType = fmtLookup, 'Should be lookup mapping');
    CheckEquals('CITIES', LMap.Mappings[0].LookupTable, 'LookupTable should match');
  finally
    FreeAndNil(LMigration);
  end;
end;

procedure TTestFieldMap.TestIgnore_ShouldAddIgnoreMapping;
var
  LMigration: TSimpleDataMigration;
  LMap: TFieldMap;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMap := LMigration.Map('SRC', 'TGT');
    LMap.Ignore('TEMP_FIELD');
    CheckEquals(1, LMap.MappingCount, 'Should have 1 mapping');
    CheckTrue(LMap.Mappings[0].MappingType = fmtIgnore, 'Should be ignore mapping');
  finally
    FreeAndNil(LMigration);
  end;
end;

procedure TTestFieldMap.TestEnd_ShouldReturnMigration;
var
  LMigration: TSimpleDataMigration;
  LReturned: TSimpleDataMigration;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LReturned := LMigration.Map('SRC', 'TGT').&End;
    CheckTrue(LMigration = LReturned, 'End should return the migration instance');
  finally
    FreeAndNil(LMigration);
  end;
end;

procedure TTestFieldMap.TestMultipleMappings_ShouldKeepAll;
var
  LMigration: TSimpleDataMigration;
  LMap: TFieldMap;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMap := LMigration.Map('SRC', 'TGT');
    LMap
      .Field('ID', 'ID')
      .Field('NAME', 'NOME')
      .Ignore('TEMP')
      .DefaultValue('STATUS', 1);
    CheckEquals(4, LMap.MappingCount, 'Should have 4 mappings');
  finally
    FreeAndNil(LMigration);
  end;
end;

{ TTestSimpleDataMigration }

procedure TTestSimpleDataMigration.TestCreate_ShouldInitialize;
var
  LMigration: TSimpleDataMigration;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    CheckEquals(0, LMigration.MapCount, 'MapCount should be 0');
    CheckEquals(1000, LMigration.GetBatchSize, 'BatchSize should default to 1000');
    CheckFalse(LMigration.GetValidate, 'Validate should default to False');
  finally
    FreeAndNil(LMigration);
  end;
end;

procedure TTestSimpleDataMigration.TestMap_ShouldReturnFieldMap;
var
  LMigration: TSimpleDataMigration;
  LMap: TFieldMap;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMap := LMigration.Map('CUSTOMERS', 'CLIENTES');
    CheckNotNull(LMap, 'Map should return TFieldMap');
    CheckEquals('CUSTOMERS', LMap.SourceTable, 'SourceTable should match');
    CheckEquals('CLIENTES', LMap.TargetTable, 'TargetTable should match');
  finally
    FreeAndNil(LMigration);
  end;
end;

procedure TTestSimpleDataMigration.TestMap_MultipleTables_ShouldKeepAll;
var
  LMigration: TSimpleDataMigration;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMigration.Map('TABLE1', 'TARGET1');
    LMigration.Map('TABLE2', 'TARGET2');
    LMigration.Map('TABLE3', 'TARGET3');
    CheckEquals(3, LMigration.MapCount, 'Should have 3 maps');
  finally
    FreeAndNil(LMigration);
  end;
end;

procedure TTestSimpleDataMigration.TestBatchSize_ShouldSetValue;
var
  LMigration: TSimpleDataMigration;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMigration.BatchSize(500);
    CheckEquals(500, LMigration.GetBatchSize, 'BatchSize should be 500');
  finally
    FreeAndNil(LMigration);
  end;
end;

procedure TTestSimpleDataMigration.TestValidate_ShouldSetFlag;
var
  LMigration: TSimpleDataMigration;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMigration.Validate(True);
    CheckTrue(LMigration.GetValidate, 'Validate should be True');
  finally
    FreeAndNil(LMigration);
  end;
end;

procedure TTestSimpleDataMigration.TestFluentChaining_ShouldWork;
var
  LMigration: TSimpleDataMigration;
begin
  LMigration := TSimpleDataMigration.Create;
  try
    LMigration
      .BatchSize(250)
      .Validate(True)
      .Map('SRC', 'TGT')
        .Field('ID', 'ID')
        .Field('NAME', 'NOME')
      .&End
      .Map('SRC2', 'TGT2')
        .Field('CODE', 'CODIGO')
      .&End;

    CheckEquals(2, LMigration.MapCount, 'Should have 2 maps');
    CheckEquals(250, LMigration.GetBatchSize, 'BatchSize should be 250');
    CheckTrue(LMigration.GetValidate, 'Validate should be True');
  finally
    FreeAndNil(LMigration);
  end;
end;

procedure TTestSimpleDataMigration.TestSaveToJSON_ShouldCreateFile;
var
  LMigration: TSimpleDataMigration;
  LFilePath: String;
begin
  LFilePath := IncludeTrailingPathDelimiter(GetCurrentDir) + 'test_migration_save.json';
  LMigration := TSimpleDataMigration.Create;
  try
    LMigration
      .BatchSize(500)
      .Validate(True)
      .Map('CUSTOMERS', 'CLIENTES')
        .Field('ID', 'ID_CLIENTE')
        .Field('NAME', 'NOME')
      .&End
      .SaveToJSON(LFilePath);

    CheckTrue(FileExists(LFilePath), 'JSON file should be created');
  finally
    FreeAndNil(LMigration);
    if FileExists(LFilePath) then
      DeleteFile(LFilePath);
  end;
end;

procedure TTestSimpleDataMigration.TestLoadFromJSON_ShouldRestoreMappings;
var
  LMigration: TSimpleDataMigration;
  LLoaded: TSimpleDataMigration;
  LFilePath: String;
begin
  LFilePath := IncludeTrailingPathDelimiter(GetCurrentDir) + 'test_migration_load.json';
  LMigration := TSimpleDataMigration.Create;
  try
    LMigration
      .BatchSize(250)
      .Validate(True)
      .Map('CUSTOMERS', 'CLIENTES')
        .Field('ID', 'ID_CLIENTE')
        .DefaultValue('STATUS', 'ACTIVE')
      .&End
      .SaveToJSON(LFilePath);

    LLoaded := TSimpleDataMigration.Create;
    try
      LLoaded.LoadFromJSON(LFilePath);
      CheckEquals(250, LLoaded.GetBatchSize, 'BatchSize should be restored');
      CheckTrue(LLoaded.GetValidate, 'Validate should be restored');
      CheckEquals(1, LLoaded.MapCount, 'Should have 1 map');
    finally
      FreeAndNil(LLoaded);
    end;
  finally
    FreeAndNil(LMigration);
    if FileExists(LFilePath) then
      DeleteFile(LFilePath);
  end;
end;

{ TTestCSVHelper }

procedure TTestCSVHelper.TestReadCSV_ShouldReturnHeaders;
var
  LWriter: TCSVWriter;
  LReader: TCSVReader;
  LFilePath: String;
begin
  LFilePath := IncludeTrailingPathDelimiter(GetCurrentDir) + 'test_csv_headers.csv';
  LWriter := TCSVWriter.Create(LFilePath, ['ID', 'NAME', 'AGE']);
  try
    LWriter.WriteRow(['1', 'Alice', '30']);
    LWriter.Flush;
  finally
    FreeAndNil(LWriter);
  end;

  LReader := TCSVReader.Create(LFilePath);
  try
    CheckEquals(3, Length(LReader.Headers), 'Should have 3 headers');
    CheckEquals('ID', LReader.Headers[0], 'First header should be ID');
    CheckEquals('NAME', LReader.Headers[1], 'Second header should be NAME');
    CheckEquals('AGE', LReader.Headers[2], 'Third header should be AGE');
  finally
    FreeAndNil(LReader);
    if FileExists(LFilePath) then
      DeleteFile(LFilePath);
  end;
end;

procedure TTestCSVHelper.TestReadCSV_ShouldReturnRows;
var
  LWriter: TCSVWriter;
  LReader: TCSVReader;
  LFilePath: String;
begin
  LFilePath := IncludeTrailingPathDelimiter(GetCurrentDir) + 'test_csv_rows.csv';
  LWriter := TCSVWriter.Create(LFilePath, ['ID', 'NAME']);
  try
    LWriter.WriteRow(['1', 'Alice']);
    LWriter.WriteRow(['2', 'Bob']);
    LWriter.Flush;
  finally
    FreeAndNil(LWriter);
  end;

  LReader := TCSVReader.Create(LFilePath);
  try
    CheckTrue(LReader.Next, 'Should have first row');
    CheckEquals('Alice', LReader.ValueByHeader('NAME'), 'First row NAME should be Alice');
    CheckTrue(LReader.Next, 'Should have second row');
    CheckEquals('Bob', LReader.ValueByHeader('NAME'), 'Second row NAME should be Bob');
    CheckFalse(LReader.Next, 'Should not have third row');
  finally
    FreeAndNil(LReader);
    if FileExists(LFilePath) then
      DeleteFile(LFilePath);
  end;
end;

procedure TTestCSVHelper.TestWriteCSV_ShouldCreateFile;
var
  LWriter: TCSVWriter;
  LFilePath: String;
begin
  LFilePath := IncludeTrailingPathDelimiter(GetCurrentDir) + 'test_csv_write.csv';
  LWriter := TCSVWriter.Create(LFilePath, ['COL1', 'COL2']);
  try
    LWriter.WriteRow(['val1', 'val2']);
    LWriter.Flush;
    CheckTrue(FileExists(LFilePath), 'CSV file should be created');
  finally
    FreeAndNil(LWriter);
    if FileExists(LFilePath) then
      DeleteFile(LFilePath);
  end;
end;

procedure TTestCSVHelper.TestReadCSV_EmptyFile_ShouldReturnEmptyList;
var
  LFilePath: String;
  LSL: TStringList;
  LReader: TCSVReader;
begin
  LFilePath := IncludeTrailingPathDelimiter(GetCurrentDir) + 'test_csv_empty.csv';
  LSL := TStringList.Create;
  try
    LSL.SaveToFile(LFilePath);
  finally
    FreeAndNil(LSL);
  end;

  LReader := TCSVReader.Create(LFilePath);
  try
    CheckEquals(0, Length(LReader.Headers), 'Should have no headers');
    CheckFalse(LReader.Next, 'Should have no rows');
  finally
    FreeAndNil(LReader);
    if FileExists(LFilePath) then
      DeleteFile(LFilePath);
  end;
end;

initialization
  RegisterTest('DataMigration', TTestMigrationReport.Suite);
  RegisterTest('DataMigration', TTestFieldTransform.Suite);
  RegisterTest('DataMigration', TTestFieldMap.Suite);
  RegisterTest('DataMigration', TTestSimpleDataMigration.Suite);
  RegisterTest('DataMigration', TTestCSVHelper.Suite);

end.
