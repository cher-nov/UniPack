unit up_methods;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface {════════════════════════════════════════════════════════════════════}

uses
  Classes, SysUtils, dynlibs;

const
  UP_NOERR = 0;
  UP_NAMELEN = SizeOf(LongWord);

{ –=────────────────────────────────────────────────────────────────────────=– }
type { Auxiliary types for TUniMethod ════════════════════════════════════════ }

  TUniMethodName = packed array[0..UP_NAMELEN-1] of Char;
  TUniMethodWord = LongWord;

  TUniPackGetName =
    function(): TUniMethodWord; cdecl;
  TUniPackGetVersion =
    function(): Integer; cdecl;
  TUniPackCompress =
    function( data: Pointer; size: SizeUInt ): Pointer; cdecl;
  TUniPackDecompress =
    function( data: Pointer; size: SizeUInt; outsize: SizeUInt ): Pointer; cdecl;
  TUniPackCompSize =
    function(): SizeUInt; cdecl;
  TUniPackGetErr =
    function(): Integer; cdecl;
  TUniPackErrStr =
    function( errlev: Integer ): PChar; cdecl;
  TUniPackReallocMem =
    function( ptr: Pointer; size: SizeUInt ): Pointer; cdecl;
  TUniPackFreeMem =
    procedure( ptr: Pointer ); cdecl;

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
    MReallocMem : TUniPackReallocMem;
    MFreeMem : TUniPackFreeMem;
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
    property ReallocMem: TUniPackReallocMem read MReallocMem;
    property FreeMem: TUniPackFreeMem read MFreeMem;

    property LibFile: String read FLibFile;
    property Name: TUniMethodName read FName;
    property Version: Integer read FVersion;
  end;

{ –=────────────────────────────────────────────────────────────────────────=– }

var
  UPMethods: TList;
  UPLoadError : Boolean = False;

function WordToName( AWord: TUniMethodWord ): TUniMethodName;
function GetMethod( AName: TUniMethodName ): TUniMethod;
function LoadMethodLib( ALibFile: String ): Boolean;
procedure UnloadAllMethods();

implementation {═══════════════════════════════════════════════════════════════}

uses StrUtils;

{ –=────────────────────────────────────────────────────────────────────────=– }

function WordToName( AWord: TUniMethodWord ): TUniMethodName;
begin
  Result := LeftStr( PChar(@AWord), UP_NAMELEN );
end;

function GetMethod( AName: TUniMethodName ): TUniMethod;
var
  i : Integer;
begin
  Result := nil;
  for i := 0 to UPMethods.Count-1 do begin
    if Assigned(Result) then Break;
    Result := TUniMethod( UPMethods[i] );
    if ( Result.Name <> AName ) then Result := nil;
  end;
end;

function LoadMethodLib( ALibFile: String ): Boolean;
var
  load: TUniMethod;
begin
  load := TUniMethod.Create( ALibFile );
  Result := True;

  if UPLoadError                       then Result := False else
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
  MGetName : TUniPackGetName;
  MGetVersion : TUniPackGetVersion;
begin
  FLibFile := ExtractFileName( ALibFile );
  FLibrary := LoadLibrary( ALibFile );

  if ( FLibrary = NilHandle ) then begin
    UPLoadError := True;
    Exit;
  end;

  MGetName := TUniPackGetName( GetProcedureAddress( FLibrary, 'get_name' ) );
  if ( MGetName = nil ) then begin
    UPLoadError := True;
    Exit;
  end;

  FName := ReverseString( WordToName( MGetName() ) );

  MCompress := TUniPackCompress( GetProcedureAddress( FLibrary, 'compress' ) );
  MDecompress := TUniPackDecompress( GetProcedureAddress( FLibrary, 'decompress' ) );
  MCompSize := TUniPackCompSize( GetProcedureAddress( FLibrary, 'compsize' ) );

  //alternative syntax for compress() and decompress()
  if ( MCompress = nil ) then
    MCompress := TUniPackCompress( GetProcedureAddress( FLibrary, 'up_pack' ) );
  if ( MDecompress = nil ) then
    MDecompress := TUniPackDecompress( GetProcedureAddress( FLibrary, 'up_unpack' ) );

  MGetErr := TUniPackGetErr( GetProcedureAddress( FLibrary, 'get_err' ) );
  MErrStr := TUniPackErrStr( GetProcedureAddress( FLibrary, 'err_str' ) );

  MReallocMem := TUniPackReallocMem( GetProcedureAddress( FLibrary, 'realloc_mem' ) );
  MFreeMem := TUniPackFreeMem( GetProcedureAddress( FLibrary, 'free_mem' ) );

  MGetVersion := TUniPackGetVersion( GetProcedureAddress( FLibrary, 'get_version' ) );
  FVersion := MGetVersion();

  UPLoadError := False;
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

