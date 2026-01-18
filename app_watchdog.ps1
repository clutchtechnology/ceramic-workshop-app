<#
.SYNOPSIS
    陶瓷车间 App 强力看门狗 (防卡死专用版 v2.0)
.DESCRIPTION
    1. 监控 App 是否崩溃（进程消失）。
    2. 监控 App 是否卡死（UI 未响应）。
    3. 使用 taskkill 进行强力查杀，确保重启前清理干净。
#>

$AppName = "ceramic_workshop_app"
# 请确保此路径指向您的 exe (开发环境)
$AppPath = ".\build\windows\x64\runner\Release\ceramic_workshop_app.exe" 
# 如果是工控机部署环境，请解开下面这行的注释并修改路径:
# $AppPath = ".\ceramic_workshop_app.exe"

$CheckInterval = 5      # 每隔几秒检查一次
$MaxFreezeCount = 6     # 连续几次检测到未响应才重启 (30秒)
$LogFile = ".\watchdog_log.txt"

$CurrentFreezeCount = 0

function Write-Log {
  param ($Message)
  $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $LogEntry = "[$TimeStamp] $Message"
  Write-Host $LogEntry -ForegroundColor Cyan
  Add-Content -Path $LogFile -Value $LogEntry
}

function Force-Kill-App {
  Write-Log "正在执行强制关闭程序..."
    
  # 1. 尝试常规关闭 (针对所有同名进程)
  Get-Process -Name $AppName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    
  # 2. 尝试 Taskkill 强力查杀 (核弹级清理)
  Start-Sleep -Seconds 1
  taskkill /F /T /IM "${AppName}.exe" 2>$null
    
  # 3. 循环确认进程是否真的消失了
  $Retry = 0
  while ((Get-Process -Name $AppName -ErrorAction SilentlyContinue) -and ($Retry -lt 5)) {
    Write-Log "等待进程释放... ($Retry)"
    Start-Sleep -Seconds 1
    taskkill /F /T /IM "${AppName}.exe" 2>$null
    $Retry++
  }
    
  if (Get-Process -Name $AppName -ErrorAction SilentlyContinue) {
    Write-Log "错误: 无法杀死进程，可能需要管理员权限或系统异常！"
    return $false
  }
    
  Write-Log "App 已成功彻底关闭。"
  return $true
}

function Start-App {
  Write-Log "正在启动 App..."
  try {
    Start-Process -FilePath $AppPath -WorkingDirectory (Split-Path $AppPath)
    Write-Log "启动命令已发送。"
  }
  catch {
    Write-Log "启动失败: $_"
    Write-Log "请检查路径是否正确: $AppPath"
  }
}

Write-Log "启动强力看门狗: $AppName (v2.0)"
Write-Log "监控路径: $AppPath"

# 初始启动
if (-not (Get-Process -Name $AppName -ErrorAction SilentlyContinue)) {
  Write-Log "初始化: App 未运行，正在启动..."
  Start-App
}

while ($true) {
  # 获取进程列表 (可能是数组)
  $Processes = Get-Process -Name $AppName -ErrorAction SilentlyContinue

  if (-not $Processes) {
    # === 情况A: 进程不存在 (崩溃/闪退) ===
    if ($CurrentFreezeCount -gt 0) { $CurrentFreezeCount = 0 } # 重置计数
    Write-Log "警告: 检测到 App 已退出！"
    Force-Kill-App # 确保清理残留
    Start-App
    Start-Sleep -Seconds 10
  }
  else {
    # === 情况B: 进程存在，检查是否卡死 ===
    $AllResponding = $true
        
    # 只要有一个进程未响应，就视为卡死
    foreach ($p in $Processes) {
      try { $p.Refresh() } catch {}
      if (-not $p.Responding) { 
        $AllResponding = $false 
        break
      }
    }

    if (-not $AllResponding) {
      $CurrentFreezeCount++
      Write-Log "警告: App未响应 (卡死) - 计数 $CurrentFreezeCount / $MaxFreezeCount"

      if ($CurrentFreezeCount -ge $MaxFreezeCount) {
        Write-Log "严重: 判定 App 永久卡死！准备重启..."
        if (Force-Kill-App) {
          Start-Sleep -Seconds 2  
          Start-App
          Start-Sleep -Seconds 15 
        }
        $CurrentFreezeCount = 0
      }
    }
    else {
      # 正常运行中
      if ($CurrentFreezeCount -gt 0) {
        Write-Log "信息: App 恢复响应"
        $CurrentFreezeCount = 0
      }
    }
  }

  Start-Sleep -Seconds $CheckInterval
}
