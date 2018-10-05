. .\config.ps1
$extensionsToTest = @(".avi",".mkv",".mp4")
$ffmpeg = "C:\Utils\ffmpeg\ffmpeg.exe"
$ffprobe = "C:\Utils\ffmpeg\ffprobe.exe"

$supportedVideoFiles = Get-ChildItem -LiteralPath $VideoFolderPath -Recurse -File | where {$_.extension -in $extensionsToTest}
$movieResults=@()
$count=0
foreach($videoFileItem in $supportedVideoFiles){
    write-progress -Activity "Processing $($videoFileItem.name)" -PercentComplete ($count / $supportedVideoFiles.count * 100)
    $movieResult=@{}
    $languages = & $ffprobe $videoFileItem.fullname -show_entries stream=index:stream_tags=language -select_streams a -v 0 -of compact=p=0:nk=1
    $movieResults+=@{"languages"=$languages;"name"=$videoFileItem.name}
    $count++
}

$AllCultures = [System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::SpecificCultures).ThreeLetterISOLanguageName
$AllCultures = $AllCultures | select -uniq

foreach($movie in $movieResults){
    if($movie.languages.getType().BaseType.Name -eq "Array"){
        $nonEngFound=$false
        foreach($lang in $movie.languages){
            if($lang -eq ""){
                continue
            }
            if($lang -match "eng"){
                $nonEngFound=$false
                break
            }
            foreach($culture in $AllCultures){
                if($culture -match $lang) {
                    $nonEngFound=$true
                }
            }

        }
        if($nonEngFound){
            write-host $movie.languages -f cyan
            write-host $movie.name -f Yellow
        }
    }
}

