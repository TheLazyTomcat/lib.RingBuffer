unit RingBuffer;

interface

uses
  AuxTypes, AuxClasses;

type
  TOverwriteBehavior = (obOverwrite,obDrop,obError);

  TOverwriteEvent = procedure(Sender: TObject; Count: TMemSize) of object;
  TOverwriteCallback = procedure(Sender: TObject; Count: TMemSize);

  TRingBuffer = class(TCustomObject)
  private
    fMemory:              Pointer;
    fSize:                TMemSize;
    fWritePtr:            Pointer;
    fReadPtr:             Pointer;
    fOverwriteBehavior:   TOverwriteBehavior;
    fIsEmpty:             Boolean;
    fOnOverwriteEvent:    TOverwriteEvent;
    fOnOverwriteCallback: TOverwriteCallback;
  protected
    Function DoOverwrite(Count: TMemSize): Boolean; virtual;
  public
    constructor Create(Size: TMemSize);
    destructor Destroy; override;
    Function Write(const Buff; Count: TMemSize): TMemSize; overload; virtual;
    Function Write(Ptr: Pointer; Count: TMemSize): TMemSize; overload; virtual;
    Function Read(out Buff; Count: TMemSize): TMemSize; overload; virtual;
    Function Read(Ptr: Pointer; Count: TMemSize): TMemSize; overload; virtual;
    Function UsedSpace: TMemSize; virtual;
    Function FreeSpace: TMemSize; virtual;
    Function IsEmpty: Boolean; virtual;
    Function IsFull: Boolean; virtual;
    property Memory: Pointer read fMemory;
    property Size: TMemSize read fSize;
    property WritePtr: Pointer read fWritePtr;
    property ReadPtr: Pointer read fReadPtr;
    property OverwriteBehavior: TOverwriteBehavior read fOverwriteBehavior write fOverwriteBehavior;
    property OnOverwriteEvent: TOverwriteEvent read fOnOverwriteEvent write fOnOverwriteEvent;
    property OnOverwriteCallback: TOverwriteCallback read fOnOverwriteCallback write fOnOverwriteCallback;
    property OnOverwrite: TOverwriteEvent read fOnOverwriteEvent write fOnOverwriteEvent;
  end;

implementation

uses
  SysUtils;

Function TRingBuffer.DoOverwrite(Count: TMemSize): Boolean;
begin
If Assigned(fOnOverwriteEvent) then
  fOnOverwriteEvent(Self,Count);
If Assigned(fOnOverwriteCallback) then
  fOnOverwriteCallback(Self,Count);
case fOverwriteBehavior of
  obOverwrite:  Result := True;
  obDrop:       Result := False;
  obError:      raise Exception.CreateFmt('TRingBuffer: Overwriting %d bytes',[Count]);
else
  raise Exception.CreateFmt('TRingBuffer.DoOverwrite: Invalid overwrite behavior (%d).',[Ord(fOverwriteBehavior)]);
end;
end;

//==============================================================================

constructor TRingBuffer.Create(Size: TMemSize);
begin
inherited Create;
fMemory := AllocMem(Size);
fSize := Size;
fWritePtr := fMemory;
fReadPtr := fMemory;
fOverwriteBehavior := obOverwrite;
fIsEmpty := True;
end;

//------------------------------------------------------------------------------

destructor TRingBuffer.Destroy;
begin
FreeMem(fMemory,fSize);
inherited;
end;

//------------------------------------------------------------------------------

Function TRingBuffer.Write(const Buff; Count: TMemSize): TMemSize;
begin
Result := Write(@Buff,Count);
end;

//------------------------------------------------------------------------------

Function TRingBuffer.Write(Ptr: Pointer; Count: TMemSize): TMemSize;
var
  Overwrite:      Boolean;
  HighWriteSpace: TMemSize;
begin
Result := 0;
If Count > 0 then
  begin
    If Count < fSize then
      begin
        Overwrite := Count > FreeSpace;
        If Overwrite then
          If not DoOverwrite(Count - FreeSpace) then Exit;
        HighWriteSpace := TMemSize(PtrUInt(fSize) - (PtrUInt(fWritePtr) - PtrUInt(fMemory)));
        // will it fit without splitting?
        If Count <= HighWriteSpace then
          begin
            // data will fit without splitting
            Move(Ptr^,fWritePtr^,Count);
            fWritePtr := Pointer(PtrUInt(fWritePtr) + PtrUInt(Count));
            If PtrUInt(fWritePtr) >= (PtrUInt(fMemory) + PtrUInt(fSize)) then
              fWritePtr := fMemory;
            Result := Count;
          end
        else
          begin
            // splitting is required...
            Move(Ptr^,fWritePtr^,HighWriteSpace);
            Move(Pointer(PtrUInt(Ptr) + HighWriteSpace)^,fMemory^,Count - HighWriteSpace);
            fWritePtr := Pointer(PtrUInt(fMemory) + (Count - HighWriteSpace));
            Result := Count;
          end;
      end
    else
      begin
        Overwrite := UsedSpace > 0;
        If Overwrite then
          If not DoOverwrite(UsedSpace) then Exit;
        // passed data cannot fit into the buffer,
        // store only number of bytes from the end that can fit
        Move(Pointer(PtrUInt(Ptr) + PtrUInt(Count - fSize))^,fMemory^,fSize);
        fWritePtr := fMemory;
        fReadPtr := fMemory;
        Result := fSize;
      end;
    fIsEmpty := False;
    If Overwrite then
      fReadPtr := fWritePtr;
  end;
end;

//------------------------------------------------------------------------------

Function TRingBuffer.Read(out Buff; Count: TMemSize): TMemSize;
begin
Result := Read(@Buff,Count);
end;

//------------------------------------------------------------------------------

Function TRingBuffer.Read(Ptr: Pointer; Count: TMemSize): TMemSize;
var
  HighReadCount:  TMemSize;
  UsedSpaceBytes: TMemSize;
begin
Result := 0;
If Count > 0 then
  begin
    HighReadCount := TMemSize(PtrUInt(fSize) - (PtrUInt(fReadPtr) - PtrUInt(fMemory)));
    UsedSpaceBytes := UsedSpace;
    If Count < UsedSpaceBytes then
      begin
        // only part of the buffer will be consumed
        If Count > HighReadCount then
          begin
            Move(fReadPtr^,Ptr^,HighReadCount);
            Move(fMemory^,Pointer(PtrUInt(Ptr) + PtrUInt(HighReadCount))^,Count - HighReadCount);
          end
        else Move(fReadPtr^,Ptr^,Count);
        fReadPtr := Pointer(PtrUInt(fReadPtr) + PtrUInt(Count));
        If PtrUInt(fReadPtr) >= (PtrUInt(fMemory) + PtrUInt(fSize)) then
          fReadPtr := Pointer(PtrUInt(fReadPtr) - PtrUInt(fSize));
        Result := Count;
      end
    else
      begin
        // all stored bytes will be consumed
        If HighReadCount <> UsedSpaceBytes then
          begin
            Move(fReadPtr^,Ptr^,HighReadCount);
            Move(fMemory^,Pointer(PtrUInt(Ptr) + PtrUInt(HighReadCount))^,UsedSpaceBytes - HighReadCount);
          end
        else Move(fReadPtr^,Ptr^,UsedSpaceBytes);
        fWritePtr := fMemory;
        fReadPtr := fMemory;
        fIsEmpty := True;
        Result := fSize;
      end;
  end;
end;

//------------------------------------------------------------------------------

Function TRingBuffer.UsedSpace: TMemSize;
begin
If fWritePtr <> fReadPtr then
  begin
    If PtrUInt(fWritePtr) > PtrUInt(fReadPtr) then
      Result := TMemSize(PtrUInt(fWritePtr) - PtrUInt(fReadPtr))
    else
      Result := TMemSize(PtrUInt(fSize) - (PtrUInt(fReadPtr) - PtrUInt(fWritePtr)));
  end
else
  begin
    If fIsEmpty then
      Result := 0
    else
      Result := fSize;
  end;
end;

//------------------------------------------------------------------------------

Function TRingBuffer.FreeSpace: TMemSize;
begin
Result := fSize - UsedSpace;
end;

//------------------------------------------------------------------------------

Function TRingBuffer.IsEmpty: Boolean;
begin
Result := UsedSpace <= 0;
end;

//------------------------------------------------------------------------------

Function TRingBuffer.IsFull: Boolean;
begin
Result := UsedSpace >= fSize;
end;

end.
