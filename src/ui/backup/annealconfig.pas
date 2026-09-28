unit AnnealConfig;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Grids, Spin, StdCtrls,
  ExtCtrls, Buttons,AnnealTypes;

type

  { TAnnealConfigForm }

  TAnnealConfigForm = class(TForm)
    AnnealSpin: TSpinEdit;
    ApplyButton: TButton;
    CancelButton: TButton;
    Label1: TLabel;
    Panel1: TPanel;
    Panel2: TPanel;
    StringGrid1: TStringGrid;
    procedure AnnealSpinChange(Sender: TObject);
    procedure ApplyButtonClick(Sender: TObject);
    procedure CancelButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure StringGrid1ColRowInserted(Sender: TObject; IsColumn: Boolean;
      sIndex, tIndex: Integer);
  private
    FModified: Boolean;
    procedure LoadGridFromConfig;
    procedure SaveCurrentConfig;
    procedure DisplaySiteNumber;
  public
    FJunctionConfigs: TStringList;
    procedure InitializeFromTask(AConfig: TStringList; ATaskName:String);
    function GetModified: Boolean;
    function RowToParamRecord(
            Row : Integer;
            out Data: TAnnealParameters;
            out ErrorMessage: string;
            out ErrorCol: Integer
            ): Boolean;

    function GridToParamArray(
            out Data: TAnnealParameterArray;
            out ErrorMessage: string;
            out ErrorRow: Integer;
            out ErrorCol: Integer
            ): Boolean;
  end;

var
  AnnealConfigForm: TAnnealConfigForm;

implementation

{$R *.lfm}

{ TAnnealConfigForm }

procedure TAnnealConfigForm.FormCreate(Sender: TObject);
begin
  FJunctionConfigs := TStringList.Create;
  FModified := False;

  with StringGrid1 do
  begin

    Columns[0].Width := 50;
    Columns[1].Width := 100;
    Columns[2].Width := 100;
    Columns[3].Width := 100;
    Columns[4].Width := 100;
    Columns[5].Width := 100;
    Columns[6].Width := 80;
    Columns[7].Width := 80;
    Columns[8].Width := 80;
    Columns[9].Width := 80;
    Columns[10].Width := 80;
    Columns[11].Width := 80;
  end;

  LoadGridFromConfig;
  DisplaySiteNumber;
end;

procedure TAnnealConfigForm.FormDestroy(Sender: TObject);
begin
  SaveCurrentConfig;
  FJunctionConfigs.Free;
end;

procedure TAnnealConfigForm.StringGrid1ColRowInserted(Sender: TObject;
  IsColumn: Boolean; sIndex, tIndex: Integer);
begin

end;

procedure TAnnealConfigForm.LoadGridFromConfig;
var
  i: Integer;
  RowHelper: TStringList;
begin
  if FJunctionConfigs.Count = 0 then
  begin
    { Add default configuration }
    StringGrid1.RowCount := 2;
    StringGrid1.Cells[0, 1] := '4500';
    StringGrid1.Cells[1, 1] := '70';
    StringGrid1.Cells[2, 1] := '-0.6';
    StringGrid1.Cells[3, 1] := '0.6';
    StringGrid1.Cells[4, 1] := '2.0';
    StringGrid1.Cells[5, 1] := '500';
    StringGrid1.Cells[6, 1] := '2';
    StringGrid1.Cells[7, 1] := '0.2';
    StringGrid1.Cells[8, 1] := '1.0';
    StringGrid1.Cells[9, 1] := '500.0';
    StringGrid1.Cells[10, 1] := '20000.0';
    StringGrid1.Cells[11, 1] := '1.0';
  end
  else
  begin
    StringGrid1.RowCount := FJunctionConfigs.Count + 1;
    for i := 0 to FJunctionConfigs.Count - 1 do
    Begin
      RowHelper := TStringList.Create;
      RowHelper.CommaText := FJunctionConfigs[i];
      StringGrid1.Rows[i + 1] := RowHelper ;
      RowHelper.Free;
    end;
  end;
end;

procedure TAnnealConfigForm.SaveCurrentConfig;
var
  i: Integer;
  RowText : TStringList;
begin
  for i := 1 to StringGrid1.RowCount-1 do
    begin
      RowText := TStringList(StringGrid1.Rows[i]);
      FJunctionConfigs.Add(RowText.CommaText);
      RowText.Free;
    end;
    FModified := True;
end;

procedure TAnnealConfigForm.DisplaySiteNumber;
begin
  {AnnealSpin.Value := FCurrentRow;
  AnnealSpin.MaxValue := StringGrid1.RowCount - 1;
  BackButton.Enabled := FCurrentRow > 1;
  NextButton.Enabled := FCurrentRow < (StringGrid1.RowCount - 1);}
end;


procedure TAnnealConfigForm.ApplyButtonClick(Sender: TObject);
begin
  SaveCurrentConfig;
  ModalResult := mrOk;
end;

procedure TAnnealConfigForm.AnnealSpinChange(Sender: TObject);
begin
  StringGrid1.RowCount:=AnnealSpin.Value+1;
end;

procedure TAnnealConfigForm.CancelButtonClick(Sender: TObject);
begin
  FModified := False;
  ModalResult := mrCancel;
end;

procedure TAnnealConfigForm.InitializeFromTask(AConfig: TStringList; ATaskName:String);
begin
  Caption := 'Configure Task: ' + ATaskName;
  FJunctionConfigs := AConfig;
  FModified := False;
  LoadGridFromConfig;
  DisplaySiteNumber;
end;

function TAnnealConfigForm.GetModified: Boolean;
begin
  Result := FModified;
end;


function TAnnealConfigForm.RowToParamRecord(
            Row : Integer;
            out Data: TAnnealParameters;
            out ErrorMessage: string;
            out ErrorCol: Integer
            ): Boolean;
var
    TargetResistance   : Double;
    Temperature        : Double;
    MeasureVoltage     : Double;
    MeasureTime        : Double;
    PulsePositive      : Double;
    PulseNegative      : Double;
    PulseLength        : Double;
    PulsePairs         : Integer;
    Cycles             : Integer;
    ThresholdOpen      : Double;
    ThresholdShort     : Double;
    InitialWait        : Double;    { s,  default 1.0    }

    tempRecord     : TAnnealParameters;


begin
  Result := False;
  ErrorMessage := '';
  ErrorCol := -1;

  if Trim(StringGrid1.Cells[0, Row]) = '' then
    Exit;

  if not TryStrToFloat(Trim(StringGrid1.Cells[0, Row]), TargetResistance) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[1, Row] + '"';
    ErrorCol := 1;
    Exit;
  end else  tempRecord.TargetResistance := TargetResistance;

  if not TryStrToFloat(Trim(StringGrid1.Cells[2, Row]), Temperature) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[2, Row] + '"';
    ErrorCol := 2;
    Exit;
  end else  tempRecord.Temperature := Temperature;

  if not TryStrToFloat(Trim(StringGrid1.Cells[3, Row]), PulseNegative) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[3, Row] + '"';
    ErrorCol := 3;
    Exit;
  end else  tempRecord.PulseNegative := PulseNegative;

  if not TryStrToFloat(Trim(StringGrid1.Cells[4, Row]), PulsePositive) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[4, Row] + '"';
    ErrorCol := 4;
    Exit;
  end else  tempRecord.PulsePositive := PulsePositive;

  if not TryStrToFloat(Trim(StringGrid1.Cells[5, Row]), PulseLength) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[5, Row] + '"';
    ErrorCol := 5;
    Exit;
  end else  tempRecord.PulseLength := PulseLength;

  if not TryStrToInt(Trim(StringGrid1.Cells[5, Row]), PulsePairs) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[6, Row] + '"';
    ErrorCol := 6;
    Exit;
  end else  tempRecord.PulsePairs := PulsePairs;

  if not TryStrToInt(Trim(StringGrid1.Cells[6, Row]), Cycles) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[6, Row] + '"';
    ErrorCol := 6;
    Exit;
  end else  tempRecord.Cycles := Cycles;

  if not TryStrToFloat(Trim(StringGrid1.Cells[7, Row]), MeasureVoltage) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[7, Row] + '"';
    ErrorCol := 7;
    Exit;
  end else  tempRecord.MeasureVoltage := MeasureVoltage;

  if not TryStrToFloat(Trim(StringGrid1.Cells[8, Row]), MeasureTime) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[8, Row] + '"';
    ErrorCol := 8;
    Exit;
  end else  tempRecord.MeasureTime := MeasureTime;

  if not TryStrToFloat(Trim(StringGrid1.Cells[9, Row]), ThresholdShort) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[9, Row] + '"';
    ErrorCol := 9;
    Exit;
  end else  tempRecord.ThresholdShort := ThresholdShort;

  if not TryStrToFloat(Trim(StringGrid1.Cells[10, Row]), ThresholdOpen) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[10, Row] + '"';
    ErrorCol := 10;
    Exit;
  end else  tempRecord.ThresholdOpen := ThresholdOpen;

  if not TryStrToFloat(Trim(StringGrid1.Cells[11, Row]), InitialWait) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[11, Row] + '"';
    ErrorCol := 11;
    Exit;
  end else  tempRecord.InitialWait := InitialWait;
  Data := tempRecord;
  Result := True;
end;

function TAnnealConfigForm.GridToParamArray(
            out Data: TAnnealParameterArray;
            out ErrorMessage: string;
            out ErrorRow: Integer;
            out ErrorCol: Integer
            ): Boolean;
var
    TargetResistance   : Double;
    Temperature        : Double;
    MeasureVoltage     : Double;
    MeasureTime        : Double;
    PulsePositive      : Double;
    PulseNegative      : Double;
    PulseLength        : Double;
    PulsePairs         : Integer;
    Cycles             : Integer;
    ThresholdOpen      : Double;
    ThresholdShort     : Double;
    InitialWait        : Double;    { s,  default 1.0    }
    tempRecord     : TAnnealParameters;
    Row                : Integer;
begin
  Result := False;
  SetLength(Data, 0);
  ErrorMessage := '';
  ErrorRow := -1;
  ErrorCol := -1;

  for Row := StringGrid1.FixedRows to StringGrid1.RowCount - 1 do
  begin
    // Ignore empty rows

    if Trim(StringGrid1.Cells[0, Row]) = '' then
      Continue;
    if not RowToParamRecord(Row,tempRecord,ErrorMessage,ErrorCol) then
    begin
      ErrorMessage := 'In Row ' + IntToStr(Row) + ' ' + ErrorMessage;
      ErrorRow := Row;
      Exit;
    end;
    SetLength(Data, Length(Data) + 1);
    Data[High(Data)] := tempRecord;
  end;
  Result := True;
end;


end.
