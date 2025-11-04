.MODEL small
.STACK 100h

.DATA
text        db 'HOLA$'

.CODE


main PROC
    mov AX, @data
    mov DS, AX

    ; Cambiar a modo de video 13h (320x200, 256 colores)
    mov AX, 0013h
    int 10h

    
    mov AH, 09
    lea DX, text
    int 21h

    ; Terminar programa
    mov AH, 4Ch
    int 21h
main ENDP
END main