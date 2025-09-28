#!/usr/bin/env bash
#
# ProxyFlow - set/unset/show proxy environment variables
#

print_help() {
    cat <<'EOF'
Usage: ProxyFlow [OPTIONS]

Options:
  -h, --help          Show this help message and exit
  -i, --ip IP         Proxy IP address (required for set)
  -p, --port PORT     Proxy port (required for set)
  -t, --type TYPE     Proxy type: http, https, socks5, all (default: all) [for set]
  -u, --unset [TYPE]  Unset proxy variables of given type (http|https|socks5|all).
                      If TYPE is omitted, defaults to "all".
  -s, --show          Show current proxy variables (raw env style)

Notes:
  * For setting, --type defaults to "all" if not provided
  * For unsetting, TYPE defaults to "all" if not provided
EOF
}

PROGRAM_NAME="proxyflow"

IP=""
PORT=""
TYPE="all"
UNSET_TYPE=""
DO_SHOW=0

# ---- argument parsing ----
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            print_help
            return 0 2>/dev/null || exit 0
            ;;
        -i|--ip)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "$PROGRAM_NAME: option '$1' requires an argument" >&2
                return 1 2>/dev/null || exit 1
            fi
            IP="$2"
            shift 2
            ;;
        -p|--port)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "$PROGRAM_NAME: option '$1' requires an argument" >&2
                return 1 2>/dev/null || exit 1
            fi
            PORT="$2"
            shift 2
            ;;
        -t|--type)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "$PROGRAM_NAME: option '$1' requires an argument" >&2
                return 1 2>/dev/null || exit 1
            fi
            TYPE="$2"
            shift 2
            ;;
        -u|--unset)
            if [ -n "$2" ] && [[ ! "$2" == -* ]]; then
                UNSET_TYPE="$2"
                shift 2
            else
                UNSET_TYPE="all"
                shift 1
            fi
            ;;
        -s|--show)
            DO_SHOW=1
            shift
            ;;
        --) shift; break ;;
        *) break ;;
    esac
done

# Validate port number if given
if [ -n "$PORT" ]; then
    if ! [[ "$PORT" =~ ^[0-9]{1,5}$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo "$PROGRAM_NAME: invalid port number '$PORT'" >&2
        return 1 2>/dev/null || exit 1
    fi
fi

# ---- functions ----
show_current() {
    echo "Current proxy variables:"
    for v in http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY; do
        val=$(eval "printf '%s' \"\${$v:-<unset>}\"")
        printf "  %-12s %s\n" "${v}=" "$val"
    done
}

pretty_show() {
    local ip=$1 port=$2 kind=$3 action=$4
    case "$action" in
        set)
            case "$kind" in
                http)   echo "http proxy   : ${ip}:${port}" ;;
                https)  echo "https proxy  : ${ip}:${port}" ;;
                socks5) echo "socks5 proxy : ${ip}:${port}" ;;
                all)
                    echo "http proxy   : ${ip}:${port}"
                    echo "https proxy  : ${ip}:${port}"
                    echo "socks5 proxy : ${ip}:${port}" ;;
            esac
            ;;
        unset)
            case "$kind" in
                http)   echo "http proxy   : <unset>" ;;
                https)  echo "https proxy  : <unset>" ;;
                socks5) echo "socks5 proxy : <unset>" ;;
                all)
                    echo "http proxy   : <unset>"
                    echo "https proxy  : <unset>"
                    echo "socks5 proxy : <unset>" ;;
            esac
            ;;
    esac
}

unset_proxies() {
    kind="$1"
    case "$kind" in
        http) unset http_proxy HTTP_PROXY ;;
        https) unset https_proxy HTTPS_PROXY ;;
        socks5) unset all_proxy ALL_PROXY ;;
        all) unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY ;;
        *) echo "$PROGRAM_NAME: invalid unset type '$kind'" >&2; return 1 ;;
    esac
}

set_proxies() {
    ip="$1"; port="$2"; kind="$3"
    http="http://${ip}:${port}"
    socks="socks5://${ip}:${port}"

    case "$kind" in
        http)
            export http_proxy="$http" HTTP_PROXY="$http"
            ;;
        https)
            export https_proxy="$http" HTTPS_PROXY="$http"
            ;;
        socks5)
            export all_proxy="$socks" ALL_PROXY="$socks"
            ;;
        all)
            export http_proxy="$http" https_proxy="$http" all_proxy="$socks"
            export HTTP_PROXY="$http" HTTPS_PROXY="$http" ALL_PROXY="$socks"
            ;;
        *) echo "$PROGRAM_NAME: invalid type '$kind'" >&2; return 1 ;;
    esac
}

# ---- actions ----
# combo: unset + set
if [ -n "$UNSET_TYPE" ] && [ -n "$IP" ] && [ -n "$PORT" ]; then
    unset_proxies "$UNSET_TYPE"
    pretty_show "" "" "$UNSET_TYPE" unset
    set_proxies "$IP" "$PORT" "$TYPE"
    pretty_show "$IP" "$PORT" "$TYPE" set
    return 0
fi

# only unset
if [ -n "$UNSET_TYPE" ]; then
    unset_proxies "$UNSET_TYPE"
    pretty_show "" "" "$UNSET_TYPE" unset
    return 0
fi

# only set
if [ -n "$IP" ] && [ -n "$PORT" ]; then
    unset_proxies "$TYPE"   # no log
    set_proxies "$IP" "$PORT" "$TYPE"
    pretty_show "$IP" "$PORT" "$TYPE" set
    return 0
fi

# show current
if [ "$DO_SHOW" -eq 1 ]; then
    show_current
    return 0
fi

# default: help
print_help
