. .\config.ps1

$pagesToSearch=10

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
$MyIMDBIDs=@()
$count=1
write-host "Compiling list of my IMDB id's"
foreach($movie in $allPlexMovies.video){
    if($count % 50 -eq 0){
        write-host "$count / $($allPlexMovies.video.Length)"
    }
    $MyIMDBIDs+=getImdbID $movie.key
    $count++
}

for($page=1;$page -lt $pagesToSearch;$page++){
    $result=invoke-webrequest -Uri "https://www.imdb.com/search/title?my_ratings=restrict&title_type=feature&sort=num_votes,desc&page=$page&ref_=adv_nxt"
    $classes=$result.ParsedHtml.body.getElementsByClassName("loadlate")
    foreach($class in $classes){
        $movieName=$class.alt
        $matched= $class.outerHTML -match "(tt[0-9]{7})"
        $imdbID=$matches[0]
        if($myIMDBIDs -notcontains $imdbID){
            write-host "$movieName - $imdbID" -f Yellow
        }
   }
}
