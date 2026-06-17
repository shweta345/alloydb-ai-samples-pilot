# AlloyDB AI Code Sample Validation Pilot

This directory contains the pilot files for validating SQL code samples in AlloyDB AI documentation.

## Files

*   `mock_server.py`: A lightweight Python HTTP server that mocks Vertex AI and OpenAI embedding APIs.
*   `setup.sql`: SQL script to enable extensions, configure GUCs (allowing HTTP endpoints), and register mock models pointing to the mock server.
*   `test_work_with_embeddings.sql`: SQL script containing the actual code samples from `work-with-embeddings.md` to be validated.
*   `.github/workflows/test-samples.yml`: GitHub Actions workflow to run the mock server, start AlloyDB Omni container, and run the SQL tests.
*   `test_mock.py`: Local test script to verify `mock_server.py`.

## How to Run the Pilot

To test this in a real GitHub environment:

1.  **Create a GitHub Repository**: Create a new repository (e.g., `alloydb-ai-samples-pilot`) on GitHub.
2.  **Push the Files**: Push all the files in this directory (including `.github/workflows/test-samples.yml`) to the main branch of your new repository.
    ```bash
    git init
    git add .
    git commit -m "Initial pilot files"
    git remote add origin git@github.com:<your-username>/alloydb-ai-samples-pilot.git
    git branch -M main
    git push -u origin main
    ```
3.  **Check GitHub Actions**: Go to the "Actions" tab of your GitHub repository. You should see the "Test SQL Code Samples" workflow running.
4.  **Verify Results**: Ensure the workflow completes successfully. You can check the logs of the "Run Tests" step to see the output of the SQL queries.

Once this pilot is verified, we can:
1.  Establish the official repository under `GoogleCloudPlatform`.
2.  Migrate the actual snippets.
3.  Update the AlloyDB documentation in google3 to reference the files in the official repository using `github_include`.
