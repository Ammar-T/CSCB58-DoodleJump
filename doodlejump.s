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
	levels: 	.word 0, 0, 0
	score: 		.word 0
	scrollGrace:	.word 1
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
		
		li $a0, 27
		jal createLevel
		addi $t3, $t3, 4
	
		li $a0, 20
		jal createLevel
		addi $t3, $t3, 4

		li $a0, 13
		jal createLevel
		
		lw $t2, 0($t1)
		sw $t2, 0($sp)
		
		# Jump height limit counter (limit = 10)
		li $t9, 0
		li $t3, 0
		
		# Game loop
		RUN: 		
			blt $t9, 10, flyUp
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
				
				blt $t0, 268465728, scrollRange2
				bgt $t0, 268465856, scrollRange2
				j Scroll
				
				scrollRange2:
					blt $t0, 268465216, continue
					bgt $t0, 268465344, continue
					j Scroll
			continue:
				# Hit the bottom
				bge $t0, 268468120, main

				# Handle left and right movement
				lw $t8, 0xffff0000 
				beq $t8, 1, leftOrRight
				
				j RUN
			
Scroll:
	jal IncreaseScore
	
	# if 0, cannot scroll
	lw $t4, scrollGrace
	beq $t4, 0, continue
	# can scroll, reset grace for next iterations
	li $t4, 0
	sw $t4, scrollGrace
	
	li $t6, 0
	li $t4, 0
	la $t8, levels
	
	# loop each level
	loopLevels:
		beq $t6, 3, addLevelAndContinue
		
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
		sw $t2, 896($s4)
		
		# increment counter and address
		addi $s4, $s4, 4
		addi $t4, $t4, 1
		blt $t4, 8, lowerLevel
		
		# update level to new location (896 - 32 = vertical diff - horizontal shift)
		addi $s4, $s4, 864
		move $t4, $s4
		sw $t4, 0($t8)
		
		li $t4, 0
		jr $ra
	
	addLevelAndContinue:
		li $v0, 32
		li $a0, 30
		syscall
	
		li $a0, 11
		jal createLevel
		addi $t3, $t3, 4
		beq $t3, 12, resetLevelCounter
		j continue
		resetLevelCounter:
			li $t3, 0
			j continue
			
IncreaseScore:
	lw $t4, score
	addi $t4, $t4, 1
	sw $t4, score
	
	li $v0, 1
	move $a0, $t4
	syscall
	li $v0, 4
	la $a0, newline
	syscall

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
	
	# (5 || 13 || 22 || 27) x 2^7 = 128
	sll $a0, $a0, 7
	add $t5, $t5, $a0
	
	# generate random number for x-coordinate
	li $v0, 42
	li $a0, 0
	li $a1, 24
	syscall
	
	# make multiple of 4 (x * 2^2)
	sll $a0, $a0, 2
	add $t5, $t5, $a0	
   	
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
		# end scrolling grace period
		lw $t4, scrollGrace
		addi $t4, $t4, 1
		sw $t4, scrollGrace
			
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
	
	
		 
