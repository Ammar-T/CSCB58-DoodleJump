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
	
	li $a0, 75
	li $a1, 200
	jal createLevel
	
	li $a0, 325
	li $a1, 150
	jal createLevel
	
	li $a0, 530
	li $a1, 150
	jal createLevel
	
	li $a0, 675
	li $a1, 250
	jal createLevel
		
	RUN: 
		# fly up
		li $a0, -128
		jal changeY
		
		# fly down
		# li $a0, 128
		# jal changeY
		
		lw $t8, 0xffff0000 
		beq $t8, 1, leftOrRight
		
		j RUN

changeY:	
	# paint old position black
	lw $t2, 0($t1)
	sw $t2, 4028($t0)
	sw $t2, 4040($t0)
	sw $t2, 4032($t0)
	sw $t2, 4036($t0)
	
   	add $t0, $t0, $a0
   	lw $t2, 4($t1)
	sw $t2, 4032($t0)
	sw $t2, 4036($t0)
	
	li $v0, 32
	li $a0, 225
	syscall

	jr $ra

createLevel:
	# set color to green
	lw $t2, 8($t1)

	move $t4, $a0
	move $t7, $a1
		
	# copy display address
	move $t5, $t0
	
	# generate random number
	li $v0, 42
	li $a0, 0
	move $a1, $t7
	syscall
	add $a0, $a0, $t4
	move $t6, $a0
	
	# make multiple of 4
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
	
clearScreen:
	addi $t6, $t6, 0
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
