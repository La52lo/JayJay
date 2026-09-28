unit B1500Module;

{
  b1500_module.pas
  ----------------
  Response parsers and base types for B1500A modules.

  Mirrors:
    QCoDeS keysightb1500/KeysightB1500_module.py
      - _FMTResponse  (namedtuple)
      - fmt_response_base_parser
      - parse_spot_measurement_response
      - parse_module_query_response

  Fixes vs first version
  ----------------------
  * Removed the forward-declared local IfThen function that conflicted
    with its own call site (type mismatch: Boolean + Integer overloads).
    DataType assignment now uses an explicit if/else, removing the need
    for IfThen entirely.
  * ParseFMTToken now handles the case where the FMT header data-type
    character is 'I' (current) explicitly, rather than treating any
    non-'V' char as current. This matches the B1500 spec.
  * ParseFMTResponse uses a local TStringList rather than relying on the
    DelimitedText property, which behaves differently across FPC versions
    with respect to whitespace.

  FMT 1,0 response format (ASCII with header)
  --------------------------------------------
  Each data point is a 13-character token:
    Position 0   : Status char  (N C T V O F G X)
    Position 1   : Channel char (A=ch1 … J=ch10, or 1-9, 0=ch10)
    Position 2   : Data type    (I = current, V = voltage)
    Positions 3+ : Value        (±ddd.ddddddE±dd)
  Multiple tokens are comma-separated in the response string.
}



interface

uses
  SysUtils, Classes, B1500Constants;

type
  { Equivalent of QCoDeS _FMTResponse namedtuple }
  TFMTResponse = record
    Value    : Double;
    Status   : TMeasurementStatusEnum;
    Channel  : Integer;      { 1-10, or -1 if no header }
    DataType : TFMTDataType;
  end;

  TFMTResponseArray = array of TFMTResponse;

  { Slot → model string as returned by ParseModuleQueryResponse }
  TSlotModel = record
    SlotNr : Integer;
    Model  : string;
  end;
  TSlotModelArray = array of TSlotModel;

{ Parse a single FMT1,x token such as "NAI+1.234567E-02".
  Raises EConvertError on unexpected format.                  }
function ParseFMTToken(const token: string): TFMTResponse;

{ Parse a complete comma-separated FMT response string. }
function ParseFMTResponse(const raw: string): TFMTResponseArray;

{ Convenience: return just the Double value from the first token.
  This is what parse_spot_measurement_response does in QCoDeS.   }
function ParseSpotMeasurement(const raw: string): Double;

{ Parse the UNT? 0 response into a slot→model array.
  Response format: "B1511B,0;B1511B,0;0,0;..."  (10 entries).   }
function ParseModuleQueryResponse(const raw: string): TSlotModelArray;

{ Convert a FMT channel character to an integer channel number 1-10. }
function ChannelCharToInt(c: Char): Integer;

{ Convert a FMT status character to TMeasurementStatus. }
function StatusCharToEnum(c: Char): TMeasurementStatusEnum;

implementation

{ ------------------------------------------------------------------ }

function StatusCharToEnum(c: Char): TMeasurementStatusEnum;
var
  s : TMeasurementStatusEnum;
begin
  for s := Low(TMeasurementStatusEnum) to High(TMeasurementStatusEnum) do
    if MeasStatusChar[s] = c then
    begin
      Result := s;
      Exit;
    end;
  Result := msInvalid;
end;

function ChannelCharToInt(c: Char): Integer;
begin
  case c of
    'A' : Result := 1;
    'B' : Result := 2;
    'C' : Result := 3;
    'D' : Result := 4;
    'E' : Result := 5;
    'F' : Result := 6;
    'G' : Result := 7;
    'H' : Result := 8;
    'I' : Result := 9;
    'J' : Result := 10;
    '1'..'9' : Result := Ord(c) - Ord('0');
    '0' : Result := 10;    { channel 10 is encoded as '0' }
  else
    Result := -1;
  end;
end;

function ParseFMTToken(const token: string): TFMTResponse;
var
  t      : string;
  hasHdr : Boolean;
  valStr : string;
  dtChar : Char;
begin
  t := Trim(token);
  if t = '' then
    raise EConvertError.Create('ParseFMTToken: empty token');

  { A 3-char header is present when the first character is not a sign.
    The value field always begins with '+' or '-'.                     }
  hasHdr := (Length(t) >= 4) and (t[1] <> '+') and (t[1] <> '-');

  if hasHdr then
  begin
    Result.Status  := StatusCharToEnum(t[1]);
    Result.Channel := ChannelCharToInt(t[2]);
    dtChar         := t[3];
    { Explicit check for the two legal data-type characters }
    if dtChar = 'V' then
      Result.DataType := dtVoltage
    else if dtChar = 'I' then
      Result.DataType := dtCurrent
    else
      raise EConvertError.CreateFmt(
        'ParseFMTToken: unknown data-type char ''%s'' in token "%s"',
        [dtChar, t]);
    valStr := Copy(t, 4, MaxInt);
  end
  else
  begin
    { No header – FMT 2 or simple responses }
    Result.Status   := msNormal;
    Result.Channel  := -1;
    Result.DataType := dtCurrent;
    valStr          := t;
  end;

  { Normalise exponent delimiter (some locales emit lowercase 'e') }
  valStr := StringReplace(valStr, 'e', 'E', [rfReplaceAll]);

  { Use invariant format settings so locale decimal separator is ignored }
  Result.Value := StrToFloat(valStr);
end;

function ParseFMTResponse(const raw: string): TFMTResponseArray;
var
  parts : TStringList;
  i     : Integer;
begin
  SetLength(Result, 0);
  parts := TStringList.Create;
  try
    { Split on commas. StrictDelimiter prevents TStringList from also
      splitting on whitespace, which is the FPC default.              }
    parts.Delimiter       := ',';
    parts.StrictDelimiter := True;
    parts.DelimitedText   := raw;
    SetLength(Result, parts.Count);
    for i := 0 to parts.Count - 1 do
      Result[i] := ParseFMTToken(parts[i]);
  finally
    parts.Free;
  end;
end;

function ParseSpotMeasurement(const raw: string): Double;
var
  arr : TFMTResponseArray;
begin
  arr := ParseFMTResponse(raw);
  if Length(arr) = 0 then
    raise EConvertError.Create(
      'ParseSpotMeasurement: no tokens in response "' + raw + '"');
  Result := arr[0].Value;
end;

function ParseModuleQueryResponse(const raw: string): TSlotModelArray;
{
  UNT? 0 example (10 slots, semicolon-separated):
    "B1511B,0;B1511B,0;0,0;0,0;0,0;0,0;0,0;0,0;0,0;0,0"
  Each field is "<model>,<adc_type>" or "0,0" for an empty slot.
}
var
  slots  : TStringList;
  fields : TStringList;
  i, cnt : Integer;
  model  : string;
begin
  SetLength(Result, 0);
  cnt := 0;

  slots  := TStringList.Create;
  fields := TStringList.Create;
  try
    slots.Delimiter       := ';';
    slots.StrictDelimiter := True;
    slots.DelimitedText   := Trim(raw);

    for i := 0 to slots.Count - 1 do
    begin
      fields.Clear;
      fields.Delimiter       := ',';
      fields.StrictDelimiter := True;
      fields.DelimitedText   := Trim(slots[i]);

      if fields.Count < 1 then Continue;
      model := Trim(fields[0]);
      if (model = '') or (model = '0') then Continue;  { empty slot }

      SetLength(Result, cnt + 1);
      Result[cnt].SlotNr := i + 1;   { slots are 1-based }
      Result[cnt].Model  := model;
      Inc(cnt);
    end;
  finally
    slots.Free;
    fields.Free;
  end;
end;

end.
