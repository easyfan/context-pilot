# context-pilot

**Claude Code context 窗口的「安全遗忘」协议。**

[English](README.md) | [Deutsch](README-de.md) | [Français](README-fr.md) | [Русский](README-ru.md)

`/clear 之后继续做 X` 是一条模型永远无法执行的指令：说出它的 context 会被它
自己销毁。context-pilot 把这条"不可发音"的指令编译成三个 harness 级动作——
clear 前写好自足的 handoff、由人按下 `/clear`、clear 后自动把 handoff 投递进
冷启动的新会话。效果：长会话可以**无损**跨过一次 context 清空，而不必拖着
臃肿 context（每一轮都是实打实的 token 税）或退回有损的 auto-compact。

[quota-pilot](https://github.com/easyfan/quota-pilot) 的姊妹插件：
quota-pilot 让会话跨过限额窗口（冬眠）；context-pilot 让会话跨过 context
清空（带着给自己的信失忆）。两者共享 checkpoint 哲学，但有一个关键差异：
quota-pilot 的 checkpoint 是保险，context-pilot 的 handoff 是新会话的
**全部记忆**——所以它的 gate 拥有否决权。

## 组件

| 组件 | 作用 |
|---|---|
| **Skill**（`context-pilot`） | 写入端协议：决策规则（继续干 / clear / compact）、把只活在对话里的东西全部翻出来的六成分审计、冷可读性写作规则、以及能否决不安全 clear 的自足性 gate。 |
| **命令**（`/clear-then <下一步>`） | 以显式给定的下一步跑同一套协议，最后把 `/clear` 按键交还给你。 |
| **SessionStart hook**（`context_deliver.sh`） | source 无关投递：你按下 `/clear` 后（原生 Claude 或 happy app 均可），新鲜的 `context-handoff.md` 会连同冷读前导注入新会话，随后被消费（改名），保证不会被无关会话重复摄入。 |
| **PostToolUse hook**（`context_sample.sh`） | 采样：从 transcript 读取 context 占用；超过 70%（可配）注入边界评估告警，冷却期内最多一次。 |

## 决策规则（skill 强制执行的内容）

三个输入：**t**（剩余工作量）、**H**（自足所需的 handoff 体积）、
**N**（距天花板的距离——只提供紧迫度）。

- **t 小** → 直接干完；任何转移都是纯开销。
- **自足性不可达**（下一步依赖仍在对话中的推理）→ **不** clear；
  干到真边界，或接受 auto-compact。
- **gate 通过且 H 小** → 写 handoff，邀请 `/clear`。
- **灰区**（H 接近 compact 摘要的体积）→ 判给 compact。compact 是**软失败**
  （模型能感到缺口、能回读文件）；坏的 clear 是**静默失败**（新会话不知道
  自己不知道什么）。边际情形一律判给软失败。

handoff 按六成分审计记录：目标、具体到命令/文件的下一步、**决策（含被显式
否决的备选方案）**、踩过的坑、诚实的未验证状态、用户的口头约束——外加指向
旧 transcript 的会话地图（clear 销毁的是注意力，磁盘上的 transcript 还在）
和审计自身的记录。只落指针，不复制内容。

## 为什么模型不能自己做这件事

对 CC 二进制（2.1.20x）实测验证：任何 hook 输出字段、命令队列或 SDK 控制
请求都无法触发 `/clear`——清空严格由人在交互界面发起。后台 subagent 也
带不动这份状态：它的返回值只能落进即将被销毁的父 context。所以是这个架构：
**磁盘文件当托管人，SessionStart hook 当信使，人当扳机。**

## 安装

作为插件：

```
/plugin marketplace add easyfan/context-pilot
/plugin install context-pilot@context-pilot
```

手动安装（把 skill + 命令 + hooks 装进 `~/.claude/`）：

```bash
git clone https://github.com/easyfan/context-pilot.git
cd context-pilot && ./install.sh          # --dry-run 预览，--uninstall 卸载
```

## 配置

可选的 `~/.claude/context-pilot/config.json`：

```json
{
  "context_window": 200000,
  "warn_pct": 70,
  "cooldown_minutes": 15,
  "check_seconds": 60
}
```

> **1M 窗口模型注意：** `context_window` 默认为 `200000`。如果你的模型是 1M token 上下文窗口（如 `[1m]` 型号），请改为 `1000000`——否则告警会过早触发，甚至报出超过 100% 的用量。

投递新鲜度窗口（handoff 距写入多久内才会被注入）：
`CONTEXT_PILOT_FRESH_SECONDS`，默认 900 秒。

## 典型流程

1. 干得够久，采样器注入 `[context-pilot]` 告警（或直接问"现在能安全 clear
   吗"，或运行 `/clear-then 实现 phase 2`）。
2. skill 跑决策规则。若确为真边界，写 `.claude/context-handoff.md`、通过
   自足性 gate，然后告诉你可以按了。
3. 你按 `/clear`。
4. 新会话带着注入的 handoff 启动，先用 2-3 行复述它对目标和下一步的理解、
   等你确认——然后带着干净的、近乎空的 context 继续干活。

## 文件

```
skills/context-pilot/SKILL.md   协议本体
commands/clear-then.md          /clear-then 命令
hooks/context_deliver.sh        SessionStart 投递（consume-once）
hooks/context_sample.sh         PostToolUse 采样
hooks/hooks.json                插件 hook 注册
install.sh                      手动安装器
evals/evals.json                行为评测集（对比无 skill 基线 +26pp）
```

## 许可证

MIT
