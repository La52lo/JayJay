unit AnnealTypes;

interface

uses
  Classes, SysUtils, System.JSON;
type

  TInstrumentStatus = record
    Label_   : string;
    Address  : string;
    Folder   : string;        { only for prober}
    OK       : Boolean;       { True = connected, False = failed }
    Skipped  : Boolean;       { True = not configured (nil address) }
    Message  : string;
  end;

  TSetupStatus = Array[0..2] of TInstrumentStatus;

  TAnnealConfig = record
    MeasureVoltage     : Double;
    MeasureTime        : Double;
    PulsePositive      : Double;
    PulseNegative      : Double;
    PulseLength        : Double;
    PulsePairs         : Integer;
    Cycles             : Integer;
    TargetResistance   : Double;
    Temperature        : Double;
    ThresholdOpen      : Double;
    ThresholdShort     : Double;
    InitialWait        : Double;    { s,  default 1.0    }
  end;

  TAnnealParameterArray =  TArray<TAnnealConfig>;
  TDoubleArray  = array of Double;
  TProbingParameters = record
      VoltageList        : TDoubleArray;
      MeasureTime        : Double;
      InitialWait        : Double;    { s,  default 1.0    }
  end;

  TSamplePoint = record
    Time  : Double;   { seconds since t0 }
    Value : Double;   { resistance (Ohm) or voltage (V) }
  end;

  TSampleArray  = array of TSamplePoint;

  TProberCoord = record
    Chip_X,Chip_Y        : Integer;
    Subsite_X,Subsite_Y  : Double;
    Subsite              : string;
    Break                : Boolean;
    function ToString    : string;
  end;

  TProberCoordArray  = array of TProberCoord;

  TAnnealResult = Record

      ResistanceSamples  : TSampleArray;   { all individual R readings }
      ResistanceAvg      : TDoubleArray;   { mean R after each cycle   }
      ResistanceStd      : TDoubleArray;   { std  R after each cycle   }
      VoltageSamples     : TSampleArray;   { all voltage log points    }
      PulseDurations     : TDoubleArray;   { wall-clock time per pulse }
      TargetResistance   : Double;         { 0.0 means no target set   }
      PulseDurationMean  : Double;
      PulseDurationStd   : Double;

      procedure   AddResistanceSample(ATime, AValue: Double);
      procedure   AddVoltageSample(ATime, AValue: Double);
      procedure   AppendCycleStats(AMean, AStd: Double);
      procedure   AppendPulseDuration(ADuration: Double);
      procedure   Finalise;
      function    FinalResistance: Double;   { last entry in ResistanceAvg, or -1 }
      function    ToJSON: TJSONObject;
      procedure   FromJSON(AJsonObj: TJSONObject);
    end;
  TAnnealedJunction = record
      AnnealResult : TAnnealResult;
      Coord        : TProberCoord;
  end;

  TAnnealResultArray = array of TAnnealedJunction;

  TProbingResult = record
      Readings        : TDoubleArray;
      MeanResistance  : Double;
      StdResistance   : Double;
      Success         : Boolean;
      ErrorMsg        : string;
      function ToJSON: TJSONObject;
      procedure FromJSON(AJsonObj: TJSONObject);
    end;

  TProbedJunction = record
      ProbingResult : TProbingResult;
      Coord        : TProberCoord;
  end;
  TProbingResultArray = array of TProbedJunction;

  TNodeType = (ntDevice, ntAddTask, ntAnneal, ntBatchAnneal,
                ntProbe,ntBatchProbe, ntAnnealConfig,
               ntAnnealResult, ntProbeConfig, ntProbeResult);

  type
  THardwareCommandType = (
    hcInitialize,
    hcAnneal,
    hcProbe,
    hcAnnealBatch,
    hcProbeBatch,
    hcShutdown
  );

  THardwareCommand = record
    TaskID : String;
    CommandType: THardwareCommandType;
    AnnealParameters: TAnnealConfig;
    ProbingParameters: TProbingParameters;
    AnnealParameterArray: TAnnealParameterArray;
  end;

  THardwareResult = record
    CommandType: THardwareCommandType;
    AnnealResult: TAnnealResult;
    ProbingResult: TProbingResult;
    AnnealResultArray: TAnnealResultArray;
    ProbingResultArray: TProbingResultArray;
    function ToJSON: TJSONObject;
    procedure FromJSON(AJsonObj: TJSONObject);
  end;

  function NowSeconds: Double;
  function MeanDoubleArray(const A: TDoubleArray): Double;
  function StdDoubleArray(const A: TDoubleArray): Double;
  function DoubleArrayToJSON(const A: TDoubleArray): TJSONArray;
  function SampleArrayToJSON(const A: TSampleArray): TJSONArray;
  function ProberCoordToJSON(const ACoord: TProberCoord): TJSONObject;
  function JSONToDoubleArray(AJsonArray: TJSONArray): TDoubleArray;
  function JSONToSampleArray(AJsonArray: TJSONArray): TSampleArray;
  function JSONToProberCoord(AJsonObj: TJSONObject): TProberCoord;

implementation
{ Current time as seconds since the Unix epoch (used for relative timing). }
function NowSeconds: Double;
begin
  Result := Now * SecsPerDay;
end;

function MeanDoubleArray(const A: TDoubleArray): Double;
var
  i: Integer;
  S: Double;
begin
  if Length(A) = 0 then Exit(0.0);
  S := 0.0;
  for i := 0 to High(A) do S := S + A[i];
  Result := S / Length(A);
end;

function StdDoubleArray(const A: TDoubleArray): Double;
var
  i: Integer;
  M, S: Double;
begin
  if Length(A) = 0 then Exit(0.0);
  M := MeanDoubleArray(A);
  S := 0.0;
  for i := 0 to High(A) do S := S + Sqr(A[i] - M);
  Result := Sqrt(S / Length(A));
end;

function DoubleArrayToJSON(const A: TDoubleArray): TJSONArray;
var
  i: Integer;
begin
  Result := TJSONArray.Create;
  for i := 0 to High(A) do
    Result.AddElement(TJSONNumber.Create(A[i]));
end;

function SampleArrayToJSON(const A: TSampleArray): TJSONArray;
var
  i: Integer;
  SampleObj: TJSONObject;
begin
  Result := TJSONArray.Create;
  for i := 0 to High(A) do
  begin
    SampleObj := TJSONObject.Create;
    SampleObj.AddPair('Time', TJSONNumber.Create(A[i].Time));
    SampleObj.AddPair('Value', TJSONNumber.Create(A[i].Value));
    Result.AddElement(SampleObj);
  end;
end;

function ProberCoordToJSON(const ACoord: TProberCoord): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Chip_X', TJSONNumber.Create(ACoord.Chip_X));
  Result.AddPair('Chip_Y', TJSONNumber.Create(ACoord.Chip_Y));
  Result.AddPair('Subsite_X', TJSONNumber.Create(ACoord.Subsite_X));
  Result.AddPair('Subsite_Y', TJSONNumber.Create(ACoord.Subsite_Y));
  Result.AddPair('Subsite', TJSONString.Create(ACoord.Subsite));
  Result.AddPair('Break', TJSONBool.Create(ACoord.Break));
end;

function JSONToDoubleArray(AJsonArray: TJSONArray): TDoubleArray;
var
  i: Integer;
begin
  if AJsonArray = nil then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(Result, AJsonArray.Count);
  for i := 0 to AJsonArray.Count - 1 do
  begin
    if AJsonArray[i] is TJSONNumber then
      Result[i] := TJSONNumber(AJsonArray[i]).AsDouble
    else
      Result[i] := 0.0;
  end;
end;

function JSONToSampleArray(AJsonArray: TJSONArray): TSampleArray;
var
  i: Integer;
  SampleObj: TJSONObject;
begin
  if AJsonArray = nil then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(Result, AJsonArray.Count);
  for i := 0 to AJsonArray.Count - 1 do
  begin
    if AJsonArray[i] is TJSONObject then
    begin
      SampleObj := TJSONObject(AJsonArray[i]);
      Result[i].Time := SampleObj.GetValue('Time', 0.0);
      Result[i].Value := SampleObj.GetValue('Value', 0.0);
    end
    else
    begin
      Result[i].Time := 0.0;
      Result[i].Value := 0.0;
    end;
  end;
end;

function JSONToProberCoord(AJsonObj: TJSONObject): TProberCoord;
begin
  if AJsonObj = nil then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;

  Result.Chip_X := AJsonObj.GetValue('Chip_X', 0);
  Result.Chip_Y := AJsonObj.GetValue('Chip_Y', 0);
  Result.Subsite_X := AJsonObj.GetValue('Subsite_X', 0.0);
  Result.Subsite_Y := AJsonObj.GetValue('Subsite_Y', 0.0);
  Result.Subsite := AJsonObj.GetValue('Subsite', '');
  Result.Break := AJsonObj.GetValue('Break', False);
end;

// ---------------------------------------------------------------------------
// TProberCoord
// ---------------------------------------------------------------------------

function TProberCoord.ToString: string;
begin
  {Result := Format('(%d, %d, ''%s'')', [X, Y, Subsite]);}
end;

// ---------------------------------------------------------------------------
// TAnnealResult
// ---------------------------------------------------------------------------
{
constructor TAnnealResult.Create;
begin
  inherited;
  SetLength(ResistanceSamples, 0);
  SetLength(ResistanceAvg,     0);
  SetLength(ResistanceStd,     0);
  SetLength(VoltageSamples,    0);
  SetLength(PulseDurations,    0);
  TargetResistance  := 0.0;
  PulseDurationMean := 0.0;
  PulseDurationStd  := 0.0;
end;
 }
procedure TAnnealResult.AddResistanceSample(ATime, AValue: Double);
var N: Integer;
begin
  N := Length(ResistanceSamples);
  SetLength(ResistanceSamples, N + 1);
  ResistanceSamples[N].Time  := ATime;
  ResistanceSamples[N].Value := AValue;
end;

procedure TAnnealResult.AddVoltageSample(ATime, AValue: Double);
var N: Integer;
begin
  N := Length(VoltageSamples);
  SetLength(VoltageSamples, N + 1);
  VoltageSamples[N].Time  := ATime;
  VoltageSamples[N].Value := AValue;
end;

procedure TAnnealResult.AppendCycleStats(AMean, AStd: Double);
var N: Integer;
begin
  N := Length(ResistanceAvg);
  SetLength(ResistanceAvg, N + 1);
  SetLength(ResistanceStd, N + 1);
  ResistanceAvg[N] := AMean;
  ResistanceStd[N] := AStd;
end;

procedure TAnnealResult.AppendPulseDuration(ADuration: Double);
var N: Integer;
begin
  N := Length(PulseDurations);
  SetLength(PulseDurations, N + 1);
  PulseDurations[N] := ADuration;
end;

procedure TAnnealResult.Finalise;
begin
  PulseDurationMean := MeanDoubleArray(PulseDurations);
  PulseDurationStd  := StdDoubleArray(PulseDurations);
end;

function TAnnealResult.FinalResistance: Double;
var N: Integer;
begin
  N := Length(ResistanceAvg);
  if N = 0 then Result := -1.0
  else           Result := ResistanceAvg[N - 1];
end;

function TAnnealResult.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('ResistanceSamples', SampleArrayToJSON(ResistanceSamples));
  Result.AddPair('ResistanceAvg', DoubleArrayToJSON(ResistanceAvg));
  Result.AddPair('ResistanceStd', DoubleArrayToJSON(ResistanceStd));
  Result.AddPair('VoltageSamples', SampleArrayToJSON(VoltageSamples));
  Result.AddPair('PulseDurations', DoubleArrayToJSON(PulseDurations));
  Result.AddPair('TargetResistance', TJSONNumber.Create(TargetResistance));
  Result.AddPair('PulseDurationMean', TJSONNumber.Create(PulseDurationMean));
  Result.AddPair('PulseDurationStd', TJSONNumber.Create(PulseDurationStd));
end;

procedure TAnnealResult.FromJSON(AJsonObj: TJSONObject);
begin
  if AJsonObj = nil then Exit;

  ResistanceSamples := JSONToSampleArray(TJSONArray(AJsonObj.Get('ResistanceSamples')));
  ResistanceAvg := JSONToDoubleArray(TJSONArray(AJsonObj.Get('ResistanceAvg')));
  ResistanceStd := JSONToDoubleArray(TJSONArray(AJsonObj.Get('ResistanceStd')));
  VoltageSamples := JSONToSampleArray(TJSONArray(AJsonObj.Get('VoltageSamples')));
  PulseDurations := JSONToDoubleArray(TJSONArray(AJsonObj.Get('PulseDurations')));
  TargetResistance := AJsonObj.GetValue('TargetResistance', 0.0);
  PulseDurationMean := AJsonObj.GetValue('PulseDurationMean', 0.0);
  PulseDurationStd := AJsonObj.GetValue('PulseDurationStd', 0.0);
end;

function TProbingResult.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Readings', DoubleArrayToJSON(Readings));
  Result.AddPair('MeanResistance', TJSONNumber.Create(MeanResistance));
  Result.AddPair('StdResistance', TJSONNumber.Create(StdResistance));
  Result.AddPair('Success', TJSONBool.Create(Success));
  Result.AddPair('ErrorMsg', TJSONString.Create(ErrorMsg));
end;

procedure TProbingResult.FromJSON(AJsonObj: TJSONObject);
begin
  if AJsonObj = nil then Exit;

  Readings := JSONToDoubleArray(TJSONArray(AJsonObj.Get('Readings')));
  MeanResistance := AJsonObj.GetValue('MeanResistance', 0.0);
  StdResistance := AJsonObj.GetValue('StdResistance', 0.0);
  Success := AJsonObj.GetValue('Success', False);
  ErrorMsg := AJsonObj.GetValue('ErrorMsg', '');
end;

function THardwareResult.ToJSON: TJSONObject;
var
  i: Integer;
  AnnealArray, ProbingArray: TJSONArray;
  JunctionObj: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('CommandType', TJSONNumber.Create(Integer(CommandType)));

  { Serialize single anneal result }
  Result.AddPair('AnnealResult', AnnealResult.ToJSON);

  { Serialize single probing result }
  Result.AddPair('ProbingResult', ProbingResult.ToJSON);

  { Serialize batch anneal results (array of TAnnealedJunction) }
  AnnealArray := TJSONArray.Create;
  for i := 0 to High(AnnealResultArray) do
  begin
    JunctionObj := TJSONObject.Create;
    JunctionObj.AddPair('AnnealResult', AnnealResultArray[i].AnnealResult.ToJSON);
    JunctionObj.AddPair('Coord', ProberCoordToJSON(AnnealResultArray[i].Coord));
    AnnealArray.AddElement(JunctionObj);
  end;
  Result.AddPair('AnnealResultArray', AnnealArray);

  { Serialize batch probing results (array of TProbedJunction) }
  ProbingArray := TJSONArray.Create;
  for i := 0 to High(ProbingResultArray) do
  begin
    JunctionObj := TJSONObject.Create;
    JunctionObj.AddPair('ProbingResult', ProbingResultArray[i].ProbingResult.ToJSON);
    JunctionObj.AddPair('Coord', ProberCoordToJSON(ProbingResultArray[i].Coord));
    ProbingArray.AddElement(JunctionObj);
  end;
  Result.AddPair('ProbingResultArray', ProbingArray);
end;

procedure THardwareResult.FromJSON(AJsonObj: TJSONObject);
var
  i: Integer;
  AnnealArray, ProbingArray: TJSONArray;
  JunctionObj: TJSONObject;
begin
  if AJsonObj = nil then Exit;

  { Deserialize command type }
  CommandType := THardwareCommandType(AJsonObj.GetValue('CommandType', 0));

  { Deserialize single anneal result }
  if AJsonObj.IndexOfName('AnnealResult') >= 0 then
    AnnealResult.FromJSON(TJSONObject(AJsonObj.Get('AnnealResult')));

  { Deserialize single probing result }
  if AJsonObj.IndexOfName('ProbingResult') >= 0 then
    ProbingResult.FromJSON(TJSONObject(AJsonObj.Get('ProbingResult')));

  { Deserialize batch anneal results }
  AnnealArray := TJSONArray(AJsonObj.Get('AnnealResultArray'));
  if AnnealArray <> nil then
  begin
    SetLength(AnnealResultArray, AnnealArray.Count);
    for i := 0 to AnnealArray.Count - 1 do
    begin
      JunctionObj := TJSONObject(AnnealArray[i]);
      AnnealResultArray[i].AnnealResult.FromJSON(TJSONObject(JunctionObj.Get('AnnealResult')));
      AnnealResultArray[i].Coord := JSONToProberCoord(TJSONObject(JunctionObj.Get('Coord')));
    end;
  end
  else
    SetLength(AnnealResultArray, 0);

  { Deserialize batch probing results }
  ProbingArray := TJSONArray(AJsonObj.Get('ProbingResultArray'));
  if ProbingArray <> nil then
  begin
    SetLength(ProbingResultArray, ProbingArray.Count);
    for i := 0 to ProbingArray.Count - 1 do
    begin
      JunctionObj := TJSONObject(ProbingArray[i]);
      ProbingResultArray[i].ProbingResult.FromJSON(TJSONObject(JunctionObj.Get('ProbingResult')));
      ProbingResultArray[i].Coord := JSONToProberCoord(TJSONObject(JunctionObj.Get('Coord')));
    end;
  end
  else
    SetLength(ProbingResultArray, 0);
end;

end.
