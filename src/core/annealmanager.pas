unit AnnealManager;


interface

uses
  SysUtils, Classes, Math, StrUtils,AnnealTypes,
  B1500Mainframe,   { B1500 Parameter Analyzer driver }
  B1500Constants,   { B1500 Parameter Analyzer driver }
  HeatingStage,     { Heating Stage driver unit }
  Prober,           { Prober driver unit }
  b1511b,           { B1500 SMU }
  MeasurementObserver; {class to receive measurement points}

const
{$IFDEF DEBUG}
  DEFAULT_ANALYZER_ADDRESS = 'GPIB0::16::INSTR';
  DEFAULT_PROBER_DIR       = 'C:\Users\B1500\Documents\voltage_annealing\apollowave';

{$ELSE}
  DEFAULT_ANALYZER_ADDRESS = 'agb1500a';
  DEFAULT_PROBER_DIR       =
  'C:\Program Files\Agilent\B1500\EasyEXPERT\Utilities\ProberControl\apollowave';

{$ENDIF}
  DEFAULT_HEATER_ADDRESS   = 'GPIB0::7::INSTR';
  DEFAULT_PROBER_ADDRESS   = 'GPIB0::5::INSTR';
  DEFAULT_COMPLIANCE       = 0.05;   { 50 mA }
  DEFAULT_SETTLETIME       = 0.2;
type

  // ---------------------------------------------------------------------------
// TB1500Controller
// ---------------------------------------------------------------------------

  TB1500Controller = class
  private
    FAddress    : string;
    FCompliance : Double;
    FB1500      : TB1500;          { from KeysightB1500 unit }
    FConnected  : Boolean;
    FObserver         : IMeasurementObserver;
    procedure RequireConnection;
    function  GetSMU(ASmu: Integer): TB1511B;
  public
    constructor Create(
           AObserver              : IMeasurementObserver;
          const AAddress: string = DEFAULT_ANALYZER_ADDRESS;
                       ACompliance: Double = DEFAULT_COMPLIANCE
                        );
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
                           Tolerance: Double = 0.5): Double;
    function  SetAndCheckVoltage(ASmu: Integer; V: Double;
                                 SettleTime: Double = DEFAULT_SETTLETIME): Double;

    { Measurement }
    function MeasureCurrent(ASmu: Integer;ARangeconfig:TIMeasRange=imr1mA): Double;
    function MeasureVoltageReadback(ASmu: Integer): Double;
    function MeasureResistance(VSource,AInitialWait,AMeasureTime : Double): Double;
    function SweepVoltageMeasureResistance(
      const AVoltages: TArray<Double>;
      AInitialWait: Double = 0.5;
      AMeasureTime  : Double =0.5 //sec
    ): TArray<Double>;

    property Address    : string  read FAddress;
    property Compliance : Double  read FCompliance write FCompliance;
    property Connected  : Boolean read FConnected;
  end;


  TAnnealManager = class
  private
    FAnalyzer         : TB1500Controller;
    FProber           : TProberController;
    FHeater           : THeatingStage;
    FObserver         : IMeasurementObserver;
    FSetupStatus      : TSetupStatus;
    FAnalyzerAddress  : string;
    FHeaterAddress    : string;
    FProberExeDir     : string;
    FProberAddress    : string;
    FCompliance       : Double;
    FRunSelfCal       : Boolean;

    function Anneal(const AParams: TAnnealConfig): TAnnealResult;
    function ProbeResistance(AParams: TProbingParameters): TProbingResult;

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

    function Initialize : Boolean;

    procedure AnnealPulse(VPulse, AT: Double);
    procedure AnnealPairs(AVPulseHigh,AVPulseLow, AT: Double;APairs:Integer;
          ASMU:TB1511B;Var Res : TAnnealResult);
    function AnnealSingle(const AParams: TAnnealConfig): TAnnealResult;
    function AnnealBatch(const ASpecs : TAnnealConfigArray;
                                    FinalTemperature: Double = 22.0) : TAnnealResultArray;
    function ProbeSingle(AParams: TProbingParameters): TProbingResult;
    function ProbeBatch(AParams: TProbingParameters): TProbingResultArray;
    function IsDamaged(R, ThresholdOpen, ThresholdShort: Double): Boolean;
    procedure setTemperature(Temp: Double);
    procedure SendZeroVoltage();
    procedure DisconnectAll;

  end;


implementation

// ---------------------------------------------------------------------------
// TB1500Controller
// ---------------------------------------------------------------------------

constructor TB1500Controller.Create(
           AObserver     : IMeasurementObserver;
          const AAddress : string = DEFAULT_ANALYZER_ADDRESS;
          ACompliance    : Double = DEFAULT_COMPLIANCE
                        );
begin
  inherited Create;
  FAddress    := AAddress;
  FCompliance := ACompliance;
  FB1500      := nil;
  FConnected  := False;
  FObserver   := AObserver;
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
  FB1500.SetDataFormat('1,0');
  FConnected := True;
end;

procedure TB1500Controller.SelfCalibrate;
begin
  RequireConnection;
  try
    FB1500.SelfCalibration;
  except
    on E: SysUtils.Exception do
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
  Sleep(50);
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
  SleepSeconds(0.2);
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

function TB1500Controller.MeasureCurrent(ASmu: Integer;
                    ARangeconfig:TIMeasRange=imr1mA): Double;
var SMU: TB1511B;
begin
  RequireConnection;
  SMU := GetSMU(ASmu);
  SMU.IMeasRangeConfig(ARangeconfig);
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

function TB1500Controller.MeasureResistance(VSource,AInitialWait,AMeasureTime : Double): Double;
var
  SMU1,SMU2: TB1511B;
  RawResp: string;
  Reading1, Reading2: TSMUSpotReading;
  SettleMs : Cardinal;
  PLC      : Integer;
begin
  SMU1 := GetSMU(1);
  SMU2 := GetSMU(2);
  SettleMs := Round(AInitialWait * 1000);

  //one power-line cycle is 20ms, Setting the number of PLC integrations.
  PLC := Round(AMeasureTime / 0.02 );
  FB1500.SetIntegrationTimePLC(PLC);
  SMU1.SetVoltage(VSource);
  if SettleMs > 0 then Sleep(SettleMs);
      // Trigger simultaneous acquisition across SMU1 & SMU2
      RawResp := FB1500.ExecuteMeasurementRaw;
      //Reading1:=FB1500.ExecuteSynchronousMeasurement

      // Extracted cleanly by each SMU instance without B1500Module types:
      //Reading1 := Smu1.ExtractReading(RawResp);
      Reading1 := Smu1.ExtractReading(RawResp);
      Reading2 := Smu2.ExtractReading(RawResp);

      // Calculate junction resistance: R = |(V_smu1 - V_smu2) / I_smu1|
      if Abs(Reading1.Current) > 1e-14 then
        //Result[I] := Abs((AVoltages[I] - Reading2.Voltage) / Reading1.Current)
        Result := Abs((VSource - Reading2.Voltage) / Reading1.Current)
      else
        Result := 1e12; // Open circuit fallback
end;

function TB1500Controller.SweepVoltageMeasureResistance(
  const AVoltages: TArray<Double>;
  AInitialWait,AMeasureTime  : Double
): TArray<Double>;
var
  I: Integer;
  CycleWait : Double;
begin
  RequireConnection;
  SetLength(Result, Length(AVoltages));
  if Length(AVoltages) = 0 then
    Exit;
  try
    for I := Low(AVoltages) to High(AVoltages) do
    begin
      if (I = Low(AVoltages)) and (High(AVoltages) <> 0)
         then  CycleWait := AInitialWait  //let it sit before first measuremnt
         else CycleWait := 0.3;

      Result[I]:= MeasureResistance(AVoltages[I],CycleWait,AMeasureTime);
      FObserver.MeasurementPoint(AVoltages[I], Result[I]);
    end;
  finally

  end;
end;

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
  FObserver        := AObserver;
  FCompliance      := ACompliance;
  FAnalyzer         := nil;
  FHeater           := nil;
  FProber           := nil;
end;

destructor TAnnealManager.Destroy;
begin
  DisconnectAll;
  inherited;
end;




function TAnnealManager.Initialize: Boolean;
var
  Temp     : Double;
begin
  Result := True;
  { --- B1500A Analyzer --- }
  FSetupStatus[itAnalyzer].Label_  := 'B1500A';
  FSetupStatus[itAnalyzer].Address := FAnalyzerAddress;
  FSetupStatus[itAnalyzer].Skipped := False;
  try
    FAnalyzer := TB1500Controller.Create(FObserver,FAnalyzerAddress, FCompliance);
    FAnalyzer.Connect;
    //if FRunSelfCal then FAnalyzer.SelfCalibrate;
    FSetupStatus[itAnalyzer].OK      := True;
    FSetupStatus[itAnalyzer].Message := '';
  except
    on E: Exception do
    begin
      FreeAndNil(FAnalyzer);
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
  FSetupStatus[itProber].Folder := FProberExeDir;
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
      FProber := TProberController.Create(FProberExeDir,FProberAddress);
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
    FObserver.Log('Heater set to '+ FloatToStr(Temp) + 'C');
  except
    FObserver.Log('Temperature setting failed');
  end;
end;

function TAnnealManager.ProbeResistance(AParams: TProbingParameters):TProbingResult;
var
  DefaultVoltages : TArray<Double>;
  Voltages        : TArray<Double>;

begin
  if AParams.VoltageList = nil then
  begin
    SetLength(DefaultVoltages, 4);
    DefaultVoltages:= [-0.01,-0.005,0.005,0.1];
    Voltages := DefaultVoltages;
  end
  else
    Voltages := TArray<Double>(AParams.VoltageList);
  FAnalyzer.FB1500.SetMeasurementConfig;
  try
   Result.Readings := TDoubleArray(FAnalyzer.SweepVoltageMeasureResistance(
                      Voltages,
                      AParams.InitialWait,
                      AParams.MeasureTime));
  finally
   //FAnalyzer.DisableOutputs;
   FAnalyzer.FB1500.AllChannelSaveAndZero
  end;
  Result.MeanResistance := MeanDoubleArray(Result.Readings);
  Result.StdResistance  := StdDoubleArray(Result.Readings);
  FObserver.Log(Format('Resistance: %.1f +/- %.1f Ohm',
                 [Result.MeanResistance, Result.StdResistance]));

end;

function TAnnealManager.ProbeSingle(AParams: TProbingParameters):TProbingResult;
var
HWRes           : THardwareResult;
begin
  FObserver.TaskStarted;
  Result := ProbeResistance(AParams);
  HWRes.CommandType:=hcProbeSingle;
  HWRes.ProbingResult:=Result;
  FObserver.TaskFinished(HWRes);
end;

procedure TAnnealManager.AnnealPulse(VPulse, AT: Double);
var
  Smu1: TB1511B;
begin
  // Only pulse SMU1; SMU2 is already held at 0 V
  Smu1 := FAnalyzer.GetSMU(1);
  Smu1.SetVoltage(VPulse);
  SleepSeconds(AT);
  Smu1.SetVoltage(0.0);
end;

procedure TAnnealManager.AnnealPairs(
              AVPulseHigh,AVPulseLow, AT: Double;
              APairs                    :Integer;
              ASMU                      :TB1511B;
              Var Res               : TAnnealResult);
var
  i: integer;
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
  Res               : TAnnealResult;
  //ProbingParameters : TProbingParameters;
  //ProbingResult     : TProbingResult;
  CurrentTime       : Double;
  CurrentR          : Double;
  Cycle       : Integer;
  TotalPairs        : Integer;
  Stop              : Boolean;
  TStart            : Double;
  Smu1              : TB1511B;
begin
  Res.TargetResistance := AParams.TargetResistance;
  Cycle := 0;TotalPairs:=0;
  FObserver.TaskStarted();
  try
  // 1. Pre-enable channels and configure static ground reference on SMU2
  Smu1 := FAnalyzer.GetSMU(1);
  FAnalyzer.FB1500.SetMeasurementConfig;
  // 2. Initial baseline resistance measurement
  TStart := NowSeconds;
  CurrentTime := NowSeconds;
  FHeater.SetTemperature(AParams.Temperature);
  //ProbingResult := ProbeResistance(ProbingParameters);
  CurrentR := FAnalyzer.MeasureResistance(
              AParams.MeasureVoltage,
              AParams.InitialWait,
              AParams.MeasureTime);
  Res.AddResistanceSample(CurrentTime-TStart, CurrentR);
  Res.AppendCycleStats(CurrentR, 0);
  FObserver.MeasurementPoint(CurrentTime-TStart, CurrentR);

  // If initial R already exceeds target, exit early
  if (Res.FinalResistance >= AParams.TargetResistance) then
  begin
    FObserver.Log(Format('Initial R (%.1f Ohm) already exceeds target (%.1f Ohm). Skipping anneal.',
      [Res.FinalResistance, AParams.TargetResistance]));
    FAnalyzer.FB1500.AllChannelSaveAndZero;
    Res.Finalise;
    Exit(Res);
  end;

  TotalPairs := 0;
  Stop       := False;

  for Cycle := 0 to AParams.Cycles - 1 do
  begin
    if FObserver.ShouldAbort then
      Break;
    try
    AnnealPairs(AParams.PulsePositive,AParams.PulseNegative,
                AParams.PulseLength,AParams.PulsePairs,Smu1,Res);
    except
        on E: Exception do
        begin
          FObserver.Log(Format('Error on  cycle (cycle %d): %s. Stopping.',
            [Cycle, E.Message]));
          FObserver.Error(E.Message);
          Break;
        end;
    end;
    Inc(TotalPairs,AParams.PulsePairs);
    if Stop then
      Break;

    // Resistance measurement at the end of the cycle
    CurrentTime := NowSeconds;
    CurrentR := FAnalyzer.MeasureResistance(
              AParams.MeasureVoltage,
              AParams.InitialWait,
              AParams.MeasureTime);
    Res.AddResistanceSample(CurrentTime-TStart, CurrentR);
    Res.AppendCycleStats(CurrentR, 0);
    FObserver.MeasurementPoint(CurrentTime-TStart, CurrentR);
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

  FAnalyzer.FB1500.AllChannelSaveAndZero;
  Res.Finalise;
  Result := Res;
  end;
end;

function TAnnealManager.AnnealSingle(const AParams: TAnnealConfig): TAnnealResult;
var
HWRes : THardwareResult;
begin
  FObserver.TaskStarted();
  Result := Anneal(AParams);
  HWRes.CommandType:=hcAnnealSingle;
  HWRes.AnnealResult:=Result;
  FObserver.TaskFinished(HWRes);
  FObserver.Log(Format('[Anneal complete. %d pulse pairs across %d cycles. ' +
                 'Final R = %.1f Ohm',
                 [Result.FinalPairCount,
                  Length(Result.ResistanceSamples) - 1,
                  Result.FinalResistance]));
end;

function TAnnealManager.AnnealBatch(const ASpecs: TAnnealConfigArray;
                                    FinalTemperature: Double
): TAnnealResultArray;
var
  Coord           : TProberCoord;
  i               : Integer;
  BR              : TAnnealResult;
  CycleResult     : TAnnealedJunction;
  HWRes,HWResCycle  : THardwareResult;
begin
  SetLength(Result, 0);
  Coord := FProber.Start;
  FObserver.TaskStarted();
  Fobserver.Log(Format('[AnnealBatch] Prober started at %s', [Coord.ToString]));
  Fobserver.Log(Format('[AnnealBatch] %d junctions to process.', [Length(ASpecs)]));

  for i := 0 to High(ASpecs) do
  begin
    if Fobserver.ShouldAbort then
      Break;
    Fobserver.Log(Format('--- [%d/%d] %s  coord=%s ---',
                   [i + 1, Length(ASpecs),
                    Coord.Subsite, Coord.ToString]));
    FObserver.TaskStarted();
    BR := Anneal(ASpecs[i]);
    SetLength(Result, Length(Result) + 1);
    CycleResult.AnnealResult := BR;
    CycleResult.Coord := Coord;
    Result[High(Result)]:= CycleResult;
    HWResCycle.CommandType:=hcAnnealBatchCycle;
    HWResCycle.AnnealedJunctionResult:=CycleResult;
    FObserver.TaskFinished(HWResCycle);
    { Advance prober (skip on last junction) }
    if i < High(ASpecs) then
    try
      Coord := FProber.NextSubsite;
      FObserver.Log(Format('[AnnealBatch] Prober moved to %s', [Coord.ToString]));
    except
      on E: SysUtils.Exception do
      begin
        FObserver.Log('[AnnealBatch] Prober move failed: ' + E.Message +
                '. Stopping batch.');
        Break;
      end;
    end;
  end;

  FProber.Finish;
  if finalTemperature <> 0 then SetTemperature(FinalTemperature);
  FObserver.Log('[AnnealBatch] Batch complete.');
  HWRes.CommandType:=hcAnnealBatch;
  HWRes.AnnealResultArray:=Result;
  FObserver.TaskFinished(HWRes);
end;

procedure TAnnealManager.SendZeroVoltage();

begin
  FAnalyzer.SetVoltage(1, 0.0);
  FAnalyzer.SetVoltage(2, 0.0);
end;

function TAnnealManager.ProbeBatch(AParams: TProbingParameters): TProbingResultArray;
var
  Coord : TProberCoord;
  i     : Integer;
  M     : TProbingResult;
  HWRes,HWResCycle: THardwareResult;
  CycleResult     : TProbedJunction;

begin
  SetLength(Result, 0);
  i:=0;
  FObserver.TaskStarted();
  try
  Coord := FProber.Start;
  Fobserver.Log(Format('[ProbeBatch] Prober started at %s', [Coord.ToString]));

    while not Coord.Break do
    begin
      try
        if Fobserver.ShouldAbort then
        Break;
        Fobserver.Log(Format('  [%d] %s ... ',
                     [i + 1, Coord.ToString]));
        FObserver.TaskStarted();
        M := ProbeResistance(AParams);
        SetLength(Result, Length(Result) + 1);
        CycleResult.ProbingResult := M;
        CycleResult.Coord := Coord;
        Result[High(Result)]:= CycleResult;
        HWResCycle.CommandType:=hcProbeBatchCycle;
        HWResCycle.ProbedJunctionResult:=CycleResult;
        FObserver.TaskFinished(HWResCycle);
        Coord := FProber.NextSubsite;
       except
          on E: SysUtils.Exception do
          begin
            Fobserver.Log('[ProbeBatch] Prober move failed: ' + E.Message +
                    '. Stopping.');
            Break;
          end
       end;
    end;
  finally
  FProber.Finish;
  Fobserver.Log(Format('[ProbeBatch] Done. %d junctions measured.',
                 [Length(Result)]));
  HWRes.CommandType:=hcProbeBatch;
  HWRes.ProbingResultArray:=Result;
  FObserver.TaskFinished(HWRes);
  end;



end;

procedure TAnnealManager.DisconnectAll;
begin
  if Assigned(FAnalyzer) then
  begin
    try FAnalyzer.Disconnect; except end;
    FreeAndNil(FAnalyzer);
  end;
  if Assigned(FHeater) then
  begin
    try FHeater.Disconnect; except end;
    FreeAndNil(FHeater);
  end;
  if Assigned(FProber) then
  begin
    try FProber.Disconnect; except end;
    FreeAndNil(FProber);
  end;
end;


end.

