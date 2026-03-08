unit SimpleAttributes;

interface

uses
  System.RTTI, System.Variants, System.Classes;

type
  Tabela = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(aName: string);
    property Name: string read FName;
  end;

  Campo = class(TCustomAttribute)
  private
    FName: string;
  public
    Constructor Create(aName: string);
    property Name: string read FName;
  end;

  PK = class(TCustomAttribute)
  end;

  FK = class(TCustomAttribute)
  end;

  NotNull = class(TCustomAttribute)
  end;

  NotZero = class(TCustomAttribute)
  end;

  Ignore = class(TCustomAttribute)
  end;

  AutoInc = class(TCustomAttribute)
  end;

  NumberOnly = class(TCustomAttribute)
  end;

  Bind = class(TCustomAttribute)
  private
    FField: String;
    procedure SetField(const Value: String);
  public
    constructor Create (aField : String);
    property Field : String read FField write SetField;
  end;

  Display = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const aName: string);
    property Name: string read FName write FName;
  end;

  Format = class(TCustomAttribute)
  private
    FMaxSize: integer;
    FPrecision: integer;
    FMask: string;
    FMinSize: integer;
  public
    property MaxSize: integer read FMaxSize write FMaxSize;
    property MinSize: integer read FMinSize write FMinSize;
    property Precision: integer read FPrecision write FPrecision;
    property Mask: string read FMask write FMask;
    function GetNumericMask: string;
    constructor Create(const aSize: Integer; const aPrecision: integer = 0); overload;
    constructor Create(const aMask: string); overload;
    constructor Create(const aRange: array of Integer); overload;
  end;

  Relationship = class abstract(TCustomAttribute)
  private
    FEntityName: string;
    FForeignKey: string;
  public
    constructor Create(const aEntityName: string); overload;
    constructor Create(const aEntityName, aForeignKey: string); overload;
    property EntityName: string read FEntityName write FEntityName;
    property ForeignKey: string read FForeignKey write FForeignKey;
  end;

  HasOne = class(Relationship)
  end;

  BelongsTo = class(Relationship)
  end;
  
  HasMany = class(Relationship)
  end;

  BelongsToMany = class(Relationship)
  end;

  SoftDelete = class(TCustomAttribute)
  private
    FFieldName: string;
  public
    constructor Create(const aFieldName: string);
    property FieldName: string read FFieldName;
  end;

  Enumerator = class(TCustomAttribute)
  private
    FTipo: string;
  public
    Constructor Create(aTipo: string);
    property Tipo: string read FTipo;
  end;

  Email = class(TCustomAttribute)
  end;

  Uuid = class(TCustomAttribute)
  end;

  MinValue = class(TCustomAttribute)
  private
    FValue: Double;
  public
    constructor Create(aValue: Double);
    property Value: Double read FValue;
  end;

  MaxValue = class(TCustomAttribute)
  private
    FValue: Double;
  public
    constructor Create(aValue: Double);
    property Value: Double read FValue;
  end;

  Regex = class(TCustomAttribute)
  private
    FPattern: string;
    FMessage: string;
  public
    constructor Create(const aPattern: string; const aMessage: string = '');
    property Pattern: string read FPattern;
    property Message: string read FMessage;
  end;

  IgnoreUpdate = class(TCustomAttribute)
  end;

  IgnoreJSON = class(TCustomAttribute)
  end;

  JSONBase64 = class(TCustomAttribute)
  end;

implementation


{ Bind }

constructor Bind.Create(aField: String);
begin
  FField := aField;
end;

procedure Bind.SetField(const Value: String);
begin
  FField := Value;
end;

{ Tabela }

constructor Tabela.Create(aName: string);
begin
  FName := aName;
end;

{ Campo }

constructor Campo.Create(aName: string);
begin
  FName := aName;
end;

{ Display }

constructor Display.Create(const aName: string);
begin
  FName := aName;
end;

{ Formato }

constructor Format.Create(const aSize, aPrecision: integer);
begin
  FMaxSize := aSize;
  FPrecision := aPrecision;
end;

constructor Format.Create(const aMask: string);
begin
  FMask := aMask;
end;

constructor Format.Create(const aRange: array of Integer);
begin
  FMinSize := aRange[0];
  FMaxSize := aRange[High(aRange)];
end;

function Format.GetNumericMask: string;
var
  sTamanho, sPrecisao: string;
begin
  sTamanho := StringOfChar('0', FMaxSize - FPrecision);
  sPrecisao := StringOfChar('0', FPrecision);

  Result := sTamanho + '.' + sPrecisao;
end;

{ Relationship }

constructor Relationship.Create(const aEntityName: string);
begin
  FEntityName := aEntityName;
  FForeignKey := '';
end;

constructor Relationship.Create(const aEntityName, aForeignKey: string);
begin
  FEntityName := aEntityName;
  FForeignKey := aForeignKey;
end;

{ SoftDelete }

constructor SoftDelete.Create(const aFieldName: string);
begin
  FFieldName := aFieldName;
end;

{ Enumerator }

constructor Enumerator.Create(aTipo: string);
begin
  FTipo := aTipo;
end;

{ MinValue }

constructor MinValue.Create(aValue: Double);
begin
  FValue := aValue;
end;

{ MaxValue }

constructor MaxValue.Create(aValue: Double);
begin
  FValue := aValue;
end;

{ Regex }

constructor Regex.Create(const aPattern: string; const aMessage: string = '');
begin
  FPattern := aPattern;
  FMessage := aMessage;
end;

end.
