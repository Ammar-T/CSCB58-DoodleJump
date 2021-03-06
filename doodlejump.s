.eqv BACKGROUND 0xFF3E7EAC
.eqv DOODLER 0xFFDB4D6A
.eqv PLATFORM 0xFF9ABFD9
.eqv CLOUDS 0xFFEFF5F9
.eqv TEXT 0xFF4DDBBD
.eqv SCORE 0xFFFF6347
.eqv NOTIFICATION_TEXT 0xFFFAE549
.eqv NOTIFICATION_BACKGROUND 0xFFCD853F

.data
	displayAddress:		.word 0x10008000
	gameActive:			.word 0
	platforms: 			.word 0, 0, 0 
	jumpHeight:			.word 10
	score: 				.word 0
	boostFuel:			.word 0
	boostAvailable:		.word 0
	boostActivated:		.word 0
	boostLocation:		.word 0
	boostType:			.word 0
	speed:				.word 75
	notif:				.word 0
	scrollGrace:		.word 1
	colors: 			.word BACKGROUND, DOODLER, PLATFORM, CLOUDS, TEXT, SCORE, NOTIFICATION_TEXT, NOTIFICATION_BACKGROUND
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
		sw $zero, gameActive
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
		# Reset global vars to original values for restart
		sw $zero, score
		sw $zero, boostAvailable
		sw $zero, boostActivated
		sw $zero, boostLocation
		sw $zero, score
		li $t3, 75
		sw $t3, speed
		li $t3, 10
		sw $t3, jumpHeight
		lw $t5, 0xffff0004
		beq $t5, 0x71, Exit 	 # Press Q
		beq $t5, 0x72, StartLoop # Press R
		beq $t5, 0x73, StartLoop # Press T
		j main

	StartLoop: 
		li $t3, 1
		sw $t3, gameActive
		li $t3, 0
		
		# create first 3 platforms
		# a0 - height of level, a1 - color of level
		li $a0, 27
		li $a1, 8
		jal createPlatform
		addi $t3, $t3, 4

		li $a0, 20
		li $a1, 8
		jal createPlatform
		addi $t3, $t3, 4
		
		li $a0, 13
		li $a1, 8
		jal createPlatform
		
		# Jump height limit counter (limit = 10)
		li $t9, 0
		# This assigns new platform location to the correct index in the array - platforms
		li $t3, 0
				
		# Game loop
		RUN: 	
			jal printScore
			
			lw $t4, boostLocation
				
			# if there is fuel, then use the boost (jetpack or spring)
			lw $t4, boostFuel
			bgt $t4, 0, useBoost

			# if jump height isn't reached, keep flying up, else fly down
			lw $t4, jumpHeight
			blt $t9, $t4, flyUp
			j flyDown

			useBoost:
				j Scroll
			flyDown:
				# before flying to next block, push it's colors so you can pop and repaint later
				jal RepaintFlyDown
				# move the doodler one level down on screen
				li $a0, 128
				jal changeY
				# check if doodle hit any boost or platform
				jal hitBoost
				jal hitLevel
				j continue
			flyUp:
				# before flying to next block, push it's colors so you can pop and repaint later
				jal RepaintFlyUp
				# move the doodler one level up on screen
				li $a0, -128
				jal changeY
				# check if doodle hit any boost
				jal hitBoost
				# increment number of "flyUp" to keep track of jumpHeight
				addi $t9, $t9, 1
				
				# if doodle is in this range, the screen will be scrolled
				blt $t0, 268465728, scrollRange2
				bgt $t0, 268465856, scrollRange2
				j Scroll
				
				# this range is slightly higher up on the screen
				scrollRange2:
					# if doodle is in this range, the screen will be scrolled
					blt $t0, 268465216, continue
					bgt $t0, 268465344, continue
					j Scroll
			continue:
				# once fuel ends update boostActivated variable
				lw $t4, boostFuel
				beq $t4, 0, updateBoostStatus
				j handleLeftRight
				updateBoostStatus:
					sw $zero, boostActivated
				
				handleLeftRight:
					# Hit the bottom
					bge $t0, 268468120, postGameText

					# Handle left and right movement input
					lw $t8, 0xffff0000 
					beq $t8, 1, leftOrRight
				
				j RUN
			
Scroll:
	# Increase score by 1, speed up doodle, show noti if hit certain score
	jal UpdateDifficulty
	# Decrease notification time on screen by 1 per scroll
	jal decrementNoti
	# Decrease boost fuel by 1 per scroll
	jal decrementboostFuel
	
	# No grace period if boosting
	lw $t4, boostActivated
	beq $t4, 0, useScrollGracePeriod
	j boostActive
	
	# reduce excessive scrolling
	useScrollGracePeriod:
		# if 0, cannot scroll
		lw $t4, scrollGrace
		beq $t4, 0, continue
		# reset grace for next iterations
		li $t4, 0
		sw $t4, scrollGrace
		j init
	
	# move doodler up while boosting
	boostActive:
		jal RepaintFlyUp
		li $a0, -128
		jal changeY
		
	init:	
		li $t6, 0
		li $t4, 0
		la $t8, platforms

	# loop over all platforms and move them down
	loopPlatforms:
		# done moving them down, so create a new platform on top of screen
		beq $t6, 3, addLevelAndContinue
		
		# load next platform and move it down
		lw $s4, 0($t8)
		jal lowerLevel
		
		# add 4 per iteration, to move to next platform
		addi $t8, $t8, 4 
		# counter variable tracking how many platforms have been moved 
		addi $t6, $t6, 1
		j loopPlatforms
		
	lowerLevel:
		# lower upper blocks of platform
		lowerTopHalf:
			# load sky blue, platform blue
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
			# move $s4 location to match lowerBottomHalf of the platform (1 level down, 6 blocks left)
			addi $s4, $s4, 104
		# lower lower blocks of platforms
		lowerBottomHalf:
			# load sky blue, platform blue
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
		lw $t4, boostAvailable # move boost -> not if using boost but if its on the screen somewhere
		beq $t4, 1, moveBoost
		lw $t4, boostActivated # move boost -> if using boost, still need to move it down
		beq $t4, 1, moveBoost
		j addPlatform

		moveBoost:
			lw $t4, boostType
			beq $t4, 0, spring
			beq $t4, 1, rocket
			j addPlatform
			spring:	
				jal moveSpringDown
				j addPlatform
			rocket:
				jal moveJetpackDown

		# create new platform at top of screen
		addPlatform:
			li $a0, 11
			li $a1, 8
			jal createPlatform
			addi $t3, $t3, 4
			ble $t3, 8, continue

		# remember: $t3 stores which index to add new platform to in array - platforms	
		updatePlatformCounter:
			li $t3, 0
			lw $ra, 0($sp)
			addi $sp, $sp, 4
			j continue

# change speed, jump height, add notifications
UpdateDifficulty:
	# update score by 1
	lw $t4, score
	addi $t4, $t4, 1
	sw $t4, score
	
	# update speed according to score reached
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
	# noti stays on screen for 5 scrolls
   	la $t5, notif
   	li $t4, 5		
   	sw $t4, 0($t5)		
	
	# store return b/c calling recursively later
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	# set color of text to be yellow
	lw $a1, 24($t1) 
	# print text according to argument provided 
	beq $a0, 0, wow
	beq $a0, 1, yay
	beq $a0, 2, woo

	wow: 
		jal wowText
		j exit
	yay:
		jal yayText
		j exit
	woo:
		jal wooText
	exit:
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra

# lowers fuel on each scroll if boost activated
decrementboostFuel:
	lw $t4, boostFuel
	bgt $t4, 0, loseFuel
	jr $ra
	
	loseFuel:
		addi $t4, $t4, -1
		sw $t4, boostFuel
		jr $ra
	
decrementNoti:
	la $t5, notif
	lw $t4, 0($t5) 
	
	bgt $t4, 0, decrement
	jr $ra
	
	decrement:
		addi $t4, $t4, -1
		sw $t4, 0($t5)
		
		# has reached time limit -> clear notification, else return
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

moveSpringDown:
	lw $t5, boostLocation
	
	# color original area sky blue
	lw $t2, 0($t1)  
   	sw $t2, -376($t5) 
   	sw $t2, -248($t5)
   	sw $t2, -120($t5)
   	sw $t2, -116($t5)
   	sw $t2, -372($t5)
   	sw $t2, -368($t5)
   	sw $t2, -240($t5)
   	sw $t2, -112($t5)
   	sw $t2, -244($t5)
   
	# color area below matching spring shape
	addi $t5, $t5, 896
	lw $t2, 12($t1) 
   	sw $t2, -376($t5) 
   	sw $t2, -248($t5)
   	sw $t2, -120($t5)
   	sw $t2, -116($t5)
   	sw $t2, -372($t5)
   	sw $t2, -240($t5)
   	sw $t2, -112($t5)

	sw $t5, boostLocation
   		
	# if spring scrolls below screen, change status
	bge $t5, 268473000, springGone
	jr $ra
	springGone:
		sw $zero, boostAvailable
	
	jr $ra


moveJetpackDown:
	lw $t5, boostLocation
	
	# color original area sky blue
	lw $t2, 0($t1)  
   	sw $t2, -376($t5) 
   	sw $t2, -248($t5)
   	sw $t2, -120($t5)
   	sw $t2, -116($t5)
   	sw $t2, -372($t5)
   	sw $t2, -368($t5)
   	sw $t2, -240($t5)
   	sw $t2, -112($t5)
   	sw $t2, -244($t5)
   	
	# color area below matching jetpack shape
	addi $t5, $t5, 896
	lw $t2, 24($t1)  
   	sw $t2, -376($t5) 
   	sw $t2, -248($t5)
   	sw $t2, -120($t5)
   	sw $t2, -116($t5)
   	lw $t2, 4($t1)  
   	sw $t2, -372($t5)
   	sw $t2, -368($t5)
   	sw $t2, -240($t5)
   	sw $t2, -112($t5)
   	lw $t2, 12($t1) 
   	sw $t2, -244($t5)
	
	sw $t5, boostLocation
   	
	# if jetpack scrolls below screen, change status
	bge $t5, 268472000, jetpackGone
	jr $ra
	jetpackGone:
		sw $zero, boostAvailable
	
	jr $ra
	
createPlatform:
	# copy display address
	lw $t5, displayAddress
	# init which color to make level
	move $t4, $a1
	
	# y * 2^7 = 128
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
   	
	# update platform location in memory
   	la $t2, platforms
   	add $t2, $t2, $t3
   	sw $t5, 0($t2)
   	
	# add boosts depending on score
   	lw $t2, score 
   	beq $t2, 3, drawSpring
   	beq $t2, 30, drawSpring
   	beq $t2, 10, drawJetpack
   	beq $t2, 11, drawJetpack
   	beq $t2, 45, drawJetpack
   	beq $t2, 90, drawJetpack

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
   
hitBoost:
	lw $t4, boostLocation
	addi $t4, $t4, -376
	
	li $t7, 0
	checkEachBlock:
		li $t6, 0
		travX:
			# block below is boost
			la $t5, 4160($t0)
			beq $t5, $t4, activateBoost
			la $t5, 4164($t0)
			beq $t5, $t4, activateBoost
			la $t5, 4168($t0)
			beq $t5, $t4, activateBoost
	
			# block above is boost
			la $t5, 3904($t0)
			beq $t5, $t4, activateBoost
			la $t5, 3908($t0)
			beq $t5, $t4, activateBoost
			la $t5, 3912($t0)
			beq $t5, $t4, activateBoost
			
			addi $t6, $t6, 1
			addi $t4, $t4, 4
			blt $t6, 3, travX
		addi $t4, $t4, 120
		addi $t7, $t7, 1
		blt $t7, 3, checkEachBlock
		jr $ra
	
	activateBoost:
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		li $a0, 1
		jal createNoti
		lw $ra, 0($sp)
		
		li $t4, 1
		sw $t4, boostActivated
		sw $zero, boostAvailable

		# run boost depending on which type doodle hit (spring or jetpack)
		lw $t4, boostType
		beq $t4, 0, springBoost
		beq $t4, 1, jetBoost

		springBoost:
			# spring lasts for 7 scrolls
			li $t4, 7
			j addFuel
		jetBoost:
			# jetpack lasts for 22 scrolls
			li $t4, 22
		addFuel:
			sw $t4, boostFuel
		jr $ra
	
hitLevel: 
	la $t8, platforms
	
	# if block below is plat color (middle unit)
	lw $t5, 4160($t0)
	beq $t5, -6635559, resetFly
	
	# if block below is plat color (right unit)
	lw $t5, 4164($t0)
	beq $t5, -6635559, resetFly
	
	# if block below is plat color (left unit)
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

drawJetpack:
   		lw $t2, boostAvailable
   		beq $t2, 1, drawPlat
   		
   		li $t2, 1
   		sw $t2, boostAvailable
   		
   		lw $t2, 24($t1) 
   		sw $t2, -376($t5) 
   		sw $t2, -248($t5)
   		sw $t2, -120($t5)
   		sw $t2, -116($t5)
   		
   		lw $t2, 4($t1) 
   		sw $t2, -372($t5)
   		sw $t2, -368($t5)
   		sw $t2, -240($t5)
   		sw $t2, -112($t5)
   		
   		lw $t2, 12($t1) 
   		sw $t2, -244($t5)
   		
   		li $t2, 1 # 1 = jetpack
   		sw $t2, boostType
   		sw $t5, boostLocation
		j drawPlat

drawSpring:
   		lw $t2, boostAvailable
   		beq $t2, 1, drawPlat
   		
   		li $t2, 1
   		sw $t2, boostAvailable
   		
   		lw $t2, 12($t1) 
   		sw $t2, -376($t5) 
   		sw $t2, -248($t5)
   		sw $t2, -120($t5)
   		sw $t2, -116($t5)
   		sw $t2, -372($t5)
   		sw $t2, -240($t5)
   		sw $t2, -112($t5)

   		sw $t5, boostLocation
   		sw $zero, boostType # 0 = spring
   		j drawPlat

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
	
	lw $t0, displayAddress
	jr $ra
	
printScore:
	la $t1, colors	
	lw $t8, displayAddress
	
	# use div to get ones and tens digit
	li $t2, 10
	lw $t4, score
	div $t4, $t2
	mflo $t5
	mfhi $t6
	
	lw $t2, 28($t1)
	lw $t4, gameActive

	# score will be on right (in game), score will in middle (post game)
	beq $t4, 1, moveToRight
	j moveToMiddle

	moveToRight:
		li $t7, 3296
		j drawTens
	moveToMiddle:
		li $t7, 3248
		
	# draw the tens value of the score
	drawTens:
		add $t8, $t8, $t7
		
		# first clear the current digit 
		move $a1, $t8
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		jal clearScore
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		
		# a0 = 1 means to come back and draw ones digit after tens digit
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
		addi $t8, $t8, 16

		# a0 = 0 means to continue b/c both digits are done being drawn
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
		sw $t2, 0($t8)
		sw $t2, 4($t8)
		sw $t2, 8($t8)
		sw $t2, 128($t8)
		sw $t2, 136($t8)
		sw $t2, 256($t8)
		sw $t2, 264($t8)
		sw $t2, 384($t8)
		sw $t2, 392($t8)
		sw $t2, 512($t8)
		sw $t2, 516($t8)
		sw $t2, 520($t8)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawOne:
		sw $t2, 0($t8)
		sw $t2, 4($t8)
		sw $t2, 132($t8)
		sw $t2, 260($t8)
		sw $t2, 388($t8)
		sw $t2, 516($t8)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawTwo:
		sw $t2, 0($t8)
		sw $t2, 4($t8)
		sw $t2, 8($t8)
		sw $t2, 136($t8)
		sw $t2, 256($t8)
		sw $t2, 260($t8)
		sw $t2, 264($t8)
		sw $t2, 384($t8)
		sw $t2, 512($t8)
		sw $t2, 516($t8)
		sw $t2, 520($t8)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawThree:
		sw $t2, 0($t8)
		sw $t2, 4($t8)
		sw $t2, 8($t8)
		sw $t2, 136($t8)
		sw $t2, 256($t8)
		sw $t2, 260($t8)
		sw $t2, 264($t8)
		sw $t2, 392($t8)
		sw $t2, 512($t8)
		sw $t2, 516($t8)
		sw $t2, 520($t8)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawFour:
		sw $t2, 0($t8)
		sw $t2, 8($t8)
		sw $t2, 128($t8)
		sw $t2, 136($t8)
		sw $t2, 256($t8)
		sw $t2, 260($t8)
		sw $t2, 264($t8)
		sw $t2, 392($t8)
		sw $t2, 520($t8)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawFive:
		sw $t2, 0($t8)
		sw $t2, 4($t8)
		sw $t2, 8($t8)
		sw $t2, 128($t8)
		sw $t2, 256($t8)
		sw $t2, 260($t8)
		sw $t2, 264($t8)
		sw $t2, 392($t8)
		sw $t2, 512($t8)
		sw $t2, 516($t8)
		sw $t2, 520($t8)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawSix:
		sw $t2, 0($t8)
		sw $t2, 4($t8)
		sw $t2, 8($t8)
		sw $t2, 128($t8)
		sw $t2, 256($t8)
		sw $t2, 260($t8)
		sw $t2, 264($t8)
		sw $t2, 384($t8)
		sw $t2, 392($t8)
		sw $t2, 512($t8)
		sw $t2, 516($t8)
		sw $t2, 520($t8)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawSeven:
		sw $t2, 0($t8)
		sw $t2, 4($t8)
		sw $t2, 8($t8)
		sw $t2, 128($t8)
		sw $t2, 136($t8)
		sw $t2, 264($t8)
		sw $t2, 392($t8)
		sw $t2, 520($t8)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawEight:
		sw $t2, 0($t8)
		sw $t2, 4($t8)
		sw $t2, 8($t8)
		sw $t2, 128($t8)
		sw $t2, 136($t8)
		sw $t2, 256($t8)
		sw $t2, 260($t8)
		sw $t2, 264($t8)
		sw $t2, 384($t8)
		sw $t2, 392($t8)
		sw $t2, 512($t8)
		sw $t2, 516($t8)
		sw $t2, 520($t8)
		beq $a0, 1, drawOnes
		beq $a0, 0, end	
	drawNine:
		sw $t2, 0($t8)
		sw $t2, 4($t8)
		sw $t2, 8($t8)
		sw $t2, 128($t8)
		sw $t2, 136($t8)
		sw $t2, 256($t8)
		sw $t2, 260($t8)
		sw $t2, 264($t8)
		sw $t2, 392($t8)
		sw $t2, 512($t8)
		sw $t2, 516($t8)
		sw $t2, 520($t8)
		beq $a0, 1, drawOnes
		beq $a0, 0, end		
	end: 
		lw $t8, displayAddress
		jr $ra

clearScore:
	la $t4, colors
	lw $t4, 0($t4)
	
	# clear tens digit
	sw $t4, 0($a1)
	sw $t4, 4($a1)
	sw $t4, 8($a1)
	sw $t4, 128($a1)
	sw $t4, 132($a1)
	sw $t4, 136($a1)
	sw $t4, 256($a1)
	sw $t4, 260($a1)
	sw $t4, 264($a1)
	sw $t4, 384($a1)
	sw $t4, 388($a1)
	sw $t4, 392($a1)
	sw $t4, 512($a1)
	sw $t4, 516($a1)
	sw $t4, 520($a1)
	
	# clear ones digit
	addi $a1, $a1, 16
	sw $t4, 0($a1)
	sw $t4, 4($a1)
	sw $t4, 8($a1)
	sw $t4, 128($a1)
	sw $t4, 132($a1)
	sw $t4, 136($a1)
	sw $t4, 256($a1)
	sw $t4, 260($a1)
	sw $t4, 264($a1)
	sw $t4, 384($a1)
	sw $t4, 388($a1)
	sw $t4, 392($a1)
	sw $t4, 512($a1)
	sw $t4, 516($a1)
	sw $t4, 520($a1)
	
	jr $ra
	
# quit game
Exit:
	li $v0, 10 
	syscall
	
		 
