# rather-than

<p align="center">
  <strong>你的 coding agent 每一場 session 都要重新學一次你的品味。<br />rather-than 把它寫下來 —— 而且寫之前會先問你。</strong>
</p>

<p align="center">
  <a href="https://www.skills.sh/kingdom84521/rather-than"><img src="https://www.skills.sh/b/kingdom84521/rather-than" alt="skills.sh" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/kingdom84521/rather-than?style=flat" alt="License" /></a>
</p>

<p align="center">
  <a href="README.md">English</a> | 繁體中文
</p>

```bash
npx plugins add kingdom84521/rather-than
```

## 這個工具在解什麼問題

同一件事，你這個月已經跟 agent 講過四次了。

指示檔（`CLAUDE.md`、`AGENTS.md`）裝的是你特地坐下來寫的規則。其餘的一切都隨著 session 結束蒸發：
你順口做的糾正、它給兩個選項時你挑的那個、它產出後你默默手改掉的那段。
下一場 session，品味重新歸零。

而兩種常見的解法，各自壞在不同的地方：

- **memory 存的是事實。** 「API client 在 `src/api`」——這種話可以查證，而檔案一搬它就直接錯了。
  但你的品味不是事實，是**選擇**：這個**而不是**那個，有理由，而且存在「另一個才對」的例外。
- **寫進指示檔就變成規則。** 規則不會轉彎。從某個下午的不爽歸納出來的規則，
  總有一天會在它根本不該管的那個檔案裡發作，然後三個月後由你自己去刪掉它。

於是你只剩兩條路：永遠重複自己，或是把每一句順口的意見都升格成法律。

## 它做什麼

rather-than 卡在這兩者之間。它在日常對話裡盯著「你出手轉向」的那一刻 ——
一次糾正、一個要求、在兩個選項間挑一個、順口抱怨一句 —— 然後往 journal 寫下一行。
不打斷任務，也不會跟你宣告。

到了自然的段落，它把收集到的東西拿出來，濾掉雜訊，然後**帶著收據**問你一次：

> **導出的型別形狀，偏好 `interface` 而不是 `type` 別名？**
>
> - `2026-08-04` —— 你把我寫的 `type` 別名改回 `interface`，當時我們在加信件列表的 props。
> - `2026-08-11` —— 同樣的事又一次，在寫信表單的 props。
>
> `個人偏好` · `團隊慣例` · `暫緩` · `永不追蹤`

你回答之後，這筆偏好就以**傾向**的身分存下來：注入之後的每一場 session、在寫程式時被套用，
而當 agent 選擇往另一邊走時，它會**說一聲** —— 不是被擋下來。

沒有你的回答，什麼都不會進到 store。任何東西都不會離開你的機器。

## 為什麼是傾向，不是規則

以下這些設計上的限制，是為了讓它不會變成另一個「你最後把它關掉」的 linter：

- **它不阻擋、也不說教。** 傾向會讓路給正確性、當下的可讀性，以及它自己記下的例外。
  你要反過來做，它就反過來做，最多附一句話說明有這個偏向。
- **沒有確認就不會寫入。** 每一筆待寫入的變更都會先用白話翻譯出來 ——
  你將會看到什麼、將不會再看到什麼、在哪裡適用、在哪裡明確**不**適用 —— 然後等你點頭。
- **它宣稱的範圍不超過它看到的。** 在導出簽章上蒐集到的證據，只會得出關於導出簽章的偏好，
  不會變成無條件的全稱句。要放大，那是「晉升」的工作，不是傾向的。
- **例外是一等公民。** 一個條目只會被 `Except` 收窄，或直接刪掉。沒有墓碑狀態，
  也不會有條目在理由早已消失之後還悄悄活著。
- **要變成真正的規則，是另一條你必須明確下令、而且設有關卡的路。** 只有你下令，
  它才會嘗試把一群傾向蒸餾成單一原則，而且只有通過五道關卡的候選 ——
  支持度、例外封閉性、反例搜尋、可機械強制性分類、對抗式辯論 —— 才會送到你面前等核可。
  通過的會變成一條 lint 規則，或你指示檔裡的一行；來源條目隨之刪除。

## 跟 memory 類 plugin 的差別

一個判準就能分辨你要的是哪一種工具：

> 你想被記住的那件事，能不能寫成「**X rather than Y**」，而 **Y 並不算錯** ——
> 只是你沒選它？

如果 Y 真的是錯的 —— `rm -rf` 指到不該指的路徑、忘了刪的 `console.log`、根本沒跑的測試 ——
你要的是護欄，而護欄是另一台機器。
[hookify](https://github.com/anthropics/claude-code/tree/main/plugins/hookify)
挖的訊號跟這個工具一樣（你糾正過的東西），但它把訊號編譯成 regex 規則，
在工具層阻擋或警告。那是另一個問題，而 regex 本身就是證據：
沒有任何 pattern 能表達「導出簽章偏好具名型別，而不是內聯結構」——
沒有字串可以比對，而且兩邊都是合法的程式碼。

如果 Y 沒有錯，那你是在兩個都可以接受的選項之間做選擇。rather-than 只存這一種東西。

| | 帶回去什麼 | 存之前會問你嗎 | 例外與範圍 |
|---|---|---|---|
| session 記憶類 plugin（[claude-mem](https://github.com/thedotmack/claude-mem)、[Remember](https://claude.com/plugins/remember)、[basic-memory](https://github.com/basicmachines-co/basic-memory)） | 發生過什麼，經 AI 壓縮；專案事實 | 不會 —— 背景 hook | 不適用 |
| 內建 auto-memory 的 `feedback` 型別 | 你對「該怎麼工作」給過的指引 | 不會 | 沒有 |
| [remember.md](https://github.com/remember-md/remember) 的 `Persona.md` | 你的 code style，由 AI 自動維護 | 不會 | 沒有 |
| [learning-loop](https://github.com/melodykoh/learning-loop-skill) | 糾正、失敗模式、判斷轉變 | 會，在收尾時 | 分別路由成一條規則或一則事實 |
| **rather-than** | 那個選擇，**以及被它打敗的那個選項** | 會 —— 批次提問，並附上收據 | `Except` 子句、`observed-in` 範圍，以及一條設有關卡、通往「變成真正規則」的路 |

memory 回答的是「發生過什麼」與「什麼是真的」。rather-than 回答的是
「你選了什麼、而不是什麼、以及哪裡不適用」。兩者是疊加而不是競爭：
這裡不存任何專案事實，也取代不了記憶類 plugin 的搜尋能力。

## 安裝

<details open>
<summary><strong>Claude Code 與 Codex —— 一道指令</strong></summary>

```bash
npx plugins add kingdom84521/rather-than
```

安裝就這樣結束，而且是對 CLI 偵測到的每一個 agent 都裝。這個 repo 是一個
[open-plugin](https://www.npmjs.com/package/plugins) 套件，一道指令就把 skill 與三個 hook
都帶進來，由各 agent 自己的 plugin 系統註冊 —— 不用改 `settings.json` 或 `config.toml`，
也沒有東西要複製。

想先看會裝什麼，跑 `npx plugins discover kingdom84521/rather-than`，
它應該回報 `rather-than  1 skill, hooks`。只想裝一家就加 `-t claude-code` 或 `-t codex`。
更新就是把同一道指令再跑一次。

</details>

<details>
<summary><strong>只要 skill —— 任何支援 Agent Skills 的 agent</strong></summary>

[skills CLI](https://skills.sh) 能觸及的 agent 多得多，但它只裝 skill、別的都不裝 ——
它完全沒有 hook 的支援。走這條路，hook 要你自己擺，而擺好之前 rather-than 什麼都不會做：
建立 store、開每個 session 的 journal、每個 turn 注入索引、在段落處停下來整併，全都是 hook 在做。
skill 自己只是一份沒人會去打開的文件。

```bash
npx skills add kingdom84521/rather-than -g
git clone https://github.com/kingdom84521/rather-than.git
cp -R rather-than/hooks/rather-than "$HOME/.claude/hooks/"
chmod +x "$HOME/.claude/hooks/rather-than/"*.sh
```

`-g` 不是可選的：它會把 skill 裝到使用者層級的 skills 目錄，那正是沒有 plugin root 時
hook 會去找的地方 —— 它會依序試 `~/.claude/skills`、`~/.agents/skills`、`~/.codex/skills`。
預設的專案範圍（`./.claude/skills/`）會把它放在 hook 不會去看的位置。

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

</details>

<details>
<summary><strong>驗證安裝</strong></summary>

需求：`bash`，以及 `jq`（建議裝 —— 有它 hook 會靜默注入 context，
沒有它會退回純 stdout，功能一樣但會出現在對話記錄裡）。
從歷史啟動（bootstrap）另外需要 `glab` 或 `gh`。

開一個新 session 後用 `/hooks` 確認 —— 三個都應該出現在各自的事件下；走 plugin 這條路
來源會標成那個 plugin，走手動那條則是 `User`。
其他什麼都不用建，store 與它的狀態目錄會在第一次執行時出現。

要從頭驗一次行為，講一個沒有技術理由的風格要求（「這邊一律用 `for…of`，不要 `forEach`」）。
表面上應該什麼都不會發生 —— 它被靜默記下，問題會在下一個段落批次送到你面前。

</details>

## 支援的 agent

| Agent | Skill | 自動捕捉與注入 |
|---|---|---|
| Claude Code | 有 | 有 —— `SessionStart`、`UserPromptSubmit`、`Stop` |
| Codex | 有 | 有 —— 同樣三個事件、同樣的 `hookSpecificOutput.additionalContext` 與 `decision: block` 契約 |
| Cursor | 有 | 部分，且未附 adapter —— `sessionStart` 收 `additional_context`，但 `beforeSubmitPrompt` 只回 `continue`／`user_message`，每個 turn 的提醒沒有地方放 |
| 其他支援 Agent Skills 的 agent | 有 | 沒有 —— 能讀能套用 store，但沒有東西會自動捕捉或更新 |

Claude Code 與 Codex 能共用同一批 hook script，是因為這兩家共用同一份 hook 契約，
不是因為封裝格式讓 hook 變得可攜：open-plugin 定的只有 `hooks/hooks.json` 放在哪裡、
以及把 plugin root 變數依各家改寫，其餘內容它原封不動傳過去。
store 與判斷邏輯本來就與 agent 無關；只有自動化那層需要 hook，而 hook 正是多數 agent 還沒有的東西。

## 運作方式

三個部分。

**Hooks** —— 純檔案 IO、不呼叫 LLM：

| Hook | 事件 | 做什麼 |
|---|---|---|
| `session-start.sh` | SessionStart | store 不存在就建起來、開一份帶來源標頭的本 session journal、索引過期就重建，並把 store 索引與這個 session 需要的所有路徑注入 |
| `prompt.sh` | UserPromptSubmit | 每個 turn 重述那一句 journal 義務、更新 session 的存活標記；只有在 store 自本 session 上次讀過之後有變動時（通常是另一個 session 併行改動）才注入變動的索引行，而不是整份索引 |
| `stop.sh` | Stop | 有已確認條目在等著整併時，攔下這次停止一次（每個 session 每 30 分鐘最多一次），讓整併發生在自然的段落，而不是永遠不發生 |

**Skill** —— `SKILL.md` 與 `references/`，承載所有判斷：什麼算偏好訊號、什麼該被濾掉、
一個問題要怎麼問才算問得起、兩個條目要怎麼合併。

**Store** —— 自動建立，一個偏好一個 Markdown 檔：

```
<store>/
├── prefer/<slug>.md      # 一筆偏好一個檔 —— 唯一真實來源
├── index.md              # 產生出來的主題清單，每個 turn 都會注入
├── journal/<sid>.md      # 每個 session 的原始事件記錄
├── deferred/<slug>.md    # 你暫緩的候選，收據完整保留
├── ignore.md             # 你選擇不追蹤的主題
├── REVIEW.md             # 正在等你確認的那一筆變更
└── team/<repo-key>/      # team scope 的本機暫存區，依 repository 分開
```

store 的根目錄是解析出來的，不是寫死的：有設 `$RATHER_THAN_HOME` 就用它，否則用既有的
`~/.claude/rather-than`（所以什麼都不必搬），再否則用 `${XDG_DATA_HOME:-~/.local/share}/rather-than`。
它不在任何單一 agent 的設定目錄裡，也不在 plugin 或 CLI 更新會管的目錄裡 —— 執行狀態
（鎖、使用次數、每個 session 的簿記）放在 `<store>/.state/` 而不是裝好的 plugin 目錄裡，
正是同一個理由：那個目錄的路徑釘在 commit 上，每次更新就換一個。
team 暫存區是以 repo 為鍵，所以同一個 checkout 底下換 agent，跟著你的還是同一份 store。

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
   linter 或 formatter 已經在管的事、你的指示檔已經寫成規則的事、
   對模型提案的被動接受。存活下來的會以候選區塊寫回 journal ——
   分析結果絕不只留在模型腦袋裡。

3. **提問 —— 一律附收據** —— 一次批次提問、最多四個候選，每個都帶著日期、你當時說了什麼、
   那是「而不是什麼」、以及當時在做什麼。拿不出收據的問題，就是還沒準備好問的問題。

4. **整併** —— 已確認的區塊一次一筆併進 `prefer/`，而且要過審閱關卡。
   互相衝突的條目會進到對抗式辯論，而不是被無聲覆寫。

把已確認的偏好套用到當下的程式碼是立刻發生的，不必等上面任何簿記。

## Scope

| Scope | 根目錄 | 進 git |
|---|---|---|
| personal | `<store>/` | 否 |
| team（暫存） | `<store>/team/<repo-key>/` | 否 |
| project（已發佈） | `<repo>/.rather-than/`（舊的 `<repo>/.claude/rather-than/` 仍然認） | 是 |

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

## 五種 Mode

| Mode | 觸發 | 做什麼 |
|---|---|---|
| A —— 捕捉 | 自動 | 記錄、分析、提問、套用 |
| B —— 整併 | 有待處理條目，或你要求 | 經審閱關卡併入 `prefer/` |
| C —— 檢視與維護 | 你要求 | 列出、閱讀、編輯、刪除、發佈／收回，或替整份 store 評分找出過期與低品質的條目 |
| D —— 晉升 | 只接受明確指令 | 把一群相關傾向蒸餾成單一原則，再過那五道關卡；通過的，能用機制表達就變成 lint 或 tsconfig 的改動，否則寫成你指示檔裡的一條規則，來源條目隨之刪除 |
| E —— 從歷史啟動 | 只接受明確指令 | 替空的 store 播種：從 merge request 的審閱討論（`glab` / `gh`）與你自己那些「修正形狀」的 commit 裡挖，挖出來的一律當成普通候選，還是要經你確認 |

Mode D 與 E 永遠不會由模型自行判斷啟動，在你下令之前，連它們的參考檔都不會被讀進 context。

## 已知問題

以下都是實際拿來跑真實工作時觀察到的。前三點的根是同一個：
store 是 Markdown，讀不讀、怎麼讀，全憑模型自己斟酌，沒有任何機制強制。

- **分析會誤解你的意思。** 分析階段把 journal 的原始行轉成候選，而它抓錯重點的頻率高到不能忽視 ——
  「而不是什麼」那一側被對調、只針對一個檔案講的話被一般化成一整類目標、
  推導出一個你根本不會給的理由。提問時的收據與審閱關卡是唯二的糾正點，
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
- **Codex 這半邊是對著契約驗的，不是對著跑起來的 Codex 驗的。** 它文件上的 hook 事件、
  stdin 欄位與輸出格式跟 Claude Code 一致，hook 也已對著那份契約端到端跑過 ——
  但請在裝有 Codex CLI 的機器上跑一次 `npx plugins discover` 與一場真的 session 再信它。

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
- 這個 plugin 是用 vendor-neutral 的 open-plugin 格式寫的：`.plugin/plugin.json` 宣告
  `hooks/hooks.json`，其中的指令用 `${PLUGIN_ROOT}` —— plugin CLI 安裝時會把它改寫成各
  agent 自己的變數（`CLAUDE_PLUGIN_ROOT` 之類），而且它只改寫設定檔，不會改 script。
  所以 hook script 自己兩種變數都認，兩者都沒設時退回使用者層級的 skills 目錄，
  skills CLI 那條路就是靠這個成立。
- 有爭議的條目衝突與晉升的最後一道關卡會交給另一個 `multi-debate` skill。
  它沒有包在這個 repo 裡；沒有它的話，這兩條路的辯論要手動跑。
- `skills/rather-than/evals/scenarios.md` 收著這套設計要對照的行為測試案例 ——
  該捕捉到的正例、該保持安靜的過濾、批次提問的節制。
  真實世界的失敗案例就該寫進那個檔，它們的份量大於人工編造的案例。

這個 repository 只裝機制。偏好、journal、執行狀態都留在你自己的機器上，永遠不會進來。
