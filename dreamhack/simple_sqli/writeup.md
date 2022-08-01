https://honey-push-30b.notion.site/Simple_sqli-f8f21f22b0b041088c8a365981009460

# Simple_sqli

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a1b463d9-28d0-4ad1-b1c7-e3f4083671db/_.png)

Simple_sqli 문제의 접속 정보와 문제파일을 다운로드 받을 수 있다. 문제파일을 다운로드 받으면 [app.py](http://app.py) 파일을 받을 수 있는데 이 파일의 코드는 아래와 같다.

```python
#!/usr/bin/python3
from flask import Flask, request, render_template, g
import sqlite3
import os
import binascii

app = Flask(__name__)
app.secret_key = os.urandom(32)

try:
    FLAG = open('./flag.txt', 'r').read()
except:
    FLAG = '[**FLAG**]'

DATABASE = "database.db"
if os.path.exists(DATABASE) == False:
    db = sqlite3.connect(DATABASE)
    db.execute('create table users(userid char(100), userpassword char(100));')
    db.execute(f'insert into users(userid, userpassword) values ("guest", "guest"), ("admin", "{binascii.hexlify(os.urandom(16)).decode("utf8")}");')
    db.commit()
    db.close()

def get_db():
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = sqlite3.connect(DATABASE)
    db.row_factory = sqlite3.Row
    return db

def query_db(query, one=True):
    cur = get_db().execute(query)
    rv = cur.fetchall()
    cur.close()
    return (rv[0] if rv else None) if one else rv

@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')
    else:
        userid = request.form.get('userid')
        userpassword = request.form.get('userpassword')
        res = query_db(f'select * from users where userid="{userid}" and userpassword="{userpassword}"')
        if res:
            userid = res[0]
            if userid == 'admin':
                return f'hello {userid} flag is {FLAG}'
            return f'<script>alert("hello {userid}");history.go(-1);</script>'
        return '<script>alert("wrong");history.go(-1);</script>'

app.run(host='0.0.0.0', port=8000)
app.run(host="0.0.0.0", port=8000)
```

여기서 핵심이 되는 부분을 순서대로 보자

1. 데이터베이스 execute 부분
2. login 함수
3. query_db 함수

# 데이터 베이스 execute

```python
DATABASE = "database.db"
if os.path.exists(DATABASE) == False:
    db = sqlite3.connect(DATABASE)
    db.execute('create table users(userid char(100), userpassword char(100));')
    db.execute(f'insert into users(userid, userpassword) values ("guest", "guest"), ("admin", "{binascii.hexlify(os.urandom(16)).decode("utf8")}");')
    db.commit()
    db.close()

```

데이터베이스가 없으면 데이터베이스를 연결해서 userid, userpassword를 가진 user 테이블을 만든다. 

그리고 이 user table에 guest(userid),guest(userpassword)  세트와 admin(userid),랜덤값(userpassword)을 추가한다.

즉 guest/guest 계정과 admin/랜덤값 이  데이터베이스에 추가된 상태이다.

# login 함수

```python
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')
    else:
        userid = request.form.get('userid')
        userpassword = request.form.get('userpassword')
        res = query_db(f'select * from users where userid="{userid}" and userpassword="{userpassword}"')
        if res:
            userid = res[0]
            if userid == 'admin':
                return f'hello {userid} flag is {FLAG}'
            return f'<script>alert("hello {userid}");history.go(-1);</script>'
        return '<script>alert("wrong");history.go(-1);</script>'
```

GET으로 요청하면 login 페이지를 보여주고

![login.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/658dece3-8c46-4e3e-9199-34562bcc1f84/login.png)

POST로 요청하면 사용자가 입력한 userid와 userpassword를 query에 검증 없이 그대로 넣어서 이 query를 db에 요청하고 그 응답값을 가져온다. 이 때 응답값의 userid가 admin이면 FLAG 값을 알려준다

즉 query 문에 userid와 password를 입력하여 admin으로 로그인 하는 것이 핵심이다.  

# query_db 함수

```python
def query_db(query, one=True):
    cur = get_db().execute(query)
    rv = cur.fetchall()
    cur.close()
    return (rv[0] if rv else None) if one else rv
```

query를 검증없이 바로 db에 넣어서 실행하는 것을 볼 수 있다. 즉 sql injection이 가능함이 확실해졌다.

select * from users where userid="admin”--" and userpassword="아무거나"

# 문제 해결

다음의 조건을 준수하면 flag값을 찾을 수 있다.

1. login 페이지에서 admin으로 로그인 하면 FLAG 값을 알 수 있다.
2. 이 때 사용자의 입력값을 검증하는 부분이 없기 때문에 sql injection이 가능하다.

즉 userid에 admin”--로 넣고 password에 아무거나 넣으면 최종적 query는 

select * from users where userid="admin”--" and userpassword="아무거나"” 가 된다. 

--뒤는 주석처리기 때문에 실질적으로 들어가는 쿼리는

select * from users where userid="admin”이 되며 user 테이블에서 userid가 admin인 경우를 가져온다. 

![답안.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a82fcee6-66af-48a3-ae17-3195a1ff6da5/.png)

hello admin flag is **DH{1f136225e316add7bff3349ab1dd5400}** 이 나오는 것을 볼 수 있다.
