unit uMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, Wininet, ExtCtrls, StdCtrls;

type
  TprticMainForm = class(TForm)
    LabeledEdit1: TLabeledEdit;
    Button1: TButton;
    Image1: TImage;
    Image2: TImage;
    yandex: TLabel;
    google: TLabel;
    Image3: TImage;
    alexa: TLabel;
    procedure Button1Click(Sender: TObject);
  end;

var
  prticMainForm: TprticMainForm;

implementation

{$R *.dfm}

uses
  FWURLPosition;

procedure TprticMainForm.Button1Click(Sender: TObject);
var
  URLPosition: TFWURLPosition;
begin
  URLPosition := TFWURLPosition.Create;
  try
    URLPosition.GetURLPosition(LabeledEdit1.Text, [ucAlexa, ucGoogle, ucYandex]);
    yandex.Caption := 'яндекс т»÷: ' +  IntToStr(URLPosition.YandexTIC);
    google.Caption := 'Google PR: ' +  IntToStr(URLPosition.GooglePR);
    alexa.Caption := 'Alexa Rank: ' +  IntToStr(URLPosition.AlexaRank);
  finally
    URLPosition.Free;
  end;   
end;

end.
