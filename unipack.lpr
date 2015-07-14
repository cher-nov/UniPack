program unipack;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads, {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp,
  up_methods;

type

  TMainApp = class( TCustomApplication )
  const
    APPVER = '.tech';
  protected
    procedure DoRun(); override;
  public
    constructor Create( TheOwner: TComponent ); override;
    destructor Destroy(); override;
  end;

{ TMainApp }

procedure TMainApp.DoRun();
begin
  WriteLn( Title, ' ', APPVER );
  WriteLn( 'Written by Kodi Studio, 2015' );

  if ( ParamCount = 0 ) then begin
    WriteLn( 'Usage: unipack.exe /[a METHOD|u] <-F archive.upa> <-D path> [options]' );
    WriteLn( '  /a METHOD - pack mode, METHOD - compression method name' );
    WriteLn( '  /u - unpack mode' );
    WriteLn( 'Arguments:' );
    WriteLn( '  -F arch.upa' );
    WriteLn( '    a: set output filename as arch.upa' );
    WriteLn( '    u: archive file to unpack' );
    WriteLn( '  -D path' );
    WriteLn( '    a: directory with files to archive' );
    WriteLn( '    u: set output directory for unpacked files' );
    WriteLn( 'Options:' );
    WriteLn( '  /l - output list of avaliable packing methods and exit' );
    WriteLn( '  /i - output file information and exit' );
    WriteLn( '  /q - quiet mode (without detailed logging)' );
    Terminate(); Exit();
  end;

  Terminate();
end;

constructor TMainApp.Create( TheOwner: TComponent );
begin
  inherited Create( TheOwner );
  StopOnException := True;
end;

destructor TMainApp.Destroy();
begin
  inherited Destroy();
end;

var
  Application : TMainApp;
begin
  Application := TMainApp.Create( nil );
  Application.Title := 'UniPack';
  Application.Run;
  Application.Free;
end.

