@echo off
cd %~dp0\..
call build.bat
cd test
gcc -o test.exe test.c -L.. -ltoml -I.. -I.
go get github.com/BurntSushi/toml-test
toml-test test bool integer float empty string-empty string-simple
toml-test test key-equals-nospace
toml-test test key-space
toml-test test key-special-chars
toml-test test long-integer
toml-test test long-float
toml-test test multiline-string
