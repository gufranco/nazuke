function split_subtitle(title,   seps, count, i, at) {
  count = split(" - |: | -- ", seps, "|")
  for (i = 1; i <= count; i++) {
    at = index(title, seps[i])
    if (at) {
      sub_head = trim(substr(title, 1, at - 1))
      sub_tail = trim(substr(title, at + length(seps[i])))
      return
    }
  }
  sub_head = trim(title)
  sub_tail = ""
}

function tokenize(s, out,   upper, n) {
  upper = toupper(s)
  gsub(/&/, " AND ", upper)
  n = 0
  while (match(upper, /[A-Z]+|[0-9]+/)) {
    out[++n] = substr(upper, RSTART, RLENGTH)
    upper = substr(upper, RSTART + RLENGTH)
  }
  return n
}

function is_digits(t) {
  return t ~ /^[0-9]+$/
}

function balanced(tok, n, maxlen, out,   i, size, alpha, fixed, total, budget, best) {
  alpha = 0
  fixed = 0
  total = 0
  for (i = 1; i <= n; i++) {
    if (is_digits(tok[i])) {
      fixed += length(tok[i])
    } else {
      alpha++
      size[i] = length(tok[i])
      total += size[i]
    }
  }
  budget = maxlen - fixed
  if (alpha == 0 || budget < alpha) { return 0 }
  while (total > budget) {
    best = 0
    for (i = 1; i <= n; i++) {
      if ((i in size) && (best == 0 || size[i] > size[best])) { best = i }
    }
    size[best]--
    total--
  }
  for (i = 1; i <= n; i++) {
    out[i] = (i in size) ? substr(tok[i], 1, size[i]) : tok[i]
  }
  return 1
}

function joined(parts, n,   i, s) {
  s = ""
  for (i = 1; i <= n; i++) { s = s parts[i] }
  return s
}

function score(parts, np, source, ns, dropped, nd, maxlen, initials,   name, truncated, whole, last_whole, i, cost, value, digits, all_in, first_alpha, single) {
  scored_ok = 0
  name = joined(parts, np)
  if (name == "" || length(name) > maxlen) { return 0 }
  truncated = 0
  whole = 0
  last_whole = 0
  if (initials) {
    if (length(name) < 3) { return 0 }
    truncated = 1
  } else {
    for (i = 1; i <= ns && i <= np; i++) {
      if (length(parts[i]) < length(source[i])) { truncated++ }
      if (source[i] == parts[i] && length(source[i]) > 1 && !is_digits(source[i])) { whole++ }
    }
    for (i = 0; i < ns && i < np; i++) {
      if (!is_digits(source[ns - i])) {
        last_whole = (source[ns - i] == parts[np - i]) ? 2 : 0
        break
      }
    }
  }
  cost = 0
  for (i = 1; i <= nd; i++) { cost += (dropped[i] in droppable) ? 1 : 10 }
  value = 2 * whole + last_whole - 3 * truncated - cost
  digits = 0
  all_in = 1
  first_alpha = ""
  for (i = 1; i <= ns; i++) {
    if (is_digits(source[i])) {
      digits++
      if (!index(name, source[i])) { all_in = 0 }
    } else if (first_alpha == "") {
      first_alpha = source[i]
    }
  }
  if (digits && all_in) { value += 2 }
  if (nd == 0 && first_alpha != "" && !(first_alpha in droppable)) { value += 3 }
  value += length(name)
  single = 0
  for (i = 1; i <= np; i++) {
    if (length(parts[i]) == 1 && !is_digits(parts[i])) { single++ }
  }
  scored_ok = 1
  return value - 3 * single
}

function offer(parts, np, source, ns, dropped, nd, maxlen, initials,   value) {
  value = score(parts, np, source, ns, dropped, nd, maxlen, initials)
  if (!scored_ok) { return }
  offered++
  offer_value[offered] = value
  offer_name[offered] = joined(parts, np)
}

function ahead(a, b) {
  if (offer_value[a] != offer_value[b]) { return offer_value[a] > offer_value[b] }
  if (length(offer_name[a]) != length(offer_name[b])) { return length(offer_name[a]) < length(offer_name[b]) }
  return offer_name[a] > offer_name[b]
}

function best_offer(   i, best) {
  best = 0
  for (i = 1; i <= offered; i++) {
    if (best == 0 || ahead(i, best)) { best = i }
  }
  return best
}

function generate_head(base, nb, dropped, nd, maxlen,   i, first, alphas, design, out) {
  alphas = 0
  first = 0
  for (i = 1; i <= nb; i++) {
    if (!is_digits(base[i])) {
      alphas++
      if (!first) { first = i }
    }
  }
  if (alphas < 2) { return }
  for (i = 1; i <= nb; i++) {
    design[i] = (i == first || is_digits(base[i])) ? base[i] : substr(base[i], 1, 1)
  }
  if (balanced(design, nb, maxlen, out)) { offer(out, nb, design, nb, dropped, nd, maxlen, 0) }
}

function generate_initials(base, nb, dropped, nd, maxlen,   i, letters, alphas, built, nbuilt, placed) {
  letters = ""
  alphas = 0
  for (i = 1; i <= nb; i++) {
    if (!is_digits(base[i])) {
      alphas++
      letters = letters substr(base[i], 1, 1)
    }
  }
  if (alphas < 2) { return }
  nbuilt = 0
  placed = 0
  for (i = 1; i <= nb; i++) {
    if (is_digits(base[i])) {
      built[++nbuilt] = base[i]
    } else if (!placed) {
      built[++nbuilt] = letters
      placed = 1
    }
  }
  offer(built, nbuilt, base, nb, dropped, nd, maxlen, 1)
}

function generate(base, nb, dropped, nd, maxlen,   out) {
  offer(base, nb, base, nb, dropped, nd, maxlen, 0)
  if (balanced(base, nb, maxlen, out)) { offer(out, nb, base, nb, dropped, nd, maxlen, 0) }
  generate_head(base, nb, dropped, nd, maxlen)
  generate_initials(base, nb, dropped, nd, maxlen)
}

function with_tail(main, nm, tail, nt, maxlen,   drop, alphas, i, seen, base, nb, dropped, nd) {
  alphas = 0
  for (i = 1; i <= nm; i++) {
    if (!is_digits(main[i])) { alphas++ }
  }
  if (alphas < 1) { alphas = 1 }
  for (drop = 0; drop < alphas; drop++) {
    split("", base)
    split("", dropped)
    nb = 0
    nd = 0
    seen = 0
    for (i = 1; i <= nm; i++) {
      if (!is_digits(main[i])) {
        seen++
        if (seen <= drop) {
          dropped[++nd] = main[i]
          continue
        }
      }
      base[++nb] = main[i]
    }
    if (nb == 0) { continue }
    for (i = 1; i <= nt; i++) { base[++nb] = tail[i] }
    generate(base, nb, dropped, nd, maxlen)
  }
}

function shorten(title, maxlen,   all, nall, main, nm, sub_tokens, ns, tail, i, initials) {
  offered = 0
  split_subtitle(title)
  nall = tokenize(sub_head, all)
  nm = 0
  for (i = 1; i <= nall; i++) {
    if (!(all[i] in stop)) { main[++nm] = all[i] }
  }
  if (nm == 0) {
    for (i = 1; i <= nall; i++) { main[++nm] = all[i] }
  }
  ns = tokenize(sub_tail, sub_tokens)
  if (ns == 0) {
    with_tail(main, nm, tail, 0, maxlen)
  } else {
    if (length(joined(main, nm)) + length(joined(sub_tokens, ns)) <= maxlen) { with_tail(main, nm, sub_tokens, ns, maxlen) }
    initials = ""
    for (i = 1; i <= ns; i++) { initials = initials substr(sub_tokens[i], 1, 1) }
    tail[1] = initials
    with_tail(main, nm, tail, 1, maxlen)
  }
  i = best_offer()
  if (i) { return offer_name[i] }
  return substr(fallback, 1, maxlen)
}

function name_line(   tab) {
  tab = index($0, "\t")
  printf "%s\t%s\n", substr($0, 1, tab - 1), shorten(clean(substr($0, tab + 1)), max)
}

function full_name(name, ext) {
  if (ext == "") { return toupper(name) }
  return toupper(name "." ext)
}

function free_name(name, ext) {
  return !(toupper(name) in reserved) && !(full_name(name, ext) in used)
}

function remember(key, name) {
  result[key] = name
  used[full_name(name, ext_of[key])] = 1
}

function settle(key,   short, letter, candidate, counter, suffix) {
  short = shorten(title_of[key], max - 1)
  letter = region_of[key]
  candidate = substr(short letter, 1, max)
  if (free_name(candidate, ext_of[key])) {
    remember(key, candidate)
    return
  }
  for (counter = 1; counter < 1000; counter++) {
    suffix = letter counter
    candidate = substr(substr(short, 1, max - length(suffix)) suffix, 1, max)
    if (free_name(candidate, ext_of[key])) {
      remember(key, candidate)
      return
    }
  }
  result[key] = ""
}

function load_extensions(file,   line, field) {
  while ((getline line < file) > 0) {
    if (split(line, field, " ") == 2) { extension[field[1]] = field[2] }
  }
  close(file)
}

function short_extension(ext,   lower) {
  lower = tolower(ext)
  if (length(ext) > extmax && (lower in extension) && length(extension[lower]) <= extmax) {
    return toupper(extension[lower])
  }
  return toupper(substr(ext, 1, extmax))
}

function assign_line(   field) {
  split($0, field, "\t")
  if (field[2] == "taken") {
    used[toupper(field[3])] = 1
    return
  }
  order[++nkeys] = field[1]
  ext_of[field[1]] = short_extension(field[4])
  title_of[field[1]] = clean(field[3])
  region_of[field[1]] = region_letter(clean_tags)
  base_of[field[1]] = shorten(title_of[field[1]], max)
  owner[field[1]] = (toupper(field[3]) == base_of[field[1]])
}

function sort_list(list, n, numeric,   i, j, value) {
  for (i = 2; i <= n; i++) {
    value = list[i]
    for (j = i - 1; j >= 1 && (numeric ? list[j] + 0 > value + 0 : list[j] > value); j--) { list[j + 1] = list[j] }
    list[j + 1] = value
  }
}

function settle_group(group, nmembers,   j, key, members, owned) {
  for (j = 1; j <= nmembers; j++) { members[j] = member[group, j] }
  sort_list(members, nmembers, 1)
  for (j = 1; j <= nmembers; j++) {
    key = members[j]
    if (owner[key] && free_name(base_of[key], ext_of[key])) {
      remember(key, base_of[key])
      owned[key] = 1
    }
  }
  for (j = 1; j <= nmembers; j++) {
    if (!(members[j] in owned)) { settle(members[j]) }
  }
}

function assign_all(   i, key, group, count, groups, ngroups, settled) {
  for (i = 1; i <= nkeys; i++) {
    key = order[i]
    group = full_name(base_of[key], ext_of[key])
    if (!(group in count)) { groups[++ngroups] = group }
    count[group]++
    member[group, count[group]] = key
  }
  sort_list(groups, ngroups, 0)
  for (i = 1; i <= ngroups; i++) {
    group = groups[i]
    key = member[group, 1]
    if (count[group] == 1 && free_name(base_of[key], ext_of[key])) {
      remember(key, base_of[key])
      settled[group] = 1
    }
  }
  for (i = 1; i <= ngroups; i++) {
    if (!(groups[i] in settled)) { settle_group(groups[i], count[groups[i]]) }
  }
  for (i = 1; i <= nkeys; i++) {
    key = order[i]
    printf "%s/%s/%s\n", key, result[key], ext_of[key]
  }
}

BEGIN {
  load_bytes()
  load_reserved()
  load_pack(pack)
  if (mode == "check") { exit pack_bad }
  load_translit(translit)
  if (mode == "assign") { load_extensions(extensions) }
}

mode == "name" { name_line() }
mode == "assign" { assign_line() }

END {
  if (mode == "assign") { assign_all() }
}
