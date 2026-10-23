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
  TChannelNr = (
   channel_1 = 1,
   channel_2 = 2
  );

  { ------------------------------------------------------------------ }
  { Voltage output range  (DV command, irange/vrange parameter)         }
  { 0 = AUTO; positive values = fixed range in V                        }
  { ------------------------------------------------------------------ }
  TVOutputRange = (
    vorAuto        = 0,    { auto ranging }
    vorFix200mV    = 2,   {  200 mV range  (B1511B only) }
    vorFix500mV    = 5,   { 500 mV range  }
    vorFix2V       = 11,   {   2 V range  }
    vorFix5V       = 50   {  5 V range  }
  );

  { ------------------------------------------------------------------ }
  { Voltage measurement range  (TV command, vrange parameter)           }
  { ------------------------------------------------------------------ }
  TVMeasRange = (
    vmrAuto        = 0,
    vmrFix200mV    = 2,
    vmrFix2V       = 11,
    vmrFix20V      = 12
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
    imr1nA    = 11,
    imr10nA   = 12,
    imr100nA  = 13,
    imr1uA    = 14,
    imr10uA   = 15,
    imr100uA  = 16,
    imr1mA    = 17,
    imr10mA   = 18,
    imr100mA  = 19
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
  { ------------------------------------------------------------------ }
  { Setting integration time (Valid until *RST or change selection via AAD }
  { ------------------------------------------------------------------ }
  TADCType = (
    adcHighSpeed = 1,
    adcHighResolution =2
  );

  TAITMode = (
   adcAuto   = 0,
   adcManual = 1,
   adcPLC    = 2
  );



    TFilterActive = (
    filterON = 1,
    filterOFF = 2
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

  RANGE_LIMIT_1mA = -17;
  RANGE_LIMIT_10mA = -18;
  AUTORANGE_MODE_UP = 1;
  AUTORANGE_THRESHOLD_50_PERCENT =  50;


implementation

end.
