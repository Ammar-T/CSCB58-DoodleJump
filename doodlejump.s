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
# - Milestone 4/5 (choose the one the applies)
#
# Which approved additional features have been implemented?
# (See the assignment handout for the list of additional features)
# 1. Fancier graphics
# 2. Dynamic notifications
# 3. Boosting/powerups
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
	levels: 			.word 0, 0, 0 
	jumpHeight:			.word 10
	score: 				.word 0
	jetpackGas:			.word 0
	jetpackAvailable:	.word 0
	jetpackActivated:	.word 0
	jetpackLocation:	.word 0
	speed:				.word 75	# initial speed
	notif:				.word 0, 0 	# timer, type of noti (wow - 0, yay- 1, woo- 2)
	scrollGrace:		.word 1
	colors: 			.word 0xFF3E7EAC 0xFFDB4D6A 0xFF9ABFD9, 0xFFEFF5F9 0xFF4DDBBD, 0xFFFF6347, 0xFFFAE549, 0xFFCD853F # background, ball, level, clouds, text, score, notiText, notiBackground
	newline: 			.asciiz "\n"

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
		jal scoreText
		jal printScore
		
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
		sw $zero, jetpackAvailable
		sw $zero, jetpackActivated
		sw $zero, jetpackLocation
		sw $zero, score
		li $t3, 75
		sw $t3, speed
		li $t3, 10
		sw $t3, speed
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
		
		# add colors to stack
		lw $t2, 0($t1)
		sw $t2, 0($sp)
		
		# Jump height limit counter (limit = 10)
		li $t9, 0
		li $t3, 0
				
		# Game loop
		RUN: 	
			lw $t4, jetpackGas
			bgt $t4, 0, jetpack	
			lw $t4, jumpHeight
			blt $t9, $t4, flyUp
			j flyDown
			jetpack:
				j Scroll
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
				# update status once jetpack ends
				lw $t4, jetpackGas
				beq $t4, 0, updateJetpackStatus
				j handleLeftRight
				updateJetpackStatus:
					sw $zero, jetpackActivated

				jal hitJetpack
				
				handleLeftRight:
					# Hit the bottom
					bge $t0, 268468120, postGameText

					# Handle left and right movement
					lw $t8, 0xffff0000 
					beq $t8, 1, leftOrRight
				
				j RUN
			
Scroll:
	jal IncreaseScore
	jal decrementNoti
	jal decrementJetpackGas
	
	lw $t4, jetpackActivated
	beq $t4, 0, useScrollGracePeriod
	j jetpackOn
	
	useScrollGracePeriod:
		# if 0, cannot scroll
		lw $t4, scrollGrace
		beq $t4, 0, continue
		# reset grace for next iterations
		li $t4, 0
		sw $t4, scrollGrace
		j init
	
	jetpackOn:
		jal RepaintFlyUp
		li $a0, -128
		jal changeY
		
	init:	
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
			# load blue, green
			lw $t2, 0($t1)
			lw $t5, 8($t1)
			
			sw $t2, 0($s4)
			sw $t5, 128($s4)
			sw $t2, 128($s4)
			sw $t5, 256($s4)
			li $v0, 32
			li $a0, 2
			syscall
			sw $t2, 256($s4)
			sw $t5, 384($s4)
			sw $t2, 384($s4)
			sw $t5, 512($s4)
			sw $t2, 512($s4)
			sw $t5, 640($s4)
			sw $t2, 640($s4)
			sw $t5, 768($s4)
			li $v0, 32
			li $a0, 2
			syscall
			sw $t2, 768($s4)
			sw $t5, 896($s4)
		
			# increment counter and address
			addi $s4, $s4, 4
			addi $t4, $t4, 1
			blt $t4, 8, lowerTopHalf
			li $t4, 0
			addi $s4, $s4, 104
		lowerBottomHalf:
			# load blue, green
			lw $t2, 0($t1)
			lw $t5, 8($t1)

			sw $t2, 0($s4)
			sw $t5, 128($s4)
			sw $t2, 128($s4)
			sw $t5, 256($s4)
			li $v0, 32
			li $a0, 2
			syscall
			sw $t2, 256($s4)
			sw $t5, 384($s4)
			sw $t2, 384($s4)
			sw $t5, 512($s4)
			sw $t2, 512($s4)
			sw $t5, 640($s4)
			li $v0, 32
			li $a0, 2
			syscall
			sw $t2, 640($s4)
			sw $t5, 896($s4)
		
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
		lw $t4, jetpackAvailable # not if using jetpack but if its on the screen somewhere
		beq $t4, 1, moveJetpack
		lw $t4, jetpackActivated
		beq $t4, 1, moveJetpack
		j not
		moveJetpack:
			jal moveJetpackDown
		not:
		li $a0, 11
		li $a1, 8
		jal createLevel
		addi $t3, $t3, 4
		ble $t3, 8, continue
		
		resetLevelCounter:
			li $t3, 0
			lw $ra, 0($sp)
			addi $sp, $sp, 4
			j continue

IncreaseScore:
	lw $t4, score
	addi $t4, $t4, 1
	sw $t4, score
	
	beq $t4, 40, increaseSpeed45
	beq $t4, 20, increaseSpeed50
	beq $t4, 10, increaseSpeed60
	jr $ra
	increaseSpeed60:
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		li $a0, 0
		jal createNoti
		lw $ra, 0($sp)
		li $t4, 60
		sw $t4, speed
		jr $ra
	increaseSpeed50:
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		li $a0, 1
		jal createNoti
		lw $ra, 0($sp)
		li $t4, 50
		sw $t4, speed
		jr $ra
	increaseSpeed45:
		li $t4, 11
		sw $t4, jumpHeight
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		li $a0, 2
		jal createNoti
		lw $ra, 0($sp)
		li $t4, 45
		sw $t4, speed
	jr $ra
   	

createNoti:
   	la $t5, notif
   	li $t4, 5		# noti stays on screen for 5 scrolls
   	sw $t4, 0($t5)		
	
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $a1, 24($t1) # set color of text to be yellow
	beq $a0, 0, wow
	beq $a0, 1, yay
	beq $a0, 2, woo

	wow: 
		li $t4, 0		# save noti type as wow
   		sw $t4, 4($t5)
		jal wowText
		j exit
	yay:
		li $t4, 1		# save noti type as yay
   		sw $t4, 4($t5)
		jal yayText
		j exit
	woo:
		li $t4, 2		# save noti type as woo
   		sw $t4, 4($t5)
		jal wooText
	exit:
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra

decrementJetpackGas:
	lw $t4, jetpackGas
	bgt $t4, 0, loseGas
	jr $ra
	
	loseGas:
		addi $t4, $t4, -1
		sw $t4, jetpackGas
		jr $ra
	
	
decrementNoti:
	la $t5, notif
	lw $t4, 0($t5) 
	
	bgt $t4, 0, decrement
	jr $ra
	
	decrement:
		addi $t4, $t4, -1
		sw $t4, 0($t5)
		
		# has reached time limit -> clear now
		beq $t4, 0, clearNoti
		jr $ra
		clearNoti:
			addi $sp, $sp, -4
			sw $ra, 0($sp)
			
			# repaint area sky blue
			lw $a0, 0($t1)
			jal setNotiBackground
			
			lw $ra, 0($sp)
			addi $sp, $sp, 4
			jr $ra
	
	
RepaintFlyUp:
	# push above-block colors onto stack
	addi $sp, $sp, -24
	lw $t2, 3656($t0)
	sw $t2, 0($sp)
	lw $t2, 3648($t0)
	sw $t2, 4($sp)
	lw $t2, 3780($t0)
	sw $t2, 8($sp)
	lw $t2, 3912($t0)
	sw $t2, 12($sp)
	lw $t2, 3908($t0)
	sw $t2, 16($sp)
	lw $t2, 3904($t0)
	sw $t2, 20($sp)
	jr $ra

RepaintFlyDown:
	# push below-block colors onto stack
	addi $sp, $sp, -24
	lw $t2, 3912($t0) # top
	sw $t2, 0($sp)
	lw $t2, 3904($t0) # top
	sw $t2, 4($sp)
	lw $t2, 4036($t0) # top
	sw $t2, 8($sp)
	lw $t2, 4168($t0) # bot right
	sw $t2, 12($sp)
	lw $t2, 4164($t0) # bot middle
	sw $t2, 16($sp)
	lw $t2, 4160($t0) # bot left
	sw $t2, 20($sp)
	jr $ra

changeY:	
	# color above/below block red
	add $t0, $t0, $a0 
   	lw $t2, 4($t1)
	sw $t2, 4032($t0)
	sw $t2, 4036($t0)
	sw $t2, 4040($t0)
	sw $t2, 3908($t0)
	sw $t2, 3776($t0)
	sw $t2, 3784($t0)
	# wait for sleep to finish
	lw $t4, speed
	li $v0, 32
	move $a0, $t4
	syscall
	# pop from stack and color accordingly
	lw $t2, 0($sp)
	sw $t2, 3784($t0)
	lw $t2, 4($sp)
	sw $t2, 3776($t0)
	lw $t2, 8($sp)
	sw $t2, 3908($t0)
	lw $t2, 12($sp)
	sw $t2, 4040($t0)
	lw $t2, 16($sp)
	sw $t2, 4036($t0)
	lw $t2, 20($sp)
	sw $t2, 4032($t0)
	addi $sp, $sp, 24
	
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

moveJetpackDown:
	lw $t5, jetpackLocation
	
	lw $t2, 0($t1)  # blue
   	sw $t2, -376($t5) 
   	sw $t2, -248($t5)
   	sw $t2, -120($t5)
   	sw $t2, -116($t5)
   	sw $t2, -372($t5)
   	sw $t2, -368($t5)
   	sw $t2, -240($t5)
   	sw $t2, -112($t5)
   	sw $t2, -244($t5)
   	
	addi $t5, $t5, 896
	lw $t2, 24($t1)  # blue
   	sw $t2, -376($t5) 
   	sw $t2, -248($t5)
   	sw $t2, -120($t5)
   	sw $t2, -116($t5)
   	lw $t2, 4($t1)  # red
   	sw $t2, -372($t5)
   	sw $t2, -368($t5)
   	sw $t2, -240($t5)
   	sw $t2, -112($t5)
   	lw $t2, 12($t1) # white
   	sw $t2, -244($t5)
	
	sw $t5, jetpackLocation
   		
	bge $t0, 268468120, jetpackGone
	jr $ra
	jetpackGone:
		sw $zero, jetpackAvailable
	
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
   	
   	la $t2, levels
   	add $t2, $t2, $t3
   	sw $t5, 0($t2)
   	
   	lw $t2, score 
   	beq $t2, 10, drawJetpack
   	beq $t2, 45, drawJetpack
   	beq $t2, 90, drawJetpack
   	j drawPlat
   	
   	drawJetpack:
   		lw $t2, jetpackAvailable
   		beq $t2, 1, drawPlat
   		
   		li $t2, 1
   		sw $t2, jetpackAvailable
   		
   		lw $t2, 24($t1)  # blue
   		sw $t2, -376($t5) 
   		sw $t2, -248($t5)
   		sw $t2, -120($t5)
   		sw $t2, -116($t5)
   		
   		lw $t2, 4($t1)  # red
   		sw $t2, -372($t5)
   		sw $t2, -368($t5)
   		sw $t2, -240($t5)
   		sw $t2, -112($t5)
   		
   		lw $t2, 12($t1) # white
   		sw $t2, -244($t5)
   	
   		sw $t5, jetpackLocation
   		
   	drawPlat:
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
   
hitJetpack:
	lw $t4, jetpackLocation
	addi $t4, $t4, -376
	
	# if block below is JETPACK (middle unit)
	la $t5, 4160($t0)
	beq $t5, $t4, activateJet
	
	# if block below is JETPACK (right unit)
	la $t5, 4164($t0)
	beq $t5, $t4, activateJet
	
	# if block below is JETPACK (left unit)
	la $t5, 4168($t0)
	beq $t5, $t4, activateJet
	
	addi $t4, $t4, 376
	jr $ra
	
	activateJet:
		li $t4, 1
		sw $t4, jetpackActivated
		sw $zero, jetpackAvailable
		li $t4, 25
		sw $t4, jetpackGas
		jr $ra
	
hitLevel: 
	la $t8, levels
	
	# if block below is green (middle unit)
	lw $t5, 4160($t0)
	beq $t5, -6635559, resetFly
	
	# if block below is green (right unit)
	lw $t5, 4164($t0)
	beq $t5, -6635559, resetFly
	
	# if block below is green (left unit)
	lw $t5, 4168($t0)
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
	addi $sp, $sp, 4
	
	jr $ra


###############################         DRAWINGS // TEXT        ############################################# 
###############################         DRAWINGS // TEXT        ############################################# 
###############################         DRAWINGS // TEXT        ############################################# 
###############################         DRAWINGS // TEXT        ############################################# 
###############################         DRAWINGS // TEXT        ############################################# 
###############################         DRAWINGS // TEXT        ############################################# 
   	
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

setNotiBackground:
	lw $t4, displayAddress
	addi $t4, $t4, 28 # shift background right
	move $t2, $zero
	
	li $t6, 0
	y:
		li $t5, 0
		x:	
			add $t4, $t4, $t5
			add $t4, $t4, $t6
			sw $a0, 0($t4)
			sub $t4, $t4, $t5
			sub $t4, $t4, $t6
			
			addi $t5, $t5, 4
			ble $t5, 60, x
		addi $t6, $t6, 128
		ble $t6, 768, y
	
	jr $ra
	
wowText:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t4, 28($t1)
	move $a0, $t4
	jal setNotiBackground
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	lw $t4, displayAddress
	move $t2, $a1 # set color of text
	
	addi $t4, $t4, 160
	# w
	sw $t2, 0($t4)
	sw $t2, 8($t4)
	sw $t2, 128($t4)
	sw $t2, 136($t4)
	sw $t2, 256($t4)
	sw $t2, 264($t4)
	sw $t2, 384($t4)
	sw $t2, 388($t4)
	sw $t2, 392($t4)
	sw $t2, 512($t4)
	sw $t2, 520($t4)
	
	# o
	addi $t4, $t4, 16
	sw $t2, 0($t4)
	sw $t2, 4($t4)
	sw $t2, 8($t4)
	sw $t2, 128($t4)
	sw $t2, 136($t4)
	sw $t2, 256($t4)
	sw $t2, 264($t4)
	sw $t2, 384($t4)
	sw $t2, 392($t4)
	sw $t2, 512($t4)
	sw $t2, 516($t4)
	sw $t2, 520($t4)
	
	# w
	addi $t4, $t4, 16
	sw $t2, 0($t4)
	sw $t2, 8($t4)
	sw $t2, 128($t4)
	sw $t2, 136($t4)
	sw $t2, 256($t4)
	sw $t2, 264($t4)
	sw $t2, 384($t4)
	sw $t2, 388($t4)
	sw $t2, 392($t4)
	sw $t2, 512($t4)
	sw $t2, 520($t4)
	
	# !
	addi $t4, $t4, 16
	sw $t2, 4($t4)
	sw $t2, 132($t4)
	sw $t2, 260($t4)
	sw $t2, 516($t4)

	jr $ra

wooText:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t4, 28($t1)
	move $a0, $t4
	jal setNotiBackground
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	lw $t4, displayAddress
	move $t2, $a1 # set color of text
	
	addi $t4, $t4, 160
	# w
	sw $t2, 0($t4)
	sw $t2, 8($t4)
	sw $t2, 128($t4)
	sw $t2, 136($t4)
	sw $t2, 256($t4)
	sw $t2, 264($t4)
	sw $t2, 384($t4)
	sw $t2, 388($t4)
	sw $t2, 392($t4)
	sw $t2, 512($t4)
	sw $t2, 520($t4)
	
	# o
	addi $t4, $t4, 16
	sw $t2, 0($t4)
	sw $t2, 4($t4)
	sw $t2, 8($t4)
	sw $t2, 128($t4)
	sw $t2, 136($t4)
	sw $t2, 256($t4)
	sw $t2, 264($t4)
	sw $t2, 384($t4)
	sw $t2, 392($t4)
	sw $t2, 512($t4)
	sw $t2, 516($t4)
	sw $t2, 520($t4)
	
	# o
	addi $t4, $t4, 16
	sw $t2, 0($t4)
	sw $t2, 4($t4)
	sw $t2, 8($t4)
	sw $t2, 128($t4)
	sw $t2, 136($t4)
	sw $t2, 256($t4)
	sw $t2, 264($t4)
	sw $t2, 384($t4)
	sw $t2, 392($t4)
	sw $t2, 512($t4)
	sw $t2, 516($t4)
	sw $t2, 520($t4)
	
	# !
	addi $t4, $t4, 16
	sw $t2, 4($t4)
	sw $t2, 132($t4)
	sw $t2, 260($t4)
	sw $t2, 516($t4)

	jr $ra
	
yayText:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t4, 28($t1)
	move $a0, $t4
	jal setNotiBackground
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	lw $t4, displayAddress
	move $t2, $a1 # set color of text
	
	addi $t4, $t4, 160
	# y
	sw $t2, 0($t4)
	sw $t2, 8($t4)
	sw $t2, 128($t4)
	sw $t2, 136($t4)
	sw $t2, 260($t4)
	sw $t2, 388($t4)
	sw $t2, 516($t4)
	
	# a
	addi $t4, $t4, 16
	sw $t2, 0($t4)
	sw $t2, 4($t4)
	sw $t2, 8($t4)
	sw $t2, 128($t4)
	sw $t2, 136($t4)
	sw $t2, 256($t4)
	sw $t2, 260($t4)
	sw $t2, 264($t4)
	sw $t2, 384($t4)
	sw $t2, 392($t4)
	sw $t2, 520($t4)
	sw $t2, 512($t4)
	sw $t2, 520($t4)
	
	# y
	addi $t4, $t4, 16
	sw $t2, 0($t4)
	sw $t2, 8($t4)
	sw $t2, 128($t4)
	sw $t2, 136($t4)
	sw $t2, 260($t4)
	sw $t2, 388($t4)
	sw $t2, 516($t4)
	
	# !
	addi $t4, $t4, 16
	sw $t2, 4($t4)
	sw $t2, 132($t4)
	sw $t2, 260($t4)
	sw $t2, 516($t4)

	jr $ra
		
scoreText:
	la $t1, colors	
	lw $t0, displayAddress
	lw $t2, 20($t1)
	
	# s
	addi $t0, $t0, 2328
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
	
	# c
	addi $t0, $t0, 16
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 256($t0)
	sw $t2, 384($t0)
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
	
	# e
	addi $t0, $t0, 16
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 128($t0)
	sw $t2, 256($t0)
	sw $t2, 260($t0)
	sw $t2, 264($t0)
	sw $t2, 384($t0)
	sw $t2, 512($t0)
	sw $t2, 516($t0)
	sw $t2, 520($t0)
	
	# :
	addi $t0, $t0, 16
	sw $t2, 128($t0)
	sw $t2, 384($t0)


	addi $t0, $t0, 16
	
	lw $t0, displayAddress
	jr $ra
	
printScore:
	la $t1, colors	
	lw $t0, displayAddress
	lw $t2, 28($t1)
	
	li $t3, 10
	lw $t4, score
	div $t4, $t3
	mflo $t5
	mfhi $t6
		
	drawHundreds:
		addi $t0, $t0, 3248
		li $a0, 1
		beq $t5, 0, drawZero
		beq $t5, 1, drawOne
		beq $t5, 2, drawTwo
		beq $t5, 3, drawThree
		beq $t5, 4, drawFour
		beq $t5, 5, drawFive
		beq $t5, 6, drawSix
		beq $t5, 7, drawSeven
		beq $t5, 8, drawEight
		beq $t5, 9, drawNine
		
	drawOnes:
		addi $t0, $t0, 16
		li $a0, 0
		beq $t6, 0, drawZero
		beq $t6, 1, drawOne
		beq $t6, 2, drawTwo
		beq $t6, 3, drawThree
		beq $t6, 4, drawFour
		beq $t6, 5, drawFive
		beq $t6, 6, drawSix
		beq $t6, 7, drawSeven
		beq $t6, 8, drawEight
		beq $t6, 9, drawNine

	j end
	
	drawZero:
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
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawOne:
		sw $t2, 0($t0)
		sw $t2, 4($t0)
		sw $t2, 132($t0)
		sw $t2, 260($t0)
		sw $t2, 388($t0)
		sw $t2, 516($t0)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawTwo:
		sw $t2, 0($t0)
		sw $t2, 4($t0)
		sw $t2, 8($t0)
		sw $t2, 136($t0)
		sw $t2, 256($t0)
		sw $t2, 260($t0)
		sw $t2, 264($t0)
		sw $t2, 384($t0)
		sw $t2, 512($t0)
		sw $t2, 516($t0)
		sw $t2, 520($t0)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawThree:
		sw $t2, 0($t0)
		sw $t2, 4($t0)
		sw $t2, 8($t0)
		sw $t2, 136($t0)
		sw $t2, 256($t0)
		sw $t2, 260($t0)
		sw $t2, 264($t0)
		sw $t2, 392($t0)
		sw $t2, 512($t0)
		sw $t2, 516($t0)
		sw $t2, 520($t0)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawFour:
		sw $t2, 0($t0)
		sw $t2, 8($t0)
		sw $t2, 128($t0)
		sw $t2, 136($t0)
		sw $t2, 256($t0)
		sw $t2, 260($t0)
		sw $t2, 264($t0)
		sw $t2, 392($t0)
		sw $t2, 520($t0)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawFive:
		sw $t2, 0($t0)
		sw $t2, 4($t0)
		sw $t2, 8($t0)
		sw $t2, 128($t0)
		sw $t2, 256($t0)
		sw $t2, 260($t0)
		sw $t2, 264($t0)
		sw $t2, 392($t0)
		sw $t2, 512($t0)
		sw $t2, 516($t0)
		sw $t2, 520($t0)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawSix:
		sw $t2, 0($t0)
		sw $t2, 4($t0)
		sw $t2, 8($t0)
		sw $t2, 128($t0)
		sw $t2, 256($t0)
		sw $t2, 260($t0)
		sw $t2, 264($t0)
		sw $t2, 384($t0)
		sw $t2, 392($t0)
		sw $t2, 512($t0)
		sw $t2, 516($t0)
		sw $t2, 520($t0)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawSeven:
		sw $t2, 0($t0)
		sw $t2, 4($t0)
		sw $t2, 8($t0)
		sw $t2, 128($t0)
		sw $t2, 136($t0)
		sw $t2, 264($t0)
		sw $t2, 392($t0)
		sw $t2, 520($t0)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawEight:
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
		sw $t2, 512($t0)
		sw $t2, 516($t0)
		sw $t2, 520($t0)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawNine:
		sw $t2, 0($t0)
		sw $t2, 4($t0)
		sw $t2, 8($t0)
		sw $t2, 128($t0)
		sw $t2, 136($t0)
		sw $t2, 256($t0)
		sw $t2, 260($t0)
		sw $t2, 264($t0)
		sw $t2, 392($t0)
		sw $t2, 512($t0)
		sw $t2, 516($t0)
		sw $t2, 520($t0)
		beq $a0, 1, drawOnes
		beq $a0, 0, end		
	end: 
		lw $t0, displayAddress
		jr $ra
		 
Exit:
	li $v0, 10 
	syscall
	
	# Text layout
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
	sw $t2, 512($t0)
	sw $t2, 516($t0)
	sw $t2, 520($t0)
		 
