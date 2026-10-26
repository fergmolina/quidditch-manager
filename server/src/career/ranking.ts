import type { Db } from "../db.js";

export const RANKING_LIMIT = 100;

export interface RankingRow {
  user_id: string;
  username: string;
  country_code: string | null;
  reputation: number;
  titles: number;
  seasons: number;
  last_season: number;
  mode: string;
  club_name: string | null;
}

export async function ranking(db: Db, country: string | null): Promise<RankingRow[]> {
  return db.query<RankingRow>(
    `with best as (
       select distinct on (c.user_id) c.user_id, c.career_id, c.last_reputation, c.last_titles, c.last_seasons,
              c.last_season, c.mode
         from public.careers c
         join public.users u on u.id = c.user_id
        where c.flagged_at is null and u.blocked_at is null and u.username is not null
          and ($1::text is null or u.country_code = $1)
        order by c.user_id, c.last_reputation desc, c.last_season desc
     )
     select b.user_id, u.username, u.country_code, b.last_reputation as reputation, b.last_titles as titles,
            b.last_seasons as seasons, b.last_season, b.mode, s.club_name
       from best b
       join public.users u on u.id = b.user_id
       left join public.career_seasons s on s.career_id = b.career_id and s.season = b.last_season
      order by b.last_reputation desc, b.last_titles desc, lower(u.username)
      limit ${RANKING_LIMIT}`,
    [country],
  );
}

export async function rankedCountries(db: Db): Promise<string[]> {
  const rows = await db.query<{ country_code: string }>(
    `select distinct u.country_code
       from public.careers c join public.users u on u.id = c.user_id
      where c.flagged_at is null and u.blocked_at is null and u.username is not null and u.country_code is not null`,
  );
  return rows.map((r) => r.country_code);
}


export interface CountryRow {
  country_code: string;
  managers: number;
  best_reputation: number;
  avg_reputation: number;
  best_username: string;
}

export async function rankingByCountry(db: Db): Promise<CountryRow[]> {
  const rows = await db.query<{ country_code: string; managers: string | number; best_reputation: number; avg_reputation: string | number; best_username: string }>(
    `with best as (
       select distinct on (c.user_id) c.user_id, c.last_reputation, u.username, u.country_code
         from public.careers c
         join public.users u on u.id = c.user_id
        where c.flagged_at is null and u.blocked_at is null and u.username is not null and u.country_code is not null
        order by c.user_id, c.last_reputation desc, c.last_season desc
     )
     select country_code, count(*) as managers, max(last_reputation) as best_reputation,
            round(avg(last_reputation)) as avg_reputation,
            (array_agg(username order by last_reputation desc, lower(username)))[1] as best_username
       from best
      group by country_code
      order by max(last_reputation) desc, count(*) desc, country_code`,
  );
  return rows.map((r) => ({ ...r, managers: Number(r.managers), avg_reputation: Number(r.avg_reputation) }));
}
