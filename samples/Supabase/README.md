# SimpleORM Supabase Sample

Console application demonstrating CRUD operations with SimpleORM using the Supabase driver.

## Pre-requisites

1. A [Supabase](https://supabase.com) account and project
2. Create the `PRODUTO` table in your Supabase SQL Editor:

```sql
CREATE TABLE produto (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nome TEXT NOT NULL,
  preco NUMERIC(10,2) DEFAULT 0,
  quantidade INTEGER DEFAULT 0
);

-- Optional: disable RLS for testing (not recommended for production)
ALTER TABLE produto DISABLE ROW LEVEL SECURITY;
```

3. Get your project URL and API key from: **Supabase Dashboard > Settings > API**

## How to Run

1. Open `SimpleORMSupabase.dpr` in the Delphi IDE (this will generate `.dproj` and `.res`)
2. Replace `YOUR_PROJECT` and `YOUR_ANON_OR_SERVICE_ROLE_KEY` with your actual Supabase credentials
3. Compile and run (F9)

## Features Demonstrated

- **INSERT** - Create a new product via Supabase REST API
- **FIND ALL** - List all products from the table
- **UPDATE** - Modify an existing product by ID
- **FIND BY ID** - Retrieve a single product
- **PAGINATION** - Use `Skip`/`Take` for paginated results
- **DELETE** - Remove a product by ID
- **Error handling** - Global `try/except` for HTTP and runtime errors

## Authentication

- By default, the `anon` key is used for both `apikey` header and Bearer token
- For Row Level Security (RLS), pass a JWT token via the `Token()` method:

```pascal
LQuery := TSimpleQuerySupabase.New(url, apikey);
TSimpleQuerySupabase(LQuery).Token('user-jwt-token');
```

- For server-side operations without RLS, use the `service_role` key (keep it secret!)
