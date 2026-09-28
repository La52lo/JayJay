object LogViewForm: TLogViewForm
  Left = 0
  Top = 0
  Caption = 'Log viewer'
  ClientHeight = 441
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poDesktopCenter
  OnShow = FormShow
  TextHeight = 15
  object Memo1: TMemo
    AlignWithMargins = True
    Left = 8
    Top = 8
    Width = 608
    Height = 425
    Margins.Left = 8
    Margins.Top = 8
    Margins.Right = 8
    Margins.Bottom = 8
    TabStop = False
    Align = alClient
    BevelKind = bkTile
    Ctl3D = False
    ParentCtl3D = False
    ReadOnly = True
    TabOrder = 0
  end
end
