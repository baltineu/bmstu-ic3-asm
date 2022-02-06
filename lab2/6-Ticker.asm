MASM
MODEL small ; model pamyati
STACK 1000 ; razmer steka
.486p

delay macro time
local ext, iter
;makros zaderzhki

;na vhode - znachenie peremennoi zaderzhki (v mikrosecundach)
push cx
mov cx, time

ext:
push cx ;v CX odna mikrosecunda, eto znachenie mozhno pomenyat'
        ;v zavisimosti ot proizvoditel'nosti processora
mov cx, 5000

iter:
loop iter
pop cx
loop ext
pop cx

endm ;konez makrosa

.data

old_off8 dw 0 ;dlya chraneniya starich znachenii vektora
old_seg8 dw 0 ;segment i smesh'nie
time_1ch dw 0 ;peremennaya dlya peresh'eta

.code ;nachalo segmenta koda

off_1ch equ 1Ch*4 ;smesh'nie vektora 1Ch v TVP
massiv db '  1234';massiv simvolov
char dw 0 ;ukazatel na massiv simvolov
color db 05h ;zvet
cnt dw 0

main proc

mov ax,@data
mov ds, ax
xor ax, ax

cli ;zapret apparatnich prerivanii na vremya zameni vektorov prerivanii
;zamena starogo vektora 1Ch na adres new_1ch, nastroika ES na nachalo TVP
;v real'nom rezhime

mov ax, 0
mov es, ax ;sochranit' starii vektor
mov ax,es:[off_1ch] ;smesh'enie starogo vektora 1Ch v AX
mov old_off8, ax ;sochranenie smesh'enia v old_off8
mov ax, es:[off_1ch+2] ;segment starogo vektora 1Ch v AX
mov old_seg8, ax ;sochranenie segmenta v old_seg8

;zapis' novogo vektora v TVP
mov ax, offset new_1ch ;smesh'enie novogo obrabotchika v AX
mov es:off_1ch, ax
push cs
pop ax ;nastroika AX na CS
mov es:off_1ch+2, ax ;zapis' segmenta

sti ;razreshenie prerivanii

;zaderzhka dlya vipolnenia prerivaniya
delay 60000
;vosstanovlenie

cli

mov ax,0
mov ax, old_off8
mov es:[off_1ch], ax
mov ax, old_seg8
mov es:[off_1ch+2],ax

sti

exit:
mov ax, 4C00h
int 21h

main endp

new_1ch proc ; obrabotchik prerivaniya ot taimera

;sochranenie registrov v steke
inc cs:[cnt]
cmp cs:[cnt],18
jz call_int
jmp vihod

call_int:

Mov cs:[cnt], 0
push ax
push bx
push es
push ds
push cx
push dx

;nastroika DS na CS

push cs
pop ds

;zapis' v ES adresa nachala videopamyati B800:0000

mov bx, 0                               ; в каждой итерации вывод заново стартует с начала видеобуфера

METKA:                                  ; метка начала цикла вывода

mov ax, 0b800h                          ; сегмент видеобуфера b8000, адрес помещается в AX
mov es, ax                              ; сегментный регистр ES инициализируется адресом сегмента видеобуфера
mov ax, offset massiv                   ; смещение массива (massiv) помещается в регистр AX
add ax, char                            ; к смещению переменной massiv добавляется указатель (char) на текущий элемент массива
mov si, ax                              ; полученное смещение сохраняется в индексный регистр SI
mov al, ds:[si]                         ; сохранение кода символа из массива в AL
mov ah, color                           ; сохранение цвета символа в AH
mov es:[bx], ax                         ; вывод символа на экран
add bx, 2                               ; переход к следующей позиции на экране

inc char                                ; происходит инкрементация указателя
cmp char, 6                             ; сравнение значения указателя с 6 (выход за границы массива)
jne skip_zero                           ; если границы не нарушены, пропускается обнуление указателя
mov char, 0                             ; обнуление указателя

skip_zero:                              ; метка для пропуска обнуления указателя

cmp bx, 12                              ; условие окончания цикла (6 символов по 2 байта сохранены в видеобуфер)
jl METKA                                ; если условие не выполнено, цикл стартует заново

; подготовка к следующей итерации, в которой вывод стартует с символа, расположенного в массиве слева от начального символа этой итерации
dec char                                ; декремент указателя
cmp char, -1                            ; сравнение значения указателя с -1 (границы массива нарушены)
jne vyhod                               ; если границы не нарушены, прыжок на выход из процедуры обработки
mov char, 5                             ; если нарушены, указатель = 5 (крайний правый элемент массива)
jmp vyhod                               ; переход на выход из процедуры обработки прерывания

vyhod:

;vosstanovlenie registrov

pop ds
pop es
pop bx
pop ax
pop cx
pop dx

vihod:

iret

;vozvrat iz prerivaniya

new_1ch endp ;konez obrabotchika

end main ;konez programmi
