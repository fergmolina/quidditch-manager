import assert from "node:assert/strict";
import { test } from "node:test";
import rules from "../../data/shared/career_rules.json" with { type: "json" };
import schema from "../../data/shared/season_report.schema.json" with { type: "json" };
import { dateFitsSeason, plausibility, seasonReportSchema, type CareerState, type SeasonReport } from "../src/career/report.js";

const base = (o: Partial<SeasonReport> = {}): SeasonReport =>
  seasonReportSchema.parse({ career_id: "0123456789abcdef", season: 1993, reported_on: "1994-07-01", reputation: 1600, titles: 0, seasons: 1, ...o });

const prev = (o: Partial<CareerState> = {}): CareerState => ({ user_id: "u", last_season: 1993, last_reputation: 1600, last_titles: 0, last_seasons: 1, ...o });

test("schema: career id, season range, date format, ids; defaults for mode, titles and seasons", () => {
  const ok = seasonReportSchema.safeParse({ career_id: "0123456789abcdef", season: 1995, reported_on: "1996-07-01", reputation: 1200 });
  assert.ok(ok.success);
  assert.deepEqual(ok.success && ok.data, { career_id: "0123456789abcdef", season: 1995, reported_on: "1996-07-01", reputation: 1200, mode: "club", titles: 0, seasons: 0 });
  for (const bad of [
    { career_id: "XYZ", season: 1995, reported_on: "1996-07-01", reputation: 1200 },
    { career_id: "0123456789abcdef", season: 1980, reported_on: "1981-07-01", reputation: 1200 },
    { career_id: "0123456789abcdef", season: 1995, reported_on: "1 July", reputation: 1200 },
    { career_id: "0123456789abcdef", season: 1995, reported_on: "1996-07-01", reputation: 12.5 },
    { career_id: "0123456789abcdef", season: 1995, reported_on: "1996-07-01", reputation: 1200, club_id: "Robert'); drop" },
    { career_id: "0123456789abcdef", season: 1995, reported_on: "1996-07-01", reputation: 1200, mode: "county" },
    { career_id: "0123456789abcdef", season: 1995, reported_on: "1996-07-01", reputation: 1200, club_name: "   " },
  ]) {
    assert.equal(seasonReportSchema.safeParse(bad).success, false, JSON.stringify(bad));
  }
  assert.equal(base({ club_name: "  Puddlemere United  " }).club_name, "Puddlemere United");
  assert.equal(base({ club_id: null, club_name: null, game_version: null }).club_id, null);
});

test("the validator comes from data/shared/season_report.schema.json and its season floor is career_rules.json's first season", () => {
  assert.equal(schema.$schema, "https://json-schema.org/draft/2020-12/schema");
  assert.equal(schema.properties.season.minimum, rules.first_season);
  assert.deepEqual(Object.keys(base()).sort(), ["career_id", "mode", "reported_on", "reputation", "season", "seasons", "titles"]);
  assert.ok(Object.keys(base()).every((k) => k in schema.properties));
});

test("the limits are data/shared/career_rules.json's: reputation tops out at 5000", () => {
  assert.equal(rules.reputation.max, 5000);
  const third = { season: 1995, reported_on: "1996-07-01" };
  assert.equal(plausibility(base({ ...third, reputation: rules.reputation.max }), null), null);
  assert.equal(plausibility(base({ ...third, reputation: rules.reputation.max + 1 }), null), "reputation_out_of_range");
});

test("the report's date falls in the season after the one it closes", () => {
  assert.equal(dateFitsSeason("1994-07-01", 1993), true);
  assert.equal(dateFitsSeason("1995-06-30", 1993), true);
  assert.equal(dateFitsSeason("1994-06-30", 1993), false);
  assert.equal(dateFitsSeason("1995-07-01", 1993), false);
});

test("plausibility: a normal first report and a normal next season pass", () => {
  assert.equal(plausibility(base(), null), null);
  assert.equal(plausibility(base({ season: 1994, reported_on: "1995-07-01", reputation: 2300, titles: 2, seasons: 2 }), prev()), null);
  assert.equal(plausibility(base({ season: 1996, reported_on: "1997-07-01", reputation: 4800, titles: 5, seasons: 4 }), prev()), null);
});

test("plausibility: flags out-of-range or jumping reputation, titles and seasons going backwards, dates and order", () => {
  assert.equal(plausibility(base({ reputation: 9999 }), null), "reputation_out_of_range");
  assert.equal(plausibility(base({ reputation: 150 }), null), "reputation_out_of_range");
  assert.equal(plausibility(base({ reported_on: "1993-12-01" }), null), "date_outside_season");
  assert.equal(plausibility(base({ titles: 50 }), null), "titles_jump");
  const next = (o: Partial<SeasonReport>) => base({ season: 1994, reported_on: "1995-07-01", seasons: 2, ...o });
  assert.equal(plausibility(next({ reputation: 1600 + rules.max_gain_per_season + 1 }), prev()), "reputation_jump");
  assert.equal(plausibility(next({ titles: 0 }), prev({ last_titles: 3 })), "titles_decreased");
  assert.equal(plausibility(next({ titles: 20 }), prev()), "titles_jump");
  assert.equal(plausibility(next({ seasons: 0 }), prev()), "seasons_decreased");
  assert.equal(plausibility(base({ season: 1993 }), prev()), "season_not_after_last");
});

test("ranking map: projection of the game's world map and population-weighted country centres", async () => {
  const { mapXY, MAP_W, MAP_H } = await import("../src/pages/ranking.js");
  const { countryCentroid } = await import("../src/profile/geo.js");
  assert.deepEqual(mapXY(80, -170), { x: 0, y: 0 });
  assert.deepEqual(mapXY(-58, 190), { x: MAP_W, y: MAP_H });
  assert.equal(mapXY(0, -175).x > MAP_W - 40, true, "west of -170 wraps to the right edge");
  const ar = countryCentroid("AR")!;
  assert.ok(ar.lat < -30 && ar.lat > -38 && ar.lon < -57 && ar.lon > -64, JSON.stringify(ar));
  const fj = countryCentroid("FJ")!;
  assert.ok(Math.abs(fj.lon) > 170, "Fiji stays near the 180° meridian, not at 0°");
  assert.equal(countryCentroid("ZZ"), null);
});
