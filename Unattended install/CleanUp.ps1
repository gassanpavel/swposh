Write-Host "Run cleanup" -ForegroundColor Green

foreach ($item in (Get-ChildItem $PSScriptRoot)){
    if ($item.name -notlike "StarWind HCA network test.ps1"){
        Write-Host "Delete " $item.name
        Remove-Item -LiteralPath $item.name -Recurse -Force
    }
}