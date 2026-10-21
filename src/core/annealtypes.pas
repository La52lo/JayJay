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

  TInstrumentType = (itAnalyzer, itProber, itHeater);
  TSetupStatus = Array[TInstrumentType] of TInstrumentStatus;

  TSetupStatusManager = record
    SetupStatus: TSetupStatus;
    function SingleProbeAllowed:Boolean;
    function BatchProbeAllowed:Boolean;
    function SingleAnnealAllowed:Boolean;
    function BatchAnnealAllowed:Boolean;
  end;


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

  TAnnealConfigArray =  TArray<TAnnealConfig>;
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
      FinalCycleCount    : Integer;
      FinalPairCount     : Integer;

      procedure   AddResistanceSample(ATime, AValue: Double);
      procedure   AddVoltageSample(ATime, AValue: Double);
      procedure   AppendCycleStats(AMean, AStd: Double);
      procedure   AppendPulseDuration(ADuration: Double);
      procedure   Finalise;
      function    FinalResistance: Double;   { last entry in ResistanceAvg, or -1 }
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
    end;

  TProbedJunction = record
      ProbingResult : TProbingResult;
      Coord        : TProberCoord;
  end;
  TProbingResultArray = array of TProbedJunction;

  TNodeType = (ntDevice, ntAddTask, ntAnneal, ntBatchAnneal,
                ntProbe,ntBatchProbe, ntAnnealConfig,
               ntAnnealResult, ntProbeConfig, ntProbeResult,ntAnnealedJunction,
               ntProbedJunction);

  THardwareCommandType = (
    hcInitialize,
    hcAnnealSingle,
    hcProbeSingle,
    hcAnnealBatchCycle,
    hcAnnealBatch,
    hcProbeBatchCycle,
    hcProbeBatch,
    hcShutdown
  );

  THardwareCommand = record
    TaskID : String;
    CommandType: THardwareCommandType;
    AnnealParameters: TAnnealConfig;
    ProbingParameters: TProbingParameters;
    AnnealConfigArray: TAnnealConfigArray;
  end;

  THardwareResult = record
    CommandType: THardwareCommandType;
    AnnealResult: TAnnealResult;
    AnnealedJunctionResult: TAnnealedJunction;
    ProbingResult: TProbingResult;
    ProbedJunctionResult: TProbedJunction;
    AnnealResultArray: TAnnealResultArray;
    ProbingResultArray: TProbingResultArray;
  end;

  function NowSeconds: Double;
  function MeanDoubleArray(const A: TDoubleArray): Double;
  function StdDoubleArray(const A: TDoubleArray): Double;

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

function TSetupStatusManager.SingleProbeAllowed:Boolean;
begin
  Result := SetupStatus[itAnalyzer].OK ;
end;

function TSetupStatusManager.BatchProbeAllowed:Boolean;
begin
    Result := SetupStatus[itAnalyzer].OK  and  SetupStatus[itProber].OK;
end;

function TSetupStatusManager.SingleAnnealAllowed:Boolean;
begin
     Result := SetupStatus[itAnalyzer].OK  and  SetupStatus[itHeater].OK;
end;

function TSetupStatusManager.BatchAnnealAllowed:Boolean;
begin
     Result := SetupStatus[itAnalyzer].OK
                and  SetupStatus[itProber].OK
                and  SetupStatus[itHeater].OK;
end;

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


end.
