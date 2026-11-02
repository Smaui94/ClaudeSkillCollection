# Declaration-aware checks for Google Java style + mandatory Javadoc (gawk).
# Tracks braces/parens on comment- and string-stripped code, classifies every
# brace as type body (T/E/I), method body (M), switch (S) or other block (B),
# and checks each declaration found directly inside a type body.
# Output: "ID<TAB>file:line:message". Env: JDOC_SCOPE=all (default) | visible.

BEGIN {
  scope = ENVIRON["JDOC_SCOPE"]
  if (scope == "") scope = "all"
  MODS = "public|protected|private|abstract|static|final|synchronized|native|default|strictfp|sealed|non-sealed|transient|volatile"
  IMPERATIVE = "^(Get|Set|Return|Create|Open|Close|Add|Remove|Check|Compute|Calculate|Build|Load|Save|Read|Write|Find|Make|Start|Stop|Run|Handle|Update|Initialize|Init|Parse|Convert|Validate|Print|Show|Draw|Reset|Clear|Execute|Process|Send|Call|Use|Apply|Register|Delete|Insert|Copy|Move|Generate|Determine|Ensure|Verify|Display|Render|Toggle|Fetch|Store|Put|Append|Compare|Count|Merge|Sort|Filter|Throw|Test)$"
}

function out(id, line, msg) { printf "%s\t%s:%d:%s\n", id, FILENAME, line, msg }
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }

BEGINFILE {
  base = FILENAME; sub(/^.*[\/\\]/, "", base); sub(/\.java$/, "", base)
  if (base == "module-info") nextfile
  isTest = (base ~ /Tests?$/)
  depth = 0; delete kind; delete enumPhase; delete swDef; delete swStmt; delete swTerm; delete swFall
  delete seen; delete last; delete bodyId
  hdr = ""; hdrLine = 0; pd = 0
  inDoc = 0; inBlock = 0; inText = 0; mdDoc = 0
  docPending = 0; implPending = 0; hdrDoc = 0; hdrImpl = 0
  topTypes = 0; topName = ""; hasPackage = 0
  impStarted = 0; impBlank = 0
}

ENDFILE {
  if (base == "package-info") { if (!hasPackage) out("O2", 1, "missing package declaration"); }
  else if (FNR > 0) {
    if (!hasPackage) out("O2", 1, "missing package declaration")
    if (topTypes >= 1 && topName != base) out("O1", 1, "file name must match top-level class: " topName ".java")
  }
}

# ---------------------------------------------------------------- line loop
{
  raw = $0
  if (inText) {
    p = index(raw, "\"\"\"")
    if (!p) next
    inText = 0; raw = substr(raw, p + 3)
  }
  if (inDoc) {
    doc[++docN] = raw
    if (index(raw, "*/")) { inDoc = 0; finishDoc() }
    next
  }
  if (inBlock) {
    p = index(raw, "*/")
    if (!p) next
    inBlock = 0; raw = substr(raw, p + 2)
  }
  if (raw ~ /^[ \t]*\/\/\//) {
    if (!mdDoc) { docN = 0; docStart = FNR; mdDoc = 1; docMd = 1 }
    doc[++docN] = raw
    next
  }
  if (mdDoc) { mdDoc = 0; finishDoc() }
  if (raw ~ /^[ \t]*\/\*\*/ && raw !~ /^[ \t]*\/\*\*\//) {
    docN = 0; docStart = FNR; docMd = 0; doc[++docN] = raw
    if (index(substr(raw, index(raw, "/**") + 3), "*/")) finishDoc(); else inDoc = 1
    next
  }
  if (raw ~ /^[ \t]*$/) { if (impStarted) impBlank = 1; next }

  code = strip(raw)
  if (code ~ /^[ \t]*$/) {
    if (hdr == "") implPending = 1
    if (ctx() == "S" && tolower(raw) ~ /fall.?s? ?through/) swFall[depth] = 1
    next
  }
  if (code ~ /^[ \t]*package[ \t]/) { hasPackage = 1; next }
  if (code ~ /^[ \t]*import[ \t]/) { checkImport(code); next }
  if (impStarted) impStarted = 0
  if (ctx() == "S") switchLine(code, raw)
  scan(code)
}

# Removes string/char literals and comments; maintains inBlock/inText.
function strip(s,   p, q, rest) {
  p = index(s, "\"\"\"")
  if (p) {
    rest = substr(s, p + 3); q = index(rest, "\"\"\"")
    if (q) s = substr(s, 1, p - 1) "\"\"" substr(rest, q + 3)
    else { s = substr(s, 1, p - 1) "\"\""; inText = 1 }
  }
  gsub(/"([^"\\]|\\.)*"/, "\"\"", s)
  gsub(/'([^'\\]|\\.)*'/, "''", s)
  while (1) {
    p = index(s, "//"); q = index(s, "/*")
    if (q && (!p || q < p)) {
      rest = substr(s, q + 2)
      if (index(rest, "*/")) { s = substr(s, 1, q - 1) " " substr(rest, index(rest, "*/") + 2); continue }
      s = substr(s, 1, q - 1); inBlock = 1
      if (s ~ /^[ \t]*$/ && hdr == "") implPending = 1
      break
    }
    if (p) s = substr(s, 1, p - 1)
    break
  }
  return s
}

function ctx() { return depth == 0 ? "F" : kind[depth] }
function isTypeCtx(c) { return c == "F" || c == "T" || c == "E" || c == "I" }

function scan(s,   i, n, c) {
  n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (c == "(") pd++
    else if (c == ")") { if (pd > 0) pd-- }
    if (pd == 0 && c == "{") { openBrace(); continue }
    if (pd == 0 && c == ";") { semi(); continue }
    if (pd == 0 && c == "}") { closeBrace(); continue }
    if (hdr == "") {
      if (c ~ /[ \t]/) continue
      hdrLine = FNR; hdrDoc = docPending; hdrImpl = implPending; docPending = 0
    }
    hdr = hdr c
  }
  if (hdr != "") hdr = hdr " "
}

function resetHdr() { hdr = ""; docPending = 0; implPending = 0; hdrDoc = 0; hdrImpl = 0 }

function openBrace(   c, k) {
  c = ctx(); k = "B"
  if (isTypeCtx(c)) {
    if (!(c == "E" && enumPhase[depth])) k = decl(1)
  } else if (hdr ~ /(^|[^A-Za-z0-9_$.])(class|interface|enum|record)[ \t]+[A-Za-z_]/) {
    k = typeKind(hdr)
  } else if (hdr ~ /^[ \t]*switch[ \t]*\(/) {
    k = "S"   # switch statement; switch expressions are exhaustive by the compiler
  }
  depth++; kind[depth] = k; bodyId[depth] = ++bodyCounter
  enumPhase[depth] = (k == "E"); swDef[depth] = 0; swStmt[depth] = 0; swTerm[depth] = 0; swFall[depth] = 0
  resetHdr()
}

function semi(   c) {
  c = ctx()
  if (isTypeCtx(c) && hdr !~ /^[ \t]*$/) {
    if (c == "E" && enumPhase[depth]) enumPhase[depth] = 0
    else decl(0)
  } else if (c == "E" && enumPhase[depth]) enumPhase[depth] = 0
  resetHdr()
}

function closeBrace() {
  if (depth > 0) {
    if (kind[depth] == "S" && !swDef[depth]) out("P5", FNR, "switch without default label (every switch must be exhaustive)")
    depth--
  }
  resetHdr()
}

function typeKind(h) {
  if (h ~ /@interface/) return "I"
  if (h ~ /(^|[^A-Za-z0-9_$])enum[ \t]/) return "E"
  if (h ~ /(^|[^A-Za-z0-9_$])interface[ \t]/) return "I"
  return "T"
}

# --------------------------------------------------------------- declarations
# Returns the kind of the block opened by this declaration (when opening).
function decl(opening,   h, ov, k, name, p, e, pre, rest, plist, isCtor, ret, tp, vis, label, c, bid, key, np, nt) {
  h = hdr; c = ctx()
  ov = (h ~ /@Override([^A-Za-z0-9_]|$)/)
  if (h ~ /@interface/) { sub(/@interface/, "interface", h) }
  gsub(/@[A-Za-z_][A-Za-z0-9_.]*[ \t]*(\([^()]*(\([^()]*\)[^()]*)*\))?/, " ", h)
  h = trim(h)
  bid = depth == 0 ? 0 : bodyId[depth]

  # ---- type
  if (h ~ /(^|[^A-Za-z0-9_$])(class|interface|enum|record)[ \t]+[A-Za-z_]/) {
    k = typeKind(h)
    match(h, /(class|interface|enum|record)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*/)
    name = substr(h, RSTART, RLENGTH); sub(/^[a-z]+[ \t]+/, "", name)
    label = (h ~ /record[ \t]/) ? "record" : (k == "E" ? "enum" : (k == "I" ? "interface" : "class"))
    if (depth == 0) { topTypes++; if (topTypes == 1) topName = name; else out("O1", hdrLine, "more than one top-level class (" name ")") }
    if (name !~ /^[A-Z][A-Za-z0-9]*$/) out("N1", hdrLine, "class name not UpperCamelCase: " name)
    acronym(name, hdrLine)
    rest = substr(h, index(h, name) + length(name)); rest = trim(rest)
    if (substr(rest, 1, 1) == "<") typeVars(bracket(rest, 1, "<", ">"), hdrLine)
    np = 0
    if (label == "record" && index(rest, "(")) np = params(bracket(rest, index(rest, "("), "(", ")"), P)
    last[bid] = ""
    vis = (h ~ /(^|[ \t])(public|protected)[ \t]/) || c == "I"
    if (scope == "visible" && !vis) return k
    requireDoc(label, name, np, P, 0, 0, 0, 0, ov, 0, T)
    return k
  }

  p = index(h, "("); e = index(h, "=")
  # ---- initializer or compact record constructor
  if (!p && !e && opening) {
    if (h ~ /^(static)?$/) return "B"
    name = h; sub(/^.*[ \t]/, "", name)
    requireDoc("constructor", name, 0, P, 0, 1, 1, 0, ov, 0, T)
    return "M"
  }
  # ---- field
  if (!p || (e && e < p)) { field(h, c); last[bid] = ""; return "A" }

  # ---- method / constructor
  pre = trim(substr(h, 1, p - 1))
  match(pre, /[A-Za-z_$][A-Za-z0-9_$]*$/); name = substr(pre, RSTART, RLENGTH)
  pre = trim(substr(pre, 1, RSTART - 1))
  vis = (pre ~ /(^|[ \t])(public|protected)([ \t]|$)/) || (c == "I" && pre !~ /(^|[ \t])private([ \t]|$)/)
  tp = pre
  while (tp ~ "(^|[ \t])(" MODS ")([ \t]|$)") gsub("(^|[ \t])(" MODS ")([ \t]|$)", " ", tp)
  tp = trim(tp)
  if (substr(tp, 1, 1) == "<") { typeVars(bracket(tp, 1, "<", ">"), hdrLine); tp = trim(substr(tp, length(bracket(tp, 1, "<", ">")) + 1)) }
  isCtor = (tp == "")
  ret = tp; while (gsub(/<[^<>]*>/, "", ret)); ret = trim(ret)
  plist = bracket(h, p, "(", ")")
  np = params(plist, P)
  rest = substr(h, p + length(plist)); nt = 0
  if (match(rest, /throws[ \t]+[^{;]*/)) nt = throwsList(substr(rest, RSTART + 6, RLENGTH - 6), T)

  key = isCtor ? "<init>" : name
  if ((bid, key) in seen && last[bid] != key) out("O3", hdrLine, "overload of '" key "' separated from its other overloads")
  seen[bid, key] = 1; last[bid] = key

  if (!isCtor) {
    if (name !~ /^[a-z][A-Za-z0-9]*$/ && !(isTest && name ~ /^[a-z][A-Za-z0-9]*(_[a-z0-9][A-Za-z0-9]*)+$/))
      out("N2", hdrLine, "method name not lowerCamelCase: " name)
    acronym(name, hdrLine)
    if (name == "finalize" && np == 0) out("P4", hdrLine, "finalizer: do not override Object.finalize")
    if (!ov && ((name == "equals" && np == 1 && plist ~ /Object/) || ((name == "hashCode" || name == "toString") && np == 0)))
      out("P1", hdrLine, "missing @Override on " name "()")
  }
  checkParamNames(np, P)
  if (scope == "visible" && !vis) return "M"
  requireDoc(isCtor ? "constructor" : "method", name, np, P, ret == "void", isCtor, 1, nt, ov, 1, T)
  return "M"
}

function field(h, c,   e, lhs, name, type, isSF, init, vis) {
  e = index(h, "="); lhs = e ? substr(h, 1, e - 1) : h; init = e ? substr(h, e + 1) : ""
  lhs = trim(lhs); gsub(/[ \t]*(\[\])+$/, "", lhs)
  if (lhs ~ /,/ && lhs !~ /<[^>]*,/) out("F11", hdrLine, "one variable per declaration")
  match(lhs, /[A-Za-z_$][A-Za-z0-9_$]*$/); name = substr(lhs, RSTART, RLENGTH)
  type = trim(substr(lhs, 1, RSTART - 1)); sub(/,$/, "", type); vis = type ~ /(^|[ \t])(public|protected)[ \t]/ || c == "I"
  isSF = (type ~ /(^|[ \t])static[ \t]/ && type ~ /(^|[ \t])final[ \t]/) || c == "I"
  while (type ~ "(^|[ \t])(" MODS ")([ \t]|$)") gsub("(^|[ \t])(" MODS ")([ \t]|$)", " ", type)
  type = trim(type)
  if (name ~ /^(m[A-Z]|s_|k[A-Z])|_$/) out("N5", hdrLine, "no prefixes/suffixes in names: " name)
  else if (isSF && name !~ /^[A-Z][A-Z0-9_]*$/ && type ~ /^(byte|short|int|long|float|double|char|boolean|String|Byte|Short|Integer|Long|Float|Double|Character|Boolean)$/)
    out("N3", hdrLine, "constant not UPPER_SNAKE_CASE: " name)
  else if (isSF && name ~ /^[A-Z][A-Z0-9_]*$/ && (type ~ /^(Logger|StringBuilder|Random)$/ || init ~ /new[ \t]+(HashMap|ArrayList|HashSet|LinkedList|TreeMap|TreeSet|LinkedHashMap|ConcurrentHashMap|StringBuilder|Atomic[A-Za-z]+|Random)/))
    out("N3", hdrLine, "mutable static final is not a constant, use lowerCamelCase: " name)
  else if (!isSF && name ~ /^[A-Z][A-Z0-9_]*$/ && length(name) > 1)
    out("N4", hdrLine, "non-constant field in UPPER_SNAKE_CASE: " name)
  else if (!isSF && name !~ /^[a-z][A-Za-z0-9]*$/)
    out("N4", hdrLine, "field not lowerCamelCase: " name)
  if (name !~ /^[A-Z][A-Z0-9_]*$/) acronym(name, hdrLine)
  if (vis && !hdrDoc && scope != "none") out("D9", hdrLine, "visible field without Javadoc: " name)
}

# Returns the bracketed substring of s starting at position i (opening char o).
function bracket(s, i, o, cl,   d, j, ch) {
  d = 0
  for (j = i; j <= length(s); j++) {
    ch = substr(s, j, 1)
    if (ch == o) d++
    else if (ch == cl) { d--; if (d == 0) return substr(s, i, j - i + 1) }
  }
  return substr(s, i)
}

# Splits "(...)" into parameter names (arr[1..n]); returns n.
function params(pl, arr,   inner, n, i, ch, d, cur, nm) {
  delete arr; n = 0
  inner = substr(pl, 2, length(pl) - 2)
  d = 0; cur = ""
  for (i = 1; i <= length(inner) + 1; i++) {
    ch = i <= length(inner) ? substr(inner, i, 1) : ","
    if (ch == "<" || ch == "(") d++
    else if (ch == ">" || ch == ")") d--
    if (ch == "," && d == 0) {
      cur = trim(cur); gsub(/(\[\])+$/, "", cur)
      if (match(cur, /[A-Za-z_$][A-Za-z0-9_$]*$/)) {
        nm = substr(cur, RSTART, RLENGTH)
        if (nm != "this" && cur ~ /[ \t.]/) arr[++n] = nm
      }
      cur = ""
    } else cur = cur ch
  }
  return n
}

function throwsList(s, arr,   n, i, parts, t) {
  delete arr; n = split(s, parts, ",")
  for (i = 1; i <= n; i++) { t = trim(parts[i]); gsub(/<.*$/, "", t); sub(/^.*\./, "", t); arr[i] = t }
  return n
}

function checkParamNames(np, P,   i) {
  for (i = 1; i <= np; i++)
    if (P[i] != "_" && P[i] !~ /^[a-z][A-Za-z0-9]*$/) out("N7", hdrLine, "parameter not lowerCamelCase: " P[i])
}

function typeVars(s,   n, parts, i, t) {
  s = substr(s, 2, length(s) - 2)
  while (gsub(/<[^<>]*>/, "", s));
  n = split(s, parts, ",")
  for (i = 1; i <= n; i++) {
    t = trim(parts[i]); sub(/[ \t].*$/, "", t)
    if (t != "" && t !~ /^[A-Z][0-9]?$/ && t !~ /^[A-Z][A-Za-z0-9]*T$/) out("N9", hdrLine, "type variable must be T, T2 or FooT: " t)
  }
}

function acronym(name, line) {
  if (name ~ /[A-Z][A-Z][A-Z]/ || name ~ /[a-z0-9][A-Z][A-Z]$/) out("N8", line, "acronym not camel-cased (XmlHttpRequest, customerId): " name)
}

# --------------------------------------------------------------- imports
function checkImport(code,   st, nm, g) {
  st = (code ~ /^[ \t]*import[ \t]+static[ \t]/)
  nm = code; sub(/^[ \t]*import[ \t]+(static[ \t]+)?/, "", nm); sub(/[ \t]*;.*$/, "", nm)
  g = st ? 0 : 1
  if (impStarted) {
    if (g < impGroup) out("O4", FNR, "static import after non-static imports: " nm)
    else if (g == impGroup) {
      if (nm < impName) out("O4", FNR, "imports not in ASCII order: " nm " after " impName)
      if (impBlank) out("O4", FNR, "blank line inside an import group")
    } else if (!impBlank) out("O4", FNR, "missing blank line between static and non-static imports")
  }
  impStarted = 1; impBlank = 0; impGroup = g; impName = nm
}

# --------------------------------------------------------------- switch
function switchLine(code, raw) {
  if (code ~ /(^|[^A-Za-z0-9_])default[ \t]*(:|->)/ || code ~ /case[ \t]+null[ \t]*,[ \t]*default/) swDef[depth] = 1
  if (code ~ /^[ \t]*(case[ \t].*|default[ \t]*):[ \t]*$/ || code ~ /^[ \t]*(case[ \t][^>]*|default[ \t]*):[ \t]*[^ \t]/ && code !~ /->/) {
    if (swStmt[depth] && !swTerm[depth] && !swFall[depth]) out("P6", FNR, "fall-through into this label without '// fall through' comment")
    swStmt[depth] = 0; swTerm[depth] = 0; swFall[depth] = 0
    return
  }
  if (code ~ /->/) return
  swStmt[depth] = 1
  swTerm[depth] = (code ~ /^[ \t]*(break|return|throw|continue|yield)([^A-Za-z0-9_]|$)/)
  if (tolower(raw) ~ /fall.?s? ?through/) swFall[depth] = 1
}

# --------------------------------------------------------------- Javadoc
function fmt(m) { if (!(m in fmtSeen)) { fmtSeen[m] = 1; D_fmt[++D_fmtN] = m } }

function finishDoc(   i, l, t, tag, rest, inTags, para, pend, sawText) {
  if (hdr == "") docPending = 1; else hdrDoc = 1
  D_md = docMd; D_line = docStart; D_inherit = 0; D_inlineReturn = 0; D_summary = ""
  T_n = 0; D_fmtN = 0; delete D_fmt; delete fmtSeen; delete T_tag; delete T_arg; delete T_desc
  inTags = 0; para = 1; pend = 0; sawText = 0
  if (!D_md && docN == 1 && doc[1] ~ /\*\//) D_single = 1; else D_single = 0
  for (i = 1; i <= docN; i++) {
    l = doc[i]
    if (D_md) sub(/^[ \t]*\/\/\/ ?/, "", l)
    else {
      if (i == 1) {
        sub(/^[ \t]*\/\*\*/, "", l)
        if (!D_single && trim(l) != "") fmt("text on the '/**' line; use the basic multi-line form")
      } else if (l ~ /^[ \t]*\*\//) l = ""
      else if (l !~ /^[ \t]*\*/) fmt("Javadoc line without leading '*'")
      else sub(/^[ \t]*\*[ \t]?/, "", l)
      if (index(l, "*/")) {
        if (!D_single && i == docN && trim(substr(l, 1, index(l, "*/") - 1)) != "") fmt("closing '*/' must be on its own line")
        l = substr(l, 1, index(l, "*/") - 1)
      }
    }
    if (l ~ /\{@inheritDoc\}/) D_inherit = 1
    if (l ~ /\{@return[ \t}]/) D_inlineReturn = 1
    t = trim(l)
    if (t ~ /^@[A-Za-z]+/) {
      if (!inTags && sawText && !pend && !D_md) fmt("blank line required before block tags")
      inTags = 1; T_n++
      tag = t; sub(/^@/, "", tag); sub(/[ \t].*$/, "", tag)
      rest = trim(substr(t, length(tag) + 2))
      T_tag[T_n] = tag
      if (tag == "param" || tag == "throws" || tag == "exception") {
        T_arg[T_n] = rest; sub(/[ \t].*$/, "", T_arg[T_n])
        T_desc[T_n] = trim(substr(rest, length(T_arg[T_n]) + 1))
      } else { T_arg[T_n] = ""; T_desc[T_n] = rest }
      continue
    }
    if (inTags) { if (t != "") T_desc[T_n] = trim(T_desc[T_n] " " t); continue }
    if (t == "") { if (sawText) pend = 1; continue }
    if (pend) {
      para++; pend = 0
      if (!D_md && t !~ /^<p>/ && t !~ /^<(ul|ol|table|pre|h[1-6]|blockquote|dl|div)/) fmt("paragraph " para " must start with <p>")
      if (t ~ /^<p>[ \t]/) fmt("no space after <p>")
    }
    sawText = 1
    if (para == 1) D_summary = trim(D_summary " " t)
  }
  if (D_single && (T_n > 0 || doc[1] ~ /[ \t]@(param|return|throws|exception|deprecated)[ \t]/))
    fmt("single-line Javadoc must not contain block tags")
}

# requireDoc(label, name, nParams, P, isVoid, isCtor, isMethod, nThrows, isOverride, checkReturn, T)
function requireDoc(label, name, np, P, isVoid, isCtor, isMethod, nt, ov, chkRet, T,   i, j, ok, hasRet, rank, maxRank, maxTag, r, s, w, pset) {
  if (!hdrDoc) {
    out("D1", hdrLine, "missing Javadoc: " label " " name (hdrImpl ? " (has // or /* */ comment: convert to Javadoc)" : "") (ov ? " (override: /** {@inheritDoc} */ suffices)" : ""))
    return
  }
  for (i = 1; i <= D_fmtN; i++) out("D8", D_line, D_fmt[i])
  if (D_inherit) return
  delete pset
  for (i = 1; i <= T_n; i++) if (T_tag[i] == "param") pset[T_arg[i]] = 1
  for (i = 1; i <= np; i++) if (P[i] != "_" && !(P[i] in pset)) out("D2", D_line, label " " name ": missing @param " P[i])
  for (i = 1; i <= T_n; i++) {
    if (T_tag[i] != "param" || T_arg[i] ~ /^</) continue
    ok = 0; for (j = 1; j <= np; j++) if (P[j] == T_arg[i]) ok = 1
    if (!ok) out("D2", D_line, label " " name ": @param " T_arg[i] " does not exist")
  }
  hasRet = 0; for (i = 1; i <= T_n; i++) if (T_tag[i] == "return") hasRet = 1
  if (isMethod && !isCtor && !isVoid && chkRet && !hasRet && !D_inlineReturn) out("D3", D_line, label " " name ": missing @return")
  if ((isVoid || isCtor) && hasRet) out("D3", D_line, label " " name ": @return on void method/constructor")
  for (i = 1; i <= nt; i++) {
    ok = 0
    for (j = 1; j <= T_n; j++) if ((T_tag[j] == "throws" || T_tag[j] == "exception") && T_arg[j] ~ ("(^|\\.)" T[i] "$")) ok = 1
    if (!ok) out("D4", D_line, label " " name ": missing @throws " T[i])
  }
  maxRank = 0
  for (i = 1; i <= T_n; i++) {
    r = T_tag[i] == "param" ? 1 : T_tag[i] == "return" ? 2 : (T_tag[i] == "throws" || T_tag[i] == "exception") ? 3 : T_tag[i] == "deprecated" ? 4 : 0
    if (!r) continue
    if (r < maxRank) out("D5", D_line, label " " name ": @" T_tag[i] " after @" maxTag " (order: @param @return @throws @deprecated)")
    if (r > maxRank) { maxRank = r; maxTag = T_tag[i] }
    if ((r == 1 || r == 3) && (T_arg[i] == "" || T_desc[i] == "")) out("D6", D_line, label " " name ": empty @" T_tag[i] " " T_arg[i])
    if ((r == 2 || r == 4) && T_desc[i] == "") out("D6", D_line, label " " name ": empty @" T_tag[i])
  }
  s = D_summary
  if (s == "") { out("D7", D_line, label " " name ": no summary fragment before block tags"); return }
  if (s ~ /^[a-z]/) out("D7", D_line, label " " name ": summary must be capitalized")
  if (s ~ /^(This|The) (method|class|function|constructor|interface|enum|record)[ \t]/ || s ~ /^An? [^ ]+ is /)
    out("D7", D_line, label " " name ": summary must be a fragment, not 'This method ...'/'A Foo is ...'")
  w = s; sub(/[^A-Za-z].*$/, "", w)
  if (isMethod && !isCtor && w ~ IMPERATIVE) out("D7", D_line, label " " name ": imperative summary '" w "'; use 3rd person (e.g. '" w "s')")
  if (s !~ /[.!?]/) out("D7", D_line, label " " name ": summary not punctuated (missing '.')")
}
