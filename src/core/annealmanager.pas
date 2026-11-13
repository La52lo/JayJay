unit AnnealManager;

interface

uses
  SysUtils, Classes, Math, StrUtils,
  AnnealTypes,
  B1500Mainframe,      { B1500 Parameter Analyzer driver }
  B1500Constants,      { B1500 Parameter Analyzer constants }
  HeatingStage,        { Heating Stage driver unit }
  Prober,              { Prober driver unit }
  b1511b,              { B1500 SMU }
  MeasurementObserver; { interface to receive measurement points }

const
{$IFDEF DEBUG}
  DEFAULT_ANALYZER_ADDRESS = 'GPIB0::16::INSTR';
  DEFAULT_PROBER_DIR       = 'C:\Users\B1500\Documents\voltage_annealing\apollowave';
{$ELSE}
  DEFAULT_ANALYZER_ADDRESS = 'agb1500a';
  DEFAULT_PROBER_DIR       = 'C:\Program Files\Agilent\B1500\EasyEXPERT\Utilities\ProberControl\apollowave';
{$ENDIF}
  DEFAULT_HEATER_ADDRESS   = 'GPIB0::7::INSTR';
  DEFAULT_PROBER_ADDRESS   = 'GPIB0::5::INSTR';


type
  TAnnealManager = class
  private
    FB1500           : TB1500;
    FProber          : TProberController;
    FHeater          : THeatingStage;
    FObserver        : IMeasurementObserver;
    FSetupStatus     : TSetupStatus;
    FAnalyzerAddress : string;
    FHeaterAddress   : string;
    FProberExeDir    : string;
    FProberAddress   : string;
    FCompliance      : Double;
    FRunSelfCal      : Boolean;

    function Anneal(const AParams: TAnnealConfig): TAnnealResult;
    function SweepResistance(AParams: TProbingParameters): TProbingResult;
  public
    constructor Create(
      AObserver              : IMeasurementObserver;
      const AAnalyzerAddress : string = DEFAULT_ANALYZER_ADDRESS;
      const AHeaterAddress   : string = DEFAULT_HEATER_ADDRESS;
      const AProberAddress   : string = DEFAULT_PROBER_ADDRESS;
      const AProberExeDir    : string = DEFAULT_PROBER_DIR;
      ACompliance            : Double = DEFAULT_COMPLIANCE;
      ARunSelfCal            : Boolean = True);

    destructor Destroy; override;

    function Initialize: Boolean;

    procedure AnnealPulse(VPulse, AT: Double);
    procedure AnnealPairs(AVPulseHigh, AVPulseLow, AT: Double; APairs: Integer;
                          ASMU: TB1511B; var Res: TAnnealResult);
    function AnnealSingle(const AParams: TAnnealConfig): TAnnealResult;
    function AnnealBatch(const ASpecs: TAnnealConfigArray;
                         FinalTemperature: Double = 22.0): TAnnealResultArray;
    function ProbeSingle(AParams: TProbingParameters): TProbingResult;
    function ProbeBatch(AParams: TProbingParameters): TProbingResultArray;
    function IsDamaged(R, ThresholdOpen, ThresholdShort: Double): Boolean;
    procedure SetTemperature(Temp: Double);
    procedure SendZeroVoltage;
    procedure DisconnectAll;
  end;

implementation
{
procedure SleepSeconds(ASeconds: Double);
begin
  if ASeconds > 0 then
    Sleep(Round(ASeconds * 1000));
end;
 }
constructor TAnnealManager.Create(
  AObserver              : IMeasurementObserver;
  const AAnalyzerAddress : string = DEFAULT_ANALYZER_ADDRESS;
  const AHeaterAddress   : string = DEFAULT_HEATER_ADDRESS;
  const AProberAddress   : string = DEFAULT_PROBER_ADDRESS;
  const AProberExeDir    : string = DEFAULT_PROBER_DIR;
  ACompliance            : Double = DEFAULT_COMPLIANCE;
  ARunSelfCal            : Boolean = True);
begin
  inherited Create;
  FAnalyzerAddress := AAnalyzerAddress;
  FHeaterAddress   := AHeaterAddress;
  FProberExeDir    := AProberExeDir;
  FProberAddress   := AProberAddress;
  FRunSelfCal      := ARunSelfCal;
  FObserver        := AObserver;
  FCompliance      := ACompliance;
  FB1500           := nil;
  FHeater          := nil;
  FProber          := nil;
end;

destructor TAnnealManager.Destroy;
begin
  DisconnectAll;
  inherited;
end;

function TAnnealManager.Initialize: Boolean;
var
  Temp: Double;
begin
  Result := True;

  { --- B1500A Analyzer --- }
  FSetupStatus[itAnalyzer].Label_  := 'B1500A';
  FSetupStatus[itAnalyzer].Address := FAnalyzerAddress;
  FSetupStatus[itAnalyzer].Skipped := False;
  try
    FB1500 := TB1500.Create(FAnalyzerAddress, FCompliance);
    // if FRunSelfCal then FB1500.SelfCalibration;
    FSetupStatus[itAnalyzer].OK      := True;
    FSetupStatus[itAnalyzer].Message := '';
  except
    on E: Exception do
    begin
      FreeAndNil(FB1500);
      FSetupStatus[itAnalyzer].OK      := False;
      FSetupStatus[itAnalyzer].Message := E.Message;
      Result := False;
      FObserver.Log(E.Message);
    end;
  end;

  { --- Heating Stage --- }
  FSetupStatus[itHeater].Label_  := 'Heater';
  FSetupStatus[itHeater].Address := FHeaterAddress;
  if FHeaterAddress = '' then
  begin
    FSetupStatus[itHeater].Skipped := True;
    FSetupStatus[itHeater].OK      := True;
    FSetupStatus[itHeater].Message := 'not configured';
  end
  else
  begin
    FSetupStatus[itHeater].Skipped := False;
    try
      FHeater := THeatingStage.Create(FHeaterAddress);
      FHeater.Connect;
      Temp := FHeater.GetTemperature;
      FSetupStatus[itHeater].OK      := True;
      FSetupStatus[itHeater].Message := Format('T: %.1f C', [Temp]);
    except
      on E: SysUtils.Exception do
      begin
        FreeAndNil(FHeater);
        FSetupStatus[itHeater].OK      := False;
        FSetupStatus[itHeater].Message := E.Message;
        Result := False;
        FObserver.Log(E.Message);
      end;
    end;
  end;

  { --- Prober --- }
  FSetupStatus[itProber].Label_  := 'Prober';
  FSetupStatus[itProber].Folder  := FProberExeDir;
  FSetupStatus[itProber].Address := FProberAddress;
  if FProberExeDir = '' then
  begin
    FSetupStatus[itProber].Skipped := True;
    FSetupStatus[itProber].OK      := True;
    FSetupStatus[itProber].Message := 'not configured';
  end
  else
  begin
    FSetupStatus[itProber].Skipped := False;
    try
      FProber := TProberController.Create(FProberExeDir, FProberAddress);
      FProber.Connect;
      FSetupStatus[itProber].OK      := True;
      FSetupStatus[itProber].Message := 'executables found';
    except
      on E: SysUtils.Exception do
      begin
        FreeAndNil(FProber);
        FSetupStatus[itProber].OK      := False;
        FSetupStatus[itProber].Message := E.Message;
        Result := False;
        FObserver.Log(E.Message);
      end;
    end;
  end;

  FObserver.InitializeSetup(FSetupStatus);
end;

function TAnnealManager.IsDamaged(R, ThresholdOpen, ThresholdShort: Double): Boolean;
begin
  Result := (R > ThresholdOpen) or (R < ThresholdShort);
end;

procedure TAnnealManager.SetTemperature(Temp: Double);
begin
  try
    FHeater.SetTemperature(Temp);
    FObserver.Log('Heater set to ' + FloatToStr(Temp) + 'C');
  except
    FObserver.Log('Temperature setting failed');
  end;
end;

function TAnnealManager.SweepResistance(AParams: TProbingParameters): TProbingResult;
var
  Voltages: TArray<Double>;
  StartV, StopV: Double;
  Steps, I, Count: Integer;
  ReadingsList: TDoubleArray;
begin
  if AParams.StepNumber <= 0 then
  begin
    { Sensible default linear sweep if uninitialized }
    StartV := -0.01;
    Steps  := 20;
    StopV  := StartV + (Steps-1) * 0.001;
  end
  else
  begin
    StartV := AParams.StartVoltage;
    StopV  := AParams.StartVoltage + (AParams.StepNumber-1) * AParams.StepSize ;
    Steps  := AParams.StepNumber;
  end;
  Voltages := AParams.GetVoltages;
  if Length(Voltages) = 0 then
      raise EArgumentOutOfRangeException.Create('StepNumber must be greater then zero');

  SetLength(ReadingsList, Steps);
  Count := 0;

  FB1500.SetMeasurementConfig;
  try
    FB1500.ExecuteStaircaseStream(
      StartV,
      StopV,
      AParams.InitialWait,
      AParams.MeasureTime,
      Steps,
      procedure(V, R: Double)
      begin
        if Count < Length(ReadingsList) then
        begin
          ReadingsList[Count] := R;
          Inc(Count);
        end;
        FObserver.MeasurementPoint(V, R);
      end);
  finally
    FB1500.AllChannelSaveAndZero;
  end;

  SetLength(ReadingsList, Count);
  Result.Readings       := ReadingsList;
  Result.MeanResistance := MeanDoubleArray(Result.Readings);
  Result.StdResistance  := StdDoubleArray(Result.Readings);
  Result.Success        := Count = Steps;
  Result.ErrorMsg       := '';

  FObserver.Log(Format('Resistance: %.1f +/- %.1f Ohm',
    [Result.MeanResistance, Result.StdResistance]));
end;

function TAnnealManager.ProbeSingle(AParams: TProbingParameters): TProbingResult;
var
  HWRes: THardwareResult;
begin
  FObserver.TaskStarted;
  Result := SweepResistance(AParams);
  HWRes.CommandType   := hcProbeSingle;
  HWRes.ProbingResult := Result;
  FObserver.TaskFinished(HWRes);
end;
procedure TAnnealManager.AnnealPulse(VPulse, AT: Double);
begin
  // Only pulse SMU1; SMU2 is already held at 0 V
  FB1500.SMU1.SetVoltage(VPulse);
  SleepSeconds(AT);
  FB1500.SMU1.SetVoltage(0.0);
end;

procedure TAnnealManager.AnnealPairs(AVPulseHigh, AVPulseLow, AT: Double;
  APairs: Integer; ASMU: TB1511B; var Res: TAnnealResult);
var
  I: Integer;
  TStart: Double;
begin
  // Only pulse SMU1; SMU2 is already held at 0 V
  for I := 1 to APairs do
  begin
    TStart := NowSeconds;
    ASMU.SetVoltage(AVPulseHigh);
    SleepSeconds(AT);
    Res.AppendPulseDuration(NowSeconds - TStart);

    TStart := NowSeconds;
    ASMU.SetVoltage(AVPulseLow);
    SleepSeconds(AT);
    Res.AppendPulseDuration(NowSeconds - TStart);
  end;

  ASMU.SetVoltage(0.0);
end;

function TAnnealManager.Anneal(const AParams: TAnnealConfig): TAnnealResult;
var
  Res: TAnnealResult;
  CurrentTime: Double;
  CurrentR: Double;
  Cycle: Integer;
  TotalPairs: Integer;
  Stop: Boolean;
  TStart: Double;
begin
  Res.TargetResistance := AParams.TargetResistance;
  Cycle := 0;
  TotalPairs := 0;
  FObserver.TaskStarted();
  try
    // 1. Pre-enable channels and configure static ground reference on SMU2
    FB1500.SetMeasurementConfig;

    // 2. Initial baseline resistance measurement
    TStart := NowSeconds;
    CurrentTime := NowSeconds;
    FHeater.SetTemperature(AParams.Temperature);

    CurrentR := FB1500.MeasureResistance(
      AParams.MeasureVoltage, AParams.InitialWait, AParams.MeasureTime);
    Res.AddResistanceSample(CurrentTime - TStart, CurrentR);
    Res.AppendCycleStats(CurrentR, 0);
    FObserver.MeasurementPoint(CurrentTime - TStart, CurrentR);

    // If initial R already exceeds target, exit early
    if (Res.FinalResistance >= AParams.TargetResistance) then
    begin
      FObserver.Log(Format('Initial R (%.1f Ohm) already exceeds target (%.1f Ohm). Skipping anneal.',
        [Res.FinalResistance, AParams.TargetResistance]));
      FB1500.AllChannelSaveAndZero;
      Res.Finalise;
      Exit(Res);
    end;

    TotalPairs := 0;
    Stop := False;

    for Cycle := 0 to AParams.Cycles - 1 do
    begin
      if FObserver.ShouldAbort then
        Break;
      try
        AnnealPairs(AParams.PulsePositive, AParams.PulseNegative,
                    AParams.PulseLength, AParams.PulsePairs, FB1500.SMU1, Res);
      except
        on E: Exception do
        begin
          FObserver.Log(Format('Error on cycle (cycle %d): %s. Stopping.', [Cycle, E.Message]));
          FObserver.Error(E.Message);
          Break;
        end;
      end;

      Inc(TotalPairs, AParams.PulsePairs);
      if Stop then
        Break;

      // Resistance measurement at the end of the cycle
      CurrentTime := NowSeconds;
      CurrentR := FB1500.MeasureResistance(
        AParams.MeasureVoltage,
        AParams.InitialWait,
        AParams.MeasureTime);
      Res.AddResistanceSample(CurrentTime - TStart, CurrentR);
      Res.AppendCycleStats(CurrentR, 0);
      FObserver.MeasurementPoint(CurrentTime - TStart, CurrentR);
      FObserver.Log(Format('Cycle %d/%d  R = %.1f Ohm', [Cycle + 1, AParams.Cycles, CurrentR]));

      // Early stop: target reached
      if (CurrentR >= AParams.TargetResistance) then
      begin
        FObserver.Log(Format('[Target reached after %d cycles (%d pairs). R = %.1f Ohm',
          [Cycle + 1, TotalPairs, CurrentR]));
        Break;
      end;

      // Early stop: junction damaged
      if IsDamaged(CurrentR, AParams.ThresholdOpen, AParams.ThresholdShort) then
      begin
        FObserver.Log(Format('Junction appears damaged (R = %.1f Ohm). Stopping.', [CurrentR]));
        Break;
      end;
    end;
  finally
    Res.FinalCycleCount := Cycle;
    Res.FinalPairCount  := TotalPairs;

    FB1500.AllChannelSaveAndZero;
    Res.Finalise;
    Result := Res;
  end;
end;

function TAnnealManager.AnnealSingle(const AParams: TAnnealConfig): TAnnealResult;
var
  HWRes: THardwareResult;
begin
  FObserver.TaskStarted();
  Result := Anneal(AParams);
  HWRes.CommandType  := hcAnnealSingle;
  HWRes.AnnealResult := Result;
  FObserver.TaskFinished(HWRes);
  FObserver.Log(Format('[Anneal complete. %d pulse pairs across %d cycles. ' +
                       'Final R = %.1f Ohm',
    [Result.FinalPairCount, Length(Result.ResistanceSamples) - 1, Result.FinalResistance]));
end;

function TAnnealManager.AnnealBatch(const ASpecs: TAnnealConfigArray;
  FinalTemperature: Double): TAnnealResultArray;
var
  Coord: TProberCoord;
  I: Integer;
  BR: TAnnealResult;
  CycleResult: TAnnealedJunction;
  HWRes, HWResCycle: THardwareResult;
begin
  SetLength(Result, 0);
  Coord := FProber.Start;
  FObserver.TaskStarted();
  FObserver.Log(Format('[AnnealBatch] Prober started at %s', [Coord.ToString]));
  FObserver.Log(Format('[AnnealBatch] %d junctions to process.', [Length(ASpecs)]));

  for I := 0 to High(ASpecs) do
  begin
    if FObserver.ShouldAbort then
      Break;
    FObserver.Log(Format('--- [%d/%d] %s  coord=%s ---',
      [I + 1, Length(ASpecs), Coord.Subsite, Coord.ToString]));
    FObserver.TaskStarted();
    BR := Anneal(ASpecs[I]);
    SetLength(Result, Length(Result) + 1);
    CycleResult.AnnealResult := BR;
    CycleResult.Coord := Coord;
    Result[High(Result)] := CycleResult;
    HWResCycle.CommandType := hcAnnealBatchCycle;
    HWResCycle.AnnealedJunctionResult := CycleResult;
    FObserver.TaskFinished(HWResCycle);

    { Advance prober (skip on last junction) }
    if I < High(ASpecs) then
      try
        Coord := FProber.NextSubsite;
        FObserver.Log(Format('[AnnealBatch] Prober moved to %s', [Coord.ToString]));
      except
        on E: SysUtils.Exception do
        begin
          FObserver.Log('[AnnealBatch] Prober move failed: ' + E.Message + '. Stopping batch.');
          Break;
        end;
      end;
  end;

  FProber.Finish;
  if FinalTemperature <> 0 then
    SetTemperature(FinalTemperature);
  FObserver.Log('[AnnealBatch] Batch complete.');
  HWRes.CommandType := hcAnnealBatch;
  HWRes.AnnealResultArray := Result;
  FObserver.TaskFinished(HWRes);
end;

procedure TAnnealManager.SendZeroVoltage;
begin
  FB1500.SetVoltage(1, 0.0);
  FB1500.SetVoltage(2, 0.0);
end;

function TAnnealManager.ProbeBatch(AParams: TProbingParameters): TProbingResultArray;
var
  Coord: TProberCoord;
  I: Integer;
  M: TProbingResult;
  HWRes, HWResCycle: THardwareResult;
  CycleResult: TProbedJunction;
begin
  SetLength(Result, 0);
  I := 0;
  FObserver.TaskStarted();
  try
    Coord := FProber.Start;
    FObserver.Log(Format('[ProbeBatch] Prober started at %s', [Coord.ToString]));

    while not Coord.Break do
    begin
      try
        if FObserver.ShouldAbort then
          Break;
        FObserver.Log(Format('  [%d] %s ... ', [I + 1, Coord.ToString]));
        FObserver.TaskStarted();
        M := SweepResistance(AParams);
        SetLength(Result, Length(Result) + 1);
        CycleResult.ProbingResult := M;
        CycleResult.Coord := Coord;
        Result[High(Result)] := CycleResult;
        HWResCycle.CommandType := hcProbeBatchCycle;
        HWResCycle.ProbedJunctionResult := CycleResult;
        FObserver.TaskFinished(HWResCycle);
        Coord := FProber.NextSubsite;
        Inc(I);
      except
        on E: SysUtils.Exception do
        begin
          FObserver.Log('[ProbeBatch] Prober move failed: ' + E.Message + '. Stopping.');
          Break;
        end;
      end;
    end;
  finally
    FProber.Finish;
    FObserver.Log(Format('[ProbeBatch] Done. %d junctions measured.', [Length(Result)]));
    HWRes.CommandType := hcProbeBatch;
    HWRes.ProbingResultArray := Result;
    FObserver.TaskFinished(HWRes);
  end;
end;

procedure TAnnealManager.DisconnectAll;
begin
  if Assigned(FB1500) then
  begin
    try
      FB1500.DisableOutputs;
    except
    end;
    FreeAndNil(FB1500);
  end;
  if Assigned(FHeater) then
  begin
    try
      FHeater.Disconnect;
    except
    end;
    FreeAndNil(FHeater);
  end;
  if Assigned(FProber) then
  begin
    try
      FProber.Disconnect;
    except
    end;
    FreeAndNil(FProber);
  end;
end;

end.
