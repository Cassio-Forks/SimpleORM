program HorseClient;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Generics.Collections,
  SimpleDAO,
  SimpleInterface,
  SimpleQueryHorse,
  Entidade.Pedido in '..\..\Entidades\Entidade.Pedido.pas';

var
  LDAO: iSimpleDAO<TPEDIDO>;
  LList: TObjectList<TPEDIDO>;
  LPedido: TPEDIDO;
  I: Integer;
begin
  // Create DAO using Horse REST driver
  // This is the ONLY line that differs from direct database usage!
  LDAO := TSimpleDAO<TPEDIDO>.New(
    TSimpleQueryHorse.New('http://localhost:9000')
  );

  // === INSERT ===
  Writeln('--- Inserting a new order ---');
  LPedido := TPEDIDO.Create;
  try
    LPedido.CLIENTE := 'Fulano de Tal';
    LPedido.DATAPEDIDO := Now;
    LPedido.VALORTOTAL := 150.50;
    LDAO.Insert(LPedido);
    Writeln('Inserted successfully!');
  finally
    LPedido.Free;
  end;

  // === FIND ALL ===
  Writeln('');
  Writeln('--- Listing all orders ---');
  LList := TObjectList<TPEDIDO>.Create;
  try
    LDAO.Find(LList);
    for I := 0 to LList.Count - 1 do
      Writeln(Format('  ID: %d | Cliente: %s | Valor: %.2f', [
        LList[I].ID,
        LList[I].CLIENTE,
        LList[I].VALORTOTAL
      ]));
    Writeln(Format('Total: %d orders', [LList.Count]));
  finally
    LList.Free;
  end;

  // === FIND BY ID ===
  Writeln('');
  Writeln('--- Finding order #1 ---');
  LPedido := LDAO.Find(1);
  try
    if Assigned(LPedido) then
      Writeln(Format('  ID: %d | Cliente: %s', [LPedido.ID, LPedido.CLIENTE]))
    else
      Writeln('  Not found');
  finally
    LPedido.Free;
  end;

  // === FIND WITH PAGINATION ===
  Writeln('');
  Writeln('--- First 5 orders (pagination) ---');
  LList := TObjectList<TPEDIDO>.Create;
  try
    LDAO.SQL.Skip(0).Take(5).&End.Find(LList);
    for I := 0 to LList.Count - 1 do
      Writeln(Format('  ID: %d | Cliente: %s', [LList[I].ID, LList[I].CLIENTE]));
  finally
    LList.Free;
  end;

  Writeln('');
  Writeln('Done! Press Enter to exit...');
  Readln;
end.
