unit threadinghelper;

{$mode delphi}{$H+}
{$modeswitch functionreferences}
{$modeswitch anonymousfunctions}

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
    procedure Anneal(const Parameters: TAnnealParameters; TaskID : String);
    procedure Probe(const Parameters: TProbingParameters; TaskID : String);
    procedure AnnealBatch(const Parameters: TAnnealParameterArray; TaskID : String);
    procedure ProbeBatch(const Parameters: TProbingParameters; TaskID : String);

    { IMeasurementObserver implementation }

    procedure Log(
      const Msg: string;
      TaskID: string);

    procedure Progress(
      Percent: Double;
      TaskID: string);

    procedure MeasurementPoint(
      Time: Double;
      Value: Double;
      TaskID: string);

    procedure TaskStarted(
      TaskID: string);

    procedure TaskFinished(
      Result: THardwareResult;
      TaskID: string);

    procedure Error(
      const Msg: string;
      TaskID: string);
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
              Command.AnnealParameters,Command.TaskID);

          hcProbe:
            FAnnealManager.ProbeResistance(
              Command.ProbingParameters,Command.TaskID);

          hcAnnealBatch:
            FAnnealManager.AnnealBatch(
              Command.AnnealParameterArray,Command.TaskID);

          hcProbeBatch:
            FAnnealManager.ProbeBatch(
              Command.ProbingParameters,Command.TaskID);

          hcShutdown:
            begin
              Terminate;
              Break;
            end;

        end;
      end;
    end;
  finally
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
  const Parameters: TAnnealParameters; TaskID : String);
var
  Command: THardwareCommand;
begin
  Command.CommandType := hcAnneal;
  Command.TaskID := TaskID;
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
  const Parameters: TAnnealParameterArray; TaskID : String);
var
  Command: THardwareCommand;
begin
  Command.CommandType := hcAnnealBatch;
  Command.TaskID := TaskID;
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
  const Parameters: TProbingParameters; TaskID : String);
var
  Command: THardwareCommand;
begin
  Command.CommandType := hcProbe;
  Command.TaskID := TaskID;
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
  const Parameters: TProbingParameters; TaskID : String);
var
  Command: THardwareCommand;
begin
  Command.CommandType := hcProbeBatch;
  Command.ProbingParameters := Parameters;
  Command.TaskID := TaskID;
  FCommandLock.Acquire;
  try
    FCommandQueue.Enqueue(Command);
  finally
    FCommandLock.Release;
  end;

  FCommandEvent.SetEvent;
end;

procedure THardwareThread.Log(const Msg: string; TaskID : String);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.Log(Msg,TaskID);
    end);
end;

procedure THardwareThread.Progress(
  Percent: Double;
   TaskID: string);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.Progress(Percent, TaskID);
    end);
end;

procedure THardwareThread.MeasurementPoint(
  Time: Double;
  Value: Double;
  TaskID: String);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.MeasurementPoint(Time, Value,TaskID);
    end);
end;

procedure THardwareThread.TaskStarted(
  TaskID: string);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.TaskStarted(TaskID);
    end);
end;

procedure THardwareThread.TaskFinished(
  Result: THardwareResult;
  TaskID: string);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.TaskFinished(Result,TaskID);
    end);
end;

procedure THardwareThread.Error(
  const Msg: string;
  TaskID: string);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FObserver) then
        FObserver.Error(Msg,TaskID);
    end);
end;
end.

