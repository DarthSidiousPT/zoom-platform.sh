# [zoom-platform.sh](https://zoom-platform.sh/)

> **This is [DarthSidiousPT](https://github.com/DarthSidiousPT)'s fork of
> [ZOOM-Platform/zoom-platform.sh](https://github.com/ZOOM-Platform/zoom-platform.sh)**,
> kept up to date with fixes and installer compatibility work that hasn't landed upstream
> yet - including building `innoextract` from
> [DarthSidiousPT/innoextract](https://github.com/DarthSidiousPT/innoextract) (itself a
> fork of doZennn's ZOOM-patched fork) so installers using newer Inno Setup versions
> actually work, and fixes for DLC installers and uninstaller cleanup. This fork stays
> current instead of waiting on upstream's release cadence.
>
> This is an independent, unofficial fork - it is not endorsed by, affiliated with, or
> supported by ZOOM Platform.

A tool to streamline installation, updating, and playing Windows games from [ZOOM Platform](https://www.zoom-platform.com/) on Linux using [umu](https://github.com/Open-Wine-Components/umu-launcher) and Proton.

## Building
| Script | Example | - |
| - | - | - |
| **build.sh** | `./build.sh "src.sh" "innoextract-upx" > output.sh` | Takes an input `src.sh`, embeds an innoextract binary, sets the version, prepends licences then prints the output. |
| **dist.sh**  |  | Downloads innoextract then creates a `zoom-platform.sh` file using `build.sh` |

## Website
The website is just a static `index.html` in [www/public](www/public).  
A small web server is used so users can get the script at the latest commit or a specific hash.
See the [README](www/README.md) here.

## Usage
For the script help, see `-h`.  
For the website:
| URL (either http or https works) |  |
| - | - |
| `curl zoom-platform.sh` | Returns the latest stable version of the script. |
| `curl zoom-platform.sh/latest` | Returns the script built from the latest commit. |
| `curl zoom-platform.sh/b8dbaf9` | Returns the script built from a specific commit. |
| `curl zoom-platform.sh/b8dbaf9cde1f98c09d7da6874c3931014275fd4b` | Same as above but using the full hash. |

## Contributing
Please see [CONTRIBUTING.md](CONTRIBUTING.md)

## Licence
[BSD-3](LICENSE)