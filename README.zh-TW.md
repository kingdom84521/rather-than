# rather-than

[English](README.md) | 繁體中文

一個 [Claude Code](https://claude.com/claude-code) skill 加三個 hook，用來記錄你「為什麼」把程式寫成這個樣子，
讓後面的 session 不必重新爭論已經定案的事。

規則的家是 `CLAUDE.md`。但真正讓一份程式碼像是你寫的東西，多半比規則更軟 ——
「泛型寧可寫明，不要靠推導」、「防護寧可讓型別系統擋住，不要靠慣例加一行註解」。
這種話在某個 session 講過，就隨那個 session 一起消失。rather-than 從日常對話裡把它們接住，
每一筆都附上收據、經你確認之後才存起來，再把整份 store 注回每一個 turn。

條目是**傾向，不是規則**：警告等級的偏向，永遠不阻擋、不說教，遇到正確性、當下的可讀性、
或條目自己記下的例外就讓路。要把一個傾向變成真正會強制執行的規則，是另一條獨立、設有關卡、
且只能由你下令啟動的路。

## 運作方式

三個部分。

**Hooks** —— 純檔案 IO、不呼叫 LLM，全部放在 `~/.claude/hooks/rather-than/`：

| Hook | 事件 | 做什麼 |
|---|---|---|
| `session-start.sh` | SessionStart | store 不存在就建起來、開一份帶來源標頭的本 session journal、索引過期就重建，並把 store 索引與這個 session 需要的所有路徑注入 |
| `prompt.sh` | UserPromptSubmit | 每個 turn 重述那一句 journal 義務、更新 session 的存活標記；只有在 store 自本 session 上次讀過之後有變動時（通常是另一個 session 併行改動）才注入變動的索引行，而不是整份索引 |
| `stop.sh` | Stop | 有已確認條目在等著整併時，攔下這次停止一次（每個 session 每 30 分鐘最多一次），讓整併發生在自然的段落，而不是永遠不發生 |

**Skill** —— `SKILL.md` 與 `references/`，承載所有判斷：什麼算偏好訊號、什麼該被濾掉、
一個問題要怎麼問才算問得起、兩個條目要怎麼合併。

**Store** —— 自動建立，一個偏好一個 Markdown 檔：

```
~/.claude/rather-than/
├── prefer/<slug>.md      # 一筆偏好一個檔 —— 唯一真實來源
├── index.md              # 產生出來的主題清單，每個 turn 都會注入
├── journal/<sid>.md      # 每個 session 的原始事件記錄
├── deferred/<slug>.md    # 你暫緩的候選，收據完整保留
├── ignore.md             # 你選擇不追蹤的主題
├── REVIEW.md             # 正在等你確認的那一筆變更
└── team/<repo-key>/      # team scope 的本機暫存區，依 repository 分開
```

執行狀態 —— 鎖、使用次數、每個 session 的簿記 —— 放在
`~/.claude/skills/rather-than/.state/`，不會進 store，也不會進任何 repository。

## 流程

捕捉刻意切成兩層：在任務壓力下，「記得寫一句話」遠比「跑一次分類」可靠得多；
而且漏記是救不回來的，分析錯了可以重跑。

1. **記錄**（每個 turn，不做判斷）—— 每個轉向事件在 session journal 寫下一句英文：
   指示、對模型輸出的糾正、順口的評價、在你面前二選一時的選擇、流程上的指正，
   以及模型自己對程式碼慣例的觀察。每一行都要寫出當時在做什麼，並且趁
   *那個「而不是什麼」還存在的時候* 把它記下來 —— 被覆寫掉的草稿、沒被選中的選項、
   原本的行為，都會在這個 turn 之後蒸發。

2. **分析**（批次進行，絕不在任務中間）—— 到了段落、或原始行累積到一定數量，
   這些行會通過一套訊號分類與硬性過濾：只限當下的指示、指名單一目標而非一類目標的任務、
   linter 或 formatter 已經在管的事、`CLAUDE.md` 已經寫成規則的事、
   對模型提案的被動接受。存活下來的會以候選區塊寫回 journal ——
   分析結果絕不只留在模型腦袋裡。

3. **提問 —— 一律附收據** —— 一次批次提問、最多四個候選，每個都帶著日期、你當時說了什麼、
   那是「而不是什麼」、以及當時在做什麼。答案有：*個人偏好*、*團隊慣例*、
   *暫緩*（等這個主題下次真的出現時再問）、*永不追蹤*。
   拿不出收據的問題，就是還沒準備好問的問題。

4. **整併** —— 已確認的區塊一次一筆併進 `prefer/`，而且要過一道審閱關卡：
   每一筆待寫入的變更會用白話翻譯進 `REVIEW.md` —— 你將會看到什麼、將不會再看到什麼、
   在哪裡適用、在哪裡明確**不**適用 —— 你認可那份翻譯之後才會寫入。
   互相衝突的條目會進到對抗式辯論，而不是被無聲覆寫。

把已確認的偏好套用到當下的程式碼是立刻發生的，不必等上面任何簿記。

## Scope

| Scope | 根目錄 | 進 git |
|---|---|---|
| personal | `~/.claude/rather-than/` | 否 |
| team（暫存） | `~/.claude/rather-than/team/<repo-key>/` | 否 |
| project（已發佈） | `<repo>/.claude/rather-than/` | 是 |

被歸類為 team 的條目先落在本機暫存區，只有你明確發佈才會進 repository ——
這讓還在實驗的慣例不會擠進別人的 context。已發佈的條目跟其他條目一樣會被讀取與套用；
新的 team 捕捉仍然只寫進暫存區。

## 一筆條目長什麼樣

```markdown
---
topic: Prefer a named type rather than an inline structural shape, in exported signatures
scope: team
confidence: confirmed
category: types & API shape
observed-in: [http client wrappers, store selectors]
created: 2026-07-22
---

## Reason
An inline shape has no name to search for, so the next person changing the contract
cannot find its other end.

## Except
- Single-use local callback parameters
  - Reason: naming a type used once, one line away, costs more than it explains.

## Evidence
- 2026-07-22 src/api/client.ts:41
```

兩個性質讓這份 store 保持誠實。第一，主題**宣稱的範圍不得超過 `observed-in`** ——
在對外簽章上蒐集到的證據，只能得出關於對外簽章的偏好，不能變成無條件的全稱句。
把它放大到實際觀察到的情境之外叫做一般化，而一般化是晉升階段的工作，不是傾向的工作。
第二，**沒有「被取代」這個狀態**：一個條目只有兩種下場 —— 用 `Except` 收窄，或直接刪掉。
不留墓碑。

## 五種 Mode

| Mode | 觸發 | 做什麼 |
|---|---|---|
| A —— 捕捉 | 自動 | 記錄、分析、提問、套用 |
| B —— 整併 | 有待處理條目，或你要求 | 經審閱關卡併入 `prefer/` |
| C —— 檢視與維護 | 你要求 | 列出、閱讀、編輯、刪除、發佈／收回，或替整份 store 評分找出過期與低品質的條目 |
| D —— 晉升 | 只接受明確指令 | 把一群相關傾向蒸餾成單一原則，再過五道關卡 —— 支持度、例外封閉性、反例搜尋、可機械強制性分類、對抗式辯論。全部通過的，能用機制表達就變成 lint 或 tsconfig 的改動，否則寫成 `CLAUDE.md` 規則，來源條目隨之刪除 |
| E —— 從歷史啟動 | 只接受明確指令 | 替空的 store 播種：從 merge request 的審閱討論（`glab` / `gh`）與你自己那些「修正形狀」的 commit 裡挖，挖出來的一律當成普通候選，還是要經你確認 |

Mode D 與 E 永遠不會由模型自行判斷啟動，在你下令之前，連它們的參考檔都不會被讀進 context。

## 安裝

需求：Claude Code、`bash`，以及 `jq`（建議裝 —— 有它 hook 會靜默注入 context，
沒有它會退回純 stdout，功能一樣但會出現在對話記錄裡）。
Mode E 另外需要 `glab` 或 `gh` 才能挖審閱討論。

### 1. Skill

```bash
npx skills add kingdom84521/rather-than -g
```

`-g` 不是可選的。它會裝到 `~/.claude/skills/rather-than/`，那正是 hook 解析 skill script 的路徑；
預設的專案範圍（`./.claude/skills/`）會把它放在 hook 不會去看的地方。
整包都會跟著過去 —— `references/`、`scripts/`、`evals/` —— script 的執行位元也保留。

### 2. Hooks

[skills CLI](https://skills.sh) 只裝 skill，不裝 hook，所以這一半是手動的 ——
而且少了它 rather-than 什麼都不會做。建立 store、開每個 session 的 journal、
每個 turn 注入索引、在段落處停下來整併，全都是 hook 在做。
skill 自己只是一份沒人會去打開的文件。

```bash
git clone https://github.com/kingdom84521/rather-than.git
cp -R rather-than/hooks/rather-than "$HOME/.claude/hooks/"
chmod +x "$HOME/.claude/hooks/rather-than/"*.sh
```

接著把三個 hook 註冊進 `~/.claude/settings.json` —— 沒有 `hooks` 這個 key 就補上，
並且不要覆蓋你原有的項目：

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "bash \"$HOME/.claude/hooks/rather-than/session-start.sh\"" }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "bash \"$HOME/.claude/hooks/rather-than/prompt.sh\"" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "bash \"$HOME/.claude/hooks/rather-than/stop.sh\"" }] }
    ]
  }
}
```

用 shell 形式是刻意的：exec 形式（`args`）不經過 shell，`$HOME` 不會展開。

### 3. 驗證

開一個新 session 後用 `/hooks` 確認 —— 三個都應該出現在各自的事件下，來源是 `User`。
其他什麼都不用建，store 與它的狀態目錄會在第一次執行時出現。

要從頭驗一次行為，講一個沒有技術理由的風格要求（「這邊一律用 `for…of`，不要 `forEach`」）。
表面上應該什麼都不會發生 —— 它被靜默記下，問題會在下一個段落批次送到你面前。

### 更新

`npx skills update rather-than` 會更新 skill；hook 要再跑一次那行 `cp -R`。
你的 store 兩者都不會動到 —— 它在這兩個目錄之外。

## 附註

- 併行 session 是安全的：每次捕捉都寫進各自 session 的 journal，整併會取一個
  atomic `mkdir` 鎖，10 分鐘後視為過期。兩個 session 動到同一筆偏好，
  會得到兩份看得見的差異，而不是一次無聲的覆寫。
- Hook 在穩定狀態下只是幾次 `find` 探測加一次雜湊 —— 遠在 30 秒的
  `UserPromptSubmit` 逾時之內。
- 注入的文字一律寫成事實陳述，而不是命令句形式的系統指令，
  這是依 hooks 參考文件關於 prompt injection 防禦的建議。
- `index.md` 是衍生產物。要重建請用
  `skills/rather-than/scripts/rebuild-index.sh <root>`，永遠不要手改。
- 有爭議的條目衝突（Mode B）與晉升的第五道關卡（Mode D）會交給另一個
  `multi-debate` skill。它沒有包在這個 repo 裡；沒有它的話，這兩條路的辯論要手動跑。
- `skills/rather-than/evals/scenarios.md` 收著這套設計要對照的行為測試案例 ——
  該捕捉到的正例、該保持安靜的過濾、批次提問的節制。
  真實世界的失敗案例就該寫進那個檔，它們的份量大於人工編造的案例。

## 已知問題

以下都是實際拿來跑真實工作時觀察到的，不是假想。三者的根都是同一個：
store 是 Markdown，讀不讀、怎麼讀，全憑模型自己斟酌，沒有任何機制強制。

- **分析會誤解你的意思。** 分析階段把 journal 的原始行轉成候選，而它抓錯重點的頻率高到不能忽視 ——
  「而不是什麼」那一側被對調、只針對一個檔案講的話被一般化成一整類目標、
  推導出一個你根本不會給的理由。提問時的收據與 `REVIEW.md` 關卡是唯二的糾正點，
  這等於把「抓出誤解」的責任整個押在你身上。
- **寫程式前應該讀完整條目，實際上並沒有。** `SKILL.md` 要求先打開
  `prefer/<slug>.md`，而且標著 `[N except]` 的條目**必須**在使用前讀過。
  沒有任何東西在強制這件事，實際上模型是靠注入的單行索引在做事、跳過檔案 ——
  於是 `Except` 子句，也就是防止一個傾向誤觸的關鍵部分，成了整份 store 最少被讀到的地方。
  usage log 也量不到這件事：它記的是 applied／excepted／overridden，不是檔案有沒有被打開。
- **讀 store 沒有工具，而且很吃 context。** 沒有查詢能力 —— 沒有「給我這個分類的條目」，
  也沒有欄位投影。讀一筆條目就是 `cat` 整個檔，所以查個幾筆就會在
  frontmatter 與當下任務不需要的敘述上燒掉大量 context。這個成本又餵養了上一點：
  便宜的路（索引，本來就在 context 裡）永遠都在，正確的路（檔案）才是貴的那條。

這個 repository 只裝機制。偏好、journal、執行狀態都留在你自己的 `~/.claude/` 底下，
永遠不會進來。
