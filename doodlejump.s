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
	bgColor: 	.word 0xFF93CAF2
	ballColor: 	.word 0xFFE61A20
	levelColor: 	.word 0xFF49B616
	ballPos: 	.word 1980
	levelPos:	.word 600 1200 1400 1700 300

.globl main
.text

main:
	lw $t0, displayAddress	
	lw $t1, bgColor	
	lw $t2, ballColor	
	lw $t3, levelColor
	
	sw $t3, 600($t0)
	sw $t3, 604($t0)	
	sw $t3, 608($t0) 
	sw $t3, 612($t0)

	sw $t2, 3260($t0)
	sw $t2, 3264($t0)	
	sw $t2, 3132($t0) 
	sw $t2, 3136($t0)
	
	WHILE: 
		jal flyUp
		lw $t8, 0xffff0000 
		beq $t8, 1, leftOrRight
		j WHILE

flyUp:	
   	addi $t0, $t0, -128
	sw $t2, 2620($t0)
	sw $t2, 2624($t0)
	sw $t2, 2492($t0)
	sw $t2, 2496($t0)
	
	li $v0, 32
	li $a0, 400
	syscall

	jr $ra

leftOrRight:
	lw $t5, 0xffff0004 
	beq $t5, 0x6A, moveLeft
	beq $t5, 0x6B, moveRight
	j WHILE

moveLeft:
	addi $t0, $t0, -4
	j WHILE

moveRight:
	addi $t0, $t0, 4
	j WHILE

	
drawRandomLevel:

Exit:
	li $v0, 10 
	syscall
	

