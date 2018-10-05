
param
(
	[Parameter(Position=0, Mandatory=$true,ValueFromPipeline=$true)]$SearchTerm
)
. .\config.ps1

function getPlexToken(){
    $BB = [System.Text.Encoding]::UTF8.GetBytes("$username`:$password")
    $EncodedPassword = [System.Convert]::ToBase64String($BB)
    $headers = @{}
    $headers.Add("Authorization","Basic $($EncodedPassword)") | out-null
    $headers.Add("X-Plex-Client-Identifier","TESTSCRIPTV1") | Out-Null
    $headers.Add("X-Plex-Product","Test script") | Out-Null
    $headers.Add("X-Plex-Version","V1") | Out-Null
    [xml]$res = Invoke-RestMethod -Headers:$headers -Method Post -Uri:$PLEXTVURL
    return $res.user.authenticationtoken
}

function apiQuery($endpoint){
    $URI= "$personalPlexURL$endpoint`?X-Plex-Token=$TOKEN"
    #write-host "$URI"
    return [xml](Invoke-WebRequest -Uri "$URI").content
}

function getLibraryKey($libraries,$type){
    return ($libraries | ? {$_.type -eq $type}).key
}

function calcSizeOfFolder($folder){
    $size=0
    $items=gci -literalPath $folder -Recurse
    $items | % {$size+=$_.Length}
    return $size
}

$TOKEN=getPlexToken
$libraryList=(apiQuery "/library/sections").MediaContainer.Directory
$movieKey=getLibraryKey $libraryList "movie"
$allPlexMovies=(apiQuery "/library/sections/$movieKey/all").MediaContainer
foreach($video in $allPlexMovies.video){
    $key=$video.key
    $movieDetails=(apiQuery $key).MediaContainer
    $plexFileName=$movieDetails.Video.Media.Part.file
    if($plexFileName -match $SearchTerm){
        write-host "FileMatched: $plexFileName"
        write-host "Plex Title: $($movieDetails.video.title)"
    }
}

