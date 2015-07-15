unit up_methods;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface {════════════════════════════════════════════════════════════════════}

uses
  Classes, SysUtils, dynlibs;

const
  UP_NOERR = 0;
  UP_NAMELEN = SizeOf(LongInt);

{ –=────────────────────────────────────────────────────────────────────────=– }
type { Auxiliary types for TUniMethod ════════════════════════════════════════ }

  TUniMethodName = String[UP_NAMELEN];

  TUniPackGetName =
    function(): LongInt; cdecl;
  TUniPackGetVersion =
    function(): Integer; cdecl;
  TUniPackCompress =
    function( data: Pointer; size: Integer ): Pointer; cdecl;
  TUniPackCompSize =
    function(): Integer; cdecl;
  TUniPackDecompress =
    function( data: Pointer; size: Integer; outsize: Integer ): Pointer; cdecl;
  TUniPackGetErr =
    function(): Integer; cdecl;
  TUniPackErrStr =
    function( errlev: Integer ): PChar; cdecl;

{ –=────────────────────────────────────────────────────────────────────────=– }
type { TUniMethod - UniPack method library ═══════════════════════════════════ }

  TUniMethod = class
  strict private
    //methods
    MCompress : TUniPackCompress;
    MCompSize : TUniPackCompSize;
    MDecompress : TUniPackDecompress;
    MGetErr : TUniPackGetErr;
    MErrStr : TUniPackErrStr;
    //variables
    FLibrary : TLibHandle;
    FLibFile : String;
    FName : TUniMethodName;
    FVersion : Integer;
  public
    constructor Create( ALibFile: String );
    destructor Destroy(); override;

    property Compress: TUniPackCompress read MCompress;
    property CompSize: TUniPackCompSize read MCompSize;
    property Decompress: TUniPackDecompress read MDecompress;
    property GetErr: TUniPackGetErr read MGetErr;
    property ErrStr: TUniPackErrStr read MErrStr;

    property LibFile: String read FLibFile;
    property Name: TUniMethodName read FName;
    property Version: Integer read FVersion;
  end;

{ –=────────────────────────────────────────────────────────────────────────=– }

var
  UPMethods: TList;

function GetMethod( AName: TUniMethodName ): TUniMethod;
function LoadMethodLib( ALibFile: String ): Boolean;
procedure UnloadAllMethods();

implementation {═══════════════════════════════════════════════════════════════}

uses StrUtils;

var
  LoadError : Boolean = False;

{ –=────────────────────────────────────────────────────────────────────────=– }

function GetMethod( AName: TUniMethodName ): TUniMethod;
var
  iter: TListEnumerator;
begin
  iter := UPMethods.GetEnumerator();
  Result := nil;
  while iter.MoveNext() and ( Result = nil ) do begin
    Result := TUniMethod( iter.Current );
    if ( Result.Name <> AName ) then Result := nil;
  end;
  iter.Destroy();
end;

function LoadMethodLib( ALibFile: String ): Boolean;
var
  load: TUniMethod;
begin
  load := TUniMethod.Create( ALibFile );
  Result := True;

  if LoadError                         then Result := False else
  if ( GetMethod( load.Name ) <> nil ) then Result := False;

  if Result then
    UPMethods.Add( load )
  else
    load.Destroy();
end;

procedure UnloadAllMethods();
var
  i : Integer;
begin
  for i := 0 to UPMethods.Count-1 do
    TUniMethod( UPMethods[i] ).Destroy();
  UPMethods.Clear();
end;

{ ═ TUniMethod ─────────────────────────────────────────────────────────────── }

constructor TUniMethod.Create( ALibFile: String );
var
  NameInt : LongInt;
  MGetName : TUniPackGetName;
  MGetVersion : TUniPackGetVersion;
begin
  FLibFile := ExtractFileName( ALibFile );
  FLibrary := LoadLibrary( ALibFile );

  if ( FLibrary = NilHandle ) then begin
    LoadError := True;
    Exit;
  end;

  MCompress := TUniPackCompress( GetProcedureAddress( FLibrary, 'compress' ) );
  MCompSize := TUniPackCompSize( GetProcedureAddress( FLibrary, 'compsize' ) );
  MDecompress := TUniPackDecompress( GetProcedureAddress( FLibrary, 'decompress' ) );
  MGetErr := TUniPackGetErr( GetProcedureAddress( FLibrary, 'get_err' ) );
  MErrStr := TUniPackErrStr( GetProcedureAddress( FLibrary, 'err_str' ) );

  MGetName := TUniPackGetName( GetProcedureAddress( FLibrary, 'get_name' ) );
  NameInt := MGetName();
  FName := ReverseString( LeftStr( PChar(@NameInt), UP_NAMELEN ) );
  
  MGetVersion := TUniPackGetVersion( GetProcedureAddress( FLibrary, 'get_version' ) );
  FVersion := MGetVersion();

  LoadError := False;
end;

destructor TUniMethod.Destroy();
begin
  UnloadLibrary( FLibrary );
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

initialization {═══════════════════════════════════════════════════════════════}

UPMethods := TList.Create();

finalization {═════════════════════════════════════════════════════════════════}

UnloadAllMethods();
UPMethods.Destroy();

end.

