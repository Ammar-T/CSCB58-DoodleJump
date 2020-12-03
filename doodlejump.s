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
	displayAddress:		.word 0x10008000
	levels: 		.word 0, 0, 0 # normal, normal, normal
	score: 			.word 0
	scrollGrace:		.word 1
	brownLevelGrace: 	.word 5
	brownLevelActive:   	.word 0
	colors: 		.word 0xFF3E7EAC 0xFFDB4D6A 0xFF9ABFD9, 0xFFEFF5F9 0xFF4DDBBD # background, ball, level, clouds, text
	newline: 		.asciiz "\n"

.globl main
.text

main:	
	preGameText:
		li $a0, 0
		jal clearScreen
		jal startText
		jal quitText
		j signalAwait
		
	postGameText:
		li $a0, 0
		jal clearScreen
		jal lostText
		
	# Wait for signal (start, restart, exit)
	signalAwait:
		lw $t0, displayAddress	
		la $t1, colors	
		
		lw $t8, 0xffff0000 
		beq $t8, 1, initGame
		j signalAwait

	initGame:
		jal clearScreen
		sw $zero, score
		lw $t5, 0xffff0004
		beq $t5, 0x71, Exit 	 # Press Q
		beq $t5, 0x72, StartLoop # Press R
		beq $t5, 0x73, StartLoop # Press T
		j main

	StartLoop: 
		li $t3, 0
		
		# a0 - height of level, a1 - color of level
		li $a1, 8
		li $a0, 27
		jal createLevel
		addi $t3, $t3, 4
	
		li $a1, 8
		li $a0, 20
		jal createLevel
		addi $t3, $t3, 4
		
		li $a1, 8
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
				bge $t0, 268468120, postGameText

				# Handle left and right movement
				lw $t8, 0xffff0000 
				beq $t8, 1, leftOrRight
				
				j RUN
			
Scroll:
	jal IncreaseScore
	
	# if 0, cannot scroll
	lw $t4, scrollGrace
	beq $t4, 0, continue
	# reset grace for next iterations
	li $t4, 0
	sw $t4, scrollGrace
	
	li $t6, 0
	li $t4, 0
	la $t8, levels

	loopLevels:
		beq $t6, 3, addLevelAndContinue
		
		lw $s4, 0($t8)
		jal lowerLevel
		
		# add 4 per iteration
		addi $t8, $t8, 4 
		addi $t6, $t6, 1
		j loopLevels
		
	lowerLevel:
		lowerTopHalf:
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
			blt $t4, 8, lowerTopHalf
			li $t4, 0
			addi $s4, $s4, 104
		lowerBottomHalf:
			# load blue
			lw $t2, 0($t1)
			# color current blue
			sw $t2, 0($s4)
			# load green color
			lw $t2, 8($t1)
			# color bottom block green
			sw $t2, 896($s4)
			addi $s4, $s4, 4
			addi $t4, $t4, 1
			blt $t4, 4, lowerBottomHalf
		
		# update level to new location (896 - 128 - 24 = vertical diff - horizontal shift)
		addi $s4, $s4, 744
		move $t4, $s4
		sw $t4, 0($t8)
		
		li $t4, 0
		jr $ra
	
	addLevelAndContinue:	
		li $a0, 11
		li $a1, 8
		jal createLevel
		addi $t3, $t3, 4
		ble $t3, 8, continue
		
		resetLevelCounter:
			li $t3, 0
			j continue

IncreaseScore:
	lw $t4, score
	addi $t4, $t4, 1
	sw $t4, score
	
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
	# init which color to make level
	move $t4, $a1
	
	# 2^7 = 128
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
	add $t1, $t1, $t4
	lw $t2, 0($t1)
	sw $t2, 0($t5)
	sw $t2, 4($t5)	
	sw $t2, 8($t5)	
	sw $t2, 12($t5)	
	sw $t2, 16($t5)
	sw $t2, 20($t5)
	sw $t2, 24($t5)
	sw $t2, 28($t5)
	sw $t2, 136($t5)
	sw $t2, 140($t5)
	sw $t2, 144($t5)
	sw $t2, 148($t5)
	sub $t1, $t1, $t4
	
	jr $ra

hitLevel: 
	la $t8, levels
	
	# get color of block below (left unit)
	lw $t5, 4160($t0)
		
	# green = -11946474
	beq $t5, -6635559, resetFly
	
	# if block below is green
	lw $t5, 4164($t0)
	beq $t5, -6635559, resetFly
	jr $ra
	
	resetFly:	
		# end scrolling grace period
		lw $t4, scrollGrace
		addi $t4, $t4, 1
		sw $t4, scrollGrace
			
		li $t9, 0
		jr $ra
		
clearScreen:
	lw $t0, displayAddress	
	la $t1, colors	
	li $t6, 0
	add $t1, $t1, $a0
	lw $t2, 0($t1)
	NotCleared:
		sw $t2, 0($t0)
		addi $t0, $t0, 4
		addi $t6, $t6, 1
		blt $t6, 1024, NotCleared
	
	lw $t0, displayAddress
	sub $t1, $t1, $a0
	li $t6, 0
	
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	jal drawClouds
	
	lw $ra, 0($sp)
	
	jr $ra

drawClouds:
	lw $t0, displayAddress
	lw $t2, 12($t1)
	
	# top left cloud
	sw $t2, 12($t0)
	sw $t2, 136($t0)
	sw $t2, 140($t0)
	sw $t2, 144($t0)
	sw $t2, 260($t0)
	sw $t2, 264($t0)
	sw $t2, 268($t0)
	sw $t2, 272($t0)
	sw $t2, 276($t0)
	sw $t2, 280($t0)
	
	# middles left cloud
	addi $t0, $t0, 1572
	sw $t2, 12($t0)
	sw $t2, 136($t0)
	sw $t2, 140($t0)
	sw $t2, 144($t0)
	sw $t2, 260($t0)
	sw $t2, 264($t0)
	sw $t2, 268($t0)
	sw $t2, 272($t0)
	sw $t2, 276($t0)
	sw $t2, 280($t0)
	subi $t0, $t0, 1572
	
	# top right cloud
	sw $t2, 224($t0)
	sw $t2, 348($t0)
	sw $t2, 352($t0)
	sw $t2, 356($t0)
	sw $t2, 468($t0)
	sw $t2, 472($t0)
	sw $t2, 476($t0)
	sw $t2, 480($t0)
	sw $t2, 484($t0)
	sw $t2, 488($t0)
	sw $t2, 492($t0)
	
	# top right cloud
	addi $t0, $t0, 3328
	sw $t2, 224($t0)
	sw $t2, 348($t0)
	sw $t2, 352($t0)
	sw $t2, 356($t0)
	sw $t2, 468($t0)
	sw $t2, 472($t0)
	sw $t2, 476($t0)
	sw $t2, 480($t0)
	sw $t2, 484($t0)
	sw $t2, 488($t0)
	sw $t2, 492($t0)
	
	lw $t0, displayAddress
	jr $ra

startText:
	la $t1, colors	
	lw $t0, displayAddress
	lw $t2, 16($t1)
	
	# s
	addi $t0, $t0, 652
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 256($t0)
	sw $t2, 260($t0)
	sw $t2, 264($t0)
	sw $t2, 392($t0)
	sw $t2, 520($t0)
	sw $t2, 516($t0)
	sw $t2, 512($t0)
	
	
	# t
	addi $t0, $t0, 16
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 132($t0)
	sw $t2, 260($t0)
	sw $t2, 388($t0)
	sw $t2, 516($t0)
	
	#a
	addi $t0, $t0, 16
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 136($t0)
	sw $t2, 256($t0)
	sw $t2, 260($t0)
	sw $t2, 264($t0)
	sw $t2, 384($t0)
	sw $t2, 392($t0)
	sw $t2, 520($t0)
	sw $t2, 512($t0)
	sw $t2, 520($t0)
	
	#r
	addi $t0, $t0, 16
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 136($t0)
	sw $t2, 256($t0)
	sw $t2, 260($t0)
	sw $t2, 264($t0)
	sw $t2, 384($t0)
	sw $t2, 388($t0)
	sw $t2, 520($t0)
	sw $t2, 512($t0)
	sw $t2, 520($t0)
	
	#t
	addi $t0, $t0, 16
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 132($t0)
	sw $t2, 260($t0)
	sw $t2, 388($t0)
	sw $t2, 516($t0)
	
	# -
	addi $t0, $t0, 16
	sw $t2, 256($t0)
	sw $t2, 260($t0)
	sw $t2, 264($t0)
	
	# r
	addi $t0, $t0, 16
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 136($t0)
	sw $t2, 256($t0)
	sw $t2, 260($t0)
	sw $t2, 264($t0)
	sw $t2, 384($t0)
	sw $t2, 388($t0)
	sw $t2, 520($t0)
	sw $t2, 512($t0)
	sw $t2, 520($t0)
	
	addi $t0, $t0, 16
	
	lw $t0, displayAddress
	jr $ra

quitText:
	la $t1, colors	
	lw $t0, displayAddress
	lw $t2, 16($t1)
	
	# q
	addi $t0, $t0, 2452
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 136($t0)
	sw $t2, 256($t0)
	sw $t2, 264($t0)
	sw $t2, 384($t0)
	sw $t2, 388($t0)
	sw $t2, 392($t0)
	sw $t2, 516($t0)
	
	# u
	addi $t0, $t0, 16
	sw $t2, 0($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 136($t0)
	sw $t2, 256($t0)
	sw $t2, 264($t0)
	sw $t2, 384($t0)
	sw $t2, 392($t0)
	sw $t2, 520($t0)
	sw $t2, 512($t0)
	sw $t2, 516($t0)
	sw $t2, 520($t0)
		 
	# i
	addi $t0, $t0, 12
	sw $t2, 4($t0)
	sw $t2, 132($t0)
	sw $t2, 260($t0)
	sw $t2, 388($t0)
	sw $t2, 516($t0)
	
	# t
	addi $t0, $t0, 12
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 132($t0)
	sw $t2, 260($t0)
	sw $t2, 388($t0)
	sw $t2, 516($t0)
	
	# -
	addi $t0, $t0, 16
	sw $t2, 256($t0)
	sw $t2, 260($t0)
	sw $t2, 264($t0)
	
	# q
	addi $t0, $t0, 16
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 136($t0)
	sw $t2, 256($t0)
	sw $t2, 264($t0)
	sw $t2, 384($t0)
	sw $t2, 388($t0)
	sw $t2, 392($t0)
	sw $t2, 516($t0)
	
	addi $t0, $t0, 16
	
	lw $t0, displayAddress
	jr $ra
	
lostText:
	la $t1, colors	
	lw $t0, displayAddress
	lw $t2, 16($t1)
	
	# y
	addi $t0, $t0, 772
	sw $t2, 0($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 136($t0)
	sw $t2, 260($t0)
	sw $t2, 388($t0)
	sw $t2, 516($t0)
	
	# o
	addi $t0, $t0, 16
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 136($t0)
	sw $t2, 256($t0)
	sw $t2, 264($t0)
	sw $t2, 384($t0)
	sw $t2, 392($t0)
	sw $t2, 512($t0)
	sw $t2, 516($t0)
	sw $t2, 520($t0)
		 
	# u
	addi $t0, $t0, 16
	sw $t2, 0($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 136($t0)
	sw $t2, 256($t0)
	sw $t2, 264($t0)
	sw $t2, 384($t0)
	sw $t2, 392($t0)
	sw $t2, 520($t0)
	sw $t2, 512($t0)
	sw $t2, 516($t0)
	sw $t2, 520($t0)
	
	# l
	addi $t0, $t0, 20
	sw $t2, 0($t0)
	sw $t2, 128($t0)
	sw $t2, 256($t0)
	sw $t2, 384($t0)
	sw $t2, 520($t0)
	sw $t2, 512($t0)
	sw $t2, 516($t0)
	sw $t2, 520($t0)
	
	# o
	addi $t0, $t0, 16
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 136($t0)
	sw $t2, 256($t0)
	sw $t2, 264($t0)
	sw $t2, 384($t0)
	sw $t2, 392($t0)
	sw $t2, 512($t0)
	sw $t2, 516($t0)
	sw $t2, 520($t0)
	
	# s
	addi $t0, $t0, 16
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 256($t0)
	sw $t2, 260($t0)
	sw $t2, 264($t0)
	sw $t2, 392($t0)
	sw $t2, 520($t0)
	sw $t2, 516($t0)
	sw $t2, 512($t0)
	
	# t
	addi $t0, $t0, 16
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 132($t0)
	sw $t2, 260($t0)
	sw $t2, 388($t0)
	sw $t2, 516($t0)
	
	addi $t0, $t0, 12
	sw $t2, 4($t0)
	sw $t2, 132($t0)
	sw $t2, 260($t0)
	sw $t2, 516($t0)
	
	addi $t0, $t0, 16
	
	lw $t0, displayAddress
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
	
	# layout
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 132($t0)
	sw $t2, 136($t0)
	sw $t2, 256($t0)
	sw $t2, 260($t0)
	sw $t2, 264($t0)
	sw $t2, 384($t0)
	sw $t2, 388($t0)
	sw $t2, 392($t0)
	sw $t2, 520($t0)
	sw $t2, 512($t0)
	sw $t2, 516($t0)
	sw $t2, 520($t0)
		 
