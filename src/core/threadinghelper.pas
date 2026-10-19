unit threadinghelper;


interface

uses
  Classes, SysUtils, MeasurementObserver, Contnrs, AnnealTypes,
  Generics.Collections,syncobjs,AnnealManager;
type
  THardwareThread = class(TThread,IMeasurementObserver)
  private
    FCommandQueue:  TQueue<THardwareCommand>;
    FCommandLock: TCriticalSection;
    FCommandEvent: TEvent;
    FAbortRequested: Integer;

    FAnnealManager: TAnnealManager;

    FObserver: IMeasurementObserver;

    function GetNextCommand(
      out Command: THardwareCommand): Boolean;

  protected
    procedure Execute; override;
     { Override TComponent interface methods to disable reference counting }

    function QueryInterface(const IID: TGuid; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;

  public
    constructor Create(Observer: IMeasurementObserver);
    destructor Destroy; override;
    procedure StopThread;
    procedure Initialize;
    procedure Anneal(const Parameters: TAnnealConfig);
    procedure Probe(const Parameters: TProbingParameters);
    procedure AnnealBatch(const Parameters: TAnnealConfigArray);
    procedure ProbeBatch(const Parameters: TProbingParameters);

    procedure AbortOperation;
    procedure ResetAbort;

    { IMeasurementObserver implementation }

    procedure Log(
      const Msg: string);

    procedure InitializeSetup(
  Status: TSetupStatus);

    procedure MeasurementPoint(
      Time: Double;
      Value: Double);

    procedure TaskStarted(
);

    procedure TaskFinished(
      Result: THardwareResult);

    procedure Error(
      const Msg: string);

    function ShouldAbort: Boolean;
  end;



implementation

constructor THardwareThread.Create(Observer: IMeasurementObserver);
begin
  inherited Create(True);  // Create suspended
  FreeOnTerminate := False;
  FObserver := Observer;
  FCommandQueue:= TQueue<THardwareCommand>.Create;
  FCommandLock := TCriticalSection.Create;
  FCommandEvent := TEvent.Create(
    nil,     // Default security attributes
    False,   // Auto-reset event
    False,   // Initially nonsignaled
    ''       // Unnamed event
  );
end;

destructor THardwareThread.Destroy;
begin
   FreeAndNil(FAnnealManager);
   FCommandLock.Free;
   FCommandQueue.Free;
   FCommandEvent.Free;
   inherited Destroy;
end;

procedure THardwareThread.Execute;
var
  Command: THardwareCommand;
begin
  FAnnealManager := TAnnealManager.Create(Self);

  try
    while not Terminated do
    begin
      FCommandEvent.WaitFor(INFINITE);

      while GetNextCommand(Command) do
      begin
        case Command.CommandType of

          hcInitialize:
            FAnnealManager.Initialize;

          hcAnnealSingle:
            FAnnealManager.AnnealSingle(
              Command.AnnealParameters);

          hcProbeSingle:
            FAnnealManager.ProbeSingle(
              Command.ProbingParameters);

          hcAnnealBatch:
            FAnnealManager.AnnealBatch(
              Command.AnnealConfigArray);

          hcProbeBatch:
            FAnnealManager.ProbeBatch(
              Command.ProbingParameters);

          hcShutdown:
            begin
              Terminate;
              Break;
            end;

        end;
      end;
    end;
  finally
  end;
end;

procedure THardwareThread.StopThread;
begin
  Terminate;
  FCommandEvent.SetEvent;
end;

function THardwareThread.GetNextCommand(
  out Command: THardwareCommand): Boolean;
begin
  FCommandLock.Acquire;
  try
    Result := FCommandQueue.Count > 0;

    if Result then
      Command := FCommandQueue.Dequeue;
  finally
    FCommandLock.Release;
  end;

  if Result and (FCommandQueue.Count = 0) then
    FCommandEvent.ResetEvent;
end;

function THardwareThread.QueryInterface(const IID: TGuid; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function THardwareThread._AddRef: Integer;
begin
  Result := -1; // Prevents Delphi from treating your Main Form as a COM object
end;

function THardwareThread._Release: Integer;
begin
  Result := -1; // Prevents accidental destruction when interface scope ends
end;

procedure THardwareThread.Initialize;
var
  Command: THardwareCommand;
begin
  Command.CommandType := hcInitialize;
  {}

  FCommandLock.Acquire;
  try
    FCommandQueue.Enqueue(Command);
  finally
    FCommandLock.Release;
  end;

  FCommandEvent.SetEvent;
end;

procedure THardwareThread.Anneal(
  const Parameters: TAnnealConfig);
var
  Command: THardwareCommand;
begin
  Command.CommandType := hcAnnealSingle;

  Command.AnnealParameters := Parameters;

  FCommandLock.Acquire;
  try
    FCommandQueue.Enqueue(Command);
  finally
    FCommandLock.Release;
  end;

  FCommandEvent.SetEvent;
end;

procedure THardwareThread.AnnealBatch(
  const Parameters: TAnnealConfigArray);
var
  Command: THardwareCommand;
begin
  Command.CommandType := hcAnnealBatch;

  Command.AnnealConfigArray := Parameters;
  FCommandLock.Acquire;
  try
    FCommandQueue.Enqueue(Command);
  finally
    FCommandLock.Release;
  end;

  FCommandEvent.SetEvent;
end;

procedure THardwareThread.Probe(
  const Parameters: TProbingParameters);
var
  Command: THardwareCommand;
begin
  Command.CommandType := hcProbeSingle;

  Command.ProbingParameters := Parameters;
  FCommandLock.Acquire;
  try
    FCommandQueue.Enqueue(Command);
  finally
    FCommandLock.Release;
  end;

  FCommandEvent.SetEvent;
end;

procedure THardwareThread.ProbeBatch(
  const Parameters: TProbingParameters);
var
  Command: THardwareCommand;
begin
  Command.CommandType := hcProbeBatch;
  Command.ProbingParameters := Parameters;

  FCommandLock.Acquire;
  try
    FCommandQueue.Enqueue(Command);
  finally
    FCommandLock.Release;
  end;

  FCommandEvent.SetEvent;
end;

procedure THardwareThread.Log(const Msg: string);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.Log(Msg);
    end);
end;

procedure THardwareThread.InitializeSetup(
  Status: TSetupStatus
);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.InitializeSetup(Status);
    end);
end;

procedure THardwareThread.AbortOperation;
begin
  TInterlocked.Exchange(FAbortRequested, 1);
end;

procedure THardwareThread.ResetAbort;
begin
  TInterlocked.Exchange(FAbortRequested, 0);
end;

procedure THardwareThread.MeasurementPoint(
  Time: Double;
  Value: Double
);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.MeasurementPoint(Time, Value);
    end);
end;

procedure THardwareThread.TaskStarted(
);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.TaskStarted();
    end);
end;

procedure THardwareThread.TaskFinished(
  Result: THardwareResult
);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.TaskFinished(Result);
    end);
end;

procedure THardwareThread.Error(
  const Msg: string);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.Error(Msg);
    end);
end;

function THardwareThread.ShouldAbort: Boolean;
begin
  Result := TInterlocked.CompareExchange(FAbortRequested, 0, 0) <> 0;
end;
end.

