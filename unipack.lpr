program unipack;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp
  { you can add units after this };

type

  { TMainApp }

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
var
  ErrorMsg: String;
begin
  WriteLn( Title, ' ', APPVER );
  WriteLn( 'Written by Kodi Studio, 2015' );

  if ( ParamCount = 0 ) then begin
    WriteLn( 'Usage: unipack.exe folder output.upa' );

  end;

  // stop program loop
  Terminate;
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

