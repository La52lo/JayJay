unit DeviceManagerUnit;


interface

uses
  Classes, SysUtils, Contnrs, DateUtils, TaskSelectDialogUnit,AnnealTypes;

type

  { TDeviceInfo - Holds device metadata }
  TDeviceInfo = class
  private
    FName: string;
    FCreatedAt: TDateTime;
    FModifiedAt: TDateTime;
  public
    constructor Create(const AName: string);
    property Name: string read FName write FName;
    property CreatedAt: TDateTime read FCreatedAt;
    property ModifiedAt: TDateTime read FModifiedAt write FModifiedAt;
  end;

  { TTaskInfo - Holds task metadata }
  {TTaskType = (ttSingleAnneal, ttBatchAnneal, ttSingleResistance, ttBatchResistance);}

  THardwareTask = class
  private
    FName: string;
    FTaskType: TNodeType;
    FCreatedAt: TDateTime;
    FExecutedAt: TDateTime;
    FIsRunning: Boolean;
  public
    constructor Create(const AName: string; ATaskType: TNodeType);
    procedure Serialize(AStream: TStream); virtual; abstract;
    procedure SetResult(const AResult: THardwareResult); virtual; abstract;
    procedure SetConfig(const AResult: THardwareResult); virtual; abstract;
    property Name: string read FName;
    property TaskType: TNodeType read FTaskType;
    property CreatedAt: TDateTime read FCreatedAt;
    property ExecutedAt: TDateTime read FExecutedAt write FExecutedAt;
    property IsRunning: Boolean read FIsRunning write FIsRunning;

  end;
   TTypedHardwareTask<TInput, TOutput> = class(THardwareTask)
  private
    FParameters: TInput;
    FData: TOutput;
  public
    property Parameters: TInput read FParameters write FParameters;
    property Result: TOutput read FData write FData;
    procedure SetResult(const AResult: THardwareResult); override;
    procedure SetConfig(const AResult: THardwareResult); virtual; abstract;
  end;

  TAnnealTask = class(TTypedHardwareTask<TAnnealConfig,TAnnealResult>)
   public
   constructor Create(const AName: string; ATaskType: TNodeType);
    procedure Serialize(AStream: TStream); override;
    procedure SetResult(const AResult: THardwareResult); override;
  end;

  TProbeTask = class(TTypedHardwareTask<TProbingParameters,TProbingResult>)
   public
   constructor Create(const AName: string; ATaskType: TNodeType);
    procedure Serialize(AStream: TStream); override;
    procedure SetResult(const AResult: THardwareResult); override;
  end;

  TBatchAnnealTask = class(TTypedHardwareTask<TAnnealParameterArray,TAnnealResultArray>)
   public
   constructor Create(const AName: string; ATaskType: TNodeType);
    procedure Serialize(AStream: TStream); override;
    procedure SetResult(const AResult: THardwareResult); override;
  end;

   TBatchProbeTask = class(TTypedHardwareTask<TProbingParameters,TProbingResultArray>)
   public
    constructor Create(const AName: string; ATaskType: TNodeType);
    procedure Serialize(AStream: TStream); override;
    procedure SetResult(const AResult: THardwareResult); override;
  end;

  { TDeviceManager - Manages device, task, and junction information }
  TDeviceManager = class
  private
    FCurrentDevice: TDeviceInfo;
    FTasks: TObjectList;
    FIsOperationRunning: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure CreateNewDevice(const AName: string);
    procedure LoadDevice(const AFilePath: string);
    procedure SaveDevice(const AFilePath: string);
    
    procedure AddTask(Task: THardwareTask;const AName: string; ATaskType: TNodeType);
    procedure RemoveTask(ATaskIndex: Integer);
    function GetTaskCount: Integer;
    function GetTask(AIndex: Integer): THardwareTask;

    procedure SetOperationRunning(ARunning: Boolean);
    
    property CurrentDevice: TDeviceInfo read FCurrentDevice;
    property IsOperationRunning: Boolean read FIsOperationRunning;
  end;

var
  DeviceManager: TDeviceManager;

implementation

{ TDeviceInfo }

constructor TDeviceInfo.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FCreatedAt := Now;
  FModifiedAt := Now;
end;

{ TTaskInfo }

constructor THardwareTask.Create(const AName: string; ATaskType: TNodeType);
begin
  inherited Create;
  FName := AName;
  FTaskType := ATaskType;
  FCreatedAt := Now;
  FExecutedAt := 0;
  FIsRunning := False;
end;

constructor TAnnealTask.Create(const AName: string; ATaskType: TNodeType);
var
AnnealParameters : TAnnealConfig;
begin
  inherited;
  with FParameters do
    begin
      TargetResistance:= 4500;
      Temperature:= 70;
      PulseNegative:= -0.6;
      PulsePositive:= 0.6;
      PulseLength:= 2.0;
      PulsePairs:= 500;
      Cycles:= 2;
      MeasureVoltage:= 0.2;
      MeasureTime:= 1.0;
      ThresholdShort:= 500.0;
      ThresholdOpen := 20000.0;
      InitialWait := 1.0;
    end;
end;

constructor TBatchAnnealTask.Create(const AName: string; ATaskType: TNodeType);

begin
  inherited;
  SetLength(FParameters,1);
  {Parameters := AnnealParameters;}
  with FParameters[0] do
    begin
      TargetResistance:= 4500;
      Temperature:= 70;
      PulseNegative:= -0.6;
      PulsePositive:= 0.6;
      PulseLength:= 2.0;
      PulsePairs:= 500;
      Cycles:= 2;
      MeasureVoltage:= 0.2;
      MeasureTime:= 1.0;
      ThresholdShort:= 500.0;
      ThresholdOpen := 20000.0;
      InitialWait := 1.0;
    end;
end;

constructor TProbeTask.Create(const AName: string; ATaskType: TNodeType);
begin
  inherited;
  with FParameters do
    begin
      VoltageList        := [0.1,0.05,-0.05,-0.1];
      MeasureTime        := 0.5;
      InitialWait        := 1.0;    { s,  default 1.0    }
    end;
end;

constructor TBatchProbeTask.Create(const AName: string; ATaskType: TNodeType);
begin
  inherited;
  with FParameters do
    begin
      VoltageList        := [0.1,0.05,-0.05,-0.1];
      MeasureTime        := 0.5;
      InitialWait        := 1.0;    { s,  default 1.0    }
    end;
end;

procedure TAnnealTask.SetResult(const AResult: THardwareResult);
begin
  Result := AResult.AnnealResult;
end;

procedure TProbeTask.SetResult(const AResult: THardwareResult);
begin
  Result := AResult.ProbingResult;
end;

procedure TBatchAnnealTask.SetResult(const AResult: THardwareResult);
begin
  Result := AResult.AnnealResultArray;
end;

procedure TBatchProbeTask.SetResult(const AResult: THardwareResult);
begin
  Result := AResult.ProbingResultArray;
end;

{ TDeviceManager }
 procedure TAnnealTask.Serialize(AStream: TStream);
 begin

 end;

 procedure TBatchAnnealTask.Serialize(AStream: TStream);
 begin

 end;

 procedure TProbeTask.Serialize(AStream: TStream);
 begin

 end;

 procedure TBatchProbeTask.Serialize(AStream: TStream);
 begin

 end;


constructor TDeviceManager.Create;
begin
  inherited Create;
  FCurrentDevice := nil;
  FTasks := TObjectList.Create(True);
  FIsOperationRunning := False;
end;

destructor TDeviceManager.Destroy;
begin
  if Assigned(FCurrentDevice) then
    FCurrentDevice.Free;
  FTasks.Free;
  inherited;
end;

procedure TDeviceManager.CreateNewDevice(const AName: string);
begin
  if Assigned(FCurrentDevice) then
    FCurrentDevice.Free;
  FCurrentDevice := TDeviceInfo.Create(AName);
  FTasks.Clear;
  FIsOperationRunning := False;
end;

procedure TDeviceManager.LoadDevice(const AFilePath: string);
begin
  { TODO: Implement device loading from file }
 end;

procedure TDeviceManager.SaveDevice(const AFilePath: string);
begin
  { TODO: Implement device saving to file }
end;

procedure TDeviceManager.AddTask(Task: THardwareTask; const AName: string; ATaskType: TNodeType);
var
  {Task: THardwareTask;}
begin
  {Task := THardwareTask.Create(AName, ATaskType); }
  FTasks.Add(Task);
end;

procedure TDeviceManager.RemoveTask(ATaskIndex: Integer);
begin
  if (ATaskIndex >= 0) and (ATaskIndex < FTasks.Count) then
    FTasks.Delete(ATaskIndex);
end;

function TDeviceManager.GetTaskCount: Integer;
begin
  Result := FTasks.Count;
end;

function TDeviceManager.GetTask(AIndex: Integer): THardwareTask;
begin
  if (AIndex >= 0) and (AIndex < FTasks.Count) then
    Result := THardwareTask(FTasks[AIndex])
  else
    Result := nil;
end;

procedure TDeviceManager.SetOperationRunning(ARunning: Boolean);
begin
  FIsOperationRunning := ARunning;
end;

initialization
  DeviceManager := TDeviceManager.Create;

finalization
  DeviceManager.Free;

end.
