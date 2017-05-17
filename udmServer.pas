(*-----------------------------------------------------------------------------
  Unit Name: udmServer
  Author:    hary
  Date:      17-Nov-2016
  Purpose:   koneksi khusus ke server utama untuk penjualan offline
  History:
    i> 18 Nov 2016 (Hary)
       * membedakan antara function GetServerStatus dan CekStatusServer
         Detail silahkan baca procedure header masing-masing
         Untuk CekStatusServer sekarang tidak melakukan call //con.Open;
         supaya tidak "ngefreeze" diproses menciptakan new connection
         solusi new connection skrg dibikin act/btn terpisah di uTransJualSalesPrimaRev2
    o> 17 Nov 2016 (Hary)
       * pertama x dibuat
-----------------------------------------------------------------------------*)


unit udmServer;

{$INCLUDE DaftarDefine.inc}

interface

uses
  SysUtils, Classes, DB, uMySQLDataset, uQSoftEmbededConst;

type
  TDBConn = record
    Host,
    Database : String;
    Port: Integer;
  end;

  TdmServer = class(TDataModule)
    con: TQSoftMySQLConnection;
    ecConnDB: TEmbededConst;
    ecUserDB: TEmbededConst;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
    FconnDB: TDBConn;
    FIsServerConnected: Boolean;
    procedure BacaParamFromFiles;
    procedure SetIsServerConnected(const Value: Boolean);
    function GetStatusServer: String;
  public
    { Public declarations }
    function CekStatusServer(_DoPing: Boolean): String;
    procedure DoConnectToServer;
    property IsServerConnected: Boolean read FIsServerConnected write SetIsServerConnected;
    property StatusServer: String read GetStatusServer;
  end;

const
  NAMA_FILE_INI = 'connServer.ini';
  NAMA_FILE_ENC = '';

var
  dmServer: TdmServer;

implementation

uses
  IniFiles;

{$R *.dfm}

procedure TdmServer.BacaParamFromFiles;
var
  ini: TIniFile;
  namaFile, namaFileConnDB: String;
begin
  namaFile := NAMA_FILE_ENC;
  if (namaFile = '') then
    namaFile := Format('connServer%s.enc',
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

  namaFileConnDB := 'connUserServerDB.enc';
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
end;

{-----------------------------------------------------------------------------
  Procedure: CekStatusServer
  Author:    hary
  Date:      18-Nov-2016
  Arguments: _DoPing: Boolean
  Result:    String  
  Function:  Mengecek status existing connection ke server
             Bila @_DoPing = True, maka status dicek pakai cara PING (real time)
             bila @_DoPing = False, maka status hanya membaca dari property
               FIsServerConnected, yang diset awal kali ketika con.Open sukses connected/tidak
             Juga dipengaruhi IFDEF PakaiConnectionKeServer yang
             di DEFINE di Prima-Define.Inc
-----------------------------------------------------------------------------}
function TdmServer.CekStatusServer(_DoPing: Boolean): String;
begin
  if _DoPing then
  begin
    {$IFDEF PakaiConnectionKeServer}
    try
      //con.Open;   // remarked by hary @18-Nov-2016 00:58, jangan panggil open karena makan main thread untuk bikin new connection
      (*con.Execute('DO 0');*)
      // perbaikan by hary @18-Nov-2016 00:58
      // cukup panggil con.connected yg didalamnya melakukan PING pada existing connection
      FIsServerConnected := con.Connected; // dalam connected sudah memanggil mysql.PING seharusnya
    except
      FIsServerConnected := False;
    end;
    //con.Connected := con.Ping;
    //FIsServerConnected := con.Connected;
    {$ELSE}
    FIsServerConnected := False;
    {$ENDIF}
  end;

  if FIsServerConnected then
    Result := 'Server Online'
  else
    Result := 'Server Offline';
end;

procedure TdmServer.DataModuleCreate(Sender: TObject);
begin
  {$IFDEF PakaiConnectionKeServer}
  BacaParamFromFiles;

  con.Connected := False;
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

  try
    con.Open;
  except
    FIsServerConnected := False;
  end;

  FIsServerConnected := con.Connected;
  {$ELSE}
  FIsServerConnected := False;
  {$ENDIF}
end;

procedure TdmServer.DoConnectToServer;
begin
  try
    con.Open;
  except
    FIsServerConnected := False;
  end;

  FIsServerConnected := con.Connected;
end;

{-----------------------------------------------------------------------------
  Procedure: GetStatusServer
  Author:    hary
  Date:      18-Nov-2016
  Arguments: _DoPing: Boolean
  Function:  Membaca status existing connection ke server
  Result:    String :
             > "Server Online"
             > "Server Offline"
-----------------------------------------------------------------------------}
function TdmServer.GetStatusServer: String;
begin
  if FIsServerConnected then
    Result := 'Server Online'
  else
    Result := 'Server Offline';
end;

procedure TdmServer.SetIsServerConnected(const Value: Boolean);
begin
  FIsServerConnected := Value;
end;

end.
