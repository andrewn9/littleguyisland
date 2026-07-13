import math
import random
import os

a = 0.7
f = 0.005
s = 0.1

count = 128

os.system("cls")

for i in range(count):
    d = random.random() * math.pi * 2.0
    print(f"Wave({a}f, {f}f, {random.random()}f, vec2({(math.cos(d))}f, {math.sin(d)}f)){"" if i == count - 1 else ","}")
    a *= 0.84
    f *= 1.12