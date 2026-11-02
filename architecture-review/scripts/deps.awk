# Module-level dependency extractor for the architecture-review skill.
# Input: file list, one relative path per line (see deps.sh).
# Vars:  depth   path components per module key (after the common prefix)
#        gomod   Go module path from go.mod, godir its directory
#        godot   directory of project.godot ("" = root)
#        mermaid non-empty: also print a Mermaid graph
# Output sections: module edges, cycles, modules, unresolved imports.

function dirof(p) {
  if (index(p, "/") == 0) return ""
  sub(/\/[^\/]*$/, "", p)
  return p
}

function join(a, b) {
  if (a == "") return b
  if (b == "") return a
  return a "/" b
}

function ext(p) {
  if (match(p, /\.[^.\/]+$/)) return tolower(substr(p, RSTART + 1))
  return ""
}

function normalize(p,    parts, n, i, out, k, res) {
  n = split(p, parts, "/")
  k = 0
  for (i = 1; i <= n; i++) {
    if (parts[i] == "" || parts[i] == ".") continue
    if (parts[i] == "..") { if (k > 0) k--; continue }
    out[++k] = parts[i]
  }
  res = ""
  for (i = 1; i <= k; i++) res = res (i > 1 ? "/" : "") out[i]
  return res
}

function common_prefix(    i, p) {
  p = dirof(files[1])
  p = (p == "" ? "" : p "/")
  for (i = 2; i <= nf && p != ""; i++)
    while (p != "" && index(files[i], p) != 1) sub(/[^\/]*\/$/, "", p)
  return p
}

function modkey(p,    d, a, n, j, k) {
  if (prefix != "" && index(p, prefix) == 1) p = substr(p, length(prefix) + 1)
  d = dirof(p)
  if (d == "") return "(root)"
  n = split(d, a, "/")
  k = a[1]
  for (j = 2; j <= n && j <= depth; j++) k = k "/" a[j]
  return k
}

function edge(f, t, label,    a, b) {
  a = modkey(f)
  b = modkey(t)
  nrefs++
  if (a == b) return
  e[a SUBSEP b]++
  if (!((a SUBSEP b) in sample)) sample[a SUBSEP b] = f ":" ln " " label
  mods[a] = 1
  mods[b] = 1
}

function unresolved(f, spec) {
  nu++
  if (nu <= 15) unres[nu] = f ":" ln " " spec
}

# ---------- declarations (pass 1) ----------

function declare(f,    e2, line, name) {
  e2 = ext(f)
  if (e2 != "java" && e2 != "kt" && e2 != "cs" && e2 != "gd") return
  while ((getline line < f) > 0) {
    sub(/\r$/, "", line)
    if ((e2 == "java" || e2 == "kt") \
        && match(line, /^[ \t]*package[ \t]+[A-Za-z0-9_.]+/)) {
      name = substr(line, RSTART, RLENGTH)
      sub(/^[ \t]*package[ \t]+/, "", name)
      if (!(name in pkgdir)) pkgdir[name] = dirof(f)
      break
    }
    if (e2 == "cs" && match(line, /^[ \t]*namespace[ \t]+[A-Za-z0-9_.]+/)) {
      name = substr(line, RSTART, RLENGTH)
      sub(/^[ \t]*namespace[ \t]+/, "", name)
      if (!(name in nsdir)) nsdir[name] = dirof(f)
    }
    if (e2 == "gd" && match(line, /^class_name[ \t]+[A-Za-z0-9_]+/)) {
      name = substr(line, RSTART, RLENGTH)
      sub(/^class_name[ \t]+/, "", name)
      gdclass[name] = f
      break
    }
  }
  close(f)
}

# ---------- resolvers ----------

function resolve_js(t,    i, n, ex) {
  if (t in known) return t
  n = split("ts tsx js jsx mjs cjs vue svelte", ex, " ")
  for (i = 1; i <= n; i++) if ((t "." ex[i]) in known) return t "." ex[i]
  for (i = 1; i <= n; i++)
    if ((t "/index." ex[i]) in known) return t "/index." ex[i]
  if (t in dirs) return t "/_"
  return ""
}

# Resolves module path m ("a/b/c") below base; drops trailing components of m
# only ("from a.b import c" may name a function), never of base.
function resolve_py(base, m,    q, p) {
  q = m
  while (q != "") {
    p = join(base, q)
    if ((p ".py") in known) return p ".py"
    if (p in dirs) return p "/_"
    q = dirof(q)
  }
  return ""
}

function by_suffix(inc,    b, n, cands, i, hit, c) {
  b = inc
  sub(/^.*\//, "", b)
  if (!(b in byname)) return ""
  n = split(byname[b], cands, SUBSEP)
  hit = ""
  for (i = 1; i <= n; i++) {
    c = cands[i]
    if (c == "") continue
    if (c == inc || substr(c, length(c) - length(inc)) == "/" inc) hit = c
  }
  return hit
}

function ns_edge(f, m, map,    q) {
  q = m
  while (q != "") {
    if (q in map) { edge(f, join(map[q], "_"), m); return }
    if (index(q, ".") == 0) return
    sub(/\.[^.]*$/, "", q)
  }
}

# ---------- per-language line handlers (pass 2) ----------

function js_line(f, line,    s, spec, t, r) {
  s = line
  while (match(s, /(from|require\(|import\(|^[ \t]*import)[ \t]*["'][^"']+["']/)) {
    spec = substr(s, RSTART, RLENGTH)
    s = substr(s, RSTART + RLENGTH)
    sub(/^[^"']*["']/, "", spec)
    sub(/["']$/, "", spec)
    if (spec ~ /\.(css|scss|sass|less|json|svg|png|jpe?g|gif|webp|ico)$/) continue
    if (spec ~ /^\./) {
      t = normalize(join(dirof(f), spec))
      r = resolve_js(t)
      if (r != "") edge(f, r, spec)
      else unresolved(f, spec)
    } else if (spec ~ /^[@~]\//) {
      r = resolve_js("src/" substr(spec, 3))
      if (r == "") r = resolve_js(substr(spec, 3))
      if (r != "") edge(f, r, spec)
      else unresolved(f, spec)
    }
  }
}

function py_mod(f, m,    orig, dots, base, rest, r, a) {
  orig = m
  if (m ~ /^\./) {
    match(m, /^\.+/)
    dots = RLENGTH
    rest = substr(m, dots + 1)
    base = dirof(f)
    while (--dots > 0) base = dirof(base)
    gsub(/\./, "/", rest)
    r = (rest == "") ? join(base, "_") : resolve_py(base, rest)
    if (r != "") edge(f, r, orig)
    else unresolved(f, orig)
    return
  }
  gsub(/\./, "/", m)
  a = dirof(f)
  while (1) {
    r = resolve_py(a, m)
    if (r != "") { edge(f, r, orig); return }
    if (a == "") return
    a = dirof(a)
  }
}

function py_line(f, line,    m, mods2, n, i, name) {
  if (match(line, /^[ \t]*from[ \t]+[.A-Za-z0-9_]+[ \t]+import/)) {
    m = substr(line, RSTART, RLENGTH)
    sub(/^[ \t]*from[ \t]+/, "", m)
    sub(/[ \t]+import$/, "", m)
    py_mod(f, m)
  } else if (match(line, /^[ \t]*import[ \t]+[A-Za-z0-9_., \t]+/)) {
    m = substr(line, RSTART, RLENGTH)
    sub(/^[ \t]*import[ \t]+/, "", m)
    n = split(m, mods2, ",")
    for (i = 1; i <= n; i++) {
      name = mods2[i]
      sub(/^[ \t]+/, "", name)
      sub(/[ \t]+as[ \t].*$/, "", name)
      sub(/[ \t]+$/, "", name)
      if (name != "") py_mod(f, name)
    }
  }
}

function jvm_line(f, line,    m) {
  if (!match(line, /^[ \t]*import[ \t]+(static[ \t]+)?[A-Za-z0-9_.*]+/)) return
  m = substr(line, RSTART, RLENGTH)
  sub(/^[ \t]*import[ \t]+(static[ \t]+)?/, "", m)
  sub(/\.\*$/, "", m)
  ns_edge(f, m, pkgdir)
}

function cs_line(f, line,    m) {
  if (!match(line, /^[ \t]*(global[ \t]+)?using[ \t]+(static[ \t]+)?([A-Za-z0-9_]+[ \t]*=[ \t]*)?[A-Za-z0-9_.]+[ \t]*;/)) return
  m = substr(line, RSTART, RLENGTH)
  sub(/^[ \t]*(global[ \t]+)?using[ \t]+(static[ \t]+)?([A-Za-z0-9_]+[ \t]*=[ \t]*)?/, "", m)
  sub(/[ \t]*;$/, "", m)
  ns_edge(f, m, nsdir)
}

function c_line(f, line,    inc, t, r) {
  if (!match(line, /^[ \t]*#[ \t]*include[ \t]*["<][^">]+[">]/)) return
  inc = substr(line, RSTART, RLENGTH)
  sub(/^[^"<]*["<]/, "", inc)
  sub(/[">]$/, "", inc)
  t = normalize(join(dirof(f), inc))
  if (t in known) { edge(f, t, inc); return }
  r = by_suffix(inc)
  if (r != "") edge(f, r, inc)
  else if (line ~ /#[ \t]*include[ \t]*"/) unresolved(f, inc)
}

function go_line(f, line, inimp,    spec, rel) {
  if (line ~ /^[ \t]*import[ \t]*\([ \t]*$/) return 1
  if (inimp && line ~ /^[ \t]*\)/) return 0
  if ((inimp || line ~ /^[ \t]*import[ \t]/) && match(line, /"[^"]+"/)) {
    spec = substr(line, RSTART + 1, RLENGTH - 2)
    if (gomod != "" && index(spec, gomod "/") == 1) {
      rel = substr(spec, length(gomod) + 2)
      edge(f, join(join(godir, rel), "_"), spec)
    }
  }
  return inimp
}

function gd_line(f, line,    s, p, n, toks, i) {
  if (line ~ /^[ \t]*#/) return
  s = line
  while (match(s, /res:\/\/[^"']+/)) {
    p = substr(s, RSTART + 6, RLENGTH - 6)
    s = substr(s, RSTART + RLENGTH)
    edge(f, join(godot, p), "res://" p)
  }
  n = split(line, toks, /[^A-Za-z0-9_]+/)
  for (i = 1; i <= n; i++)
    if ((toks[i] in gdclass) && gdclass[toks[i]] != f)
      edge(f, gdclass[toks[i]], toks[i])
}

function scan(f,    e2, line, inimp) {
  e2 = ext(f)
  inimp = 0
  ln = 0
  while ((getline line < f) > 0) {
    ln++
    sub(/\r$/, "", line)
    if (e2 ~ /^(js|jsx|ts|tsx|mjs|cjs|vue|svelte)$/) js_line(f, line)
    else if (e2 == "py") py_line(f, line)
    else if (e2 == "java" || e2 == "kt") jvm_line(f, line)
    else if (e2 == "cs") cs_line(f, line)
    else if (e2 ~ /^(c|cc|cpp|cxx|h|hh|hpp|hxx)$/) c_line(f, line)
    else if (e2 == "go") inimp = go_line(f, line, inimp)
    else if (e2 == "gd") gd_line(f, line)
  }
  close(f)
}

# ---------- output ----------

# Prints lines[1..n] sorted (insertion sort; module graphs are small).
function print_sorted(lines, n,    i, j, t) {
  for (i = 2; i <= n; i++) {
    t = lines[i]
    for (j = i - 1; j >= 1 && lines[j] > t; j--) lines[j + 1] = lines[j]
    lines[j + 1] = t
  }
  for (i = 1; i <= n; i++) print lines[i]
}

# Tarjan's algorithm: prints strongly connected components with > 1 module.
function strong(v,    k, p, w, comp, cnt) {
  idx[v] = ++counter
  low[v] = counter
  stk[++sp] = v
  onst[v] = 1
  for (k in e) {
    split(k, p, SUBSEP)
    if (p[1] != v) continue
    w = p[2]
    if (!(w in idx)) {
      strong(w)
      if (low[w] < low[v]) low[v] = low[w]
    } else if (onst[w] && idx[w] < low[v]) {
      low[v] = idx[w]
    }
  }
  if (low[v] == idx[v]) {
    comp = ""
    cnt = 0
    do {
      w = stk[sp--]
      onst[w] = 0
      comp = comp (cnt++ ? ", " : "") w
    } while (w != v)
    if (cnt > 1) {
      ncyc++
      print "SCC " ncyc " (" cnt " modules): " comp
    }
  }
}

function mid(m,    s) {
  s = m
  gsub(/[^A-Za-z0-9_]/, "_", s)
  return "m_" s
}

function output(    k, p, n, m, lines, fo, fi, two) {
  printf "# %d files, common prefix '%s', depth %d, %d resolved references\n", \
    nf, prefix, depth, nrefs
  print "## module edges (from -> to: references | first sample)"
  n = 0
  for (k in e) {
    split(k, p, SUBSEP)
    lines[++n] = p[1] " -> " p[2] ": " e[k] " | " sample[k]
    fo[p[1]]++
    fi[p[2]]++
  }
  if (n == 0) print "none"
  print_sorted(lines, n)

  print "## cycles (strongly connected components)"
  for (m in mods) if (!(m in idx)) strong(m)
  if (ncyc == 0) print "none"

  print "## two-module cycles (A <-> B: refs A->B / B->A)"
  n = 0
  delete lines
  for (k in e) {
    split(k, p, SUBSEP)
    if (((p[2] SUBSEP p[1]) in e) && p[1] < p[2])
      lines[++n] = p[1] " <-> " p[2] ": " e[k] " / " e[p[2] SUBSEP p[1]]
  }
  if (n == 0) print "none"
  print_sorted(lines, n)

  print "## modules (files, fan-in = modules depending on it, fan-out)"
  n = 0
  delete lines
  for (m in modfiles) mods[m] = 1
  for (m in mods)
    lines[++n] = sprintf("%s: %d files, fan-in %d, fan-out %d", \
      m, modfiles[m], fi[m], fo[m])
  print_sorted(lines, n)

  print "## unresolved internal-looking imports (" nu + 0 " total, sample)"
  if (nu == 0) print "none"
  for (k = 1; k <= nu && k <= 15; k++) print unres[k]

  if (mermaid != "") {
    print "## mermaid"
    print "graph LR"
    for (k in e) {
      split(k, p, SUBSEP)
      print "  " mid(p[1]) "[\"" p[1] "\"] --> " mid(p[2]) "[\"" p[2] "\"]"
    }
  }
}

{
  sub(/\r$/, "")
  if ($0 == "") next
  files[++nf] = $0
  known[$0] = 1
  d = dirof($0)
  while (d != "" && !(d in dirs)) {
    dirs[d] = 1
    d = dirof(d)
  }
  b = $0
  sub(/^.*\//, "", b)
  byname[b] = byname[b] SUBSEP $0
}

END {
  if (depth == "" || depth + 0 < 1) depth = 2
  depth += 0
  prefix = common_prefix()
  for (i = 1; i <= nf; i++) declare(files[i])
  for (i = 1; i <= nf; i++) {
    scan(files[i])
    modfiles[modkey(files[i])]++
  }
  output()
}
