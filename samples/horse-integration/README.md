# SimpleORM + Horse Integration Sample

Demonstrates how to use SimpleORM with Horse (ExpxHorse) as a REST server and SimpleORM as the frontend client.

## Server (HorseServer.dpr)

Registers entity CRUD routes automatically with one line per entity:

```pascal
TSimpleHorseRouter.RegisterEntity<TPEDIDO>(THorse, LQuery);
```

This generates:
- `GET /pedido` - List all (supports `?skip=N&take=N`)
- `GET /pedido/:id` - Find by ID
- `POST /pedido` - Insert (JSON body)
- `PUT /pedido/:id` - Update (JSON body)
- `DELETE /pedido/:id` - Delete

## Client (HorseClient.dpr)

Uses `TSimpleQueryHorse` instead of `TSimpleQueryFiredac` - the rest of the code is identical:

```pascal
// Only difference from direct database usage:
LDAO := TSimpleDAO<TPEDIDO>.New(
  TSimpleQueryHorse.New('http://localhost:9000')
);

// Same API as always:
LDAO.Find(LList);
LDAO.Insert(LPedido);
```

## Running

1. Start the server: run `HorseServer.exe`
2. Run the client: run `HorseClient.exe`
