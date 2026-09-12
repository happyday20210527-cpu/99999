<#
.SYNOPSIS
    Kilo Code(終端機/CLI 版本)自動催促腳本 —— 每隔一段時間檢查任務是否還在跑,
    如果偵測到它「安靜下來(疑似在等指示/原地待命)」,就自動幫你在它的輸入視窗
    打一句「請繼續、不要等待」把它推回去做事。

.DESCRIPTION
    這支腳本會由「自己」把 kilo 這個指令啟動成子行程(child process),
    並接管它的標準輸入/輸出(stdin/stdout),所以：
      - 不需要用 SendKeys 之類的方式去「亂點」畫面上的視窗(那樣容易點錯視窗,
        有風險),而是直接、乾淨地把文字寫進 kilo 自己的輸入管道。
      - kilo 原本印出來的畫面內容,一樣會即時顯示在你執行本腳本的這個
        PowerShell 視窗裡(同時也會存一份到 log 檔),你仍然看得到它在做什麼。

    判斷邏輯(簡化版,用「多久沒有新輸出」當作代理指標):
      - 每隔 $CheckIntervalMinutes 分鐘檢查一次
      - 如果最近 $IdleAfterMinutes 分鐘內「有」新的輸出 → 視為「執行中」,不理它
      - 如果最近 $IdleAfterMinutes 分鐘內「完全沒有」新輸出 → 視為「等指示 / 原地待命」
        → 自動送出 $NudgePrompt 這句話進去,催它繼續動作

    注意(重要限制,請務必看過):
      1. Kilo Code CLI 目前**沒有**官方文件記載的「查詢任務狀態」API,所以這裡是用
         「輸出畫面多久沒更新」當作「還在執行 vs 在等待」的判斷依據,不是 100% 精準。
         如果 kilo 本身在做一個「需要很久才會有輸出」的長任務(例如下載大檔案、
         跑很久的編譯),有可能被誤判成「閒置」而被催促 —— 這只是多打一行字進去,
         不會中斷正在跑的任務,頂多是多一句「請繼續」對它沒什麼影響。
      2. 本腳本**不會**執行任何刪除檔案或修改系統設定的動作,它只做兩件事:
         (a) 讀取 kilo 行程的輸出、(b) 在偵測到閒置時,對 kilo 行程的輸入管道
         寫入一句文字。是否要核准/拒絕實際的檔案操作,仍然是由
         kilo.jsonc(參考同資料夾 kilocode-auto-approve-settings.jsonc)裡的
         permission 設定決定,與這支腳本無關。
      3. 本腳本必須是「啟動 kilo 任務的那個腳本」,不是額外開一個新視窗去猜
         已經在跑的 kilo 視窗是哪一個。也就是說,以後要跑 kilo 任務時,
         改成執行這支腳本(它會幫你啟動 kilo 並全程看著),而不是自己先手動
         打 `kilo run ...` 之後才想到要監控它。
      4. 這是在雲端作業環境離線撰寫、依官方文件推斷 CLI 行為寫成的腳本,
         沒有你這台筆電的實機可以先跑一次驗證。第一次使用時,建議先用一個
         不重要的小任務試跑,觀察行為是否符合預期,再套用到正式任務上;
         如果 $IdleAfterMinutes / $NudgePrompt 的效果不如預期,直接調整
         這兩個參數即可。

.PARAMETER TaskPrompt
    要交給 kilo 執行的任務內容(一段文字描述)。

.PARAMETER CheckIntervalMinutes
    多久檢查一次是否閒置,預設 15 分鐘(符合「每十五分鐘」的需求)。

.PARAMETER IdleAfterMinutes
    輸出畫面「連續幾分鐘沒有新內容」才視為閒置,預設等於 CheckIntervalMinutes,
    也就是「每次檢查時,如果從上次檢查到現在完全沒新輸出」就催它。

.PARAMETER NudgePrompt
    偵測到閒置時,自動送進去的那句催促話。

.PARAMETER KiloExe
    kilo 執行檔名稱或完整路徑,預設 "kilo"(假設已加入 PATH)。

.PARAMETER ExtraArgs
    傳給 kilo 的額外參數陣列,預設是 @("run")。若你平常是用
    `kilo run --auto "..."` 啟動,可以改成 @("run","--auto")。
    請注意:若使用 --auto,kilo 會「自動核准所有動作」(包含刪除/系統設定類),
    這會蓋掉 kilo.jsonc 裡针对刪除/系統穩定性設的 deny/ask 規則。
    若要保留「刪除檔案、影響系統穩定性」不自動核准的限制,
    建議**不要**加 --auto,改為單純依賴 kilo.jsonc 的 permission 設定
    (allow/ask/deny),讓 kilo 走一般核准流程。

.PARAMETER LogPath
    輸出 log 存檔路徑,預設在腳本同目錄下的 kilo-task.log。

.EXAMPLE
    # 最基本用法:啟動一個任務並全程自動監控、閒置時自動催促
    .\kilo-auto-nudge.ps1 -TaskPrompt "幫我把 XXX 模組重構完成"

.EXAMPLE
    # 縮短檢查間隔到 5 分鐘做測試
    .\kilo-auto-nudge.ps1 -TaskPrompt "測試任務" -CheckIntervalMinutes 5 -IdleAfterMinutes 5
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskPrompt,

    [int]$CheckIntervalMinutes = 15,

    [int]$IdleAfterMinutes = 15,

    [string]$NudgePrompt = "請繼續完成任務,不需要等待我確認,直接執行下一步動作,盡快完成。(但仍請遵守：不要刪除檔案、不要執行任何會影響系統穩定性的操作)",

    [string]$KiloExe = "kilo",

    [string[]]$ExtraArgs = @("run"),

    [string]$LogPath = (Join-Path $PSScriptRoot "kilo-task.log")
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$stamp] $Message"
    Write-Host $line
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

# ------------------------------------------------------------------
# 檢查 kilo 指令是否存在
# ------------------------------------------------------------------
$kiloCmd = Get-Command $KiloExe -ErrorAction SilentlyContinue
if (-not $kiloCmd) {
    Write-Host "找不到指令 '$KiloExe',請確認 Kilo Code CLI 已安裝並加入 PATH," -ForegroundColor Red
    Write-Host "或用 -KiloExe 參數指定完整路徑(例如 -KiloExe 'C:\Tools\kilo\kilo.exe')。" -ForegroundColor Yellow
    exit 1
}

Write-Log "===== 啟動 Kilo 自動監控/催促腳本 ====="
Write-Log "任務內容: $TaskPrompt"
Write-Log "檢查間隔: 每 $CheckIntervalMinutes 分鐘 / 閒置門檻: $IdleAfterMinutes 分鐘"
Write-Log "啟動指令: $KiloExe $($ExtraArgs -join ' ') `"$TaskPrompt`""

# ------------------------------------------------------------------
# 啟動 kilo 子行程,接管 stdin/stdout/stderr
# ------------------------------------------------------------------
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $kiloCmd.Source
$allArgs = @()
$allArgs += $ExtraArgs
$allArgs += $TaskPrompt
# 用 ArgumentList 逐一加入,避免手動組字串造成的引號問題
foreach ($a in $allArgs) { $psi.ArgumentList.Add($a) }

$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $false

$script:lastOutputTime = Get-Date

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi

$outputHandler = {
    if ($EventArgs.Data) {
        $script:lastOutputTime = Get-Date
        Write-Host $EventArgs.Data
        Add-Content -Path $using:LogPath -Value $EventArgs.Data -Encoding UTF8
    }
}

Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action $outputHandler | Out-Null
Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -Action $outputHandler | Out-Null

$proc.Start() | Out-Null
$proc.BeginOutputReadLine()
$proc.BeginErrorReadLine()

Write-Log "kilo 行程已啟動,PID = $($proc.Id)"

# ------------------------------------------------------------------
# 主迴圈:每 $CheckIntervalMinutes 分鐘檢查一次
# ------------------------------------------------------------------
try {
    while (-not $proc.HasExited) {
        Start-Sleep -Seconds ($CheckIntervalMinutes * 60)

        if ($proc.HasExited) { break }

        $idleMinutes = (New-TimeSpan -Start $script:lastOutputTime -End (Get-Date)).TotalMinutes

        if ($idleMinutes -ge $IdleAfterMinutes) {
            Write-Log "偵測到已閒置 $([math]::Round($idleMinutes,1)) 分鐘 → 判定為「等指示/原地待命」,自動催促一下..."
            try {
                $proc.StandardInput.WriteLine($NudgePrompt)
                $proc.StandardInput.Flush()
                Write-Log "已送出催促訊息: $NudgePrompt"
                $script:lastOutputTime = Get-Date
            } catch {
                Write-Log "送出催促訊息失敗(行程可能已結束或輸入管道已關閉): $($_.Exception.Message)"
            }
        } else {
            Write-Log "最近 $([math]::Round($idleMinutes,1)) 分鐘內有新輸出 → 判定為「執行中」,不用理它。"
        }
    }
}
finally {
    if ($proc.HasExited) {
        Write-Log "kilo 行程已結束,結束代碼 = $($proc.ExitCode)"
        switch ($proc.ExitCode) {
            0   { Write-Log "結束代碼 0 = 任務成功完成。" }
            124 { Write-Log "結束代碼 124 = 逾時。" }
            1   { Write-Log "結束代碼 1 = 發生錯誤,或有權限被自動拒絕(deny)。" }
            default { Write-Log "結束代碼 $($proc.ExitCode) = 其他狀況,請自行查看上方 log。" }
        }
    }
    Get-EventSubscriber | Where-Object { $_.SourceObject -eq $proc } | Unregister-Event
}

Write-Log "===== 監控腳本結束 ====="
