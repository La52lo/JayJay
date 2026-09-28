unit ProbeConfig;

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ValEdit, Vcl.Grids,
  AnnealTypes, Vcl.ExtCtrls, Vcl.StdCtrls;

type

  { TResistanceConfigForm }

  TProbeConfigForm = class(TForm)
    ProbeConfigEditor: TValueListEditor;
    Button1: TButton;
    Button2: TButton;
    Panel1: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);


  private

  public
    DefaultResistanceConfig: TStringList;
    procedure InitializeFromConfig(AConfig: TProbingParameters;
                                               ATaskName:String);
    procedure SaveToConfig( out AConfig:TProbingParameters;
                                         out ErrorMessage: string );
  end;

var
  ProbeConfigForm: TProbeConfigForm;

implementation

{$R *.dfm}

{ TResistanceConfigForm }

procedure TProbeConfigForm.FormCreate(Sender: TObject);
begin
  with ProbeConfigEditor.ItemProps['Mode'] do
  begin
    EditStyle := TEditStyle.esPickList;
    ReadOnly := True;
    PickList.Add('Single');
    PickList.Add('Batch');

  end;
  ProbeConfigEditor.Values['Mode']:='Single';
  DefaultResistanceConfig := TStringList.Create;
  DefaultResistanceConfig.Assign(ProbeConfigEditor.Strings);
end;

procedure TProbeConfigForm.InitializeFromConfig(AConfig: TProbingParameters;
                                               ATaskName:String);
begin
  Caption := 'Configure Task: ' + ATaskName;
  with AConfig do begin
      if (Length(VoltageList) > 0) then
      begin
         ProbeConfigEditor.Values['Starting voltage [V]']:= VoltageList[0].ToString;
         ProbeConfigEditor.Values['Number of steps']:= Length(VoltageList).ToString;
      end;
      if (Length(VoltageList) > 1) then
      begin
         ProbeConfigEditor.Values['Step size [V]']
                    := (VoltageList[1]-VoltageList[0]).ToString;
      end;
      ProbeConfigEditor.Values['Measure Time [s]']
                    := MeasureTime.ToString;
      ProbeConfigEditor.Values['Initial Wait [s]']
                    := InitialWait.ToString;

  end;


end;



procedure TProbeConfigForm.SaveToConfig( out AConfig:TProbingParameters;
                                         out ErrorMessage: string );
var
      VoltageList        : TDoubleArray;
      MeasureTime        : Double;
      InitialWait        : Double;    { s,  default 1.0    }
      StartingVoltage    : Double;
      StepSize           : Double;
      NumberOfSteps      : Integer;
      i                  : Integer;
begin
if not TryStrToFloat(Trim(ProbeConfigEditor.Values['Starting voltage [V]']),
    StartingVoltage) then
  begin
    ErrorMessage := 'Starting voltage Invalid number: "' +
                    ProbeConfigEditor.Values['Starting voltage [V]'] + '"';
    Exit;
  end;

 if not TryStrToFloat(Trim(ProbeConfigEditor.Values['Step size [V]']),
    StepSize) then
  begin
    ErrorMessage := 'Step size Invalid number: "' +
                    ProbeConfigEditor.Values['Step size [V]'] + '"';
    Exit;
  end;

 if not TryStrToInt(Trim(ProbeConfigEditor.Values['Number of steps']),
    NumberOfSteps) then
  begin
    ErrorMessage := 'Number of steps Invalid number: "' +
                    ProbeConfigEditor.Values['Number of steps'] + '"';
    Exit;
  end;


   if not TryStrToFloat(Trim(ProbeConfigEditor.Values['Measure Time [s]']),
    MeasureTime) then
  begin
    ErrorMessage := 'Measure Time Invalid number: "' +
                    ProbeConfigEditor.Values['Measure Time [s]'] + '"';
    Exit;
  end;

  if not TryStrToFloat(Trim(ProbeConfigEditor.Values['Initial Wait [s]']),
    InitialWait) then
  begin
    ErrorMessage := 'Initial Wait Invalid number: "' +
                    ProbeConfigEditor.Values['Initial Wait [s]'] + '"';
    Exit;
  end;

  SetLength(VoltageList,NumberOfSteps);
  VoltageList[0]:= StartingVoltage;
  for i := 1 to NumberOfSteps-1  do
  begin
    VoltageList[i] :=  StartingVoltage + i*StepSize;
  end;
  AConfig.VoltageList := VoltageList;
  AConfig.MeasureTime := MeasureTime;
  AConfig.InitialWait := InitialWait;

end;

procedure TProbeConfigForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(DefaultResistanceConfig);
end;

end.
