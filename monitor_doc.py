import urllib.request
import re
import os
import sys
import difflib

URL = "https://docs.cloud.google.com/alloydb/docs/ai/evaluate-semantic-queries-ai-operators"
LAST_KNOWN_GOOD_FILE = "last_known_good_doc.html"

import ssl

def sanitize_html(html):
    # Remove HATS survey which changes frequently
    html = re.sub(r'<devsite-hats-survey.*?</devsite-hats-survey>', '', html, flags=re.DOTALL)
    # Remove feedback section if it has dynamic IDs (often has nocontent)
    html = re.sub(r'<div class="devsite-feedback-.*?>.*?</div>', '', html, flags=re.DOTALL)
    return html

def extract_article(html):
    # Extract <article class="devsite-article">...</article>
    match = re.search(r'<article class="devsite-article">.*?</article>', html, re.DOTALL)
    if not match:
        print("Error: Could not find <article class=\"devsite-article\"> in the page.")
        # Save HTML for debugging
        with open("debug_fetched.html", "w") as f:
            f.write(html)
        print("Saved fetched HTML to debug_fetched.html")
        sys.exit(2)
    
    content = match.group(0)
    content = sanitize_html(content)
    return content

def fetch_article_content(url):
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
    req = urllib.request.Request(url, headers=headers)
    
    try:
        # Try with default SSL verification
        with urllib.request.urlopen(req) as response:
            return extract_article(response.read().decode('utf-8'))
    except urllib.error.URLError as e:
        if "CERTIFICATE_VERIFY_FAILED" in str(e):
            print("SSL verification failed. Retrying with unverified context (common behind corp proxies)...")
            try:
                context = ssl._create_unverified_context()
                with urllib.request.urlopen(req, context=context) as response:
                    return extract_article(response.read().decode('utf-8'))
            except Exception as retry_e:
                print(f"Error fetching URL after retrying with unverified context: {retry_e}")
                sys.exit(2)
        else:
            print(f"Error fetching URL: {e}")
            sys.exit(2)
    except Exception as e:
        print(f"Error fetching URL: {e}")
        sys.exit(2)

def main():
    print(f"Fetching content from {URL}...")
    current_content = fetch_article_content(URL)

    # Normalize line endings and whitespace slightly to reduce noise
    current_content = "\n".join([line.rstrip() for line in current_content.splitlines()])

    if not os.path.exists(LAST_KNOWN_GOOD_FILE):
        print(f"{LAST_KNOWN_GOOD_FILE} not found. Creating it with current content.")
        with open(LAST_KNOWN_GOOD_FILE, "w") as f:
            f.write(current_content)
        print("Please commit this file to your repository.")
        sys.exit(0)

    with open(LAST_KNOWN_GOOD_FILE, "r") as f:
        old_content = f.read()

    if current_content != old_content:
        print("WARNING: Documentation page has changed!")
        
        # Generate diff
        diff = difflib.unified_diff(
            old_content.splitlines(),
            current_content.splitlines(),
            fromfile='last_known_good',
            tofile='current_live',
            lineterm=''
        )
        print("\n".join(diff))
        
        # Exit with code 1 to fail the CI/CD job
        sys.exit(1)
    
    print("No changes detected.")
    sys.exit(0)

if __name__ == "__main__":
    main()
