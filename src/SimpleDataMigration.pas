unit SimpleDataMigration;

interface

uses
  SimpleTypes, SimpleInterface,
  System.SysUtils, System.Classes, System.JSON,
  System.Generics.Collections, System.DateUtils, System.Variants;

type
  TSimpleDataMigration = class;

  TTableReport = class
  private
    FSourceTable: String;
    FTargetTable: String;
    FTotalRecords: Integer;
    FMigrated: Integer;
    FFailed: Integer;
    FSkipped: Integer;
    FErrors: TList<TMigrationError>;
  public
    constructor Create(const aSourceTable, aTargetTable: String);
    destructor Destroy; override;
    procedure AddError(aError: TMigrationError);
    function Errors: TArray<TMigrationError>;
    property SourceTable: String read FSourceTable write FSourceTable;
    property TargetTable: String read FTargetTable write FTargetTable;
    property TotalRecords: Integer read FTotalRecords write FTotalRecords;
    property Migrated: Integer read FMigrated write FMigrated;
    property Failed: Integer read FFailed write FFailed;
    property Skipped: Integer read FSkipped write FSkipped;
  end;

  TMigrationReport = class
  private
    FTables: TObjectList<TTableReport>;
    FStartTime: TDateTime;
    FEndTime: TDateTime;
  public
    constructor Create;
    destructor Destroy; override;
    function AddTable(const aSourceTable, aTargetTable: String): TTableReport;
    function TotalRecords: Integer;
    function Migrated: Integer;
    function Failed: Integer;
    function Skipped: Integer;
    function Errors: TArray<TMigrationError>;
    function DurationMs: Int64;
    procedure MarkStart;
    procedure MarkEnd;
    function ToJSON: TJSONObject;
    function ToCSV: String;
    function Tables: TObjectList<TTableReport>;
  end;

  TFieldTransform = class
  public
    class function Upper: TFieldTransformFunc;
    class function Lower: TFieldTransformFunc;
    class function Trim: TFieldTransformFunc;
    class function Replace(const aOld, aNew: String): TFieldTransformFunc;
    class function Custom(aFunc: TFieldTransformFunc): TFieldTransformFunc;
    class function DateFormat(const aFromFormat, aToFormat: String): TFieldTransformFunc;
    class function Split(const aDelimiter: Char; aIndex: Integer): TFieldTransformFunc;
    class function Concat(const aFields: TArray<String>; const aDelimiter: String): TFieldTransformFunc;
  end;

  TFieldMappingType = (fmtDirect, fmtTransform, fmtDefault, fmtLookup, fmtIgnore);

  TFieldMapping = class
  private
    FSourceField: String;
    FTargetField: String;
    FMappingType: TFieldMappingType;
    FTransformFunc: TFieldTransformFunc;
    FDefaultValue: Variant;
    FLookupTable: String;
    FLookupField: String;
    FReturnField: String;
  public
    property SourceField: String read FSourceField write FSourceField;
    property TargetField: String read FTargetField write FTargetField;
    property MappingType: TFieldMappingType read FMappingType write FMappingType;
    property TransformFunc: TFieldTransformFunc read FTransformFunc write FTransformFunc;
    property DefaultValue: Variant read FDefaultValue write FDefaultValue;
    property LookupTable: String read FLookupTable write FLookupTable;
    property LookupField: String read FLookupField write FLookupField;
    property ReturnField: String read FReturnField write FReturnField;
  end;

  TFieldMap = class
  private
    FMigration: TSimpleDataMigration;
    FSourceTable: String;
    FTargetTable: String;
    FMappings: TObjectList<TFieldMapping>;
  public
    constructor Create(const aSourceTable, aTargetTable: String; aMigration: TSimpleDataMigration);
    destructor Destroy; override;
    function Field(const aSource, aTarget: String): TFieldMap;
    function Transform(const aSource, aTarget: String; aTransform: TFieldTransformFunc): TFieldMap;
    function DefaultValue(const aTarget: String; aValue: Variant): TFieldMap;
    function Lookup(const aSource, aTarget, aLookupTable, aLookupField, aReturnField: String): TFieldMap;
    function Ignore(const aSource: String): TFieldMap;
    function &End: TSimpleDataMigration;
    function MappingCount: Integer;
    function Mappings: TObjectList<TFieldMapping>;
    property SourceTable: String read FSourceTable;
    property TargetTable: String read FTargetTable;
  end;

  TCSVReader = class
  private
    FLines: TStringList;
    FHeaders: TArray<String>;
    FCurrentIndex: Integer;
    FDelimiter: Char;
    function SplitLine(const aLine: String): TArray<String>;
  public
    constructor Create(const aFilePath: String; aDelimiter: Char = ',');
    destructor Destroy; override;
    function Next: Boolean;
    function CurrentRow: TArray<String>;
    function ValueByHeader(const aHeader: String): String;
    property Headers: TArray<String> read FHeaders;
  end;

  TCSVWriter = class
  private
    FSL: TStringList;
    FFilePath: String;
    FHeaders: TArray<String>;
    FDelimiter: Char;
  public
    constructor Create(const aFilePath: String; const aHeaders: TArray<String>; aDelimiter: Char = ',');
    destructor Destroy; override;
    procedure WriteRow(const aValues: TArray<String>);
    procedure Flush;
  end;

  TSimpleDataMigration = class
  private
    FSourceQuery: iSimpleQuery;
    FTargetQuery: iSimpleQuery;
    FSourceFile: String;
    FTargetFile: String;
    FSourceFormat: TMigrationFormat;
    FTargetFormat: TMigrationFormat;
    FMaps: TObjectList<TFieldMap>;
    FBatchSize: Integer;
    FValidate: Boolean;
    FOnProgress: TSimpleMigrationProgress;
    FOnError: TSimpleMigrationErrorCallback;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: TSimpleDataMigration;
    function Source(aQuery: iSimpleQuery): TSimpleDataMigration; overload;
    function Source(const aFilePath: String; aFormat: TMigrationFormat): TSimpleDataMigration; overload;
    function Target(aQuery: iSimpleQuery): TSimpleDataMigration; overload;
    function Target(const aFilePath: String; aFormat: TMigrationFormat): TSimpleDataMigration; overload;
    function Map(const aSourceTable, aTargetTable: String): TFieldMap;
    function BatchSize(aSize: Integer): TSimpleDataMigration;
    function Validate(aEnabled: Boolean = True): TSimpleDataMigration;
    function OnProgress(aCallback: TSimpleMigrationProgress): TSimpleDataMigration;
    function OnError(aCallback: TSimpleMigrationErrorCallback): TSimpleDataMigration;
    function Execute: TMigrationReport;
    function SaveToJSON(const aFilePath: String): TSimpleDataMigration;
    function LoadFromJSON(const aFilePath: String): TSimpleDataMigration;
    function MapCount: Integer;
    function GetBatchSize: Integer;
    function GetValidate: Boolean;
  end;

implementation

{ TTableReport }

constructor TTableReport.Create(const aSourceTable, aTargetTable: String);
begin
  inherited Create;
  FSourceTable := aSourceTable;
  FTargetTable := aTargetTable;
  FTotalRecords := 0;
  FMigrated := 0;
  FFailed := 0;
  FSkipped := 0;
  FErrors := TList<TMigrationError>.Create;
end;

destructor TTableReport.Destroy;
begin
  FreeAndNil(FErrors);
  inherited;
end;

procedure TTableReport.AddError(aError: TMigrationError);
begin
  FErrors.Add(aError);
end;

function TTableReport.Errors: TArray<TMigrationError>;
begin
  Result := FErrors.ToArray;
end;

{ TMigrationReport }

constructor TMigrationReport.Create;
begin
  inherited Create;
  FTables := TObjectList<TTableReport>.Create(True);
  FStartTime := 0;
  FEndTime := 0;
end;

destructor TMigrationReport.Destroy;
begin
  FreeAndNil(FTables);
  inherited;
end;

function TMigrationReport.AddTable(const aSourceTable, aTargetTable: String): TTableReport;
begin
  Result := TTableReport.Create(aSourceTable, aTargetTable);
  FTables.Add(Result);
end;

function TMigrationReport.TotalRecords: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FTables.Count - 1 do
    Result := Result + FTables[I].TotalRecords;
end;

function TMigrationReport.Migrated: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FTables.Count - 1 do
    Result := Result + FTables[I].Migrated;
end;

function TMigrationReport.Failed: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FTables.Count - 1 do
    Result := Result + FTables[I].Failed;
end;

function TMigrationReport.Skipped: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FTables.Count - 1 do
    Result := Result + FTables[I].Skipped;
end;

function TMigrationReport.Errors: TArray<TMigrationError>;
var
  LList: TList<TMigrationError>;
  I: Integer;
  LErrors: TArray<TMigrationError>;
  LError: TMigrationError;
begin
  LList := TList<TMigrationError>.Create;
  try
    for I := 0 to FTables.Count - 1 do
    begin
      LErrors := FTables[I].Errors;
      for LError in LErrors do
        LList.Add(LError);
    end;
    Result := LList.ToArray;
  finally
    FreeAndNil(LList);
  end;
end;

function TMigrationReport.DurationMs: Int64;
begin
  Result := MilliSecondsBetween(FEndTime, FStartTime);
end;

procedure TMigrationReport.MarkStart;
begin
  FStartTime := Now;
end;

procedure TMigrationReport.MarkEnd;
begin
  FEndTime := Now;
end;

function TMigrationReport.ToJSON: TJSONObject;
var
  LRoot: TJSONObject;
  LTablesArr: TJSONArray;
  LTableObj: TJSONObject;
  LErrorsArr: TJSONArray;
  LErrorObj: TJSONObject;
  I: Integer;
  LErrors: TArray<TMigrationError>;
  LError: TMigrationError;
begin
  LRoot := TJSONObject.Create;
  LRoot.AddPair('total_records', TJSONNumber.Create(TotalRecords));
  LRoot.AddPair('migrated', TJSONNumber.Create(Migrated));
  LRoot.AddPair('failed', TJSONNumber.Create(Failed));
  LRoot.AddPair('skipped', TJSONNumber.Create(Skipped));
  LRoot.AddPair('duration_ms', TJSONNumber.Create(DurationMs));

  LTablesArr := TJSONArray.Create;
  for I := 0 to FTables.Count - 1 do
  begin
    LTableObj := TJSONObject.Create;
    LTableObj.AddPair('source_table', FTables[I].SourceTable);
    LTableObj.AddPair('target_table', FTables[I].TargetTable);
    LTableObj.AddPair('total_records', TJSONNumber.Create(FTables[I].TotalRecords));
    LTableObj.AddPair('migrated', TJSONNumber.Create(FTables[I].Migrated));
    LTableObj.AddPair('failed', TJSONNumber.Create(FTables[I].Failed));
    LTableObj.AddPair('skipped', TJSONNumber.Create(FTables[I].Skipped));

    LErrorsArr := TJSONArray.Create;
    LErrors := FTables[I].Errors;
    for LError in LErrors do
    begin
      LErrorObj := TJSONObject.Create;
      LErrorObj.AddPair('source_table', LError.SourceTable);
      LErrorObj.AddPair('record_index', TJSONNumber.Create(LError.RecordIndex));
      LErrorObj.AddPair('field_name', LError.FieldName);
      LErrorObj.AddPair('error_message', LError.ErrorMessage);
      LErrorsArr.Add(LErrorObj);
    end;
    LTableObj.AddPair('errors', LErrorsArr);

    LTablesArr.Add(LTableObj);
  end;
  LRoot.AddPair('tables', LTablesArr);

  Result := LRoot;
end;

function TMigrationReport.ToCSV: String;
var
  LSL: TStringList;
  I: Integer;
begin
  LSL := TStringList.Create;
  try
    LSL.Add('source_table,target_table,total_records,migrated,failed,skipped');
    for I := 0 to FTables.Count - 1 do
      LSL.Add(SysUtils.Format('%s,%s,%d,%d,%d,%d', [
        FTables[I].SourceTable,
        FTables[I].TargetTable,
        FTables[I].TotalRecords,
        FTables[I].Migrated,
        FTables[I].Failed,
        FTables[I].Skipped
      ]));
    Result := LSL.Text;
  finally
    FreeAndNil(LSL);
  end;
end;

function TMigrationReport.Tables: TObjectList<TTableReport>;
begin
  Result := FTables;
end;

{ TFieldTransform }

class function TFieldTransform.Upper: TFieldTransformFunc;
begin
  Result := function(aValue: Variant): Variant
    begin
      Result := AnsiUpperCase(VarToStr(aValue));
    end;
end;

class function TFieldTransform.Lower: TFieldTransformFunc;
begin
  Result := function(aValue: Variant): Variant
    begin
      Result := AnsiLowerCase(VarToStr(aValue));
    end;
end;

class function TFieldTransform.Trim: TFieldTransformFunc;
begin
  Result := function(aValue: Variant): Variant
    begin
      Result := System.SysUtils.Trim(VarToStr(aValue));
    end;
end;

class function TFieldTransform.Replace(const aOld, aNew: String): TFieldTransformFunc;
begin
  Result := function(aValue: Variant): Variant
    begin
      Result := StringReplace(VarToStr(aValue), aOld, aNew, [rfReplaceAll]);
    end;
end;

class function TFieldTransform.Custom(aFunc: TFieldTransformFunc): TFieldTransformFunc;
begin
  Result := aFunc;
end;

class function TFieldTransform.DateFormat(const aFromFormat, aToFormat: String): TFieldTransformFunc;
begin
  Result := function(aValue: Variant): Variant
    var
      LFS: TFormatSettings;
      LDate: TDateTime;
      LOutFS: TFormatSettings;
    begin
      LFS := TFormatSettings.Create;
      LFS.ShortDateFormat := aFromFormat;
      LFS.DateSeparator := aFromFormat[Pos(aFromFormat[3], aFromFormat)];

      LOutFS := TFormatSettings.Create;
      LOutFS.ShortDateFormat := aToFormat;
      if Pos('/', aToFormat) > 0 then
        LOutFS.DateSeparator := '/'
      else if Pos('-', aToFormat) > 0 then
        LOutFS.DateSeparator := '-'
      else if Pos('.', aToFormat) > 0 then
        LOutFS.DateSeparator := '.';

      LDate := StrToDate(VarToStr(aValue), LFS);
      Result := DateToStr(LDate, LOutFS);
    end;
end;

class function TFieldTransform.Split(const aDelimiter: Char; aIndex: Integer): TFieldTransformFunc;
begin
  Result := function(aValue: Variant): Variant
    var
      LSL: TStringList;
    begin
      LSL := TStringList.Create;
      try
        LSL.Delimiter := aDelimiter;
        LSL.StrictDelimiter := True;
        LSL.DelimitedText := VarToStr(aValue);
        if (aIndex >= 0) and (aIndex < LSL.Count) then
          Result := LSL[aIndex]
        else
          Result := '';
      finally
        FreeAndNil(LSL);
      end;
    end;
end;

class function TFieldTransform.Concat(const aFields: TArray<String>; const aDelimiter: String): TFieldTransformFunc;
begin
  Result := function(aValue: Variant): Variant
    begin
      Result := String.Join(aDelimiter, aFields);
    end;
end;

{ TFieldMap }

constructor TFieldMap.Create(const aSourceTable, aTargetTable: String; aMigration: TSimpleDataMigration);
begin
  inherited Create;
  FSourceTable := aSourceTable;
  FTargetTable := aTargetTable;
  FMigration := aMigration;
  FMappings := TObjectList<TFieldMapping>.Create(True);
end;

destructor TFieldMap.Destroy;
begin
  FreeAndNil(FMappings);
  inherited;
end;

function TFieldMap.Field(const aSource, aTarget: String): TFieldMap;
var
  LMapping: TFieldMapping;
begin
  LMapping := TFieldMapping.Create;
  LMapping.SourceField := aSource;
  LMapping.TargetField := aTarget;
  LMapping.MappingType := fmtDirect;
  FMappings.Add(LMapping);
  Result := Self;
end;

function TFieldMap.Transform(const aSource, aTarget: String; aTransform: TFieldTransformFunc): TFieldMap;
var
  LMapping: TFieldMapping;
begin
  LMapping := TFieldMapping.Create;
  LMapping.SourceField := aSource;
  LMapping.TargetField := aTarget;
  LMapping.MappingType := fmtTransform;
  LMapping.TransformFunc := aTransform;
  FMappings.Add(LMapping);
  Result := Self;
end;

function TFieldMap.DefaultValue(const aTarget: String; aValue: Variant): TFieldMap;
var
  LMapping: TFieldMapping;
begin
  LMapping := TFieldMapping.Create;
  LMapping.SourceField := '';
  LMapping.TargetField := aTarget;
  LMapping.MappingType := fmtDefault;
  LMapping.DefaultValue := aValue;
  FMappings.Add(LMapping);
  Result := Self;
end;

function TFieldMap.Lookup(const aSource, aTarget, aLookupTable, aLookupField, aReturnField: String): TFieldMap;
var
  LMapping: TFieldMapping;
begin
  LMapping := TFieldMapping.Create;
  LMapping.SourceField := aSource;
  LMapping.TargetField := aTarget;
  LMapping.MappingType := fmtLookup;
  LMapping.LookupTable := aLookupTable;
  LMapping.LookupField := aLookupField;
  LMapping.ReturnField := aReturnField;
  FMappings.Add(LMapping);
  Result := Self;
end;

function TFieldMap.Ignore(const aSource: String): TFieldMap;
var
  LMapping: TFieldMapping;
begin
  LMapping := TFieldMapping.Create;
  LMapping.SourceField := aSource;
  LMapping.TargetField := '';
  LMapping.MappingType := fmtIgnore;
  FMappings.Add(LMapping);
  Result := Self;
end;

function TFieldMap.&End: TSimpleDataMigration;
begin
  Result := FMigration;
end;

function TFieldMap.MappingCount: Integer;
begin
  Result := FMappings.Count;
end;

function TFieldMap.Mappings: TObjectList<TFieldMapping>;
begin
  Result := FMappings;
end;

{ TCSVReader }

constructor TCSVReader.Create(const aFilePath: String; aDelimiter: Char = ',');
begin
  inherited Create;
  FDelimiter := aDelimiter;
  FCurrentIndex := 0;
  FLines := TStringList.Create;
  FLines.LoadFromFile(aFilePath);
  if FLines.Count > 0 then
    FHeaders := SplitLine(FLines[0])
  else
    SetLength(FHeaders, 0);
end;

destructor TCSVReader.Destroy;
begin
  FreeAndNil(FLines);
  inherited;
end;

function TCSVReader.SplitLine(const aLine: String): TArray<String>;
var
  LSL: TStringList;
  I: Integer;
begin
  LSL := TStringList.Create;
  try
    LSL.Delimiter := FDelimiter;
    LSL.StrictDelimiter := True;
    LSL.DelimitedText := aLine;
    SetLength(Result, LSL.Count);
    for I := 0 to LSL.Count - 1 do
      Result[I] := LSL[I];
  finally
    FreeAndNil(LSL);
  end;
end;

function TCSVReader.Next: Boolean;
begin
  Inc(FCurrentIndex);
  Result := FCurrentIndex < FLines.Count;
end;

function TCSVReader.CurrentRow: TArray<String>;
begin
  if (FCurrentIndex > 0) and (FCurrentIndex < FLines.Count) then
    Result := SplitLine(FLines[FCurrentIndex])
  else
    SetLength(Result, 0);
end;

function TCSVReader.ValueByHeader(const aHeader: String): String;
var
  I: Integer;
  LRow: TArray<String>;
begin
  Result := '';
  LRow := CurrentRow;
  for I := 0 to Length(FHeaders) - 1 do
  begin
    if SameText(FHeaders[I], aHeader) then
    begin
      if I < Length(LRow) then
        Result := LRow[I];
      Break;
    end;
  end;
end;

{ TCSVWriter }

constructor TCSVWriter.Create(const aFilePath: String; const aHeaders: TArray<String>; aDelimiter: Char = ',');
begin
  inherited Create;
  FFilePath := aFilePath;
  FHeaders := aHeaders;
  FDelimiter := aDelimiter;
  FSL := TStringList.Create;
  FSL.Add(String.Join(FDelimiter, FHeaders));
end;

destructor TCSVWriter.Destroy;
begin
  FreeAndNil(FSL);
  inherited;
end;

procedure TCSVWriter.WriteRow(const aValues: TArray<String>);
begin
  FSL.Add(String.Join(FDelimiter, aValues));
end;

procedure TCSVWriter.Flush;
begin
  FSL.SaveToFile(FFilePath);
end;

{ TSimpleDataMigration }

constructor TSimpleDataMigration.Create;
begin
  inherited Create;
  FMaps := TObjectList<TFieldMap>.Create(True);
  FBatchSize := 1000;
  FValidate := False;
  FSourceFile := '';
  FTargetFile := '';
end;

destructor TSimpleDataMigration.Destroy;
begin
  FreeAndNil(FMaps);
  inherited;
end;

class function TSimpleDataMigration.New: TSimpleDataMigration;
begin
  Result := Self.Create;
end;

function TSimpleDataMigration.Source(aQuery: iSimpleQuery): TSimpleDataMigration;
begin
  FSourceQuery := aQuery;
  Result := Self;
end;

function TSimpleDataMigration.Source(const aFilePath: String; aFormat: TMigrationFormat): TSimpleDataMigration;
begin
  FSourceFile := aFilePath;
  FSourceFormat := aFormat;
  Result := Self;
end;

function TSimpleDataMigration.Target(aQuery: iSimpleQuery): TSimpleDataMigration;
begin
  FTargetQuery := aQuery;
  Result := Self;
end;

function TSimpleDataMigration.Target(const aFilePath: String; aFormat: TMigrationFormat): TSimpleDataMigration;
begin
  FTargetFile := aFilePath;
  FTargetFormat := aFormat;
  Result := Self;
end;

function TSimpleDataMigration.Map(const aSourceTable, aTargetTable: String): TFieldMap;
begin
  Result := TFieldMap.Create(aSourceTable, aTargetTable, Self);
  FMaps.Add(Result);
end;

function TSimpleDataMigration.BatchSize(aSize: Integer): TSimpleDataMigration;
begin
  FBatchSize := aSize;
  Result := Self;
end;

function TSimpleDataMigration.Validate(aEnabled: Boolean = True): TSimpleDataMigration;
begin
  FValidate := aEnabled;
  Result := Self;
end;

function TSimpleDataMigration.OnProgress(aCallback: TSimpleMigrationProgress): TSimpleDataMigration;
begin
  FOnProgress := aCallback;
  Result := Self;
end;

function TSimpleDataMigration.OnError(aCallback: TSimpleMigrationErrorCallback): TSimpleDataMigration;
begin
  FOnError := aCallback;
  Result := Self;
end;

function TSimpleDataMigration.Execute: TMigrationReport;
begin
  Result := TMigrationReport.Create;
  Result.MarkStart;
  Result.MarkEnd;
end;

function TSimpleDataMigration.SaveToJSON(const aFilePath: String): TSimpleDataMigration;
var
  LRoot: TJSONObject;
  LMapsArr: TJSONArray;
  LMapObj: TJSONObject;
  LMappingsArr: TJSONArray;
  LMappingObj: TJSONObject;
  I, J: Integer;
  LSL: TStringList;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('batch_size', TJSONNumber.Create(FBatchSize));
    LRoot.AddPair('validate', TJSONBool.Create(FValidate));

    LMapsArr := TJSONArray.Create;
    for I := 0 to FMaps.Count - 1 do
    begin
      LMapObj := TJSONObject.Create;
      LMapObj.AddPair('source_table', FMaps[I].SourceTable);
      LMapObj.AddPair('target_table', FMaps[I].TargetTable);

      LMappingsArr := TJSONArray.Create;
      for J := 0 to FMaps[I].Mappings.Count - 1 do
      begin
        LMappingObj := TJSONObject.Create;
        LMappingObj.AddPair('source_field', FMaps[I].Mappings[J].SourceField);
        LMappingObj.AddPair('target_field', FMaps[I].Mappings[J].TargetField);
        LMappingObj.AddPair('type', TJSONNumber.Create(Ord(FMaps[I].Mappings[J].MappingType)));
        if FMaps[I].Mappings[J].MappingType = fmtDefault then
          LMappingObj.AddPair('default_value', VarToStr(FMaps[I].Mappings[J].DefaultValue));
        if FMaps[I].Mappings[J].MappingType = fmtLookup then
        begin
          LMappingObj.AddPair('lookup_table', FMaps[I].Mappings[J].LookupTable);
          LMappingObj.AddPair('lookup_field', FMaps[I].Mappings[J].LookupField);
          LMappingObj.AddPair('return_field', FMaps[I].Mappings[J].ReturnField);
        end;
        LMappingsArr.Add(LMappingObj);
      end;
      LMapObj.AddPair('mappings', LMappingsArr);
      LMapsArr.Add(LMapObj);
    end;
    LRoot.AddPair('maps', LMapsArr);

    LSL := TStringList.Create;
    try
      LSL.Text := LRoot.Format;
      LSL.SaveToFile(aFilePath);
    finally
      FreeAndNil(LSL);
    end;
  finally
    FreeAndNil(LRoot);
  end;
  Result := Self;
end;

function TSimpleDataMigration.LoadFromJSON(const aFilePath: String): TSimpleDataMigration;
var
  LSL: TStringList;
  LRoot: TJSONObject;
  LMapsArr: TJSONArray;
  LMapObj: TJSONObject;
  LMappingsArr: TJSONArray;
  LMappingObj: TJSONObject;
  I, J: Integer;
  LFieldMap: TFieldMap;
  LMapping: TFieldMapping;
  LMappingType: Integer;
begin
  LSL := TStringList.Create;
  try
    LSL.LoadFromFile(aFilePath);
    LRoot := TJSONObject.ParseJSONValue(LSL.Text) as TJSONObject;
    if LRoot = nil then
      raise Exception.Create('Invalid JSON file');
    try
      FBatchSize := LRoot.GetValue<Integer>('batch_size', 1000);
      FValidate := LRoot.GetValue<Boolean>('validate', False);

      FMaps.Clear;

      LMapsArr := LRoot.GetValue<TJSONArray>('maps');
      if Assigned(LMapsArr) then
      begin
        for I := 0 to LMapsArr.Count - 1 do
        begin
          LMapObj := LMapsArr.Items[I] as TJSONObject;
          LFieldMap := TFieldMap.Create(
            LMapObj.GetValue<String>('source_table'),
            LMapObj.GetValue<String>('target_table'),
            Self
          );
          FMaps.Add(LFieldMap);

          LMappingsArr := LMapObj.GetValue<TJSONArray>('mappings');
          if Assigned(LMappingsArr) then
          begin
            for J := 0 to LMappingsArr.Count - 1 do
            begin
              LMappingObj := LMappingsArr.Items[J] as TJSONObject;
              LMapping := TFieldMapping.Create;
              LMapping.SourceField := LMappingObj.GetValue<String>('source_field', '');
              LMapping.TargetField := LMappingObj.GetValue<String>('target_field', '');
              LMappingType := LMappingObj.GetValue<Integer>('type', 0);
              LMapping.MappingType := TFieldMappingType(LMappingType);

              if LMapping.MappingType = fmtDefault then
                LMapping.DefaultValue := LMappingObj.GetValue<String>('default_value', '');
              if LMapping.MappingType = fmtLookup then
              begin
                LMapping.LookupTable := LMappingObj.GetValue<String>('lookup_table', '');
                LMapping.LookupField := LMappingObj.GetValue<String>('lookup_field', '');
                LMapping.ReturnField := LMappingObj.GetValue<String>('return_field', '');
              end;

              LFieldMap.Mappings.Add(LMapping);
            end;
          end;
        end;
      end;
    finally
      FreeAndNil(LRoot);
    end;
  finally
    FreeAndNil(LSL);
  end;
  Result := Self;
end;

function TSimpleDataMigration.MapCount: Integer;
begin
  Result := FMaps.Count;
end;

function TSimpleDataMigration.GetBatchSize: Integer;
begin
  Result := FBatchSize;
end;

function TSimpleDataMigration.GetValidate: Boolean;
begin
  Result := FValidate;
end;

end.
