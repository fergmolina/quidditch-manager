<!--
  AUTHORITATIVE TEXT. The nine translations (privacy.<lang>.md) follow this file: same headings, same number of list
  items, same links and the same {placeholders} (test/legal.test.ts checks it). Change this file first, then the
  translations, and bump TERMS_VERSION when a change matters to users.

  Placeholders, filled by server/src/pages/legal.ts:
    {controller}  LEGAL_CONTROLLER on the server   (until set: "[Operator name]")
    {contact}     LEGAL_CONTACT_EMAIL on the server (until set: "[contact email on the game's domain]")
    {min_age}     the minimum age (13)
  Never write a real name or address in this file: the repository is public.

  Backup retention (7 daily + 4 weekly dumps → "within 45 days") must match deploy/env.example.
-->
# Privacy policy

Quidditch Manager is a free, non-commercial fan game. This policy explains what personal data the online (browser) version keeps and why. The desktop versions for Windows and macOS work offline, have no account and send us nothing.

## Who is responsible

The controller of your personal data is {controller}. You can write to {contact} about anything in this policy.

## What we keep

To play in the browser you need a free account. We keep:

- **Your email address.** You sign in with it, through a link we email you or through Google. It is never shown in the game or to other players.
- **Your Google account ID**, only if you sign in with Google. Google gives us that ID, your email address and whether the address is verified. Google may also send your name and photo; we do not keep them.
- **Your username**, and when you last changed it. Other players may see your username, for example in a future ranking.
- **Your first and last name**, only if you choose to give them. They are never shown to other players.
- **Your country**, and only if you choose, **your region and your city**, picked from a public list of places. For the city we keep its name, its GeoNames ID and the coordinates of the city, never your address.
- **The version of these documents you accepted**, and when.
- **Account dates**: when you created the account and when you last signed in.
- **Moderation flags**, only if needed: whether the account is blocked, or must choose a new username.
- **Your sessions**, one per device you are signed in on: when it started, when it was last used, when it expires, and a rough browser description such as "Firefox · Windows". Sessions do not keep your IP address.
- **Sign-in links**: your email address, a fingerprint of the link (not the link itself), the page language, the page to return to, and a keyed hash of your network address (your IPv4 address, or the first half of an IPv6 address).
- **Abuse counters**: account IDs or keyed hashes of network addresses, used to limit how many requests can be made.
- **Season summaries of your careers**: when you finish a season of a game in the browser, the game sends that career's number (a random code, not your save), the season, the date in the game, your manager's reputation, the club, your titles and seasons managed, and the game version. They are for a future ranking, overall and by country. A summary that fails our plausibility checks is marked and left out of rankings.
- **Your feedback**, only if you use the feedback form: whether it is a bug or an idea, your message, the page language, the reply address if you choose to give one, and your account ID if you were signed in. No network address is stored with the message, only the abuse counter above. You do not need an account to send feedback; if you delete your account, your feedback stays but is no longer linked to you.

We do **not** keep your saved games: they stay in your browser and in the files you download. We use no analytics, no advertising and no tracking, and we never sell your data or use it for marketing.

## Why we use it

- **To provide your account and the game**: create the account, sign you in, show your username and country, and later rankings or a map of players by country, region and city. Legal basis: the contract you accept with the terms of use (Art. 6(1)(b) GDPR).
- **To keep the service safe**: limit sign-in requests, stop abuse and moderate usernames. Legal basis: our legitimate interest in a secure service (Art. 6(1)(f) GDPR).

We do not ask for your consent for anything, because we do nothing that needs it.

## Cookies

We only use cookies the site needs to work, so there is no cookie banner:

- `__Host-qm_session` keeps you signed in, for up to 30 days after your last visit and never more than 180 days.
- `__Host-qm_oauth` exists only during a Google sign-in and expires after 10 minutes.
- `qm_lang` remembers your language for one year.

The game also keeps your saves and settings in your browser's storage. They only leave your device if you download them.

## Who else handles it

These companies process data for us, only to run the service:

- **Hetzner Online GmbH** (Germany): our server and database run in its data centre in Germany.
- **Cloudflare, Inc.** (USA): delivers the website and protects it from attacks. Your requests and your IP address pass through its network.
- **Resend** (USA): sends the sign-in emails. It receives your email address and the email.
- **Google**: only if you choose to continue with Google. Your Google account is governed by Google's own privacy policy.
- **Backblaze, Inc.**: stores the database backups in its European region (the Netherlands).

When data goes to the USA, it is protected by the EU-US Data Privacy Framework or by the European Commission's standard contractual clauses.

## How long we keep it

- **Account data**: while your account exists. When you delete your account, it is erased from the live database at once.
- **Backups**: copies of the database are kept for up to five weeks, so deleted data also disappears from the backups within 45 days.
- **Sessions**: until you sign out, or until they expire (30 days without use, 180 days at most).
- **Sign-in links**: they work for 15 minutes and are deleted about one day after they expire.
- **Abuse counters**: one day.
- **Feedback**: 12 months, or earlier if you ask us to delete it. The reply address is used only to answer you.

## Your rights

- **Access and download**: your [account page](/account) shows your data and lets you download all of it.
- **Correction**: change your details on your [account page](/account).
- **Deletion**: delete your account yourself on your [account page](/account). It takes effect at once.
- **Sessions**: sign out of one device or of all of them on your [account page](/account).
- **Anything else**, including objecting to a use of your data: write to {contact} from the email address of your account.
- **Complaints**: you can complain to the data protection authority of your country.

If you signed in with Google, you can also remove the game's access at [myaccount.google.com/connections](https://myaccount.google.com/connections).

## Children

You must be at least {min_age} years old to create an account. If you are younger, please do not sign up. If we learn that an account belongs to someone under {min_age}, we will delete it.

## Changes

When this policy changes in a way that matters, we update the version date at the top, and you will be asked to accept the new version the next time you sign in.

## Language

This policy is written in English, and the English text is the authoritative version. Translations into other languages are provided for convenience; if a translation differs from the English text, the English text prevails.
