unit up_methods;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface {════════════════════════════════════════════════════════════════════}

uses
  Classes, SysUtils, dynlibs;

{ –=────────────────────────────────────────────────────────────────────────=– }
type { Auxiliary types for TUniPackMethod ════════════════════════════════════ }

  PSizeUInt = ^SizeUInt;
  uplib_MethodName = packed array[0..3] of Char;

  upfunc_GetName =
    function(): PChar; cdecl;
  upfunc_GetVersion =
    function(): Integer; cdecl;
  upfunc_HasError =
    function( ret_code: PInteger = nil ): Boolean; cdecl;
  upfunc_ErrorMsg =
    function( err_code: Integer ): PChar; cdecl;
  upfunc_InitPack =
    procedure( pack_sz: QWord ); cdecl;
  upfunc_PackSetChunk =
    procedure( chunk: Pointer; chunk_sz: SizeUInt ); cdecl;
  upfunc_PackStep =
    function( outbuf: Pointer; outbuf_sz: SizeUInt;
      data_left: PSizeUInt = nil ): SizeUInt; cdecl;
  upfunc_PackLeft =
    function(): QWord; cdecl;
  upfunc_PackDone =
    function(): Boolean; cdecl;
  upfunc_EndPack =
    procedure(); cdecl;
  upfunc_InitUnpack =
    procedure( unpack_sz: QWord ); cdecl;
  upfunc_UnpackSetChunk =
    procedure( chunk: Pointer; chunk_sz: SizeUInt ); cdecl;
  upfunc_UnpackStep =
    function( outbuf: Pointer; outbuf_sz: SizeUInt;
      data_left: PSizeUInt = nil ): SizeUInt; cdecl;
  upfunc_UnpackLeft =
    function(): QWord; cdecl;
  upfunc_UnpackDone =
    function(): Boolean; cdecl;
  upfunc_EndUnpack =
    procedure(); cdecl;

const
  upNilMethod : uplib_MethodName = #0;

{ –=────────────────────────────────────────────────────────────────────────=– }
type { TUniPackMethod - UniPack method library ═══════════════════════════════ }

  TUniPackMethod = class
  strict private
    //methods
    MHasError : upfunc_HasError;
    MErrorMsg : upfunc_ErrorMsg;
    MInitPack : upfunc_InitPack;
    MPackSetChunk : upfunc_PackSetChunk;
    MPackStep : upfunc_PackStep;
    MPackLeft : upfunc_PackLeft;
    MPackDone : upfunc_PackDone;
    MEndPack : upfunc_EndPack;
    MInitUnpack : upfunc_InitUnpack;
    MUnpackSetChunk : upfunc_UnpackSetChunk;
    MUnpackStep : upfunc_UnpackStep;
    MUnpackLeft : upfunc_UnpackLeft;
    MUnpackDone : upfunc_UnpackDone;
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

    property HasError: upfunc_HasError read MHasError;
    property ErrorMsg: upfunc_ErrorMsg read MErrorMsg;
    property InitPack: upfunc_InitPack read MInitPack;
    property PackSetChunk: upfunc_PackSetChunk read MPackSetChunk;
    property PackStep: upfunc_PackStep read MPackStep;
    property PackLeft: upfunc_PackLeft read MPackLeft;
    property PackDone: upfunc_PackDone read MPackDone;
    property EndPack: upfunc_EndPack read MEndPack;
    property InitUnpack: upfunc_InitUnpack read MInitUnpack;
    property UnpackSetChunk: upfunc_UnpackSetChunk read MUnpackSetChunk;
    property UnpackStep: upfunc_UnpackStep read MUnpackStep;
    property UnpackLeft: upfunc_UnpackLeft read MUnpackLeft;
    property UnpackDone: upfunc_UnpackDone read MUnpackDone;
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
    method.FIndex := upMethods.Add( method );
  end else begin
    method.FIndex := UP_NO_INDEX;
    method.Destroy();
  end;
end;

destructor TUniPackMethod.Destroy();
begin
  if FLibrary <> NilHandle then
    UnloadLibrary( FLibrary );
  if FIndex <> UP_NO_INDEX then
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
  if AName = upNilMethod then Exit;

  i := 0;
  while (Result = nil) and (i < upMethods.Count) do begin
    Result := TUniPackMethod( upMethods[i] );
    if Result.Name <> AName then Result := nil;
    i += 1;
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
  if FLibrary = NilHandle then
    Exit( False );

  MGetName := upfunc_GetName(
    GetProcedureAddress( FLibrary, 'up_info_name' ) );
  MHasError := upfunc_HasError(
    GetProcedureAddress( FLibrary, 'up_has_error' ) );
  MErrorMsg := upfunc_ErrorMsg(
    GetProcedureAddress( FLibrary, 'up_error_msg' ) );

  if (MGetName = nil) or (MHasError = nil) or (MErrorMsg = nil) then
    Exit( False );
  FName := uplib_MethodName( MGetName() );

  MInitPack := upfunc_InitPack(
    GetProcedureAddress( FLibrary, 'up_pack_init' ) );
  MPackSetChunk := upfunc_PackSetChunk(
    GetProcedureAddress( FLibrary, 'up_pack_chunk' ) );
  MPackStep := upfunc_PackStep(
    GetProcedureAddress( FLibrary, 'up_pack_step' ) );
  MPackLeft := upfunc_PackLeft(
    GetProcedureAddress( FLibrary, 'up_pack_left' ) );
  MPackDone := upfunc_PackDone(
    GetProcedureAddress( FLibrary, 'up_pack_done' ) );
  MEndPack := upfunc_EndPack(
    GetProcedureAddress( FLibrary, 'up_pack_end' ) );

  FCanPack := Assigned(MInitPack) and Assigned(MPackSetChunk)
    and Assigned(MPackStep) and Assigned(MPackLeft) and Assigned(MPackDone)
    and Assigned(MEndPack);

  MInitUnpack := upfunc_InitUnpack(
    GetProcedureAddress( FLibrary, 'up_unpack_init' ) );
  MUnpackSetChunk := upfunc_UnpackSetChunk(
    GetProcedureAddress( FLibrary, 'up_unpack_chunk' ) );
  MUnpackStep := upfunc_UnpackStep(
    GetProcedureAddress( FLibrary, 'up_unpack_step' ) );
  MUnpackLeft := upfunc_UnpackLeft(
    GetProcedureAddress( FLibrary, 'up_unpack_left' ) );
  MUnpackDone := upfunc_UnpackDone(
    GetProcedureAddress( FLibrary, 'up_unpack_done' ) );
  MEndUnpack := upfunc_EndUnpack(
    GetProcedureAddress( FLibrary, 'up_unpack_end' ) );

  FCanUnpack := Assigned(MInitUnpack) and Assigned(MUnpackSetChunk)
    and Assigned(MUnpackStep) and Assigned(MUnpackLeft) and Assigned(MUnpackDone)
    and Assigned(MEndUnpack);

  if not FCanPack and not FCanUnpack then
    Exit( False );

  MGetVersion := upfunc_GetVersion(
    GetProcedureAddress( FLibrary, 'up_info_version' ) );

  if MGetVersion <> nil then
    FVersion := MGetVersion()
  else
    FVersion := -1;

  Result := True;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure upUnloadAllMethods();
begin
  while upMethods.Count > 0 do
    TUniPackMethod.Get( upMethods.Count-1 ).Destroy();
end;

initialization

  upMethods := TList.Create();

finalization

  upUnloadAllMethods();
  upMethods.Destroy();

end.

