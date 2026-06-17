import json
import re
from http.server import BaseHTTPRequestHandler, HTTPServer

def evaluate_single_prompt(prompt):
    # Normalize spacing
    prompt = re.sub(r'\s+', ' ', prompt)
    
    # 1. Check if it is a classification/boolean question (ai.if)
    if "positive review" in prompt or "Is the review positive" in prompt or "Is the given statement true" in prompt:
        if "excellent" in prompt or "positive" in prompt or "excellent" in prompt.lower():
            return "true"
        else:
            return "false"
            
    # 2. Check if it is the join question: "Does the ... review talk about the menu item ..."
    elif "talk about the menu item" in prompt:
        # Extract review and menu item
        # prompt format: "... review: <review> menu item: <item>"
        match = re.search(r'review:\s*(.*?)\s*menu item:\s*(.*)$', prompt, re.IGNORECASE)
        if match:
            review = match.group(1).lower()
            item = match.group(2).lower()
            if item in review:
                return "true"
            else:
                return "false"
        return "false"
        
    # 3. Check if it is a ranking question (ai.rank)
    elif "Score the following review" in prompt or "Score" in prompt:
        if "excellent" in prompt.lower() or "excellent" in prompt:
            return "9" # 8-10
        elif "ok" in prompt.lower() or "ok" in prompt:
            return "5" # 4-7
        else:
            return "2" # 1-3
            
    # 4. Check if it is a summarization/generation question (ai.generate)
    elif "Summarize" in prompt or "What is" in prompt:
        return "Mock response for: " + prompt[:30] + "..."
        
    # Fallback for old tests
    if "Is apple a fruit or a vegetable?" in prompt:
        return "fruit"
    elif "Is carrot a fruit or a vegetable?" in prompt:
        return "vegetable"
    elif "Is apple a fruit?" in prompt:
        return "true"
    elif "Is carrot a fruit?" in prompt:
        return "false"
    elif "Score apple on a scale of 0 to 1" in prompt:
        return "0.9"
    elif "Score carrot on a scale of 0 to 1" in prompt:
        return "0.3"
        
    return "default response"

class MockHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Health check
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(b"OK")

    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        req_body = json.loads(post_data.decode('utf-8'))
        
        print(f"Received request: {self.path}")
        print(f"Body: {req_body}")

        response_data = None
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()

        if 'vertexai' in self.path:
            # If it is NOT an embedding model, treat it as Gemini LLM
            if 'embedding' not in self.path:
                # Gemini LLM response
                contents = req_body['contents']
                if isinstance(contents, list):
                    # Scalar (usually list of contents)
                    prompt = contents[0]['parts'][0]['text']
                    response_text = evaluate_single_prompt(prompt)
                    response_data = {
                        "candidates": [
                            {
                                "content": {
                                    "parts": [
                                        {
                                            "text": response_text
                                        }
                                    ]
                                }
                            }
                        ]
                    }
                elif isinstance(contents, dict):
                    # Batch (usually dict with parts?)
                    # Wait, in our GHA batch test, contents was a dict?
                    # Let's check how batch is sent by extension.
                    # Actually, batch_array_async might send it differently.
                    # In our previous implementation we had:
                    parts = contents.get('parts', [])
                    responses = []
                    for part in parts:
                        text = part['text']
                        # Extension prefixes prompts with index "0: prompt", "1: prompt"
                        match = re.match(r'^(\d+):\s*(.*)$', text)
                        if match:
                            prompt = match.group(2)
                            response_text = evaluate_single_prompt(prompt)
                            responses.append(response_text)
                        else:
                            responses.append(evaluate_single_prompt(text)) # fallback if no prefix
                    
                    response_json_string = json.dumps(responses)
                    response_data = {
                        "candidates": [
                            {
                                "content": {
                                    "parts": [
                                        {
                                            "text": response_json_string
                                        }
                                    ]
                                }
                            }
                        ]
                    }
            else:
                # Vertex AI embedding response
                dim = 768
                if 'gemini-embedding-001' in self.path:
                    dim = 3072
                
                fake_vector = [0.1] * dim
                response_data = {
                    "predictions": [
                        {
                            "embeddings": {
                                "values": fake_vector
                            }
                        }
                    ]
                }
        elif 'openai' in self.path:
            # OpenAI response (always embedding in our tests)
            dim = 1536
            fake_vector = [0.1] * dim
            response_data = {
                "data": [
                    {
                        "embedding": fake_vector
                    }
                ]
            }
        else:
            # Default
            response_data = {
                "predictions": [
                    {
                        "embeddings": {
                            "values": [0.1] * 768
                        }
                    }
                ]
            }

        self.wfile.write(json.dumps(response_data).encode('utf-8'))

def run(server_class=HTTPServer, handler_class=MockHandler, port=8080):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print(f'Starting mock server on port {port}...')
    httpd.serve_forever()

if __name__ == '__main__':
    run()
