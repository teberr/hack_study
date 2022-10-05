https://honey-push-30b.notion.site/SQL-Injection-Bypass-WAF-53567ac6c11d47ccae44e3295c07cb98

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3402f76e-2aea-44d7-a4e4-0e20d01f9ed2/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

문제 파일을 다운로드 받으면 app.py와 init.sql이 있다. 아래는 app.py의 코드이다.

```python
import os
from flask import Flask, request
from flask_mysqldb import MySQL

app = Flask(__name__)
app.config['MYSQL_HOST'] = os.environ.get('MYSQL_HOST', 'localhost')
app.config['MYSQL_USER'] = os.environ.get('MYSQL_USER', 'user')
app.config['MYSQL_PASSWORD'] = os.environ.get('MYSQL_PASSWORD', 'pass')
app.config['MYSQL_DB'] = os.environ.get('MYSQL_DB', 'users')
mysql = MySQL(app)

template ='''
<pre style="font-size:200%">SELECT * FROM user WHERE uid='{uid}';</pre><hr/>
<pre>{result}</pre><hr/>
<form>
    <input tyupe='text' name='uid' placeholder='uid'>
    <input type='submit' value='submit'>
</form>
'''

keywords = ['union', 'select', 'from', 'and', 'or', 'admin', ' ', '*', '/']
def check_WAF(data):
    for keyword in keywords:
        if keyword in data:
            return True

    return False

@app.route('/', methods=['POST', 'GET'])
def index():
    uid = request.args.get('uid')
    if uid:
        if check_WAF(uid):
            return 'your request has been blocked by WAF.'
        cur = mysql.connection.cursor()
        cur.execute(f"SELECT * FROM user WHERE uid='{uid}';")
        result = cur.fetchone()
        if result:
            return template.format(uid=uid, result=result[1])
        else:
            return template.format(uid=uid, result='')

    else:
        return template

if __name__ == '__main__':
    app.run(host='0.0.0.0')
```

그리고 아래는 init.sql의 코드이다.

```sql
CREATE DATABASE IF NOT EXISTS `users`;
GRANT ALL PRIVILEGES ON users.* TO 'dbuser'@'localhost' IDENTIFIED BY 'dbpass';

USE `users`;
CREATE TABLE user(
  idx int auto_increment primary key,
  uid varchar(128) not null,
  upw varchar(128) not null
);

INSERT INTO user(uid, upw) values('abcde', '12345');
INSERT INTO user(uid, upw) values('admin', 'DH{**FLAG**}');
INSERT INTO user(uid, upw) values('guest', 'guest');
INSERT INTO user(uid, upw) values('test', 'test');
INSERT INTO user(uid, upw) values('dream', 'hack');
FLUSH PRIVILEGES;
```

# 코드 분석

두가지의 코드를 분석해야한다.

1. app.py
2. init.sql

데이터 베이스 역할을 하는 init.sql을 먼저 분석해보자.

```sql
CREATE DATABASE IF NOT EXISTS `users`;
GRANT ALL PRIVILEGES ON users.* TO 'dbuser'@'localhost' IDENTIFIED BY 'dbpass';

USE `users`;
CREATE TABLE user(
  idx int auto_increment primary key,
  uid varchar(128) not null,
  upw varchar(128) not null
);

INSERT INTO user(uid, upw) values('abcde', '12345');
INSERT INTO user(uid, upw) values('admin', 'DH{**FLAG**}');
INSERT INTO user(uid, upw) values('guest', 'guest');
INSERT INTO user(uid, upw) values('test', 'test');
INSERT INTO user(uid, upw) values('dream', 'hack');
FLUSH PRIVILEGES;
```

users 데이터베이스를 만든 후 user 테이블을 만든다.

user 테이블은 idx, uid, upw로 이루어져 있다.

이 데이터베이스에는 5개의 user가 있으며 abcde(uid)는 12345(upw) 형식으로 이루어져 있다.

우리가 찾고자 하는 플래그 값은 uid가 admin인 upw값이다.

그럼 이제 [app.py](http://app.py)를 분석해보자.

 

```python
import os
from flask import Flask, request
from flask_mysqldb import MySQL

app = Flask(__name__)
app.config['MYSQL_HOST'] = os.environ.get('MYSQL_HOST', 'localhost')
app.config['MYSQL_USER'] = os.environ.get('MYSQL_USER', 'user')
app.config['MYSQL_PASSWORD'] = os.environ.get('MYSQL_PASSWORD', 'pass')
app.config['MYSQL_DB'] = os.environ.get('MYSQL_DB', 'users')
mysql = MySQL(app)

template ='''
<pre style="font-size:200%">SELECT * FROM user WHERE uid='{uid}';</pre><hr/>
<pre>{result}</pre><hr/>
<form>
    <input tyupe='text' name='uid' placeholder='uid'>
    <input type='submit' value='submit'>
</form>
'''

keywords = ['union', 'select', 'from', 'and', 'or', 'admin', ' ', '*', '/']
def check_WAF(data):
    for keyword in keywords:
        if keyword in data:
            return True

    return False

@app.route('/', methods=['POST', 'GET'])
def index():
    uid = request.args.get('uid')
    if uid:
        if check_WAF(uid):
            return 'your request has been blocked by WAF.'
        cur = mysql.connection.cursor()
        cur.execute(f"SELECT * FROM user WHERE uid='{uid}';")
        result = cur.fetchone()
        if result:
            return template.format(uid=uid, result=result[1])
        else:
            return template.format(uid=uid, result='')

    else:
        return template

if __name__ == '__main__':
    app.run(host='0.0.0.0')
```

크게 세가지 부분으로 나눌 수 있다.

1. MYSQL을 사용하여 데이터베이스와 연결하는 부분
2. 사용자의 입력을 필터링하는 check_WAF
3. 데이터베이스에 SQL 쿼리를 실행하는 index 함수

### 데이터베이스와 연결하는 부분

```python
import os
from flask import Flask, request
from flask_mysqldb import MySQL

app = Flask(__name__)
app.config['MYSQL_HOST'] = os.environ.get('MYSQL_HOST', 'localhost')
app.config['MYSQL_USER'] = os.environ.get('MYSQL_USER', 'user')
app.config['MYSQL_PASSWORD'] = os.environ.get('MYSQL_PASSWORD', 'pass')
app.config['MYSQL_DB'] = os.environ.get('MYSQL_DB', 'users')
mysql = MySQL(app)

```

데이터베이스와 연결을 위한 코드이다. 여기서 중요한 점은 MYSQL 데이터베이스를 사용하고 있음을 알 수 있다.

### 사용자의 입력을 필터링하는 check_WAF

```python
keywords = ['union', 'select', 'from', 'and', 'or', 'admin', ' ', '*', '/']
def check_WAF(data):
    for keyword in keywords:
        if keyword in data:
            return True

    return False
```

사용자의 입력으로 부터 union ,select, from, and, or, admin, 공백, *, / 를 필터링하고 있다. 하지만 여기서 알아야 할점은 MYSQL 데이터베이스는 대소문자 구분을 하지 않고 쿼리를 실행할 수 있기 때문에 union을 Union으로 우회하는 것도 막아야 한다. 

하지만 사용자 입력값을 upper나 lower로 대소문자까지 처리하여 필터링하지 않기 때문에 이 필터링은 대문자를 섞는 방식을 통하여 우회할 수 있다.

MYSQL 에서 공백을 우회하는 방법은 두가지 인데 /**/ 을 사용하여 우회하거나 개행문자(”\n”)을 이용하여 우회하거나 공백문자(tab)및 Back Quote를 이용하여 우회할 수 있다.

이문제에서는 공백을 우회하는 방법인 /**/는 사용할 수 없도록 필터링 하기 때문에 나머지 방법을 사용하도록 한다.

### 데이터베이스에 SQL 쿼리를 실행하는 index 함수

```python
@app.route('/', methods=['POST', 'GET'])
def index():
    uid = request.args.get('uid')
    if uid:
        if check_WAF(uid):
            return 'your request has been blocked by WAF.'
        cur = mysql.connection.cursor()
        cur.execute(f"SELECT * FROM user WHERE uid='{uid}';")
        result = cur.fetchone()
        if result:
            return template.format(uid=uid, result=result[1])
        else:
            return template.format(uid=uid, result='')

    else:
        return template

```

사용자로부터 입력을 받은 값을 check_WAF로 한번 필터링 한 후 그 필터링한 값을 쿼리에 **직접 넣어** SQL Injection 공격에 취약해 지는 모습이다. 따라서 필터링을 우회하여 sql injection을 공격을 하면 된다.

그리고 결과 값중 두번째 값(result[1])만 출력해서 보여주므로 select * from users where uid=’admin’의 경우 idx, uid, upw중 uid값이 나온다. 따라서 공격 결과인 admin의 upw가 두번째로 오도록 조정해주어야한다.

# 공격 설계

1. 우리의 목적은 admin(uid)의 upw값이다.
2. sql injection이 가능하다.
3. 필터링을 우회하기 위해 대소문자 + 공백 우회를 하면 된다.
4. 결과값으로 admin의 upw가 두번째에 있어야 한다.

이를 위해서 먼저 `SELECT * FROM user WHERE uid='{uid}';` 쿼리의 두번째 결과값이 upw가 나오도록 설계한 후 대소문자 + 공백우회를 통해 필터링을 회피하자. 이 때 form 을 통해서 넣으면 \n이 URL 인코딩을 통해서 넘어가기에 \n이 공백으로 인식이 되지 않아 url에서 직접 linefeed 값인 %0A로 넣어줘야 한다.

![개행문자를 통한 공격.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/82b15f55-6428-40dc-aa4c-1d425bdec72a/%EA%B0%9C%ED%96%89%EB%AC%B8%EC%9E%90%EB%A5%BC_%ED%86%B5%ED%95%9C_%EA%B3%B5%EA%B2%A9.png)

이 때 생각해야 할점은 user 테이블은 컬럼이 세개이므로 2를 출력하고 싶어도 1,2,3 세개의 값을 넣어줘야 한다는 점이다. 이거 생각안하고 그냥 두번째 결과값이 필요하니까 1,2만 넣으면 오류가 뜬다.

그럼 이를 통해 목적인 ‘Union Select null,upw,null From user Where uid=’Admin’--을 URL 인코딩에 맞춰서 넣어주자. 이 공백들을 개행문자 %0A로 변경해주면 된다.

![인코딩.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/54d298d0-330e-47fa-846a-e9a4162f9667/%EC%9D%B8%EC%BD%94%EB%94%A9.png)

'Union%20Select%20null,upw,null%20From%20user%20Where%20uid='Admin'#

공백을 의미하는 %20을 %0A로 일일이 변경시켜주자.

%27Union%0ASelect%0Anull%2Cupw%2Cnull%0AFrom%0Auser%0Awhere%0Auid%3D%27adMin%27%23

그리고 이 값을 url에 넣어 공격을 해주면

![결과.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/eb2e6ffd-f807-4000-b9c0-c38ef586539d/%EA%B2%B0%EA%B3%BC.png)

플래그값`DH{bc818d522986e71f9b10afd732aef9789a6db76d}`을 구할 수 있다.
