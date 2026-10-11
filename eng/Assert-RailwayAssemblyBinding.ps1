param(
    [Parameter(Mandatory)][string] $JobsAssembly,
    [Parameter(Mandatory)][string] $CoreAssembly
)

$ErrorActionPreference = 'Stop'
$coreIdentity = [Reflection.AssemblyName]::GetAssemblyName((Resolve-Path $CoreAssembly).Path)
$stream = [IO.File]::OpenRead((Resolve-Path $JobsAssembly).Path)
$reader = [System.Reflection.PortableExecutable.PEReader]::new($stream)
try {
    $metadata = [System.Reflection.Metadata.PEReaderExtensions]::GetMetadataReader($reader)
    $references = @($metadata.AssemblyReferences | ForEach-Object {
        $reference = $metadata.GetAssemblyReference($_)
        if ($metadata.GetString($reference.Name) -ceq $coreIdentity.Name) { $reference.Version }
    })
    if ($references.Count -ne 1 -or $references[0] -ne $coreIdentity.Version) {
        throw 'Packed Jobs assembly does not reference the exact restored core assembly version.'
    }
    Write-Output $coreIdentity.FullName
}
finally { $reader.Dispose(); $stream.Dispose() }
