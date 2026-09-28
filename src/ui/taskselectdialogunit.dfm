object TaskSelectDialog: TTaskSelectDialog
  Left = 558
  Top = 37
  ActiveControl = OKButton
  Anchors = []
  AutoSize = True
  Caption = 'Select Task Type'
  ClientHeight = 264
  ClientWidth = 396
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Padding.Right = 10
  Padding.Bottom = 10
  DesignSize = (
    396
    264)
  TextHeight = 15
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 386
    Height = 201
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitTop = 8
    ExplicitWidth = 396
    object RadioButtonSingleAnneal: TRadioButton
      Left = 20
      Top = 20
      Width = 132
      Height = 29
      Caption = 'Single Anneal'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object RadioButtonBatchAnneal: TRadioButton
      Left = 20
      Top = 60
      Width = 127
      Height = 29
      Caption = 'Batch Anneal'
      TabOrder = 1
    end
    object RadioButtonSingleResistance: TRadioButton
      Left = 20
      Top = 100
      Width = 212
      Height = 29
      Caption = 'Single Resistance Probe'
      TabOrder = 2
    end
    object RadioButtonBatchResistance: TRadioButton
      Left = 20
      Top = 140
      Width = 207
      Height = 29
      Caption = 'Batch Resistance Probe'
      TabOrder = 3
    end
  end
  object OKButton: TButton
    Left = 184
    Top = 222
    Width = 100
    Height = 32
    Caption = 'OK'
    ModalResult = 1
    TabOrder = 1
  end
  object CancelButton: TButton
    Left = 295
    Top = 222
    Width = 84
    Height = 32
    Anchors = []
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 2
    ExplicitLeft = 304
  end
end
