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
  end;

  function NowSeconds: Double;
  function MeanDoubleArray(const A: TDoubleArray): Double;
  function StdDoubleArray(const A: TDoubleArray): Double;
  function DoubleArrayToJSON(const A: TDoubleArray): TJSONArray;
  function SampleArrayToJSON(const A: TSampleArray): TJSONArray;
  function ProberCoordToJSON(const ACoord: TProberCoord): TJSONObject;

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

function TProbingResult.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Readings', DoubleArrayToJSON(Readings));
  Result.AddPair('MeanResistance', TJSONNumber.Create(MeanResistance));
  Result.AddPair('StdResistance', TJSONNumber.Create(StdResistance));
  Result.AddPair('Success', TJSONBool.Create(Success));
  Result.AddPair('ErrorMsg', TJSONString.Create(ErrorMsg));
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

end.
