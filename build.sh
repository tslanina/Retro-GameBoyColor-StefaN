./rgbasm -ostefan.obj stefan.asm
./rgblink -mstefan.map -nstefan.sym -ostefan.gb stefan.obj 
./rgbfix -v -p0 stefan.gb
