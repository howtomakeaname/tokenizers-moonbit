# PROGRESS — tokenizers-moonbit 开发进度与任务跟踪

> **本文档维护约定（后续接手的模型/开发者请先读）**
>
> - 本文件是进度的唯一真相源；**细节看 git 历史与 PR 链接**，这里保留"当前状态 + 足以独立开展工作的细节"。
> - 接手先读 §2（当前状态与下一步），需要细节再按 §3–§6 下钻。
> - 更新规则：
>   1. 新工作开始 → 在 §2 待办队列表加一行（做什么/验收口径）；
>   2. 每个 PR 合入 → 在 §2「最近工作日志」**顶部**加摘要（日期 + PR 号 + 改了什么 + 为什么 + 验证数据，5–15 行为宜）；
>   3. 能力/组件变化 → 同步改 §4 矩阵；发现新缺口 → 加进 §5；
>   4. 「最近工作日志」超过 ~30 条时，把最旧的按主题并入 §7 历史归档；
>   5. 归档节按主题组织、保留具体事实（API 名、规则、数据），**禁止**退化为纯流水账或过度压缩。

## 1. 项目定位与硬约束

- MoonBit 版 HuggingFace `tokenizers`：加载标准 `tokenizer.json`，全后端（wasm/wasm-gc/js/native）运行同一套 encode/decode，无 FFI。
- **对齐基准：Python `tokenizers` 0.22.2**（用户指定；HF 0.23-dev 的行为变化不跟随，遇到差异先实测 0.22.2 —— 已知分歧例：pair truncation overflow 0.23 改为每侧独立窗口，本库按 0.22.2 叉积实现）。
- 原则：inference-first、确定性、跨 target；**精确 HF 行为优先于大而全**；不支持的行为必须显式失败（加载期 `UnsupportedComponent` / 运行期报错），**绝不静默近似**。
- 公开 API 变更必须 `moon info` 更新 .mbti。
- 措辞红线（合规）：PR/commit/docs 只用"行为对比/probe/对拍"，禁用逆向类词汇。
- 发布：mooncakes `howtomakeaname/tokenizers-moonbit`，已发 0.1.0→**0.11.0**（2026-09-22，0.10.3 后含 PR #56 锚定 plus 拼写 + 混合锚窗口）。0.11.0 后待办见 §2 队列。

## 2. 当前状态与下一步（TL;DR）

**状态（2026-09-21）**：行为对比扫描**双双全绿**——合成 1134/1134、真实模型 100/100（Python 0.22.2 基准）；39 模型 fixture 对拍全绿；测试 native/js 452、wasm/wasm-gc 429；CI 8/8（含 HF benchmark smoke）。Replace text/aligned 双路径已统一到共享匹配 span 分发器（PR #19），71 拼写 ×20 输入等价扫描在库内常驻。

### 待办队列

| 优先级 | 事项 | 验收口径 | 备注 |
|---|---|---|---|
| P1 | normalizer Replace 不支持 regex 族的**加载期显式门** | 穷举 chain 支持族做判定，未知族 load 期 `UnsupportedComponent`，不得误拒现有 39 模型 | 需先枚举 `normalize_utils.mbt` replace_all 全部族；decoder 侧同类门见 PR #8（`replace_pattern_supported`） |
| P2 | identity 对齐列 lazy 化 | `tokenizer-encode-special-switch-mixed` 微基准回到 +14% 以内 | encode 热路径每归一化字符一个 tuple（PR #9 评审 nit；identity 情形可延迟构造） |
| P2 | `replace_pattern_supported` 与 `replace_all` 分发表去重 | 从 `@common` 暴露统一族判定，两处调用同一实现 | 两处表会漂移（PR #8 评审 nit） |

| P3 | 高级 trainer 大语料 EM 对拍 | 与 HF trainer 在真实语料逐 id 对比；需外部数据集 | 当前 Unigram 为 deterministic ranking+shrinking 近似（§7.4） |
| P3 | Hub sidecar 内容解析与错误映射 | 参照 hf-tokenizers 源码逐项对拍 | R11 遗留 |
| P3 | Python binding 低频 alias 长尾 | 按需 | 已至第三十七批（§7.4） |

### 最近工作日志（新在上）
- **2026-09-22 发版 0.11.0（已发布，干净验证 4/4×三后端）**：0.10.3 后 PR #56 单批。直接推 main：bump + `moon publish` 200 OK + /tmp/verify0110 干净验证（`\b\w+`、`\b\w+?`、`\ba{2,4}\B`、`\b\S+\b` 混合词性回缩，含字面反斜杠输入与 HF 逐字符一致）。
- **2026-09-22 PR #56**（6 commit，两轮评审，round-2 APPROVE）：锚定 **plus 拼写** + **混合 \b+\B 锚窗口**。探针定真值：`\bX+`≡`\bX{1,}`、`\bX+?`≡`\bX{1}`（空续接使惰性组停在最小值），**真 \b 尾锚例外**（`\ba+?\b` 于 'aaa'→'#'，惰性升到 run 尾；`b_trail` 参数分流 \b/\B/混合三路调用）；混合锚 = 起点一种锚门控 → 窗口内贪婪 → 逐字符回缩到另一锚成立（`\ba{2,4}\B` 于 'aaaa'→'#a'），新 `mixed_anchor_window_spec`/`mixed_anchor_window_spans` + 四处 dispatch。**评审两轮抓真问题**：round-1 发现混合词性基类（`\S`/`\D`/`[^0-9]`/`\P{…}`/`\p{P}`/`[^A-Za-z0-9_]`，kind 集 {8,12,14,16,17,18,19,23,25,29}）内部可持 \b——惰性+尾锚显式拒绝（我补探 19/25 两 kind 亦发散）；并顺藤发现 **main 上既有分歧**：\b 族 we 路径只测 full-run 尾、混合基贪婪窗需 hi 封顶后回缩（`\b\S+\b` 于 'a\nb, c'→'#\n#, #'）——统一 greedy-cap+shrink，均匀基字节等价（评审 A/B 2303 行 byte-identical 佐证）。round-2 独立对拍 3825+343 单元零分歧。星号/占有量词/混合零下限/`\ba{2}?\B`/`\b\++` 保持显式拒绝；`\w{5x}` 类确认 HF 为字面量 concat no-op（拒绝对齐无碍）。支持位 pin 测试提交前抓到 plus 分支吞任意非 `}` 尾的真 bug（`\ba*` 误判 `{1,}`）。四后端 517/496 全绿 + 双扫描 1134/1134 + 100/100。
- **2026-09-22 发版 0.10.3（已发布，干净验证 4/4×三后端）**：0.10.2 后 PR #55 单批。直接推 main：bump + `moon publish` 成功 + /tmp/verify0103 干净验证（`\B\w{5}` 非边界窗、`\ba{2}?` 回归、`^\w{1,2}` 回归、`\w{5}` 回归）。

- **2026-09-22 PR #55**（4 commit，一轮评审 APPROVE）：`\B` 非边界族（windows + lazy-exact）。`\B`→`\b` 改写 + 共享 `boundary_window_parse`（\b 零下限收窄留在 \b 侧 caller——提取经验证行为保持，168 拼写 sweep byte-identical）。**尾 \B 规则与 \b 结构不同**：左扫贪婪、尾 \B 回缩长度至端点为非边界（`\w{5}\B` 于 'zaaaaaz' → (0,5) → '#az'，而 \b 是钉 run 尾）。专设引擎；`\Ba{2}?` 可选组反向；精确 `{0}` 内部空（'zaaz'→'z#a#a#z'）；**\B 零下限区间拒绝**（与 \b 同型的 walk-vs-scan 分歧，HF 逐位重启贪婪扫描）。评审 1263 cell 三方对拍（949 normalizer + 949 decoder 零分歧，main-vs-PR 零回归）；515/515（native/js）、双扫描全绿。遗留（评审记录）：混合锚 `\ba{2}\B`、plus 惰性锚定 `\B\w+?`。

- **2026-09-22 发版 0.10.2（已发布，干净验证 4/4×三后端）**：0.10.1 后 PR #54 单批。直接推 main：bump + `moon publish` 成功 + /tmp/verify0102 干净验证（`\ba{2}?` 惰性 exact、`^\w{1,2}` 回归、`\b\w{5}` 回归、`\w{5}` 回归）。

- **2026-09-22 PR #54**（4 commit，两轮评审）：边界惰性 exact `\ba{2}?` / `\w{2}?\b`。onig 把 `X{n}?` 解析为**可选组** `(X{n})?`——块命中双锚时替换、否则在锚位置插空、无其他回退（`\ba{2}?` 于 'aaa'→'#a#'；`\ba{2}?\b` 于 'aaaa'→'#aaaa#' 块失败尾锚两空齐发；`\w{5}?\b` 于 'zaaaaaz'→'#za#' 块须终于 EOS 词边界）。实现委托 boundary_window_spec 于去 `?` 串（**保留尾 \b 使 we flag 存活**——两次自验修 strip 边界算术）+ 专属引擎。**意外发现**：区间惰性锚定形（`{n,m}?`/`{n,}?`）早已经 lazy_normalize 折叠到 `{n}` 窗正确工作（无空回退）——我首版电池误断言不支持，探针纠正自己。评审 F1：`cut<6` 误拒 we-only 单字符基 `a{2}?\b`（HF 可算）→ cut 降至 5 + 7 cell 锁定。两轮 ~330 cell；513/513（native/js）、双扫描全绿。遗留（评审记录）：`a{2}?\\b` 字面反斜杠尾、`\b\w+?` plus 惰性锚定、重复锚。

- **2026-09-22 发版 0.10.1（已发布，干净验证 4/4×三后端）**：0.10.0 后 PR #53 单批。直接推 main：bump + `moon publish` 成功 + /tmp/verify0101 干净验证（`^\w{1,2}` 单锚窗、`\b\w{5}` 回归、`\w{5}` 回归、裸 `\s` Split 回归）。

- **2026-09-22 PR #53**（4 commit，两轮评审）：单锚窗口 `^\w{1,2}` / `\w{1,2}$`。`single_anchor_window_spec`（^BASE{n|n,m|n,}/BASE{...}$，零下限与 {n,0} 拒绝——空走位置全局非锚定）+ 引擎：**首锚**块起于行首贪婪窗口内、谓词须在锚处成立（`^\w{1,2}` 于 '  ab cd' 不变）；**尾锚**块终于行尾取最大 len ≤ min(hi, run)（首版实现我自验抓出 trailing 用 e 而非 i 的锚位 bug）。评审一项 blocking：**尾锚 nl-pred 基整体拒绝**（评审识别两种缺陷模式——floor 过限与最小端发射，`\s{2}$` 于 'a \n' HF 'a#' 我们 no-op）——按双锚族规则；**首锚 nl-pred 保留**（评审实证含跨换行 run 全对，锁定 4 例）。两轮 558 cell；510/510（native/js）、双扫描全绿。遗留（评审记录）：`^a{2}\n` 尾随字面、点基 `^.{2}`、惰性 `^a{2}?`。

- **2026-09-22 发版 0.10.0（已发布，干净验证 4/4×三后端）**：0.9.8 后 PR #52 单批。直接推 main：bump + `moon publish` 成功 + /tmp/verify010 干净验证（`\b\w{5}` 边界窗、`a{2,0}` 回归、`\w{5}` 类窗回归、裸 `\s` Split 回归）。

- **2026-09-22 PR #52**（5 commit，三轮评审）：边界窗（`\b\w{5}`/`\w{5}\b`/`\ba{2,4}\b`）。`boundary_window_spec`（`[\b]BASE{n|n,m|n,|0形}[\b]` 至少一锚，基经 bare_class_kind/字面/转义，cap 100000）+ 引擎：**尾 \b 强制块终结于词边界**（字面基 run 止于词字符非边界——'aaz' 内的 'aa' 不匹配）；双锚 = 窗口内整词；首锚 = 词首贪婪；尾锚独 = run 末窗口（左扫边界约束端）。评审三轮：F1/F2 零下限端锚静默分歧（HF 逐位贪婪-空回退——`\ba{0,2}\b` 于 'aab'→'#aab#'，空走模型不可表达）→ **收窄拒绝**；R2 评审诚实纠正自己 round-1 探针不足（ws-only 零下限区间同样分歧，'zaaz'→'#az#' 15 cell）→ 拒绝扩至任意锚；仅精确 `{0}` 保留（纯边界过滤空走，全电池验证）。三轮 ~570 cell；507/507（native/js）、双扫描全绿。遗留（记录）：`\bBASE{n}?` 惰性 exact、`\B` 非边界族。

- **2026-09-22 发版 0.9.8（已发布，干净验证 4/4×三后端）**：0.9.7 后 PR #51 单批。直接推 main：bump + `moon publish` 成功 + /tmp/verify098 干净验证（`a{2,0}` 游走、`\w{5,0}`、尾零变体、`\w{5}` 回归）。

- **2026-09-22 PR #51**（2 commit，评审 agent 超时 → 自验合入）：`{n,0}` 路由到零下限引擎。并排探针钉死语义：onig 交换 `{n,0}`→`{0,n}`（`\s{5,0}`==`\s{0,5}`、`\w{5,0}`==`\w{0,5}`、`a{2,0}`==`a{0,2}` 逐输入一致——**首版电池两格抄错**，把 `{n}` 形状的输出当成了 `{n,0}`，新鲜探针纠正）。实现：`zero_min_quantifier_spec` 加 `{n,0}` 分支（数字 1..100000 + `,0`，基经 `zero_min_base`——字面/转义/类全落地现有空匹配引擎；dispatch 在 char_bounded `{n,0}` 拒绝之后天然到达）。自验抓出两个变体缺口并修复：尾零 `a{2,00}`、前导零 `a{02,0}`（HF 均计算）；`a{2,0,}`/`a{2,0x}` 保持字面量。原"reversed zero rejects"锁定翻转为支持。505/505（native/js）、双扫描全绿、CI 8/8。

- **2026-09-22 发版 0.9.7（已发布，干净验证 4/4×三后端）**：0.9.6 后 PR #50 单批。直接推 main：bump + `moon publish` 成功 + /tmp/verify097 干净验证（`\w{5}` 类窗、`\d{5}` 块、`^a{5}$` 锚定窗、裸 `\s` Split 回归）。

- **2026-09-22 PR #50**（3 commit，一轮评审 APPROVE）：非锚类窗口通用化——最后一个**结构性**缺口关闭。新 `class_bounded_spec`：`BASE{n}/{n,}/{n,m}` 通用数值解析（基经 `bare_class_kind`、窗口经 `parse_capped_digits`、cap 100000、逆序交换、`{n,0}` 拒绝——与字面族规则一致）路由到共享 block 引擎，**涵盖硬编码 {1,2}/{1,3}/{1,4} 拼写表的全部纯窗形**（评审证明 kinds 与 ascii override 交互一致、block ≡ 四个 run 函数）。四点接线（replace_family_spans/replace 门/Split 门+matcher）。HF 实证：`\w{5}` 于 'zz abcdefg 9912345 zz'→'zz #fg #45 zz'；Split 分隔符也走块语义（189 Split cell 全对）。评审 650+ cell 零回归（≤4 子集、锚定/零下限/惰性 dispatch 全部 byte-identical to main）。502/502（native/js）、双扫描全绿。遗留（评审记录，均 pre-existing）：`{n,0}` 可路由到零下限引擎（候选后续）、`\b\w{5}` 边界前缀窗、单锚窗口 `^\w{1,2}`、`\w{5x}` 字面回退。

- **2026-09-22 发版 0.9.6（已发布，干净验证 4/4×三后端）**：0.9.5 后 PR #49 单批。直接推 main：bump + `moon publish` 成功 + /tmp/verify096 干净验证（`^a{5}$` 窗、`a{5}` 块、`a{6,4}` 交换、裸 `\s` Split 回归）。

- **2026-09-22 PR #49**（4 commit，两轮评审）：字面量词窗口上限 1..4 → **onig 100000**。char_bounded_spec（非锚 replace/decoder）与 double_anchored_brace（锚定整行）cap 放开（`a{5}`/`^a{5}$`/`^a{4,6}$`/前导零/逗号开/零下限全算，块语义不变）；**非锚逆序 `{n,m}` n>m 现交换**（`a{6,4}` ≡ `{4,6}` 块，探针 run 0-8 + 双块 case）；cap 边界 `{100001}` 双侧加载报错（中环 cap 防 Int 回绕——**顺带修复 main 既有溢出**：`a{4294967300}` 回绕成 4 静默错算）。评审一项 blocking：`{n,0}` 交换缺零守卫（空匹配插入语义，`a{2,0}` 静默错）→ 与锚定族同规则拒绝。评审 ~335 cell（119 自动匹配 + 边界/逆序/守卫交互）；500/500（native/js）、双扫描全绿。遗留（记录）：非锚**类**窗口 >4（`\w{5}`——走硬编码拼写表）、`a{100001x}` 字面回退分歧（pre-existing）。

- **2026-09-22 发版 0.9.5（已发布，干净验证 4/4×三后端）**：0.9.4 后 PR #48 单批。直接推 main：bump + `moon publish` 成功 + /tmp/verify095 干净验证（裸 `\s` Split 逐字符、`[\s]+` 整段、`[\r\n]` 回归、经典 `\s+`）。

- **2026-09-22 PR #48**（2 commit，评审 agent 超时 → 按自验 + CI 8/8 合入）：issue #47——裸单字符类 + `[\s]+` 门表扩展。Split 门 OR `bare_class_kind`（裸拼写 `\s`/`[\s]`/`\d`/`\w`/`[0-9]`/`[\p{L}]`… 路由到 PR #46 的 `exact_one_matches` 逐字符）；`[\s]+` 进 Split 空白 run 行 + Replace 门（replace 侧裸类本来就经 `bare_class_kind` exact-1 正确——缺口只在 Split 加载拒绝与 `[\s]+`）。自验对拍 HF：量化拼写未被误抢（`\s{2}` 仍走量化表）、`[\s]+` 全 behavior×invert 于 CRLF 混合输入、近族回归（`[\r\n]` 逐字符/`\w+` 整段）；498/498（native/js）、双扫描全绿。

- **2026-09-22 发版 0.9.4（已发布，干净验证 4/4×三后端）**：0.9.3 后 PR #46 单批（`[\r\n]` 逐字符）。直接推 main：bump + `moon publish` 成功 + /tmp/verify094 干净验证（逐字符/整段回归/窗口/经典）。

- **2026-09-22 PR #46**（3 commit，一轮评审 APPROVE）：issue #45——`[\r\n]` 无 `+` 拼写误入 run_matches 整段分支。改为新 `exact_one_matches` 逐字符（HF 'a\n\nb' Isolated → a, \n(1,2), \n(2,3), b；5 behavior × 2 invert 全对拍，21 分歧 cell 清零）；`+` 拼写保持整段。**顺带修复** replace 侧字面 CR/LF 拼写（原先也走整段分支，评审发现后补锁定）。评审 868 cell 零分歧（含相邻拼写 450 cell 回归）；494/494（native/js）、双扫描全绿。遗留：issue #47（裸单字符类 `\s`/`[\s]`/`\d`/`\w`/`[0-9]`/`[\p{L}]` 与 `[\s]+` 加载拒绝——与 #45 同型的门表缺口）。

- **2026-09-22 发版 0.9.3（已发布，干净验证 4/4×三后端）**：0.9.2 后 PR #44 单批。直接推 main：bump + `moon publish` 成功 + /tmp/verify093 干净验证（窗口 Split Isolated、`\b$` contiguous+invert、逐分支锚 mwp、经典 `\s+` 回归——按偏移对拍）。

- **2026-09-22 PR #44**（4 commit，三轮评审）：Split pre-tokenizer 路径的断言/窗口 pattern + **apply_split_matches 按 HF 源码模型重写**。①裸断言序列（`\b$`/`^`/`^$`）、双锚整行窗（`^.{0,2}$`）、逐分支锚 alternation 进 Split 门与 matcher（原先加载成功但整串透传）；②评审 B1：合并语义改为**词锚定**——behavior 统一作用于匹配段、mwp 的匹配段只并入紧邻前词（空词仍作锚）、mwn 连续匹配各自独立；③评审 B2（评审者拉取 HF v0.22.2 Rust 源码定模）：**invert = 交错 gap/match 条目表（零宽匹配保留为条目）的逐条 flag 取反 + 折叠**（非补集区域）——Contiguous 合并同 flag 连续段（零宽翻转词截断分隔符链）。三轮累计 ~5,700 对拍：11 pattern × 5 behavior × 2 invert × 10 输入 550/550（首版 519/550）+ 经典 pattern 200/200；63 个分歧 cell（31 B1 + 32 B2）全部修复并按偏移锁定。492/492（native/js）、双扫描全绿。遗留：issue #45（`[\r\n]` 无 + 应逐字符）、GPT2 扫描器忽略非 Isolated 行为（设计决策）。

- **2026-09-22 发版 0.9.2（已发布，干净验证 5/5×三后端）**：0.9.1 后 PR #43 单批。直接推 main：bump + `moon publish` 成功 + /tmp/verify092 干净验证（`\b$` 序列、`^` 串尾规则、零下限空行窗、逗号开、逐分支锚回归）。

- **2026-09-22 PR #43**（6 commit，一轮评审 + 自验）：裸断言序列 + 双锚零下限窗。①纯零宽断言 pattern（`\b$`/`^\b`/`\b\b`/`$\b`/`^\b$`/`^$`/`^`）= 全 AND 断言位置的空匹配游走（HF `\b$` 于 'ab\ncd'→'ab#\ncd#'）；**统一规则：multiline `^` 永不匹配串尾位置**（`^$` 于 '\n\n'→'#\n#\n' 两次非三次；应用于空分支 matcher）；②双锚零下限窗（`^.{0,2}$`/`^a{0}$`/`^.{0,}$`/逗号开 `^{,m}$`）空行匹配（串尾空行被 `^` 规则排除）、逗号开经正常基解析（`double_anchored_base` 提取）。评审三项 blocking：接线漏提交（死代码+decoder abort——commit 分组失误）、**nl-pred brace 窗整体显式拒绝**（连续换行下任何模型都与 HF 分歧：`^\s{1,2}$` 于 'a\n\nb' HF 零匹配；连 PR #34 已验证形状都特异，探针 30+ 无法归纳稳定规则；`+`/量化-less 形保持 PR#34/#36 已验行为）。复评 agent 超时，按 round-1 评审已验证的 34/34 锁定值 + CI 8/8 + 自验探针全绿合入。489/489（native/js）、双扫描全绿。遗留（评审记录）：`^.{0,100000}$` cap 窗口、`^{,}$` 字面分歧、reversed `{0,n}` 注释 stale、Split 路径的断言/窗口 pattern。

- **2026-09-21 发版 0.9.1（已发布，干净验证 4/4×三后端）**：PR #42 单批（空分支零下限语义 + matcher 单遍重写）。直接推 main：bump + `moon publish` 成功 + /tmp/verify091 干净验证（空分支游走、位置放弃、逐分支锚/逐行字面回归）。

- **2026-09-21 PR #42**（2 commit，一轮评审 APPROVE）：空分支空匹配插入语义。空分支 = 零宽断言组合替代（`^`/`$`/`\b`/裸），走零下限 prev_end 规则：声明序逐位置尝试；**邻接空匹配放弃整个位置**（onig 不回试同位置后续分支——`a||b` 于 'ab'→'#b#'，b 分支永不触发）；串尾空仅非邻接插入；空输入不匹配。架构：branch matcher 从 collect-and-merge **重写为单遍扫描**（merge 无法表达位置放弃），非空分支的逐分支锚/边界匹配统一进同一扫描。评审确认非空-only 分支集下单遍与 merge 行为等价（解析证明 + 全回归电池 + 485 全套件）；意外收获：全空 pattern（`|`、`||`）HF 也计算且我们正确复现（`"ab"`→'#a#b#'）。验证：~212 cell 全一致（含 Split 5 模式含 offsets、decoder、declaration-order 攻击）；485/485、双扫描全绿。遗留（评审记录）：裸 `\b$`（无 pipe）单 pattern 路径、`(?:)|a` 组包裹空分支——pre-existing 后续面。

- **2026-09-21 发版 0.9.0（已发布，干净验证 4/4×三后端）**：0.8.1 后累计 PR #40（dot 基 kind 30 整行族 + 顶层 `|` 逐分支 `^`/`$` 锚定——修复一处 pre-existing 静默分歧）、#41（`\b` 逐分支绑定 + 评审 b_start 循环修复）。直接推 main 流程：bump + `moon publish` 成功 + /tmp/verify09 干净安装验证（`\b` 逐分支、逐分支锚、dot 窗口、`^ab$` 逐行回归，native/js/wasm-gc 全过）。

- **2026-09-21 PR #41**（3 commit，两轮评审）：`` 逐分支绑定。`foo|bar` == `(\bfoo)|(bar\b)`（HF 于 'foobar'→'##'——原全局绑定静默 no-op，同 PR #40 修复的 `^`/`$` 逐分支同类）。branch spec 剥每分支前导 `\bFOO`/尾随 `FOO\b`（5 元组），matcher 逐分支应用；整组形式 `\b(?:foo|bar)\b` 语义不变。评审一项 blocking：`b_start` 循环漏迁移（`^foo\b|bar` 于 'foobar' 应 'foo#' 而非 '##'——main 上该 pattern 显式拒绝，故非回归但属新面静默错）修复 + 死参数移除。验证：140 cell（137 一致 + 3 pre-existing fail-explicit：`\\\b` 后边界、空分支）；483/483、双扫描全绿。空分支（`^|a` HF '#b#'）评估为零下限空匹配语义——复杂度高、真实配置不出现，维持显式拒绝记录在案。

- **2026-09-21 PR #40**（4 commit，两轮评审）：dot 基整行族 + 逐分支锚 alternation。①`.` 基（kind 30）入双锚族：`^.$`/`^..$`（点序列=定长窗口）/`^.{1,3}$`/`^.{2,}$`/逆序 swap——`.` **不匹配 `\n`**（onig 默认，`^.{3,2}$` 于 'a\nb' 不变定位此语义）；量化多 dot（`^..+$` 量词绑最后一个点）显式拒绝；②**顶层 `|`（深度 0、转义感知）触发逐分支锚解读**：`^foo|bar$` == `(^foo)|(bar$)`（HF 于 'foo\nfoobar'→'#\n##'——旧行为误读为整组锚 `#\nfoobar`，**修复一处 pre-existing 静默分歧**）；分支可 `(?:...)` 包裹；候选按 (start, 声明序) 合并、贪心非重叠（`^ab|a`→'#' vs `a|^ab`→'#b' 探针锁定）；整组锚 `^(?:foo|bar)$` 语义不变。评审两项 blocking 修复：plain 分支收集**每个**出现（重叠抑制归 merge——`ax|xxx` 于 'axxxx'→'##'，本地跳过会丢被遮蔽的同分支出现）；量化多 dot 拒绝。验证：行为 486 cell（436 一致 + 47 fail-explicit + 3 pre-existing \b 逐分支）+ 代码审计全量 parser/engine 攻击；481/481（native/js）、双扫描全绿。遗留（评审记录）：`\b` 逐分支绑定（pre-existing，与本次 `^`/`$` 同类）、空分支/裸组分支的空匹配语义、`^.{0,2}$` 零下限点窗。

- **2026-09-21 发版 0.8.1（已发布，干净验证 2/2×三后端）**：PR #39 单批修复（锚定字面逐行）。按新工作流偏好（发版类 commit 直接推 main，不走 PR）执行：bump + `moon publish` 成功 + /tmp/verify081 干净安装验证（`^ab$` 逐行、`^a$` 多行，native/js/wasm-gc 全过）。

- **2026-09-21 PR #39**（4 commit，两轮评审）：多字符字面双锚逐行锚定——**最后一个已知静默分歧关闭**（PR #36 三轮评审均点名）。`literal_alternation_matches_anchored` 原为整串锚（`^ab$` 加载成功但多行输入静默 no-op），重写为 multiline 逐行：`^lit` 每行行首、`lit$` 每行行尾、`^lit$` 行首到**任意**行尾整串等值。评审两轮 blocking 修复：①含 `\n` 字面跨行匹配（`a\nb$` 于 'xa\nb'→'x#'、`\n\n$` 塌缩尾空行、`^a\nb$` 跨行），`^lit` 匹配遮蔽覆盖的行首（非重叠 find_iter 语义）；②`lit$` alternation 的 **onig tie-break = 最左 start + 声明序**（非长度——双声明序探针确证 `(?:\n\n|\n)$`→'a#' 而反序→'a##'），改 start 升序扫描。单一实现经 simple_split 服务 Split/normalizer/decoder/aligned 四路。验证：两轮 ~1,000 对拍，除 fail-explicitly 面（`^.$`/`^ab?c$`/`^foo|bar$` 等）外零分歧；477/477（native/js）、454/454（wasm）、双扫描全绿。遗留（评审记录）：`^foo|bar$` 混合锚按 onig 应逐分支绑定锚（pre-existing）、`^.$` 单字符通配整行族可作 double_anchored 后续扩展。

- **2026-09-21 发版 0.8.0（已发布，干净安装验证 6/6×三后端）**：0.7.0 后累计 PR #34（双锚整行族 + 逆序惰性交换）、#36（无量词多行/双锚逆序/转义基/decoder 路径）。PR #37 CI 8/8 后合并；`moon publish` 成功；干净项目安装 0.8.0（/tmp/verify08，native/js/wasm-gc 各 6/6）——`^a$` 多行整行、\b Unicode 边界加载、混类双锚逐行、`^5{3,2}$` 交换、惰性 `a{2,3}?`、\p{N} 全 N 全部与 HF 一致（验证脚本坑：JSON 转义需含反斜杠，`\b` 不转义会被 JSON 解析成退格）。

- **2026-09-21 PR #36**（5 commit，三轮评审）：双锚族剩余拼写。①无量词 `^BASE$` ≡ `^BASE{1}$` 多行整行（原被非多行 literal wrapper 吞掉而 gate 声称支持——**静默分歧**修复；单字符窗口天然不跨行）；②双锚逆序 `^a{3,2}$` 交换为原子 `{2,3}` 窗口——**仅限谓词不含 `\n` 的类**（`bounded_regex_kind_pred(kind,'\n')` 语义守卫：原子 vs 回溯在 \n 跨行 run 上分歧，HF 实测 `^\s{4,2}$` 于 '   \nx' 不变）；③`$` 前惰性 `?` 显式拒绝（HF 的 `(?:X{n,m})?` 整行形有 ^∩$ 空匹配 + 最短行尾语义——另一引擎能力），转义感知（`^\?$` 字面问号基保留多行语义，反斜杠奇偶）；④转义操作符基全集；⑤decoder 路径修复——`decode_replace_direct` 最前抢占双锚拼写（原非多行 wrapper 抢先，`^a$` decode 不变 vs HF `#\n#`）。评审三轮七项 blocking 全修（含我的 swap 枚举守卫被证伪改语义守卫、`^\?$` 转义回归）。验证：三轮 ~7,000 对拍，除记录在案的 fail-explicitly 形状外零分歧；473/473（native/js）、450/450（wasm）、双扫描全绿。遗留（评审记录）：多字符字面 `^ab$`/`^!!$`/`^\{2}$` 的 literal wrapper 整串锚（非逐行）仍静默分歧——后续批次；`^a{5}$` 窗口外、`^.{1}$` 等继续 fail-explicitly。

- **2026-09-21 PR #34**（5 commit，两轮评审）：双锚 `^BASE QUANT $` 整行族 + 逆序惰性区间交换。①双锚语义 HF 实证：multiline 下**逐行整行匹配**（`'!!'`→`'#'`、`'!!x!!'` 不变、`'a\n!!\nb'`→`'a\n#\nb'`），且类含 `\n` 时贪婪 run **可跨行**（`^\s+$` 于 `" \n "` 整串一个匹配）、`\r` 属于行内容（`'!!\r\n!!'` 仅第二行匹配）——引擎 = 行首起贪婪（hi 封顶）+ 最长行尾边界（长 ≥ lo）；QUANT ∈ +/{n}/{n,}/{n,m}（窗口 1-4），基 = 单类/12 混类排列/字面/\n\t\r 转义；②逆序 `{n,m}?`（n>m）onig 交换为 `(?:X{m,n})?` = 贪婪 ranged 块 + 空匹配游走（`a{3,2}?` 于 'zaaaaz'→'#z#a#z#'：块3+余1走空），lazy_exact 引擎泛化为 (lo,hi)。评审一项 blocking：`p = g` 尾部跳转丢弃 sub-lo 余量内部空匹配（回归 `{n}?` n≥3）→ `p = b` 贯穿修复 + 7 cell 尾部锁定（含评审自身期望值错误一例——HF 新鲜 oracle 纠正）。两轮评审 ~1,000 对拍（双锚 18×27 矩阵 + 逆序 198 项 run 长度扫描）零分歧；470/470（native/js）、447/447（wasm）、双扫描全绿。遗留（评审记录）：双锚逆序 `^a{3,2}$`、无量词 `^a$` 多行、窗口外 `{5}`、`.{n}` 基等仍 fail-explicitly。

- **2026-09-21 发版 0.7.0（已发布，干净安装验证 7/7×三后端）**：0.6.0 后累计 PR #24（\p{N} 全 N kind 28/29 拆分 + \d 经验 Nd 表 + GPT2/Qwen/o200k patstr 全 N）、#26（\b Unicode 词边界）、#28（{,n}/前导零/转义基/混类 12 排列）、#30（惰性 ? 三族）。新增公开 API：is_unicode_number、lazy_normalize、lazy_exact_spec、replace_lazy_exact_runs、replace_ascii_word_boundary_runs、zero_min_match_spans/replace_family_spans/char_bounded_spec 族。PR #32 CI 8/8 后合并；`moon publish` 成功；干净项目安装 0.7.0（/tmp/verify07，native/js/wasm-gc 各 7/7）——\p{Number}+ 于 a²b→aQb（content Q）、\b 包裹 ASCII 类于 x_1y→Q、惰性 a{2,3}?/a{2}?、{,2}、\d 保持 Nd、\n{2} 转义基，全部与 HF 0.22.2 一致。

- **2026-09-21 PR #30**（8 commit，三轮评审）：惰性 `?` 后缀量词族。HF 探针实证三族归约：①零下限 lazy（`{0}?`/`{,n}?`/`{0,n}?`/`{0,}?`/`{00}?`）≡ `{0}`；②`{n,m}?`/`{n,}?`（n≥1）≡ 贪婪 exact `{n}`（块 n、余量保留、无空匹配）；③**exact `{n}?` 是独立族**（run 达 n 时 exact-n 块、否则零下限空匹配游走——`'zaaz'`→`'#z#z#'` 而 `'za'`→`'#z#a#'`，既非 `{0,n}` 也非 `{n}`，评审确证 onig 解析为 `(?:X{n})?` 叠加可选）——需专设 `lazy_exact_match_spans` 引擎。`lazy_normalize` 在 normalizer/decoder 双 replace 链、`replace_family_spans`（aligned）、加载门四点前置归一化。评审三轮修复五项：前导零按**解析值**路由（`a{02}?` 是 exact-2 lazy 非 `{0}`）、非法尾（`a{0,2x}?`）归字面量、`{0,N}?` 补 100000 cap、转义大括号基奇偶判定（奇=字面量拒/偶=转义反斜杠基照算，`\\{2,3}?` 全族 HF 一致）、逆序 `{3,2}?` 显式拒绝（HF 交换语义记录为后续面）。验证：三轮评审累计 ~9,900 对拍（84 拼写 × 47 输入矩阵 + 转义基专项 18 cell），除 17 个记录在案的 fail-explicitly 形状外零分歧；467/467（native/js）、444/444（wasm）、双扫描 1134+100、CI 全绿（pull_request 事件丢失一次，workflow_dispatch 手动补跑）。

- **2026-09-21 PR #28**（9 commit，两轮评审）：fail-explicitly 清单廉价扩展四项（全部先 HF 探针定真值）。①`{,m}` 逗号开界 = 量词 `{0,m}`（`a{,2}` 于 'zaaz'→'#z#z#'；空 `{,}` **不是**量词——字面量，'xa{,}x'→'x#x'）；②前导零等价（`a{00}`≡`a{0}`、`a{01}`≡`a{1}`、`a{0,02}`≡`a{0,2}`）；③转义字面量基 `
	
\.` 携带量词（`
{2}` 于 "z

z"→'z#z'；转义基跳过元字符排除——`.`{2}` 是 any-char 拒绝、`\.{2}` 是字面点计算）；④混类补集排列补全至 12（短名 6+长名 6）× 门控/扫描器/bounded/ranged/exact/min/anchored 全位点。评审三项修复：F1 gate 孪生 `char_bounded_quantifier_shape` 未扩展转义基（compute 层 HF-exact 但 from_json 拒绝、decoder SIGABRT）——两个调用点改用 `char_bounded_spec` 直接判定并删除孪生（单一真相源）；F2 `at_quantifier_brace` 要求逗号后 ≥1 数字使 `{,}` 归字面量（HF 可加载）；F3 anchored/exact/min 位点排列补齐。验证：两轮评审 ~5,500 对拍 0 输出分歧（含 12 排列 ×10 输入全量、decoder 无 abort、边界 cap 100000 双向一致）；463/463（native/js）、440/440（wasm）、双扫描 1134+100、CI 8/8。遗留（评审记录）：双锚 `^[...]+$`、惰性后缀 `?`、多转义基 `\{0,2}` 仍 fail-explicitly（HF 可算，后续批次）。

- **2026-09-21 PR #26**（4 commit，一轮评审）：issue #21 —— `\b` 词边界改用 Unicode 词定义。`\b[A-Za-z0-9_]+\b` 原与裸 `[A-Za-z0-9_]+` 共分支（ASCII run 全替换）；现拆到 `ascii_word_boundary_run_matches`（span helper + `replace_ascii_word_boundary_runs`）：匹配 = ASCII 词 run 且 prev/next 均非 Unicode 词（**裸 \w 表含 onig 怪癖**——HF 实测 `²ab`/`ab²`/`¼ab½` 均无匹配，怪癖在 \b 处算词）。回溯不可救子 run（任何更短子 run 仍邻词字符）→ run 级过滤即精确。scanner/normalizer/decoder 三处拆分（等价扫描与 aligned 路径经 simple_split 自动获得）。评审：行为 841 cell（可达 568 全一致，边界模型证明 + 对抗输入实证）、代码审计 dispatch 完备性确认（无遮蔽、门不拒、`\b\w+\b` 与字面量族 `regex_word_boundary_at` 约定不变）；一项 blocking = 漏提交 .mbti（已补）。验证：459/459（native/js）、436/436（wasm）、双扫描 1134+100、CI 8/8。评审另证 HF 可算的 `\b[ˆ\W]+\b`/`\b\w+`/`\w+\b` 拼写本库显式拒绝（加载期/解码期 fail-loud，策略合规）——留作后续可选扩展。

- **2026-09-21 PR #24**（9 commit，两轮评审）：issue #20 —— `\p{N}`/`\p{Number}` 全 N（Nd+Nl+No）与 `\d`（Nd）kind 拆分。①`scripts/gen_unicode_number.py` 全量 content-swap 双探针生成两张经验表：`number_ranges`（\p{N}，1911 码点/144 区间，130 个 drift 于 host unicodedata——onig 更新，如 U+10D40 Garay）与 `decimal_ranges`（\d，760/71；旧硬编码 Nd 区间漏 Unicode-14+ 新增，实测 U+1FBF0 数学数字 HF \d 匹配而我们漏）；②kind 28/29 拆分（bare/bounded/ranged/exact/min/anchored/quantified-base 表 + pred 行），`\d`/`[0-9]` 保持 11/22，kind-21 混合类数字部分换全 N（HF `[ˆ\s\p{L}\p{N}]` 于 a²b 零匹配）；③scanner/normalizer/decoder 全部混合 hardcode 组拆分。评审四项 blocking 全修：F1 bounded 负拼写 `\P{N}{1,n}` 漏拆（`aⅠb`→`#Ⅰ#` 非 `##`）、F2 decoder `\P{N}{3,}` 被 `\D{3,}` 行抢跑（新 `decode_replace_min_runs_direct` 谓词参数化）、F3 GPT2/Qwen/o200k patstr `is_number` Nd-only（`x ¼3y`→['x',' ¼3','y']，最高流量 \p{N} 消费者）、F4 split `{2,}` 死行谓词。行为评审的 decoder "字面量" must-fix 经直接探针**证伪**（Python `decoders.Replace(pattern=str)` 是字面量重载，本库消费 JSON `{"Regex":...}` 是 onig 路径——`decoder.decode(["a²¼…"])→'a#'`），评审二轮撤回并改用 JSON Regex oracle。两轮累计 ~2,700 行为 cell + 两次全码点表 sweep 零未解释分歧。验证：457/457（native/js）、434/434（wasm/wasm-gc）、双扫描 1134+100 全绿、CI 8/8。

- **2026-09-21 发版 0.6.0（已发布）**：0.5.0 后累计 PR #16–#19（fail-explicitly 批次、`\w` Unicode 经验表 797 区间、kind 26/27 括号分裂、零下限量词 + aligned 路径统一）。含行为变化：括号 `\w` 类上下文语义、字面量有界量词、多行锚定 Split/decoder、零下限空匹配插入、encode 路径全部量词族从静默跳过改为生效、`a{0,100001}` 加载期拒绝。semver minor（新增公开 API：`zero_min_quantifier_spec`、`zero_min_match_spans`、`replace_family_spans`、`char_bounded_spec`、kind 26/27 谓词）。PR #22 CI 8/8 后合并；`moon publish` 成功；干净项目安装 0.6.0（/tmp/verify06，native/js/wasm-gc 三后端各 8/8）——零下限 encode 全链 tokens/ids/offsets 与 HF 逐位一致（含空匹配零宽 (0,0) 偏移在真实 encode 中可观测）、有界族 encode 生效、100001 拒绝、基础 encode/offsets 回归。

- **2026-09-21 PR #19**（8 commit，两轮评审）：`{0}`/`{0,m}`/`{0,}` 零下限量词 replace 语义 + 评审抓出的 **encode 路径 aligned 静默 no-op 结构性修复**。①零下限族走 onig 全局替换空匹配规则（prev_end 邻接跳过 / 空匹配插入并复制一字符 / 串尾仅非邻接插入 / 空输入无匹配），字面量与类基两种 base，normalizer/decoder 接入；②评审 blocking：`replace_aligned` 原先只查 simple_split 扫描器——**全部量词族（`a{2}`、`\s{1,2}`、多行锚定、零下限）在 encode 路径静默跳过**（tokenizer.json 加载成功但 encode 不替换，正是 no-silent-mismatch 红线；`a{2}` 族为 main 既有洞）。修复：text/aligned 双路径共用 `@common.replace_family_spans` 匹配 span 分发器（`zero_min_match_spans` 含空 span、`block_match_spans` 统一 bounded/exact/min/ranged 块语义、多行 leading/trailing span 镜像、`char_bounded_spec` 提取），`replace_zero_min_runs`/`replace_char_bounded_runs` 重构为同源 span 步进——两路径结构性不可分歧，未匹配模式双侧同走 literal 回退；③偏移规则 HF 实测锁定：非空匹配 content 锚定**最后匹配字符** span、空匹配于 p 锚 `(p-1,p)`、串首钳 `(0,0)`（`a{0,2}`/"zaaz" → `(0,0)(0,1)(2,3)(3,4)(3,4)` 逐位一致）；④评审 F2：max 上限 100000（onig 实测 `a{0,100000}` 加载 / `a{0,100001}` 报错，同时消除 Int 回绕→无界隐患）；⑤71 拼写 ×20 输入 text≡aligned 等价扫描进库常驻 + decoder 逐 token 零下限锁定。两轮评审 APPROVE：行为评审 2,111 项 MoonBit-vs-HF 对拍 0 项归因本 PR；代码评审 16,039 项 text-vs-aligned 0 分歧。评审另发现两处 main 既有分歧 → issue #20（`\p{N}` 仅映射 Nd）与 #21（`\b` ASCII 词边界）。验证：452/452（native/js）、429/429（wasm/wasm-gc）、双扫描 1134+100 全绿、CI 8/8。

- **2026-09-21 PR #18**（8 commit，评审修正后）：kind 26/27 括号拼写表分裂（PR #17 评审 F3 设计落地）。`[\w]`/`[^\W]`→26（word-class，怪癖排除）、`[\W]`/`[^\w]`→27，接入 bounded/ranged/quantified(min+exact)/anchored 表 + bare_class_kind + scanner/normalizer/decoder 三链——恢复 PR #16 被回退的括号拼写支持且语义正确（HF 实测怪癖字符类上下文不匹配、run 在怪癖处断开、`\w` 裸拼写包含怪癖）。评审 18,060 项交叉对拍确认核心设计正确后抓 3 项：F1 bounded 表 kind-13 行遮蔽新 27 行（行序修正）、F2 ranged {3,4} 漏反集拼写（`[^\W]{3,4}` 加载后 decoder SIGABRT / `[^\w]{3,4}` 静默 kind-13）、F3 Split 门未加括号 +拼写（scanner 行不可达）；另确认 F4 副作用修复（single_word 边界怪癖字符不再阻断提取，`²TAG` 现可提取 TAG）并补锁定测试。验证：445/445 四后端、双扫描 1134+100 全绿、17+7 项 HF 探针逐例一致。

- **2026-09-21 PR #17**（7 commit，评审修正后）：`\w` 谓词 Unicode 覆盖（PR #16 评审 F7，1851 项对拍中 72 项分歧主因）。初版类别推导（L*/M*/Nd/Nl/Pc + 6 个 onig 怪癖）**被评审证伪**——本地 unicodedata 13.0 而 onig 追踪新 Unicode（U+2C2F/U+9FFD 等 14+ 新增遗漏，498 边界分歧）；改为**全量经验生成**（content-swap 双探针对 0..0x110000 每码点探测）。评审三项发现全部修正：F1 表为 fn 返回字面量致每次调用分配 794 元组（**~190x 热路径回归**，评审实测 685ns vs 3.6ns）→ hoist 为模块级 let + 二分；F2 只扫平面 0-2 漏 9,371 码点（CJK Ext G/H、变体选择符补充）→ 全量重生 797 区间/144,671 码点，边界 ±1 验证 0 分歧；F3 onig 六怪癖字符（²³¹¼½¾）**裸 `\w` 匹配但类上下文（`[\w]`/`[^\w]`）与 single_word 边界不匹配**——统一谓词无法两全，PR #16 的括号拼写规范化被**回退**（按 no-silent-mismatch 原则显式拒绝优于错语义），single_word 边界改用新 `is_word_char_class`（无怪癖表），拼写感知表分裂（kind 26/27 显式括号行）记录为后续设计。评审另实证推断了 §5.7 旧记录中 ˆ/全角数字两条 stale 结论（评审探针自身的 '#' content 碰撞）。验证：442/442 四后端、双扫描 1134+100 全绿、141k 边界探针 0 分歧。

- **2026-09-21 PR #16**（9 commit，评审修正后）：fail-explicitly 清单收敛。①`[\w]`/`[\W]` 括号拼写经 `canonicalize_word_class` 在六个 kind 入口统一规范化到 `\w`/`\W` 快捷形式（HF 实测括号 `\w` 保持 Unicode-wide，与 ASCII `[A-Za-z0-9_]` 拼写不同；评审 1851 项交叉对拍 normalizer 路径零分歧）；②锚定 `[\r\n]+`/`[\r\n]+$` 入表；③单字符字面量有界量词 `a{2}`/`a{2,}`/`a{2,3}`（`replace_char_bounded_runs` 贪婪有界 run，normalizer/decoder 三路径接入，decoder 逐 token 与 HF 一致）。评审四项发现全部修复：F1 元字符基（`.{2}` HF 为 any-char、`?{2}` 等为构造错误）加入拒绝集；F2/F3 Split 与 decoder 锚定 span 改为**多行**语义（评审实测 HF `^[\r\n]+` Split 于 "A\n\nB" 产 `['A\n','B']`、decoder 于 `["x\n\n","y"]` 产 `x\n#y`——修复后逐例一致；13 处 split 锚定行全部改走 `*_multiline` helper，旧单锚 helper 删除）；F4 `a{n,}` 去 64 cap（整 run 消费，HF 70 个 a 对拍一致）；F6 canonicalize 文档注释反转修正。评审另报 F7（`\w` 谓词缺全角拉丁/半角片假名等区间，1851 项对拍中 72 项分歧的主因）→ §5.7 记录为后续批次。验证：440/440 四后端、双扫描 1134+100 全绿。

- **2026-09-21 发版 0.5.0（已发布）**：0.4.0 后累计 PR #6–#14（行为对比扫描五批 + 工具链漂移 7/8 层 + lazy align/正则分歧批）。含行为变化：decode join、charsmap 字素簇、decoder 边缘语义、offsets 原文参照、added-token id 分配、Replace 显式门、ASCII class/多行锚定/裸类。semver minor（新增公开 API：normalize_aligned 族、is_supported_replace_regex、unicode_punct_ranges、is_hf_punctuation、kind extends）。PR #15 CI 8/8 后合并；`moon publish` 成功；干净项目安装 0.5.0 验证四项全中——naïve offsets (0,2)(2,5)(5,8) 与 HF 逐位一致、decode roundtrip、BatchLongest 单条 encode 按 multiple=2 取整（odd→4/even→4，HF 同）、`Hello world` parity [15496, 995]。

- **2026-09-21 PR #14**（8 commit，两轮评审）：队列 P2 + §5.7 四类对抗分歧修复。①**lazy identity 对齐列**：`Align::Identity(len)` 零分配替代逐字符 tuple（钳制算术逐位等价，评审穷举+随机化证明；独立实测 no-normalizer encode ~1.7x 提速）；②**字面量大括号**：非量词 `{`/`}` 字面字符（onig），`{,n}` 视为量词→显式拒绝（评审抓到首版顺序 bug：`{,n}` 检查排在 digits==0 早退后被跳过）；③**ASCII class 拼写**：新增 kind 22–25，五个 kind 入口后置覆盖——评审抓到 plain-`+` 拼写绕过全部入口（共享 scanner/normalizer/decoder 双路径硬编码 Unicode 分支），已全部拆分；裸 `\p{L}` 误映射 kind 6 修正为 Unicode kind 7/17；④**多行锚定**按 onig 重写（行首贪婪跨换行、最长边界前缀匹配）；⑤**裸类** exact-1 逐字符替换双侧接入。评审另证伪我三处测试期望（`[^0-9]+` 于全角为单 run、`\P{L}` 保留字母、decoder Replace 逐 token）。流程教训：c8591d4 描述了多行锚定重写但漏提交 replace.mbt 本体（本地绿/CI 红暴露）——commit 前应 `git status` 核对文件清单。验证：438/438 四后端、双扫描 1134+100 全绿、27 项 HF 探针逐项对齐。

- **2026-09-20 PR #13**（10 commit）：队列 P1+P2+覆盖扩展。①扫描语料加 pair 电池（3 对 (a,b)/用例，ids/tokens/offsets/type_ids 四字段，+126 检查全过——pair 路径干净，留作回归）；②`@common.is_supported_replace_regex` 统一 replace-regex 族判定（PR #8 评审 nit 去重）；③normalizer Replace 不支持 regex 族加载期 `UnsupportedComponent`（39 fixture 审计仅用支持族，集成 28/28 实跑）；④decoder 门改用共享谓词（评审实测两表 0 判定差）。评审修正：门的锁定测试曾被 catch 吞掉失败（改 `assert_raise` 并以"禁用门→测试红"验证非空转）、谓词文档过度声明收窄 + 四类对抗性分歧入 §5 队列。**工具链漂移第 7/8 层**：`implicit_impl_as_method`（51 个 derive 类型补显式 `pub extend`、9 包补 debug 导入、.mbti 再生成）与 `test_unqualified_package`（黑盒测试同包名 `@pkg.` 限定，词法感知迁移 ~685 处）；纯机械，扫描仍 1134/1134 + 100/100。本地工具链已升 0.1.20260920 与 CI 对齐。


- **2026-09-20 PR #11**：PROGRESS.md 本轮结构化（见文首约定）。
- **2026-09-20 PR #10**：残余小类清零，双扫描 100%。内容：
  - charsmap 字素簇替换 span 按 HF `-N` 契约映射**首个**消费字符（t5 NFD 输入最后一例真实模型失败清零）；
  - BatchLongest 对**单条** encode 也 padding（longest=自身长度再按 `pad_to_multiple_of` 取整，实测 len5+multiple2→6）；
  - ByteLevel `trim_offsets` 精确复刻 HF `byte_level.rs process_offsets`（首/零锚 token 自加单前导空格保留、其余裁剪钳制、全空白 token 坍缩到末端；旧 `start>0` 近似被实测证伪，含一处旧测试期望修正 Roberta pair (0,2)→(1,2)）；
  - standalone StripAccents 只删已分解记号（`normalize("café")=="café"`），与 BertNormalizer 的 NFD-再-删分离为两个函数（含 aligned 变体）；
  - added-token id 分配 = HF `add_tokens`：内容可解析（模型词表或已添加）则复用该 id，否则**完全忽略声明 id**、按 `get_vocab_size()+计数` 顺序分配（重复声明不再静默遮蔽；两处旧测试按实测更新）。
  - 按用户 commit 纪律拆为 6 个单一关注点 commit + 2 个评审修正 commit。
- **2026-09-20 PR #9**：offsets 原文映射架构（详见 §7.8）。合成 857→987、真实 59→94。评审修 4 项阻塞：NFC 组合 span 保留**首**字符（非区间合并）、Replace 内容附着**命中末字符**、ReplaceString 恢复纯字面量路径（回归）、piece origin map 按**预分词器类型**选择（非长度巧合；混合 Sequence 显式不支持）。
- **2026-09-20 PR #8**：decoder 边缘语义：BPEDecoder 逐 token **子串级全量** suffix 替换（非末 token→空格、末 token 仅删）、Metaspace scheme 感知解码（always/first 丢首 token 全部 ▁ 含中部、never 全转空格）、CTC dedup→pad 子串任意位置删除→cleanup 逐 token（`cleanup=false` 分隔符保留字面量）、Replace decoder 不支持族显式 abort（评审补：门须覆盖 `decode_replace_direct` 快路径 + Sequence 快路径 regex 元字符回落）。`cleanup_text` 恢复上游 11 条有序规则（旧单趟近似多清 `;`/`:`、漏 `" ' "` 与 `" do not"→" don't"`）。探针表"Replace 跨 token 边界"一行被直接复测证伪，未采纳。
- **2026-09-19 PR #7**：precompiled charsmap 按字素簇（基础字符+组合记号，<6 UTF-8 字节）整簇查 trie，未命中回退逐字符；≥6 字节簇（谚文 jamo）不组合。t5 对 NFD 输入 ids 分歧清零（`e`+U+0301 → `é`）。
- **2026-09-19 PR #6**：decode 无 decoder 改 `tokens.join(" ")`（unknown id 先过滤、显式空格 token 原样参与、保留的 special 同样 join）；HF 标点分类器 `is_hf_punctuation` = `is_ascii_punctuation ∪ is_punctuation`，P\* 表由 `scripts/gen_unicode_punct.py` 对 0.22.2 BertPreTokenizer 分类器做 0–2 平面**全量经验扫描**生成（161 区间/717 码点；ASCII 符号刻意排除以保 `\p{P}` 语义）；BertPreTokenizer 不再逐字切 CJK（"你好，世界！ Hello"→你好|，|世界|！|Hello）；Punctuation MWP/MWN 改 run 首/末字符合并（"hi!!!there"→hi!|!|!|there / hi|!|!|!there）。评审修 2 阻塞：手写 P\* 表漏 391 个真 P\*（FE 竖排块、U+30FB 片假名中点、各文字系统、星面）且误删 38 个造成 `\p{P}` 回归→改为经验生成。
- **2026-09-08 PR #5 + publish 0.4.0**：版本 bump + 工具链漂移修复（unused `core/bench` 导入）。
- **2026-09-06 PR #1–#4**：truncation overflowing 修复（§7.6）、文档可运行化（§7.7 前置）、stride 配置期校验（双层：配置期用单序列预算 `stride > max - num_special_tokens_to_add` 即抛、消息逐字对齐上游；pair 编码期按每侧预算复检）。

## 3. 对齐基准与验证设施

### 行为对比扫描（核心验收设施）

- **语料**：`scripts/parity_cases.py` 生成 42 个合成 tokenizer 配置（富词表 BPE ~90 tokens 含多字符 merges/大小写/标点/重音/全角/CJK/数字 + WordPiece）× 20 条边界输入（全角 apostrophe、CJK 混排、NFD 组合、代码、连续空白、连标点等）+ 5 个真实模型（gpt2/bert/t5/qwen3/llama3_2）同输入矩阵；golden 由本机 Python `tokenizers` 0.22.2 产出，比较 ids/tokens/offsets 与 decode 往返。
- **驱动**：`/tmp/parity-driver`（moon.workspace 软链本仓库 `/tmp/tokenizer-moonbit`），`moon run cmd/sweep --target native`；`PARITY_MODE=real` 跑真实模型。**探针写 `cmd/drv`，勿覆盖 `cmd/sweep`**。
- **语料再生成**：`python3 scripts/parity_cases.py /tmp/parity-sweep`（真实模型目录 `PARITY_MODELS_DIR` 可覆盖）。
- **当前基线：合成 1134/1134、真实 100/100**。改行为前先跑，改后回归对比；新增修复应加锁定测试进仓库（期望值先在 Python 实测）。

### 39 模型 fixture 对拍

`src/integration/parity_test.mbt` 表驱动；`scripts/fetch_models.py` 下载 `tests/data/*.full.json`，`scripts/gen_parity.py` 生成期望（均 gitignore，缺失自跳过）。逐 token id 一致，覆盖：

- **经典**：gpt2（+内联 `<|endoftext|>`/decode 往返）、roberta-base、bert-base-uncased（+special/type_ids/mask/pair）、bert-base-cased、distilbert、t5-small（Unigram+Metaspace）、albert、xlm-roberta（NFKC）。
- **现代 LLM**：llama（byte_fallback+Metaspace，emoji 字节回退）、Llama-3.2、Qwen2.5、Qwen3、Qwen3-Coder、Qwen3-VL、DeepSeek-V2-Lite/V3.2/R1-Distill、Phi-3-mini（byte_fallback+Prepend）、Phi-4-mini（o200k）、Mistral、Falcon、StarCoder2、GPT-NeoX、GPT-OSS、GLM-4.5-Air、Granite-4、SmolLM2。
- **多模态/编码器**：CLIP ViT-B/32、ModernBERT、GTE-ModernBERT、tiny-random-DeBERTaV2（Precompiled whitespace）。
- **Embedding**：bge-m3、bge-large-en、multilingual-e5-large/small、MiniLM、jina-v3、nomic-embed-1.5、mxbai-embed-large。

### 性能对比

- 结论必须基于 `scripts/bench_compare.py` 同机 Moon/HF 比值（覆盖 encode/byte-offsets/decode/encode_batch/pair_batch/pretokenized/builder+add_tokens/to_json/post_process/decode_batch/decode_stream/from_str/from_pretrained/save_pretrained/regex fast paths），不用裸 `moon bench`。
- 阈值：`>1.10x` 进优化排期、`<0.90x` 才可宣称快；`--fail-above` 可作 CI 门、`--json-out` 出结构化报告；HF baseline 缺 NumPy 时记 skipped 不中断。
- 最近全量抽样（native）：主流 encode 0.25x–0.68x（gpt2 0.43x / llama 0.28x / Qwen2.5 0.58x / bert 0.53x / clip 0.48x / t5 0.39x），decode 同档或更快（bert cleanup 0.13x、llama sequence 融合 0.17x），from_str 大模型基本同档或更快（gpt2 0.45x / Qwen2.5 0.39x / llama 1.14x 待优化），`post_process` 0.09x、`decode_stream` 0.44–0.76x。下一优化重点：大词表 JSON 冷加载、nightly 趋势落盘。

### 测试与 CI 门禁

```bash
export PATH="$HOME/.moon/bin:$PATH"
moon fmt --check && moon check --deny-warn && moon info   # .mbti 无 diff
moon test --target native --deny-warn                      # 同样跑 js/wasm/wasm-gc
```

- CI 8 job：4 后端测试 / Python 脚本 / Release gates（fmt+check+info+metadata）/ 可选 parity smoke / HF benchmark smoke（~10min）。
- **工具链漂移警惕**：CI 用最新 moon；历史已现八层——`StringBuilder::new()` 弃用、`{}` 歧义、formatter 规范变化、`.mbti` 尾空行、`unused_package`（bench/core:int/core:bench 导入）、`implicit_impl_as_method`（43 个 pub derive 类型补 `pub extend X with Eq/Debug`，20260920 工具链）、`test_unqualified_package`（黑盒测试同包类型/函数需 `@pkg.` 全限定，~680 处迁移）。本地全绿 CI 红时先怀疑漂移，逐层修复后提交。

## 4. 能力矩阵

### Models

| 组件 | 状态 | 备注 |
|---|---|---|
| BPE / 字节级 BPE | ✅ | 优先队列(pairing heap)合并+惰性失效+word cache；decode 反查 dense id array 加载期填充；`unk_token=None` 时 unknown 跳过、配置 unk 但 vocab 缺失抛错；`dropout` 解析/序列化，`>0` 禁 word cache 按概率跳 merge；legacy merges code-unit 扫描解析 |
| byte_fallback / fuse_unk / ignore_merges | ✅ | |
| WordPiece | ✅ | 贪心最长前缀；`continuing_subword_prefix`/`end_of_word_suffix`；fallback `[UNK]` 缺失抛错 |
| Unigram | ✅ | Viterbi DP+word cache；`byte_fallback`/`fuse_unk`；`alpha>0` 前向-后向采样、`nbest_size>0` beam-search N-best 采样（确定性种子）；缺 `unk_id` 遇 unknown 抛错 |
| WordLevel | ✅ | fallback unk 缺失抛错 |

### Normalizers（全部带原文对齐列，规则见 §7.8）

| 组件 | 状态 | 备注 |
|---|---|---|
| Lowercase / Strip / Prepend / Sequence | ✅ | ASCII whitespace strip（HF 同） |
| Replace（String/Regex）/ ReplaceString | ✅ | 共享 Split 的 simple-regex span scanner（类族见 Pre-tokenizers Split 行）；**String 变体纯字面量**；不支持 regex 族文本级暂静默（待显式门，§5.1） |
| BertNormalizer | ✅ | clean_text/handle_chinese_chars/strip_accents(三态 `Bool?`，随 lowercase)/lowercase；strip_accents=NFD-再-删 |
| StripAccents | ✅ | **仅删已分解组合记号**（预组合 é 原样），与 Bert 变体不同 |
| NFC/NFD/NFKC/NFKD | ✅ | 生成表 + UAX#15 分解/规范排序/组合 |
| Precompiled（charsmap） | ✅ | base64→SentencePiece double-array trie；**字素簇（<6 字节）整簇查询**，≥6 字节（jamo）不组合；空/缺 map 走 NFKC+空白折叠并带 ASCII fast path |
| Nmt | ✅ | 控制/格式字符清理 + Unicode 空白归一 |
| ByteLevel-normalizer | ✅ | UTF-8 bytes→GPT-2 字母表 |

### Pre-tokenizers

| 组件 | 状态 | 备注 |
|---|---|---|
| ByteLevel | ✅ | add_prefix_space/use_regex/trim_offsets；手写 GPT-2 扫描 |
| Whitespace / WhitespaceSplit / Sequence | ✅ | |
| BertPreTokenizer | ✅ | HF 分类器（`is_ascii_punctuation ∪ is_punctuation`）；**不逐字切 CJK**（那是 BertNormalizer 的事） |
| Punctuation | ✅ | 五种 behavior；MWP/MWN 只合并 run 的首/末字符（HF 实测） |
| Metaspace | ✅ | always/first/never 三种 prepend_scheme；split 开关 |
| Split（Regex 策略） | ✅ | 主流家族手写扫描器：GPT-2/Qwen-Llama3/o200k（case-aware 含希腊）/CLIP/CJK/digit-triplet；literal 与 escaped-literal alternation（`^foo$`、`\bfoo\b`、`foo|bar`、`(?:...)`、锚定/边界组合）；`\s`/`\S`/`\d`/`\D`/`\w`/`\W`、ASCII alnum/letter、`\p{L}`/`\p{N}`/`\p{P}`/`\p{S}` 及 union/反集的 exact `{2..4}` / min `{2,}..{4,}` / bounded `{1,n}` / ranged `{2,3}` 等；` {2,}`、`[\r\n]+`、水平空白族；**复杂未知 pattern 加载期 `UnsupportedComponent`** |
| Digits / CharDelimiterSplit / FixedLength / UnicodeScripts | ✅ | 含 runtime offsets 单测 |

标点分类器底座：`is_hf_punctuation` = ASCII 图形非字母数字 ∪ `@common.is_unicode_punctuation`（**经验生成** P\* 表 `src/common/unicode_punct_data.mbt`，161 区间/0–2 平面，`scripts/gen_unicode_punct.py` 扫描 0.22.2 BertPreTokenizer 生成，全边界复核零差异）。

### Decoders

| 组件 | 状态 | 备注 |
|---|---|---|
| ByteLevel | ✅ | 逆 GPT-2 映射；不可映射字符按整 token 原样；跨 token 字节拼接后一次 lossy 解码 |
| WordPiece | ✅ | i==0 原样（含前缀）/其余 strip `##` 或前缀空格；cleanup **逐 token**、精确上游 11 条有序规则（`" ."`→`.`、`" ' "`→`'`、`" n't"`、`" do not"→" don't"` 等；无 `;`/`:` 规则） |
| BPEDecoder | ✅ | 逐 token **子串级全量**替换 suffix：非末 token→空格、末 token 仅删除 |
| Metaspace | ✅ | scheme 感知：always/first 丢首 token **全部** ▁（含中部）；never 全部转空格；`split` 字段 state 保真不影响输出 |
| Fuse / Strip / Sequence | ✅ | Strip 单字符 content、首/尾各至多 n 次 |
| Replace（String/Regex） | ✅ | **逐 token** replace-all（不跨边界）；regex 不支持族经 `replace_pattern_supported` 门**显式 abort**（decode_chain 与 decode_replace_direct 两路 + Sequence 快路径元字符回落） |
| ByteFallback | ✅ | 连续/中断/非法 UTF-8 byte runs |
| CTC | ✅ | 先折叠连续重复→pad 串**任意位置**删除并去空 token→cleanup=true 逐 token wordpiece-cleanup 后分隔符串任意位置转空格；cleanup=false 分隔符保留字面量 |

### Post-processors

| 组件 | 状态 | 备注 |
|---|---|---|
| TemplateProcessing | ✅ | 预解析 pieces + 字符串 DSL（`$A`/`$B` 与 `$0`/`$1` 别名）；overflow 窗口套完整模板 |
| Bert / Roberta | ✅ | pair type_ids：Bert 0/1，Roberta 全 0（+额外 `</s>`） |
| ByteLevel | ✅ | `trim_offsets` 精确复刻 `process_offsets`（保留自加单前导空格、钳制、全空白坍缩到末端；`add_prefix_space` 插入映射零宽 (0,0)） |
| Sequence | ✅ | 含 ByteLevel+Bert 组合 pair 语义（A/B 分别 trim offsets 后再组装） |

**overflow 语义（0.22.2）**：单序列窗口进 `enc.overflowing`（Left 方向=被移除头部、近主在前）；post-processor 作用于每个窗口；Fixed padding 同步 pad 窗口；**pair 为窗口叉积**（|wa|×|wb|+|wa|+|wb|，gpt2 116/424、bert 179 与 Python 实测逐 id 一致）。

### Tokenizer 核心

| 能力 | 状态 | 备注 |
|---|---|---|
| 加载/序列化 | ✅ | `from_str`（多项 parsed-JSON cache）/`from_file`/`from_buffer`/`from_pretrained`（本地目录/文件/HF cache snapshot+source cache）/`save`/`save_pretrained`/`to_str(pretty)`/`to_json` 保真往返；root truncation/padding 自动加载 |
| encode 全族 | ✅ | `encode`/`encode_pair`/`encode_batch`/`encode_pretokenized(_pair)(_batch)`；`*_fast`（offsets 置零）；`encode_input`（EncodeInput/TextInputSequence）；`*_parallel` 兼容入口（串行+缓存）；async 兼容入口 |
| decode 全族 | ✅ | `decode`/`decode_batch`（重复序列缓存）/`decode_stream`（增量、ByteFallback 不完整缓冲）；无 decoder=`join(" ")` |
| truncation | ✅ | LongestFirst/OnlyFirst/OnlySecond；**双层 stride 校验**（配置期单序列预算 + pair 编码期每侧预算，消息逐字对齐上游）；`max<=0` 整体成空主窗口的溢出 |
| padding | ✅ | Fixed/BatchLongest、Left/Right、pad_to_multiple_of；**单条 encode 也 pad**（BatchLongest=自身长度取整）；padded 位 mask=0/special=1 |
| AddedVocabulary | ✅ | single_word/lstrip/rstrip/normalized；stage1 原文匹配 + stage2 归一化匹配；**id 分配=HF add_tokens**（可解析复用、否则 vocab_size+计数，忽略声明 id） |
| offsets | ✅ | **原文参照** char offsets（§7.8）；byte-offset 变体 API；word_ids/token↔char↔word 映射 |
| 低层/扩展 | ✅ | `NormalizedString`/`PreTokenizedString` 最小公共类型；`TokenizerComponentHooks`（per-call/persistent 组件回调）；`Regex::{is_supported,find_matches,replace_all}` |
| 缓存控制 | ✅ | `clear_cache`/`resize_cache`/`cache_size`（BPE/WordPiece/Unigram） |

### 训练

`Tokenizer::train(_from_iterator/_from_files)`（训练前应用 added-vocab extraction/normalizer/pre-tokenizer，完成后写回 model 并重映射 special ids）+ `Trainer::{wordlevel,wordpiece,bpe,unigram}` 及 `*_with_pretokenizer`/`*_from_tokens` 变体；模型文件级 `Model::save`/`from_*_file(s)`（BPE vocab.json+merges.txt、WordPiece vocab.txt、WordLevel vocab.json、Unigram score-preserving unigram.json）。参数覆盖 min_frequency/special_tokens/vocab_size/initial_alphabet/limit_alphabet/continuing prefix/end suffix/max_input_chars_per_word/max_token_length/byte_level_alphabet/unk 位置/seed_size/progress_format 等（§7.4）。**大语料 EM 对拍为遗留项**（Unigram 当前为 deterministic ranking+shrinking 近似）。

### Hub（可选 native/js `hub` 包）

`from_pretrained`（在线下载+标准 HF cache 写入；endpoint/mirror、token 显式或 `$HF_TOKEN`/`$HF_TOKEN_PATH`/`$HF_HOME/token`、`HF_ENDPOINT`/`HF_HUB_OFFLINE`/`local_files_only`）；`download_tokenizer_with_sidecars` 文件族；ETag/`If-None-Match`/`Range`/`If-Range` 请求规划与 304/200/206/416 响应决策、`.incomplete` 断点续传、HEAD 预检、`http.get_stream` byte-chunk 流式落盘（防 UTF-8 跨 chunk 截断）、401/403/404/429/5xx 诊断、private/gated 提示、aux sidecar（tokenizer_config/special_tokens_map/added_tokens）读取与 cache bridge。**sidecar 内容解析与完整错误映射为遗留项**。

## 5. 已知缺口与取舍（当前有效）

1. **normalizer Replace regex 族显式门（队列 P1）**：不支持族（如 `a+`、`e.*o`）在 normalizer 路径文本级静默 no-op（decoder 侧已显式 abort）；需穷举 `replace_all` chain 全部支持族后加加载期判定，防误拒真实模型。
2. **通用 regex 引擎**：明确不做；策略=主流家族手写扫描器（§4 Split 行）+复杂 pattern 加载期 Unsupported。Split 与 Replace/Normalizer/Decoder 三端共享 `common.simple_split_regex_matches` 分发保持同步。
3. **batch 并行**：`moonbitlang/async` 为单线程协作式（官方文档明示单硬件核），无法跨 target 多核并行 CPU-bound encode；提供 `*_parallel(_fast)` 兼容入口（串行+批内重复缓存+word cache）。runtime 提供稳定 worker 调度后可替换内部实现而不动公开 API。
4. **pair overflow 叉积 vs 0.23-dev**：按用户确认锁定 0.22.2；HF 主分支已改每侧独立窗口，若未来切换基准需重做（背景与实测数据在 PR #3）。
5. **性能遗留**：大词表 JSON 冷加载（llama from_str ~1.14x）；identity 对齐列分配（lazy 化在队列 P2）；nightly 趋势落盘未建。
6. **Unigram 采样随机性**：确定性种子（可复现），按需换真随机源。
7. **已收敛的 Replace/正则对抗分歧**（PR #13 评审发现，PR #14/#16 修复并全部 HF 实测对齐）：多行锚定（onig 逐行 `^`/`$` + 跨换行贪婪 run，normalizer/Split/decoder 三端一致）、ASCII class 拼写（`[0-9]`/`[A-Za-z0-9_]` 全量词/锚定/裸拼写）、字面量大括号（`a{b` 字面量化、`{,n}` 显式拒绝）、裸单字符类逐字符替换（双侧）、`[\w]` 族括号拼写（canonicalize 到 `\w`/`\W` 快捷形式，Unicode-wide 与 HF 一致）、锚定 `[\r\n]+`、单字符字面量有界量词 `c{n}`/`c{n,}`/`c{n,m}`（窗口 1–4，`{n,}` 整 run 消费；元字符基 `.{n}`/`?{n}` 等显式拒绝）、零下限量词 `c{0}`/`c{0,m}`/`c{0,}` 与类基（PR #19：onig 空匹配规则，max 上限 100000 与 onig 一致；text/aligned 双路径统一走 `replace_family_spans`，71 拼写等价扫描常驻）。**仍显式不支持**：`a{2,1}` 逆序区间（HF 接受并等价 `{1,2}`，本库拒绝）、class 内大括号、惰性后缀 `?`（`a{,2}?` 等）、双锚 `^[...]+$`、多转义基 `\\{0,2}`（PR #28 评审记录，均 HF 可算而本库显式拒绝）、

## 6. 开发约定

- 新组件变体：对应包 enum 加变体 → `from_json` 加 `"type"` 分派 → 实现行为（normalize/pre_tokenize/decode 同步三端语义）→ 对拍测试（先 Python 实测期望）→ §4 矩阵更新。
- 新模型对拍：`fetch_models.py` 加 URL → 下载 `tests/data/<name>.full.json` → `gen_parity.py` 生成期望 → `parity_test.mbt` 加行。
- **commit 纪律：一个 commit 一个关注点**（便于回滚）；多修批次先 `git reset main` 再按逻辑切片提交（代码+对应测试同片）；docs/PROGRESS 可跟 fix 或独立 chore commit。
- PR 流程：行为对比扫描回归 → 全后端门禁 → PR → **subagent 独立评审**（prompt 给足上下文：基准/文件位置/需实证复核的点/合规措辞；要求 detach worktree 防分支干扰）→ 评审阻塞项全部落实 → CI 8/8 → 合入。评审产出与证伪记录进「最近工作日志」。
- 消费方视角验证：`consumer-eval` 项目（moon.work 软链本仓库）模拟真实下游按文档调用。
- 代码结构：

```
src/
  types/         Encoding/Token/Split/TokenizerError + JSON 辅助
  common/        共享 regex span scanner / Unicode 表（punct/空白）/文本工具
  normalizer/    enum Normalizer + normalize(_aligned)
  pretokenizer/  enum PreTokenizer + pre_tokenize（byte_level/gpt2 等扫描器）
  model/         enum Model{BPE,WordPiece,Unigram,WordLevel} + tokenize + trainer
  processor/     enum PostProcessor + process（含 overflow 窗口）
  decoder/       enum Decoder + decode_chain
  tokenizer/     Tokenizer 组装；added_vocabulary；encode/decode/truncation/padding
  hub/           可选 native/js 在线下载（supported_targets +js+native）
  integration/   39 模型 fixture 对拍（自跳过）
  benchmarks/    moon bench
scripts/         fetch_models / gen_parity / gen_expected / bench_python / bench_compare / gen_unicode_punct / parity_cases
tests/data/      *.full.json + *_expected.json（gitignore）
```

## 7. 历史归档（按主题；细节见 git 与各 PR）

### 7.1 P0–P8 奠基（2026-06）

P0 骨架+JSON 解析 → P1 tokenizer.json 反序列化 → P2 BPE（rank 合并）→ P3 字节级 BPE+ByteLevel（GPT-2 对齐）→ P4 decode → P5 WordPiece（BERT 对齐）→ P6 Unigram+Metaspace（T5 对齐）→ P7 后处理/special token/encode_pair → P8 跨后端验证。随后：R1 AddedVocabulary 文本内 special 预切分；R2 WordLevel+byte_fallback/fuse_unk/ignore_merges+ByteFallback decoder；R3 多模型对拍设施+CI；R4 truncation/padding/encode_batch；R5 Unicode 归一化最小集（NFD+Mn/strip_accents）；R6 pre_tokenizer/decoder/template DSL 补全；R7 benchmark 套件+HF 跑分；R8 文档+迁移指南。

### 7.2 R9 迁移收敛（2026-06~07，全部完成）

`get_vocab(with_added)`、`decode_batch`（重复序列单批缓存）、`decode_stream`（增量+special skip+ByteFallback 不完整缓冲）、root-level truncation/padding 自动加载、CI/pre-commit 门禁、byte offsets 模式、`sequence_ids`、token↔char 映射（`token_to_sequence/token_to_chars/char_to_token`）、pre-tokenized encode 全族（offsets 基于归一化词单空格连接）、`word_ids`/word↔char 映射全家、Encoding/Tokenizer getter 迁移 API、Truncation strategy 完整化（预留 special slots→先截 raw pair→post-process→pad）、trim_offsets、程序化构造与 AddedToken API（builder/`set_*`/add_tokens 计数/重复不增表/introspection/`num_special_tokens_to_add`/显式 `post_process`）、charsmap 完整解码、通用 Split-Replace 正则族（三端共享分发）、save/to_json 对称性+`save_pretrained`、`from_pretrained` 全后端离线+可选 hub 包、batch 缓存与 `*_parallel` 入口、四模型 trainer MVP。
**性能专项**：BPE word cache、dense reverse vocab、legacy merges code-unit 扫描、from_str 多项 parsed-JSON cache、WordPiece cleanup 单遍化、decoder/normalizer Replace 直通快路径、Unigram word cache——全模型 `--corpus all` 无 >1.10x 慢项。

### 7.3 R10 架构治理（2026-07）

公共库/测试与基准分层/HF 风格组件边界；大文件模块化拆分十余次（model→model_vocab、tokenizer→encode(_batch)/decode/truncation/padding、trainer→training(_convenience)/setters(_model_specific)/state、added_vocabulary→_impl、split_regex→_pattern、regex_pattern_quantified→_utils、hub→helpers/_apply/_stream、normalize_precompiled→normalize_utils、encoding→_getters/_mapping），均行为无变化、以测试计数不变验收。

### 7.4 R11 前期：binding alias / trainer / hub / regex 长尾（2026-07）

- **Python binding alias（三十七批）**：全组件（Tokenizer/Model/Normalizer/PreTokenizer/PostProcessor/Decoder/Encoding/Trainer/AddedToken/Token/Regex/NormalizedString/PreTokenizedString/DecodeStream/EncodeInput）的 state（`get_state/__getstate__/__setstate__/from_state`）、tuple（`as_tuple/from_tuple`）、属性 getter/setter（`set_*` 返回新值保持不可变语义）、显示（`__str__/__repr__`）、序列访问（`__len__/__getitem__/get_item`、Sequence 子列表 getter）、配置 getter（各组件 `get_*` 全家，如 `get_strip_left/get_prepend_scheme/get_pad_token`）、精确属性名（`Strip.left/right`、`ByteLevel.alphabet()`）、lower-snake 构造器（`bert_normalizer/metaspace/bpe_decoder/fuse/sequence/char_delimiter_split`）、`Encoding` HF 形态（`*_by_sequence_index/truncate_hf/pad_hf`）、`EncodeInput/TextInputSequence`、async/parallel 兼容入口、错误分类 helper、Hub header 合约（Accept/UA 差异/空 token 不发 Authorization）。原则：typed 显式风格不变，alias 均薄封装。
- **Trainer 进化（十四批）**：show_progress/special_added_tokens（no-op 兼容）、WordPiece end_of_word_suffix+max_token_length、Unigram unk_piece/max_piece_length/initial_alphabet（多字符取首字符、cap 下优先）/unk 插入位（special_tokens 含 unk 时保序）/seed_size（ranked candidate cap）/shrinking_factor+n_sub_iterations 透传 + deterministic ranking+shrinking 近似、BPE continuing_subword_prefix merge surface（合并右侧先去 prefix，防 `a@@b`）/progress_format（indicatif/json/silent 回落）、initial_alphabet×limit_alphabet 交互（同池优先但受 limit）、train_from_iterator 保留原模型 dropout/byte_fallback/ignore_merges/cache 容量、TrainerState、通用+模型特异 getter/setter alias。
- **Hub 进化**：`PretrainedAuxFiles` 固定 aux 读取、`from_pretrained_aux_file(_path)` 通用 sidecar 原文、`cache_pretrained_aux_file`/`apply_hub_file_download_result` raw cache bridge、`download_hub_file` 2xx-only GET、`PretrainedCacheMetadata`（cache_exists/etag_matches/is_fresh）、`PretrainedResolutionHint`（private/gated 诊断）、ref/resume 元数据 helper、`HubRequestPlan/HubResponseMetadata`（If-None-Match/Range/If-Range）、`HubTransferAction/HubResponseDecision`（304/200/206/416）、HEAD 预检（缓存命中校验后复用）、`apply_tokenizer_json_download_chunks/bytes`（byte-accurate 续传 sidecar）、`get_stream` byte-chunk 流式（防 UTF-8 截断）、`stream_chunk_size`、header 大小写无关解析/Content-Range 起点校验/model id 路径段校验、401/403/404/429/5xx 诊断、文件族自动下载（tokenizer_config/special_tokens_map）。
- **Regex/Replace 覆盖扩展**：digit/word/letter/punct/symbol 正反向 class 的 exact/min/bounded/ranged 量词族、锚定与反集 runs（`[^\s\p{L}\p{N}]+` 等），三端共享分发表；`PreTokenizedString::get_item`、Decoder Sequence 索引/长度 alias、PostProcessor Sequence pair 修正（A/B 分别 ByteLevel trim 后再组装）同期落地。

### 7.5 版本发布史

| 版本 | 日期 | 要点 |
|---|---|---|
| 0.1.0 | 2026-06 | 首发 mooncakes |
| 0.2.0 | 2026-07-11 | trainer/hub/binding 长尾第一批 |
| 0.3.0 | 2026-07-13 | Hub 文件族自动下载；CI 8/8 |
| **0.4.0** | 2026-09-08（PR #5） | truncation overflow 全链路修复（#1）、pair 叉积（#3）、文档可运行化（#2）、stride 配置期校验（#4）、工具链漂移治理；发布后干净项目安装验证四特性全中（24 窗口/424 叉积/配置期报错逐字/parity 保持） |

0.4.0 之后 main 未发版：PR #6–#10（§7.7）→ 建议发 0.5.0。

### 7.6 truncation/overflow 专项（PR #1–#4，2026-09-06）

消费方评估（consumer-eval 按 README 从零调用 0.3.0）发现 `enc.overflowing` 恒空而 HF 返回窗口（gpt2 stride8→24、bert→15）。三处独立丢失点：`processor/process.mbt` 的 `build()`（template/bert 共用，硬编码 `[]`）、`merge_plain`（ByteLevel 族）、`pad_encoding` 双方向。修复后：单序列双方向/stride 0 与正/padding 同步/`add_special_tokens=false` 窗口无 special 全对齐；pair 按叉积公式（见 §4 overflow 行）；stride 校验双层（§2 日志）。根源分析含 HF `Encoding::truncate` 逐区间复刻（`rev().step_by(offset)`）。

### 7.7 行为对比扫描专项（PR #6–#10，2026-09-19~20）

建扫描设施（§3）后五批修复：**合成 813/1008→1008/1008、真实 59/100→100/100**。
1. **#6** decode join + 标点分类器（经验 P\* 表）+ MWP/MWN + CJK 分组；
2. **#7** charsmap 字素簇归一化（t5 NFD ids 清零）；
3. **#8** decoder 边缘语义 + Replace 显式门（三次评审修正）；
4. **#9** offsets 原文映射架构（四次评审修正）；
5. **#10** 残余清零（见 §2 日志）。
方法论要点：所有期望值先在 Python 0.22.2 实测；agent 探针表也会出错（两处被直接复测证伪并撤销）；subagent 评审累计抓出 12 项阻塞级问题全部落实。

### 7.8 offsets 原文映射架构（PR #9+，维护者参考）

- **数据结构**：`Normalizer::normalize_aligned(文本) -> (String, Array[(Int,Int)])`——每归一化字符一个原文 [start,stop) span；`compose_align(base, top)` 级联重定基（Sequence/Bert 各步）；`expand_align(align, s, e)` span 回转（start/stop 双侧钳制，零宽→(0,0)）。
- **各 normalizer span 规则（HF transform 契约，全部实测锁定）**：
  - 1:1 替换（lowercase/clean_text）：继承原字符 span；
  - 展开（NFD/accent-map）：每个输出字符继承源字符 span；
  - 组合（NFC/NFKC `canonical_compose_aligned`）：组合结果保留**首个**被组合字符 span（`-N` 契约；"z"+"e"+U+0301+"z"→z(0,1) é(1,2) z(3,4)）；
  - 删除（strip/控制字符/组合记号）：后续字符 span 不变；
  - 插入（Prepend/bert 中文空格）：附着邻字符 span（Prepend 全部映射 [0,1)）；
  - Replace：内容字符附着**命中末字符** span（Regex "aa"→"XY" 于 "zaa"：X、Y 均 (2,3)）；ReplaceString 走独立纯字面量路径；
  - charsmap 整簇替换：映射**首**消费字符 span（t5 "cafe◌́"→é 取 "e" 的 (8,9)）。
- **管线**（`encode_helpers.mbt`）：`normalize_with_alignment`（组件 hook 回退 identity 列，行为不变）→ stage-2 added-token 段与模型 token 发射统一经 `to_orig`（expand + stage-1 基址）→ 模型 `tokenize(offset=0)` 取 piece 相对 span 后转换。
- **piece origin map**：`piece_origin_map(kind, norm_sub, value_len)` 按**预分词器类型**选模型——ByteLevel=每 UTF-8 字节一 entry、Metaspace=每字符 1:1；单个前缀插入（Ġ/▁）+1 附着 index 0；长度不符返回 None 走旧行为；ByteLevel+Metaspace 混合 Sequence 显式不支持。ByteLevel 自加前缀空格经 post-trim 后映射零宽 (0,0)。
- **identity 对齐=旧行为逐位不变**（gpt2/llama 无 normalizer 模型为回归护栏）；已知代价：每字符一个 tuple 分配（lazy 化在队列）。

---

*更早的逐条记录（77 个小闭环全文、R9–R11 完整验收表）见 git 历史：2026-09-20 PROGRESS 重构（PR #11）及其父提交。*
