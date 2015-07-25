program unipack;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads, {$ENDIF}{$ENDIF}
  Classes, SysUtils,
  CustApp, dynlibs,
  up_methods, up_archive;

{ –=────────────────────────────────────────────────────────────────────────=– }
type { ═ TMainApp ──────────────────────────────────────────────────────────── }

  TMainApp = class( TCustomApplication )
  const
    APPVER = '0.2';
  strict private
    FWorkMode : ( MODE_UNKNOWN, MODE_PACK, MODE_UNPACK, MODE_REPACK );
    //FErrorNum : Integer;
    //procedure ErrorMsg(  );
    procedure LoadMethods( ADir: String );
    procedure EnumMethods();
    function ErrStrUPA( ErrLev: TErrorUPA ): String;
    procedure AppDoPack( AFile, ADir: String; AMethod: TUniMethod );
    procedure AppDoRepack( AFile: String; AMethod: TUniMethod );
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
  OptUPA, OptDir : Boolean;
  PackMethod : TUniMethod;
  pkmethname : TUniMethodName;
begin
  WriteLn( Title, ' ', APPVER );
  WriteLn( 'Written by KoDi Studio, 2015' );

  if ( ParamCount = 0 ) then begin
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
    //WriteLn( '  -s - create solid archive' );
    //WriteLn( '  -q - quiet mode (without detailed logging)' );
    Terminate(); Exit();
  end;
  WriteLn();

  LoadMethods( 'packlibs' );
  if HasOption('l') then begin
    EnumMethods();
    Terminate(); Exit();
  end;
  
  if HasOption('a') then begin
    pkmethname := GetOptionValue('a');
    PackMethod := GetMethod( pkmethname );
    if ( PackMethod = nil ) then begin
      WriteLn( 'ERROR: unknown compression method: ', pkmethname );
      Terminate(); Exit();
    end;
    FWorkMode := MODE_PACK;
  end;

  if HasOption('u') then begin
    if ( FWorkMode = MODE_UNKNOWN ) then FWorkMode := MODE_UNPACK else
    if ( FWorkMode = MODE_PACK )    then FWorkMode := MODE_REPACK;
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

  if ( FWorkMode = MODE_PACK ) then begin
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
              else ProcUPA := ProcDir + UPA_FILEEXT;
    if FileExists( ProcUPA ) then begin
      WriteLn( 'ERROR: file already exists: ', ProcUPA );
      Terminate(); Exit();
    end;
  end;
      
  if ( FWorkMode in [MODE_UNPACK, MODE_REPACK] ) then begin
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
    if ( FWorkMode <> MODE_REPACK ) then begin
      if OptDir then ProcDir := GetOptionValue('D')
                else ProcDir := ChangeFileExt( ProcUPA, '' );
      CreateDir( ProcDir ); //no exception if dir already exists
    end;
  end;

  case FWorkMode of 
    MODE_PACK:   AppDoPack  ( ProcUPA, ProcDir, PackMethod );
    MODE_REPACK: AppDoRepack( ProcUPA, PackMethod );
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
  if ( FindFirst( ADir+'*.'+SharedSuffix, 0, EnumFile ) = 0 ) then begin
    repeat
      if not LoadMethodLib( ADir+EnumFile.Name ) then
        WriteLn( 'ERROR: unable to load method library: ', EnumFile.Name );
    until ( FindNext( EnumFile ) <> 0 );
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
    for i := 0 to UPMethods.Count-1 do begin
      with TUniMethod( UPMethods[i] ) do begin
        if ( Compress   = nil ) then pack   := '-' else pack   := '+';
        if ( Decompress = nil ) then unpack := '-' else unpack := '+';
        WriteLn( Format( '%0:6s | %1:7d | %2:4s | %3:6s | %4:7s',
                 [String(Name), Version, pack, unpack, LibFile] ) );
      end;
    end;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TMainApp.AppDoPack( AFile, ADir: String; AMethod: TUniMethod );
var
  ArchUPA : TUniPackArchive;
  PackFile : TSearchRec;
begin
  WriteLn( 'File: ', AFile );
  WriteLn( 'Path: ', ADir );
  WriteLn();

  ArchUPA := TUniPackArchive.Create( AFile );
  ArchUPA.SetMethod( AMethod );
  ADir := IncludeTrailingPathDelimiter(ADir);

  if ( FindFirst( ADir+'*', faAnyFile xor faDirectory, PackFile ) = 0 ) then begin
    repeat
      if ArchUPA.AddFile( ADir+PackFile.Name ) then
        WriteLn('added: ', PackFile.Name )
      else
        WriteLn( 'failed: ', PackFile.Name );
    until ( FindNext( PackFile ) <> 0 );
    WriteLn( 'packing, please wait...' );
  end else
    WriteLn( 'WARNING: directory is empty, no files were packed' );

  ArchUPA.DestroySave();
end;

procedure TMainApp.AppDoRepack( AFile: String; AMethod: TUniMethod );
var
  ArchUPA : TUniPackArchive;
begin
  WriteLn( 'File: ', AFile );
  ArchUPA := OpenUPA( AFile );
  if ( UPALastError <> UPA_OK ) then begin
    WriteLn( 'UPA ERROR: ', ErrStrUPA( UPALastError ) );
    Exit();
  end;

  WriteLn( 'Archive method: ', ArchUPA.Method );
  ArchUPA.SetMethod( AMethod );
  WriteLn( 'repacking, please wait...' );
  ArchUPA.DestroySave();
end;

procedure TMainApp.AppDoUnpack( AFile, ADir: String );
var
  ArchUPA : TUniPackArchive;
  FileEntry : TFileEntry;
  i : Integer;
begin
  WriteLn( 'File: ', AFile );
  WriteLn( 'Path: ', ADir );

  ArchUPA := OpenUPA( AFile );
  if ( UPALastError <> UPA_OK ) then begin
    WriteLn( 'UPA ERROR: ', ErrStrUPA( UPALastError ) );
    Exit();
  end;

  WriteLn( 'Archive method: ', ArchUPA.Method );

  for i := 0 to ArchUPA.Count-1 do begin
    FileEntry := ArchUPA.Files[i];
    WriteLn();
    WriteLn( FileEntry.FileName );
    WriteLn(  'size: ', FileEntry.FileSize,
      ' attr: ', binStr( FileEntry.FileAttr, 8 ),
      ' time: ', StrTimePOSIX( FileEntry.FileTime ) );
    ArchUPA.WriteFile( i, ADir );
  end;

  ArchUPA.Destroy();
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function TMainApp.ErrStrUPA( ErrLev: TErrorUPA ): String;
begin
  case ErrLev of
    UPA_OK:       Result := 'no error';
    UPA_NOFILE:   Result := 'file not found';
    UPA_BADSIGN:  Result := 'not an UPA file';
    UPA_NOMETHOD: Result := 'unknown compression method';
    UPA_NOMEMORY: Result := 'out of memory';
    UPA_LIBERROR: Result := 'internal method error';
    else Result := 'unknown error';
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

