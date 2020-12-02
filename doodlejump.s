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
	levels: 	.word 0, 0, 0, 0
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
		li $t3, 0
				
		li $a0, 250
		li $a1, 200
		jal createLevel
		addi $t3, $t3, 4
		
		li $a0, 500
		li $a1, 200
		jal createLevel
		addi $t3, $t3, 4
	
		li $a0, 500
		li $a1, 200
		jal createLevel
		addi $t3, $t3, 4

		li $a0, 750
		li $a1, 200
		jal createLevel
		
		
		lw $t2, 0($t1)
		sw $t2, 0($sp)
		
		# Jump height limit counter (limit = 10)
		li $t9, 0
		li $t3, 0
		
		# Game loop
		RUN: 		
			blt $t9, 12, flyUp
			flyDown:
				jal RepaintFlyDown
				li $a0, 128
				jal changeY
				jal hitLevel
				j continue
			flyUp:	
				jal RepaintFlyUp
				li $a0, -128
				jal changeY
				addi $t9, $t9, 1
				
				# Scroll screen up
				ble $t0, 268465544, Scroll
			continue:
				# Hit the bottom
				bge $t0, 268470272, main

				# Handle left and right movement
				lw $t8, 0xffff0000 
				beq $t8, 1, leftOrRight
				
				j RUN
			
Scroll:
	li $t6, 0
	li $t4, 0
	la $t8, levels
		
	# loop each pixel
	loopLevels:
		beq $t6, 4, RUN
		
		# $s4 = levels[i]
		lw $s4, 0($t8)
		jal lowerLevel
		
		# add 4 per iteration
		addi $t8, $t8, 4 
		addi $t6, $t6, 1
		j loopLevels
		
		
	lowerLevel:
		# load blue
		lw $t2, 0($t1)
		# color current blue
		sw $t2, 0($s4)
		# load green color
		lw $t2, 8($t1)
		# color bottom block green
		sw $t2, 256($s4)

		# increment counter and address
		addi $s4, $s4, 4
		addi $t4, $t4, 1
		blt $t4, 8, lowerLevel
		
		# update level to new location (256 - 32 = vertical diff - horizontal shift)
		addi $s4, $s4, 224
		move $t4, $s4
		sw $t4, 0($t8)
		
		li $t4, 0
		jr $ra
	
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
	li $a0, 70
	syscall
	# pop from stack and color accordingly
	lw $t2, 0($sp)
	sw $t2, 4036($t0)
	lw $t2, 4($sp)
	sw $t2, 4032($t0)
	addi $sp, $sp, 8
	
	jr $ra

createLevel:
	# copy display address
	lw $t5, displayAddress
	move $t4, $a0
	
	# generate random number
	li $v0, 42
	li $a0, 0
	syscall
	add $a0, $a0, $t4
	move $t6, $a0
	
	# make multiple of 4 (x * 2^2)
	sll $t6, $t6, 2
	add $t5, $t5, $t6	
   	
   	# add level location to levels array
   	la $t2, levels
   	add $t2, $t2, $t3
   	sw $t5, 0($t2)
   	
	# draw level
	lw $t2, 8($t1)
	sw $t2, 0($t5)
	sw $t2, 4($t5)	
	sw $t2, 8($t5)	
	sw $t2, 12($t5)	
	sw $t2, 16($t5)
	sw $t2, 20($t5)
	sw $t2, 24($t5)
	sw $t2, 28($t5)
	
	jr $ra

hitLevel: 
	la $t8, levels
	
	# get color of block below (left unit)
	lw $t5, 4160($t0)
		
	# green = -11946474
	beq $t5, -11946474, resetFly
	
	# get color of block below (right unit)
	lw $t5, 4164($t0)
	# green = -11946474
	beq $t5, -11946474, resetFly
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
