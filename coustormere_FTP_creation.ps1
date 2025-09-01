# FTP User Manager Script (Create + Cleanup) with Secure Logging
# Run as Administrator on Windows Server with IIS FTP installed


# Examples on how to run the script:
# Create: .\coustormer_FTP_creation.ps1 -Supporter "DOMAIN\jdoe" (DOMAIN\jdoe referes to how the supporters credentials is set up in AD)
# Clean: .\coustormer_FTP_creation.ps1 -CleanupUser "[RANDOM CREATED USER]"

param (
    [string]$BasePath = "F:\Kunde_FTP",             # Where user folders live on the server it self
    [string]$FtpSiteName = "FTP_Kunder",            # IIS FTP site name if we have more then 1
    [string]$FtpDomain = "ftp.creme.local",  # For the generated link the Domain where our FTP server is servered thru DNS
    [string]$Supporter = "",                       # AD username of supporter (e.g. "DOMAIN\jdoe")
    [string]$CleanupUser = ""                      # If set, script will delete this user + folder (used for the cleanup of the coustormer user)
)

# --------------------------
# Setup secure log file
# --------------------------
$LogPath = "C:\FTP_Logs"
$LogFile = Join-Path $LogPath "FTP-Provision.log"

if (-not (Test-Path $LogFile)) {
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
    New-Item -ItemType File -Path $LogFile -Force | Out-Null

    # Lock down permissions to Administrators only
    icacls $LogFile /inheritance:r /grant "Administrators:(F)" | Out-Null
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$timestamp] $Message"
}

# --------------------------
# CLEANUP MODE
# --------------------------
if ($CleanupUser) {
    Write-Host "Cleaning up FTP user $CleanupUser..." -ForegroundColor Yellow

    $userFolder = Join-Path $BasePath $CleanupUser

    # Delete Windows user
    try {
        net user $CleanupUser /delete
        Write-Host "Deleted user $CleanupUser" -ForegroundColor Green
    } catch {
        Write-Host "User $CleanupUser not found or already deleted." -ForegroundColor Red
    }

    # Delete user folder
    if (Test-Path $userFolder) {
        Remove-Item $userFolder -Recurse -Force
        Write-Host "Deleted folder $userFolder" -ForegroundColor Green
    } else {
        Write-Host "Folder $userFolder not found." -ForegroundColor Red
    }

    # Remove IIS Virtual Directory if it exists
    Import-Module WebAdministration
    $vdPath = "IIS:\Sites\$FtpSiteName\$CleanupUser"
    if (Test-Path $vdPath) {
        Remove-WebVirtualDirectory -Site $FtpSiteName -Name $CleanupUser -Confirm:$false
        Write-Host "Removed IIS Virtual Directory $CleanupUser" -ForegroundColor Green
    }

    # Log the cleanup
    Write-Log "Cleaned $CleanupUser (by supporter $env:USERNAME)"

    exit
}

# --------------------------
# CREATE MODE
# --------------------------

if (-not $Supporter) {
    $Supporter = Read-Host "Enter your AD username (e.g. DOMAIN\jdoe)"
}

# Generate random username + password
$randUser = "ftpuser" + -join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_})
$randPass = -join ((33..126) | Get-Random -Count 12 | % {[char]$_})

# Create user folder
$userFolder = Join-Path $BasePath $randUser
New-Item -ItemType Directory -Path $userFolder -Force | Out-Null

# Create local Windows user for FTP
Write-Host "Creating FTP user $randUser..."
net user $randUser $randPass /add /y

# Set NTFS permissions
icacls $userFolder /inheritance:r | Out-Null
icacls $userFolder /grant "$randUser:(OI)(CI)F" /T | Out-Null
icacls $userFolder /grant "$Supporter:(OI)(CI)F" /T | Out-Null

# Link folder to FTP site
Import-Module WebAdministration
$vdPath = "IIS:\Sites\$FtpSiteName\$randUser"
if (-Not (Test-Path $vdPath)) {
    New-WebVirtualDirectory -Site $FtpSiteName -Name $randUser -PhysicalPath $userFolder
}

# Generate FTP link
$ftpLink = "ftp://$randUser`:$randPass@$FtpDomain"

Write-Host "`n✅ Customer FTP Link (send this to customer):"
Write-Host $ftpLink -ForegroundColor Green

Write-Host "`nℹ️ Supporter Access:"
Write-Host "Folder: $userFolder" -ForegroundColor Cyan
Write-Host "Supporter user '$Supporter' has full access." -ForegroundColor Cyan

# Log the creation
Write-Log "Created $randUser (Supporter: $Supporter, Folder: $userFolder)"