-- Test AI Operators

SELECT * FROM ai.model_info_view;

-- Scalar tests
SELECT 'SCALAR TESTS' as test_section;

SELECT ai.generate('Is apple a fruit or a vegetable?') as apple_gen;
SELECT ai.generate('Is carrot a fruit or a vegetable?') as carrot_gen;
SELECT ai.generate('Summarize: AlloyDB is a fully managed PostgreSQL-compatible database service.') as summary_gen;

SELECT ai.if('Is apple a fruit?') as apple_if;
SELECT ai.if('Is carrot a fruit?') as carrot_if;

SELECT ai.rank('Score apple on a scale of 0 to 1') as apple_rank;
SELECT ai.rank('Score carrot on a scale of 0 to 1') as carrot_rank;

-- Batch/Array tests
SELECT 'BATCH TESTS' as test_section;

SELECT ai.generate(ARRAY['Is apple a fruit or a vegetable?', 'Is carrot a fruit or a vegetable?']) as batch_gen;
SELECT ai.if(ARRAY['Is apple a fruit?', 'Is carrot a fruit?']) as batch_if;
SELECT ai.rank(ARRAY['Score apple on a scale of 0 to 1', 'Score carrot on a scale of 0 to 1']) as batch_rank;
