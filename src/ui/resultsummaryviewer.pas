unit ResultSummaryViewer;

interface

uses
  System.SysUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Grids,
  DeviceManagerUnit;

procedure ShowTaskResultSummary(ATask: THardwareTask);

type
  TTaskResultSummaryForm = class(TForm)
  private
    FGrid: TStringGrid;
    FNextRow: Integer;
    procedure SetColumns(const AHeaders: array of string);
    procedure AddRow(const AValues: array of string);
    procedure ShowNoResults;
    procedure ShowSingleAnneal(ATask: TAnnealTask);
    procedure ShowSingleProbe(ATask: TProbeTask);
    procedure ShowBatchAnneal(ATask: TBatchAnnealTask);
    procedure ShowBatchProbe(ATask: TBatchProbeTask);
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

uses
  Vcl.StdCtrls,
  AnnealTypes;

constructor TTaskResultSummaryForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'Task Result Summary';
  Position := poScreenCenter;
  Width := 850;
  Height := 420;
  BorderStyle := bsSizeable;

  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.FixedRows := 1;
  FGrid.FixedCols := 0;
  FGrid.ColCount := 1;
  FGrid.RowCount := 2;
  FGrid.Options := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine,
    goColSizing, goRowSelect, goThumbTracking];
  FGrid.DefaultColWidth := 140;
  FGrid.Cells[0, 0] := 'Summary';
  FGrid.Cells[0, 1] := '';
  FNextRow := 1;
end;

procedure TTaskResultSummaryForm.SetColumns(const AHeaders: array of string);
var
  I: Integer;
begin
  FGrid.ColCount := Length(AHeaders);
  FGrid.RowCount := 2;
  FNextRow := 1;
  for I := Low(AHeaders) to High(AHeaders) do
    FGrid.Cells[I, 0] := AHeaders[I];
end;

procedure TTaskResultSummaryForm.AddRow(const AValues: array of string);
var
  I: Integer;
begin
  if Length(AValues) <> FGrid.ColCount then
    raise EArgumentException.Create('Summary row does not match the column count.');

  if FNextRow >= FGrid.RowCount then
    FGrid.RowCount := FNextRow + 1;
  for I := Low(AValues) to High(AValues) do
    FGrid.Cells[I, FNextRow] := AValues[I];
  Inc(FNextRow);
end;

procedure TTaskResultSummaryForm.ShowNoResults;
begin
  SetColumns(['Status']);
  AddRow(['No results are available for this task.']);
end;

procedure TTaskResultSummaryForm.ShowSingleAnneal(ATask: TAnnealTask);
var
  R: TAnnealResult;
begin
  R := ATask.Result;
  if (Length(R.ResistanceSamples) = 0) and (Length(R.ResistanceAvg) = 0) and
     (Length(R.PulseDurations) = 0) and (R.FinalCycleCount = 0) and
     (R.FinalPairCount = 0) then
  begin
    ShowNoResults;
    Exit;
  end;

  SetColumns(['Metric', 'Value']);
  AddRow(['Target resistance (Ohm)', FloatToStrF(R.TargetResistance, ffFixed, 12, 2)]);
  AddRow(['Final resistance (Ohm)', FloatToStrF(R.FinalResistance, ffFixed, 12, 2)]);
  AddRow(['Total cycles', IntToStr(R.FinalCycleCount)]);
  AddRow(['Total pairs', IntToStr(R.FinalPairCount)]);
  AddRow(['Pulse duration mean (s)', FloatToStrF(R.PulseDurationMean, ffFixed, 12, 4)]);
  AddRow(['Pulse duration std (s)', FloatToStrF(R.PulseDurationStd, ffFixed, 12, 4)]);
end;

procedure TTaskResultSummaryForm.ShowSingleProbe(ATask: TProbeTask);
var
  R: TProbingResult;
begin
  R := ATask.Result;
  if (Length(R.Readings) = 0) and not R.Success and (R.ErrorMsg = '') then
  begin
    ShowNoResults;
    Exit;
  end;

  SetColumns(['Metric', 'Value']);
  AddRow(['Mean resistance (Ohm)', FloatToStrF(R.MeanResistance, ffFixed, 12, 2)]);
  AddRow(['Std resistance (Ohm)', FloatToStrF(R.StdResistance, ffFixed, 12, 2)]);
  AddRow(['Success', BoolToStr(R.Success, True)]);
  if R.ErrorMsg <> '' then
    AddRow(['Error', R.ErrorMsg]);
end;

procedure TTaskResultSummaryForm.ShowBatchAnneal(ATask: TBatchAnnealTask);
var
  I: Integer;
  J: TAnnealedJunction;
begin
  if Length(ATask.Result) = 0 then
  begin
    ShowNoResults;
    Exit;
  end;

  SetColumns(['Subsite name', 'Subsite X', 'Subsite Y', 'Target resistance (Ohm)',
    'Final resistance (Ohm)', 'Total pairs']);
  for I := Low(ATask.Result) to High(ATask.Result) do
  begin
    J := ATask.Result[I];
    AddRow([J.Coord.Subsite,
      FloatToStrF(J.Coord.Subsite_X, ffFixed, 12, 3),
      FloatToStrF(J.Coord.Subsite_Y, ffFixed, 12, 3),
      FloatToStrF(J.AnnealResult.TargetResistance, ffFixed, 12, 2),
      FloatToStrF(J.AnnealResult.FinalResistance, ffFixed, 12, 2),
      IntToStr(J.AnnealResult.FinalPairCount)]);
  end;
end;

procedure TTaskResultSummaryForm.ShowBatchProbe(ATask: TBatchProbeTask);
var
  I: Integer;
  J: TProbedJunction;
begin
  if Length(ATask.Result) = 0 then
  begin
    ShowNoResults;
    Exit;
  end;

  SetColumns(['Subsite name', 'Subsite X', 'Subsite Y', 'Mean resistance (Ohm)',
    'Std resistance (Ohm)', 'Success']);
  for I := Low(ATask.Result) to High(ATask.Result) do
  begin
    J := ATask.Result[I];
    AddRow([J.Coord.Subsite,
      FloatToStrF(J.Coord.Subsite_X, ffFixed, 12, 3),
      FloatToStrF(J.Coord.Subsite_Y, ffFixed, 12, 3),
      FloatToStrF(J.ProbingResult.MeanResistance, ffFixed, 12, 2),
      FloatToStrF(J.ProbingResult.StdResistance, ffFixed, 12, 2),
      BoolToStr(J.ProbingResult.Success, True)]);
  end;
end;

procedure ShowTaskResultSummary(ATask: THardwareTask);
var
  Form: TTaskResultSummaryForm;
begin
  if ATask = nil then
    Exit;

  Form := TTaskResultSummaryForm.Create(nil);
  try
    Form.Caption := ATask.DisplayName + ' - Result Summary';
    case ATask.TaskType of
      ntAnneal:
        Form.ShowSingleAnneal(TAnnealTask(ATask));
      ntProbe:
        Form.ShowSingleProbe(TProbeTask(ATask));
      ntBatchAnneal:
        Form.ShowBatchAnneal(TBatchAnnealTask(ATask));
      ntBatchProbe:
        Form.ShowBatchProbe(TBatchProbeTask(ATask));
    else
      Form.ShowNoResults;
    end;
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

end.
