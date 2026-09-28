unit threadinghelper2;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;
type
  THardwareCommandType = (
    hcInitialize,
    hcAnneal,
    hcProbe,
    hcAnnealBatch,
    hcProbeBatch,
    hcShutdown
  );

  THardwareCommand = record
    CommandType: THardwareCommandType;
    AnnealParameters: TAnnealParameters;
    ProbingParameters: TProbingParameters;
    AnnealParameterArray: TAnnealParameterArray;
    ProbingParameterArray: TProbingParameterArray;
  end;

  THardwareThread = class(TThread,IMeasurementObserver)
  private
    FCommandQueue: specialize TQueue<THardwareCommand>;
    FCommandLock: TCriticalSection;
    FCommandEvent: TEvent;

    FAnnealManager: TAnnealManager;

    FObserver: IMeasurementObserver;

    function GetNextCommand(
      out Command: THardwareCommand): Boolean;

  protected
    procedure Execute; override;

  public
    constructor Create(Observer: IMeasurementObserver);
    destructor Destroy; override;

    procedure Initialize;
    procedure Anneal(const Parameters: TAnnealParameters);
    procedure Probe(const Parameters: TProbingParameters);
    procedure AnnealBatch(const Parameters: TAnnealParameterArray);
    procedure ProbeBatch(const Parameters: TProbingParameterArray);

    { IMeasurementObserver implementation }

    procedure Log(const Msg: string);

    procedure Progress(
      Percent: Double;
      const Msg: string);

    procedure MeasurementPoint(
      Time: Double;
      Value: Double);

    procedure BatchStarted(
      Count: Integer);

    procedure BatchFinished;

    procedure JunctionStarted(
      const Name: string);

    procedure JunctionFinished(
      const Name: string;
      Result: TAnnealResult);

    procedure Error(
      E: Exception);
  end;



implementation

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

          hcAnneal:
            FAnnealManager.Anneal(
              Command.AnnealParameters);

          hcProbe:
            FAnnealManager.Probe(
              Command.ProbingParameters);

          hcAnnealBatch:
            FAnnealManager.AnnealBatch(
              Command.AnnealParameterArray);

          hcProbeBatch:
            FAnnealManager.ProbeBatch(
              Command.ProbingParameterArray);

          hcShutdown:
            begin
              Terminate;
              Break;
            end;

        end;
      end;
    end;
  finally
    FAnnealManager.Shutdown;
    FAnnealManager.Free;
  end;
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


procedure THardwareThread.Anneal(
  const Parameters: TAnnealParameters);
var
  Command: THardwareCommand;
begin
  Command.CommandType := hcAnneal;
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
  const Parameters: TAnnealParameterArray);
var
  Command: THardwareCommand;
begin
  Command.CommandType := hcAnnealBatch;
  Command.AnnealParameterArray := Parameters;
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
  Command.CommandType := hcProbe;
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

procedure THardwareThread.Progress(
  Percent: Double;
  const Msg: string);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.Progress(Percent, Msg);
    end);
end;

procedure THardwareThread.MeasurementPoint(
  Time: Double;
  Value: Double);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.MeasurementPoint(Time, Value);
    end);
end;

procedure THardwareThread.BatchStarted(
  Count: Integer);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.BatchStarted(Count);
    end);
end;

procedure THardwareThread.BatchFinished;
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.BatchFinished;
    end);
end;

procedure THardwareThread.JunctionStarted(
  const Name: string);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.JunctionStarted(Name);
    end);
end;

procedure THardwareThread.JunctionFinished(
  const Name: string;
  Result: TAnnealResult);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.JunctionFinished(Name, Result);
    end);
end;

procedure THardwareThread.Error(
  E: Exception);
var
  ErrorClass: string;
  ErrorMessage: string;
begin
  // Capture the values now. Don't pass the Exception object
  // across the thread boundary.
  if Assigned(E) then
  begin
    ErrorClass := E.ClassName;
    ErrorMessage := E.Message;
  end
  else
  begin
    ErrorClass := 'Exception';
    ErrorMessage := 'Unknown exception';
  end;

  TThread.Queue(nil,
    procedure
    var
      Error: Exception;
    begin
      if Assigned(FObserver) then
      begin
        Error := Exception.CreateFmt(
          '%s: %s',
          [ErrorClass, ErrorMessage]);

        try
          FObserver.Error(Error);
        finally
          Error.Free;
        end;
      end;
    end);
end;


end.

