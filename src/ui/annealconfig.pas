unit AnnealConfig;


interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Grids, Spin, StdCtrls,
  ExtCtrls, Buttons,AnnealTypes,
  Clipbrd, System.Math;

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
    procedure StringGrid1KeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    FModified: Boolean;
    FAnnealConfig: TAnnealConfig;
    FAnnealConfigArray: TAnnealParameterArray;
    procedure LoadGridFromConfig(AConfig: TAnnealParameterArray);
    {procedure SaveCurrentConfig; }
    procedure DisplaySiteNumber;

  public

    procedure InitializeFromConfig(AConfig: TAnnealConfig; ATaskName:String); overload;
    procedure InitializeFromConfig(AConfig: TAnnealParameterArray; ATaskName:String); overload;
    function GetModified: Boolean;
    function RowToParamRecord(
            Row : Integer;
            out Data: TAnnealConfig;
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

{$R *.dfm}

{ TAnnealConfigForm }

procedure TAnnealConfigForm.FormCreate(Sender: TObject);
begin
  FModified := False;
  AnnealSpin.Alignment := taCenter;
with StringGrid1 do
begin
  
  ColWidths[0]  := 30;
  ColWidths[1]  := 100;
  ColWidths[2]  := 133;
  ColWidths[3]  := 132;
  ColWidths[4]  := 123;
  ColWidths[5]  := 110;
  ColWidths[6]  := 70;
  ColWidths[7]  := 144;
  ColWidths[8]  := 162;
  ColWidths[9]  := 96;
  ColWidths[10] := 96;
  ColWidths[11] := 96;

  Cells[0, 0]  := 'Junction No.';
  Cells[1, 0]  := 'Target [Ohm]';
  Cells[2, 0]  := 'Temp [ÅãC]';
  Cells[3, 0]  := 'Pulse Low [V]';
  Cells[4, 0]  := 'Pulse High [V]';
  Cells[5, 0]  := 'Pulse Len [s]';
  Cells[6, 0]  := 'Pairs';
  Cells[7, 0]  := 'Cycles';
  Cells[8, 0]  := 'Measure [V]';
  Cells[9, 0]  := 'Measure [s]';
  Cells[10, 0]  := 'Short [Ohm]';
  Cells[11, 0] := 'Open [Ohm]';
  Cells[12, 0] := 'Wait [s]';
end;


  {LoadGridFromConfig(TAnnealParameterArray.Create());}
  DisplaySiteNumber;
end;

procedure TAnnealConfigForm.FormDestroy(Sender: TObject);
begin
  {SaveCurrentConfig;}
end;

procedure TAnnealConfigForm.LoadGridFromConfig(AConfig: TAnnealParameterArray);
var
  i: Integer;
begin
 { if length(Aconfig) = 0 then
  begin

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
  begin}
    StringGrid1.RowCount := length(AConfig) + 1;
    for i := 1 to length(AConfig) do
    Begin
          StringGrid1.Cells[1, i]  := AConfig[i-1].TargetResistance.ToString;
          StringGrid1.Cells[2, i]  := AConfig[i-1].Temperature.ToString;
          StringGrid1.Cells[3, i]  := AConfig[i-1].PulseNegative.ToString;
          StringGrid1.Cells[4, i]  := AConfig[i-1].PulsePositive.ToString;
          StringGrid1.Cells[5, i]  := AConfig[i-1].PulseLength.ToString;
          StringGrid1.Cells[6, i]  := AConfig[i-1].PulsePairs.ToString;
          StringGrid1.Cells[7, i]  := AConfig[i-1].Cycles.ToString;
          StringGrid1.Cells[8, i]  := AConfig[i-1].MeasureVoltage.ToString;
          StringGrid1.Cells[9, i]  := AConfig[i-1].MeasureTime.ToString;
          StringGrid1.Cells[10, i] := AConfig[i-1].ThresholdShort.ToString;
          StringGrid1.Cells[11, i] := AConfig[i-1].ThresholdOpen.ToString;
          StringGrid1.Cells[12, i] := AConfig[i-1].InitialWait.ToString;
    end;
  {end;}
StringGrid1.FixedRows := 1;
StringGrid1.FixedColor := clLime;
end;

{procedure TAnnealConfigForm.SaveCurrentConfig;
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
end;}

procedure TAnnealConfigForm.DisplaySiteNumber;
var
  I: Integer;
begin
  for I := 1 to StringGrid1.RowCount - 1 do
    StringGrid1.Cells[0, I] := IntToStr(I);
end;

procedure TAnnealConfigForm.ApplyButtonClick(Sender: TObject);
begin
  {SaveCurrentConfig;  }
  ModalResult := mrOk;
end;

procedure TAnnealConfigForm.AnnealSpinChange(Sender: TObject);
begin
  StringGrid1.RowCount:=AnnealSpin.Value+1;
  DisplaySiteNumber;
  StringGrid1.FixedRows := 1;
  StringGrid1.FixedColor := clLime;
  
end;

procedure TAnnealConfigForm.CancelButtonClick(Sender: TObject);
begin
  FModified := False;
  ModalResult := mrCancel;
end;

procedure TAnnealConfigForm.InitializeFromConfig(AConfig: TAnnealParameterArray; ATaskName:String);
begin
  Caption := 'Configure Task: ' + ATaskName;
  FAnnealConfigArray := AConfig;
  FModified := False;
  LoadGridFromConfig(FAnnealConfigArray);
  DisplaySiteNumber;
  Label1.Visible := True;
  AnnealSpin.Visible:= True;
end;

procedure TAnnealConfigForm.InitializeFromConfig(AConfig: TAnnealConfig; ATaskName:String);
begin
  Caption := 'Configure Task: ' + ATaskName;
  FAnnealConfigArray := TArray<TAnnealConfig>.Create(AConfig);
  FModified := False;
  LoadGridFromConfig(FAnnealConfigArray);
  DisplaySiteNumber;
  Label1.Visible := False;
  AnnealSpin.Visible:= False;
end;

function TAnnealConfigForm.GetModified: Boolean;
begin
  Result := FModified;
end;


function TAnnealConfigForm.RowToParamRecord(
            Row : Integer;
            out Data: TAnnealConfig;
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

    tempRecord     : TAnnealConfig;

begin
  Result := False;
  ErrorMessage := '';
  ErrorCol := -1;

  if Trim(StringGrid1.Cells[1, Row]) = '' then
    Exit;

  if not TryStrToFloat(Trim(StringGrid1.Cells[1, Row]), TargetResistance) then
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

  if not TryStrToInt(Trim(StringGrid1.Cells[6, Row]), PulsePairs) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[6, Row] + '"';
    ErrorCol := 6;
    Exit;
  end else  tempRecord.PulsePairs := PulsePairs;

  if not TryStrToInt(Trim(StringGrid1.Cells[7, Row]), Cycles) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[7, Row] + '"';
    ErrorCol := 7;
    Exit;
  end else  tempRecord.Cycles := Cycles;

  if not TryStrToFloat(Trim(StringGrid1.Cells[8, Row]), MeasureVoltage) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[8, Row] + '"';
    ErrorCol := 8;
    Exit;
  end else  tempRecord.MeasureVoltage := MeasureVoltage;

  if not TryStrToFloat(Trim(StringGrid1.Cells[9, Row]), MeasureTime) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[9, Row] + '"';
    ErrorCol := 9;
    Exit;
  end else  tempRecord.MeasureTime := MeasureTime;

  if not TryStrToFloat(Trim(StringGrid1.Cells[10, Row]), ThresholdShort) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[10, Row] + '"';
    ErrorCol := 10;
    Exit;
  end else  tempRecord.ThresholdShort := ThresholdShort;

  if not TryStrToFloat(Trim(StringGrid1.Cells[11, Row]), ThresholdOpen) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[11, Row] + '"';
    ErrorCol := 11;
    Exit;
  end else  tempRecord.ThresholdOpen := ThresholdOpen;

  if not TryStrToFloat(Trim(StringGrid1.Cells[12, Row]), InitialWait) then
  begin
    ErrorMessage := 'Invalid number: "' + StringGrid1.Cells[12, Row] + '"';
    ErrorCol := 12;
    Exit;
  end else  tempRecord.InitialWait := InitialWait;
  Data := tempRecord;
  Result := True;
end;



procedure TAnnealConfigForm.StringGrid1KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  Grid: TStringGrid;
  R, C: Integer;
  S: string;
  StartRow, EndRow: Integer;
  Values: TArray<string>;
begin
  Grid := TStringGrid(Sender);

  // Ctrl+C
  if (Key = Ord('C')) and (ssCtrl in Shift) then
  begin
    StartRow := Grid.Selection.Top;
    EndRow   := Grid.Selection.Bottom;

    S := '';

    for R := StartRow to EndRow do
    begin
      if R > StartRow then
        S := S + sLineBreak;

      for C := 1 to Grid.ColCount - 1 do  // skip fixed row-number column
      begin
        if C > 1 then
          S := S + #9;

        S := S + Grid.Cells[C, R];
      end;
    end;

    Clipboard.AsText := S;
    Key := 0;
    Exit;
  end;

  // Ctrl+V
  if (Key = Ord('V')) and (ssCtrl in Shift) then
  begin
    S := Clipboard.AsText;

    if S = '' then
      Exit;

    Values := S.Split([#13, #10], TStringSplitOptions.ExcludeEmpty);

    R := Grid.Row;

    for var Line in Values do
    begin
      // Add a row if necessary
      if R >= Grid.RowCount then
        Grid.RowCount := Grid.RowCount + 1;

      var Cols := Line.Split([#9]);

      for C := 0 to Min(Grid.ColCount - 2, High(Cols)) do
        Grid.Cells[C + 1, R] := Cols[C];

      Inc(R);
    end;

    Key := 0;
  end;
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
    tempRecord     : TAnnealConfig;
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
