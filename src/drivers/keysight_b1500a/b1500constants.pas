unit B1500Constants;

{
  b1500_constants.pas
  -------------------
  Integer constants and enumerated types used by the B1500A FLEX command set.

  Sources:
    Keysight B1500A Programming Guide (Edition 7)
    QCoDeS qcodes/instrument_drivers/Keysight/keysightb1500/constants.py
}


interface

type

  { ------------------------------------------------------------------ }
  { Channel numbers (slot * 10 + channel-within-slot)                  }
  { For B1511B in slot 1 → channel 1; slot 2 → channel 2; etc.        }
  { ------------------------------------------------------------------ }
  TChannelNr = 1..10;

  { ------------------------------------------------------------------ }
  { Voltage output range  (DV command, irange/vrange parameter)         }
  { 0 = AUTO; positive values = fixed range in V                        }
  { ------------------------------------------------------------------ }
  TVOutputRange = (
    vorAuto        = 0,    { auto ranging }
    vorFix2mV      = 11,   {  2 mV range  (B1511B only) }
    vorFix20mV     = 12,   { 20 mV range  }
    vorFix200mV    = 13,   { 200 mV range }
    vorFix2V       = 14,   {   2 V range  }
    vorFix20V      = 15,   {  20 V range  }
    vorFix40V      = 16,   {  40 V range  }
    vorFix100V     = 17,   { 100 V range  }
    vorFix200V     = 18    { 200 V range  }
  );

  { ------------------------------------------------------------------ }
  { Voltage measurement range  (TV command, vrange parameter)           }
  { ------------------------------------------------------------------ }
  TVMeasRange = (
    vmrAuto        = 0,
    vmrFix2mV      = 11,
    vmrFix20mV     = 12,
    vmrFix200mV    = 13,
    vmrFix2V       = 14,
    vmrFix20V      = 15,
    vmrFix40V      = 16,
    vmrFix100V     = 17,
    vmrFix200V     = 18
  );

  { ------------------------------------------------------------------ }
  { Current measurement range  (TI command, irange parameter)           }
  {  0  = AUTO                                                           }
  {  Positive values = fixed range in Amperes (see table below)          }
  {   8 =   1 nA                                                         }
  {   9 =  10 nA                                                         }
  {  10 = 100 nA                                                         }
  {  11 =   1 µA                                                         }
  {  12 =  10 µA                                                         }
  {  13 = 100 µA                                                         }
  {  14 =   1 mA                                                         }
  {  15 =  10 mA                                                         }
  {  16 = 100 mA                                                         }
  {  17 =   1 A   (B1511B limited to 100 mA)                             }
  { ------------------------------------------------------------------ }
  TIMeasRange = (
    imrAuto   =  0,
    imr1nA    =  8,
    imr10nA   =  9,
    imr100nA  = 10,
    imr1uA    = 11,
    imr10uA   = 12,
    imr100uA  = 13,
    imr1mA    = 14,
    imr10mA   = 15,
    imr100mA  = 16,
    imr1A     = 17
  );

  { ------------------------------------------------------------------ }
  { UNT query mode                                                       }
  { ------------------------------------------------------------------ }
  TUNTMode = (
    untModuleInfoOnly = 0,
    untModuleAndADC   = 1
  );

  { ------------------------------------------------------------------ }
  { FMT response data type characters                                    }
  { ------------------------------------------------------------------ }
  TFMTDataType = (
    dtCurrent = 0,   { 'I' }
    dtVoltage = 1    { 'V' }
  );

  { ------------------------------------------------------------------ }
  { Measurement status characters returned in FMT1 responses            }
  { ------------------------------------------------------------------ }
  TMeasurementStatusEnum = (
    msNormal          ,   { 'N',0 – normal }
    msCompliance      ,   { 'C',1 – compliance }
    msForceSideOvf    ,   { 'T',2 – force side overflow }
    msMeasSideOvf     ,   { 'V',3 – measure side overflow }
    msOscillation     ,   { 'O',4 – oscillation }
    msSearchComplete  ,   { 'F',5 – search complete }
    msSearchFailed    ,   { 'G',6 – target not found }
    msSelfCalFailed   ,   { 'X',7 – self-cal in progress }
    msInvalid
  );



const
  { String equivalents used when parsing }
  MeasStatusChar : array[TMeasurementStatusEnum] of Char = (
    'N','C','T','V','O','F','G','X',#0
  );

  MeasStatusOrd : array[TMeasurementStatusEnum] of Integer = (0,1,2,3,4,5,6,7,99);

  { Known B1511B model string as returned by UNT? }
  MODEL_B1511B = 'B1511B';
  MODEL_B1511A = 'B1511A';

implementation

end.
