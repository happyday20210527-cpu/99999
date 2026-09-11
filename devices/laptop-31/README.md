# 31 號筆電 — Kilo Code + qwen2.5-coder:32b 本地模型架設

目標:在 31 號筆電上架設本地推論服務(Ollama),讓 VS Code 的 **Kilo Code** 擴充套件
透過本地端的 **qwen2.5-coder:32b(量化版)** 當作「模型大腦」使用,不用依賴雲端 API。

---

## 0. 硬體評估(已依工作管理員實際截圖確認)

實際硬體(Windows 工作管理員→效能頁籤截圖):

| 項目 | 數值 |
|---|---|
| 系統記憶體(RAM) | 17.0/27.6 GB 使用中 → **總實體 RAM 約 32GB** |
| GPU | AMD Radeon(TM) 8xx 系列內顯(integrated,無獨立顯卡)+ NPU |
| 專屬 GPU 記憶體 | 3.8 GB(從系統 RAM 切割) |
| 共用 GPU 記憶體 | 13.8 GB(從系統 RAM 切割) |
| CPU | 3% 使用率,4.61 GHz(閒置狀態,代表有不錯的 boost clock) |

這是一台 **AMD Ryzen AI 系列處理器**筆電(內顯 + NPU 組合),沒有獨立 VRAM 的獨立顯卡。

**qwen2.5-coder:32b 的資源需求(以 Ollama 預設量化 q4_K_M 估算)：**

| 項目 | 需求 |
|---|---|
| 模型檔案大小(硬碟) | 約 19–20 GB |
| 執行時記憶體(RAM) | 約 20–24 GB(含 context) |
| 建議總 RAM | 32GB 以上(CPU 推論) |

**結論:32GB RAM 足夠讓 32b 模型「跑起來」,不會 OOM。** 但因為是 AMD 內顯而非獨立顯卡,Ollama 在 Windows 上對 AMD 內顯的 GPU 加速支援有限,**推論主要會吃 CPU**,速度預期較慢(概估每秒個位數 token,依實際 CPU 而定),不是即時等級的回應速度。此外模型佔用大部分 RAM 期間,**其他應用程式的可用記憶體會明顯變少**,建議跑模型時避免同時開太多其他吃記憶體的程式,以維持系統穩定。

### 建議做法

| 方案 | 說明 |
|---|---|
| **A. 直接跑 32b(照原始需求)** | 32GB RAM 可行,但回應速度較慢,且跑模型期間系統可用記憶體會吃緊 |
| **B. 改用 14b 當日常主力,32b 備用** | `qwen2.5-coder:14b`(約 9GB)速度快很多、RAM 壓力小,適合日常互動;需要更高品質時再切換 32b |
| **C. 若日後加裝獨立顯卡** | 有 12GB+ VRAM 的獨立顯卡時,32b 可用 GPU 加速,速度會大幅提升 |

本資料夾內的腳本**預設安裝 32b(q4_K_M)**,並會先做 RAM 檢查再繼續。若想改用 14b,用 `-Model` 參數切換即可。

---

## 1. 架設步驟總覽

1. 安裝 Ollama(本地 LLM 推論服務)
2. 用 Ollama 下載 qwen2.5-coder:32b(或依硬體改用 14b/7b)
3. 安裝 VS Code 的 Kilo Code 擴充套件
4. 在 Kilo Code 設定中,把 Provider 指向本地 Ollama(`http://localhost:11434`)

---

## 2. 安裝 Ollama(Windows)

執行 `setup-ollama-kilocode.ps1`(以系統管理員身分開啟 PowerShell):

```powershell
# 預設安裝 32b 量化版,並先做 RAM 檢查
.\setup-ollama-kilocode.ps1

# 若想直接改用建議的 14b 版本
.\setup-ollama-kilocode.ps1 -Model "qwen2.5-coder:14b"

# 略過 RAM 檢查警告直接安裝 32b(不建議,除非你已確認 RAM ≥ 32GB)
.\setup-ollama-kilocode.ps1 -SkipRamCheck
```

腳本會自動:
- 檢查/安裝 Ollama(透過 winget,若無 winget 則提示手動下載網址)
- 檢查系統總 RAM,對 32b 模型給出警告
- 執行 `ollama pull <model>` 下載模型
- 啟動 Ollama 服務(預設監聽 `http://localhost:11434`)
- 印出後續 Kilo Code 設定步驟

如果 winget 不可用,請手動至官網下載安裝:
`https://ollama.com/download/windows`(此連結需你在筆電上自行開啟確認,本次雲端 session 因網路出口限制無法即時存取該網域驗證)。

---

## 3. 安裝 Kilo Code 擴充套件

1. 打開 VS Code
2. 左側 Extensions(擴充套件)頁籤,搜尋 **Kilo Code**
3. 安裝擴充套件(發布者:Kilo Code)

或用命令列(VS Code 需已加入 PATH):

```powershell
code --install-extension kilocode.kilo-code
```

> 若此擴充套件 ID 有誤,請直接在 VS Code Marketplace 搜尋「Kilo Code」安裝,以你電腦上看到的實際 ID 為準——本次雲端環境無法連線 marketplace 逐一核對版本資訊。

---

## 4. 設定 Kilo Code 使用本地 Ollama 模型

在 VS Code 中打開 Kilo Code 側邊欄 → 齒輪(Settings)→ Providers,新增/選擇 **Ollama** 作為 Provider,填入:

| 欄位 | 值 |
|---|---|
| Provider | Ollama |
| Base URL | `http://localhost:11434` |
| Model ID | `qwen2.5-coder:32b`(或你實際下載的 tag,如 `qwen2.5-coder:14b`) |

也可以參考 `kilocode-settings-snippet.json`,若 Kilo Code 支援匯入/貼上設定 JSON,可直接套用其中的內容(欄位名稱可能隨版本更新而異,請以你實際安裝的版本介面為準)。

設定完成後,在 Kilo Code 聊天視窗輸入測試訊息,確認能收到模型回覆(第一次回覆會較慢,因為模型要先載入記憶體)。

---

## 5. 驗證與疑難排解

```powershell
# 確認 Ollama 服務有在跑
ollama list

# 確認模型已下載
ollama list | findstr qwen2.5-coder

# 手動測試模型是否能正常推論
ollama run qwen2.5-coder:32b "寫一個 Python 的 quicksort function"
```

常見問題:

- **模型載入失敗 / 電腦變超卡**:代表 RAM 不夠,請改用 `qwen2.5-coder:14b` 或 `7b`(見上方方案 B)
- **Kilo Code 連不到 Ollama**:確認 `ollama serve` 有在背景執行(安裝完會自動註冊成開機啟動服務),並確認防火牆沒擋 `localhost:11434`
- **回覆速度很慢**:32b 在只有 CPU/低 VRAM 的機器上是預期行為,如果不能接受速度,請改用較小模型

---

## 6. 檔案清單

所有本次新增檔案的完整路徑,已記錄在 `檔案清單.txt`。
