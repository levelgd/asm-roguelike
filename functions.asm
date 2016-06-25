; EXIT
; CLS
; HIDE_CURSOR
; CURRENT_VIDEOPAGE
; ADDR_VIDEO_XY
; DRAW_DEC
; RANDOM_SEED
; RANDOM
; RND
; DELAY
; DELAY_MS
;----------------------------------------------------------------------------
proc EXIT ;выход в ДОС
; <
; >
	mov ah,04Ch
	int 21h
endp
;----------------------------------------------------------------------------
proc CLS ;очистка экрана
; <
; >
	push AX
	push BX
	push CX
	push DX
	mov ah,06h
	xor al,al
	mov BH,0fh ;атрибут для добавляемых при прокрутке строк
	xor CX,CX  ;в СХ - координаты верхнего левого угла окна.
	mov dh,24d ;координаты нижнего правого угла окна.
	mov dl,79d
	int 10h
	pop DX
	pop CX
	pop BX
	pop AX
	ret
endp
;----------------------------------------------------------------------------
proc HIDE_CURSOR ;скрывает курсор
; <
; >
	push AX
	push BX
	push DX
	mov dx,1900h ;ставим курсор на 25 строку, чтобы скрыть его
	xor bh,bh;call CURRENT_VIDEOPAGE ;номер видеостраницы
	mov ah,02h
	int 10h
	pop DX
	pop BX
	pop AX
	ret
endp
;----------------------------------------------------------------------------
proc CURRENT_VIDEOPAGE
; <
; > bh - активная видеостраница
	push AX
	mov ah,0fh
	int 10h
	pop AX
	ret
endp
;----------------------------------------------------------------------------
proc ADDR_VIDEO_XY ; получаем адрес в видеопамяти, соответствующий позиции х,у в текстовом режиме 80x25
; < dl - x, dh - y
; > di - нужный адрес, точнее смещение
	push AX BX DX CX

	shl dl,01d ;тут используем смещение как умножение на 2 (2 байта, символ+атрибут)
;используем формулу (dl*2)+(dh*160), т.е. типа двумерного массива - столбец*2байта + строк*160 байт (одна строка из 80 символов занимает 160 байт)
	mov al,dh
	mov bl,160d	;80*2
	mul bl	;al*bl, результат уходит в AX

	mov di,AX
	xor dh,dh
	add di,DX	;готово

	pop CX DX BX AX
	ret
endp
;----------------------------------------------------------------------------
proc DRAW_DEC ;число в текст, выводится в видеопамять по смещению DI
; < ah - значение
; >
	push AX BX CX DX
	xor CX, CX
	mov BX, 10d
split:
	xor DX, DX
	div BX
	mov dh,0eh ;цвет
	push DX
	inc CX
	cmp AX, 00h
	jnz split
print:
	pop AX
	add AX, 30h ;в dl символ
	stosw
	dec CX
	jnz print
	pop DX CX BX AX
	ret
endp
;----------------------------------------------------------------------------
proc RANDOM_SEED ;генерация seed
	push EAX
	push DS
	push 00h
	pop DS
	mov EAX,[DS:046Ch]	;таймер располагается по адресу 0000:046Ch
	pop DS ;возвращаем значение сегментного регистра, указывающего на data_segment здесь, иначе seed не найдем
	mov [seed],EAX
	pop EAX
	ret
endp
;----------------------------------------------------------------------------
proc RANDOM ;алгоритм Парка-Миллера
; <
; >
	push EDX ECX
	mov EAX,[seed]
	xor EDX,EDX
	mov ECX,127773d
	div ECX
	mov ECX,EAX
	mov EAX,16807d
	mul EDX
	mov EDX,ECX
	mov ECX,EAX
	mov EAX,2836d
	mul EDX
	sub ECX,EAX
	xor EDX,EDX
	mov EAX,ECX
	mov [seed],ECX
	mov ECX,100000d
	div ECX
	mov EAX,EDX
	pop ECX EDX
	ret
endp
;----------------------------------------------------------------------------
proc RND
; < параметры берутся из памяти, как в UNYTI Random.Range([rmin], [rmax])
; > EAX - значение
	push EDX ECX
	mov ECX,[rmax]
	sub ECX,[rmin]
	inc ECX
	call RANDOM
	xor EDX,EDX
	div ECX
	mov EAX,EDX
	add EAX,[rmin]
	pop ECX EDX
	ret
endp
;----------------------------------------------------------------------------
proc DELAY
; <
; >
	mov AX,60000d
delay: 
	dec AX
	cmp AX,00d
	jne delay

	mov ah,0ch ;обнуляем буфер клавиатуры
	int 21h
	ret
endp
;----------------------------------------------------------------------------
proc DELAY_MS
; < AX - задержка в миллисекундах
; >
	push AX DX CX DI SI
	mov	AX,100d 
    mov	DX,1024d
    imul DX 
    mov CX,DX 
    mov DX,AX 
    mov ah,86h 
    int 15h
	
	mov ah,0ch
	int 21h
	
	pop SI DI CX DX AX
	ret
endp