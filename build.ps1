Param(
    [switch]$Redist
)

$ErrorActionPreference = "Inquire"

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must run with administrator priviledges as it will mount a virtual partition." -ForegroundColor Yellow
    Start-Process -Verb RunAs powershell (@(' -NoExit')[!$NoExit] + " -File `"$PSCommandPath`" " + ($MyInvocation.Line -split '\.ps1[\s\''\"]\s*', 2)[-1])
    Break
}

$art = @"
                                        (
                                       @@@
                                     /@@@@@
                                    @@@@@@@@(
                                   @@@@@@@@@@@        *
                          @@@@@  &@@@@@@@@@@@@@* .@@@@,
                          .@@@@@@@@@@@@@@@@@@@@@@@@@@@
                           @@@@@@@@@@@@@@@@@@@@@@@@@@/
                           ,@@@@@@@@@@@@@@@@@@@@@@@@@
                  @#        @@@@@@@@@@@@@@@@@@@@@@@@#        @@
     &.          @@@@@      *@@@@@@@@@@@@@@@@@@@@@@@       @@@@*          /@
     /@@@@@@@@@@@@@@@@@@     @@@@@@@@@@@@@@@@@@@@@@%    .@@@@@@@@@@@@@@@@@@
      @@@@@@@@@@@@@@@@@@@@   %@@@@@@@@@@@@@@@@@@@@@   #@@@@@@@@@@@@@@@@@@@*
       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
       *@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&
   #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,
      @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(
         &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@/
            %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*
               %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.
                  (@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.
                     #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.
                     .@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
                     @@@@@@@@@@@@@@#. .@@@  *%@@@@@@@@@@@@@@
                                       #@
                                       &@*
                                       @@(
                                       @@#
                                       @@%
                                       @@&
                                       @@@
"@

$info = @"
Time: $(Get-Date -Format "o")
User: $($env:UserName)
CWD: $(Get-Location)
CLI: $($MyInvocation.Line)
"@

Write-Output @"
$art

$info

"@


# Windows loves to run random stuff in System32...
Set-Location (Split-Path -Path "$PSCommandPath" -Parent)



# Basic tmp / cache / ... folder and variable preparation

$root = "$PSScriptRoot"
Write-Output "Running Ahorn-VHD build script in $root"

$mount = "$root\mount"
$out = "$root\out"
$tmp = "$root\tmp"
$cache = "$root\cache"
$ahorn = "$out\ahorn.vhdx"

if (Test-Path -Path "$mount") {
    Remove-Item -Force -Path "$mount"
}
New-Item -Path "$mount" -ItemType Directory

if (Test-Path -Path "$out") {
    Remove-Item -Recurse -Path "$out"
}
New-Item -Path "$out" -ItemType Directory

if (Test-Path -Path "$tmp") {
    Remove-Item -Recurse -Path "$tmp"
}
New-Item -Path "$tmp" -ItemType Directory

if (!(Test-Path -Path "$cache")) {
    New-Item -Path "$cache" -ItemType Directory
}



# First of the two diskpart scripts.

Write-Output ""
Write-Output "Creating empty $ahorn and mounting it to $mount"
Write-Output ""
Write-Output @"
create vdisk file="$ahorn" maximum=8192 type=expandable
attach vdisk
create partition primary
format fs=ntfs label="Ahorn Virtual Disk" quick
assign mount="$mount"
"@ | Out-File -Encoding ASCII -FilePath "$tmp\dp-init.txt"
& diskpart /s "$tmp\dp-init.txt"
Write-Output ""

Write-Output @"
$art

This virtual disk image was created using the Ahorn-VHD tool by 0x0ade and is meant to be used with Olympus.
If you're hardcore enough, feel free to update and then run Ahorn directly off of this VHD.
The tool can be found at https://github.com/0x0ade/Ahorn-VHD
It currently uses Julia 1.6.0.

Please read Ahorn's LICENSE file: https://github.com/CelestialCartographers/Ahorn/blob/master/LICENSE.md
Most notably, "NO permission is granted to distribute [Ahorn]"
To make this VHD REDISTRIBUTABLE (BEFORE UPLOAD), run launch-local-julia.bat misc/prepare-for-redistribution.jl OR build it with -Redist
To make this VHD USABLE (AFTER DOWNLOAD), run update-ahorn.bat

Here's some information about how this disk image was built:
$info
"@ | Out-File -Encoding UTF8 -FilePath "$mount\info.txt"

Copy-Item -Path "$root\data\*" -Destination "$mount\" -Recurse



# Download and prepare a basic Julia environment.
# Let the user / CI cache the download.
# NOTE: This currently downloads a beta version of Julia and is x64-only.

if (!(Test-Path -Path "$cache\julia.zip")) {
    Write-Output "Downloading Julia"
    Invoke-WebRequest -Uri "https://julialang-s3.julialang.org/bin/winnt/x64/1.6/julia-1.6.0-win64.zip" -OutFile "$cache\julia.zip"
}
Write-Output "Unpacking Julia"
Expand-Archive -Force -Path "$cache\julia.zip" -DestinationPath "$mount\"
if (Test-Path -Path "$mount\julia") {
    Remove-Item -Recurse -Path "$mount\julia"
}
Move-Item -Path "$mount\julia-1.6.0" -Destination "$mount\julia"

if (!(Test-Path -Path "$mount\julia-depot")) {
    New-Item -Path "$mount\julia-depot" -ItemType Directory
}
if (!(Test-Path -Path "$mount\ahorn-env")) {
    New-Item -Path "$mount\ahorn-env" -ItemType Directory
}

Write-Output ""

# Time to do what's probably gonna take the longest time...
& "$mount\update-ahorn.bat"
Move-Item -Path "$mount\log-install-ahorn.txt" -Destination "$mount\log-init-ahorn.txt"

# File permissions are FUN.
Write-Output "" | Out-File -Encoding UTF8 -FilePath "$mount\log-install-ahorn.txt"

if ($Redist) {
    & "$mount\launch-local-julia.bat" "$mount\misc\prepare-for-redistribution.jl"
}



# Line ending config mismatches cause some fun issues.

if ((Test-Path (& where.exe git.exe 2>&1 | %{ "$_" })) -eq $true) {
    Write-Output ""
    Write-Output "Fixing git config for general registry"
    Push-Location -Path "$mount\julia-depot\registries\General"
    Write-Output "core.autocrlf: $(& git.exe config --global core.autocrlf)"
    & git.exe config core.autocrlf "$(& git.exe config --global core.autocrlf)"
    Write-Output "core.whitespace: $(& git.exe config --global core.whitespace)"
    & git.exe config core.whitespace "$(& git.exe config --global core.whitespace)"
    Pop-Location
}



# File permissions are FUN. Perms set on the mount point aren't inherited properly...
Write-Host ""
Write-Output "Fixing perms for dir $mount"
$acl = Get-Acl "$mount"
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule((New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinUsersSid, $null)), "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
Set-Acl -Path "$mount" -AclObject $acl
foreach ($sub in Get-ChildItem -Path "$mount" -Directory) {
    Write-Output "Fixing perms for dir $($sub.FullName)"
    $acl = Get-Acl $sub.FullName
    $acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule((New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinUsersSid, $null)), "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
    Set-Acl -Path $sub.FullName -AclObject $acl
}
foreach ($sub in Get-ChildItem -Path "$mount" -File) {
    Write-Output "Fixing perms for file $($sub.FullName)"
    $acl = Get-Acl $sub.FullName
    $acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule((New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinUsersSid, $null)), "FullControl", "None", "None", "Allow")))
    Set-Acl -Path $sub.FullName -AclObject $acl
}
Write-Host ""


# Ideally this would list volume, select volume ? and remove mount="$mount"
# ... but detaching the vdisk works as well and we can force-delete the mount point.
Write-Output "Unmounting $ahorn"
Write-Output @"
select vdisk file="$ahorn"
detach vdisk
"@ | Out-File -Encoding ASCII -FilePath "$tmp\dp-exit.txt"
& diskpart /s "$tmp\dp-exit.txt"
Remove-Item -Force -Path "$mount"
New-Item -Path "$mount" -ItemType Directory



Write-Output ""
Write-Output "Done"
