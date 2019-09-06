#windows update自動化

@if(0)==(0) ECHO OFF

rem ■BAT部前処理■
NET SESSION > NUL 2>&1
IF ERRORLEVEL 1 ECHO 管理者として実行していません & GOTO :EOF

rem ■初回動作記録■
eventcreate /L APPLICATION /T INFORMATION /SO "%~n0" /ID 1 /D "開始" >NUL

rem ■JScript部実行■
cscript.exe /nologo //E:JScript "%~f0" %*

rem ■BAT部後処理■
rem シャットダウンが必要な場合　60秒後にシャットダウンします
IF %ERRORLEVEL% EQU -1 shutdown /f /r /t 60

GOTO :EOF
@end
@以降がJScript
//----------------------------------------------------------
//Ver 20170201A
//除外するアップデート KB番号をセット //NOTE:サンプルとして過去のWin10強制UPD等を記述してます
var EXCLUDE_KB_IDs = [3035583,2976978,2952664,3021917];
//アップデートのみインストール(Feture pack等を無視する)
var UPDATE_ONLY = true;
//ダウンロードサーバーの指定(0:既定値,1:ローカルWSUS,2:Microsoft,3:その他)
var SERVER_SELECTION = 0;
//一度にインストールするアップデートの数
// 一気に入れようとして失敗するとRollbackが起きて悲惨なため。増加はリスク覚悟で
var MAXUPDATES = 50;

var wsh = WScript.CreateObject("WScript.Shell");
WScript.Quit(main());

//-----------------------------------------------------------
function main()
{
    try
    {
        UnregisterScript();

        var reqReboot = wu_detect();

        switch(reqReboot)
        {
            case 0:{
                LRES(80,"アップデートなし、正常終了",false);
                break;
            }
            case 1:{
                LRES(81,"アップデート実施、正常終了",false);
                break;
            }
            case 2:{
                LRES(82,"アップデート実施、Windows再起動後再実行",false);
                RegisterScript();
                return -1;
            }
        }
    }
    catch(e)
    {
        LRES(99, "！例外終了" + e.name + "(0x" + (e.number >>> 0).toString(16) + ")" + e.description , true);
        return 1;
    }

    return 0;
}
//-----------------------------------------------------------
function wu_detect()  //return 0:インストールなし、1:インストール再起動不要、2:インストール再起動要
{
    var wu_items;    //WUApiLib.ISearchResult
    var uitem;
    var RESULTSTRS = Array("未実行", "実行中", "成功", "一部失敗", "失敗", "中止");

//状態チェック
    LINF(31,"状態チェック...");

    //WU設定チェック
    var wu_au = WScript.CreateObject("Microsoft.Update.AutoUpdate");
    if(! wu_au.ServiceEnabled)throw new Error("\t自動更新が未設定または使用できない");

    //再起動要求
    var sinf = WScript.CreateObject("Microsoft.Update.SystemInfo");
    if(sinf.RebootRequired)
    {
        LINF(32,"\t再起動要求検出");
        return 2;
    }

//アップデートの検索
    LINF(33,"アップデート検索...");
    wu_au.DetectNow();
    var wu_sess = WScript.CreateObject("Microsoft.Update.Session");

    var wu_searcher = wu_sess.CreateUpdateSearcher();
    wu_searcher.ServerSelection = SERVER_SELECTION;

    wu_items = wu_searcher.Search("(IsInstalled=0)and(IsHidden=0)and(Type='Software')");

//アップデート検索結果処理
    if( (wu_items.Updates.Count == 0) )
    {
        return 0;
    }

//アップデートのダウンロード、同時にアップデートリストの生成
    LINF(34, "アップデートのダウンロード...");
    var wu_nrinsts=[], wu_rinsts=[];
    var arinsts = [wu_nrinsts,wu_rinsts];
    var wu_dldr = wu_sess.CreateUpdateDownloader();
    wu_dldr.Updates = WScript.CreateObject("Microsoft.Update.UpdateColl");

    for(var i=0;i<wu_items.Updates.Count;++i)
    {
        uitem = wu_items.Updates.Item(i);
        if( IsKBExclude(uitem) || (UPDATE_ONLY && IsNotUpdate(uitem)) )
        {
            L("\t[SKP]" + uitem.Title);
            continue;
        }

        if(! uitem.IsDownloaded )
        {
            wu_dldr.Updates.Add(uitem);
            wu_dldr.Download();
            L("\t[ DL]" + uitem.Title);
            wu_dldr.Updates.Clear();
        }else{
            L("\t[NDL]" + uitem.Title);
        }

        uitem.AcceptEula();

        if( uitem.EulaAccepted )
        {
            if(uitem.RebootRequired){
                wu_rinsts.push( uitem );
            }else{
                wu_nrinsts.push( uitem );
            }
        }
    }

//インストール

    //インストール対象収集
    LINF(35, "アップデートのインストール...");
    var ilst = "";
    var instRes = null;
    var wu_inst = wu_sess.CreateUpdateInstaller();
    wu_inst.Updates = WScript.CreateObject("Microsoft.Update.UpdateColl");

    for(var j in arinsts)
    {
        for(var i in arinsts[j])
        {
            uitem = arinsts[j][i];
            if( uitem.IsDownloaded )
            {
                wu_inst.Updates.Add(uitem);
                ilst = ilst + "\t" + uitem.Title + "\n";
                L("\t[INS]" + uitem.Title);
            }
            if( (wu_inst.Updates.Count >= MAXUPDATES) || ( (i == arinsts[j].length-1) && (wu_inst.Updates.Count > 0) ) )
            {
                L("\tインストール実行中...");
                try
                {
                    instRes = wu_inst.Install();

                    ilst = "インストール実施\n" + ilst;
                    LRES(36,ilst,false);
                    if(instRes.RebootRequired)break;
                    ilst = "";
                }
                catch(e)
                {
                    ilst = "インストール失敗\n" + ilst;
                    LRES(37,ilst,true);
                    ilist = ""
                }
                wu_inst.Updates.Clear();
            }
        }
        if( (instRes != null) && instRes.RebootRequired){break;}
    }

    if(instRes == null)
    {
        L("\tインストールなし");
        return 0;
    }

//インストール結果処理
    LINF(38, "インストール結果 ResultCode=" + RESULTSTRS[instRes.ResultCode] + (instRes.RebootRequired ? " 再起動が必要" : " 再起動不要") );

    return (instRes.RebootRequired ? 2 : 1);
}
//-----------------------------------------------------------
function RegisterScript()
{
    var cmd,ret;
    //cmd = "schtasks /create /tn \"#KEY#\" /tr \"\\\"#CMD#\"\\\" /sc onstart /ru system /rl highest /f";
    cmd = "schtasks /create /tn \"#KEY#\" /tr \"\\\"#CMD#\"\\\" /sc onstart /delay 0002:00 /ru system /rl highest /f";
    cmd = cmd.replace("#KEY#", WScript.ScriptName);
    cmd = cmd.replace("#CMD#", WScript.ScriptFullName);

    ret = wsh.run(cmd,0,true);

    if(ret == 0)
    {
        LRES(70,"スタートアップタスク登録：成功",false);
    }else{
        LRES(71,"スタートアップタスク登録：失敗",true);
    }
}
//-----------------------------------------------------------
function UnregisterScript()
{
    var cmd,ret;
    //アイテムチェック
    cmd = "schtasks /query /tn \"#KEY#\"";
    cmd = cmd.replace("#KEY#", WScript.ScriptName);
    ret = wsh.run(cmd,0,true);

    if(ret == 0) //タスクが存在している
    {
        cmd = "schtasks /delete /tn \"#KEY#\" /f";
        cmd = cmd.replace("#KEY#", WScript.ScriptName);

        ret = wsh.run(cmd,0,true);
        if(ret == 0)
        {
            LRES(20,"スタートアップタスク除去：成功",false);
        }else{
            LRES(21,"スタートアップタスク除去：失敗",true);
        }
    }
}
//-----------------------------------------------------------
function L(msg)
{
    if(msg.length > 67){ msg = msg.substr(0,31) + "..." + msg.substr(msg.length-31,31); }
    WScript.Echo(msg);
}
//-----------------------------------------------------------
function LINF(code,msg)
{
    L(WScript.ScriptName+" "+msg);
    EventCreate("INFORMATION", code, msg);
}
//-----------------------------------------------------------
function LRES(code,msg,iserror)
{
    L(WScript.ScriptName+" "+msg);
    EventCreate( (iserror ? "ERROR" : "SUCCESS") , code, msg);
}
//-----------------------------------------------------------
function IsNotUpdate(uitem)
{
    for(var j=0;j<uitem.Categories.Count;++j)
    {
        var cat = uitem.Categories.Item(j);
        if((cat.Type=="UpdateClassification")&&(cat.Name!="Updates"))return true;
    }
    return false;
}
//-----------------------------------------------------------
function IsKBExclude(uitem)
{
    for(var i in EXCLUDE_KB_IDs)
        for(var j=0;j<uitem.KBArticleIDs.Count;++j)
            if(Number(EXCLUDE_KB_IDs[i]) === Number(uitem.KBArticleIDs.Item(j)) )return true;

    return false;
}
//-----------------------------------------------------------
function EventCreate(LogLevel,LogID,Desc)
{
    var cmd = "eventcreate /L APPLICATION /T \"#LT#\" /SO \"#SO#\" /ID #ID# /D \"#DS#\"";
    cmd = cmd.replace("#LT#", LogLevel);
    cmd = cmd.replace("#SO#", WScript.ScriptName);
    cmd = cmd.replace("#ID#", LogID);
    cmd = cmd.replace("#DS#", Desc);
    wsh.run(cmd,0,true);
}
