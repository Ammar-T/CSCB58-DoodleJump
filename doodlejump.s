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
	
	j clearScreen	
	jal flyUp
	
	WHILE: 
		ble $t0, 268466816, flyDown
		jal flyUp
		
		lw $t8, 0xffff0000 
		beq $t8, 1, leftOrRight
		
		j WHILE

flyUp:	
	# paint old position black
	lw $t2, 0($t1)
	sw $t2, 4028($t0)
	sw $t2, 4040($t0)
	sw $t2, 4032($t0)
	sw $t2, 4036($t0)
	
   	addi $t0, $t0, -128
   	lw $t2, 4($t1)
	sw $t2, 4032($t0)
	sw $t2, 4036($t0)
	
	li $v0, 32
	li $a0, 225
	syscall

	jr $ra

flyDown:	
	# paint old position black
	lw $t2, 0($t1)
	sw $t2, 4028($t0)
	sw $t2, 4040($t0)
	sw $t2, 4032($t0)
	sw $t2, 4036($t0)
	
   	addi $t0, $t0, 128
   	lw $t2, 4($t1)
	sw $t2, 4032($t0)
	sw $t2, 4036($t0)
	
	li $v0, 32
	li $a0, 225
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

	
clearScreen:
	addi $t6, $t6, 0
	lw $t2, 0($t1)
	NotCleared:
		sw $t2, 0($t0)
		addi $t0, $t0, 4
		
		addi $t6, $t6, 1
		blt $t6, 1024, NotCleared
		lw $t0, displayAddress
		j WHILE
		 
Exit:
	li $v0, 10 
	syscall
	

