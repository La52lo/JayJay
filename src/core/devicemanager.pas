unit DeviceManager;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, DateUtils;

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
  TTaskType = (ttSingleAnneal, ttBatchAnneal, ttSingleResistance, ttBatchResistance);
  
  TTaskInfo = class
  private
    FName: string;
    FTaskType: TTaskType;
    FCreatedAt: TDateTime;
    FExecutedAt: TDateTime;
    FIsRunning: Boolean;
    FJunctionCount: Integer;
  public
    constructor Create(const AName: string; ATaskType: TTaskType);
    property Name: string read FName;
    property TaskType: TTaskType read FTaskType;
    property CreatedAt: TDateTime read FCreatedAt;
    property ExecutedAt: TDateTime read FExecutedAt write FExecutedAt;
    property IsRunning: Boolean read FIsRunning write FIsRunning;
    property JunctionCount: Integer read FJunctionCount write FJunctionCount;
  end;

  { TJunctionInfo - Holds junction metadata }
  TJunctionInfo = class
  private
    FLabel: string;
    FProbeCoord: string;
    FLastResultTime: TDateTime;
    FHasResult: Boolean;
  public
    constructor Create(const ALabel: string; const ACoord: string = '');
    property Label_: string read FLabel;
    property ProbeCoord: string read FProbeCoord;
    property LastResultTime: TDateTime read FLastResultTime write FLastResultTime;
    property HasResult: Boolean read FHasResult write FHasResult;
  end;

  { TDeviceManager - Manages device, task, and junction information }
  TDeviceManager = class
  private
    FCurrentDevice: TDeviceInfo;
    FTasks: TObjectList;
    FJunctions: TObjectList;
    FIsOperationRunning: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure CreateNewDevice(const AName: string);
    procedure LoadDevice(const AFilePath: string);
    procedure SaveDevice(const AFilePath: string);
    
    procedure AddTask(const AName: string; ATaskType: TTaskType);
    procedure RemoveTask(ATaskIndex: Integer);
    function GetTaskCount: Integer;
    function GetTask(AIndex: Integer): TTaskInfo;
    
    procedure AddJunction(const ALabel: string; const ACoord: string = '');
    procedure RemoveJunction(AJunctionIndex: Integer);
    function GetJunctionCount: Integer;
    function GetJunction(AIndex: Integer): TJunctionInfo;
    
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

constructor TTaskInfo.Create(const AName: string; ATaskType: TTaskType);
begin
  inherited Create;
  FName := AName;
  FTaskType := ATaskType;
  FCreatedAt := Now;
  FExecutedAt := 0;
  FIsRunning := False;
  FJunctionCount := 0;
end;

{ TJunctionInfo }

constructor TJunctionInfo.Create(const ALabel: string; const ACoord: string);
begin
  inherited Create;
  FLabel := ALabel;
  FProbeCoord := ACoord;
  FLastResultTime := 0;
  FHasResult := False;
end;

{ TDeviceManager }

constructor TDeviceManager.Create;
begin
  inherited Create;
  FCurrentDevice := nil;
  FTasks := TObjectList.Create(True);
  FJunctions := TObjectList.Create(True);
  FIsOperationRunning := False;
end;

destructor TDeviceManager.Destroy;
begin
  if Assigned(FCurrentDevice) then
    FCurrentDevice.Free;
  FTasks.Free;
  FJunctions.Free;
  inherited;
end;

procedure TDeviceManager.CreateNewDevice(const AName: string);
begin
  if Assigned(FCurrentDevice) then
    FCurrentDevice.Free;
  FCurrentDevice := TDeviceInfo.Create(AName);
  FTasks.Clear;
  FJunctions.Clear;
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

procedure TDeviceManager.AddTask(const AName: string; ATaskType: TTaskType);
var
  Task: TTaskInfo;
begin
  Task := TTaskInfo.Create(AName, ATaskType);
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

function TDeviceManager.GetTask(AIndex: Integer): TTaskInfo;
begin
  if (AIndex >= 0) and (AIndex < FTasks.Count) then
    Result := TTaskInfo(FTasks[AIndex])
  else
    Result := nil;
end;

procedure TDeviceManager.AddJunction(const ALabel: string; const ACoord: string);
var
  Junction: TJunctionInfo;
begin
  Junction := TJunctionInfo.Create(ALabel, ACoord);
  FJunctions.Add(Junction);
end;

procedure TDeviceManager.RemoveJunction(AJunctionIndex: Integer);
begin
  if (AJunctionIndex >= 0) and (AJunctionIndex < FJunctions.Count) then
    FJunctions.Delete(AJunctionIndex);
end;

function TDeviceManager.GetJunctionCount: Integer;
begin
  Result := FJunctions.Count;
end;

function TDeviceManager.GetJunction(AIndex: Integer): TJunctionInfo;
begin
  if (AIndex >= 0) and (AIndex < FJunctions.Count) then
    Result := TJunctionInfo(FJunctions[AIndex])
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
