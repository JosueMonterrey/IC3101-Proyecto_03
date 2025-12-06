.MODEL large
.STACK 100h

.DATA
    ; [DATA GRAFICOS]
    pantallaX               EQU  320
    pantallaY               EQU  192
    x                       DW  0
    y                       DW  0
    pantallaBorderSpace     EQU 0       ; cantidad de pixeles a los lados de los bordes para que los enemigos no se salgan de la pantalla

    ; [GUI]
    enemigosText    DB  "Enemigos: $"
    vidasText       DB  " Vidas: $"
    nivelText       DB  " Nivel: $"

    ; [DATA SPRITES]
    handle          DW  ?                    ; Handle del archivo a leer
    spriteJugador   DB  '..\PLAYER.BIN', 0
    spriteBala      DB  '..\BULLET.BIN', 0
    wallsDataPath   DB  '..\WALLS.BIN', 0
    spriteBrick     DB  '..\BRICK.BIN', 0
    spriteSteel     DB  '..\STEEL.BIN', 0
    spriteBush      DB  '..\BUSH.BIN', 0
    spriteWater     DB  '..\WATER.BIN', 0
    spriteEnemigo1  DB  '..\ENEMY1.BIN', 0
    spriteEnemigo2  DB  '..\ENEMY2.BIN', 0
    spriteEnemigo3  DB  '..\ENEMY3.BIN', 0
    spriteEagle     DB  '..\EAGLE.BIN', 0

    ; [word x, word y, byte dir, byte size, byte[256] colors]
    buffJugador     DB  1030    DUP (?) ; Buffer para leer bytes del jugador
    buffEnemigo1    DB  1030    DUP (?) ; Buffer para leer bytes del enemigo1
    buffEnemigo2    DB  1030    DUP (?) ; Buffer para leer bytes del enemigo2
    buffEnemigo3    DB  1030    DUP (?) ; Buffer para leer bytes del enemigo3
    buffBala        DB  32      DUP (?) ; Buffer para leer bytes de la bala
    buffBrick       DB  262     DUP (?) ; Buffer para leer bytes de los ladrillos
    buffSteel       DB  262     DUP (?) ; Buffer para leer bytes del metal
    buffBush        DB  262     DUP (?) ; Buffer para leer bytes de los arbustos
    buffWater       DB  262     DUP (?) ; Buffer para leer bytes del agua
    buffEagle       DB  262     DUP (?) ; Buffer para leer bytes del aguila
    buffTexto       DB 9 DUP (?)   ; buffer para leer bytes de texto

    ; [DATA GAMEPLAY]
    frameCounter        DW  0000h
    fps                 EQU  30
    tamUnidad           EQU  0008h

    nivel               DB  0       ; cual nivel se está jugando

    vidas               DB  3       ; el jugador tiene 3 vidas
    jugadorBalaOffset   EQU 00h     ; sin offset la bala spawnea en la esquina del sprite del jugador en vez del centro
    tiempoDeDisparo     EQU 1       ; 10 frames entre disparo del jugador
    disparoCoolDown     DB  0
    jugadorSpawnX       EQU 152       ; posicion X del spawn del jugador
    jugadorSpawnY       EQU 152       ; posicion Y del spawn del jugador

    ; Informacion de cada bala en la escena [posX (WORD), posY (WORD), direccion (BYTE), desplazamiento (BYTE), idTirador (WORD)]
    arrayBalas      DB  400 DUP (0Fh)
    arrayBalasLen   EQU 0014h   ; 50 en decimal (pueden haber maximo 50 balas en escena)
    balaDataLen     EQU 0008h   ; cada bala en el array de balas tiene 6 bytes de informacion

    ; Offsets en X y Y para cada dirección
    offsetXDir0     EQU 6
    offsetYDir0     EQU 0
    offsetXDir1     EQU 10
    offsetYDir1     EQU 6
    offsetXDir2     EQU 6
    offsetYDir2     EQU 10
    offsetXDir3     EQU 0
    offsetYDir3     EQU 6

    ; Informacion de cada pared en la escena [word x, word y, byte type (0=destruida)]
    arrayParedesLen EQU 960
    wallsData       DB  arrayParedesLen DUP (?) ; Matris de 40*24
    wallsDataColLen EQU 40
    wallsDataRowLen EQU 24
    wallSizePixels  EQU 8
    paredDataLen    EQU 5

    enemigoSpawnX       EQU 152     ; posX del spawn de los enemigos
    enemigoSpawnY       EQU 16      ; posY del spawn de los enemigos
    tiempoEnemigoSpawn  EQU 2       ; segundos entre cada intento de spawn
    tiempoSpawnActual   DW  0       ; timer para spawnear un enemigo
    maxEnemigosVivos    EQU 5       ; cuantos enemigos pueden existir al mismo tiempo en un nivel
    enemigosEnNivel     EQU 20      ; cuantos enemigos en total hay que matar para pasar el nivel
    cantSpawneados      DB  0       ; cantidad de enemigos spawneados
    enemigosVivos       DB  0       ; cuantos enemigos hay vivos en este momento
    kills               DB  0       ; kill counter
    ; Informacion de cada enemigo en la escena [posX (WORD), posY (WORD), direccion (BYTE), tipo (BYTE, 0=muerto), vidas (BYTE), velocidad(BYTE), disparoCooldown (WORD)]
    arrayEnemigos       DB  50
    enemigoDataLen      EQU 10       ; cada enemigo utiliza 8 bytes de informacion en el array de enemigos
    arrayEnemigosLen    EQU 5       ; hay maximo 5 enemigos en el array
    velocidadEnemigo1   EQU 1
    velocidadEnemigo2   EQU 2
    velocidadEnemigo3   EQU 1
    cooldownEnemigo1    EQU 80       ; cooldown para el disparo de los enemigos de tipo 1
    cooldownEnemigo2    EQU 40       ; cooldown para el disparo de los enemigos de tipo 2
    cooldownEnemigo3    EQU 100       ; cooldown para el disparo de los enemigos de tipo 3
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
    add DI, 2560
    mov CX, 32000           ; 320*200 = 64000 bytes → 32000 palabras
    sub CX, 1280
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

dispararBala PROC   ; AX = posX, DX = posY, CH = dir, CL = disp, BP = idTirador
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

        mov [DI + BX], AX       ; arrayBalas[indexBala].posX = posX
        mov [DI + BX + 2], DX   ; arrayBalas[indexBala].posY = posY

        ; set desplazamiento
        mov [DI + BX + 5], CL

        ; set idTirador
        mov [DI + BX + 6], BP

        ; dir=0 -> sube,
        ; dir=1 -> derecha
        ; dir=2 -> baja
        ; dir=3 -> izquierda
        mov [DI + BX + 4], CH

        cmp CH, 0
        je  dispararBala_offsetArriba
        cmp CH, 1
        je  dispararBala_offsetDerecha
        cmp CH, 2
        je  dispararBala_offsetAbajo
        cmp CH, 3
        je  dispararBala_offsetIzquierda


        dispararBala_offsetArriba:
            add [DI + BX], offsetXDir0
            add [DI + BX + 2], offsetYDir0
            jmp dispararBala_return

        dispararBala_offsetDerecha:
            add [DI + BX], offsetXDir1
            add [DI + BX + 2], offsetYDir1
            jmp dispararBala_return

        dispararBala_offsetAbajo:
            add [DI + BX], offsetXDir2
            add [DI + BX + 2], offsetYDir2
            jmp dispararBala_return

        dispararBala_offsetIzquierda:
            add [DI + BX], offsetXDir3
            add [DI + BX + 2], offsetYDir3
            jmp dispararBala_return
    
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

        ;---------------------------------;
        ; Calcular colisiones con jugador ;
        ;---------------------------------;
        mov AX, [DI + BX + 6]       ; AX = bala.idTirador
        cmp AX, 0                   ; idTirador = 0 -> bala de jugador. Una bala del jugador no puede hacerle daño a él mismo entonces ignoramos la colision
        je  dibujarBalas_checkColisionEnemigos

        xor CX, CX
        mov CL, [SI + 5]            ; CX = bala.size

        push SI

        lea SI, buffJugador

        mov AX, [DI + BX]           ; AX = bala.posX
        xor DX, DX
        mov DL, [SI + 5]            ; DX = jugador.size
        add DX, [SI]                ; DX = jugador.posX + jugador.size

        cmp AX, DX
        jge dibujarBalas_noColisionConJugador      ; si la bala está más a la derecha que el jugador no hay colisión

        add AX, CX                  ; AX = bala.posX + bala.size
        mov DX, [SI]                ; DX = jugador.posX

        cmp AX, DX
        jle dibujarBalas_noColisionConJugador      ; si la bala está más a la izquierda que el jugador no hay colisión


        mov AX, [DI + BX + 2]           ; AX = bala.posY
        xor DX, DX
        mov DL, [SI + 5]                ; DX = jugador.size
        add DX, [SI + 2]                ; DX = jugador.posY + jugador.size

        cmp AX, DX
        jge dibujarBalas_noColisionConJugador      ; si la bala está más abajo que el jugador no hay colisión

        add AX, CX                  ; AX = bala.posY + bala.size
        mov DX, [SI + 2]            ; DX = jugador.posY

        cmp AX, DX
        jle dibujarBalas_noColisionConJugador      ; si la bala está más arriba que el jugador no hay colisión

        ;--------------------------------;
        ; SI HAY COLISION CON EL JUGADOR ;
        ;--------------------------------;
        ; reposicionar jugador y quitar una vida
        mov [SI], jugadorSpawnX
        mov [SI + 2], jugadorSpawnY
        dec vidas

        pop SI
        jmp dibujarBalas_desactivarBala

        dibujarBalas_noColisionConJugador:
        pop SI

        ;----------------------------------;
        ; Calcular colisiones con enemigos ;
        ;----------------------------------;
        dibujarBalas_checkColisionEnemigos:
        mov AX, [DI + BX + 6]       ; AX = bala.idTirador
        cmp AX, 1                   ; idTirador = 1 -> bala de enemigo. Una bala de enemigo no mata a otro enemigo entonces ignoramos la colision
        je  dibujarBalas_checkColisionParedes
        
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
        inc kills

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

        cmp AX, 4
        je  dibujarBalas_dibujar  ; 4 significa agua, no hay colisiones con el agua

        cmp AX, -1
        je  dibujarBalas_desactivarBala     ; si colisiono con un borde

        cmp AX, -2
        je  dibujarBalas_colisionEagle      ; si le dispararon al eagle

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

        dibujarBalas_colisionEagle:
            mov vidas, 0            ; game over
            jmp dibujarBalas_desactivarBala


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

dibujarAgua PROC
    mov x, 0
    mov y, 0
    xor CX, CX      ; columnasCount = 0

    lea DI, wallsData
    lea SI, buffWater

    mov BX, 0       ; i = 0
    dibujarAgua_forPared:
        cmp BX, wallsDataRowLen * wallsDataColLen   ; if (i > filas * columnas) break
        jge end_dibujarAgua_forPared

        mov AL, [DI + BX]   ; AL = pared.type

        cmp AL, 4
        jne  dibujarAgua_continue       ; si no es agua continuar

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


        dibujarAgua_continue:
            inc CX          ; columnasCount++
            inc BX          ; i++

            add x, wallSizePixels   ; coords de la siguiente pared

            cmp CX, wallsDataColLen
            jl  dibujarAgua_forPared      ; if columnasCount < totalColumnas

            xor CX, CX              ; columnasCount = 0
            mov x, 0                ; siguiente columna empieza en x = 0
            add y, wallSizePixels   ; siguiente fila

            jmp dibujarAgua_forPared
    end_dibujarAgua_forPared:

    ret
dibujarAgua ENDP

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
        cmp AL, 4                       ; 4 = agua
        je  dibujarParedes_continue     ; se tiene que renderizar aparte

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

    ;-----------------------------------;
    ; CALCULAR COLISIONES CON EL AGUILA ;
    ;-----------------------------------;
    call calcColisionAguila     ; AX (bool) = hayColision
    cmp AX, 0
    je calcColisionPared_iniciarCalculo     ; si no hubo colision con la eagle proseguir como normal
    mov AX, -2                              ; else return -2
    ret

    calcColisionPared_iniciarCalculo:
    ;-------------------------;
    ; Inicializacion de datos ;
    ;-------------------------;
    xor CX, CX              ; CX lleva la cuenta de columnas
    mov x, 0
    mov y, 0
    lea DI, wallsData

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

calcColisionAguila PROC     ; SI = buffer objeto, out AX (bool hayColision)

    lea DI, buffEagle

    xor CX, CX
    mov CL, [DI + 5]            ; CX = eagle.size

    mov AX, [DI]           ; AX = eagle.posX
    xor DX, DX
    mov DL, [SI + 5]            ; DX = objeto.size
    add DX, [SI]                ; DX = objeto.posX + objeto.size

    cmp AX, DX
    jge calcColisionAguila_return      ; si la eagle está más a la derecha que el objeto no hay colisión

    add AX, CX                  ; AX = eagle.posX + eagle.size
    mov DX, [SI]                ; DX = objeto.posX

    cmp AX, DX
    jle calcColisionAguila_return      ; si la eagle está más a la izquierda que el objeto no hay colisión


    mov AX, [DI + 2]           ; AX = eagle.posY
    xor DX, DX
    mov DL, [SI + 5]                ; DX = objeto.size
    add DX, [SI + 2]                ; DX = objeto.posY + objeto.size

    cmp AX, DX
    jge calcColisionAguila_return      ; si la eagle está más abajo que el objeto no hay colisión

    add AX, CX                  ; AX = eagle.posY + eagle.size
    mov DX, [SI + 2]            ; DX = objeto.posY

    cmp AX, DX
    jle calcColisionAguila_return      ; si la eagle está más arriba que el objeto no hay colisión

    ;-----------------;
    ; SI HAY COLISION ;
    ;-----------------;
    mov AX, -2           ; return true
    ret

    calcColisionAguila_return:
    mov AX, 0           ; return false
    ret

calcColisionAguila ENDP

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
        mov [DI + BX + 4], 02h              ; dir = 2 -> abajo

        call byteAleatorio  ; AL = byte aleatorio
        mov AH, 0
        xor DX, DX
        mov CX, 3
        div CX              ; AX = byteAleatorio / 3, DX = byteAleatorio % 3

        cmp DX, 0
        je  spawnearEnemigo_tipo1
        cmp DX, 1
        je  spawnearEnemigo_tipo2
        cmp DX, 2
        je  spawnearEnemigo_tipo3


        spawnearEnemigo_tipo1:
            mov [DI + BX + 5], 01h              ; tipo = 1
            mov [DI + BX + 6], 01h              ; vidas = 1
            mov [DI + BX + 7], velocidadEnemigo1
            mov [DI + BX + 8], cooldownEnemigo1
            jmp spawnearEnemigo_return

        spawnearEnemigo_tipo2:
            mov [DI + BX + 5], 02h              ; tipo = 2
            mov [DI + BX + 6], 01h              ; vidas = 1
            mov [DI + BX + 7], velocidadEnemigo2
            mov [DI + BX + 8], cooldownEnemigo2
            jmp spawnearEnemigo_return

        spawnearEnemigo_tipo3:
            mov [DI + BX + 5], 03h              ; tipo = 2
            mov [DI + BX + 6], 03h              ; vidas = 1
            mov [DI + BX + 7], velocidadEnemigo3
            mov [DI + BX + 8], cooldownEnemigo3
            jmp spawnearEnemigo_return

    spawnearEnemigo_return:
    ret
spawnearEnemigo ENDP

dibujarEnemigos PROC
    lea DI, arrayEnemigos
    
    mov BX, -enemigoDataLen
    dibujarEnemigos_siguienteEnemigo:
        add BX, enemigoDataLen

        cmp BX, enemigoDataLen * arrayEnemigosLen
        jge dibujarEnemigos_return                  ; si ya iteramos por todos los enemigos

        mov AL, [DI + BX + 6]
        cmp AL, 0
        je  dibujarEnemigos_siguienteEnemigo        ; si el enemigo esta muerto, no hay que dibujarlo

        ;-----------------;
        ; DETERMINAR TIPO ;
        ;-----------------;
        mov AL, [DI + BX + 5]           ; AL = enemigo.tipo

        cmp AL, 1
        je  dibujarEnemigos_cargarBuffEnemigo1      ; cargar el buffEnemigo1 si el tipo = 1
        cmp AL, 2
        je  dibujarEnemigos_cargarBuffEnemigo2      ; cargar el buffEnemigo1 si el tipo = 2
        cmp AL, 3
        je  dibujarEnemigos_cargarBuffEnemigo3      ; cargar el buffEnemigo1 si el tipo = 3

        dibujarEnemigos_cargarBuffEnemigo1:
        lea SI, buffEnemigo1
        jmp dibujarEnemigos_dibujar
        dibujarEnemigos_cargarBuffEnemigo2:
        lea SI, buffEnemigo2
        jmp dibujarEnemigos_dibujar
        dibujarEnemigos_cargarBuffEnemigo3:
        lea SI, buffEnemigo3
        jmp dibujarEnemigos_dibujar


        dibujarEnemigos_dibujar:
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

        ;-----------------------------------------;
        ; RESTAURAR COOLDOWN DEPENDIENDO DEL TIPO ;
        ;-----------------------------------------;
        mov AL, [DI + BX + 5]           ; AL = enemigo.tipo

        cmp AL, 1
        je  dibujarEnemigos_restaurarCooldownEnemigo1
        cmp AL, 2
        je  dibujarEnemigos_restaurarCooldownEnemigo2
        cmp AL, 3
        je  dibujarEnemigos_restaurarCooldownEnemigo2

        dibujarEnemigos_restaurarCooldownEnemigo1:
        mov [DI + BX + 8], cooldownEnemigo1     ; restaurar cooldown de disparo
        jmp dibujarEnemigos_disparar
        dibujarEnemigos_restaurarCooldownEnemigo2:
        mov [DI + BX + 8], cooldownEnemigo2     ; restaurar cooldown de disparo
        jmp dibujarEnemigos_disparar
        dibujarEnemigos_restaurarCooldownEnemigo3:
        mov [DI + BX + 8], cooldownEnemigo3     ; restaurar cooldown de disparo
        jmp dibujarEnemigos_disparar


        dibujarEnemigos_disparar:
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

detectarChoques PROC
    lea SI, buffJugador
    call calcColisionEnemigo            ; revisar si el jugador choca fisicamente con un enemigo

    cmp AX, 0
    je detectarChoques_return           ; si no hubo colisiones solo retornar

    ; si hubo un choque respawnear al jugador y quitar una vida
    lea SI, buffJugador
    mov [SI], jugadorSpawnX
    mov [SI + 2], jugadorSpawnY
    dec vidas

    detectarChoques_return:
    ret
detectarChoques ENDP

updateGUI PROC
    mov AH, 02
    mov DL, 0Dh
    int 21h             ; carriage return
    ; mov DL, 0Ah
    ; int 21h             ; line feed

    mov AH, 09
    lea DX, enemigosText
    int 21h

    xor AX, AX
    mov AL, kills
    call writeInt

    mov AH, 2
    mov DL, 2Fh
    int 21h

    xor AX, AX
    mov AL, enemigosEnNivel
    call writeInt

    mov AH, 09
    lea DX, vidasText
    int 21h

    xor AX, AX
    mov AL, vidas
    call writeInt

    ret
updateGUI ENDP

writeInt PROC   ; AX = numero
    lea SI, buffTexto
    mov CX, 0       ; contador de digitos
    writeInt_forEach_digito:
        xor DX, DX
        mov BX, 10
        div BX      ; numero % 10 (obtener el ultimo digito)
        
        add DX, 30h ; sumar 30h para alinear al codigo ascii de los numeros

        mov BX, CX
        mov [SI + BX], DL   ; añadir numero al buffer de texto

        inc CX              ; countDigitos++

        cmp AX, 0
        jne writeInt_forEach_digito ; si todavia quedan digitos continuar procesandolos

    mov AH, 02h
    writeInt_escribir:
        mov BX, CX
        dec BX
        mov DL, [SI + BX]   ; obtener digito del buffer de texto
        int 21h             ; imprimir digito
    loop writeInt_escribir
    ret

writeInt ENDP

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

    lea DI, spriteEnemigo2
    lea SI, buffEnemigo2
    call cargarObjeto

    lea DI, spriteEnemigo3
    lea SI, buffEnemigo3
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

    lea DI, spriteWater
    lea SI, buffWater
    call cargarObjeto

    lea DI, spriteEagle
    lea SI, buffEagle
    call cargarObjeto

    ;-------;
    ; JUEGO ;
    ;-------;
    main_loop:

        cmp vidas, 0
        jle game_over
        
        inc frameCounter

        ;---------------------;
        ; DIBUJAR EN PANTALLA ;
        ;---------------------;
        call vSync
        call dibujarPantalla
        call updateGUI
        call limpiarPantalla

        ;-----;
        ; I/O ;
        ;-----;
        call procesarInput
        call calcDisparoCoolDown

        ;----------;
        ; GAMEPLAY ;
        ;----------;
        call dibujarAgua
        
        lea SI, buffJugador
        call dibujarObjeto

        call dibujarEnemigos

        call dibujarBalas

        lea SI, buffEagle
        call dibujarObjeto

        call dibujarParedes

        call detectarChoques

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