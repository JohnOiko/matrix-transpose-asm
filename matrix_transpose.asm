.MODEL small
.STACK 100h


.DATA

matrix_dim equ 3 ; the dimension of the two-dimensional matrices

;---------------- matrix to be transposed ----------------
matrix           dd 3868F2EBh, F66C18ABh, 3A2D9BD0h        ; 0946402027 + 4134279339 + 0976067536 = 6056748902 | sum = 18888260387 (465D3FB23 in hex)
second_row       dd 6F0B5FAFh, C18479F2h, 30BAF549h        ; 1863016367 + 3246684658 + 0817558857 = 5927259882 | average = 2098695598.55555 (7D178DAE.8E38 in hex)
third_row        dd EB52A335h, 3963D7F7h, 76D009A7h        ; 3948061493 + 0962844663 + 1993345447 = 6904251603 | max = 4134279339 (F66C18ABh in hex) at [0, 1] with zero-indexing
;--------------------------------------------------------- 

;------------------- transposed matrix -------------------
matrix_tr        dd ?, ?, ?
second_row_tr    dd ?, ?, ?
third_row_tr     dd ?, ?, ?
;---------------------------------------------------------
                          
;------------------ matrix color combos ------------------                                                
matrix_cl        db 03Eh, 047h, 0E4h                       ; cyan background - yellow foreground,         red background - light gray foreground,    yellow background - red foreground
second_row_cl    db 05Bh, 0CFh, 00Ah                       ; magenta background - light cyan foreground,  light red background - white foreground,   black background - light green foreground
third_row_cl     db 0FDh, 0A0h, 09Ch                       ; white background - light magenta foreground, light green background - black foreground, light blue background - light red foreground
;---------------------------------------------------------                                                                                           
                                 
i dw ?
j dw ?
row_jump dw ?
prev_ip_1 dw 0

row_print_index dw 0
col_print_index dw 0
print_gap dw 0

sum_carry dw 0
sum dd 0

dividend db ?
divisor dw 9

result_int db ?, ?, ?, ?, ?, ?
result_fl db ?, ?

max_value dd 0
matrix_max_row_index db 0
matrix_max_column_index db 0

transpose_max_row_index db 0
transpose_max_column_index db 0

average_msg db "The average value is: ", "$"
max_matrix_msg db "The matrix's max value is at (0-indexing): ", "$"
max_transpose_msg db "The transposed matrix's max value is at (0-indexing): ", "$"
new_line DB 0AH,0DH,"$"


.CODE
.STARTUP

call calculate_row_jump ; call the procedure that calculates the row jump
call calculate_average ; call the procedure that calculates the average of the matrix
call calculate_matrix_max_indexes ; call the procedure that calculates the indexes of the matrix's max element
call calculate_transpose ; call the procedure that calculates the transpose matrix of the matrix
call calculate_transpose_max_indexes ; call the procedure that calculates the indexes of the transposed matrix's max element

call print_average ; call the procedure that prints the average of the matrix
call print_max_value_indexes ; call the procedure that prints the indexes of the matrix's max element 
call print_matrix ; call the procedure that prints the matrix  
call print_transpose ; call the procedure that prints the transpose matrix of the matrix
 
.EXIT


calculate_row_jump proc ; procedure that calculates the row jump number and saves it in row_jump
    mov ax, matrix_dim ; matrix dimensions for the number of elements in a row of the matrix
    mov cx, 4 ; 4 for the number of bytes in an element of the matrix which is a double word comprised of 4 bytes
    mul cx ; the row jump is the number of bytes the row index i needs to jump to skip a whole row in the matrix (4 * matrix dimension)
    mov row_jump, ax ; save the row jump to the corresponding variable
    ret  
calculate_row_jump endp


calculate_average proc ; procedure that calcuates the average value of the matrix and places its integer part in result_int and its decimal part in result_fl
    mov i, 0 ; initialize the row index i to 0     
    mov cx, matrix_dim ; counter for the outer row loop 
    loop_rows_avg: ; outer row loop that iterates through the rows of the matrix 
        mov ax, i ; save the row index i to ax
        mov dx, row_jump
        mul dx ; multiply the row index i saved in ax with the row jump (4 * matrix dimension) so that the row index i skips a whole row (matrix dimension number of double words/4 bytes)        
        mov si, ax ; save the final row index i to si
                              
        mov j, 0 ; initialize the column index j to 0
        push cx ; push the counter of the outer row loop to the stack since a counter will be needed for the inner column loop
        mov cx, matrix_dim ; counter for the inner column loop 
        loop_columns_avg: ; inner column loop that iterates through the columns of the matrix            
            push cx ; push the counter of the inner column loop to the stack since the cx register will be needed next
            
            mov ax, j ; save the column index j to ax
            mov dx, 4
            mul dx ; multiply the column index j saved in ax with 4 because each element of the matrix is a double word (4 bytes)
            mov bx, ax ; save the final column index j to bx
            
            push matrix[si][bx]+2 ; pass the 4 highest hex digits of the current element as parameters to the procedure that adds the current element's value to the matrix's sum of values 
            push matrix[si][bx] ; pass the 4 lowest hex digits of the current element as parameters to the procedure that adds the current element's value to the matrix's sum of values
            call add_to_sum ; call the procedure that adds the current element's value to the matrix's sum of values     
            
            inc j ; increment the column index j           
            pop cx ; pop the inner column loop counter which was pushed to the stack earlier
            loop loop_columns_avg ; repeat the process until the counter is 0, which means all matrix_dim columns have been iterated over
        inc i ; increment the row index i    
        pop cx ; pop the outer row loop counter which was pushed to the stack earlier
        loop loop_rows_avg ; repeat the process until the counter is 0, which means all matrix_dim rows have been iterated over
    
    push sum
    push sum+2    
    push sum_carry ; pass the matrix's sum of values (sum_carry and sum) as parameter to the procedure that divides it by divisor to get the average  
        
    call divide_hex_num ; call the procedure that divides the given number by divisor (in this case it gives the average value of the matrix)
           
    ret    
calculate_average endp


calculate_matrix_max_indexes proc ; procedure that calculates the indexes of the matrix's max value and places the row index in matrix_max_row_index and the column index in matrix_max_column_index 
    mov i, 0 ; initialize the row index i to 0
    mov max_value, 0 ; initialize the max value to 0
    mov cx, matrix_dim ; counter for the outer row loop 
    loop_rows_matrix_max: ; outer row loop that iterates through the rows of the matrix
        mov ax, i ; save the row index i to ax
        mov dx, row_jump
        mul dx ; multiply the row index i saved in ax with the row jump (4 * matrix dimension) so that the row index i skips a whole row (matrix dimension number of double words/4 bytes)        
        mov si, ax ; save the final row index i to si
    
        mov j, 0 ; initialize the column index j to 0            
        push cx ; push the counter of the outer row loop to the stack since a counter will be needed for the inner column loop
        mov cx, matrix_dim ; counter for the inner column loop
        loop_columns_matrix_max: ; inner column loop that iterates through the columns of the matrix
            push cx ; push the counter of the inner column loop to the stack since the cx register will be needed next
            
            mov ax, j ; save the column index j to ax
            mov dx, 4
            mul dx ; multiply the column index j saved in ax with 4 because each element of the matrix is a double word (4 bytes)
            mov bx, ax ; save the final column index j to bx                          
            
            mov ax, matrix[si][bx]+2 ; save the 4 highest hex digits of the current element to ax
            mov dx, max_value+2 ; save the 4 highest hex digits of the current max value to dx
            cmp dx, ax ; if the 4 highest hex digits of the current max value are less than the 4 highest hex digits of the current element, then this element is the new max, else if they are greater continue to the next element, else compare their 4 lowest hex digits
            jb save_matrix_max ; save the current element as the new max as well as its indexes
            ja exit_matrix_max_comparison ; continue to the next element
            
            mov ax, matrix[si][bx] ; save the 4 lowest hex digits of the current element to ax
            mov dx, max_value ; save the 4 lowest hex digits of the current max value to dx      
            cmp dx, ax ; if the 4 lowest hex digits of the current max value are less than the 4 lowest hex digits of the current element, then this element is the new max, else if they are equal or greater continue to the next element
            jb save_matrix_max ; save the current element as the new max as well as its indexes   
            jae exit_matrix_max_comparison ; continue to the next element
            
            save_matrix_max:
                mov ax, matrix[si][bx] ; save the 4 lowest hex digits of the current element to ax 
                mov dx, matrix[si][bx]+2 ; save the 4 highest hex digits of the current element to dx             
                mov max_value, ax ; save the 4 lowest hex digits of the current element as the new 4 lowest hex digits of the max
                mov max_value+2, dx ; save the 4 highest hex digits of the current element as the new 4 highest hex digits of the max
                mov ax, i ; save the row index i of the current element and new max to ax
                mov dx, j ; save the column index j of the current element and new max to dx
                mov matrix_max_row_index, al ; save the row index i of the current element and new max as the row index of the max element
                mov matrix_max_column_index, dl ; save the column index j of the current element and new max as the column index of the max element
            
            exit_matrix_max_comparison:                     
            inc j ; increment the column index j           
            pop cx ; pop the inner column loop counter which was pushed to the stack earlier
            loop loop_columns_matrix_max ; repeat the process until the counter is 0, which means all matrix_dim columns have been iterated over
        inc i ; increment the row index i    
        pop cx ; pop the outer row loop counter which was pushed to the stack earlier
        loop loop_rows_matrix_max ; repeat the process until the counter is 0, which means all matrix_dim rows have been iterated over          
    ret
calculate_matrix_max_indexes endp


calculate_transpose proc
    mov i, 0 ; initialize the row index i to 0     
    mov cx, matrix_dim ; counter for the outer row loop 
    loop_rows_transpose: ; outer row loop that iterates through the rows of the matrix                          
        mov j, 0 ; initialize the column index j to 0
        push cx ; push the counter of the outer row loop to the stack since a counter will be needed for the inner column loop
        mov cx, matrix_dim ; counter for the inner column loop 
        loop_columns_transpose: ; inner column loop that iterates through the columns of the matrix            
            push cx ; push the counter of the inner column loop to the stack since the cx register will be needed next            
            
            mov ax, i ; save the row index i to ax
            mov dx, row_jump
            mul dx ; multiply the row index i saved in ax with the row jump (4 * matrix dimension) so that the row index i skips a whole row (matrix dimension number of double words/4 bytes)        
            mov si, ax ; save the final row index i to si
            
            mov ax, j ; save the column index j to ax
            mov dx, 4
            mul dx ; multiply the column index j saved in ax with 4 because each element of the matrix is a double word (4 bytes)
            mov bx, ax ; save the final column index j to bx
            
            mov ax, matrix[si][bx] ; save the 4 lowest hex digits of the current element to ax
            mov dx, matrix[si][bx]+2 ; save the 4 highest hex digits of the current element to dx  
             
            push dx ; push the 4 highest hex digits of the current element to the stack since dx is needed next
            push ax ; push the 4 lowest hex digits of the current element to the stack since ax is needed next        
         
            mov ax, j ; save the column index j to ax
            mov dx, row_jump
            mul dx ; multiply the column index j saved in ax with the row jump (4 * matrix dimension) so that the column index j skips a whole row (matrix dimension number of double words/4 bytes) of the transposed matrix        
            mov bx, ax ; save the final column index j to bx
            
            mov ax, i ; save the row index i to ax
            mov dx, 4
            mul dx ; multiply the row index i saved in ax with 4 because each element of the transposed matrix is a double word (4 bytes)
            mov si, ax ; save the final row index i to si
            
            pop ax ; pop the 4 lowest hex digits of the current element which were pushed to the stack earlier
            pop dx ; pop the 4 highest hex digits of the current element which were pushed to the stack earlier
            
            mov matrix_tr[bx][si], ax ; replace the transposed matrix's 4 lowest hex digits of  the element [j, i] with the 4 lowest hex digits of the matrix's [i, j] element
            mov matrix_tr[bx][si]+2, dx ; replace the transposed matrix's 4 highest hex digits of the element [j, i] with the 4 highest hex digits of the matrix's [i, j] element
                            
            inc j ; increment the column index j           
            pop cx ; pop the inner column loop counter which was pushed to the stack earlier
            loop loop_columns_transpose ; repeat the process until the counter is 0, which means all matrix_dim columns have been iterated over
        inc i ; increment the row index i    
        pop cx ; pop the outer row loop counter which was pushed to the stack earlier
        loop loop_rows_transpose ; repeat the process until the counter is 0, which means all matrix_dim rows have been iterated over
    ret    
calculate_transpose endp


calculate_transpose_max_indexes proc ; procedure that calculates the indexes of the transposed matrix's max value and places the row index in transpose_max_row_index and the column index in transpose_max_column_index 
    mov i, 0 ; initialize the row index i to 0
    mov max_value, 0 ; initialize the max value to 0
    mov cx, matrix_dim ; counter for the outer row loop 
    loop_rows_transpose_max: ; outer row loop that iterates through the rows of the transposed matrix
        mov ax, i ; save the row index i to ax
        mov dx, row_jump
        mul dx ; multiply the row index i saved in ax with the row jump (4 * matrix dimension) so that the row index i skips a whole row (matrix dimension number of double words/4 bytes)        
        mov si, ax ; save the final row index i to si
    
        mov j, 0 ; initialize the column index j to 0            
        push cx ; push the counter of the outer row loop to the stack since a counter will be needed for the inner column loop
        mov cx, matrix_dim ; counter for the inner column loop
        loop_columns_transpose_max: ; inner column loop that iterates through the columns of the transposed matrix
            push cx ; push the counter of the inner column loop to the stack since the cx register will be needed next
            
            mov ax, j ; save the column index j to ax
            mov dx, 4
            mul dx ; multiply the column index j saved in ax with 4 because each element of the matrix is a double word (4 bytes)
            mov bx, ax ; save the final column index j to bx                          
            
            mov ax, matrix_tr[si][bx]+2 ; save the 4 highest hex digits of the current element to ax
            mov dx, max_value+2 ; save the 4 highest hex digits of the current max value to dx
            cmp dx, ax ; if the 4 highest hex digits of the current max value are less than the 4 highest hex digits of the current element, then this element is the new max, else if they are greater continue to the next element, else compare their 4 lowest hex digits
            jb save_transpose_max ; save the current element as the new max as well as its indexes
            ja exit_transpose_max_comparison ; continue to the next element
            
            mov ax, matrix_tr[si][bx] ; save the 4 lowest hex digits of the current element to ax
            mov dx, max_value ; save the 4 lowest hex digits of the current max value to dx      
            cmp dx, ax ; if the 4 lowest hex digits of the current max value are less than the 4 lowest hex digits of the current element, then this element is the new max, else if they are equal or greater continue to the next element
            jb save_transpose_max ; save the current element as the new max as well as its indexes   
            jae exit_transpose_max_comparison ; continue to the next element
            
            save_transpose_max:
                mov ax, matrix_tr[si][bx] ; save the 4 lowest hex digits of the current element to ax 
                mov dx, matrix_tr[si][bx]+2 ; save the 4 highest hex digits of the current element to dx             
                mov max_value, ax ; save the 4 lowest hex digits of the current element as the new 4 lowest hex digits of the max
                mov max_value+2, dx ; save the 4 highest hex digits of the current element as the new 4 highest hex digits of the max
                mov ax, i ; save the row index i of the current element and new max to ax
                mov dx, j ; save the column index j of the current element and new max to dx
                mov transpose_max_row_index, al ; save the row index i of the current element and new max as the row index of the max element
                mov transpose_max_column_index, dl ; save the column index j of the current element and new max as the column index of the max element
            
            exit_transpose_max_comparison:                     
            inc j ; increment the column index j           
            pop cx ; pop the inner column loop counter which was pushed to the stack earlier
            loop loop_columns_transpose_max ; repeat the process until the counter is 0, which means all matrix_dim columns have been iterated over
        inc i ; increment the row index i    
        pop cx ; pop the outer row loop counter which was pushed to the stack earlier
        loop loop_rows_transpose_max ; repeat the process until the counter is 0, which means all matrix_dim rows have been iterated over          
    ret
calculate_transpose_max_indexes endp


print_average proc ; procedure that prints the average value of the matrix    
    lea dx, average_msg ; save the effective address of the string with the applicable message for printing the average of the matrix
    mov ah, 9 ; move the value that prints a string to ah
    int 21h ; call the interrupt that prints the string saved in dx     
    call print_new_line ; call the procedure that prints a new line
    call print_new_line ; call the procedure that prints a new line
    
    xor cx, cx ; set cx to 0
    mov cl, matrix_cl ; move the color code of the matrix's first cell to cx
    push cx ; push the color code of the matrix's first cell to the stack to restore it after changing it next
    mov matrix_cl, 07h ; set the color code of the matrix's first cell to the default color combination (black background, light gray foreground)
    
    mov print_gap, 26 ; set the gap so that the fifth digit of the average's integer part is printed at the 23rd spot (26 - 4 = 22 gap because the digits are printed in groups of 4 hex digits)
    push 0 
    push 0 ; pass two zeros as parameters to the procedure that prints the hex digits 5-8 of the average's integer part so that it colors them the way the cell at [0, 0] of the matrix is to be colored (set in the matrix_cl matrix and changed in the previous line)
    mov dh, result_int+2 ; save the hex digits 5-6 of the average's integer part to dh, counting from digit 1 and moving to the lowest digits (the digits 1-4 are not printed because they are always 0 as the average of double words is a double word (8 hex digits) as well) 
    mov dl, result_int+3 ; save the hex digits 7-8 of the average's integer part to dl, counting from digit 1 and moving to the lowest digits
    push dx ; pass the hex digits 5-8 of the average's integer part as parameters to the procedure that prints them
    call print_hex_digits ; call the procedure that prints the hex digits 5-8 of the  average's integer part
    
    mov print_gap, 30 ; set the gap so that the ninth digit of the average's integer part is printed at the 27th spot (30 - 4 = 26 gap because the digits are printed in groups of 4 hex digits)
    push 0
    push 0 ; pass two zeros as parameters to the procedure that prints the hex digits 9-12 of the average's integer part so that it colors them the way the cell at [0, 0] of the matrix is to be colored (set in the matrix_cl matrix and changed previously)
    mov dh, result_int+4 ; save the hex digits 9-10 of the average's integer part to dh, counting from digit 1 and moving to the lowest digits
    mov dl, result_int+5 ; save the hex digits 11-12 of the average's integer part to dl, counting from digit 1 and moving to the lowest digits
    push dx ; pass the hex digits 9-12 of the average's integer part as parameters to the procedure that prints them      
    call print_hex_digits ; call the procedure that prints the hex digits 9-12 of the average's integer part
    
    push ds ; push the ds register's value to the stack to restore it after changing it next
    mov ax, 0B800h ; save the video memory's starting address to ax
    mov ds, ax ; save the video memory's starting address to ds

    mov ch, 07h ; set the color code of the character that will be printed to the default color combination (black background, light gray foreground)
    mov cl, "," ; set cl to the ascii code of ","
    mov [60], cx ; print "," right after the integer part of the average 
    pop ds ; pop the ds register's value which was pushed to the stack earlier
    
    mov print_gap, 35 ; set the gap so that the first digit of the average's floating point part is printed right after the "," at the 32nd spot (35 - 4 = 31 gap because the digits are printed in groups of 4 hex digits)
    push 0
    push 0 ; pass two zeros as parameters to the procedure that prints the hex digits 1-4 digits of the average's floating point part so that it colors them the way the cell at [0, 0] of the matrix is to be colored (set in the matrix_cl matrix and changed previously)
    mov dh, result_fl ; save the hex digits 1-2 of the average's floating point part to dh, counting from digit 1 and moving to the lowest digits
    mov dl, result_fl+1 ; save the hex digits 3-4 of the average's floating point part to dl, counting from digit 1 and moving to the lowest digits
    push dx ; pass the hex digits 1-4 of the average's floating point part as parameters to the procedure that prints them    
    call print_hex_digits ; call the procedure that prints the hex digits 1-4 of the average's floating point part
    
    pop cx ; pop the color code of the matrix's first cell which was pushed to the stack earlier    
    mov matrix_cl, cl ; restore the color code of the matrix's first cell which was changed previously
    
    ret
print_average endp


print_max_value_indexes proc ; procedure that prints the row and column indexes of the matrix's max value
    lea dx, max_matrix_msg ; save the effective address of the string with the applicable message for printing the indexes of the matrix's max value
    mov ah, 9 ; move the value that prints a string to ah
    int 21h ; call the interrupt that prints the string saved in dx
    call print_new_line ; call the procedure that prints a new line
    call print_new_line ; call the procedure that prints a new line
    
    mov dh, matrix_max_row_index ; save the row index of the matrix's max value to dh
    mov dl, matrix_max_column_index ; save the column index of the matrix's max value to dl
    add dh, 30h
    add dl, 30h ; add 48 (30h in hex) to dh and dl to get the ascii value that corresponds to the saved indexes
    
    push ds ; push the ds register's value to the stack to restore it after changing it next
    mov ax, 0B800h ; save the video memory's starting address to ax
    mov ds, ax ; save the video memory's starting address to ds        
    
    mov ch, 07h ; set the color code of the characters that will be printed to the default color combination (black background, light gray foreground)    
    mov cl, "(" ; set cl to the ascii code of "("
    mov [406], cx ; print "(" right after a gap that follows the applicable message for printing the indexes of the matrix's max value
    mov cl, dh ; set cl to the ascii code of the row index of the matrix's max value 
    mov [408], cx ; print the row index of the matrix's max value right after "(" 
    mov cl, "," ; set cl to the ascii code of ","
    mov [410], cx ; print "," right after the row index of the matrix's max value
    mov cl, dl ; set cl to the ascii code of the column index of the matrix's max value   
    mov [412], cx ; print the column index of the matrix's max value right after "," 
    mov cl, ")" ; set cl to the ascii code of ")"
    mov [414], cx ; print ")" right after the column index of the matrix's max value   
    pop ds ; pop the ds register's value which was pushed to the stack earlier
    
    lea dx, max_transpose_msg ; save the effective address of the string with the applicable message for printing the indexes of the transposed matrix's max value
    mov ah, 9 ; move the value that prints a string to ah
    int 21h ; call the interrupt that prints the string saved in dx
    
    mov dh, transpose_max_row_index ; save the row index of the transposed matrix's max value to dh
    mov dl, transpose_max_column_index ; save the column index of the transposed matrix's max value to dl
    add dh, 30h
    add dl, 30h ; add 48 (30h in hex) to dh and dl to get the ascii value that corresponds to the saved indexes
    
    push ds ; push the ds register's value to the stack to restore it after changing it next
    mov ax, 0B800h ; save the video memory's starting address to ax
    mov ds, ax ; save the video memory's starting address to ds        
    
    mov ch, 07h ; set the color code of the characters that will be printed to the default color combination (black background, light gray foreground)    
    mov cl, "(" ; set cl to the ascii code of "("
    mov [748], cx ; print "(" right after a gap that follows the applicable message for printing the indexes of the transposed matrix's max value
    mov cl, dh ; set cl to the ascii code of the row index of the transposed matrix's max value    
    mov [750], cx ; print the row index of the transposed matrix's max value right after "("
    mov cl, "," ; set cl to the ascii code of ","
    mov [752], cx ; print "," right after the row index of the transposed matrix's max value
    mov cl, dl ; set cl to the ascii code of the column index of the transposed matrix's max value   
    mov [754], cx ; print the column index of the transposed matrix's max value right after "," 
    mov cl, ")" ; set cl to the ascii code of ")"
    mov [756], cx ; print ")" right after the column index of the transposed matrix's max value     
    pop ds ; pop the ds register's value which was pushed to the stack earlier
    
    ret    
print_max_value_indexes endp


print_matrix proc ; procedure that prints the matrix 
    push ds ; push the ds register's value to the stack to restore it after changing it next
    mov ax, 0B800h ; save the video memory's starting address to ax
    mov ds, ax ; save the video memory's starting address to ds
    
    mov ch, 07h ; set the color code of the characters that will be printed to the default color combination (light gray foreground, black background)
    mov cl, 'A' ; set cl to the ascii code of "A"
    mov [960], cx ; print "A" right at the start of the 7th line
    mov cl, '=' ; set cl to the ascii code of "="
    mov [962], cx ; print "=" right after "A"  
    pop ds ; pop the ds register's value which was pushed to the stack earlier
    
    mov i, 0 ; initialize the row index i to 0
    mov cx, matrix_dim ; counter for the outer row loop 
    loop_rows_matrix_print: ; outer row loop that iterates through the rows of the matrix   
        mov ax, i ; save the row index i to ax
        mov dx, row_jump
        mul dx ; multiply the row index i saved in ax with the row jump (4 * matrix dimension) so that the row index i skips a whole row (matrix dimension number of double words/4 bytes)        
        mov si, ax ; save the final row index i to si
        
        mov ax, i ; save the row index i to ax
        mov row_print_index, 160 ; save 160 in row_print_index so that it leaves 1 empty line between rows
        mul row_print_index ; multiply the row index i with the row_print_index so that it prints the row in the correct line 
        add ax, 649 ; add 649 to the previous i * row_print_index so that every line starts after the correct number or lines
        mov row_print_index, ax ; save the final row_print_index = i * row_print_index + 649
                              
        mov j, 0 ; initialize the column index j to 0
        push cx ; push the counter of the outer row loop to the stack since a counter will be needed for the inner column loop
        mov cx, matrix_dim ; counter for the inner column loop 
        loop_columns_matrix_print: ; inner column loop that iterates through the columns of the matrix 
            push cx ; push the counter of the inner column loop to the stack since the cx register will be needed next
            push si ; push the final row index si to the stack since the si register will be needed next
            
            mov ax, j ; load the column index j to ax
            mov dx, 4
            mul dx ; multiply the column index j saved in ax with 4 because each element of the matrix is a double word (4 bytes)
            mov bx, ax ; save the final column index j to bx 
            
            mov ax, j ; save the column index j to ax
            mov col_print_index, 9 ; save 9 in col_print_index so that it leaves 1 space between elements (9-8 hex digits -> 1 empty space)
            mul col_print_index ; multiply the column index j with the col_print_index so that it prints the element in the correct column
            mov col_print_index, ax ; save the final col_print_index = j * col_print_index                                                
            
            mov cx, matrix[si][bx] ; save the 4 lowest hex digits of the current element to cx
            mov bx, matrix[si][bx]+2 ; save the 4 highest hex digits of the current element to bx      
            
            push cx ; push the 4 lowest hex digits of the current element since the cx register will be needed next
            mov ax, i ; save the row index i to ax
            mov dx, matrix_dim 
            mul dx ; multiply the row index i saved in ax with the matrix dimension (ax = i * matrix_dim)
            
            mov print_gap, 0 ; set the gap so that the first digit of the 4 highest hex digits of the current element is printed at the 1st spot
            push j ; pass the column index j as parameter to the procedure that prints the 4 highest hex digits of the current element
            push ax ; pass the row index i multiplied by the matrix dimension saved in ax as parameter to the procedure that prints the 4 highest hex digits of the current element
            push bx ; pass the 4 highest hex digits of the current element as parameter to the procedure that prints them
            call print_hex_digits ; call the procedure that prints the 4 highest hex digits of the current element    
            
            pop cx ; pop the 4 lowest hex digits of the current element which were pushed to the stack earlier
            mov ax, i ; save the row index i to ax
            mov dx, matrix_dim
            mul dx ; multiply the row index i saved in ax with the matrix dimension (ax = i * matrix_dim)
            
            mov print_gap, 4 ; set the gap so that the first digit of the 4 lowest hex digits of the current element is printed at the 5th spot
            push j ; pass the column index j as parameter to the procedure that prints the 4 lowest hex digits of the current element 
            push ax ; pass the row index i multiplied by the matrix dimension saved in ax as parameter to the procedure that prints the 4 lowest hex digits of the current element
            push cx ; pass the 4 lowest hex digits of the current element as parameter to the procedure that prints them
            call print_hex_digits ; call the procedure that prints the 4 lowest hex digits of the current element  
            
            inc j ; increment the column index j
            pop si ; pop the final row index si which was pushed to the stack earlier                
            pop cx ; pop the inner column loop counter which was pushed to the stack earlier
            loop loop_columns_matrix_print ; repeat the process until the counter is 0, which means all matrix_dim columns have been iterated over
        inc i ; increment the row index i 
        pop cx ; pop the outer row loop counter which was pushed to the stack earlier
        loop loop_rows_matrix_print ; repeat the process until the counter is 0, which means all matrix_dim row have been iterated over
    ret    
print_matrix endp


print_transpose proc ; procedure that prints the transposed matrix 
    push ds ; push the ds register's value to the stack to restore it after changing it next
    mov ax, 0B800h ; save the video memory's starting address to ax
    mov ds, ax ; save the video memory's starting address to ds
    
    mov ch, 07h ; set the color code of the characters that will be printed to the default color combination (light gray foreground, black background)
    mov cl, 'T' ; set cl to the ascii code of "T"
    mov [2240], cx ; print "T" right at the start of the 15th line
    mov cl, '=' ; set cl to the ascii code of "="
    mov [2242], cx ; print "=" right after "T"  
    pop ds ; pop the ds register's value which was pushed to the stack earlier
    
    mov i, 0 ; initialize the row index i to 0
    mov cx, matrix_dim ; counter for the outer row loop 
    loop_rows_transpose_print: ; outer row loop that iterates through the rows of the transposed matrix   
        mov ax, i ; save the row index i to ax
        mov dx, row_jump
        mul dx ; multiply the row index i saved in ax with the row jump (4 * matrix dimension) so that the row index i skips a whole row (matrix dimension number of double words/4 bytes)        
        mov si, ax ; save the final row index i to si
        
        mov ax, i ; save the row index i to ax
        mov row_print_index, 160 ; save 160 in row_print_index so that it leaves 1 empty line between rows
        mul row_print_index ; multiply the row index i with the row_print_index so that it prints the row in the correct line 
        add ax, 1289 ; add 1289 to the previous i * row_print_index so that every line starts after the correct number or lines
        mov row_print_index, ax ; save the final row_print_index = i * row_print_index + 1289
                              
        mov j, 0 ; initialize the column index j to 0
        push cx ; push the counter of the outer row loop to the stack since a counter will be needed for the inner column loop
        mov cx, matrix_dim ; counter for the inner column loop 
        loop_columns_transpose_print: ; inner column loop that iterates through the columns of the transposed matrix 
            push cx ; push the counter of the inner column loop to the stack since the cx register will be needed next
            push si ; push the final row index si to the stack since the si register will be needed next
            
            mov ax, j ; load the column index j to ax
            mov dx, 4
            mul dx ; multiply the column index j saved in ax with 4 because each element of the transposed matrix is a double word (4 bytes)
            mov bx, ax ; save the final column index j to bx 
            
            mov ax, j ; save the column index j to ax
            mov col_print_index, 9 ; save 9 in col_print_index so that it leaves 1 space between elements (9-8 hex digits -> 1 empty space)
            mul col_print_index ; multiply the column index j with the col_print_index so that it prints the element in the correct column
            mov col_print_index, ax ; save the final col_print_index = j * col_print_index                                                
            
            mov cx, matrix_tr[si][bx] ; save the 4 lowest hex digits of the current element to cx
            mov bx, matrix_tr[si][bx]+2 ; save the 4 highest hex digits of the current element to bx      
            
            push cx ; push the 4 lowest hex digits of the current element since the cx register will be needed next
            mov ax, i ; save the row index i to ax
            mov dx, matrix_dim 
            mul dx ; multiply the row index i saved in ax with the matrix dimension (ax = i * matrix_dim)
            
            mov print_gap, 0 ; set the gap so that the first digit of the 4 highest hex digits of the current element is printed at the 1st spot
            push j ; pass the column index j as parameter to the procedure that prints the 4 highest hex digits of the current element
            push ax ; pass the row index i multiplied by the matrix dimension saved in ax as parameter to the procedure that prints the 4 highest hex digits of the current element
            push bx ; pass the 4 highest hex digits of the current element as parameter to the procedure that prints them
            call print_hex_digits ; call the procedure that prints the 4 highest hex digits of the current element    
            
            pop cx ; pop the 4 lowest hex digits of the current element which were pushed to the stack earlier
            mov ax, i ; save the row index i to ax
            mov dx, matrix_dim
            mul dx ; multiply the row index i saved in ax with the matrix dimension (ax = i * matrix_dim)
            
            mov print_gap, 4 ; set the gap so that the first digit of the 4 lowest hex digits of the current element is printed at the 5th spot
            push j ; pass the column index j as parameter to the procedure that prints the 4 lowest hex digits of the current element 
            push ax ; pass the row index i multiplied by the matrix dimension saved in ax as parameter to the procedure that prints the 4 lowest hex digits of the current element
            push cx ; pass the 4 lowest hex digits of the current element as parameter to the procedure that prints them
            call print_hex_digits ; call the procedure that prints the 4 lowest hex digits of the current element  
            
            inc j ; increment the column index j
            pop si ; pop the final row index si which was pushed to the stack earlier                
            pop cx ; pop the inner column loop counter which was pushed to the stack earlier
            loop loop_columns_transpose_print ; repeat the process until the counter is 0, which means all matrix_dim columns have been iterated over
        inc i ; increment the row index i 
        pop cx ; pop the outer row loop counter which was pushed to the stack earlier
        loop loop_rows_transpose_print ; repeat the process until the counter is 0, which means all matrix_dim row have been iterated over
    ret    
print_transpose endp


add_to_sum proc ; procedure that adds a double word integer that is passed to it as parameter to the sum (sum_carry and sum)
    pop prev_ip_1 ; pop the previous ip register value that was pushed to the stack when the procedure was called to be able to get its parameters and then restore the ip register's value to the stack
    
    pop ax ; pop the 4 lowest hex digits of the double word integer that was passed as parameter 
    add sum, ax ; add the 4 lowest hex digits of the double word integer that was passed as parameter to the sum without taking into account the carry        
    pop ax ; pop the 4 highest hex digits of the double word integer that was passed as parameter
    adc sum+2, ax ; add the 4 highest hex digits of the double word integer that was passed as parameter to the sum with the carry that was produced by the previous addition of the 4 lowest hex digits    
    adc sum_carry, 0 ; add the carry produced by the previous addition of the 4 highest hex digits to the sum's carry part 
        
    push prev_ip_1 ; push the previous ip register value that was popped from the stack earlier back to the stack so that the control can return to where the procedure was called from
    ret      
add_to_sum endp


divide_hex_num proc ; procedure that divides the 48 bit integer by the divisor and places the integer part of the result in result_int and the floating part in result_fl
    pop prev_ip_1 ; pop the previous ip register value that was pushed to the stack when the procedure was called to be able to get its parameters and then restore the ip register's value to the stack
    
    ; this whole procedure calculates the division using long division by dividing the previous remainder and the next 2 hex digits by the divisor at each step 
    
    pop cx ; pop the 4 highest hex digits of the 48 bit integer that was passed as parameter
    mov ah, 0 ; set ah to 0
    mov al, ch ; save the 2 highest hex digits of the 48 bit integer that was passed as parameter to al                                                  
    div divisor ; divide the 2 highest hex digits by divisor
    mov result_int, al ; save the quotient in the 2 highest hex digits of the result's integer part
    
    mov dx, divisor
    mul dx ; multiply the quotient with the divisor (ax = quotient * divisor)
    sub ch, al ; subtract the quotient multiplied by the divisor from the 2 highest hex digits (ch = ch - quotient * divisor)
    
    mov ax, cx ; save the next dividend in ax, ah = previous 2 highest hex digits - quotient * divisor and al = next 2 highest hex digits                                               
    div divisor ; divide the digits previously saved in ax by divisor
    mov result_int+1, al ; save the quotient in the next 2 highest hex digits of the result's integer part (the quotient is always no more than 2 hex digits, thus is saved in al)
    
    mov dx, divisor
    mul dx ; multiply the quotient with the divisor (ax = quotient * divisor)
    sub cx, ax ; subtract the quotient multiplied by the divisor from the dividend (cx = cx - quotient * divisor)
    
    pop bx ; pop the next 4 highest hex digits of the 48 bit integer that was passed as parameter
    mov ch, cl ; save the result of the previous subtraction in ch (that result is always less than the divisor so it fits in cl and thus in ch) 
    mov cl, bh ; save the next 2 highest digits of the the 48 bit integer that was passed as parameter to cl
    
    mov ax, cx ; save the next dividend in ax, ah = previous 2 highest hex digits - quotient * divisor and al = next 2 highest hex digits                                                
    div divisor ; divide the digits previously saved in ax by divisor
    mov result_int+2, al ; save the quotient in the next 2 highest hex digits of the result's integer part (the quotient is always no more than 2 hex digits, thus is saved in al)
    
    mov dx, divisor
    mul dx ; multiply the quotient with the divisor (ax = quotient * divisor)
    sub cx, ax ; subtract the quotient multiplied by the divisor from the dividend (cx = cx - quotient * divisor)
    
    mov ch, cl ; save the result of the previous subtraction in ch (that result is always less than the divisor so it fits in cl and thus in ch)
    mov cl, bl ; save the next 2 highest digits of the the 48 bit integer that was passed as parameter to cl
    
    mov ax, cx ; save the next dividend in ax, ah = previous 2 highest hex digits - quotient * divisor and al = next 2 highest hex digits                                                
    div divisor ; divide the digits previously saved in ax by divisor
    mov result_int+3, al ; save the quotient in the next 2 highest hex digits of the result's integer part (the quotient is always no more than 2 hex digits, thus is saved in al)
    
    mov dx, divisor
    mul dx ; multiply the quotient with the divisor (ax = quotient * divisor)
    sub cx, ax ; subtract the quotient multiplied by the divisor from the dividend (cx = cx - quotient * divisor)
    
    pop bx ; pop the next 4 highest hex digits of the 48 bit integer that was passed as parameter
    mov ch, cl ; save the result of the previous subtraction in ch (that result is always less than the divisor so it fits in cl and thus in ch) 
    mov cl, bh ; save the next 2 highest digits of the the 48 bit integer that was passed as parameter to cl
    
    mov ax, cx ; save the next dividend in ax, ah = previous 2 highest hex digits - quotient * divisor and al = next 2 highest hex digits                                               
    div divisor ; divide the digits previously saved in ax by divisor
    mov result_int+4, al ; save the quotient in the next 2 highest hex digits of the result's integer part (the quotient is always no more than 2 hex digits, thus is saved in al)
    
    mov dx, divisor
    mul dx ; multiply the quotient with the divisor (ax = quotient * divisor)
    sub cx, ax ; subtract the quotient multiplied by the divisor from the dividend (cx = cx - quotient * divisor)
    
    mov ch, cl ; save the result of the previous subtraction in ch (that result is always less than the divisor so it fits in cl and thus in ch)
    mov cl, bl ; save the next 2 highest digits of the the 48 bit integer that was passed as parameter to cl
    
    mov ax, cx ; save the next dividend in ax, ah = previous 2 highest hex digits - quotient * divisor and al = next 2 highest hex digits
    xor dx, dx ; set dx to 0                                               
    div divisor ; divide the digits previously saved in ax by divisor
    mov result_int+5, al ; save the quotient in the next 2 highest hex digits of the result's integer part (the quotient is always no more than 2 hex digits, thus is saved in al)
    
    mov ch, dl ; save the remainder of the 48 bit integer's division by the divisor in ch (the remainder is always less than divisor so it fits in dl and thus in ch)
    mov cl, 0 ; set cl to 0
    
    mov ax, cx ; save the next dividend in ax, ah = previous remainder and al = 0
    xor dx, dx ; set dx to 0                                               
    div divisor ; divide the digits previously saved in ax by divisor
    mov result_fl, al ; save the quotient in the 2 highest hex digits of the result's floating point part
    
    mov ch, dl ; save the remainder of the remainder's division by the divisor in ch (the remainder is always less than divisor so it fits in dl and thus in ch)
    mov cl, 0 ; set cl to 0
    
    mov ax, cx ; save the next dividend in ax, ah = previous remainder and al = 0
    xor dx, dx ; set dx to 0                                               
    div divisor ; divide the digits previously saved in ax by divisor
    mov result_fl+1, al ; save the quotient in the next 2 highest hex digits of the result's floating point part
    
    push prev_ip_1 ; push the previous ip register value that was popped from the stack earlier back to the stack so that the control can return to where the procedure was called from
    ret  
divide_hex_num endp


print_hex_digits proc ; procedure that prints an integer with 4 hex digits passed to it as a parameter    
    pop prev_ip_1 ; pop the previous ip register value that was pushed to the stack when the procedure was called to be able to get its parameters and then restore the ip register's value to the stack
    
    pop ax ; pop the 4 hex digits that are to be printed and were passed as parameter
    pop si ; pop the final row index si that indicates which row of color combinations in the matrix_cl matrix should be used to print the digits with
    pop bx ; pop the final column index bx that indicates which column of color combinations in the matrix_cl matrix should be used to print the digits with

    mov cx, 4 ; counter for the loop
    save_digits: ; loop that pushes each hex digit of the 4 hex digit integer to the stack starting from the lowest digit              
        push cx ; push the counter of the loop to the stack since the cx register will be needed next
                    
        mov cx, 16 ; save the divisor to get the next lowest hex digit of the 4 hex digits which is 16 since it is using the hex system  
        xor dx, dx ; set the remainder of the division to 0, this will be the next lowest hex digit of the integer's 4 hex digits 
        div cx ; divide the 4 hex digit integer by 16 to get the next lowest hex digit in the remainder saved in dx
                    
        pop cx ; pop the loop counter which was pushed to the stack earlier           
        push dx ; push the next lowest hex digit of the integer's 4 hex digits to the stack
        loop save_digits ; repeat the process until the counter is 0, which means all 4 hex digits have been pushed to the stack
            
    mov cx, 4 ; counter for the loop                              
    retrieve_digits: ; loop that pops the integer's 4 hex digits from the stack and prints them to the video memory
        pop dx ; pop the next highest hex digit which was pushed to the stack in the save_digits loop (since a stack is being used, the first digits that are popped are the highest)
        cmp dl, 10 ; if the hex digit is less than 10 then convert it from decimal to ascii code, else convert it from hex to ascii code
        jl convert_dec_ascii ; if the hex digit is less than 10 then jump to label convert_dec_ascii to convert it from decimal to ascii code
        convert_hex_ascii: ; if the hex digit is equal to or greater than 10 then convert it from hex to ascii code
            add dl, 37h ; add 55 (37h in hex) to dl to get the ascii code that corresponds to the saved hex digit 
            jmp exit_convertion ; continue to label exit_convertion to skip to the next part of the procedure
        convert_dec_ascii: ; if the hex digit is less than 10 then convert it from decimal to ascii code
            add dl, 30h ; add 48 (30h in hex) to dl to get the ascii code that corresponds to the saved decimal/hex digit (since the digit is less than 10 it is the same in both systems)              
        exit_convertion:
            mov dh, matrix_cl[si][bx] ; set the color code of the characters that will be printed to the color code saved in the [si, bx] element of the matrix_cl matrix 
                    
        push bx ; push the final column index bx to the stack since the bx register will be needed next 
                    
        mov ax, row_print_index ; save the row print index to ax
        add ax, col_print_index ; add the column print index to the row print index                
        add ax, print_gap ; add the print gap to the row print index and the column print index                
        mov bx, ax ; save the index of the video memory where the lowest of the 4 hex digits will be printed which was calculated in the 3 previous instructions
        sub bx, cx ; save the index of the video memory where the curent hex digit will be printed, bx = bx - cx, where cx is the loop counter and bx was saved in the previous instruction
        
        mov ax, 2 ; save 2 in dx          
        push dx ; push the current hex digit to the stack since after the multiplication the dx register's value will be changed                               
        mul bx ; double the index of the video memory where the curent hex digit will be printed since each video memory position has one bit for the character being printed and one for the color                
        mov bx, ax ; save the final index of the video memory where the curent hex digit will be printed back to bx
        pop dx ; pop the current hex digit which was pushed to the stack earlier                 
                    
        push ds ; push the ds register's value to the stack to restore it after changing it next               
        mov ax, 0B800h ; save the video memory's starting address to ax
        mov ds, ax ; save the video memory's starting address to ds
        mov [bx], dx ; print the hex digit saved in dl to the bx position of the video memory with the colors saved in dh                                
        pop ds ; pop the ds register's value which was pushed to the stack earlier
                    
        pop bx ; pop the final column index bx which was pushed to the stack earlier                                                                      
        loop retrieve_digits ; repeat the process until the counter is 0, which means all 4 hex digits have been printed
    push prev_ip_1 ; push the previous ip register value that was popped from the stack earlier back to the stack so that the control can return to where the procedure was called from
    ret        
print_hex_digits endp


print_new_line proc ; procedure that prints a new line
    lea dx, new_line ; load the effective address of the string with the new line
    mov ah, 9 ; move the value that prints a string to ah
    int 21h ; call the interrupt that prints the string saved in dx
    ret
print_new_line endp

                           
END