# MultiWorlds Launcher updates

Public update feed for the MultiWorlds Launcher. The launcher reads launcher-updates/manifest.json from the main branch and downloads versioned ZIP packages from this repository.

## Publishing a new version

Prepare the per-profile mods, resourcepacks, and/or config files, then run tools/Build-Update.ps1 from the project workspace. Copy the generated upload/launcher-updates directory into this repository, review the manifest and package hashes, and commit the new manifest and version directory to main.

The manifest must remain public and valid JSON. Package ZIPs may contain only mods, resourcepacks, and config at their root. Do not add player saves or private files.
