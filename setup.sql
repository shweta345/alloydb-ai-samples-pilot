-- Enable extensions
CREATE EXTENSION IF NOT EXISTS google_ml_integration CASCADE;
CREATE EXTENSION IF NOT EXISTS vector CASCADE;

-- Enable GUCs
ALTER SYSTEM SET google_ml_integration.enable_ai_query_engine = ON;
ALTER SYSTEM SET google_ml_integration.enable_model_support = ON;
ALTER SYSTEM SET google_ml_integration.allow_http_endpoints = ON;
ALTER SYSTEM SET google_ml_integration.enable_preview_ai_functions = ON;
SELECT PG_RELOAD_CONF();

-- Register mock models pointing to the mock server
-- We use model_provider => 'custom' to avoid default Vertex AI auth checks.
-- We use the built-in transform functions for Vertex AI.
-- We use host.docker.internal to access the host from the container.

-- Register text-embedding-005 mock
CALL google_ml.create_model(
    model_id => 'text-embedding-005',
    model_request_url => 'http://host.docker.internal:8080/vertexai/text-embedding-005',
    model_provider => 'custom',
    model_type => 'text_embedding',
    model_auth_type => NULL,
    model_in_transform_fn => 'google_ml.vertexai_text_embedding_input_transform',
    model_out_transform_fn => 'google_ml.vertexai_text_embedding_output_transform'
);

-- Register gemini-embedding-001 mock
CALL google_ml.create_model(
    model_id => 'gemini-embedding-001',
    model_request_url => 'http://host.docker.internal:8080/vertexai/gemini-embedding-001',
    model_provider => 'custom',
    model_type => 'text_embedding',
    model_auth_type => NULL,
    model_in_transform_fn => 'google_ml.vertexai_text_embedding_input_transform',
    model_out_transform_fn => 'google_ml.vertexai_text_embedding_output_transform'
);

-- Register OpenAI mock
CALL google_ml.create_model(
    model_id => 'text-embedding-ada-002',
    model_request_url => 'http://host.docker.internal:8080/openai/text-embedding-ada-002',
    model_provider => 'custom',
    model_type => 'text_embedding',
    model_auth_type => NULL,
    model_in_transform_fn => 'google_ml.openai_text_embedding_input_transform',
    model_out_transform_fn => 'google_ml.openai_text_embedding_output_transform'
);

CALL google_ml.create_model(
    model_id => 'text-embedding-3-small',
    model_request_url => 'http://host.docker.internal:8080/openai/text-embedding-3-small',
    model_provider => 'custom',
    model_type => 'text_embedding',
    model_auth_type => NULL,
    model_in_transform_fn => 'google_ml.openai_text_embedding_input_transform',
    model_out_transform_fn => 'google_ml.openai_text_embedding_output_transform'
);

-- Create fake secret for batch LLM
CALL google_ml.create_sm_secret(
    secret_id => 'fake_secret_id',
    secret_path => 'projects/fake-project/secrets/fake-secret/versions/1'
);

-- Create fake header function to bypass secret manager call in ml-agent
-- Batch version
CREATE OR REPLACE FUNCTION google_ml.fake_gemini_headers(
    model_id character varying,
    prompts text[],
    generation_config json,
    system_instructions json
)
RETURNS json
LANGUAGE sql
AS $$
  SELECT '{"Authorization": "FakeToken"}'::json;
$$;

-- Scalar version
CREATE OR REPLACE FUNCTION google_ml.fake_gemini_headers(
    model_id character varying,
    prompt text,
    generation_config json,
    system_instructions json
)
RETURNS json
LANGUAGE sql
AS $$
  SELECT '{"Authorization": "FakeToken"}'::json;
$$;

-- Register gemini-2.5-flash-lite mock
CALL google_ml.create_model(
    model_id => 'gemini-2.5-flash-lite',
    model_request_url => 'http://host.docker.internal:8080/vertexai/gemini-2.5-flash-lite',
    model_provider => 'custom',
    model_type => 'llm',
    model_qualified_name => 'gemini-2.5-flash-lite',
    model_auth_type => 'secret_manager',
    model_auth_id => 'fake_secret_id',
    generate_headers_fn => 'google_ml.fake_gemini_headers',
    model_in_transform_fn => 'google_ml.gemini_llm_input_transform',
    model_out_transform_fn => 'google_ml.gemini_llm_output_transform',
    model_batch_in_transform_fn => 'google_ml.gemini_llm_batch_input_transform',
    model_batch_out_transform_fn => 'google_ml.gemini_llm_batch_output_transform'
);

-- Override ai schema functions to default model_id to 'gemini-2.5-flash-lite'
-- This avoids PrivateKeyFileError in mock environment when model_id is omitted.

-- ai.generate overrides
CREATE OR REPLACE FUNCTION ai.generate(prompts text[], batch_size integer DEFAULT NULL, model_id varchar(100) DEFAULT 'gemini-2.5-flash-lite')
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE COST 2e+08
AS $function$
    SELECT google_ml.inc_call_count_impl(20);
    SELECT google_ml.generate(prompts => prompts, batch_size => batch_size, model_id => model_id);
$function$;

CREATE OR REPLACE FUNCTION ai.generate(prompt text, input_cursor refcursor, batch_size integer DEFAULT NULL, model_id varchar(100) DEFAULT 'gemini-2.5-flash-lite')
 RETURNS refcursor
 LANGUAGE sql
 COST 2e+08
AS $function$
      SELECT google_ml.inc_call_count_impl(20);
      SELECT google_ml.generate(prompt => prompt, input_cursor => input_cursor, batch_size => batch_size, model_id => model_id);
$function$;

CREATE OR REPLACE FUNCTION ai.generate(prompt text, model_id varchar(100) DEFAULT 'gemini-2.5-flash-lite')
 RETURNS text
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE COST 5e+07
AS $function$
    SELECT google_ml.inc_call_count_impl(12);
    SELECT google_ml.generate(prompt => prompt, model_id => model_id);
$function$;

-- ai.if overrides
CREATE OR REPLACE FUNCTION ai.if(prompts text[], batch_size integer DEFAULT NULL, model_id varchar(100) DEFAULT 'gemini-2.5-flash-lite')
 RETURNS boolean[]
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE COST 2e+08
AS $function$
    SELECT google_ml.inc_call_count_impl(19);
    SELECT google_ml.if(prompts => prompts, batch_size => batch_size, model_id => model_id);
$function$;

CREATE OR REPLACE FUNCTION ai.if(prompt text, input_cursor refcursor, batch_size integer DEFAULT NULL, model_id varchar(100) DEFAULT 'gemini-2.5-flash-lite')
 RETURNS refcursor
 LANGUAGE sql
 COST 2e+08
AS $function$
      SELECT google_ml.inc_call_count_impl(19);
      SELECT google_ml.if(prompt => prompt, input_cursor => input_cursor, batch_size => batch_size, model_id => model_id);
$function$;

CREATE OR REPLACE FUNCTION ai.if(prompt text, model_id varchar(100) DEFAULT 'gemini-2.5-flash-lite')
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE COST 5e+07
AS $function$
    SELECT google_ml.inc_call_count_impl(11);
    SELECT google_ml.if(prompt => prompt, model_id => model_id);
$function$;

-- ai.rank overrides
CREATE OR REPLACE FUNCTION ai.rank(prompts text[], batch_size integer DEFAULT NULL, model_id varchar(100) DEFAULT 'gemini-2.5-flash-lite')
 RETURNS real[]
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE COST 2e+08
AS $function$
    SELECT google_ml.inc_call_count_impl(21);
    SELECT google_ml.rank(prompts => prompts, batch_size => batch_size, model_id => model_id);
$function$;

CREATE OR REPLACE FUNCTION ai.rank(prompt text, input_cursor refcursor, batch_size integer DEFAULT NULL, model_id varchar(100) DEFAULT 'gemini-2.5-flash-lite')
 RETURNS refcursor
 LANGUAGE sql
 COST 2e+08
AS $function$
      SELECT google_ml.inc_call_count_impl(21);
      SELECT google_ml.rank(prompt => prompt, input_cursor => input_cursor, batch_size => batch_size, model_id => model_id);
$function$;

CREATE OR REPLACE FUNCTION ai.rank(prompt text, model_id varchar(100) DEFAULT 'gemini-2.5-flash-lite')
 RETURNS real
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE COST 5e+07
AS $function$
    SELECT google_ml.inc_call_count_impl(13);
    SELECT google_ml.rank(prompt => prompt, model_id => model_id);
$function$;


-- Provision tables and dummy data for documentation examples
CREATE TABLE IF NOT EXISTS restaurant_reviews (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    location_city VARCHAR(100),
    review TEXT
);

CREATE TABLE IF NOT EXISTS menu_items (
    id SERIAL PRIMARY KEY,
    item_name VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS user_reviews (
    id SERIAL PRIMARY KEY,
    review_text TEXT,
    review TEXT
);

-- Truncate to ensure clean run
TRUNCATE restaurant_reviews, menu_items, user_reviews CASCADE;

INSERT INTO restaurant_reviews (name, location_city, review) VALUES
('Apple Cafe', 'Apple City', 'The apple pie was excellent and very tasty.'),
('Carrot Bistro', 'Carrot Town', 'The carrot cake was ok, but a bit dry.');

INSERT INTO menu_items (item_name) VALUES
('apple'),
('carrot');

INSERT INTO user_reviews (review_text, review) VALUES
('The apple pie was excellent and very tasty.', 'The apple pie was excellent and very tasty.'),
('The carrot cake was ok, but a bit dry.', 'The carrot cake was ok, but a bit dry.'),
('The service was terrible and the food was cold.', 'The service was terrible and the food was cold.');
