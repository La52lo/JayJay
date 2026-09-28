object TResistanceForm: TTResistanceForm
  Left = 357
  Height = 361
  Top = 37
  Width = 639
  Caption = 'TResistanceForm'
  ClientHeight = 361
  ClientWidth = 639
  DesignTimePPI = 144
  LCLVersion = '4.6.0.0'
  object TResistanceGrid: TDBGrid
    Left = 0
    Height = 361
    Top = 0
    Width = 639
    Align = alClient
    Color = clWindow
    Columns = <    
      item
        Title.Caption = 'Name'
      end    
      item
        Title.Caption = 'R [Ohm]'
      end    
      item
        Title.Caption = 'X Chip'
      end    
      item
        Title.Caption = 'Y Chip'
      end    
      item
        Title.Caption = 'X coord'
      end    
      item
        Title.Caption = 'Y coord'
      end>
    TabOrder = 0
  end
end
