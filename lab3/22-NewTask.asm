; Простой планировщик задач
; ~~~~~~~~~~~~~~~~~~~~~~~~~
; Производит переключение в защищенный режим с инициализацией
; таблиц GDT и IDT и сегментов TSS. Осуществляет переключение между тремя
; фиксированными задачами в круговом порядке, переключение происходит по
; истечении кванта времени (по прерыванию от таймера), т.е. реализуется
; механизм вытесняющей многозадачности. Обрабатываются все прерывания и
; исключения (для того чтобы апп-е прерывания не накладывались на исключения,
; 1ый ПКП перепрограммируется для отображения Irq0 на Int 20h и т.д.).
; Любое исключение приводит к выдаче сообщения и завершению программы,
; нажатие Esc - выход из программы.
;
; Компиляция TASM:
;       tasm /zi <имя файла>.asm
;       tlink /3 /v <имя файла>.obj
; Компиляция WASM:
;       wasm /D <имя файла>.asm
;       wlink debug file <имя файла>.obj form DOS
;
so     equ     offset  ; для WASM
;so      equ     small offset    ; для TASM
PAUSE   EQU     700000H ; Задержка при перерисовке символа
.386p   ; Разрешены все команды I386



; Сегмент данных для защищенного режима, содержит GDT, IDT и сегменты TSS
PM_data SEGMENT para public 'DATA' use32

; таблица глобальных дескрипторов 
GDT     LABEL   byte
; нулевой дескриптор (обязательно должен быть на первом месте)
db      8 dup(0)
; 16-битный 64-килобайтный сегмент кода с базой RM_seg
GDT_16bitCS     db      0FFh,0FFh,0,0,0,10011000b,0,0
; 16-битный 64-килобайтный сегмент данных с нулевой базой
GDT_R_MODE_DATA db      0FFh,0FFh,0,0,0,10010010b,0,0
; 32-битный 64-килобайтный сегмент данных с базой 0B8000h
GDT_VideoBuf    db      0FFh,0FFh,0,80h,0Bh,11110010b,01000000b,0
; 32-битный 4-гигабайтный сегмент кода с базой PM_code
GDT_32bitCS     db      0FFh,0FFh,0,0,0,10011010b,11001111b,0
; 32-битный 4-гигабайтный сегмент данных с базой PM_data
GDT_32bitDS     db      0FFh,0FFh,0,0,0,10010010b,11001111b,0
; 32-битный 4-гигабайтный сегмент данных с базой Stak_seg
GDT_32bitSS     db      0FFh,0FFh,0,0,0,10010010b,11001111b,0
; 32-битный свободный TSS задачи 0 с лимитом 67h
GDT_TSS0        db      67h,0,0,0,0,10001001b,01000000b,0
; 32-битный свободный TSS задачи 1 с лимитом 67h
GDT_TSS1        db      67h,0,0,0,0,10001001b,01000000b,0
; 32-битный свободный TSS задачи 2 с лимитом 67h
GDT_TSS2        db      67h,0,0,0,0,11101001b,01000000b,0
; 32-битный ограниченный сегмент кода задачи 2
GDT_Task2_CS	db		0,0,0,0,0,11111010b,01000010b,0
; 32-битный ограниченный сегмент данных задачи 2
GDT_Task2_DS	db		0,0,0,0,0,11110010b,01000000b,0
; 32-битный ограниченные сегменты стека задачи 2
GDT_Task2_SS3	db		0FFh,0,0,0,0,11110010b,01000000b,0
GDT_Task2_SS0	db		0FFh,0,0,0,0,10010010b,01000000b,0
; 32-битный ограниченный сегмент локальной таблицы дескрипторов задачи 2
GDT_Task2_LDT	db		0,0,0,0,0,11100010b,01000000b,0

; Дескрипторы для задачи 3

; 32-битный свободный TSS задачи 3 с лимитом 67h
GDT_TSS3        db      67h,0,0,0,0,10001001b,01000000b,0
; 32-битный ограниченный сегмент кода задачи 3
GDT_Task3_CS	db		0,0,0,0,0,10011010b,01000010b,0
; 32-битные ограниченные сегменты стека задачи 3
GDT_Task3_SS3	db		0FFh,0,0,0,0,10010010b,01000000b,0
GDT_Task3_SS0	db		0FFh,0,0,0,0,10010010b,01000000b,0
; 32-битный ограниченный сегмент локальной таблицы дескрипторов задачи 3
GDT_Task3_LDT	db		0,0,0,0,0,10000010b,01000000b,0

gdt_size = $-GDT
GDTr    dw      gdt_size-1      ; лимит GDT
dd      ?       ; здесь будет 32-битный линейный адрес GDT


; таблица локальных дескрипторов задачи 2
LDT2     LABEL   byte
; нулевой дескриптор (обязательно должен быть на первом месте)
db      8 dup(0)
; 32-битный ограниченный сегмент данных задачи 2
LDT2_DS	db		0,0,0,0,0,11110010b,01000000b,0
ldt2_size = $-LDT2
LDT2_Limit    	dw      ldt2_size-1      ; лимит LDT2

; таблица локальных дескрипторов задачи 3
LDT3     LABEL   byte
; нулевой дескриптор (обязательно должен быть на первом месте)
db      8 dup(0)
; 32-битный ограниченный сегмент данных задачи 3
LDT3_DS	    db		0,0,0,0,0,10010010b,01000000b,0
ldt3_size = $-LDT3
LDT3_Limit    	dw      ldt3_size-1      ; лимит LDT3


; имена для селекторов (все селекторы для GDT, с RPL = 00)
SEL_16bitCS     equ     0001000b
SEL_R_MODE_DATA equ     0010000b
SEL_VideoBuf    equ     0011000b
SEL_32bitCS     equ     0100000b
SEL_32bitDS     equ     0101000b
SEL_32bitSS     equ     0110000b
SEL_TSS0        equ     0111000b
SEL_TSS1        equ     1000000b
SEL_TSS2 		equ     1001011b
SEL_Task2_CS	equ		1010011b
SEL_Task2_DS	equ		1011011b
SEL_Task2_SS3	equ		1100011b
SEL_Task2_SS0	equ		1101000b
SEL_Task2_LDT	equ 	1110011b	; селектор локальной таблицы задачи 2 в глобальной таблице

; К задаче 3
SEL_TSS3        equ     1111000b
SEL_Task3_CS	equ	   10000000b
SEL_Task3_SS3	equ	   10001000b
SEL_Task3_SS0	equ	   10010000b
SEL_Task3_LDT	equ	   10011000b

; Локальная таблица дескрипторов 
SEL_LDT2_DS		equ		0001111b	; селектор сегмента данных задачи 2 в локальной таблице задачи 2
SEL_LDT3_DS     equ     0001100b    ; селектор сегмента данных задачи 3 в локальной таблице задачи 3

; таблица дескрипторов прерываний
IDT     LABEL   byte
; INT 00h - 1Fh (исключения)
; все эти дескрипторы имеют тип 0Fh -> 32-битный шлюз ловушки
dw      32 dup (so Exept_h,SEL_32bitCS,8F00h,0)
; все след. дескрипторы имеют тип 0Eh -> 32-битный шлюз прерывания
; INT 20h (Irq0)
dw      so Plan,SEL_32bitCS,8E00h,0
; INT 21h (Irq1)
dw      so Irq1_h,SEL_32bitCS,8E00h,0
; INT 22h (Irq2)
dw      so Irq2_7_h,SEL_32bitCS,8E00h,0
; INT 23h - 24h (Irq3 - Irq4 COM2,COM1)
dw      2 dup (so Receive,SEL_32bitCS,8E00h,0)
; INT 25h - 27h (Irq5 - Irq7)
dw      3 dup (so Irq2_7_h,SEL_32bitCS,8E00h,0)
; INT 28h - 6Fh
dw      72 dup (so Int_h,SEL_32bitCS,8E00h,0)
; INT 70h - 77h (Irq8 - Irq15)
dw      8 dup (so Irq8_15_h,SEL_32bitCS,8E00h,0)
; INT 78h - FFh
dw      136 dup (so Int_h,SEL_32bitCS,8E00h,0)
idt_size = $-IDT
IDTr    dw      idt_size-1      ; лимит IDT
dd      ?       ; здесь будет 32-битный линейный адрес IDT

; содержимое регистра IDTR в реальном режиме
IDTr_real dw    3FFh,0,0

; сегмент TSS_0 задачи 0 будет инициализирован в начале задачи 0, которая начнет
; выполняться сразу после переключения МП в защищенный режим. Конечно, 
; если бы мы собирались использовать несколько уровней привилегий, то 
; нужно было бы инициализировать стеки.
TSS_0   db      68h dup(0)

; сегмент TSS_1 задачи 1. В неё будет выполняться переключение командой jmp из
; планировщика задач, так что надо инициализировать все, что может потребоваться:
TSS_1   dd      8 dup(0)        ; связь, стеки, CR3
dd      offset Task_1   ;       EIP
dd      0200h   ;       EFLAGS (IF=1, DF=0)
dd      0Ah*256 ;       Symb_Col*256    ;       EAX
dd      0,0,0   ;       ECX, EDX, EBX
dd      Stack_1 ;       ESP
dd      0,0     ;       EBP, ESI
dd      LastPos_1       ;       EDI (для вывода начального символа)
dd      SEL_VideoBuf    ;       ES
dd      SEL_32bitCS     ;       CS
dd      SEL_32bitSS     ;       SS
dd      SEL_32bitDS     ;       DS
dd      0,0     ;       FS, GS
dd      0       ;       LDTR
dw      0       ;       слово флагов задачи
dw      0       ;       адрес таблицы ввода-вывода

; сегмент TSS_2. Аналогично TSS_1:
TSS_2   dw		0		; селектор TSS обратной связи (для вложенных задач)
dw		0
dd		Stack_2_PL0		; ESP для стека уровня привилегий 0
dw		SEL_Task2_SS0	; SS для стека уровня привилегий 0 (должно быть RPL = 00)
dw		0
dd		0				; ESP для стека уровня привилегий 1
dw		0				; SS для стека уровня привилегий 1 (должно быть RPL = 01)
dw		0
dd		0				; ESP для стека уровня привилегий 2
dw		0				; SS для стека уровня привилегий 2 (должно быть RPL = 10)
dw		0
dd      0        		; CR3, адрес каталога таблиц страниц (при страничной адресации)
dd      offset Task_2   ; EIP
dd      0200h           ; EFLAGS (IF=1, DF=0)
dd      05h*256    		; EAX
dd      0,0,0           ; ECX, EDX, EBX
dd      Stack_2_PL3     ; ESP для стека уровня привилегий сегмента кода задачи, в данном случае 3
dd      0,0             ; EBP, ESI
dd      LastPos_2       ; EDI (для вывода начального символа)
dd      SEL_VideoBuf    ; ES
dd      SEL_Task2_CS    ; CS
dd      SEL_Task2_SS3   ; SS для стека уровня привилегий сегмента кода задачи, в данном случае 3
dd      SEL_Task2_DS    ; DS
dd      0,0             ; FS, GS
dw      SEL_Task2_LDT   ; LDTR
dw		0
dw      0               ; слово флагов задачи
dw      0               ; адрес таблицы ввода-вывода

; сегмент TSS_3. Аналогично TSS_2:
TSS_3   dw		0		; селектор TSS обратной связи (для вложенных задач)
dw		0
dd		Stack_3_PL0		; ESP для стека уровня привилегий 0
dw		SEL_Task3_SS0	; SS для стека уровня привилегий 0 (должно быть RPL = 00)
dw		0
dd		0				; ESP для стека уровня привилегий 1
dw		0				; SS для стека уровня привилегий 1 (должно быть RPL = 01)
dw		0
dd		0				; ESP для стека уровня привилегий 2
dw		0				; SS для стека уровня привилегий 2 (должно быть RPL = 10)
dw		0
dd      0        		; CR3, адрес каталога таблиц страниц (при страничной адресации)
dd      offset Task_3   ; EIP
dd      0200h           ; EFLAGS (IF=1, DF=0)
dd      05h*256    		; EAX
dd      0,0,0           ; ECX, EDX, EBX
dd      Stack_3_PL3     ; ESP для стека уровня привилегий сегмента кода задачи, в данном случае 3
dd      0,0             ; EBP, ESI
dd      LastPos_3       ; EDI (для вывода начального символа)
dd      SEL_VideoBuf    ; ES
dd      SEL_Task3_CS    ; CS
dd      SEL_Task3_SS3   ; SS для стека уровня привилегий сегмента кода задачи, в данном случае 3
dd      SEL_LDT3_DS     ; DS
dd      0,0             ; FS, GS
dw      SEL_Task3_LDT   ; LDTR
dw		0
dw      0               ; слово флагов задачи
dw      0               ; адрес таблицы ввода-вывода

; Счетчик (для планировщика)
Counter dw      0
; [Селектор]:[Смещение] всех трех TSS для дальнего jmp'а (для планировщика)
Sel_0   dd      0       ; смещение
dw      SEL_TSS0        ; селектор
dw      ?
Sel_1   dd      0       ; смещение
dw      SEL_TSS1        ; селектор
dw      ?
Sel_2   dd      0       ; смещение
dw      SEL_TSS2        ; селектор
dw      ?
Sel_3   dd      0       ; смещение
dw      SEL_TSS3        ; селектор

; Сообщение об исключении
Exp_msg LABEL   byte
IRPC chr, <!!! Exception raised - program exits !!!> 
  db '&chr&', 0Ch
ENDM
Emsg_size = $ - Exp_msg

; константы, которые используются в задачах
LastPos_0       =       027Eh
LastPos_1       =       075Eh
LastPos_2       =       0C7Eh
LastPos_3       =       0F9Eh
Delta   =       9Ch
Symb_Col        EQU       0Ah
Symb_Div        =       20h 
DataBufer    db 40 dup (30h)
;буфер данных
COUNT   DB      20h
SMVL    DB      20h
;переменые
COM     dw      0
IER     dw      0
IIR     dw      0
LCR     dw      0
MCR     dw      0
LSR     dw      0
MSR     dw      0

PM_data ENDS



; 32-битный сегмент, содержащий код, который будет исполняться в защищенном режиме 
PM_code SEGMENT para public 'CODE' use32
ASSUME  cs: PM_code
ASSUME  ds: PM_data

; точка входа в 32-битный защищенный режим
PM_ENTRY:
;здесь будем инициализировать микросхему контроллера прерываний
cli     ;запрещаем
MOV     AL,0
MOV     DX,MCR
OUT     DX,AL
JMP     $+2
MOV     DX,LSR
IN      AL,DX
JMP     $+2
MOV     DX,MSR
IN      AL,DX
JMP     $+2
MOV     DX,COM
IN      AL,DX
JMP     $+2
; инициализация COM порта
MOV     AX, 2F8H ;тут должен быть адрес компорта COM2
MOV     COM, AX ; тута ждем 2f8
INC     AX
MOV     IER, AX ; адрес регистра разрешения прерываний
INC     AX
MOV     IIR, AX ; адрес регистра идентификации прерываний
INC     AX
MOV     LCR, AX ; адрес регистра управления линией
INC     AX
MOV     MCR, AX ; адрес регистра управления модемом
INC     AX
MOV     LSR, AX ; адрес регистра состояния линии
INC     AX
MOV     MSR,AX ; адрес регистра состояния модема
XOR     AX,AX
; ycтановка speeda
MOV     DX,LCR
MOV     AL,10000000B
OUT     DX,AL
MOV     DX,COM
MOV     AL,60H
OUT     DX,AL
INC     DX
MOV     AL,0
OUT     DX,AL
;инициализ регистра контроля линии
MOV     DX,LCR
MOV     AL,00H
OR      AL,00000011B
OR      AL,00000000B
OR      AL,00000000B
OR      AL,00000000B
OUT     DX,AL
;управления регистра управления модемом
MOV     DX,MCR
MOV     AL,00011000B ; Должно быть 00011000B (чтобы разрешить прерывания от COM-порта)
OUT     DX,AL
;mcr ready
MOV     DX,IER
MOV     AL,00000111B
OUT     DX,AL
; контроллер прерываний
IN      AL,21H
AND     AL,11100111B
OUT     21H,AL
MOV     AL,20H
OUT     20H,AL
OUT     0A0H,AL
STI     ;разрешаем прерывания
;финиш
; подготовить регистры задачи 0
mov     ax, SEL_32bitDS
mov     ds, ax
mov     ax, SEL_VideoBuf
mov     es, ax
mov     ax, SEL_32bitSS
mov     ss, ax
mov     esp, Stack_0
; загрузить TSS задачи 0 в регистр TR
mov     ax, SEL_TSS0
ltr     ax
; подготовить регистры
mov     edi, LastPos_0
mov     ah, Symb_Col
cld
; разрешить прерывания
sti

; Задача 0
Task_0:
sub     edi, 2
mov     ah,02h                     ;гасим
mov     al,SMVL
dec     al
cmp     al,1Fh                     ;вот 1f выводить не будем
jnz     @1
mov     al,20h
@1:     stosw
cmp     edi, LastPos_0
jnz     short @0
sub     edi, Delta
@0:     mov     al, SMVL        ;Symb_Code
mov     ah, 1Eh ;активный цвет
stosw
; ниже описан передатчик
MOV     DX,LSR
SNDRDY: IN      AL,DX
TEST    AL,00100000B
JZ      SNDRDY
MOV     AL,SMVL
CMP     AL,0FFH
JNZ     N_RESET
MOV     AL,20H
N_RESET:
MOV     DX,COM
OUT     DX,AL
;сохраним следующий символ
INC     AL
MOV     SMVL,AL
; небольшая пауза, зависящая от скорости процессора
mov     ecx, Pause
;mov     ecx, 700000h
loop    $
jmp     short Task_0


; Задача 1
Task_1:

; Вставка

; Пункт 3. Запрет прерывания от COM-портов irq3, irq4
; в контроллере прерываний
;push AX
;in AL, 21h
;or AL, 00011000b
;out 21h, AL
;pop AX

; Конец вставки

mov     cx,28h  ;length
mov     esi,0   ;offcet
sub     edi,54h ;correct edi
next:
mov     al,[Databufer+esi]
inc     esi
stosw
loop    next
mov     al,20h  ; вывели пробел
stosw
mov     al,Count        ; а это наша звездочка
cmp     al,20h
jnz     toreset
mov     al,2Ah
jmp     print
toreset:
mov     al,20h
print:
mov     Count,al
mov     ah,0Ch
stosw
mov     ah,0Ah  ;восстанавливаем цвет
mov     ecx, Pause
;mov     ecx, 700000h
loop    $
jmp     short Task_1


; обработчик исключения
Exept_h: cli
mov bx, SEL_32bitDS
mov ds, bx
mov bx, SEL_VideoBuf
mov es, bx

; Достаем код ошибки со стека
;pop ecx
;and ecx, 0100b
;jnz Skip
; выводим сообщение
mov     esi, offset Exp_msg
mov     ecx, Emsg_size
cld
rep     movsb
Skip:
; и выходим в реальный режим
db      0EAh    ; код дальнего jmp
dd      offset RM_return        ; 32-битное смещение RM_return
dw      SEL_16bitCS     ; селектор RM_seg


; обработчик программного прерывания
Int_h:
iretd


; обработчик аппаратного прерывания Irq2 - Irq7
Irq2_7_h:
push    eax
mov     al, 20h
out     20h, al         ; послать EOI контроллеру прерываний #1
pop     eax
iretd


; обработчик аппаратного прерывания Irq8 - Irq15
Irq8_15_h:
push    eax
mov     al, 20h
out     0A0h, al        ; послать EOI контроллеру прерываний #2
pop     eax
iretd


; обработчик Irq0 - прерывания от таймера (сам Планировщик)
Plan:
push    ds                      ; сохраняем регистры
push    ebx
push    eax
mov     ax, SEL_32bitDS
mov     ds, ax                  ; селектор PM_data -> в ds
xor     ebx, ebx
mov     bx, Counter             ; читаем Counter,
inc     ebx                     ; увеличиваем его на 1
cmp     ebx, 4                  ; и проверяем: если он соотв-ет
jnz     short @OK               ; задаче 2, то устанавливаем его
xor     ebx, ebx                ; на задачу 0,
@OK:    mov     Counter, bx     ; сохраняем Counter
mov     al, 20h
out     20h, al                 ; посылаем EOI контроллеру прерываний
jmp     fword ptr [ebx*8+Sel_0] ; переключаемся на задачу №Counter
pop     eax
pop     ebx                     ; восстанавливаем регистры и выходим
pop     ds
iretd



; Обработчик IRQ3-IRQ4 - прерывания от COM-портов
RECEIVE:
PUSH    EAX
PUSH    ESI
PUSH    DX
MOV     ESI,39
movebufer:
MOV     AL,[DATABUFER+ESI-1]
MOV     [DATABUFER+ESI],AL
DEC     ESI
CMP     ESI,0
JNZ     MOVEBUFER
;теперь работаем с портом (i8250)
MOV     DX,IIR  ;interrupt testing
IN      AL,DX
RCR     AL,1
JC      BYE
DATRDY: MOV     DX,LSR  ;data present testing
IN      AL,DX
TEST    AL,00001110B
JNZ     BYE     ;на самом деле тут должен быть
;прыжок на обработчик ошибок
;TEST    AL,00000001B <-- бит готовности данных почему-то не выставляется DosBox'ом
;JZ      DATRDY       <-- поэтому пришлось закомментировать эту проверку.
MOV     DX,COM  ;receiving
IN      AL,DX
PUSH    AX 
BUFRDY: MOV     DX,LSR  ;data received, Buffer is empty
IN      AL,DX
TEST    AL,00000001B
JNZ     BUFRDY
POP     AX      ;тут по идее должны были прочитать из стека
MOV     [DATABUFER],AL  ;записали новое значение в начало 
bye:    MOV     AL, 20H
OUT     20H,AL  ; послать EOI контроллеру прерываний #1
POP     DX
POP     ESI
POP     EAX
IRETD


; обработчик Irq1 - прерывания от клавиатуры
Irq1_h:
push    eax
in      al, 60h         ; прочитать скан-код нажатой клавиши,
cmp     al, 1           ; если это Esc,
jz      Esc_pressed     ; выйти в реальный режим,
in      al, 61h         ; иначе:
or      al, 80h
out     61h, al         ; разрешить работу клавиатуры
mov     al, 20h
out     20h, al         ; послать EOI контроллеру прерываний #1
pop     eax
iretd   ; и закончить обработчик

; сюда передается управление из обработчика Irq1, если нажата Esc
Esc_pressed:
in      al, 61h
or      al, 80h
out     61h, al         ; разрешить работу клавиатуры
mov     al, 20h
out     20h, al         ; послать EOI контроллеру прерываний #1
cli     ; запретить прерывания
db      0EAh    ; и вернуться в реальный режим
dd      offset RM_return
dw      SEL_16bitCS

PM_code ENDS



; Сегмент данных задачи 2
Task2_DS SEGMENT PARA PUBLIC 'DATA' use32

Task2_DS_Start LABEL byte

MYVAR 	DB	5
MYVAR2  DB  'Z'

Task2_DS_Size  EQU $-Task2_DS_Start
Task2_DS_Limit dw Task2_DS_Size - 1

Task2_DS ENDS



; Сегмент кода задачи 2
Task2_CS SEGMENT PARA PUBLIC 'CODE' use32
ASSUME CS:Task2_CS
;ASSUME CS:PM_code
ASSUME DS:Task2_DS
ASSUME SS:Task2_SS3

Task2_CS_Start LABEL byte
; Задача 2
Task_2:
; mov <память>, <регистр>
; СЕЛЕКТОР NNNNNNNTPP 
;          0000011011
; номер, идентификатор таблицы, привилегии
; mov CX, 0000011011b ; инициализация
; mov GS, CX          ; селектора видеобуфера
; mov CL, 'Z'
; mov CH, 0Eh
; mov GS:[0000], CX

; mov CX, 0100000h
; mov GS, CX
; call GS:[0]



mov 	bx, SEL_LDT2_DS
mov		fs, bx

xor     al, al
sub     edi, 2
stosw
cmp     edi, LastPos_2
jnz     short @2
sub     edi, Delta
@2: mov al, fs:[MYVAR] ;Symb_Code access using LDT
stosw
; небольшая пауза, зависящая от скорости процессора
mov     ecx, Pause
;mov     ecx, 700000h
loop    $
jmp     short Task_2
Task2_CS_Size  EQU $-Task2_CS_Start
Task2_CS_Limit dw Task2_CS_Size - 1

Task2_CS ENDS



; 32-битный сегмент стека задачи 2 для уровня привилегий 3
Task2_SS3 SEGMENT para stack 'STACK' use32

Task2_SS3_End db      	100h dup(?)     ; стек задачи 2 уровня привилегий 3
Stack_2_PL3 = $-Task2_SS3_End

Task2_SS3 ENDS

; 32-битный сегмент стека задачи 2 для уровня привилегий 0
Task2_SS0 SEGMENT para stack 'STACK' use32

Task2_SS0_End db		100h dup(?)     ; стек задачи 2 уровня привилегий 0
Stack_2_PL0 = $-Task2_SS0_End

Task2_SS0 ENDS



; Сегмент данных задачи 3
Task3_DS SEGMENT PARA PUBLIC 'DATA' use32

Task3_DS_Start LABEL byte

MYVAR3 	DB	6

Task3_DS_Size  EQU $-Task3_DS_Start
Task3_DS_Limit dw Task3_DS_Size - 1

Task3_DS ENDS

; Сегмент кода задачи 3
Task3_CS SEGMENT PARA PUBLIC 'CODE' use32
ASSUME CS:Task3_CS
ASSUME DS:Task3_DS  ; директивы ассемблера?
ASSUME SS:Task3_SS3 ; нужны для отображения кода, можно без них

Task3_CS_Start LABEL byte
; Задача 3
Task_3:

mov 	bx, SEL_LDT3_DS
mov		fs, bx

xor     al, al
sub     edi, 2
stosw
cmp     edi, LastPos_3
jnz     short @3
sub     edi, Delta
@3: mov al, fs:[MYVAR3] ;Symb_Code access using LDT
stosw
; небольшая пауза, зависящая от скорости процессора
mov     ecx, Pause
;mov     ecx, 700000h
loop    $
jmp     short Task_3
Task3_CS_Size  EQU $-Task3_CS_Start
Task3_CS_Limit dw Task3_CS_Size - 1

Task3_CS ENDS

; 32-битный сегмент стека задачи 3 для уровня привилегий 3
Task3_SS3 SEGMENT para stack 'STACK' use32

Task3_SS3_End db      	100h dup(?)     ; стек задачи 3 уровня привилегий 3
Stack_3_PL3 = $-Task3_SS3_End

Task3_SS3 ENDS

; 32-битный сегмент стека задачи 3 для уровня привилегий 0
Task3_SS0 SEGMENT para stack 'STACK' use32

Task3_SS0_End db		100h dup(?)     ; стек задачи 3 уровня привилегий 0
Stack_3_PL0 = $-Task3_SS0_End

Task3_SS0 ENDS


; Сегмент стека. Используется как 16-битный в 16-битной части программы и как
; 32-битный (через селектор SEL_32bitSS) в 32-битной части.
Stak_seg SEGMENT para stack 'STACK'

st_start        db      100h dup(?)     ; стек задачи 0 и RM
Stack_0 = $-st_start

db      100h dup(?)     ; стек задачи 1
Stack_1 = $-st_start

Stak_seg ENDS

; 16-битный сегмент, в котором находится код для входа и выхода из защищенного режима
RM_seg  SEGMENT para public 'CODE' use16

ASSUME cs: RM_seg
ASSUME ds: RM_seg
ASSUME ss: Stak_seg

V86_msg db      "Processor in V86 mode - unable to switch to PM$"
WIN_MSG DB      "Program running under WINDOWS - unable to switch to PL0$"
mes     db      "Return to The Real Mode!!!                                                      $"
Ramk_Col = 03h  ;Color

Header  LABEL   byte
IRPC chr, < --  Task 1  ------------------------------------------------------------------ > 
  db '&chr&', Ramk_Col
ENDM

Footer  LABEL   byte
IRPC chr, < ------------------------------------------------------------------------------ > 
  db '&chr&', Ramk_Col
ENDM

My_msg  LABEL   byte
IRPC chr, <************************ Coded by Max&Roman&Olga IU3-91 ***********************> 
  db '&chr&', 03h
ENDM

Wind PROC near ; П/п рисует окно задачи. Вход: di = начальное смещение cld
mov     cx, 80
mov     si, offset Header
rep     movsw
mov     al, " "
mov     ah, Ramk_Col
mov     cx, 4
@cycl:  stosw
add     di, 156
stosw
loop    @cycl
mov     cx, 80
mov     si, offset Footer
rep     movsw
ret
Wind    ENDP

TR_text PROC
mov     edi,01E2h
mov     ah,02h
mov     al,20h
mov     cx,78
nxt:
stosw
inc     al
loop    nxt
TR_text ENDP

PicInit PROC near ; П/п иниц-ет 1ый ПКП. Вход: dl = № Int, соотв-щее Irq0 
;mov al, 00010101b ; ICW1
mov al, 00010001b ; ICW1
out     20h, al
mov     al, dl
out     21h, al         ; ICW2
mov     al, 00000100b   ; ICW3
out     21h, al
mov     al, 00001101b   ; ICW4
out     21h, al
ret
PicInit ENDP


; -------------------- Точка входа в программу ------------------------------
Start:
; подготовить сегментные регистры
mov     ax, RM_seg
mov     ds, ax
mov     ax, Stak_seg
mov     ss, ax
mov     sp, Stack_0
mov     ax, 0B800h
mov     es, ax
; проверить, не находимся ли мы уже в PM
mov     eax, cr0        ; прочитать регистр CR0
test    al, 1   ; проверить бит PE, если он ноль - мы можем
jz      No_V86  ; продолжать, иначе - сообщить об ошибке и выйти
mov     dx, offset V86_msg
Err_exit:
mov     ah, 9   ; функция DOS 09h - вывод строки
int     21h
mov     ah, 4Ch ; конец EXE-программы
int     21h
; может быть, это Windows'95 делает вид, что PE = 0?
No_V86: mov     ax, 1600h       ; Функция 1600h
int     2Fh             ; прерывания мультиплексора:
test    al, al          ; если AL = 0, то
jz      No_win          ; Windows не запущена
mov     dx, offset Win_msg
jmp     short Err_exit  ; сообщить и выйти
; итак, мы точно находимся в реальном режиме
No_win:
; очистить экран
mov     ax, 3
int     10h
; заполнить экран
xor     di, di
mov     di, 00A0h
call    Wind            ; Окно задачи A
mov     di, 05A0h
call    Wind            ; Окно задачи B
mov     di, 05B4h
mov     byte ptr es:[di], '2'
mov     di, 0AA0h
call    Wind            ; Окно задачи C
mov     di, 0AB4h
mov     byte ptr es:[di], '3'
mov     cx, 80          ; Вывод нижней строки
mov     si, offset My_msg
xor     di, di
cld
REP     MOVSW
;       call    TR_text

; ------------ Подготовка к переходу и переход в защищенный режим -------------
; подготовить регистр ds
ASSUME ds: PM_data 
mov ax, PM_data 
mov ds, ax
; вычислить базы для всех используемых дескрипторов сегментов 
xor     eax, eax
; 16bitCS                          ; базой 16bitCS будет начало RM_seg:
mov     ax, RM_seg                 ; AX - сегментный адрес RM_seg
shl     eax, 4                     ; EAX - линейный адрес RM_seg
mov     word ptr GDT_16bitCS+2, ax ; биты 15 - 0 базы
shr     eax, 16
mov     byte ptr GDT_16bitCS+4, al ; биты 23 - 16 базы
; 32bitCS
mov     ax, PM_code
shl     eax, 4
mov     word ptr GDT_32bitCS+2, ax ; базой 32bitCS будет начало PM_code
shr     eax, 16
mov     byte ptr GDT_32bitCS+4, al
; 32bitDS
mov     ax, PM_data
shl     eax, 4
push    eax
mov     word ptr GDT_32bitDS+2, ax ; базой 32bitDS будет начало PM_data
shr     eax, 16
mov     byte ptr GDT_32bitDS+4, al
; 32bitSS
mov     ax, Stak_seg
shl     eax, 4
mov     word ptr GDT_32bitSS+2, ax ; базой 32bitSS будет начало Stak_seg
shr     eax, 16
mov     byte ptr GDT_32bitSS+4, al
; вычислить линейные адреса сегментов TSS наших задач и поместить их в дескрипторы
; TSS задачи 0
pop     eax
push    eax
add     eax, offset TSS_0
mov     word ptr GDT_TSS0+2, ax
shr     eax, 16
mov     byte ptr GDT_TSS0+4, al
; TSS задачи 1
pop     eax
push    eax
add     eax, offset TSS_1
mov     word ptr GDT_TSS1+2, ax
shr     eax, 16
mov     byte ptr GDT_TSS1+4, al
; TSS задачи 2
pop     eax
push    eax
add     eax, offset TSS_2
mov     word ptr GDT_TSS2+2, ax
shr     eax, 16
mov     byte ptr GDT_TSS2+4, al
; TSS задачи 3
pop     eax
push    eax
add     eax, offset TSS_3
mov     word ptr GDT_TSS3+2, ax
shr     eax, 16
mov     byte ptr GDT_TSS3+4, al
; CS задачи 2
mov		ax, Task2_CS
mov		es, ax
mov		ax, es:[Task2_CS_Limit]
mov		word ptr ds:[GDT_Task2_CS], ax
mov		eax, 0
mov		ax, Task2_CS
shl		eax, 4
mov		word ptr ds:[GDT_Task2_CS+2], ax
shr		eax, 16
mov		byte ptr ds:[GDT_Task2_CS+4], al
; DS задачи 2
mov		ax, Task2_DS
mov		es, ax
mov		ax, es:[Task2_DS_Limit]
mov		word ptr ds:[GDT_Task2_DS], ax
mov 	eax, 0
mov		ax, Task2_DS
shl		eax, 4
mov		word ptr ds:[GDT_Task2_DS+2], ax
shr		eax, 16
mov		byte ptr ds:[GDT_Task2_DS+4], al
; SS задачи 2 для уровня привилегий 3
mov 	eax, 0
mov		ax, Task2_SS3
shl		eax, 4
mov		word ptr ds:[GDT_Task2_SS3+2], ax
shr		eax, 16
mov		byte ptr ds:[GDT_Task2_SS3+4], al
; SS задачи 2 для уровня привилегий 0
mov 	eax, 0
mov		ax, Task2_SS0
shl		eax, 4
mov		word ptr ds:[GDT_Task2_SS0+2], ax
shr		eax, 16
mov		byte ptr ds:[GDT_Task2_SS0+4], al
; LDT задачи 2
mov		ax, ds:[LDT2_Limit]
mov		word ptr ds:[GDT_Task2_LDT], ax
pop     eax
push    eax
add		eax, offset LDT2
mov		word ptr ds:[GDT_Task2_LDT+2], ax
shr		eax, 16
mov		byte ptr ds:[GDT_Task2_LDT+4], al
; Дескриптор сегмента данных задачи 2 в локальной таблице дескрипторов задачи 2
mov		ax, Task2_DS
mov		es, ax
mov		ax, es:[Task2_DS_Limit]
mov		word ptr ds:[LDT2_DS], ax
mov 	eax, 0
mov		ax, Task2_DS
shl		eax, 4
mov		word ptr ds:[LDT2_DS+2], ax
shr		eax, 16
mov		byte ptr ds:[LDT2_DS+4], al

; CS задачи 3
mov		ax, Task3_CS
mov		es, ax
mov		ax, es:[Task3_CS_Limit]
mov		word ptr ds:[GDT_Task3_CS], ax
mov		eax, 0
mov		ax, Task3_CS
shl		eax, 4
mov		word ptr ds:[GDT_Task3_CS+2], ax
shr		eax, 16
mov		byte ptr ds:[GDT_Task3_CS+4], al
; SS задачи 3 для уровня привилегий 3
mov 	eax, 0
mov		ax, Task3_SS3
shl		eax, 4
mov		word ptr ds:[GDT_Task3_SS3+2], ax
shr		eax, 16
mov		byte ptr ds:[GDT_Task3_SS3+4], al
; SS задачи 3 для уровня привилегий 0
mov 	eax, 0
mov		ax, Task3_SS0
shl		eax, 4
mov		word ptr ds:[GDT_Task3_SS0+2], ax
shr		eax, 16
mov		byte ptr ds:[GDT_Task3_SS0+4], al
; LDT задачи 3
mov		ax, ds:[LDT3_Limit]
mov		word ptr ds:[GDT_Task3_LDT], ax
pop     eax
push    eax
add		eax, offset LDT3
mov		word ptr ds:[GDT_Task3_LDT+2], ax
shr		eax, 16
mov		byte ptr ds:[GDT_Task3_LDT+4], al

; Дескриптор сегмента данных задачи 3 в локальной таблице дескрипторов задачи 3
mov		ax, Task3_DS
mov		es, ax
mov		ax, es:[Task3_DS_Limit]
mov		word ptr ds:[LDT3_DS], ax
mov 	eax, 0
mov		ax, Task3_DS
shl		eax, 4
mov		word ptr ds:[LDT3_DS+2], ax
shr		eax, 16
mov		byte ptr ds:[LDT3_DS+4], al

; вычислить линейный адрес GDT
pop     eax     ; EAX - линейный адрес PM_data
push    eax
add     eax, offset GDT ; EAX - линейный адрес GDT
mov     dword ptr GDTr+2, eax   ; записать его в GDTr
; вычислить линейный адрес IDT
pop     eax     ; EAX - линейный адрес PM_data
add     eax, offset IDT ; EAX - линейный адрес GDT
mov     dword ptr IDTr+2, eax   ; записать его в IDTr
; загрузить GDT
lgdt    fword ptr GDTr
; загрузить IDT
lidt    fword ptr IDTr
; запретить аппаратные прерывания
cli
; и также NMI
mov     al, 8Fh         ; установка бита 7 в нем запрещает NMI
out     70h, al
jmp     $+2
mov     al,05h
out     71h,al
push    es
mov     ax,40h
mov     es,ax
mov     word ptr es:[67h],offset ret1
mov     word ptr es:[69h],cs
pop     es
; переинициализировать первый контроллер прерываний,
; с отображением Irq0 -> Int 20h ... Irq7 -> Int 27h
mov     dl, 20h
call    PicInit
; если мы собираемся работать с 32-битной памятью, стоит открыть A20
       mov     al,0D1h
       out     64h,al
       mov     al,0DFh
       out     60h,al
; перейти в защищенный режим
mov     eax, cr0        ; прочитать регистр CR0
or      al, 1   		; установить бит PE в нем
mov     cr0, eax
; код операции дальнего jmp к метке PM_entry:
; загрузить SEL_32bitCS в CS, смещение PM_entry в IP
db      66h     ; префикс изменения разрядности операнда
db      0EAh    ; код команды дальнего jmp
dd      offset PM_entry ; 32-битное смещение
dw      SEL_32bitCS     ; селектор


; -------------------- Корректное завершение программы ----------------------
; ----------------- после возврата из защищенного режима --------------------
RM_return:      ; сюда передается управление при выходе из защищенного режима
; перейти в реальный режим
;add me
mov     ax,SEL_R_MODE_DATA
mov     ss,ax
mov     ds,ax
mov     es,ax
        db     0EAh
        dw     offset  go
        dw     SEL_16bitCS
go:    mov     eax, cr0        ; прочитать регистр CR0
       and     eax, 0FFFFFFFEh ; сбросить бит PE в нем
       mov     cr0, eax
; сбросить очередь предвыборки и загрузить CS реальным сегментным адресом
        db      0EAh   ; код дальнего jmp
        dw      $+4    ; адрес следующей команды
        dw      RM_seg ; сегментный адрес RM_seg
; установить регистры для работы        в реальном режиме
;add me
mov     al,0FEh
out     64h,al
;hlt
ret1:   mov     ax, PM_data
mov     ds, ax
mov     es, ax
mov     ax, Stak_seg
mov     ss, ax
mov     sp, Stack_0
; загрузить IDTR для реального режима
       lidt    fword ptr IDTr_real
;A20_OFF
       mov     al,0D1h
       out     64h,al
       mov     al,0DDh
       out     60h,al
; переинициализировать первый контроллер прерываний в стандартное
; состояние (Irq0 -> Int 08h)
       mov     dl, 08h
       call    PicInit
;add me
mov     al,0B8h
out     21h,al
mov     al,9Dh
out     0A1h,al
; разрешить NMI
; индексный порт CMOS
mov     al, 0   ; сброс бита 7 отменяет блокирование NMI
out     70h, al
; разрешить прерывания
sti
; и выйти
;add me
mov     ax,RM_Seg
mov     ds, ax
mov     es, ax
mov     ah, 09h
mov     dx, offset mes
int     21h
mov     ax, 4C00h
int     21h

RM_seg  ENDS



END Start
