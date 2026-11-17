$ErrorActionPreference = 'Stop'
$msiPath = Join-Path $env:TEMP ("nodejs-lts-{0}.msi" -f [guid]::NewGuid().ToString('N'))

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $distIndex = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' -TimeoutSec 30

    $architecture = if ($env:PROCESSOR_ARCHITEW6432) {
        $env:PROCESSOR_ARCHITEW6432
    } else {
        $env:PROCESSOR_ARCHITECTURE
    }

    switch ($architecture.ToUpperInvariant()) {
        'AMD64' { $msiArchitecture = 'x64'; $metadataAsset = 'win-x64-msi' }
        'ARM64' { $msiArchitecture = 'arm64'; $metadataAsset = 'win-arm64-msi' }
        'X86' { $msiArchitecture = 'x86'; $metadataAsset = 'win-x86-msi' }
        default { throw "Arquitectura de Windows no compatible para instalar Node.js: $architecture" }
    }

    $release = $distIndex |
        Where-Object { $_.lts -and $_.files -contains $metadataAsset } |
        Select-Object -First 1

    if (-not $release) {
        throw "No se encontro una version LTS de Node.js con instalador para $architecture."
    }

    $msiName = "node-$($release.version)-$msiArchitecture.msi"
    $downloadUrl = "https://nodejs.org/dist/$($release.version)/$msiName"
    Write-Host "Descargando Node.js $($release.version) ($architecture) desde nodejs.org..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $msiPath -UseBasicParsing -TimeoutSec 180

    if ((Get-Item -LiteralPath $msiPath).Length -lt 1MB) {
        throw 'El instalador descargado esta incompleto o no es valido.'
    }

    $signature = Get-AuthenticodeSignature -FilePath $msiPath
    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
        throw "La firma digital del instalador no es valida (estado: $($signature.Status)). No se ejecutara."
    }

    if ($signature.SignerCertificate.Subject -notmatch 'OpenJS Foundation') {
        throw "El instalador no esta firmado por OpenJS Foundation. No se ejecutara. Editor encontrado: $($signature.SignerCertificate.Subject)"
    }

    Write-Host "Firma digital valida. Iniciando el instalador de Node.js..."
    Write-Host 'Si Windows solicita confirmacion de permisos, elija Si para instalar Node.js.'
    $installer = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\msiexec.exe') `
        -ArgumentList @('/i', "`"$msiPath`"", '/passive', '/norestart') `
        -Wait -PassThru

    if ($installer.ExitCode -notin @(0, 3010)) {
        throw "El instalador de Node.js termino con el codigo $($installer.ExitCode)."
    }

    if ($installer.ExitCode -eq 3010) {
        Write-Warning 'Node.js se instalo correctamente; Windows requiere reiniciarse para completar la instalacion.'
    } else {
        Write-Host 'Node.js se instalo correctamente.'
    }
} catch {
    Write-Error "No se pudo instalar Node.js desde nodejs.org: $($_.Exception.Message)"
    exit 1
} finally {
    if (Test-Path -LiteralPath $msiPath) {
        try {
            Remove-Item -LiteralPath $msiPath -Force
        } catch {
            Write-Warning "No se pudo borrar el instalador temporal $msiPath : $($_.Exception.Message)"
        }
    }
}
