unit RingBuffer;

interface

uses
  AuxTypes, AuxClasses;

type
  TOverwriteBehavior = (obOverwrite,obDrop,obError);

  TOverwriteEvent = procedure(Sender: TObject; Count: TMemSize) of object;

  TRingBuffer = class(TObject)
  private
    fMemory:      Pointer;
    fSize:        TMemSize;
    fReadPtr:     Pointer;
    fWritePtr:    Pointer;
    fOverwrite:   TOverwriteBehavior;
    fOnOverwrite: TOverwriteEvent;
  protected
  public
    constructor Create(Size: TMemSize);
    destructor Destroy; override;
    //procedure Write(const Buff; Count: TMemSize); overload; virtual;
    //procedure Write(Ptr: Pointer; Count: TMemSize); overload; virtual;
    //procedure Read(out Buff; Count: TMemSize); overload; virtual;
    //provedure Read(Ptr: Pointer; Count: TMemSize); overload; virtual;
    Function FreeSpace: TMemSize; virtual;
    Function IsEmpty: Boolean; virtual;
    Function IsFull: Boolean; virtual;
    property Memory: Pointer read fMemory;
    property Size: TMemSize read fSize;
    property Overwrite: TOverwriteBehavior read fOverwrite write fOverwrite;
    property OnOverwrite: TOverwriteEvent read fOnOverwrite write fOnOverwrite;
  end;

implementation

constructor TRingBuffer.Create(Size: TMemSize);
begin
inherited Create;
end;

destructor TRingBuffer.Destroy;
begin

inherited;
end;

Function TRingBuffer.FreeSpace: TMemSize;
begin
end;

Function TRingBuffer.IsEmpty: Boolean;
begin
end;

Function TRingBuffer.IsFull: Boolean;
begin
end;

end.
