import threading
import time
import urllib.request
import urllib.error
import json
from mock_server import HTTPServer, MockHandler

def run_server(httpd):
    httpd.serve_forever()

def test_mock_server():
    server_address = ('localhost', 8080)
    httpd = HTTPServer(server_address, MockHandler)
    
    # Start server in a thread
    threading.Thread(target=run_server, args=(httpd,), daemon=True).start()
    time.sleep(1) # Wait for server to start
    
    print("Testing GET /...")
    try:
        response = urllib.request.urlopen("http://localhost:8080/")
        html = response.read().decode('utf-8')
        print(f"GET Response: {html}")
        assert html == "OK"
    except Exception as e:
        print(f"GET Failed: {e}")
        httpd.shutdown()
        return

    print("\nTesting POST /vertexai/text-embedding-005...")
    try:
        req_data = json.dumps({"instances": [{"content": "hello"}]}).encode('utf-8')
        req = urllib.request.Request("http://localhost:8080/vertexai/text-embedding-005", data=req_data, headers={'Content-Type': 'application/json'})
        response = urllib.request.urlopen(req)
        resp_data = json.loads(response.read().decode('utf-8'))
        print(f"POST Response: {json.dumps(resp_data)[:100]}...")
        assert "predictions" in resp_data
        assert "embeddings" in resp_data["predictions"][0]
        assert len(resp_data["predictions"][0]["embeddings"]["values"]) == 768
    except Exception as e:
        print(f"POST Vertex AI Failed: {e}")
        httpd.shutdown()
        return

    print("\nTesting POST /vertexai/gemini-embedding-001...")
    try:
        req_data = json.dumps({"instances": [{"content": "hello"}]}).encode('utf-8')
        req = urllib.request.Request("http://localhost:8080/vertexai/gemini-embedding-001", data=req_data, headers={'Content-Type': 'application/json'})
        response = urllib.request.urlopen(req)
        resp_data = json.loads(response.read().decode('utf-8'))
        print(f"POST Response: {json.dumps(resp_data)[:100]}...")
        assert "predictions" in resp_data
        assert "embeddings" in resp_data["predictions"][0]
        assert len(resp_data["predictions"][0]["embeddings"]["values"]) == 3072
    except Exception as e:
        print(f"POST Vertex AI Gemini Failed: {e}")
        httpd.shutdown()
        return

    print("\nTesting POST /openai/text-embedding-ada-002...")
    try:
        req_data = json.dumps({"input": "hello"}).encode('utf-8')
        req = urllib.request.Request("http://localhost:8080/openai/text-embedding-ada-002", data=req_data, headers={'Content-Type': 'application/json'})
        response = urllib.request.urlopen(req)
        resp_data = json.loads(response.read().decode('utf-8'))
        print(f"POST Response: {json.dumps(resp_data)[:100]}...")
        assert "data" in resp_data
        assert "embedding" in resp_data["data"][0]
        assert len(resp_data["data"][0]["embedding"]) == 1536
    except Exception as e:
        print(f"POST OpenAI Failed: {e}")
        httpd.shutdown()
        return

    print("\nTesting POST /vertexai/gemini-2.5-flash-lite (scalar)...")
    try:
        req_data = json.dumps({
            "contents": [
                {
                    "role": "user",
                    "parts": [
                        {
                            "text": "Is apple a fruit or a vegetable?"
                        }
                    ]
                }
            ]
        }).encode('utf-8')
        req = urllib.request.Request("http://localhost:8080/vertexai/gemini-2.5-flash-lite", data=req_data, headers={'Content-Type': 'application/json'})
        response = urllib.request.urlopen(req)
        resp_data = json.loads(response.read().decode('utf-8'))
        print(f"POST Response: {json.dumps(resp_data)}")
        assert "candidates" in resp_data
        assert resp_data["candidates"][0]["content"]["parts"][0]["text"] == "fruit"
    except Exception as e:
        print(f"POST Gemini LLM Scalar Failed: {e}")
        httpd.shutdown()
        return

    print("\nTesting POST /vertexai/gemini-2.5-flash-lite (batch)...")
    try:
        req_data = json.dumps({
            "contents": {
                "role": "user",
                "parts": [
                    {
                        "text": "1: Is apple a fruit?"
                    },
                    {
                        "text": "2: Is carrot a fruit?"
                    }
                ]
            }
        }).encode('utf-8')
        req = urllib.request.Request("http://localhost:8080/vertexai/gemini-2.5-flash-lite", data=req_data, headers={'Content-Type': 'application/json'})
        response = urllib.request.urlopen(req)
        resp_data = json.loads(response.read().decode('utf-8'))
        print(f"POST Response: {json.dumps(resp_data)}")
        assert "candidates" in resp_data
        resp_text = resp_data["candidates"][0]["content"]["parts"][0]["text"]
        resp_list = json.loads(resp_text)
        print(f"Parsed response list: {resp_list}")
        assert resp_list == ["true", "false"]
    except Exception as e:
        print(f"POST Gemini LLM Batch Failed: {e}")
        httpd.shutdown()
        return

    print("\nAll tests passed!")
    httpd.shutdown()

if __name__ == '__main__':
    test_mock_server()
