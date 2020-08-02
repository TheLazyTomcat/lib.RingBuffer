{-------------------------------------------------------------------------------

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------}
{===============================================================================

  Ring buffer

    Simple and naive implementation of general ring buffer, also known as
    circular buffer. Currently the buffer is implemented as size-invariant.

    General buffer (TRingBuffer) can be used for any data as it operates on
    bytes and pointers. But if you want to create a typed ring buffer, there
    is a class TTypedRingBuffer created for that purpose. It should not be used
    directly, it is provided only as a base for other typed buffers. Create
    its descendant and implement it on type you want.

    An integer ring buffer is implemented as a guideline for how to inherit
    from TTypedRingBuffer and create specialized ring buffers.

  Version 1.1 (2020-01-02)

  Last change 2020-08-02

  ©2018-2020 František Milt

  Contacts:
    František Milt: frantisek.milt@gmail.com

  Support:
    If you find this code useful, please consider supporting its author(s) by
    making a small donation using the following link(s):

      https://www.paypal.me/FMilt

  Changelog:
    For detailed changelog and history please refer to this git repository:

      github.com/TheLazyTomcat/Lib.RingBuffer

  Dependencies:
    AuxTypes   - github.com/TheLazyTomcat/Lib.AuxTypes
    AuxClasses - github.com/TheLazyTomcat/Lib.AuxClasses

===============================================================================}
unit RingBuffer;

{$IFDEF FPC}
  {$MODE Delphi}
  {$DEFINE FPC_DisableWarns}
  {$MACRO ON}
{$ENDIF}
{$H+}

interface

uses
  SysUtils,
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

  ERBException = class(Exception);

  ERBOverwriteError = class(ERBException);

{===============================================================================
    TRingBuffer - class declaration
===============================================================================}
type
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
    Function WriteBuff(const Buff; Count: TMemSize): TMemSize; virtual;
    Function WriteMem(Ptr: Pointer; Count: TMemSize): TMemSize; virtual;
    Function ReadBuff(out Buff; Count: TMemSize): TMemSize; virtual;
    Function ReadMem(Ptr: Pointer; Count: TMemSize): TMemSize; virtual;
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

{===============================================================================
--------------------------------------------------------------------------------
                                TTypedRingBuffer
--------------------------------------------------------------------------------
===============================================================================}

type
  TValueOverwriteEvent = procedure(Sender: TObject; Count: Integer) of object;
  TValueOverwriteCallback = procedure(Sender: TObject; Count: Integer);

  ETRBException = class(ERBException);

{===============================================================================
    TTypedRingBuffer - class declaration
===============================================================================}
type
  TTypedRingBuffer = class(TRingBuffer)
  private
    fBaseTypeSize:              TMemSize;
    fOnValueOverwriteEvent:     TValueOverwriteEvent;
    fOnValueOverwriteCallback:  TValueOverwriteCallback;
    Function GetCount: Integer;
    Function GetWriteIndex: Integer;
    Function GetReadIndex: Integer;
  protected
    Function DoOverwrite(Count: TMemSize): Boolean; override;
  public
    constructor Create(BaseTypeSize: TMemSize; Count: Integer);
    Function UsedCount: Integer; virtual;
    Function FreeCount: Integer; virtual;
    property BaseTypeSize: TMemSize read fBaseTypeSize;
    property Count: Integer read GetCount;
    property WriteIndex: Integer read GetWriteIndex;
    property ReadIndex: Integer read GetReadIndex;
    property OnValueOverwriteEvent: TValueOverwriteEvent read fOnValueOverwriteEvent write fOnValueOverwriteEvent;
    property OnValueOverwriteCallback: TValueOverwriteCallback read fOnValueOverwriteCallback write fOnValueOverwriteCallback;
    property OnValueOverwrite: TValueOverwriteEvent read fOnValueOverwriteEvent write fOnValueOverwriteEvent;
  end;

{===============================================================================
--------------------------------------------------------------------------------
                               TIntegerRingBuffer
--------------------------------------------------------------------------------
===============================================================================}

type
  EIRBException = class(ETRBException);

  EIRBIndexOutOfBounds = class(EIRBException);
  EIRBWriteError       = class(EIRBException);
  EIRBReadError        = class(EIRBException);  

{===============================================================================
    TIntegerRingBuffer - class declaration
===============================================================================}
type
  TIntegerRingBuffer = class(TTypedRingBuffer)
  private
    Function GetValue(Index: Integer): Integer;
    procedure SetValue(Index: Integer; Value: Integer);
  public
    constructor Create(Count: Integer);
    procedure Write(Value: Integer); overload; virtual;
    Function Write(Values: PInteger; Count: Integer): Integer; overload; virtual;
    Function Write(Values: array of Integer): Integer; overload; virtual;
    Function Read: Integer; overload; virtual;
    Function Read(out Value: Integer): Boolean; overload; virtual;
    Function Read(Value: PInteger; Count: Integer): Integer; overload; virtual;
    property Values[Index: Integer]: Integer read GetValue write SetValue; default;
  end;

implementation

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
  obError:      raise ERBOverwriteError.CreateFmt('TRingBuffer: Overwriting %d bytes',[Count]);
else
  raise ERBException.CreateFmt('TRingBuffer.DoOverwrite: Invalid overwrite behavior (%d).',[Ord(fOverwriteBehavior)]);
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

Function TRingBuffer.WriteBuff(const Buff; Count: TMemSize): TMemSize;
begin
Result := WriteMem(@Buff,Count);
end;

//------------------------------------------------------------------------------

Function TRingBuffer.WriteMem(Ptr: Pointer; Count: TMemSize): TMemSize;
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

Function TRingBuffer.ReadBuff(out Buff; Count: TMemSize): TMemSize;
begin
Result := ReadMem(@Buff,Count);
end;

//------------------------------------------------------------------------------

Function TRingBuffer.ReadMem(Ptr: Pointer; Count: TMemSize): TMemSize;
var
  HighReadCount:  TMemSize;
  UsedSpaceBytes: TMemSize;
begin
Result := 0;
If (Count > 0) and not IsEmpty then
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
        Result := UsedSpaceBytes;
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

{===============================================================================
--------------------------------------------------------------------------------
                                TTypedRingBuffer
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TTypedRingBuffer - class declaration
===============================================================================}
{-------------------------------------------------------------------------------
    TTypedRingBuffer - private methods
-------------------------------------------------------------------------------}

Function TTypedRingBuffer.GetCount: Integer;
begin
Result := Integer(Size div fBaseTypeSize);
end;

//------------------------------------------------------------------------------

Function TTypedRingBuffer.GetWriteIndex: Integer;
begin
{$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
Result := Integer((PtrUInt(WritePtr) - PtrUInt(Memory)) div fBaseTypeSize);
{$IFDEF FPCDWM}{$POP}{$ENDIF}
end;

//------------------------------------------------------------------------------

Function TTypedRingBuffer.GetReadIndex: Integer;
begin
{$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
Result := Integer((PtrUInt(ReadPtr) - PtrUInt(Memory)) div fBaseTypeSize);
{$IFDEF FPCDWM}{$POP}{$ENDIF}
end;

{-------------------------------------------------------------------------------
    TTypedRingBuffer - protected methods
-------------------------------------------------------------------------------}

Function TTypedRingBuffer.DoOverwrite(Count: TMemSize): Boolean;
begin
If Assigned(fOnValueOverwriteEvent) then
  fOnValueOverwriteEvent(Self,Count div fBaseTypeSize);
If Assigned(fOnValueOverwriteCallback) then
  fOnValueOverwriteCallback(Self,Count div fBaseTypeSize);
Result := inherited DoOverwrite(Count);
end;

{-------------------------------------------------------------------------------
    TTypedRingBuffer - public methods
-------------------------------------------------------------------------------}

constructor TTypedRingBuffer.Create(BaseTypeSize: TMemSize; Count: Integer);
begin
If Count > 0 then
  begin
    inherited Create(TMemSize(Count) * BaseTypeSize);
    fBaseTypeSize := BaseTypeSize;
  end
else raise ETRBException.CreateFmt('TTypedRingBuffer.Create: Invalid count (%d)',[Count]);
end;

//------------------------------------------------------------------------------

Function TTypedRingBuffer.UsedCount: Integer;
begin
Result := UsedSpace div fBaseTypeSize;
end;

//------------------------------------------------------------------------------

Function TTypedRingBuffer.FreeCount: Integer;
begin
Result := FreeSpace div fBaseTypeSize;
end;

{===============================================================================
--------------------------------------------------------------------------------
                               TIntegerRingBuffer
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TIntegerRingBuffer - class declaration
===============================================================================}
{-------------------------------------------------------------------------------
    TIntegerRingBuffer - private methods
-------------------------------------------------------------------------------}

Function TIntegerRingBuffer.GetValue(Index: Integer): Integer;
begin
If (Index >= 0) and (Index < Count) then
  {$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
  Result := PInteger(PtrUInt(Memory) + (PtrUInt(Index) * SizeOf(Integer)))^
  {$IFDEF FPCDWM}{$POP}{$ENDIF}
else
  raise EIRBIndexOutOfBounds.CreateFmt('TIntegerRingBuffer.GetValue: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TIntegerRingBuffer.SetValue(Index: Integer; Value: Integer);
begin
If (Index >= 0) and (Index < Count) then
  {$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
  PInteger(PtrUInt(Memory) + (PtrUInt(Index) * SizeOf(Integer)))^ := Value
  {$IFDEF FPCDWM}{$POP}{$ENDIF}
else
  raise EIRBIndexOutOfBounds.CreateFmt('TIntegerRingBuffer.SetValue: Index (%d) out of bounds.',[Index]);
end;

{-------------------------------------------------------------------------------
    TIntegerRingBuffer - public methods
-------------------------------------------------------------------------------}

constructor TIntegerRingBuffer.Create(Count: Integer);
begin
inherited Create(SizeOf(Integer),Count);
end;

//------------------------------------------------------------------------------

procedure TIntegerRingBuffer.Write(Value: Integer);
begin
If WriteBuff(Value,SizeOf(Integer)) <> SizeOf(Integer) then
  raise EIRBWriteError.Create('TIntegerRingBuffer.Write: Writing error.');
end;

//------------------------------------------------------------------------------

Function TIntegerRingBuffer.Write(Values: PInteger; Count: Integer): Integer;
begin
Result := WriteMem(Values,Count * SizeOf(Integer)) div SizeOf(Integer);
end;

//------------------------------------------------------------------------------

Function TIntegerRingBuffer.Write(Values: array of Integer): Integer;
begin
Result := Write(Addr(Values[Low(Values)]),Length(Values));
end;

//------------------------------------------------------------------------------

Function TIntegerRingBuffer.Read: Integer;
begin
If ReadBuff(Result,SizeOf(Integer)) <> SizeOf(Integer) then
  raise EIRBReadError.Create('TIntegerRingBuffer.Read: Reading error.');
end;

//------------------------------------------------------------------------------

Function TIntegerRingBuffer.Read(out Value: Integer): Boolean;
begin
Result := ReadBuff(Value,SizeOf(Integer)) = SizeOf(Integer);
end;

//------------------------------------------------------------------------------

Function TIntegerRingBuffer.Read(Value: PInteger; Count: Integer): Integer;
begin
Result := ReadMem(Value,Count * SizeOf(Integer)) div SizeOf(Integer);
end;

end.
