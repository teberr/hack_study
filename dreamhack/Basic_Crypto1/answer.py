alpha="ABCDEFGHIJKLMNOPQRSTUVWXYZ"

target="EDVLF FUBSWR GUHDPKDFN"

for i in range(0,len(alpha)):
    encode_result=""
    for j in target:
        if j==" ":
            encode_result=encode_result+"_"
            continue
        index=alpha.find(j)+i
        if index>=len(alpha):
            index=index-len(alpha)
        encode_result=encode_result+alpha[index]
    print(encode_result)
        
