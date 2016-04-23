program unipack;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

// TODO: Version of the archiver with GUI.

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads, {$ENDIF}{$ENDIF}
  Classes, SysUtils,
  CustApp, dynlibs,
  up_methods, up_archive, routines, int_list;

{ –=────────────────────────────────────────────────────────────────────────=– }
type { ═ TMainApp ──────────────────────────────────────────────────────────── }

  TMainApp = class( TCustomApplication )
  const
    sAppVersion = '0.3.3';
  strict private
    fWorkMode : ( awmUnknown, awmPack, awmUnpack, awmRepack );
    fArchCtx : TUniPackArchive;
    fError : TErrorUPA;
    fProcArch : String;
    fProcDir : String;
    fSolid : Boolean;
    fMethod : TUniPackMethod;
    fSkipFiles : TIntList;
    procedure LoadMethods( aDir: String );
    procedure EnumMethods();
    procedure ListFiles();
    procedure DeleteFiles();
    procedure AppDoPack();
    procedure AppDoRepack();
    procedure AppDoUnpack();
    function ErrStrUPA( ErrCode: TErrorUPA ): String;
    function YesNo( expr: Boolean ): String; inline;
  protected
    procedure DoRun(); override;
  public
    constructor Create( TheOwner: TComponent ); override;
    destructor Destroy(); override;
  end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TMainApp.DoRun();
var
  OptArch, OptDir : Boolean;
  split_list : TStringList;
  method_name : uplib_MethodName;
  i : Integer;
begin
  WriteLn( Title, ' ', sAppVersion );
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
    WriteLn( '  -r LIST - specify files to skip on unpack/repack (e.g. -r 1,3,5)' );
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

  fMethod := nil;
  if HasOption('a') then begin
    method_name := GetOptionValue('a');
    fMethod := TUniPackMethod.Get( method_name );
    if fMethod = nil then begin
      WriteLn( 'ERROR: unknown compression method: ', method_name );
      Terminate(); Exit();
    end;
    fWorkMode := awmPack;
  end;

  if HasOption('u') then begin
    if fWorkMode = awmUnknown then fWorkMode := awmUnpack else
    if fWorkMode = awmPack    then fWorkMode := awmRepack;
  end;

  case fWorkMode of 
    awmPack:   WriteLn( 'Pack mode' );
    awmUnpack: WriteLn( 'Unpack mode' );
    awmRepack: WriteLn( 'Repack mode' );
    else begin
      WriteLn( 'Invalid arguments specified. Type "unipack.exe" to show help.' );
      Terminate(); Exit();
    end;
  end;

  OptArch := HasOption('F');
  OptDir := HasOption('D');

  if fWorkMode = awmPack then begin
    if not OptDir then begin
      WriteLn( 'ERROR: directory to pack isn''t specified.' );
      Terminate(); Exit();
    end else begin
      fProcDir := ExpandFileName(
        ExcludeTrailingPathDelimiter( GetOptionValue('D') ) );
      if not DirectoryExists( fProcDir ) then begin
        WriteLn( 'ERROR: directory doesn''t exist: ', fProcDir );
        Terminate(); Exit();
      end;
    end;
    if OptArch then fProcArch := GetOptionValue('F')
               else fProcArch := fProcDir + upaFileExt;
    if FileExists( fProcArch ) then begin
      WriteLn( 'ERROR: file already exists: ', fProcArch );
      Terminate(); Exit();
    end;
  end;

  fSkipFiles := nil;
  split_list := nil;
  if fWorkMode in [awmUnpack, awmRepack] then begin
    if not OptArch then begin
      WriteLn( 'ERROR: file to unpack/repack isn''t specified.' );
      Terminate(); Exit();
    end else begin
      fProcArch := ExpandFileName( GetOptionValue('F') );
      if not FileExists( fProcArch ) then begin
        WriteLn( 'ERROR: file doesn''t exist: ', fProcArch );
        Terminate(); Exit();
      end;
    end;
    if fWorkMode = awmUnpack then begin
      if OptDir then fProcDir := GetOptionValue('D')
                else fProcDir := ChangeFileExt( fProcArch, EmptyStr );
      CreateDir( fProcDir ); //no exception if dir already exists
    end;
    if HasOption('r') then begin
      try
        fSkipFiles := TIntList.Create();
        fSkipFiles.Sorted := True;
        split_list := TStringList.Create();
        split_list.CommaText := GetOptionValue('r');
        for i := 0 to split_list.Count-1 do
          fSkipFiles.Add( StrToInt64(split_list[i]) );
      finally
        split_list.Free();
      end;
    end;
  end;

  fSolid := HasOption('s');
  WriteLn( 'File: ', fProcArch );
  if fWorkMode <> awmRepack then WriteLn( 'Path: ', fProcDir );
  if fWorkMode <> awmUnpack then WriteLn( 'Make solid: ', YesNo(fSolid) );

  fArchCtx := TUniPackArchive.Create();
  if HasOption('pbuf') then
    fArchCtx.PackBufSize := 1024*StrToInt( GetOptionValue('pbuf') );
  if HasOption('obuf') then
    fArchCtx.OutputBufSize := 1024*StrToInt( GetOptionValue('obuf') );

  WriteLn( 'Packed data buffer size: ', fArchCtx.PackBufSize, ' bytes' );
  WriteLn( 'Output buffers size: ', fArchCtx.OutputBufSize, ' bytes' );

  WriteLn();
  case fWorkMode of 
    awmPack:   AppDoPack();
    awmRepack: AppDoRepack();
    awmUnpack: AppDoUnpack();
  end;

  if fError <> eupOK then
    WriteLn( 'ERROR: ', ErrStrUPA(fError) );
  fArchCtx.Free();
  fSkipFiles.Free();
  Terminate();
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

//loading all available methods libraries
procedure TMainApp.LoadMethods( aDir: String );
var
  EnumFile : TSearchRec;
begin
  aDir := Location + IncludeTrailingPathDelimiter( aDir );
  if FindFirst( aDir+'*.'+SharedSuffix, 0, EnumFile ) = 0 then begin
    repeat
      if not TUniPackMethod.Load( aDir+EnumFile.Name ) then
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
        WriteLn( Format( '%6s | %7.4x | %4s | %6s | %7s',
                 [String(Name), Version, pack, unpack, LibFile] ) );
      end;
    end;
end;

procedure TMainApp.ListFiles();
var
  info : TFileInfoUPA;
  i : Integer;
begin
  for i := 0 to fArchCtx.Count()-1 do begin
    info := fArchCtx.FileInfo(i);
    WriteLn( i, '. ', info.Name );
    Write( Format('=== size: %.2f Kb', [info.Size/1024]) );
    Write( ' = attr: ', binStr( info.Attr, 8 ) );
    WriteLn( ' = date: ', StrTimePOSIX( info.Time ) );
    WriteLn();
  end;
end;

procedure TMainApp.DeleteFiles();
var
  i, del : Integer;
  info : TFileInfoUPA;
begin
  if fSkipFiles <> nil then begin
    for i := 0 to fSkipFiles.Count-1 do begin
      del := fSkipFiles[i];
      info := fArchCtx.FileInfo( del-i );
      fArchCtx.DeleteFile( del-i );
      WriteLn( Format('Deleted #%d: %s', [del, info.Name]) );
    end;
    WriteLn();
  end;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TMainApp.AppDoPack();
var
  PackFile : TSearchRec;
begin
  fProcDir := IncludeTrailingPathDelimiter( fProcDir );
  if FindFirst( fProcDir+'*', faAnyFile xor faDirectory, PackFile ) = 0 then
  begin
    repeat
      if fArchCtx.AddFile( fProcDir+PackFile.Name ) then
        WriteLn( 'Added: ', PackFile.Name )
      else
        WriteLn( 'FAILED: ', PackFile.Name );
    until FindNext( PackFile ) <> 0;
    WriteLn( 'Writing archive, please wait...' );
  end else begin
    WriteLn( 'WARNING: directory is empty, no files were packed' );
  end;

  fError := fArchCtx.Save( fProcArch, fMethod, fSolid, False );
end;

procedure TMainApp.AppDoRepack();
begin
  fError := fArchCtx.Open( fProcArch );
  if fError <> eupOK then Exit;
  WriteLn( 'Archive method: ', fArchCtx.Method.Name );
  WriteLn( 'Solid stream: ', YesNo( fArchCtx.Solid ) );
  WriteLn();
  DeleteFiles();
  WriteLn( 'Repacking archive, please wait...' );
  fError := fArchCtx.Save( EmptyStr, fMethod, fSolid, False );
end;

procedure TMainApp.AppDoUnpack();
begin
  fError := fArchCtx.Open( fProcArch );
  if fError <> eupOK then Exit;

  WriteLn( 'Archive method: ', fArchCtx.Method.Name );
  WriteLn( 'Solid stream: ', YesNo( fArchCtx.Solid ) );
  WriteLn();
  DeleteFiles();
  ListFiles();
  WriteLn( 'Writing files, please wait...' );
  fError := fArchCtx.WriteFiles( fProcDir );
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function TMainApp.ErrStrUPA( ErrCode: TErrorUPA ): String;
var
  method_error : Integer;
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
    eupMethodNotImplemented:
      Result := 'method doesn''t support specified action';
    eupInvalidInput:
      Result := 'invalid input';
    eupMemoryError:
      Result := 'memory error';
    eupMethodError: begin
      fMethod.HasError( @method_error );
      Result := 'internal method error: ' + fMethod.ErrorMsg( method_error );
      end
    else
      Result := 'unknown error';
  end;
end;

function TMainApp.YesNo( expr: Boolean ): String;
begin
  if expr then Result := 'Yes' else Result := 'No';
end;

{══════════════════════════════════════════════════════════════════════════════}

constructor TMainApp.Create( TheOwner: TComponent );
begin
  inherited Create( TheOwner );
  StopOnException := True;
  CaseSensitiveOptions := True;
  fWorkMode := awmUnknown;
  fError := eupOK;
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

