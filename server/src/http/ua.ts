const BROWSERS: ReadonlyArray<[RegExp, string]> = [
  [/\bEdg(e|A|iOS)?\//, "Edge"],
  [/\b(OPR|Opera)\//, "Opera"],
  [/\bSamsungBrowser\//, "Samsung Internet"],
  [/\bFirefox\/|\bFxiOS\//, "Firefox"],
  [/\bChrome\/|\bCriOS\//, "Chrome"],
  [/\bSafari\//, "Safari"],
];

const SYSTEMS: ReadonlyArray<[RegExp, string]> = [
  [/\b(iPhone|iPad|iPod)\b/, "iOS"],
  [/\bAndroid\b/, "Android"],
  [/\bCrOS\b/, "ChromeOS"],
  [/\bWindows\b/, "Windows"],
  [/\bMac OS X\b|\bMacintosh\b/, "macOS"],
  [/\bLinux\b/, "Linux"],
];

export function userAgentFamily(ua: string | null | undefined): string | null {
  if (!ua) return null;
  const s = ua.slice(0, 512);
  const browser = BROWSERS.find(([re]) => re.test(s))?.[1] ?? null;
  const os = SYSTEMS.find(([re]) => re.test(s))?.[1] ?? null;
  if (!browser && !os) return null;
  return [browser ?? "?", os ?? "?"].join(" · ");
}
