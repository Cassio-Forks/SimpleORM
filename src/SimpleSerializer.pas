unit SimpleSerializer;

interface

uses
  System.SysUtils, System.Classes, System.Rtti, System.JSON,
  System.DateUtils, System.Generics.Collections,
  SimpleAttributes;

type
  TSimpleSerializer = class
  public
    class function EntityToJSON<T: class>(aEntity: T): TJSONObject;
    class function JSONToEntity<T: class, constructor>(aJSON: TJSONObject): T;
    class function EntityListToJSONArray<T: class>(aList: TObjectList<T>): TJSONArray;
    class function JSONArrayToEntityList<T: class, constructor>(aArray: TJSONArray): TObjectList<T>;
  end;

implementation

{ TSimpleSerializer }

class function TSimpleSerializer.EntityToJSON<T>(aEntity: T): TJSONObject;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LAttr: TCustomAttribute;
  LCampoName: string;
  LHasCampo: Boolean;
  LHasIgnore: Boolean;
  LValue: TValue;
begin
  Result := TJSONObject.Create;
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TObject(aEntity).ClassType);
    for LProp in LType.GetProperties do
    begin
      LHasCampo := False;
      LHasIgnore := False;
      LCampoName := '';

      for LAttr in LProp.GetAttributes do
      begin
        if LAttr is Ignore then
          LHasIgnore := True;
        if LAttr is Campo then
        begin
          LHasCampo := True;
          LCampoName := Campo(LAttr).Name;
        end;
      end;

      if LHasIgnore or (not LHasCampo) then
        Continue;

      LValue := LProp.GetValue(TObject(aEntity));

      case LProp.PropertyType.TypeKind of
        tkUString, tkString, tkLString, tkWString:
          Result.AddPair(LCampoName, LValue.AsString);
        tkInteger:
          Result.AddPair(LCampoName, TJSONNumber.Create(LValue.AsInteger));
        tkInt64:
          Result.AddPair(LCampoName, TJSONNumber.Create(LValue.AsInt64));
        tkFloat:
        begin
          if LProp.PropertyType.Handle = TypeInfo(TDateTime) then
            Result.AddPair(LCampoName, DateToISO8601(LValue.AsExtended, False))
          else
            Result.AddPair(LCampoName, TJSONNumber.Create(LValue.AsExtended));
        end;
        tkEnumeration:
        begin
          if LProp.PropertyType.Handle = TypeInfo(Boolean) then
          begin
            if LValue.AsBoolean then
              Result.AddPair(LCampoName, TJSONTrue.Create)
            else
              Result.AddPair(LCampoName, TJSONFalse.Create);
          end;
        end;
      end;
    end;
  finally
    LContext.Free;
  end;
end;

class function TSimpleSerializer.JSONToEntity<T>(aJSON: TJSONObject): T;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LAttr: TCustomAttribute;
  LCampoName: string;
  LHasCampo: Boolean;
  LHasIgnore: Boolean;
  LJSONValue: TJSONValue;
  LObj: T;
begin
  LObj := T.Create;
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TObject(LObj).ClassType);
    for LProp in LType.GetProperties do
    begin
      LHasCampo := False;
      LHasIgnore := False;
      LCampoName := '';

      for LAttr in LProp.GetAttributes do
      begin
        if LAttr is Ignore then
          LHasIgnore := True;
        if LAttr is Campo then
        begin
          LHasCampo := True;
          LCampoName := Campo(LAttr).Name;
        end;
      end;

      if LHasIgnore or (not LHasCampo) then
        Continue;

      LJSONValue := aJSON.FindValue(LCampoName);
      if LJSONValue = nil then
        Continue;

      case LProp.PropertyType.TypeKind of
        tkUString, tkString, tkLString, tkWString:
          LProp.SetValue(TObject(LObj), LJSONValue.Value);
        tkInteger:
          LProp.SetValue(TObject(LObj), (LJSONValue as TJSONNumber).AsInt);
        tkInt64:
          LProp.SetValue(TObject(LObj), (LJSONValue as TJSONNumber).AsInt64);
        tkFloat:
        begin
          if LProp.PropertyType.Handle = TypeInfo(TDateTime) then
            LProp.SetValue(TObject(LObj), TValue.From<TDateTime>(ISO8601ToDate(LJSONValue.Value, False)))
          else
            LProp.SetValue(TObject(LObj), (LJSONValue as TJSONNumber).AsDouble);
        end;
        tkEnumeration:
        begin
          if LProp.PropertyType.Handle = TypeInfo(Boolean) then
          begin
            if LJSONValue is TJSONTrue then
              LProp.SetValue(TObject(LObj), True)
            else if LJSONValue is TJSONFalse then
              LProp.SetValue(TObject(LObj), False);
          end;
        end;
      end;
    end;
  finally
    LContext.Free;
  end;
  Result := LObj;
end;

class function TSimpleSerializer.EntityListToJSONArray<T>(aList: TObjectList<T>): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := 0 to aList.Count - 1 do
    Result.AddElement(EntityToJSON<T>(aList[I]));
end;

class function TSimpleSerializer.JSONArrayToEntityList<T>(aArray: TJSONArray): TObjectList<T>;
var
  I: Integer;
begin
  Result := TObjectList<T>.Create;
  for I := 0 to aArray.Count - 1 do
    Result.Add(JSONToEntity<T>(aArray.Items[I] as TJSONObject));
end;

end.
