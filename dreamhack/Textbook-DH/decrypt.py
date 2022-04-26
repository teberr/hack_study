from Crypto.Util.Padding import pad, unpad
from Crypto.Cipher import AES
import hashlib



Alice="e48e9174a9103e249f4bb809e13d58d49283e2438954799030be4854328adacbeb310c79bce3e91719f218158359af0d"
Bob="2a69648d494907e551b69b74676f2e528644a526e5f7bc8b6300f1bd8ad5f091a9e40939960ea5bd0ad2ceff23a14f96"
sk= 1
aes_key = hashlib.md5(str(sk).encode()).digest()
cipher = AES.new(aes_key, AES.MODE_ECB)

print(unpad(cipher.decrypt(bytes.fromhex(Alice)), 16))
print(unpad(cipher.decrypt(bytes.fromhex(Bob)),16))
