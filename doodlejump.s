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
	displayAddress:	.word	0x10008000
	bgColor: 	.word 0xFF93CAF2
	ballColor: 	.word 0xFFE61A20
	levelColor: 	.word 0xFF49B616

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
	
	sw $t2, 1980($t0)
	sw $t2, 1984($t0)	
	sw $t2, 1852($t0) 
	sw $t2, 1856($t0) 
	
	WHILE: 
		lw $t4, 0xffff0004 
		beq $t4, 0x6A, moveLeft
		beq $t4, 0x6B, moveRight
		j WHILE

drawRandomLevel:

moveLeft:
	sw $t2, 1988($t0)
	sw $t2, 1992($t0)	
	sw $t2, 1860($t0) 
	sw $t2, 1864($t0)

moveRight:


Exit:
	li $v0, 10 
	syscall
	

