#!/bin/sh
# shellcheck enable=avoid-nullary-conditions,check-unassigned-uppercase

#__LICENSE_HERE__

#set -x

#__INNOEXTRACT_BINARY_START__
INNOEXTRACT_BINARY_B64=0
#__INNOEXTRACT_BINARY_END__

INSTALLER_VERSION="DEV"
REPO_PATH="https://github.com/ZOOM-Platform/zoom-platform.sh"
INNOEXT_BIN="/tmp/innoextract_zoom"
LAUNCH_SCRIPTS_PATH="$HOME"/.local/share/zoom-platform
APPLICATIONS_ROOT="$HOME"/.local/share/applications/zoom-platform
UMU_BIN=umu-run
CACHE_DIR="$HOME"/.cache/zoom-platform

# Resolve the Desktop dir once, with a fallback in case xdg-utils isn't
# installed. Baked into the generated uninstall.sh too, so uninstalling
# doesn't depend on xdg-user-dir either.
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2> /dev/null)"
[ -d "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME/Desktop"

# Check if dialogs can be used and set tool
CAN_USE_DIALOGS=0
USE_ZENITY=1
(command -v kdialog >/dev/null || command -v zenity >/dev/null) && [ -n "$DISPLAY" ] && CAN_USE_DIALOGS=1
[ $CAN_USE_DIALOGS -eq 1 ] && ! command -v zenity >/dev/null && USE_ZENITY=0

# Create cache directory
mkdir -p "$CACHE_DIR"

# .shellcheck will consume ram trying to parse INNOEXTRACT_BINARY_B64
# when developing, just load the bin from working dir
get_innoext_string() {
    if [ $INSTALLER_VERSION = "DEV" ]; then
        printf '%s' "$(base64 -w 0 innoextract)"
    else
        printf '%s' "$INNOEXTRACT_BINARY_B64"
    fi
}

dialog_installer_select() {
    if [ $USE_ZENITY -eq 1 ]; then
        zenity --file-selection --title="Select a ZOOM Platform installer"
        return $?
    else
        kdialog --getopenfilename . "ZOOM Platform Windows installer(*.exe)" --title "Select a ZOOM Platform installer"
        return $?
    fi
}

dialog_install_dir_select() {
    if [ $USE_ZENITY -eq 1 ]; then
        zenity --file-selection --directory --title="Select an installation directory"
        return $?
    else
        kdialog --getexistingdirectory . --title "Select an installation directory"
        return $?
    fi
}

dialog_msgbox() {
    _type=$1
    _title=$2
    _msg=$3

    [ -z "$_title" ] && _title=""

    _param=''
    case $_type in
        "info") [ $USE_ZENITY -eq 1 ] && _param='info' || _param='msgbox' ;;
        "warning") [ $USE_ZENITY -eq 1 ] && _param='warning' || _param='sorry' ;;
        "error") _param='error' ;;
    esac

    if [ $USE_ZENITY -eq 1 ]; then
        zenity --no-wrap --$_param --text="$_msg" --title="$_title"
        return $?
    else
        kdialog --$_param "$_msg" --title "$_title"
        return $?
    fi
}

log_error() {
    printf "\033[31;1mERROR:\033[0m %s\n" "$*" >&2
}

# Shows an error dialog and an error message then exits
# $1: Error message
# $2: Msgbox title (optional)
fatal_error() {
    [ $CAN_USE_DIALOGS -eq 1 ] && dialog_msgbox error "$2" "$1"
    log_error "$1"
    exit 1
}

log_info() {
    printf "\033[33m[\033[35mzoom-platform.sh\033[33m]\033[0m: %s\n" "$*"
}

base64_dec() {
    _input="$1"
    if command -v base64 > /dev/null; then
        printf '%s' "$_input" | base64 -d 2>/dev/null || return 1
    elif command -v openssl > /dev/null; then
        printf '%s' "$_input" | openssl enc -d -base64 -A 2>/dev/null || return 1
    elif command -v python3 > /dev/null; then
        printf '%s' "$_input" | python3 -m base64 -d 2>/dev/null || return 1
    else
        return 1
    fi
}

validate_uuid() {
    _input="$1"
    _uuid_pattern="^[0-9a-fA-F]\{8\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{12\}$"
    expr "$_input" : "$_uuid_pattern" > /dev/null && return 0
    return 1
}

trim_string() {
    awk '{$1=$1;print}'
}

# Download the umu-launcher zipapp
download_umu_zipapp() {
    _url="$1"
    _url_resp=$(curl -o "$CACHE_DIR"/umu-launcher.tar.xz "$_url" -Ls -H "User-Agent: zoom-platform.sh/$INSTALLER_VERSION (+https://zoom-platform.sh/)")
    _url_exit=$?
    if [ $_url_exit -ne 0 ]; then
        fatal_error "Could not download umu-launcher. Please install it manually."
    fi

    if ! command -v tar > /dev/null; then
        fatal_error "tar was not found on this system."
    fi

    tar --overwrite-dir -C "$CACHE_DIR" -xf "$CACHE_DIR"/umu-launcher.tar.xz umu/umu-run
    rm -f "$CACHE_DIR"/umu-launcher.tar.xz
    chmod +x "$CACHE_DIR"/umu/umu-run
    UMU_BIN="$CACHE_DIR"/umu/umu-run
}

# Get umu-launcher's url from lutris' runtime api
get_umu_url() {
    _api_resp=$(curl -Ls -H "User-Agent: zoom-platform.sh/$INSTALLER_VERSION (+https://zoom-platform.sh/)" \
                    'https://lutris.net/api/runtimes?format=json')
    _api_exit=$?
    if [ $_api_exit -eq 0 ]; then
        _parsed_str="$(printf '%s' "$_api_resp" | awk -F'"name":"umu"' '{ split($2, urls, "url\":\""); print substr(urls[2], 1, index(urls[2], "\"")-1) }')"
        # Validate parsed output
        case $_parsed_str in
            *"umu-launcher"*)
                printf '%s' "$_parsed_str"
                exit 0
                ;;
            *)
                exit 1
                ;;
        esac
    fi
    exit 1
}

get_umu_id() {
    _guid="$1"
    _api_resp=$(curl -Ls -H "User-Agent: zoom-platform.sh/$INSTALLER_VERSION (+https://zoom-platform.sh/)" \
                    "https://umu.openwinecomponents.org/umu_api.php?store=zoomplatform&codename=$_guid")
    _api_exit=$?
    if [ $_api_exit -eq 0 ]; then
        _parsed_str="$(printf '%s' "$_api_resp" | awk -F'"umu_id":"' '{print substr($2, 1, index($2, "\"")-1)}')"
        # Validate parsed output
        case $_parsed_str in
            "umu-"*)
                printf '%s' "$_parsed_str"
                exit 0
                ;;
            *)
                exit 1
                ;;
        esac
    fi
    exit 1
}

get_desktop_value() {
    _key=$1
    _desktopfile=$2
    sed -n -e "/^$_key=/s/^$_key=//p" "$_desktopfile"
}

show_log_file_line() {
    _install_dir=$(printf '%s' "$2" | sed 's/\\/\\\\/g')
    _line=$(printf '%s' "$1" | sed -n "s/.*Dest filename: $_install_dir//p" | sed 's/^\\//;s/\\/\//g')
    printf "\r\e[K\033[33m[\033[35mzoom-platform.sh\033[33m]\033[0m: Extracting: %s" "$_line"
}

# Generate command to launch umu with
umu_launch_command() {
    if [ "$UMU_BIN" = "FLATPAK" ]; then
        # shellcheck disable=SC2016
        printf '%s' 'flatpak run --env=GAMEID="$GAMEID" --env=WINEPREFIX="$WINEPREFIX" --env=STORE="$STORE" org.openwinecomponents.umu.umu-launcher'
    else
        printf '%s' "$UMU_BIN"
    fi
}

umu_launch() {
    if [ "$UMU_BIN" = "FLATPAK" ]; then
        [ -z "$PROTON_VERB" ] && PROTON_VERB=waitforexitandrun
        # The Flatpak only sees the env vars passed with --env, so a caller that sets
        # extra ones for a single call (see ensure_proton_shortcuts) opts in by listing
        # their names in ZOOM_FORWARD_ENV. Forwarding them unconditionally would also
        # start applying e.g. the user's own global WINEDLLOVERRIDES to every other
        # call, which the Flatpak never saw before.
        # The app id goes first and each --env is put in front of everything, which keeps
        # values with spaces intact and them all before the app id, where flatpak wants them.
        set -- org.openwinecomponents.umu.umu-launcher "$@"
        for _fwd_name in $ZOOM_FORWARD_ENV; do
            _fwd_val=""
            eval "_fwd_val=\${$_fwd_name}"
            set -- "--env=$_fwd_name=$_fwd_val" "$@"
        done
        flatpak run --env=GAMEID="$GAMEID" --env=WINEPREFIX="$WINEPREFIX" --env=PROTON_VERB="$PROTON_VERB" "$@"
    else
        "$UMU_BIN" "$@"
    fi
}

# Check permissions for path or file
# Runs check from within the flatpak if umu flatpak is being used
test_file_perms() {
    _mode=$1 # r or w
    _target=$2

    case $_mode in
        "r" | "w") ;;
        *)
            fatal_error "Invalid test_file_perms pararm: $_mode. Must be r or w"
    esac

    if [ "$UMU_BIN" = "FLATPAK" ]; then
        flatpak run --command=sh org.openwinecomponents.umu.umu-launcher -c "test -$_mode \"$_target\""
        return $?
    else
        test -"$_mode" "$_target"
        return $?
    fi
}

# Check that the install destination can be written to, even if it doesn't exist yet.
# "test -w" is false for a path that doesn't exist, so this tests the nearest ancestor
# that does exist instead (that's the folder the install would create it in).
# Prints the folder that was tested and returns the result of "test -w" on it.
# Runs from within the flatpak if umu flatpak is being used, in one sandbox start: the
# sandbox may not see the same paths as the host, so both the "does it exist" walk and
# the write test have to happen inside it.
test_dest_writable() {
    # The path is passed as $1 rather than spliced into the script, so quotes, $ and
    # spaces in it can't break the script (or run as part of it)
    # shellcheck disable=SC2016
    _tdw_script='
        _p=$1
        # Walk up until something exists. dirname gives "." for a relative path with no
        # slash left and "/" for "/", and both are their own dirname, so stop there.
        while [ ! -e "$_p" ]; do
            _parent=$(dirname "$_p")
            [ "$_parent" = "$_p" ] && break
            _p=$_parent
        done
        printf "%s\n" "$_p"
        test -w "$_p"
    '
    if [ "$UMU_BIN" = "FLATPAK" ]; then
        flatpak run --command=sh org.openwinecomponents.umu.umu-launcher -c "$_tdw_script" sh "$1"
        return $?
    else
        sh -c "$_tdw_script" sh "$1"
        return $?
    fi
}

# Loose check if dir is a wine prefix
is_valid_prefix() {
    _wine_prefix="$1"

    # Check if the directory exists
    [ ! -d "$_wine_prefix" ] && return 1

    # Check for some files and dirs
    _required_dirs="drive_c dosdevices"
    _required_files="system.reg user.reg"
    for dir in $_required_dirs; do
        [ ! -d "$_wine_prefix/$dir" ] && return 1
    done

    for f in $_required_files; do
        [ ! -f "$_wine_prefix/$f" ] && return 1
    done

    return 0
}

# Get values from the zoom keys in the registry
# Warning:
#   This is very loose query on purpose!
#   It'll return multi lines if more than 1 game is installed.
get_prefix_reg_val() {
    _wine_prefix="$1"
    _key="$2"
    _res="$(awk -v key="$_key" '
        BEGIN { in_section = 0; }
        {
            if ($0 ~ ("^\\[Software\\\\\\\\ZOOM PLATFORM\\\\\\\\")) {
                in_section = 1;
            } else if (in_section && match($0, "^\"" key "\"=")) {
                print $0;
            }
        }
    ' "$_wine_prefix/system.reg" | awk -F'"' '{print $4}')"

    printf '%s\n' "$_res" # the line break is required for while read
}

# Check if wine prefix has a specific zoom game installed
prefix_has_game() {
    _wine_prefix="$1"
    _guid="$2"

    # Check if the directory exists
    if ! is_valid_prefix "$_wine_prefix"; then
        return 1
    else
        _r=1
        _tmp=$(mktemp)
        get_prefix_reg_val "$_wine_prefix" "Site GUID" > "$_tmp"
        while read -r line; do
            # Validate the paths, stop on first success
            if [ "$line" = "$_guid" ]; then
                _r=0
                break
            fi
        done < "$_tmp"
        rm -f "$_tmp"
        return $_r
    fi
}

# Check if wine prefix has any zoom game installed
prefix_has_any_game() {
    _wine_prefix="$1"

    _r=1
    _tmp=$(mktemp)
    get_prefix_reg_val "$_wine_prefix" "InstallPath" > "$_tmp"

    # normally there should only be one game installed, but multiple is valid if dlc is installed
    while read -r line; do
        # Validate the paths, stop on first success
        if [ -d "$(PROTON_VERB=getnativepath umu_launch "$line")" ]; then
            _r=0
            break
        fi
    done < "$_tmp"
    rm -f "$_tmp"
    return $_r
}

_lnk_read_block() {
    _lnkpath=$1
    _offset=$2
    _length=$3
    od --endian=little -tdI -An -j "$_offset" -N "$_length" "$_lnkpath" | tr -d '\n '
}

_lnk_readstr_utf16() {
    _lnkpath=$1
    _offset=$2
    _length=$3
    _unicode=$4
    _result=''
    if [ "$_unicode" = 1 ]; then
        # stop at first \0 by getting offset and overriding _length
        _nul_offset=$(od -w2 -v -t x2 -Ad -j "$_offset" -N "$_length" "$_lnkpath" | awk '$2 == "0000" {print $1+0;exit}')
        [ -n "$_nul_offset" ] && _length=$((_nul_offset-_offset))

        _result=$(dd skip="$_offset" count="$_length" if="$_lnkpath" bs=1 status=none | iconv -f UTF-16LE -t UTF-8)
    else
        _result=$(od -S1 -An -j "$_offset" -N "$_length" "$_lnkpath")
    fi
    printf '%s' "$_result" | sed 's/\\/\\\\/g'
}

# Parse Windows .lnk for data
# Based on these documentation: 
# - https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-shllink/16cb4ca1-9339-4d0c-a68d-bf1d6cc0f943
# - https://github.com/libyal/liblnk/tree/main/documentation
parse_lnk() {
    _lnkpath="$1"

    # https://github.com/libyal/liblnk/blob/main/documentation/Windows%20Shortcut%20File%20(LNK)%20format.asciidoc#21-data-flags
    _flags_oct=$(od -An -j 20 -N 1 "$_lnkpath" | tr -d '\n ')
    _flags=$(printf '%s\n' "$_flags_oct" | dd status=none)

    # https://github.com/libyal/liblnk/blob/main/documentation/Windows%20Shortcut%20File%20(LNK)%20format.asciidoc#3-link-target-identifier
    _itemlist_count=$(_lnk_read_block "$_lnkpath" 76 2)

    # LinkInfo
    # https://github.com/libyal/liblnk/blob/main/documentation/Windows%20Shortcut%20File%20(LNK)%20format.asciidoc#4-location-information
    _location_offset=$((_itemlist_count+78)) # skip guid
    _link_info_length=$(_lnk_read_block "$_lnkpath" $_location_offset 4)            # LinkInfoSize
    _link_info_header_size=$(_lnk_read_block "$_lnkpath" $((_location_offset+4)) 4) # LinkInfoHeaderSize
    _link_info_flags=$(_lnk_read_block "$_lnkpath" $((_location_offset+8)) 4)       # LinkInfoFlags
    _basepath_offset=$(_lnk_read_block "$_lnkpath" $((_location_offset+16)) 4)      # LocalBasePathOffset

    _basepath_is_unicode=0
    # Use unicode offset instead
    if [ "$_link_info_header_size" -gt 28 ]; then
        _basepath_offset=$(_lnk_read_block "$_lnkpath" $((_location_offset+28)) 4) # LocalBasePathOffsetUnicode
        _basepath_is_unicode=1
    fi

    _localpath_offset=$((_location_offset+_basepath_offset))
    _localpath_end=$((_location_offset+_link_info_length))
    _localpath_length=$((_localpath_end-_localpath_offset))

    _localpath=$(_lnk_readstr_utf16 "$_lnkpath" $_localpath_offset $_localpath_length $_basepath_is_unicode) # LocalBasePath or LocalBasePathUnicode

    printf 'LocalBasePath:%s\n' "$_localpath"

    # StringData
    # STRING_DATA = [NAME_STRING] [RELATIVE_PATH] [WORKING_DIR] [COMMAND_LINE_ARGUMENTS] [ICON_LOCATION]
    # https://github.com/libyal/liblnk/blob/main/documentation/Windows%20Shortcut%20File%20(LNK)%20format.asciidoc#5-data-strings
    
    _stringdata_is_unicode=0
    # IsUnicode
    [ "$((_flags & 0x00000080))" -ne 0 ] && _stringdata_is_unicode=1

    _stringdata_offset=$_localpath_end
    # HasName HasRelativePath HasWorkingDir HasArguments HasIconLocation
    for i in 0x00000004 0x00000008 0x00000010 0x00000020 0x00000040 ; do
        if [ "$((_flags & i))" -ne 0 ]; then
            _stringdata_length=$(_lnk_read_block "$_lnkpath" "$_stringdata_offset" 2) # CountCharacters
            [ "$_stringdata_is_unicode" = 1 ] && _stringdata_length=$((_stringdata_length*2))

            _stringdata_value=''
            [ "$_stringdata_length" -gt 0 ] && \
                _stringdata_value="$(_lnk_readstr_utf16 "$_lnkpath" $((_stringdata_offset+2)) "$_stringdata_length" "$_stringdata_is_unicode")"

            _stringdata_offset=$((_stringdata_offset+_stringdata_length))
            [ $_stringdata_is_unicode = 1 ] && _stringdata_offset=$((_stringdata_offset+2))

            if [ -n "$_stringdata_value" ]; then
                case "$i" in
                    0x00000004) printf 'NAME_STRING:';;
                    0x00000008) printf 'RELATIVE_PATH:';;
                    0x00000010) printf 'WORKING_DIR:';;
                    0x00000020) printf 'COMMAND_LINE_ARGUMENTS:';;
                    0x00000040) printf 'ICON_LOCATION:';;
                esac
                printf '%s\n' "$_stringdata_value"
            fi
        fi
    done
}

# Whether a shortcut is one we don't make a launcher for: the uninstaller, PDFs and
# HTML manuals.
# $1: exe (or document) the shortcut points to. Wine's StartupWMClass is this,
#     lowercased; parse_lnk gives it in its original case. Lowercased here so both work.
# $2: shortcut name (the .lnk filename without extension, same as the .desktop Name=)
# Returns 0 if the shortcut should be skipped.
is_skipped_shortcut() {
    _skip_target=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    _skip_name=$2
    case $_skip_target in
        # Skip uninstaller and PDFs
        "unins000.exe" | *".pdf")
            return 0
            ;;
        # Skip HTML manuals
        *".html" | *".htm")
            case $_skip_name in
                *"Manual"*)
                    return 0
                    ;;
            esac
            ;;
    esac
    return 1
}

# Print the Windows path of every shortcut (.lnk) this install created, one per line.
# Inno logs each [Icons] entry as:
#     <timestamp>   -- Icon entry --
#     <timestamp>   Dest filename: C:\ProgramData\...\Start Menu\Programs\Game\Game.lnk
# The log is recreated for every installer run, so in a prefix shared by a base game
# and its DLC this only returns the shortcuts of the install that just ran.
get_install_lnks() {
    # The log has CRLF line endings (and a UTF-8 BOM on its first line, which never
    # matters here). An "Icon entry" header arms the flag, the next "Dest filename:"
    # is the shortcut, and any other "-- Xxx entry --" header disarms it so a File
    # entry's "Dest filename:" is never mistaken for one.
    awk '
        { sub("\r$", "") }
        /-- Icon entry --$/ { icon = 1; next }
        /-- [A-Za-z]+ entry --$/ { icon = 0; next }
        icon && /Dest filename: / {
            sub(/^.*Dest filename: /, "")
            if (tolower($0) ~ /\.lnk$/) print
            icon = 0
        }
    ' "$INSTALL_PATH/drive_c/zoom_installer.log"
}

# Print the native path of every shortcut (.lnk) in the places an installer puts them:
# the common and the per-user Start Menu, and the Public Desktop ({commondesktop}).
# The shortcuts of a prefix are shared by every install in it (base game + DLC), so
# what tells this run's apart is when they were written: zoom_install_started is created
# right before the installer is launched.
# $1: "new" for the shortcuts written since then (this run's), "old" for all the others
# Newlines in shortcut names aren't handled (Windows doesn't allow them anyway).
list_lnks_on_disk() {
    _ll_drive_c="$INSTALL_PATH/drive_c"
    _ll_marker="$_ll_drive_c/zoom_install_started"
    # Without the marker there's no telling which run wrote what
    [ -f "$_ll_marker" ] || return 0
    if [ "$1" = "new" ]; then
        set -- -newer "$_ll_marker"
    else
        set -- ! -newer "$_ll_marker"
    fi
    find "$_ll_drive_c/ProgramData/Microsoft/Windows/Start Menu" \
         "$_ll_drive_c"/users/*/AppData/Roaming/Microsoft/Windows/"Start Menu" \
         "$_ll_drive_c/users/Public/Desktop" \
         -iname '*.lnk' "$@" 2> /dev/null
}

# Fallback for get_install_lnks: this run's shortcuts found on disk instead, the .lnk files
# written since the installer was launched (see list_lnks_on_disk). Unlike a search by
# Start Menu folder this also finds Desktop-only shortcuts, and never another install's.
# Prints Windows paths like get_install_lnks.
find_install_lnks() {
    _fl_drive_c="$INSTALL_PATH/drive_c"
    list_lnks_on_disk new | while IFS= read -r _fl_lnk; do
        # Strip the (literal, hence quoted) prefix up to drive_c, then / -> \ (octal 134,
        # to keep a literal backslash out of the quoting) and put C:\ back
        _fl_win=$(printf '%s' "${_fl_lnk#"$_fl_drive_c/"}" | tr '/' '\134')
        printf '%s\n' "C:\\$_fl_win"
    done
}

# The parts of a shortcut that decide what it launches: target, working dir and arguments.
# Empty if the .lnk can't be parsed.
# $1: native path of the .lnk
lnk_launch_signature() {
    parse_lnk "$1" 2> /dev/null | grep -E '^(LocalBasePath|WORKING_DIR|COMMAND_LINE_ARGUMENTS):'
}

# For a DLC's shortcut: compare it with the shortcuts of the same name that were already in
# the prefix before this run (the base game's, most likely).
# $1: native path of this run's .lnk
# $2: shortcut name (the .lnk filename without extension)
# Returns 0 if one of them launches exactly the same thing (nothing new to make a launcher
# for), 2 if there are some but they launch something else (this one is the DLC's own, and
# it can't take the name), 1 if there's none.
compare_with_existing_lnk() {
    _cw_sig=$(lnk_launch_signature "$1")
    _cw_name=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
    _cw_result=1
    # Names are compared here, and not with find -name, because a name can have glob
    # characters in it ([, *, ?). Case-insensitive, like wine.
    while IFS= read -r _cw_other; do
        [ -n "$_cw_other" ] || continue
        _cw_base=${_cw_other##*/}
        _cw_base=$(printf '%s' "${_cw_base%.[lL][nN][kK]}" | tr '[:upper:]' '[:lower:]')
        [ "$_cw_base" = "$_cw_name" ] || continue
        _cw_result=2
        # An unreadable .lnk (empty signature) is never "the same"
        if [ -n "$_cw_sig" ] && [ "$(lnk_launch_signature "$_cw_other")" = "$_cw_sig" ]; then
            _cw_result=0
            break
        fi
    done <<EOL
$(list_lnks_on_disk old)
EOL
    return $_cw_result
}

# Whether a .desktop in proton_shortcuts was written by wine during this run. Wine keeps one
# .desktop per shortcut name for the whole prefix, so one that's there can be an earlier
# install's: a DLC's shortcut with the same name as the base game's, when winemenubuilder
# didn't run, would find the base game's and take it for its own. Wine rewrites the file on
# every run, even for identical content (checked with a real reinstall), so a .desktop
# older than zoom_install_started isn't this run's.
# $1: path of the .desktop
is_desktop_from_this_run() {
    _fr_marker="$INSTALL_PATH/drive_c/zoom_install_started"
    # Without the marker there's no telling, so trust what's there
    [ -f "$_fr_marker" ] || return 0
    [ -n "$(find "$1" -newer "$_fr_marker" 2> /dev/null)" ]
}

# Shortcut name from its Windows path: the filename without ".lnk". Wine names the
# .desktop it writes into proton_shortcuts after it, so this is also the .desktop's name.
get_lnk_name() {
    _gl_name=${1##*\\}
    printf '%s' "${_gl_name%.[lL][nN][kK]}"
}

# Wait for wine to finish creating Proton's shortcuts (proton_shortcuts/*.desktop),
# then make sure every shortcut this install created has one.
#
# Wine's winemenubuilder turns each .lnk the installer saves into a .desktop + icons,
# but it's started in the background and nothing waits for it. Right after the
# installer is killed it may still be running, or it may never have run at all: setups
# that export WINEDLLOVERRIDES="winemenubuilder.exe=d" (Lutris-style ones do) disable it.
# Without this step that means no launchers and no error.
#
# 1. Any default-verb umu launch runs "wineserver -w" first (Proton's waitforexitandrun),
#    which waits for every process in the prefix, background winemenubuilders included.
# 2. Shortcuts that still have no .desktop from this run (see is_desktop_from_this_run)
#    get winemenubuilder run by hand, with the winemenubuilder DLL override forced back
#    on for that call only.
# 3. Whatever is still missing is reported by name (not fatal, the game is installed).
#
# Only the shortcuts of the installer that just ran are looked at, never the rest of a
# shared prefix (a base game and its DLC): they come from the installer's own log, or, if
# that gives none, from the .lnk files written since it was launched.
#
# Sets SHORTCUTS_KEPT to how many shortcuts this install has that should get a launcher.
# Sets INSTALL_SHORTCUTS to the names of all of this run's shortcuts, as "|name|name|",
# and INSTALL_DESKTOP_SHORTCUTS the same for the ones that are on the Desktop. A shortcut
# not in the first isn't this install's, and gets no launcher. An empty list is empty: a DLC
# with no shortcuts of its own has nothing to make.
# Output of the umu calls goes to drive_c/zoom_menubuilder.log.
# Idea from upstream's 672c694 ("Run winemenubuilder manually").
ensure_proton_shortcuts() {
    _sc_log="$INSTALL_PATH/drive_c/zoom_menubuilder.log"
    SHORTCUTS_KEPT=0
    INSTALL_SHORTCUTS='|'
    INSTALL_DESKTOP_SHORTCUTS='|'

    _sc_links=$(get_install_lnks)
    [ -n "$_sc_links" ] || _sc_links=$(find_install_lnks)
    if [ -z "$_sc_links" ]; then
        _sc_icon_count=$(get_header_val 'icon_count')
        # The Start Menu entries can't be turned off in the installer (the Desktop one can), so
        # an installer that defines shortcuts and made none is worth telling about
        [ "${_sc_icon_count:-0}" -gt 0 ] && \
            log_error "The installer defines ${_sc_icon_count} shortcut(s) but none were created, so there are no launchers. The game is installed in \"$INSTALL_PATH\"."
    fi

    # Sync point, see (1) above. Any cheap command works, hostname has no side effects.
    # UMU_CONTAINER_NSENTER would switch umu to a verb that doesn't wait.
    ( unset UMU_CONTAINER_NSENTER; umu_launch hostname ) >> "$_sc_log" 2>&1 < /dev/null

    _sc_missing=''
    _sc_nl='
'
    # Reads from a here-doc rather than a pipe so the counters survive the loop (dash
    # runs the right side of a pipe in a subshell). The umu calls inside get </dev/null
    # so they can't swallow the here-doc.
    while IFS= read -r _sc_win; do
        [ -n "$_sc_win" ] || continue
        _sc_name=$(get_lnk_name "$_sc_win")

        # Note which ones the installer put on the Desktop (C:\users\<user>\Desktop\..., the
        # Public one for everyone), before the check below drops the Desktop copy of a name
        case $_sc_win in
            *\\[Dd]esktop\\*) INSTALL_DESKTOP_SHORTCUTS="$INSTALL_DESKTOP_SHORTCUTS$_sc_name|" ;;
        esac

        # The Desktop and Start Menu copies of a shortcut share one .desktop, only handle it once
        case $INSTALL_SHORTCUTS in
            *"|$_sc_name|"*) continue ;;
        esac
        INSTALL_SHORTCUTS="$INSTALL_SHORTCUTS$_sc_name|"

        _sc_desktop="$PROTON_SHORTCUTS_PATH/$_sc_name.desktop"
        if [ -f "$_sc_desktop" ] && is_desktop_from_this_run "$_sc_desktop"; then
            # Wine made it. (One left by an earlier install doesn't count, it's dealt with as
            # a missing one below.) The skip rules apply to what wine recorded as the target.
            is_skipped_shortcut "$(get_desktop_value "StartupWMClass" "$_sc_desktop")" "$_sc_name" && continue
            SHORTCUTS_KEPT=$((SHORTCUTS_KEPT+1))
            continue
        fi

        # No .desktop. Read the .lnk to decide whether it's one we'd skip anyway, so we
        # don't launch umu for the uninstaller and manuals.
        # C:\a\b.lnk -> <prefix>/drive_c/a/b.lnk. Wine matches names case-insensitively
        # and the filesystem doesn't, so if that misses ask wine for the real path.
        _sc_rel=${_sc_win#?:\\}
        _sc_native="$INSTALL_PATH/drive_c/$(printf '%s' "$_sc_rel" | tr '\134' '/')" # \134 is a backslash
        if [ ! -f "$_sc_native" ]; then
            _sc_native=$( (PROTON_VERB=getnativepath umu_launch "$_sc_win" < /dev/null) 2> /dev/null | head -n 1)
        fi
        if [ ! -f "$_sc_native" ]; then
            log_error "Can't find the shortcut file for \"$_sc_name\" ($_sc_win), so it won't get a launcher."
            continue
        fi
        # LocalBasePath is the target exe; parse_lnk doubles the backslashes, so drop
        # everything up to the last one to get the exe name. A corrupt .lnk makes
        # parse_lnk complain and print nothing: the exe is then unknown, so it's not
        # skipped and winemenubuilder gets to have its say (and gets reported if it fails).
        _sc_exe=$(parse_lnk "$_sc_native" 2> /dev/null | sed -n 's/^LocalBasePath://p')
        _sc_exe=${_sc_exe##*\\}
        is_skipped_shortcut "$_sc_exe" "$_sc_name" && continue

        SHORTCUTS_KEPT=$((SHORTCUTS_KEPT+1))
        _sc_missing="$_sc_missing$_sc_win$_sc_nl"
    done <<EOL
$_sc_links
EOL

    [ -n "$_sc_missing" ] || return 0

    log_info "Wine didn't create every shortcut, creating the missing ones..."
    printf '=== winemenubuilder for shortcuts wine did not create:\n%s' "$_sc_missing" >> "$_sc_log"
    # Proton hides wine's own messages unless PROTON_LOG is set, and then writes them to a
    # steam-*.log of their own. Turn that on for this call only, so that when winemenubuilder
    # fails, what it said about it ends up in our log instead of nowhere.
    _sc_wine_log_dir="$INSTALL_PATH/drive_c/zoom_menubuilder_tmp"
    mkdir -p "$_sc_wine_log_dir"
    (
        # One call for all of them. Each .lnk is its own argument, so names with spaces,
        # quotes or non-ASCII characters need no escaping (unlike a generated .bat, which
        # cmd would read in the OEM codepage).
        set --
        while IFS= read -r _sc_win; do
            [ -n "$_sc_win" ] && set -- "$@" "$_sc_win"
        done <<EOL
$_sc_missing
EOL
        # Force the DLL back on for this call only, keeping whatever else the user set.
        # Later entries win, so this beats a user's "winemenubuilder.exe=d". It stays
        # inside this subshell, so no other umu call or generated launch script sees it.
        WINEDLLOVERRIDES="${WINEDLLOVERRIDES:+$WINEDLLOVERRIDES;}winemenubuilder.exe=b"
        PROTON_LOG=1
        PROTON_LOG_DIR="$_sc_wine_log_dir"
        WINEDEBUG="err+menubuilder,warn+menubuilder"
        export WINEDLLOVERRIDES PROTON_LOG PROTON_LOG_DIR WINEDEBUG
        ZOOM_FORWARD_ENV="WINEDLLOVERRIDES PROTON_LOG PROTON_LOG_DIR WINEDEBUG"
        umu_launch winemenubuilder "$@"
    ) >> "$_sc_log" 2>&1 < /dev/null
    # Keep just wine's winemenubuilder lines, and drop the rest of Proton's log
    cat "$_sc_wine_log_dir"/*.log 2> /dev/null | grep -a 'menubuilder:' >> "$_sc_log"
    rm -rf "$_sc_wine_log_dir"

    # winemenubuilder exits 0 even when it fails to write an entry, so check for the files
    while IFS= read -r _sc_win; do
        [ -n "$_sc_win" ] || continue
        _sc_name=$(get_lnk_name "$_sc_win")
        { [ -f "$PROTON_SHORTCUTS_PATH/$_sc_name.desktop" ] && is_desktop_from_this_run "$PROTON_SHORTCUTS_PATH/$_sc_name.desktop"; } || \
            log_error "Couldn't create a launcher for the shortcut \"$_sc_name\" ($_sc_win). See $_sc_log"
    done <<EOL
$_sc_missing
EOL
}

show_usage() {
    printf 'Usage: zoom-platform.sh [OPTIONS] INSTALLER DEST

Description:
  zoom-platform.sh - Install Windows games from ZOOM Platform using umu and Proton.

Options:
  -h, --help           Display this help message and exit.
  -v, --version        Display the version information and exit.
  -i, --installer      Path to a ZOOM Platform installer .exe.
  -d, --dest           Path to where you want the game to install to.
  -o, --output         Alias for -d.

Arguments:
  INSTALLER            Path to a ZOOM Platform installer .exe.
  DEST                 Path to where you want the game to install to.

Examples:
  zoom-platform.sh "Game-English-Setup-1.33.7.exe" ~/Games/new_game_dir
  zoom-platform.sh -i "Game-English-Setup-1.33.7.exe" -d ~/Games/new_game_dir

Note:
  - INSTALLER and DEST are optional if your environment can use KDialog or Zenity.
  - When the -i or -d options are used, they take priority over the arguments.
  - If updating a game or installing DLC, DEST should be the same path that the
    base game was installed in.
  - If you tick "Create a desktop shortcut" during setup, Desktop entries will be
    placed in: %s

Source & issues: %s
' "$DESKTOP_DIR" "$REPO_PATH"
}

INPUT_INSTALLER=""
INSTALL_PATH=""

options=$(getopt -o hvi:d:o: --long help,version,installer:,dest:,output: -n 'zoom-platform.sh' -- "$@")

eval set -- "$options"

while true; do
  case "$1" in
    -h | --help )
        show_usage
        exit 0
        ;;
    -v | --version )
        printf '%s\n' $INSTALLER_VERSION
        exit 0
        ;;
    -i | --installer )
        INPUT_INSTALLER="$2" 
        shift 2
        ;;
    -d | --dest | -o | --output )
        INSTALL_PATH="$2"
        shift 2
        ;;
    --) shift; break ;;
    *)
        fatal_error "Invalid option: $1"
    ;;
  esac
done

[ -z "$INPUT_INSTALLER" ] && INPUT_INSTALLER=$1

[ -z "$INSTALL_PATH" ] && INSTALL_PATH=$2

# Unpack innoextract into tmp
base64_dec "$(get_innoext_string)" > $INNOEXT_BIN
PAYLOAD_DECODED_STATUS=$?
[ $PAYLOAD_DECODED_STATUS -ne 0 ] && fatal_error "Could not decode base64." "Error unpacking innoextract"
if [ -s "$INNOEXT_BIN" ]; then
    # Make it executable and test it
    chmod +x $INNOEXT_BIN
    $INNOEXT_BIN --version > /dev/null 2>&1 || fatal_error "Cannot launch $INNOEXT_BIN"
else
    fatal_error "Could not decode base64." "Error unpacking innoextract"
fi

# Check if UWU is installed
if command -v umu-run > /dev/null; then
    UMU_BIN=umu-run
    log_info "Using umu native"
elif command -v "$HOME"/.local/share/umu/umu-run > /dev/null; then
    UMU_BIN="$HOME"/.local/share/umu/umu-run
    log_info "Using $HOME/.local/share/umu/umu-run"
elif command -v /usr/bin/umu-run > /dev/null; then
    UMU_BIN=/usr/bin/umu-run
    log_info "Using /usr/bin/umu-run"
elif flatpak info org.openwinecomponents.umu.umu-launcher >/dev/null 2>&1; then
    UMU_BIN="FLATPAK"
    log_info "Using umu Flatpak"
else
    _umu_url="$(get_umu_url)"
    download_umu_zipapp "$_umu_url"
    # fatal_error "umu is not installed"
fi

# If dialogs are usable and installer wasn't specified, show a dialog
if [ $CAN_USE_DIALOGS -eq 1 ] && [ -z "$INPUT_INSTALLER" ]; then
    INPUT_INSTALLER=$(dialog_installer_select)
    case $? in
        0)
            log_info "Selected \"$INPUT_INSTALLER\"";;
        1)
            fatal_error "No installer chosen.";;
        *)
            fatal_error "An unexpected error occurred when trying to choose an installer.";;
    esac
fi

# Show usage if can't use dialogs and no paths passed
if [ $CAN_USE_DIALOGS -eq 0 ]; then
    if [ -z "$INPUT_INSTALLER" ] || [ -z "$INSTALL_PATH" ]; then
        log_error "Cannot use dialogs, please specify INSTALLER and DEST."
        show_usage
        exit 1
    fi
fi

# Show an error if can't read installer
if ! test_file_perms r "$INPUT_INSTALLER" ; then
    _msg="Installer either does not exist or $([ "$UMU_BIN" = "FLATPAK" ] && printf "umu Flatpak does not have" || printf "no") read permissions."
    fatal_error "$_msg"
fi

# Validate and get some info from installer
ZOOM_GUID=$($INNOEXT_BIN -s --zoom-game-id "$INPUT_INSTALLER" 2> /dev/null | trim_string)
ZOOM_GUID_EXIT=$?
# GUID can be wrong for very old installers, make sure it's a valid string
if [ $ZOOM_GUID_EXIT -gt 0 ] || ! validate_uuid "$ZOOM_GUID"; then
    fatal_error "This doesn't seem to be a ZOOM Platform installer.
If you think this is an error, please submit a bug report:
$REPO_PATH/issues" "Invalid ZOOM Platform Installer"
fi

INSTALLER_INFO=$($INNOEXT_BIN -s --print-headers "$INPUT_INSTALLER")
get_header_val () {
    printf '%s' "$INSTALLER_INFO" | sed -n "s/$1: \"\(.*\)\"/\1/p; s/$1: \(.*\)/\1/p" # Handles with and without quotes
}

INNO_APPID=$(get_header_val 'app_id' | sed 's/[{}]//g') # Strip {{}

# Check if installer is for DLC
IS_DLC=0
[ "$(get_header_val 'default_dir_name')" = "{code:GetInstallationPath}" ] && IS_DLC=1

# Show installer info
printf "
Title: \033[32;1m%s\033[0m 
Publisher: \033[39;49;1m%s\033[0m
ZOOM Platform Version: \033[39;49;1m%s\033[0m
ZOOM Platform UUID: \033[39;49;1m%s\033[0m
IS DLC: \033[39;49;1m%s\033[0m
\n" \
"$(get_header_val 'app_name')" \
"$(get_header_val 'app_publisher')" \
"$(get_header_val 'app_version')" \
"$ZOOM_GUID" \
"$([ "$IS_DLC" -eq 1 ] && printf "yes" || printf "no")"

# Open file selector if DEST wasn't given
if [ -z "$INSTALL_PATH" ]; then
    if [ $CAN_USE_DIALOGS -eq 1 ]; then
        # If DLC, ask user to select prefix where base game was installed
        if [ $IS_DLC -eq 1 ]; then
            dialog_msgbox info "DLC Installer Chosen" \
                "$(get_header_val 'app_name')\n\nSelect the same directory you chose when you installed the base game in the next prompt."
        fi

        printf "Select an installation directory\n"
        INSTALL_PATH=$(dialog_install_dir_select)
        case $? in
            0)
                log_info "Selected \"$INSTALL_PATH\"";;
            1)
                fatal_error "No install directory chosen.";;
            *)
                fatal_error "An unexpected error has occurred.";;
        esac
    else
        show_usage
        fatal_error 'No install directory specified'
    fi
fi

# Show an error if install destination isn't writable, only do this for the Flatpak.
# The destination may not exist yet, so what's tested is its nearest existing folder.
if [ "$UMU_BIN" = "FLATPAK" ] && ! _dest_checked=$(test_dest_writable "$INSTALL_PATH"); then
    _nl='
'
    _msg="The umu Flatpak does not have write permissions to the install directory.$_nl$INSTALL_PATH"
    if [ "$_dest_checked" != "$INSTALL_PATH" ]; then
        _msg="$_msg${_nl}(it doesn't exist yet, so this was checked: $_dest_checked)"
    fi
    # Also prints the message in the terminal, not just in the popup
    fatal_error "$_msg" "No permissions"
fi

export WINEPREFIX="$INSTALL_PATH"
export GAMEID="zoominstall"

# Safety checks to save users from themselves
# - Don't allow dirs that are NOT empty
# - Don't let user choose existing prefix
# - Allow existing prefix only if it's updating the same game OR installing DLC
# If DLC, must be a wine prefix and a zoom game needs to exist already
# Only checking existence, let the DLC installer itself run checks to see if it's the right game or not
if is_valid_prefix "$INSTALL_PATH"; then
    # Same game is installed on this prefix, must be updating or reinstalling
    if prefix_has_game "$INSTALL_PATH" "$ZOOM_GUID"; then
        log_info "Detected the same game installed in this prefix! [$ZOOM_GUID]"
    else
        if prefix_has_any_game "$INSTALL_PATH"; then
            # Don't let user put different games in a prefix
            if [ $IS_DLC -eq 0 ]; then
                fatal_error "Invalid install directory. A different game is already installed here."
            fi
        else
            # Dont allow installing DLC if no other game is here
            if [ $IS_DLC -eq 1 ]; then
                fatal_error "Invalid install directory. When installing DLC, choose the directory you installed the base game in."
            fi
        fi
    fi
# must be empty or not exist
elif [ -d "$INSTALL_PATH" ] && [ -n "$(ls -A "$INSTALL_PATH")" ]; then
    fatal_error "Install directory must either be empty or an existing wine prefix if updating a game."
fi

# Write Inno inf to C drive
# This hides some stuff the user shouldn't change
mkdir -p "$INSTALL_PATH/drive_c"
cat >"$INSTALL_PATH/drive_c/zoom_installer.inf" <<EOL
[Setup]
Lang=english
Tasks=desktopicon
DisableWelcomePage=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
EOL

# These reg values need to preexist in the registry before the installer
# runs to skip the option to change the directory and remove windows shortcuts.

# DLC's don't need this since main game should already be installed.
# Also don't need to do this if game is already installed
if [ $IS_DLC -eq 0 ] && ! prefix_has_game "$INSTALL_PATH" "$ZOOM_GUID"; then
    cat >"$INSTALL_PATH/drive_c/zoom_regkeys.bat" <<EOL
@echo off
REM We do a check cause we don't want to overwrite in case of an update that changes the default installation directory.
reg query "HKLM\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{$INNO_APPID}_is1" >nul
if %errorlevel% neq 0 (
    reg add "HKLM\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{$INNO_APPID}_is1" /v "Inno Setup: Icon Group" /t REG_SZ /d "$(get_header_val 'default_group_name')"
    reg add "HKLM\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{$INNO_APPID}_is1" /v "Inno Setup: App Path" /t REG_SZ /d "$(get_header_val 'default_dir_name')"
)
EOL

    log_info "Creating installer reg keys..."
    umu_launch start "C:\\zoom_regkeys.bat"
fi

printf "\n" > "$INSTALL_PATH/drive_c/zoom_installer.log"
# Everything the installer writes from here on is newer than this file, which is how
# this run's shortcuts are told apart from the ones already in a shared prefix
# (see list_lnks_on_disk)
: > "$INSTALL_PATH/drive_c/zoom_install_started"

# If installer doesn't have custom components then it can be installed silently
# Disabling for now, need to figure out how to reliably check this
VERYSILENT=0
# [ -z "$(get_header_val 'component_count')" ] || [ "$(get_header_val 'component_count')" -eq 0 ] && VERYSILENT=1

# Launch installer in a subprocess
# Only important stuff like the EULA and configurable items should show.
# "/ZOOMINSTALLERGUID=" is only used so we can easily find the process with pkill -f
log_info "Launching installer..."
umu_launch "$INPUT_INSTALLER" \
    /NORESTART \
    /SP- \
    /LOADINF=C:\\zoom_installer.inf \
    /LOG=C:\\zoom_installer.log \
    /ZOOMINSTALLERGUID="$ZOOM_GUID" \
    "$([ "$VERYSILENT" -eq 1 ] && printf "/VERYSILENT")" &

# Watch the install log
_currentfile=0
# Not every installer reports every header (DLC installers in particular may
# omit icon_count entirely rather than report 0), so default missing values
# to 0 - otherwise $(( )) dies on an empty operand.
_header_file_count=$(get_header_val 'file_count')
_header_icon_count=$(get_header_val 'icon_count')
_filecount=$(( ${_header_file_count:-0} + ${_header_icon_count:-0} ))
_readlog=1
while [ $_readlog -eq 1 ]; do
    sleep 0.010
    while read -r line || [ -n "$line" ]; do
        case $line in
            *"Dest filename: "*)
                # show_log_file_line "$line" "$(get_header_val 'default_dir_name')" # too slow
                _currentfile=$((_currentfile+1))
                printf "\r\e[K\033[33m[\033[35mzoom-platform.sh\033[33m]\033[0m: Extracting: %d/%d" $_currentfile $_filecount
            ;;
            *"Exception message"* | *"Got EAbort exception"*)
                _readlog=0
                fatal_error "Unknown installation error occured."
                ;;
        esac

        # Handle killing process based on if silent install chosen
        if [ "$VERYSILENT" -eq 1 ]; then
            case $line in
                *"Log closed."*)
                    printf "\n"
                    log_info "Installer finished!"
                    _readlog=0
                    ;;
            esac
        else
            case $line in
                *"Need to restart Windows?"*) # User shouldn't launch the game through the option supplied by Inno, kill installer asap
                    printf "\n\r"
                    log_info "Installer finished! Force closing."
                    printf "\r"
                    pkill -f "/ZOOMINSTALLERGUID=$ZOOM_GUID"
                    printf "\r"
                    _readlog=0
                    ;;
                *"Log closed."*) # Shouldn't be able to get to this point if killed by above
                    _readlog=0
                    printf "\n\r"
                    pkill -f "/ZOOMINSTALLERGUID=$ZOOM_GUID"
                    printf "\r"
                    fatal_error "Installer failed or canceled."
                    ;;
            esac
        fi
    done
done < "$INSTALL_PATH/drive_c/zoom_installer.log"

# Query API for UMU ID
UMU_ID="$(get_umu_id "$ZOOM_GUID")"
UMU_ID_EXIT=$?
[ $UMU_ID_EXIT -gt 0 ] && UMU_ID="0"


CREATE_DESKTOP_ENTRIES=1
if ! command -v desktop-file-install > /dev/null; then
    log_error "desktop-file-install is not available. Skipping desktop entry creation."
    CREATE_DESKTOP_ENTRIES=0
fi

# Create shortcuts using the shortcuts and icons in C:\proton_shortcuts\
# https://github.com/ValveSoftware/wine/commit/0a02c50a20ddc8f4a4c540c43a8b8a686023d422
# https://github.com/ValveSoftware/wine/commit/d0109f6ce75e13a4972371d7ef5819d2614c6d61
# https://github.com/ValveSoftware/wine/commit/7c040c3c0f837278e2ef3bb55fc9770f61444b36
GAME_NAME_SAFE=$(get_header_val 'default_group_name')
PROTON_SHORTCUTS_PATH="$INSTALL_PATH/drive_c/proton_shortcuts"
APPLICATIONS_PATH="$APPLICATIONS_ROOT/$GAME_NAME_SAFE"
ZOOM_SHORTCUTS_PATH="$INSTALL_PATH/drive_c/zoom_shortcuts"
log_info "Creating desktop entries..."
mkdir -p "$ZOOM_SHORTCUTS_PATH"
ensure_proton_shortcuts # waits for wine to create the shortcuts and fills in any it missed
LAUNCHERS_MADE=0
DUPLICATE_SHORTCUTS=0 # this run's shortcuts that are copies of ones already there, so get no launcher
# One "<shortcut name>|<launcher name>" line for each launcher made, for the Desktop links.
# They differ for a DLC's shortcut that has the name of one the base game already has.
LAUNCHER_MAP=''
_nl='
'
for file in "$PROTON_SHORTCUTS_PATH"/*.desktop; do
    [ ! -f "$file" ] && continue # safety check if .desktop exists

    _filename=$(basename "$file" ".desktop")
    # The prefix's proton_shortcuts holds what wine made for every install that was ever
    # run in it, and only this run's shortcuts are this run's to make launchers for
    case $INSTALL_SHORTCUTS in
        *"|$_filename|"*) ;;
        *) continue ;;
    esac
    _shortcut_name=$_filename # what the installer called it; _filename may become the launcher's name below

    # Get some values from the .desktop
    _name="$(get_desktop_value "Name" "$file")"
    _lnkpathwin="$(get_desktop_value "Exec" "$file")"
    _wmclass="$(get_desktop_value "StartupWMClass" "$file")"
    _iconname="$(get_desktop_value "Icon" "$file")"

    # Skip certain shortcuts
    is_skipped_shortcut "$_wmclass" "$_name" && continue

    # Unescape windows path
    _lnkpathlinux=$( (PROTON_VERB=getnativepath umu_launch "$(printf '%s' "$_lnkpathwin" | sed 's/\\\\/\\/g; s/\\ / /g; s/\\\([^\\]\)/\1/g')") 2> /dev/null | head -n 1)
    # A DLC can have a shortcut with the same name as one of the base game's (both share the
    # same proton_shortcuts/<name>.desktop, launch script and menu entry name).
    # If it launches the same thing there's nothing to add. If it launches something else,
    # its arguments probably are what starts the DLC, so it's kept, under the DLC's name
    # so that it doesn't overwrite the base game's launcher.
    if [ $IS_DLC -eq 1 ]; then
        compare_with_existing_lnk "$_lnkpathlinux" "$_shortcut_name"
        case $? in
            0)
                DUPLICATE_SHORTCUTS=$((DUPLICATE_SHORTCUTS+1))
                continue
                ;;
            2)
                _filename=$GAME_NAME_SAFE
                # A second one in the same run can't have the same name too
                case $LAUNCHER_MAP in
                    *"|$_filename$_nl"*) _filename="$GAME_NAME_SAFE ($_shortcut_name)" ;;
                esac
                _name=$_filename
                ;;
        esac
    fi

    # Get values from .lnk
    _lnk="$(parse_lnk "$_lnkpathlinux")"
    _lnk_exe=$(printf '%s' "$_lnk" | sed -n 's/LocalBasePath://p')
    _lnk_workingdir=$(printf '%s' "$_lnk" | sed -n 's/WORKING_DIR://p')
    _lnk_args=$(printf '%s' "$_lnk" | sed -n 's/COMMAND_LINE_ARGUMENTS://p')

    # Get absolute path to largest icon. A shortcut wine couldn't extract an icon for has
    # no Icon= at all, and searching for "*.png" would pick some other shortcut's icon.
    _iconpath=""
    if [ -n "$_iconname" ]; then
        _iconfile=$(find "$PROTON_SHORTCUTS_PATH/icons" -type f -name "*$_iconname.png" -printf '%P\n' 2> /dev/null | sort -n -tx -k1 -r | head -n 1)
        [ -n "$_iconfile" ] && _iconpath="$PROTON_SHORTCUTS_PATH/icons/$_iconfile"
    fi

    cat >"$ZOOM_SHORTCUTS_PATH/$_filename.sh" <<EOL
#!/bin/sh
export GAMEID="$UMU_ID"
export WINEPREFIX="$INSTALL_PATH"
export STORE="zoomplatform"
$(umu_launch_command) start /b /d "$_lnk_workingdir" "$_lnk_exe" $_lnk_args
EOL
    chmod +x "$ZOOM_SHORTCUTS_PATH/$_filename.sh"
    LAUNCHERS_MADE=$((LAUNCHERS_MADE+1))
    LAUNCHER_MAP="$LAUNCHER_MAP$_shortcut_name|$_filename$_nl"

    # Desktop entries do not play well with special characters, and each distro handles them
    # different enough to be annoyingly problematic.
    # So we create a script in a location with no special characters (hopefully) that launches umu.
    if [ $CREATE_DESKTOP_ENTRIES -eq 1 ]; then
        _zoomdesktopfile="$ZOOM_SHORTCUTS_PATH/$_filename.desktop"
        _fsum=$(printf '%s' "$_filename" | cksum | cut -d ' ' -f1)

        # Place script in $XDG_DATA_HOME/zoom-platform/
        mkdir -p "$LAUNCH_SCRIPTS_PATH/$ZOOM_GUID/"
        ln -sf "$ZOOM_SHORTCUTS_PATH/$_filename.sh" "$LAUNCH_SCRIPTS_PATH/$ZOOM_GUID/$_fsum.sh"

        # Now create .desktop and point to script
        cat >"$_zoomdesktopfile" <<EOL
[Desktop Entry]
Name=$_name
Exec=$LAUNCH_SCRIPTS_PATH/$ZOOM_GUID/$_fsum.sh
${_iconpath:+Icon=$_iconpath}
StartupWMClass=$_wmclass
Terminal=false
Type=Application
Categories=Game
X-KDE-RunOnDiscreteGpu=true
EOL
        log_info "Creating \"$APPLICATIONS_PATH/$_name.desktop\""
        desktop-file-install --delete-original --dir="$APPLICATIONS_PATH" "$_zoomdesktopfile"
        chmod +x "$APPLICATIONS_PATH/$_name.desktop"
    fi
done

# The install can look successful while having no launcher at all, so say so
if [ $((SHORTCUTS_KEPT-DUPLICATE_SHORTCUTS)) -gt 0 ] && [ "$LAUNCHERS_MADE" -eq 0 ]; then
    log_error "The installer created $SHORTCUTS_KEPT shortcut(s) but no launch scripts could be made from them. The game is installed, but new launchers weren't created (any you already had were left as they are). See \"$INSTALL_PATH/drive_c/zoom_menubuilder.log\""
fi

# A shared prefix can hold more than one install (base game + DLC(s)), each with
# its own $GAME_NAME_SAFE/applications dir, but they all share one $ZOOM_GUID
# and get wiped together below. So the uninstaller must clean up every
# applications dir ever created in this prefix, not just the one this install
# just made. Every install writes its group name as the "IconGroup" value
# under its own [Software\ZOOM PLATFORM\...] key in system.reg, so pull the
# full list back out with get_prefix_reg_val (union'd with $GAME_NAME_SAFE
# itself, since wine may not have flushed this install's own key to
# system.reg yet).
#
# Filter out anything that isn't a bare directory name (empty, ".", "..", or
# containing "/") before it's used inside rm -rf below.
_icon_groups="$(
    {
        get_prefix_reg_val "$INSTALL_PATH" 'IconGroup'
        printf '%s\n' "$GAME_NAME_SAFE"
    } | sort -u | while IFS= read -r _g; do
        case "$_g" in
            "" | . | ..) continue ;;
            */*) continue ;;
        esac
        printf '%s\n' "$_g"
    done
)"
# Escape for embedding as a single-quoted literal inside the heredoc below
# (group names can contain spaces, e.g. "e-Racer Track Pack DLC", and in
# theory apostrophes).
_icon_groups_escaped="$(printf '%s\n' "$_icon_groups" | sed "s/'/'\\\\''/g")"

# Create uninstaller
# The Desktop symlinks and Public Desktop lookup below don't exist yet at this
# point in the script (they're created further down), so the uninstaller can't
# just record their paths. Instead it scans the Desktop at uninstall time and
# removes only the symlinks that point into a known applications dir,
# leaving every other file on the Desktop alone.
cat >"$INSTALL_PATH/uninstall.sh" <<EOL
#!/bin/sh
printf "You are about to remove %s's data and shortcuts. Are you sure you want to continue? [y/N]\n" "$GAME_NAME_SAFE"
read in
if [ "\$in" = "y" ] || [ "\$in" = "yes" ] || [ "\$in" = "Y" ] || [ "\$in" = "YES" ]; then
    # Every applications-menu group name ever installed into this prefix
    # (base game + any DLC), baked in at install time.
    _icon_groups='$_icon_groups_escaped'
    printf '%s\n' "\$_icon_groups" | while IFS= read -r _group; do
        [ -n "\$_group" ] || continue
        for _desktopfile in "$DESKTOP_DIR"/*.desktop; do
            [ -L "\$_desktopfile" ] || continue
            case "\$(readlink "\$_desktopfile")" in
                "$APPLICATIONS_ROOT/\$_group"/*) rm -f "\$_desktopfile" ;;
            esac
        done
        rm -rf "$APPLICATIONS_ROOT/\$_group"
    done
    # Launch script symlinks in \$XDG_DATA_HOME/zoom-platform/
    rm -rf "$LAUNCH_SCRIPTS_PATH/$ZOOM_GUID"
    rm -rf "$INSTALL_PATH"
    # Remove the now empty parents. Fails harmlessly while other games are installed.
    rmdir "$APPLICATIONS_ROOT" "$LAUNCH_SCRIPTS_PATH" 2> /dev/null
fi
EOL
chmod +x "$INSTALL_PATH/uninstall.sh"

# If user chose to create Desktop shortcuts in the installer, symlink to XDG desktop
# Shortcut names placed on the Desktop are always the same as what was made in the Start Menu
# Only the ones this run's installer put on the Desktop, and only for the launchers it made:
# a Desktop shortcut from an earlier install in the same prefix is that install's, and
# leaving the box unticked this time doesn't remove it (or re-point it).
if [ $CREATE_DESKTOP_ENTRIES -eq 1 ]; then
    while IFS='|' read -r _shortcut_name _launcher_name; do
        [ -n "$_shortcut_name" ] || continue
        case $INSTALL_DESKTOP_SHORTCUTS in
            *"|$_shortcut_name|"*) ;;
            *) continue ;;
        esac
        _existingdesktoppath="$APPLICATIONS_PATH/$_launcher_name.desktop"
        if [ -f "$_existingdesktoppath" ]; then
            log_info "Creating \"$DESKTOP_DIR/$_launcher_name.desktop\""
            ln -sf "$_existingdesktoppath" "$DESKTOP_DIR/$_launcher_name.desktop"
        fi
    done <<EOL
$LAUNCHER_MAP
EOL
    printf "\n"
    log_info "Installation complete! You can now launch your games from the applications launcher."
    log_info "To add to your Steam library, from within Steam go to \"Games\" -> \"Add a Non-Steam Game to My Library\" then select it from the popup."
else
    printf "\n"
    log_info "Installation complete! Desktop entry creation was skipped, the launch scripts are in \"$ZOOM_SHORTCUTS_PATH\""
fi
