unit SimpleQueryFiredac;

interface

uses
  SimpleInterface, SimpleTypes, FireDAC.Comp.Client, System.Classes, Data.DB,
  FireDAC.Stan.Param, FireDAC.DatS,
  FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.DataSet;

Type
  TSimpleQueryFiredac = class(TInterfacedObject, iSimpleQuery)
  private
    FConnection: TFDConnection;
    FTransaction: TFDTransaction;
    FQuery: TFDQuery;
    FParams: TParams;
    FSQLType: TSQLType;
  public
    constructor Create(aConnection: TFDConnection; aSQLType: TSQLType = TSQLType.Firebird);
    destructor Destroy; override;
    class function New(aConnection: TFDConnection; aSQLType: TSQLType = TSQLType.Firebird): iSimpleQuery;
    function SQL: TStrings;
    function Params: TParams;
    function ExecSQL: iSimpleQuery;
    function DataSet: TDataSet;
    function Open(aSQL: String): iSimpleQuery; overload;
    function Open: iSimpleQuery; overload;
    function &EndTransaction: iSimpleQuery;
    function StartTransaction: iSimpleQuery;
    function Commit: iSimpleQuery;
    function Rollback: iSimpleQuery;
    function InTransaction: Boolean;
    function SQLType: TSQLType;
  end;

implementation

uses
  System.SysUtils;

{ TSimpleQuery<T> }

constructor TSimpleQueryFiredac.Create(aConnection: TFDConnection; aSQLType: TSQLType = TSQLType.Firebird);
begin
  FQuery := TFDQuery.Create(nil);
  FConnection := aConnection;
  FQuery.Connection := FConnection;

  FTransaction := TFDTransaction.Create(nil);
  FTransaction.Connection := FConnection;
  FQuery.Transaction := FTransaction;

  FSQLType := aSQLType;
end;

function TSimpleQueryFiredac.DataSet: TDataSet;
begin
  Result := TDataSet(FQuery);
end;

destructor TSimpleQueryFiredac.Destroy;
begin
  FreeAndNil(FTransaction);
  FreeAndNil(FQuery);
  if Assigned(FParams) then
    FreeAndNil(FParams);
  inherited;
end;

function TSimpleQueryFiredac.EndTransaction: iSimpleQuery;
begin
  Result := Commit;
end;

function TSimpleQueryFiredac.ExecSQL: iSimpleQuery;
begin
  Result := Self;
  if Assigned(FParams) then
    FQuery.Params.Assign(FParams);

  FQuery.Prepare;

  try
    FQuery.ExecSQL;
  except
    on E: Exception do
    begin
      if FTransaction.Active then
        FTransaction.Rollback;
      raise;
    end;
  end;

  if Assigned(FParams) then
    FreeAndNil(FParams);
end;

class function TSimpleQueryFiredac.New(aConnection: TFDConnection; aSQLType: TSQLType): iSimpleQuery;
begin
  Result := Self.Create(aConnection, aSQLType);
end;

function TSimpleQueryFiredac.Open: iSimpleQuery;
begin
  Result := Self;
  FQuery.Close;

  if Assigned(FParams) then
    FQuery.Params.Assign(FParams);

  FQuery.Prepare;
  FQuery.Open;

  if Assigned(FParams) then
    FreeAndNil(FParams);
end;

function TSimpleQueryFiredac.Open(aSQL: String): iSimpleQuery;
begin
  Result := Self;
  FQuery.Close;
  FQuery.Open(aSQL);
end;

function TSimpleQueryFiredac.Params: TParams;
begin
  if not Assigned(FParams) then
  begin
    FParams := TParams.Create(nil);
    FParams.Assign(FQuery.Params);
  end;
  Result := FParams;
end;

function TSimpleQueryFiredac.SQL: TStrings;
begin
  Result := FQuery.SQL;
end;

function TSimpleQueryFiredac.StartTransaction: iSimpleQuery;
begin
  Result := Self;
  if not FTransaction.Active then
    FTransaction.StartTransaction;
end;

function TSimpleQueryFiredac.Commit: iSimpleQuery;
begin
  Result := Self;
  if FTransaction.Active then
    FTransaction.Commit;
end;

function TSimpleQueryFiredac.Rollback: iSimpleQuery;
begin
  Result := Self;
  if FTransaction.Active then
    FTransaction.Rollback;
end;

function TSimpleQueryFiredac.InTransaction: Boolean;
begin
  Result := FTransaction.Active;
end;

function TSimpleQueryFiredac.SQLType: TSQLType;
begin
  Result := FSQLType;
end;

end.
