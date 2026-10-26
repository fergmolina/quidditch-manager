import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { STATIC_DIR } from "../src/http/static.js";
import { locationFieldset, usernameField } from "../src/pages/profile-form.js";
import { REGISTER_JS } from "../src/pages/register-js.js";
import { cityChoice } from "../src/profile/profile.js";

const t = (k: string) => k;
const script = readFileSync(join(STATIC_DIR, "register.js"), "utf8");
const datasetKey = (attr: string) => attr.replace(/^data-/, "").replace(/-([a-z])/g, (_, c: string) => c.toUpperCase());

test("static/register.js reads every hook the profile form renders, by selector or dataset key", () => {
  const J = REGISTER_JS;
  assert.match(script, new RegExp(`\\[${J.geoForm}\\]`));
  for (const role of J.geoRoles) assert.ok(script.includes(`[${J.geoRole}="${role}"]`), role);
  for (const wrap of J.geoWraps) assert.ok(script.includes(`[${J.geoWrap}="${wrap}"]`), wrap);
  for (const attr of Object.values(J.cityTexts)) assert.ok(script.includes(`dataset.${datasetKey(attr)}`), attr);
  assert.ok(script.includes(`dataset.${datasetKey(J.cityOptionRegion)}`));
  assert.ok(script.includes(`input[${J.usernameCheck}]`));
  assert.ok(script.includes(`input.id + "${J.usernameStatusSuffix}"`));
  for (const attr of Object.values(J.usernameStatus)) assert.ok(script.includes(`dataset.${datasetKey(attr)}`), attr);
});

test("the rendered form carries the same hooks, with the texts the script shows", () => {
  const J = REGISTER_JS;
  const form = locationFieldset(t, "en", { country: "US", region: "CA", city: cityChoice("5368361") }, {}).value;
  assert.match(form, new RegExp(`<fieldset ${J.geoForm}>`));
  for (const role of ["country", "region", "city", "refresh-row"]) assert.ok(form.includes(` ${J.geoRole}="${role}"`), role);
  for (const wrap of J.geoWraps) assert.ok(form.includes(` ${J.geoWrap}="${wrap}"`), wrap);
  assert.ok(form.includes(` ${J.cityTexts.other}="web.profile.city_other"`));
  assert.ok(form.includes(` ${J.cityTexts.none}="web.profile.city_no_results"`));
  assert.ok(form.includes(` ${J.cityTexts.placeholder}="web.profile.city_search_placeholder"`));
  assert.ok(form.includes(`<option value="5368361" ${J.cityOptionRegion}="CA" selected>Los Angeles</option>`));
  const tooMany = locationFieldset(t, "en", { country: "US", region: "", city: cityChoice("") }, {}).value;
  assert.ok(tooMany.includes(` ${J.geoRole}="city-hint"`), "the no-JS hint the script hides");
  const username = usernameField(t, { value: "" }).value;
  assert.ok(username.includes(` ${J.usernameCheck}>`));
  assert.ok(username.includes(`id="username${J.usernameStatusSuffix}"`));
  assert.ok(username.includes(` ${J.usernameStatus.taken}="web.profile.error.username_taken"`));
});
