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
Write-Output @"
$art

"@



# Windows loves to run random stuff in System32...
Set-Location (Split-Path -Path "$PSCommandPath" -Parent)



# Basic tmp / cache / ... folder and variable preparation

$root = "$PSScriptRoot"
Write-Output "Running Ahorn-VHD build script in $root"

$mount = "$root\mount"
if (Test-Path -Path "$mount") {
    Remove-Item -Force -Path "$mount"
}
New-Item -Path "$mount" -ItemType Directory

$out = "$root\out"
if (Test-Path -Path "$out") {
    Remove-Item -Recurse -Path "$out"
}
New-Item -Path "$out" -ItemType Directory

$tmp = "$root\tmp"
if (Test-Path -Path "$tmp") {
    Remove-Item -Recurse -Path "$tmp"
}
New-Item -Path "$tmp" -ItemType Directory

$cache = "$root\cache"
if (!(Test-Path -Path "$cache")) {
    New-Item -Path "$cache" -ItemType Directory
}

$ahorn = "$out\ahorn.vhdx"



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
diskpart /s "$tmp\dp-init.txt"
Write-Output ""

Write-Output @"
$art

This virtual disk image was created using the Ahorn-VHD tool by 0x0ade, and is meant to be used with Olympus.
If you're hardcore enough, feel free to update and then run Ahorn directly off of this VHD.
The tool can be found on https://github.com/0x0ade/Ahorn-VHD

Please read Ahorn's LICENSE file: https://github.com/CelestialCartographers/Ahorn/blob/master/LICENSE.md
Most notably, "NO permission is granted to distribute [Ahorn]"
To make this VHD REDISTRIBUTABLE (BEFORE UPLOAD), run launch-local-julia.bat misc/prepare-for-redistribution.jl OR build it with -Redist
To make this VHD USABLE (AFTER DOWNLOAD), run update-ahorn.bat

Here's some information about when and how this disk image was built:
Time: $(Get-Date -Format "o")
CWD: $(Get-Location)
User: $env:UserName
Redist: $Redist
"@ | Out-File -Encoding UTF8 -FilePath "$mount\info.txt"

Copy-Item -Path "$root\data\*" -Destination "$mount\" -Recurse



# Download and prepare a basic Julia environment.
# Let the user / CI cache the download.
# NOTE: This currently downloads a beta version of Julia and is x64-only.

if (!(Test-Path "$cache\julia.zip")) {
    Invoke-WebRequest -Uri "https://julialang-s3.julialang.org/bin/winnt/x64/1.6/julia-1.6.0-beta1-win64.zip" -OutFile "$cache\julia.zip"
}
Expand-Archive -Path "$cache\julia.zip" -DestinationPath "$mount\"
Move-Item -Path "$mount\julia-b84990e1ac" -Destination "$mount\julia"

New-Item -Path "$mount\julia-depot" -ItemType Directory
New-Item -Path "$mount\ahorn-env" -ItemType Directory



# Time to do what's probably gonna take the longest time...
& "$mount\update-ahorn.bat"

if ($Redist) {
    & "$mount\launch-local-julia.bat" "$mount\misc\prepare-for-redistribution.jl"
}



# File permissions are FUN. Perms set on the mount point aren't inherited properly...
Write-Host ""
foreach ($sub in Get-ChildItem -Path "$mount" -Directory) {
    Write-Output "Fixing perms for dir $(sub.FullName)"
    $acl = Get-Acl $sub.FullName
    $acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule((New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinUsersSid, $null)), "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
    Set-Acl -Path $sub.FullName -AclObject $acl
}
foreach ($sub in Get-ChildItem -Path "$mount" -File) {
    Write-Output "Fixing perms for file $(sub.FullName)"
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
diskpart /s "$tmp\dp-exit.txt"

Write-Output ""
Write-Output "Done"
