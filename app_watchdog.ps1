# 陶瓷车间 App 看门狗脚本
# 功能：监控 App 进程，如果崩溃或退出则自动重启
# 用法：右键 -> 使用 PowerShell 运行

$AppName = "ceramic_workshop_app"
$AppPath = ".\build\windows\x64\runner\Release\ceramic_workshop_app.exe" # 开发环境路径
# 如果是部署环境，请修改为实际路径，例如：
# $AppPath = ".\ceramic_workshop_app.exe"

$CheckInterval = 5 # 检查间隔（秒）
$LogFile = ".\watchdog_log.txt"

function Write-Log {
  param ($Message)
  $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $LogEntry = "[$TimeStamp] $Message"
  Write-Host $LogEntry -ForegroundColor Cyan
  Add-Content -Path $LogFile -Value $LogEntry
}

Write-Log "启动看门狗监控: $AppName"

# 初始启动
if (-not (Get-Process -Name $AppName -ErrorAction SilentlyContinue)) {
  Write-Log "App 未运行，正在启动..."
  Start-Process -FilePath $AppPath -WorkingDirectory (Split-Path $AppPath)
}

while ($true) {
  $Process = Get-Process -Name $AppName -ErrorAction SilentlyContinue
    
  if (-not $Process) {
    Write-Log "警告: 检测到 App 已退出或崩溃！"
    Write-Log "正在尝试重启..."
        
    try {
      Start-Process -FilePath $AppPath -WorkingDirectory (Split-Path $AppPath)
      Write-Log "重启命令已发送。"
      # 等待一会儿让程序启动，避免死循环
      Start-Sleep -Seconds 10 
    }
    catch {
      Write-Log "错误: 无法启动 App. 请检查路径: $AppPath"
      Write-Log $_.Exception.Message
    }
  }
    
  Start-Sleep -Seconds $CheckInterval
}
