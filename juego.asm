.MODEL large
.STACK 100h

.DATA
    ; [DATA GRAFICOS]
    pantallaX               DW  320
    pantallaY               DW  200
    x                       DW  0
    y                       DW  0
    pantallaBorderSpace     EQU 8       ; cantidad de pixeles a los lados de los bordes para que los enemigos no se salgan de la pantalla

    ; [DATA SPRITES]
    handle          DW  ?                    ; Handle del archivo a leer
    spriteJugador   DB  '..\PLAYER.BIN', 0
    spriteBala      DB  '..\BULLET.BIN', 0
    spriteBrick     DB  '..\BRICK.BIN', 0

    ; [word x, word y, byte dir, byte size, byte[256] colors]
    buffJugador     DB  262 DUP (?) ; Buffer para leer bytes del jugador
    buffBala        DB  32  DUP (?) ; Buffer para leer bytes de la bala
    buffBrick       DB  22  DUP (?) ; Buffer para leer bytes de los ladrillos

    ; [DATA GAMEPLAY]
    tamUnidad           DW  8

    jugadorBalaOffset   EQU 00h     ; sin offset la bala spawnea en la esquina del sprite del jugador en vez del centro
    tiempoDeDisparo     EQU 1       ; 10 frames entre disparo del jugador
    disparoCoolDown     DB  0

    ; Informacion de cada bala en la escena [posX (WORD), posY (WORD), direccion (BYTE), desplazamiento (BYTE)]
    arrayBalas      DB  120 DUP (0Fh)
    arrayBalasLen   EQU 0014h   ; 50 en decimal (pueden haber maximo 50 balas en escena)
    balaDataLen     EQU 0006h   ; cada bala en el array de balas tiene 6 bytes de informacion

    ; Informacion de cada pared en la escena [word x, word y, byte type (0=destruida)]
    arrayParedesLen EQU 100
    paredDataLen    EQU 5

.DATA_BUFF_PANTALLA segment
    buffPantalla            DB  64000 DUP (0)
.DATA_BUFF_PANTALLA ends

.DATA_ARRAY_PAREDES segment
arrayParedes    DB  500 DUP (0)   ; Un array con capacidad para 2800 paredes
.DATA_ARRAY_PAREDES ends

.CODE
dibujarPantalla PROC
    mov AX, seg .DATA_BUFF_PANTALLA
    mov DS, AX
    assume DS:.DATA_BUFF_PANTALLA

    lea SI, buffPantalla

    
    mov AX, 0A000h           ; segmento de memoria de video
    mov ES, AX

    xor DI, DI              ; destino = inicio de VRAM
    mov CX, 32000           ; 320*200 = 64000 bytes → 32000 palabras
    rep movsw               ; copiar buffer (64 KB aprox)
    mov AX, @data
    mov DS, AX
    assume DS:@data
    
    ret
dibujarPantalla ENDP

limpiarPantalla PROC
    mov AX, seg .DATA_BUFF_PANTALLA
    mov ES, AX

    xor AX, AX

    lea DI, buffPantalla

    mov CX, 320*200         ; recorrer todos los pixeles
    rep stosb               ; llenar el buffer
    ret
limpiarPantalla ENDP

vSync PROC
    mov dx, 03DAh
    esperar_fuera:
        in al, dx
        test al, 08h
        jnz esperar_fuera
    esperar_dentro:
        in al, dx
        test al, 08h
        jz esperar_dentro
    ret
vSync ENDP

cargarObjeto PROC   ; DS:.DATA_SPRITES | DI = filename, SI = buffer'
    ;---------------------------------
    ; Abrir archivo
    ;---------------------------------
    mov AH, 3Dh          ; Función: Abrir archivo
    mov AL, 0            ; Modo lectura
    mov DX, DI
    int 21h
    jc  error_open
    mov handle, AX       ; Guardar handle

    ;---------------------------------
    ; Leer archivo
    ;---------------------------------
    mov AH, 3Fh          ; Función: Leer archivo
    mov BX, handle
    mov CX, 1024          ; Leer hasta 1024 bytes
    mov DX, SI
    int 21h
    jc  error_read
    mov SI, 0            ; Índice para el buffer
    mov DX, AX           ; Cantidad de bytes leídos

    ;---------------------------------
    ; Cerrar archivo
    ;---------------------------------
    close_file:
        mov AH, 3Eh
        mov BX, handle
        int 21h
        ret

    error_open:
    error_read:
        ; Si hay error, terminar
        jmp close_file

cargarObjeto ENDP

dibujarObjeto PROC ; SI = buffer
    mov BX, 0             ; Contador de píxeles
    mov CX, 0
    mov CL, [SI + 5]      ; Filas por recorrer

    mov AX, [SI + 2]
    mov y, AX             ; Fila inicial

    cld                   ; Incrementos positivos
    dibujarObjeto_filas:
        push CX
        mov CL, [SI + 5]      ; Columnas por recorrer

        mov AX, [SI]
        mov x, AX             ; Columna inicial

        dibujarObjeto_columnas:
            ; Calcular coordenadas (DX = y*320 + x)
            mov AX, y
            mul pantallaX         ; AX *= 320
            add AX, x
            mov DX, AX

            ; Dibujar píxel
            mov AL, [SI + BX + 6] ; Color del píxel
            push AX

            mov AX, seg .DATA_BUFF_PANTALLA
            mov DS, AX
            assume DS:.DATA_BUFF_PANTALLA

            pop AX
            lea DI, buffPantalla
            add DI, DX
            mov [DI], AL

            mov AX, @data
            mov DS, AX
            assume DS:@data
            
            inc BX
            inc x
        loop dibujarObjeto_columnas

        inc y
        pop CX
    loop dibujarObjeto_filas
    ret
dibujarObjeto ENDP

procesarInput PROC
    mov AH, 1h
    int 16h      ; verifica si hay una tecla presionada

    jz  .return  ; si no hay tecla, return

    mov AH, 00h
    int 16h     ; leer la tecla presionada. Se guarda en AL
    
    cmp AH, 48h                 ; flecha arriba
    je  .inputTeclaArriba
    cmp AL, 77h                 ; tecla 'w'
    je  .inputTeclaArriba

    cmp AH, 4Dh                 ; flecha derecha
    je  .inputTeclaDerecha
    cmp AL, 64h                 ; tecla 'd'
    je  .inputTeclaDerecha

    cmp AH, 50h                 ; flecha abajo
    je  .inputTeclaAbajo
    cmp AL, 73h                 ; tecla 's'
    je  .inputTeclaAbajo
    
    cmp AH, 4Bh                 ; flecha izquierda
    je  .inputTeclaIzquierda
    cmp AL, 61h                 ; tecla 'a'
    je  .inputTeclaIzquierda

    cmp AL, 20h                 ; barra espaciadora
    je  .inputTeclaDisparar

    jmp .return

    .inputTeclaArriba:
        lea SI, buffJugador
        
        mov AL, 0
        mov [SI + 4], AL        ; dir=0 -> arriba

        mov AX, [SI + 2]

        sub AX, tamUnidad
        mov [SI + 2], AX
        jmp .return

    .inputTeclaDerecha:
        lea SI, buffJugador
        
        mov AL, 1
        mov [SI + 4], AL        ; dir=1 -> derecha

        mov AX, [SI]
        add AX, tamUnidad
        mov [SI], AX
        jmp .return
        
    .inputTeclaAbajo:
        lea SI, buffJugador

        mov AL, 2
        mov [SI + 4], AL        ; dir=2 -> abajo
        
        mov AX, [SI + 2]
        add AX, tamUnidad
        mov [SI + 2], AX
        jmp .return

    .inputTeclaIzquierda:
        lea SI, buffJugador

        mov AL, 3
        mov [SI + 4], AL        ; dir=3 -> izquierda
        
        mov AX, [SI]
        sub AX, tamUnidad
        mov [SI], AX
        jmp .return
    
    .inputTeclaDisparar:
        cmp disparoCoolDown, 0
        jne .return                 ; solo disparar si el cooldown terminó
        
        mov disparoCoolDown, tiempoDeDisparo    ; resetear cooldown

        lea DI, buffJugador
        mov AX, [DI]
        mov DX, [DI + 2]
        mov CH, [DI + 4]
        mov CL, 8
        mov SI, jugadorBalaOffset
        call dispararBala   ; AX = posX, DX = posY, CH = dir, CL = disp, SI = spawnOffset
        jmp .return

    .return:
        ret
procesarInput ENDP

calcDisparoCoolDown PROC
    cmp disparoCoolDown, 0
    je  calcDisparoCoolDown_return

    dec disparoCoolDown

    calcDisparoCoolDown_return:
    ret
calcDisparoCoolDown ENDP

dispararBala PROC   ; AX = posX, DX = posY, CH = dir, CL = disp, SI = spawnOffset
    ; la idea es iterar por todo el array de balas hasta encontrar un campo libre
    ; si no encuentra uno en porque ya hay 50 balas en pantalla (demasiadas)
    lea DI, arrayBalas
    mov BX, -balaDataLen
    dispararBala_siguienteBala:
        add BX, balaDataLen

        cmp BX, balaDataLen * arrayBalasLen
        jge dispararBala_return     ; si ya iteramos por todas la balas y no encontramos un espacio libre: return

        push AX
        mov AH, [DI + BX + 4]       ; AH = bala.dir
        cmp AH, 0Fh
        pop AX
        jne  dispararBala_siguienteBala     ; if (espacio_en_uso) continue

        add AX, SI
        mov [DI + BX], AX       ; arrayBalas[indexBala].posX = posX

        mov [DI + BX + 2], DX   ; arrayBalas[indexBala].posY = posY

        ; dir=0 -> sube,
        ; dir=1 -> derecha
        ; dir=2 -> baja
        ; dir=3 -> izquierda
        mov [DI + BX + 4], CH

        ; set desplazamiento
        mov [DI + BX + 5], CL
    
    dispararBala_return:
    ret
dispararBala ENDP

dibujarBalas PROC
    mov CX, -1
    dibujarBalas_forEach_bala:
        inc CX                      ; balaIndex++

        cmp CX, arrayBalasLen
        jge dibujarBalas_return     ; si ya iteramos por todas la balas y no encontramos un espacio libre: return

        mov AX, CX
        mov BX, balaDataLen
        mul BX
        mov BX, AX                  ; offset bala

        lea DI, arrayBalas
        lea SI, buffBala

        mov AH, [DI + BX + 4]   ; AH = bala.dir
        mov AL, [DI + BX + 5]   ; AL = bala.desp

        cmp AH, 0Fh
        je  dibujarBalas_forEach_bala           ; saltarse las balas desactivadas
        
        cmp AH, 0               ; dir=0 -> subir
        je  dibujarBalas_subir
        cmp AH, 1               ; dir=1 -> derecha
        je  dibujarBalas_derecha
        cmp AH, 2               ; dir=2 -> bajar
        je  dibujarBalas_bajar
        cmp AH, 3               ; dir=3 -> izquierda
        je  dibujarBalas_izquierda

        ; aplicar desplazamiento cuando bala.dir = 0
        dibujarBalas_subir:
        mov AH, 0
        sub [DI + BX + 2], AX
        jmp dibujarBalas_actualizarBuffer

        ; aplicar desplazamiento cuando bala.dir = 1
        dibujarBalas_derecha:
        mov AH, 0
        add [DI + BX], AX
        jmp dibujarBalas_actualizarBuffer

        ; aplicar desplazamiento cuando bala.dir = 2
        dibujarBalas_bajar:
        mov AH, 0
        add [DI + BX + 2], AX
        jmp dibujarBalas_actualizarBuffer

        ; aplicar desplazamiento cuando bala.dir = 3
        dibujarBalas_izquierda:
        mov AH, 0
        sub [DI + BX], AX
        jmp dibujarBalas_actualizarBuffer


        dibujarBalas_actualizarBuffer:
        mov AX, [DI + BX]       ; AX = bala.posX
        mov [SI], AX            ; buffBala.posX = bala.posX

        mov AX, [DI + BX + 2]   ; AX = bala.posY
        cmp AX, pantallaBorderSpace
        jl  dibujarBalas_desactivarBala ; if (bala.posY < 10) desactivar.

        mov DX, pantallaY
        sub DX, pantallaBorderSpace
        cmp AX, DX
        jg  dibujarBalas_desactivarBala ; if (bala.posY > 200) desactivar.

        mov AX, [DI + BX]   ; AX = bala.posX
        cmp AX, pantallaBorderSpace
        jl  dibujarBalas_desactivarBala ; if (bala.posX < 10) desactivar.

        mov DX, pantallaX
        sub DX, pantallaBorderSpace
        cmp AX, DX
        jg  dibujarBalas_desactivarBala ; if (bala.posX > 320) desactivar.

        mov AX, [DI + BX]
        mov [SI], AX            ; buffBala.posX = bala.posX

        mov AX, [DI + BX + 2]
        mov [SI + 2], AX        ; buffBala.posY = bala.posY

        push CX
        call dibujarObjeto
        pop CX

        jmp dibujarBalas_forEach_bala

        dibujarBalas_desactivarBala:
        mov [DI + BX + 4], 0Fh

    jmp dibujarBalas_forEach_bala

    dibujarBalas_return:
    ret
dibujarBalas ENDP

dibujarParedes PROC
    mov CX, -1
    dibujarParedes_forEach_pared:
        inc CX
        cmp CX, arrayParedesLen
        jge dibujarParedes_return          ; salir del ciclo si ya iteramos sobre todas las paredes del array

        mov AX, paredDataLen
        mov BX, CX
        mul BX
        mov BX, AX                          ; BX = paredIndex

        mov AX, seg .DATA_ARRAY_PAREDES
        mov DS, AX
        assume DS:.DATA_ARRAY_PAREDES

        lea DI, arrayParedes
        mov AH, [DI + BX + 4]               ; AH = tipo de pared

        mov AX, @data
        mov DS, AX
        assume DS:@data

        cmp AH, 0
        je  dibujarParedes_forEach_pared    ; Si el tipo de pared = 0, entonces significa que está destruida. NO hay que dibujarla.

        ; Si la pared sí existe, hay que determinar cual buffer usar para dibujar su sprite correctamente
        cmp AH, 1                           ; tipo 1 = brick
        je  dibujarParedes_typeBrick


        dibujarParedes_typeBrick:
        lea SI, buffBrick
        jmp dibujarParedes_dibujar


        dibujarParedes_dibujar:
        mov AX, seg .DATA_ARRAY_PAREDES
        mov DS, AX
        assume DS:.DATA_ARRAY_PAREDES
        mov AX, [DI + BX]                   ; AX = arrayParedes[paredIndex].posX
        mov DX, [DI + BX + 2]               ; DX = arrayParedes[paredIndex].posY

        mov AX, @data
        mov DS, AX
        assume DS:@data
        mov [SI], AX                        ; buffBarrera.posX = AX
        mov [SI + 2], DX                    ; buffBarrera.posY = DX

        push CX
        call dibujarObjeto
        pop CX

        jmp dibujarParedes_forEach_pared
    
    dibujarParedes_return:
    ret
dibujarParedes ENDP


main PROC
    mov AX, @data
    mov DS, AX

    ; Cambiar a modo de video 13h (320x200, 256 colores)
    mov AX, 0013h
    int 10h
    
    ;-------------------;
    ; PRECARGAR SPRITES ;
    ;-------------------;
    lea DI, spriteJugador
    lea SI, buffJugador
    call cargarObjeto

    lea DI, spriteBala
    lea SI, buffBala
    call cargarObjeto

    lea DI, spriteBrick
    lea SI, buffBrick
    call cargarObjeto

    ;-------;
    ; JUEGO ;
    ;-------;
    main_loop:
        call vSync
        call dibujarPantalla

        ; call updateGUI

        call limpiarPantalla

        call procesarInput

        lea SI, buffJugador
        call dibujarObjeto

        call dibujarBalas

        call dibujarParedes

        call calcDisparoCoolDown
    
    jmp main_loop
    game_over:

    ; volver al modo texto
    mov AX, 0003h
    int 10h

    ; Terminar programa
    mov AH, 4Ch
    int 21h
main ENDP
END main