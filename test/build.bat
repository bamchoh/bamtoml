@echo off
cd ..
call build.bat
cd test
gcc -o test.exe test.c -L.. -ltoml -I.. -I.
toml-test test bool integer float empty string-empty string-simple
