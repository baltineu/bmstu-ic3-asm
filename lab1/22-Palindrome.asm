ASSUME CS:MYCODE
ASSUME DS:MYDATA

MYDATA SEGMENT

MYSTR DB "PALINILAP",0
MYSTR2 DB "NOT PALINDROM",0

MYDATA ENDS

MYCODE SEGMENT

MYENTRY:
; INITSIALIZATSIYA SEGMENTNYH REGISTROV
MOV AX, MYDATA
MOV DS, AX		; DS --> MYDATA
MOV AX, 0B800H
MOV ES, AX      ; ES --> VIDEOBUFFER

; POLEZNAYA RABOTA
PODSCHET_INIT:
MOV SI, -1      ; SI - ukazatel po stroke 
MOV AL, 0       ; 0 - eto konets stroki

PODSCHET:
INC SI
CMP AL, DS:[SI] ; 
JNZ PODSCHET    ; esli ne konets stroki, eshe raz

SRAVNENIE_INIT:
MOV CX, SI      ; CX = LENGTH OF MYSTR

MOV BX, SI
SHR BX, 1       ; BX = LEN/2

MOV SI, 1       ; ukazatel po stroke

SRAVNENIE:
MOV AL, DS:[SI-1]   ; simvol is pervoi poloviny stroki
MOV DI, CX
SUB DI, SI          ; DI = CX - SI = LENGTH - SI
CMP AL, DS:[DI]     ; esli simvol is pervoi poloviny != simvol iz vtoroi
JNZ VYVOD_2_INIT    ; togda perehod na vyvod "NE PALINDROM"
INC SI              ; inache SI++
CMP SI, BX          ; sravnivaem SI i LEN/2
JLE SRAVNENIE       ; esli ne dostignuto, vozvrat na nachalo sravneniya

VYVOD_1_INIT:
MOV DI, 1           ; DI - POINTER FOR VIDEOBUFFER
MOV SI, 0           ; SI - POINTER FOR MEMORY (MYDATA SEGMENT BEGIN WITH MYSTR)

VYVOD_1:
MOV AH, 060H        ; 
MOV AL, DS:[SI]     ;

MOV ES:[DI-1], AX   ;
INC DI              ;
INC DI              ;

INC SI              ;
CMP SI, CX          ;
JNZ VYVOD_1         ;

JZ KONETS           ;

VYVOD_2_INIT:
MOV DI, 1           ; DI - POINTER FOR VIDEOBUFFER
MOV SI, 0          ; SI - POINTER FOR MEMORY (MYSTR2)

VYVOD_2:
MOV AH, 060H            ;
MOV AL, DS:[SI+MYSTR2]  ;

MOV ES:[DI-1], AX   ;
INC DI              ;
INC DI              ;

INC SI              ;
CMP SI, 13          ;
JNZ VYVOD_2         ;

JZ KONETS           ;

; ZAVERSHENIE PROGRAMMY
KONETS:         ;
MOV AX, 4C00H   ;
INT 21H         ;

MYCODE ENDS

END MYENTRY
