# [zoom-platform.sh](https://zoom-platform.sh/)

> **This is [DarthSidiousPT](https://github.com/DarthSidiousPT)'s fork of
> [ZOOM-Platform/zoom-platform.sh](https://github.com/ZOOM-Platform/zoom-platform.sh)**,
> kept up to date with fixes and installer compatibility work that hasn't landed upstream
> yet (see the table below). It builds `innoextract` from
> [DarthSidiousPT/innoextract](https://github.com/DarthSidiousPT/innoextract) (itself a
> fork of doZennn's ZOOM-patched fork), and stays current instead of waiting on upstream's
> release cadence.
>
> This is an independent, unofficial fork - it is not endorsed by, affiliated with, or
> supported by ZOOM Platform.

## What's different from the official script:

|                                                                                                                    | Feature                                   | This version                                                                                                                                     | Official script                                                                                                                                                         |
| ------------------------------------------------------------------------------------------------------------------ | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <img src="https://api.iconify.design/ph/package-duotone.svg?color=%232f81f7&height=20" height="20" alt="">         | Newer game installers (Inno Setup 6.3+)   | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> Supported                      | <img src="https://api.iconify.design/ph/question-fill.svg?color=%238b949e&height=18" height="18" alt="Unknown"> Bundles an older innoextract                            |
| <img src="https://api.iconify.design/ph/terminal-window-duotone.svg?color=%232f81f7&height=20" height="20" alt=""> | Running the script on Ubuntu, Debian, Mint | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> Works                          | <img src="https://api.iconify.design/ph/x-circle-fill.svg?color=%23cf222e&height=18" height="18" alt="Fails"> Stops before creating shortcuts, unless started with `bash`                           |
| <img src="https://api.iconify.design/ph/stack-duotone.svg?color=%232f81f7&height=20" height="20" alt="">           | Game + DLC in the same folder             | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> Each keeps its own shortcuts   | <img src="https://api.iconify.design/ph/warning-circle-fill.svg?color=%23d4a72c&height=18" height="18" alt="Partial"> DLC duplicates the game's shortcuts               |
| <img src="https://api.iconify.design/ph/app-window-duotone.svg?color=%232f81f7&height=20" height="20" alt="">      | Menu and Desktop shortcuts                | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> Always created, gaps reported  | <img src="https://api.iconify.design/ph/warning-circle-fill.svg?color=%23d4a72c&height=18" height="18" alt="Partial"> Can go missing without an error                   |
| <img src="https://api.iconify.design/ph/folder-plus-duotone.svg?color=%232f81f7&height=20" height="20" alt="">     | Installing into a new folder              | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> Works                          | <img src="https://api.iconify.design/ph/warning-circle-fill.svg?color=%23d4a72c&height=18" height="18" alt="Partial"> Can wrongly refuse a folder that doesn't exist yet |
| <img src="https://api.iconify.design/ph/files-duotone.svg?color=%232f81f7&height=20" height="20" alt="">           | Game split into several .bin files        | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> Checked before installing      | <img src="https://api.iconify.design/ph/x-circle-fill.svg?color=%23cf222e&height=18" height="18" alt="Fails"> Doesn't check for the .bin files                          |
| <img src="https://api.iconify.design/ph/trash-duotone.svg?color=%232f81f7&height=20" height="20" alt="">           | Uninstall                                 | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> Removes everything             | <img src="https://api.iconify.design/ph/x-circle-fill.svg?color=%23cf222e&height=18" height="18" alt="Fails"> Leaves Desktop links and launch scripts           |

<sub>Official script = the [v1.0.1 release](https://github.com/ZOOM-Platform/zoom-platform.sh/releases/tag/v1.0.1) that `curl zoom-platform.sh` serves, checked September 2026. Some of these are already fixed in its unreleased development code.</sub>

---

A tool to streamline installation, updating, and playing Windows games from [ZOOM Platform](https://www.zoom-platform.com/) on Linux using [umu](https://github.com/Open-Wine-Components/umu-launcher) and Proton.

## Building

| Script       | Example                                             | -                                                                                                                  |
| ------------ | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **build.sh** | `./build.sh "src.sh" "innoextract-upx" > output.sh` | Takes an input `src.sh`, embeds an innoextract binary, sets the version, prepends licences then prints the output. |
| **dist.sh**  |                                                     | Downloads innoextract then creates a `zoom-platform.sh` file using `build.sh`                                      |

## Website

The website is just a static `index.html` in [www/public](www/public).  
A small web server is used so users can get the script at the latest commit or a specific hash.
See the [README](www/README.md) here.

## Usage

For the script help, see `-h`.  
For the website:
| URL (either http or https works) | |
| - | - |
| `curl zoom-platform.sh` | Returns the latest stable version of the script. |
| `curl zoom-platform.sh/latest` | Returns the script built from the latest commit. |
| `curl zoom-platform.sh/b8dbaf9` | Returns the script built from a specific commit. |
| `curl zoom-platform.sh/b8dbaf9cde1f98c09d7da6874c3931014275fd4b` | Same as above but using the full hash. |

### Games split into several files

Some big games (such as Necro Vision) come as one `.exe` plus `-1.bin`, `-2.bin`, ... files. Download all of them into the same folder, keep their names, and choose the `.exe`. Before installing, the script checks that every part is there and complete. If one is missing, or your browser renamed it (`-1 (1).bin`), it tells you which file to rename, and a part that looks cut short is a warning you can choose to continue past.

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md)

## Licence

[BSD-3](LICENSE)
