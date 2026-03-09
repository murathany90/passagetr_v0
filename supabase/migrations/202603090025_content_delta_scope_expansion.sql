grant execute on function public.pull_content_changes(text, bigint, integer) to anon, authenticated;

drop trigger if exists trg_reading_sentences_content_change on public.reading_passage_sentences;
create trigger trg_reading_sentences_content_change
after insert or update or delete on public.reading_passage_sentences
for each row execute function public.log_content_change('reading_passage_sentences', 'readings');

drop trigger if exists trg_reading_passage_words_content_change on public.reading_passage_words;
create trigger trg_reading_passage_words_content_change
after insert or update or delete on public.reading_passage_words
for each row execute function public.log_content_change('reading_passage_words', 'readings');

drop trigger if exists trg_grammar_examples_content_change on public.gramer_ornekler;
create trigger trg_grammar_examples_content_change
after insert or update or delete on public.gramer_ornekler
for each row execute function public.log_content_change('gramer_ornekler', 'grammar');

drop trigger if exists trg_grammar_tests_content_change on public.gramer_testler;
create trigger trg_grammar_tests_content_change
after insert or update or delete on public.gramer_testler
for each row execute function public.log_content_change('gramer_testler', 'grammar');
