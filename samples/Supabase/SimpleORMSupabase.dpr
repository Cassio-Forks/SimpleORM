program SimpleORMSupabase;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SimpleInterface,
  SimpleDAO,
  SimpleQuerySupabase,
  System.SysUtils,
  System.Generics.Collections,
  Entidade.Produto in '..\Entidades\Entidade.Produto.pas';

var
  LQuery: iSimpleQuery;
  LDAO: iSimpleDAO<TProduto>;
  LList: TObjectList<TProduto>;
  LProduto: TProduto;
  I: Integer;
begin
  try
    // =====================================================================
    // SETUP - Replace with your Supabase project URL and API key
    // =====================================================================
    // You can find these in: Supabase Dashboard > Settings > API
    LQuery := TSimpleQuerySupabase.New(
      'https://YOUR_PROJECT.supabase.co',  // Supabase project URL
      'YOUR_ANON_OR_SERVICE_ROLE_KEY'       // Supabase API key (anon or service_role)
    );

    // Optional: use a JWT token for Row Level Security (RLS)
    // TSimpleQuerySupabase(LQuery).Token('YOUR_JWT_TOKEN');

    LDAO := TSimpleDAO<TProduto>.New(LQuery);

    // =====================================================================
    // INSERT - Create a new product
    // =====================================================================
    Writeln('--- INSERT: Creating a new product ---');
    LProduto := TProduto.Create;
    try
      LProduto.NOME := 'Teclado Mecanico';
      LProduto.PRECO := 299.90;
      LProduto.QUANTIDADE := 50;
      LDAO.Insert(LProduto);
      Writeln('Product inserted successfully!');
    finally
      LProduto.Free;
    end;

    Writeln('');

    // =====================================================================
    // FIND ALL - List all products
    // =====================================================================
    Writeln('--- FIND ALL: Listing all products ---');
    LList := TObjectList<TProduto>.Create;
    try
      LDAO.Find(LList);
      for I := 0 to LList.Count - 1 do
        Writeln(SysUtils.Format('  ID: %d | Nome: %s | Preco: %.2f | Qtd: %d', [
          LList[I].ID,
          LList[I].NOME,
          LList[I].PRECO,
          LList[I].QUANTIDADE
        ]));
      Writeln(SysUtils.Format('Total: %d products', [LList.Count]));
    finally
      LList.Free;
    end;

    Writeln('');

    // =====================================================================
    // UPDATE - Modify an existing product
    // =====================================================================
    Writeln('--- UPDATE: Updating product #1 ---');
    LProduto := LDAO.Find(1);
    try
      if Assigned(LProduto) then
      begin
        LProduto.NOME := 'Teclado Mecanico RGB';
        LProduto.PRECO := 349.90;
        LDAO.Update(LProduto);
        Writeln(SysUtils.Format('Updated: %s - R$ %.2f', [LProduto.NOME, LProduto.PRECO]));
      end
      else
        Writeln('  Product #1 not found');
    finally
      LProduto.Free;
    end;

    Writeln('');

    // =====================================================================
    // FIND BY ID - Retrieve a single product
    // =====================================================================
    Writeln('--- FIND BY ID: Finding product #1 ---');
    LProduto := LDAO.Find(1);
    try
      if Assigned(LProduto) then
        Writeln(SysUtils.Format('  ID: %d | Nome: %s | Preco: %.2f | Qtd: %d', [
          LProduto.ID,
          LProduto.NOME,
          LProduto.PRECO,
          LProduto.QUANTIDADE
        ]))
      else
        Writeln('  Product not found');
    finally
      LProduto.Free;
    end;

    Writeln('');

    // =====================================================================
    // PAGINATION - Retrieve products with Skip/Take
    // =====================================================================
    Writeln('--- PAGINATION: First 5 products (skip 0, take 5) ---');
    LList := TObjectList<TProduto>.Create;
    try
      LDAO.SQL.Skip(0).Take(5).&End.Find(LList);
      for I := 0 to LList.Count - 1 do
        Writeln(SysUtils.Format('  ID: %d | Nome: %s', [
          LList[I].ID,
          LList[I].NOME
        ]));
      Writeln(SysUtils.Format('Page items: %d', [LList.Count]));
    finally
      LList.Free;
    end;

    Writeln('');

    // =====================================================================
    // DELETE - Remove a product
    // =====================================================================
    Writeln('--- DELETE: Deleting product #1 ---');
    LProduto := TProduto.Create;
    try
      LProduto.ID := 1;
      LDAO.Delete(LProduto);
      Writeln('Product deleted successfully!');
    finally
      LProduto.Free;
    end;

    Writeln('');
    Writeln('All operations completed successfully!');

  except
    on E: Exception do
      Writeln('ERROR: ' + E.ClassName + ' - ' + E.Message);
  end;

  Writeln('');
  Writeln('Press Enter to exit...');
  Readln;
end.
