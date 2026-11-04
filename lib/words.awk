function load_translit(file,   line, tab) {
  while ((getline line < file) > 0) {
    tab = index(line, "\t")
    if (tab > 1) {
      tr[substr(line, 1, tab - 1)] = substr(line, tab + 1)
    }
  }
  close(file)
}

function pack_fail(number, reason) {
  printf "%d\t%s\n", number, reason
  pack_bad = 1
}

function pack_words(field, count, kind, number, pattern,   i) {
  if (count < 2) {
    pack_fail(number, kind " needs at least one word")
    return
  }
  for (i = 2; i <= count; i++) {
    if (field[i] !~ pattern) {
      pack_fail(number, kind " holds an invalid word: " field[i])
      return
    }
    if (kind == "stopwords") { stop[field[i]] = 1 }
    if (kind == "droppable") { droppable[field[i]] = 1 }
    if (kind == "articles") { article[++narticles] = field[i] }
  }
}

function pack_line(line, number,   field, count) {
  count = split(line, field, " ")
  if (count == 0) { return }
  if (field[1] == "fallback") {
    if (count != 2 || field[2] !~ /^[A-Z0-9]+$/) { pack_fail(number, "fallback needs one word of A to Z and 0 to 9"); return }
    fallback = field[2]
  } else if (field[1] == "region") {
    if (count != 3 || field[2] !~ /^[A-Z]+$/ || field[3] !~ /^[A-Z0-9]$/) { pack_fail(number, "region needs a word and one letter or digit"); return }
    rword[++nregions] = field[2]
    rletter[nregions] = field[3]
  } else if (field[1] == "stopwords" || field[1] == "droppable") {
    pack_words(field, count, field[1], number, "^[A-Z0-9]+$")
  } else if (field[1] == "articles") {
    pack_words(field, count, field[1], number, "^[A-Z]+$")
  } else {
    pack_fail(number, "unknown key: " field[1])
  }
}

function load_pack(file,   line, number) {
  fallback = "FILE"
  while ((getline line < file) > 0) {
    pack_line(line, ++number)
  }
  close(file)
}

function load_reserved(   name, count, i) {
  count = split("CON PRN AUX NUL COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 COM9 LPT1 LPT2 LPT3 LPT4 LPT5 LPT6 LPT7 LPT8 LPT9", name, " ")
  for (i = 1; i <= count; i++) { reserved[name[i]] = 1 }
}

function load_bytes(   i) {
  for (i = 1; i < 32; i++) { control[sprintf("%c", i)] = 1 }
  control[sprintf("%c", 127)] = 1
  for (i = 128; i < 256; i++) { byte[sprintf("%c", i)] = i }
}

function sequence_length(b) {
  if (b >= 240) { return 4 }
  if (b >= 224) { return 3 }
  if (b >= 192) { return 2 }
  return 1
}

function combining(seq,   first, second) {
  if (length(seq) != 2) { return 0 }
  first = byte[substr(seq, 1, 1)]
  second = byte[substr(seq, 2, 1)]
  if (first == 204) { return 1 }
  return first == 205 && second < 176
}

function plain_text(s,   out, i, n, c, size, seq) {
  out = ""
  n = length(s)
  i = 1
  while (i <= n) {
    c = substr(s, i, 1)
    if (c in control) {
      out = out " "
      i++
      continue
    }
    if (!(c in byte)) {
      out = out c
      i++
      continue
    }
    size = sequence_length(byte[c])
    seq = substr(s, i, size)
    if (seq in tr) {
      out = out tr[seq]
    } else if (!combining(seq)) {
      out = out seq
    }
    i += size
  }
  return out
}

function strip_edges(s) {
  sub(/^[- _.]+/, "", s)
  sub(/[- _.]+$/, "", s)
  return s
}

function trim(s) {
  sub(/^ +/, "", s)
  sub(/ +$/, "", s)
  return s
}

function drop_trailing_article(s, word,   upper) {
  upper = toupper(s)
  if (match(upper, ", *" word "$")) { s = substr(s, 1, RSTART - 1) }
  return s
}

function join_article_dash(s, word,   upper, out) {
  out = ""
  upper = toupper(s)
  while (match(upper, ", *" word " +-")) {
    out = out substr(s, 1, RSTART - 1) " -"
    s = substr(s, RSTART + RLENGTH)
    upper = substr(upper, RSTART + RLENGTH)
  }
  return out s
}

function drop_leading_article(s,   upper, i) {
  upper = toupper(s)
  for (i = 1; i <= narticles; i++) {
    if (match(upper, "^" article[i] " +")) { return substr(s, RLENGTH + 1) }
  }
  return s
}

function word_byte(c) {
  return c ~ /^[A-Za-z0-9_]$/ || (c in byte)
}

function drop_possessive(s,   out, i, n, c, after) {
  out = ""
  n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (c == "'" && i < n && substr(s, i + 1, 1) ~ /^[sS]$/) {
      after = substr(s, i + 2, 1)
      if (after == "" || !word_byte(after)) {
        i++
        continue
      }
    }
    out = out c
  }
  return out
}

function clean(raw,   s, inner, i) {
  s = plain_text(raw)
  clean_tags = ""
  while (match(s, /[[(][^])]*[])]/)) {
    inner = substr(s, RSTART + 1, RLENGTH - 2)
    clean_tags = clean_tags " " inner
    s = substr(s, 1, RSTART - 1) " " substr(s, RSTART + RLENGTH)
  }
  s = strip_edges(s)
  for (i = 1; i <= narticles; i++) {
    s = drop_trailing_article(s, article[i])
    s = join_article_dash(s, article[i])
  }
  s = drop_leading_article(s)
  s = drop_possessive(s)
  gsub(/ +/, " ", s)
  return trim(s)
}

function region_letter(tags,   upper, i) {
  upper = toupper(tags)
  for (i = 1; i <= nregions; i++) {
    if (index(upper, rword[i])) { return rletter[i] }
  }
  return ""
}
