-- Enable extensions
CREATE EXTENSION IF NOT EXISTS google_ml_integration CASCADE;
CREATE EXTENSION IF NOT EXISTS vector CASCADE;

-- Enable GUCs
ALTER SYSTEM SET google_ml_integration.enable_ai_query_engine = ON;
ALTER SYSTEM SET google_ml_integration.enable_model_support = ON;
ALTER SYSTEM SET google_ml_integration.allow_http_endpoints = ON;
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
