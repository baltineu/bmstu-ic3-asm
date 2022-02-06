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
position1 dw 0 ;nachalnaya pozizia na ekrane
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

mov bx, position1

METKA:

mov ax, 0b800h
mov es, ax
mov ax, offset massiv ;ukazatel' v si
add ax, char
mov si, ax
mov al, ds:[si] ;simvol v al
mov ah, color ;zvet v ah
mov es:[bx], ax ;vivod simvola na ekran
add bx, 2 ;переход к следующей позиции

inc char ;sleduush'ii simvol
cmp char, 6 ;proverka na simvol 5
jne symbol2
mov char, 0
jmp symbol2

symbol2:

cmp bx, 12
jl METKA

dec char ;
cmp char, -1 ;
jne symbol3
mov char, 5
jmp symbol3

symbol3:

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
