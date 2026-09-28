object ProbeConfigForm: TProbeConfigForm
  Left = 469
  Top = 37
  BorderStyle = bsDialog
  Caption = 'Probe configuration'
  ClientHeight = 387
  ClientWidth = 373
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object ProbeConfigEditor: TValueListEditor
    Left = 0
    Top = 0
    Width = 373
    Height = 350
    Align = alClient
    DefaultColWidth = 180
    DefaultRowHeight = 20
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = 18
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    Strings.Strings = (
      'Mode='
      'Starting voltage [V]=-0.01'
      'Step size [V]=0.001'
      'Number of steps=20'
      'Measure Time [s]=0.5'
      'Initial Wait [s]=1.0')
    TabOrder = 0
    ExplicitHeight = 373
    ColWidths = (
      180
      187)
  end
  object Panel1: TPanel
    Left = 0
    Top = 350
    Width = 373
    Height = 37
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitTop = 346
    DesignSize = (
      373
      37)
    object Button1: TButton
      Left = 205
      Top = 6
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object Button2: TButton
      Left = 292
      Top = 6
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
end
