@echo off
bison -t -v parse.y -o parse.c
gcc -c node.c
gcc -c toml_str.c
gcc -O -I. -o a.exe parse.c toml_str.o node.o
