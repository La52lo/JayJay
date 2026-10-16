unit MainWindowUnit;

interface

uses
  Classes, SysUtils, Vcl.Forms, Controls, Graphics, Dialogs, Menus, ComCtrls,
  ExtCtrls ,Contnrs, Winapi.Windows, ProbeConfig, DeviceDialogUnit,
  TaskSelectDialogUnit, AnnealConfig, ResultViewer,logview, threadinghelper,
  MeasurementObserver,AnnealManager,AnnealTypes,nodejunctionmapper,
  System.ImageList, Vcl.ImgList, Vcl.ToolWin, Mitov.VCLTypes,
  VCL.LPControl, SLControlCollection, LPControlDrawLayers, SLBasicDataDisplay,
  SLDataDisplay, SLDataChart, SLScope, System.Types,System.Generics.Collections,
  DeviceManagerUnit, Chart4D.Types,Chart4D.Style,Chart4D.VCL, Chart4D.Series;

type

  { TMainWindowForm }

  TNodeToTaskMap = TDictionary<TTreeNode,THardwareTask>;
  TNodeSpecifier = class
  public
    FNodeType: TNodeType;
  end;
  TMainWindowForm = class(TForm,IMeasurementObserver)
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
    TaskToolBar: TToolBar;
    RunSingleButton: TToolButton;
    ConnectButton: TToolButton;
    DeviceTreeView: TTreeView;
    TreeNodeIcons: TImageList;
    LogButton: TToolButton;
    ToolButton1: TToolButton;

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
    procedure DeviceTreeViewChanging(Sender: TObject; Node: TTreeNode;
      var AllowChange: Boolean);
    procedure ToolButton1Click(Sender: TObject);
    procedure LogButtonClick(Sender: TObject);
    procedure DeviceTreeViewEditing(Sender: TObject; Node: TTreeNode;
      var AllowEdit: Boolean);
    procedure DeviceTreeViewEdited(Sender: TObject; Node: TTreeNode;
      var S: string);
  private
    FAddTask: TTreeNode;
    FDeviceNode: TTreeNode;
    FSetupStatus: TSetupStatus;
    FCurrentThread: THardwareThread;
    FSelectedTaskNode: TTreeNode;
    {FActiveNode: TTreeNode;}
    FActiveTask: THardwareTask;
    IsTaskRunning: Boolean;
    FDeviceManager: TDeviceManager;
    FJunctionNodeList: TObjectList<TJunctionNodeData>;
    Chart        : TChart4D;
    function GetImageIndexForNodeType(ANodeType: TNodeType): Integer;
    function GetDisplayNameForNodeType(ANodeType: TNodeType): string;
    function AddNode(AParent: TTreeNode; const ANodeType: TNodeType;
                     const AText: string): TTreeNode;
    procedure OnThreadTerminate(Sender: TObject);
    procedure UpdateEquipmentStatus;
    procedure PopulateDeviceInfo;
    procedure CreateDefaultDevice;
    procedure DispatchTask(TaskPointer:Pointer);
    procedure AddMetadataNodes(ANode: TTreeNode; ACreatedAt, AModifiedAt: TDateTime);
    function AddJunctionNode(ANode: TTreeNode;JunctionEntry:TJunctionEntry):TTreeNode;
    function IsMetadataNode(ANode: TTreeNode): Boolean;
  protected
     { Override TComponent interface methods to disable reference counting }
    function QueryInterface(const IID: TGuid; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    procedure RefreshTreeView;
    { :::::::::: Interface procedures :::::::::: }
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
    (NodeType: TNodeType.ntDevice; ImageIndex: 0; DisplayName: 'Device'),
    (NodeType: TNodeType.ntAddTask; ImageIndex: 0; DisplayName: 'Add Task...'),
    (NodeType: TNodeType.ntAnneal; ImageIndex: 1; DisplayName: 'Anneal'),
    (NodeType: TNodeType.ntBatchAnneal; ImageIndex: 1; DisplayName: 'Batch Anneal'),
    (NodeType: TNodeType.ntProbe; ImageIndex: 2; DisplayName: 'Resistance'),
    (NodeType: TNodeType.ntBatchProbe; ImageIndex: 2; DisplayName: 'Batch Probing'),
    (NodeType: TNodeType.ntAnnealConfig; ImageIndex: 3; DisplayName: 'Config'),
    (NodeType: TNodeType.ntAnnealResult; ImageIndex: 4; DisplayName: 'Result'),
    (NodeType: TNodeType.ntProbeConfig; ImageIndex: 3; DisplayName: 'Config'),
    (NodeType: TNodeType.ntProbeResult; ImageIndex: 4; DisplayName: 'Result'),
    (NodeType: TNodeType.ntAnnealedJunction; ImageIndex: 7; DisplayName: 'Junction'),
    (NodeType: TNodeType.ntProbedJunction; ImageIndex: 6; DisplayName: 'Junction')
  );

var
  MainWindowForm: TMainWindowForm;
  {AnnealSetup: TAnnealSetup;}

implementation

{$R *.dfm}

{ TMainWindowForm }

procedure TMainWindowForm.FormCreate(Sender: TObject);
begin

  FJunctionNodeList := TObjectList<TJunctionNodeData>.Create(True);
  DeviceTreeView.Items.Clear;
  FCurrentThread := nil;
  FSelectedTaskNode := nil;
  {FNodeToJunctionMap:= TTreeArrayMapper.Create; }
  
  { Enable inline editing }
  DeviceTreeView.ReadOnly := False;
  DeviceTreeView.OnEditing := DeviceTreeViewEditing;
  DeviceTreeView.OnEdited := DeviceTreeViewEdited;
  
  Chart := TChart4D.Create(Self);
  Chart.Parent := Self;
  Chart.Align := alClient;


  Chart.Plot.Kind := TChartKind.Scatter;
  Chart.Plot.Orientation := TChartOrientation.Vertical;
  Chart.Plot.Title := 'Almost everyone is online';
  Chart.Plot.Subtitle := 'Share of the population using the internet, 2020';
  Chart.Plot.Source := 'Source: World Bank';
  {Chart.Plot.Categories := ['Sweden', 'Spain', 'Belgium', 'Netherlands'];}
  Chart.Plot.AddSeries('2020', [94.5, 93.2, 91.5, 91.3]);
  {Chart.Plot.AddLineSeries();}

  Chart.SaveToPng('online.png');

  { Create default device }
  FSetupStatus[0].Label_ := 'Analyzer';
  FSetupStatus[1].Label_ := 'Prober';
  FSetupStatus[2].Label_ := 'Heater';
  {FNodeToTaskMap := TNodeToTaskMap.Create;}
  FDeviceManager := TDeviceManager.Create;
  CreateDefaultDevice;
end;

procedure TMainWindowForm.CreateDefaultDevice;
begin
  FDeviceManager.CreateNewDevice('Default Device');
  RefreshTreeView;
end;

procedure TMainWindowForm.DispatchTask(TaskPointer:Pointer);
begin
   case (THardwareTask(TaskPointer)).TaskType of
       TNodeType.ntProbe:
         begin
         FCurrentThread.Probe((TProbeTask(TaskPointer)).Config);
         end;
       TNodeType.ntAnneal:
         begin
         FCurrentThread.Anneal((TAnnealTask(TaskPointer)).Config);
         end;
       TNodeType.ntBatchAnneal:
         begin
         FCurrentThread.AnnealBatch((TBatchAnnealTask(TaskPointer)).Config);
         end;
       TNodeType.ntBatchProbe:
         begin
         FCurrentThread.ProbeBatch((TBatchProbeTask(TaskPointer)).Config);
         end;
   end;
end;

procedure TMainWindowForm.PopulateDeviceInfo;
var
  InfoText: string;
begin
  if FDeviceManager.DeviceInfo <> nil then
  begin
    InfoText := Format('Device: %s | Created: %s',
      [FDeviceManager.DeviceInfo.Name,
       FormatDateTime('yyyy-mm-dd hh:nn:ss', FDeviceManager.DeviceInfo.CreatedAt)]);
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

function TMainWindowForm.IsMetadataNode(ANode: TTreeNode): Boolean;
begin
  Result := (ANode <> nil) and (ANode.Parent <> nil) and
    ((ANode.Text = 'Created') or (ANode.Text = 'Modified') or 
     (ANode.Text = 'Config') or (ANode.Text = 'Result'));
end;

procedure TMainWindowForm.AddMetadataNodes(ANode: TTreeNode; ACreatedAt, AModifiedAt: TDateTime);
var
  CreatedNode, ModifiedNode: TTreeNode;
begin
  if ANode = nil then Exit;

  CreatedNode := DeviceTreeView.Items.AddChild(ANode, 'Created: ' + FormatDateTime('yyyy-mm-dd hh:mm:ss', ACreatedAt));
  CreatedNode.ImageIndex := 5; { Gray info icon }
  CreatedNode.SelectedIndex := CreatedNode.ImageIndex;

  ModifiedNode := DeviceTreeView.Items.AddChild(ANode, 'Modified: ' + FormatDateTime('yyyy-mm-dd hh:mm:ss', AModifiedAt));
  ModifiedNode.ImageIndex := 5; { Gray info icon }
  ModifiedNode.SelectedIndex := ModifiedNode.ImageIndex;
end;

function TMainWindowForm.AddJunctionNode(ANode: TTreeNode;
                        JunctionEntry:TJunctionEntry):TTreeNode;
var
  CreatedNode: TTreeNode;
begin

  if ANode = nil then Exit(nil);

  CreatedNode := DeviceTreeView.Items.AddChild(ANode, JunctionEntry.Name);
  CreatedNode.ImageIndex := GetImageIndexForNodeType(JunctionEntry.NodeType);
  CreatedNode.SelectedIndex := CreatedNode.ImageIndex;
  FJunctionNodeList.Add(TJunctionNodeData.Create(JunctionEntry));
  CreatedNode.Data := FJunctionNodeList.Last;
  result := CreatedNode;
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
  if ANodeType in [ntAnneal, ntProbe, ntBatchAnneal, ntBatchProbe] then
  begin
    ConfigNode := DeviceTreeView.Items.AddChild(Result, 'Config');
    ConfigNode.ImageIndex := GetImageIndexForNodeType(ntAnnealConfig);
    ConfigNode.SelectedIndex := ConfigNode.ImageIndex;
    {ConfigNode.Data := TStringList.Create;}

    ResultNode := DeviceTreeView.Items.AddChild(Result, 'Result');
    ResultNode.ImageIndex := GetImageIndexForNodeType(ntAnnealResult);
    ResultNode.SelectedIndex := ResultNode.ImageIndex;
  end;
  DeviceTreeView.FullExpand;
end;


procedure TMainWindowForm.NewDeviceMenuItemClick(Sender: TObject);
var
  DeviceName: string;
begin
  if FDeviceManager.IsOperationRunning then
  begin
    ShowMessage('Cannot create device while operation is running.');
    Exit;
  end;

  if DeviceDialog.ShowDeviceDialog(DeviceName) then
  begin
    DeviceTreeView.Items.Clear;
    FDeviceManager.CreateNewDevice(DeviceName);
    FDeviceNode := DeviceTreeView.Items.Add(nil, DeviceName);
    FDeviceNode.ImageIndex := GetImageIndexForNodeType(ntDevice);
    FDeviceNode.SelectedIndex := FDeviceNode.ImageIndex;
    FDeviceNode.Data := FDeviceManager.DeviceInfo;

    { Add metadata subnodes }
    AddMetadataNodes(FDeviceNode, FDeviceManager.DeviceInfo.CreatedAt, FDeviceManager.DeviceInfo.ModifiedAt);

    FAddTask := DeviceTreeView.Items.AddChild(FDeviceNode, 'Add Task...');
    FAddTask.ImageIndex := GetImageIndexForNodeType(ntAddTask);
    {FAddTask.Data := Pointer(PtrInt(AddTaskUniqueID));}

    FDeviceNode.Expanded := True;
    PopulateDeviceInfo;
  end;
end;

function TMainWindowForm.QueryInterface(const IID: TGuid; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function TMainWindowForm._AddRef: Integer;
begin
  Result := -1; // Prevents Delphi from treating your Main Form as a COM object
end;

function TMainWindowForm._Release: Integer;
begin
  Result := -1; // Prevents accidental destruction when interface scope ends
end;


procedure TMainWindowForm.OpenDeviceMenuItemClick(Sender: TObject);
var
  OpenDialog: TOpenDialog;
begin
  if FDeviceManager.IsOperationRunning then
  begin
    ShowMessage('Cannot open device while operation is running.');
    Exit;
  end;

  OpenDialog := TOpenDialog.Create(nil);
  try
    OpenDialog.Filter := 'Device files (*.json)|*.json';
    if OpenDialog.Execute then
    begin
      FDeviceManager.LoadDevice(OpenDialog.FileName);
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
    SaveDialog.Filter := 'Device files (*.json)|*.json';
    SaveDialog.DefaultExt := 'json';
    if SaveDialog.Execute then
      FDeviceManager.SaveDevice(SaveDialog.FileName);
  finally
    SaveDialog.Free;
  end;
end;

procedure TMainWindowForm.AddTaskButtonClick(Sender: TObject);
var
  TaskType: TNodeType;
  TaskName: string;
  NewTaskNode: TTreeNode;
  NewHardwareTask: THardwareTask;
begin
  if TaskSelectDialog.ShowTaskSelectDialog(TaskType) then
  begin
    case TaskType of
      TNodeType.ntAnneal:
      begin
        NewHardwareTask := TAnnealTask.Create('',TaskType)
      end;
     TNodeType.ntBatchAnneal:
      begin
        NewHardwareTask := TBatchAnnealTask.Create('',TaskType)
      end;
      TNodeType.ntProbe:
      begin
        NewHardwareTask := TProbeTask.Create('',TaskType)
      end;
      TNodeType.ntBatchProbe:
      begin
        NewHardwareTask := TBatchProbeTask.Create('',TaskType)
      end else exit;
    end;
    TaskName := NewHardwareTask.DisplayName;
    //NewTaskNode := AddNode(FDeviceNode, TaskType, TaskName);
    //NewTaskNode.Data := NewHardwareTask;
    
    { Add metadata subnodes to task }
    //AddMetadataNodes(NewTaskNode, NewHardwareTask.CreatedAt, NewHardwareTask.ExecutedAt);
    
    FDeviceManager.AddTask(NewHardwareTask,TaskName, TaskType);
    FSelectedTaskNode := NewTaskNode;
    RefreshTreeView;
  end;
end;

procedure TMainWindowForm.RunSingleButtonClick(Sender: TObject);
var
  SelectedNode: TTreeNode;
begin
  SelectedNode := DeviceTreeView.Selected;
  if SelectedNode = nil then
  begin
    ShowMessage('Please select a task.');
    Exit;
  end;

  if FDeviceManager.IsOperationRunning then
  begin
    ShowMessage('An operation is already running.');
    Exit;
  end;

  { Determine task type and execute }
  if (SelectedNode.Parent <> nil) and (SelectedNode.Parent = FDeviceNode) then
  begin
    ShowMessage('Running task: ' + SelectedNode.Text);
    FActiveTask := THardwareTask(SelectedNode.Data);
    DispatchTask(SelectedNode.Data);
    { TODO: Implement actual task execution }
    {FCurrentThread.}
  end;
end;

procedure TMainWindowForm.RunBatchButtonClick(Sender: TObject);
var
  SelectedNode: TTreeNode;
begin
  SelectedNode := DeviceTreeView.Selected;
  if SelectedNode = nil then
  begin
    ShowMessage('Please select a batch task.');
    Exit;
  end;

  if FDeviceManager.IsOperationRunning then
  begin
    ShowMessage('An operation is already running.');
    Exit;
  end;

  if (SelectedNode.Parent <> nil) and (SelectedNode.Parent = FDeviceNode) then
  begin
    ShowMessage('Running task: ' + SelectedNode.Text);
    FActiveTask := THardwareTask(SelectedNode.Data);
    DispatchTask(SelectedNode.Data);
    { TODO: Implement actual task execution }
    {FCurrentThread.}
  end;

  { ResultViewerForm.ShowModal;}

end;

procedure TMainWindowForm.DeviceTreeViewDblClick(Sender: TObject);
var
  {SelectedNode: TTreeNode;  }
  AnnealTask : TAnnealTask;
  BatchAnnealTask : TBatchAnnealTask;
  ProbeTask : TProbeTask;
  Task      : THardwareTask;
  AnnealParameters : TAnnealConfig;
  AnnealParameterArray :  TAnnealConfigArray;
  ProbingParameters : TProbingParameters;
  XValues,YValues: TArray<Double>;
  ErrorMsg  : String;
  ErrorCol  : Integer;
  ErrorRow  : Integer;

  P: TPoint;
  Node: TTreeNode;
begin
  {SelectedNode := DeviceTreeView.Selected;
  if SelectedNode = nil then Exit; }
  GetCursorPos(P);
  P := DeviceTreeView.ScreenToClient(P);
  Node := DeviceTreeView.GetNodeAt(P.X, P.Y);
  if not Assigned(Node) then
    Exit;
  { Handle different node types }
  if (Node.Level = 1) or (Node.Level = 0)  then
  begin
    Node.EditText;
  end;
  if Node.Level = 2 then
  begin
    if (Node.Text = 'Config') and (Node.Parent.Text = 'Single Anneal') then
    begin
      { Open configuration form }
      AnnealTask :=  TAnnealTask(Node.Parent.Data);
      AnnealConfigForm.InitializeFromConfig(
         AnnealTask.Config,Node.Parent.Text);
      if AnnealConfigForm.ShowModal = mrOk then
      begin
        AnnealConfigForm.RowToParamRecord(1,AnnealParameters,
                                          ErrorMsg,ErrorCol);
        if ErrorMsg = '' then
        Begin
        ShowMessage('Configuration saved.');
        AnnealTask.Config := AnnealParameters;
        End Else ShowMessage(ErrorMsg);
      end;
    end else
      if (Node.Text = 'Config') and (Node.Parent.Text = 'Batch Anneal') then
    begin
      { Open configuration form }
      BatchAnnealTask :=  TBatchAnnealTask(Node.Parent.Data);
      AnnealConfigForm.InitializeFromConfig(
         BatchAnnealTask.Config,Node.Parent.Text);
      if AnnealConfigForm.ShowModal = mrOk then
      begin
        AnnealConfigForm.GridToParamArray(AnnealParameterArray,
                                          ErrorMsg,ErrorRow,ErrorCol);
        if ErrorMsg = '' then
        Begin
        ShowMessage('Configuration saved.');
        BatchAnnealTask.Config := AnnealParameterArray;
        End Else ShowMessage(ErrorMsg);
      end;
    end  else
    if (Node.Text = 'Config') then
    begin
      { Open configuration form }
      ProbeTask :=  TProbeTask(Node.Parent.Data);
      ProbeConfigForm.InitializeFromConfig(
         ProbeTask.Config,Node.Parent.Text);
      if ProbeConfigForm.ShowModal = mrOk then
      begin
        ProbeConfigForm.SaveToConfig(ProbingParameters,
                                          ErrorMsg);
        if ErrorMsg = '' then
        Begin
        ShowMessage('Configuration saved.');
        ProbeTask.Config := ProbingParameters;
        End Else ShowMessage(ErrorMsg);
      end;
    end
    else if Node.Text = 'Result' then
    begin
      ShowMessage('Displaying result chart for: ' + Node.Parent.Text);
      { TODO: Display result data }
    end else if (Node.Data <> nil) and (TObject(Node.Data) is TJunctionNodeData) then
             begin
               Task :=  THardwareTask(Node.Parent.Data);
               Task.GetChartPoints(XValues,YValues,TJunctionNodeData(Node.Data).FEntry.Index);
               ResultViewerForm.PlotData(XValues,YValues);
             end;
  end;
end;

procedure TMainWindowForm.ConnectButtonClick(Sender: TObject);
begin
  if not Assigned(FCurrentThread) then
    FCurrentThread := THardwareThread.Create(Self);

  try
    FCurrentThread.Start;
    FCurrentThread.Initialize

  except
    on E: Exception do
      ShowMessage('Connection error: ' + E.Message);
  end;
end;

procedure TMainWindowForm.UpdateEquipmentStatus;
begin
  if length(FSetupStatus) = 3  then
      EquipmentStatusBar.Panels[1].Text := 'Equipment: Connected'
  else EquipmentStatusBar.Panels[1].Text := 'Initializing';
  EquipmentStatusBar.Repaint;
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
    FJunctionNodeList.Free;
    FDeviceManager.Free;

  end;

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
var
  LedRadius: Integer;
  LedX, LedY: Integer;
  TextX, TextY: Integer;
  StatusText: string;
  Instrument: TInstrumentStatus;
begin

  AEquipmentStatusBar.Canvas.Brush.Color := AEquipmentStatusBar.Color;
  AEquipmentStatusBar.Canvas.FillRect(Rect);
  LedRadius := 5;
  LedX := Rect.Left + LedRadius + 6;
  LedY := Rect.Top + ((Rect.Bottom - Rect.Top) div 2);
  AEquipmentStatusBar.Canvas.Pen.Color := clGray;

  for Instrument in FSetupStatus do

  begin
    if Instrument.OK then
        AEquipmentStatusBar.Canvas.Brush.Color := clLime
    else  AEquipmentStatusBar.Canvas.Brush.Color := clRed;
    AEquipmentStatusBar.Canvas.Ellipse(LedX - LedRadius, LedY - LedRadius,
      LedX + LedRadius, LedY + LedRadius);
    AEquipmentStatusBar.Canvas.Brush.Style := bsClear;
    AEquipmentStatusBar.Canvas.Font.Color := clWindowText;
    StatusText := Instrument.Label_;
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

procedure TMainWindowForm.ToolButton1Click(Sender: TObject);
var
  C: Integer;
  TempArray  : TArray<Double>;
  XTempArray  : TArray<Double>;
begin
//Chart.Plot.AddSeries('Res');
 TempArray := Chart.Plot.Series[0].Values;
 XTempArray := Chart.Plot.Series[0].XValues;
 C := Length(TempArray);
 SetLength(TempArray, C + 1);
 SetLength(XTempArray, C + 1);
 TempArray[High(TempArray)] := 88;
 XTempArray[High(XTempArray)] := 5;
 ;Chart.Plot.Series[0].Values := TempArray;
 ;Chart.Plot.Series[0].XValues := XTempArray;
 Chart.Plot.ClearSeries;
 Chart.Plot.AddSeries('Resistance',TempArray);


end;

procedure TMainWindowForm.DeviceTreeViewChanging(Sender: TObject;
  Node: TTreeNode; var AllowChange: Boolean);
begin
  AllowChange := Node.HasChildren;
end;

procedure TMainWindowForm.DeviceTreeViewClick(Sender: TObject);
var
HardwareTask : THardwareTask;
Node         : TTreeNode;

begin

  if (DeviceTreeView.Selected <> nil) and (DeviceTreeView.Selected.Data <> nil) then
  begin
    Node := DeviceTreeView.Selected;
    if  Node.Level = 0 then
      begin
        RunSingleButton.Visible := False;
        RunBatchButton.Visible := False;
        exit;
      end;
    HardwareTask :=  THardwareTask(Node.Data);


    if (HardwareTask.TaskType = TNodeType.ntAnneal) or (HardwareTask.TaskType = TNodeType.ntProbe) then
    begin
      RunSingleButton.Visible := True;
      RunBatchButton.Visible := False;
    end else
    begin
      RunSingleButton.Visible := False;
      RunBatchButton.Visible := True;
    end;
  end;
end;

procedure TMainWindowForm.DeviceTreeViewEditing(Sender: TObject; Node: TTreeNode;
  var AllowEdit: Boolean);
begin
  { Only allow editing of device and task nodes, not metadata subnodes }
  AllowEdit := (Node.Data <> nil) and not IsMetadataNode(Node);
  
  { Prevent editing Config/Result nodes }
  if (Node.Text = 'Config')
    or (Node.Text = 'Result')
    or (Node.Text = 'Add Task...')
    then AllowEdit := False;
end;

procedure TMainWindowForm.DeviceTreeViewEdited(Sender: TObject; Node: TTreeNode;
  var S: string);
var
  Task: THardwareTask;
  Device: TDeviceInfo;
begin
  { Validate input }
  if Trim(S) = '' then
  begin
    ShowMessage('Name cannot be empty.');
    S := Node.Text;  { Revert changes }
    Exit;
  end;

  { Update device name }
  if Node = FDeviceNode then
  begin
    Device := TDeviceInfo(Node.Data);
    if Device <> nil then
    begin
      Device.Name := S;
      Device.ModifiedAt := Now;
      {FDeviceManager.SaveDevice('');  Optional: auto-save if filepath set }
      PopulateDeviceInfo;
    end;
  end
  else if Node.Parent = FDeviceNode then
  begin
    { Update task name }
    Task := THardwareTask(Node.Data);
    if Task <> nil then
    begin
      Task.Name := S;
      Task.DisplayName := S;
      {FDeviceManager.SaveDevice('');  Optional: auto-save if filepath set }
    end;
  end;

  Node.Text := S;
end;

procedure TMainWindowForm.RefreshTreeView;
var
 I,J : Integer;
 NewTaskNode :TTreeNode;
 JunctionListing : TJunctionListing;

begin
  DeviceTreeView.Items.Clear;
  if FDeviceManager.DeviceInfo <> nil then
  begin
    FDeviceNode := DeviceTreeView.Items.Add(nil, FDeviceManager.DeviceInfo.Name);
    FDeviceNode.ImageIndex := GetImageIndexForNodeType(ntDevice);
    FDeviceNode.SelectedIndex := FDeviceNode.ImageIndex;
    FDeviceNode.Data := FDeviceManager.DeviceInfo;

    { Add metadata subnodes for device }
    AddMetadataNodes(FDeviceNode, FDeviceManager.DeviceInfo.CreatedAt, FDeviceManager.DeviceInfo.ModifiedAt);
    for I := 0 to FDeviceManager.GetTaskCount-1 do
    begin
        NewTaskNode := AddNode(FDeviceNode, FDeviceManager.GetTask(I).TaskType,
                                             FDeviceManager.GetTask(I).DisplayName);
        NewTaskNode.Data := FDeviceManager.GetTask(I);

        { Add metadata subnodes for each task }
        AddMetadataNodes(NewTaskNode, FDeviceManager.GetTask(I).CreatedAt, FDeviceManager.GetTask(I).ExecutedAt);
        JunctionListing :=  FDeviceManager.GetTask(I).GetJunctionListing;
        For J := 0 To High(JunctionListing) do
          begin
            AddJunctionNode(NewTaskNode,JunctionListing[J]);
          end;
    end;
    FDeviceNode.Expanded := True;
    PopulateDeviceInfo;
  end;
end;

procedure TMainWindowForm.OnThreadTerminate(Sender: TObject);
begin
 { if FCurrentThread <> nil then
  begin
    if FCurrentThread.ThreadError <> '' then
      ShowMessage('Operation failed: ' + FCurrentThread.ThreadError)
    else
      ShowMessage('Operation completed successfully.');

    DeviceManager.SetOperationRunning(False);
    FCurrentThread.Free;
    FCurrentThread := nil;
    UpdateEquipmentStatus;
  end;}
end;

procedure TMainWindowForm.Log(const Msg: string);
begin
   LogViewForm.Memo1.Lines.Add(Msg);
end;

procedure TMainWindowForm.LogButtonClick(Sender: TObject);
begin
LogViewForm.Show;
end;

procedure TMainWindowForm.InitializeSetup(
  Status: TSetupStatus);
begin
    if length(Status) = 3 then
     begin
      ShowMessage('Connected to all instruments.');
    end
    else
      ShowMessage('Failed to connect to one or more instruments.');
    FSetupStatus := Status;
    UpdateEquipmentStatus;
end;

procedure TMainWindowForm.MeasurementPoint(
  Time: Double;
  Value: Double);
var
  C: Integer;
  TempArray  : TArray<Double>;
  XTempArray  : TArray<Double>;
begin
 TempArray := Chart.Plot.Series[0].Values;
 XTempArray := Chart.Plot.Series[0].XValues;
 C := Length(TempArray);
 SetLength(TempArray, C + 1);
 SetLength(XTempArray, C + 1);
 TempArray[High(TempArray)] := Value;
 XTempArray[High(XTempArray)] := Time;
 Chart.Plot.ClearSeries;
 Chart.Plot.AddSeries('Resistance',TempArray);
end;

procedure TMainWindowForm.TaskStarted();
 begin
    Chart.Plot.ClearSeries;
 end;

procedure TMainWindowForm.TaskFinished(
  Result: THardwareResult);
 begin
   FActiveTask.SetResult(Result);
   RefreshTreeView;

 end;


procedure TMainWindowForm.Error(
  const Msg: string);
  begin
    LogViewForm.Memo1.Lines.Add(Msg);
end;

end.
