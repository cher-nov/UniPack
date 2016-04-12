unit up_archive;

{$MODE OBJFPC}
{$LONGSTRINGS ON}
{$POINTERMATH ON}

//TODO: Rewrite data pipeline as a separate helper class

interface {════════════════════════════════════════════════════════════════════}

uses
  Classes, SysUtils, int_list, up_methods;

const
  upaFileExt = '.upa';
  upaFileSign = 'UPA';
  upaMaxFiles = 65535;
  upaInvalidIndex = -1;
  upaPackBufStd = 512 * 1024; // 512 Kb
  upaOutputBufStd = 768 * 1024; // 768 Kb

type { UPA Archives management class ═════════════════════════════════════════ }

  TFileInfoUPA = record
    Name : String;
    Size : QWord;
    Attr : Byte;
    Time : Int64;
    PackSize : QWord;
  end;

  TErrorUPA = ( eupOK, eupFileNotFound, eupFileError, eupInvalidArchive,
    eupUnknownMethod, eupMethodNotImplemented, eupInvalidInput, eupMemoryError,
    eupMethodError );

  //for internal use, do not touch
  PFileEntryUPA = ^TFileEntryUPA;
  TFileEntryUPA = record
    Info : TFileInfoUPA;
    Handle : THandle;
    StreamOffset : QWord; //used only for unpacking
    SkipBytesBefore : QWord; { needed for correct deletion of packed files
                               from solid stream to skip them from pipeline }
  end;

  TUniPackArchive = class
  strict private
    FFileName : String;
    FFileHandle : THandle; //archive file handle
    FFiles : TList; //contains PFileEntryUPA for each file
    FStreamStartPos : QWord;
    FStreamSize : QWord;
    FPackedCount : Integer; //count of packed files
    FAllFilesSize : QWord;
    FSolid : Boolean;
    FMethod : TUniPackMethod;
    FPackBufSize : SizeUInt;
    FOutputBufSize : SizeUInt;

    FDplPackedBuf : Pointer;
    FDplDataOutBuf : Pointer;
    FDplCurrentFile : Integer;
    FDplFileBytesLeft : QWord;
    FDplChunkDataLeft : SizeUInt;
    FDplSkipBytesLeft : QWord; //needed only for solid stream

    procedure Init(); inline;

    function UPA_GetSaveArchName( var NewFileName: String ): Boolean;
    function UPA_CalculateStreamPos(): QWord;
    function UPA_CalculateStreamSize(): QWord;
    function UPA_ReadAndCheckHeader( ArchHandle: THandle ): TErrorUPA;
    procedure UPA_WriteHeader( ArchHandle: THandle; aMethod: TUniPackMethod;
      aSolid: Boolean );
    procedure UPA_RemapArchive( const ArchName: String; isTemp: Boolean;
      aMethod: TUniPackMethod; aSolid: Boolean; aStreamStartPos: QWord;
      aPackedSizes: array of QWord );
    function UPA_GetFileAttr( FileName: String ): Byte;
    procedure UPA_SetFileAttr( FileName: String; AttrUPA: Byte );
    function FAT_ReadEntry( ArchHandle: THandle ): TFileInfoUPA;
    procedure FAT_WriteEntry( ArchHandle: THandle; FileIndex: Integer;
      NewPackSize: QWord );

    function AddEntry( const aInfo: TFileInfoUPA; aHandle: THandle;
      aOffsetStream: QWord ): Integer;
    function GetEntry( Index: Integer ): PFileEntryUPA; inline;
    procedure CloseHandle( Handle: THandle ); inline;
    function FindFirstNotEmptyFile( StartIndex: Integer ): Integer;

    procedure PipelineInit();
    procedure PipelineResetState( Forced: Boolean = False );
    procedure PipelineEndUnpack();
    procedure PipelineFree();
    function PipelineSetNext( FileIndex: Integer;
      SkipEmpty: Boolean = True ): Boolean;
    function PipelineGetData( OutBufOffset: SizeUInt = 0;
      AutoNext: Boolean = False ): SizeUInt;

  public
    constructor Create();
    destructor Destroy(); override;
    function Open( FileName: String ): TErrorUPA;
    function Save( NewFileName: String; aMethod: TUniPackMethod;
      aSolid: Boolean; RemapToNew: Boolean ): TErrorUPA;
    procedure Close();

    function AddFile( FileName: String ): Boolean;
    procedure DeleteFile( Index: Integer );
    function Count(): Integer;
    function FileInfo( Index: Integer ): TFileInfoUPA;
    function WriteFiles( DirPath: String; FileIndexes: TIntList = nil ): TErrorUPA;

    property Solid: Boolean read FSolid;
    property Method: TUniPackMethod read FMethod;
    property PackBufSize: SizeUInt read FPackBufSize write FPackBufSize;
    property OutputBufSize: SizeUInt read FOutputBufSize write FOutputBufSize;
  end;

implementation {═══════════════════════════════════════════════════════════════}

uses routines;

const
  upaAReadOnly = $01;
  upaAHidden = $02;
  upaASystem = $04;
  upaAArchive = $08;

type

  TArchHeaderUPA = packed record
    Sign : packed array[0..2] of Char;
    Method : uplib_MethodName;
    isSolid : ByteBool;
    FileCount : Word;
  end;

  //TArchEntryUPA doesn't contain filename because it's size is dynamic
  TArchEntryUPA = packed record
    PackSize : QWord;
    FileSize : QWord;
    FileAttr : Byte;
    FileTime : LongInt; //TODO: change to Int64 in standard
  end;

{ –=────────────────────────────────────────────────────────────────────────=– }
{ ═ TUniPackArchive ────────────────────────────────────────────────────────── }

//returns if file name is temporary
function TUniPackArchive.UPA_GetSaveArchName( var NewFileName: String ): Boolean;
begin
  if NewFileName = EmptyStr then begin
    if FFileHandle = UnusedHandle then
      Exit( False );
    NewFileName := ChangeFileExt( FFileName, '.tmp' );
    Result := True;
  end else begin
    NewFileName := ExpandFileName( NewFileName );
    Result := False;
  end;
  NewFileName := UniqueFileName( NewFileName );
end;

function TUniPackArchive.UPA_CalculateStreamPos(): QWord;
var
  i : Integer;
begin
  Result := SizeOf( TArchHeaderUPA ) + SizeOf( TArchEntryUPA ) * FFiles.Count;
  for i := 0 to FFiles.Count-1 do
    Result += Length( GetEntry(i)^.Info.Name ) + 1; // +1 for length descriptor
end;

function TUniPackArchive.UPA_CalculateStreamSize(): QWord;
begin
  Result := GetFileSize( FFileHandle ) - FStreamStartPos;
end;

function TUniPackArchive.UPA_ReadAndCheckHeader( ArchHandle: THandle ): TErrorUPA;
var
  header : TArchHeaderUPA;
  new_method : TUniPackMethod;
begin
  FileRead( ArchHandle, header, SizeOf(header) );
  if header.Sign <> upaFileSign then
    Exit( eupInvalidArchive );

  new_method := TUniPackMethod.Get( header.Method );
  if new_method = nil then
    Exit( eupUnknownMethod );
  if not new_method.CanUnpack then
    Exit( eupMethodNotImplemented );

  Close();
  FPackedCount := Header.FileCount;
  FSolid := Header.isSolid;
  FMethod := new_method;

  Result := eupOK;
end;

procedure TUniPackArchive.UPA_WriteHeader( ArchHandle: THandle;
  aMethod: TUniPackMethod; aSolid: Boolean );
var
  header : TArchHeaderUPA;
begin
  header.Sign := upaFileSign;
  header.Method := aMethod.Name;
  header.isSolid := aSolid;
  header.FileCount := FFiles.Count;
  FileWrite( ArchHandle, header, SizeOf(header) );
end;

procedure TUniPackArchive.UPA_RemapArchive( const ArchName: String;
  isTemp: Boolean; aMethod: TUniPackMethod; aSolid: Boolean;
  aStreamStartPos: QWord; aPackedSizes: array of QWord );
var
  entry : PFileEntryUPA;
  pos_stream : QWord;
  i : Integer;
begin
  FSolid := aSolid;
  FMethod := aMethod;

  FileClose( FFileHandle );
  for i := FPackedCount to FFiles.Count-1 do
    CloseHandle( GetEntry(i)^.Handle );

  if isTemp then begin
    SysUtils.DeleteFile( FFileName );
    RenameFile( ArchName, FFileName );
  end else begin
    FFileName := ArchName;
  end;
  FFileHandle := FileOpen( FFileName, fmOpenRead or fmShareExclusive );

  pos_stream := 0;
  for i := 0 to FFiles.Count-1 do begin
    entry := GetEntry(i);
    entry^.Handle := FFileHandle;
    entry^.StreamOffset := pos_stream;
    entry^.SkipBytesBefore := 0;

    if not aSolid then begin
      entry^.Info.PackSize := aPackedSizes[i];
      pos_stream += aPackedSizes[i];
    end else begin
      entry^.Info.PackSize := 0;
    end;
  end;

  FStreamStartPos := aStreamStartPos;
  FStreamSize := UPA_CalculateStreamSize();
  FPackedCount := FFiles.Count;
end;

function TUniPackArchive.UPA_GetFileAttr( FileName: String ): Byte;
var
  fpcAttr: LongInt;
begin
  Result := 0;
  fpcAttr := FileGetAttr( FileName );
  if Boolean(fpcAttr and faReadOnly) then Result := Result or upaAReadOnly;
  if Boolean(fpcAttr and faHidden)   then Result := Result or upaAHidden;
  if Boolean(fpcAttr and faSysFile)  then Result := Result or upaASystem;
  if Boolean(fpcAttr and faArchive)  then Result := Result or upaAArchive;
end;

procedure TUniPackArchive.UPA_SetFileAttr( FileName: String; AttrUPA: Byte );
var
  fpcAttr: LongInt;
begin
  fpcAttr := 0;
  if Boolean(AttrUPA and upaAReadOnly) then fpcAttr := fpcAttr or faReadOnly;
  if Boolean(AttrUPA and upaAHidden)   then fpcAttr := fpcAttr or faHidden;
  if Boolean(AttrUPA and upaASystem)   then fpcAttr := fpcAttr or faSysFile;
  if Boolean(AttrUPA and upaAArchive)  then fpcAttr := fpcAttr or faArchive;
  FileSetAttr( FileName, fpcAttr );
end;

function TUniPackArchive.FAT_ReadEntry( ArchHandle: THandle ): TFileInfoUPA;
  function ReadFName(): String;
    var
      len : Byte; //zero-based, meant range is 1..256
    begin
      FileRead( ArchHandle, len, 1 );
      SetLength( Result, len+1 );
      FileRead( ArchHandle, PChar(Result)^, len+1 );
    end;
var
  fat_entry : TArchEntryUPA;
begin
  Result.Name := ReadFName();
  FileRead( ArchHandle, fat_entry, SizeOf(fat_entry) );
  Result.Size := fat_entry.FileSize;
  Result.Attr := fat_entry.FileAttr;
  Result.Time := fat_entry.FileTime;
  Result.PackSize := fat_entry.PackSize;
end;

procedure TUniPackArchive.FAT_WriteEntry( ArchHandle: THandle;
  FileIndex: Integer; NewPackSize: QWord );
  procedure WriteFName( FileName: String );
    var
      len : Byte;
    begin
      len := Byte( Length(FileName)-1 );
      FileWrite( ArchHandle, len, 1 );
      FileWrite( ArchHandle, PChar(FileName)^, len+1 );
    end;
var
  fat_entry : TArchEntryUPA;
begin
  with GetEntry(FileIndex)^.Info do begin
    WriteFName( Name );
    fat_entry.PackSize := NewPackSize;
    fat_entry.FileSize := Size;
    fat_entry.FileAttr := Attr;
    fat_entry.FileTime := LongInt(Time); //TODO: remove typecast
  end;
  FileWrite( ArchHandle, fat_entry, SizeOf(fat_entry) );
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TUniPackArchive.Init();
begin
  FFileName := EmptyStr;
  FFileHandle := UnusedHandle;
  FStreamStartPos := 0;
  FStreamSize := 0;
  FPackedCount := 0;
  FAllFilesSize := 0;
  FSolid := False;
  FMethod := nil;
end;

constructor TUniPackArchive.Create();
begin
  FPackBufSize := upaPackBufStd;
  FOutputBufSize := upaOutputBufStd;
  FFiles := TList.Create();
  Init();
end;

destructor TUniPackArchive.Destroy();
begin
  Close();
  FFiles.Destroy();
  inherited Destroy();
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function TUniPackArchive.Open( FileName: String ): TErrorUPA;
var
  EntryInfo : TFileInfoUPA;
  ArchFile : THandle;
  header_check : TErrorUPA;
  pos_stream : QWord;
  i : Integer;
begin
  FileName := ExpandFileName( FileName );
  if not FileExists( FileName ) then
    Exit( eupFileNotFound );

  ArchFile := FileOpen( FileName, fmOpenRead or fmShareExclusive );
  if ArchFile = UnusedHandle then
    Exit( eupFileError );

  header_check := UPA_ReadAndCheckHeader( ArchFile );
  if header_check <> eupOK then begin
    FileClose( ArchFile );
    Exit( header_check );
  end;

  pos_stream := 0;
  FAllFilesSize := 0;

  for i := 1 to FPackedCount do begin
    EntryInfo := FAT_ReadEntry( ArchFile );
    AddEntry( EntryInfo, ArchFile, pos_stream );
    if not FSolid then pos_stream += EntryInfo.PackSize;
    FAllFilesSize += EntryInfo.Size;
  end;

  FFileName := FileName;
  FFileHandle := ArchFile;
  FStreamStartPos := GetFilePos( ArchFile );
  FStreamSize := UPA_CalculateStreamSize();

  Result := eupOK;
end;

function TUniPackArchive.Save( NewFileName: String; aMethod: TUniPackMethod;
  aSolid: Boolean; RemapToNew: Boolean ): TErrorUPA;
var
  ArchFile : THandle;
  PackedBuf : Pointer;
  ChunkPacked, ChunkLeft, write_size : SizeUInt;
  packed_size : QWord;
  i, upd_pos : Integer;
  TempFile, PackingNow : Boolean;
  NewStreamStartPos : QWord;
  NewPackedSizes : array of QWord;
begin
  if not aMethod.CanPack then
    Exit( eupMethodNotImplemented );

  TempFile := UPA_GetSaveArchName( NewFileName );
  if NewFileName = EmptyStr then
    Exit( eupFileError );
  if TempFile then RemapToNew := True;

  ArchFile := FileCreate( NewFileName );
  NewStreamStartPos := UPA_CalculateStreamPos();
  SetFilePos( ArchFile, NewStreamStartPos );
  PipelineInit();
  PackedBuf := GetMem( FPackBufSize );

  upd_pos := 0;
  if aSolid then begin
    SetLength( NewPackedSizes, 1 );
    if FAllFilesSize > 0 then
      aMethod.InitPack( FAllFilesSize );
  end else begin
    SetLength( NewPackedSizes, FFiles.Count );
  end;

  //packing and writing data
  ChunkLeft := 0;
  PackingNow := False;
  while (FDplCurrentFile < FFiles.Count) or PackingNow do begin
    if not aSolid and not PackingNow then begin
      upd_pos := FDplCurrentFile;
      aMethod.InitPack( GetEntry(upd_pos)^.Info.Size );
      PackingNow := True;
    end;
    if (ChunkLeft = 0) and (aMethod.PackLeft() > 0) then begin
      repeat //read data to be packed, from pipeline
        ChunkLeft += PipelineGetData( ChunkLeft, aSolid );
      until (
        not aSolid //if non-solid, read file data only once
        or (ChunkLeft = FOutputBufSize) //FDplDataOutBuf is full
        or (FDplCurrentFile = FFiles.Count) //data ended in pipeline
      );
      aMethod.PackSetChunk( FDplDataOutBuf, ChunkLeft );
    end;

    ChunkPacked := aMethod.PackStep( PackedBuf, FPackBufSize, @ChunkLeft );
    if aMethod.HasError() then begin
      FileClose( ArchFile );
      SysUtils.DeleteFile( NewFileName );
      PipelineFree();
      aMethod.EndPack();
      Exit( eupMethodError );
    end;

    write_size := FileWrite( ArchFile, PackedBuf^, ChunkPacked );
    //TODO: handle file error here
    if aSolid then NewPackedSizes[0] += ChunkPacked
      else NewPackedSizes[upd_pos] += ChunkPacked;

    PackingNow := not aMethod.PackDone();
    if not PackingNow then begin
      aMethod.EndPack();
      if not aSolid then
        PipelineSetNext( FDplCurrentFile+1 );
    end;
  end;

  SetFilePos( ArchFile, 0 );
  UPA_WriteHeader( ArchFile, aMethod, aSolid );
  for i := 0 to FFiles.Count-1 do begin
    if aSolid then packed_size := 0
      else packed_size := NewPackedSizes[i];
    FAT_WriteEntry( ArchFile, i, packed_size );
  end;

  FileClose( ArchFile );
  PipelineFree();
  FreeMem( PackedBuf );

  if RemapToNew then UPA_RemapArchive( NewFileName, TempFile, aMethod, aSolid,
    NewStreamStartPos, NewPackedSizes );

  Result := eupOK;
end;

procedure TUniPackArchive.Close();
begin
  while FFiles.Count > 0 do
    DeleteFile( FFiles.Count-1 );
  FileClose( FFileHandle );
  Init();
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function TUniPackArchive.AddFile( FileName: String ): Boolean;
var
  hfile : THandle;
  info : TFileInfoUPA;
  index : Integer;
begin
  if FFiles.Count = upaMaxFiles then
    Exit( False );
  if not FileExists( FileName ) then
    Exit( False );

  info.Attr := UPA_GetFileAttr( FileName );
  info.Time := GetFileTimePOSIX( FileName );

  hfile := FileOpen( FileName, fmOpenRead or fmShareDenyWrite );
  if hfile = UnusedHandle then
    Exit( False );

  info.Name := ExtractFileName( FileName );
  info.Size := GetFileSize( hfile );
  info.PackSize := 0;

  index := AddEntry( info, hfile, 0 );
  Result := index <> upaInvalidIndex;
  if Result then FAllFilesSize += info.Size
    else FileClose( hfile );
end;

procedure TUniPackArchive.DeleteFile( Index: Integer );
var
  entry, next : PFileEntryUPA;
begin
  entry := GetEntry( Index );

  CloseHandle( entry^.Handle );
  FAllFilesSize -= entry^.Info.Size;
  if index < FPackedCount then begin
    if (index < FPackedCount-1) and FSolid then begin
      next := GetEntry( Index+1 );
      next^.SkipBytesBefore += entry^.SkipBytesBefore + entry^.Info.Size;
    end;
    FPackedCount -= 1;
  end;

  FFiles.Delete( Index );
  Dispose( entry );
end;

function TUniPackArchive.Count(): Integer;
begin
  Result := FFiles.Count;
end;

function TUniPackArchive.FileInfo( Index: Integer ): TFileInfoUPA;
begin
  Result := GetEntry(Index)^.Info;
end;

//note: Files.Sorted must be True
function TUniPackArchive.WriteFiles( DirPath: String; FileIndexes: TIntList ): TErrorUPA;
var
  CurrentFile, FileCount, fnum : Integer;
  BytesRead : SizeUInt;
  filetime : Int64;
  hfile : THandle;
  entry : PFileEntryUPA;
  fname : String;
begin
  if not FMethod.CanUnpack and (FPackedCount > 0) then
    Exit( eupMethodNotImplemented );

  if FileIndexes <> nil then begin
    if not FileIndexes.Sorted then
      Exit( eupInvalidInput );
    FileCount := FileIndexes.Count;
  end else begin
    FileCount := FFiles.Count;
  end;

  DirPath := IncludeTrailingPathDelimiter( DirPath );
  if not DirectoryExists( DirPath ) then CreateDir( DirPath );

  CurrentFile := -1;
  fnum := 0;
  PipelineInit();

  while FileCount > 0 do begin

    if FileIndexes = nil then begin
      CurrentFile += 1
    end else begin
      CurrentFile := FileIndexes[fnum];
      fnum += 1;
    end;

    PipelineSetNext( CurrentFile, False );
    entry := GetEntry( CurrentFile );
    fname := DirPath + entry^.Info.Name;
    hfile := FileCreate( fname );

    while FDplFileBytesLeft > 0 do begin
      BytesRead := PipelineGetData();
      FileWrite( hfile, FDplDataOutBuf^, BytesRead );
    end;

    FileClose( hfile );
    filetime := entry^.Info.Time;
    if filetime <> -1 then SetFileTimePOSIX( fname, filetime );
    UPA_SetFileAttr( fname, entry^.Info.Attr );
    FileCount -= 1;

  end;

  PipelineFree();
  Result := eupOK;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function TUniPackArchive.AddEntry( const aInfo: TFileInfoUPA; aHandle: THandle;
  aOffsetStream: QWord ): Integer;
var
  entry : PFileEntryUPA;
begin
  New( entry );
  if entry = nil then
    Exit( upaInvalidIndex );

  with entry^ do begin
    Info := aInfo;
    Handle := aHandle;
    StreamOffset := aOffsetStream;
    SkipBytesBefore := 0;
  end;

  Result := FFiles.Add( entry );
end;

function TUniPackArchive.GetEntry( Index: Integer ): PFileEntryUPA;
begin
  Result := PFileEntryUPA( FFiles[Index] );
end;

procedure TUniPackArchive.CloseHandle( Handle: THandle );
begin
  if Handle <> FFileHandle then
    FileClose( Handle );
end;

//returns FFiles.Count if StartIndex'ed file and all subsequent are empty
function TUniPackArchive.FindFirstNotEmptyFile( StartIndex: Integer ): Integer;
begin
  repeat
    Result := StartIndex;
    if Result >= FFiles.Count then
      Exit( FFiles.Count );
    StartIndex += 1;
  until GetEntry(Result)^.Info.Size > 0;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

{
  Data pipeline intended to get plain data from packed/non-packed data stream.
  How pipeline works:
  Firsly, let's assume an important invariant: packed files (files
  from archive) always go first in FFiles list. This is guaranteed
  by adding file records to empty list when opening archive.
  In general, we have an abstract data stream that looks like this:
    packed1#packed2#...#packedN#newfile1#newfile2#...newfileM
  where N is FPackedCount and M is (FFiles.Count-FPackedCount).
  So, if we start from packed file 3, then we skip first two files
  (even if archive is solid, obviously) and begin to unpack data.
  Note that files must be enumerated ascendingly when accessing.
  For solid archives: if packed file that was between two packed too, was
  removed, it's data will be skipped automatically (see FDplSkipBytesLeft and
  TFileEntryUPA.SkipBytesBefore).
}

procedure TUniPackArchive.PipelineInit();
var
  packed_size : QWord;
begin
  FDplCurrentFile := FindFirstNotEmptyFile(0);
  if FDplCurrentFile = FFiles.Count then
    Exit;

  PipelineResetState( True );
  FDplDataOutBuf := GetMem( FOutputBufSize );

  //if there are packed files, init decompressor context
  if FPackedCount > 0 then begin
    FDplPackedBuf := GetMem( FPackBufSize );
    SetFilePos( FFileHandle, FStreamStartPos );
    if FSolid then packed_size := FStreamSize
      else packed_size := GetEntry(FDplCurrentFile)^.Info.PackSize;
    FMethod.InitUnpack( packed_size );

  end else begin
    FDplPackedBuf := nil;
  end;
end;

procedure TUniPackArchive.PipelineResetState( Forced: Boolean );
var
  entry : PFileEntryUPA;
begin
  if FDplCurrentFile = FFiles.Count then begin
    FDplFileBytesLeft := 0;
    FDplSkipBytesLeft := 0;
  end else begin
    entry := GetEntry( FDplCurrentFile );
    FDplFileBytesLeft := entry^.Info.Size;
    FDplSkipBytesLeft := entry^.SkipBytesBefore;
  end;
  if not FSolid or Forced then
    FDplChunkDataLeft := 0;
end;

procedure TUniPackArchive.PipelineEndUnpack();
begin
  if FDplPackedBuf <> nil then begin
    FMethod.EndUnpack();
    FreeMem( FDplPackedBuf );
    FDplPackedBuf := nil;
  end;
end;

procedure TUniPackArchive.PipelineFree();
begin
  PipelineEndUnpack();
  FreeMem( FDplDataOutBuf );
end;

//note: next file index must be always larger than current
function TUniPackArchive.PipelineSetNext( FileIndex: Integer;
  SkipEmpty: Boolean ): Boolean;
var
  entry : PFileEntryUPA;
  seek_file : THandle;
  seek_pos : QWord;
begin
  if FileIndex <= FDplCurrentFile then
    Exit( False );
  if SkipEmpty then
    FileIndex := FindFirstNotEmptyFile( FileIndex );
  if FileIndex >= FFiles.Count then begin
    FDplCurrentFile := FFiles.Count;
    PipelineResetState();
    PipelineEndUnpack();
    Exit( True );
  end;

  if not FSolid then begin
    FDplCurrentFile := FileIndex;
    PipelineResetState();
    entry := GetEntry( FileIndex );
    if FileIndex < FPackedCount then begin
      seek_file := FFileHandle;
      seek_pos := FStreamStartPos + entry^.StreamOffset;
      FMethod.EndUnpack();
      FMethod.InitUnpack( entry^.Info.PackSize );
    end else begin
      seek_file := entry^.Handle;
      seek_pos := 0;
      PipelineEndUnpack(); //we don't need decompressor context anymore
    end;
    SetFilePos( seek_file, seek_pos );

  end else begin
    //if packed data is solid, successively unpack files that are between
    //old and new index to skip them (we don't use unpacked data here)
    //note: empty files between old and new indexes will be successfully
    //skipped because FDplFileBytesLeft will equal to 0
    repeat
      if FDplFileBytesLeft = 0 then begin
        FDplCurrentFile += 1;
        PipelineResetState();
      end else begin
        PipelineGetData();
      end;
    until FDplCurrentFile = FileIndex;
  end;

  Result := True;
end;

function TUniPackArchive.PipelineGetData( OutBufOffset: SizeUInt;
  AutoNext: Boolean ): SizeUInt;
var
  out_size, fread_size : SizeUInt;
  chunk_size, skip_size : QWord;
  out_buf, void_buf : Pointer; //for skipping data
begin
  Result := 0;

  if AutoNext and (FDplFileBytesLeft = 0) then
    PipelineSetNext( FDplCurrentFile+1 );
  if (FDplFileBytesLeft = 0) then
    Exit;

  out_size := FOutputBufSize - OutBufOffset;
  if out_size > FDplFileBytesLeft then out_size := FDplFileBytesLeft;
  out_buf := FDplDataOutBuf + OutBufOffset;

  if FDplCurrentFile < FPackedCount then begin
    //if OutBufOffset > 0 then user may need data in FDplDataOutBuf before
    //this offset, so we allocate another buffer to skip data
    if OutBufOffset = 0 then void_buf := FDplDataOutBuf
      else void_buf := GetMem( FOutputBufSize );

    skip_size := 0;
    repeat
      //feeding new packed data chunk, if needed
      chunk_size := FMethod.UnpackLeft();
      if (FDplChunkDataLeft = 0) and (chunk_size > 0) then begin
        if chunk_size > FPackBufSize then chunk_size := FPackBufSize;
        fread_size := FileRead( FFileHandle, FDplPackedBuf^, chunk_size );
        if fread_size <> chunk_size then
          Exit;
        FMethod.UnpackSetChunk( FDplPackedBuf, chunk_size );
        FDplChunkDataLeft := chunk_size;
      end;

      //performing decompression step
      FDplSkipBytesLeft -= skip_size;
      if not FSolid or (FDplSkipBytesLeft = 0) then begin
        Result := FMethod.UnpackStep( out_buf, out_size, @FDplChunkDataLeft );
      end else begin //if less
        skip_size := FDplSkipBytesLeft;
        if skip_size > FOutputBufSize then skip_size := FOutputBufSize;
        skip_size := FMethod.UnpackStep( void_buf, skip_size, @FDplChunkDataLeft );
      end;
    until FDplSkipBytesLeft = 0;

    if void_buf <> FDplDataOutBuf then
      FreeMem( void_buf );

  end else begin
    //if we are on non-packed files now, simply read bytes
    fread_size := FileRead( GetEntry(FDplCurrentFile)^.Handle,
      out_buf^, out_size );
    if fread_size <> out_size then
      Exit;
    Result := out_size;
  end;

  FDplFileBytesLeft -= Result;
end;

end.

