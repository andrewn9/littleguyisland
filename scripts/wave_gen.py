import math
import random
import os

a = 10.0
f = 0.001
s = 0.5

count = 10

os.system("cls")

for i in range(count):
    d = random.random() * math.pi * 2.0
    print(f"Wave({a}f, {f}f, {2.0 * (1 - math.pow(0.8, i) + 0.4)}f, vec2({(math.cos(d))}f, {math.sin(d)}f)){"" if i == count - 1 else ","}")
    a *= 0.6
    f *= 2.0