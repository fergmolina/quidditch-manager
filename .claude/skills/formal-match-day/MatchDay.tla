------------------------------- MODULE MatchDay -------------------------------
(* A model of the match-day stepper of Quidditch Manager: src/game/game_engine.gd, functions begin_day,       *)
(* step_day, _finish_day, _open_day, _queue_matches, _match_step, _after_matches, _queue_resume_open_day,      *)
(* _after_resume, _open_human_fixture, _queue_close_day / _queue_end_of_day and complete_pending_match_begin,  *)
(* together with what the player, a reload (GameSession.load_game -> GameEngine.new) and a job change           *)
(* (GameEngine.accept_job, resign, accept_national_job) can do between steps.                                    *)
(*                                                                                                               *)
(* Promise checked: every fixture dated on a day is played exactly once before the calendar leaves that day,     *)
(* and the end-of-day work (close) runs exactly once per day, whatever order the player, a reload and a job      *)
(* change interleave with the engine's steps.                                                                    *)
(*                                                                                                               *)
(* Abstractions: the day's work that does not touch fixtures (daily, events, market, weekly, monthly) is one     *)
(* step; competitions are flattened into one ordered list of fixtures per day (the engine visits competitions   *)
(* sorted by id and fixtures in list order); the lineup check is a free choice at the two points where the      *)
(* engine evaluates it; the AI's own sackings and hirings inside the day are out of scope.                       *)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
  None,                      \* "no fixture" / "no team"
  Clubs,                     \* club ids the human can manage (w.player_club_id)
  NTs,                       \* national team ids the human can coach (w.manager.national_team_id)
  FixSeq,                    \* sequence of fixture records [id, day, home, away], in the engine's visiting order
  MaxDay,                    \* the calendar runs from day 0 (nothing played) to MaxDay
  InitClub, InitNT,          \* the human's club and national team at the start (None = none)
  BUG_DROP_HALF_DAY,         \* begin_day drops a half-stepped day instead of finishing it first (the guard at the top of begin_day)
  BUG_NO_RESUME,             \* begin_day never takes the resume branch (any competition's fixtures_on(w.today) not empty)
  BUG_NO_SECOND_HUMAN_FIXTURE, \* complete_pending_match_begin queues the close instead of the resume of the day, so it never looks for another human fixture today
  BUG_KEEP_FOREIGN_PENDING,  \* a job change keeps a pending match neither of whose teams the human manages any more (_release_foreign_pending_match)
  JOB_CHANGE_ON_OPEN_DAY     \* FALSE excludes job changes while a match day is still open (the finding fixed on 2026-10-25, see SKILL.md)

FixRecs == {FixSeq[i] : i \in DOMAIN FixSeq}
Fixtures == {r.id : r \in FixRecs}
Fx(f) == CHOOSE r \in FixRecs : r.id = f
Day(f) == Fx(f).day
OnDaySeq(d) == SelectSeq(FixSeq, LAMBDA r : r.day = d)
FxOn(d) == {f \in Fixtures : Day(f) = d}

VARIABLES
  today,      \* w.today
  played,     \* [Fixtures -> Nat]: how many times apply_result ran for the fixture (f["played"] is a bool in the code)
  closed,     \* [1..MaxDay -> Nat]: how many times the close of that day ran (_queue_end_of_day)
  steps,      \* the engine's remaining step queue (_steps from _step_i on), each a record with a `kind`
  pending,    \* GameEngine.pending_match's fixture, or None (volatile: not saved)
  humanFx,    \* GameEngine._human_fixture, or None (volatile)
  club,       \* w.player_club_id, or None when unemployed
  nt,         \* w.manager.national_team_id, or None
  result      \* GameEngine._day_result.reason (for reading traces)

vars == <<today, played, closed, steps, pending, humanFx, club, nt, result>>

Phase(k) == [kind |-> k]
FixtureStep(f, resume) == [kind |-> "fixture", f |-> f, resume |-> resume]
FixtureSteps(d, resume) == [i \in DOMAIN OnDaySeq(d) |-> FixtureStep(OnDaySeq(d)[i].id, resume)]

\* GameEngine._is_human, for the human's club c and national team n
HumanOf(t, c, n) == (c # None /\ t = c) \/ (n # None /\ t = n)
HumanInWith(f, c, n) == HumanOf(Fx(f).home, c, n) \/ HumanOf(Fx(f).away, c, n)
IsHuman(t) == HumanOf(t, club, nt)
HumanIn(f) == HumanInWith(f, club, nt)
\* GameEngine._is_club_fixture
IsClubFx(f) == club # None /\ (Fx(f).home = club \/ Fx(f).away = club)
Unplayed(f) == played[f] = 0

\* GameEngine._open_human_fixture: any unplayed fixture of the human today, the club's first
OpenClub == {f \in FxOn(today) : Unplayed(f) /\ IsClubFx(f)}
OpenAny == {f \in FxOn(today) : Unplayed(f) /\ HumanIn(f)}
OpenHumanFx == IF OpenClub # {} THEN CHOOSE f \in OpenClub : TRUE
               ELSE IF OpenAny # {} THEN CHOOSE f \in OpenAny : TRUE
               ELSE None

Init ==
  /\ today = 0
  /\ played = [f \in Fixtures |-> 0]
  /\ closed = [d \in 1..MaxDay |-> 0]
  /\ steps = <<>>
  /\ pending = None
  /\ humanFx = None
  /\ club = InitClub
  /\ nt = InitNT
  /\ result = "none"

(* GameEngine.begin_day. The code first finishes a day left half-stepped; here that is the interleaving      *)
(* "Step until the queue is empty, then BeginDay", so BeginDay waits for an empty queue unless the bug toggle  *)
(* drops the queue the way the code would without its guard. The day is open while any fixture of today is     *)
(* unplayed, read from the world, so a reload or a job change cannot lose it.                                  *)
BeginDay ==
  /\ steps = <<>> \/ BUG_DROP_HALF_DAY
  /\ IF pending # None THEN
          /\ steps' = <<>>
          /\ result' = "match_pending"
     ELSE IF (\E f \in FxOn(today) : Unplayed(f)) /\ ~BUG_NO_RESUME THEN
          /\ steps' = <<Phase("resume")>>
          /\ result' = "none"
     ELSE
          /\ today < MaxDay
          /\ steps' = <<Phase("open"), Phase("daily"), Phase("matches"), Phase("close")>>
          /\ result' = "none"
  /\ UNCHANGED <<today, played, closed, pending, humanFx, club, nt>>

(* GameEngine.step_day: one step of the queue. *)
StepOpen(s, rest) ==          \* _open_day
  /\ s.kind = "open"
  /\ today' = today + 1
  /\ steps' = rest
  /\ UNCHANGED <<played, closed, pending, humanFx, club, nt, result>>

StepDaily(s, rest) ==         \* _queue_daily, _events_step, _market_step: no fixture is touched
  /\ s.kind = "daily"
  /\ steps' = rest
  /\ UNCHANGED <<today, played, closed, pending, humanFx, club, nt, result>>

StepMatches(s, rest) ==       \* _queue_matches: one step per fixture of today, then _after_matches
  /\ s.kind = "matches"
  /\ humanFx' = None
  /\ steps' = FixtureSteps(today, FALSE) \o <<Phase("matches:done")>> \o rest
  /\ UNCHANGED <<today, played, closed, pending, club, nt, result>>

StepFixture(s, rest) ==       \* _match_step (resume = FALSE): hold back the human's fixture, play the others
  /\ s.kind = "fixture" /\ ~s.resume
  /\ steps' = rest
  /\ IF played[s.f] > 0 THEN
          UNCHANGED <<played, humanFx>>
     ELSE IF HumanIn(s.f) THEN
          /\ UNCHANGED played
          /\ IF humanFx = None \/ ~IsClubFx(humanFx) THEN humanFx' = s.f ELSE UNCHANGED humanFx
     ELSE
          /\ played' = [played EXCEPT ![s.f] = @ + 1]
          /\ UNCHANGED humanFx
  /\ UNCHANGED <<today, closed, pending, club, nt, result>>

StepFixtureResume(s, rest) == \* _match_step (resume = TRUE): the human's fixtures are left to _after_resume
  /\ s.kind = "fixture" /\ s.resume
  /\ steps' = rest
  /\ IF played[s.f] > 0 \/ HumanIn(s.f) THEN UNCHANGED played
     ELSE played' = [played EXCEPT ![s.f] = @ + 1]
  /\ UNCHANGED <<today, closed, pending, humanFx, club, nt, result>>

StepAfterMatches(s, rest) ==  \* _after_matches: the day stays open with the human's match pending, or the lineup blocks
  /\ s.kind = "matches:done"
  /\ IF humanFx # None THEN
          /\ \E blocked \in BOOLEAN :         \* lineup_blocked(): depends on the squad, free here
               IF IsClubFx(humanFx) /\ blocked THEN
                    /\ result' = "lineup"
                    /\ steps' = <<>>                \* _finish_day drops the rest of the day
                    /\ UNCHANGED pending
               ELSE
                    /\ pending' = humanFx          \* _prepare_human_match
                    /\ result' = "match"
                    /\ steps' = <<>>
     ELSE
          /\ steps' = rest
          /\ UNCHANGED <<pending, result>>
  /\ UNCHANGED <<today, played, closed, humanFx, club, nt>>

StepResume(s, rest) ==        \* _queue_resume_open_day
  /\ s.kind = "resume"
  /\ steps' = FixtureSteps(today, TRUE) \o <<Phase("matches:resume")>> \o rest
  /\ UNCHANGED <<today, played, closed, pending, humanFx, club, nt, result>>

StepAfterResume(s, rest) ==   \* _after_resume
  /\ s.kind = "matches:resume"
  /\ LET o == OpenHumanFx IN
     IF o = None THEN
          /\ steps' = <<Phase("close")>> \o rest
          /\ UNCHANGED <<pending, result>>
     ELSE \E blocked \in BOOLEAN :
          IF IsClubFx(o) /\ blocked THEN
               /\ result' = "lineup"
               /\ steps' = <<>>
               /\ UNCHANGED pending
          ELSE
               /\ pending' = o
               /\ result' = "match"
               /\ steps' = <<>>
  /\ UNCHANGED <<today, played, closed, humanFx, club, nt>>

StepClose(s, rest) ==         \* _queue_close_day -> _queue_end_of_day (weekly, monthly) and _close_day_result
  /\ s.kind = "close"
  /\ today \in 1..MaxDay
  /\ closed' = [closed EXCEPT ![today] = @ + 1]
  /\ steps' = rest
  /\ result' = "done"
  /\ UNCHANGED <<today, played, pending, humanFx, club, nt>>

Step ==
  /\ steps # <<>>
  /\ LET s == Head(steps)
         rest == Tail(steps)
     IN \/ StepOpen(s, rest)
        \/ StepDaily(s, rest)
        \/ StepMatches(s, rest)
        \/ StepFixture(s, rest)
        \/ StepFixtureResume(s, rest)
        \/ StepAfterMatches(s, rest)
        \/ StepResume(s, rest)
        \/ StepAfterResume(s, rest)
        \/ StepClose(s, rest)

(* GameEngine.complete_pending_match_begin: the UI finished the match; record it, then queue the resume of the   *)
(* open day (_queue_resume_open_day), which plays any fixture of today a job change has handed to the AI and     *)
(* then leaves the human's next fixture of the day pending or queues the close (_after_resume).                  *)
CompleteMatch ==
  /\ pending # None
  /\ played' = [played EXCEPT ![pending] = @ + 1]
  /\ pending' = None
  /\ steps' = IF BUG_NO_SECOND_HUMAN_FIXTURE THEN <<Phase("close")>> ELSE <<Phase("resume")>>
  /\ result' = "none"
  /\ UNCHANGED <<today, closed, humanFx, club, nt>>

(* GameSession.load_game: the world (today, fixtures, who the human manages) comes back from the save; the      *)
(* engine is new, so pending_match and _human_fixture are gone; whether the day is open is read from the       *)
(* fixtures, which the save keeps. The UI is busy while a day is stepping. Saving is refused only while the     *)
(* match screen runs a live match (main.gd _match_locked / save_and_confirm), so a save can hold a pending      *)
(* match: before kickoff (the press screen, or any screen the player leaves to), after the final whistle until  *)
(* Finish, and the autosave of Game.after_advance when the advance stops for a match.                           *)
Reload ==
  /\ steps = <<>>
  /\ pending' = None
  /\ humanFx' = None
  /\ result' = "none"
  /\ UNCHANGED <<today, played, closed, steps, club, nt>>

(* A match day that has begun but not closed: some fixture of today is still unplayed, or the close has not run. *)
DayInProgress == today \in 1..MaxDay /\ (closed[today] = 0 \/ \E f \in FxOn(today) : Unplayed(f))

(* GameEngine._release_foreign_pending_match, at the end of accept_job, resign and accept_national_job: a pending  *)
(* match neither of whose teams the human manages any more is dropped, and the resume of the day lets the AI play  *)
(* it, as for a fixture held back over the lineup.                                                                 *)
PendingAfterJobChange(c, n) ==
  IF pending # None /\ ~HumanInWith(pending, c, n) /\ ~BUG_KEEP_FOREIGN_PENDING THEN None ELSE pending

(* inbox_screen -> GameEngine.accept_job, manager_screen -> GameEngine.resign: reachable from any office screen  *)
(* whenever the match screen is not running a live match (main.gd go / _match_locked), so between days, on an    *)
(* open day whose advance stopped over the lineup, and with a match pending (before kickoff or after the final   *)
(* whistle). With JOB_CHANGE_ON_OPEN_DAY = FALSE the open-day cases are left out (the first three bug configs    *)
(* do this, so the removed guard alone causes their failure).                                                   *)
ChangeClub ==
  /\ steps = <<>>
  /\ JOB_CHANGE_ON_OPEN_DAY \/ ~DayInProgress
  /\ \E c \in (Clubs \cup {None}) \ {club} :
       /\ club' = c
       /\ pending' = PendingAfterJobChange(c, nt)
  /\ UNCHANGED <<today, played, closed, steps, humanFx, nt, result>>

(* inbox_screen -> GameEngine.accept_national_job (the federation can also take the team back: None). None also    *)
(* stands for a national team that does not play today, which the instance in MC.tla has no room for.            *)
ChangeNT ==
  /\ steps = <<>>
  /\ JOB_CHANGE_ON_OPEN_DAY \/ ~DayInProgress
  /\ \E n \in (NTs \cup {None}) \ {nt} :
       /\ nt' = n
       /\ pending' = PendingAfterJobChange(club, n)
  /\ UNCHANGED <<today, played, closed, steps, humanFx, club, result>>

Next == BeginDay \/ Step \/ CompleteMatch \/ Reload \/ ChangeClub \/ ChangeNT

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* Invariants. Each one is a sentence about the game. *)

\* No fixture's result is recorded twice (apply_result ran at most once per fixture).
NoDoublePlay == \A f \in Fixtures : played[f] <= 1

\* No fixture is played before its day.
NoFuturePlay == \A f \in Fixtures : played[f] > 0 => Day(f) <= today

\* The end of a day (weekly wages, monthly board, contracts) runs at most once per day.
ClosedOnce == \A d \in 1..MaxDay : closed[d] <= 1

\* Once the calendar has left a day, that day was closed.
PastDaysClosed == \A d \in 1..MaxDay : d < today => closed[d] = 1

\* Once the calendar has left a day, every fixture of that day has a result.
PastFixturesPlayed == \A f \in Fixtures : Day(f) < today => played[f] = 1

\* A day is closed only when every fixture of the day has a result.
ClosedMeansPlayed == \A d \in 1..MaxDay : closed[d] = 1 => \A f \in FxOn(d) : played[f] = 1

\* The match waiting for the player is today's and has not been played yet.
PendingIsToday == pending # None => Day(pending) = today /\ played[pending] = 0

\* The match waiting for the player is one of the teams the player manages: after a job change the AI plays it.
PendingIsHuman == pending # None => HumanIn(pending)

TypeOK ==
  /\ today \in 0..MaxDay
  /\ played \in [Fixtures -> Nat]
  /\ closed \in [1..MaxDay -> Nat]
  /\ pending \in Fixtures \cup {None}
  /\ humanFx \in Fixtures \cup {None}
  /\ club \in Clubs \cup {None}
  /\ nt \in NTs \cup {None}

=============================================================================
