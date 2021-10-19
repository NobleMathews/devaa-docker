param ($giturl,$testName)

# Remove-Item -LiteralPath "testRepo" -Force -Recurse
git clone $giturl testRepo

$repo = $(Resolve-Path -Path testRepo).Path
$java_home = "C:\Program Files\Java\jre1.8.0_301"
# $env:Path = "C:\Program Files\Java\jre1.8.0_301\bin;"+$env:Path
$env:JAVA_HOME = $java_home

$external_variables = Get-Content -raw -Path variables.txt | ConvertFrom-StringData
$projectName = (Get-Item $repo).Name
$SDK_LOCATION = $external_variables.'SDK_LOCATION' -replace '[\\]','\$&'
$NDK_LOCATION = $external_variables.'NDK_LOCATION' -replace '[\\]','\$&'
# [Regex]::Escape($external_variables.'NDK_LOCATION')
function ConvertTo-StringData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [HashTable[]]$HashTable
    )
    process {
        foreach ($item in $HashTable) {
            foreach ($entry in $item.GetEnumerator()) {
                "{0}={1}" -f $entry.Key, $entry.Value
            }
        }
    }
}
function updateLocalProperties{
    if(!(Test-Path $external_variables.'SDK_LOCATION') -or  !(Test-Path ($external_variables.'SDK_LOCATION'+"\ndk"))){
        Write-Host "Please update the SDK and NDK location with a valid path"
    }
    $LocalProps.'sdk.dir' = $SDK_LOCATION
    $LocalProps.'ndk.dir' = $NDK_LOCATION
    ConvertTo-StringData $LocalProps | Set-Content $local_properties.FullName
}

function updateGlobalProperties{
    $LocalProps.Remove("org.gradle.java.home")
    ConvertTo-StringData $LocalProps | Set-Content $gradle_properties.FullName
}
# Set-StrictMode -Version Latest
# $ErrorActionPreference = "Stop"
# $PSDefaultParameterValues['*:ErrorAction']='Stop'
$data = @('codeql')
$data.ForEach({
    if ($null -eq (Get-Command $PSItem -ErrorAction SilentlyContinue)) 
    { 
       Write-Host "Unable to find $PSItem in your PATH"
       exit 1
    }
})
$local_properties = Get-ChildItem $repo | Where-Object { ($_.PSIsContainer -ne $true) -and ($_.Name -eq "local.properties")}  
$gradle_properties = Get-ChildItem $repo | Where-Object { ($_.PSIsContainer -ne $true) -and ($_.Name -eq "gradle.properties")}  

# | Select-Object FullName
if($null -eq $local_properties){
    Write-Host "Rewriting local.properties"
    Set-Content "$repo\\local.properties" "sdk.dir=$SDK_LOCATION"
    Add-Content "$repo\\local.properties" "ndk.dir=$NDK_LOCATION"
    # updateLocalProperties
}
else{
    $LocalProps = convertfrom-stringdata (get-content $local_properties.FullName -Raw)
    if(!(Test-Path $LocalProps.'sdk.dir') -or  !(Test-Path $LocalProps.'ndk.dir')){
        updateLocalProperties
    }
}

if(!($null -eq $gradle_properties)){
    Write-Host "Rewriting gradle.properties"
    $LocalProps = convertfrom-stringdata (get-content $gradle_properties.FullName -Raw)
    updateGlobalProperties
}

Push-Location $repo
# Start Scan
codeql database create $projectName --language=java
# --overwrite
# Start Analysis
codeql database analyze --format=sarif-latest --output=output.json --search-path=C:\Users\elbon\Documents\GitHub\Devaa++\vscode-codeql-starter $projectName "C:\Users\elbon\Documents\GitHub\Devaa++\vscode-codeql-starter\ql\java\ql\test\query-tests\security\CWE-2203\$($testName).ql"
#  --rerun
# Fetch JSON and [parse grammar]
$jsonObj = Get-Content -raw -Path output.json | ConvertFrom-Json
$jsonObj.runs.ForEach({
    $_.results.ForEach({
        $_.locations.ForEach({ 
            "$($_.physicalLocation.artifactLocation.uri):$($_.physicalLocation.region.startLine):$($_.physicalLocation.region.startColumn):$($_.physicalLocation.region.endColumn)"
        })
    })
})
# activity class - bqrs file -> json - get source and sinks -> running test cases
#  eg. "com.irccloud.android", "com.irccloud.android.activity.SAMLAuthActivity"
#  run on https://github.com/shivasurya/nextcloud-android.git

# C:\Users\elbon\Documents\GitHub\devaa\examples

Pop-Location