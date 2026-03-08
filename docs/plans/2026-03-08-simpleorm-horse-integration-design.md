# SimpleORM + ExpxHorse Integration Design

## Goal

Integração completa entre SimpleORM e ExpxHorse: servidor auto-gerado + cliente REST, permitindo usar SimpleORM nos dois lados com a mesma API fluente.

## Architecture

3 novas units compartilham o RTTI do SimpleORM para serialização, geração automática de rotas CRUD no servidor Horse, e um driver REST no cliente que implementa `iSimpleQuery` via HTTP.

## Components

### 1. SimpleSerializer.pas (Compartilhado)

Converte Entity ↔ JSON usando RTTI e atributos `[Campo]`:

```pascal
TSimpleSerializer = class
  class function EntityToJSON<T: class>(aEntity: T): TJSONObject;
  class function JSONToEntity<T: class, constructor>(aJSON: TJSONObject): T;
  class function EntityListToJSONArray<T: class>(aList: TObjectList<T>): TJSONArray;
  class function JSONArrayToEntityList<T: class, constructor>(aArray: TJSONArray): TObjectList<T>;
end;
```

- Nomes JSON = valor do atributo `[Campo]` (ex: `NOME_PRODUTO`)
- Respeita `[Ignore]` — pula propriedades ignoradas
- Suporta: string, Integer, Double, TDateTime, Boolean
- `[PK]` e `[AutoInc]` serializados normalmente

### 2. SimpleHorseRouter.pas (Servidor)

Auto-gera rotas CRUD no Horse a partir de entidades:

```pascal
TSimpleHorseRouter = class
  class procedure RegisterEntity<T: class, constructor>(
    aApp: THorse;
    aDAO: iSimpleDAO<T>;
    aPath: string = ''
  );
end;
```

Rotas geradas:
- `GET /entidade` → Find (suporta `?skip=N&take=N`)
- `GET /entidade/:id` → Find por PK
- `POST /entidade` → Insert
- `PUT /entidade/:id` → Update
- `DELETE /entidade/:id` → Delete (respeita SoftDelete)

Callbacks opcionais via fluent interface:
- `OnBeforeInsert(procedure(aEntity: TObject; var aContinue: Boolean))`
- `OnAfterInsert(procedure(aEntity: TObject))`
- `OnBeforeUpdate(procedure(aEntity: TObject; var aContinue: Boolean))`
- `OnBeforeDelete(procedure(aId: string; var aContinue: Boolean))`

Path padrão derivado de `[Tabela]`: `Tabela('PRODUTOS')` → `/produtos` (lowercase).
Respostas JSON via `TSimpleSerializer`, status codes padrão (200, 201, 204, 400, 404, 500).
GET lista retorna `{ "data": [...], "count": N }`.

### 3. SimpleQueryHorse.pas (Cliente)

Driver REST implementando `iSimpleQuery` via HTTP:

```pascal
TSimpleQueryHorse = class(TInterfacedObject, iSimpleQuery)
  constructor Create(aBaseURL: string; aToken: string = '');
  class function New(aBaseURL: string; aToken: string = ''): iSimpleQuery;
  function Token(aValue: string): iSimpleQuery;
  function OnBeforeRequest(aProc: TProc<TStrings>): iSimpleQuery;
end;
```

Mapeamento:
- `DAO.Find` → `GET /entidade`
- `DAO.Find(id)` → `GET /entidade/:id`
- `DAO.Insert` → `POST /entidade` (body JSON)
- `DAO.Update` → `PUT /entidade/:id` (body JSON)
- `DAO.Delete` → `DELETE /entidade/:id`
- Skip/Take → query params `?skip=N&take=N`

Usa `THTTPClient` (System.Net.HttpClient, nativo Delphi).
Bearer token no header `Authorization`.
`OnBeforeRequest` para headers customizados.

## Data Flow

```
[Frontend Delphi]                    [Servidor Horse]
TSimpleDAO<TProduto>                 TSimpleHorseRouter.RegisterEntity<TProduto>
  └─ TSimpleQueryHorse ──HTTP──→       └─ GET/POST/PUT/DELETE auto-gerados
       (BaseURL + Token)                    └─ TSimpleDAO<TProduto>
                                                └─ TSimpleQueryFiredac (banco real)
```

## Dependencies

- `System.Net.HttpClient` (nativo Delphi) no cliente
- `Horse` no servidor (dependência do ExpxHorse)
- Zero dependências externas novas
