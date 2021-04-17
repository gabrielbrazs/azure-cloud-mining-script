#!/usr/bin/env bash


cd ..
rm -rf xmrig/
git clone https://github.com/gabrielbrazs/xmrig.git
cd xmrig
git checkout master
mkdir build
cd build
cmake ..
make 
cd ..
cd ..

