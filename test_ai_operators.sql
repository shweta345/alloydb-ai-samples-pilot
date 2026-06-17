-- Test AI Operators using exact queries from docs (with resolved placeholders and syntax fixes)

\echo '=== STARTING TEST FOR evaluate-semantic-queries-ai-operators ==='

-- 1. Register model global (L98)
\echo 'Testing google_ml.create_model for gemini-2.5-flash-lite-global...'
CALL google_ml.drop_model('gemini-2.5-flash-lite-global');
CALL google_ml.create_model(
    model_id => 'gemini-2.5-flash-lite-global',
    model_type => 'llm',
    model_provider => 'google',
    model_qualified_name => 'gemini-2.5-flash-lite',
    model_request_url =>  'https://aiplatform.googleapis.com/v1/projects/fake-project/locations/global/publishers/google/models/gemini-2.5-flash-lite:generateContent',
    model_auth_type => 'alloydb_service_agent_iam'
);

-- Mockify it for local test execution
UPDATE google_ml.models 
SET provider = 'custom'::google_ml.model_provider, 
    request_url = 'http://host.docker.internal:8080/vertexai/gemini-2.5-flash-lite-global',
    auth_type = 'secret_manager'::google_ml.auth_type,
    auth_id = 'fake_secret_id',
    header_gen_fn = 'google_ml.fake_gemini_headers'
WHERE id = 'gemini-2.5-flash-lite-global';


-- 2. Register model 3 (L114)
\echo 'Testing google_ml.create_model for gemini-3-preview-model...'
CALL google_ml.drop_model('gemini-3-preview-model');
CALL google_ml.create_model(
    model_id => 'gemini-3-preview-model',
    model_request_url => 'https://aiplatform.googleapis.com/v1/projects/fake-project/locations/global/publishers/google/models/gemini-3-pro-preview:generateContent',
    model_qualified_name => 'gemini-3-pro-preview',
    model_provider => 'google',
    model_type => 'llm',
    model_auth_type => 'alloydb_service_agent_iam'
);

-- Mockify it
UPDATE google_ml.models 
SET provider = 'custom'::google_ml.model_provider, 
    request_url = 'http://host.docker.internal:8080/vertexai/gemini-3-preview-model',
    auth_type = 'secret_manager'::google_ml.auth_type,
    auth_id = 'fake_secret_id',
    header_gen_fn = 'google_ml.fake_gemini_headers'
WHERE id = 'gemini-3-preview-model';


-- 3. Use model 3 (L133)
\echo 'Testing ai.generate with gemini-3-preview-model...'
SELECT ai.generate(prompt => 'What is AlloyDB?', model_id => 'gemini-3-preview-model');


-- 4. Filter scalar (L163)
\echo 'Testing ai.if scalar...'
SELECT r.name, r.location_city
FROM restaurant_reviews r
WHERE
  AI.IF(r.location_city || ' has a population OF more than 100,000 AND the following is a positive review; Review: ' || r.review)
GROUP BY r.name, r.location_city
HAVING COUNT(*) > 0; -- Changed from > 500 to > 0 to get results with dummy data


-- 5. Filter scalar with model (L176)
\echo 'Testing ai.if scalar with model_id...'
SELECT r.name, r.location_city
FROM restaurant_reviews r
WHERE
  AI.IF(r.location_city || ' has a population of more than 100,000 AND the following is a positive review; Review: ' || r.review, model_id => 'gemini-2.5-flash-lite')
GROUP BY r.name, r.location_city
HAVING COUNT(*) > 0; -- Changed from > 500 to > 0


-- 6. Join with IF (L191)
\echo 'Testing join with ai.if...'
SELECT item_name, COUNT(*)
FROM menu_items JOIN user_reviews
  ON ai.if(
    prompt => 'Does the following user review talk about the menu item mentioned ? review: ' || user_reviews.review_text || ' menu item: ' || item_name)
GROUP BY item_name;


-- 7. Array-based filter (L207) - Fixed city -> location_city
\echo 'Testing array-based ai.if...'
WITH initial_arrays AS (
  SELECT
    ARRAY_AGG(r.id ORDER BY r.id) AS review_ids,
    ai.if(
      prompts => ARRAY_AGG('Is the review positive: ' || r.review ORDER BY r.id),
      model_id => 'gemini-2.5-flash-lite',
      batch_size => 20
    ) AS truth_values
  FROM restaurant_reviews r
),
reviews AS (
SELECT
  initial_arrays.review_ids[i] AS review_id,
  initial_arrays.truth_values[i] AS truth_value
FROM
  initial_arrays,
  generate_series(1, array_length(initial_arrays.review_ids, 1)) AS i
)
SELECT rest_review.location_city, rest_review.name
FROM restaurant_reviews rest_review JOIN reviews review ON rest_review.id=review.review_id
WHERE review.truth_value = true
GROUP BY rest_review.location_city, rest_review.name
HAVING COUNT(*) > 0; -- Changed from > 10 to > 0


-- 8. Cursor-based filter (L241)
\echo 'Testing cursor-based ai.if...'
DROP TABLE IF EXISTS filtered_results;
CREATE TABLE filtered_results(input text, result bool);

DO $$
DECLARE
    prompt_cursor REFCURSOR;
    result_cursor REFCURSOR;
    rec RECORD;
BEGIN
    OPEN prompt_cursor FOR
        SELECT r.location_city || ' has a population of > 100,000 and is a positive review; Review: ' || r.review
        FROM restaurant_reviews r;

    result_cursor := ai.if(
        'Is the given statement true? ',
        prompt_cursor,
        model_id => 'gemini-2.5-flash-lite'
    );

    LOOP
        FETCH result_cursor INTO rec;
        EXIT WHEN NOT FOUND;
        INSERT INTO filtered_results VALUES(rec.input, rec.output);
    END LOOP;

    CLOSE result_cursor;
END $$;

SELECT * FROM filtered_results;


-- 9. Scalar generate (L291)
\echo 'Testing ai.generate scalar...'
SELECT
  ai.generate(
    prompt => 'Summarize the review in 20 words or less. Review: ' || review) AS review_summary
FROM user_reviews;


-- 10. Array-based generate (L303) - Fixed trailing comma
\echo 'Testing array-based ai.generate...'
SELECT
  UNNEST(
    ai.generate(
      prompts => ARRAY_AGG('Summarize the review in 20 words or less. Review: ' || review),
      model_id => 'gemini-2.5-flash-lite'
    )
  ) AS review_summary
FROM user_reviews;


-- 11. Cursor-based generate (L319) - Fixed trailing comma
\echo 'Testing cursor-based ai.generate...'
DROP TABLE IF EXISTS summary_results;
CREATE TABLE summary_results(summary text);

DO $$
DECLARE
    prompt_cursor REFCURSOR;
    summary_cursor REFCURSOR;
    rec RECORD;
BEGIN
    OPEN prompt_cursor FOR SELECT review_text FROM user_reviews ORDER BY id;

    summary_cursor := ai.generate(
        'Summarize the review in 20 words or less. Review:',
        prompt_cursor
    );

    LOOP
        FETCH summary_cursor INTO rec;
        EXIT WHEN NOT FOUND;
        INSERT INTO summary_results VALUES(rec.output);
    END LOOP;

    CLOSE summary_cursor;
END $$;

SELECT * FROM summary_results;


-- 12. Scalar rank (L363)
\echo 'Testing ai.rank scalar...'
SELECT review AS top20
FROM user_reviews
ORDER BY ai.rank(
  'Score the following review according to these rules:
  (1) Score OF 8 to 10 IF the review says the food IS excellent.
  (2) 4 to 7 IF the review says the food is ok.
  (3) 1 to 3 IF the review says the food is not good. Here is the review:' || review) DESC
LIMIT 20;


-- 13. Array-based rank (L386) - Fixed trailing comma
\echo 'Testing array-based ai.rank...'
SELECT
  UNNEST(
    ai.rank(
      ARRAY_AGG('Score the following review according to these rules:
  (1) Score OF 8 to 10 IF the review says the food IS excellent.
  (2) 4 to 7 IF the review says the food is ok.
  (3) 1 to 3 IF the review says the food is not good. Here is the review:' || review)
    )
  ) as review_scores
FROM user_reviews;


-- 14. Cursor-based rank (L410) - Fixed trailing comma
\echo 'Testing cursor-based ai.rank...'
DROP TABLE IF EXISTS scored_results;
CREATE TABLE scored_results(input text, score real);

DO $$
DECLARE
    prompt_cursor REFCURSOR;
    score_cursor REFCURSOR;
    rec RECORD;
BEGIN
    OPEN prompt_cursor FOR SELECT review FROM user_reviews ORDER BY id;

    score_cursor := ai.rank(
        'Score the following review: (1) 8-10 if excellent, (2) 4-7 if ok, (3) 1-3 if not good. Review:',
        prompt_cursor
    );

    LOOP
        FETCH score_cursor INTO rec;
        EXIT WHEN NOT FOUND;
        INSERT INTO scored_results VALUES(rec.input, rec.output);
    END LOOP;

    CLOSE score_cursor;
END $$;

SELECT * FROM scored_results;

\echo '=== TEST COMPLETED SUCCESSFULLY ==='
