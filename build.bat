@echo off
bison -t -v parse.y -o parse.c
gcc -c node.c
gcc -c toml_float.c
gcc -c toml_str.c
gcc -c parse.c
ar r libtoml.a parse.o toml_str.o toml_float.o node.o
gcc -o a.exe main.c -L. -ltoml
