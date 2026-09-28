object ResultViewerForm: TResultViewerForm
  Left = 100
  Top = 100
  Caption = 'Result Viewer'
  ClientHeight = 600
  ClientWidth = 900
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  DesignSize = (
    900
    600)
  TextHeight = 15
  object InfoPanel: TPanel
    Left = 0
    Top = 550
    Width = 900
    Height = 50
    Align = alBottom
    TabOrder = 0
  end
  object SaveButton: TButton
    Left = -6
    Top = 0
    Width = 0
    Height = 0
    Anchors = [akRight, akBottom]
    TabOrder = 2
  end
  object CloseButton: TButton
    Left = -6
    Top = 0
    Width = 0
    Height = 0
    Anchors = [akRight, akBottom]
    TabOrder = 1
  end
  object SLScope1: TSLScope
    Left = 0
    Top = 0
    Width = 900
    Height = 550
    Align = alClient
    TabOrder = 3
    Channels = <
      item
        Name = 'Channel0'
      end>
    ExplicitLeft = 240
    ExplicitTop = 152
    ExplicitWidth = 450
    ExplicitHeight = 280
  end
end
