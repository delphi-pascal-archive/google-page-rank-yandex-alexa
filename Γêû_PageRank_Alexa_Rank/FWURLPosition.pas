////////////////////////////////////////////////////////////////////////////////
//
//  ****************************************************************************
//  * Project   : Fangorn Wizards Lab Exstension Library v1.35
//  * Unit Name : FWURLPosition
//  * Purpose   : ����� ��� ��������� �������� ��������, ����� ���
//  *           : Yandex ���, Google Page Rank � Alexa Rank
//  * Author    : ��������� (Rouse_) ������
//  * Copyright : � Fangorn Wizards Lab 1998 - 2006.
//  * Version   : 1.00
//  * Home Page : http://rouse.drkb.ru
//  ****************************************************************************
//

unit FWURLPosition;

interface

uses
  SysUtils,
  WinInet;

type
  TDynByteArray = array of Byte;
  TAdvancedInteger = record
    LowPart, HighPart: Integer;
  end;

  TFWUrlCounter = (ucAlexa, ucGoogle, ucYandex);
  TFWUrlCounters = set of TFWUrlCounter;

  TFWURLPosition = class
  private
    FYandexTIC, FGooglePR, FAlexaRank: Integer;
  protected
    function ShrEx(Value, ShearSize: Integer): Integer;
    function AddEx(Base, Value: Integer): Integer;
    function SubEx(Base, Value: Integer): Integer;
    procedure Mix(var A, B, C: Integer);
    function GoogleChecksum(Value: TDynByteArray): Integer;
  protected
    function DelHttp(URL: String): String;
    function GetUrl(const URL: String): String;
    procedure GetYandexTIC(URL: String);
    procedure GetGooglePR(URL: String);
    procedure GetAlexaRank(URL: String);
  public
    constructor Create;
    procedure GetURLPosition(URL: String; Counters: TFWUrlCounters);
    property AlexaRank: Integer read FAlexaRank;
    property GooglePR: Integer read FGooglePR;
    property YandexTIC: Integer read FYandexTIC;
  end;

implementation

{ TFWURLPosition }

//  �������� ���� ����� � ������� �������� �����
// =============================================================================
function TFWURLPosition.AddEx(Base, Value: Integer): Integer;
var
  ABase, AValue: TAdvancedInteger;
  AResult: Integer;
begin
  ABase.LowPart := Base and $FFFFFF;
  ABase.HighPart := (Base and $7F000000) shr 24;
  if Base < 0 then
    ABase.HighPart := ABase.HighPart or $80;
  AValue.LowPart := Value and $FFFFFF;
  AValue.HighPart := (Value and $7F000000) shr 24;
  if Value < 0 then
    AValue.HighPart := AValue.HighPart or $80;
  Result := ABase.LowPart + AValue.LowPart;
  AResult := ABase.HighPart + AValue.HighPart;
  if (Result and $1000000) <> 0 then Inc(AResult);
  Result := (Result and $FFFFFF) + ((AResult and $7F) shl 24);
  if Boolean(AResult and $80) then
    Result := Result or $80000000;
end;

constructor TFWURLPosition.Create;
begin
  FAlexaRank := -1;
  FGooglePR := -1;
  FYandexTIC := -1;
end;

//  ������� �������� HTTP ���������, ���� ����
// =============================================================================
function TFWURLPosition.DelHttp(URL: String): String;
begin
  if Pos('http://', URL) > 0 then Delete(Url, 1, 7);
  Result := Copy(Url, 1, Pos('/', Url) - 1);
  if Result = '' then Result := URL;
end;

//  ��������� Alexa Rank
// =============================================================================
procedure TFWURLPosition.GetAlexaRank(URL: String);
const
  Request = 'http://data.alexa.com/data?cli=10&dat=snbamz&url=';
  http = 'http://';
var
  XMLData: String;
  AlexaRank: Integer;
begin
  URL := DelHttp(URL);
  // ����� ��� ������ �� ������� Request �������� XML ��������,
  // �� ������� ��� ����� �������� ������ ��������������� ������ REACH RANK
  XMLData := GetUrl(Request + URL);
  AlexaRank := Pos('REACH RANK="', XMLData);
  try
    if AlexaRank = 0 then Abort;
    Delete(XMLData, 1, AlexaRank + 11);
    AlexaRank := Pos('"', XMLData);
    if AlexaRank = 0 then Abort;
    FAlexaRank := StrToInt(Copy(XMLData, 1, AlexaRank - 1));
  except
    FAlexaRank := -1;
  end;
end;

//  ��������� Google Page Rank
// =============================================================================
procedure TFWURLPosition.GetGooglePR(URL: String);
const
  Request = 'http://toolbarqueries.google.com/search?' +
    'client=navclient-auto&ch=6%d&features=Rank&q=%s';
  http = 'http://';
var
  XMLData, AResult: String;
  Checksum, DataPos: Integer;
  DynArray: TDynByteArray;
begin
  if LowerCase(Copy(URL, 1, 7)) <> http then
    URL := http + URL;
  URL := 'info:' + URL;
  SetLength(DynArray, Length(URL));
  Move(URL[1], DynArray[0], Length(URL));
  try
    // ��� ��������� ��������� Google Page Rank ����������� � ���,
    // ��� � ������� ���������� ����������� �����,
    // �������������� �� ��������� URL, �� �������� ���������� ������.
    // ���� Checksum �� �� - ����� �� ��������.
    // ���������� ������� ����� ���� ������� ������
    // � ���������� ��������� ���� ����������� �����
    Checksum := GoogleChecksum(DynArray);
    XMLData := GetUrl(Format(Request, [Checksum, URL]));
    // �� � ����� ��� ����������, �� ������� ������� ��������
    // ������ �� �������� Page Rank, ����� ������ ����������
    DataPos := Pos('RANK_', UpperCase(XMLData));
    if DataPos = 0  then Abort;
    Delete(XMLData, 1, DataPos + 6);
    DataPos := Pos(':', UpperCase(XMLData));
    Delete(XMLData, 1, DataPos);
    AResult := XMLData[1];
    if Length(XMLData) > 1 then
      if XMLData[2] = '0' then
        AResult := AResult + '0';
    FGooglePR := StrToInt(AResult);
  except
    FGooglePR := -1;
  end;
end;

//  ��������� ������ �� ������ �������
// =============================================================================
function TFWURLPosition.GetUrl(const URL: String): String;
const
  HTTP_PORT = 80;
  Header = 'Content-Type: application/x-www-form-urlencoded' + sLineBreak;
var
  FSession, FConnect, FRequest: HINTERNET;
  FHost, FScript: String;
  Ansi: PAnsiChar;
  Buff: array [0..1023] of Char;
  BytesRead: Cardinal;
begin

  Result := '';
  // ��������� �������
  // ����������� ��� ����� � ��������� ��������� � �������
  FHost := DelHttp(Url);
  FScript := Url;
  Delete(FScript, 1, Pos(FHost, FScript) + Length(FHost));

  // �������������� WinInet
  FSession := InternetOpen('DMFR', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if not Assigned(FSession) then Exit;
  try
    // ������� ���������� � ��������
    FConnect := InternetConnect(FSession, PChar(FHost), HTTP_PORT, nil,
                                'HTTP/1.0', INTERNET_SERVICE_HTTP, 0, 0);
    if not Assigned(FConnect) then Exit;
    try
      // �������������� ������ ��������
      Ansi := 'text/*';
      FRequest := HttpOpenRequest(FConnect, 'GET', PChar(FScript), 'HTTP/1.0',
                                  '', @Ansi, INTERNET_FLAG_RELOAD, 0);
      if not Assigned(FConnect) then Exit;
      try
        // ��������� ���������
        if not (HttpAddRequestHeaders(FRequest, Header, Length(Header),
                                      HTTP_ADDREQ_FLAG_REPLACE or
                                      HTTP_ADDREQ_FLAG_ADD)) then Exit;
        // ���������� ������
        if not (HttpSendRequest(FRequest, nil, 0, nil, 0)) then Exit;
        // �������� �����
        FillChar(Buff, SizeOf(Buff), 0);
        repeat
          Result := Result + Buff;
          FillChar(Buff, SizeOf(Buff), 0);
          InternetReadFile(FRequest, @Buff, SizeOf(Buff), BytesRead);
        until BytesRead = 0;
      finally
        InternetCloseHandle(FRequest);
      end;
    finally
      InternetCloseHandle(FConnect);
    end;
  finally
    InternetCloseHandle(FSession);
  end;
end;

//  ������������� �������� ��������� �� ������������� �����
// =============================================================================
procedure TFWURLPosition.GetURLPosition(URL: String; Counters: TFWUrlCounters);
begin
  if ucAlexa in Counters then GetAlexaRank(URL);
  if ucGoogle in Counters then GetGooglePR(URL);
  if ucYandex in Counters then GetYandexTIC(URL);
end;

//  ��������� Alexa Rank
// =============================================================================
procedure TFWURLPosition.GetYandexTIC(URL: String);
const
  Request = 'http://bar-navig.yandex.ru/u?ver=2&show=32&url=';
  http = 'http://';
var
  XMLData: String;
  TIC: Integer;
begin
  if LowerCase(Copy(URL, 1, 7)) <> http then
    URL := http + URL;
  // ����� ��� ������ �� ������� Request �������� XML ��������,
  // �� ������� ��� ����� �������� ������ ��������������� ������ value
  XMLData := GetUrl(Request + URL);
  TIC := Pos('value="', XMLData);
  try
    if TIC = 0 then Abort;
    Delete(XMLData, 1, TIC + 6);
    TIC := Pos('"', XMLData);
    if TIC = 0 then Abort;
    FYandexTIC := StrToInt(Copy(XMLData, 1, TIC - 1));
  except
    FYandexTIC := -1;
  end;
end;

//  ������� ����������� ����� URL, �� �������� � Google Toolbar
// =============================================================================
function TFWURLPosition.GoogleChecksum(Value: TDynByteArray): Integer;
const
  GOOGLE_MAGIC = $E6359A60;
var
  I: Integer;
  A, B, C, K, Len: Integer;
begin
  A := $9E3779B9;
  B := $9E3779B9;
  C := GOOGLE_MAGIC;
  K := 0;
  Len := Length(Value);
  while Len >= 12 do
  begin
    A := AddEx(A,
      AddEx(Value[k],
      AddEx((Value[k + 1] shl 8),
      AddEx((Value[k + 2] shl 16),
      (Value[k + 3] shl 24)))));
    B := AddEx(B,
      AddEx(Value[k + 4],
      AddEx((Value[k + 5] shl 8),
      AddEx((Value[k + 6] shl 16),
      (Value[k + 7] shl 24)))));
    C := AddEx(C,
      AddEx(Value[k + 8],
      AddEx((Value[k + 9] shl 8),
      AddEx((Value[k + 10] shl 16),
      (Value[k + 11] shl 24)))));
    Mix(A, B, C);
    Inc(K, 12);
    Dec(Len, 12);
  end;
  C := AddEx(C, Length(Value));
  if Len > 10 then
    C := AddEx(C, Value[K + 10] shl 24);
  if Len > 9 then
    C := AddEx(C, Value[K + 9] shl 16);
  if Len > 8 then
    C := AddEx(C, Value[K + 8] shl 8);
  if Len > 7 then
    B := AddEx(B, Value[K + 7] shl 24);
  if Len > 6 then
    B := AddEx(B, Value[K + 6] shl 16);
  if Len > 5 then
    B := AddEx(B, Value[K + 5] shl 8);
  if Len > 4 then
    B := AddEx(B, Value[K + 4]);
  if Len > 3 then
    A := AddEx(A, Value[K + 3] shl 24);
  if Len > 2 then
    A := AddEx(A, Value[K + 2] shl 16);
  if Len > 1 then
    A := AddEx(A, Value[K + 1] shl 8);
  if Len > 0 then
    A := AddEx(A, Value[K]);

  Mix(A, B, C);
  Result := C;
end;

//  �������������� ����������� ��� �������� ����������� �����
// =============================================================================
procedure TFWURLPosition.Mix(var A, B, C: Integer);
begin
  A := SubEx(SubEx(A, B), C);
  A := A xor ShrEx(C, 13);
  B := SubEx(SubEx(B, C), A);
  B := B xor (A shl 8);
  C := SubEx(SubEx(C, A), B);
  C := C xor ShrEx(B, 13);

  A := SubEx(SubEx(A, B), C);
  A := A xor ShrEx(C, 12);
  B := SubEx(SubEx(B, C), A);
  B := B xor (A shl 16);
  C := SubEx(SubEx(C, A), B);
  C := C xor ShrEx(B, 5);

  A := SubEx(SubEx(A, B), C);
  A := A xor ShrEx(C, 3);
  B := SubEx(SubEx(B, C), A);
  B := B xor (A shl 10);
  C := SubEx(SubEx(C, A), B);
  C := C xor ShrEx(B, 15);
end;

//  ������� ����� ������
// =============================================================================
function TFWURLPosition.ShrEx(Value, ShearSize: Integer): Integer;
begin
  if Boolean(Value and $80000000) then
  begin
    Value := Value shr 1;
    Value := Value and not $80000000;
    Value := Value or $40000000;
    Result := Value shr (ShearSize - 1);
  end
  else
    Result := Value shr ShearSize;
end;

//  ��������� ���� ����� � ������� �������� �����
// =============================================================================
function TFWURLPosition.SubEx(Base, Value: Integer): Integer;
var
  ABase, AValue: TAdvancedInteger;
  AResult: Integer;
begin
  ABase.LowPart := Base and $FFFFFF;
  ABase.HighPart := (Base and $7F000000) shr 24;
  if Base < 0 then
    ABase.HighPart := ABase.HighPart or $80;
  AValue.LowPart := Value and $FFFFFF;
  AValue.HighPart := (Value and $7F000000) shr 24;
  if Value < 0 then
    AValue.HighPart := AValue.HighPart or $80;
  Result := ABase.LowPart - AValue.LowPart;
  AResult := ABase.HighPart - AValue.HighPart;
  if Result < 0 then
  begin
    Dec(AResult);
    Inc(Result, $1000000);
  end;
  Result := Result + ((AResult and $7F) * $1000000);
  if Boolean(AResult and $80) then
    Result := Result or $80000000;
end;

end.
