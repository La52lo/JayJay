unit ResultViewer;

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, AnnealTypes,
  Mitov.VCLTypes, VCL.LPControl, SLControlCollection, LPControlDrawLayers,
  SLBasicDataDisplay, SLDataDisplay, SLDataChart, SLScope;

type

  { TResultViewerForm }

  TResultViewerForm = class(TForm)
    CloseButton: TButton;
    InfoPanel: TPanel;
    SaveButton: TButton;
    SLScope1: TSLScope;
    procedure CloseButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
  private
    FResult: TAnnealResult;
    FJunctionLabel: string;
    FExecutionTime: TDateTime;
    procedure PlotResistanceData;
    procedure PlotVoltageData;
    procedure UpdateInfoPanel;
  public
    procedure DisplayResult(AResult: TAnnealResult; const AJunctionLabel: string;
                           AExecutionTime: TDateTime);
  end;

var
  ResultViewerForm: TResultViewerForm;

implementation

{$R *.dfm}

{ TResultViewerForm }
procedure TResultViewerForm.FormCreate(Sender: TObject);
{
var
  LineSeries: TLineSeries;}
begin
 {
   Create two series: one for resistance, one for voltage
  LineSeries := TLineSeries.Create(Chart1);
  LineSeries.Title := 'Resistance';
  Chart1.AddSeries(LineSeries);

  LineSeries := TLineSeries.Create(Chart1);
  LineSeries.Title := 'Voltage';
  Chart1.AddSeries(LineSeries); }
end;

procedure TResultViewerForm.PlotResistanceData;
{
var
  i: Integer;
  Series: TLineSeries;  }
begin                   {
  if Chart1.SeriesCount = 0 then Exit;

  Series := TLineSeries(Chart1.Series[0]);
  Series.Clear;

  for i := 0 to High(FResult.ResistanceAvg) do
    Series.AddXY(i, FResult.ResistanceAvg[i]);}
end;

procedure TResultViewerForm.PlotVoltageData;
{
var
  i: Integer;
  Series: TLineSeries;  }
begin                    {
  if Chart1.SeriesCount < 2 then Exit;

  Series := TLineSeries(Chart1.Series[1]);
  Series.Clear;

  for i := 0 to High(FResult.VoltageSamples) do
    Series.AddXY(FResult.VoltageSamples[i].Time, FResult.VoltageSamples[i].Value);

    }end;

procedure TResultViewerForm.UpdateInfoPanel;
var
  InfoText: string;
begin
  InfoText := Format('Junction: %s | Executed: %s | Final Resistance: %.1f Ohm | ' +
                     'Target: %.1f Ohm',
                     [FJunctionLabel, FormatDateTime('yyyy-mm-dd hh:nn:ss', FExecutionTime),
                      FResult.FinalResistance, FResult.TargetResistance]);
  InfoPanel.Caption := InfoText;
end;

procedure TResultViewerForm.DisplayResult(AResult: TAnnealResult;
  const AJunctionLabel: string; AExecutionTime: TDateTime);
begin
  FResult := AResult;
  FJunctionLabel := AJunctionLabel;
  FExecutionTime := AExecutionTime;

  Caption := 'Result: ' + AJunctionLabel;
  PlotResistanceData;
  PlotVoltageData;
  UpdateInfoPanel;
end;

procedure TResultViewerForm.SaveButtonClick(Sender: TObject);
var
  SaveDialog: TSaveDialog;
begin
  SaveDialog := TSaveDialog.Create(nil);
  try
    SaveDialog.FileName := FJunctionLabel + '_result.csv';
    SaveDialog.Filter := 'CSV files (*.csv)|*.csv';
    if SaveDialog.Execute then
    begin
      { Save resistance data }
        ShowMessage('Result saved to ' + SaveDialog.FileName);
    end;
  finally
    SaveDialog.Free;
  end;
end;

procedure TResultViewerForm.CloseButtonClick(Sender: TObject);
begin
  Close;
end;
end.
