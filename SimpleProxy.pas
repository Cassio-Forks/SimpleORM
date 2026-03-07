unit SimpleProxy;

interface

uses
  System.Generics.Collections, SimpleInterface, Data.DB, System.RTTI,
  System.TypInfo, System.SysUtils, SimpleRTTIHelper, SimpleAttributes;

type
  TSimpleLazyLoader<T: class, constructor> = class(TObjectList<T>)
  private
    FLoaded: Boolean;
    FQuery: iSimpleQuery;
    FForeignKey: string;
    FForeignValue: Variant;
    procedure EnsureLoaded;
  public
    constructor Create(aQuery: iSimpleQuery; const aForeignKey: string; aForeignValue: Variant);
    function Count: Integer;
    function ToArray: TArray<T>;
  end;

implementation

constructor TSimpleLazyLoader<T>.Create(aQuery: iSimpleQuery; const aForeignKey: string; aForeignValue: Variant);
begin
  inherited Create(True);
  FQuery := aQuery;
  FForeignKey := aForeignKey;
  FForeignValue := aForeignValue;
  FLoaded := False;
end;

procedure TSimpleLazyLoader<T>.EnsureLoaded;
var
  Info: PTypeInfo;
  ctxRtti: TRttiContext;
  typRtti: TRttiType;
  prpRtti: TRttiProperty;
  aTableName: string;
  aSQL: string;
  Field: TField;
  Item: T;
begin
  if FLoaded then
    Exit;

  FLoaded := True;

  Info := System.TypeInfo(T);
  ctxRtti := TRttiContext.Create;
  try
    typRtti := ctxRtti.GetType(Info);

    // Get table name
    if typRtti.Tem<Tabela> then
      aTableName := typRtti.GetAttribute<Tabela>.Name
    else
      Exit;

    // Build query
    aSQL := 'SELECT * FROM ' + aTableName + ' WHERE ' + FForeignKey + ' = :pValue';
    FQuery.SQL.Clear;
    FQuery.SQL.Add(aSQL);
    FQuery.Params.ParamByName('pValue').Value := FForeignValue;
    FQuery.Open;

    // Map results to objects
    while not FQuery.DataSet.Eof do
    begin
      Item := T.Create;
      for prpRtti in typRtti.GetProperties do
      begin
        if prpRtti.IsIgnore then
          Continue;
        Field := FQuery.DataSet.FindField(prpRtti.FieldName);
        if Field = nil then
          Continue;

        case prpRtti.PropertyType.TypeKind of
          tkInteger, tkInt64:
            prpRtti.SetValue(Pointer(Item), Field.AsInteger);
          tkFloat:
            prpRtti.SetValue(Pointer(Item), Field.AsFloat);
          tkUString, tkString, tkWString, tkLString:
            prpRtti.SetValue(Pointer(Item), Field.AsString);
        end;
      end;
      Self.Add(Item);
      FQuery.DataSet.Next;
    end;
  finally
    ctxRtti.Free;
  end;
end;

function TSimpleLazyLoader<T>.Count: Integer;
begin
  EnsureLoaded;
  Result := inherited Count;
end;

function TSimpleLazyLoader<T>.ToArray: TArray<T>;
begin
  EnsureLoaded;
  Result := inherited ToArray;
end;

end.
