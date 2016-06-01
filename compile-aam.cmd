@echo off
::
::	Compile the AAM.EXE file
::


fpc.exe aam_main.pas -oaam.exe

::del ..\bin\*.o
::del ..\bin\*.ppu

echo Complilation done...