# Location picklists (GeoNames)

The region and city picklists on `/register` and `/account` read these files. Both fields are optional, and they are kept for a future map of where players come from.

## Source and license

- Data from [GeoNames](https://www.geonames.org), licensed under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/) (CC BY 4.0).
- Files used:
  - `admin1CodesASCII.txt`: first-level divisions (states, provinces, regions).
  - `cities5000.zip`: places with at least 5,000 inhabitants, plus the seats of first-level divisions.
- Changes made to the data:
  - kept only the columns listed below;
  - rounded the coordinates to 4 decimals;
  - dropped countries outside our ISO 3166-1 list (plus XK);
  - cleared city admin1 codes that do not exist in `admin1CodesASCII.txt`.
- The forms credit GeoNames under the location fields, and `ATTRIBUTION.md` at the repo root does too.
- `meta.json` records the download URLs, their `Last-Modified` dates and the row counts.

## Files

| File | Content |
|---|---|
| `admin1.json` | `{"<CC>": [{"code": "<admin1>", "name": "<name>"}, …]}`, sorted by code. `code` is the GeoNames admin1 code, which `users.region_code` stores. |
| `cities/<CC>.json` | One row per city, sorted by id. See the row layout below. |
| `meta.json` | Source, license, dates and counts. |

Each city row is `[geonameid, name, admin1, lat, lon, population, asciiname?]`:
- `admin1` is `""` when the place has no first-level division.
- `asciiname` is present only when folding `name` (accents removed, lower case) does not already give it, so a name that does not fold to plain ASCII can still be found by its ASCII spelling.

Size: about 4 MB in total, with 3,865 regions and 69,905 cities in 245 countries.

## Rebuilding

```sh
cd server
npm run build:geo                  # downloads from download.geonames.org and rewrites this folder
npm run build:geo -- --from <dir>  # or reads admin1CodesASCII.txt + cities5000.zip from <dir>
```

- The output is deterministic, so a rebuild only changes what changed upstream.
- Commit the result together with the updated `meta.json`.
- The server never downloads anything at run time.
- Rows already stored in `users` keep their values. A city that disappears upstream simply stops being offered.
