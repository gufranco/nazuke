"${REAL}" "$@"
moved=$?
describe() {
  if [ -r "/proc/$1/stat" ]; then
    printf '%s:%s\n' "$(cat "/proc/$1/comm")" "$(tr '\0' ' ' <"/proc/$1/cmdline")"
    return
  fi
  printf '%s:%s\n' "$(ps -o comm= -p "$1")" "$(ps -o args= -p "$1")"
}
parent_of() {
  if [ -r "/proc/$1/stat" ]; then
    sed 's/.*) //' "/proc/$1/stat" | cut -d ' ' -f 2
    return
  fi
  ps -o ppid= -p "$1" | tr -d ' '
}
if [ "$3" = GRANDTA ]; then
  pid="${PPID}"
  top=""
  hops=0
  while [ "${hops}" -lt 12 ] && [ "${pid:-1}" -gt 1 ]; do
    case "$(describe "${pid}")" in
    *sh:*bin/nazuke*) top="${pid}" ;;
    *) [ -z "${top}" ] || break ;;
    esac
    pid="$(parent_of "${pid}")"
    hops=$((hops + 1))
  done
  kill -TERM "${top}"
fi
exit "${moved}"
