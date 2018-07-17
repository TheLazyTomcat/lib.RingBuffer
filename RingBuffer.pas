{-------------------------------------------------------------------------------

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------}
{===============================================================================

  Ring buffer (also known as circular buffer)

  ©František Milt 2018-07-16

  Version 1.0

  Dependencies:
    AuxTypes   - github.com/ncs-sniper/Lib.AuxTypes
    AuxClasses - github.com/ncs-sniper/Lib.AuxClasses

===============================================================================}
unit RingBuffer;

{$IFDEF FPC}
  {$MODE ObjFPC}{$H+}
  {$DEFINE FPC_DisableWarns}
  {$MACRO ON}
{$ENDIF}

interface

uses
  AuxTypes, AuxClasses;

{===============================================================================
--------------------------------------------------------------------------------
                                   TRingBuffer
--------------------------------------------------------------------------------
===============================================================================}

type
  TOverwriteBehavior = (obOverwrite,obDrop,obError);

  TOverwriteEvent = procedure(Sender: TObject; Count: TMemSize) of object;
  TOverwriteCallback = procedure(Sender: TObject; Count: TMemSize);

{===============================================================================
    TRingBuffer - class declaration
===============================================================================}

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

{$IFDEF FPC_DisableWarns}
  {$DEFINE FPCDWM}
  {$DEFINE W4055:={$WARN 4055 OFF}} // Conversion between ordinals and pointers is not portable
  {$DEFINE W4056:={$WARN 4056 OFF}} // Conversion between ordinals and pointers is not portable
{$ENDIF}

{===============================================================================
--------------------------------------------------------------------------------
                                   TRingBuffer
--------------------------------------------------------------------------------
===============================================================================}

{===============================================================================
    TRingBuffer - class implementation
===============================================================================}

{-------------------------------------------------------------------------------
    TRingBuffer - protected methods
-------------------------------------------------------------------------------}

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

{-------------------------------------------------------------------------------
    TRingBuffer - public methods
-------------------------------------------------------------------------------}

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
      {$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
        HighWriteSpace := TMemSize(PtrUInt(fSize) - (PtrUInt(fWritePtr) - PtrUInt(fMemory)));
      {$IFDEF FPCDWM}{$POP}{$ENDIF}
        // will it fit without splitting?
        If Count <= HighWriteSpace then
          begin
            // data will fit without splitting
            Move(Ptr^,fWritePtr^,Count);
          {$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
            fWritePtr := Pointer(PtrUInt(fWritePtr) + PtrUInt(Count));
            If PtrUInt(fWritePtr) >= (PtrUInt(fMemory) + PtrUInt(fSize)) then
              fWritePtr := fMemory;
          {$IFDEF FPCDWM}{$POP}{$ENDIF}
            Result := Count;
          end
        else
          begin
            // splitting is required...
            Move(Ptr^,fWritePtr^,HighWriteSpace);
          {$IFDEF FPCDWM}{$PUSH}W4055 W4056{$ENDIF}
            Move(Pointer(PtrUInt(Ptr) + HighWriteSpace)^,fMemory^,Count - HighWriteSpace);
            fWritePtr := Pointer(PtrUInt(fMemory) + (Count - HighWriteSpace));
          {$IFDEF FPCDWM}{$POP}{$ENDIF}
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
      {$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
        Move(Pointer(PtrUInt(Ptr) + PtrUInt(Count - fSize))^,fMemory^,fSize);
      {$IFDEF FPCDWM}{$POP}{$ENDIF}
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
  {$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
    HighReadCount := TMemSize(PtrUInt(fSize) - (PtrUInt(fReadPtr) - PtrUInt(fMemory)));
  {$IFDEF FPCDWM}{$POP}{$ENDIF}
    UsedSpaceBytes := UsedSpace;
    If Count < UsedSpaceBytes then
      begin
        // only part of the buffer will be consumed
        If Count > HighReadCount then
          begin
            Move(fReadPtr^,Ptr^,HighReadCount);
          {$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
            Move(fMemory^,Pointer(PtrUInt(Ptr) + PtrUInt(HighReadCount))^,Count - HighReadCount);
          {$IFDEF FPCDWM}{$POP}{$ENDIF}
          end
        else Move(fReadPtr^,Ptr^,Count);
      {$IFDEF FPCDWM}{$PUSH}W4055 W4056{$ENDIF}
        fReadPtr := Pointer(PtrUInt(fReadPtr) + PtrUInt(Count));
        If PtrUInt(fReadPtr) >= (PtrUInt(fMemory) + PtrUInt(fSize)) then
          fReadPtr := Pointer(PtrUInt(fReadPtr) - PtrUInt(fSize));
      {$IFDEF FPCDWM}{$POP}{$ENDIF}
        Result := Count;
      end
    else
      begin
        // all stored bytes will be consumed
        If HighReadCount <> UsedSpaceBytes then
          begin
            Move(fReadPtr^,Ptr^,HighReadCount);
          {$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
            Move(fMemory^,Pointer(PtrUInt(Ptr) + PtrUInt(HighReadCount))^,UsedSpaceBytes - HighReadCount);
          {$IFDEF FPCDWM}{$POP}{$ENDIF}
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
  {$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
    If PtrUInt(fWritePtr) > PtrUInt(fReadPtr) then
      Result := TMemSize(PtrUInt(fWritePtr) - PtrUInt(fReadPtr))
    else
      Result := TMemSize(PtrUInt(fSize) - (PtrUInt(fReadPtr) - PtrUInt(fWritePtr)));
  {$IFDEF FPCDWM}{$POP}{$ENDIF}
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
