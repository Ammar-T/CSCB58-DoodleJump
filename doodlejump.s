#####################################################################
#
# CSCB58 Fall 2020 Assembly Final Project
# University of Toronto, Scarborough
#
# Student: Ammar Tariq, 1006143317
#
# Bitmap Display Configuration:
# - Unit width in pixels: 16					     
# - Unit height in pixels: 16
# - Display width in pixels: 512
# - Display height in pixels: 512
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestone is reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1/2/3/4/5 (choose the one the applies)
#
# Which approved additional features have been implemented?
# (See the assignment handout for the list of additional features)
# 1. (fill in the feature, if any)
# 2. (fill in the feature, if any)
# 3. (fill in the feature, if any)
# ... (add more if necessary)
#
# Link to video demonstration for final submission:
# - (insert YouTube / MyMedia / other URL here). 
#
# Any additional information that the TA needs to know:
# - (write here, if any)
#
#####################################################################
.data
	displayAddress:	.word 0x10008000
	colors: 	.word 0xFF93CAF2 0xFFE61A20 0xFF49B616 # background, ball, level
	newline: .asciiz "\n"
.globl main
.text

main:
	lw $t0, displayAddress	
	la $t1, colors	
	
	jal clearScreen
	
	# Wait for signal (start, restart, exit)
	lw $t8, 0xffff0000 
	beq $t8, 1, initGame
	j main

	initGame:
		lw $t5, 0xffff0004
		beq $t5, 0x71, Exit 	 # Press Q
		beq $t5, 0x72, StartLoop # Press R
		beq $t5, 0x73, StartLoop # Press T
		j main

	StartLoop: 
		li $a0, 675
		li $a1, 250
		jal createLevel
		
		li $a0, 75
		li $a1, 200
		jal createLevel
	
		li $a0, 325
		li $a1, 150
		jal createLevel

		li $a0, 530
		li $a1, 150
		jal createLevel
		
		lw $t2, 0($t1)
		sw $t2, 0($sp)
		
		# Jump height limit counter (limit = 10)
		li $t9, 0
		li $t3, 0
		
		# Game loop
		RUN: 			
			ble $t9, 10, flyUp
			flyDown:
				jal RepaintFlyDown
				li $a0, 128
				jal changeY
				jal hitLevel
				j continue
			flyUp:	
				jal RepaintFlyUp
				addi $t9, $t9, 1
				li $a0, -128
				jal changeY
			continue:
				# Hit the bottom
				bge $t0, 268468300, main
			
				# Handle left and right movement
				lw $t8, 0xffff0000 
				beq $t8, 1, leftOrRight
				
				# Scroll screen up
				ble $t0, 268465160, Scroll
				
				j RUN

Scroll:
	li $t6, 0
	lw $t3, displayAddress
	
	# loop each pixel
	loopPixel:
		# get color of block
		lw $t8, 0($t3)
		# if green then lower it
		li $t4, 0
		beq $t8, -11946474, scrollLevel
	
		nextPixel: 
			addi $t3, $t3, 4
			addi $t6, $t6, 1
			blt $t6, 1024, loopPixel
			
			li $a0, 1
			li $a1, 20
			jal createLevel
		
			j RUN
	
	scrollLevel:
		# load blue
		lw $t2, 0($t1)
		# color current blue
		sw $t2, 0($t3)
		# load green color
		lw $t2, 8($t1)
		# color bottom block green
		sw $t2, 128($t3)
		
		# increment counter and address
		addi $t3, $t3, 4
		addi $t4, $t4, 1
		blt $t4, 6, scrollLevel
		
		addi $t3, $t3, 128
		j nextPixel
	
RepaintFlyUp:
	# push above-block colors onto stack
	addi $sp, $sp, -8
	lw $t2, 3908($t0)
	sw $t2, 0($sp)
	lw $t2, 3904($t0)
	sw $t2, 4($sp)
	jr $ra

RepaintFlyDown:
	# push below-block colors onto stack
	addi $sp, $sp, -8
	lw $t2, 4164($t0)
	sw $t2, 0($sp)
	lw $t2, 4160($t0)
	sw $t2, 4($sp)
	jr $ra

changeY:	
	# color above/below block red
	add $t0, $t0, $a0 
   	lw $t2, 4($t1)
	sw $t2, 4032($t0)
	sw $t2, 4036($t0)
	# wait for sleep to finish
	li $v0, 32
	li $a0, 225
	syscall
	# pop from stack and color accordingly
	lw $t2, 0($sp)
	sw $t2, 4036($t0)
	lw $t2, 4($sp)
	sw $t2, 4032($t0)
	addi $sp, $sp, 8
	
	jr $ra

createLevel:
	# set color to green
	lw $t2, 8($t1)

	# copy lowerbound of level location range
	move $t4, $a0
	# copy display address
	lw $t5, displayAddress
	
	# generate random number
	li $v0, 42
	li $a0, 0
	syscall
	add $a0, $a0, $t4
	move $t6, $a0
	
	# make multiple of 4 (x * 2^2)
	sll $t6, $t6, 2
	add $t5, $t5, $t6	
   	
	# draw level
	sw $t2, 0($t5)
	sw $t2, 4($t5)	
	sw $t2, 8($t5)	
	sw $t2, 12($t5)	
	sw $t2, 16($t5)
	sw $t2, 20($t5)
	
	jr $ra

hitLevel: 
	# get color of block below (left unit)
	lw $t3, 4160($t0)
	# green = -11946474
	beq $t3, -11946474, resetFly
	# get color of block below (right unit)
	lw $t3, 4164($t0)
	# green = -11946474
	beq $t3, -11946474, resetFly
	jr $ra
	
	resetFly:			
		li $t9, 0
		jr $ra
		
clearScreen:
	li $t6, 0
	lw $t2, 0($t1)
	NotCleared:
		sw $t2, 0($t0)
		addi $t0, $t0, 4
		addi $t6, $t6, 1
		li $v0, 32
		li $a0, 3
		syscall
		blt $t6, 1024, NotCleared
		
	lw $t0, displayAddress
	li $t6, 0
	jr $ra
		
leftOrRight:
	lw $t5, 0xffff0004 
	beq $t5, 0x6A, moveLeft
	beq $t5, 0x6B, moveRight
	j RUN

moveLeft:
	addi $t0, $t0, -4
	j RUN

moveRight:
	addi $t0, $t0, 4
	j RUN
		 
Exit:
	li $v0, 10 
	syscall
	
	
		#li $v0, 1
		#move $a0, $t6
		#syscall
		# Display newline
		#li $v0, 4
		#la $a0, newline
		#syscall 
