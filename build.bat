@echo off
bison -t -v parse.y -o parse.c
gcc -c node.c
gcc -c toml_float.c
gcc -c toml_str.c
gcc -c parse.c
ar r libtoml.a parse.o toml_str.o toml_float.o node.o
gcc -o a.exe main.c -L. -ltoml

if "%1" == "test" (
	cd /d test
  gcc -o test.exe test.c -L.. -ltoml -I.. -I.
  go get github.com/BurntSushi/toml-test
  toml-test test bool integer float empty string-empty string-simple
  toml-test test key-equals-nospace
  toml-test test key-space
  toml-test test key-special-chars
  toml-test test long-integer
  toml-test test long-float
  toml-test test multiline-string
)

cd /d %~dp0
