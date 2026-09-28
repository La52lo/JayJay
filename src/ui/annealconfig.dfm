object AnnealConfigForm: TAnnealConfigForm
  Left = 588
  Top = 211
  Caption = 'Anneal Configuration'
  ClientHeight = 400
  ClientWidth = 800
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  TextHeight = 15
  object StringGrid1: TStringGrid
    Left = 0
    Top = 0
    Width = 800
    Height = 320
    Align = alClient
    Anchors = [akLeft, akTop, akBottom]
    ColCount = 13
    DrawingStyle = gdsClassic
    FixedColor = clLime
    RowCount = 2
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goEditing, goFixedRowDefAlign]
    TabOrder = 0
    OnKeyDown = StringGrid1KeyDown
    ColWidths = (
      96
      100
      100
      133
      132
      123
      68
      70
      144
      162
      96
      96
      96)
  end
  object Panel1: TPanel
    Left = 0
    Top = 320
    Width = 800
    Height = 30
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object Label1: TLabel
      AlignWithMargins = True
      Left = 8
      Top = 3
      Width = 104
      Height = 24
      Margins.Left = 8
      Margins.Right = 8
      Align = alLeft
      Caption = 'Junction Count'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
      ExplicitHeight = 21
    end
    object AnnealSpin: TSpinEdit
      Left = 120
      Top = 0
      Width = 80
      Height = 35
      Align = alLeft
      AutoSelect = False
      AutoSize = False
      Constraints.MaxWidth = 80
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = 0
      Font.Name = 'Segoe UI'
      Font.Style = []
      MaxValue = 2000
      MinValue = 1
      ParentFont = False
      TabOrder = 0
      Value = 1
      OnChange = AnnealSpinChange
    end
  end
  object Panel2: TPanel
    Left = 0
    Top = 350
    Width = 800
    Height = 50
    Align = alBottom
    BevelOuter = bvNone
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    TabOrder = 2
    object ApplyButton: TButton
      Left = 550
      Top = 10
      Width = 100
      Height = 32
      Caption = 'Apply'
      ModalResult = 1
      TabOrder = 0
      OnClick = ApplyButtonClick
    end
    object CancelButton: TButton
      Left = 670
      Top = 10
      Width = 100
      Height = 32
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
      OnClick = CancelButtonClick
    end
  end
end
