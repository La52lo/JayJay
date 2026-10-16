unit DeviceManagerUnit;


interface

uses
  Classes, SysUtils, Contnrs, DateUtils, AnnealTypes, System.Rtti,
  System.JSON,System.TypInfo,
  Neon.Core.Types,Neon.Core.Persistence,
  Neon.Core.Persistence.JSON,Neon.Core.Persistence.JSON.Schema,
  Neon.Core.Attributes,        // needs Data.DB
  Neon.Core.Serializers.Nullables,
  System.Generics.Collections;

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
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property ModifiedAt: TDateTime read FModifiedAt write FModifiedAt;
  end;

  { TTaskInfo - Holds task metadata }
  {TTaskType = (ttSingleAnneal, ttBatchAnneal, ttSingleResistance, ttBatchResistance);}

  THardwareTask = class
  private
    FName: string;
    FDisplayName: string;
    FTaskType: TNodeType;
    FCreatedAt: TDateTime;
    FExecutedAt: TDateTime;
    FIsRunning: Boolean;
  public
    constructor Create(const AName: string; ATaskType: TNodeType);
    procedure SetResult(const AResult: THardwareResult); virtual; abstract;
    function GetJunctionListing : TJunctionListing; virtual; abstract;
    procedure GetChartPoints(var XValues,YValues: TArray<Double>;
                AJunctionIndex: Integer); virtual; abstract;
    {procedure SetConfig(const AResult: THardwareResult); virtual; abstract;}
    property Name: string read FName write FName;
    property TaskType: TNodeType read FTaskType write FTaskType;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property ExecutedAt: TDateTime read FExecutedAt write FExecutedAt;
    property IsRunning: Boolean read FIsRunning write FIsRunning;
    property DisplayName: string read FDisplayName write FDisplayName;

  end;


  TTypedHardwareTask<TConfig, TData> = class(THardwareTask)
  private
    FConfig: TConfig;
    FData: TData;
  public
    property Config: TConfig read FConfig write FConfig;
    property Result: TData read FData write FData;
  end;

  TAnnealTask = class(TTypedHardwareTask<TAnnealConfig,TAnnealResult>)
   public
   constructor Create(const AName: string; ATaskType: TNodeType);
    procedure SetResult(const AResult: THardwareResult); override;
    procedure GetChartPoints(var XValues,YValues: TArray<Double>;
                AJunctionIndex: Integer); override;
    function GetJunctionListing : TJunctionListing; override;
  end;

  TProbeTask = class(TTypedHardwareTask<TProbingParameters,TProbingResult>)
   public
   constructor Create(const AName: string; ATaskType: TNodeType);
    procedure SetResult(const AResult: THardwareResult); override;
    procedure GetChartPoints(var XValues,YValues: TArray<Double>;
                AJunctionIndex: Integer); override;
    function GetJunctionListing : TJunctionListing; override;
  end;

  TBatchAnnealTask = class(TTypedHardwareTask<TAnnealConfigArray,TAnnealResultArray>)
   public
   constructor Create(const AName: string; ATaskType: TNodeType);
    procedure SetResult(const AResult: THardwareResult); override;
    procedure GetChartPoints(var XValues,YValues: TArray<Double>;
                AJunctionIndex: Integer); override;
    function GetJunctionListing : TJunctionListing; override;
  end;

    TBatchProbeTask = class(TTypedHardwareTask<TProbingParameters,TProbingResultArray>)
   public
    constructor Create(const AName: string; ATaskType: TNodeType);
    procedure SetResult(const AResult: THardwareResult); override;
    procedure GetChartPoints(var XValues,YValues: TArray<Double>;
                AJunctionIndex: Integer); override;
    function GetJunctionListing : TJunctionListing; override;
  end;

  { TDeviceManager - Manages device, task, and junction information }
  TDeviceManager = class
  private
    FDeviceInfo: TDeviceInfo;
    FTasks: TObjectList<THardwareTask>;
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

    property DeviceInfo: TDeviceInfo read FDeviceInfo write FDeviceInfo;

    property IsOperationRunning: Boolean read FIsOperationRunning write FIsOperationRunning;
    property Tasks:  TObjectList<THardwareTask> read FTasks write FTasks;
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
  FExecutedAt := now;
end;

procedure TProbeTask.SetResult(const AResult: THardwareResult);
begin
  Result := AResult.ProbingResult;
  FExecutedAt := now;
end;

procedure TBatchAnnealTask.SetResult(const AResult: THardwareResult);
begin
  if AResult.CommandType = hcAnnealBatchCycle then
  begin
    setlength(FData,Length(FData)+1);
    FData[High(FData)]:=AResult.AnnealedJunctionResult;
    FExecutedAt := now;
  end;
end;

procedure TBatchProbeTask.SetResult(const AResult: THardwareResult);
begin
  if AResult.CommandType = hcProbeBatchCycle then
  begin
    setlength(FData,Length(FData)+1);
    FData[High(FData)]:=AResult.ProbedJunctionResult;
    FExecutedAt := now;
  end;
end;

procedure TAnnealTask.GetChartPoints(var XValues,YValues: TArray<Double>;
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

procedure TProbeTask.GetChartPoints(var XValues,YValues: TArray<Double>;
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

procedure TBatchAnnealTask.GetChartPoints(var XValues,YValues: TArray<Double>;
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

procedure TBatchProbeTask.GetChartPoints(var XValues,YValues: TArray<Double>;
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

    if FExecutedAt<>0 then
    begin
     SetLength(Result,1);
     Result[High(Result)].Name := 'Junction';
     Result[High(Result)].Index := 1;
     Result[High(Result)].NodeType := TNodeType.ntAnneal;
    end else
      SetLength(Result,0);

end;

function TProbeTask.GetJunctionListing : TJunctionListing;
begin
 if FExecutedAt<>0 then
    begin
     SetLength(Result,1);
     Result[High(Result)].Name := 'Junction';
     Result[High(Result)].Index := 1;
     Result[High(Result)].NodeType := TNodeType.ntProbe;
   end else
      SetLength(Result,0);
end;

function TBatchAnnealTask.GetJunctionListing : TJunctionListing;
var I:Integer;
begin
  SetLength(Result,Length(Self.Result));
   for I := 0 to High(Self.Result) do
   begin

     Result[High(Result)].Name := Self.Result[I].Coord.Subsite;
     Result[High(Result)].Index := I;
     Result[High(Result)].NodeType := TNodeType.ntAnnealedJunction;

   end;

end;

function TBatchProbeTask.GetJunctionListing : TJunctionListing;
var I:Integer;
begin
  SetLength(Result,Length(Self.Result));
   for I := 0 to High(Self.Result) do
   begin
     Result[High(Result)].Name := Self.Result[I].Coord.Subsite;
     Result[High(Result)].Index := I;
     Result[High(Result)].NodeType := TNodeType.ntProbedJunction;

   end;

end;

{ TDeviceManager }


constructor TDeviceManager.Create;
begin
  inherited Create;
  FDeviceInfo := nil;
  FTasks := TObjectList<THardwareTask>.Create(True);
  FIsOperationRunning := False;
end;

destructor TDeviceManager.Destroy;
begin
  if Assigned(FDeviceInfo) then
    FDeviceInfo.Free;
  FTasks.Free;
  inherited;
end;

procedure TDeviceManager.CreateNewDevice(const AName: string);
begin
  if Assigned(FDeviceInfo) then
    FDeviceInfo.Free;
  FDeviceInfo := TDeviceInfo.Create(AName);
  FTasks.Clear;
  FIsOperationRunning := False;
end;

procedure TDeviceManager.LoadDevice(const AFilePath: string);
var
  JsonText: string;
  StringList: TStringList;
  TempDevice: TDeviceManager;
  Config: INeonConfiguration;
  z: integer;
  LJSON: TJSONObject;
  LTasksJSON: TJSONArray;
  LTaskJSON: TJSONValue;
  LTaskTypeJSON: TJSONValue;
  LTaskType: TNodeType;
  LTask: THardwareTask;

begin
  Config := TNeonConfiguration.Default
    .SetMembers([TNeonMembers.Properties])
    .SetVisibility([TMemberVisibility.mvPrivate])
    .SetIgnoreMembers(['Tasks']);
  TempDevice := TDeviceManager.Create();
  Tasks := TObjectList<THardwareTask>.Create(True);
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
    z := GetEnumValue(TypeInfo(TNodeType), 'ntAnneal');
    TempDevice.CreateNewDevice('placeholdere');
    TNeon.JSONToObject(TempDevice,JsonText,Config);

    TNeon.JSONToObject(Self,JsonText);

        // Deserialize the non-polymorphic properties.
        // Exclude Tasks from this pass, or deserialize them separately.
        // See the note below about Neon member configuration.
        LJSON := TJSONObject.ParseJSONValue(JsonText) as TJSONObject;
        LTasksJSON := LJSON.GetValue<TJSONArray>('Tasks');
        if LTasksJSON = nil then
          Exit;

        FTasks.Clear;

        for LTaskJSON in LTasksJSON do
        begin
          if not (LTaskJSON is TJSONObject) then
            Continue;

          LTaskTypeJSON := TJSONObject(LTaskJSON).GetValue('TaskType');
          if LTaskTypeJSON = nil then
            raise Exception.Create('TaskType is missing');

          LTaskType := TNodeType(GetEnumValue(
            TypeInfo(TNodeType), LTaskTypeJSON.Value));

          case LTaskType of
                 TNodeType.ntAnneal:
                    begin
                      //LTask := TAnnealTask.Create('',LTaskType)
                      LTask := TNeon.JSONToObject<TAnnealTask>(LTaskJSON);
                    end;
                   TNodeType.ntBatchAnneal:
                    begin
                      //LTask := TBatchAnnealTask.Create('',LTaskType)
                      LTask := TNeon.JSONToObject<TBatchAnnealTask>(LTaskJSON);
                    end;
                    TNodeType.ntProbe:
                    begin
                      //LTask := TProbeTask.Create('',LTaskType)
                      LTask := TNeon.JSONToObject<TProbeTask>(LTaskJSON);
                    end;
                    TNodeType.ntBatchProbe:
                    begin
                      //LTask := TBatchProbeTask.Create('',LTaskType)
                      LTask := TNeon.JSONToObject<TBatchProbeTask>(LTaskJSON);
                    end
          else
            raise Exception.CreateFmt(
              'Unsupported task type: %s',
              [LTaskTypeJSON.Value]);
      end;
        try
          //TNeon.JSONToObject(LTask, LTaskJSON.Value);
          FTasks.Add(LTask);
        except
          LTask.Free;
        raise;
      end;
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
  DeviceJSON: TJSONValue;
  StringList: TStringList;
  Config: INeonConfiguration;

begin
  Config := TNeonConfiguration.Default
    .SetMembers([TNeonMembers.Properties])
    .SetVisibility([TMemberVisibility.mvPrivate]);
  try
    if not Assigned(FDeviceInfo) then
    begin
      raise Exception.Create('No device loaded. Cannot save.');
    end;

    { Create root JSON object }
    DeviceJSON := TNeon.ValueToJSON(TValue.From<TDeviceManager>(Self));
    try
      { Save device metadata }

      { Write to file }
      StringList := TStringList.Create;
      try
        StringList.Text := TNeon.Print(DeviceJSON, True);
        StringList.SaveToFile(AFilePath);
      finally
        StringList.Free;
      end

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
