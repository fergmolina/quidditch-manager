---------------------------------- MODULE MC ----------------------------------
(* The model: two days, four clubs, two national teams. Day 1 has the human club's match, another club match   *)
(* and the national teams' match (the human coaches n1, so two human fixtures fall on the same day); day 2 has  *)
(* two club matches. Small enough for TLC to finish in seconds; big enough for every branch of the stepper.     *)
EXTENDS Naturals, Sequences
CONSTANTS a, b, c, d, n1, n2, f1, f2, f3, f4, f5, None,
          BUG_DROP_HALF_DAY, BUG_NO_RESUME, BUG_NO_SECOND_HUMAN_FIXTURE, BUG_KEEP_FOREIGN_PENDING,
          JOB_CHANGE_ON_OPEN_DAY
VARIABLES today, played, closed, steps, pending, humanFx, club, nt, result

MCFixSeq == << [id |-> f1, day |-> 1, home |-> a, away |-> b],
               [id |-> f2, day |-> 1, home |-> c, away |-> d],
               [id |-> f3, day |-> 1, home |-> n1, away |-> n2],
               [id |-> f4, day |-> 2, home |-> a, away |-> c],
               [id |-> f5, day |-> 2, home |-> b, away |-> d] >>

INSTANCE MatchDay WITH Clubs <- {a, b, c, d}, NTs <- {n1, n2}, FixSeq <- MCFixSeq, MaxDay <- 2,
                       InitClub <- a, InitNT <- n1
=============================================================================
