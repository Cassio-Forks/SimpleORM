unit SimpleDAO;

interface

uses
    SimpleInterface,
    System.RTTI,
    System.Generics.Collections,
    System.Classes,
    Data.DB,
{$IFNDEF CONSOLE}
{$IFDEF FMX}
    FMX.Forms,
{$ELSE}
    Vcl.Forms,
{$ENDIF}
{$ENDIF}
    SimpleDAOSQLAttribute,
    System.Threading;

Type
    TSimpleDAO<T: class, constructor> = class(TInterfacedObject, iSimpleDAO<T>)
    private
        FQuery: iSimpleQuery;
        FDataSource: TDataSource;
        FSQLAttribute: iSimpleDAOSQLAttribute<T>;
{$IFNDEF CONSOLE}
        FForm: TForm;
{$ENDIF}
        FList: TObjectList<T>;
        function FillParameter(aInstance: T): iSimpleDAO<T>; overload;
        function FillParameter(aInstance: T; aId: Variant)
          : iSimpleDAO<T>; overload;
        procedure OnDataChange(Sender: TObject; Field: TField);
        procedure LoadRelationships(aEntity: T);
    public
        constructor Create(aQuery: iSimpleQuery);
        destructor Destroy; override;
        class function New(aQuery: iSimpleQuery): iSimpleDAO<T>; overload;
        function DataSource(aDataSource: TDataSource): iSimpleDAO<T>;
        function Insert(aValue: T): iSimpleDAO<T>; overload;
        function Update(aValue: T): iSimpleDAO<T>; overload;
        function Delete(aValue: T): iSimpleDAO<T>; overload;
        function Delete(aField: String; aValue: String): iSimpleDAO<T>;
          overload;
        function LastID: iSimpleDAO<T>;
        function LastRecord: iSimpleDAO<T>;
{$IFNDEF CONSOLE}
        function Insert: iSimpleDAO<T>; overload;
        function Update: iSimpleDAO<T>; overload;
        function Delete: iSimpleDAO<T>; overload;
{$ENDIF}
        function Find(aBindList: Boolean = True): iSimpleDAO<T>; overload;
        function Find(var aList: TObjectList<T>): iSimpleDAO<T>; overload;
        function Find(aId: Integer): T; overload;
        function Find(aKey: String; aValue: Variant): iSimpleDAO<T>; overload;
        function SQL: iSimpleDAOSQLAttribute<T>;
{$IFNDEF CONSOLE}
        function BindForm(aForm: TForm): iSimpleDAO<T>;
{$ENDIF}
    end;

implementation

uses
    System.SysUtils,
    SimpleAttributes,
    SimpleTypes,
    System.TypInfo,
    SimpleRTTI,
    SimpleRTTIHelper,
    SimpleSQL,
    Variants;
{ TGenericDAO }
{$IFNDEF CONSOLE}

function TSimpleDAO<T>.BindForm(aForm: TForm): iSimpleDAO<T>;
begin
    Result := Self;
    FForm := aForm;
end;

{$ENDIF}

constructor TSimpleDAO<T>.Create(aQuery: iSimpleQuery);
begin
    FQuery := aQuery;
    FSQLAttribute := TSimpleDAOSQLAttribute<T>.New(Self);
    FList := TObjectList<T>.Create;
end;

function TSimpleDAO<T>.DataSource(aDataSource: TDataSource): iSimpleDAO<T>;
begin
    Result := Self;
    FDataSource := aDataSource;
    FDataSource.DataSet := FQuery.DataSet;
    FDataSource.OnDataChange := OnDataChange;
end;

function TSimpleDAO<T>.Delete(aValue: T): iSimpleDAO<T>;
var
    aSQL: String;
begin
    Result := Self;
    TSimpleSQL<T>.New(aValue).Delete(aSQL);
    FQuery.SQL.Clear;
    FQuery.SQL.Add(aSQL);
    Self.FillParameter(aValue);
    FQuery.ExecSQL;
end;
{$IFNDEF CONSOLE}

function TSimpleDAO<T>.Delete: iSimpleDAO<T>;
var
    aSQL: String;
    Entity: T;
begin
    Result := Self;
    Entity := T.Create;
    try
        TSimpleSQL<T>.New(Entity).Delete(aSQL);
        FQuery.SQL.Clear;
        FQuery.SQL.Add(aSQL);
        TSimpleRTTI<T>.New(nil).BindFormToClass(FForm, Entity);
        Self.FillParameter(Entity);
        FQuery.ExecSQL;
    finally
        FreeAndNil(Entity);
    end;
end;
{$ENDIF}

function TSimpleDAO<T>.Delete(aField, aValue: String): iSimpleDAO<T>;
var
    aTableName: string;
    Entity: T;
begin
    Result := Self;
    Entity := T.Create;
    try
        TSimpleRTTI<T>.New(Entity).TableName(aTableName);
        FQuery.SQL.Clear;
        FQuery.SQL.Add('DELETE FROM ' + aTableName + ' WHERE ' + aField + ' = :pValue');
        FQuery.Params.ParamByName('pValue').Value := aValue;
        FQuery.ExecSQL;
    finally
        FreeAndNil(Entity);
    end;
end;

destructor TSimpleDAO<T>.Destroy;
begin
    FreeAndNil(FList);
    inherited;
end;

function TSimpleDAO<T>.Find(aBindList: Boolean = True): iSimpleDAO<T>;
var
    aSQL: String;
    I: Integer;
begin
    Result := Self;
    TSimpleSQL<T>.New(nil).Fields(FSQLAttribute.Fields).Join(FSQLAttribute.Join)
      .Where(FSQLAttribute.Where).GroupBy(FSQLAttribute.GroupBy)
      .OrderBy(FSQLAttribute.OrderBy)
      .Skip(FSQLAttribute.GetSkip)
      .Take(FSQLAttribute.GetTake)
      .DatabaseType(FQuery.SQLType)
      .Select(aSQL);
    FQuery.DataSet.DisableControls;
    FQuery.Open(aSQL);
    if aBindList then
    begin
        TSimpleRTTI<T>.New(nil).DataSetToEntityList(FQuery.DataSet, FList);
        for I := 0 to FList.Count - 1 do
            LoadRelationships(FList[I]);
    end;
    FSQLAttribute.Clear;
    FQuery.DataSet.EnableControls;
end;

function TSimpleDAO<T>.Find(aId: Integer): T;
var
    aSQL: String;
begin
    Result := T.Create;
    TSimpleSQL<T>.New(nil).SelectId(aSQL);
    FQuery.SQL.Clear;
    FQuery.SQL.Add(aSQL);
    Self.FillParameter(Result, aId);
    FQuery.Open;
    TSimpleRTTI<T>.New(nil).DataSetToEntity(FQuery.DataSet, Result);
    LoadRelationships(Result);
end;
{$IFNDEF CONSOLE}

function TSimpleDAO<T>.Insert: iSimpleDAO<T>;
var
    aSQL: String;
    Entity: T;
begin
    Result := Self;
    Entity := T.Create;
    try
        TSimpleSQL<T>.New(Entity).Insert(aSQL);
        FQuery.SQL.Clear;
        FQuery.SQL.Add(aSQL);
        TSimpleRTTI<T>.New(nil).BindFormToClass(FForm, Entity);
        Self.FillParameter(Entity);
        FQuery.ExecSQL;
    finally
        FreeAndNil(Entity);
    end;
end;

{$ENDIF}

function TSimpleDAO<T>.LastID: iSimpleDAO<T>;
var
    aSQL: String;
begin
    Result := Self;
    TSimpleSQL<T>.New(nil).LastID(aSQL);
    FQuery.Open(aSQL);
end;

function TSimpleDAO<T>.LastRecord: iSimpleDAO<T>;
var
    aSQL: String;
begin
    Result := Self;
    TSimpleSQL<T>.New(nil).LastRecord(aSQL);
    FQuery.Open(aSQL);
end;

function TSimpleDAO<T>.Find(var aList: TObjectList<T>): iSimpleDAO<T>;
var
    aSQL: String;
    I: Integer;
begin
    Result := Self;
    TSimpleSQL<T>.New(nil).Fields(FSQLAttribute.Fields).Join(FSQLAttribute.Join)
      .Where(FSQLAttribute.Where).GroupBy(FSQLAttribute.GroupBy)
      .OrderBy(FSQLAttribute.OrderBy)
      .Skip(FSQLAttribute.GetSkip)
      .Take(FSQLAttribute.GetTake)
      .DatabaseType(FQuery.SQLType)
      .Select(aSQL);
    FQuery.Open(aSQL);
    TSimpleRTTI<T>.New(nil).DataSetToEntityList(FQuery.DataSet, aList);
    for I := 0 to aList.Count - 1 do
        LoadRelationships(aList[I]);
    FSQLAttribute.Clear;
end;

function TSimpleDAO<T>.Insert(aValue: T): iSimpleDAO<T>;
var
    aSQL: String;
begin
    Result := Self;
    TSimpleSQL<T>.New(aValue).Insert(aSQL);
    FQuery.SQL.Clear;
    FQuery.SQL.Add(aSQL);
    Self.FillParameter(aValue);
    FQuery.ExecSQL;
end;

class function TSimpleDAO<T>.New(aQuery: iSimpleQuery): iSimpleDAO<T>;
begin
    Result := Self.Create(aQuery);
end;

procedure TSimpleDAO<T>.OnDataChange(Sender: TObject; Field: TField);
begin
    if (FList.Count > 0) and (FDataSource.DataSet.RecNo - 1 <= FList.Count) then
    begin
{$IFNDEF CONSOLE}
        if Assigned(FForm) then
            TSimpleRTTI<T>.New(nil).BindClassToForm(FForm,
              FList[FDataSource.DataSet.RecNo - 1]);
{$ENDIF}
    end;
end;

function TSimpleDAO<T>.SQL: iSimpleDAOSQLAttribute<T>;
begin
    Result := FSQLAttribute;
end;
{$IFNDEF CONSOLE}

function TSimpleDAO<T>.Update: iSimpleDAO<T>;
var
    aSQL: String;
    Entity: T;
begin
    Result := Self;
    Entity := T.Create;
    try
        TSimpleSQL<T>.New(Entity).Update(aSQL);
        FQuery.SQL.Clear;
        FQuery.SQL.Add(aSQL);
        TSimpleRTTI<T>.New(nil).BindFormToClass(FForm, Entity);
        Self.FillParameter(Entity);
        FQuery.ExecSQL;
    finally
        FreeAndNil(Entity)
    end;
end;
{$ENDIF}

function TSimpleDAO<T>.Update(aValue: T): iSimpleDAO<T>;
var
    aSQL: String;
begin
    Result := Self;
    TSimpleSQL<T>.New(aValue).Update(aSQL);
    FQuery.SQL.Clear;
    FQuery.SQL.Add(aSQL);
    Self.FillParameter(aValue);
    FQuery.ExecSQL;
end;

function TSimpleDAO<T>.FillParameter(aInstance: T): iSimpleDAO<T>;
var
    Key: String;
    DictionaryFields: TDictionary<String, Variant>;
    DictionaryTypeFields: TDictionary<String, TFieldType>;
    FieldType: TFieldType;
begin
    DictionaryFields := TDictionary<String, Variant>.Create;
    DictionaryTypeFields := TDictionary<String, TFieldType>.Create;
    TSimpleRTTI<T>.New(aInstance).DictionaryFields(DictionaryFields);
    TSimpleRTTI<T>.New(aInstance).DictionaryTypeFields(DictionaryTypeFields);
    try
        for Key in DictionaryFields.Keys do
        begin
            if FQuery.Params.FindParam(Key) <> nil then
            begin
                if DictionaryTypeFields.TryGetValue(Key, FieldType ) then
                  FQuery.Params.ParamByName(Key).DataType := FieldType;
                FQuery.Params.ParamByName(Key).Value := DictionaryFields.Items[Key];
            end;
        end;
    finally
        FreeAndNil(DictionaryFields);
        FreeAndNil(DictionaryTypeFields);
    end;
end;

function TSimpleDAO<T>.FillParameter(aInstance: T; aId: Variant): iSimpleDAO<T>;
var
    I: Integer;
    ListFields: TList<String>;
begin
    ListFields := TList<String>.Create;
    TSimpleRTTI<T>.New(aInstance).ListFields(ListFields);
    try
        for I := 0 to Pred(ListFields.Count) do
        begin
            if FQuery.Params.FindParam(ListFields[I]) <> nil then
                FQuery.Params.ParamByName(ListFields[I]).Value := aId;
        end;
    finally
        FreeAndNil(ListFields);
    end;
end;

function TSimpleDAO<T>.Find(aKey: String; aValue: Variant): iSimpleDAO<T>;
var
    aSQL: String;
begin
    Result := Self;
    TSimpleSQL<T>.New(nil).Where(aKey + ' = :' + aKey).Select(aSQL);
    FQuery.SQL.Clear;
    FQuery.SQL.Add(aSQL);
    FQuery.Params.ParamByName(aKey).Value := aValue;
    FQuery.Open;
end;

procedure TSimpleDAO<T>.LoadRelationships(aEntity: T);
var
  ctxRtti: TRttiContext;
  typRtti: TRttiType;
  prpRtti: TRttiProperty;
  Info: PTypeInfo;
  Rel: Relationship;
  aSQL: string;
  FKValue: Variant;
  FKProp: TRttiProperty;
  RelObj: TObject;
  RelField: TField;
  RelProp: TRttiProperty;
  RelType: TRttiType;
  RelTableName: string;
  RelPKName: string;
  RelPKProp: TRttiProperty;
begin
  Info := System.TypeInfo(T);
  ctxRtti := TRttiContext.Create;
  try
    typRtti := ctxRtti.GetType(Info);
    for prpRtti in typRtti.GetProperties do
    begin
      if not (prpRtti.IsBelongsTo or prpRtti.IsHasOne) then
        Continue;

      if prpRtti.PropertyType.TypeKind <> tkClass then
        Continue;

      Rel := prpRtti.GetRelationship;
      if (Rel = nil) or (Rel.ForeignKey = '') then
        Continue;

      // Get FK value from the entity
      FKProp := typRtti.GetProperty(Rel.ForeignKey);
      if FKProp = nil then
        Continue;
      FKValue := FKProp.GetValue(Pointer(aEntity)).AsVariant;

      // Create related object instance
      RelObj := prpRtti.PropertyType.AsInstance.MetaclassType.Create;

      // Get the related entity's table name and PK using its RTTI
      RelType := ctxRtti.GetType(prpRtti.PropertyType.AsInstance.MetaclassType);

      RelTableName := '';
      RelPKName := '';

      if RelType.Tem<Tabela> then
        RelTableName := RelType.GetAttribute<Tabela>.Name;

      RelPKProp := RelType.GetPKField;
      if RelPKProp <> nil then
        RelPKName := RelPKProp.FieldName;

      if (RelTableName = '') or (RelPKName = '') then
      begin
        RelObj.Free;
        Continue;
      end;

      aSQL := 'SELECT * FROM ' + RelTableName + ' WHERE ' + RelPKName + ' = :pValue';
      FQuery.SQL.Clear;
      FQuery.SQL.Add(aSQL);
      FQuery.Params.ParamByName('pValue').Value := FKValue;
      FQuery.Open;

      // Map dataset fields to related object properties
      if not FQuery.DataSet.IsEmpty then
      begin
        for RelProp in RelType.GetProperties do
        begin
          if RelProp.IsIgnore then
            Continue;
          RelField := FQuery.DataSet.FindField(RelProp.FieldName);
          if RelField = nil then
            Continue;

          case RelProp.PropertyType.TypeKind of
            tkInteger, tkInt64:
              RelProp.SetValue(RelObj, RelField.AsInteger);
            tkFloat:
              RelProp.SetValue(RelObj, RelField.AsFloat);
            tkUString, tkString, tkWString, tkLString:
              RelProp.SetValue(RelObj, RelField.AsString);
          end;
        end;
      end;

      // Set the related object on the main entity
      prpRtti.SetValue(Pointer(aEntity), RelObj);

      FQuery.DataSet.Close;
    end;
  finally
    ctxRtti.Free;
  end;
end;

end.
