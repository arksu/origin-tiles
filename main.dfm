object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Origin tiles converter ver 0.2'
  ClientHeight = 353
  ClientWidth = 688
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    688
    353)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 376
    Top = 8
    Width = 58
    Height = 13
    Caption = 'Client folder'
  end
  object Button1: TButton
    Left = 8
    Top = 35
    Width = 75
    Height = 25
    Caption = 'Parse file'
    TabOrder = 0
    OnClick = Button1Click
  end
  object logmemo: TMemo
    Left = 1
    Top = 77
    Width = 688
    Height = 273
    Anchors = [akLeft, akTop, akRight, akBottom]
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object Edit1: TEdit
    Left = 8
    Top = 8
    Width = 121
    Height = 21
    TabOrder = 2
    Text = 'tiles_cfg.xml'
  end
  object Button2: TButton
    Left = 176
    Top = 35
    Width = 169
    Height = 25
    Caption = 'Parse and start tracking files'
    TabOrder = 3
    OnClick = Button2Click
  end
  object client_folder: TJvDirectoryEdit
    Left = 376
    Top = 27
    Width = 121
    Height = 21
    DialogKind = dkWin32
    TabOrder = 4
    Text = 'client_folder'
  end
  object copy_files_ch: TCheckBox
    Left = 376
    Top = 54
    Width = 145
    Height = 17
    Caption = 'Copy files to client folder'
    TabOrder = 5
  end
  object Timer1: TTimer
    Enabled = False
    OnTimer = Timer1Timer
    Left = 208
    Top = 120
  end
  object TrayIcon1: TJvTrayIcon
    Active = True
    IconIndex = 0
    OnClick = TrayIcon1Click
    Left = 168
    Top = 120
  end
end
