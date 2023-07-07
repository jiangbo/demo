// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Fill.asm

// Runs an infinite loop that listens to the keyboard input.
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel;
// the screen should remain fully black as long as the key is pressed. 
// When no key is pressed, the program clears the screen, i.e. writes
// "white" in every pixel;
// the screen should remain fully clear as long as no key is pressed.

// Put your code here.

// r0 = screen start address
@SCREEN
D=A    
@0
M=D

// r1 = screen end address
@24575
D=A
@1
M=D

(LOOP)
        // D = key code
	@KBD
	D=M
        // 有按键按下，跳到 FILL
        @FILL
	D;JGT  
        // 没有键按下，跳到 CLEAR
	@CLEAR 
	0;JMP

(FILL)
        // D = 屏幕最大地址
	@1    
	D=M
        // D = 屏幕最大地址 - 当前屏幕地址
	@0
	D=D-M 
        // 如果小于 D 小于 0，跳转到 LOOP
	@LOOP
	D;JLT 

        // 将当前屏幕地址变黑
	@0
	D=M  
	A=D  
	M=-1 
        // 将当前屏幕地址+1
	@0    
	D=M  
	D=D+1 
	M=D
@LOOP
0;JMP 

(CLEAR)
        // 当前屏幕地址-1
	@0
	D=M     
	D=D-1  
	M=D
        // 如果当前地址小于屏幕开始地址，跳转到 LOOP
	@SCREEN 
	D=D-A   
	@LOOP
	D;JLT   
        // 屏幕变白
	@0      
	D=M     
	A=D     
	M=0     
	@LOOP
	0;JMP  