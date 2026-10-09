unit ResultViewer;

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, AnnealTypes,
  Mitov.VCLTypes, VCL.LPControl, SLControlCollection, LPControlDrawLayers,
  Chart4D.Types,Chart4D.Style,Chart4D.VCL, Chart4D.Series;

type

  { TResultViewerForm }

  TResultViewerForm = class(TForm)
    InfoPanel: TPanel;
    procedure CloseButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
  private
    FResult: TAnnealResult;
    FJunctionLabel: string;
    FExecutionTime: TDateTime;
    Chart        : TChart4D;
    procedure PlotData(XValues,YValues:  TArray<Double>);
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
end;

procedure TResultViewerForm.PlotData(XValues,YValues: TArray<Double>);
 var
  I: Integer;
begin
  Chart.Plot.ClearSeries;
  Chart.Plot.AddLineSeries('Measurement', XValues, YValues);
  Self.Show;
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
