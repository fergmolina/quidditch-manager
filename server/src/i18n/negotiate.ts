import { DEFAULT_LANG, isLang, LANGS, type Lang } from "./i18n.js";

export function normalizeLang(raw: string | null | undefined): Lang | null {
  if (!raw) return null;
  const tag = raw.trim().replace(/_/g, "-").toLowerCase();
  if (!tag || tag.length > 35 || !/^[a-z]{2,3}(-[a-z0-9]{1,8})*$/.test(tag)) return null;
  const exact = LANGS.find((l) => l.toLowerCase().replace("_", "-") === tag);
  if (exact) return exact;
  const primary = tag.split("-")[0];
  switch (primary) {
    case "pt":
      return "pt_BR";
    case "zh":
      return "zh_CN";
    default:
      return isLang(primary) ? primary : null;
  }
}

export function fromAcceptLanguage(header: string | null | undefined): Lang | null {
  if (!header) return null;
  const items = header
    .slice(0, 512)
    .split(",")
    .map((part, i) => {
      const [tag = "", ...params] = part.trim().split(";");
      const qp = params.find((p) => p.trim().startsWith("q="));
      const q = qp ? Number.parseFloat(qp.trim().slice(2)) : 1;
      return { tag: tag.trim(), q: Number.isFinite(q) ? q : 0, i };
    })
    .filter((x) => x.tag && x.tag !== "*" && x.q > 0)
    .sort((a, b) => b.q - a.q || a.i - b.i);
  for (const x of items) {
    const l = normalizeLang(x.tag);
    if (l) return l;
  }
  return null;
}

export interface LangSources {
  query: string | null | undefined;
  cookie: string | null | undefined;
  acceptLanguage: string | null | undefined;
}

export function negotiateLang(src: LangSources): { lang: Lang; fromQuery: boolean } {
  const q = normalizeLang(src.query);
  if (q) return { lang: q, fromQuery: true };
  return { lang: normalizeLang(src.cookie) ?? fromAcceptLanguage(src.acceptLanguage) ?? DEFAULT_LANG, fromQuery: false };
}
