program unipack;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads, {$ENDIF}{$ENDIF}
  Classes, SysUtils,
  CustApp, dynlibs,
  up_methods, up_archive, routines;

{ –=────────────────────────────────────────────────────────────────────────=– }
type { ═ TMainApp ──────────────────────────────────────────────────────────── }

  TMainApp = class( TCustomApplication )
  const
    APPVER = '0.3.1';
  strict private
    FWorkMode : ( MODE_UNKNOWN, MODE_PACK, MODE_UNPACK, MODE_REPACK );
    fNewPackBufSize : SizeUInt;
    fNewOutputBufSize : SizeUInt;
    //FErrorNum : Integer;
    //procedure ErrorMsg(  );
    procedure LoadMethods( ADir: String );
    procedure EnumMethods();
    function ErrStrUPA( ErrCode: TErrorUPA ): String;
    procedure AppDoPack( AFile, ADir: String; AMethod: TUniPackMethod;
      ASolid: Boolean  );
    procedure AppDoRepack( AFile: String; AMethod: TUniPackMethod;
      ASolid: Boolean  );
    procedure AppDoUnpack( AFile, ADir: String );
  protected
    procedure DoRun(); override;
  public
    constructor Create( TheOwner: TComponent ); override;
    destructor Destroy(); override;
  end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TMainApp.DoRun();
var
  ProcUPA, ProcDir : String;
  OptUPA, OptDir, OptSolid : Boolean;
  PackMethod : TUniPackMethod;
  method_name : uplib_MethodName;
begin
  WriteLn( Title, ' ', APPVER );
  WriteLn( 'Written by KoDi Studio, 2015-2016' );

  if ParamCount = 0 then begin
    WriteLn( 'Usage: unipack.exe -[a METHOD|u] <-F archive.upa> <-D path> [options]' );
    WriteLn( '  -a METHOD - pack mode, METHOD - compression method name' );
    WriteLn( '  -u - unpack mode' );
    WriteLn( '  if both are specified, file will be repacked' );
    WriteLn( 'Arguments:' );
    WriteLn( '  -F arch.upa' );
    WriteLn( '    a: set output filename as arch.upa (optional)' );
    WriteLn( '    u: archive file to unpack' );
    WriteLn( '  -D path' );
    WriteLn( '    a: directory with files to archive' );
    WriteLn( '    u: set output directory for unpacked files (optional)' );
    WriteLn( 'Options:' );
    WriteLn( '  -l - output list of avaliable compression methods and exit' );
    //WriteLn( '  -i - output file information and exit' );
    WriteLn( '  -s - create solid archive' );
    WriteLn( '  -pbuf SIZE - set size of packed data buffer, in KBytes' );
    WriteLn( '  -obuf SIZE - set size of output buffers, in KBytes' );
    //WriteLn( '  -q - quiet mode (without detailed logging)' );
    Terminate(); Exit();
  end;
  WriteLn();

  LoadMethods( 'packlibs' );
  if HasOption('l') then begin
    EnumMethods();
    Terminate(); Exit();
  end;

  PackMethod := nil;
  if HasOption('a') then begin
    method_name := GetOptionValue('a');
    PackMethod := TUniPackMethod.Get( method_name );
    if PackMethod = nil then begin
      WriteLn( 'ERROR: unknown compression method: ', method_name );
      Terminate(); Exit();
    end;
    FWorkMode := MODE_PACK;
  end;

  if HasOption('u') then begin
    if FWorkMode = MODE_UNKNOWN then FWorkMode := MODE_UNPACK else
    if FWorkMode = MODE_PACK    then FWorkMode := MODE_REPACK;
  end;

  case FWorkMode of 
    MODE_PACK:   WriteLn( 'Pack mode' );
    MODE_UNPACK: WriteLn( 'Unpack mode' );
    MODE_REPACK: WriteLn( 'Repack mode' );
    else begin
      WriteLn( 'Invalid arguments specified. Type "unipack.exe" to show help.' );
      Terminate(); Exit();
    end;
  end;

  OptUPA := HasOption('F');
  OptDir := HasOption('D');
  OptSolid := HasOption('s');

  if FWorkMode = MODE_PACK then begin
    if not OptDir then begin
      WriteLn( 'ERROR: directory to pack isn`t specified.' );
      Terminate(); Exit();
    end else begin
      ProcDir := ExpandFileName(
        ExcludeTrailingPathDelimiter( GetOptionValue('D') ) );
      if not DirectoryExists( ProcDir ) then begin
        WriteLn( 'ERROR: directory doesn`t exist: ', ProcDir );
        Terminate(); Exit();
      end;
    end;
    if OptUPA then ProcUPA := GetOptionValue('F')
              else ProcUPA := ProcDir + upaFileExt;
    if FileExists( ProcUPA ) then begin
      WriteLn( 'ERROR: file already exists: ', ProcUPA );
      Terminate(); Exit();
    end;
  end;
      
  if FWorkMode in [MODE_UNPACK, MODE_REPACK] then begin
    if not OptUPA then begin
      WriteLn( 'ERROR: file to unpack/repack isn`t specified.' );
      Terminate(); Exit();
    end else begin
      ProcUPA := ExpandFileName( GetOptionValue('F') );
      if not FileExists( ProcUPA ) then begin
        WriteLn( 'ERROR: file doesn`t exist: ', ProcUPA );
        Terminate(); Exit();
      end;
    end;
    if FWorkMode <> MODE_REPACK then begin
      if OptDir then ProcDir := GetOptionValue('D')
                else ProcDir := ChangeFileExt( ProcUPA, EmptyStr );
      CreateDir( ProcDir ); //no exception if dir already exists
    end;
  end;

  if HasOption('pbuf') then
    fNewPackBufSize := 1024 * StrToInt( GetOptionValue('pbuf') )
  else
    fNewPackBufSize := 0;
  if HasOption('obuf') then
    fNewOutputBufSize := 1024 * StrToInt( GetOptionValue('obuf') )
  else
    fNewOutputBufSize := 0;
  
  case FWorkMode of 
    MODE_PACK:   AppDoPack  ( ProcUPA, ProcDir, PackMethod, OptSolid );
    MODE_REPACK: AppDoRepack( ProcUPA, PackMethod, OptSolid );
    MODE_UNPACK: AppDoUnpack( ProcUPA, ProcDir );
  end;

  Terminate();
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

//loading all available methods libraries
procedure TMainApp.LoadMethods( ADir: String );
var
  EnumFile : TSearchRec;
begin
  ADir := Location + IncludeTrailingPathDelimiter( ADir );
  if FindFirst( ADir+'*.'+SharedSuffix, 0, EnumFile ) = 0 then begin
    repeat
      if not TUniPackMethod.Load( ADir+EnumFile.Name ) then
        WriteLn( 'ERROR: unable to load method library: ', EnumFile.Name );
    until FindNext( EnumFile ) <> 0;
  end else
    WriteLn( 'WARNING: no methods libraries are found.' );
  FindClose( EnumFile );
end;

//prints list of all available compression methods
procedure TMainApp.EnumMethods();
var
  i : Integer;
  pack, unpack : Char;
begin
  WriteLn( 'METHOD | VERSION | PACK | UNPACK | LIBRARY' );
    for i := 0 to TUniPackMethod.Count()-1 do begin
      with TUniPackMethod.Get(i) do begin
        if CanPack   then pack   := '+' else pack   := '-';
        if CanUnpack then unpack := '+' else unpack := '-';
        WriteLn( Format( '%0:6s | %1:7x | %2:4s | %3:6s | %4:7s',
                 [String(Name), Version, pack, unpack, LibFile] ) );
      end;
    end;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TMainApp.AppDoPack( AFile, ADir: String; AMethod: TUniPackMethod;
  ASolid: Boolean );
var
  ArchUPA : TUniPackArchive;
  PackFile : TSearchRec;
  ErrorUPA : TErrorUPA;
  errcode : integer;
begin
  WriteLn( 'File: ', AFile );
  WriteLn( 'Path: ', ADir );
  WriteLn();

  ArchUPA := TUniPackArchive.Create();
  if fNewPackBufSize > 0 then ArchUPA.PackBufSize := fNewPackBufSize;
  if fNewOutputBufSize > 0 then ArchUPA.OutputBufSize := fNewOutputBufSize;
  ADir := IncludeTrailingPathDelimiter(ADir);

  if FindFirst( ADir+'*', faAnyFile xor faDirectory, PackFile ) = 0 then begin
    repeat
      if ArchUPA.AddFile( ADir+PackFile.Name ) then
        WriteLn( 'added: ', PackFile.Name )
      else
        WriteLn( 'failed: ', PackFile.Name );
    until FindNext( PackFile ) <> 0;
    WriteLn( 'packing, please wait...' );
  end else
    WriteLn( 'WARNING: directory is empty, no files were packed' );

  ErrorUPA := ArchUPA.Save( AFile, AMethod, ASolid, False );
  if ErrorUPA <> eupOK then begin
    AMethod.HasError(@errcode);
    writeln( 'pack error: ', ErrStrUPA( ErrorUPA ), ' ', AMethod.ErrorMsg(errcode) );
  end;
  ArchUPA.Destroy();
end;

procedure TMainApp.AppDoRepack( AFile: String; AMethod: TUniPackMethod;
  ASolid: Boolean );
var
  ArchUPA : TUniPackArchive;
  ErrorUPA : TErrorUPA;
begin
  WriteLn( 'File: ', AFile );
  ArchUPA := TUniPackArchive.Create();
  if fNewPackBufSize > 0 then ArchUPA.PackBufSize := fNewPackBufSize;
  if fNewOutputBufSize > 0 then ArchUPA.OutputBufSize := fNewOutputBufSize;

  ErrorUPA := ArchUPA.Open( AFile );
  if ErrorUPA <> eupOK then begin
    WriteLn( 'UPA ERROR: ', ErrStrUPA( ErrorUPA ) );
    Exit();
  end;

  WriteLn( 'Archive method: ', ArchUPA.Method.Name );
  WriteLn( 'repacking, please wait...' );
  ArchUPA.Save( EmptyStr, AMethod, ASolid, False );
  ArchUPA.Destroy();
end;

procedure TMainApp.AppDoUnpack( AFile, ADir: String );
var
  ArchUPA : TUniPackArchive;
  FileInfo : TFileInfoUPA;
  ErrorUPA : TErrorUPA;
  i : Integer;
begin
  WriteLn( 'File: ', AFile );
  WriteLn( 'Path: ', ADir );
  ArchUPA := TUniPackArchive.Create();
  if fNewPackBufSize > 0 then ArchUPA.PackBufSize := fNewPackBufSize;
  if fNewOutputBufSize > 0 then ArchUPA.OutputBufSize := fNewOutputBufSize;

  ErrorUPA := ArchUPA.Open( AFile );
  if ErrorUPA <> eupOK then begin
    WriteLn( 'UPA ERROR: ', ErrStrUPA( ErrorUPA ) );
    Exit();
  end;

  WriteLn( 'Archive method: ', ArchUPA.Method.Name );

  for i := 0 to ArchUPA.Count()-1 do begin
    FileInfo := ArchUPA.FileInfo(i);
    WriteLn();
    WriteLn( FileInfo.Name );
    WriteLn(  'size: ', FileInfo.Size,
      ' attr: ', binStr( FileInfo.Attr, 8 ),
      ' time: ', StrTimePOSIX( FileInfo.Time ) );
  end;

  ArchUPA.WriteFiles( ADir );
  ArchUPA.Destroy();
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function TMainApp.ErrStrUPA( ErrCode: TErrorUPA ): String;
begin
  case ErrCode of
    eupOK:
      Result := 'no error';
    eupFileNotFound:
      Result := 'file not found';
    eupFileError:
      Result := 'file I/O error';
    eupInvalidArchive:
      Result := 'invalid UPA file';
    eupUnknownMethod:
      Result := 'unknown compression method';
    eupMemoryError:
      Result := 'memory error';
    eupMethodError:
      Result := 'internal method error';
    else
      Result := 'unknown error';
  end;
end;

{══════════════════════════════════════════════════════════════════════════════}

constructor TMainApp.Create( TheOwner: TComponent );
begin
  inherited Create( TheOwner );
  StopOnException := True;
  CaseSensitiveOptions := True;
  FWorkMode := MODE_UNKNOWN;
end;

destructor TMainApp.Destroy();
begin
  inherited Destroy();
end;

{══════════════════════════════════════════════════════════════════════════════}

var
  Application : TMainApp;
begin
  Application := TMainApp.Create( nil );
  Application.Title := 'UniPack';
  Application.Run();
  Application.Free();
end.

