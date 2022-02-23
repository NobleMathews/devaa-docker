param ($giturls,$testName,$hash)
$arrayG = $giturls.Split(",") 
# Remove-Item -LiteralPath "testRepo" -Force -Recurse
for ($i=0; $i -lt $arrayG.length; $i++) {
    if($i -eq 0){
        git clone $arrayG[$i].Trim() testRepo
        if($null -ne $hash){
            Push-Location ./testRepo
            git checkout $hash
            Pop-Location
        }
    }
	else{
        git clone $arrayG[$i].Trim()
    }
}

if ($IsWindows -or $ENV:OS) {
    $search_path = "C:\Users\elbon\Documents\GitHub\Devaa++\vscode-codeql-starter\ql\java"
    $tests_folder= "$search_path\ql\test\query-tests\security\tests"
    $external_variables = Get-Content -raw -Path ./win_variables.txt | ConvertFrom-StringData
} else {
    $search_path = "/usr/local/codeql-home/codeql-repo/java"
    $tests_folder= "$search_path/ql/test/query-tests/security/Devaa/tests"
    $external_variables = Get-Content -raw -Path ./variables.txt | ConvertFrom-StringData
}

$repo = $(Resolve-Path -Path testRepo).Path
# $java_home = "C:\Program Files\Java\jre1.8.0_301"
# # $env:Path = "C:\Program Files\Java\jre1.8.0_301\bin;"+$env:Path
# $env:JAVA_HOME = $java_home

$projectName = (Get-Item $repo).Name
$SDK_LOCATION = $external_variables.'SDK_LOCATION'
$NDK_LOCATION = $external_variables.'NDK_LOCATION'
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
    # Reading file as a single string:
    $sRawString = Get-Content $local_properties.FullName | Out-String

    # The following line of code makes no sense at first glance 
    # but it's only because the first '\\' is a regex pattern and the second isn't. )
    $sStringToConvert = $sRawString -replace '\\', '\\'
    $LocalProps = convertfrom-stringdata $sStringToConvert
    # (get-content $local_properties.FullName -Raw)
    # if(!(Test-Path $LocalProps.'sdk.dir') -or  !(Test-Path $LocalProps.'ndk.dir')){
    updateLocalProperties
    # }
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
codeql database analyze --format=sarif-latest --output=output.json --search-path=$search_path $projectName "$tests_folder/$($testName).ql" 
# --rerun
# Fetch JSON and [parse grammar]
$jsonObj = Get-Content -raw -Path output.json | ConvertFrom-Json
$classNames = New-Object System.Collections.Generic.List[System.Object]
$jsonObj.runs.ForEach({
    $_.results.ForEach({
        $_.locations.ForEach({ 
            $classNames.Add("$($_.physicalLocation.artifactLocation.uri)".Replace("/",".").Replace("app.src.main.java.","").Replace(".java",""))
            # $packageNameParts = $className.Split(".")
            # $packageName = "$($packageNameParts[0]).$($packageNameParts[1]).$($packageNameParts[2])"
            # Write-Output $packageName
            # Write-Output $className
        })
    })
})
# activity class - bqrs file -> json - get source and sinks -> running test cases
#  eg. "com.irccloud.android", "com.irccloud.android.activity.SAMLAuthActivity"
#  run on https://github.com/shivasurya/nextcloud-android.git
# C:\Users\elbon\Documents\GitHub\devaa\examples

Import-Module "$search_path/ql/test/query-tests/security/Devaa/exploit_engine/runner.psm1"
Import-Module "$search_path/ql/test/query-tests/security/Devaa/exploit_engine/runner2.psm1"
# attackXSS($classNames)
attackSpecific($classNames)

# $data = @(
#     [pscustomobject]@{xssPayload="https://zoho.com/";domain="https://zoho.com/"}
#     [pscustomobject]@{xssPayload="https:/jbdaksndf.com/dskjhbakjhsfh";domain="twitter.com"}
# )
# # $data | ForEach-Object {$_.xssPayload}
# $payloadData = $data[0].xssPayload
# $domain = $data[0].domain

Pop-Location