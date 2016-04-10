unit routines;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface

uses SysUtils;

function GetFilePos( FileHandle: THandle ): Int64; inline;
function SetFilePos( FileHandle: THandle; FilePos: Int64 ): Int64; inline;
function GetFileSize( FileHandle: THandle ): Int64;
function UniqueFileName( FileName: String ): String;

function StrTimePOSIX( TimePOSIX: Int64 ): String; inline;
function GetFileTimePOSIX( FileName: String ): Int64; inline;
function SetFileTimePOSIX( FileName: String; TimePOSIX: Int64 ): LongInt; inline;

implementation

uses DateUtils;

function GetFilePos( FileHandle: THandle ): Int64;
begin
  Result := FileSeek( FileHandle, Int64(0), fsFromCurrent );
end;

function SetFilePos( FileHandle: THandle; FilePos: Int64 ): Int64;
begin
  //I made this as a separate function in order not to always cast new position
  //to Int64 due to unclear FileSeek() LongInt/Int64 overload
  //also, other values than fsFromBeginning are used rarely on setting position
  Result := FileSeek( FileHandle, FilePos, fsFromBeginning );
end;

function GetFileSize( FileHandle: THandle ): Int64;
var
  pos : Int64;
begin
  //getting file size in C style
  pos := GetFilePos( FileHandle );
  Result := FileSeek( FileHandle, Int64(0), fsFromEnd );
  SetFilePos( FileHandle, pos );
end;

function UniqueFileName( FileName: String ): String;
var
  suff : Integer;
  FilePath, FileExt : String;
begin
  Result := FileName;
  suff := 0;
  FilePath := ExtractFilePath( FileName );
  FileExt  := ExtractFileExt( FileName );
  FileName := ChangeFileExt( ExtractFileName( FileName ), EmptyStr );
  while FileExists( Result ) do begin
    suff += 1;
    Result := FilePath+FileName+ '_'+IntToStr(suff) +FileExt;
  end;
end;

function StrTimePOSIX( TimePOSIX: Int64 ): String;
begin
  Result := DateTimeToStr( UnixToDateTime( TimePOSIX ) );
end;

function GetFileTimePOSIX( FileName: String ): Int64;
var
  filetime : LongInt;
begin
  filetime := FileAge( FileName );
  if ( filetime <> -1 ) then
    Result := DateTimeToUnix( FileDateToDateTime( filetime ) )
  else
    Result := -1;
end;

function SetFileTimePOSIX( FileName: String; TimePOSIX: Int64 ): LongInt;
begin
  Result := FileSetDate( FileName,
    DateTimeToDosDateTime( UnixToDateTime( TimePOSIX ) ) );
end;

end.

