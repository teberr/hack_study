https://teberr.notion.site/NoSQL-CouchDB-e70a44ec6c724e6ebcd4043b784a280b

# 문제파일 다운로드

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a4ecf070-df5f-487e-820e-8d9595788477/%EB%AC%B8%EC%A0%9C.png)

NoSQL-CouchDB 문제파일을 다운로드 받으면 app폴더가 존재하며 그 내부에는 소스파일들과 도커파일 등이 존재한다.

그 중에서도 couchDB와 연결하는 핵심적인 내용인 app.js 파일은 아래와 같다.

```jsx
var createError = require('http-errors');
var express = require('express');
var path = require('path');
var cookieParser = require('cookie-parser');

const nano = require('nano')(`http://${process.env.COUCHDB_USER}:${process.env.COUCHDB_PASSWORD}@couchdb:5984`);
const users = nano.db.use('users');
var app = express();

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');

app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

/* GET home page. */
app.get('/', function(req, res, next) {
  res.render('index');
});

/* POST auth */
app.post('/auth', function(req, res) {
    users.get(req.body.uid, function(err, result) {
        if (err) {
            console.log(err);
            res.send('error');
            return;
        }
        if (result.upw === req.body.upw) {
            res.send(`FLAG: ${process.env.FLAG}`);
        } else {
            res.send('fail');
        }
    });
});

// catch 404 and forward to error handler
app.use(function(req, res, next) {
  next(createError(404));
});

// error handler
app.use(function(err, req, res, next) {
  // set locals, only providing error in development
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};

  // render the error page
  res.status(err.status || 500);
  res.render('error');
});

module.exports = app;
```

# 코드 분석 및 공격 설계

couchDB는 http에서 파라미터 값을 통해서 데이터베이스에 접근할 수 있게 해준다.

curl -X PUT [http://{username}:{password}@localhost:5984/users/guest](http://%7Busername%7D:%7Bpassword%7D@localhost:5984/users/guest) -d '{"upw":"guest"}'

와 같이 curl을 사용하여 -d 옵션을 통해 HTTP의 body 부분에 데이터를 넣어서 사용할 수 있다. 

couchDB와 연결하는 app.js 코드를 살펴보면 

```jsx
/* POST auth */
app.post('/auth', function(req, res) {
    users.get(req.body.uid, function(err, result) {
        if (err) {
            console.log(err);
            res.send('error');
            return;
        }
        if (result.upw === req.body.upw) {
            res.send(`FLAG: ${process.env.FLAG}`);
        } else {
            res.send('fail');
        }
    });
});
```

사용자로부터 전달받는 req.body에서 uid값을 받아와 이 결과값을 반환해 주고있지만 이 uid 인풋값을 검증하고 있지 않기 때문에 couchDB에서 사용하는 특수 구성 요소인 _all_docs나 _find 와 같은 값을 넣어서 사용할 수 있다.

![all docs.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8fb2761b-ec9d-4287-8265-6fd12308b301/all_docs.png)

드림핵 강의에서 제공해 주었던 _all_docs의 결과 값을 참고하면 result의 key값으로는 total_rows, offset, rows로 upw 값이 존재하지 않는 것을 볼 수 있다. 

즉 _all_docs를 uid에 넣어주면 result.upw는 `undefined`가 됨을 추측할 수 있다. 따라서 req.body.upw 값이 존재하지 않도록 http body값에 upw를 넣어주지 않으면 된다.

# 공격

![upw.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/7c142f4d-35e3-4e54-adeb-7ec93ab20303/upw.png)

먼저 첫 페이지에서 upw 값을 입력하는 란을 지우기 위하여 개발자 도구에서 upw input란을 지운다.

![upw삭제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c98e0a0a-898d-4ce8-bc00-05e5251ab358/upw%EC%82%AD%EC%A0%9C.png)

upw란을 지우고 나면 uid위치에 _all_docs를 넣어준다.

![flag2.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/4b74df46-bc48-4300-9f60-afefef4c01e5/flag2.png)

FLAG: DH{f350aad835d053891385b1bb9cfbc1c318ab29f0} 값을 얻어낼 수 있다.
