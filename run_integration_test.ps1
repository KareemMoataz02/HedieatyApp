# ================================
# Flutter Integration Test Script
# ================================

# ----------------------------
# Define Environment Variables
# ----------------------------

$androidSdkPath = "C:\Users\karee\AppData\Local\Android\Sdk\platform-tools"
$flutterPath = "C:\tools\flutter"
$projectPath = "C:\Users\karee\AndroidStudioProjects\hedieaty"
$testFile = "$projectPath\integration_test\end_to_end_test.dart"
$deviceName = "Pixel_7_Pro_API_35"
$logFile = "$projectPath\test_logs.txt"
$videoFile = "$projectPath\testRecording.mp4"
$emulatorExecutable = "C:\Users\karee\AppData\Local\Android\Sdk\emulator\emulator.exe"

# Explicitly specify flutter.bat
$flutterCommand = Join-Path $flutterPath "bin\flutter.bat"

# ----------------------------
# Helper Functions
# ----------------------------

function Log-Message {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

function Clean-Up {
    param ([string]$Path)
    if (Test-Path $Path) {
        Remove-Item $Path -Force
        Log-Message "Removed existing file: $Path"
    }
}

function Is-EmulatorRunning {
    param ([string]$AvdName)
    $emulators = Get-Process -Name "emulator" -ErrorAction SilentlyContinue
    if ($emulators) {
        foreach ($emu in $emulators) {
            $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($emu.Id)").CommandLine
            if ($commandLine -and $commandLine -like "*-avd*$AvdName*") {
                return $true
            }
        }
    }
    return $false
}

# ----------------------------
# Start of Script
# ----------------------------

try {
    Set-Location -Path $projectPath
    Log-Message "Set working directory to $projectPath"

    Log-Message "Cleaning up previous test artifacts..."
    Clean-Up -Path $logFile
    Clean-Up -Path $videoFile

    Log-Message "Checking Flutter SDK version..."
    # Ensure you call flutter.bat and do not add extra punctuation
    $flutterVersion = & "$flutterCommand" --version
    Log-Message "Flutter version: $flutterVersion"

    Log-Message "Checking if emulator '$deviceName' is already running..."
    $isEmulatorRunning = Is-EmulatorRunning -AvdName $deviceName

    if (-not $isEmulatorRunning) {
        Log-Message "Emulator '$deviceName' not found. Starting Android emulator..."
        Start-Process -FilePath $emulatorExecutable -ArgumentList "-avd", $deviceName -NoNewWindow -PassThru | Out-Null
        Log-Message "Emulator started. Waiting for it to boot up..."
        Start-Sleep -Seconds 30
    } else {
        Log-Message "Emulator '$deviceName' is already running."
    }

    Log-Message "Verifying emulator boot status..."
    $emulatorBooted = $false
    $maxRetries = 24
    $retryCount = 0
    while (-not $emulatorBooted -and $retryCount -lt $maxRetries) {
        $bootStatus = & "$androidSdkPath\adb.exe" shell getprop sys.boot_completed 2>&1
        if ($bootStatus.Trim() -eq "1") {
            $emulatorBooted = $true
            Log-Message "Emulator boot completed."
        } else {
            Log-Message "Waiting for emulator to finish booting... ($retryCount/$maxRetries)"
            Start-Sleep -Seconds 5
            $retryCount++
        }
    }

    if (-not $emulatorBooted) {
        throw "Emulator failed to boot within the expected time."
    }

    Log-Message "Initializing Firebase dependencies..."
    # Run 'flutter pub get' correctly
    & "$flutterCommand" pub get | Out-Null
    Log-Message "Firebase dependencies initialized."

    Log-Message "Starting screen recording..."
    $recordJob = Start-Job -ScriptBlock {
        param ($adbPath)
        & "$adbPath\adb.exe" shell screenrecord /sdcard/testRecording.mp4 --size 720x1280
    } -ArgumentList $androidSdkPath

    Start-Sleep -Seconds 5

    $driverFile = "$projectPath\integration_test\driver.dart"
    if (-not (Test-Path $driverFile)) {
        throw "Test driver file not found at $driverFile"
    }

    if (-not (Test-Path $testFile)) {
        throw "Test file not found at $testFile"
    }

    Log-Message "Running integration test..."
    # Call flutter drive correctly
    $testCommand = "& '$flutterCommand' drive --driver integration_test\driver.dart --target $testFile"
    Log-Message "Executing command: $testCommand"

    # Use Invoke-Expression carefully:
    $testResult = Invoke-Expression "$flutterCommand drive --driver integration_test\driver.dart --target $testFile" 2>&1
    $testResult | Out-File -FilePath $logFile -Encoding utf8

    Log-Message "Integration test execution completed."

    Log-Message "Stopping the screen recording..."
    Stop-Job $recordJob
    Remove-Job $recordJob
    Log-Message "Screen recording stopped."

    Log-Message "Pulling screen recording from device..."
    & "$androidSdkPath\adb.exe" pull /sdcard/testRecording.mp4 $videoFile
    Log-Message "Screen recording saved to $videoFile"

    Log-Message "Checking test results..."
    $testOutput = Get-Content $logFile -ErrorAction SilentlyContinue
    if ($testOutput -match "All tests passed!") {
        Log-Message "Test passed successfully!"
    } else {
        Log-Message "Test failed. Check the log file for details."
        Log-Message "Log file: $logFile"
    }

    Log-Message "Cleaning up test artifacts on the device..."
    & "$androidSdkPath\adb.exe" shell rm /sdcard/testRecording.mp4
    Log-Message "Cleanup completed."

} catch {
    Log-Message "An error occurred: $_"
    exit 1
}

Log-Message "Test run completed successfully."
exit 0
