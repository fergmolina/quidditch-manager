import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { parseAdmin1, parseCities, unzipEntry } from "../scripts/build-geo.js";
import { GENERATED_STRINGS_PATH, LANGS, loadStrings } from "../src/i18n/i18n.js";
import { ACCOUNT_SAVED } from "../src/pages/account.js";
import { tRich } from "../src/pages/profile-form.js";
import { html } from "../src/http/html.js";
import { COUNTRY_CODES, countryFromHeader, countryName, countryOptions, isCountryCode, ISO_3166_1_ALPHA2, normalizeCountry, type CountryCode } from "../src/profile/countries.js";
import { citiesForSelect, findCity, findRegion, foldText, GEO_DIR, NO_JS_CITY_LIMIT, regionsFor, searchCities } from "../src/profile/geo.js";
import { checkName } from "../src/profile/names.js";
import { changeUsername, cityChoice, collectErrors, completeProfile, formValues, parseLocation, parseNames, parseUsername, PROFILE_ERRORS, ProfileWriteError, registerProfile, type Parsed } from "../src/profile/profile.js";
import { checkUsername, foldForBlocklist, usernameCooldownUntilMs, USERNAME_COOLDOWN_MS } from "../src/profile/username.js";
import { deflateRawSync } from "node:zlib";
import { fakeDb } from "./helpers.js";

test("username: format, case kept, reserved names, blocklist with digit swaps, no Scunthorpe on common names", () => {
  assert.deepEqual(checkUsername("  HarryFan "), { ok: true, value: "HarryFan" });
  for (const ok of ["abc", "A_b_9", "Zz" + "9".repeat(18), "Cassandra", "Scunthorpe", "Dickens", "Spicer", "Nazionale", "Hancock"]) {
    assert.equal(checkUsername(ok).ok, true, ok);
  }
  const err = (v: unknown) => (checkUsername(v) as { error?: string }).error;
  assert.equal(err(""), "username_required");
  assert.equal(err(undefined), "username_required");
  for (const bad of ["ab", "1abc", "_abc", "a".repeat(21), "has space", "аdmin", "ñandu", "a-b", "a.b"]) assert.equal(err(bad), "username_format", bad);
  for (const r of ["admin", "ADMIN", "Quidditch_Manager", "root", "deleted", "Anonymous"]) assert.equal(err(r), "username_reserved", r);
  for (const b of ["xNiggerx", "H1tl3r_fan", "n_i_g_g_e_r", "Maricon99"]) assert.equal(err(b), "username_blocked", b);
  assert.equal(foldForBlocklist("H1_tl3r"), "hitler");
});

test("username cooldown: 30 days from the last change; never set → free", () => {
  const now = Date.parse("2026-10-21T12:00:00Z");
  assert.equal(usernameCooldownUntilMs(null, now), null);
  const changed = new Date(now - 10 * 86_400_000).toISOString();
  assert.equal(usernameCooldownUntilMs(changed, now), Date.parse(changed) + USERNAME_COOLDOWN_MS);
  assert.equal(usernameCooldownUntilMs(new Date(now - 31 * 86_400_000).toISOString(), now), null);
});

test("names: NFC, optional, 1–50 code points, letters/marks/space/hyphen/apostrophes/period, no invisible characters", () => {
  const ok = (v: string) => {
    const r = checkName(v);
    assert.ok(r.ok, v);
    return r.value;
  };
  assert.equal(ok(""), null);
  assert.equal(ok("   "), null);
  assert.equal(checkName(undefined).ok, true);
  assert.equal(ok("  José   María "), "José María");
  assert.equal(ok("José"), "José", "NFC");
  for (const v of ["O’Neill", "O'Neill", "da Silva", "Jean-Luc", "St. John", "Ægir", "ジョン・スミス", "张伟", "Владимир", "Gal·la", "Nguyễn"]) ok(v);
  assert.equal(ok("A B"), "A B", "NBSP becomes a space");
  assert.equal(ok("あ".repeat(50)), "あ".repeat(50));
  const err = (v: string) => (checkName(v) as { error?: string }).error;
  assert.equal(err("𠀀".repeat(51)), "name_too_long", "counts code points, not UTF-16 units");
  for (const bad of ["Ann​ie", "‮evil", "Tab\tName", "Line\nBreak", "﻿Bom", "R2D2", "<script>", "a@b", "---", "..."]) {
    assert.equal(err(bad), "name_invalid", JSON.stringify(bad));
  }
});

test("countries: the 249 ISO codes plus XK; XX/T1 and junk refused", () => {
  assert.equal(ISO_3166_1_ALPHA2.length, 249);
  assert.equal(new Set(ISO_3166_1_ALPHA2).size, 249);
  assert.equal(COUNTRY_CODES.length, 250);
  assert.ok(isCountryCode("XK"));
  // @ts-expect-error a plain string is not a CountryCode until normalizeCountry or isCountryCode has seen it
  const unchecked: CountryCode = "AR";
  assert.equal(normalizeCountry(unchecked), "AR");
  for (const c of ["AR", "GB", "TW", "PS", "XK", "AQ"]) assert.equal(normalizeCountry(c), c);
  assert.equal(normalizeCountry(" ar "), "AR");
  for (const c of ["XX", "T1", "UK", "EU", "ARG", "", "GB-ENG", null, 7]) assert.equal(normalizeCountry(c), null, String(c));
  assert.equal(countryFromHeader("DE"), "DE");
  assert.equal(countryFromHeader("XX"), null);
  assert.equal(countryFromHeader("T1"), null);
  assert.equal(countryFromHeader(undefined), null);
});

test("country names come from full ICU in every page language (pinned values catch a small-ICU image)", () => {
  assert.equal(countryName("DE", "ja"), "ドイツ");
  assert.equal(countryName("AR", "zh_CN"), "阿根廷");
  assert.equal(countryName("FR", "ru"), "Франция");
  assert.equal(countryName("BR", "pt_BR"), "Brasil");
  assert.equal(countryName("ES", "es"), "España");
  assert.equal(countryName("XK", "en"), "Kosovo");
  for (const lang of LANGS) {
    const opts = countryOptions(lang);
    assert.equal(opts.length, 250);
    const unnamed = opts.filter((o) => !o.name || o.name === o.code).map((o) => o.code);
    assert.deepEqual(unnamed, [], `${lang}: codes without a name`);
  }
  const es = countryOptions("es").map((o) => o.name);
  assert.ok(es.indexOf("Alemania") < es.indexOf("Zambia"), "sorted with the page language's collator");
});

test("geo data: committed, every country in it is a valid code, admin1 codes fit the DB check", () => {
  assert.ok(existsSync(join(GEO_DIR, "admin1.json")), "run `npm run build:geo`");
  const admin1 = JSON.parse(readFileSync(join(GEO_DIR, "admin1.json"), "utf8")) as Record<string, Array<{ code: string; name: string }>>;
  const codes = new Set<string>(COUNTRY_CODES);
  for (const [cc, list] of Object.entries(admin1)) {
    assert.ok(codes.has(cc), cc);
    for (const r of list) assert.match(r.code, /^[A-Za-z0-9]{1,20}$/, `${cc}.${r.code}`);
  }
  const files = readdirSync(join(GEO_DIR, "cities"));
  assert.ok(files.length > 200);
  for (const f of files) assert.ok(codes.has(f.replace(/\.json$/, "")), f);
  const meta = JSON.parse(readFileSync(join(GEO_DIR, "meta.json"), "utf8"));
  assert.match(meta.license, /CC BY 4\.0/);
});

test("geo lookups: regions, cities, search (accents, ASCII names, word starts), no-JS select limits", () => {
  assert.equal(findRegion("AR", "07")?.name, "Buenos Aires F.D.");
  assert.equal(findRegion("AR", "99"), null);
  assert.equal(findRegion("ZZ", "07"), null);
  const ba = findCity("AR", 3435910);
  assert.ok(ba);
  assert.equal(ba.name, "Buenos Aires");
  assert.equal(ba.admin1, "07");
  assert.ok(Math.abs(ba.lat + 34.61) < 0.01 && Math.abs(ba.lon + 58.38) < 0.01);
  assert.equal(findCity("UY", 3435910), null, "a city belongs to one country");
  assert.ok(regionsFor("AR").length >= 24);

  assert.equal(searchCities("BR", { q: "sao paulo" })[0]?.name, "São Paulo");
  assert.equal(searchCities("PL", { q: "lodz" })[0]?.name, "Łódź");
  assert.equal(searchCities("GB", { q: "london" })[0]?.name, "London");
  assert.ok(searchCities("AR", { q: "aires" }).some((c) => c.id === 3435910), "word start");
  const inRegion = searchCities("AR", { region: "07", q: "" });
  assert.ok(inRegion.length > 0 && inRegion.every((c) => c.admin1 === "07"));
  assert.ok(searchCities("US", { q: "" }).length <= 20);
  assert.deepEqual(searchCities("ZZ", { q: "a" }), []);
  assert.equal(foldText("Saint-Étienne"), "saint etienne");

  assert.deepEqual(citiesForSelect("US", null), { kind: "needs_region" }, "too many without a region");
  const ca = citiesForSelect("US", "CA");
  assert.ok(ca.kind === "cities" && ca.list.length > 0 && ca.list.length <= NO_JS_CITY_LIMIT && ca.list.every((c) => c.admin1 === "CA"));
  const ad = citiesForSelect("AD", null);
  assert.ok(ad.kind === "cities" && ad.list.length > 0, "small country: whole list");
  const sg = findCity("SG", 1880135);
  assert.equal(sg?.admin1, null, "a place in a country without first-level divisions");
});

const location = (country: string, region: string, city: string) => parseLocation({ country, region, city: cityChoice(city) });
const failed = (r: Parsed<unknown>) => (r.ok ? {} : r.errors);
const valueOf = <T>(r: Parsed<T>): T => {
  assert.ok(r.ok, JSON.stringify(r));
  return r.value;
};

test("cityChoice: the posted city is nothing, 'other' or a GeoNames id; anything else is invalid", () => {
  assert.deepEqual(cityChoice(""), { kind: "none" });
  assert.deepEqual(cityChoice("  "), { kind: "none" });
  assert.deepEqual(cityChoice("other"), { kind: "other" });
  assert.deepEqual(cityChoice("3435910"), { kind: "id", id: 3435910 });
  for (const bad of ["0", "007", "3435910abc", "-1", "12345678901"]) assert.deepEqual(cityChoice(bad), { kind: "invalid" }, bad);
  assert.deepEqual(formValues({ city: "other" }).city, { kind: "other" });
});

test("parseLocation: country required; region and city checked against the data", () => {
  assert.deepEqual(failed(location("", "", "")), { country: "country_required" });
  assert.deepEqual(failed(location("XX", "", "")), { country: "country_invalid" });
  assert.deepEqual(valueOf(location("ar", "", "")), { country: "AR", region: null, city: null });
  assert.deepEqual(failed(location("AR", "nope", "")), { region: "region_invalid" });
  assert.deepEqual(failed(location("AR", "", "123")), { city: "city_invalid" });
  assert.deepEqual(failed(location("AR", "", "3435910abc")), { city: "city_invalid" });
  assert.deepEqual(failed(location("UY", "", "3435910")), { city: "city_invalid" }, "Buenos Aires is not in Uruguay");
  assert.deepEqual(failed(location("AR", "nope", "123")), { region: "region_invalid", city: "city_invalid" }, "both reported at once");
  const other = valueOf(location("AR", "01", "other"));
  assert.equal(other.city, null);
  assert.equal(other.region, "01");
});

test("parseLocation precedence: a chosen city's region wins over the pick, which is then not checked; without one the pick is", () => {
  assert.equal(valueOf(location("AR", "01", "3435910")).region, "07", "the city's own region replaces a different valid pick");
  assert.equal(valueOf(location("AR", "zz", "3435910")).region, "07", "an invalid pick is ignored once a city is chosen");
  assert.equal(valueOf(location("AR", "", "3435910")).region, "07", "no pick: the city's region");
  const noDivision = valueOf(location("SG", "", "1880135"));
  assert.equal(noDivision.city?.id, 1880135);
  assert.equal(noDivision.region, null, "a city without a first-level division leaves the region empty");
  assert.deepEqual(failed(location("SG", "zz", "1880135")), { region: "region_invalid" }, "that city does not excuse an invalid pick");
});

test("parseNames and parseUsername return the value or the field errors, never both", () => {
  assert.deepEqual(parseNames({ first_name: "  José   María ", last_name: "" }), { ok: true, value: { firstName: "José María", lastName: null } });
  assert.deepEqual(parseNames({ first_name: "R2D2", last_name: "𠀀".repeat(51) }), { ok: false, errors: { first_name: "name_invalid", last_name: "name_too_long" } });
  assert.deepEqual(parseUsername(" HarryFan "), { ok: true, value: "HarryFan" });
  assert.deepEqual(parseUsername("admin"), { ok: false, errors: { username: "username_reserved" } });
  assert.deepEqual(collectErrors(parseUsername(""), null, parseNames({ first_name: "<x>", last_name: "" }), parseLocation({ country: "", region: "", city: cityChoice("") })), {
    username: "username_required",
    first_name: "name_invalid",
    country: "country_required",
  });
});

test("23505 on users_username_key becomes username_taken; any other error, even a 23505 without a constraint, is rethrown; empty updates raise the right code", async () => {
  const userId = "11111111-1111-4111-8111-111111111111";
  const unique = Object.assign(new Error("duplicate key"), { code: "23505", constraint_name: "users_username_key" });
  const db = fakeDb(() => {
    throw unique;
  });
  const loc = { country: normalizeCountry("AR")!, region: null, city: null };
  const profile = { firstName: null, lastName: null, location: loc, termsVersion: "v" };
  await assert.rejects(registerProfile(db, userId, { ...profile, username: "Taken" }, Date.now()), (e: unknown) => e instanceof ProfileWriteError && e.code === "username_taken");
  const other = fakeDb(() => {
    throw Object.assign(new Error("boom"), { code: "57014" });
  });
  await assert.rejects(changeUsername(other, userId, "Abc", Date.now(), { forced: false }), (e: unknown) => !(e instanceof ProfileWriteError));
  const anonymousUnique = Object.assign(new Error("duplicate key"), { code: "23505" });
  const unnamed = fakeDb(() => {
    throw anonymousUnique;
  });
  await assert.rejects(registerProfile(unnamed, userId, { ...profile, username: "Abc" }, Date.now()), (e: unknown) => e === anonymousUnique, "a 23505 on another index is not a username clash");
  const none = fakeDb(() => []);
  await assert.rejects(changeUsername(none, userId, "Abc", Date.now(), { forced: false }), (e: unknown) => e instanceof ProfileWriteError && e.code === "username_cooldown");
  await assert.rejects(changeUsername(none, userId, "Abc", Date.now(), { forced: true }), (e: unknown) => e instanceof ProfileWriteError && e.code === "username_same");
  await assert.rejects(registerProfile(none, userId, { ...profile, username: "Abc" }, Date.now()), (e: unknown) => e instanceof ProfileWriteError && e.code === "conflict");
  await assert.rejects(completeProfile(none, userId, profile, Date.now()), (e: unknown) => e instanceof ProfileWriteError && e.code === "conflict");
  const sql = none.log.map((s) => s.text);
  assert.ok(sql.some((s) => /where id = \$1::uuid and username is null and blocked_at is null/.test(s)), "first registration only sets a missing username");
  assert.ok(sql.some((s) => /where id = \$1::uuid and username is not null and blocked_at is null/.test(s)), "completing a profile never touches the username");
  assert.ok(sql.some((s) => /username_changed_at is null or username_changed_at <= \$4/.test(s)), "cooldown in SQL");
  assert.ok(sql.some((s) => /must_rename and blocked_at is null and \(username is null or lower\(username\) <> lower\(\$2\)\)/.test(s)), "forced rename must differ");
});

test("tRich escapes the translated text and the values, keeps the given markup", () => {
  const t = (k: string) => (k === "x" ? "<b>{age}</b> & {link} {missing}" : k);
  const out = tRich(t, "x", { age: "<13>", link: html`<a href="/terms">T</a>` }).value;
  assert.equal(out, "&lt;b&gt;&lt;13&gt;&lt;/b&gt; &amp; <a href=\"/terms\">T</a> {missing}");
});

test("build-geo: zip reader and parsers (synthetic input)", () => {
  const text = Buffer.from("hello geo");
  const deflated = deflateRawSync(text);
  const name = Buffer.from("cities5000.txt");
  const local = Buffer.alloc(30);
  local.writeUInt32LE(0x04034b50, 0);
  local.writeUInt16LE(8, 8);
  local.writeUInt32LE(deflated.length, 18);
  local.writeUInt32LE(text.length, 22);
  local.writeUInt16LE(name.length, 26);
  const central = Buffer.alloc(46);
  central.writeUInt32LE(0x02014b50, 0);
  central.writeUInt16LE(8, 10);
  central.writeUInt32LE(deflated.length, 20);
  central.writeUInt32LE(text.length, 24);
  central.writeUInt16LE(name.length, 28);
  central.writeUInt32LE(0, 42);
  const cdOffset = local.length + name.length + deflated.length;
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50, 0);
  eocd.writeUInt16LE(1, 8);
  eocd.writeUInt16LE(1, 10);
  eocd.writeUInt32LE(central.length + name.length, 12);
  eocd.writeUInt32LE(cdOffset, 16);
  const zip = Buffer.concat([local, name, deflated, central, name, eocd]);
  assert.equal(unzipEntry(zip, "cities5000.txt").toString(), "hello geo");
  assert.throws(() => unzipEntry(zip, "nope.txt"));

  const countries = new Set(["AR", "PL"]);
  const admin1 = parseAdmin1("AR.07\tBuenos Aires F.D.\tBuenos Aires F.D.\t1\nXX.01\tNope\tNope\t2\nPL.74\tŁódź Voivodeship\tLodz\t3\nAR.b@d\tBad\tBad\t4\n", countries);
  assert.deepEqual(admin1, { AR: [{ code: "07", name: "Buenos Aires F.D." }], PL: [{ code: "74", name: "Łódź Voivodeship" }] });
  const row = (id: number, name: string, ascii: string, lat: number, lon: number, cc: string, a1: string, pop: number) =>
    [id, name, ascii, "alt", lat, lon, "P", "PPL", cc, "", a1, "", "", "", pop, "", "", "", ""].join("\t");
  const cities = parseCities(
    [row(2, "Buenos Aires", "Buenos Aires", -34.613151, -58.377232, "AR", "07", 100), row(1, "Łódź", "Lodz", 51.75, 19.46667, "PL", "74", 5), row(5, "東京", "Tokyo", 35.6895, 139.69171, "PL", "", 9), row(3, "Nowhere", "Nowhere", 0, 0, "AR", "00", 1), row(4, "Bad", "Bad", 95, 0, "AR", "07", 1)].join("\n"),
    countries,
    admin1,
  );
  assert.deepEqual(cities, { AR: [[2, "Buenos Aires", "07", -34.6132, -58.3772, 100], [3, "Nowhere", "", 0, 0, 1]], PL: [[1, "Łódź", "74", 51.75, 19.4667, 5], [5, "東京", "", 35.6895, 139.6917, 9, "Tokyo"]] }, "asciiname kept only when folding the name does not give it");
});

test("every profile/account string exists in all 10 languages once the keys are merged", (t) => {
  const s = existsSync(GENERATED_STRINGS_PATH) ? loadStrings() : {};
  if (!Object.keys(s.en ?? {}).some((k) => k.startsWith("web.profile."))) {
    t.skip("generated/strings.json has no web.profile.* keys yet");
    return;
  }
  const keys = [...PROFILE_ERRORS.map((c) => `web.profile.error.${c}`), ...ACCOUNT_SAVED.map((x) => `web.account.saved.${x}`)];
  const missing = keys.flatMap((k) => LANGS.filter((l) => !s[l]?.[k]).map((l) => `${l}:${k}`));
  assert.deepEqual(missing, []);
});
