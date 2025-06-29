unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.OleCtrls, WMPLib_TLB, Vcl.Grids, Vcl.ComCtrls, TlHelp32,ShellAPI;

type
  TForm1 = class(TForm)
    Panel1: TPanel;
    Button1: TButton;
    ListView1: TListView;
    Panel2: TPanel;
    Button2: TButton;
    Button3: TButton;
    Btn_PlayPause: TButton;
    OpenDialog1: TOpenDialog;
    Btn_Proximo: TButton;
    Button6: TButton;
    Button7: TButton;
    LblLegenda: TLabel;
    Button8: TButton;
    Panel3: TPanel;
    Button4: TButton;
    Button5: TButton;
    btnToggleFull: TButton;
    TimerMonitorMPC: TTimer;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ListView1DblClick(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Btn_PlayPauseClick(Sender: TObject);
    procedure Btn_ProximoClick(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure Panel3Resize(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure btnToggleFullClick(Sender: TObject);
    procedure TimerMonitorMPCTimer(Sender: TObject);

  private
    { Private declarations }
    FVUMeterProcessHandle: THandle;
    CurrentIndex: Integer;
    procedure EmbedWindowContainingText(const PartialTitle: string);
  public
    { Public declarations }
    procedure StartVUMeter;
    procedure StopVUMeter;
    function FileSizeByName(const FileName: string): Int64;
    procedure CreatePlaylistWithSubtitles(const VideoFile, SubtitleFile: string; const PlaylistFile: string);
    //uso do media player classic
    procedure EmbedMPC(const VideoPath: string);
    procedure MPC_ToggleSubtitles;
    procedure MPC_AddToPlaylist(const VideoPath: string);
    procedure EmbedMPC_FullScreen(const VideoPath: string);
    procedure MPC_ToggleFullScreen;   //n�o funcionou
    procedure MPC_GoFullScreen;
    procedure MPC_ReturnToPanel;
    procedure ToggleFullScreen;
    procedure PlayNextVideo;
    procedure PlayVideoFromItem(Item: TListItem);
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

var
  FoundHWND: HWND = 0;
  SearchText: string;
  //novas para uso do MP Classic
  MPCProcessInfo: TProcessInformation;
  MPCHandle: HWND;
  MPCFullScreenMode: Boolean = False;

  function EnumWindowsProc(Wnd: HWND; lParam: LPARAM): BOOL; stdcall;
var
  Title: array[0..255] of Char;
begin
  Result := True; // Continua enumerando

  if IsWindowVisible(Wnd) then
  begin
    GetWindowText(Wnd, Title, Length(Title));
    if Pos(SearchText, string(Title)) > 0 then
    begin
      FoundHWND := Wnd;
      Result := False; // Para a enumera��o, achou a janela
    end;
  end;
end;

function FindWindowContainingText(const Text: string): HWND;
begin
  FoundHWND := 0;
  SearchText := Text;
  EnumWindows(@EnumWindowsProc, 0);
  Result := FoundHWND;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  EmbedWindowContainingText('VUMeter');
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  I: Integer;
begin
  // Remove selecionados, de tr�s pra frente para evitar problemas
  for I := ListView1.Items.Count - 1 downto 0 do
    if ListView1.Items[I].Selected then
      ListView1.Items.Delete(I);

end;

procedure TForm1.Button3Click(Sender: TObject);
var
  I: Integer;
  Item: TListItem;
  FileName: string;
  FileSize: Int64;
begin
  if OpenDialog1.Execute then
  begin
    for I := 0 to OpenDialog1.Files.Count - 1 do
    begin
      FileName := OpenDialog1.Files[I];
      if FileExists(FileName) then
      begin
        FileSize := FileSizeByName(FileName);

        Item := ListView1.Items.Add;
        Item.Caption := ExtractFileName(FileName);
        Item.SubItems.Add(FileName);
        Item.SubItems.Add(IntToStr(FileSize div 1024));
      end;
    end;
  end;

end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  MPC_ToggleSubtitles;
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
if OpenDialog1.Execute then
    MPC_AddToPlaylist(OpenDialog1.FileName);
end;

procedure TForm1.Btn_PlayPauseClick(Sender: TObject);
const
  ID_PLAYPAUSE = 889; // comando Play/Pause
begin
  if MPCHandle <> 0 then
    SendMessage(MPCHandle, WM_COMMAND, ID_PLAYPAUSE, 0);

end;

procedure TForm1.Btn_ProximoClick(Sender: TObject);
const
  ID_NEXT = 922;
begin
  if MPCHandle <> 0 then
    SendMessage(MPCHandle, WM_COMMAND, ID_NEXT, 0);
end;

procedure TForm1.Button6Click(Sender: TObject);
const
  ID_PREVIOUS = 921;
begin
  if MPCHandle <> 0 then
    SendMessage(MPCHandle, WM_COMMAND, ID_PREVIOUS, 0);
end;

procedure TForm1.Button8Click(Sender: TObject);
begin
  if OpenDialog1.Execute then
     EmbedMPC(OpenDialog1.FileName);
end;

procedure TForm1.btnToggleFullClick(Sender: TObject);
begin
//  if OpenDialog1.Execute then
//     EmbedMPC_FullScreen(OpenDialog1.FileName);
 //MPC_ToggleFullScreen; //n�o funcionou
//  MPC_GoFullScreen;
  ToggleFullScreen;
end;

procedure TForm1.CreatePlaylistWithSubtitles(const VideoFile, SubtitleFile,
  PlaylistFile: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Add('#EXTM3U');
    SL.Add(VideoFile);
    SL.Add(SubtitleFile);
    SL.SaveToFile(PlaylistFile);
  finally
    SL.Free;
  end;

end;

procedure TForm1.EmbedMPC(const VideoPath: string);
var
  StartInfo: TStartupInfo;
  CmdLine, MPCPath: string;
  Ret: Boolean;
begin
  MPCPath := '"C:\Program Files (x86)\K-Lite Codec Pack\MPC-HC64\mpc-hc64.exe"';
  CmdLine := MPCPath + ' /play /close "' + VideoPath + '"'; // <-- aqui est� o segredo

  ZeroMemory(@StartInfo, SizeOf(StartInfo));
  StartInfo.cb := SizeOf(StartInfo);
  StartInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartInfo.wShowWindow := SW_HIDE;

  if CreateProcess(nil, PChar(CmdLine), nil, nil, False, CREATE_NEW_CONSOLE, nil, nil, StartInfo, MPCProcessInfo) then
  begin
    TThread.CreateAnonymousThread(
      procedure
      begin
        Sleep(1000);
        repeat
          MPCHandle := FindWindow(nil, 'Media Player Classic Home Cinema');
          Sleep(100);
        until MPCHandle <> 0;

        // Se quiser embutir:
        Winapi.Windows.SetParent(MPCHandle, Panel3.Handle);
        SetWindowLong(MPCHandle, GWL_STYLE,
          GetWindowLong(MPCHandle, GWL_STYLE) and not WS_CAPTION and not WS_THICKFRAME);
        SetWindowPos(MPCHandle, 0, 0, 0, Panel3.Width, Panel3.Height, SWP_NOZORDER or SWP_SHOWWINDOW);

        // Inicia monitoramento
        TThread.Synchronize(nil,
          procedure
          begin
            TimerMonitorMPC.Enabled := True;
          end);
      end
    ).Start;
  end;

end;

procedure TForm1.EmbedMPC_FullScreen(const VideoPath: string);
var
  StartInfo: TStartupInfo;
  CmdLine, MPCPath: string;
  Ret: Boolean;
begin
  MPCPath := '"C:\Program Files (x86)\K-Lite Codec Pack\MPC-HC64\mpc-hc64.exe"';

  // Adiciona o argumento /fullscreen
  CmdLine := MPCPath + ' /play /fullscreen "' + VideoPath + '"';

  ZeroMemory(@StartInfo, SizeOf(StartInfo));
  StartInfo.cb := SizeOf(StartInfo);
  StartInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartInfo.wShowWindow := SW_SHOWNORMAL;

  CreateProcess(nil, PChar(CmdLine), nil, nil, False, 0, nil, nil, StartInfo, MPCProcessInfo);

end;

procedure TForm1.EmbedWindowContainingText(const PartialTitle: string);
var
  Wnd: HWND;
  style: LongInt;
begin
  Wnd := FindWindowContainingText(PartialTitle);
  if Wnd = 0 then
  begin
    //ShowMessage('Janela contendo "' + PartialTitle + '" n�o encontrada.');
    Exit;
  end;

  style := GetWindowLong(Wnd, GWL_STYLE);
  style := (style or WS_CHILD or WS_VISIBLE) and (not WS_POPUP);
  SetWindowLong(Wnd, GWL_STYLE, style);

  Winapi.Windows.SetParent(Wnd, Panel1.Handle);

  SetWindowPos(Wnd, HWND_TOP, 0, 0, Panel1.Width, Panel1.Height,
    SWP_NOZORDER or SWP_NOACTIVATE or SWP_SHOWWINDOW);

  ShowWindow(Wnd, SW_SHOW);
end;

function TForm1.FileSizeByName(const FileName: string): Int64;
var
  SR: TSearchRec;
begin
  if FindFirst(FileName, faAnyFile, SR) = 0 then
  begin
    Result := SR.Size;
    FindClose(SR);
  end
  else
    Result := 0;

end;

procedure TForm1.FormCreate(Sender: TObject);
var
  ProcInfo: TProcessInformation;
  StartInfo: TStartupInfo;
  CmdLine: array[0..MAX_PATH - 1] of Char;
  ExecPath: string;
begin
  CurrentIndex := -1;

  ExecPath := 'C:\Users\Mauricio Abreu\Downloads\vu_meter\Win32\Debug\VUMeter.exe';

  StrPLCopy(CmdLine, ExecPath, MAX_PATH - 1);  // Copia o texto para array de char

  ZeroMemory(@StartInfo, SizeOf(StartInfo));
  StartInfo.cb := SizeOf(StartInfo);
  ZeroMemory(@ProcInfo, SizeOf(ProcInfo));

  if not CreateProcess(nil, CmdLine, nil, nil, False,
    CREATE_NEW_CONSOLE or NORMAL_PRIORITY_CLASS, nil, nil, StartInfo, ProcInfo) then
  begin
    ShowMessage('Erro ao iniciar o VUMeter.');
  end;
 SendMessage(Button1.Handle, BM_CLICK, 0, 0);

  // Configura colunas do ListView
  ListView1.Columns.Clear;

  with ListView1.Columns.Add do
  begin
    Caption := 'Nome do Arquivo';
    Width := 200; // largura em pixels
  end;

  with ListView1.Columns.Add do
  begin
    Caption := 'Caminho Completo';
    Width := 400; // largura maior para o caminho
  end;

  with ListView1.Columns.Add do
  begin
    Caption := 'Tamanho (KB)';
    Width := 100; // largura para tamanho
  end;

  ListView1.ViewStyle := vsReport;
  ListView1.MultiSelect := True;

end;

procedure TForm1.FormShow(Sender: TObject);
begin
 EmbedWindowContainingText('VUMeter');
 if FVUMeterProcessHandle <> 0 then
  begin
    // Encerra o processo de forma for�ada
    TerminateProcess(FVUMeterProcessHandle, 0);
    CloseHandle(FVUMeterProcessHandle);
    FVUMeterProcessHandle := 0;
  end;
end;

procedure TForm1.ListView1DblClick(Sender: TObject);
var
  FilePath: string;
begin
  if Assigned(ListView1.Selected) and (ListView1.Selected.SubItems.Count > 0) then
  begin
    EmbedMPC(ListView1.Selected.SubItems[0]); // caminho completo
  end;

end;

procedure TForm1.MPC_AddToPlaylist(const VideoPath: string);
var
  MPCPath, CmdLine: string;
begin
  MPCPath := '"C:\Program Files (x86)\K-Lite Codec Pack\MPC-HC64\mpc-hc64.exe"';
  CmdLine := MPCPath + ' /add "' + VideoPath + '"';

  ShellExecute(0, 'open', PChar(MPCPath), PChar('/add "' + VideoPath + '"'), nil, SW_SHOWNORMAL);

end;

procedure TForm1.MPC_GoFullScreen;
const
  ID_FULLSCREEN = 897;
begin
  if MPCHandle <> 0 then
  begin
    // Remove do painel
    Winapi.Windows.SetParent(MPCHandle, 0); // Volta a ser janela independente

    // Restaura o estilo da janela (caso precise)
    SetWindowLong(MPCHandle, GWL_STYLE,
      GetWindowLong(MPCHandle, GWL_STYLE) or WS_CAPTION or WS_THICKFRAME);

    // Move para frente da tela
    SetForegroundWindow(MPCHandle);

    // Envia comando ALT+ENTER (fullscreen)
    SendMessage(MPCHandle, WM_COMMAND, ID_FULLSCREEN, 0);
  end;

end;

procedure TForm1.MPC_ReturnToPanel;
const
  ID_FULLSCREEN = 897;
begin
  if MPCHandle <> 0 then
  begin
    // Sai do modo tela cheia (Alt+Enter)
    SendMessage(MPCHandle, WM_COMMAND, ID_FULLSCREEN, 0);
    Sleep(300); // D� tempo da janela sair do full screen

    // Remove t�tulo e borda
    SetWindowLong(MPCHandle, GWL_STYLE,
      GetWindowLong(MPCHandle, GWL_STYLE) and not WS_CAPTION and not WS_THICKFRAME);

    // Reatribui o Panel como pai
    Winapi.Windows.SetParent(MPCHandle, Panel3.Handle);

    // Redimensiona para ocupar o Panel
    SetWindowPos(MPCHandle, 0, 0, 0, Panel3.Width, Panel3.Height, SWP_NOZORDER or SWP_SHOWWINDOW);
  end;

end;

procedure TForm1.MPC_ToggleFullScreen;
const
  ID_FULLSCREEN = 897; // Comando de tela cheia
begin
  if MPCHandle <> 0 then
    SendMessage(MPCHandle, WM_COMMAND, ID_FULLSCREEN, 0);

end;

procedure TForm1.MPC_ToggleSubtitles;
const
  ID_SUBTITLES_TOGGLE = 950; // Ativar/desativar legendas
begin
  if MPCHandle <> 0 then
    SendMessage(MPCHandle, WM_COMMAND, ID_SUBTITLES_TOGGLE, 0);
end;

procedure TForm1.Panel3Resize(Sender: TObject);
begin
if MPCHandle <> 0 then
    SetWindowPos(MPCHandle, 0, 0, 0, Panel3.Width, Panel3.Height, SWP_NOZORDER or SWP_SHOWWINDOW);
end;

procedure TForm1.PlayNextVideo;
var
  NextIndex: Integer;
begin
  if ListView1.ItemIndex < 0 then Exit;

  NextIndex := ListView1.ItemIndex + 1;
  if NextIndex < ListView1.Items.Count then
  begin
    ListView1.ItemIndex := NextIndex;
    ListView1.Items[NextIndex].Selected := True;
    PlayVideoFromItem(ListView1.Items[NextIndex]);
  end;

end;

procedure TForm1.PlayVideoFromItem(Item: TListItem);
var
  FullPath: string;
begin
  if Assigned(Item) and (Item.SubItems.Count > 0) then
  begin
    FullPath := Item.SubItems[0]; // Caminho completo
    if FileExists(FullPath) then
    begin
      EmbedMPC(FullPath);
      TimerMonitorMPC.Enabled := True;
    end
    else
      ShowMessage('Arquivo n�o encontrado: ' + FullPath);
  end;
end;

procedure TForm1.StartVUMeter;
var
  ProcInfo: TProcessInformation;
  StartInfo: TStartupInfo;
  CmdLine: array[0..MAX_PATH - 1] of Char;
  ExecPath: string;
begin
  ExecPath := 'C:\Users\Mauricio Abreu\Downloads\vu_meter\Win32\Debug\VUMeter.exe';
  StrPLCopy(CmdLine, ExecPath, MAX_PATH - 1);

  ZeroMemory(@StartInfo, SizeOf(StartInfo));
  StartInfo.cb := SizeOf(StartInfo);
  ZeroMemory(@ProcInfo, SizeOf(ProcInfo));

  if CreateProcess(nil, CmdLine, nil, nil, False,
    CREATE_NEW_CONSOLE or NORMAL_PRIORITY_CLASS, nil, nil, StartInfo, ProcInfo) then
  begin
    // Salva o handle do processo para depois encerrar
    FVUMeterProcessHandle := ProcInfo.hProcess;

    // Fecha os handles do thread (n�o usaremos)
    CloseHandle(ProcInfo.hThread);
  end
  else
    ShowMessage('Erro ao iniciar o VUMeter.');

end;

procedure TForm1.StopVUMeter;
begin
  if FVUMeterProcessHandle <> 0 then
  begin
    // Encerra o processo de forma for�ada
    TerminateProcess(FVUMeterProcessHandle, 0);
    CloseHandle(FVUMeterProcessHandle);
    FVUMeterProcessHandle := 0;
  end;
end;


procedure TForm1.TimerMonitorMPCTimer(Sender: TObject);
begin
if (MPCHandle <> 0) and (not IsWindow(MPCHandle)) then
  begin
    MPCHandle := 0;
    TimerMonitorMPC.Enabled := False;
    PlayNextVideo;
  end;
end;

procedure TForm1.ToggleFullScreen;
const
  ID_FULLSCREEN = 897;
begin
  if MPCHandle = 0 then Exit;

  if not MPCFullScreenMode then
  begin
    // === Entrar em tela cheia ===

    // Remove do painel
    Winapi.Windows.SetParent(MPCHandle, 0);

    // Restaura bordas/janela
    SetWindowLong(MPCHandle, GWL_STYLE,
      GetWindowLong(MPCHandle, GWL_STYLE) or WS_CAPTION or WS_THICKFRAME);

    // Traz para frente
    SetForegroundWindow(MPCHandle);

    // Entra em fullscreen (Alt+Enter)
    SendMessage(MPCHandle, WM_COMMAND, ID_FULLSCREEN, 0);

    // Marca estado
    MPCFullScreenMode := True;

    // Atualiza texto do bot�o
    btnToggleFull.Caption := 'Voltar ao Painel';
  end
  else
  begin
    // === Voltar ao painel ===

    // Sai do fullscreen
    SendMessage(MPCHandle, WM_COMMAND, ID_FULLSCREEN, 0);
    Sleep(300);

    // Remove bordas
    SetWindowLong(MPCHandle, GWL_STYLE,
      GetWindowLong(MPCHandle, GWL_STYLE) and not WS_CAPTION and not WS_THICKFRAME);

    // Volta ao painel
    Winapi.Windows.SetParent(MPCHandle, Panel3.Handle);

    // Redimensiona
    SetWindowPos(MPCHandle, 0, 0, 0, Panel3.Width, Panel3.Height, SWP_NOZORDER or SWP_SHOWWINDOW);

    // Marca estado
    MPCFullScreenMode := False;

    // Atualiza texto do bot�o
    btnToggleFull.Caption := 'Tela Cheia';
  end;

end;

end.