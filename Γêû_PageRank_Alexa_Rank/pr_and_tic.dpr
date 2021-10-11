program pr_and_tic;

uses
  Forms,
  uMain in 'uMain.pas' {prticMainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TprticMainForm, prticMainForm);
  Application.Run;
end.
