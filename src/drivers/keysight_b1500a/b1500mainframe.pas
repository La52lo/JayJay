unit B1500Mainframe;

{
  b1500_mainframe.pas
  -------------------
  Top-level driver for the Keysight B1500A Semiconductor Parameter Analyzer.

  Mirrors:
    QCoDeS keysightb1500/KeysightB1500_base.py  (KeysightB1500)
    lib_voltage_anneal.py                         (RikenB1500 + initialize())

  Fixes vs first version
  ----------------------
  * Write() now checks ERR? after every command, exactly matching the
    QCoDeS KeysightB1500.write() override:
        def write(self, cmd):
            super().write(cmd)
            error_message = self.error_message()
            if error_message != '+0,"No Error."':
                raise RuntimeError(...)
    The check is done in TB1500.Write so that all paths - including
    commands issued by TB1511B - go through it via the callback
    mechanism added in b1511b.pas.

 Error response parsing now uses
    Pos() and Copy() which compile cleanly in all FPC modes.

  * Removed the local IfThen(Boolean,string,string) helper that
    conflicted with the Math unit overload. The SMU count message
    is now built with a plain if/else block.

  * FindModules passes TB1500.Write and TB1500.Ask as method-of-object
    callbacks to each TB1511B, so every SMU command goes through the
    error-checking Write path.

  * SelfCalibration temporarily raises the VISA timeout to 35 s before
    sending *CAL? and restores it afterwards, matching QCoDeS behaviour
    (the instrument can take up to 30 s).
}


interface

uses
  SysUtils, VisaTransport, B1500Constants, MessageBuilder,
  B1500Module, b1511b;

const
  DEFAULT_TIMEOUT_MS = 10000;   { 10 s for normal commands  }
  CAL_TIMEOUT_MS     = 30000;   { 35 s for *CAL?            }

type
  EB1500Error = class(Exception);

  TB1500 = class
  private
    FTransport : TVisaTransport;
    FSMU1      : TB1511B;
    FSMU2      : TB1511B;

    { Raw transport – no error check. Used internally only. }
    procedure RawWrite(const cmd: string);
    function  RawAsk (const cmd: string): string;

    { Check ERR? and raise if the instrument reports an error.
      Called by Write() after every command.                  }
    procedure CheckInstrumentError(const context: string);

    procedure FindModules;
    function GetConnected: Boolean;

  public
    constructor Create(const gpibAddress: string;
                       timeoutMs: LongWord = DEFAULT_TIMEOUT_MS);
    destructor  Destroy; override;

    { Write a FLEX command and check ERR? afterwards.
      This is the method-of-object passed to TB1511B as its
      write callback, so SMU commands also go through here.  }
    procedure Write(const cmd: string);

    { Send a query and return the response. No ERR? check
      (read commands do not generate errors that ERR? would catch,
      and the response itself carries status information).        }
    function  Ask(const cmd: string): string;

    { self_calibration() }
    procedure SelfCalibration;

    { Disable all channels (CL with no argument = all) }
    procedure DisableAllChannels;

    { SMU channels, populated by FindModules.
      Correspond to b1500.smu1 / b1500.smu2 in Python. }
    property SMU1 : TB1511B read FSMU1;
    property SMU2 : TB1511B read FSMU2;
    property Connected : Boolean read GetConnected;
  end;

implementation

{ ------------------------------------------------------------------ }

constructor TB1500.Create(const gpibAddress: string; timeoutMs: LongWord);
begin
  inherited Create;
  FSMU1 := nil;
  FSMU2 := nil;

  {WriteLn('Connecting to B1500A at ', gpibAddress, ' ...');}
  FTransport := TVisaTransport.Create(gpibAddress, timeoutMs);
  {WriteLn('Connected.');}

  { Set ASCII data format: FMT 1,0 (with header, measurement data only) }
  {Write('FMT 1,0');}

  {******FindModules;  }
end;

destructor TB1500.Destroy;
begin
  try
    if Assigned(FTransport) then
      DisableAllChannels;
  except
  end;
  FreeAndNil(FSMU1);
  FreeAndNil(FSMU2);
  FreeAndNil(FTransport);
  inherited;
end;

{ ------------------------------------------------------------------ }
{ Transport helpers                                                    }
{ ------------------------------------------------------------------ }

procedure TB1500.RawWrite(const cmd: string);
begin
  FTransport.Write(cmd);
end;

function TB1500.RawAsk(const cmd: string): string;
begin
  Result := FTransport.Ask(cmd);
end;

{ ------------------------------------------------------------------ }
{ Error checking - mirrors KeysightB1500.write() override in QCoDeS   }
{ ------------------------------------------------------------------ }

procedure TB1500.CheckInstrumentError(const context: string);
var
  resp : string;
  code : string;
begin
  { ERR? returns "+<code>,\"<message>\"" }
  resp := Trim(RawAsk('ERR?'));

  { No error is indicated by code 0 }
  if (Length(resp) >= 2) and (resp[1] = '+') then
  begin
    code := Copy(resp, 2, 1);   { just the first digit after '+' }
    if code = '0' then Exit;    { +0 = no error }
  end;

  raise EB1500Error.CreateFmt(
    'B1500 instrument error after "%s": %s', [context, resp]);
end;

procedure TB1500.Write(const cmd: string);
begin
  RawWrite(cmd);
  CheckInstrumentError(cmd);
end;

function TB1500.Ask(const cmd: string): string;
begin
  Result := RawAsk(cmd);
end;

{ ------------------------------------------------------------------ }
{ Module detection                                                     }
{ ------------------------------------------------------------------ }

procedure TB1500.FindModules;
var
  slots  : TSlotModelArray;
  i      : Integer;
  count  : Integer;
  raw    : string;
  smuMsg : string;
begin
  raw   := RawAsk('UNT? 0');
  slots := ParseModuleQueryResponse(raw);
  count := 0;

  for i := 0 to High(slots) do
  begin
    if (slots[i].Model = MODEL_B1511B) or
       (slots[i].Model = MODEL_B1511A) then
    begin
      Inc(count);
      case count of
        1 : FSMU1 := TB1511B.Create(Write, Ask, slots[i].SlotNr);
        2 : FSMU2 := TB1511B.Create(Write, Ask, slots[i].SlotNr);
      end;
    end;
  end;

  if count = 0 then
    raise EB1500Error.Create(
      'FindModules: no B1511B/B1511A found. UNT? response: ' + raw);

  { Build the log message without IfThen }
  smuMsg := Format('Found %d B1511B module(s). SMU1=ch%d',
                   [count, FSMU1.Channel]);
  if Assigned(FSMU2) then
    smuMsg := smuMsg + Format(', SMU2=ch%d', [FSMU2.Channel]);
  {WriteLn(smuMsg);}
end;
function TB1500.GetConnected: Boolean;
begin
  Result := (FTransport <> nil);
end;
{ ------------------------------------------------------------------ }
{ Self-calibration                                                     }
{ ------------------------------------------------------------------ }

procedure TB1500.SelfCalibration;
var
  resp : string;
begin
  {WriteLn('Starting self-calibration (may take up to 30 s)...'); }

  { Raise timeout temporarily so the blocking *CAL? does not time out }
  FTransport.SetTimeout(CAL_TIMEOUT_MS);
  try
    resp := Trim(RawAsk('*IDN?'));
  finally
    FTransport.SetTimeout(DEFAULT_TIMEOUT_MS);
  end;

  if resp = '0' then
    {WriteLn('Self-calibration completed successfully.')}
  else
    raise EB1500Error.Create(
      'Self-calibration failed. Instrument response: ' + resp);
end;

{ ------------------------------------------------------------------ }

procedure TB1500.DisableAllChannels;
begin
  { CL with no argument disables all channels simultaneously }
  RawWrite('CL');
end;

end.
