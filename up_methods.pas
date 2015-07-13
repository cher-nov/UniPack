unit up_methods;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface {════════════════════════════════════════════════════════════════════}

uses
  Classes, SysUtils, dynlibs;

const
  UP_NOERR = 0;
  UP_NAMELEN = 4;

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

  TUniMethods = class of TUniMethod;

implementation {═══════════════════════════════════════════════════════════════}

uses StrUtils;

{ –=────────────────────────────────────────────────────────────────────────=– }

constructor TUniMethod.Create( ALibFile: String );
var
  NameInt : Integer;
  MGetName : TUniPackGetName;
  MGetVersion : TUniPackGetVersion;
begin
  FLibFile := ExtractFileName( ALibFile );
  FLibrary := LoadLibrary( ALibFile );

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
end;

destructor TUniMethod.Destroy();
begin
  UnloadLibrary( FLibrary );
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

end.

