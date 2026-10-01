unit DeviceManagerUnit;


interface

uses
  Classes, SysUtils, Contnrs, DateUtils, TaskSelectDialogUnit, AnnealTypes, System.JSON;

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
    FDisplayName: string;
    constructor Create(const AName: string; ATaskType: TNodeType);
    procedure Serialize(AStream: TStream); virtual; abstract;
    procedure SetResult(const AResult: THardwareResult); virtual; abstract;
    procedure SetConfig(const AResult: THardwareResult); virtual; abstract;
    property Name: string read FName write FName;
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
    {procedure SetResult(const AResult: THardwareResult); override;}
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
{
var
  DeviceManager: TDeviceManager;}

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
  FDisplayName := 'Single Anneal';
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
  FDisplayName := 'Batch Anneal';
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
  FDisplayName := 'Single Resistance';
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
  FDisplayName := 'Batch Resistance';
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
var
  JsonObject: TJSONObject;
  TasksArray: TJSONArray;
  i: Integer;
  TaskObject: TJSONObject;
  TaskType: TNodeType;
  TaskName: string;
  DeviceName: string;
  CreatedAt, ModifiedAt: TDateTime;
  JsonText: string;
  StringList: TStringList;
begin
  try
    if not FileExists(AFilePath) then
    begin
      raise Exception.Create('Device file not found: ' + AFilePath);
    end;

    StringList := TStringList.Create;
    try
      StringList.LoadFromFile(AFilePath);
      JsonText := StringList.Text;
    finally
      StringList.Free;
    end;

    JsonObject := TJSONObject.ParseJSONValue(JsonText) as TJSONObject;
    try
      if not Assigned(JsonObject) then
      begin
        raise Exception.Create('Invalid JSON format in device file');
      end;

      { Load device metadata }
      DeviceName := JsonObject.GetValue<string>('DeviceName', 'Unnamed Device');
      CreatedAt := StrToDateTime(JsonObject.GetValue<string>('CreatedAt', FormatDateTime('yyyy-mm-dd hh:mm:ss', Now)));
      ModifiedAt := StrToDateTime(JsonObject.GetValue<string>('ModifiedAt', FormatDateTime('yyyy-mm-dd hh:mm:ss', Now)));

      { Create new device }
      if Assigned(FCurrentDevice) then
        FCurrentDevice.Free;
      FCurrentDevice := TDeviceInfo.Create(DeviceName);
      FCurrentDevice.FCreatedAt := CreatedAt;
      FCurrentDevice.FModifiedAt := ModifiedAt;

      { Clear existing tasks }
      FTasks.Clear;

      { Load tasks }
      if Assigned(JsonObject.GetValue('Tasks')) then
      begin
        TasksArray := JsonObject.GetValue('Tasks') as TJSONArray;
        if Assigned(TasksArray) then
        begin
          for i := 0 to TasksArray.Count - 1 do
          begin
            TaskObject := TasksArray.Items[i] as TJSONObject;
            TaskName := TaskObject.GetValue<string>('TaskName', 'Task' + IntToStr(i));
            TaskType := TNodeType(TaskObject.GetValue<Integer>('TaskType', Integer(ntDevice)));

            { Reconstruct tasks based on type }
            case TaskType of
              ntAnneal:
                FTasks.Add(TAnnealTask.Create(TaskName, TaskType));
              ntBatchAnneal:
                FTasks.Add(TBatchAnnealTask.Create(TaskName, TaskType));
              ntProbe:
                FTasks.Add(TProbeTask.Create(TaskName, TaskType));
              ntBatchProbe:
                FTasks.Add(TBatchProbeTask.Create(TaskName, TaskType));
            end;
          end;
        end;
      end;

      FIsOperationRunning := False;

    finally
      JsonObject.Free;
    end;

  except
    on E: Exception do
    begin
      raise Exception.Create('Error loading device from file: ' + E.Message);
    end;
  end;
end;

procedure TDeviceManager.SaveDevice(const AFilePath: string);
var
  JsonObject: TJSONObject;
  TasksArray: TJSONArray;
  i: Integer;
  TaskObject: TJSONObject;
  Task: THardwareTask;
  StringList: TStringList;
begin
  try
    if not Assigned(FCurrentDevice) then
    begin
      raise Exception.Create('No device loaded. Cannot save.');
    end;

    { Create root JSON object }
    JsonObject := TJSONObject.Create;
    try
      { Save device metadata }
      JsonObject.AddPair('DeviceName', TJSONString.Create(FCurrentDevice.FName));
      JsonObject.AddPair('CreatedAt', TJSONString.Create(FormatDateTime('yyyy-mm-dd hh:mm:ss', FCurrentDevice.FCreatedAt)));
      JsonObject.AddPair('ModifiedAt', TJSONString.Create(FormatDateTime('yyyy-mm-dd hh:mm:ss', FCurrentDevice.FModifiedAt)));

      { Create tasks array }
      TasksArray := TJSONArray.Create;
      JsonObject.AddPair('Tasks', TasksArray);

      { Save each task }
      for i := 0 to FTasks.Count - 1 do
      begin
        Task := THardwareTask(FTasks[i]);
        TaskObject := TJSONObject.Create;

        TaskObject.AddPair('TaskName', TJSONString.Create(Task.FName));
        TaskObject.AddPair('TaskType', TJSONNumber.Create(Integer(Task.FTaskType)));
        TaskObject.AddPair('DisplayName', TJSONString.Create(Task.FDisplayName));
        TaskObject.AddPair('CreatedAt', TJSONString.Create(FormatDateTime('yyyy-mm-dd hh:mm:ss', Task.FCreatedAt)));
        TaskObject.AddPair('ExecutedAt', TJSONString.Create(FormatDateTime('yyyy-mm-dd hh:mm:ss', Task.FExecutedAt)));
        TaskObject.AddPair('IsRunning', TJSONBool.Create(Task.FIsRunning));

        TasksArray.AddElement(TaskObject);
      end;

      { Write to file }
      StringList := TStringList.Create;
      try
        StringList.Text := JsonObject.ToJSON;
        StringList.SaveToFile(AFilePath);
      finally
        StringList.Free;
      end;

    finally
      JsonObject.Free;
    end;

  except
    on E: Exception do
    begin
      raise Exception.Create('Error saving device to file: ' + E.Message);
    end;
  end;
end;

procedure TDeviceManager.AddTask(Task: THardwareTask; const AName: string; ATaskType: TNodeType);

begin
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
 { DeviceManager := TDeviceManager.Create;}

finalization
{  DeviceManager.Free; }

end.
