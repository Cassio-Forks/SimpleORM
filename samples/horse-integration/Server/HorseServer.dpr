program HorseServer;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Phys.FB,
  SimpleInterface,
  SimpleQueryFiredac,
  SimpleHorseRouter,
  Entidade.Pedido in '..\..\Entidades\Entidade.Pedido.pas';

var
  LConn: TFDConnection;
  LQuery: iSimpleQuery;
begin
  // Configure database connection
  LConn := TFDConnection.Create(nil);
  LConn.Params.DriverID := 'FB';
  LConn.Params.Database := 'C:\database\MEUBANCO.FDB';
  LConn.Params.UserName := 'SYSDBA';
  LConn.Params.Password := 'masterkey';
  LConn.Connected := True;

  LQuery := TSimpleQueryFiredac.New(LConn);

  // Register entity routes - one line per entity!
  TSimpleHorseRouter.RegisterEntity<TPEDIDO>(THorse, LQuery);

  // Example with custom path and callbacks:
  // TSimpleHorseRouter.RegisterEntity<TPEDIDO>(THorse, LQuery, '/api/pedidos')
  //   .OnBeforeInsert(
  //     procedure(aEntity: TObject; var aContinue: Boolean)
  //     begin
  //       Writeln('Inserting: ', TPEDIDO(aEntity).CLIENTE);
  //       aContinue := True;
  //     end
  //   )
  //   .OnAfterInsert(
  //     procedure(aEntity: TObject)
  //     begin
  //       Writeln('Inserted ID: ', TPEDIDO(aEntity).ID);
  //     end
  //   );

  Writeln('Server running on port 9000...');
  Writeln('Routes:');
  Writeln('  GET    /pedido      - List all');
  Writeln('  GET    /pedido/:id  - Find by ID');
  Writeln('  POST   /pedido      - Insert');
  Writeln('  PUT    /pedido/:id  - Update');
  Writeln('  DELETE /pedido/:id  - Delete');

  THorse.Listen(9000);
end.
