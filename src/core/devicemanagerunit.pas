unit DeviceManagerUnit;


interface

uses
  Classes, SysUtils, Contnrs, DateUtils, AnnealTypes, System.JSON;

type

  { TDeviceInfo - Holds device metadata }
  TJunctionEntry = Record
    Name: String;
    Index: Integer;
    NodeType: TNodeType;
  end;

  TJunctionListing = Array of TJunctionEntry;

  TJunctionNodeData = class
    FEntry : TJunctionEntry;
  public
    constructor Create(const Entry: TJunctionEntry);
  end;


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
    function ToJSON: TJSONValue; virtual; abstract;
    procedure SetResult(const AResult: THardwareResult); virtual; abstract;
    function GetJunctionListing : TJunctionListing; virtual; abstract;
    procedure GetChartPoints(var XValues,YValues: TDoubleArray;
                AJunctionIndex: Integer); virtual; abstract;
    procedure SetConfig(const AResult: THardwareResult); virtual; abstract;
    property Name: string read FName write FName;
    property TaskType: TNodeType read FTaskType;
    property CreatedAt: TDateTime read FCreatedAt;
    property ExecutedAt: TDateTime read FExecutedAt write FExecutedAt;
    property IsRunning: Boolean read FIsRunning write FIsRunning;

  end;
    TTypedHardwareTask<TConfig, TData> = class(THardwareTask)
  private
    FConfig: TConfig;
    FData: TData;
  public
    property Config: TConfig read FConfig write FConfig;
    property Result: TData read FData write FData;
    {procedure SetResult(const AResult: THardwareResult); override;}
    procedure SetConfig(const AResult: THardwareResult); virtual; abstract;
  end;

  TAnnealTask = class(TTypedHardwareTask<TAnnealConfig,TAnnealResult>)
   public
   constructor Create(const AName: string; ATaskType: TNodeType);
    function ToJSON: TJSONValue; override;
    procedure SetResult(const AResult: THardwareResult); override;
    procedure GetChartPoints(var XValues,YValues: TDoubleArray;
                AJunctionIndex: Integer); override;
    function GetJunctionListing : TJunctionListing; override;
  end;

  TProbeTask = class(TTypedHardwareTask<TProbingParameters,TProbingResult>)
   public
   constructor Create(const AName: string; ATaskType: TNodeType);
    function ToJSON: TJSONValue; override;
    procedure SetResult(const AResult: THardwareResult); override;
    procedure GetChartPoints(var XValues,YValues: TDoubleArray;
                AJunctionIndex: Integer); override;
    function GetJunctionListing : TJunctionListing; override;
  end;

  TBatchAnnealTask = class(TTypedHardwareTask<TAnnealParameterArray,TAnnealResultArray>)
   public
   constructor Create(const AName: string; ATaskType: TNodeType);
    function ToJSON: TJSONValue; override;
    procedure SetResult(const AResult: THardwareResult); override;
    procedure GetChartPoints(var XValues,YValues: TDoubleArray;
                AJunctionIndex: Integer); override;
    function GetJunctionListing : TJunctionListing; override;
  end;

    TBatchProbeTask = class(TTypedHardwareTask<TProbingParameters,TProbingResultArray>)
   public
    constructor Create(const AName: string; ATaskType: TNodeType);
    function ToJSON: TJSONValue; override;
    procedure SetResult(const AResult: THardwareResult); override;
    procedure GetChartPoints(var XValues,YValues: TDoubleArray;
                AJunctionIndex: Integer); override;
    function GetJunctionListing : TJunctionListing; override;
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

constructor TJunctionNodeData.Create(const Entry: TJunctionEntry);
begin
  FEntry := Entry;
end;

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
  with FConfig do
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
  SetLength(FConfig,1);
  {Parameters := AnnealParameters;}
  with FConfig[0] do
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
  with FConfig do
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
  with FConfig do
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
  if AResult.CommandType = hcAnnealBatchCycle then
  begin
    setlength(FData,Length(FData)+1);
    FData[High(FData)]:=AResult.AnnealedJunctionResult;
  end;
end;

procedure TBatchProbeTask.SetResult(const AResult: THardwareResult);
begin
  if AResult.CommandType = hcProbeBatchCycle then
  begin
    setlength(FData,Length(FData)+1);
    FData[High(FData)]:=AResult.ProbedJunctionResult;
  end;
end;

procedure TAnnealTask.GetChartPoints(var XValues,YValues: TDoubleArray;
                AJunctionIndex: Integer);

var
I : Integer;
begin
SetLength(XValues,Length(Self.Result.ResistanceSamples));
SetLength(YValues,Length(XValues));
for I := Low(XValues) to High(XValues) do
  begin
      XValues[I]:= Self.Result.ResistanceSamples[I].Time/SecsPerDay;
      YValues[I]:= Self.Result.ResistanceSamples[I].Value;
  end;

end;

procedure TProbeTask.GetChartPoints(var XValues,YValues: TDoubleArray;
                AJunctionIndex: Integer);
var
I : Integer;
begin
SetLength(XValues,Length(Self.Result.Readings));
SetLength(YValues,Length(XValues));
for I := Low(XValues) to High(XValues) do
  begin
      XValues[I]:= Self.FConfig.VoltageList[I];
      YValues[I]:= Self.Result.Readings[I];
  end;

end;

procedure TBatchAnnealTask.GetChartPoints(var XValues,YValues: TDoubleArray;
                AJunctionIndex: Integer);
var
I : Integer;
begin
SetLength(XValues,Length(Self.Result[AJunctionIndex].AnnealResult.ResistanceSamples));
SetLength(YValues,Length(XValues));
for I := Low(XValues) to High(XValues) do
  begin
      XValues[I]:= Self.Result[AJunctionIndex].AnnealResult.
                                ResistanceSamples[I].Time/SecsPerDay;
      YValues[I]:= Self.Result[AJunctionIndex].AnnealResult.
                                ResistanceSamples[I].Value;
  end;

end;

procedure TBatchProbeTask.GetChartPoints(var XValues,YValues: TDoubleArray;
                AJunctionIndex: Integer);
var
I : Integer;
begin
SetLength(XValues,Length(Self.Result[AJunctionIndex].ProbingResult.Readings));
SetLength(YValues,Length(XValues));
for I := Low(XValues) to High(XValues) do
  begin
      XValues[I]:= Self.FConfig.VoltageList[I];
      YValues[I]:= Self.Result[AJunctionIndex].ProbingResult.Readings[I];
  end;

end;

function TAnnealTask.GetJunctionListing : TJunctionListing;
begin
     SetLength(Result,1);
     Result[High(Result)].Name := 'Junction';
     Result[High(Result)].Index := 1;
     Result[High(Result)].NodeType := TNodeType.ntAnneal;

end;

function TProbeTask.GetJunctionListing : TJunctionListing;
begin
     SetLength(Result,1);
     Result[High(Result)].Name := 'Junction';
     Result[High(Result)].Index := 1;
     Result[High(Result)].NodeType := TNodeType.ntProbe;

end;

function TBatchAnnealTask.GetJunctionListing : TJunctionListing;
var I:Integer;
begin
   for I := 0 to Length(Self.Result)-1 do
   begin
     SetLength(Result,I+1);
     Result[High(Result)].Name := Self.Result[I].Coord.Subsite;
     Result[High(Result)].Index := I;
     Result[High(Result)].NodeType := TNodeType.ntAnnealedJunction;

   end;

end;

function TBatchProbeTask.GetJunctionListing : TJunctionListing;
var I:Integer;
begin
   for I := 0 to Length(Self.Result)-1 do
   begin
     SetLength(Result,I+1);
     Result[High(Result)].Name := Self.Result[I].Coord.Subsite;
     Result[High(Result)].Index := I;
     Result[High(Result)].NodeType := TNodeType.ntProbedJunction;

   end;

end;

{ TDeviceManager }
function TAnnealTask.ToJSON: TJSONValue;
var
  Parameters: TJSONObject;
begin
    Parameters := TJSONObject.Create;
  try
    Parameters.AddPair('TaskName', TJSONString.Create(Name));
    Parameters.AddPair('TaskType', TJSONNumber.Create(Integer(TaskType)));
    Parameters.AddPair('DisplayName', TJSONString.Create(FDisplayName));
    Parameters.AddPair(
      'CreatedAt',
      TJSONString.Create(
        FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', CreatedAt)
      )
    );
    Parameters.AddPair(
      'ExecutedAt',
      TJSONString.Create(
        FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', ExecutedAt)
      )
    );
    Parameters.AddPair('IsRunning', TJSONBool.Create(IsRunning));


    Parameters.AddPair('Parameters', Self.Config.ToJSON);

  finally
    Result := Parameters;
  end;
end;

 function TBatchAnnealTask.ToJSON: TJSONValue;
 var
 ParameterArray: TJSONArray;
 i: Integer;
 begin
  ParameterArray := TJSONArray.Create;
  for i := 0 to length(Config) - 1 do
      begin
        ParameterArray.AddElement(Config[i].ToJSON);
      end;
  Result := ParameterArray;
 end;

 function TProbeTask.ToJSON: TJSONValue;
 begin

 end;

 function TBatchProbeTask.ToJSON: TJSONValue;
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
  DeviceJSON: TJSONObject;
  TasksArray: TJSONArray;
  i: Integer;
  TaskObject: TJSONValue;
  Task: THardwareTask;
  StringList: TStringList;
begin
  try
    if not Assigned(FCurrentDevice) then
    begin
      raise Exception.Create('No device loaded. Cannot save.');
    end;

    { Create root JSON object }
    DeviceJSON := TJSONObject.Create;
    try
      { Save device metadata }
      DeviceJSON.AddPair('DeviceName', TJSONString.Create(FCurrentDevice.FName));
      DeviceJSON.AddPair('CreatedAt', TJSONString.Create(FormatDateTime('yyyy-mm-dd hh:mm:ss', FCurrentDevice.FCreatedAt)));
      DeviceJSON.AddPair('ModifiedAt', TJSONString.Create(FormatDateTime('yyyy-mm-dd hh:mm:ss', FCurrentDevice.FModifiedAt)));

      { Create tasks array }
      TasksArray := TJSONArray.Create;
      DeviceJSON.AddPair('Tasks', TasksArray);

      { Save each task }
      for i := 0 to FTasks.Count - 1 do
      begin
        Task := THardwareTask(FTasks[i]);
        TaskObject := TJSONObject.Create;

        {TaskObject.AddPair('TaskName', TJSONString.Create(Task.FName));
        TaskObject.AddPair('TaskType', TJSONNumber.Create(Integer(Task.FTaskType)));
        TaskObject.AddPair('DisplayName', TJSONString.Create(Task.FDisplayName));
        TaskObject.AddPair('CreatedAt', TJSONString.Create(FormatDateTime('yyyy-mm-dd hh:mm:ss', Task.FCreatedAt)));
        TaskObject.AddPair('ExecutedAt', TJSONString.Create(FormatDateTime('yyyy-mm-dd hh:mm:ss', Task.FExecutedAt)));
        TaskObject.AddPair('IsRunning', TJSONBool.Create(Task.FIsRunning));}
        TaskObject := Task.ToJSON;
        TasksArray.AddElement(TaskObject);
      end;

      { Write to file }
      StringList := TStringList.Create;
      try
        StringList.Text := DeviceJSON.ToJSON;
        StringList.SaveToFile(AFilePath);
      finally
        StringList.Free;
      end;

    finally
      DeviceJSON.Free;
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
