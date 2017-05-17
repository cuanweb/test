{-----------------------------------------------------------------------------
  Unit Name: udm
  History:
    o> 29 Nov 2016 (Hary)
       * font grid di schTemplate dijadikan bold sesuai permintaan Prima
       * (+) property DisplayFormatRp di schTemplate
         tujuannya semua sch yang bertipe rupiah (float), akan diseragamkan
         displayformatnya
    o> 22 Jan 2016 (Hary) :
       * bug pada conn.Log, dimana pada waktu mengambil param dari con,
         lupa mengambil nilai isEncryptednya juga
         cari code // @ by hary @22-Jan-2016
    o> 22 Juni 2015 (Hary) :
       -> mengganti user dan password di UserDB
    o> 25 Maret 2015 (Hary) :
       -> menambahan include DaftarDefine.Inc
    o> 7 Jan 2014 : (Hary)
       >> Menambahkan directive EnableLogTrans
          yang berfungsi untuk mencatat sql statement yang akan diexecute
          dikontrol dengan property SimpanLog
-----------------------------------------------------------------------------}

unit udm;

{$INCLUDE DaftarDefine.inc}

interface

uses
  SysUtils, Classes, DBXpress, DB, SqlExpr, uQSoftEmbededConst,
  uMySQLDataset, uQSoftButton, ImgList, Controls, uQSoftBtnBmp, Graphics,
  uQSoftMsgDlgSetting, uQSoftSearchDataSet, uQSoftPreview, Dialogs,
  DBClient, Provider, ActnList, XPStyleActnCtrls, ActnMan,
  uQSoftTextPrinterClient{, uMySQL};

type
  TDBConn = record
    Host,
    Database : String;
    Port: Integer;
  end;

  TMyProcedureCetak = procedure(Sender: TObject) of object;

  TActiveConServer = (acsSatu, acsDua);
  Tdm = class(TDataModule)
    ecConnDB: TEmbededConst;
    con: TQSoftMySQLConnection;
    imgLstMenu: TImageList;
    imgLst: TImageList;
    settingMsgDlg1: TQSoftMsgDlgSetting;
    resVista1: TQSoftTileResBtnBmp;
    schTemplate: TQSoftSearchDataSet;
    query: TQSoftMySQLDataset;
    resVistaGede: TQSoftTileResBtnBmp;
    resKosong: TQSoftResBtnBmp;
    resVistaDipakeJuga: TQSoftTileResBtnBmp;
    preview: TQSoftPreview;
    PrintDialog1: TPrintDialog;
    resCloseButton: TQSoftResBtnBmp;
    ActionManager1: TActionManager;
    actNewItem: TAction;
    actNewCust: TAction;
    actNewSupp: TAction;
    actNewArea: TAction;
    actNewTipeItem: TAction;
    actNewSalesman: TAction;
    ecUserDB: TEmbededConst;
    actNewWarehouse: TAction;
    ecConnHRD: TEmbededConst;
    ecConnDB2: TEmbededConst;
    tpcPrint: TQSoftTextPrinterClient;
    ecSpecialSettings: TEmbededConst;
    conLog: TQSoftMySQLConnection;

    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
    procedure conBeforeExecuteSQL(Sender: TObject; SQL: String);
    procedure previewPrintExecute(AReport: TStrings);
    procedure mCustNamaGetText(Sender: TField; var Text: String;
      DisplayText: Boolean);
  private
    { Private declarations }
    FconnDB, FconnDB2: TDBConn;

    // remarked by hary @06-Sep-2016 13:06
    // declared but never used anymore, so remarked
    {FBrowseItem,
    FBrowseItemKonsinyasi,
    FBrowseItemNonStok,}

    FDoCetakKePrinter: TMyProcedureCetak;
    FActiveConServer: TActiveConServer;
    FActiveUsername: String;
    //FLockWaitInSec: Integer; // remarked by hary @02-Nov-2016 21:13, declared but never used
    FSimpanLog: Boolean;
    FLogFileListLoginName: TStrings;
    FNamaTerminalFromKonfigFile: String; 
    procedure BacaKonfigParamFiles; // @ by hary @18-Oct-2016 13:04
    procedure BacaParamFromFiles;
    procedure SetDoCetakKePrinter(const Value: TMyProcedureCetak);
    procedure SetActiveConServer(const Value: TActiveConServer);
    procedure SetActiveUsername(const Value: String);
    procedure SetNamaTerminalFromKonfigFile(const Value: String);
    function GetNamaTerminalFromKonfigFile: String;
  public
    { Public declarations }
    function QueryInt(SQL: string; ValueIfNull: integer): integer;
    function QueryString(SQL: string; ValueIfNull: String): String;
    function QueryDateTime(SQL: string; ValueIfNull: TDateTime): TDateTime;

    // @ by Hariyanto @22-Oct-2014
    function GetValuesSpecialSettings(KeyValue, DefaultValue: string): String;

    function GetServerTime: TDateTime;
    function GetServerDate: TDate;

    procedure AddLoginToLoginList(_newLoginName: String); // @ by Yugga @20-Agust-2015

    property NamaTerminalFromKonfigFile: String read GetNamaTerminalFromKonfigFile write SetNamaTerminalFromKonfigFile;

    property DoCetakKePrinter: TMyProcedureCetak read FDoCetakKePrinter write SetDoCetakKePrinter;
    property ActiveConServer: TActiveConServer read FActiveConServer write SetActiveConServer;
    property ActiveUsername: String read FActiveUsername write SetActiveUsername;

    property SimpanLog: Boolean read FSimpanLog write FSimpanLog; // @ by Hary @07-Jan-2015
  end;

const
  NAMA_FILE_INI = 'conn.ini';
  NAMA_FILE_ENC = '';
  SP_SETTINGS_ENC = 'specialSettings.enc';

var
  dm: Tdm;

implementation

uses
  IniFiles, Forms, uLibQSoft, StrUtils, Printers, uQSoftReports, uConst,
  uUser, StdCtrls;

{$R *.dfm}

{ Tdm }

{-----------------------------------------------------------------------------
  Procedure : GetValuesSpecialSettings
  Author    : Hariyanto
  Date      : 22-Oct-2014
  Arguments : KeyValue: string
  Result    : String  
  Notes     : untuk menghasilkan nilai yang ada di dalam ecSpecialSettings
-----------------------------------------------------------------------------}
function Tdm.GetValuesSpecialSettings(KeyValue, DefaultValue: String): String;
var
  namaFile: String;
begin
  namaFile := SP_SETTINGS_ENC;

  try
    if FileExists(namaFile) then
      ecSpecialSettings.LoadFromFile(namaFile);
  finally

  end;
  try
    Result := ecSpecialSettings.Values[KeyValue];
  except
    Result := DefaultValue;
  end;
end;

procedure Tdm.BacaParamFromFiles;
var
  ini: TIniFile;
  namaFile, namaFileConnDB: String;
begin
  namaFile := NAMA_FILE_ENC;
  if (namaFile = '') then
    namaFile := Format('conn%s.enc',
      [ChangeFileExt(ExtractFileName(ParamStr(0)),'')]);

  if FileExists(namaFile) then
  begin
    ecConnDB.LoadFromFile(namaFile);
    FconnDB.Host := ecConnDB.Values['Host'];
    TryStrToInt(ecConnDB.Values['Port'], FconnDB.Port);
    FconnDB.Database := ecConnDB.Values['Database'];
  end
  else
  begin
    namaFile := ExtractFilePath(ParamStr(0)) + NAMA_FILE_INI;
    ini := TIniFile.Create(namaFile);
    try
      FconnDB.Host := Ini.ReadString( 'Connection', 'HostName', con.Host);
      FconnDB.Database  := Ini.ReadString( 'Connection', 'Database', con.Database);
      FconnDB.Port := Ini.ReadInteger( 'Connection', 'Port', con.Port);
    finally
      ini.Free;
    end;
  end;

  namaFileConnDB := 'connUserDB.enc';
  if FileExists(namaFileConnDB) then // load file .enc
    ecUserDB.LoadFromFile(namaFileConnDB)
  else // load file .ini
  begin
    namaFile := ExtractFilePath(ParamStr(0)) +
      StringReplace(ExtractFileName(namaFileConnDB), '.enc', '.ini', []);
    ini := TIniFile.Create(namaFile);
    try
      ecUserDB.Values['user'] := Ini.ReadString('UserDB', 'user', ecUserDB.Values['user']);
      ecUserDB.Values['password'] := Ini.ReadString('UserDB', 'password', ecUserDB.Values['password']);
      ecUserDB.Values['isencrypted'] := Ini.ReadString('UserDB', 'isencrypted', ecUserDB.Values['isencrypted']);
    finally
      ini.Free;
    end;
  end;

  BacaKonfigParamFiles; // @ by hary @18-Oct-2016 13:04
end;

procedure Tdm.DataModuleCreate(Sender: TObject);
var
  //userName, password: string;
  sukses, programDihentikan: Boolean;
  {$IFDEF EnableLogTrans}
  cmd: String;
  {$ENDIF}
  namafile: string; // @ by Yugga @20-Agust-2015
begin
  // merubah setting & interface dari message dialog
  LibQSoft.MsgDlgSetting := settingMsgDlg1;
  LibQSoft.CultureID := CULTURE_INDONESIA;

  {$IFNDEF Prototype}
  repeat
    sukses := False;
    programDihentikan := False;

    BacaParamFromFiles;

    con.IsEncrypted := StrToBool(ecUserDB.Values['isencrypted']); // @ by hary @06-Apr-2016 17:36

    try
      con.Connected := False; // @ by hary @16-Oct-2013,
      // bila tidak baris diatas, maka param2 dibawah seakan2 tidak dibaca bila pada saat designTime connected=true

      con.Host := FconnDB.Host;
      con.Port := FconnDB.Port;
      con.Database := FconnDB.Database;

      con.User := ecUserDB.Values['User'];
      con.Password := ecUserDB.Values['Password'];

      (*ShowMessageFmt(
        'Host = %s'#13 +
        'Port = %d'#13 +
        'DB = %s'#13 +
        'User = %s',
        [con.Host,
         con.Port,
         con.Database,
         con.User
        ]
      );*)
      con.Open;
      if not con.Connected then
        Abort
      else
        sukses := True;

      {$IFDEF EnableLogTrans}
      conLog.Close;
      conLog.Host := con.Host;
      conLog.Database := con.Database;
      conLog.Password := con.Password;
      conLog.User := con.User;
      conLog.Port := con.Port;
      conLog.IsEncrypted := con.IsEncrypted; // @ by hary @22-Jan-2016 14:29

      (*ShowMessageFmt(
        'Host = %s'#13 +
        'Port = %d'#13 +
        'DB = %s'#13 +
        'User = %s',
        [conLog.Host,
         conLog.Port,
         conLog.Database,
         conLog.User
        ]
      );*)
      
      conLog.Open;
      if not conLog.Connected then
        Abort;

      // @ by Hary @07-Jan-2015
      //create log sql
      FSimpanLog := False;
      cmd :=
        'CREATE TABLE IF NOT EXISTS Log ( '#13 +
        '  IDLog integer NOT NULL AUTO_INCREMENT, '#13 +
        '  Tanggal DATETIME NOT NULL, '#13 +
        '  UserName varchar(16) NOT NULL, '#13 +
        '  FormName varchar(255) NOT NULL, '#13 +
        '  SQLStatement TEXT NOT NULL, '#13 +
        '  PRIMARY KEY (IDLog) '#13 +
        ') '#13;
      dm.con.Execute(cmd);
      ////////////////////////////////////////////
      {$ENDIF}
    except
    on ex: Exception do
      programDihentikan :=
        LibQSoft.MyMessageDlg(
          Format(
            'Gagal terhubung ke database server' + #13 +
            '(%s: %s)' + #13 +
            'Cek parameter file [conn.ini] yang ada pada folder aplikasi' + #13 +
            #13 +
            'Tekan tombol [Ulangi] untuk mencoba ulang proses koneksi ke server' + #13 +
            'Tekan tombol [OK] untuk mengakhiri program ini',
            [ex.ClassName,
            ex.Message]),
          mtError,
          [mbOK, mbRetry],
          ['&OK', '&Ulangi'],
          ' Gagal Terhubung',
          1
        ) = mrOk;
    end;
  until sukses or programDihentikan;
  if programDihentikan then
    Application.Terminate;
  {$ENDIF}

  // @ by Yugga @20-Agust-2015
  namafile := 'DafatrLogin.log';
  FLogFileListLoginName := TStringList.Create;
  if FileExists(namafile) then
    FLogFileListLoginName.LoadFromFile(ExtractFilePath(ParamStr(0)) +  'DaftarLogin.log');
end;

procedure Tdm.DataModuleDestroy(Sender: TObject);
begin
  //FreeAndNil(FBrowseItem);
  con.Close;
  // @ by Yugga @20-Agust-2015
  FLogFileListLoginName.SaveToFile(ExtractFilePath(ParamStr(0)) +  'DaftarLogin.log');
end;

procedure Tdm.conBeforeExecuteSQL(Sender: TObject; SQL: String);
{$IFDEF QSoftLog}
var
  log: TextFile;
{$ENDIF}
{$IFDEF EnableLogTrans}
var
  cmd: String;
{$ENDIF}
begin
{$IFDEF ShowUserOnline}
  if SameText(LeftStr(SQL, Length('SELECT')), 'SELECT')
  and (Pos('NOW()', SQL) = 0) then // supaya tidak recursive karena dibawah ini ada pemanggilan GetServerTime
  begin
    con.Execute(Format(
      'UPDATE tlistpc '#13 +
      'SET '#13 +
      '  LastActive = ''%s'', '#13 + // @ by hary @23-Jul-2014
      '  UserActive = ''%s'' '#13 + // @ by hary @23-Jul-2014
      'WHERE '#13 +
      '  IPAddress = ''%s'' '#13,
      [
       LibQSoft.SafeText(FormatDateTime('yyyy-MM-dd hh:mm:ss', dm.GetServerTime)), // @ by hary @23-Jul-2014
       LibQSoft.SafeText(ActiveUsername), // @ by hary @23-Jul-2014
       LibQSoft.SafeText(LibQSoft.GetIPAddress)
      ]));
  end;
{$ENDIF}

{$IFDEF EnableLogTrans}
  SQL := Trim(SQL);
  if not SameText(LeftStr(SQL,
    Length('SELECT')), 'SELECT')
    and not SameText(LeftStr(SQL,
      Length('SHOW')), 'SHOW') then
  begin
    if FSimpanLog then
    begin
      cmd := Format(
        'INSERT INTO Log (Tanggal, UserName, FormName, SQLStatement) '#13 +
        'Values(''%s'', ''%s'', ''%s'', ''%s'') '#13,
        [FormatDateTime('yyyy-MM-dd hh:mm:ss', Now),
          User.UserName,
         'TransJualDO',
         StringReplace(SQL, '''', '"', [rfReplaceAll])]);
      dm.conLog.Execute(cmd);
    end;
  end;
{$ENDIF}  

  {$IFDEF QSoftLog}
  SQL := Trim(SQL);
  if not SameText(LeftStr(SQL,
    Length('SELECT')), 'SELECT')
    and not SameText(LeftStr(SQL,
      Length('SHOW')), 'SHOW') then
  begin
    AssignFile(log, Application.ExeName + '.log');
    {$I--}
    Append(log);
    {$I++}
    if (IOResult <> 0) then
      Rewrite(log);
    Writeln(log, SQL + ';');
    CloseFile(log);
  end;
  {$ENDIF}
end;

procedure Tdm.previewPrintExecute(AReport: TStrings);
var
  {cmdLine, }appPath, curDir: String;
  //hasil: Integer;
  memStream: TMemoryStream;
begin
  if (Assigned(FDoCetakKePrinter)) then
    DoCetakKePrinter(nil)
  else
  begin
    curDir := GetCurrentDir;
    appPath := ExtractFilePath(ParamStr(0));
  //  AReport.SaveToFile(appPath + NAMA_FILE_PRINTING);
    memStream := TMemoryStream.Create;

    // khusus untuk project ini, untuk menghilangkan 1 baris plg akhir yang berlebih
    AReport.Delete(AReport.Count-1);
    // khusus untuk project ini, untuk menghilangkan semua FF supaya printer tidak menggulung kertas
    AReport.Text := StringReplace(AReport.Text, EPSON_SET_FORMFEED, '', [rfReplaceAll]);
    AReport.Add(EPSON_SET_FORMFEED);

    AReport.SaveToFile(appPath + 'test.txt');
    AReport.SaveToStream(memStream);
    //memStream.SetSize(memStream.Size - 2);
    //memStream.SaveToFile(appPath + 'test.txt');

    memStream.Seek(0, soFromBeginning);
    if PrintDialog1.Execute then
    begin
      LibQSoft.Cetak(Printer.Printers[Printer.PrinterIndex], Application.ExeName, memStream);
      LibQSoft.MyMessageDlg('Data telah dikirim ke printer', mtInformation, [mbOK], ['OK']);
    end;

    memStream.Free;
  end;
end;

function Tdm.QueryDateTime(SQL: string; ValueIfNull: TDateTime): TDateTime;
begin
  query.Close;
  query.CommandText := SQL;
  query.Open;
  if query.Eof
  or query.Fields[0].IsNull
  or not (query.Fields[0] is TDateTimeField) then
    Result := ValueIfNull
  else
    Result := query.Fields[0].AsDateTime;
  query.Close;
end;

function Tdm.QueryInt(SQL: string; ValueIfNull: integer): integer;
begin
  query.Close;
  query.CommandText := SQL;
  query.Open;
  if query.Eof
  or query.Fields[0].IsNull
  or not (query.Fields[0] is TIntegerField) then
    Result := ValueIfNull
  else
    Result := query.Fields[0].AsInteger;
  query.Close;
end;

function Tdm.QueryString(SQL, ValueIfNull: String): String;
begin
  query.Close;
  query.CommandText := SQL;
  query.Open;
  if query.Eof
  or query.Fields[0].IsNull
  or not (query.Fields[0] is TStringField) then
    Result := ValueIfNull
  else
    Result := query.Fields[0].AsString;
  query.Close;
end;

function Tdm.GetServerTime: TDateTime;
begin
  Result := QueryDateTime('SELECT NOW()', Now);
end;

procedure Tdm.mCustNamaGetText(Sender: TField; var Text: String;
  DisplayText: Boolean);
var
  sfPrefixNama, sfNama: TStringField;
begin
  inherited;
  sfNama := Sender as TStringField;
  sfPrefixNama := (sfNama.DataSet as TClientDataSet).FieldByName('PrefixNama') as TStringField;
  if DisplayText
  and (Trim(sfPrefixNama.Value) <> '') then
    Text := Trim(sfPrefixNama.Value) + ' ' + sfNama.Value
  else
    Text := sfNama.Value;
end;

procedure Tdm.SetDoCetakKePrinter(const Value: TMyProcedureCetak);
begin
  FDoCetakKePrinter := Value;
end;

function Tdm.GetServerDate: TDate;
begin
  Result := queryDateTime('SELECT CURDATE()', Date);
end;

procedure Tdm.SetActiveConServer(const Value: TActiveConServer);
begin
  FActiveConServer := Value;
  case Value of
    acsSatu :
    begin
      con.Connected := False; // @ by hary @16-Oct-2013,
      // bila tidak baris diatas, maka param2 dibawah seakan2 tidak dibaca bila pada saat designTime connected=true

      con.Host := FconnDB.Host;
      con.Port := FconnDB.Port;
      con.Database := FconnDB.Database;

      con.User := ecUserDB.Values['User'];
      con.Password := ecUserDB.Values['Password'];
      con.Open;
      if not con.Connected then
      begin
        ShowMessage('Gagal terhubung ke server');
        Abort;
      end;
    end;

    acsDua :
    begin
      con.Connected := False; // @ by hary @16-Oct-2013,
      // bila tidak baris diatas, maka param2 dibawah seakan2 tidak dibaca bila pada saat designTime connected=true

      con.Host := FconnDB2.Host;
      con.Port := FconnDB2.Port;
      con.Database := FconnDB2.Database;

      con.User := ecUserDB.Values['User'];
      con.Password := ecUserDB.Values['Password'];
      con.Open;
      if not con.Connected then
      begin
        ShowMessage('Gagal terhubung ke server');
        Abort;
      end;
    end;
  end;
end;

procedure Tdm.SetActiveUsername(const Value: String);
begin
  FActiveUsername := Value;
end;

procedure Tdm.AddLoginToLoginList(_newLoginName: String);
var
  i: Integer;
  namauser: string;
begin
  // cek dulu apakah _newLoginName sudah pernah ada di listbox
  // FLogFileListLoginName.IndexOf() kalau hasilnya >= 0 itu artinya ditemukan di listbox nya
  // kalau belum pernah ada, maka add ke listbox
  //FLogFileListLoginName.LoadFromFile(ExtractFilePath(ParamStr(0)) +  'DaftarLogin.log');

  for i := 0 to FLogFileListLoginName.Count - 1 do
  begin
    namauser := FLogFileListLoginName.Strings[i];
    if FLogFileListLoginName.IndexOf(namauser) = 0 then
      FLogFileListLoginName.Append(_newLoginName);
  end;

end;

procedure Tdm.BacaKonfigParamFiles;
var
  ini: TIniFile;
  namaFile: String;
begin
  // generate nama file sesuai nama project
  namaFile := Format('param%s.ini', [ChangeFileExt(ExtractFileName(ParamStr(0)),'')]);
  // generate nama file sesuai folder tempat project bin berada
  namaFile := ExtractFilePath(ParamStr(0)) + namaFile;
  ini := TIniFile.Create(namaFile);
  try
    FNamaTerminalFromKonfigFile := ini.ReadString( 'kasir', 'Terminal', LibQSoft.GetHostName);
    //ShowMessage(FNamaTerminalFromKonfigFile);
  finally
    ini.Free;
  end;
end;

procedure Tdm.SetNamaTerminalFromKonfigFile(const Value: String);
var
  ini: TIniFile;
  namaFile: String;
begin
  FNamaTerminalFromKonfigFile := Value;

  namaFile := Format('param%s.ini', [ChangeFileExt(ExtractFileName(ParamStr(0)),'')]);
  ini := TIniFile.Create(namaFile);
  try
    ini.WriteString( 'kasir', 'Terminal', FNamaTerminalFromKonfigFile);
  finally
    ini.Free;
  end;
end;

function Tdm.GetNamaTerminalFromKonfigFile: String;
begin
  Result := FNamaTerminalFromKonfigFile;
end;

end.
