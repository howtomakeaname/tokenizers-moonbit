# PROGRESS — tokenizers-moonbit 开发进度与任务跟踪

> **本文档维护约定（后续接手的模型/开发者请先读）**
>
> - 本文件是进度的唯一真相源；**细节看 git 历史与 PR 链接**，这里只保留"当前状态 + 可检索的结论"。
> - 接手先读 §2（当前状态与下一步），需要细节再按 §3–§6 下钻。
> - 更新规则：
>   1. 新工作开始 → 在 §2 待办队列表加一行（谁/做什么/验收口径）；
>   2. 每个 PR 合入 → 在 §2「最近工作日志」**顶部**加 3–8 行摘要（日期 + PR 号 + 结论 + 验证数据）；
>   3. 能力/组件变化 → 同步改 §4 矩阵；发现新缺口 → 加进 §5；
>   4. 「最近工作日志」超过 ~30 条时，把最旧的压缩进 §7 历史归档（按主题合并，不逐条搬运）；
>   5. **禁止**在归档节追加流水账；**禁止**恢复按日期逐条记录全部细节的旧格式。

## 1. 项目定位与硬约束

- MoonBit 版 HuggingFace `tokenizers`：加载标准 `tokenizer.json`，全后端（wasm/wasm-gc/js/native）运行同一套 encode/decode。
- **对齐基准：Python `tokenizers` 0.22.2**（用户指定；HF 0.23-dev 的行为变化不跟随，遇到差异先实测 0.22.2）。
- 原则：inference-first、确定性、跨 target；**精确 HF 行为优先于大而全**；不支持的行为必须显式失败（加载期 `UnsupportedComponent` / 运行期报错），**绝不静默近似**。
- 公开 API 变更必须 `moon info` 更新 .mbti；措辞只用"行为对比/probe"（合规要求，禁用逆向类表述）。
- 发布：mooncakes `howtomakeaname/tokenizers-moonbit`，当前 **0.4.0**（0.4.0 后 main 已合入行为对比扫描五批修复，见 §7.7，下次发版建议 0.5.0）。

## 2. 当前状态与下一步（TL;DR）

**状态（2026-09-20）**：行为对比扫描**双双全绿**——合成 1008/1008、真实模型 100/100（Python 0.22.2 基准）；39 模型 fixture 对拍全绿；测试 native/js 432、wasm/wasm-gc 409；CI 8/8（含 HF benchmark smoke）。

### 待办队列

| 优先级 | 事项 | 验收口径 | 备注 |
|---|---|---|---|
| P1 | normalizer Replace 不支持 regex 族的**加载期显式门** | 穷举 chain 支持族做判定，未知族 load 期 `UnsupportedComponent`，不得误拒现有真实模型 | 需先枚举 `normalize_utils.mbt` replace_all 全部族；decoder 侧同类门见 PR #8 |
| P2 | identity 对齐列 lazy 化 | `tokenizer-encode-special-switch-mixed` 微基准回到 +14% 以内 | encode 热路径每字符一个 tuple 的开销（PR #9 评审 nit） |
| P2 | `replace_pattern_supported` 与 `replace_all` 分发表知识去重 | 从 `@common` 暴露统一族判定 | 两处表会漂移（PR #8 评审 nit） |
| P3 | 发版 0.5.0 | PR + CI 全绿 + `moon publish` + 干净项目安装验证 | 含 offsets 对齐、id 分配等行为变化；semver minor |
| P3 | 高级 trainer 大语料对拍 | 需外部数据集 | R11 遗留 |
| P3 | Hub sidecar 内容解析与错误映射 | 参照 hf-tokenizers 源码逐项对拍 | R11 遗留 |
| P3 | Python binding 低频 alias 长尾 | 按需 | 已至第三十七批 |

### 最近工作日志（新在上）

- **2026-09-20 PR #10**：残余小类清零，双扫描 100%。charsmap 簇 span 首字符规则、BatchLongest 单条 encode 取整 padding、ByteLevel trim 精确复刻 `process_offsets`、standalone StripAccents 只删已分解记号、added-token id 按 HF `add_tokens` 顺序分配（评审修正为完全忽略声明 id）。按用户要求拆为 6 个单一关注点 commit。
- **2026-09-20 PR #9**：offsets 原文映射架构落地（`normalize_aligned` 对齐列 + 管线穿线 + kind-keyed piece origin map）。合成 857→987、真实 59→94。评审修 4 项阻塞（compose 首 span 规则、Replace 末字符附着、ReplaceString 字面量路径、按类型选映射）。
- **2026-09-20 PR #8**：decoder 边缘语义（BPE 末 token suffix、Metaspace scheme、CTC 子串/逐 token cleanup、Replace 显式门）。评审修 3 项阻塞（门覆盖直接路径、BPE 子串全量、cleanup 规则表精确复刻）。探针表一行被证伪未采纳。
- **2026-09-19 PR #7**：precompiled charsmap 字素簇（<6 字节整簇查 trie），t5 NFD ids 分歧清零。
- **2026-09-19 PR #6**：decode join(" ")、HF 标点分类器（经验生成 P\* 表 `scripts/gen_unicode_punct.py`）、BertPreTokenizer 不切 CJK、MWP/MWN run 语义。评审修 2 项阻塞（P\* 表不精确→经验生成；FE 区块误删回归）。
- **2026-09-08 PR #5 + publish**：发版 0.4.0（truncation overflow 修复 + pair 叉积 + 文档 + 配置期校验 + 工具链漂移治理）。
- **2026-09-06 PR #1–#4**：truncation overflowing 三处丢失点修复、pair overflow 叉积（0.22.2 语义）、文档可运行化、stride 配置期校验。消费方视角评估（consumer-eval 项目）发现 overflowing 缺陷。

## 3. 对齐基准与验证设施

### 行为对比扫描（核心验收设施）

- **语料**：`scripts/parity_cases.py` 生成 42 个合成 tokenizer 配置（富词表 BPE/WordPiece）× 20 条边界输入（全角/CJK/NFD/代码/空白等）+ 5 个真实模型（gpt2/bert/t5/qwen3/llama3_2）同输入矩阵；golden 由本机 Python `tokenizers` 0.22.2 产出。
- **驱动**：`/tmp/parity-driver`（moon.workspace 软链本仓库），`moon run cmd/sweep`；`PARITY_MODE=real` 跑真实模型。探针用 `cmd/drv`，勿覆盖 `cmd/sweep`。
- **语料再生成**：`python3 scripts/parity_cases.py /tmp/parity-sweep`（真实模型目录可用 `PARITY_MODELS_DIR` 覆盖）。
- **当前基线：合成 1008/1008、真实 100/100**。改行为前先跑扫描，改后回归对比。

### 39 模型 fixture 对拍

`src/integration/parity_test.mbt` 表驱动；`scripts/fetch_models.py` 下载 `tests/data/*.full.json`，`scripts/gen_parity.py` 生成期望（均 gitignore，缺失自跳过）。覆盖 gpt2/roberta/llama/bert(-cased)/distilbert/t5/albert/xlm-roberta/Qwen2.5/Qwen3/DeepSeek-V2/V3.2/R1/Phi-3/Phi-4-mini/Mistral/Falcon/StarCoder2/GPT-NeoX/CLIP/DeBERTa/Llama-3.2/GPT-OSS/GLM-4.5/Granite/Qwen3-Coder/Qwen3-VL/bge-m3/e5(-multilingual/small)/ModernBERT/GTE-ModernBERT/MiniLM/bge-large/jina-v3/nomic/mxbai/SmolLM2，逐 token id 一致。

### 性能对比

结论必须基于 `scripts/bench_compare.py` 同机比值（Moon/HF），不用裸 `moon bench`。`>1.10x` 进优化排期、`<0.90x` 才可宣称快。全量抽样结论：主流 encode 0.25x–0.68x（快于 HF），decode 同档或更快，大词表冷加载为下一优化重点。CI 含 benchmark smoke 门。

### 测试与 CI 门禁

```bash
export PATH="$HOME/.moon/bin:$PATH"
moon fmt --check && moon check --deny-warn && moon info   # .mbti 无 diff
moon test --target native --deny-warn                      # 同样跑 js/wasm/wasm-gc
```

- CI 8 job：4 后端测试 / Python 脚本 / Release gates（fmt+check+info+metadata）/ 可选 parity smoke / HF benchmark smoke。
- **工具链漂移警惕**：CI 用最新 moon，历史上已连续出现 StringBuilder 弃用、`{}` 歧义、formatter 重排、`.mbti` 尾行、`unused_package`（bench/core/int 导入）六层；本地门禁全绿但 CI 红时先怀疑漂移，逐层修复。
- 措辞红线：PR/commit/docs 只用"行为对比/probe"，禁用逆向类词汇（合规）。

## 4. 能力矩阵

### Models

| 组件 | 状态 | 备注 |
|---|---|---|
| BPE / 字节级 BPE | ✅ | 优先队列合并+惰性失效+word cache；`unk_token=None` 跳过 unknown；dropout 序列化且 `>0` 禁缓存 |
| byte_fallback / fuse_unk / ignore_merges | ✅ | |
| WordPiece | ✅ | `continuing_subword_prefix`/`end_of_word_suffix` |
| Unigram | ✅ | Viterbi+cache+forward-backward/N-best 采样（`alpha`/`nbest_size`，确定性种子） |
| WordLevel | ✅ | |

### Normalizers（全部带原文对齐列，见 §7.8）

Lowercase/Strip/Replace(String+Regex)/Prepend/Sequence/BertNormalizer/StripAccents(仅删已分解记号)/NFC/NFD/NFKC/NFKD(UAX#15 全流程)/Precompiled(二进制 charsmap+字素簇<N字节整簇查询+ASCII fast path)/Nmt/ByteLevel —— 全 ✅。

### Pre-tokenizers

ByteLevel(含 add_prefix_space/use_regex/trim_offsets)/Whitespace/WhitespaceSplit/BertPreTokenizer(HF 分类器，不切 CJK)/Punctuation(五种 behavior，MWP/MWN run 首/末字符语义)/Metaspace(三种 prepend_scheme)/Split(主流 regex 家族+literal/alternation/锚定/word-boundary/量词族；复杂 pattern 加载期显式 Unsupported)/Digits/CharDelimiterSplit/FixedLength/UnicodeScripts/Sequence —— 全 ✅。标点分类器 `is_hf_punctuation` = ASCII ∪ 经验生成 P\* 表（`unicode_punct_data.mbt`，0–2 平面全量扫描 0.22.2 生成，`scripts/gen_unicode_punct.py` 再生）。

### Decoders

ByteLevel/WordPiece(逐 token cleanup，精确 11 规则)/BPEDecoder(子串级 suffix 全量替换)/Metaspace(scheme 感知首 token 全删)/Fuse/Replace(逐 token；不支持族显式 abort)/Strip/ByteFallback/CTC(dedup+pad 子串删除+cleanup 逐 token)/Sequence —— 全 ✅。

### Post-processors

Template(预解析 pieces+字符串 DSL)/Bert/Roberta(pair 全 type_id 0)/ByteLevel(trim 精确复刻 process_offsets)/Sequence —— 全 ✅。**overflow 语义**：单序列窗口保留（含套模板/同步 padding）；pair 为 0.22.x 叉积。

### Tokenizer 核心

from_str/from_file/from_buffer/from_pretrained(本地+HF cache)/save/to_json/encode(_fast/_batch/_pair/_pretokenized 全族)/decode(_batch/_stream)/truncation(配置期+编码期双层 stride 校验)/padding(Fixed/BatchLongest；单条 encode 也按 multiple 取整)/AddedVocabulary(single_word/lstrip/rstrip/normalized；**id 分配按 HF add_tokens：可解析复用、否则 vocab_size+计数顺序分配**)/offsets(**原文参照**，含 byte-offset 变体)/token↔char↔word 映射/程序化构造与 binding alias 常备。

### 训练

`Tokenizer::train(_from_iterator/_from_files)` + `Trainer::{wordlevel,wordpiece,bpe,unigram}`（MVP，确定性；`*_with_pretokenizer`/`*_from_tokens` 变体；模型文件级 save/load）。大语料 EM 对拍为遗留项。

### Hub（可选 native/js `hub` 包）

`from_pretrained`（在线下载+HF cache 写入+mirror/token/env）、`download_tokenizer_with_sidecars`（文件族）、ETag/Range/resume/HEAD 预检/流式落盘/诊断 hint。sidecar 内容解析为遗留项。

## 5. 已知缺口与取舍（当前有效）

1. **normalizer Replace regex 族**：不支持族（如 `a+`）文本级静默 no-op（decoder 侧已显式门）——待加载期显式门（见 §2 队列 P1）。
2. **通用 regex 引擎**：明确不做；覆盖策略=主流家族手写扫描器+复杂 pattern 加载期 Unsupported。
3. **batch 并行**：`moonbitlang/async` 为单线程协作式，无法跨 target 多核；提供 `*_parallel` 兼容入口（串行+缓存）。runtime 提供稳定 worker 后可替换实现。
4. **pair overflow 叉积 vs 0.23-dev**：按用户确认锁定 0.22.2 语义；HF 主分支已改为每侧独立窗口，若未来切换基准需重做（记录于 PR #3）。
5. **性能遗留**：大词表 JSON 冷加载；identity 对齐列分配（lazy 化在队列）。
6. **Unigram 采样随机性**：确定性种子，按需换真随机。

## 6. 开发约定

- 新组件变体：包 enum 加变体 → `from_json` 分派 → 实现行为 → 对拍测试 → 矩阵更新。
- 新模型对拍：`fetch_models.py` 加 URL → `gen_parity.py` 生成期望 → `parity_test.mbt` 加行。
- **commit 纪律：一个 commit 一个关注点**（便于回滚）；多修批次先 `git reset main` 再切片提交；PROGRESS/docs 可跟对应 fix 或作独立 chore commit。
- PR 流程：行为对比扫描回归 → 全后端门禁 → PR → **subagent 独立评审**（给足上下文，要求实证复核）→ 修正 → CI 8/8 → 合入。评审抓出的阻塞项全部落实后才能合。
- 消费方视角验证：`consumer-eval` 项目（moon.work 软链）模拟真实下游调用。

## 7. 历史归档（按主题压缩；细节见 git 与 PR）

### 7.1 P0–P8 奠基（2026-06）

骨架→JSON 反序列化→BPE/字节级 BPE→decode→WordPiece→Unigram+Metaspace→后处理/special token/pair→跨后端验证；随后 AddedVocabulary、WordLevel+byte_fallback/fuse_unk/ignore_merges、多模型对拍设施、truncation/padding/encode_batch、Unicode 归一化最小集、pre-tokenizer/decoder/template DSL 补全、benchmark 套件、文档与迁移指南全部完成。

### 7.2 R9 迁移收敛（2026-06~07）

get_vocab(with_added)/decode_batch/decode_stream/root truncation+padding 自动加载/CI 门禁/byte offsets/sequence_ids/token↔char 映射/pre-tokenized encode API/word_ids/Truncation strategy 完整化/trim_offsets/程序化构造与 AddedToken API/charsmap 完整解码/通用 Split-Replace 正则族/save 对称性/from_pretrained+可选 hub 包/batch 缓存与 parallel 入口/四模型 trainer MVP —— 全部完成。性能专项：word cache、dense reverse vocab、merges code-unit 扫描、parsed-JSON cache、decoder/normalizer 直通快路径，全模型抽样无 >1.10x 慢项。

### 7.3 R10 架构治理（2026-07）

公共库/测试与基准分层/HF 风格组件边界；大文件模块化拆分（model/tokenizer/trainer/added_vocabulary/split_regex/hub/normalize_precompiled 等十余次拆分，行为无变化）。

### 7.4 Binding alias 与 Hub 长尾（R11 前期，2026-07）

- **Python binding alias（至第三十七批）**：全组件 state/tuple/getter/setter/`__str__`/`__repr__`/`__len__`/`__getitem__`/低层 NormalizedString/PreTokenizedString API/EncodeInput/async 兼容入口/错误分类 helper/构造器 lower-snake alias 等；原则=typed 显式风格不变，alias 薄封装。
- **Trainer 进化（十四批）**：setter/getter alias、TrainerState、initial_alphabet/limit_alphabet 交互、BPE continuation prefix merge surface、Unigram unk 插入位/seed_size/progress_format、exotic 配置透传等。
- **Hub 进化**：aux sidecar 读取、ETag/Range/resume 元数据、条件请求与响应决策、HEAD 预检、流式落盘（byte chunk 防 UTF-8 截断）、env/local-only 闭环、文件族自动下载、HTTP 诊断。
- **Regex/Replace 覆盖扩展**：digit/word/letter/punct/symbol 正反向 class 的 exact/min/bounded/ranged 量词族、锚定与反集 runs，三端（Split/Normalizer/Decoder）共享分发。

### 7.5 版本发布史

0.1.0（2026-06 首发 mooncakes）→ 0.2.0（2026-07-11）→ 0.3.0（2026-07-13，Hub 文件族）→ **0.4.0（2026-09-08，PR #5；truncation overflow 修复+pair 叉积+文档+配置期校验；发布后干净项目四特性验证全中）**。0.4.0 之后 main 未发版内容见 7.6–7.8。

### 7.6 truncation/overflow 专项（PR #1–#4，2026-09-06）

消费方评估发现 `enc.overflowing` 恒空（三处丢失点：template build、ByteLevel merge_plain、pad_encoding）；逐项修复并补 Left 方向窗口、pair 叉积（gpt2 116/424、bert 179 与 Python 实测逐 id 一致）、stride 配置期+编码期双层校验（消息逐字对齐上游）。

### 7.7 行为对比扫描专项（PR #6–#10，2026-09-19~20）

建扫描设施（§3）后五批修复，从合成 813/1008、真实 59/100 推进到**双双 100%**：
1. decode join(" ") + HF 标点分类器（经验生成 P\* 表）+ MWP/MWN + CJK 分组（#6）；
2. charsmap 字素簇归一化（#7）；
3. decoder 边缘语义四项 + Replace 显式门（#8）；
4. offsets 原文映射架构（#9）；
5. 残余小类清零：BatchLongest 单条、ByteLevel trim 权威算法、StripAccents 拆分、added-token id 分配（#10）。

每批均经 subagent 评审，累计抓出 12 项阻塞级问题并全部修正；两处探针表/缺口记录被评审证伪并撤销。

### 7.8 offsets 原文映射架构（PR #9+，供后续维护参考）

- `Normalizer::normalize_aligned` 返回 (文本, 每归一化字符的原文 span 列)；`compose_align` 级联重定基、`expand_align` span 回转（边界钳制）。
- 关键规则（均 HF transform 契约，实测锁定）：NFC 组合→**首**被组合字符 span；NFD 展开→各分解字符继承原字符 span；Replace 内容→**命中末字符** span；Prepend/中文空格插入→附着邻字符 span；charsmap 整簇替换→**首**消费字符 span；standalone StripAccents 只删已分解记号。
- 管线：`normalize_with_alignment`（hook 回退 identity）→ stage-2/模型 token 发射经 `to_orig` 转换 → 模型以 `offset=0` 取 piece 相对 span。
- piece origin map 按**预分词器类型**选择（ByteLevel=每字节、Metaspace=每字符；前缀插入 +1 附着首字符；混合 Sequence 显式不支持）。identity 对齐=旧行为逐位不变（gpt2/llama 护栏）。

---

*历史细节（含全部小闭环条目原文）见 git 历史：2026-09-20 之前的 PROGRESS.md 版本。*
