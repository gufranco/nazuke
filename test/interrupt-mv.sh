"${REAL}" "$@"
moved=$?
if [ "$3" = GRANDTA ]; then
  pid="${PPID}"
  top=""
  hops=0
  while [ "${hops}" -lt 12 ] && [ "${pid:-1}" -gt 1 ]; do
    case "$(ps -o comm= -p "${pid}"):$(ps -o args= -p "${pid}")" in
    *sh:*bin/nazuke*) top="${pid}" ;;
    *) [ -z "${top}" ] || break ;;
    esac
    pid="$(ps -o ppid= -p "${pid}" | tr -d " ")"
    hops=$((hops + 1))
  done
  kill -TERM "${top}"
fi
exit "${moved}"
