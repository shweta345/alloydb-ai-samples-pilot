import json
import re
from http.server import BaseHTTPRequestHandler, HTTPServer

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
            # Vertex AI response
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
            # OpenAI response
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
