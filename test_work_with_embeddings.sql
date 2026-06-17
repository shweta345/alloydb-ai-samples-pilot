-- Start test block
\echo '=== STARTING TEST FOR work-with-embeddings.md ==='

-- 1. Public Schema - Generate an embedding (with text-embedding-005)
\echo 'Testing public.embedding with text-embedding-005...'
SELECT embedding('text-embedding-005', 'AlloyDB is a managed, cloud-hosted SQL database service.');

-- 2. Google_ml Schema - Generate embedding (with gemini-embedding-001)
\echo 'Testing google_ml.embedding with gemini-embedding-001...'
SELECT google_ml.embedding(
    model_id => 'gemini-embedding-001',
    content => 'AlloyDB is a managed, cloud-hosted SQL database service');

-- 3. Google_ml Schema - Register model in different project (Syntax Check Only)
-- We use a unique model_id and a valid-looking URL. We do not call this model.
\echo 'Testing google_ml.create_model syntax for different project...'
CALL google_ml.create_model(
    model_id => 'gemini-embedding-001-diff-project',
    model_request_url => 'https://us-central1-aiplatform.googleapis.com/v1/projects/test-project/locations/us-central1/publishers/google/models/gemini-embedding-001:predict',
    model_provider => 'google',
    model_type => 'text_embedding',
    model_auth_type => 'alloydb_service_agent_iam',
    model_in_transform_fn => 'google_ml.vertexai_text_embedding_input_transform',
    model_out_transform_fn => 'google_ml.vertexai_text_embedding_output_transform'
);

-- Verify it was registered
SELECT model_id, model_provider, model_auth_type FROM google_ml.models WHERE model_id = 'gemini-embedding-001-diff-project';

-- Clean it up so it doesn't pollute the DB if we run multiple times
CALL google_ml.drop_model('gemini-embedding-001-diff-project');

-- 4. OpenAI - text-embedding-ada-002
\echo 'Testing OpenAI text-embedding-ada-002...'
SELECT google_ml.embedding(
    model_id => 'text-embedding-ada-002',
    content => 'e-mail spam');

-- 5. OpenAI - text-embedding-3-small
\echo 'Testing OpenAI text-embedding-3-small...'
SELECT google_ml.embedding(
    model_id => 'text-embedding-3-small',
    content => 'Vector embeddings in AI');

\echo '=== TEST COMPLETED SUCCESSFULLY ==='
