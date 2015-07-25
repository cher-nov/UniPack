unit up_archive;

{$MODE OBJFPC}
{$LONGSTRINGS ON}
{$POINTERMATH ON}

interface {════════════════════════════════════════════════════════════════════}

uses
  Classes, SysUtils, up_methods;

const
  UPA_FILEEXT = '.upa';
  UPA_SIGN = 'UPA';
  UPA_MAXFILES = 65535;

type { UPA Archives management class ═════════════════════════════════════════ }

  TEntryData = ( DS_NODATA, DS_APPMEM, DS_LIBMEM, DS_FILE );

  PFileEntry = ^TFileEntry;
  TFileEntry = record
    FileName : String;
    FileSize : SizeUInt;
    FileAttr : Byte;
    FileTime : LongInt;
    //next fields are for internal use
    isPacked : Boolean;
    DataSize : SizeUInt;
    case Storage: TEntryData of
      DS_NODATA: ();
      DS_APPMEM, DS_LIBMEM: (
        MemoryPtr : Pointer );
      DS_FILE: (
        FileHandle : THandle;
        DataOffset : SizeUInt );
  end;

  TErrorUPA = ( UPA_OK, UPA_NOFILE, UPA_BADSIGN, UPA_NOMETHOD,
    UPA_NOMEMORY, UPA_LIBERROR );

  TUniPackArchive = class
  strict private
    FFileName : String;
    FHandle : THandle; //archive file handle
    FFiles : TList; //contains TFileEntry for each file
    FMethod : TUniMethod;
    FSolid : Boolean;
    function AddEntry( AName: String = ''; ASize: SizeUInt = 0;
      AAttr: Byte = 0; ATime: LongInt = -1 ): Integer;
    procedure SetEntryData( Index: Integer; APacked: Boolean; ASize: SizeUInt;
      ALibMem: Boolean; AMemory: Pointer ); overload; // DS_APPMEM / DS_LIBMEM
    procedure SetEntryData( Index: Integer; APacked: Boolean; ASize: SizeUInt;
      AHandle: THandle; AOffset: SizeUInt ); overload; // DS_FILE
    function GetEntry( Index: Integer ): TFileEntry;
    function GetCount: Integer;
    function GetMethodName: TUniMethodName;
    procedure CloseHandle( Index: Integer );
    procedure FreeBuffer( Index: Integer );
    procedure FileToMemory( Index: Integer; AClose: Boolean = True );
    procedure MemoryToFile( Index: Integer; Handle: THandle; Offset: SizeUInt );
  public
    constructor Create( UPAFile: String; OpenFile: Boolean = False );
    destructor Destroy(); override;
    procedure DestroySave();
    function AddFile( FileName: String ): Boolean;
    procedure WriteFile( Index: Integer; ADir: String = '' );
    procedure Clear();
    function PackData( Index: Integer ): Boolean;
    function UnpackData( Index: Integer ): Boolean;
    procedure SetMethod( AMethod: TUniMethod );
    property Files[Index: Integer]: TFileEntry read GetEntry;
    property Count: Integer read GetCount;
    property Solid: Boolean read FSolid write FSolid;
    property Method: TUniMethodName read GetMethodName;
  end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function OpenUPA( UPAFile: String ): TUniPackArchive;
function StrTimePOSIX( TimePOSIX: LongInt ): String;

function GetFileSize( FileHandle: THandle ): Int64;

var
  UPALastError : TErrorUPA = UPA_OK;

implementation {═══════════════════════════════════════════════════════════════}

uses DateUtils;

const
  upaReadOnly = $01; upaHidden = $02; upaSystem = $04; upaArchive = $08;

type
  THeaderUPA = packed record
    Sign : packed array[0..2] of Char;
    Method : TUniMethodName;
    isSolid : ByteBool;
    FileNum : Word;
  end;

  //TEntryFAT doesn't contain filename because it's size is dynamic
  TEntryFAT = packed record
    PackSize : QWord;
    FileSize : QWord;
    FileAttr : Byte;
    FileTime : LongInt;
  end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function read_fatfname( FileHandle: THandle ): String;
var
  len : Byte; //zero-based, meant range is 1..256
begin
  FileRead( FileHandle, len, 1 );
  SetLength( Result, len+1 );
  FileRead( FileHandle, PChar(Result)^, len+1 );
end;

procedure write_fatfname( FileHandle: THandle; FileName: String );
var
  len : Byte;
begin
  len := Byte( Length(FileName)-1 );
  FileWrite( FileHandle, len, 1 );
  FileWrite( FileHandle, PChar(FileName)^, len+1 );
end;

function GetFileSize( FileHandle: THandle ): Int64;
var
  seek : Int64;
begin
  //getting file size in C style
  seek := FileSeek( FileHandle, 0, fsFromCurrent );
  Result := FileSeek( FileHandle, 0, fsFromEnd );
  FileSeek( FileHandle, seek, fsFromBeginning );
end;

function UniqueFileName( FileName: String ): String;
var
  suff : Integer;
  FilePath, FileExt : String;
begin
  Result := FileName;
  suff := 0;
  FilePath := ExtractFilePath( FileName );
  FileExt  := ExtractFileExt ( FileName );
  FileName := ChangeFileExt( ExtractFileName( FileName ), '' );
  while FileExists( Result ) do begin
    suff += 1;
    Result := FilePath+FileName+ '_'+IntToStr(suff) +FileExt;
  end;
end;

{ POSIX filetime routines ════════════════════════════════════════════════════ }

function GetFileTimePOSIX( FileHandle: THandle ): LongInt;
begin
  Result := FileGetDate( FileHandle );
  if ( Result <> -1 ) then
    Result := LongInt( DateTimeToUnix( DosDateTimeToDateTime( Result ) ) );
end;

procedure SetFileTimePOSIX( FileHandle: THandle; TimePOSIX: LongInt );
begin
  FileSetDate( FileHandle,
    DateTimeToDosDateTime( UnixToDateTime( Int64( TimePOSIX ) ) )
  );
end;

{ UPA file attributes format routines ════════════════════════════════════════ }

function eval( cond: Integer ): Boolean;
   begin Result := cond <> 0;
     end;

function GetFileAttrUPA( FileName: String ): Byte;
var
  fpcAttr: LongInt;
begin
  Result := 0;
  fpcAttr := FileGetAttr( FileName );
  if eval(fpcAttr and faReadOnly) then Result := Result or upaReadOnly;
  if eval(fpcAttr and faHidden)   then Result := Result or upaHidden;
  if eval(fpcAttr and faSysFile)  then Result := Result or upaSystem;
  if eval(fpcAttr and faArchive)  then Result := Result or upaArchive;
end;

procedure SetFileAttrUPA( FileName: String; AttrUPA: Byte );
var
  fpcAttr: LongInt;
begin
  fpcAttr := 0;
  if eval(AttrUPA and upaReadOnly) then fpcAttr := fpcAttr or faReadOnly;
  if eval(AttrUPA and upaHidden)   then fpcAttr := fpcAttr or faHidden;
  if eval(AttrUPA and upaSystem)   then fpcAttr := fpcAttr or faSysFile;
  if eval(AttrUPA and upaArchive)  then fpcAttr := fpcAttr or faArchive;
  FileSetAttr( FileName, fpcAttr );
end;

{ Interfaced common routines ═════════════════════════════════════════════════ }

function OpenUPA( UPAFile: String ): TUniPackArchive;
begin
  UPAFile := ExpandFileName( UPAFile );
  if not FileExists( UPAFile ) then begin
    UPALastError := UPA_NOFILE;
    Exit(nil);
  end;

  Result := TUniPackArchive.Create( UPAFile, True );
  if ( UPALastError <> UPA_OK ) then begin
    Result.Destroy();
    Result := nil
  end;
end;

function StrTimePOSIX( TimePOSIX: LongInt ): String;
begin
  Result := DateTimeToStr( UnixToDateTime( Int64( TimePOSIX ) ) );
end;

{ –=────────────────────────────────────────────────────────────────────────=– }
{ ═ TUniPackArchive ────────────────────────────────────────────────────────── }

constructor TUniPackArchive.Create( UPAFile: String; OpenFile: Boolean );
var
  i : Integer;
  fname : String;
  Header: THeaderUPA;
  FATEntry : TEntryFAT;
  SizePacked : array of SizeUInt;
  StreamOffset : QWord;
  //next vars used only for solid archives
  StreamSize : QWord;
  StreamBuf : Pointer;
  UnpackSize : QWord;
  UnpackBuf : Pointer;
begin
  FFiles := TList.Create();
  FFileName := UPAFile;

  if not OpenFile then begin
    FHandle := UnusedHandle;
    FMethod := nil;
    FSolid := False;
    UPALastError := UPA_OK;
    Exit;
  end;

  FHandle := FileOpen( UPAFile, fmOpenRead or fmShareExclusive );
  FileRead( FHandle, Header, SizeOf(THeaderUPA) );

  if ( Header.Sign <> UPA_SIGN ) then begin
    UPALastError := UPA_BADSIGN;
    Exit;
  end;

  FMethod := GetMethod( Header.Method );
  if ( FMethod = nil ) then begin
    UPALastError := UPA_NOMETHOD;
    Exit;
  end;

  FSolid := Header.isSolid;
  SetLength( SizePacked, Header.FileNum );

  //reading FAT
  UnpackSize := 0;
  for i := 1 to Header.FileNum do begin
    fname := read_fatfname( FHandle );
    FileRead( FHandle, FATEntry, SizeOf(TEntryFAT) );
    AddEntry( fname, FATEntry.FileSize, FATEntry.FileAttr, FATEntry.FileTime );
    SizePacked[i-1] := FATEntry.PackSize;
    UnpackSize += FATEntry.FileSize;
  end;

  //unpacking data
  StreamOffset := FileSeek( FHandle, 0, fsFromCurrent );
  if not FSolid then begin
    //if archive isn't solid, we just store data locations
    for i := 0 to Header.FileNum-1 do begin
      SetEntryData( i, True, SizePacked[i], FHandle, StreamOffset );
      StreamOffset += SizePacked[i];
    end;
  end else begin
    //otherwise we unpack all the data
    StreamSize := GetFileSize( FHandle ) - StreamOffset;
    StreamBuf := GetMemory( StreamSize );
    if ( StreamBuf = nil ) then begin
      UPALastError := UPA_NOMEMORY;
      Exit;
    end;

    FileRead( FHandle, StreamBuf^, StreamSize );
    UnpackBuf := FMethod.Decompress( StreamBuf, StreamSize, UnpackSize );
    FreeMemory( StreamBuf ); //we don't need packed stream anymore
    if ( UnpackBuf = nil ) then begin
      UPALastError := UPA_LIBERROR;
      Exit;
    end;

    //our strategy is next: we take last file in unpacked stream, store it
    //in separate buffer and then perform reallocation of unpacked stream to
    //truncate data of processed file. and repeat this till stream end.
    //thereby, we will not waste much of memory only for copies.

    // i don't want to create tons of variables, sorry
    StreamBuf := UnpackBuf;
    StreamSize := UnpackSize;

    for i := Header.FileNum downto 1 do begin
      UnpackSize := PFileEntry( FFiles[i-1] )^.FileSize;
      UnpackBuf := GetMemory( UnpackSize );
      StreamSize -= UnpackSize;
      Move( (StreamBuf+StreamSize)^, UnpackBuf^, UnpackSize );
      StreamBuf := FMethod.ReallocMem( StreamBuf, StreamSize );
      SetEntryData( i, False, UnpackSize, False, UnpackBuf );
    end;
    FMethod.FreeMem( StreamBuf );
  end;

  UPALastError := UPA_OK;
  SetLength( SizePacked, 0 );
end;

destructor TUniPackArchive.Destroy();
begin
  Clear();
  inherited Destroy();
end;

procedure TUniPackArchive.DestroySave();
var
  UPAFile : String;
  i : Integer;
  outFile : THandle;
  Header : THeaderUPA;
  Entry : TEntryFAT;
  StreamOffset : QWord;
begin
  //TODO: Write saving of solid archives
  if FSolid then
    raise Exception.Create('Solid archives not supported yet, sorry.');
  
  UPAFile := FFileName;
  if ( FHandle <> UnusedHandle ) then UPAFile := ChangeFileExt( UPAFile, '.tmp' );
  UPAFile := UniqueFileName( ExpandFileName( UPAFile ) );

  outFile := FileCreate( UPAFile, fmShareExclusive );

  Header.Sign := UPA_SIGN;
  Header.Method := FMethod.Name;
  Header.isSolid := FSolid;
  Header.FileNum := FFiles.Count;
  FileWrite( outFile, Header, SizeOf(THeaderUPA) );

  //calculating data stream offset in archive file
  StreamOffset := SizeOf(THeaderUPA) + FFiles.Count * SizeOf(TEntryFAT);
  for i := 0 to FFiles.Count-1 do // +1 is for string length descriptor
    StreamOffset += Length( PFileEntry( FFiles[i] )^.FileName ) + 1;
  
  //packing files and writing its data and FAT entries
  for i := 0 to FFiles.Count-1 do begin
    with PFileEntry( FFiles[i] )^ do begin
      FileToMemory(i); //because file could be stored packed in archive
      if not FSolid then begin
        //if archive isn't solid, just writing packed files data
        PackData(i);
        MemoryToFile( i, outFile, StreamOffset );
        StreamOffset += DataSize;
        Entry.PackSize := DataSize;
      end {else begin
        UnpackData(i);
        Entry.PackSize := 0;
      end};
      Entry.FileSize := FileSize;
      Entry.FileAttr := FileAttr;
      Entry.FileTime := FileTime;
      write_fatfname( outFile, FileName );
    end;
    FileWrite( outFile, Entry, SizeOf(TEntryFAT) );
  end;

  FileClose( outFile );
  if ( FHandle <> UnusedHandle ) then begin
    FileClose( FHandle );
    DeleteFile( FFileName );
    RenameFile( UPAFile, FFileName );
  end;

  FHandle := outFile; //to prevent freeing handles by CloseHandle() in Clear()
  Destroy();
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function TUniPackArchive.AddFile( FileName: String ): Boolean;
var
  ind : Integer;
  size : SizeUInt;
  hfile : THandle;
begin
  if ( FFiles.Count = UPA_MAXFILES ) then Exit( False );
  if not FileExists( FileName ) then Exit( False );

  hfile := FileOpen( FileName, fmOpenRead or fmShareDenyWrite );
  size := GetFileSize( hfile );

  ind := AddEntry( ExtractFileName( FileName ), size,
                   GetFileAttrUPA( FileName ), GetFileTimePOSIX( hfile ) );
  SetEntryData( ind, False, size, hfile, 0 ); // DS_FILE
end;

procedure TUniPackArchive.WriteFile( Index: Integer; ADir: String = '' );
var
  hfile: THandle;
  DumpHandle: THandle;
  DumpOffset: SizeUInt;
  FileBuf: Pointer;
begin
  // if file data is currently stored on disk, we will transfer it to memory
  // without changing actual data location storage
  // we don't use UnpackData() because then current file data will be discarded
  with PFileEntry( FFiles[Index] )^ do begin
    if ( Storage = DS_FILE ) then begin
      DumpHandle := FileHandle;
      DumpOffset := DataOffset;
      FileToMemory( Index, False );
    end else
      DumpHandle := UnusedHandle;

    //if data is packed, we unpacking it manually
    if isPacked then begin
      FileBuf := FMethod.Decompress( MemoryPtr, DataSize, FileSize )
    end else
      FileBuf := MemoryPtr;

    ADir := IncludeTrailingPathDelimiter(ADir) + FileName;
    hfile := FileCreate( ADir, fmShareExclusive );
    FileWrite( hfile, FileBuf^, FileSize );
    SetFileTimePOSIX( hfile, FileTime );
    FileClose( hfile );
    SetFileAttrUPA( ADir, FileAttr );

    //freeing and restoring everything
    if isPacked then FMethod.FreeMem( FileBuf );
    if ( DumpHandle <> UnusedHandle ) then begin
      FreeBuffer( Index );
      SetEntryData( Index, isPacked, DataSize, DumpHandle, DumpOffset );
    end;
  end;
end;

procedure TUniPackArchive.Clear();
var
  i : Integer;
begin
  for i := 0 to FFiles.Count-1 do begin
    FreeBuffer(i);
    CloseHandle(i);
    Dispose( PFileEntry( FFiles[i] ) );
  end;
  FFiles.Clear();
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function TUniPackArchive.PackData( Index: Integer ): Boolean;
var
  newbuf : Pointer;
begin
  if ( FMethod = nil ) then Exit( False );
  if ( FMethod.Compress = nil ) then Exit( False );

  with PFileEntry( FFiles[Index] )^ do begin
    if isPacked then Exit( False );
    FileToMemory(Index);
    newbuf := FMethod.Compress( MemoryPtr, DataSize );
    if ( newbuf = nil ) then begin
      UPALastError := UPA_LIBERROR;
      Exit;
    end;
    FreeBuffer(Index);
  end;
  SetEntryData( Index, True, FMethod.CompSize(), True, newbuf ); // DS_LIBMEM
  Result := True;
end;

function TUniPackArchive.UnpackData( Index: Integer ): Boolean;
var
  newbuf : Pointer;
begin
  if ( FMethod = nil ) then Exit( False );
  if ( FMethod.Decompress = nil ) then Exit( False );

  with PFileEntry( FFiles[Index] )^ do begin
    if not isPacked then Exit( False );
    FileToMemory(Index);
    newbuf := FMethod.Decompress( MemoryPtr, DataSize, FileSize );
    if ( newbuf = nil ) then begin
      UPALastError := UPA_LIBERROR;
      Exit;
    end;
    FreeBuffer(Index);
    SetEntryData( Index, False, FileSize, True, newbuf ); // DS_LIBMEM
  end;
  Result := True;
end;

procedure TUniPackArchive.SetMethod( AMethod: TUniMethod );
var
  i : Integer;
begin
  if ( AMethod = FMethod ) then Exit;
  for i := 0 to FFiles.Count-1 do UnpackData(i);
  FMethod := AMethod;
end;

{ TUniPackArchive - Internal Routines ════════════════════════════════════════ }

function TUniPackArchive.AddEntry( AName: String; ASize: SizeUInt; AAttr: Byte;
  ATime: LongInt ): Integer;
var
  entry : PFileEntry;
begin
  New( entry );
  if not Assigned( entry ) then Exit(-1);

  Result := FFiles.Add( entry );
  with PFileEntry( entry )^ do begin
    FileName := AName; FileSize := ASize;
    FileAttr := AAttr; FileTime := ATime;
    Storage := DS_NODATA;
  end;
end;

procedure TUniPackArchive.SetEntryData( Index: Integer; APacked: Boolean;
  ASize: SizeUInt; ALibMem: Boolean; AMemory: Pointer ); overload;
begin
  with PFileEntry( FFiles[Index] )^ do begin
    isPacked := APacked;
    DataSize := ASize;

    if ALibMem then Storage := DS_LIBMEM
               else Storage := DS_APPMEM;
    MemoryPtr := AMemory;
  end;
end;

procedure TUniPackArchive.SetEntryData( Index: Integer; APacked: Boolean;
  ASize: SizeUInt; AHandle: THandle; AOffset: SizeUInt ); overload;
begin
  with PFileEntry( FFiles[Index] )^ do begin
    isPacked := APacked;
    DataSize := ASize;

    Storage := DS_FILE;
    FileHandle := AHandle;
    DataOffset := AOffset;
  end;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TUniPackArchive.CloseHandle( Index: Integer );
begin
  with PFileEntry( FFiles[Index] )^ do begin
    if ( Storage <> DS_FILE ) then Exit;
    if ( FileHandle <> FHandle ) then begin
      FileClose( FileHandle );
      FileHandle := UnusedHandle;
      DataOffset := 0;
    end;
  end;
end;

procedure TUniPackArchive.FreeBuffer( Index: Integer );
begin
  with PFileEntry( FFiles[Index] )^ do begin
    case Storage of
      DS_APPMEM: FreeMemory( MemoryPtr );
      DS_LIBMEM: FMethod.FreeMem( MemoryPtr );
      else Exit;
    end;
    MemoryPtr := nil;
  end;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TUniPackArchive.FileToMemory( Index: Integer; AClose: Boolean = True );
var
  tempbuf : Pointer;
  oldoffs : Int64;
begin
  with PFileEntry( FFiles[Index] )^ do begin
    if ( Storage <> DS_FILE ) then Exit;
    tempbuf := GetMemory( DataSize );
    oldoffs := FileSeek( FileHandle, 0, fsFromCurrent );
    FileSeek( FileHandle, DataOffset, fsFromBeginning );
    FileRead( FileHandle, tempbuf^, DataSize );
    FileSeek( FileHandle, oldoffs, fsFromBeginning );
  end;
  if AClose then CloseHandle(Index);
  with PFileEntry( FFiles[Index] )^ do begin
    Storage := DS_APPMEM;
    MemoryPtr := tempbuf;
  end;
end;

procedure TUniPackArchive.MemoryToFile( Index: Integer; Handle: THandle;
  Offset: SizeUInt );
var
  oldoffs : Int64;
begin
  with PFileEntry( FFiles[Index] )^ do begin
    if not ( Storage in [DS_APPMEM, DS_LIBMEM] ) then Exit;
    oldoffs := FileSeek( Handle, 0, fsFromCurrent );
    FileSeek( Handle, Offset, fsFromBeginning );
    FileWrite( Handle, MemoryPtr^, DataSize );
    FileSeek( Handle, oldoffs, fsFromBeginning );
  end;
  FreeBuffer(Index);
  with PFileEntry( FFiles[Index] )^ do begin
    Storage := DS_FILE;
    FileHandle := Handle;
    DataOffset := Offset;
  end;
end;

{ TUniPackArchive - Property Routines ════════════════════════════════════════ }

//TODO: Check if entry could be corrupt here
function TUniPackArchive.GetEntry( Index: Integer ): TFileEntry;
begin
  Result := PFileEntry( FFiles[Index] )^; //it is copy!
  Result.Storage := DS_NODATA; //zero data fields for safety
end;

function TUniPackArchive.GetCount: Integer;
   begin Result := FFiles.Count;
     end;

function TUniPackArchive.GetMethodName: TUniMethodName;
   begin Result := FMethod.Name;
     end;

end.

