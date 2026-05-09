# DISK_CLEANER Workspace 指令

## 入口脚本
- `D:\bot\maintenance\disk_cleaner.ps1`

## 触发优先级（Telegram）
当机器人收到以下指令时，优先执行 `disk_cleaner.ps1`：
- 磁盘报告
- 清理C盘
- 清理D盘
- 查看可清理空间

## 建议映射
- 磁盘报告 -> `powershell -ExecutionPolicy Bypass -File D:\bot\maintenance\disk_cleaner.ps1 -Scan -Top 30`
- 查看可清理空间 -> `powershell -ExecutionPolicy Bypass -File D:\bot\maintenance\disk_cleaner.ps1 -Scan -Top 30`
- 清理C盘 -> `powershell -ExecutionPolicy Bypass -File D:\bot\maintenance\disk_cleaner.ps1 -CleanSafe -Top 30`
- 清理D盘 -> `powershell -ExecutionPolicy Bypass -File D:\bot\maintenance\disk_cleaner.ps1 -CleanSafe -Top 30`

## 安全约束
- 未携带 `-CleanSafe` 时，只允许扫描，不执行删除。
- 禁止删除：
  - `openclaw.json`
  - `credentials`
  - `telegram`
  - `scripts`
  - `workspace`
  - Desktop 文件
  - Downloads 文件
  - `D:\bot` 业务文件

## JSON 输出
- 需要结构化回传时，追加 `-Json`。
