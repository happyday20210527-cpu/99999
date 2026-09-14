<#
.SYNOPSIS
    在桌面建立一個「Claude」捷徑,點兩下就會開一個終端機、自動切換到
    E:\3131---claude 這個資料夾,並啟動 claude。

.DESCRIPTION
    這支腳本本身**不是**捷徑,而是「用來產生捷徑」的安裝腳本 —— 因為捷徑
    (.lnk)是一種二進位檔案格式,無法用純文字直接寫出來,要透過 Windows
    的 WScript.Shell 元件來建立。所以使用方式是:

        1. 把這支 .ps1 複製到你的電腦(或直接從這個 repo 抓下來)
        2. 用「系統管理員身分」或一般身分都可以,執行這支腳本一次
           (見下方「使用方式」)
        3. 執行完成後,桌面上就會出現一個叫做「Claude」的捷徑圖示,
           以後直接點兩下它就好,不用再手動 cd 資料夾、打指令。

    捷徑點下去實際會執行的指令(等同你平常手動做的事):
        cd /d "E:\3131---claude"
        claude

    腳本會先檢查 E:\3131---claude 資料夾底下有沒有現成的啟動檔
    (claude.cmd / claude.bat / start.ps1 / start.bat),如果有就優先
    用那個啟動;如果都沒有,就退回用最單純的方式:切換到該資料夾後
    直接執行 `claude` 指令(前提是 claude 已經加入系統 PATH,這通常也是
    你平常在終端機打 `claude` 就能用的情況)。

    視窗會保持開啟(用 -NoExit),這樣如果 claude 指令找不到或發生錯誤,
    你可以直接在視窗裡看到錯誤訊息,而不是視窗一閃就關掉。

.PARAMETER ClaudeDir
    Claude 專案/啟動資料夾路徑,預設 "E:\3131---claude"。

.PARAMETER ShortcutName
    桌面捷徑的顯示名稱,預設 "Claude"。

.EXAMPLE
    # 在你的電腦上,直接執行(建議用系統管理員身分開 PowerShell):
    .\create-claude-desktop-shortcut.ps1

.EXAMPLE
    # 若你的 claude 資料夾路徑不是 E:\3131---claude,可以自訂:
    .\create-claude-desktop-shortcut.ps1 -ClaudeDir "D:\claude-project"
#>

[CmdletBinding()]
param(
    [string]$ClaudeDir = "E:\3131---claude",
    [string]$ShortcutName = "Claude"
)

$ErrorActionPreference = "Stop"

Write-Host "==== 建立 Claude 桌面捷徑 ====" -ForegroundColor Cyan

# ------------------------------------------------------------------
# 1. 檢查資料夾是否存在(僅提醒,不阻擋 —— 也許這支腳本是在別台電腦上
#    先準備捷徑,之後才複製過去真正有該資料夾的電腦使用)
# ------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $ClaudeDir)) {
    Write-Host "提醒: 目前這台電腦上找不到資料夾 '$ClaudeDir'。" -ForegroundColor Yellow
    Write-Host "      捷徑仍會建立,但要在『真正有這個資料夾』的電腦上才能正常啟動。" -ForegroundColor Yellow
}

# ------------------------------------------------------------------
# 2. 決定要執行的啟動指令:優先用資料夾內現成的啟動檔,否則退回
#    「cd 進去 + 執行 claude」
# ------------------------------------------------------------------
$launcherCandidates = @("claude.cmd", "claude.bat", "start.ps1", "start.bat")
$foundLauncher = $null

foreach ($name in $launcherCandidates) {
    $candidatePath = Join-Path $ClaudeDir $name
    if (Test-Path -LiteralPath $candidatePath) {
        $foundLauncher = $candidatePath
        break
    }
}

if ($foundLauncher) {
    Write-Host "偵測到現成的啟動檔: $foundLauncher,捷徑將優先使用它。" -ForegroundColor Green
    if ($foundLauncher -like "*.ps1") {
        $psCommand = "Set-Location -LiteralPath '$ClaudeDir'; & '$foundLauncher'"
    } else {
        $psCommand = "Set-Location -LiteralPath '$ClaudeDir'; & '$foundLauncher'"
    }
} else {
    Write-Host "資料夾內沒找到現成啟動檔,捷徑將採用: cd 到資料夾後執行 claude 指令。" -ForegroundColor Green
    $psCommand = "Set-Location -LiteralPath '$ClaudeDir'; claude"
}

# ------------------------------------------------------------------
# 3. 用 WScript.Shell 建立桌面捷徑
# ------------------------------------------------------------------
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "$ShortcutName.lnk"

$wshShell = New-Object -ComObject WScript.Shell
$shortcut = $wshShell.CreateShortcut($shortcutPath)

$shortcut.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$shortcut.Arguments = "-NoExit -ExecutionPolicy Bypass -Command `"$psCommand`""
$shortcut.WorkingDirectory = $ClaudeDir
$shortcut.IconLocation = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe,0"
$shortcut.Description = "啟動 Claude ($ClaudeDir)"
$shortcut.Save()

Write-Host ""
Write-Host "完成! 桌面捷徑已建立: $shortcutPath" -ForegroundColor Green
Write-Host "以後直接點兩下桌面上的「$ShortcutName」圖示,就會開終端機並啟動 claude。" -ForegroundColor Green
Write-Host ""
Write-Host "小提醒:" -ForegroundColor Yellow
Write-Host " - 若你電腦的 PowerShell 執行原則(Execution Policy)比較嚴格," -ForegroundColor Yellow
Write-Host "   捷徑已經加上 -ExecutionPolicy Bypass,只影響這個捷徑開啟的視窗,不會更動" -ForegroundColor Yellow
Write-Host "   你電腦全域的安全性設定。" -ForegroundColor Yellow
Write-Host " - 如果點捷徑後出現「claude: 無法辨識」之類的錯誤,代表 claude 指令" -ForegroundColor Yellow
Write-Host "   還沒加入系統 PATH,請確認平常你是用什麼指令啟動 claude," -ForegroundColor Yellow
Write-Host "   再回報給我,我幫你把捷徑內容改成正確的啟動方式。" -ForegroundColor Yellow
