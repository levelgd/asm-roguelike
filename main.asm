; "игра" написана в 2012 году,после чего functions.asm был утерян. Наконец, в 2016 году нашлись силы заново написать нужные процедуры.

	format mz
	heap	0
	stack 128h
	entry code_segment:start
;-----------------------------------------------------------------------------
include 'proc16.inc'
;-----------------------------------------------------------------------------
segment code_segment use16
;-----------------------------------------------------------------------------
; MAIN
; KEYBOARD
; DRAW_STAGE
; DRAW_HERO
; DRAW_HUD
; CHANGE_VIDEOPAGE
; WORLD_TO_STAGE
; DRAW_VERTICAL
; COLLISION
; CONSOLE_LOG
; COPY_LINE
; WORLD_ADDR
; WINEND
;-----------------------------------------------------------------------------
start:
    mov AX,data_segment
    mov DS,AX
    xor AX,AX
    push world_segment
    pop FS ;в запасе есть еще GS

	call RANDOM_SEED
    call MAIN
;*****************************************************************************
proc MAIN
; <
; >
	mov al,03h
	int 10h
	;заливка рандомными символами
	mov BX,40000d
genloop:
	dec BX
	call RND
	cmp al,7fh
	jne genmov
	dec al
genmov:
	mov [FS:world+BX],al
	cmp BX,00h
	jne genloop
	
	mov SI,message
	call CONSOLE_LOG
mainloop:
	cmp [moves],10d
	jne nomission
	mov SI,mission
	call CONSOLE_LOG
nomission:
	cmp [score],5d
	jne nocomplete
	cmp [missionf],1d
	je nocomplete
	mov [missionf],1d
	mov SI,complete
	call CONSOLE_LOG
	pusha
	call RND
	mov [door_x],AX
	mov dl,al
	call RND
	mov [door_y],AX
	xor ah,ah

	call WORLD_ADDR
	mov [FS:world+BX],7fh

	popa
nocomplete: 

	call WORLD_TO_STAGE
	call DRAW_STAGE
	call DRAW_HERO
	call DRAW_HUD

	call CHANGE_VIDEOPAGE
	call HIDE_CURSOR

	mov AX,50d
	call DELAY_MS

	call KEYBOARD

	jmp mainloop
endp
;-----------------------------------------------------------------------------
proc KEYBOARD ;обработка нажатий клавиш
; <
; >
	push AX
	mov ah,00h			; int 16 ah 00 - чтение символа с клавиатуры
	int 16h				; выход: ah - сканкод, al - ASCII
	cmp ah,01h			;ESC
	je ext
	cmp ah,48h			;стрелка вверх
	je up
	cmp ah,4Bh			;стрелка влево
	je left
	cmp ah,4Dh			;стрелка вправо
	je right
	cmp ah,50h			;стрелка вниз
	je down

bspret: ;Если нажата необрабатываемая клавиша то выполняется этот код
	pop AX
	ret
ext:
	call EXIT			; выход в дос
up: 
	cmp [hero_y],9d		;если игрок у края карты
	je bspret
	dec [hero_y]
	call COLLISION
	inc [moves]
	jmp bspret
down: 
	cmp [hero_y],189d
	je bspret
	inc [hero_y]
	call COLLISION
	inc [moves]
	jmp bspret
left: 
	cmp [hero_x],10d
	je bspret
	dec [hero_x]
	call COLLISION
	inc [moves]
	jmp bspret
right: 
	cmp [hero_x],190d
	je bspret
	inc [hero_x]
	call COLLISION
	inc [moves]
	jmp bspret
endp
;памятка по атрибутам
;0-черный, 1-синий, 2-зеленый, 3-циановый, 4-красный, 5-фиолетовый, 6-коричневый, 7-белый, 8-серый, 9-голубой, A-светло-зеленый, B-светло-циановый, C-розовый, D-светло-фиолетовый, E-желтый, F-белый
;0f - фон/цвет
;-----------------------------------------------------------------------------
proc DRAW_STAGE ;рисуем видимую часть карты
; <
; >
	pusha

	call CURRENT_VIDEOPAGE	;проверяем какая видеостраница текущая.
	cmp bh,00h				;если нулевая - пишем графон в первую
	jne set00h				;если нет - пишем в нулевую
	push 0b900h				;адрес первой страницы видеопамяти
	pop es 					;заносим его в ес
	inc bh 					;получается 1
	jmp set01				;готово
set00h: 
	push 0b800h				; адрес нулевой страницы видеопамяти
	pop es
	dec bh 					;получается 0
set01: 

	xor DX,DX		;очистка экрана
	call ADDR_VIDEO_XY
	mov [videopage],bh	;заносим в переменную с номером страницы, которую покажем в конце отрисовки
	mov AX,0f20h		;пробел с атрибутом (атрибут/символ)
	mov CX,2000d		;80*25
	rep stosw			;2000 по 2 байта = 4000 байт

	mov dl,02d			;х
	mov dh,01d			;у
	call ADDR_VIDEO_XY	;выставляем "курсор" на нужное место

	mov CX,20d			;сколько строк выводить, счетчик для nextline
	xor BX,BX			;чтоб считать от начала массива stage
nextline: 
	push CX
	mov CX,20d			;это счетчик для цикла linedraw
linedraw: 
	mov ah,08h			;серый
	mov al,[stage+BX]	;читаем из массива
	cmp al,'$'
	je green
	cmp al,7fh
	je brown
	jmp draw
green: 
	mov ah,02h
	jmp draw
brown: 
	mov ah,06h
	;jmp draw
draw: 
	stosw			;пишем в видеопамять символ с атрибутом, di +2 байта автоматом
	mov AX,0f20h		;пробел
	stosw			;высота символа в 2 раза больше ширины, чтоб экран был квадратный выводим пробелы между символами по ширине
	add BX,1d		;di на 2 байта увеличивается, BX 1
	loop linedraw
	add di,80d		;длина одной строки 80 символов умножить на 2 байта = 160 байт, тут 40 символов нарисовали - осталось 80 байт, которые добавляем к di для перевода на новую строку
	pop CX 		;в стеке сохраняли СХ счетчик для цикла nextline
	loop nextline

	popa
	ret
endp
;-----------------------------------------------------------------------------
proc DRAW_HERO ;рисуем героя
; <
; >
	push AX DX
	mov dl,22d	
	mov dh,10d
	call ADDR_VIDEO_XY
	mov AX,0e40h
	stosw
	pop DX AX
	ret
endp
;-----------------------------------------------------------------------------
proc DRAW_HUD ;рисуем стату и прочие менюшки
; <
; >
	pusha

	mov dh,24d
	mov dl,00d
	call ADDR_VIDEO_XY	;на нижней строке выводим "Esc - выход, стрелки - перемещение."
 
	mov ah,0Eh		;так как строка состоит только из букв (без атрибутов), атрибут проставляем вручную
	mov al,'>'
	stosw
	add DI,2d

	mov SI,line3
	call DRAW_MESSAGE

	mov dh,23d
	mov dl,02d
	call ADDR_VIDEO_XY
	mov ah,0Fh
	mov SI,line2
	call DRAW_MESSAGE

	mov dh,22d
	mov dl,02d
	call ADDR_VIDEO_XY
	mov ah,08h
	mov SI,line1
	call DRAW_MESSAGE

	mov ah,0Fh
	mov DX,012ch
	call ADDR_VIDEO_XY
	mov al,'X'
	stosw
	add DI,2d

	xor AX,AX
	mov al,[hero_x]
	call DRAW_DEC
 
	mov DX,032Ch
	call ADDR_VIDEO_XY
	mov al,'Y'
	mov ah,0Fh
	stosw
	add di,2d

	xor AX,AX
	mov al,[hero_y]
	call DRAW_DEC

	mov DX,052Ch
	call ADDR_VIDEO_XY
	mov al,'$'
	mov ah,0Fh
	stosw
	add di,2d

	xor AX,AX
	mov al,[score]
	call DRAW_DEC

	mov DX,072Ch
	call ADDR_VIDEO_XY
	mov ah,0Fh 
	mov SI,shagov
	call DRAW_MESSAGE
	mov AX,[moves]
	call DRAW_DEC

	mov DX,092Ch
	call ADDR_VIDEO_XY 
	mov AX,[door_x]
	call DRAW_DEC
	mov DX,0a2Ch
	call ADDR_VIDEO_XY 
	mov AX,[door_y]
	call DRAW_DEC

	xor DX,DX		;рамки
	call ADDR_VIDEO_XY
	mov al,218d ;Г
	mov ah,08h
	stosw
	mov al,196d ;-
	
	mov CX,41d
	rep stosw
	
	mov dh,21d
	mov dl,00d
	call ADDR_VIDEO_XY
	mov al,192d ;L
	stosw
	mov al,196d ;-
	
	mov CX,41d
	rep stosw

	mov al,191d ;`|
	xor DX,DX
	mov dl,42d
	call ADDR_VIDEO_XY
	stosw
	
	mov al,217d ;_|
	mov dl,42d
	mov dh,21d
	call ADDR_VIDEO_XY
	stosw

	mov al,179d

	mov DX,0100h
	call DRAW_VERTICAL

	mov DX,012Ah
	call DRAW_VERTICAL
	
	popa
	ret
endp
;-----------------------------------------------------------------------------
proc CHANGE_VIDEOPAGE	;реализация двойной буферизации
; <
; >
   push AX
   mov ah,05h
   mov al,[videopage]	;в videopage - номер страницы на которую нужно переключиться, не номер текущей
   int 10h
   pop AX
   ret
endp
;-----------------------------------------------------------------------------
proc WORLD_TO_STAGE ;копирование из карты мира в массив для вывода на экран
; <
; >
	pusha
	push DI

	mov dl,[hero_x]	
	mov al,[hero_y]
	sub dl,10d		;получаем верхний левый угол, герой то в центре
	sub al,09d

	call WORLD_ADDR

	xor AX,AX
	xor DX,DX
	xor di,di

	mov CX,20d
nextline2: 
	push CX
	mov CX,20d
linecopy2: 
	mov dh,[fs:world+BX]
	mov [stage+di],dh
	inc di
	inc BX
	loop linecopy2
	add BX,180d
	pop CX
	loop nextline2

	pop di
	popa
	ret
endp
;-----------------------------------------------------------------------------
proc DRAW_VERTICAL ;рамка
; <
; >
	push CX
	call ADDR_VIDEO_XY
	mov CX,20d
drwvert: 
	stosw
	add di,158d
	loop drwvert
	pop CX
	ret
endp
;-----------------------------------------------------------------------------
proc COLLISION		;обработка столкновений героя с объектами
; <
; >
	push DX BX

	mov dl,[hero_x]
	mov al,[hero_y]

	mov bl,200d	
	mul bl
	mov BX,AX
	xor dh,dh
	add BX,DX				;world + stage

	mov dh,[fs:world+BX]
	cmp dh,'$'
	je find$
	cmp dh,7fh				;символ "двери"
	je win
	jmp nocoll
find$: 
	mov [fs:world+BX],' '
	inc [score]
	mov SI,finddollar
	call CONSOLE_LOG
	jmp nocoll
win: 
	call WINEND
nocoll: 
	mov AX,00h

	pop BX DX
	ret
endp
;-----------------------------------------------------------------------------
proc CONSOLE_LOG ;в консоль выводится новая строка, старые смещаются на одну строку вверх
; <	 SI - указатель на новое сообщение
; >
	push SI
	mov SI,line2		;откуда
	mov DI,line1		;куда
	call COPY_LINE
	mov SI,line3		;откуда
	mov DI,line2		;куда 
	call COPY_LINE
	pop SI				;откуда
	mov DI,line3		;куда
	call COPY_LINE
	ret
endp
;-----------------------------------------------------------------------------
proc COPY_LINE ;копирует строку из одного массива в другой
; <	 SI - откуда, DI - куда
; >
	push AX BX CX
	mov CX,78d				;длина строки на вывод. Отступ - 2 позиции.
	xor BX,BX				;смещение
copy: 
	mov al,[SI+BX]			;читаем символ с массива откуда копируем
	cmp al,127d				;конец строки?
	je toend
	mov [DI+BX],al			;не конец - копируем символ в строку-назначение
	inc BX					;переводим "курсор" вправо
	loop copy
toend:					;если конец строки - заполняем пробелами
	mov byte [DI+BX],127d	;но сперва поставим знак конца строки
	inc BX
endcopy: 
	mov byte [DI+BX],032d	;фигачим пробелы
	inc BX
	loop endcopy			;до конца строки
	pop CX BX AX
	ret
endp
;-----------------------------------------------------------------------------
proc DRAW_MESSAGE
; <	 SI - адрес со строкой на вывод
; >
	push AX BX
	xor BX,BX
nxtchar:
	mov al,[SI+BX]
	cmp al,127d
	je stringclose
	stosw
	inc BX
	jmp nxtchar
stringclose: 
	pop BX AX
	ret
endp
;-----------------------------------------------------------------------------
proc WORLD_ADDR
; < dl - x, al - y
; > ВХ - смещение
	mov bl,200d
	mul bl

	mov BX,AX
	xor dh,dh
	add BX,DX
	ret
endp
;-----------------------------------------------------------------------------
proc WINEND
; <
; >
	mov SI,winmessage
	call CONSOLE_LOG
	call WORLD_TO_STAGE
	call DRAW_STAGE
	call DRAW_HERO
	call DRAW_HUD
	call CHANGE_VIDEOPAGE
	call HIDE_CURSOR
	call EXIT
endp
;-----------------------------------------------------------------------------
include 'functions.asm'
;-----------------------------------------------------------------------------
segment data_segment use16
	stage db 400d dup (?) ;массив 25х25 с видимой областью экрана
	hero_x db 100d
	hero_y db 100d
	score db 00d
	moves dw 00h
	videopage db 00h

	door_x dw 00h
	door_y dw 00h

	seed dd 00h
	rmax dd 180d
	rmin dd 11d

	missionf db 00d
	mission db '5 baksov needed',127d
	complete db 'find door!',127d

	message db 'Esc - exit, arrows - move',127d
	finddollar db 'You find one dollar',127d
	winmessage db 'WIN',127d
	shagov db 'Moves: ',127d
	;сообщения в консоли
	line1 db 77d dup (' '),127d
	line2 db 77d dup (' '),127d
	line3 db 77d dup (' '),127d
;-----------------------------------------------------------------------------
segment world_segment use16
	world db 40000d dup (?) ;200х200,
;-----------------------------------------------------------------------------
