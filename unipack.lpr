program unipack;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads, {$ENDIF}{$ENDIF}
  Classes, SysUtils,
  CustApp, dynlibs,
  up_methods;

{ –=────────────────────────────────────────────────────────────────────────=– }
type { ═ TMainApp ──────────────────────────────────────────────────────────── }

  { TMainApp }

  TMainApp = class( TCustomApplication )
  const
    APPVER = '.tech';
  strict private
    procedure LoadMethods( ADir: String );
    procedure EnumMethods();
  protected
    procedure DoRun(); override;
  public
    constructor Create( TheOwner: TComponent ); override;
    destructor Destroy(); override;
  end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TMainApp.DoRun();
begin
  WriteLn( Title, ' ', APPVER );
  WriteLn( 'Written by Kodi Studio, 2015' );

  if ( ParamCount = 0 ) then begin
    WriteLn( 'Usage: unipack.exe -[a METHOD|u] <-F archive.upa> <-D path> [options]' );
    WriteLn( '  -a METHOD - pack mode, METHOD - compression method name' );
    WriteLn( '  -u - unpack mode' );
    WriteLn( 'Arguments:' );
    WriteLn( '  -F arch.upa' );
    WriteLn( '    a: set output filename as arch.upa' );
    WriteLn( '    u: archive file to unpack' );
    WriteLn( '  -D path' );
    WriteLn( '    a: directory with files to archive' );
    WriteLn( '    u: set output directory for unpacked files' );
    WriteLn( 'Options:' );
    WriteLn( '  -l - output list of avaliable packing methods and exit' );
    WriteLn( '  -i - output file information and exit' );
    WriteLn( '  -q - quiet mode (without detailed logging)' );
    Terminate(); Exit();
  end;

  LoadMethods( 'packlibs' );
  if HasOption('l') then begin
    EnumMethods();
    Terminate(); Exit();
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
  if ( FindFirst( ADir+'*.'+SharedSuffix, faAnyFile, EnumFile ) = 0 ) then begin
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
                 [Name, Version, pack, unpack, LibFile] ) );
      end;
    end;
end;

{══════════════════════════════════════════════════════════════════════════════}

constructor TMainApp.Create( TheOwner: TComponent );
begin
  inherited Create( TheOwner );
  StopOnException := True;
  CaseSensitiveOptions := True;
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

