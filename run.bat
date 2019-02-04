del bdoing.d64
\vice\c1541 -format #bdoing#,8 d64 bdoing.d64 -write BDoing.prg @8:bdoing
for %%i in (example\*.snd) do \vice\c1541 bdoing.d64 -write %%i @8:%%~ni.snd
\vice\x64 -remotemonitor BDoing.d64
IF EXIST tmp rmdir /S /Q tmp
mkdir tmp
cd tmp
dir ..\bdoing.d64
\vice\c1541 ..\bdoing.d64 -extract
cd ..
dir tmp
move /Y tmp\*.snd example
IF EXIST tmp\*.s move /Y tmp\*.s example
rmdir /S /Q tmp


