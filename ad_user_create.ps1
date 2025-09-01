# Requires RSAT / Active Directory module
# Run as a Domain Admin

# Use example: .\ad_user_create.ps1 -FirstName "John" -LastName "Doe" -OU "OU=Employees,DC=company,DC=local"

param (
    [Parameter(Mandatory=$true)]
    [string]$FirstName,

    [Parameter(Mandatory=$true)]
    [string]$LastName,

    [string]$OU = "OU=Users,DC=company,DC=local", # Target OU
    [string]$Domain = "creme.local"             # Your AD domain
)

Import-Module ActiveDirectory

# Build base username (first initial + last name, all lowercase)
$baseSam = ($FirstName.Substring(0,1) + $LastName).ToLower()

# Ensure uniqueness by appending a number if needed
$sam = $baseSam
$counter = 1
while (Get-ADUser -Filter { SamAccountName -eq $sam }) {
    $sam = "$baseSam$counter"
    $counter++
}

# Generate random password
$Password = -join ((33..126) | Get-Random -Count 12 | % {[char]$_})
$SecurePass = ConvertTo-SecureString $Password -AsPlainText -Force

# Build display name
$DisplayName = "$FirstName $LastName"

# Create AD user
New-ADUser `
    -SamAccountName $sam `
    -UserPrincipalName "$sam@$Domain" `
    -Name $DisplayName `
    -GivenName $FirstName `
    -Surname $LastName `
    -DisplayName $DisplayName `
    -Path $OU `
    -AccountPassword $SecurePass `
    -Enabled $true `
    -ChangePasswordAtLogon $true

Write-Host "`n✅ User created successfully!" -ForegroundColor Green
Write-Host "Username: $sam@$Domain"
Write-Host "Temp Password: $Password" -ForegroundColor Yellow