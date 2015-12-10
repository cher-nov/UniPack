unit up_methods;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface {════════════════════════════════════════════════════════════════════}

uses
  Classes, SysUtils, dynlibs;

{ –=────────────────────────────────────────────────────────────────────────=– }
type { Auxiliary types for TUniPackMethod ════════════════════════════════════ }

  uplib_MethodName = packed array[0..3] of Char;

  upfunc_GetName =
    function(): PChar; cdecl;
  upfunc_GetVersion =
    function(): Integer; cdecl;
  upfunc_LastError =
    function(): PChar; cdecl;
  upfunc_InitPack =
    procedure( pack_sz: QWord ); cdecl;
  upfunc_PackChunk =
    function( chunk: Pointer; chunk_sz: SizeUInt; outbuf: Pointer;
      outbuf_sz: SizeUInt ): SizeUInt; cdecl;
  upfunc_EndPack =
    procedure(); cdecl;
  upfunc_InitUnpack =
    procedure( unpack_sz: QWord ); cdecl;
  upfunc_UnpackChunk =
    function( chunk: Pointer; chunk_sz: SizeUInt; outbuf: Pointer;
      outbuf_sz: SizeUInt ): SizeUInt; cdecl;
  upfunc_EndUnpack =
    procedure(); cdecl;

{ –=────────────────────────────────────────────────────────────────────────=– }
type { TUniPackMethod - UniPack method library ═══════════════════════════════ }

  TUniPackMethod = class
  strict private
    //methods
    MLastError : upfunc_LastError;
    MInitPack : upfunc_InitPack;
    MPackChunk : upfunc_PackChunk;
    MEndPack : upfunc_EndPack;
    MInitUnpack : upfunc_InitUnpack;
    MUnpackChunk : upfunc_UnpackChunk;
    MEndUnpack : upfunc_EndUnpack;
    //variables
    FIndex : Integer;
    FLibrary : TLibHandle;
    FLibFile : String;
    FName : uplib_MethodName;
    FVersion : Integer;
    FCanPack : Boolean;
    FCanUnpack : Boolean;

    function LoadLib( const ALibFile: String ): Boolean;
  public
    class function Load( const ALibFile: String ): Boolean;
    destructor Destroy(); override;
    class function Count(): Integer;
    class function Get( AName: uplib_MethodName ): TUniPackMethod; overload;
    class function Get( AIndex: Integer ): TUniPackMethod; overload;

    property LastError: upfunc_LastError read MLastError;
    property InitPack: upfunc_InitPack read MInitPack;
    property PackChunk: upfunc_PackChunk read MPackChunk;
    property EndPack: upfunc_EndPack read MEndPack;
    property InitUnpack: upfunc_InitUnpack read MInitUnpack;
    property UnpackChunk: upfunc_UnpackChunk read MUnpackChunk;
    property EndUnpack: upfunc_EndUnpack read MEndUnpack;

    property LibFile: String read FLibFile;
    property Name: uplib_MethodName read FName;
    property Version: Integer read FVersion;

    property CanPack: Boolean read FCanPack;
    property CanUnpack: Boolean read FCanUnpack;
  end;


implementation {═══════════════════════════════════════════════════════════════}

const
  UP_NO_INDEX = -1;

var
  upMethods: TList;

{ –=────────────────────────────────────────────────────────────────────────=– }
{ ═ TUniPackMethod ─────────────────────────────────────────────────────────── }

class function TUniPackMethod.Load( const ALibFile: String ): Boolean;
var
  method: TUniPackMethod;
begin
  method := TUniPackMethod.Create();

  Result := method.LoadLib( ALibFile );
  if Result then
    Result := Get( method.FName ) = nil;

  if Result then begin
    method.FIndex := upMethods.Add( method )
  end else begin
    method.FIndex := UP_NO_INDEX;
    method.Destroy();
  end;
end;

destructor TUniPackMethod.Destroy();
begin
  if ( FLibrary <> NilHandle ) then
    UnloadLibrary( FLibrary );
  if ( FIndex <> UP_NO_INDEX ) then
    upMethods.Delete( FIndex );
  inherited Destroy();
end;

class function TUniPackMethod.Count(): Integer;
begin
  Result := upMethods.Count;
end;

class function TUniPackMethod.Get( AName: uplib_MethodName ): TUniPackMethod;
var
  i : Integer;
begin
  Result := nil;
  i := 0;
  while ( Result = nil ) and ( i < upMethods.Count ) do begin
    Result := TUniPackMethod( upMethods[i] );
    if ( Result.Name <> AName ) then Result := nil;
  end;
end;

class function TUniPackMethod.Get( AIndex: Integer ): TUniPackMethod;
begin
  try
    Result := TUniPackMethod( upMethods[AIndex] );
  except
    Result := nil;
  end;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function TUniPackMethod.LoadLib( const ALibFile: String ): Boolean;
var
  MGetName : upfunc_GetName;
  MGetVersion : upfunc_GetVersion;
begin
  FLibFile := ExtractFileName( ALibFile );

  FLibrary := LoadLibrary( ALibFile );
  if ( FLibrary = NilHandle ) then
    Exit( False );

  MGetName := upfunc_GetName( GetProcedureAddress( FLibrary, 'up_info_name' ) );
  MLastError := upfunc_LastError( GetProcedureAddress( FLibrary, 'up_last_error' ) );
  if ( MGetName = nil ) or ( MLastError = nil ) then
    Exit( False );
  FName := uplib_MethodName( MGetName() );

  MInitPack := upfunc_InitPack( GetProcedureAddress( FLibrary, 'up_pack_init' ) );
  MPackChunk := upfunc_PackChunk( GetProcedureAddress( FLibrary, 'up_pack_chunk' ) );
  MEndPack := upfunc_EndPack( GetProcedureAddress( FLibrary, 'up_pack_end' ) );
  FCanPack := Assigned(MInitPack) and Assigned(MPackChunk) and Assigned(MEndPack);

  MInitUnpack := upfunc_InitUnpack( GetProcedureAddress( FLibrary, 'up_unpack_init' ) );
  MUnpackChunk := upfunc_UnpackChunk( GetProcedureAddress( FLibrary, 'up_unpack_chunk' ) );
  MEndUnpack := upfunc_EndUnpack( GetProcedureAddress( FLibrary, 'up_unpack_end' ) );
  FCanUnpack := Assigned(MInitUnpack) and Assigned(MUnpackChunk) and Assigned(MEndUnpack);

  if not FCanPack and not FCanUnpack then
    Exit( False );

  MGetVersion := upfunc_GetVersion( GetProcedureAddress( FLibrary, 'up_info_version' ) );
  if ( MGetVersion <> nil ) then
    FVersion := MGetVersion()
  else
    FVersion := -1;

  Result := True;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure upUnloadAllMethods();
var
  i : Integer;
begin
  for i := 0 to upMethods.Count-1 do
    TUniPackMethod( upMethods[i] ).Destroy();
end;

initialization

  upMethods := TList.Create();

finalization

  upUnloadAllMethods();
  upMethods.Destroy();

end.

