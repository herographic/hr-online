@echo off
:: Flutter Cleanup Script for Windows
:: สำหรับทำความสะอาด Flutter และคืนพื้นที่ฮาร์ดดิส

:: ตั้งค่า encoding เป็น UTF-8 เพื่อแสดงภาษาไทย
chcp 65001 > nul

:: ตั้งค่าสี
color 0A

:: แสดงหัวข้อ
echo ================================================================
echo 🧹 Flutter Cleanup Script for Windows
echo ================================================================
echo 📝 สคริปต์นี้จะทำความสะอาด Flutter และคืนพื้นที่ฮาร์ดดิส
echo ⚠️  กรุณาปิดโปรแกรม IDE ทั้งหมดก่อนดำเนินการ
echo ================================================================
echo.

:: ฟังก์ชันตรวจสอบและแสดงขนาดโฟลเดอร์
:check_folder_size
if exist "%~1" (
    echo 📁 %~2: พบ
    for /f "tokens=3" %%a in ('dir "%~1" /-c /s 2^>nul ^| findstr /c:" bytes"') do set size=%%a
    if defined size (
        echo    💾 ขนาด: %size% bytes
    )
) else (
    echo 📁 %~2: ไม่พบ
)
goto :eof

:: ฟังก์ชันลบโฟลเดอร์อย่างปลอดภัย
:safe_remove
if exist "%~1" (
    echo   🗑️ กำลังลบ: %~1
    rmdir /s /q "%~1" 2>nul
    if exist "%~1" (
        echo   ❌ ลบไม่สำเร็จ: %~1
    ) else (
        echo   ✅ ลบสำเร็จ: %~1
    )
) else (
    echo   ⚠️ ไม่พบ: %~1
)
goto :eof

:: ตรวจสอบ Flutter
echo 🔍 ตรวจสอบ Flutter...
where flutter > nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Flutter ไม่ได้ติดตั้งหรือไม่ได้ตั้งค่า PATH
    echo 💡 กรุณาติดตั้ง Flutter และตั้งค่า PATH ให้ถูกต้อง
    pause
    exit /b 1
)

:: ตรวจสอบ Dart
echo 🔍 ตรวจสอบ Dart...
where dart > nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Dart ไม่ได้ติดตั้งหรือไม่ได้ตั้งค่า PATH
    pause
    exit /b 1
)

:: หา FLUTTER_ROOT
if not defined FLUTTER_ROOT (
    for /f "tokens=*" %%i in ('where flutter 2^>nul') do (
        set "flutter_path=%%i"
        goto :found_flutter
    )
    :found_flutter
    for %%i in ("!flutter_path!") do set "FLUTTER_ROOT=%%~dpi"
    set "FLUTTER_ROOT=!FLUTTER_ROOT:~0,-5!"
)

echo 📍 Flutter SDK Path: %FLUTTER_ROOT%
echo.

:: ตรวจสอบพื้นที่ก่อนทำความสะอาด
echo 📊 ตรวจสอบพื้นที่ก่อนทำความสะอาด:
echo ================================
call :check_folder_size "%FLUTTER_ROOT%" "Flutter SDK"
call :check_folder_size "%FLUTTER_ROOT%\bin\cache" "Flutter Cache"
call :check_folder_size "%LOCALAPPDATA%\Pub\Cache" "Pub Cache"
call :check_folder_size "%USERPROFILE%\.gradle" "Gradle Cache"
call :check_folder_size "%USERPROFILE%\.android" "Android Cache"
call :check_folder_size "%APPDATA%\Code\User\workspaceStorage" "VS Code Workspace"
echo.

:: ถามการยืนยัน
echo 🤔 คุณต้องการดำเนินการทำความสะอาดหรือไม่?
echo    [Y] ใช่, ดำเนินการ
echo    [N] ไม่, ยกเลิก
echo.
set /p "confirm=เลือก (Y/N): "
if /i not "%confirm%"=="y" (
    echo ❌ ยกเลิกการทำความสะอาด
    pause
    exit /b 0
)

echo.
echo 🚀 เริ่มทำความสะอาด...
echo ================================

:: 1. ทำความสะอาด Flutter Cache
echo.
echo 1️⃣ ทำความสะอาด Flutter Cache
echo ================================
echo 🔄 รันคำสั่ง: flutter cache clean
flutter cache clean

call :safe_remove "%FLUTTER_ROOT%\bin\cache\artifacts" "Flutter Artifacts"
call :safe_remove "%FLUTTER_ROOT%\bin\cache\dart-sdk" "Dart SDK Cache"
call :safe_remove "%FLUTTER_ROOT%\bin\cache\engine" "Flutter Engine Cache"
call :safe_remove "%FLUTTER_ROOT%\bin\cache\gradle" "Flutter Gradle Cache"

:: 2. ทำความสะอาด Dart Pub Cache
echo.
echo 2️⃣ ทำความสะอาด Dart Pub Cache
echo ================================
echo 🔄 รันคำสั่ง: dart pub cache clean
dart pub cache clean

call :safe_remove "%LOCALAPPDATA%\Pub\Cache" "Pub Cache (Local)"
call :safe_remove "%APPDATA%\Pub\Cache" "Pub Cache (Roaming)"

:: 3. ทำความสะอาด Gradle Cache
echo.
echo 3️⃣ ทำความสะอาด Gradle Cache
echo ================================
call :safe_remove "%USERPROFILE%\.gradle\caches" "Gradle Caches"
call :safe_remove "%USERPROFILE%\.gradle\wrapper" "Gradle Wrapper"
call :safe_remove "%USERPROFILE%\.gradle\daemon" "Gradle Daemon"

:: 4. ทำความสะอาด A