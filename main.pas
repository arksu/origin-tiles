unit main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Mask, JvExMask, JvToolEdit, StdCtrls, utils_xml,
  Generics.Collections, parser_utils, pngimage, math, ExtCtrls, JvComponentBase,
  JvTrayIcon;

const
  TILES_MAX = 255;
  TILE_WIDTH = 50;
  TILE_HEIGHT = 25;

type
  TTileSet = class;

  TMainForm = class(TForm)
    Button1: TButton;
    logmemo: TMemo;
    Edit1: TEdit;
    Button2: TButton;
    Timer1: TTimer;
    TrayIcon1: TJvTrayIcon;
    client_folder: TJvDirectoryEdit;
    Label1: TLabel;
    copy_files_ch: TCheckBox;

    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure TrayIcon1Click(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
    { Private declarations }
  public
    is_tracking : Boolean;
    tilesets : array [0..TILES_MAX] of TTileSet;
    track_files : array of string;
    track_files_date : array of Cardinal;

    procedure ClearTracking();
    procedure AddTracking(f : string);

    procedure ParseFile(fname : string);
    procedure MakeTexture();
    procedure MakeXML();
    procedure ClearAll();
    procedure TrackCopyFiles();
  end;

  TTile = class
    // тип тайла
    TTileType : Integer;
    // позиция на текстуре
    Pos : TPoint;
    // файл текстуры
    TextureFile : string;
    // кусок тайла
    Image : TPngImage;
    // вес
    Weight : Integer;

    // позиция на финальной текстуре
    outPos : TPoint;

    constructor Create;
    procedure LoadImage();
    function ToString() : string; override;
  end;

  TGround = class(TTile)

  end;

  TCorner = class(TTile)
    idx : Integer;
    function ToString() : string; override;
  end;

  TBorder = class(TTile)
    idx : Integer;
    function ToString() : string; override;
  end;

  TTileSet = class
  public
    ground : TList<TGround>;
    border : TList<TBorder>;
    corner : TList<TCorner>;

    constructor Create;
    destructor Destroy; override;
    function GetCount() : Integer;
  end;

var
  MainForm: TMainForm;
  log_level : Integer;

implementation

{$R *.dfm}

function currpath: string;
begin
  Result := extractfiledir(paramstr(0));
  if not IsPathDelimiter(Result, Length(Result)) then
    Result := Result + PathDelim;
end;

procedure CopyPngRect(src : TPngImage; src_point : TPoint; dst : TPngImage; dst_point : TPoint; w, h : Integer);
var
  i, j : Integer;
  palpha_line, palpha_line1 : PbyteArray;
begin
  dst.Canvas.CopyRect(Bounds(dst_point.X,dst_point.Y,w, h),
    src.Canvas, Bounds(src_point.X, src_point.Y, w, h ));

  for i := 0 to h - 1 do begin
    palpha_line1 := src.AlphaScanline[i+src_point.Y];
    palpha_line := dst.AlphaScanline[i+dst_point.Y];
    for j := 0 to w - 1 do
      palpha_line[j+dst_point.X] := palpha_line1[j+src_point.X];

  end;

end;


procedure Log(msg : string);
var
  i : Integer;
  s : string;
begin
  s := '';
  for i := 0 to log_level - 1 do
    s := s + '  ';
  MainForm.logmemo.Lines.BeginUpdate;
  MainForm.logmemo.Lines.Add(s+msg);
  MainForm.logmemo.Lines.EndUpdate;
end;

{ TMainForm }


procedure TMainForm.AddTracking(f: string);
var
  s : string;
begin
  for s in track_files do
    if (s = f) then Exit;

  SetLength(track_files, length(track_files)+1);
  track_files[Length(track_files)-1] := f;

  SetLength(track_files_date, length(track_files_date)+1);
  track_files_date[Length(track_files_date)-1] := FileAge(f);
end;

procedure TMainForm.Button1Click(Sender: TObject);
begin
  if not FileExists(currpath + Edit1.Text) then begin
    TrayIcon1.BalloonHint( 'Error', 'file not exist '+edit1.Text, btError, 5000, True);
    exit;
  end;

  is_tracking := false;
  Timer1.Enabled := False;
  ClearTracking;
  ClearAll;
  ParseFile( Edit1.Text );
end;

procedure TMainForm.Button2Click(Sender: TObject);
begin
  if not FileExists(currpath + Edit1.Text) then begin
    TrayIcon1.BalloonHint( 'Error', 'file not exist '+edit1.Text, btError, 5000, True);
    exit;
  end;

  is_tracking := True;
  Timer1.Enabled := True;
  ClearTracking;

  ParseFile(Edit1.Text);
  TrackCopyFiles;
  TrayIcon1.BalloonHint( 'Info', 'Следим за файлами...', btInfo, 5000, false);
end;

procedure TMainForm.ClearAll;
var
  i : integer;
begin
  for i := 0 to TILES_MAX do
    if tilesets[i] <> nil then begin
      tilesets[i].Free;
      tilesets[i] := nil;
    end;

end;

procedure TMainForm.ClearTracking;
begin
  SetLength(track_files, 0);
  track_files := nil;

  SetLength(track_files_date, 0);
  track_files_date := nil;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  i : Integer;

begin
  for i := 0 to TILES_MAX do
    tilesets[i] := nil;

  TrayIcon1.Hint := MainForm.Caption;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  ClearTracking;
  ClearAll;
end;

procedure TMainForm.MakeTexture;
var
  i, r, tiles_count, tw, th, ty, tx : Integer;
  tex : TPngImage;
  g : TGround;
  c : TCorner;
  b : TBorder;

  procedure AddTile(t : TTile);
  begin
    Log('add tile tx='+IntToStr(tx)+' ty='+IntToStr(ty));
    CopyPngRect(t.Image, Point(0,0), tex, Point(tx*TILE_WIDTH, ty*TILE_HEIGHT), TILE_WIDTH, TILE_HEIGHT);
    Inc(tx);

    if tx > r-1 then begin
      tx := 0;
      Inc(ty);
    end;
  end;

begin
  tiles_count := 0;
  for i := 0 to TILES_MAX do
    if tilesets[i] <> nil then
      tiles_count := tiles_count + tilesets[i].GetCount;

  r := Ceil(tiles_count / 2);
  r := Ceil(Sqrt(r));

  tw := r * TILE_WIDTH;
  th := r * 2 * TILE_HEIGHT;

  tw := ceil(math.IntPower(2, ceil((Ln(tw)/ln(2)))));
  th := ceil(math.IntPower(2, ceil((Ln(th)/ln(2)))));

  if (tw > 2048) or (th > 2048) then MessageBox(Application.Handle, 'texture more 2048!', 'error', MB_ICONERROR);

  tx := 0;
  ty := 0;
  tex := TPngImage.CreateBlank(COLOR_RGBALPHA, 8, tw, th);
  for i := 0 to TILES_MAX do
    if tilesets[i] <> nil then begin
      for g in tilesets[i].ground do
        begin
          g.outPos := Point(tx*TILE_WIDTH, ty*TILE_HEIGHT);
          AddTile(g);
        end;
      for b in tilesets[i].border do
        begin
          b.outPos := Point(tx*TILE_WIDTH, ty*TILE_HEIGHT);
          AddTile(b);
        end;
      for c in tilesets[i].corner do
        begin
          c.outPos := Point(tx*TILE_WIDTH, ty*TILE_HEIGHT);
          AddTile(c);
        end;
    end;
  tex.SaveToFile(currpath + 'tiles.png');
end;

procedure TMainForm.MakeXML;
var
  fname : string;
  f : TextFile;
  i : Integer;
  tabs : Integer;

  g : TGround;
  c : TCorner;
  b : TBorder;

  procedure write_row(s : string);
  var t : Integer; st : string;
  begin
    st := '';
    for t := 1 to tabs do
      st := st + '    ';
    writeln(f, st + s);
  end;

begin
  fname := currpath + 'tiles.xml';
  if FileExists(fname) then DeleteFile(fname);
  AssignFile(f, fname);
  Rewrite(f);

  tabs := 0;

  write_row('<?xml version=''1.0''?>');
  write_row('<list>');

  Inc(tabs);
  for i := 0 to TILES_MAX do
    if tilesets[i] <> nil then
    begin
      write_row('<tile type="'+IntToStr(i)+'" texture="tiles">');
      Inc(tabs);

      for g in tilesets[i].ground do
        write_row('<ground '+
        'w="'+IntToStr(g.Weight)+'" '+
        'pos="'+IntToStr(g.outPos.X)+
        ', '+IntToStr(g.outPos.Y)+
        '" />');

      for b in tilesets[i].border do
        write_row('<border '+
        'idx="'+IntToStr(b.idx)+'" '+
        'w="'+IntToStr(b.Weight)+'" '+
        'pos="'+IntToStr(b.outPos.X)+
        ', '+IntToStr(b.outPos.Y)+
        '" />');

      for c in tilesets[i].corner do
        write_row('<corner '+
        'idx="'+IntToStr(c.idx)+'" '+
        'w="'+IntToStr(c.Weight)+'" '+
        'pos="'+IntToStr(c.outPos.X)+
        ', '+IntToStr(c.outPos.Y)+
        '" />');

      Dec(tabs);
      write_row('</tile>');
    end;

  Dec(tabs);

  write_row('</list>');

  Flush(f);
  CloseFile(f);
end;

procedure TMainForm.ParseFile(fname: string);
var
  xml, node : TXML;
  i, ttype : Integer;
  g : TGround;
  c : TCorner;
  b : TBorder;
begin
  if not (CharInSet(fname[2], [':', '\', '/'])) then
    fname := currpath + fname;

  Log('BEGIN parse file: '+fname);
  inc(log_level);
  try
    if is_tracking then
      AddTracking(fname);

    xml := TXML.Create(fname);

    if xml.Tag = 'list' then begin
      Log('begin add tiles');

      inc(log_level);
      for i := 0 to xml.Count - 1 do
      begin
        node := xml.NodeI[i];
        //----------------------------------------------------
        if node.Tag = 'ground' then
        begin
          ttype := StrToInt(node.Params['type'].Value);

          g := TGround.Create;
          g.TTileType := ttype;
          if node.Params.Param['w'].Value <> '' then
            g.Weight := StrToInt(node.Params['w'].Value);

          g.Pos := StrToPoint(node.Params['pos'].Value);
          g.TextureFile := node.Params['file'].Value;

          g.LoadImage;

          if tilesets[ttype] = nil then
            tilesets[ttype] := TTileSet.Create;

          tilesets[ttype].ground.Add(g);

          log('ground: '+g.ToString);
        end;
        //----------------------------------------------------
        if node.Tag = 'corner' then
        begin
          ttype := StrToInt(node.Params['type'].Value);

          c := TCorner.Create;
          c.TTileType := ttype;
          if node.Params.Param['w'].Value <> '' then
            c.Weight := StrToInt(node.Params['w'].Value);
          c.Pos := StrToPoint(node.Params['pos'].Value);
          c.TextureFile := node.Params['file'].Value;
          c.idx := StrToInt(node.Params['idx'].Value);

          c.LoadImage;

          if tilesets[ttype] = nil then
            tilesets[ttype] := TTileSet.Create;

          tilesets[ttype].corner.Add(c);

          log('corner: '+c.ToString);
        end;
        //------------------------------------------------
        if node.Tag = 'border' then
        begin
          ttype := StrToInt(node.Params['type'].Value);

          b := TBorder.Create;
          b.TTileType := ttype;
          if node.Params.Param['w'].Value <> '' then
            b.Weight := StrToInt(node.Params['w'].Value);
          b.Pos := StrToPoint(node.Params['pos'].Value);
          b.TextureFile := node.Params['file'].Value;
          b.idx := StrToInt(node.Params['idx'].Value);

          b.LoadImage;

          if tilesets[ttype] = nil then
            tilesets[ttype] := TTileSet.Create;

          tilesets[ttype].border.Add(b);

          log('border: '+b.ToString);
        end;
      end;
      dec(log_level);

      Log('end add tiles');

      log('make texture...');
      inc(log_level);
      MakeTexture();
      dec(log_level);
      log('texture created!');

      log('make xml...');
      inc(log_level);
      MakeXML();
      dec(log_level);
      log('xml created!');

    end;
  finally

  end;
  dec(log_level);
  Log('END parse file: '+fname);

end;

procedure TMainForm.Timer1Timer(Sender: TObject);
var
  i : Integer;
begin
  if not is_tracking then exit;

  for i := 0 to Length(track_files)-1 do
    if FileAge(track_files[i]) <> track_files_date[i] then
    begin
      Log('Files changed!!!');
      TrayIcon1.BalloonHint( 'Изменения тайлов', 'Файл '+
      ExtractFileName(track_files[i])+' был изменен. XML обновлен', btInfo, 5000, true );
      ClearTracking;
      ClearAll;
      ParseFile(Edit1.Text);

      TrackCopyFiles;

      Break;
    end;
end;

procedure TMainForm.TrackCopyFiles;
var
  cf : string;
begin
      // надо скопировать файлы в папку с клиентом
      if copy_files_ch.Checked then begin
        cf := IncludeTrailingBackslash(client_folder.Directory);
        DeleteFile(cf + 'tiles.png');
        DeleteFile(cf + 'tiles.xml');
        CopyFile( PChar(currpath + 'tiles.png'), PChar(cf+'tiles.png'), false );
        CopyFile( PChar(currpath + 'tiles.xml'), PChar(cf+'tiles.xml'), false );
      end;

end;

procedure TMainForm.TrayIcon1Click(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin

end;

{ TResTile }

constructor TTileSet.Create;
begin
  ground := TList<TGround>.Create;
  border := TList<TBorder>.Create;
  corner := TList<TCorner>.Create;
end;

destructor TTileSet.Destroy;
var
  g : TGround;
  c : TCorner;
  b : TBorder;
begin
  for g in ground do
    g.Free;
  ground.Free;

  for c in corner do
    c.Free;
  corner.Free;

  for b in border do
    b.Free;
  border.Free;


  inherited;
end;

function TTileSet.GetCount: Integer;
begin
  Result := ground.Count + corner.Count + border.Count;
end;

{ TTile }

constructor TTile.Create;
begin
  Weight := 10;
end;

procedure TTile.LoadImage;
var
  src : TPngImage;
begin
  if MainForm.is_tracking then
    MainForm.AddTracking(currpath + TextureFile);

  src := TPngImage.Create;
  src.LoadFromFile(currpath + TextureFile);

  Image := TPngImage.CreateBlank(COLOR_RGBALPHA, 8, TILE_WIDTH, TILE_HEIGHT);

  CopyPngRect(src, Pos, Image, Point(0,0), TILE_WIDTH, TILE_HEIGHT);
  src.Free;

//  Image.SaveToFile('d:\111\'+ IntToStr(pos.X)+'x'+IntToStr(pos.Y) +'.png');
end;

function TTile.ToString: string;
begin
  Result := 'type='+IntToStr(TTileType)+' pos='+IntToStr(Pos.X)+','+IntToStr(Pos.Y)+
  ' file='+TextureFile;
end;

{ TBorder }

function TBorder.ToString: string;
begin
  Result := inherited;
  Result := Result + ' idx='+IntToStr(idx);
end;

{ TCorner }

function TCorner.ToString: string;
begin
  Result := inherited;
  Result := Result + ' idx='+IntToStr(idx);
end;

end.
