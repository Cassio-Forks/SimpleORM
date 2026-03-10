program SimpleORMAgents;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  SimpleAttributes in '..\..\src\SimpleAttributes.pas',
  SimpleInterface in '..\..\src\SimpleInterface.pas',
  SimpleRTTIHelper in '..\..\src\SimpleRTTIHelper.pas',
  SimpleTypes in '..\..\src\SimpleTypes.pas',
  SimpleLogger in '..\..\src\SimpleLogger.pas',
  SimpleRules in '..\..\src\SimpleRules.pas',
  SimpleSkill in '..\..\src\SimpleSkill.pas',
  SimpleAgent in '..\..\src\SimpleAgent.pas',
  SimpleAIAttributes in '..\..\src\SimpleAIAttributes.pas';

type
  { Entidade com Rules declarativas }
  [Tabela('PEDIDOS')]
  [Rule('VALOR > 0', raBeforeInsert, 'Valor do pedido deve ser positivo')]
  [Rule('QUANTIDADE > 0', raBeforeInsert, 'Quantidade deve ser maior que zero')]
  [Rule('STATUS <> ''CANCELADO''', raBeforeUpdate, 'Pedido cancelado nao pode ser alterado')]
  TPedido = class
  private
    FID: Integer;
    FVALOR: Double;
    FQUANTIDADE: Integer;
    FSTATUS: String;
    FCLIENTE: String;
    procedure SetID(const Value: Integer);
    procedure SetVALOR(const Value: Double);
    procedure SetQUANTIDADE(const Value: Integer);
    procedure SetSTATUS(const Value: String);
    procedure SetCLIENTE(const Value: String);
  public
    constructor Create;
    destructor Destroy; override;
  published
    [Campo('ID'), PK, AutoInc]
    property ID: Integer read FID write SetID;
    [Campo('VALOR')]
    property VALOR: Double read FVALOR write SetVALOR;
    [Campo('QUANTIDADE')]
    property QUANTIDADE: Integer read FQUANTIDADE write SetQUANTIDADE;
    [Campo('STATUS')]
    property STATUS: String read FSTATUS write SetSTATUS;
    [Campo('CLIENTE')]
    property CLIENTE: String read FCLIENTE write SetCLIENTE;
  end;

{ TPedido }

constructor TPedido.Create;
begin
  FID := 0;
  FVALOR := 0;
  FQUANTIDADE := 0;
  FSTATUS := '';
  FCLIENTE := '';
end;

destructor TPedido.Destroy;
begin
  inherited;
end;

procedure TPedido.SetID(const Value: Integer);
begin
  FID := Value;
end;

procedure TPedido.SetVALOR(const Value: Double);
begin
  FVALOR := Value;
end;

procedure TPedido.SetQUANTIDADE(const Value: Integer);
begin
  FQUANTIDADE := Value;
end;

procedure TPedido.SetSTATUS(const Value: String);
begin
  FSTATUS := Value;
end;

procedure TPedido.SetCLIENTE(const Value: String);
begin
  FCLIENTE := Value;
end;

{ Main }

var
  LRuleEngine: TSimpleRuleEngine;
  LSkillRunner: TSimpleSkillRunner;
  LAgent: TSimpleAgent;
  LSkillContext: iSimpleSkillContext;
  LPedido: TPedido;
  LNotificado: Boolean;
begin
  try
    Writeln('=== SimpleORM Agents, Skills & Rules Demo ===');
    Writeln('');

    // -------------------------------------------------------
    // 1. RULES — Regras declarativas na entidade
    // -------------------------------------------------------
    Writeln('--- 1. RULES ---');
    Writeln('');

    LRuleEngine := TSimpleRuleEngine.New;
    LPedido := TPedido.Create;
    try
      // Pedido valido
      LPedido.VALOR := 150;
      LPedido.QUANTIDADE := 3;
      LPedido.STATUS := 'ATIVO';
      LPedido.CLIENTE := 'Joao Silva';

      Writeln('Testando pedido valido (VALOR=150, QTD=3)...');
      LRuleEngine.Evaluate(LPedido, raBeforeInsert);
      Writeln('  Resultado: APROVADO - todas as regras passaram');
      Writeln('');

      // Pedido com valor negativo
      LPedido.VALOR := -10;
      Writeln('Testando pedido invalido (VALOR=-10)...');
      try
        LRuleEngine.Evaluate(LPedido, raBeforeInsert);
      except
        on E: ESimpleRuleViolation do
          Writeln('  Resultado: BLOQUEADO - ', E.Message);
      end;
      Writeln('');

      // Pedido cancelado tentando update
      LPedido.VALOR := 100;
      LPedido.STATUS := 'CANCELADO';
      Writeln('Testando update em pedido cancelado...');
      try
        LRuleEngine.Evaluate(LPedido, raBeforeUpdate);
      except
        on E: ESimpleRuleViolation do
          Writeln('  Resultado: BLOQUEADO - ', E.Message);
      end;
    finally
      FreeAndNil(LPedido);
      FreeAndNil(LRuleEngine);
    end;

    Writeln('');

    // -------------------------------------------------------
    // 2. SKILLS — Plugins reutilizaveis
    // -------------------------------------------------------
    Writeln('--- 2. SKILLS ---');
    Writeln('');

    LNotificado := False;
    LSkillRunner := TSimpleSkillRunner.New;
    LPedido := TPedido.Create;
    try
      LPedido.VALOR := 500;
      LPedido.CLIENTE := 'Maria Santos';

      // Adicionar skills
      LSkillRunner.Add(TSkillLog.New('DEMO', srAfterInsert));
      LSkillRunner.Add(TSkillNotify.New(
        procedure(aObj: TObject)
        begin
          LNotificado := True;
          Writeln('  [Notify] Entidade processada!');
        end, srAfterInsert));

      LSkillContext := TSimpleSkillContext.New(nil, nil, nil, 'PEDIDOS', 'INSERT');

      Writeln('Executando Skills After Insert...');
      LSkillRunner.RunAfter(LPedido, LSkillContext, srAfterInsert);
      Writeln('  Notificado: ', BoolToStr(LNotificado, True));
    finally
      FreeAndNil(LPedido);
      FreeAndNil(LSkillRunner);
    end;

    Writeln('');

    // -------------------------------------------------------
    // 3. AGENTS — Modo reativo
    // -------------------------------------------------------
    Writeln('--- 3. AGENTS (Reativo) ---');
    Writeln('');

    LAgent := TSimpleAgent.New;
    LPedido := TPedido.Create;
    try
      // Configurar reacao: pedidos acima de 1000
      LAgent.When(TPedido, aoAfterInsert)
        .Condition(function(aEntity: TObject): Boolean
          begin
            Result := TPedido(aEntity).VALOR > 1000;
          end)
        .Execute(TSkillNotify.New(
          procedure(aObj: TObject)
          begin
            Writeln('  [Agent] ALERTA: Pedido de alto valor detectado! Valor: ',
              FormatFloat('#,##0.00', TPedido(aObj).VALOR));
          end))
        .Execute(TSkillLog.New('alto-valor'));

      // Pedido normal
      LPedido.VALOR := 200;
      Writeln('Pedido de R$ 200,00 inserido...');
      LAgent.React(LPedido, aoAfterInsert);
      Writeln('  (nenhuma reacao - abaixo do limite)');
      Writeln('');

      // Pedido alto valor
      LPedido.VALOR := 5000;
      Writeln('Pedido de R$ 5.000,00 inserido...');
      LAgent.React(LPedido, aoAfterInsert);
    finally
      FreeAndNil(LPedido);
      FreeAndNil(LAgent);
    end;

    Writeln('');

    // -------------------------------------------------------
    // Uso integrado no DAO
    // -------------------------------------------------------
    Writeln('--- Uso integrado no TSimpleDAO ---');
    Writeln('');
    Writeln('  DAOPedido := TSimpleDAO<TPedido>');
    Writeln('    .New(Conn)');
    Writeln('    .AIClient(TSimpleAIClient.New(''claude'', ''key''))');
    Writeln('    .Skill(TSkillLog.New(''app'', srAfterInsert))');
    Writeln('    .Skill(TSkillAudit.New(''AUDIT_LOG'', srAfterInsert))');
    Writeln('    .Agent(TAgentVendas.New);');
    Writeln('');
    Writeln('  DAOPedido.Insert(Pedido);');
    Writeln('  // Pipeline: Rules -> AI -> Skills(Before) -> SQL -> Skills(After) -> Agent');

    Writeln('');
    Writeln('=== Demo finalizada com sucesso ===');
  except
    on E: Exception do
      Writeln('Erro: ', E.Message);
  end;

  Writeln('');
  Writeln('Pressione ENTER para sair...');
  Readln;
end.
