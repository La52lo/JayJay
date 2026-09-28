unit MainWindowUnit;

{$mode ObjFPC}{$H+}
{$modeswitch ADVANCEDRECORDS}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus, ComCtrls,
  ExtCtrls, TAGraph, GraphType, ProbeConfig, DeviceDialogUnit,
  TaskSelectDialogUnit, AnnealConfig, ResultViewer, ThreadingHelper,
  DeviceManagerUnit,MeasurementObserver,AnnealManager;

type

  { TMainWindowForm }
  TNodeType = (ntDevice, ntAddTask, ntAnneal, ntResistance, ntAnnealConfig,
               ntAnnealResult, ntResistanceConfig, ntResistanceResult);

  TMainWindowForm = class(TForm,IMeasurementObserver)
    Chart1: TChart;
    IconList: TImageList;
    MainMenu: TMainMenu;
    FileMenuItem: TMenuItem;
    EditMenuItem: TMenuItem;
    AnnealMenuItem: TMenuItem;
    OpenDeviceMenuItem: TMenuItem;
    AddTaskButton: TToolButton;
    RunBatchButton: TToolButton;
    SaveDeviceMenuItem: TMenuItem;
    SaveAsDeviceMenuItem: TMenuItem;
    ResistanceMenuItem: TMenuItem;
    NewDeviceMenuItem: TMenuItem;
    EquipmentStatusBar: TStatusBar;
    TaskSelectionPopup: TPopupMenu;
    DeviceTreeView: TTreeView;
    TaskToolBar: TToolBar;
    RunSingleButton: TToolButton;
    ConnectButton: TToolButton;
    procedure AnnealMenuItemClick(Sender: TObject);
    procedure ConnectButtonClick(Sender: TObject);
    procedure DeviceTreeViewDblClick(Sender: TObject);
    procedure DeviceTreeViewDeletion(Sender: TObject; Node: TTreeNode);
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FileMenuItemClick(Sender: TObject);
    procedure SaveAsDeviceMenuItemClick(Sender: TObject);
    procedure OpenDeviceMenuItemClick(Sender: TObject);
    procedure NewDeviceMenuItemClick(Sender: TObject);
    procedure ResistanceMenuItemClick(Sender: TObject);
    procedure EquipmentStatusBarDrawPanel(AEquipmentStatusBar: TStatusBar;
      Panel: TStatusPanel; const Rect: TRect);
    procedure TaskToolBarClick(Sender: TObject);
    procedure DeviceTreeViewClick(Sender: TObject);
    procedure AddTaskButtonClick(Sender: TObject);
    procedure RunSingleButtonClick(Sender: TObject);
    procedure RunBatchButtonClick(Sender: TObject);
  private
    FAddTask: TTreeNode;
    FDeviceNode: TTreeNode;
    FAnnealManager: TAnnealManager;
    FSetupStatus: TSetupStatus;
    FCurrentThread: TOperationThread;
    FCurrentTaskType: TTaskType;
    FSelectedTaskNode: TTreeNode;
    
    function GetImageIndexForNodeType(ANodeType: TNodeType): Integer;
    function GetDisplayNameForNodeType(ANodeType: TNodeType): string;
    function AddNode(AParent: TTreeNode; const ANodeType: TNodeType;
                     const AText: string): TTreeNode;
    procedure OnThreadTerminate(Sender: TObject);
    procedure UpdateEquipmentStatus;
    procedure PopulateDeviceInfo;
    procedure CreateDefaultDevice;
  public
    procedure RefreshTreeView;
    { :::::::::: Interface procedures :::::::::: }
    procedure Log(const Msg : string);
    procedure Progress(
        Percent : Double;
        const Msg : string);
    procedure MeasurementPoint(
        Time : Double;
        Value : Double);
    procedure BatchStarted(
        Count : Integer);
    procedure BatchFinished;
    procedure JunctionStarted(
        const Name : string);
    procedure JunctionFinished(
        const Name : string;
        Result : TAnnealResult);
    procedure Error(
        E : Exception);
      end;

  TNodeTypeDefinition = record
    NodeType: TNodeType;
    ImageIndex: Integer;
    DisplayName: string;
  end;

  PNodeData = ^TNodeData;
  TNodeData = record
    NodeType: TNodeType;
    TaskType: TTaskType;
    Data: Pointer;
  end;

const
  AddTaskUniqueID: Integer = 42;
  NODETYPE_MAP: array[TNodeType] of TNodeTypeDefinition = (
    (NodeType: ntDevice; ImageIndex: 9; DisplayName: 'Device'),
    (NodeType: ntAddTask; ImageIndex: 0; DisplayName: 'Add Task...'),
    (NodeType: ntAnneal; ImageIndex: 1; DisplayName: 'Anneal'),
    (NodeType: ntResistance; ImageIndex: 4; DisplayName: 'Resistance'),
    (NodeType: ntAnnealConfig; ImageIndex: 8; DisplayName: 'Config'),
    (NodeType: ntAnnealResult; ImageIndex: 3; DisplayName: 'Result'),
    (NodeType: ntResistanceConfig; ImageIndex: 8; DisplayName: 'Config'),
    (NodeType: ntResistanceResult; ImageIndex: 3; DisplayName: 'Result')
  );

var
  MainWindowForm: TMainWindowForm;
  AnnealSetup: TAnnealSetup;

implementation

{$R *.lfm}

{ TMainWindowForm }

procedure TMainWindowForm.FormCreate(Sender: TObject);
begin
  DeviceTreeView.Items.Clear;
  FAnnealManager := nil;
  FCurrentThread := nil;
  FSelectedTaskNode := nil;

  { Create default device }
  CreateDefaultDevice;
end;

procedure TMainWindowForm.CreateDefaultDevice;
var
  ConfigNode, ResultNode: TTreeNode;
begin
  DeviceManager.CreateNewDevice('Default Device');
  FDeviceNode := DeviceTreeView.Items.Add(nil, 'Default Device');
  FDeviceNode.ImageIndex := GetImageIndexForNodeType(ntDevice);
  FDeviceNode.SelectedIndex := FDeviceNode.ImageIndex;

  { Add "Add Task" node }
  FAddTask := DeviceTreeView.Items.AddChild(FDeviceNode, 'Add Task...');
  FAddTask.ImageIndex := GetImageIndexForNodeType(ntAddTask);
  FAddTask.Data := Pointer(PtrInt(AddTaskUniqueID));

  FDeviceNode.Expanded := True;
  PopulateDeviceInfo;
end;

procedure TMainWindowForm.PopulateDeviceInfo;
var
  InfoText: string;
begin
  if DeviceManager.CurrentDevice <> nil then
  begin
    InfoText := Format('Device: %s | Created: %s',
      [DeviceManager.CurrentDevice.Name,
       FormatDateTime('yyyy-mm-dd hh:nn:ss', DeviceManager.CurrentDevice.CreatedAt)]);
    EquipmentStatusBar.Panels[0].Text := InfoText;
  end;
end;

function TMainWindowForm.GetImageIndexForNodeType(ANodeType: TNodeType): Integer;
begin
  Result := NODETYPE_MAP[ANodeType].ImageIndex;
end;

function TMainWindowForm.GetDisplayNameForNodeType(ANodeType: TNodeType): string;
begin
  Result := NODETYPE_MAP[ANodeType].DisplayName;
end;

function TMainWindowForm.AddNode(AParent: TTreeNode; const ANodeType: TNodeType;
  const AText: string): TTreeNode;
var
  ConfigNode, ResultNode: TTreeNode;
begin
  Result := DeviceTreeView.Items.AddChild(AParent, AText);
  Result.ImageIndex := GetImageIndexForNodeType(ANodeType);
  Result.SelectedIndex := Result.ImageIndex;

  { For task nodes, add Config and Result subnodes }
  if ANodeType in [ntAnneal, ntResistance] then
  begin
    ConfigNode := DeviceTreeView.Items.AddChild(Result, 'Config');
    ConfigNode.ImageIndex := GetImageIndexForNodeType(ntAnnealConfig);
    ConfigNode.SelectedIndex := ConfigNode.ImageIndex;
    ConfigNode.Data := TStringList.Create;

    ResultNode := DeviceTreeView.Items.AddChild(Result, 'Result');
    ResultNode.ImageIndex := GetImageIndexForNodeType(ntAnnealResult);
    ResultNode.SelectedIndex := ResultNode.ImageIndex;
  end;
end;

procedure TMainWindowForm.NewDeviceMenuItemClick(Sender: TObject);
var
  DeviceName: string;
begin
  if DeviceManager.IsOperationRunning then
  begin
    ShowMessage('Cannot create device while operation is running.');
    Exit;
  end;

  if DeviceDialog.ShowDeviceDialog(DeviceName) then
  begin
    DeviceTreeView.Items.Clear;
    DeviceManager.CreateNewDevice(DeviceName);
    FDeviceNode := DeviceTreeView.Items.Add(nil, DeviceName);
    FDeviceNode.ImageIndex := GetImageIndexForNodeType(ntDevice);
    FDeviceNode.SelectedIndex := FDeviceNode.ImageIndex;

    FAddTask := DeviceTreeView.Items.AddChild(FDeviceNode, 'Add Task...');
    FAddTask.ImageIndex := GetImageIndexForNodeType(ntAddTask);
    FAddTask.Data := Pointer(PtrInt(AddTaskUniqueID));

    FDeviceNode.Expanded := True;
    PopulateDeviceInfo;
  end;
end;

procedure TMainWindowForm.OpenDeviceMenuItemClick(Sender: TObject);
var
  OpenDialog: TOpenDialog;
begin
  if DeviceManager.IsOperationRunning then
  begin
    ShowMessage('Cannot open device while operation is running.');
    Exit;
  end;

  OpenDialog := TOpenDialog.Create(nil);
  try
    OpenDialog.Filter := 'Device files (*.dvc)|*.dvc';
    if OpenDialog.Execute then
    begin
      DeviceManager.LoadDevice(OpenDialog.FileName);
      RefreshTreeView;
    end;
  finally
    OpenDialog.Free;
  end;
end;

procedure TMainWindowForm.SaveAsDeviceMenuItemClick(Sender: TObject);
var
  SaveDialog: TSaveDialog;
begin
  SaveDialog := TSaveDialog.Create(nil);
  try
    SaveDialog.Filter := 'Device files (*.dvc)|*.dvc';
    if SaveDialog.Execute then
      DeviceManager.SaveDevice(SaveDialog.FileName);
  finally
    SaveDialog.Free;
  end;
end;

procedure TMainWindowForm.AddTaskButtonClick(Sender: TObject);
var
  TaskType: TTaskType;
  TaskName: string;
  NewTaskNode: TTreeNode;
begin
  if TaskSelectDialog.ShowTaskSelectDialog(TaskType) then
  begin
    case TaskType of
      ttSingleAnneal:
        TaskName := 'Single Anneal';
      ttBatchAnneal:
        TaskName := 'Batch Anneal';
      ttSingleResistance:
        TaskName := 'Single Resistance';
      ttBatchResistance:
        TaskName := 'Batch Resistance';
    end;

    NewTaskNode := AddNode(FDeviceNode, ntAnneal, TaskName);
    DeviceManager.AddTask(TaskName, TaskType);
    FSelectedTaskNode := NewTaskNode;
  end;
end;

procedure TMainWindowForm.RunSingleButtonClick(Sender: TObject);
var
  SelectedNode: TTreeNode;
  TaskType: TTaskType;
begin
  SelectedNode := DeviceTreeView.Selected;
  if SelectedNode = nil then
  begin
    ShowMessage('Please select a task.');
    Exit;
  end;

  if DeviceManager.IsOperationRunning then
  begin
    ShowMessage('An operation is already running.');
    Exit;
  end;

  { Determine task type and execute }
  if (SelectedNode.Parent <> nil) and (SelectedNode.Parent = FDeviceNode) then
  begin
    ShowMessage('Running task: ' + SelectedNode.Text);
    { TODO: Implement actual task execution }
  end;
end;

procedure TMainWindowForm.RunBatchButtonClick(Sender: TObject);
var
  SelectedNode: TTreeNode;
  thread: TAnnealBatchThread;
  SpecsStringList: TStringList;
  SpecsArrary: TJunctionSpecArray;

begin
  SelectedNode := DeviceTreeView.Selected;
  if SelectedNode = nil then
  begin
    ShowMessage('Please select a batch task.');
    Exit;
  end;

  if DeviceManager.IsOperationRunning then
  begin
    ShowMessage('An operation is already running.');
    Exit;
  end;

  ShowMessage('Running batch task: ' + SelectedNode.Text);
  { TODO: Implement actual batch task execution }

  SpecsStringList:= TStringList(SelectedNode.Data);
  SetLength(SpecsArray, SpecsStringList.Count);
  For i:=0 to SpecsStringList.Count-1 do
  Begin
    SpecsArray[i]:=  TJunctionSpec.CreateFromCSV(SpecsStringList[i]);
  end;
  thread.Create(FAnnealManager.AnnealBatch(SpecsArray,"C:\"));
  ResultViewerForm.ShowModal;
end;

procedure TMainWindowForm.DeviceTreeViewDblClick(Sender: TObject);
var
  SelectedNode: TTreeNode;
begin
  SelectedNode := DeviceTreeView.Selected;
  if SelectedNode = nil then Exit;

  { Handle different node types }
  if SelectedNode.Text = 'Config' then
  begin
    { Open configuration form }
    AnnealConfigForm.InitializeFromTask(TStringList(SelectedNode.Data),SelectedNode.Parent.Text);
    if AnnealConfigForm.ShowModal = mrOk then
    begin
      SelectedNode.Data := AnnealConfigForm.FJunctionConfigs;
      ShowMessage('Configuration saved.');
    end;
  end
  else if SelectedNode.Text = 'Result' then
  begin
    ShowMessage('Displaying result chart for: ' + SelectedNode.Parent.Text);
    { TODO: Display result data }
  end;
end;

procedure TMainWindowForm.ConnectButtonClick(Sender: TObject);
begin
  if not Assigned(FAnnealManager) then
    FAnnealManager := TAnnealManager.Create("","","",Self);

  try
    if FAnnealManager.Initialize then
    begin
      ShowMessage('Connected to all instruments.');
      UpdateEquipmentStatus;
    end
    else
      ShowMessage('Failed to connect to one or more instruments.');
  except
    on E: Exception do
      ShowMessage('Connection error: ' + E.Message);
  end;
end;

procedure TMainWindowForm.UpdateEquipmentStatus;
begin
  if Assigned(FAnnealManager) then
  begin
    EquipmentStatusBar.Panels[1].Text := 'Equipment: Connected';
    EquipmentStatusBar.Repaint;
  end;
end;

procedure TMainWindowForm.DeviceTreeViewDeletion(Sender: TObject; Node: TTreeNode);
begin
  if Node.Data <> nil then
  begin
    {Dispose(PNodeData(Node.Data));
    Node.Data := nil;}
  end;
end;

procedure TMainWindowForm.FormDestroy(Sender: TObject);
begin
  if Assigned(FCurrentThread) then
  begin
    FCurrentThread.Terminate;
    FCurrentThread.WaitFor;
    FCurrentThread.Free;
  end;
  FreeAndNil(FAnnealManager);
end;

procedure TMainWindowForm.FileMenuItemClick(Sender: TObject);
begin
  { Menu click handler }
end;

procedure TMainWindowForm.AnnealMenuItemClick(Sender: TObject);
begin
  AddTaskButtonClick(nil);
end;

procedure TMainWindowForm.ResistanceMenuItemClick(Sender: TObject);
begin
  AddTaskButtonClick(nil);
end;

procedure TMainWindowForm.EquipmentStatusBarDrawPanel(AEquipmentStatusBar: TStatusBar;
  Panel: TStatusPanel; const Rect: TRect);
type
  TStatusRecord = record
    Color: TColor;
    Text: string;
  end;

var
  LedColor: TColor;
  LedRadius: Integer;
  LedX, LedY: Integer;
  TextX, TextY: Integer;
  StatusText: string;
  item: TStatusRecord;
  EquipmentStatusArray: array[1..3] of TStatusRecord;
begin
  EquipmentStatusArray[1].Color := clRed;
  EquipmentStatusArray[1].Text := 'B1500: OFF';
  EquipmentStatusArray[2].Color := clRed;
  EquipmentStatusArray[2].Text := 'HEATER: OFF';
  EquipmentStatusArray[3].Color := clRed;
  EquipmentStatusArray[3].Text := 'Prober: OFF';


  if Panel.Index = 1 then
  begin
    if Assigned(FAnnealManager) then
    begin
      if FAnnealManager.FSetupStatus[0].OK then
      begin
        EquipmentStatusArray[1].Color := clLime;
        EquipmentStatusArray[1].Text := 'B1500: Connected';
      end;
      if FAnnealManager.FSetupStatus[1].OK then
      begin
        EquipmentStatusArray[3].Color := clLime;
        EquipmentStatusArray[3].Text := 'Heater: Connected';
      end;
      if FAnnealManager.FSetupStatus[2].OK then
      begin
        EquipmentStatusArray[2].Color := clLime;
        EquipmentStatusArray[2].Text := 'Prober: Connected';
      end;
    end;
  end;

  AEquipmentStatusBar.Canvas.Brush.Color := AEquipmentStatusBar.Color;
  AEquipmentStatusBar.Canvas.FillRect(Rect);
  LedRadius := 5;
  LedX := Rect.Left + LedRadius + 6;
  LedY := Rect.Top + ((Rect.Bottom - Rect.Top) div 2);
  AEquipmentStatusBar.Canvas.Pen.Color := clGray;

  for item in EquipmentStatusArray do
  begin
    AEquipmentStatusBar.Canvas.Brush.Color := item.Color;
    AEquipmentStatusBar.Canvas.Ellipse(LedX - LedRadius, LedY - LedRadius,
      LedX + LedRadius, LedY + LedRadius);
    AEquipmentStatusBar.Canvas.Brush.Style := bsClear;
    AEquipmentStatusBar.Canvas.Font.Color := clWindowText;
    StatusText := item.Text;
    TextX := LedX + LedRadius + 8;
    TextY := Rect.Top + ((Rect.Bottom - Rect.Top -
      AEquipmentStatusBar.Canvas.TextHeight(StatusText)) div 2);
    AEquipmentStatusBar.Canvas.TextOut(TextX, TextY, StatusText);
    LedX := TextX + AEquipmentStatusBar.Canvas.TextWidth(StatusText) + LedRadius + 12;
  end;
end;

procedure TMainWindowForm.TaskToolBarClick(Sender: TObject);
begin
  { Toolbar click handler }
end;

procedure TMainWindowForm.DeviceTreeViewClick(Sender: TObject);
begin
  if (DeviceTreeView.Selected <> nil) and (DeviceTreeView.Selected.Data <> nil) then
  begin
    if (Integer(PtrInt(DeviceTreeView.Selected.Data)) = AddTaskUniqueID) then
    begin
      TaskSelectionPopup.PopUp;
      DeviceTreeView.Selected.Selected := False;
    end;
  end;
end;

procedure TMainWindowForm.RefreshTreeView;
begin
  DeviceTreeView.Items.Clear;
  if DeviceManager.CurrentDevice <> nil then
  begin
    FDeviceNode := DeviceTreeView.Items.Add(nil, DeviceManager.CurrentDevice.Name);
    FDeviceNode.ImageIndex := GetImageIndexForNodeType(ntDevice);
    FDeviceNode.SelectedIndex := FDeviceNode.ImageIndex;

    FAddTask := DeviceTreeView.Items.AddChild(FDeviceNode, 'Add Task...');
    FAddTask.ImageIndex := GetImageIndexForNodeType(ntAddTask);
    FAddTask.Data := Pointer(PtrInt(AddTaskUniqueID));

    FDeviceNode.Expanded := True;
    PopulateDeviceInfo;
  end;
end;

procedure TMainWindowForm.OnThreadTerminate(Sender: TObject);
begin
  if FCurrentThread <> nil then
  begin
    if FCurrentThread.ThreadError <> '' then
      ShowMessage('Operation failed: ' + FCurrentThread.ThreadError)
    else
      ShowMessage('Operation completed successfully.');

    DeviceManager.SetOperationRunning(False);
    FCurrentThread.Free;
    FCurrentThread := nil;
    UpdateEquipmentStatus;
  end;
end;

procedure TMainWindowForm.Log(const Msg : string);
begin

end;

procedure TMainWindowForm.Progress(
    Percent : Double;
    const Msg : string);
begin

end;

procedure TMainWindowForm.MeasurementPoint(
    Time : Double;
    Value : Double);
begin

end;

procedure TMainWindowForm.BatchStarted(
    Count : Integer);
begin

end;

procedure TMainWindowForm.BatchFinished;
begin

end;

procedure TMainWindowForm.JunctionStarted(
    const Name : string);
begin

end;

procedure TMainWindowForm.JunctionFinished(
    const Name : string;
    Result : TAnnealResult);
begin

end;

procedure TMainWindowForm.Error(
    E : Exception);
begin

end;

end.
