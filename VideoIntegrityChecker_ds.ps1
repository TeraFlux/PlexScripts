#==========================================
#VideoIntegrityChecker_ds.ps1
#
#This file contains helper functions validating the integrity of video files!
#==========================================
. .\config.ps1

$extensionsToTest = @(".avi",".mkv",".mp4")
$ffmpeg = "C:\Utils\ffmpeg\ffmpeg.exe"
$ffprobe = "C:\Utils\ffmpeg\ffprobe.exe"

if(! (Test-Path $screenShotDir))
{
	$out = mkdir $screenShotDir
}

#==========================================
#Validate-VideosInFolder
#Runs Validate-VideoFile on all supported video files under a specified folder
#==========================================
Function Validate-VideosInFolder
{
	#Parameters
	param
	(
		[Parameter(Position=0, Mandatory=$true)]$VideoFolderPath,
		[Parameter(Position=1, Mandatory=$false)][bool]$IntegrityCheck = $false,
		[Parameter(Position=2, Mandatory=$false)][int]$MinimumBitRate = (2 * 1024 * 1024) #2/mb per second
	)
	$Started = Get-Date
	$results = @()
	$errorlist = @()
	$i = 0
	
	#Validate folder exists
	Write-Progress -Activity "Validate-VideosInFolder started on $Started" -Status "Validating specified video folder" -CurrentOperation "Testing path $VideoFolderPath" -PercentComplete 0 -SecondsRemaining ((Get-Date) - $Started).TotalSeconds
	if(! (Test-Path -LiteralPath $VideoFolderPath))
	{
		throw "Cannot find folder $VideoFolderPath"
	}
	
	#Find all supported video files
	Write-Progress -Activity "Validate-VideosInFolder started on $Started" -Status "Gathering suppoorted video files" -CurrentOperation "Get-ChildItem on $VideoFolderPath" -PercentComplete 0 -SecondsRemaining ((Get-Date) - $Started).TotalSeconds
	$supportedVideoFiles = Get-ChildItem -LiteralPath $VideoFolderPath -Recurse -File | where {$_.extension -in $extensionsToTest}
	if(($supportedVideoFiles.count -gt 0) -eq $false)
	{
		throw "No supported video files found in $VideoFilePath"
	}
	
	#Loop through each file and run Validate-VideoFile
	foreach($videoFile in $supportedVideoFiles)
	{
		$i++
		Write-Progress -Activity "Validate-VideosInFolder started on $Started" -Status "Validate-VideoFile $i / $($supportedVideoFiles.Count)" -CurrentOperation "Validate-VideoFile -VideoFilePath $($videoFile.Name) -IntegrityCheck $IntegrityCheck -MinimumBitRate $MinimumBitRate" -PercentComplete 0 -SecondsRemaining ((Get-Date) - $Started).TotalSeconds
		try
		{
			$results += Validate-VideoFile -VideoFilePath $videoFile.FullName -IntegrityCheck $IntegrityCheck -MinimumBitRate $MinimumBitRate
		}
		catch
		{
			$errorlist += $_
			write-host "Error encountered in $($videoFile.name): $_"
		}
	}
	
	Write-Host "Finished in $((Get-Date) - $Started)"
	
	return $results
}

#==========================================
#Validate-VideoFile
#Validates the specified video file is HD, contains valid video, and runs an optional integrity check
#==========================================
Function Validate-VideoFile
{
	#Parameters
	param
	(
		[Parameter(Position=0, Mandatory=$true)]$VideoFilePath,
		[Parameter(Position=1, Mandatory=$false)][bool]$IntegrityCheck = $false,
		[Parameter(Position=2, Mandatory=$false)][int]$MinimumBitRate = (2 * 1024 * 1024) #2/mb per second
	)
	
	#Validate file exists
	if(! (Test-Path $VideoFilePath))
	{
		#First, attempt to escape the path.
		$VideoFilePath2 = [Management.Automation.WildcardPattern]::Escape($VideoFilePath)
		if(! (Test-Path $VideoFilePath2))
		{
			throw "Cannot find file $VideoFilePath"
		}
		else
		{
			$VideoFilePath = $VideoFilePath2
		}
	}
	
	#Gather file information and metadata
	$videoFileItem = Get-Item $VideoFilePath
	
	$shell = New-Object -COMObject Shell.Application
	$videoFolder = $videoFileItem.directoryname
	$videoFileName = $videoFileItem.name
	$shellFolder = $shell.Namespace($videoFolder)
	$shellFile = $shellFolder.ParseName($videoFileName)
	
	$size = $videoFileItem.Length
	$length = $shellFolder.GetDetailsOf($shellFile, 27)
	$bitRate = $shellFolder.GetDetailsOf($shellFile, 28)
	$dataRate = $shellFolder.GetDetailsOf($shellFile, 305)
	$frameHeight = $shellFolder.GetDetailsOf($shellFile, 306)
	$frameRate = $shellFolder.GetDetailsOf($shellFile, 307)
	$frameWidth = $shellFolder.GetDetailsOf($shellFile, 308)
	$totalBitRate = $shellFolder.GetDetailsOf($shellFile, 310)
	
	#Calculate timespans of movie
	$epochDate = "00:00:00" | get-date
	$videoLengthDate = $length | get-date
	$videoLengthTimeSpan = $videoLengthDate - $epochDate
	$firstThirdTimespan = new-timespan -seconds (($videoLengthTimeSpan.totalseconds) / 3)
	$firstThirdLength = "{0:c}" -f $firstThirdTimespan
	$secondThirdTimespan = new-timespan -seconds (($videoLengthTimeSpan.totalseconds * 2) / 3)
	$secondThirdLength = "{0:c}" -f $secondThirdTimespan
	
	#Take 2 screenshots, 1/3rd and 2/3rds of the way through the movie
	$screenShotFile = (Join-Path $screenShotDir $videoFileItem.Name).replace("%","") + ".jpg"
	$screenShotFile2 = (Join-Path $screenShotDir $videoFileItem.Name).replace("%","") + "2.jpg"
	
	#ffmpeg will freeze if it attempts to overwrite and existing file. Delete it ahead of time.
	if(Test-Path -LiteralPath $screenShotFile)
	{
		Remove-Item  -LiteralPath $screenShotFile -Force
	}
	if(Test-Path -LiteralPath $screenShotFile2)
	{
		Remove-Item  -LiteralPath $screenShotFile2 -Force
	}
	
	$screenShotError = & $ffmpeg -v error -ss $firstThirdLength -i "$($videoFileItem.fullname)" -vframes 1 -q:v 2 $screenShotFile 2>&1
	$out = & $ffmpeg -v error -ss $secondThirdLength -i "$($videoFileItem.fullname)" -vframes 1 -q:v 2 $screenShotFile2 2>&1
	
	#Compare the screenshots to make sure the video is actually changing
	$hash1 = Get-FileHash -LiteralPath $screenShotFile
	$hash2 = Get-FileHash -LiteralPath $screenShotFile2
	
	#Clean up second screenshot
	Remove-Item  -LiteralPath $screenShotFile2 -Force
	
	$results = [PsCustomObject]@{
		Name=$videoFileItem.name;
		VideoPath=$VideoFilePath;
		ScreenShotPath=$screenShotFile;
		Width=$frameWidth;
		Height=$frameHeight;
		CalculatedBitRate=$null;
		Languages=$null;
		BitRateTest=$null;
		HDTest=$null;
		IntegrityCheck=$null;
		FFMpegReadable=$null;
		VideoTest=$null;
		LanguageTest=$null;
		Notes="";}
	
	
	#Tests
	
	#Bitrate
	$calculatedBitRate = ($size / $videoLengthTimeSpan.TotalSeconds) * 8
	$results.CalculatedBitRate = $calculatedBitRate
	$results.BitRateTest = $MinimumBitRate -gt $CalculatedBitRate
	
	#HD
	$results.HDTest = ($frameWidth -ge 1280) -and ($frameHeight -ge 720)
	
	#IntegrityCheck
	if($IntegrityCheck)
	{
		$ffmpegErrors = & $ffmpeg -v error -i $videoFileItem.fullname -map 0:1 -f null - 2>&1
		if($ffmpegErrors)
		{
			$results.IntegrityCheck = $false
			$results.Notes += $ffmpegErrors
		}
		else
		{
			$results.IntegrityCheck = $true
		}
	}
	
	#FFMpegReadable
	if($screenShotError)
	{
		$results.FFMpegReadable = $false
		$results.Notes += $screenShotError
	}
	else
	{
		$results.FFMpegReadable = $true
	}
	
	#Video
	#Very basic check - compare file hashes between 2 different screenshots. If the video is missing (or completely black), they should return the same hash.
	$results.VideoTest = $hash1.Hash -ne $hash2.Hash
	
	#Language
	$languages = & $ffprobe $videoFileItem.fullname -show_entries stream=index:stream_tags=language -select_streams a -v 0 -of compact=p=0:nk=1
	$results.Languages = $languages
	$results.LanguageTest = ($languages -join "").contains("|eng")
	
	return $results
}
