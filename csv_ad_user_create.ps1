# Bulk AD User Creation from CSV

# Use example: .\csv_ad_user_create.ps1 -CsvFile "C:\Temp\Employees.csv" -OU "OU=Employees,DC=company,DC=local"
param (
    [Parameter(Mandatory=$true)]
    [string]$CsvFile,                     # Path to CSV file
    [string]$OU = "OU=Users,DC=company,DC=local",
    [string]$Domain = "creme.local"
)

Import-Module ActiveDirectory

# Import CSV
$Users = Import-Csv $CsvFile

foreach ($user in $Users) {
    $FirstName = $user.FirstName
    $LastName = $user.LastName

    # Build base username
    $baseSam = ($FirstName.Substring(0,1) + $LastName).ToLower()
    $sam = $baseSam
    $counter = 1

    while (Get-ADUser -Filter { SamAccountName -eq $sam }) {
        $sam = "$baseSam$counter"
        $counter++
    }

    # Generate random password
    $Password = -join ((33..126) | Get-Random -Count 12 | % {[char]$_})
    $SecurePass = ConvertTo-SecureString $Password -AsPlainText -Force

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

    Write-Host "✅ Created user: $sam@$Domain with temporary password: $Password" -ForegroundColor Green
}