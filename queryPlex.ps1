param
(
	[Parameter(ParameterSetName='ByPlexID', Mandatory=$true,ValueFromPipeline=$true)]$PlexID,
    [Parameter(ParameterSetName='ByFileName', Mandatory=$true,ValueFromPipeline=$true)]$FileSearchText,
    [Parameter(ParameterSetName='ByMovieDBID', Mandatory=$true,ValueFromPipeline=$true)]$MovieDBID
)

if((test-path .\config.ps1) -eq $false){
    Write-Error "Config.ps1 missing"
    exit
}else{
    . .\config.ps1
}

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
    return [xml](Invoke-WebRequest -Uri "$URI").content
}

function getLibraryKey($libraries,$type){
    return ($libraries | ? {$_.type -eq $type}).key
}

function getImdbID($movieKey){
    $matched=(apiquery "$movieKey").mediaContainer.Video.guid -match "//([0-9]*)"
    $result=Invoke-WebRequest -uri "https://api.themoviedb.org/3/movie/$($matches[1])?api_key=$mdbAPIKey&language=en"
    start-sleep -Milliseconds 200
    return ($result.Content | ConvertFrom-Json).imdb_id
}

$TOKEN=getPlexToken
$libraryList=(apiQuery "/library/sections").MediaContainer.Directory
$movieKey=getLibraryKey $libraryList "movie"
$allPlexMovies=(apiQuery "/library/sections/$movieKey/all").MediaContainer
$found=$false
if($PsCmdlet.ParameterSetName -eq "ByPlexID"){
    $allPlexMovies=(apiQuery "/library/sections/$movieKey/all").MediaContainer
    foreach($video in $allPlexMovies.video){
        if($video.ratingKey -eq $PlexID){
            $found=$true
            Write-Output $video
            break
        }
    }
}elseif($PsCmdlet.ParameterSetName -eq "ByFileName"){
    $found=$false
    foreach($video in $allPlexMovies.video){
        $key=$video.key
        $movieDetails=(apiQuery $key).MediaContainer
        $plexFileName=$movieDetails.Video.Media.Part.file
        if($plexFileName -match $FileSearchText){
            $found=$true
            Write-Output "File Match: $plexFileName"
            Write-Output "Plex Title: $($movieDetails.video.title)`n"
        }
    }
}elseif($PsCmdlet.ParameterSetName -eq "ByMovieDBID"){
    foreach($video in $allPlexMovies.video){
        $movieKey=$video.key
        $matched=(apiquery "$movieKey").mediaContainer.Video.guid -match "//([0-9]*)"
        if($matches[1] -eq $MovieDBID){
            $found=$true
            Write-Output $video.title
        }
    }
}
if($found -eq $false){
    Write-Output "$PlexID Not Found in Plex Movie Library"
}