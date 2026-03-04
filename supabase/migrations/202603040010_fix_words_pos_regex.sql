alter table public.words
  drop constraint if exists words_pos_check;

alter table public.words
  add constraint words_pos_check check (
    pos ~ '^(prep[.]|phr[.] v[.]|v[.]|n[.]|adj[.]|adv[.]|NP|conj[.]|det[.]|modal)(;(prep[.]|phr[.] v[.]|v[.]|n[.]|adj[.]|adv[.]|NP|conj[.]|det[.]|modal))*$'
  ) not valid;
