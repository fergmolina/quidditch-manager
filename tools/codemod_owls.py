#!/usr/bin/env python3
"""The mechanical half of the owl migration: stored text moves to Say values and notices to Inbox.tell.

Usage:
    python3 tools/codemod_owls.py --check     # dry run: print the rewrites and the report, edit nothing
    python3 tools/codemod_owls.py --apply     # rewrite src/**/*.gd and the locale rows
Then: godot --headless --path . tools/check_scripts.tscn, and the text dump (tools/owl_text_dump.gd) diffed against
the one taken before, with equal RNG counts.

Passes:
  V1  every value of a params literal becomes a Say constructor, by what it encodes today:
        "@g:%d" % X -> Say.money(X); "@comp:" + X -> Say.comp(X); "@t:" + K / "@t:k" -> Say.key(K)
        "pos." + X and the other key prefixes, Awards.kind_key(), Career.rank_key() -> Say.key(...)
        P.name() -> Say.player(P); C.name -> Say.club(C); w.team_name(ID) -> Say.team(w, ID); their "<k>_id"
        companions are dropped; "%d-%02d" % [Y, ...] -> Say.season(Y); strings -> Say.plain; numbers -> Say.num
        A ternary converts both arms. A plain int under a money key at one of PLAIN_INT_MONEY -> Say.money.
  C1  w.post_message(F, S, B, P) with no actions -> Inbox.tell(w, &F, S, B, P'), folding the decorations of the
      returned dict: `x["read"] = true` -> Inbox.QUIET; `world.inbox[0]["tutorial"] = k` -> link k.
  N1  news literals {"key": K, "importance": I, "params": {...}, ...} -> NewsGenerator.item(K, I, {...}, {...}).
  L1  "{fee} G" -> "{fee}" in the templates whose fee becomes Say.money (all 10 languages).
  L2  positional keys -> named: ui.action.accept_sale_sell_on {fee}, ui.action.accept_sponsor {name} {monthly}
      {until}, ui.inbox.outcome {answer}, the complaint replies {player}; "%%" -> "%".
  L3  ui.list.name_detail "{name} ({detail})", the list item with a detail (a wage, points).
A site the passes cannot finish (actions, a params variable, a joined name list, a decorated owl, an unknown value)
is left as it is and listed in the report with the reason; those are migrated by hand.
"""
import csv, json, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KEY_PREFIXES = ("pos.", "objective.", "house.", "award.", "facility.", "venue.")
PLAIN_INT_MONEY = {("msg.welcome.body", "balance"), ("msg.option_exercised.body", "fee"),
                   ("msg.release_clause.body", "fee"), ("msg.incoming_counter_no.body", "fee"),
                   ("msg.loan_option.body", "fee")}
INT_HINTS = re.compile(r"^(int\(.*\)|\d+|.*\.size\(\)|.*injury_days|.*score_(home|away)|.*\.season( [+-] \d+)?|year|n|age|left - 1|"
                       r"pos|final_pos|rpos|i \+ 1|.*position_of\(.*\)|Career\.expected_position\(.*\)|w\.manager\[\"reputation\"\]|"
                       r"st\[i\]\[\"pts\"\]|comp\.club_ids\.size\(\)|places|need|streak|-streak|goals|delta|days|cut|amount|cash|years|y)$")
STR_HINTS = re.compile(r"^(manager_name|sname|season_label|.*\.short_name|_best_of\(.*\)|old|club\.manager_name|.*\.manager_name)$")


class Hand(Exception):
    pass


def match_close(s, i):
    """Index just past the bracket that closes the one at s[i]."""
    depth, q = 0, None
    j = i
    while j < len(s):
        c = s[j]
        if q:
            if c == "\\":
                j += 1
            elif c == q:
                q = None
        elif c in "\"'":
            q = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                return j + 1
        j += 1
    raise ValueError("unbalanced")


def split_top(s, sep=","):
    out, depth, q, cur = [], 0, None, ""
    i = 0
    while i < len(s):
        c = s[i]
        if q:
            cur += c
            if c == "\\":
                cur += s[i + 1]
                i += 1
            elif c == q:
                q = None
        elif c in "\"'":
            q = c
            cur += c
        elif c in "([{":
            depth += 1
            cur += c
        elif c in ")]}":
            depth -= 1
            cur += c
        elif depth == 0 and s.startswith(sep, i):
            out.append(cur)
            cur = ""
            i += len(sep) - 1
        else:
            cur += c
        i += 1
    if cur.strip():
        out.append(cur)
    return [x.strip() for x in out]


def top_find(s, word):
    depth, q = 0, None
    for i, c in enumerate(s):
        if q:
            if c == q:
                q = None
        elif c in "\"'":
            q = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif depth == 0 and s.startswith(word, i):
            return i
    return -1


def unwrap(e):
    e = e.strip()
    while e.startswith("(") and match_close(e, 0) == len(e):
        e = e[1:-1].strip()
    return e


def parse_dict(lit):
    body = lit.strip()
    assert body.startswith("{") and body.endswith("}")
    pairs = []
    for part in split_top(body[1:-1]):
        k = top_find(part, ":")
        key = part[:k].strip()
        if not re.fullmatch(r'"[^"]*"', key):
            raise Hand("non-literal key " + key)
        pairs.append((key[1:-1], part[k + 1:].strip()))
    return pairs


def entity(e):
    """(constructor, id expression) for an entity-name expression, else None."""
    m = re.fullmatch(r"([A-Za-z_][\w.]*(?:\([^()]*\))?)\.name\(\)", e)
    if m:
        return "Say.player(%s)" % m.group(1), m.group(1) + ".id"
    m = re.fullmatch(r"(w|Game\.world)\.team_name\((.+)\)", e)
    if m and match_close(e, len(m.group(1) + ".team_name")) == len(e):
        return "Say.team(%s, %s)" % (m.group(1), m.group(2)), m.group(2)
    m = re.fullmatch(r"([A-Za-z_][\w]*(?:\.club\([^()]*\))?)\.name", e)
    if m and not e.endswith("short_name"):
        return "Say.club(%s)" % m.group(1), m.group(1) + ".id"
    return None


def conv(key, e, body_key, notes):
    e = e.strip()
    u = unwrap(e)
    if u.startswith("Say."):
        return e
    i_if, i_else = top_find(u, " if "), top_find(u, " else ")
    if i_if > 0 and i_else > i_if:
        a, cond, b = u[:i_if], u[i_if + 4:i_else], u[i_else + 6:]
        return "(%s if %s else %s)" % (conv(key, a, body_key, notes), cond.strip(), conv(key, b, body_key, notes))
    m = re.fullmatch(r'"@g:%d" % (.+)', u)
    if m:
        return "Say.money(%s)" % unwrap(m.group(1))
    m = re.fullmatch(r'"@comp:" \+ (.+)', u)
    if m:
        return "Say.comp(%s)" % m.group(1)
    m = re.fullmatch(r'"@t:" \+ (.+)', u)
    if m:
        return "Say.key(%s)" % m.group(1)
    m = re.fullmatch(r'"@t:([^"]+)"', u)
    if m:
        return 'Say.key("%s")' % m.group(1)
    if any(u.startswith('"%s" +' % p) for p in KEY_PREFIXES) or re.fullmatch(r"(Awards\.kind_key|Career\.rank_key)\(.*\)", u):
        return "Say.key(%s)" % u
    if "list_sep().join(" in u or '", ".join(' in u or ".join(" in u:
        raise Hand("joined name list in %r" % key)
    m = re.fullmatch(r'"%d-%02d" % \[(.+), \(.+\) % 100\]', u)
    if m:
        return "Say.season(%s)" % m.group(1)
    m = re.fullmatch(r"(?:NewsGenerator\.)?(?:_dur|duration_text)\((.+)\)", u)
    if m:
        return "Say.duration(%s)" % m.group(1)
    if re.fullmatch(r'"[^"@]*" % .+', u):
        return "Say.plain(%s)" % u
    m = re.fullmatch(r'"@t:([\w.]+)" \+ (.+)', u)
    if m:
        return 'Say.key("%s" + %s)' % (m.group(1), m.group(2))
    if re.fullmatch(r'Game\.loader\.brooms\[\w+\]\["model"\]', u):
        return "Say.plain(str(%s))" % u
    ent = entity(u)
    if ent:
        return ent[0]
    if re.fullmatch(r'"[^"]*"', u):
        if any(u[1:].startswith(p) for p in KEY_PREFIXES) or u.startswith('"@'):
            raise Hand("encoded literal " + u)
        return "Say.plain(%s)" % u
    if u.startswith("str(") or STR_HINTS.fullmatch(u) or ".repeat(" in u or u.startswith('("+"'):
        return "Say.plain(%s)" % u
    if (body_key, key) in PLAIN_INT_MONEY:
        return "Say.money(%s)" % u
    if INT_HINTS.fullmatch(u):
        return "Say.num(%s)" % u
    if re.fullmatch(r"w\.manager\.get\(\"name\", \"\"\)", u):
        return "Say.plain(str(%s))" % u
    raise Hand("unknown value %r: %s" % (key, u))


def conv_params(lit, body_key, notes):
    pairs = parse_dict(lit)
    names = {k for k, _ in pairs}
    ent_ids = {}
    out = []
    for k, v in pairs:
        if k.endswith("_ids") and k[:-4] in names:
            raise Hand("list companion %r" % k)
    for k, v in pairs:
        if k.endswith("_id") and k[:-3] in names:
            continue
        new = conv(k, v, body_key, notes)
        ent = entity(unwrap(v))
        if ent:
            ent_ids[k] = ent[1]
        out.append('"%s": %s' % (k, new))
    for k, v in pairs:
        if k.endswith("_id") and k[:-3] in names and k[:-3] not in ent_ids:
            base = dict(pairs)[k[:-3]]
            if " if " not in base:
                raise Hand("id companion %r without an entity value" % k)
    return "{" + ", ".join(out) + "}" if out else ""


def line_of(s, i):
    return s.count("\n", 0, i) + 1


def rewrite_posts(path, s, report):
    out, pos = [], 0
    for m in re.finditer(r"(?P<var>var (?P<name>\w+) := )?(?P<recv>Game\.world|world|w)\.post_message\(", s):
        if m.start() < pos:
            continue
        open_i = m.end() - 1
        end = match_close(s, open_i)
        args = split_top(s[open_i + 1:end - 1])
        where = "%s:%d" % (path.relative_to(ROOT), line_of(s, m.start()))
        if m.group("recv") == "w" and path.name == "world.gd":
            continue
        try:
            if len(args) > 4:
                raise Hand("actions (question)")
            if len(args) < 3:
                raise Hand("short call")
            frm, subj, body = args[0], args[1], args[2]
            params = args[3] if len(args) == 4 else "{}"
            if not params.startswith("{"):
                raise Hand("params variable %s" % params)
            body_key = body.strip('"') if re.fullmatch(r'"[^"]*"', body) else ""
            new_args = conv_params(params, body_key, report)
            flags, link = "", ""
            tail_start = end
            line_end = s.find("\n", end)
            rest = s[line_end + 1:]
            nxt = rest.split("\n", 2)[:2]
            drop = 0
            var = m.group("name")
            if var:
                if re.fullmatch(r"\s*%s\[\"read\"\] = true" % re.escape(var), nxt[0] or ""):
                    flags = "Inbox.QUIET"
                    drop = 1
                else:
                    raise Hand("decorated owl %s" % (nxt[0] or "").strip())
            elif nxt and re.fullmatch(r'\s*world\.inbox\[0\]\["tutorial"\] = (\w+)', nxt[0] or ""):
                link = re.fullmatch(r'\s*world\.inbox\[0\]\["tutorial"\] = (\w+)', nxt[0]).group(1)
                drop = 1
            frm_new = "&" + frm if re.fullmatch(r'"[^"]*"', frm) else frm
            call = "Inbox.tell(%s, %s, %s, %s" % (m.group("recv"), frm_new, subj, body)
            if new_args or flags or link:
                call += ", " + (new_args or "{}")
            if flags or link:
                call += ", " + (flags or "0")
            if link:
                call += ", " + link
            call += ")"
            out.append(s[pos:m.start()])
            out.append(call)
            pos = end
            if drop:
                cut_from = line_end
                cut_to = line_end + 1 + len(nxt[0]) if drop == 1 else line_end
                out.append(s[end:cut_from])
                pos = cut_to
            report.append("C1 %s -> %s" % (where, call[:160]))
        except Hand as h:
            report.append("HAND %s post_message: %s" % (where, h))
    out.append(s[pos:])
    return "".join(out)


def rewrite_news(path, s, report):
    out, pos = [], 0
    for m in re.finditer(r'\{"key": ', s):
        if m.start() < pos:
            continue
        end = match_close(s, m.start())
        lit = s[m.start():end]
        where = "%s:%d" % (path.relative_to(ROOT), line_of(s, m.start()))
        try:
            pairs = parse_dict(lit)
        except Exception:
            continue
        d = dict(pairs)
        if "importance" not in d or "params" not in d or "args" in d:
            continue
        try:
            if not d["params"].startswith("{"):
                raise Hand("params variable %s" % d["params"])
            args = conv_params(d["params"], d["key"].strip('"'), report)
            routing = ['"%s": %s' % (k, v) for k, v in pairs if k not in ("key", "importance", "params")]
            call = "NewsGenerator.item(%s, %s" % (d["key"], d["importance"])
            if args or routing:
                call += ", " + (args or "{}")
            if routing:
                call += ", {" + ", ".join(routing) + "}"
            call += ")"
            out.append(s[pos:m.start()])
            out.append(call)
            pos = end
            report.append("N1 %s -> %s" % (where, call[:160]))
        except Hand as h:
            report.append("HAND %s news item: %s" % (where, h))
    out.append(s[pos:])
    return "".join(out)


def rewrite_press(path, s, report):
    """N1 for press questions (press.gd): the `base` literals become typed Say args and so does the literal `extra`
    of every _q/_pre_q call; the three builders that merge them are migrated by hand."""
    if path.name != "press.gd":
        return s
    out, pos = [], 0
    for m in re.finditer(r"var base := (\{)|(?:_q|_pre_q)\([^,]+, base, (\{)", s):
        brace = m.start(1) if m.group(1) else m.start(2)
        if brace < pos:
            continue
        end = match_close(s, brace)
        where = "%s:%d" % (path.relative_to(ROOT), line_of(s, m.start()))
        lit = s[brace:end]
        try:
            new = conv_params(lit, "", report) if lit != "{}" else "{}"
            prefix = s[pos:brace]
            if m.group(1):
                prefix = prefix[:len(prefix) - len("var base := ")] + "var base: Dictionary[String, Say.Arg] = "
            out.append(prefix)
            out.append(new or "{}")
            pos = end
            report.append("N1 %s -> %s" % (where, (new or "{}")[:160]))
        except Hand as h:
            report.append("HAND %s press params: %s" % (where, h))
    out.append(s[pos:])
    return "".join(out)


LANGS = ["es", "en", "de", "fr", "it", "pt_BR", "nl", "ru", "ja", "zh_CN"]


def locale_rows():
    rows = {r[0]: r[1:] for r in csv.reader(open(ROOT / "locale/strings.csv", newline="", encoding="utf-8"))}
    new = {}

    def put(key, fn):
        vals = [fn(v) for v in rows[key]]
        if vals != rows[key]:
            new[key] = vals

    for key in ("msg.loan_option.body", "msg.option_exercised.body", "msg.release_clause.body", "msg.incoming_counter_no.body"):
        put(key, lambda v: re.sub(r"\{fee\}\s?G", "{fee}", v))
    put("ui.action.accept_sale_sell_on", lambda v: re.sub(r"%d\s?G", "{fee}", v).replace("%%", "%"))

    def sponsor(v):
        v = re.sub(r"%d\s?G", "{monthly}", v)
        for name in ("{name}", "{until}"):
            v = v.replace("%s", name, 1)
        return v
    put("ui.action.accept_sponsor", sponsor)
    put("ui.inbox.outcome", lambda v: v.replace("%s", "{answer}"))
    for key in ("ui.complaint.listed", "ui.complaint.ignored", "ui.complaint.wants_out"):
        put(key, lambda v: v.replace("%s", "{player}"))
    if "ui.list.name_detail" not in rows:
        new["ui.list.name_detail"] = ["{name} ({detail})"] * len(LANGS)
    return new


def main():
    apply = "--apply" in sys.argv[1:]
    report = []
    for path in sorted((ROOT / "src").rglob("*.gd")):
        s = path.read_text(encoding="utf-8")
        t = rewrite_press(path, rewrite_news(path, rewrite_posts(path, s, report), report), report)
        if t != s and apply:
            path.write_text(t, encoding="utf-8")
    rows = locale_rows()
    for k, v in rows.items():
        report.append("L %s -> %s" % (k, v[1]))
    if apply and rows:
        tmp = ROOT / "tools" / "_codemod_owls_keys.json"
        tmp.write_text(json.dumps(rows, ensure_ascii=False))
        subprocess.run([sys.executable, "tools/add_keys.py", str(tmp)], cwd=ROOT, check=True)
        tmp.unlink()
        subprocess.run([sys.executable, "tools/merge_translations.py"], cwd=ROOT, check=True)
    print("\n".join(report))
    print("codemod_owls: %d rewritten, %d left for hand migration" % (
        sum(1 for r in report if r[:2] in ("C1", "N1")), sum(1 for r in report if r.startswith("HAND"))))


if __name__ == "__main__":
    main()
