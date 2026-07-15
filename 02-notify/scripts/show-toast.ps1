# Windows toast helper for notify-on-stop.sh.
# No modules required (avoids BurntToast, whose install is often blocked by
# execution policy on managed devices). Uses the WinRT toast API available in
# Windows PowerShell 5.1; falls back to a tray balloon tip if that fails.
#
# STATUS: UNTESTED — written on macOS, pending verification by the first
# Windows user. If it misbehaves, please report what you see.
#
# Known desk-check risk: if the PowerShell AppId below has no Start-Menu
# shortcut registered (some managed Windows images strip these), .Show() can
# silently no-op WITHOUT throwing — so the balloon fallback won't trigger.
# If your manual test shows nothing and no error, that's the likely cause;
# report it and we'll switch the default to the balloon path.
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File show-toast.ps1 -Title "Claude Code" -Message "Done"

param(
  [string]$Title = "Claude Code",
  [string]$Message = "Claude finished"
)

try {
  [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
  [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

  $xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
    [Windows.UI.Notifications.ToastTemplateType]::ToastText02)
  $nodes = $xml.GetElementsByTagName("text")
  $nodes.Item(0).AppendChild($xml.CreateTextNode($Title)) | Out-Null
  $nodes.Item(1).AppendChild($xml.CreateTextNode($Message)) | Out-Null

  $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
  # AppId of Windows PowerShell itself — toasts must be attributed to an
  # installed app, and PowerShell is always present.
  $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
  [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
} catch {
  try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $ni = New-Object System.Windows.Forms.NotifyIcon
    $ni.Icon = [System.Drawing.SystemIcons]::Information
    $ni.Visible = $true
    $ni.ShowBalloonTip(5000, $Title, $Message, [System.Windows.Forms.ToolTipIcon]::Info)
    Start-Sleep -Seconds 6
    $ni.Dispose()
  } catch { }
}
