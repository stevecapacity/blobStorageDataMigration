# INSTALL AZ STORAGE MODULE FOR BLOB
Write-Host "Checking for NuGet Package provider and Azure Storage module..."
$nuget = Get-PackageProvider -Name NuGet


if(-not($nuget))
{
    try {
        Write-Host "Package Provider NuGet not found - installing now..."
        Install-PackageProvider -Name NuGet -Confirm:$false -Force
        Write-Host "NuGet installed"
    }
    catch {
        $message = $_
        Write-Host "Error installing NuGet: $message"
    }
} 
else 
{
    Write-Host "Package Provider NuGet already installed."
}

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

$azStorage = Get-InstalledModule -Name Az.Storage

if(-not($azStorage))
{
    try {
        Write-Host "Az.Storage module not found - installing now..."
        Install-Module -Name Az.Storage -Force
        Write-Host "Az.Storage installed."
        Import-Module Az.Storage
        Write-Host "Az.Storage imported."        
    }
    catch {
        $message = $_
        Write-Warning "Error installing AzStorage module: $message"
    }
} 
else 
{
    Write-Host "Az.Storage module already installed."
    try {
        Import-Module Az.Storage
        Write-Host "Az.Storage imported."    
    }
    catch {
        $message = $_
        Write-Warning "Error importing AzStorage module: $message"
    }
}


$activeUsername = (Get-WmiObject Win32_ComputerSystem | Select-Object username).username
$userName = $activeUsername -replace '.*\\'
$user = $userName.ToLower()

$storageAccountName = "<STORAGE ACCOUNT NAME>"
$storageAccountKey = "<STORAGE ACCOUNT KEY>"
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

#Have to backup each location as ZIP
#FIND container by username
#Download ZIP to temp location
#Expand into destination

$container = (Get-AzStorageContainer -context $context) | Where-Object {$_.Name -like "*$($user)*"}
$containerName = $container.Name

$locations = @(
	"AppData\Local"
	"AppData\Roaming"
	"Documents"
	"Desktop"
	"Pictures"
	"Downloads"
)

$tempBlobPath = "C:\ProgramData\IntuneMigration\TempData"
if(!(Test-Path $tempBlobPath))
{
	mkdir $tempBlobPath
}

foreach($location in $locations)
{
    if($location -match '[^a-zA-Z0-9]')
    {
        Write-Host "$($location) contains special character... proceding with path A"
        $blobName = $location
        $blobName = $blobName -replace '\\'
        $blob = "$($blobName).zip"
        $localPath = "C:\Users\$($userName)\$($location)"
        $blobDownload = @{
            Blob = $blob
            Container = $containerName
            Destination = $tempBlobPath
            Context = $context    
        }
        Get-AzStorageBlobContent @blobDownload | Out-Null
        $publicPath = "C:\Users\Public\Temp"
        if(!(Test-Path $publicPath))
        {
            mkdir $publicPath
        }
        Expand-Archive -Path "$($tempBlobPath)\$($blob)" -DestinationPath $publicPath -Force | Out-Null
        Write-Host "Expanded $($tempBlobPath)\$($blob) to $publicPath folder"
        $fullPublicPath = "$($publicPath)\$($blobName)"
        robocopy $fullPublicPath $localPath /E /ZB /R:0 /W:0 /V /XJ /FFT
        Write-Host "Coppied contents of $($fullPublicPath) to $($localPath)"
    }
    else 
    {
        Write-Host "$($location) DOES NOT contain a special character... proceding with path B"
        $blobName = "$($location).zip"
        $localPath = "C:\Users\$($userName)"
        $blobDownload = @{
            Blob = $blobName
            Container = $containerName
            Destination = $tempBlobPath
            Context = $context
        }
        Get-AzStorageBlobContent @blobDownload | Out-Null
        Expand-Archive -Path "$($tempBlobPath)\$($blobName)" -DestinationPath $localPath -Force | Out-Null
        Write-Host "Expanded $($tempBlobPath)\$($blob) to $localPath folder"
    }
   
    #Remove-Item -Path "$($tempBlobPath)\$($blobName)" -Force
}





