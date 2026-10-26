/*
 * Progressive enhancement for /register and /account (src/pages/profile-form.ts). The forms work without this
 * file: plain <select>s plus an "update the lists" button. With it:
 *   - the update button is hidden; changing the country reloads its regions (GET /api/geo/regions);
 *   - the city <select> becomes a search-as-you-type box (GET /api/geo/cities) that posts the same `city` field
 *     (a GeoNames id, "other", or empty);
 *   - the username field says whether a name is free (GET /api/username-available).
 * Loaded with <script src defer> (CSP script-src 'self'): no inline code, no eval, no inline styles. Every visible
 * text comes from data-* attributes rendered by the server in the page language.
 */
(function () {
  "use strict";

  function getJson(url) {
    return fetch(url, { credentials: "same-origin", headers: { Accept: "application/json" } }).then(function (r) {
      return r.ok ? r.json() : null;
    });
  }

  // ---- username availability ------------------------------------------------------------------------------------
  var USERNAME_RE = /^[A-Za-z][A-Za-z0-9_]{2,19}$/;
  Array.prototype.forEach.call(document.querySelectorAll("input[data-username-check]"), function (input) {
    var status = document.getElementById(input.id + "-status");
    if (!status) return;
    var timer = 0;
    input.addEventListener("input", function () {
      clearTimeout(timer);
      status.textContent = "";
      status.className = "help";
      var value = input.value.trim();
      if (!USERNAME_RE.test(value)) return;
      timer = setTimeout(function () {
        getJson("/api/username-available?u=" + encodeURIComponent(value))
          .then(function (d) {
            if (!d || input.value.trim() !== value) return;
            var msg = d.available ? status.dataset.ok : d.error === "username_taken" ? status.dataset.taken : d.error === "username_reserved" ? status.dataset.reserved : d.error === "username_blocked" ? status.dataset.blocked : "";
            status.textContent = msg || "";
            status.className = "help " + (d.available ? "ok" : "bad");
          })
          .catch(function () {});
      }, 400);
    });
  });

  // ---- location picklists ---------------------------------------------------------------------------------------
  var box = document.querySelector("[data-geo-form]");
  if (!box) return;
  var country = box.querySelector('[data-geo="country"]');
  var region = box.querySelector('[data-geo="region"]');
  var regionWrap = box.querySelector('[data-geo-wrap="region"]');
  var cityWrap = box.querySelector('[data-geo-wrap="city"]');
  var citySelect = box.querySelector('[data-geo="city"]');
  var refreshRow = box.querySelector('[data-geo="refresh-row"]');
  var hint = box.querySelector('[data-geo="city-hint"]');
  if (!country || !region || !cityWrap || !citySelect) return;

  // Removed, not disabled: a disabled submit button would still be the form's default button and Enter in a text
  // field would then submit nothing.
  if (refreshRow) refreshRow.parentNode.removeChild(refreshRow);
  if (hint) hint.hidden = true;

  var texts = { other: cityWrap.dataset.other || "", none: cityWrap.dataset.none || "", placeholder: cityWrap.dataset.placeholder || "" };

  // Replace the <select> with: text input (combobox) + listbox + hidden `city` field.
  var picked = citySelect.options[citySelect.selectedIndex];
  var hidden = document.createElement("input");
  hidden.type = "hidden";
  hidden.name = "city";
  hidden.value = citySelect.value;
  var cityRegion = picked && picked.dataset ? picked.dataset.region || "" : "";

  var input = document.createElement("input");
  input.type = "text";
  input.id = citySelect.id;
  input.autocomplete = "off";
  input.spellcheck = false;
  input.placeholder = texts.placeholder;
  input.setAttribute("role", "combobox");
  input.setAttribute("aria-autocomplete", "list");
  input.setAttribute("aria-expanded", "false");
  input.setAttribute("aria-controls", "city-list");
  ["aria-describedby", "aria-invalid"].forEach(function (a) {
    if (citySelect.hasAttribute(a)) input.setAttribute(a, citySelect.getAttribute(a));
  });
  if (citySelect.value === "other") input.value = texts.other;
  else if (citySelect.value && picked) input.value = picked.textContent;

  var list = document.createElement("ul");
  list.id = "city-list";
  list.className = "combo-list";
  list.setAttribute("role", "listbox");
  list.hidden = true;

  citySelect.parentNode.insertBefore(input, citySelect);
  citySelect.parentNode.insertBefore(list, citySelect);
  citySelect.parentNode.insertBefore(hidden, citySelect);
  citySelect.parentNode.removeChild(citySelect);

  var items = [];
  var active = -1;
  var seq = 0;
  var timer = 0;

  function open() {
    list.hidden = false;
    input.setAttribute("aria-expanded", "true");
  }
  function close() {
    list.hidden = true;
    input.setAttribute("aria-expanded", "false");
    input.removeAttribute("aria-activedescendant");
    active = -1;
  }
  function highlight(i) {
    var lis = list.querySelectorAll('[role="option"]');
    Array.prototype.forEach.call(lis, function (li, n) {
      li.setAttribute("aria-selected", n === i ? "true" : "false");
    });
    active = i;
    if (lis[i]) {
      input.setAttribute("aria-activedescendant", lis[i].id);
      lis[i].scrollIntoView({ block: "nearest" });
    }
  }
  function choose(i) {
    var it = items[i];
    if (!it) return;
    hidden.value = it.value;
    input.value = it.label;
    cityRegion = it.region || "";
    if (it.region && region.value !== it.region) region.value = it.region;
    close();
  }
  function render(cities) {
    items = cities.map(function (c) {
      return { value: String(c.id), label: c.name, sub: !region.value && c.region_name ? c.region_name : "", region: c.region || "" };
    });
    items.push({ value: "other", label: texts.other, sub: "", region: "" });
    list.textContent = "";
    if (!cities.length && input.value.trim()) {
      var none = document.createElement("li");
      none.className = "muted";
      none.textContent = texts.none;
      list.appendChild(none);
    }
    items.forEach(function (it, i) {
      var li = document.createElement("li");
      li.id = "city-opt-" + i;
      li.setAttribute("role", "option");
      li.setAttribute("aria-selected", "false");
      li.textContent = it.label;
      if (it.sub) {
        var sub = document.createElement("span");
        sub.className = "sub";
        sub.textContent = " · " + it.sub;
        li.appendChild(sub);
      }
      li.addEventListener("mousedown", function (e) {
        e.preventDefault();
        choose(i);
      });
      list.appendChild(li);
    });
    active = -1;
    open();
  }
  function search() {
    if (!country.value) {
      close();
      return;
    }
    var mine = ++seq;
    var q = new URLSearchParams({ country: country.value, region: region.value || "", q: input.value.trim() });
    getJson("/api/geo/cities?" + q.toString())
      .then(function (d) {
        if (mine === seq && document.activeElement === input) render((d && d.cities) || []);
      })
      .catch(function () {});
  }

  input.addEventListener("input", function () {
    hidden.value = "";
    clearTimeout(timer);
    timer = setTimeout(search, 200);
  });
  input.addEventListener("focus", function () {
    if (!hidden.value) search();
  });
  input.addEventListener("blur", function () {
    setTimeout(close, 150);
  });
  input.addEventListener("keydown", function (e) {
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      if (list.hidden) {
        search();
        return;
      }
      var n = items.length;
      if (!n) return;
      highlight(e.key === "ArrowDown" ? (active + 1) % n : (active - 1 + n) % n);
    } else if (e.key === "Enter" && !list.hidden && active >= 0) {
      e.preventDefault();
      choose(active);
    } else if (e.key === "Escape" && !list.hidden) {
      e.preventDefault();
      close();
    }
  });

  function clearCity() {
    hidden.value = "";
    input.value = "";
    cityRegion = "";
    close();
  }

  country.addEventListener("change", function () {
    clearCity();
    while (region.options.length > 1) region.remove(1);
    region.value = "";
    if (!country.value) {
      if (regionWrap) regionWrap.hidden = false;
      return;
    }
    var cc = country.value;
    getJson("/api/geo/regions?country=" + encodeURIComponent(cc))
      .then(function (d) {
        if (country.value !== cc) return;
        var regions = (d && d.regions) || [];
        regions.forEach(function (r) {
          region.add(new Option(r.name, r.code));
        });
        if (regionWrap) regionWrap.hidden = regions.length === 0;
      })
      .catch(function () {});
  });

  region.addEventListener("change", function () {
    if (hidden.value && hidden.value !== "other" && cityRegion && cityRegion !== region.value) clearCity();
  });
})();
