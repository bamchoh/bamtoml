@echo off
bison -t -v parse.y -o parse.c
gcc -c node.c
gcc -c toml_str.c
gcc -c parse.c
ar r libtoml.a parse.o toml_str.o node.o
gcc -o a.exe main.c -L. -ltoml
a.exe test\bool.toml
