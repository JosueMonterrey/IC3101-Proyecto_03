.MODEL large
.STACK 100h

.DATA
    ; [DATA GRAFICOS]
    pantallaX               EQU  320
    pantallaY               EQU  200
    x                       DW  0
    y                       DW  0
    pantallaBorderSpace     EQU 0       ; cantidad de pixeles a los lados de los bordes para que los enemigos no se salgan de la pantalla

    ; [DATA SPRITES]
    handle          DW  ?                    ; Handle del archivo a leer
    spriteJugador   DB  '..\PLAYER.BIN', 0
    spriteBala      DB  '..\BULLET.BIN', 0
    wallsDataPath   DB  '..\WALLS.BIN', 0
    spriteBrick     DB  '..\BRICK.BIN', 0
    spriteSteel     DB  '..\STEEL.BIN', 0
    spriteBush      DB  '..\BUSH.BIN', 0
    spriteEnemigo1  DB  '..\ENEMY1.BIN', 0

    ; [word x, word y, byte dir, byte size, byte[256] colors]
    buffJugador     DB  1030    DUP (?) ; Buffer para leer bytes del jugador
    buffEnemigo1    DB  1030    DUP (?) ; Buffer para leer bytes del enemigo1
    buffBala        DB  32      DUP (?) ; Buffer para leer bytes de la bala
    buffBrick       DB  262     DUP (?) ; Buffer para leer bytes de los ladrillos
    buffSteel       DB  262     DUP (?) ; Buffer para leer bytes del metal
    buffBush        DB  262     DUP (?) ; Buffer para leer bytes de los arbustos

    ; [DATA GAMEPLAY]
    frameCounter        DW  0000h
    fps                 EQU  30
    tamUnidad           EQU  0008h

    jugadorBalaOffset   EQU 00h     ; sin offset la bala spawnea en la esquina del sprite del jugador en vez del centro
    tiempoDeDisparo     EQU 1       ; 10 frames entre disparo del jugador
    disparoCoolDown     DB  0

    ; Informacion de cada bala en la escena [posX (WORD), posY (WORD), direccion (BYTE), desplazamiento (BYTE), idTirador (WORD)]
    arrayBalas      DB  400 DUP (0Fh)
    arrayBalasLen   EQU 0014h   ; 50 en decimal (pueden haber maximo 50 balas en escena)
    balaDataLen     EQU 0008h   ; cada bala en el array de balas tiene 6 bytes de informacion

    ; Informacion de cada pared en la escena [word x, word y, byte type (0=destruida)]
    wallsData       DB  1000 DUP (?) ; Matris de 40*25
    wallsDataColLen EQU 40
    wallsDataRowLen EQU 25
    wallSizePixels  EQU 8
    arrayParedesLen EQU 1000
    paredDataLen    EQU 5

    enemigoSpawnX       EQU 150     ; posX del spawn de los enemigos
    enemigoSpawnY       EQU 16      ; posY del spawn de los enemigos
    tiempoEnemigoSpawn  EQU 2       ; segundos entre cada intento de spawn
    tiempoSpawnActual   DW  0       ; timer para spawnear un enemigo
    maxEnemigosVivos    EQU 5       ; cuantos enemigos pueden existir al mismo tiempo en un nivel
    enemigosEnNivel     EQU 20      ; cuantos enemigos en total hay que matar para pasar el nivel
    cantSpawneados      DB  0       ; cantidad de enemigos spawneados
    enemigosVivos       DB  0       ; cuantos enemigos hay vivos en este momento
    ; Informacion de cada enemigo en la escena [posX (WORD), posY (WORD), direccion (BYTE), tipo (BYTE, 0=muerto), vidas (BYTE), velocidad(BYTE), disparoCooldown (WORD)]
    arrayEnemigos       DB  50
    enemigoDataLen      EQU 10       ; cada enemigo utiliza 8 bytes de informacion en el array de enemigos
    arrayEnemigosLen    EQU 5       ; hay maximo 5 enemigos en el array
    cooldownEnemigo1    EQU 50       ; cooldown para el disparo de los enemigos de tipo 1
    cambioDirRandom     EQU 8       ; probabilidad x/256 de que un enemigo cambie aleatoriamente de direccion

.DATA_BUFF_PANTALLA segment
    buffPantalla            DB  64000 DUP (0)
.DATA_BUFF_PANTALLA ends

.CODE
byteAleatorio PROC  ; ret: AL = byte aleatorio
    in AL, 40h       ; lee el contador del temporizador
    mov AH, AL
    in AL, 40h       ; léelo de nuevo (más mezcla)
    xor AL, AH

    ret
byteAleatorio ENDP

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

cargarObjeto PROC   ; DI = filename, SI = buffer
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
    mov CX, 1030          ; Leer hasta 1030 bytes
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

dibujarObjeto PROC  ; SI = buffer
    ;--------------;
    ; Cargar datos ;
    ;--------------;
    mov AX, [SI]
    mov CX, AX              ; CX = posX

    mov AX, [SI + 2]
    mov BP, AX              ; BP = posY

    xor BX, BX
    mov BL, [SI + 5]        ; BX = columnas
    mov DX, BX              ; DX = filas
    
    ;------------------------------------;
    ; Elejir sprite rotado correctamente ;
    ;------------------------------------;
    push BX
    push DX

    mov AX, BX              ; AX = columnas
    mul DX                  ; AX = columnas * filas

    xor BX, BX
    mov BL, [SI + 4]        ; BL = obj.dir
    mul BX                  ; AX = dir * columnas * filas

    add SI, 6               ; compensar por los 6 bytes de datos al inicio del buffer
    add SI, AX              ; avanzar AX pixeles hasta apuntar al inicio del sprite deseado
    ; ahora SI apunta al array de pixeles

    pop DX
    pop BX

    ;------------------------;
    ; Preparar buff pantalla ;
    ;------------------------;
    push DS                             ; guardar momentaneamente el segmento de data

    mov AX, seg .DATA_BUFF_PANTALLA
    mov DS, AX                          ; apuntar al segmento del buffer de pantalla momentaneamente
    mov ES, AX                          ; ES tambien debe apuntar al segmento del buffer
    assume DS:.DATA_BUFF_PANTALLA

    lea DI, buffPantalla                ; cargar el buffer de pantalla a DI

    pop DS                              ; regresar al segmento de data
    assume DS:@data

    ;-------------------------;
    ; Calcular offset inicial ;
    ;-------------------------;
    ; me quedé sin registros para usar asi que guardemos DX para usarlo momentaneamente
    push DX

    mov AX, BP
    mov DX, 320
    mul DX
    add AX, CX
    add DI, AX              ; DI = posY * 320 + posX

    pop DX

    cld                     ; para iterar hacia adelante

    dibujarObjeto_loop:
        mov CX, BX

        ; DS:SI -> ES:DI
        rep movsb           ; copiar fila de pixeles completa al buffer

        ; calcular direccion de la siguiente fila. DI += 320 - columnas
        add DI, 320
        sub DI, BX

        dec DX              ; filas--
        jnz dibujarObjeto_loop      ; si todavia quedan filas por dibujar seguir iterando

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

        sub [SI + 2], tamUnidad

        call calcColisionPared  ; devuelve bool AX = hayColision

        cmp AX, 0
        je  .return     ; if no hubo colision

        add [SI + 2], tamUnidad     ; Si sí hubo colision devolver al tanque

        jmp .return

    .inputTeclaDerecha:
        lea SI, buffJugador
        
        mov AL, 1
        mov [SI + 4], AL        ; dir=1 -> derecha

        add [SI], tamUnidad
        
        call calcColisionPared  ; devuelve bool AX = hayColision

        cmp AX, 0
        je  .return     ; if no hubo colision

        sub [SI], tamUnidad     ; Si sí hubo colision devolver al tanque
        jmp .return
        
    .inputTeclaAbajo:
        lea SI, buffJugador

        mov AL, 2
        mov [SI + 4], AL        ; dir=2 -> abajo
        
        add [SI + 2], tamUnidad
        
        call calcColisionPared  ; devuelve bool AX = hayColision

        cmp AX, 0
        je  .return     ; if no hubo colision

        sub [SI + 2], tamUnidad     ; Si sí hubo colision devolver al tanque
        jmp .return

    .inputTeclaIzquierda:
        lea SI, buffJugador

        mov AL, 3
        mov [SI + 4], AL        ; dir=3 -> izquierda
        
        sub [SI], tamUnidad
                
        call calcColisionPared  ; devuelve bool AX = hayColision

        cmp AX, 0
        je  .return     ; if no hubo colision

        add [SI], tamUnidad     ; Si sí hubo colision devolver al tanque
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
        mov BP, 0                       ; idTirador (0 = jugador)
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

dispararBala PROC   ; AX = posX, DX = posY, CH = dir, CL = disp, SI = spawnOffset, BP = idTirador
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

        ; set idTirador
        mov [DI + BX + 6], BP
    
    dispararBala_return:
    ret
dispararBala ENDP

dibujarBalas PROC
    ;-----------------------;
    ; Inicializar variables ;
    ;-----------------------;
    lea DI, arrayBalas
    lea SI, buffBala

    ;----------------------------;
    ; Iterar por todas las balas ;
    ;----------------------------;
    mov BX, 0                      ; balaIndex = -1

    dibujarBalas_forEach_bala:
        cmp BX, arrayBalasLen * balaDataLen
        jge dibujarBalas_return     ; si ya iteramos por todas la balas

        mov AH, [DI + BX + 4]   ; AH = bala.dir
        mov AL, [DI + BX + 5]   ; AL = bala.desp

        cmp AH, 0Fh
        je  dibujarBalas_continue           ; saltarse las balas desactivadas
        
        ;---------------------------------;
        ; Determinar direccion de la bala ;
        ;---------------------------------;
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


        ;--------------;
        ; Dibujar bala ;
        ;--------------;
        dibujarBalas_actualizarBuffer:
        ;-------;
        ; POS X ;
        ;-------;
        mov AX, [DI + BX]       ; AX = bala.posX
        mov [SI], AX            ; buffBala.posX = bala.posX

        ;-------;
        ; POS Y ;
        ;-------;
        mov AX, [DI + BX + 2]       ; AX = bala.posY
        mov [SI + 2], AX            ; buffBala.posY = bala.posY

        
        ;---------------------;
        ; Calcular colisiones ;
        ;---------------------;
        push SI
        push DI
        push BX
        
        call calcColisionEnemigo        ; AX = (bool) hayColision
        mov DX, BX                      ; DX = enemigoIndex

        pop BX
        pop DI
        pop SI

        cmp AX, 0
        je  dibujarBalas_checkColisionParedes  ; no hubo colision con ningun enemigo, checkear si hay colision con las paredes

        mov AX, [DI + BX + 6]       ; AX = bala.idTirador
        cmp AX, 1                   ; idTirador = 1 -> bala de enemigo. Una bala de enemigo no mata a otro enemigo entonces ignoramos la colision
        je  dibujarBalas_checkColisionParedes

        push DI
        push BX

        lea DI, arrayEnemigos
        mov BX, DX

        mov AL, [DI + BX + 6]
        dec AL
        mov [DI + BX + 6], AL

        cmp AL, 0
        jg  dibujarBalas_foreach_bala_disparoNoMatoEnemigo

        dec enemigosVivos

        dibujarBalas_foreach_bala_disparoNoMatoEnemigo:
        pop BX
        pop DI
        
        jmp dibujarBalas_desactivarBala


        dibujarBalas_checkColisionParedes:
        push SI
        push DI
        push BX
        
        call calcColisionPared      ; AX = (bool) hayColision
        mov DX, BX                  ; DX = wallIndex

        pop BX
        pop DI
        pop SI

        cmp AX, 0
        je  dibujarBalas_dibujar  ; no hubo colision con las paredes entonces dibujar la bala

        cmp AX, -1
        je  dibujarBalas_desactivarBala     ; si colisiono con un borde

        cmp AX, 1
        je  dibujarBalas_colisionBrick     ; colision con wall.Type = 1 (brick)

        jmp dibujarBalas_desactivarBala

        dibujarBalas_colisionBrick:
            push DI
            push BX

            lea DI, wallsData       ; array de paredes
            mov BX, DX              ; BX = wallIndex
            mov AL, 0
            mov [DI + BX], AL        ; marcar pared en paredesArray[wallIndex] desactivada

            pop BX
            pop DI
            jmp dibujarBalas_desactivarBala     ; desactivar bala

        ;--------------;
        ; Dibujar bala ;
        ;--------------;
        dibujarBalas_dibujar:
        push SI
        push DI
        push BX

        call dibujarObjeto

        pop BX
        pop DI
        pop SI

        jmp dibujarBalas_continue

        
        ;-----------------;
        ; Desactivar bala ;
        ;-----------------;
        dibujarBalas_desactivarBala:
        mov [DI + BX + 4], 0Fh

        dibujarBalas_continue:
        add BX, balaDataLen         ; balaIndex++
        jmp dibujarBalas_forEach_bala

    dibujarBalas_return:
    ret
dibujarBalas ENDP

dibujarParedes PROC
    mov x, 0
    mov y, 0
    xor CX, CX      ; columnasCount = 0

    lea DI, wallsData

    mov BX, 0       ; i = 0
    dibujarParedes_forPared:
        cmp BX, wallsDataRowLen * wallsDataColLen   ; if (i > filas * columnas) break
        jge end_dibujarParedes_forPared

        mov AL, [DI + BX]   ; AL = pared.type

        cmp AL, 0                       ; 0 = no hay pared
        je  dibujarParedes_continue     ; continue

        cmp AL, 1                       ; 1 = bricks
        je  dibujarParedes_Bricks

        cmp AL, 2                       ; 2 = steel
        je  dibujarParedes_Steel

        cmp AL, 3                       ; 3 = bush
        je  dibujarParedes_Bush

        dibujarParedes_Bricks:
            lea SI, buffBrick
            jmp dibujarParedes_dibujar
        
        dibujarParedes_Steel:
            lea SI, buffSteel
            jmp dibujarParedes_dibujar
        
        dibujarParedes_Bush:
            lea SI, buffBush
            jmp dibujarParedes_dibujar
        

        dibujarParedes_dibujar:
            mov AX, x
            mov [SI], AX
            mov AX, y
            mov [SI + 2], AX

            push SI
            push DI
            push BX
            push CX
            push x
            push y

            call dibujarObjeto

            pop y
            pop x
            pop CX
            pop BX
            pop DI
            pop SI

    
        dibujarParedes_continue:
            inc CX          ; columnasCount++
            inc BX          ; i++

            add x, wallSizePixels   ; coords de la siguiente pared

            cmp CX, wallsDataColLen
            jl  dibujarParedes_forPared      ; if columnasCount < totalColumnas

            xor CX, CX              ; columnasCount = 0
            mov x, 0                ; siguiente columna empieza en x = 0
            add y, wallSizePixels   ; siguiente fila

            jmp dibujarParedes_forPared
    end_dibujarParedes_forPared:

    ret
dibujarParedes ENDP

calcColisionPared PROC   ; SI = buffer objeto, out AX (bool hayColision / int wall.Type), out BX (int wallIndex)
    ;-------------------------;
    ; Inicializacion de datos ;
    ;-------------------------;
    xor CX, CX              ; CX lleva la cuenta de columnas
    mov x, 0
    mov y, 0
    lea DI, wallsData
    xor DX, DX
    mov DL, [SI + 5]        ; DX = sprite.Size

    ;---------------------------------;
    ; Colision con bordes de pantalla ;
    ;---------------------------------;
    mov AX, [SI]    ; AX = extremo izquierdo del sprite

    cmp AX, 0
    jl  calcColisionPared_hayBorder       ; if obj.posX < 0 esta fuera del borde

    add AX, DX      ; AX = extremo derecho del sprite

    cmp AX, pantallaX
    jg  calcColisionPared_hayBorder       ; if obj.posX > 320 esta fuera del borde

    mov AX, [SI + 2]    ; AX = extremo superior del sprite

    cmp AX, 0
    jl  calcColisionPared_hayBorder       ; if obj.posY < 0 esta fuera del borde

    add AX, DX      ; AX = extremo inferior del sprite

    cmp AX, pantallaY
    jg  calcColisionPared_hayBorder       ; if obj.posY > 200 esta fuera del borde


    ;-----------------------;
    ; Iterar por cada pared ;
    ;-----------------------;
    mov BX, 0                   ; i = 0
    calcColisionPared_forPared:
        cmp BX, wallsDataRowLen * wallsDataColLen   ; if (i > filas * columnas) break
        jge end_calcColisionPared_forPared

        mov AL, [DI + BX]       ; AL = wall.Type

        cmp AL, 0
        je  calcColisionPared_continue       ; if pared destruida o no existe
        cmp AL, 3
        je  calcColisionPared_continue       ; if pared es de tipo arbusto no tiene colision
    
        ;--------------------------;
        ; Calcular si hay colision ;
        ;--------------------------;
        mov DX, x
        add DX, wallSizePixels - 1

        mov AX, [SI]            ; AX = obj.posX
        cmp AX, DX
        jg  calcColisionPared_continue       ; Si el objeto está más a la derecha que la pared no hay colision

        xor DX, DX
        mov DL, [SI + 5]        ; DX = sprite.Size
        add AX, DX              ; AX = extremo derecho del sprite
        dec AX

        cmp AX, x
        jl  calcColisionPared_continue       ; Si el objeto está más a la izquierda que la pared no hay colision

        mov DX, y
        add DX, wallSizePixels - 1

        mov AX, [SI + 2]        ; AX = obj.posY
        cmp AX, DX
        jg  calcColisionPared_continue       ; Si el objeto está más abajo que la pared no hay colision

        xor DX, DX
        mov DL, [SI + 5]        ; DX = sprite.Size
        add AX, DX              ; AX = extremo inferior del sprite
        dec AX

        cmp AX, y
        jl  calcColisionPared_continue       ; Si el objeto está más a arriba que la pared no hay colision

        ;------------------;
        ; Sí hay colision! ;
        ;------------------;
        xor AX, AX
        mov AL, [DI + BX]
        ret                     ; return True (wall.Type)

        calcColisionPared_continue:
            inc CX      ; columnasCount++
            inc BX      ; i++

            add x, wallSizePixels   ; coords de la siguiente pared

            cmp CX, wallsDataColLen
            jl  calcColisionPared_forPared      ; if columnasCount < totalColumnas

            xor CX, CX              ; columnasCount = 0
            mov x, 0                ; siguiente columna empieza en x = 0
            add y, wallSizePixels   ; siguiente fila

            jmp calcColisionPared_forPared

    end_calcColisionPared_forPared:
    mov AX, 0
    ret                     ; return False

    calcColisionPared_hayBorder:
    mov AX, -1
    ret                     ; return -1

calcColisionPared ENDP

calcColisionEnemigo PROC   ; SI = buffer objeto, out AX (bool hayColision), out BX (int enemigoIndex)
    lea DI, buffEnemigo1
    xor CX, CX
    mov CL, [DI + 5]            ; CX = enemigo.Size (todos los enemigos son del mismo tamaño entonces no importa cual buffer usamos)

    lea DI, arrayEnemigos
    mov BX, -enemigoDataLen
    calcColisionEnemigo_siguienteEnemigo:
        add BX, enemigoDataLen

        cmp BX, enemigoDataLen * arrayEnemigosLen
        jge calcColisionEnemigo_return                  ; si ya iteramos por todos los enemigos

        mov AL, [DI + BX + 6]
        cmp AL, 0
        je  calcColisionEnemigo_siguienteEnemigo        ; si el enemigo esta muerto, no tiene colisiones obvio


        ;-------------------;
        ; COLISION EN EJE X ;
        ;-------------------;
        mov AX, [SI]            ; AX = objeto.posX
        mov DX, [DI + BX]
        add DX, CX              ; DX = extremo derecho del enemigo

        cmp AX, DX
        jg  calcColisionEnemigo_siguienteEnemigo        ; si el objeto está más a la derecha del enemigo no hay colisión

        xor DX, DX
        mov DL, [SI + 5]            ; DX = objeto.Size
        add AX, DX                  ; AX = extremo derecho del objeto

        mov DX, [DI + BX]           ; DX = extremo izquierdo del enemigo

        cmp AX, DX
        jl  calcColisionEnemigo_siguienteEnemigo        ; si el objeto está más a la izquierda del enemigo no hay colisión

        
        ;-------------------;
        ; COLISION EN EJE Y ;
        ;-------------------;
        mov AX, [SI + 2]        ; AX = objeto.posY
        mov DX, [DI + BX + 2]
        add DX, CX              ; DX = extremo inferior del enemigo

        cmp AX, DX
        jg  calcColisionEnemigo_siguienteEnemigo        ; si el objeto está más abajo del enemigo no hay colisión

        xor DX, DX
        mov DL, [SI + 5]            ; DX = objeto.Size
        add AX, DX                  ; AX = extremo inferior del objeto

        mov DX, [DI + BX + 2]       ; DX = extremo superior del enemigo

        cmp AX, DX
        jl  calcColisionEnemigo_siguienteEnemigo        ; si el objeto está más arriba del enemigo no hay colisión


        ;---------------;
        ; HAY COLISION! ;
        ;---------------;
        mov AX, 1           ; hayColision = true
        ret


    calcColisionEnemigo_return:
    mov AX, 0               ; hayColision = false
    ret

calcColisionEnemigo ENDP

spawnearEnemigo PROC
    ; timer de spawneo
    inc tiempoSpawnActual
    cmp tiempoSpawnActual, tiempoEnemigoSpawn
    jl  spawnearEnemigo_return

    ; resetar timer de spawneo
    mov tiempoSpawnActual, 0

    ; revisar si ya se spawnearon todos los enemigos del nivel
    cmp cantSpawneados, enemigosEnNivel
    jge spawnearEnemigo_return

    ; revisar si ya se llegó al límite de enemigos vivos al mismo tiempo
    cmp enemigosVivos, maxEnemigosVivos
    jge spawnearEnemigo_return

    inc enemigosVivos
    inc cantSpawneados

    lea DI, arrayEnemigos
    mov BX, -enemigoDataLen
    spawnearEnemigo_siguienteEnemigo:
        add BX, enemigoDataLen

        cmp BX, enemigoDataLen * arrayEnemigosLen
        ; si ya iteramos por todos los enemigos y no encontramos un espacio libre: return (ESTO NUNCA DEBERIA OCURRIR)
        jge spawnearEnemigo_return

        mov AL, [DI + BX + 6]
        cmp AL, 0
        jne spawnearEnemigo_siguienteEnemigo    ; si el enemigo en esta posicion no esta muerto seguir buscando un espacio

        ; si llegamos a este punto es porque en esta posicion del array podemos spawnear un enemigo!

        mov [DI + BX], enemigoSpawnX
        mov [DI + BX + 2], enemigoSpawnY
        mov [DI + BX + 4], 02h              ; dir = 2
        mov [DI + BX + 5], 01h              ; tipo = 1
        mov [DI + BX + 6], 01h              ; vidas = 1
        mov [DI + BX + 7], 02h              ; velocidad = 1
        mov [DI + BX + 8], cooldownEnemigo1

    spawnearEnemigo_return:
    ret
spawnearEnemigo ENDP

dibujarEnemigos PROC
    lea DI, arrayEnemigos
    lea SI, buffEnemigo1
    
    mov BX, -enemigoDataLen
    dibujarEnemigos_siguienteEnemigo:
        add BX, enemigoDataLen

        cmp BX, enemigoDataLen * arrayEnemigosLen
        jge dibujarEnemigos_return                  ; si ya iteramos por todos los enemigos

        mov AL, [DI + BX + 6]
        cmp AL, 0
        je  dibujarEnemigos_siguienteEnemigo        ; si el enemigo esta muerto, no hay que dibujarlo

        ;-----------------;
        ; DIBUJAR ENEMIGO ;
        ;-----------------;
        mov AX, [DI + BX]
        mov [SI], AX

        mov AX, [DI + BX + 2]
        mov [SI + 2], AX

        mov AL, [DI + BX + 4]
        mov [SI + 4], AL

        push SI
        push DI
        push BX

        call dibujarObjeto

        pop BX
        pop DI
        pop SI

        ;----------;
        ; DISPARAR ;
        ;----------;
        mov AX, [DI + BX + 8]
        dec AX
        mov [DI + BX + 8], AX                   ; reducir cooldown
        cmp AX, 0
        ja  dibujarEnemigos_moverEnemigo        ; si el cooldown de disparo no ha terminado

        mov [DI + BX + 8], cooldownEnemigo1     ; restaurar cooldown de disparo

        push SI
        push DI
        push BX

        mov AX, [DI + BX]       ; bala.posX = enemigo.posX
        mov DX, [DI + BX + 2]   ; bala.posY = enemigo.posY
        mov CH, [DI + BX + 4]   ; bala.dir = enemigo.dir 
        mov CL, tamUnidad       ; bala.vel = tamUnidad
        mov SI, 30              ; balaOffset
        mov BP, 1               ; idTirador = 1 (enemigo)

        call dispararBala

        pop BX
        pop DI
        pop SI

        dibujarEnemigos_moverEnemigo:
        ;------------------;
        ; MOVER EL ENEMIGO ;
        ;------------------;
        ; probabilidad random de cambiar de direccion
        call byteAleatorio  ; AL = byte aleatorio

        cmp AL, cambioDirRandom
        jbe dibujarEnemigos_cambiarDireccion

        mov AL, [DI + BX + 4]           ; AL = enemigo.dir

        xor DX, DX
        mov DL, [DI + BX + 7]           ; DX = enemigo.velocidad

        cmp AL, 0
        je  dibujarEnemigos_moverArriba         ; dir 0 = arriba

        cmp AL, 1
        je  dibujarEnemigos_moverDerecha        ; dir 1 = derecha

        cmp AL, 2
        je  dibujarEnemigos_moverAbajo          ; dir 2 = abajo

        cmp AL, 3
        je  dibujarEnemigos_moverIzquierda      ; dir 3 = izquierda

        dibujarEnemigos_moverArriba:
            sub [DI + BX + 2], DX           ; mover enemigo hacia arriba
            sub [SI + 2], DX           ; mover enemigo hacia arriba
            
            push SI
            push DI
            push BX
            push DX
            
            call calcColisionPared          ; AX = (bool) hayColision

            pop DX
            pop BX
            pop DI
            pop SI

            cmp AX, 0
            je  dibujarEnemigos_siguienteEnemigo        ; no hubo colision con ninguna pared

            add [DI + BX + 2], DX        ; devolver al enemigo
            add [SI + 2], DX        ; devolver al enemigo
            jmp dibujarEnemigos_cambiarDireccion

        dibujarEnemigos_moverDerecha:
            add [DI + BX], DX           ; mover enemigo hacia la derecha
            add [SI], DX           ; mover enemigo hacia la derecha
            
            push SI
            push DI
            push BX
            push DX
            
            call calcColisionPared          ; AX = (bool) hayColision

            pop DX
            pop BX
            pop DI
            pop SI

            cmp AX, 0
            je  dibujarEnemigos_siguienteEnemigo        ; no hubo colision con ninguna pared

            sub [DI + BX], DX            ; devolver al enemigo
            sub [SI], DX            ; devolver al enemigo
            jmp dibujarEnemigos_cambiarDireccion

        dibujarEnemigos_moverAbajo:
            add [DI + BX + 2], DX           ; mover enemigo hacia abajo
            add [SI + 2], DX           ; mover enemigo hacia abajo
            
            push SI
            push DI
            push BX
            push DX
            
            call calcColisionPared          ; AX = (bool) hayColision

            pop DX
            pop BX
            pop DI
            pop SI

            cmp AX, 0
            je  dibujarEnemigos_siguienteEnemigo        ; no hubo colision con ninguna pared

            sub [DI + BX + 2], DX        ; devolver al enemigo
            sub [SI + 2], DX        ; devolver al enemigo
            jmp dibujarEnemigos_cambiarDireccion

        dibujarEnemigos_moverIzquierda:
            sub [DI + BX], DX           ; mover enemigo hacia la izquierda
            sub [SI], DX           ; mover enemigo hacia la izquierda
            
            push SI
            push DI
            push BX
            push DX
            
            call calcColisionPared          ; AX = (bool) hayColision

            pop DX
            pop BX
            pop DI
            pop SI

            cmp AX, 0
            je  dibujarEnemigos_siguienteEnemigo        ; no hubo colision con ninguna pared

            add [DI + BX], DX            ; devolver al enemigo
            add [SI], DX            ; devolver al enemigo
            jmp dibujarEnemigos_cambiarDireccion
        
        dibujarEnemigos_cambiarDireccion:
            push BX
            call byteAleatorio      ; AL = random byte
            xor DX, DX
            mov BX, 4
            div BX                  ; byteAleatorio / 4, DX = byteAleatorio % 4
            pop BX

            mov [DI + BX + 4], DL   ; asignar nueva direccion
            jmp dibujarEnemigos_siguienteEnemigo


    dibujarEnemigos_return:
    ret
dibujarEnemigos ENDP

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

    lea DI, spriteEnemigo1
    lea SI, buffEnemigo1
    call cargarObjeto

    lea DI, spriteBala
    lea SI, buffBala
    call cargarObjeto

    lea DI, wallsDataPath
    lea SI, wallsData
    call cargarObjeto

    lea DI, spriteBrick
    lea SI, buffBrick
    call cargarObjeto

    lea DI, spriteSteel
    lea SI, buffSteel
    call cargarObjeto

    lea DI, spriteBush
    lea SI, buffBush
    call cargarObjeto


    ;-------;
    ; JUEGO ;
    ;-------;
    main_loop:
        inc frameCounter

        ;---------------------;
        ; DIBUJAR EN PANTALLA ;
        ;---------------------;
        call vSync
        call dibujarPantalla
        ; call updateGUI
        call limpiarPantalla

        ;-----;
        ; I/O ;
        ;-----;
        call procesarInput
        call calcDisparoCoolDown

        ;----------;
        ; GAMEPLAY ;
        ;----------;
        lea SI, buffJugador
        call dibujarObjeto

        call dibujarEnemigos

        call dibujarParedes

        call dibujarBalas

        ;----------------------------;
        ; PROCESOS UNA VEZ POR FRAME ;
        ;----------------------------;
        cmp frameCounter, fps
        jl  main_loop
        mov frameCounter, 0

        call spawnearEnemigo
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