. .\config.ps1

$movies=gci $VideoFolderPath | ? { $_.PSIsContainer }

$movieFolders=$movies

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

$plexNames=$allPlexMovies.video.title


function deleteEmpty($folderName){
    $size=calcSizeOfFolder $folderName
    if($size -lt 500000){
        remove-item $folderName -Force
        return $true
    }
    return $false
}

foreach($myMovie in $movieFolders){
    $foundTitle=$false
    $replaceRegex="[\-\,\[\]\<\>\.\:\'\!\|\|\*\\\`"\?\/]"
    $myMovieName=$myMovie.Name -replace $replaceRegex, ""
    $myMovieName=$myMovieName -replace " \([0-9]{4}\)",""
    foreach($plexMovie in $plexNames){
        $plexMovieName=$plexMovie -replace $replaceRegex,""
        if($myMovieName -eq $plexMovieName){
            $foundTitle=$true
        }
    }
    if($foundTitle -eq $false){
        if(deleteEmpty $myMovie.FullName){
            write-host "Deleting Empty:"$myMovieName -f yellow
            write-host $myMovie.FullName -f yellow
        }
        write-host "Mine:"$myMovieName 
        write-host $myMovie.FullName 
    }
}



