unit SimpleInterface;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Data.DB,
  System.TypInfo,
  {$IFNDEF CONSOLE}
    {$IFDEF FMX}
      FMX.Forms,
    {$ELSE}
      Vcl.Forms,
    {$ENDIF}
  {$ENDIF}
  System.SysUtils,
  SimpleTypes,
  SimpleLogger;
type
  TSimpleCallback = reference to procedure(aEntity: TObject);

  iSimpleDAOSQLAttribute<T : class> = interface;

  iSimpleDAO<T : class> = interface
    ['{19261B52-6122-4C41-9DDE-D3A1247CC461}']
    {$IFNDEF CONSOLE}
    function Insert: iSimpleDAO<T>; overload;
    function Update : iSimpleDAO<T>; overload;
    function Delete : iSimpleDAO<T>; overload;
    {$ENDIF}
    function Insert(aValue : T) : iSimpleDAO<T>; overload;
    function Update(aValue : T) : iSimpleDAO<T>; overload;
    function Delete(aValue : T) : iSimpleDAO<T>; overload;
    function LastID : iSimpleDAO<T>;
    function LastRecord : iSimpleDAO<T>;
    function ForceDelete(aValue: T): iSimpleDAO<T>;
    function Delete(aField : String; aValue : String) : iSimpleDAO<T>; overload;
    function DataSource( aDataSource : TDataSource) : iSimpleDAO<T>;
    function Find(aBindList : Boolean = True) : iSimpleDAO<T>; overload;
    function Find(var aList : TObjectList<T>) : iSimpleDAO<T> ; overload;
    function Find(aId : Integer) : T; overload;
    function Find(aKey : String; aValue : Variant) : iSimpleDAO<T>; overload;
    function InsertBatch(aList: TObjectList<T>): iSimpleDAO<T>;
    function UpdateBatch(aList: TObjectList<T>): iSimpleDAO<T>;
    function DeleteBatch(aList: TObjectList<T>): iSimpleDAO<T>;
    function SQL : iSimpleDAOSQLAttribute<T>;
    function Count: Integer;
    function Sum(const aField: String): Double;
    function Min(const aField: String): Double;
    function Max(const aField: String): Double;
    function Avg(const aField: String): Double;
    function RegisterScope(const aName, aWhere: String): iSimpleDAO<T>;
    function Scope(const aName: String): iSimpleDAO<T>;
    function ClearScopes: iSimpleDAO<T>;
    function FindOrCreate(const aField: String; aValue: Variant; aEntity: T): T;
    function UpdateOrCreate(const aField: String; aValue: Variant; aEntity: T): T;
    function Logger(aLogger: iSimpleQueryLogger): iSimpleDAO<T>;
    function AIClient(aValue: iSimpleAIClient): iSimpleDAO<T>;
    function OnBeforeInsert(aCallback: TSimpleCallback): iSimpleDAO<T>;
    function OnAfterInsert(aCallback: TSimpleCallback): iSimpleDAO<T>;
    function OnBeforeUpdate(aCallback: TSimpleCallback): iSimpleDAO<T>;
    function OnAfterUpdate(aCallback: TSimpleCallback): iSimpleDAO<T>;
    function OnBeforeDelete(aCallback: TSimpleCallback): iSimpleDAO<T>;
    function OnAfterDelete(aCallback: TSimpleCallback): iSimpleDAO<T>;
    function RawSQL(const aSQL: String): iSimpleDAO<T>;
    function RawSQLWithParams(const aSQL: String; const aParamNames: array of String; const aParamValues: array of Variant): iSimpleDAO<T>;
    function FindRaw: TObjectList<T>;
    function ExecRawSQL(const aSQL: String): iSimpleDAO<T>;
    function EnableCache: iSimpleDAO<T>;
    function DisableCache: iSimpleDAO<T>;
    function ClearCache: iSimpleDAO<T>;
    {$IFNDEF CONSOLE}
    function BindForm(aForm : TForm)  : iSimpleDAO<T>;
    {$ENDIF}
  end;

  iSimpleDAOSQLAttribute<T : class> = interface
    ['{5DE6F977-336B-4142-ABD1-EB0173FFF71F}']
    function Fields (aSQL : String) : iSimpleDAOSQLAttribute<T>; overload;
    function Where (aSQL : String) : iSimpleDAOSQLAttribute<T>; overload;
    function OrderBy (aSQL : String) : iSimpleDAOSQLAttribute<T>; overload;
    function GroupBy (aSQL : String) : iSimpleDAOSQLAttribute<T>; overload;
    function Join (aSQL : String) : iSimpleDAOSQLAttribute<T>; overload;
    function Join : String; overload;
    function Fields : String; overload;
    function Where : String; overload;
    function OrderBy : String; overload;
    function GroupBy : String; overload;
    function Clear : iSimpleDAOSQLAttribute<T>;
    function Skip(aValue: Integer): iSimpleDAOSQLAttribute<T>;
    function Take(aValue: Integer): iSimpleDAOSQLAttribute<T>;
    function GetSkip: Integer;
    function GetTake: Integer;
    function &End : iSimpleDAO<T>;
  end;

  iSimpleRTTI<T : class> = interface
    ['{EEC49F47-24AC-4D82-9BEE-C259330A8993}']
    function TableName(var aTableName: String): ISimpleRTTI<T>;
    function ClassName (var aClassName : String) : iSimpleRTTI<T>;
    function DictionaryFields(var aDictionary : TDictionary<string, variant>) : iSimpleRTTI<T>;
    function DictionaryTypeFields(var aDictionary: TDictionary<string, TFieldType>): iSimpleRTTI<T>;
    function ListFields (var List : TList<String>) : iSimpleRTTI<T>;
    function Update (var aUpdate : String) : iSimpleRTTI<T>;
    function Where (var aWhere : String) : iSimpleRTTI<T>;
    function Fields (var aFields : String) : iSimpleRTTI<T>;
    function FieldsInsert (var aFields : String) : iSimpleRTTI<T>;
    function Param (var aParam : String) : iSimpleRTTI<T>;
    function DataSetToEntityList (aDataSet : TDataSet; var aList : TObjectList<T>) : iSimpleRTTI<T>;
    function DataSetToEntity (aDataSet : TDataSet; var aEntity : T) : iSimpleRTTI<T>;
    function PrimaryKey(var aPK : String) : iSimpleRTTI<T>;
    function SoftDeleteField(var aFieldName: string): iSimpleRTTI<T>;
    {$IFNDEF CONSOLE}
    function BindClassToForm (aForm : TForm;  const aEntity : T) : iSimpleRTTI<T>;
    function BindFormToClass (aForm : TForm; var aEntity : T) : iSimpleRTTI<T>;
    {$ENDIF}
  end;

  iSimpleSQL<T> = interface
    ['{1590A7C6-6E32-4579-9E60-38C966C1EB49}']
    function Insert (var aSQL : String) : iSimpleSQL<T>;
    function Update (var aSQL : String) : iSimpleSQL<T>;
    function Delete (var aSQL : String) : iSimpleSQL<T>;
    function Select (var aSQL : String) : iSimpleSQL<T>;
    function SelectId(var aSQL: String): iSimpleSQL<T>;
    function Fields (aSQL : String) : iSimpleSQL<T>;
    function Where (aSQL : String) : iSimpleSQL<T>;
    function OrderBy (aSQL : String) : iSimpleSQL<T>;
    function GroupBy (aSQL : String) : iSimpleSQL<T>;
    function Join (aSQL : String) : iSimpleSQL<T>;
    function LastID (var aSQL : String) : iSimpleSQL<T>;
    function LastRecord (var aSQL : String) : iSimpleSQL<T>;
    function Count(var aSQL: String): iSimpleSQL<T>;
    function Aggregate(var aSQL: String; const aFunction, aField: String): iSimpleSQL<T>;
    function Skip(aValue: Integer): iSimpleSQL<T>;
    function Take(aValue: Integer): iSimpleSQL<T>;
    function DatabaseType(aType: TSQLType): iSimpleSQL<T>;
  end;

  iSimpleAIClient = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function Complete(const aPrompt: String): String;
    function Model(const aValue: String): iSimpleAIClient;
    function MaxTokens(aValue: Integer): iSimpleAIClient;
    function Temperature(aValue: Double): iSimpleAIClient;
  end;

  iSimpleQuery = interface
    ['{6DCCA942-736D-4C66-AC9B-94151F14853A}']
    function SQL : TStrings;
    function Params : TParams;
    function ExecSQL : iSimpleQuery;
    function DataSet : TDataSet;
    function Open(aSQL : String) : iSimpleQuery; overload;
    function Open : iSimpleQuery; overload;
    function StartTransaction: iSimpleQuery;
    function Commit: iSimpleQuery;
    function Rollback: iSimpleQuery;
    function &EndTransaction: iSimpleQuery;
    function InTransaction: Boolean;
    function SQLType: TSQLType;
    function RowsAffected: Integer;
  end;



implementation

end.
