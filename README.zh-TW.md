# rather-than

<p align="center">
  <strong>你的 coding agent 每開一場新對話，就把你的品味忘光一次。<br />rather-than 把品味記下來 —— 而且記之前一定先問你。</strong>
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

同一件事，你這個月已經跟 agent 講四次了。

指示檔（`CLAUDE.md`、`AGENTS.md`）只裝得下你特地坐下來寫的規則。其他的東西，
session 一結束就消失：你順口糾正的那句話、它給兩個選項時你挑的那個、
它產出後你自己動手改掉的那段。下一場 session，一切歸零。

常見的兩種解法，各有各的問題：

- **memory 類工具存的是事實。**「API client 在 `src/api`」是事實：查得到，
  而且檔案一搬就變成錯的。但偏好不是事實，是**選擇**——選這個**而不是**那個，
  有理由，也有例外（例外的情況下反而該選另一邊）。
- **指示檔存的是規則。** 規則不會轉彎。你把某個下午的不爽寫成規則，
  它總有一天會在完全不該管的檔案裡發作。三個月後，動手刪掉它的人還是你。

所以你現在只有兩條路：永遠重複自己，或是把每句順口的意見都變成法律。

## 它做什麼

rather-than 站在這兩條路中間。它在日常對話裡留意你「出手糾正方向」的時刻——
一次糾正、一個要求、兩個選項裡挑一個、順口抱怨一句——然後往流水帳
（journal）寫一行。它不打斷你的工作，也不出聲。

到了自然的段落，它濾掉雜訊，帶著證據問你一次：

> **導出的型別形狀，偏好 `interface` 而不是 `type` 別名？**
>
> - `2026-08-04` —— 你把我寫的 `type` 別名改回 `interface`，當時我們在加信件列表的 props。
> - `2026-08-11` —— 同樣的事又一次，在寫信表單的 props。
>
> `個人偏好` · `團隊慣例` · `暫緩` · `永不追蹤`

你回答之後，這筆偏好就存成一個**傾向**（tendency，會影響方向但不強制的偏好）。
之後每場 session 都會載入它、寫程式時套用它；當 agent 要走另一邊時，
它只會提一句，不會擋下來。

你沒回答，就什麼都不會存。所有資料都留在你的機器上。

## 為什麼是「傾向」，不是規則

五條設計原則，讓它不會變成另一個你最後關掉的 linter：

- **不阻擋、不說教。** 傾向讓路給正確性、當下的可讀性、和它自己記下的例外。
  你要反著做，它就反著做，最多補一句「有這個傾向」。
- **沒確認就不寫入。** 每筆要存的變更都先翻成白話給你看：你會看到什麼、
  不會再看到什麼、哪裡適用、哪裡明確不適用。你點頭它才寫。
- **只主張它看到的範圍。** 證據來自導出簽章，就只存「關於導出簽章」的偏好，
  不會擴大成通用規則。要擴大，得走另一個步驟（晉升），而且只有你能啟動。
- **例外是一等公民。** 一筆條目要嘛用 `Except` 收窄，要嘛整筆刪掉。
  沒有封存狀態，也不會有條目在理由消失後還活著。
- **要變成真規則，必須你明確下令。** 你下令之後，它才會把一群相關傾向
  蒸餾成一條原則。這個候選要過五道關卡——支持度夠不夠、例外收乾淨了沒、
  找得到反例嗎、linter 能不能代勞、最後再吵一輪對抗式辯論——全過了才送你核准。
  過關的變成 lint 規則或指示檔裡的一行，來源條目隨之刪除。

## 跟 memory 類 plugin 差在哪

一個問題就能分辨你需要哪種工具：

> 你想記住的那件事，能不能寫成「**X rather than Y**」，而 **Y 並沒有錯**——
> 只是你沒選它？

如果 Y 真的是錯的——`rm -rf` 指錯路徑、忘了刪的 `console.log`、根本沒跑的測試——
你需要的是護欄，護欄是另一種工具。
[hookify](https://github.com/anthropics/claude-code/tree/main/plugins/hookify)
挖的訊號跟這裡一樣（你糾正過的事），但它把訊號編成 regex 規則，
在工具層阻擋或警告。regex 本身就說明了差異：「導出簽章偏好具名型別、
而不是內聯結構」寫不成任何 pattern——沒有字串可以比對，而且兩邊都是合法的程式碼。

如果 Y 沒有錯，你是在兩個都可以的選項之間挑一個。rather-than 只存這種選擇。

| | 帶回去什麼 | 存之前會問你嗎 | 例外與範圍 |
|---|---|---|---|
| session 記憶類 plugin（[claude-mem](https://github.com/thedotmack/claude-mem)、[Remember](https://claude.com/plugins/remember)、[basic-memory](https://github.com/basicmachines-co/basic-memory)） | 發生過什麼，經 AI 壓縮；專案事實 | 不會 —— 背景 hook | 不適用 |
| 內建 auto-memory 的 `feedback` 型別 | 你對「該怎麼工作」給過的指引 | 不會 | 沒有 |
| [remember.md](https://github.com/remember-md/remember) 的 `Persona.md` | 你的 code style，由 AI 自動維護 | 不會 | 沒有 |
| [learning-loop](https://github.com/melodykoh/learning-loop-skill) | 糾正、失敗模式、判斷轉變 | 會，在收尾時 | 分別存成一條規則或一則事實 |
| **rather-than** | 那個選擇，**加上被它比下去的選項** | 會 —— 批次提問，附證據 | `Except` 子句、`observed-in` 適用範圍，加一條通往真規則的關卡路 |

memory 回答「發生過什麼」和「什麼是真的」。rather-than 回答「你選了什麼、
沒選什麼、哪裡不適用」。兩者互補不衝突：這裡不存專案事實，
也取代不了 memory plugin 的搜尋。

## 安裝

<details open>
<summary><strong>Claude Code 與 Codex —— 一道指令</strong></summary>

```bash
npx plugins add kingdom84521/rather-than
```

這一道指令就是完整安裝，CLI 偵測到的每個 agent 都會裝。這個 repo 是
[open-plugin](https://www.npmjs.com/package/plugins) 套件：一道指令帶入
skill 和三個 hook，由各 agent 自己的 plugin 系統註冊。你不用改
`settings.json` 或 `config.toml`，也不用複製任何檔案。

想先看會裝什麼，跑 `npx plugins discover kingdom84521/rather-than`，
它應該回報 `rather-than  1 skill, hooks`。只想裝在一個 agent，
加 `-t claude-code` 或 `-t codex`。要更新，把同一道指令再跑一次——
然後看下面的「更新」。

</details>

<details>
<summary><strong>更新 —— 順便把 store 遷移過來</strong></summary>

**更新 plugin。** 把安裝指令再跑一次：

```bash
npx plugins add kingdom84521/rather-than -t claude-code
```

沒有 `npx plugins update` 這個指令。這個 CLI 會把不認識的字當成 repo 路徑，
然後印出 `No plugins found.`。新版會放在
`~/.claude/plugins/cache/kingdom84521-rather-than/rather-than/<commit>/`；
舊 commit 的目錄會留在旁邊，可以刪掉。

**遷移 store。** 開一個新 session。如果你的 store 比新版預期的舊，session context
會用一行告訴你，並寫出下面這個指令的完整路徑。你可以自己跑，也可以叫 agent 跑：

```bash
bash <plugin>/skills/rather-than/scripts/init.sh        # 只列計畫：會改什麼，什麼都不寫
bash <plugin>/skills/rather-than/scripts/init.sh --yes  # 套用；先備份到 <store>/.state/backups/
```

store 版面每改一次，就在 `skills/rather-than/migrations/` 多一個編號檔，
和改版面的那個 commit 一起寫好。`init` 讀 `<store>/.state/schema` 這個標記，
挑出你的 store 還缺的那幾個，按順序跑。跑兩次是安全的，第二次會發現沒事可做。

計畫怎麼看：`move` 是舊檔在新位置沒有對應，直接搬；`merge` 是兩邊都有，
把舊 log 缺的行補進去；`park` 是兩邊都有，舊的那份放到 `.state/legacy-conflicts/`
保留。回填的天數，是 hook 開始做記號之前、store 實際被用到的天數。

**從舊的「只給 Claude 用」的裝法過來**（複製到 `~/.claude/skills/` 和
`~/.claude/hooks/`、在 `settings.json` 手動加三筆的那種）：順序很重要，
因為舊 hook 只要還註冊著，就會繼續把狀態寫回舊位置。

1. 關掉這台機器上所有 Claude Code session。
2. 跑 `init.sh --yes`。migration 001 會把舊的使用紀錄從
   `~/.claude/skills/rather-than/.state/` 搬出來。
3. 把 `~/.claude/settings.json` 裡三筆 `hooks/rather-than/` 的項目刪掉。
   `init` 會印一行 `jq` 指令給你；它自己永遠不動這個檔。
4. 跑 `init.sh --yes --prune`。這會刪掉舊的 skill 副本；舊 hook 檔在沒有人引用之後
   也會一併刪掉。
5. 開新 session。`/hooks` 應該只在 plugin 名下列出三個 hook，
   `Store schema` 那行也不該再出現。

**遷移完之後，沒有要你手動做的事。** 兩件 script 做不到的改動改由規則處理：
舊的候選 block 被標成 `inferred`，下一次提問會先跟你確認用字；author 規則之前寫的
journal 帶著 `client unrecorded`，分析時會讀得更保守。第一次清理會比較久：
之前每個 session 沒消化的候選、沒分析的 journal 行，現在都會在 session 開頭
一起報出來。另外開一個 session 專門做（「整理偏好」），會比夾在工作中間輕鬆。

</details>

<details>
<summary><strong>把個人 store 同步到別台機器（選用）</strong></summary>

你的個人偏好可以跟著你到每一台機器。只有「知識」會走——`prefer/`、`deferred/`、
`ignore.md`；journal、索引、執行狀態、team 暫存區都留在原地。後端可以換，
出廠附兩個 adapter：

| Adapter | 存到哪 | 你需要什麼 |
|---|---|---|
| `s3` | 任何 S3 相容的 bucket：Cloudflare R2（免費 10 GB、不收流量費）、AWS S3、Backblaze B2、MinIO | 一組 access key；簽章由 `curl` 和 `openssl` 完成，不用裝東西 |
| `local` | 一個目錄：NFS 掛載、Dropbox 或 Drive 桌面同步資料夾 | 不用 |

**Cloudflare R2 一步一步來。** 到後台：R2 → Create bucket（名稱 `rather-than`，
位置 Automatic）。Manage R2 API Tokens → Create API token → 權限選 Object Read &
Write、範圍只給這個 bucket → 複製 Access Key ID 和 Secret Access Key。Overview →
複製 Account ID。然後寫設定檔——它放在 store 裡，大多數人的 store 是
`~/.claude/rather-than`：

```ini
# ~/.claude/rather-than/cloud.conf   （chmod 600）
adapter = s3
provider = r2
account_id = <account id>
bucket = rather-than
prefix = personal
access_key_id = <key>
secret_access_key = <secret>
```

```bash
bash <plugin>/skills/rather-than/scripts/cloud.sh status   # 檢查連得上，並列出試跑計畫
bash <plugin>/skills/rather-than/scripts/cloud.sh sync     # 第一次同步
```

也可以跑 `cloud.sh setup s3`，讓它問你同樣的值再幫你寫檔。另一台機器放同一份檔，
第一次同步就會把東西全部拉下來。之後 hook 會在背景同步：session 開始時拉別台
機器推上去的（下一個 prompt 會以索引變動的形式出現），以及某次回應改了條目之後
推上去。任何一步都不會等網路。

**兩台機器改到同一筆條目時**，比較新的那份留在原位，另一份保存在
`.state/cloud/conflicts/`。下一次 session 開頭會說，Mode C 會帶你合併——
不會有任何一份被無聲覆蓋，跟 journal 的規則一樣。在一台機器刪掉的條目，
另一台也會消失（它的副本在 `.state/cloud/trash/` 留 30 天）；一台在改、
另一台在刪的條目，保留改過的那份。

`cloud.sh off` 暫停背景同步；`on` 恢復；`conflicts` 列出保存的衝突副本。
其他供應商、以及怎麼自己寫一個 adapter（五個 shell 函式），見
[`skills/rather-than/scripts/cloud.d/README.md`](skills/rather-than/scripts/cloud.d/README.md)。

</details>

<details>
<summary><strong>只裝 skill —— 任何支援 Agent Skills 的 agent</strong></summary>

[skills CLI](https://skills.sh) 支援的 agent 多很多，但它只裝 skill，
裝不了 hook。沒有 hook，rather-than 什麼都不會做：建 store（存放偏好的
資料夾）、開每個 session 的 journal、每回合注入索引、在段落停下來整併，
全都是 hook 在做。所以走這條路，hook 要自己放：

```bash
npx skills add kingdom84521/rather-than -g
git clone https://github.com/kingdom84521/rather-than.git
cp -R rather-than/hooks/rather-than "$HOME/.claude/hooks/"
chmod +x "$HOME/.claude/hooks/rather-than/"*.sh
```

`-g` 一定要加。它把 skill 裝到使用者層級的目錄——沒設 plugin root 時，
hook 就是去那裡找，依序試 `~/.claude/skills`、`~/.agents/skills`、
`~/.codex/skills`。預設的專案層級目錄（`./.claude/skills/`）hook 不會去看。

接著把三個 hook 註冊進 `~/.claude/settings.json`。沒有 `hooks` 這個 key
就補上；已經有的項目保留，不要蓋掉：

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

請照上面用 shell 形式寫。exec 形式（`args`）不經過 shell，`$HOME` 不會展開。

</details>

<details>
<summary><strong>驗證安裝</strong></summary>

需要 `bash`，最好也裝 `jq`。有 `jq` 時 hook 靜默注入 context；沒有時改印到
stdout——功能一樣，但文字會出現在對話記錄裡。要從歷史挖偏好（Mode E），
另外需要 `glab` 或 `gh`。

開一場新 session，跑 `/hooks`。三個 hook 都該出現在各自的事件下——
走 plugin 路線的會標成 plugin，手動註冊的標成 `User`。其他什麼都不用建：
store 和狀態目錄會在第一次執行時自己出現。

想完整測一遍，講一個沒有技術理由的風格要求（「這邊一律用 `for…of`，
不要 `forEach`」）。表面上什麼都不會發生：它被靜默記下，
問題會在下一個段落一起送到你面前。

</details>

## 支援的 agent

| Agent | Skill | 自動捕捉與注入 |
|---|---|---|
| Claude Code | 有 | 有 —— `SessionStart`、`UserPromptSubmit`、`Stop` |
| Codex | 有 | 有 —— 同樣三個事件、同樣的 `hookSpecificOutput.additionalContext` 與 `decision: block` 契約 |
| Cursor | 有 | 部分，未附轉接層 —— `sessionStart` 收 `additional_context`，但 `beforeSubmitPrompt` 只回 `continue`／`user_message`，每回合的提醒沒地方放 |
| 其他支援 Agent Skills 的 agent | 有 | 沒有 —— 能讀能套用 store，但沒有東西會自動捕捉或更新 |

Claude Code 和 Codex 能共用同一批 hook script，是因為兩家的 hook 契約相同，
不是因為封裝格式讓 hook 變得可攜。open-plugin 只規定 `hooks/hooks.json`
放哪裡、並把 plugin root 變數改寫成各家的名字；其他內容原樣傳過去。
store 和判斷邏輯在任何 agent 上都能用；只有自動化那層需要 hook，
而多數 agent 還沒有 hook。

## 運作方式

三個部分。

**Hooks** —— 只做檔案操作，不呼叫 LLM：

| Hook | 事件 | 做什麼 |
|---|---|---|
| `session-start.sh` | SessionStart | store 不存在就建立（並蓋上目前的 schema 版本）、開一份帶來源標頭的 journal、索引過期就重建、把今天標成活躍日、記下 usage 基準線、store 版面落後 plugin 時說一聲、有設定雲端同步就在背景啟動一次，然後注入索引和這場 session 需要的所有路徑 |
| `prompt.sh` | UserPromptSubmit | 每回合重述那一句記錄義務、更新 session 存活標記和當天的活躍標記；只有別的 session 改過 store 時，才注入變動的索引行 |
| `stop.sh` | Stop | 有已確認的條目在等整併時，攔下這次結束一次（每 session 每 30 分鐘最多一次），讓整併在段落發生，而不是永遠不發生。同樣地，這次回應改了檔案卻一筆 usage 都沒記時，也攔一次，讓帳在段落被補上。條目有變動時在背景啟動一次雲端同步 |

**Skill** —— `SKILL.md` 和 `references/`，裝著所有判斷：什麼算偏好訊號、
什麼該濾掉、問題要怎麼問、兩筆條目怎麼合併。

**Store** —— 自動建立，一筆偏好一個 Markdown 檔：

```
<store>/
├── prefer/<slug>.md      # 一筆偏好一個檔 —— 唯一真實來源
├── index.md              # 產生出來、依活性分層的主題清單，每回合注入
├── journal/<sid>.md      # 每個 session 的原始事件流水帳
├── deferred/<slug>.md    # 你按過「暫緩」的候選，證據完整保留
├── ignore.md             # 你選擇不追蹤的主題
├── REVIEW.md             # 正在等你確認的那一筆變更
├── team/<repo-key>/      # team 範圍的本機暫存區，一個 repo 一份
└── .state/               # 鎖、usage 帳、活躍日標記、schema 標記
```

store 的位置在執行時決定，順序是：你設了 `$RATHER_THAN_HOME` 就用它；
已經有 `~/.claude/rather-than` 就用它（所以什麼都不用搬）；
都沒有就用 `${XDG_DATA_HOME:-~/.local/share}/rather-than`。
store 不在任何 agent 的設定目錄裡，也不在 plugin 更新會動到的目錄裡。
同一個理由，執行狀態（鎖、使用次數、每個 session 的記號）放在
`<store>/.state/`，不放在裝好的 plugin 裡——plugin 的路徑釘在 commit 上，
每次更新就整個換掉。team 暫存區以 repo 為鍵，所以在同一個 checkout 裡
換 agent，用的還是同一份 store。

## 流程

捕捉刻意分成兩層。在任務壓力下，「記得寫一句話」比「跑一次完整分類」
可靠得多；而且漏記救不回來，分析錯了可以重來。

1. **記錄**（每回合，不做判斷）。每個糾正方向的事件，在 journal 寫一句英文：
   指示、對模型輸出的糾正、順口的評價、兩個選項裡挑的那個、對工作方式的要求，
   還有模型自己注意到的程式碼慣例。每行都寫明當時在做什麼，
   而且趁「沒被選上的那一邊」還存在時記下來——被蓋掉的草稿、沒挑的選項、
   原本的行為，這回合過了就全部消失。

2. **分析**（批次做，絕不在任務中間）。到了段落、或原始行累積夠多，
   這些行會過一輪訊號分類和硬性過濾。會被濾掉的：只管當下的指示、
   指名單一目標而不是一類目標的任務、linter 已經在管的事、
   指示檔已經寫了的事、你只是沒反對模型自己的提案。
   留下來的寫回 journal 變成候選區塊——分析結果不能只留在模型腦袋裡。

3. **提問——一定帶證據。** 一次批次提問，最多四個候選。每個都帶日期、
   你當時說的話、被比下去的選項、當時在做什麼。拿不出證據的問題就還不能問。

4. **整併。** 確認過的區塊一次一筆併入 `prefer/`，而且要過審閱關卡。
   互相衝突的條目送進對抗式辯論，不會被無聲蓋掉。

把已確認的偏好套用到手上的程式碼是立刻發生的，不等上面這些簿記。

## 範圍

| 範圍 | 根目錄 | 進 git |
|---|---|---|
| personal | `<store>/` | 否 |
| team（暫存） | `<store>/team/<repo-key>/` | 否 |
| project（已發佈） | `<repo>/.rather-than/`（舊路徑 `<repo>/.claude/rather-than/` 仍然認得） | 是 |

歸類為 team 的條目先進本機暫存區，你明確發佈了才進 repository——
還在實驗的慣例不會跑進同事的 context。發佈後的條目跟其他條目一樣被讀取套用；
新的 team 捕捉還是先進暫存區。

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
| B —— 整併 | 有待處理條目，或你要求 | 過審閱關卡，併入 `prefer/` |
| C —— 檢視與維護 | 你要求 | 列出、閱讀、編輯、刪除、發佈／收回，或替整個 store 評分，找出過期和低品質的條目 |
| D —— 晉升 | 只接受明確指令 | 把一群相關傾向蒸餾成一條原則，過五道關卡。機器能強制的變成 lint 或 tsconfig 設定，不能的寫進指示檔；來源條目刪除 |
| E —— 從歷史挖 | 只接受明確指令 | 替空的 store 播種：從 merge request 的審查討論（`glab`／`gh`）和你那些「修正形狀」的 commit 裡挖。挖出來的當一般候選排隊，還是要你確認 |

Mode D 和 E 絕不會由模型自己啟動。你下令之前，連它們的參考檔都不會被讀進
context。

## 已知問題

以下都是拿真實工作跑出來的觀察。前三點的根源相同：store 是 Markdown，
讀不讀、怎麼讀全看模型自己，沒有機制強制。後兩點的根源是另一個：
捕捉只是一條模型會遵守的指示，背後沒有機制知道「說話的是誰」、
「已經寫了多少」。

- **分析會誤解你的意思。** 分析步驟把 journal 的原始行轉成候選，
  而它錯的頻率高到不能忽視：把你選的那邊和沒選的那邊弄反、
  把只講一個檔案的話擴大成一整類、編出一個你根本不會給的理由。
  能糾正它的只有提問時附的證據和審閱關卡——也就是說，抓錯全靠你。
  *應已在 `e3d3ec2` 修正（span 紀律），尚未實測驗證。*
- **寫程式前該讀完整條目，實際上沒有。** `SKILL.md` 要求先開
  `prefer/<slug>.md`，標著 `[N except]` 的條目更是必須先讀。
  但沒有機制強制。實際上模型只看注入的單行索引、跳過檔案——
  於是 `Except` 子句（防止傾向誤用的關鍵）成了整個 store 最少人讀的部分。
  usage log 也量不到這件事：它記的是 applied／excepted／overridden，
  不是檔案有沒有被開過。
  *應已在 `21e2afc` 修正（Except 直接寫進索引行；`query.sh` 讓正確的讀法變便宜），尚未實測驗證。*
- **讀 store 沒有工具，而且很吃 context。** 沒有查詢功能：不能「給我這個分類的條目」，
  也不能只讀某幾個欄位。讀一筆條目就是印出整個檔案，查個幾筆就會把 context
  燒在任務用不到的 frontmatter 和說明文字上。這個成本又加重了上一點：
  便宜的路（索引，本來就在 context 裡）永遠都在，正確的路（檔案）偏偏是貴的。
  *應已在 `21e2afc` 修正（`scripts/query.sh`），尚未實測驗證。*
- **分不出是你在糾正，還是另一個 AI。** 整套機制的前提是「人在糾正方向」——
  journal 的句型甚至以「User…」開頭。但 subagent 收到的 prompt 來自它的父 agent、
  跨 session 的訊息來自另一個模型，而 hook 收到的輸入不帶作者身分。
  於是 agent 之間的往來（父對子、子對父、平行之間）會像你親口說的一樣進到
  journal，甚至進到批次提問——「證據」引用的其實是 AI，不是你。
  在 store 記下說話者之前，不是你親自開的 session，它的證據都該多看一眼。
  *應已在 `d05757b` 修正（作者紀律加分析的零號關卡——但這是紀律，不是機制），尚未實測驗證。*
- **記多少，取決於用哪個介面，不是你糾正了多少。** 這份義務只是一行注入的文字，
  模型自己遵守。背後沒有計數器、沒有頻率上限、寫入時也不去重，
  所以積極程度隨環境變——同樣的工作量，VS Code 擴充看起來就比終端機 CLI 記得多。
  store 本身也量不出來：來源標頭記了 session、repo、暫存根目錄、開始時間，
  就是沒有客戶端身分。所以這只是印象，不是數字。
  *已在 `d05757b` 部分修正（來源標頭記下客戶端身分，變得可量測；加上「一個事件一行」的去重），尚未實測驗證——計數器和頻率上限仍然沒有。*
- **Codex 那半邊只對過文件上的契約，沒對過真的 Codex。** 它文件上的 hook 事件、
  stdin 欄位、輸出格式都和 Claude Code 一致，hook 也對著這份契約完整測過。
  但要信它之前，請在裝了 Codex CLI 的機器上跑一次 `npx plugins discover`
  和一場真的 session。

## 附註

- 多個 session 同時開是安全的。每次捕捉都寫進自己 session 的 journal；
  整併會拿一個 atomic `mkdir` 鎖，10 分鐘沒動就視為過期。兩個 session
  動到同一筆偏好，你會看到兩份變更，而不是一次無聲覆蓋。
- hook 每回合只花幾次 `find` 和一次雜湊——離 `UserPromptSubmit` 的
  30 秒上限很遠。
- 注入的文字都寫成事實陳述，不寫成命令句，這是照 hooks 參考文件
  對 prompt injection 防禦的建議。
- `index.md` 是產生出來的。要重建就跑
  `skills/rather-than/scripts/rebuild-index.sh <root> [<state-dir>]`，
  永遠不要手改。
- 索引的分層方式模仿習慣：條目靠「被使用」掙得常駐（`habitual`）地位。
  活性用 ACT-R 式公式從 usage.log 事件、Evidence 日期、`created` 算出——
  用得越多越近分數越高，分數隨時間以冪次衰減。不用就沉回 `cold`；
  被反覆推翻（override）就直接打入 cold。cold 條目只以
  「分類：數量（slug）」注入，工作碰到時再用 `query.sh` 查。
  habitual 層最多 `RATHER_THAN_HABIT_MAX` 筆（預設 15）。
  hook 每天重刷一次索引，衰減才會跟著時間走，而不是只跟著寫入走。
- usage 這本帳不靠模型記得去寫。`query.sh` 每印出一筆條目，
  就自己記一筆 `consulted` 事件（維護型讀取加 `-n`，看一看不算使用）；
  Stop hook 則在「這次回應改了檔案、usage 卻零成長」時，強制補一次帳。
  衰減也用**活躍天**計算——hook 會把 store 被用到的每一天標記下來——
  所以出門三週回來，什麼都不會冷掉：習慣因為錯過練習而消退，
  不是因為日曆翻頁。
- `skills/rather-than/scripts/query.sh <root>` 是便宜的讀取方式：
  `-c` 篩分類、`-s` 選 slug、`-m` 比對文字、`-f` 挑欄位。
  預設輸出（topic、`observed-in`、Except）正是套用傾向時需要的三樣東西。
- store 有版本。`<store>/.state/schema` 記著最後套用的版面 migration 編號；
  `skills/rather-than/migrations/` 收著每一個 migration——版面每改一次一個檔，
  和改版面的那個 commit 一起寫好——還有對應到 commit 的帳本。
  `scripts/init.sh` 負責算出某個 store 還缺哪些，然後套用。
  檔案操作做不到的事（重讀 author 規則之前寫的 journal、補回候選當初沒記的
  span）寫成規則——DETECTION.md 的 legacy-journal 規則、`inferred` 的 span
  交給提問確認——不讓 script 猜。
- 這個 plugin 用 vendor 中立的 open-plugin 格式寫成。`.plugin/plugin.json`
  宣告 `hooks/hooks.json`，裡面的指令用 `${PLUGIN_ROOT}`。安裝時 plugin CLI
  把這個變數改寫成各家自己的名字（例如 `CLAUDE_PLUGIN_ROOT`）——
  而且它只改寫設定檔，不改 script。所以 hook script 自己兩種變數都認，
  兩個都沒設時退回使用者層級的 skills 目錄。skills CLI 那條安裝路線
  就是靠這個退路成立的。
- 有爭議的條目衝突、和晉升的最後一關，會交給另一個 `multi-debate` skill。
  它沒有包在這個 repo 裡；沒裝它的話，這兩種辯論要自己手動跑。
- `skills/rather-than/evals/scenarios.md` 收著這套設計的行為測試案例：
  該捕捉到的正例、該保持安靜的過濾、批次提問的節制。真實世界的失敗案例
  請寫進這個檔——它們比人工編的案例更重要。

這個 repository 只放機制。你的偏好、journal、執行狀態都留在你自己的機器上，
永遠不會進到這裡。
