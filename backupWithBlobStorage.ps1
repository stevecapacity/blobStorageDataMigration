$tempDataPath = "C:\ProgramData\IntuneMigration\TempData"
if(!(Test-Path $tempDataPath))
{
	mkdir $tempDataPath
}

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

$containerName = $user
New-AzStorageContainer -Context $context -Name $containerName

$locations = @(
	"AppData\Local"
	"AppData\Roaming"
	"Documents"
	"Desktop"
	"Pictures"
	"Downloads"
)

#loop through each directory in locations array
foreach($location in $locations)
{
	$localPath = "C:\Users\$($user)\$($location)"
	$blobName = $location
	if($blobName -match '[^a-zA-Z0-9]')
	{
        Write-Host "$($blobName) contains a special character... proceding with path A"
        $blobName = $blobName -replace '\\'
        Write-Host "Removed special character from $($blobName)"
        $publicPath = "C:\Users\Public\Temp\$($blobName)"
        if(!(Test-Path $publicPath))
        {
            mkdir $publicPath
        }
        robocopy $localPath $publicPath /E /ZB /R:0 /W:0 /V /XJ /FFT
        Write-Host "Coppied data from $($localPath) to $($publicPath)"
        $tempAppPath = "$($tempDataPath)\$($blobName)"
        if(!(Test-Path $tempAppPath))
        {
            mkdir $tempAppPath
        }
        Write-Host "Created $($tempAppPath) for $($publicPath)"
        Compress-Archive -Path $publicPath -DestinationPath "$($tempAppPath)\$($blobName)" -Force
        Write-Host "Compressed $($publicPath) to $($tempAppPath)\$($blobName).zip"
        Set-AzStorageBlobContent -File "$($tempAppPath)\$($blobName).zip" -Container $containerName -Blob "$($blobName).zip" -Context $context -Force
	}
    else
    {
        $tempPath = "$($tempDataPath)\$($blobName)"
        Write-Host "$($blobName) does NOT contain a special character... proceding with path B"
        if(!(Test-Path $tempPath))
        {
            mkdir $tempPath
        }
        Write-Host "Created $($tempPath)"
        Compress-Archive -Path $localPath -DestinationPath "$($tempPath)\$($blobName)" -Force
        Write-Host "Compressed $($localPath) to $($tempPath)"
        Set-AzStorageBlobContent -File "$($tempPath)\$($blobName).zip" -Container $containerName -Blob "$($blobName).zip" -Context $context -Force
        #Write-Host "Compressed $($location) to blob storage"
    }
}


#Remove-Item -Path $tempDataPath -Recurse -Force



