# Script para encontrar e executar gsutil
$possiblePaths = @(
    "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd",
    "${env:ProgramFiles(x86)}\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd",
    "$env:ProgramFiles\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd",
    "$env:USERPROFILE\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd"
)

$gsutilPath = $null
foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $gsutilPath = $path
        Write-Host "Encontrado gsutil em: $gsutilPath"
        break
    }
}

if ($gsutilPath) {
    Write-Host "Aplicando configuração CORS..."
    & $gsutilPath cors set cors.json gs://sincroapp-529cc.firebasestorage.app
    Write-Host "CORS aplicado com sucesso!"
} else {
    Write-Host "ERRO: gsutil não encontrado. Por favor, verifique a instalação do Google Cloud SDK."
    Write-Host "Tente procurar manualmente em: C:\Program Files (x86)\Google\Cloud SDK\"
}
