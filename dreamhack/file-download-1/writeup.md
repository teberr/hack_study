https://honey-push-30b.notion.site/file-download-1-75e83ce7316a41a3ac13b228f3ed32ae

# 문제 접근

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5a5b4bbf-670b-45bf-8e43-1c83e9f91da2/Untitled.png)

file-download-1 문제의 접속 정보와 문제 설명 및 문제파일을 다운로드 받을 수 있다. app.py 파일을 보면 아래 코드를 볼 수 있다.

```php
#!/usr/bin/env python3
import os
import shutil

from flask import Flask, request, render_template, redirect

from flag import FLAG

APP = Flask(__name__)

UPLOAD_DIR = 'uploads'

@APP.route('/')
def index():
    files = os.listdir(UPLOAD_DIR)
    return render_template('index.html', files=files)

@APP.route('/upload', methods=['GET', 'POST'])
def upload_memo():
    if request.method == 'POST':
        filename = request.form.get('filename')
        content = request.form.get('content').encode('utf-8')

        if filename.find('..') != -1:
            return render_template('upload_result.html', data='bad characters,,')

        with open(f'{UPLOAD_DIR}/{filename}', 'wb') as f:
            f.write(content)

        return redirect('/')

    return render_template('upload.html')

@APP.route('/read')
def read_memo():
    error = False
    data = b''

    filename = request.args.get('name', '')

    try:
        with open(f'{UPLOAD_DIR}/{filename}', 'rb') as f:
            data = f.read()
    except (IsADirectoryError, FileNotFoundError):
        error = True

    return render_template('read.html',
                           filename=filename,
                           content=data.decode('utf-8'),
                           error=error)

if __name__ == '__main__':
    if os.path.exists(UPLOAD_DIR):
        shutil.rmtree(UPLOAD_DIR)

    os.mkdir(UPLOAD_DIR)

    APP.run(host='0.0.0.0', port=8000)
```

upload_memo와 read_memo 함수를 좀 더 자세히 살펴보자.

# upload_memo 페이지

```php
@APP.route('/upload', methods=['GET', 'POST'])
def upload_memo():
    if request.method == 'POST':
        filename = request.form.get('filename')
        content = request.form.get('content').encode('utf-8')

        if filename.find('..') != -1:
            return render_template('upload_result.html', data='bad characters,,')

        with open(f'{UPLOAD_DIR}/{filename}', 'wb') as f:
            f.write(content)

        return redirect('/')

    return render_template('upload.html')
```

사용자로부터 filename과 content를 받아서 /uploads/filename 으로 저장한다.

이 때 사용자가 filename에 ..을 넣어서 다른 디렉토리로 이동하지 못하도록 ..은 필터링을 해주는 것을 알 수 있다.

# read_memo 페이지

```php
@APP.route('/read')
def read_memo():
    error = False
    data = b''

    filename = request.args.get('name', '')

    try:
        with open(f'{UPLOAD_DIR}/{filename}', 'rb') as f:
            data = f.read()
    except (IsADirectoryError, FileNotFoundError):
        error = True

    return render_template('read.html',
                           filename=filename,
                           content=data.decode('utf-8'),
                           error=error)
```

get 방식으로 사용자로부터 name을 받아 uploads/name 의 내용을 읽어서 보여주는 함수이다. 여기서 알아야할 점은 업로드 할때는 filename에 ..을 입력하지 못하게 하여서 상위 디렉토리를 접근하지 못하도록 하였는데 이 name에서는 사용자로 부터 입력받는 name을 필터링 하지 않는다. 

# 문제 풀이

실제로 페이지에 접근하면서 진행해보자

![업로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/7392d7d8-72cc-4520-9ed6-75dd3b7f50fb/.png)

upload페이지에서 Filename과 Content에 a를 넣어주었다. 어차피 Filename에는 ..이 필터링 되므로 시도하지 않았다.

![a가 된모습.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e38192f5-77bb-4b47-868e-705123698bf8/a_.png)

그러면 정상적으로 a가 업로드 된것을 확인할 수 있다.

![read페이지.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8c02ccc4-e832-4d7a-b87c-6cec5c580745/read.png)

들어가보면 read?name=a를 통해 a 파일을 읽고 내용을 보여주는 것을 볼 수 있다.

flag는 flag.py에 있다고 했으므로 url에 a대신 flag.py를 넣어보자.

![flag없음.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/aac1a81c-64a0-44a7-abf1-6e5dcb396fe2/flag.png)

아쉽게도 flag.py는 존재하지 않는다고 한다. 근데 그럴수 밖에 없는게 애초에 index 페이지에서 현재 uploads/ 폴더에 존재하는 파일들을 보여주는데 직접 올린 a파일 밖에 존재하지 않았으므로 uploads/폴더에는 flag.py가 없다고 생각하는게 맞다.

그래서 상위 폴더로 이동해서 flag.py를 찾아보자

![flag찾음.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/cf9c5dbf-6df2-4fdd-9b35-9b6eb77b1f69/flag.png)

url에 name값으로 ../flag.py를 넣은 결과 flag.py값이 출력되는 것을 볼 수 있다.

FLAG = 'DH{uploading_webshell_in_python_program_is_my_dream}’

FLAG값을 찾았다.
