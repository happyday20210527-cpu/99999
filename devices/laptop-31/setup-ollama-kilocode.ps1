<#
.SYNOPSIS
    31 號筆電 - 架設 Ollama + qwen2.5-coder 模型,供 VS Code Kilo Code 擴充套件使用。

.DESCRIPTION
    1. 檢查/安裝 Ollama
    2. 檢查系統總 RAM,對大型模型(32b)給出警告
    3. 下載指定的 qwen2.5-coder 模型(預設 32b, q4_K_M 量化)
    4. 確認 Ollama 服務正常運作
    5. 印出 Kilo Code 設定步驟

.PARAMETER Model
    要下載的 Ollama 模型 tag。預設 "qwen2.5-coder:32b"。
    硬體較弱時建議改用 "qwen2.5-coder:14b" 或 "qwen2.5-coder:7b"。

.PARAMETER SkipRamCheck
    略過 RAM 檢查警告,直接繼續安裝(不建議)。

.EXAMPLE
    .\setup-ollama-kilocode.ps1
    .\setup-ollama-kilocode.ps1 -Model "qwen2.5-coder:14b"
    .\setup-ollama-kilocode.ps1 -SkipRamCheck

.NOTES
    請以「系統管理員身分」執行 PowerShell 再跑此腳本(安裝軟體需要權限)。
    此腳本內容係依 Ollama / Kilo Code 官方文件之一般安裝方式撰寫,
    實際安裝程式互動畫面可能因版本更新而略有差異,請依畫面指示操作。
#>

[CmdletBinding()]
param(
    [string]$Model = "qwen2.5-coder:32b",
    [switch]$SkipRamCheck
)

$ErrorActionPreference = "Stop"

function Write-Section($title) {
    Write-Host ""
    Write-Host "==== $title ====" -ForegroundColor Cyan
}

# ------------------------------------------------------------------
# 1. RAM 檢查
# ------------------------------------------------------------------
Write-Section "檢查系統記憶體"

$totalRamGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
Write-Host "偵測到總實體 RAM: $totalRamGB GB"

$is32bModel = $Model -like "*32b*"

if ($is32bModel -and -not $SkipRamCheck) {
    if ($totalRamGB -lt 24) {
        Write-Host "警告: 總 RAM 只有 $totalRamGB GB,低於 32b 模型建議的 32GB。" -ForegroundColor Yellow
        Write-Host "強烈建議改用較小模型,例如:" -ForegroundColor Yellow
        Write-Host "  .\setup-ollama-kilocode.ps1 -Model 'qwen2.5-coder:14b'" -ForegroundColor Yellow
        $ans = Read-Host "仍要繼續安裝 $Model 嗎? 可能導致系統卡頓或安裝失敗 (y/N)"
        if ($ans -ne "y" -and $ans -ne "Y") {
            Write-Host "已取消。請改用較小模型或加上 -SkipRamCheck 強制繼續。"
            exit 0
        }
    } else {
        Write-Host "RAM 足夠 ($totalRamGB GB >= 24GB),可以繼續安裝 $Model。" -ForegroundColor Green
        Write-Host "備註: 此筆電為 AMD 內顯(無獨立顯卡),推論將以 CPU 為主,速度會較慢。" -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------------
# 2. 安裝 Ollama
# ------------------------------------------------------------------
Write-Section "檢查 / 安裝 Ollama"

$ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue

if ($ollamaCmd) {
    Write-Host "Ollama 已安裝: $($ollamaCmd.Source)" -ForegroundColor Green
} else {
    Write-Host "未偵測到 Ollama,嘗試以 winget 安裝..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        try {
            winget install --id Ollama.Ollama -e --accept-source-agreements --accept-package-agreements
        } catch {
            Write-Host "winget 安裝失敗: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "請手動至 https://ollama.com/download/windows 下載安裝程式後重新執行本腳本。" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "此系統沒有 winget,請手動至 https://ollama.com/download/windows 下載安裝,安裝完成後重新執行本腳本。" -ForegroundColor Yellow
        exit 1
    }

    # 重新整理 PATH,讓當前 session 抓得到剛裝好的 ollama
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
    if (-not $ollamaCmd) {
        Write-Host "安裝完成,但目前終端機抓不到 ollama 指令,請關閉並重新開啟 PowerShell 後再執行一次本腳本。" -ForegroundColor Yellow
        exit 0
    }
}

# ------------------------------------------------------------------
# 3. 確保 Ollama 服務有在跑
# ------------------------------------------------------------------
Write-Section "確認 Ollama 服務"

$service = Get-Process -Name "ollama" -ErrorAction SilentlyContinue
if (-not $service) {
    Write-Host "啟動 Ollama 服務..."
    Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 3
} else {
    Write-Host "Ollama 服務已在執行中。" -ForegroundColor Green
}

# ------------------------------------------------------------------
# 4. 下載模型
# ------------------------------------------------------------------
Write-Section "下載模型: $Model"
Write-Host "檔案較大(32b 約 19-20GB),依網速可能需要一段時間,請耐心等候..."

ollama pull $Model

if ($LASTEXITCODE -ne 0) {
    Write-Host "模型下載失敗,請檢查網路連線或磁碟空間後重試。" -ForegroundColor Red
    exit 1
}

Write-Host "模型下載完成: $Model" -ForegroundColor Green

# ------------------------------------------------------------------
# 5. 完成,印出後續步驟
# ------------------------------------------------------------------
Write-Section "安裝完成 - 後續請在 VS Code 中設定 Kilo Code"

Write-Host @"

1. 在 VS Code 擴充套件市集搜尋並安裝 "Kilo Code"

2. 開啟 Kilo Code 設定 (齒輪圖示) -> Providers -> 新增/選擇 Ollama Provider,填入:
     Base URL : http://localhost:11434
     Model ID : $Model

3. 回到聊天視窗輸入一句測試訊息,確認能收到模型回覆。
   第一次回覆會較慢,因為模型要先載入記憶體。

4. 驗證指令(可另開一個 PowerShell 視窗測試):
     ollama list
     ollama run $Model "寫一個 Python 的 quicksort function"

詳細說明請見同資料夾的 README.md
"@ -ForegroundColor Cyan
