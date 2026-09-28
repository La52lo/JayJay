unit JunctionTask;
{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

{
  jj_anneal.pas
  =============
  OOP library for voltage annealing of Josephson junctions
  using a Keysight B1500A parameter analyzer.

  Assumed external units (drivers supplied separately):
    KeysightB1500   - driver unit exposing TB1500, TSMU
    VisaWrapper     - unit exposing TVisaInstrument with Write/methods

  Classes
  -------
    TAnnealSetup        Top-level wrapper owning all three instruments.
                        Call Initialise to connect and check all instruments.
    TB1500Controller    Manages the B1500A connection and SMU operations.
    TJosephsonJunction  Per-junction parameters and anneal / measure methods.
    THeatingStage       VISA-controlled heating stage.
    TProberController   Apollowave wafer prober via command-line executables.
    TAnnealBatch        Anneals a collection of junctions with prober automation.
    TProbeBatch         Probes resistance of a sequence of junctions.

  Data records
  ------------
    TAnnealResult       Time-series data from one anneal run.
    TProberCoord        Prober position (x, y, subsite string).
    TJunctionSpec       Per-junction configuration for a batch anneal run.
    TBatchResult        Outcome record for one junction in a batch.
    TProbeMeasurement   Resistance reading for one junction in a probe run.
}



interface

uses
  SysUtils, Classes, Math, StrUtils,
  B1500Mainframe,   { B1500 Parameter Analyzer driver }
  B1500Constants,   { B1500 Parameter Analyzer driver }
  HeatingStage,     { Heating Stage driver unit }
  Prober,           { Prober driver unit }
  b1511b,           { B1500 SMU }
  MeasurementObserver; {class to receive measurement points}

const
  DEFAULT_ANALYZER_ADDRESS = 'GPIB0::16::INSTR';
  DEFAULT_HEATER_ADDRESS   = 'GPIB0::7::INSTR';
  DEFAULT_PROBER_DIR       =
    'C:\Users\B1500\Documents\voltage_annealing\apollowave';
  DEFAULT_COMPLIANCE       = 0.05;   { 50 mA }
type

// ---------------------------------------------------------------------------
// TAnnealResult
// ---------------------------------------------------------------------------

  { Dynamic arrays used for time-series data.
    TSamplePoint holds a (time, value) pair. }
  TSamplePoint = record
    Time  : Double;   { seconds since t0 }
    Value : Double;   { resistance (Ohm) or voltage (V) }
  end;

  TSampleArray  = array of TSamplePoint;
  TDoubleArray  = array of Double;

  TAnnealResult = class
  public
    ResistanceSamples  : TSampleArray;   { all individual R readings }
    ResistanceAvg      : TDoubleArray;   { mean R after each cycle   }
    ResistanceStd      : TDoubleArray;   { std  R after each cycle   }
    VoltageSamples     : TSampleArray;   { all voltage log points    }
    PulseDurations     : TDoubleArray;   { wall-clock time per pulse }
    TargetResistance   : Double;         { 0.0 means no target set   }
    PulseDurationMean  : Double;
    PulseDurationStd   : Double;

    constructor Create;
    procedure   AddResistanceSample(ATime, AValue: Double);
    procedure   AddVoltageSample(ATime, AValue: Double);
    procedure   AppendCycleStats(AMean, AStd: Double);
    procedure   AppendPulseDuration(ADuration: Double);
    procedure   Finalise;
    function    FinalResistance: Double;   { last entry in ResistanceAvg, or -1 }
  end;

// ---------------------------------------------------------------------------
// TB1500Controller
// ---------------------------------------------------------------------------

  TB1500Controller = class
  private
    FAddress    : string;
    FCompliance : Double;
    FB1500      : TB1500;          { from KeysightB1500 unit }
    FConnected  : Boolean;
    procedure RequireConnection;
    function  GetSMU(ASmu: Integer): TB1511B;
  public
    constructor Create(const AAddress: string = DEFAULT_ANALYZER_ADDRESS;
                       ACompliance: Double = DEFAULT_COMPLIANCE);
    destructor  Destroy; override;

    { Connection }
    procedure Connect;
    procedure SelfCalibrate;
    procedure Disconnect;

    { Output control }
    procedure EnableOutputs;
    procedure DisableOutputs;

    { Voltage }
    procedure SetVoltage(ASmu: Integer; V: Double);
    function  CheckVoltage(ASmu: Integer; VExpected: Double;
                           Tolerance: Double = 0.1): Double;
    function  SetAndCheckVoltage(ASmu: Integer; V: Double;
                                 SettleTime: Double = 0.1): Double;

    { Measurement }
    function MeasureCurrent(ASmu: Integer): Double;
    function MeasureVoltageReadback(ASmu: Integer): Double;
    function MeasureResistance(VSource: Double): Double;

    property Address    : string  read FAddress;
    property Compliance : Double  read FCompliance write FCompliance;
    property Connected  : Boolean read FConnected;
  end;

// ---------------------------------------------------------------------------
// TJosephsonJunction
// ---------------------------------------------------------------------------

  TJosephsonJunction = class
  private
    FInstrument : TB1500Controller;
    FLabel      : string;
    FResult     : TAnnealResult;
    FObserver   : IMeasurementObserver;

    procedure SendZeroVoltage(AResult: TAnnealResult;
                              ADuration, AT0: Double);
    procedure MeasurePulse(AResult: TAnnealResult; AT0: Double);
    procedure AnnealPulse(AResult: TAnnealResult;
                          VPulse, AT0: Double);
    function  IsDamaged(R: Double): Boolean;

  public
    { Measurement parameters }
    VMeasure          : Double;    { V,  default 0.01   }
    MeasurePulseTime  : Double;    { s,  default 0.1    }
    NSamplesMeasure   : Integer;   {     default 5      }

    { Annealing pulse parameters }
    VPulsePos         : Double;    { V,  default +0.6   }
    VPulseNeg         : Double;    { V,  default -0.6   }
    AnnealPulseLength : Double;    { s,  default 2.0    }
    NSamplesAnneal    : Integer;   {     default 10     }

    { Run control }
    NPulsePairs       : Integer;   {     default 1      }
    NCycles           : Integer;   {     default 500    }
    InitialWait       : Double;    { s,  default 1.0    }

    { Safety thresholds }
    ThresholdOpen     : Double;    { Ohm, default 15000 }
    ThresholdShort    : Double;    { Ohm, default 1000  }

    constructor Create(AInstrument: TB1500Controller;
                                    AObserver:IMeasurementObserver;
                       const ALabel: string = 'JJ');
    destructor  Destroy; override;

    { Precise multi-voltage resistance measurement.
      AVoltages may be nil — defaults to [-0.01, -0.005, 0.005, 0.01].
      Returns mean and std in AMeanR / AStdR. }
    procedure MeasureResistance(AVoltages: TDoubleArray;
                                NRepeats: Integer;
                                out AMeanR, AStdR: Double;
                                AAllReadings: TDoubleArray);

    { Main annealing routine.
      Pass ATargetResistance = 0.0 no target.
      Returns a TAnnealResult (caller owns the object). }
    function Anneal(ATargetResistance: Double): TAnnealResult;

    { Save ResistanceAvg / ResistanceStd from FResult to a CSV file. }
    procedure SaveResults(const APath: string;
                          AResult: TAnnealResult = nil);

    property Instrument : TB1500Controller read FInstrument;
    property JJLabel    : string           read FLabel;
    property Result     : TAnnealResult    read FResult;
  end;



// ---------------------------------------------------------------------------
// TJunctionSpec
// ---------------------------------------------------------------------------

  TJunctionSpec = record
    Label_            : string;
    TargetResistance  : Double;
    VPulsePos         : Double;
    VPulseNeg         : Double;
    AnnealPulseLength : Double;
    NPulsePairs       : Integer;
    NCycles           : Integer;

    procedure FromCSV(const S: string);
  end;

  TJunctionSpecArray = array of TJunctionSpec;



// ---------------------------------------------------------------------------
// TBatchResult
// ---------------------------------------------------------------------------

  TBatchResult = class
  public
    JJLabel      : string;
    Coord        : TProberCoord;
    Success      : Boolean;
    AnnealResult : TAnnealResult;   { may be nil if failed before any data }
    ErrorMsg     : string;

    constructor Create(const ALabel: string;
                       ACoord: TProberCoord;
                       ASuccess: Boolean;
                       AResult: TAnnealResult;
                       const AError: string);
    destructor  Destroy; override;
    function    FinalResistance: Double;
  end;

  TBatchResultArray = array of TBatchResult;

// ---------------------------------------------------------------------------
// TAnnealBatch
// ---------------------------------------------------------------------------

  TAnnealBatch = class
  private
    FInstrument : TB1500Controller;
    FProber     : TProberController;
    FSpecs      : TJunctionSpecArray;
    FOutputDir  : string;
    FResults    : TBatchResultArray;

    function  AnnealOne(const ASpec: TJunctionSpec;
                        ACoord: TProberCoord): TBatchResult;
    function  BuildJunction(const ASpec: TJunctionSpec): TJosephsonJunction;
  public
    constructor Create(AInstrument: TB1500Controller;
                       AProber: TProberController;
                       ASpecs: TJunctionSpecArray;
                       const AOutputDir: string = 'batch_results');
    destructor  Destroy; override;

    function Run: TBatchResultArray;
    procedure PrintSummary;

    property Results : TBatchResultArray read FResults;
  end;

// ---------------------------------------------------------------------------
// TProbeMeasurement
// ---------------------------------------------------------------------------

  TProbeMeasurement = class
  public
    Coord           : TProberCoord;
    MeanResistance  : Double;
    StdResistance   : Double;
    Success         : Boolean;
    ErrorMsg        : string;

    constructor Create(ACoord: TProberCoord;
                       AMean, AStd: Double;
                       ASuccess: Boolean;
                       const AError: string);
    function ToString: string; override;
  end;

  TProbeMeasurementArray = array of TProbeMeasurement;

// ---------------------------------------------------------------------------
// TProbeBatch
// ---------------------------------------------------------------------------

  TProbeBatch = class
  private
    FInstrument   : TB1500Controller;
    FProber       : TProberController;
    FNJunctions   : Integer;
    FVoltages     : TDoubleArray;
    FNRepeats     : Integer;
    FOutputPath   : string;
    FMeasurements : TProbeMeasurementArray;

    function MeasureOne(AJJ: TJosephsonJunction;
                        ACoord: TProberCoord): TProbeMeasurement;
  public
    constructor Create(AInstrument: TB1500Controller;
                       AProber: TProberController;
                       ANJunctions: Integer;
                       AVoltages: TDoubleArray = nil;
                       ANRepeats: Integer = 5;
                       const AOutputPath: string = '');
    destructor  Destroy; override;

    function  Run: TProbeMeasurementArray;
    procedure PrintSummary;
    procedure SaveResults(const APath: string = '');

    property Measurements : TProbeMeasurementArray read FMeasurements;
  end;

// ---------------------------------------------------------------------------
// TAnnealSetup
// ---------------------------------------------------------------------------

  { Status record for one instrument during Initialise. }
  TInstrumentStatus = record
    Label_   : string;
    Address  : string;
    Folder   : string;        { only for prober}
    OK       : Boolean;       { True = connected, False = failed }
    Skipped  : Boolean;       { True = not configured (nil address) }
    Message  : string;
  end;

  TAnnealSetup = class
  private
    FAnalyzerAddress  : string;
    FHeaterAddress    : string;
    FProberExeDir     : string;
    FCompliance       : Double;
    FRunSelfCal       : Boolean;

    procedure PrintStatus(const AStatuses: array of TInstrumentStatus);
    procedure CheckProberExecutables;

  public
    Analyzer : TB1500Controller;
    Heater   : THeatingStage;
    Prober   : TProberController;
    Observer : IMeasurementObserver;

    constructor Create(const AAnalyzerAddress : string = DEFAULT_ANALYZER_ADDRESS;
                       const AHeaterAddress   : string = DEFAULT_HEATER_ADDRESS;
                       const AProberExeDir    : string = DEFAULT_PROBER_DIR;
                       AObserver              : IMeasurementObserver;
                       ACompliance            : Double  = DEFAULT_COMPLIANCE;
                       ARunSelfCal            : Boolean = True);
    destructor Destroy; override;

    { Connect to all configured instruments. Returns True if all succeeded. }
    function Initialise: Boolean;

    { Factory helpers — raise EInvalidOp if required instrument is not ready. }
    function Junction(const ALabel: string = 'JJ'): TJosephsonJunction;
    function AnnealBatch(ASpecs: TJunctionSpecArray;
                         const AOutputDir: string = 'batch_results'): TAnnealBatch;
    function ProbeBatch(ANJunctions: Integer;
                        AVoltages: TDoubleArray = nil;
                        ANRepeats: Integer = 5;
                        const AOutputPath: string = ''): TProbeBatch;

    procedure DisconnectAll;
  end;
  { Helper to create a TJunctionSpec with defaults. }
function MakeJunctionSpec(const ALabel: string;
                          ATarget: Double = 0.0;
                          AVPulsePos: Double = 0.6;
                          AVPulseNeg: Double = -0.6;
                          APulseLen: Double = 2.0;
                          ANPairs: Integer = 1;
                          ANCycles: Integer = 500): TJunctionSpec;

// ===========================================================================
// IMPLEMENTATION
// ===========================================================================

implementation

uses
  DateUtils, RegExpr;

// ---------------------------------------------------------------------------
// Utility helpers
// ---------------------------------------------------------------------------

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
// TAnnealResult
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// TB1500Controller
// ---------------------------------------------------------------------------

constructor TB1500Controller.Create(const AAddress: string;
                                    ACompliance: Double);
begin
  inherited Create;
  FAddress    := AAddress;
  FCompliance := ACompliance;
  FB1500      := nil;
  FConnected  := False;
end;

destructor TB1500Controller.Destroy;
begin
  Disconnect;
  inherited;
end;

procedure TB1500Controller.RequireConnection;
begin
  if not FConnected then
    raise EInvalidOp.Create(
      'B1500 not connected. Call TB1500Controller.Connect first.');
end;

function TB1500Controller.GetSMU(ASmu: Integer): TB1511B;
begin
  case ASmu of
    1: Result := FB1500.SMU1;
    2: Result := FB1500.SMU2;
    else raise EArgumentOutOfRangeException.CreateFmt(
           'SMU must be 1 or 2, got %d.', [ASmu]);
  end;
end;

procedure TB1500Controller.Connect;
begin
  FB1500 := TB1500.Create(FAddress);   { driver constructor }
  {FB1500.Open;}
  FConnected := True;
  {WriteLn('Connected to B1500A at ' + FAddress);}
end;

procedure TB1500Controller.SelfCalibrate;
begin
  RequireConnection;
  {WriteLn('Starting self-calibration (may take up to 30 s) ...'); }
  try
    FB1500.SelfCalibration;
    {WriteLn('Self-calibration completed successfully.');}
  except
    on E: Exception do
      {WriteLn('Self-calibration failed: ' + E.Message);}
  end;
end;

procedure TB1500Controller.Disconnect;
begin
  DisableOutputs;
  if FConnected and Assigned(FB1500) then
  begin
    {FB1500.Close; }
    FreeAndNil(FB1500);
    FConnected := False;
    {WriteLn('B1500A disconnected.'); }
  end;
end;

procedure TB1500Controller.EnableOutputs;
begin
  RequireConnection;
  FB1500.SMU1.EnableOutputs;
  FB1500.SMU2.EnableOutputs;
end;

procedure TB1500Controller.DisableOutputs;
begin
  if not FConnected then Exit;
  try
    FB1500.SMU1.DisableOutputs;
    FB1500.SMU2.DisableOutputs;
  except
    { silently ignore — safe even if already disconnected }
  end;
end;

procedure TB1500Controller.SetVoltage(ASmu: Integer; V: Double);
var SMU: TB1511B;
begin
  RequireConnection;
  SMU := GetSMU(ASmu);
  SMU.EnableOutputs;
  SMU.SourceConfig(TVOutputRange.vorAuto, FCompliance);
  SMU.SetVoltage(V);
end;

function TB1500Controller.CheckVoltage(ASmu: Integer; VExpected: Double;
                                       Tolerance: Double): Double;
var
  SMU    : TB1511B;
  VMeas  : Double;
begin
  RequireConnection;
  SMU := GetSMU(ASmu);
  SMU.VMeasRangeConfig(vmrFix2V);
  SMU.EnableOutputs;
  VMeas := SMU.GetVoltage;
  if (VExpected <> 0.0) and
     (Abs((VExpected - VMeas) / VExpected) > Tolerance) then
    raise EInvalidOp.CreateFmt(
      'SMU%d: measured %.4f V deviates more than %.0f%% from expected %.4f V.',
      [ASmu, VMeas, Tolerance * 100, VExpected]);
  Result := VMeas;
end;

function TB1500Controller.SetAndCheckVoltage(ASmu: Integer; V: Double;
                                              SettleTime: Double): Double;
begin
  SetVoltage(ASmu, V);
  SleepSeconds(SettleTime);
  Result := CheckVoltage(ASmu, V);
end;

function TB1500Controller.MeasureCurrent(ASmu: Integer): Double;
var SMU: TB1511B;
begin
  RequireConnection;
  SMU := GetSMU(ASmu);
  SMU.IMeasRangeConfig(imrAuto);
  SMU.EnableOutputs;
  Result := SMU.GetCurrent;
end;

function TB1500Controller.MeasureVoltageReadback(ASmu: Integer): Double;
var SMU: TB1511B;
begin
  RequireConnection;
  SMU := GetSMU(ASmu);
  SMU.VMeasRangeConfig(vmrFix2V);
  SMU.EnableOutputs;
  Result := SMU.GetVoltage;
end;

function TB1500Controller.MeasureResistance(VSource: Double): Double;
var
  V1, V0, I: Double;
begin
  V1 := CheckVoltage(1, VSource);
  V0 := MeasureVoltageReadback(2);
  I  := MeasureCurrent(1);
  Result := Abs((V1 - V0) / I);
end;

// ---------------------------------------------------------------------------
// TJosephsonJunction
// ---------------------------------------------------------------------------

constructor TJosephsonJunction.Create(AInstrument: TB1500Controller;
                                              AObserver:IMeasurementObserver;
                                      const ALabel: string);
begin
  inherited Create;
  FInstrument := AInstrument;
  FLabel      := ALabel;
  FResult     := nil;
  FObserver   := AObserver;

  VMeasure          := 0.01;
  MeasurePulseTime  := 0.1;
  NSamplesMeasure   := 5;
  VPulsePos         := 0.6;
  VPulseNeg         := -0.6;
  AnnealPulseLength := 2.0;
  NSamplesAnneal    := 10;
  NPulsePairs       := 1;
  NCycles           := 500;
  InitialWait       := 1.0;
  ThresholdOpen     := 15000.0;
  ThresholdShort    := 1000.0;
end;

destructor TJosephsonJunction.Destroy;
begin
  FResult.Free;
  inherited;
end;

function TJosephsonJunction.IsDamaged(R: Double): Boolean;
begin
  Result := (R > ThresholdOpen) or (R < ThresholdShort);
end;

procedure TJosephsonJunction.SendZeroVoltage(AResult: TAnnealResult;
                                             ADuration, AT0: Double);
var
  N, i : Integer;
  dt   : Double;
  VRead: Double;
begin
  N  := NSamplesMeasure;
  dt := ADuration / (N + 1);
  FInstrument.SetVoltage(1, 0.0);
  FInstrument.SetVoltage(2, 0.0);
  for i := 1 to N do
  begin
    SleepSeconds(dt);
    VRead := FInstrument.MeasureVoltageReadback(1);
    AResult.AddVoltageSample(NowSeconds - AT0, VRead);
  end;
  SleepSeconds(dt);
end;

procedure TJosephsonJunction.AnnealPulse(AResult: TAnnealResult;
                                         VPulse, AT0: Double);
var
  N, i : Integer;
  dt   : Double;
  VRead: Double;
begin
  N  := NSamplesAnneal;
  dt := AnnealPulseLength / (N + 1);
  FInstrument.SetVoltage(1, VPulse);
  for i := 1 to N do
  begin
    FInstrument.SetVoltage(2, 0.0);
    SleepSeconds(dt);
    VRead := FInstrument.CheckVoltage(1, VPulse);
    AResult.AddVoltageSample(NowSeconds - AT0, VRead);
  end;
  SleepSeconds(dt);
end;

procedure TJosephsonJunction.MeasurePulse(AResult: TAnnealResult;
                                          AT0: Double);
var
  N, i    : Integer;
  dt, R   : Double;
  VRead   : Double;
  Readings: TDoubleArray;
begin
  N  := NSamplesMeasure;
  dt := MeasurePulseTime / (N + 1);
  SetLength(Readings, N);

  FInstrument.SetVoltage(1, VMeasure);
  for i := 0 to N - 1 do
  begin
    FInstrument.SetVoltage(2, 0.0);
    SleepSeconds(dt);
    VRead := FInstrument.CheckVoltage(1, VMeasure);
    AResult.AddVoltageSample(NowSeconds - AT0, VRead);
    R := FInstrument.MeasureResistance(VMeasure);
    Readings[i] := R;
    AResult.AddResistanceSample(NowSeconds - AT0, R);
  end;

  AResult.AppendCycleStats(MeanDoubleArray(Readings),
                            StdDoubleArray(Readings));
  SleepSeconds(dt);
end;

procedure TJosephsonJunction.MeasureResistance(AVoltages: TDoubleArray;
                                               NRepeats: Integer;
                                               out AMeanR, AStdR: Double;
                                               AAllReadings: TDoubleArray);
var
  DefaultVoltages : TDoubleArray;
  Voltages        : TDoubleArray;
  Count, i, j     : Integer;
  V, R            : Double;
begin
  if AVoltages = nil then
  begin
    SetLength(DefaultVoltages, 4);
    DefaultVoltages[0] := -0.01;
    DefaultVoltages[1] := -0.005;
    DefaultVoltages[2] :=  0.005;
    DefaultVoltages[3] :=  0.01;
    Voltages := DefaultVoltages;
  end
  else
    Voltages := AVoltages;

  Count := Length(Voltages) * NRepeats;
  SetLength(AAllReadings, Count);
  i := 0;

  for V in Voltages do
  begin
    FInstrument.SetAndCheckVoltage(1, V, 0.1);
    for j := 1 to NRepeats do
    begin
      SleepSeconds(0.1);
      AAllReadings[i] := FInstrument.MeasureResistance(V);
      Inc(i);
    end;
    FInstrument.DisableOutputs;
  end;

  AMeanR := MeanDoubleArray(AAllReadings);
  AStdR  := StdDoubleArray(AAllReadings);
  WriteLn(Format('[%s] Resistance: %.1f +/- %.1f Ohm',
                 [FLabel, AMeanR, AStdR]));
end;

function TJosephsonJunction.Anneal(ATargetResistance: Double): TAnnealResult;
var
  Res         : TAnnealResult;
  T0          : Double;
  CurrentR    : Double;
  Cycle, Pair : Integer;
  TotalPairs  : Integer;
  Stop        : Boolean;
  TStart      : Double;
begin
  Res := TAnnealResult.Create;
  Res.TargetResistance := ATargetResistance;
  T0 := NowSeconds;

  SendZeroVoltage(Res, InitialWait, T0);
  MeasurePulse(Res, T0);

  { If initial R already exceeds target, skip the anneal loop }
  if (Res.FinalResistance >= ATargetResistance) then
  begin
    WriteLn(Format('[%s] Initial R (%.1f Ohm) already exceeds target ' +
                   '(%.1f Ohm). Skipping anneal.',
                   [FLabel, Res.FinalResistance, ATargetResistance]));
    Res.Finalise;
    FResult := Res;
    Result  := Res;
    Exit;
  end;

  TotalPairs := 0;
  Stop       := False;

  for Cycle := 0 to NCycles - 1 do
  begin
    { Inner loop: NPulsePairs pairs per cycle }
    for Pair := 0 to NPulsePairs - 1 do
    begin
      { Positive pulse }
      try
        TStart := NowSeconds;
        AnnealPulse(Res, VPulsePos, T0);
        Res.AppendPulseDuration(NowSeconds - TStart);
      except
        on E: Exception do
        begin
          FObserver.ErrorHappened(Format('[%s] Could not send positive pulse ' +
                         '(cycle %d, pair %d): %s. Stopping.',
                         [FLabel, Cycle, Pair, E.Message]));
          Stop := True;
          Break;
        end;
      end;

      { Negative pulse }
      try
        TStart := NowSeconds;
        AnnealPulse(Res, VPulseNeg, T0);
        Res.AppendPulseDuration(NowSeconds - TStart);
      except
        on E: Exception do
        begin
          FObserver.ErrorHappened(Format('[%s] Could not send negative pulse ' +
                         '(cycle %d, pair %d): %s. Stopping.',
                         [FLabel, Cycle, Pair, E.Message]));
          Stop := True;
          Break;
        end;
      end;

      Inc(TotalPairs);
    end;  { pair loop }

    if Stop then Break;

    { Resistance measurement after all pairs in this cycle }
    MeasurePulse(Res, T0);
    CurrentR := Res.FinalResistance;

    WriteLn(Format('[%s] Cycle %d/%d  R = %.1f Ohm',
                   [FLabel, Cycle + 1, NCycles, CurrentR]));

    { Early stop: target reached }
    if (CurrentR >= ATargetResistance) then
    begin
      WriteLn(Format('[%s] Target reached after %d cycles (%d pairs). ' +
                     'R = %.1f Ohm',
                     [FLabel, Cycle + 1, TotalPairs, CurrentR]));

       FObserver.NewPoint(0,NowSeconds(),CurrentR);

      Break;
    end;

    { Early stop: junction damaged }
    if IsDamaged(CurrentR) then
    begin
      FObserver.ErrorHappened(Format('[%s] Junction appears damaged (R = %.1f Ohm). Stopping.',
                     [FLabel, CurrentR]));
      Break;
    end;
  end;  { cycle loop }

  FInstrument.DisableOutputs;
  Res.Finalise;
  FObserver.NewPoint(0,NowSeconds(),CurrentR);
  { Free previous result if any, store new one }
  FreeAndNil(FResult);
  FResult := Res;
  Result  := Res;

  {WriteLn(Format('[%s] Anneal complete. %d pulse pairs across %d cycles. ' +
                 'Final R = %.1f Ohm',
                 [FLabel, TotalPairs,
                  Length(Res.ResistanceAvg) - 1,
                  Res.FinalResistance]));   }
end;

procedure TJosephsonJunction.SaveResults(const APath: string;
                                         AResult: TAnnealResult);
var
  R   : TAnnealResult;
  F   : TextFile;
  i   : Integer;
  Dir : string;
begin
  if AResult <> nil then R := AResult
  else                    R := FResult;

  if R = nil then
    raise EInvalidOp.Create('No results to save. Run Anneal first.');

  Dir := ExtractFileDir(APath);
  if (Dir <> '') and not DirectoryExists(Dir) then
    ForceDirectories(Dir);

  AssignFile(F, APath);
  Rewrite(F);
  try
    WriteLn(F, 'pulse_index,resistance_mean_ohm,resistance_std_ohm');
    for i := 0 to High(R.ResistanceAvg) do
      WriteLn(F, Format('%d,%.6f,%.6f',
                        [i, R.ResistanceAvg[i], R.ResistanceStd[i]]));
  finally
    CloseFile(F);
  end;
  WriteLn(Format('[%s] Results saved to %s', [FLabel, APath]));
end;


// ---------------------------------------------------------------------------
// MakeJunctionSpec
// ---------------------------------------------------------------------------

function MakeJunctionSpec(const ALabel: string;
                          ATarget: Double;
                          AVPulsePos, AVPulseNeg, APulseLen: Double;
                          ANPairs, ANCycles: Integer): TJunctionSpec;
begin
  Result.Label_            := ALabel;
  Result.TargetResistance  := ATarget;
  Result.VPulsePos         := AVPulsePos;
  Result.VPulseNeg         := AVPulseNeg;
  Result.AnnealPulseLength := APulseLen;
  Result.NPulsePairs       := ANPairs;
  Result.NCycles           := ANCycles;
end;

procedure TJunctionSpec.FromCSV(const S: string);
var
  Fields: array of string;
begin
  Fields := SplitString(S, ',');

  if Length(Fields) <> 8 then
    raise Exception.CreateFmt(
      'Expected 8 fields, got %d.', [Length(Fields)]);

  Label_             := Trim(Fields[1]);
  TargetResistance   := StrToFloat(Trim(Fields[2]));
  VPulsePos          := StrToFloat(Trim(Fields[5]));
  VPulseNeg          := StrToFloat(Trim(Fields[4]));
  AnnealPulseLength  := StrToFloat(Trim(Fields[6]));
  NPulsePairs        := StrToInt(Trim(Fields[7]));
  NCycles            := StrToInt(Trim(Fields[8]));

end;

// ---------------------------------------------------------------------------
// TBatchResult
// ---------------------------------------------------------------------------

constructor TBatchResult.Create(const ALabel: string;
                                ACoord: TProberCoord;
                                ASuccess: Boolean;
                                AResult: TAnnealResult;
                                const AError: string);
begin
  inherited Create;
  JJLabel      := ALabel;
  Coord        := ACoord;
  Success      := ASuccess;
  AnnealResult := AResult;
  ErrorMsg     := AError;
end;

destructor TBatchResult.Destroy;
begin
  AnnealResult.Free;
  inherited;
end;

function TBatchResult.FinalResistance: Double;
begin
  if Assigned(AnnealResult) then
    Result := AnnealResult.FinalResistance
  else
    Result := -1.0;
end;

// ---------------------------------------------------------------------------
// TAnnealBatch
// ---------------------------------------------------------------------------

constructor TAnnealBatch.Create(AInstrument: TB1500Controller;
                                AProber: TProberController;
                                ASpecs: TJunctionSpecArray;
                                const AOutputDir: string);
begin
  inherited Create;
  FInstrument := AInstrument;
  FProber     := AProber;
  FSpecs      := ASpecs;
  FOutputDir  := AOutputDir;
  SetLength(FResults, 0);
end;

destructor TAnnealBatch.Destroy;
var i: Integer;
begin
  for i := 0 to High(FResults) do FResults[i].Free;
  inherited;
end;

function TAnnealBatch.BuildJunction(const ASpec: TJunctionSpec): TJosephsonJunction;
begin
  Result := TJosephsonJunction.Create(FInstrument, ASpec.Label_);
  Result.VPulsePos         := ASpec.VPulsePos;
  Result.VPulseNeg         := ASpec.VPulseNeg;
  Result.AnnealPulseLength := ASpec.AnnealPulseLength;
  Result.NPulsePairs       := ASpec.NPulsePairs;
  Result.NCycles           := ASpec.NCycles;
end;

function TAnnealBatch.AnnealOne(const ASpec: TJunctionSpec;
                                ACoord: TProberCoord): TBatchResult;
var
  JJ  : TJosephsonJunction;
  Res : TAnnealResult;
begin
  JJ := BuildJunction(ASpec);
  try
    Res := JJ.Anneal(ASpec.TargetResistance);
    Result := TBatchResult.Create(ASpec.Label_, ACoord, True, Res, '');
    { Res is now owned by TBatchResult; detach from JJ to avoid double-free }
    JJ.FResult := nil;
  except
    on E: Exception do
    begin
      FObserver.ErrorHappened(Format('[AnnealBatch] %s failed: %s', [ASpec.Label_, E.Message]));
      Result := TBatchResult.Create(ASpec.Label_, ACoord, False,
                                    JJ.FResult, E.Message);
      JJ.FResult := nil;
    end;
  end;
  JJ.Free;
end;

function TAnnealBatch.Run: TBatchResultArray;
var
  Coord  : TProberCoord;
  i      : Integer;
  BR     : TBatchResult;
  CsvPath: string;
  JJ     : TJosephsonJunction;
begin
  SetLength(FResults, 0);
  if not DirectoryExists(FOutputDir) then
    ForceDirectories(FOutputDir);

  Coord := FProber.Start;
  {WriteLn(Format('[AnnealBatch] Prober started at %s', [Coord.ToString]));
  WriteLn(Format('[AnnealBatch] %d junctions to process.', [Length(FSpecs)]));}

  for i := 0 to High(FSpecs) do
  begin
    {WriteLn(Format('--- [%d/%d] %s  coord=%s ---',
                   [i + 1, Length(FSpecs),
                    FSpecs[i].Label_, Coord.ToString])); }

    BR := AnnealOne(FSpecs[i], Coord);
    SetLength(FResults, Length(FResults) + 1);
    FResults[High(FResults)] := BR;

    { Save per-junction CSV if data exists }
    if Assigned(BR.AnnealResult) then
    begin
      CsvPath := IncludeTrailingPathDelimiter(FOutputDir) +
                 FSpecs[i].Label_ + '.csv';
      JJ := TJosephsonJunction.Create(FInstrument, FSpecs[i].Label_);
      try
        JJ.SaveResults(CsvPath, BR.AnnealResult);
      finally
        JJ.Free;
      end;
    end;

    { Advance prober (skip on last junction) }
    if i < High(FSpecs) then
    try
      Coord := FProber.NextSubsite;
      WriteLn(Format('[AnnealBatch] Prober moved to %s', [Coord.ToString]));
    except
      on E: Exception do
      begin
        WriteLn('[AnnealBatch] Prober move failed: ' + E.Message +
                '. Stopping batch.');
        Break;
      end;
    end;
  end;

  FProber.Finish;
  WriteLn('[AnnealBatch] Batch complete.');
  PrintSummary;
  Result := FResults;
end;

procedure TAnnealBatch.PrintSummary;
var
  i   : Integer;
  BR  : TBatchResult;
  RStr: string;
begin
  WriteLn('');
  WriteLn(StringOfChar('=', 60));
  WriteLn(Format('  Batch summary  (%d junctions)', [Length(FResults)]));
  WriteLn(StringOfChar('=', 60));
  WriteLn(Format('  %-14s %-16s %14s  Status',
                 ['Label', 'Coord', 'Final R (Ohm)']));
  WriteLn(StringOfChar('-', 60));
  for i := 0 to High(FResults) do
  begin
    BR := FResults[i];
    if BR.FinalResistance >= 0 then
      RStr := Format('%.1f', [BR.FinalResistance])
    else
      RStr := '-';
    if BR.Success then
      WriteLn(Format('  %-14s %-16s %14s  OK',
                     [BR.JJLabel, BR.Coord.ToString, RStr]))
    else
      WriteLn(Format('  %-14s %-16s %14s  FAILED: %s',
                     [BR.JJLabel, BR.Coord.ToString, RStr, BR.ErrorMsg]));
  end;
  WriteLn(StringOfChar('=', 60));
end;

// ---------------------------------------------------------------------------
// TProbeMeasurement
// ---------------------------------------------------------------------------

constructor TProbeMeasurement.Create(ACoord: TProberCoord;
                                     AMean, AStd: Double;
                                     ASuccess: Boolean;
                                     const AError: string);
begin
  inherited Create;
  Coord          := ACoord;
  MeanResistance := AMean;
  StdResistance  := AStd;
  Success        := ASuccess;
  ErrorMsg       := AError;
end;

function TProbeMeasurement.ToString: string;
begin
  if Success then
    Result := Format('%s  R = %.1f +/- %.1f Ohm',
                     [Coord.ToString, MeanResistance, StdResistance])
  else
    Result := Format('%s  FAILED: %s', [Coord.ToString, ErrorMsg]);
end;

// ---------------------------------------------------------------------------
// TProbeBatch
// ---------------------------------------------------------------------------

constructor TProbeBatch.Create(AInstrument: TB1500Controller;
                               AProber: TProberController;
                               ANJunctions: Integer;
                               AVoltages: TDoubleArray;
                               ANRepeats: Integer;
                               const AOutputPath: string);
begin
  inherited Create;
  FInstrument := AInstrument;
  FProber     := AProber;
  FNJunctions := ANJunctions;
  FNRepeats   := ANRepeats;
  FOutputPath := AOutputPath;

  if AVoltages = nil then
  begin
    SetLength(FVoltages, 4);
    FVoltages[0] := -0.01;
    FVoltages[1] := -0.005;
    FVoltages[2] :=  0.005;
    FVoltages[3] :=  0.01;
  end
  else
    FVoltages := AVoltages;

  SetLength(FMeasurements, 0);
end;

destructor TProbeBatch.Destroy;
var i: Integer;
begin
  for i := 0 to High(FMeasurements) do FMeasurements[i].Free;
  inherited;
end;

function TProbeBatch.MeasureOne(AJJ: TJosephsonJunction;
                                ACoord: TProberCoord): TProbeMeasurement;
var
  MeanR, StdR: Double;
  AllReadings: TDoubleArray;
begin
  try
    AJJ.MeasureResistance(FVoltages, FNRepeats, MeanR, StdR,AllReadings);
    Result := TProbeMeasurement.Create(ACoord, MeanR, StdR, True, '');
  except
    on E: Exception do
      Result := TProbeMeasurement.Create(ACoord, 0, 0, False, E.Message);
  end;
end;

function TProbeBatch.Run: TProbeMeasurementArray;
var
  Coord : TProberCoord;
  JJ    : TJosephsonJunction;
  i     : Integer;
  M     : TProbeMeasurement;
begin
  SetLength(FMeasurements, 0);

  Coord := FProber.Start;
  WriteLn(Format('[ProbeBatch] Prober started at %s', [Coord.ToString]));
  WriteLn(Format('[ProbeBatch] Measuring %d junctions.', [FNJunctions]));

  JJ := TJosephsonJunction.Create(FInstrument);
  try
    for i := 0 to FNJunctions - 1 do
    begin
      Write(Format('  [%d/%d] %s ... ',
                   [i + 1, FNJunctions, Coord.ToString]));

      M := MeasureOne(JJ, Coord);
      SetLength(FMeasurements, Length(FMeasurements) + 1);
      FMeasurements[High(FMeasurements)] := M;
      WriteLn(M.ToString);

      if i < FNJunctions - 1 then
      try
        Coord := FProber.NextSubsite;
      except
        on E: Exception do
        begin
          WriteLn('[ProbeBatch] Prober move failed: ' + E.Message +
                  '. Stopping.');
          Break;
        end;
      end;
    end;
  finally
    JJ.Free;
  end;

  FProber.Finish;
  WriteLn(Format('[ProbeBatch] Done. %d junctions measured.',
                 [Length(FMeasurements)]));

  if FOutputPath <> '' then SaveResults;
  PrintSummary;
  Result := FMeasurements;
end;

procedure TProbeBatch.PrintSummary;
var
  i           : Integer;
  M           : TProbeMeasurement;
  Successes   : Integer;
  Failures    : Integer;
  MeanVals    : TDoubleArray;
  K           : Integer;
begin
  if Length(FMeasurements) = 0 then
  begin
    WriteLn('No measurements yet. Call Run first.');
    Exit;
  end;

  Successes := 0; Failures := 0;
  SetLength(MeanVals, 0);

  WriteLn('');
  WriteLn(StringOfChar('=', 65));
  WriteLn(Format('  Probe summary  (%d junctions)', [Length(FMeasurements)]));
  WriteLn(StringOfChar('=', 65));
  WriteLn(Format('  %-20s %4s %4s  %14s  %12s',
                 ['Subsite', 'x', 'y', 'R mean (Ohm)', 'R std (Ohm)']));
  WriteLn(StringOfChar('-', 65));

  for i := 0 to High(FMeasurements) do
  begin
    M := FMeasurements[i];
    if M.Success then
    begin
      Inc(Successes);
      K := Length(MeanVals);
      SetLength(MeanVals, K + 1);
      MeanVals[K] := M.MeanResistance;
      WriteLn(Format('  %-20s %4d %4d  %14.1f  %12.1f',
                     [M.Coord.Subsite, M.Coord.Chip_X, M.Coord.Chip_Y,
                      M.MeanResistance, M.StdResistance]))
    end
    else
    begin
      Inc(Failures);
      WriteLn(Format('  %-20s %4d %4d  %14s  %s',
                     [M.Coord.Subsite, M.Coord.Chip_X, M.Coord.Chip_Y,
                      'FAILED', M.ErrorMsg]));
    end;
  end;

  WriteLn(StringOfChar('=', 65));
  WriteLn(Format('  %d succeeded,  %d failed.', [Successes, Failures]));
  if Length(MeanVals) > 0 then
    WriteLn(Format('  R across batch:  mean = %.1f Ohm,  std = %.1f Ohm,' +
                   '  min = %.1f Ohm,  max = %.1f Ohm',
                   [MeanDoubleArray(MeanVals),
                    StdDoubleArray(MeanVals),
                    MinValue(MeanVals),
                    MaxValue(MeanVals)]));
  WriteLn(StringOfChar('=', 65));
end;

procedure TProbeBatch.SaveResults(const APath: string);
var
  Dest : string;
  F    : TextFile;
  i    : Integer;
  M    : TProbeMeasurement;
begin
  if APath <> '' then Dest := APath
  else                Dest := FOutputPath;

  if Dest = '' then
    raise EInvalidOp.Create('No output path specified.');

  AssignFile(F, Dest);
  Rewrite(F);
  try
    WriteLn(F, 'subsite,x,y,resistance_mean_ohm,resistance_std_ohm,' +
               'success,error');
    for i := 0 to High(FMeasurements) do
    begin
      M := FMeasurements[i];
      if M.Success then
        WriteLn(F, Format('%s,%d,%d,%.6f,%.6f,True,',
                          [M.Coord.Subsite, M.Coord.Chip_X, M.Coord.Chip_Y,
                           M.MeanResistance, M.StdResistance]))
      else
        WriteLn(F, Format('%s,%d,%d,,,False,%s',
                          [M.Coord.Subsite, M.Coord.Chip_X, M.Coord.Chip_Y,
                           M.ErrorMsg]));
    end;
  finally
    CloseFile(F);
  end;
  WriteLn('[ProbeBatch] Results saved to ' + Dest);
end;

// ---------------------------------------------------------------------------
// TAnnealSetup
// ---------------------------------------------------------------------------

constructor TAnnealSetup.Create(const AAnalyzerAddress,
                                      AHeaterAddress,
                                      AProberExeDir    : string;
                                      AObserver        : IMeasurementObserver;
                                ACompliance            : Double;
                                ARunSelfCal            : Boolean);
begin
  inherited Create;
  FAnalyzerAddress := AAnalyzerAddress;
  FHeaterAddress   := AHeaterAddress;
  FProberExeDir    := AProberExeDir;
  FCompliance      := ACompliance;
  FRunSelfCal      := ARunSelfCal;
  FObserver        := AObserver;
  Analyzer         := nil;
  Heater           := nil;
  Prober           := nil;
end;

destructor TAnnealSetup.Destroy;
begin
  DisconnectAll;
  inherited;
end;

procedure TAnnealSetup.CheckProberExecutables;
const
  Exes: array[0..2] of string = (
    'Start_apw.exe', 'Subsite_apw.exe', 'Final_apw.exe');
var
  i    : Integer;
  Path : string;
begin
  for i := 0 to High(Exes) do
  begin
    Path := IncludeTrailingPathDelimiter(FProberExeDir) + Exes[i];
    if not FileExists(Path) then
      raise EFileNotFoundException.CreateFmt(
        'Apollowave executable not found: %s', [Path]);
  end;
end;

procedure TAnnealSetup.PrintStatus(
  const AStatuses: array of TInstrumentStatus);
var
  i    : Integer;
  S    : TInstrumentStatus;
  Icon : string;
  AllOK: Boolean;
begin
  AllOK := True;
  WriteLn('');
  WriteLn('  Instrument status');
  WriteLn('  ' + StringOfChar('-', 55));
  for i := 0 to High(AStatuses) do
  begin
    S := AStatuses[i];
    if S.Skipped then
      Icon := '[--]'
    else if S.OK then
      Icon := '[OK]'
    else
    begin
      Icon  := '[!!]';
      AllOK := False;
    end;

    if S.Message <> '' then
      WriteLn(Format('  %s  %-10s  %s  (%s)',
                     [Icon, S.Label_, S.Address, S.Message]))
    else
      WriteLn(Format('  %s  %-10s  %s',
                     [Icon, S.Label_, S.Address]));
  end;
  WriteLn('  ' + StringOfChar('-', 55));
  if AllOK then
    WriteLn('  All instruments ready.')
  else
    WriteLn('  One or more instruments failed to connect.');
  WriteLn('');
end;

function TAnnealSetup.Initialise: Boolean;
var
  Statuses : array[0..2] of TInstrumentStatus;
  AllOK    : Boolean;
  Temp     : Double;
begin
  AllOK := True;

  { --- B1500A Analyzer --- }
  Statuses[0].Label_  := 'B1500A';
  Statuses[0].Address := FAnalyzerAddress;
  Statuses[0].Skipped := False;
  try
    Analyzer := TB1500Controller.Create(FAnalyzerAddress, FCompliance);
    Analyzer.Connect;
    if FRunSelfCal then Analyzer.SelfCalibrate;
    Statuses[0].OK      := True;
    Statuses[0].Message := '';
  except
    on E: Exception do
    begin
      FreeAndNil(Analyzer);
      Statuses[0].OK      := False;
      Statuses[0].Message := E.Message;
      AllOK               := False;
    end;
  end;

  { --- Heating Stage --- }
  Statuses[1].Label_  := 'Heater';
  Statuses[1].Address := FHeaterAddress;
  if FHeaterAddress = '' then
  begin
    Statuses[1].Skipped := True;
    Statuses[1].OK      := True;
    Statuses[1].Message := 'not configured';
  end
  else
  begin
    Statuses[1].Skipped := False;
    try
      Heater := THeatingStage.Create(FHeaterAddress);
      Heater.Connect;
      Temp := Heater.GetTemperature;
      Statuses[1].OK      := True;
      Statuses[1].Message := Format('T: %.1f C', [Temp]);
    except
      on E: Exception do
      begin
        FreeAndNil(Heater);
        Statuses[1].OK      := False;
        Statuses[1].Message := E.Message;
        AllOK               := False;
      end;
    end;
  end;

  { --- Prober --- }
  Statuses[2].Label_  := 'Prober';
  Statuses[2].Address := FProberExeDir;
  if FProberExeDir = '' then
  begin
    Statuses[2].Skipped := True;
    Statuses[2].OK      := True;
    Statuses[2].Message := 'not configured';
  end
  else
  begin
    Statuses[2].Skipped := False;
    try
      Prober := TProberController.Create(FProberExeDir);
      CheckProberExecutables;
      Statuses[2].OK      := True;
      Statuses[2].Message := 'executables found';
    except
      on E: Exception do
      begin
        FreeAndNil(Prober);
        Statuses[2].OK      := False;
        Statuses[2].Message := E.Message;
        AllOK               := False;
      end;
    end;
  end;

  {PrintStatus(Statuses);  }
  Result := AllOK;
end;

function TAnnealSetup.Junction(const ALabel: string): TJosephsonJunction;
begin
  if Analyzer = nil then
    raise EInvalidOp.Create(
      'Analyzer not connected. Call Initialise first.');
  Result := TJosephsonJunction.Create(Analyzer, ALabel);
end;

function TAnnealSetup.AnnealBatch(ASpecs: TJunctionSpecArray;
                                  const AOutputDir: string): TAnnealBatch;
begin
  if Analyzer = nil then
    raise EInvalidOp.Create('Analyzer not connected. Call Initialise first.');
  if Prober = nil then
    raise EInvalidOp.Create('Prober not connected. Call Initialise first.');
  Result := TAnnealBatch.Create(Analyzer, Prober, ASpecs, AOutputDir);
end;

function TAnnealSetup.ProbeBatch(ANJunctions: Integer;
                                 AVoltages: TDoubleArray;
                                 ANRepeats: Integer;
                                 const AOutputPath: string): TProbeBatch;
begin
  if Analyzer = nil then
    raise EInvalidOp.Create('Analyzer not connected. Call Initialise first.');
  if Prober = nil then
    raise EInvalidOp.Create('Prober not connected. Call Initialise first.');
  Result := TProbeBatch.Create(Analyzer, Prober, ANJunctions,
                               AVoltages, ANRepeats, AOutputPath);
end;

procedure TAnnealSetup.DisconnectAll;
begin
  if Assigned(Analyzer) then
  begin
    try Analyzer.Disconnect; except end;
    FreeAndNil(Analyzer);
  end;
  if Assigned(Heater) then
  begin
    try Heater.Disconnect; except end;
    FreeAndNil(Heater);
  end;
  if Assigned(Prober) then
  begin
    try Prober.Disconnect; except end;
    FreeAndNil(Prober);
  end;
end;

end.
