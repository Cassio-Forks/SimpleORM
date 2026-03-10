program SimpleORMSkills;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Generics.Collections,
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleAttributes in '..\..\src\SimpleAttributes.pas',
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleSkill in '..\..\src\SimpleSkill.pas',
  SimpleValidator in '..\..\src\SimpleValidator.pas',
  SimpleRTTIHelper in '..\..\src\SimpleRTTIHelper.pas',
  SimpleAIAttributes in '..\..\src\SimpleAIAttributes.pas',
  SimpleLogger in '..\..\src\SimpleLogger.pas';

type
  [Tabela('PRODUTO')]
  TProduto = class
  private
    FID: Integer;
    FNOME: String;
    FPRECO: Double;
    FCREATED_AT: TDateTime;
    FUPDATED_AT: TDateTime;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write FID;
    [Campo('NOME'), NotNull]
    property NOME: String read FNOME write FNOME;
    [Campo('PRECO'), NotZero]
    property PRECO: Double read FPRECO write FPRECO;
    [Campo('CREATED_AT')]
    property CREATED_AT: TDateTime read FCREATED_AT write FCREATED_AT;
    [Campo('UPDATED_AT')]
    property UPDATED_AT: TDateTime read FUPDATED_AT write FUPDATED_AT;
  end;

var
  LProduto: TProduto;
  LContext: iSimpleSkillContext;
  LRunner: TSimpleSkillRunner;
begin
  try
    Writeln('=== SimpleORM Built-in Skills Demo ===');
    Writeln;

    { --- TSkillTimestamp --- }
    Writeln('1. TSkillTimestamp');
    LProduto := TProduto.Create;
    try
      LProduto.NOME := 'Notebook';
      LProduto.PRECO := 3500.00;

      LContext := TSimpleSkillContext.New(nil, nil, nil, 'PRODUTO', 'INSERT');
      LRunner := TSimpleSkillRunner.New;
      try
        LRunner.Add(TSkillTimestamp.New('CREATED_AT', srBeforeInsert));
        LRunner.RunBefore(LProduto, LContext, srBeforeInsert);
        Writeln('   CREATED_AT preenchido: ', DateTimeToStr(LProduto.CREATED_AT));
      finally
        FreeAndNil(LRunner);
      end;
    finally
      LProduto.Free;
    end;
    Writeln;

    { --- TSkillValidate --- }
    Writeln('2. TSkillValidate');
    LProduto := TProduto.Create;
    try
      LProduto.NOME := '';
      LProduto.PRECO := 0;

      LContext := TSimpleSkillContext.New(nil, nil, nil, 'PRODUTO', 'INSERT');
      LRunner := TSimpleSkillRunner.New;
      try
        LRunner.Add(TSkillValidate.New(srBeforeInsert));
        try
          LRunner.RunBefore(LProduto, LContext, srBeforeInsert);
          Writeln('   Validacao OK');
        except
          on E: Exception do
            Writeln('   Validacao falhou (esperado): ', E.Message);
        end;
      finally
        FreeAndNil(LRunner);
      end;
    finally
      LProduto.Free;
    end;
    Writeln;

    { --- TSkillLog --- }
    Writeln('3. TSkillLog');
    LProduto := TProduto.Create;
    try
      LProduto.NOME := 'Mouse';
      LContext := TSimpleSkillContext.New(nil, nil, nil, 'PRODUTO', 'INSERT');
      LRunner := TSimpleSkillRunner.New;
      try
        LRunner.Add(TSkillLog.New('Demo', srAfterInsert));
        LRunner.RunAfter(LProduto, LContext, srAfterInsert);
        Writeln('   Log executado com sucesso');
      finally
        FreeAndNil(LRunner);
      end;
    finally
      LProduto.Free;
    end;
    Writeln;

    { --- TSkillNotify --- }
    Writeln('4. TSkillNotify');
    LProduto := TProduto.Create;
    try
      LProduto.NOME := 'Teclado';
      LContext := TSimpleSkillContext.New(nil, nil, nil, 'PRODUTO', 'INSERT');
      LRunner := TSimpleSkillRunner.New;
      try
        LRunner.Add(TSkillNotify.New(
          procedure(aObj: TObject)
          begin
            Writeln('   Callback disparado para: ', TProduto(aObj).NOME);
          end, srAfterInsert));
        LRunner.RunAfter(LProduto, LContext, srAfterInsert);
      finally
        FreeAndNil(LRunner);
      end;
    finally
      LProduto.Free;
    end;
    Writeln;

    Writeln('=== Fim do Demo ===');
    Writeln;
    Writeln('Nota: TSkillGuardDelete, TSkillHistory e TSkillWebhook requerem');
    Writeln('conexao com banco ou servidor HTTP para demonstracao completa.');
    Writeln('Consulte a documentacao para exemplos de uso.');
  except
    on E: Exception do
      Writeln('Erro: ', E.ClassName, ': ', E.Message);
  end;
  Readln;
end.
