unit HeatingStage;


interface

uses
  Classes, SysUtils, VisaTransport;
type
  THeatingStage = class
  private
    FAddress    : string;
    FInstrument : TVisaTransport;   { from VisaWrapper unit }
    procedure RequireConnection;
    function GetConnected: Boolean;
  public
    constructor Create(const AAddress: string);
    destructor  Destroy; override;

    procedure Connect;
    procedure Disconnect;
    procedure SetTemperature(TempC: Double);
    function  GetTemperature: Double;
    procedure AirOn;
    procedure AirOff;
    procedure Stop;

    property Address   : string read FAddress;
    property Connected : Boolean read GetConnected;
  end;

implementation

{ ------------------------------------------------------------------ }

constructor THeatingStage.Create(const AAddress: string);
begin
  try
    inherited Create;
    FAddress    := AAddress;
    FInstrument := nil;
  except
      On EVISAError do Disconnect;
  end;
end;

destructor THeatingStage.Destroy;
begin
  Disconnect;
  inherited;
end;

procedure THeatingStage.RequireConnection;
begin
  if FInstrument = nil then
    raise EInvalidOp.Create(
      'Heating stage not connected. Call THeatingStage.Connect first.');
end;


procedure THeatingStage.Connect;
begin
  FInstrument := TVisaTransport.Create(FAddress);
  {FInstrument.Open; }
  {WriteLn('Heating stage connected at ' + FAddress); }
end;

function THeatingStage.GetConnected: Boolean;
begin
  Result := (FInstrument <> nil);
end;


procedure THeatingStage.Disconnect;
begin
  if Assigned(FInstrument) then
  begin
    {FInstrument.Close;}
    FreeAndNil(FInstrument);
  end;
end;

procedure THeatingStage.SetTemperature(TempC: Double);
begin
  RequireConnection;
  FInstrument.Write(Format('TEMP%03d', [Round(TempC)]));
  FInstrument.Write('STE');
  WriteLn(Format('Heating stage target set to %.1f C', [TempC]));
end;

function THeatingStage.GetTemperature: Double;
var
  Response : string;
  Idx      : Integer;
begin
  RequireConnection;
  Response := FInstrument.Ask('STS?');
  Idx := Pos('TEMP', Response);
  if Idx = 0 then
    raise EInvalidOp.CreateFmt(
      'Unexpected heater status response: %s', [Response]);
  Result := StrToFloat(Copy(Response, Idx + 4, 6));
end;

procedure THeatingStage.AirOn;
begin
  RequireConnection;
  FInstrument.Write('AIRON');
end;

procedure THeatingStage.AirOff;
begin
  RequireConnection;
  FInstrument.Write('AIROFF');
end;

procedure THeatingStage.Stop;
begin
  RequireConnection;
  FInstrument.Write('CLE');
end;


end.

