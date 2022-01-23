; To do:
; Implement handling interrupts from system timer, keyboard and COM.
; Every 1 sec of time processor must print in a first line of screen
; and send to COM next symbol of string:
; "HELLO FROM BAUMAN MOSCOW STATE TECHNICAL UNIVERSITY!".
; In COM interrupt handler, symbol that was got back from COM must be printed to a second line.
; If 'a' was pressed, COM interrupts must be prohibited.
; If 's' was pressed, COM interrupts must be permitted.
; Program must be stopped when all symbols will be sent to COM.

.model tiny
assume cs:mycode
assume ds:mydata
assume ss:mystack

mydata segment
    mystr db "HELLO FROM BAUMAN MOSCOW STATE TECHNICAL UNIVERSITY!", 0
    rtc_old_offset dw 0     ; Default offset of the RTC interrupt vector
    rtc_old_segment dw 0    ; Default segment of the RTC interrupt vector
    keyb_old_offset dw 0    ; Default offset of the KEYBOARD interrupt vector
    keyb_old_segment dw 0   ; Default segment of the KEYBOARD interrupt vector
    com_old_offset dw 0     ; Default offset of the COM interrupt vector
    com_old_segment dw 0    ; Default segment of the COM interrupt vector
    rtc_counter dw 0        ; Counter to implement interrupt on each 18s tick
    pointer dw 0            ; Current pointer on symbol in mystr
    pointer2 dw 0           ; Pointer for second line (COM) of videobuffer
    endprog_flag db 0       ; If this flag = 1, we need to stop the program
mydata ends

mycode segment

; Initsializatsiya COM-porta
initialize:
    cli
    ; 1. Ustanovka skorosti peredachi
    mov dx, 2FBh
    in al, dx
    or al, 10000000b
    out dx, al

    mov dx, 2F8h
    mov al, 01100000b ; mladshii bait delitelya chastoty
    out dx, al
    inc dx
    mov al, 00000000b ; starshii bait delitelya chastoty
    out dx, al

    mov dx, 2FBh
    in al, dx
    and al, 01111111b
    out dx, al

    ; 2. Ustanovka formata asinhronnoy posylki
    mov dx, 2FBh
    mov al, 00011111b
    out dx, al

    ; 3. Vklyuchit diagnosticheskii rezhim i razreshit COM-portu
    ; vyrabatyvat zaprosy na preryvanie
    mov dx, 2FCh
    mov al, 00011000b
    out dx, al

    ; 4. Razreshit COM-portu formirovat zaprosy na preryvanie po priemu
    mov dx, 2F9h
    mov al, 00000010b 
    out dx, al

    ; 5. Razreshaem obrabotku preryvaniya v kontrollere preryvanii
    in al, 21h
    and al, 11110111b
    out 21h, al     
    
    sti
    ret

; Timer interrupt
rtc_handler:
    ; Prepare for handling
    sti
    push ax
    push bx
    push cx
    push dx

    ; Check if this tick is 18s
    mov si, offset rtc_counter
    mov cx, ds:[si]
    cmp cx, 18
    jnz rtc_handler_end ; If not, skip handling.
    
    ; HANDLING
    mov cx, 0 ; Counter Reset
    push cx   ; Needed, if we change CX in handling

    ; Handler
    mov ax, 0b800h
    mov es, ax ; VIDEOBUFFER —> ES

    ; Print symbol in 1st line of videobuffer, send symbol to COM
    cli
    
    mov si, ds:[pointer]
    mov al, ds:[si]
    
    cmp al, 0
    jz end_prog
    
    mov di, si
    shl di, 1
    mov es:[di], al
    mov dx, 2F8h
    out dx, al
    sti
    
    inc si
    mov ds:[pointer], si
    
    jmp exit
    
end_prog:
    mov si, offset endprog_flag
    mov byte ptr ds:[si], 1
    ;
    
exit:
    pop cx ;

rtc_handler_end:
    ; Increment tick counter and save
    inc cx
    mov si, offset rtc_counter
    mov ds:[si], cx
    
    ; Return previous context
    pop dx
    pop cx
    pop bx
    pop ax
    
    ; Notify PIC
    mov al, 20h
    out 20h, al
    iret
    
keyb_handler:
    ; Prepare for handling
    sti
    push ax
    push bx
    push cx
    push dx
    IN al, 60h  ; Read keyboard symbol in AL
    mov ch, 0   ; 
    mov cl, al  ; CX = AL
    
    ; Call system keyboard interrupt handler
    INT 90h
    cli
   
    ;CMP cl, 'a'
    CMP cl, 1eh ; If symbol = 'a' (1e is scan code)
    JZ com_proh ; COM interrupt prohibition
    
    ;CMP cl, 's'
    CMP cl, 1fh ; If symbol = 's' (1f is scan code)
    JZ com_perm ; COM interrupt permission

    JMP keyb_exit ; Exit without actions
    
    com_proh:
    in al, 21h
    or al, 08h
    out 21h, al
    JMP keyb_exit
    
    com_perm:
    in al, 21h
    and al, 0f7h
    out 21h, al
 
keyb_exit:
    ; Return previous context
    pop dx
    pop cx
    pop bx
    pop ax
    
    mov al, 20h
    out 20h, al
    iret

com_handler:
    sti
    push ax
    
    mov dx, 2F8h
    in al, dx
    mov si, ds:[pointer2]
    mov es:[si + 0A0h], al
    inc si
    inc si
    mov ds:[pointer2], si
    
    pop ax
    
    mov al, 20h
    out 20h, al
    iret
    
mystart:
    mov ax, mydata  ;
    mov ds, ax      ; DS is equal to an address of the data segment
    mov ax, 0       ; 
    mov es, ax      ; ES is equal to an address where the interrupt vectors table starts
    mov ax, mystack ; 
    mov ss, ax      ; SS is equal to an address of the stack segment
    mov sp, 0       ; Stack Pointer is 0

    call initialize ; call COM initialize procedure

    ; Save old vector (offset and segment)
    mov ax, es:[1Ch*4]              ;
    mov si, offset rtc_old_offset          ;
    mov ds:[si], ax                 ; Saves old timer interrupt vector offset
    
    mov bx, es:[1Ch*4+2]            ;
    mov si, offset rtc_old_segment         ;
    mov ds:[si], bx                 ; Saves old timer interrupt vector segment
    
    mov ax, es:[09h*4]              ;
    mov si, offset keyb_old_offset         ;
    mov ds:[si], ax                 ; Saves old keyboard interrupt vector offset
    
    mov bx, es:[09h*4+2]            ;
    mov si, offset keyb_old_segment ;
    mov ds:[si], bx                 ; Saves old keyboard interrupt vector segment

    mov ax, es:[0Bh*4]              ;
    mov si, offset com_old_offset          ;
    mov ds:[si], ax                 ; Saves old COM interrupt vector offset
    
    mov bx, es:[0Bh*4+2]            ;
    mov si, offset com_old_segment         ;
    mov ds:[si], bx                 ; Saves old COM interrupt vector segment
    
    ; Switch vectors to the new handlers
    CLI                             ; Interrupts prohibition
    
    mov word ptr es:[1CH*4], offset rtc_handler ;
    mov word ptr es:[1CH*4+2], seg rtc_handler  ; Switch 1Ch to user's timer handler
    
    mov ax, ds:[keyb_old_offset]                ;
    mov es:[90h*4], ax                          ;
    mov bx, ds:[keyb_old_segment]               ;
    mov es:[90h*4+2], bx                        ; Using empty 90h vector for system keyboard interrupt handler
    
    mov word ptr es:[09H*4], offset keyb_handler  ; 
    mov word ptr es:[09H*4+2], seg keyb_handler   ; Switch 09h to user's keyboard handler

    mov word ptr es:[0BH*4], offset com_handler ;
    mov word ptr es:[0BH*4+2], seg com_handler  ; Switch 0Bh to user's COM handler
    
    ; Enable interrupts from irq0, irq1, irq3
    in al, 21h
    and al, 11110100b
    out 21h, al
    
    STI                             ; Interrupts permission
    ;
    
    ; Load to make a delay
    mov ax, 0ffffh  ;
cycle1:             ;
    mov bx, 0ffffh  ;
cycle2:             ;
    cli             ; interrupts prohibition
    mov si, offset endprog_flag
    mov dl, ds:[si]
    cmp dl, 1
    jz restore      ; restore interrupt vectors to default
    sti             ; interrupt permission
    dec bx          ;
    jnz cycle2      ;
    dec ax          ;
    jnz cycle1      ;

restore:
    ; Restore vectors to the default values
    CLI
    
    mov si, offset rtc_old_offset                      ;
    mov ax, ds:[si]                             ;
    mov es:[1CH*4], ax                          ; Restore timer vector offset
    
    mov si, offset rtc_old_segment                     ;
    mov bx, ds:[si]                             ;
    mov es:[1CH*4+2], bx                        ; Restore timer vector segment
    
    mov si, offset keyb_old_offset                     ;
    mov ax, ds:[si]                             ;
    mov es:[09H*4], ax                          ; Restore keyboard vector offset
    
    mov si, offset keyb_old_segment                    ;
    mov bx, ds:[si]                             ;
    mov es:[09H*4+2], bx                        ; Restore keyboard vector segment
    
    mov ax, 00h                                 ;
    mov es:[90h*4], ax                          ;
    mov bx, 00h                                 ;
    mov es:[90h*4+2], bx                        ; Empty 90h vector
    
    mov si, offset com_old_offset                      ;
    mov ax, ds:[si]                             ;
    mov es:[0BH*4], ax                          ; Restore COM vector offset
    
    mov si, offset com_old_segment                     ;
    mov bx, ds:[si]                             ;
    mov es:[0BH*4+2], bx                        ; Restore COM vector segment
    
    STI
    ;

    ; Vyhod v DOS
    mov ax, 4C00h
    int 21h
mycode ends

.stack
mystack segment
          db 1000 dup(?)  ; razmer steka 1000 bait
mystack ends

end mystart
