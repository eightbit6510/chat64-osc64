// General info
// Relaunch 64 IDE: https://github.com/sjPlot/Relaunch64/releases
// Kick assembler for java 8: https://csdb.dk/release/?id=180813
// Memory Map: http://www.bartvenneker.nl/C64/Mem_map.html
// PETSCI KEY CODES: http://www.bartvenneker.nl/C64/Petscii_codes.html
// SCREEN functions: http://www.bartvenneker.nl/C64/Screen_codes.html
// Kernal Screen functions: http://www.bartvenneker.nl/C64/kernal_screen.html
// All Kernal functions: http://www.bartvenneker.nl/C64/kernal.html
// Petscii editor: https://petscii.krissz.hu/
// Vice emulator: https://vice-emu.sourceforge.io/windows.html


// constants
.const _LINE_COLOR_ = $9c
.const _LINE_POS_ = $fb
.const _BUFFER_POINTER_ = $fb
.const _FIELD_ = $fb
.const _NOTE_ = $fb

.const _IO1_ = $de00
.const _IO2_ = $df00
//=========================================================================================================
//   ASM Dialect: Kick assembler  v5.9 by Mads Nielsen
//=========================================================================================================
*=$0800 "BASIC Start"                             // location to put a 1 line basic program so we can just
        .byte $00                                 // first byte of basic memory should be a zero
        .byte $0E, $08                            // Forward address to next basic line
        .byte $0A, $00                            // this will be line 10 ($0A)
        .byte $9E                                 // basic token for SYS
        .text " (2064)"                           // 10 SYS (2064)
        .byte $00, $00, $00                       // end of basic program (addr $080E from above)

*=$810 "Main Program"

//=========================================================================================================
//    Warm start procedure starts at $810
//========================================================================================================= 
main_init:                                        //                                    
    jsr $E544                                     // Clear screen
    lda #5                                        //
    sta _LINE_COLOR_                              // default line color (green)
    lda #0                                        // 
    sta $d020                                     // Set black screen
    sta $d021                                     // Set black border
    sta PRINTER_ENABLED_FLAG                      // Set printer output to off
    sta PRINTIT                                   //  
    lda #144                                      // Load petscii code for Black Cursor
    jsr $ffd2                                     // output black cursor to the screen
    ldx #24                                       // zero SID sound register (1)
    lda #0
!clear_sid_loop:                                  // Clear the SID registers
    sta $d400, x                                  // 
    dex                                           // 
    bne !clear_sid_loop-                          // 
    lda #$80                                      // disable SHIFT-Commodore
    sta $0291                                     //
    lda #<(nmi)                                   // \
    sta $0318                                     //  \ Load our new nmi vector
    lda #>(nmi)                                   //  / And replace the old vector to our own nmi routine
    sta $0319                                     // /        
    jsr !are_we_in_the_matrix+                    // check if we are running inside a simulator (esp32 is disconnected)
    jsr !start_screen+                            // Call the start screen sub routine first
    jsr $E544                                     // Clear screen after start screen
    lda #23                                       // Load 23 into accumulator and use it to
    sta $D018                                     // Switch to LOWER CASE
    lda CONFIG_STATUS                             // 
    cmp #4                                        // Are we fully configured?
    bne !mainmenu+                                // No, jump to main menu first
    lda VICEMODE                                  //
    cmp #1                                        //
    bne !+                                        //
    jsr !sounderror+                              // error sound because cartridge was not found!
                                                  //
!:  jmp !main_chat_screen+                        // 
                                                  // 
!mainmenu:                                        //     
    jmp !mainmenu+                                // 
                                                  // 
//=========================================================================================================
//  Vice Simulation check
//=========================================================================================================
!are_we_in_the_matrix:                            // 
                                                  // this is to check if a real cartridge is attached
                                                  // or if we are running in the Vice simulator
                                                  // 
    jsr !wait_for_ready_to_receive+               // 
    lda #245                                      // Load number #245 (to check if the esp32 is connected)
    sta _IO1_                                     // write the byte to IO1
                                                  // 
                                                  // Send the ROM version to the cartrdige
!:  ldx #1                                        // x will be our index when we loop over the version text, we start at 1 to skip the first color byte
!sendversion:                                     // 
    jsr !wait_for_ready_to_receive+               // wait for ready to receive (bit D7 goes high)
    lda version,x                                 // load a byte from the version text with index x
    sta _IO1_                                     // send it to IO1
    cmp #128                                      // if the last byte was 128, the buffer is finished
    beq !+                                        // exit in that case
    inx                                           // increase the x index
    jmp !sendversion-                             // jump back to send the next byte
                                                  // 
!:  lda #100                                      // Delay 100... hamsters
    sta DELAY                                     // Store 100 in the DELAY variable
    jsr !delay+                                   // and call the delay subroutine
                                                  // 
    lda _IO2_                                     // read from IO2.
    cmp #128                                      // 
                                                  // 
    beq !exit+                                    // if vice mode, we do not try to communicate with the
    lda #1                                        // cartridge because it will result in error
    sta VICEMODE                                  //  
                                                  //
!exit:                                            // 
    lda #100                                      // Delay 100... hamsters
    sta DELAY                                     // Store 100 in the DELAY variable
    jsr !delay+                                   // and call the delay subroutine
    rts                                           // 

!hide_cursor:
    lda #$01; sta $cc                             // Hide the cursor
    rts
!show_cursor:  
    lda #$00; sta $cc                             // show the cursor
    rts
//=========================================================================================================
//    PRIVATE CHAT SCREEN
//=========================================================================================================
!private_chat_screen:                             // 
    jsr !start_menu_screen+                       //   
    lda #3                                        // Set a flag so other routines know that you
    sta SCREEN_ID                                 // are in a private chat screen
    jsr !restore_pm_screen+                       //  
    jsr !toggleText+                              // SCREEN_ID | Screen    
     
    jsr !delay+
    jmp !chat_screen+                             // #0        | Main Chat Screen
                                                  // #3        | Private Chat Screen 
!toggleText:                                      //           
    displayText(text_F5_toggle,1,0)               //                                               
rts
//=========================================================================================================
//     MAIN CHAT SCREEN
//=========================================================================================================
!main_chat_screen:                                // 
    ldx #0                                        // get ready to draw the line, x is our index
    stx SCREEN_ID                                 // also store zero in the screen id
!chat_screen:                                     // Draw the divider line
    lda #0                                        //
    sta MENU_ID                                   //
    lda #12                                       // color number 12 is gray
    sta _LINE_COLOR_                              // store the color code in $c9
    lda #21                                       // a line on screen line 21
    sta _LINE_POS_                                // 
    jsr !draw_menu_line+                          // 
                                                  // 
    lda VICEMODE                                  // 
    cmp #1                                        // 
    bne !+                                        //     
    displayText(text_error_vice_mode,3,8)         // 
                                                  // 
!:  lda #0                                        // Set the limits to where the cursor can travel
    sta HOME_COLM                                 // store 0 into home_column variable, so the cursor can not go below 0
    lda #22                                       // load 22 into accumulator
    sta HOME_LINE                                 // Store 22 into Home_line variable, so the cursor van not go above line 22
    lda #24                                       // load 24 into accumulator
    sta LIMIT_LINE                                // store 24 into limit_line variable so the cursor van not go below line 24
    lda #39                                       // load 39 into accumulator
    sta LIMIT_COLM                                // store 39 into the limit_column so the cursor can not go beyond that position
!ti:                                              // 
    jsr !text_input+                              // jump to the text input routine. We return from this routine when the users presses enter on the last input line     
                                                  // at this point we have returned from the text_input routine and we must send the typed message to the esp32
                                                  // so lets read the message fom screen, including the color information 
    lda SCREEN_ID                                 // check the screen id
    cmp #3                                        // if we are in private messaging (id = 3)
    beq !private_message+                         // then we can skip to label "private_message"
    lda $770                                      // if we are in public messaging, we want to check if the message starts with @
    cmp #0                                        // because that would mean you are trying to send a private message from the public screen
    bne !+                                        // if that is the case:
    jsr !backup_message_lines+                    // backup the message lines
    lda #1                                        // and set the restore message lines flag
    sta DO_RESTORE_MESSAGE_LINES                  // 
    jsr !backup_screen+                           // backup the public message screen
    jmp !private_chat_screen-                     // and jump to the private message screen to send you message privately
                                                  // 
!private_message:                                 // 
    lda $770                                      // if the message screen does not start with @,
    cmp #0                                        // then we raise an error "Don't send public msgs from priv. screen"
    beq !+                                        //
    lda #1
    sta SEND_ERROR
    displayText(text_error_private_message,1,0)   // then display the errormessage
    jsr !sounderror+                              // play the error sound.
    jmp !ti-                                      // return to text input  
                                                  // 
                                                  // find the message length
!:  ldx #0                                        // reset the message length variable to zero
    stx MESSAGELEN                                // 
                                                  // x is also our index
!loop:                                            // start a loop
    lda $770,x                                    // read a character from screen (the message)
    cmp #32                                       // test if it is a space
    beq !+                                        // 
    cmp #96                                       // screen code 96 also represents a space character
    beq !+                                        // 
    cmp #127                                      // screen codes >= 127 also need to be ignored
    bcs !+                                        // 
    stx MESSAGELEN                                // store x a as our message length
!:  inx                                           // increase x
    cpx #120                                      // until x reaches 120 (3 lines of 40 characters long)
    bne !loop-                                    // back to the loop
    lda MESSAGELEN                                // after te loop,
    cmp #0                                        // see if the message was empty
    bne !+                                        // do not send it in that case.
    jmp !empty_message+                           // 
!:  inc MESSAGELEN                                // add one more to the message length
    lda #255                                      // Delay 255... hamsters
    sta DELAY                                     // Store 255 in the DELAY variable
    jsr !delay+                                   // and call the delay subroutine
                                                  // 
                                                  // Next we need to store the character and color information into a buffer
                                                  // the chat message always starts at $770 in screen RAM and $db70 in color RAM
    ldx #0                                        // x is the index for reading the screen and color RAM
    ldy #0                                        // y is the index for writing to the TXBUFFER
    sty COLOR                                     // set the start color to 0
                                                  // 
!loop:                                            // 
    lda $db70,x                                   // read the color, this can be any number between 0 and 254, we need to bring it down to 144=black, 145=white, 146=red ect.
    and #15                                       // reduce the byte to the 4 least significant bits
    ora #144                                      // the do a logic OR operation with the number 144
    cmp COLOR                                     // compare it to the current color
    beq !+                                        // if the color stays the same, we do not add it to the buffer, only the color changes are important
    sta TXBUFFER,y                                // Store it in the buffer
    sta COLOR                                     // also update COLOR variable with the new color value                                                  
    iny                                           // increase the TXBUFFER index
                                                  // 
!:  lda $770,x                                    // read the character screen code from screen RAM
    sta TXBUFFER,y                                // store the character in the buffer
    iny                                           // increase the index for TXBUFFER
    inx                                           // increase the index for reading the screen and color RAM
    cpx MESSAGELEN                                // if x reaches the message lengt value, we are at the end of message,
    bne !loop-                                    // continue to loop while x < message length

!store_pm_user:                                   // store the PM_user 
    lda SCREEN_ID                                 // but only if we are on screen 3 (the private screen)
    cmp #3                                        // 3 means the private screen
    bne !send+                                    // if we are on any other screen, just send the message
    ldx #0
!loop:    
    lda $770,x    
    sta text_pmuser,x
    cmp #32
    beq !+
    inx
    jmp !loop-
!:  inx
    lda #128 
    sta text_pmuser,x
    
!send:                                            // 
    jsr !backup_message_lines+    
    lda COLOR                                     // Convert the last used color into a petsci color code                                        
    and #15                                       // that color could be a high number, reduce it to a 4 bit number so we get 0-15                                      
    tax                                           // transfer that number to x
    lda petsciColors,x                            // use a lookup table to find the petscii code                               
    sta CURSORCOLOR                               // Store that in variable CURSORCOLOR                                   
    lda #128                                      // load byte 128 in the accumulator
    sta TXBUFFER,y                                // and put it in the buffer as an end marker
                                                  // 
    jsr !clear_message_lines+                     //
    jsr !hide_cursor-                             //  
    jsr !wait_for_ready_to_receive+               // At this point we have the chat message from the screen, in the txbuffer
    lda #253                                      // Load 253 into accumulator    
    sta _IO1_                                     // Send the start byte (253 = send new chat message)
    jsr !send_buffer+                             // Send the message to the ESP32
    jsr !getResult+                               // 
    lda #10                                       //
    sta CHECKREPEAT                               //
    sta CHECKINTERVAL                             //
    lda #1                                        //
    sta WAITFORMESSAGE                            //
    lda #8                                        //
    sta TIMER2                                    //
    lda SEND_ERROR                                //
    cmp #1                                        //
    bne !exit+                                    //
    jsr !sounderror+                              //
    jsr !restore_message_lines+                   //
    jmp !ti-                                      //
!empty_message:                                   // 
                                                  // 
!exit:                                            // 
    jmp !chat_screen-                             // jump back to the start of the chat screen routine.

//=========================================================================================================
//     Play note and play song
//=========================================================================================================
!playnote:                                        // A=frequency, DELAY = tone length
    cmp #0                                        // if A=0 then play no sound, just a silent delay
    beq !tonelength+                              //
    sta $d401                                     // frequency voice 1 high byte 
    sta $d408                                     //
    lda #7                                        //
    sta $d403                                     //
    lda #7                                        //
    sta $d40a                                     //
    lda #255                                      //
    sta $d402                                     //
    sta $d409                                     //
    lda #0                                        // 
    sta $d400                                     // frequency voice 1 low byte  
    sta $d407                                     //
    lda #143                                      // set volume to max for all voices and MUTE voice 3
    sta $d418                                     //                                                                                             
    lda #0                                        // 
    sta $d405                                     // 
    sta $d40c                                     //
    lda #240                                      //
    sta $d406                                     // 
    sta $d40d                                     //
    lda #33                                       //
    sta $d404                                     //
    lda #65                                       //
    sta $d40b                                     // set triangle wave form (bit 4) and gate bit 0 to 1 (sound on)                                              // 
!tonelength:                                      //
    tya                                           //
    pha                                           // save value in accumulator
    jsr !delay+                                   //    
    pla                                           // restore value in accumulator
    tay                                           //   
    lda #32                                       // stop playing sound on voice 1
    sta $d404                                     //
    sta $d404                                     // 
    lda #64                                       // stop playing sound on voice 2
    sta $d40b                                     //
    sta $d40b                                     //
    lda #128                                      // set volume to NUL for all voices and MUTE voice 3
    sta $d418                                     //                                                                                             

    rts
    
!playsongk: 
   ldy #0
!fetchnote:
   lda (_NOTE_),y
   cmp #255
   beq !exit+
   sta DELAY
   iny
   lda (_NOTE_),y
   jsr !playnote-    
   iny   
   jmp !fetchnote-
!exit:
   rts

!sounderror:                                      // 
    lda #143                                      // set volume to max and mute voice 3
    sta $d418                                     // and store it here
    lda #5                                        // set the pitch very low
    sta $d401                                     // and store it here (voice 1)
    lda #15                                       // 
    sta $d405                                     // set attack / decay lenght (voice 1)
    lda #0                                        // 
    sta $d406                                     // set volume sustain to zero / release lenght (voice 1)
    lda #33                                       // sawtooth wave, and sound on
    sta $d404                                     // set sawtooth (bit 5) and gate bit 0 to 1 (sound on)
    lda #70                                       // Delay 70... hamsters
    sta DELAY                                     // Store 70 in the DELAY variable
    jsr !delay+                                   // and call the delay subroutine
    lda #32                                       // 
    sta $d404                                     // set gate bit 0 to 0 (sound off)
    rts                                           // 
                                                  // 

//=========================================================================================================
//     MAIN MENU
//=========================================================================================================
!start_menu_screen:                               // 
    jsr !hide_cursor-                             // Cursor off
    jsr $E544                                     // Clear screen
    jsr !draw_top_menu_lines+                     // 
    rts                                           // 
                                                  // 
//=========================================================================================================
!mainmenu:                                        //        
    playsong(song4)
    lda #1                                        //
    sta MENU_ID                                   //
    sta RETURNTOMENU                              //
    lda UPDATECHECK                               //
    cmp #2                                        //
    bne !+                                        //
    jsr !update_screen+                           //
                                                  //
!:  jsr !start_menu_screen-                       // 
    lda #22 ; sta _LINE_POS_                      // Load 23 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 23
    lda CONFIG_STATUS                             // Check the config status
    cmp #4                                        // Configuration complete?
    beq !all+                                     // Yes, show all
    cmp #3                                        // No, server config done?
    beq !serverdone+                              // Yes, show Account setup
    cmp #2                                        // No, WiFi config done?
    beq !wifidone+                                // Yes, show Server setup
    jmp !noconf+                                  // No, assume no configuration
                                                  // 
!all:                                             // 
                                                  // 
    displayText(text_menu_item_3,9,3)             // [F3] - List Users
    displayText(text_menu_item_6,13,3)            // [F5] - Help about private messaging
    jsr !display_F7_menuItem+                     // [F7] - Exit
    displayText(text_menu_item_8,19,3)            // [F8] - Output setup  
    displayText(text_menu_item_4,11,3)            // [F4] - Server Setup                                              // 
!wifidone:
!serverdone:                                      // 
                                                  // 
    displayText(text_menu_item_2,7,3)             // [F2] - Account setup
                                                  // 
                                                  // 
                                                  //     
                                                  // 
!noconf:                                          // 
    displayText(text_main_menu,1,15)              // Text MAIN MENU
    displayText(text_menu_item_1,5,3)             // [F1] - WiFi Setup
    displayText(text_menu_item_5,15,3)            // [F6] - About this Software
                                                  // 
    displayText(text_version,23,1)                // Software version info
    displayText(versionmask,23,9)                 // Software version info
    displayText(version,23,13)                    // Software version info
    displayText(version_date,23,32)               // Software version info
    lda VICEMODE                                  // check vice mode                                    
    cmp #1                                        // do not display the ESP32 version in vice mode
    beq !keyinput+                                //
    displayText(SWVERSION,23,22)                  // display the ESP32 version on the bottom of the screen 
!keyinput:                                        // 
                                                  // 
    jsr $ffe4                                     // Call KERNAL routine: Get character from keyboard buffer                  
!:  cmp #133                                      // F1 key pressed?
    bne !+                                        // No, next
    jmp !wifi_setup+                              // Yes, go to WiFi setup
!:  cmp #137                                      // F2 key pressed?
    bne !F3+                                      // No, next
    jsr !callstatus+                              // Yes, check the configuration status
    lda CONFIG_STATUS                             // 
    cmp #3                                        // F2 Allowed now?
    beq !FA+                                      // No, back to keyinput
    cmp #4                                        // F2 Allowed now?
    bne !keyinput-                                // No, back to keyinput
!FA:jmp !account_setup+                           // Yes, go to Account setup
!F3:cmp #134                                      // F3 key pressed?
    bne !F4+                                      // No, next
    jsr !callstatus+                              // Yes, check the configuration status
    lda CONFIG_STATUS                             // 
    cmp #4                                        // F3 Allowed now?
    bne !keyinput-                                // No, back to keyinput
    jmp !list_users+                              // Yes, jump to list users.                                                                   
!F4:cmp #138                                      // F4 key pressed?
    bne !F5+                                      // No, next
    jsr !callstatus+                              // Yes, check the configuration status
    lda CONFIG_STATUS                             // 
    cmp #2                                        // F4 Allowed in this stage?
    beq !FS+                                      // Yes, go to server setup
    cmp #3                                        // F4 Allowed in this stage?
    beq !FS+                                      // Yes, go to server setup
    cmp #4                                        // F4 Allowed in this stage?
    bne !keyinput-                                // No, back to keyinput
!FS:jmp !server_setup+                            // Yes, go to server setup
!F5:cmp #135                                      // F5 key pressed?
    bne !F6+                                      // No, next
    jmp !osc_setup+                             // Yes, goto private messages help screen
!F6:cmp #139                                      // F6 Pressed?
    bne !F7+                                      // No, next.
    jmp !about_screen+                            // Yes, show the about screen
!F7:cmp #136                                      // F7 key pressed?
    bne !F8+                                      // No, next
    jsr !callstatus+                              // Yes, check the configuration status
    lda CONFIG_STATUS                             // 
    cmp #4                                        // F7 Allowed now?
    bne !F8+                                      // No, check for F8
    jmp !exit_menu+                               // Yes, exit menu
!F8:cmp #140                                      // F8 key pressed?
  bne !FX+                                        // No, next
    jsr !callstatus+                              // Yes, check the configuration status
    lda CONFIG_STATUS                             // 
    cmp #4                                        // F8 Allowed here?
  bne !FX+                                        // Not yet, back to key input 
    jmp !output_setup+                            // Jump to output device setup (If any)
!FX:jmp !keyinput-                                // Ignore all other keys and wait for user input
                                                  // 
!exit_menu:                                       //                                  
!exit_main_menu:                                  // F7 Pressed, prepare to exit to chat screen
    lda TEMPCOLOR                                 // we saved the cursor color when we opened the main menu
    tax                                           // but is should be translated to a petsci color
    lda petsciColors,x                            // fetch the petsci color code 
    sta CURSORCOLOR                               // and store it in the cursorcolor          
    lda SCREEN_ID                                 // 
    cmp #3                                        // 
    beq !p+                                       // 
    jsr $E544                                     // Clear screen
    jsr !restore_screen+                          // Restore the screen
    jmp !main_chat_screen-                        // Jump to the main chat screen
!p: jsr !restore_pm_screen+                       // Restore the screen
    jmp !private_chat_screen-                     // 
                                                  //                                                 
//=========================================================================================================
//    MENU WIFI SETUP
//=========================================================================================================
// send byte 248 to get the wifi connection status
// send byte 251 to get current wifi ssid, password and time offset
// send byte 252 to set new ssid, password and time offset
//=========================================================================================================
!wifi_setup:                                      //     
    lda #255                                      //
    sta DELAY                                     //
    jsr !start_menu_screen-                       // 
    lda #10 ; sta _LINE_POS_                      // Load 8 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call draw_menu_line sub routine to draw a line on row 8
    lda #20 ; sta _LINE_POS_                      // Load 20 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call draw_menu_line sub routine to draw a line on row 20
                                                  // 
    displayText(text_wifi_menu,1,15)              // Display the menu title on line 1, row 15
    displayText(text_wifi_ssid,4,1)               // Display static text "SSID:" on line 4, row 1 
    displayText(text_wifi_password,6,1)           // Display static text "Password:" on line 6, row 1 
    displayText(text_time_offset,8,1)             //                
    jsr !display_F7_menuItem+                     // Display "[ F7 ] exit menu" on line 17, row 3. 
    lda VICEMODE                                  // If the cartridge is not attached, then                                  
    cmp #1                                        // skip the part where we ask for wifi status          
    bne !+                                        // see if the vicemode variable is 1
    jmp !notVice+                                 // if so jump to not-vice                                                   
!:  jsr !get_wifi_status+                         // get the wifi status into the buffer
//!:  lda #248                                      // Load number #248 (ask for WiFi status)
//    sta CMD                                       // Store that in CMD variable
//    jsr !send_start_byte_ff+                      // Call the sub routine to send 248 to the esp32
//    lda TIMOUTERROR                               // 
//    cmp #1                                        //
//    bne !+                                        //           
//    jsr !delay+                                   //
//    jmp !-                                        //
    
!:  displayText(RXBUFFER,23,3)                    // Display the buffer on screen
    lda RXBUFFER                                  // 
    cmp #146                                      // Buffer starts with color code RED (because connection failed)
    beq !wifi_error+                              // 
    jmp !wifi_okay+                               // 
!wifi_error:                                      // 
    jsr !sounderror-                              // 
    jmp !continue+                                // 
!wifi_okay:                                       // 
    playsong(song2)                               // 
!continue:                                        // 
    lda #251                                      // Load number #251  (ask for WiFi SSID)
    sta CMD                                       // Store that in variable CMD
    jsr !send_start_byte_ff+                      // Call the sub routine to send 251 to the esp32
    lda TIMOUTERROR                               //
    cmp #1                                        //
    bne !+                                        //           
    jsr !delay+                                   //
    jmp !continue-                                //                                              
                                                  //
!:  lda #1                                        // the RXBUFFER now contains ssid[32]password[32]timeoffset[128]
    sta $02                                       //
    jsr !splitRXbuffer+                           //
    displayText(SPLITBUFFER,4,7)                  // Display the buffers on screen (SSID name)
                                                  //
    lda #2                                        //
    sta $02                                       //
    jsr !splitRXbuffer+                           //
    displayText(SPLITBUFFER,6,11)                 // Display the buffers on screen (password)
                                                  //
    lda #3                                        //
    sta $02                                       //
    jsr !splitRXbuffer+                           //
    displayText(SPLITBUFFER,8, 23)                // Display the buffers on screen (time offset from GMT)
                                                  //                                                  
!notVice:                                         // 
    lda #156                                      // Set the limits to where the cursor can travel
    sta CURSORCOLOR                               //
    lda #4                                        // Load 4 into accumulator
    sta HOME_LINE                                 // Store 4 into Home_line variable, so the cursor van not go above line 4
    sta LIMIT_LINE                                // Store 4 into limit_line variable so the cursor van not go below line 4
    lda #7                                        // Load 7 into accumulator
    sta HOME_COLM                                 // Store 7 into home_column variable, so the cursor can not go below 7
    lda #39                                       // Load 39 into accumulator
    sta LIMIT_COLM                                // Store 35 into the limit_column so the cursor can not go beyond that position
    lda #0                                        // Load 0 into accumulator
    sta SCREEN_ID                                 // and store it as the ID of this screen    
    lda #1                                        //
    sta MENU_ID                                   //
    sta CLEAR_FIELD_FLAG                          // and SET clear text flag to 1 (default is zero)
    jsr !text_input+                              // Call the text input routine, we will be back when the user presses RETURN
                                                  // 
    lda #31                                       // Set the limits to where the cursor can travel
    sta CURSORCOLOR                               //
    lda #6                                        // Load 6 into accumulator
    sta LIMIT_LINE                                // Store 6 into limit_line variable so the cursor van not go below line 24
    sta HOME_LINE                                 // Store 6 into Home_line variable, so the cursor van not go above line 22
    lda #11                                       // Load 11 into accumulator
    sta HOME_COLM                                 // Store 11 into home_column variable, so the cursor can not go below 10
    lda #1                                        // Load 1 into the accumulator
    sta CLEAR_FIELD_FLAG                          // SET clear text flag to 1 (default is zero)
    jsr !text_input+                              // Call text input routine, we will be back when the user presses RETURN
                                                  //
    lda #149                                      // Set the limits to where the cursor can travel
    sta CURSORCOLOR                               //
    lda #8                                        // Load 8 into accumulator
    sta LIMIT_LINE                                // Store 8 into limit_line variable so the cursor van not go below line 24
    sta HOME_LINE                                 // Store 8 into Home_line variable, so the cursor van not go above line 22
    lda #23                                       // Load 14 into accumulator
    sta HOME_COLM                                 // Store 14 into home_column variable, so the cursor can not go below 10
    lda #1                                        // Load 1 into the accumulator
    sta CLEAR_FIELD_FLAG                          // SET clear text flag to 1 (default is zero)
    jsr !text_input+                              // Call text input routine, we will be back when the user presses RETURN 
    jsr !hide_cursor-                             // Hide the cursor
                                                  // 
    displayText(text_save_settings,14,3)          // 
                                                  // 
!keyinput:                                        // At this point the user can select F1 or F7 to Save settings and Test settings, or exit the menu
                                                  // 
    jsr !wait_for_a_key+                          //
    cmp #133                                      // F1 key pressed?
    beq !save_settings+                           // If true, save the WiFi settings
    cmp #136                                      // F7 key pressed?
    beq !exit_menu+                               // If true, exit to main menu
    jmp !keyinput-                                // Ignore all other keys and wait for user input again
                                                  // 
!exit_menu:                                       // F7 Pressed!
                                                  // We reached the end so
    jmp !mainmenu-                                // we jump back to main menu
                                                  // 
!save_settings:                                   // F1 pressed, we are going to save the WiFi settings
    lda VICEMODE                                  // \                                              
    cmp #1                                        //  \ Skip save settings if we run in simulation without Cartrdige         
    bne !readSsid+                                //  /   
    jmp !wifi_setup-                              // /
!readSsid:                                        //
                                                  // \
    lda #$A7                                      //  \
    sta _FIELD_                                   //   The ssid is at screen memory location: $04A7
    lda #$04                                      //  /
    sta _FIELD_ +1                                // /
    lda #33                                       // set the number of character to read from screen
    sta READLIMIT                                 //
    jsr !read_from_screen+                        // Read the SSID Name from screen into the TXBUFFER
    jsr !wait_for_ready_to_receive+               // At this point we have the SSID name, from the screen, in the txbuffer
    lda #252                                      // Load 252 into accumulator
    sta _IO1_                                     // Send the start byte (252 = send wifi information)
    jsr !send_buffer+                             // Send the new SSID to the ESP32
!readPassword:                                    //
    lda #$FB                                      // - The password is at screen memory location: $4FB
    sta _FIELD_                                   // 
    lda #28                                       // set the number of character to read from screen
    sta READLIMIT                                 //
    jsr !read_from_screen+                        // Read the PASSWORD from screen into the TXBUFFER
                                                  // At this point we have the password, from the screen, in the txbuffer
    jsr !wait_for_ready_to_receive+               // Prepare the ESP to receive
    jsr !send_buffer+                             // Send the new password to the ESP32
                                                  //
!readTimeOffset:                                  //
    inc _FIELD_ +1                                // Next read the time offset from the screen
    lda #$57                                      // the time offset starts at $0557
    sta _FIELD_                                   // 
    lda #5                                        // set the number of character to read from screen
    sta READLIMIT                                 //
    jsr !read_from_screen+                        // read it
    jsr !wait_for_ready_to_receive+               // Prepare the ESP to receive
    jsr !send_buffer+                             // Send the new time offset to the ESP32
                                                  //
    ldx #23 ; jsr $e9ff                           // Clear display line 23 (where the connection status is)
                                                  //                                                      
                                                  // Now we need to wait a few seconds so the ESP can restart wifi with the new credentials
    lda #255                                      // Delay 255... hamsters
    sta DELAY                                     // Store 255 in the DELAY variable
    lda #58                                       // setup the count down timer, ascii code for ':' (one above 9)
    sta text_wifi_wait_countdown                  // we count down from 9 to 0
!waitforwifi:                                     // this is a 10x loop to wait for wifi
    jsr !delay+                                   // call the delay subroutine    
    jsr !get_wifi_status+                         //
    lda RXBUFFER                                  // 
    cmp #149                                      // Buffer starts with color code GREEN if connection was succesful
    beq !endwait+                                 // once we have wifi, break out of the loop     
    dec text_wifi_wait_countdown                  // decrease the count down, 
    displayText(text_wifi_wait,23,3)              // Display the text "wait for wifi connection
    lda text_wifi_wait_countdown                  // check the counter (ascii code 47 is one below 0)
    cmp #47                                       // if we fall below zero, exit the loop
    bne !waitforwifi-                             //
!endwait:
    ldx #23 ; jsr $e9ff                           // Clear line 23 (where the connection status is)
    jsr !callstatus+                              // Check the configuration status
    lda CONFIG_STATUS                             // 
    cmp #4                                        // Config already done?
    beq !+                                        // if so, we do not have to alter the status
    lda #3                                        // Tell the main menu that WiFi is configured
    jsr !sendstatus+                              // 
!:  jmp !wifi_setup-                              // Jump to start WiFi setup

!get_wifi_status:
!:  lda #248                                      // Load number #248 (ask for WiFi status)
    sta CMD                                       // Store that in CMD variable
    jsr !send_start_byte_ff+                      // Call the sub routine to send 248 to the esp32
    lda TIMOUTERROR                               // 
    cmp #1                                        //
    bne !+                                        //           
    jsr !delay+                                   //
    jmp !-                                        //                                                  
!:  rts 
//=========================================================================================================
//    MENU ACCOUNT SETUP
//=========================================================================================================
// send byte 243 to get the mac address, registration ID and users nick name and registration status
// send byte 240 to set the new registration code and nickname
//=========================================================================================================
!account_setup:                                   // 
    lda #255                                      //
    sta DELAY                                     //
    jsr !checkWiFi+                               // check if we have wifi   
    jsr !start_menu_screen-                       // 
    lda #10 ; sta _LINE_POS_                      // Load 10 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 8
    lda #20 ; sta _LINE_POS_                      // Load 20 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 20
    displayText(text_account_menu,1,15)           // Display the menu title on line 1, row 15,
!ac_wifi_check:                                   //
    lda HAVEWIFI                                  //
    cmp #1                                        //
    beq !+                                        //
    displayText(text_any_key,21,7)                //
    displayText(text_error_no_internet,4,1)       //
    jsr !wait_for_a_key+                          //
    jmp !mainmenu-                                //
!:  lda #10 ; sta _LINE_POS_                      // Load 10 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 8
    displayText(text_account_mac,4,1)             // Display static text "mac address:" on line 4, row 1,  
    displayText(text_account_regid,6,1)           // Display static text "regid:" on line 6, row 1,  
    displayText(text_account_nick_name,8,1)       // Display static text "nickname:" on line 8, row 1,  
    displayText(text_account_menu_item_2,15,3)    // Display "[ F6 ] Factory defaults" on line 13, row 1. 
    lda #10 ; sta _LINE_POS_                      // Load 10 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 10
    jsr !display_F7_menuItem+                     // Display "[ F7 ] exit menu" on line 15, row 1.  
                                                  //
    lda VICEMODE                                  // \                                  
    cmp #1                                        //  \ Skip receiving the data from the cartridge if the cartridge is not attachted! 
    bne !+                                        //  /  
    jmp !fill_fields+                             // /   
                                                  // 
!sendcmd:                                         // 
!:  lda #243                                      // load the number #243
    sta CMD                                       // Store that in variable CMD
    jsr !send_start_byte_ff+                      // Call the sub routine to send 243 to the esp32 to ask for the Mac Address, reg id and nickname
    lda TIMOUTERROR                               // RXBUFFER now contains macaddress[32]regid[32]nickname[32]regstatus[128]
    cmp #1                                        //
    bne !+                                        //           
    jsr !delay+                                   //
    jmp !sendcmd-                                 //
                                                  //
!:  lda #1                                        // we need the first element from the RXBUFFER (macaddress)
    sta $02                                       // store 1 (1=first element) in $02
jsr !splitRXbuffer+                               // copy the first element to Splitbuffer
    displayText(SPLITBUFFER,4,14)                 // Display the buffer (containing mac address) on screen
                                                  // 
    lda #2                                        // now we need the second element from the RX buffer (registration id)
    sta $02                                       // so we put #2 in address $02
    jsr !splitRXbuffer+                           // and call the split routine to copy the element to the Splitbuffer
    displayText(SPLITBUFFER,6,18)                 // Display the buffer (containing registration id) on screen
                                                  //
    lda #3                                        // repeat for the third element (nick name)
    sta $02                                       // copy #3 to address $02
    jsr !splitRXbuffer+                           // and call the splut routine
    displayText(SPLITBUFFER,8,12)                 // Display the buffer (containing nick name) on screen
                                                  //
    lda #4                                        // repeat for the fourth element (registration status)
    sta $02                                       // put #4 in address $2
    jsr !splitRXbuffer+                           // and call the split routine
                                                  // 
    lda SPLITBUFFER                               // load the first char of the registration status into the accumulator
    cmp #21                                       // compare to 'u' (u means unregistred, so that is an error)
    bne !+                                        // if not equal, skip to the next label
    displayText(text_unreg_error,22,1)            // Display a error message "unregistered cartridge"
    displayText(SERVERNAME,23,21)                 // display the server name or IP on screen as part of the error message
                                                  //
!:  cmp #14                                       // compare to 'n'
    bne !+                                        // if not, skip to the next label
    displayText(text_name_taken,22,4)             // display an error "nickname is alreay taken by someone else"
    jsr !sounderror-                              // Play the error sound
!:  cmp #18                                       // compare to 'r' (registration was succesful)
    bne !+                                        // if not skip to the next label
    displayText(text_registration_ok,22,6)        // display the success message
    playsong(song2)                               // 
    lda #4                                        // Tell the main menu that Registartion is valid and complete and the user is not blocked
    jsr !sendstatus+                              // 
!:                                                //                                                                                                    
                                                  // Now we need a text input box so the user can change the registration id and or nick name
!fill_fields:                                     // Set the limits to where the cursor can travel
    lda #2                                        // Load 2 into accumulator
    sta MENU_ID                                   // and store it as the ID of this menu
    lda #6                                        // Load 4 into accumulator
    sta HOME_LINE                                 // Store 4 into Home_line variable, so the cursor van not go above line 4
    lda #18                                       // Load 7 into accumulator
    sta HOME_COLM                                 // Store 7 into home_column variable, so the cursor can not go below 7
    lda #6                                        // Load 4 into accumulator
    sta LIMIT_LINE                                // Store 4 into limit_line variable so the cursor van not go below line 4
    lda #39                                       // Load 39 into accumulator
    sta LIMIT_COLM                                // Store 39 into the limit_column so the cursor can not go beyond that position
    lda #1                                        // Load 1 intop accumulator
    sta CLEAR_FIELD_FLAG                          // and SET clear text flag to 1 (default is zero)
    lda #31                                       //
    sta CURSORCOLOR                               //
    jsr !text_input+                              // Call the text input routine, we will be back when the user presses RETURN
    lda #8                                        // Load 6 into accumulator
    sta HOME_LINE                                 // Store 6 into Home_line variable, so the cursor van not go above line 22
    sta LIMIT_LINE                                // Store 6 into limit_line variable so the cursor van not go below line 24
    lda #12                                       // Load 11 into accumulator
    sta HOME_COLM                                 // Store 11 into home_column variable, so the cursor can not go below 10
    lda #22                                       // Load 22 into accumulator
    sta LIMIT_COLM                                // Store 22 into the limit_column so the cursor can not go beyond that position
    lda #1                                        // 
    sta CLEAR_FIELD_FLAG                          // 
    lda #149                                      //
    sta CURSORCOLOR                               //
    jsr !text_input+                              // Call the text input routine, we will be back when the user presses RETURN
    jsr !hide_cursor-                             // Hide the cursor
                                                  // 
    displayText(text_save_settings,13,3)          // Display "[ F1 Save settings" on line 13, row 3 
                                                  // 
!keyinput:                                        // At this point the user can select F1 or F7 to Save settings and Test settings, or exit the menu
                                                  // 
    jsr !wait_for_a_key+                          //
    cmp #133                                      // F1 key pressed?
    beq !save_settings+                           // If true, save the Account settings
    cmp #139                                      // F6 Key pressed?
    beq !reset_factory+                           // If true, restore to default settings
    cmp #136                                      // F7 key pressed?
    beq !exit_menu+                               // If true, exit to main menu.
    jmp !keyinput-                                // Ignore all other keys and wait for user input again
                                                  // 
!exit_menu:                                       // F7 Pressed!
                                                  // We reached the end so
    jmp !mainmenu-                                // we jump back to main menu
                                                  // 
!save_settings:                                   // Read the registration code from screen into the TXBUFFER
                                                  // \
    lda #$02                                      //  \
    sta _FIELD_                                   //   The registration code starts at screen memory location: $0502
    lda #$05                                      //  /
    sta _FIELD_ +1                                // /
    lda #17                                       // set the number of characters to read to 17
    sta READLIMIT                                 //
    jsr !read_from_screen+                        // Read the registration code from screen into the TXBUFFER
    jsr !wait_for_ready_to_receive+               // Prepare the ESP to receive
    lda #240                                      // Load 240 in accumulator
    sta _IO1_                                     // Send the start byte (240 = send new registration code)
    jsr !send_buffer+                             // Send the new registration code to the ESP32
                                                  // Read the Nick Name from screen into the TXBUFFER
    lda #$4c                                      // 
    sta _FIELD_                                   // - The nick name is at screen memory location: $054c
    lda #11                                       // Set the number of characters to read to 11
    sta READLIMIT                                 //
    jsr !read_from_screen+                        // Read the registration code from screen into the TXBUFFER
                                                  // At this point we have the nick name, from the screen, in the txbuffer
    jsr !wait_for_ready_to_receive+               // Prepare the ESP to receive
    jsr !send_buffer+                             // Send the new nickname to the ESP32
                                                  // 
    ldx #22 ; jsr $E9FF                           // Clear line 22
    inx ; jsr $E9FF                               // Clear line 23
    displayText(text_settings_saved,23,6)         // 
                                                  // 
    lda #255                                      // Delay 255... hamsters
    sta DELAY                                     // Store 255 in the DELAY variable
    jsr !delay+                                   // and call the delay subroutine
    jsr !delay+                                   // a few times
    jsr !delay+                                   // a few times
    jsr !delay+                                   // a few times
    jsr !delay+                                   // a few times
    jmp !account_setup-                           // Rinse and repeat
                                                  // 
!reset_factory:                                   // 
                                                  // 
    jsr !hide_cursor-                             // Hide the cursor
    jsr $e544                                     // Clear screen
                                                  // 
    displayText(text_reset_shure,13,10);          // 
                                                  // 
!keyinput:                                        // 
    jsr !wait_for_a_key+                          //
    cmp #138                                      // F4 pressed?
    beq !reset_for_real+                          // If true, we are going to default settings
    jmp !account_setup-                           // No, second thoughts, go back to config screen.
                                                  // 
!reset_for_real:                                  // 
    jsr !delay+                                   // 
    jsr !wait_for_ready_to_receive+               // User has selected and confirmed 'reset to factory defaults' function
    lda #244                                      // Load 244 in accumulator
    sta _IO1_                                     // Send the start byte 244 (244 = reset to factory defaults)
!:  ldx #0                                        // x will be our index when we loop over the version text, we start at 1 to skip the first color byte
!sendconfirmation:                                // 
    jsr !wait_for_ready_to_receive+               // wait for ready to receive (bit D7 goes high)
    lda factoryreset,x                            // load a byte from the version text with index x
    sta _IO1_                                     // send it to IO1
    cmp #128                                      // if the last byte was 128, the buffer is finished
    beq !+                                        // exit in that case
    inx                                           // increase the x index
    jmp !sendconfirmation-                        //
                                                  //
                                                  // 
!loop_forever:                                    //                              
    jsr !delay+                                   //           
    jsr !delay+                                   //
    jsr !delay+                                   //
    jmp !reset_for_real-                          // Loop forever and wait for the ESP32 to reset the C64
                                                  // 
//=========================================================================================================
//    SUB ROUTINE TO SPLIT RXBUFFER
//=========================================================================================================
!splitRXbuffer:                                   //
                                                  // RXBUFFER now contains FOR EXAMPLE macaddress[129]regid[129]nickname[129]regstatus[128]
    ldx #0                                        // load zero into x and y    
    ldy #0                                        //   
    lda RXBUFFER,x                                // See if the RXBUFFER is empty
    cmp #128                                      // exit if it is..
    beq !exit+                                    //
!read:                                            // read a byte from the index buffer   
    lda RXBUFFER,x                                // copy that byte to the split buffer   
    sta SPLITBUFFER,y                             // until we find byte 129   
    cmp #129                                      //    
    beq !+                                        //    
    cmp #128                                      // or the end of line character   
    beq !+                                        //    
    inx                                           // increase the x index   
    iny                                           // and also the y index   
    jmp !read-                                    // back to the start to get the next character   
!:                                                //    
    lda #128                                      //     
    sta SPLITBUFFER,y                             // load 128 (the end byte) into the splitbuffer   
    dec $02                                       // decrease $02. This address holds a number that indicates   
    lda $02                                       // which word we need from the RXBUFFER   
    cmp #0                                        // so if $02 is equal to zero, we have the right word   
    beq !exit+                                    // exit in that case   
    ldy #0                                        // if we need the next word   
    inx                                           // we reset the y index,   
    jmp !read-                                    // increase the x index   
                                                  // and get the next word from the RX buffer
!exit:                                            // 
    rts                                           // return.   
//=========================================================================================================
// Check if we have Wifi
//=========================================================================================================
!checkWiFi:                                       // 
    lda VICEMODE                                  //
    cmp #1                                        //
    beq !weHave_wifi+                             //
    lda #0                                        //
    sta HAVEWIFI                                  //
    lda #248                                      //
    sta CMD                                       // Store that in variable CMD
    jsr !send_start_byte_ff+                      // Call the sub routine to send 248 to the esp32 to ask for the wifi
    lda RXBUFFER                                  // the first byte of RXBUFFER now contains 146 or 149
    cmp #149                                      // for Not connected or Connected
    bne !+                                        //
!weHave_wifi:                                     //
    lda #1                                        //                                           
    sta HAVEWIFI                                  // We are connected, just return
!:  rts                                           //
//=========================================================================================================
//    MENU SERVER SETUP
//=========================================================================================================
// send byte 245 to get current server ip/fqdn
// send byte 246 to set new server ip/fqdn
// send byte 235 to set configuration status
//=========================================================================================================
!server_setup:                                    // 
    lda #255                                      // 
    sta DELAY                                     //
    jsr !checkWiFi-                               //
    jsr !start_menu_screen-                       // 
    lda #8 ; sta _LINE_POS_                       // Load 8 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 8
    lda #20 ; sta _LINE_POS_                      // Load 20 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 20
                                                  // 
    displayText(text_server_menu,1,13)            // Display the menu title on line 1, row 15   
    lda HAVEWIFI                                  // check if we have wifi
    cmp #1                                        // if yes, continue
    beq !+                                        // if not, there is no need for server setup
    ldx #6 ; jsr $e9ff                            // clear line 6
    ldx #8 ; jsr $e9ff                            // clear line 8
    jmp !ac_wifi_check-                           // tell the user to go back and check wifi setup
!:                                                // Now ask for the server ip/fqdn from ESP
//  jsr !callstatus+                              // Call the sub routine to get config status and Servername
    jsr !display_F7_menuItem+                     // Display "[ F7 ] exit menu" on line 17, row 3                                                  // 
    displayText(SERVERNAME,4,9)                   // display the server name on screen
    lda CONFIG_STATUS                             //
    cmp #2                                        //
    beq !server_setup_2+                          //
    jsr !wait_for_ready_to_receive+               // Prepare the ESP to receive
    lda #238                                      // Load 238 into accumulator
    sta _IO1_                                     // Send the start byte (238 = test chatserver connectivity)
    lda #255                                      // Set the delay variable to almost nothing, only 2 hamsters
    sta DELAY                                     // Store 255 in the DELAY variable
    jsr !delay+                                   //
    jmp !connection_check+                        // 
!server_setup_2:                                  // 
    ldx #23 ; jsr $e9ff                           // Clear line 23 (where the connection status is)
    ldx #15 ; jsr $e9ff                           // Clear line 15 (where the Save Settings line is)
    lda #255                                      // Delay 255... hamsters
    sta DELAY                                     // Store 255 in the DELAY variable
    lda #1                                        // Load 1 into accumulator
    sta MENU_ID                                   // and store it as the ID of this menu (id =1, same as wifi menu, functionality / logic is the same)
    sta CLEAR_FIELD_FLAG                          // and SET clear text flag to 1 (default is zero)
                                                  // Set the limits to where the cursor can travel
    lda #4                                        // Load 4 into accumulator
    sta HOME_LINE                                 // Store 4 into Home_line variable, so the cursor can not go above line 4
    sta LIMIT_LINE                                // Store 4 into limit_line variable so the cursor van not go below line 4
    lda #9                                        // Load 9 into accumulator
    sta HOME_COLM                                 // Store 9 into home_column variable, so the cursor can not go before 9
    lda #39                                       // Load 35 into accumulator
    sta LIMIT_COLM                                // Store 39 into the limit_column so the cursor can not go beyond that position
    lda #156                                      // set cursor color to purple
    sta CURSORCOLOR                               //
    jsr !text_input+                              // Call the text input routine, we will be back when the user presses RETURN
    jsr !hide_cursor-                             // Hide the cursor
                                                  // 
    displayText(text_save_settings,15,3)          // display "[ F1 ] Save Settings" on line 15, row 3
                                                  // 
!keyinput:                                        // At this point the user can select F1 or F7 to Save settings and Test settings, or exit the menu
    jsr !wait_for_a_key+                          //
    cmp #133                                      // F1 key pressed?
    beq !save_settings+                           // If true, save the server settings
    cmp #136                                      // F7 key pressed?
    beq !exit_menu+                               // If true, exit to main menu
    jmp !keyinput-                                // Ignore all other keys and wait for user input again
                                                  // 
!exit_menu:                                       // F7 Pressed!
                                                  // We reached the end so
    jmp !mainmenu-                                // we jump back to main menu
                                                  // 
!save_settings:                                   // Read the server ip/fqdn from screen into the TXBUFFER
                                                  // \
    lda #$A9                                      //  \
    sta _FIELD_                                   //   The server ip/fqdn starts at screen memory location: $04A9
    lda #$04                                      //  /
    sta $fc                                       // /
    lda #29                                       // set the number of characters to read to 29
    sta READLIMIT                                 //
    jsr !read_from_screen+                        // Read the server ip/fqdn from screen into the TXBUFFER
    jsr !wait_for_ready_to_receive+               // At this point we have the server ip/fqdn, from the screen, in the txbuffer
    jsr !wait_for_ready_to_receive+               // Prepare the ESP to receive
    lda #246                                      // Load 246 into accumulator
    sta _IO1_                                     // Send the start byte (246 = send new server ip/fqdn)
    jsr !send_buffer+                             // Send the new server ip/fqdn to the ESP32
                                                  // 
    displayText(text_settings_saved,23,6)         // 
    ldx #24 ; jsr $e9ff                           // Clear line 24 (where the connection status is)
    jsr !callstatus+                              // Check the configuration status
    lda CONFIG_STATUS                             // 
    cmp #4                                        // Server configuration changed, no change in status
    beq !nochange+                                // Skip status update
    lda #3                                        // Load "C" into accumulator
    jsr !sendstatus+                              // 
                                                  // 
!nochange:                                        // 
                                                  // Now check if we can connect to the server                                                  
    jsr !wait_for_ready_to_receive+               // Prepare the ESP to receive
    lda #238                                      // Load 238 into accumulator
    sta _IO1_                                     // Send the start byte (238 = test chatserver connectivity)
    lda #255                                      //    
    sta DELAY                                     //    
    jsr !delay+                                   // and jump to the delay subroutine
    jsr !delay+                                   //
    jsr !delay+                                   //  
    jsr !delay+                                   // 
    jsr !delay+                                   // 
    jsr !delay+                                   // 
    jsr !delay+                                   // 
    jsr !delay+                                   // 
    jsr !delay+                                   // 
                                                  // 
!connection_check:                                // are we connected to a chat server?
    lda VICEMODE                                  //
    cmp #1                                        //
    beq !exit1+                                   //
    lda #237                                      // Load 237 in accumulator (get current connection status)
    sta CMD                                       // Store that in variable CMD
    jsr !send_start_byte_ff+                      // Call the sub routine to obtain connection status from esp32
    lda TIMOUTERROR                               // 
    cmp #1                                        //
    bne !+                                        //           
    jsr !delay+                                   //
    jmp !connection_check-                        //
                                                  //
!:  lda RXBUFFER                                  // 
    cmp #146                                      // Connection status begins with color code RED
    beq !Error+                                   // 
    cmp #149                                      // Connection status begins with color code GREEN
    beq !Succes+                                  //  
                                                  // 
!Error:                                           // 
    ldx #24 ; jsr $e9ff                           // Clear line 24 (where the connection status is)
    displayText(RXBUFFER,24,5)                    // Display the buffer (containing connection status) on screen
    jsr !sounderror-                              // 
    jsr !delay+                                   // and jump to the delay subroutine
    jsr !delay+                                   // 
    jsr !delay+                                   // 
!exit1:                                           //
    jmp !server_setup_2-                          // 
!Succes:                                          // 
    ldx #24 ; jsr $e9ff                           // Clear line 24 (where the connection status is)
    displayText(RXBUFFER,24,8)                    // Display the buffer (containing connection status) on screen
    playsong(song2)                               // 
    jsr !delay+                                   // and jump to the delay subroutine
    jsr !delay+                                   // 
    jsr !delay+                                   // 
    jmp !server_setup_2-                          // 
                                                  //
//=========================================================================================================
//    MENU OUTPUT SETUP
//=========================================================================================================
!output_setup:                                    // This needs to be done after every reset.
                                                  // 
    jsr !start_menu_screen-                       // 
    lda #6 ; sta _LINE_POS_                       // Load 7 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 8
    lda #22 ; sta _LINE_POS_                      // Load 22 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 20
    displayText(text_output_menu,1,13)            // Display the menu title on line 1, row 13       
    displayText(text_output_enable,9,3)           // display "[ F1 ] Enable Output" on line 9, row 3  
    displayText(text_output_disable,11,3)         // Display "[ F3 ] Disable Output" on line 11, row 3
    jsr !display_F7_menuItem+                     // Display "[ F7 ] exit menu" on line 17, row 3. 

!loopdeloop:
    lda PRINTER_ENABLED_FLAG                      // Get current status 
    cmp #0                                        //
    bne !+                                        //
    displayText(text_disabled,4,12)               // Display active status
    jmp !hcursor+                                 //
!:  displayText(text_enabled,4,12)                // 
    
!hcursor:

    jsr !hide_cursor-                             // Hide the cursor
                                                  // 
!keyinput:                                        // At this point the user can select F1, F3 or F7
                                                  // 
    jsr $ffe4                                     // Call KERNAL routine: Get character from keyboard buffer
    cmp #133                                      // F1 key pressed?
    bne !checkF3+                                 // No, check for F3                 
    lda #4                                        // Yes, set printer output on.
    ldx #4                                        //
    ldy #7                                        //
    jsr $ffba                                     //  
    jsr $ffc0                                     //
    ldx #4                                        //
    jsr $ffc9                                     //
    cmp #5                                        // Is the printer there?
    bne !printer_found+                           //
  lda #0                                          //                      
  sta PRINTIT                                     //
    sta PRINTER_ENABLED_FLAG                      // No device found, set printer output to off    
    displayText(text_printer_error,23,3)          // Display the text "Printer not found or offline"
    jmp !close+                                   //
!printer_found:                                   //
    lda #1                                        // Set enabled flag 
  sta PRINTIT                                     //
    sta PRINTER_ENABLED_FLAG                      // and store it
    displayText(text_printer_enabled,23,3)        // Display the text "Printer connected!"
  jmp !loopdeloop-                                //
!close:                                           //
    lda #4                                        //
    jsr $ffc3                                     //
    jsr $ffcc                                     //
  jmp !loopdeloop-                                //
!checkF3:                                         //  
  cmp #134                                        // F3 key pressed?
    bne !checkF7+                                 // If no match loopy loopy
    lda #0                                        // Set disabled flag
    sta PRINTER_ENABLED_FLAG                      // and store it
  sta PRINTIT                                     //
    lda #4                                        // Close output to printer
    jsr $ffc3                                     //
    jsr $ffcc                                     //
    displayText(text_printer_disabled,23,3)       // Display the text "Printer disabled"
  jmp !loopdeloop-                                // And return to the key input loop 
!checkF7:                                         //
  cmp #136                                        // F7 key pressed?
    bne !+                                        // No, keep checking for keypress   
    lda #4                                        // Close output to printer
    jsr $ffc3                                     //
    jsr $ffcc                                     //  
    jmp !mainmenu-                                // F7 Pressed, exit 
!:  jmp !loopdeloop-                              // had to implement jmp because of jump dist. error on BNE  
                                                  //
//=========================================================================================================    
//   UPDATE SCREEN   
//=========================================================================================================    
!update_screen:                                   //
    jsr !start_menu_screen-                       // 
    lda #22 ; sta _LINE_POS_                      // Load 20 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 20
    displayText(text_update_menu,1,15)            //
    displayText(text_update_line1,4,4)            //
    displayText(text_update_line2,6,4)            //
    displayText(text_update_line3,10,4)           // new version rom
    displayText(NEWROM,10,22)                     //
    displayText(text_update_line4,11,4)           // new version esp
    displayText(NEWSW,11,22)                      //
    displayText(text_update_line6,16,4)           //
                                                  //
    displayText(text_version,23,1)                // Software version info
    displayText(versionmask,23,9)                 // Software version info
    displayText(version,23,13)                    // Software version info
    displayText(version_date,23,32)               // Software version info
    displayText(SWVERSION,23,22)                  //
                                                  // ask the cartridge for new version information
!keyinput:                                        // At this point the user can select Y or N
    jsr !wait_for_a_key+                          //
    cmp #78                                       // 'n' key pressed?
    beq !exit_menu+                               // If true, exit this page
    cmp #89                                       // 'y' key pressed?
    beq !do_update+                               // if so, do the update
    cmp #136                                      // F7 key pressed?
    beq !exit_menu+                               // If true, exit to main menu
    jmp !keyinput-                                // Ignore all other keys and wait for user input again
                                                  //
!exit_menu:                                       // 
    lda #0                                        // Disable the update check
    sta UPDATECHECK                               //    
                                                  //
!:                                                //
    rts                                           //
                                                  //
!do_update:                                       //
   displayText(text_update_download,14,1)         //
   displayText(text_update_download1,15,1)        //
   displayText(text_update_download2,16,1)        //
   displayText(text_update_download3,17,1)        //
   jsr !wait_for_ready_to_receive+                //
   lda #242                                       // load the number #242    
   sta _IO1_                                      //
   ldx #0                                         // x will be our index when we loop over the version text, we start at 1 to skip the first color byte
                                                  //
!sendconfirmation:                                // 
    jsr !wait_for_ready_to_receive+               // wait for ready to receive (bit D7 goes high)
    lda doupdate,x                                // load a byte from the version text with index x
    sta _IO1_                                     // send it to IO1
    cmp #128                                      // if the last byte was 128, the buffer is finished
    beq !+                                        // exit in that case
    inx                                           // increase the x index
    jmp !sendconfirmation-                        //
!:                                                //
    lda #<(update_nmi)                            // \
    sta $0318                                     //  \ Load a new nmi vector, just for the update
    lda #>(update_nmi)                            //  / And replace the old vector to our own nmi routine
    sta $0319                                     // /
    lda #1                                        // 
    sta HOME_COLM                                 // the nmi routine will update the HOME_COLM variable
                                                  //
                                                  //
!barloop:                                         //
    ldx #19 ; jsr $e9ff                           // clear line 19
    ldx #0                                        // x is the length of the bar
    lda #160                                      // 160 is the block character that makes up the bar
!bar:                                             //
    sta $0682,x                                   // draw the bar (it starts at screen address $0682)
    inx                                           // inc x
    cpx #28                                       // if x reaches 28, we should be done 
    beq !done+                                    //
    cpx HOME_COLM                                 // as long as x equals HOME_COLM, we redraw the same bar starting at zero
    beq !barloop-                                 //
    jmp !bar-                                     // if x < HOME_COLM then increase the bar
                                                  //
!done:                                            //
   displayText(text_update_done,19,1)             //
                                                  //
!waitForReset:                                    //
   lda HOME_COLM                                  //
   cmp #28                                        //
   bne !+ 
   //   bcc !barloop-                                  //
   jmp !waitForReset-                             //   
!: jmp !do_update-                                              // 
//=========================================================================================================
//    MENU LIST USERS
//=========================================================================================================
// send byte 234 to reset the page number to 0 and get the first group of 20 users
// send byte 233 to get the next group of 20 users
// this is repeated 3 times for a total of 60 users per page, 120 users in total.
// at this point we support a max of 120 users per chat server.
//=========================================================================================================
!list_users:                                      // 
jsr !start_menu_screen-                           //              
    lda #23 ; sta _LINE_POS_                      // Load 23 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 23
    displayText(text_user_list,1,15)              // 
    lda USER_LIST_FLAG                            // 
    cmp #1                                        //  \
    beq !textF3+                                  //   \
    displayText(text_list_menu,24,0)              //      Depending if we come from the chat screen we load 
    jmp !showusers+                               //      and show the correct footer menu  
!textF3:                                          //   /  
    displayText(text_list_menu2,24,0)             //  /
!showusers:                                       //
    lda VICEMODE                                  //
    cmp #1                                        //
    beq !keyinput+                                //
    lda #0                                        //
    sta PAGE                                      // there can be 3 pages full of users, we start at 0 so we set the page number to 0
!zp:                                              // 
    lda #234                                      // load the number #234    
    sta CMD                                       // Store that in variable CMD
    jsr !send_start_byte_ff+                      // Call the sub routine to send 234 to the esp32 to ask for the the user list (234 resets the page counter, so page is 0)
    lda TIMOUTERROR                               // 
    cmp #1                                        //
    bne !fp+                                      //           
    jsr !delay+                                   //
    jmp !zp-                                      //
                                                  //
!fp:displayText(RXBUFFER,4,0)                     // 
    lda #233                                      // load the number #233
    sta CMD                                       // Store that in variable CMD
    jsr !send_start_byte_ff+                      // Call the sub routine to send 233 to the esp32 to ask for the the user list next page
    lda TIMOUTERROR                               // 
    cmp #1                                        //
    bne !+                                        //           
    jsr !delay+                                   //
    jmp !fp-                                      // 
!:  displayText(RXBUFFER,9,0)                     // 
!:  lda #233                                      // load the number #233
    sta CMD                                       // Store that in variable CMD
    jsr !send_start_byte_ff+                      // Call the sub routine to send 233 to the esp32 to ask for the the user list next page
    lda TIMOUTERROR                               // 
    cmp #1                                        //
    bne !+                                        //           
    jsr !delay+                                   //
    jmp !-                                        // 
!:  displayText(RXBUFFER,14,0)                    // 
                                                  // 
!keyinput:                                        // At this point the user can select F7 to exit the menu or pres 'n' or 'p' for next page / previous page
    jsr !wait_for_a_key+                          //
    cmp #78                                       // 'n' key pressed?
    beq !nextpage+                                // If true, go to the next page
    cmp #80                                       // 'p' key pressed?
    beq !prevpage+                                // if so, go to previous page
    cmp #82                                       // E pressed?
    bne !+                                        // No, check next 
    lda #0                                        // Yes, clear flag  
    sta USER_LIST_FLAG                            //  
    jmp !return_to_chat+                          // Return to chat window
!:  cmp #136                                      // F7 key pressed?
    bne !+                                        // No, back to key input  
    lda USER_LIST_FLAG                            // Yes, check were we came from
    cmp #1                                        // Did we come from the chat window?  
    beq !+                                        // Yes, Ignore F7 
    jmp !exit_menu+                               // No, exit to main menu
!:  jmp !keyinput-                                // Ignore all other keys and wait for user input again
                                                  // 
!nextpage:                                        // 
    lda PAGE                                      // Load the Page number
    cmp #0                                        // Compare with zero
    bne !keyinput-                                // if we are not on the first page (so we are on the second page) we can not go forward (there are only 2 pages), so branch back to keyinput
    inc PAGE                                      // set Page to 1
    jsr !clearinfofield+                          // clean the user list
!l233:                                            //
    lda #233                                      // load the number #233
    sta CMD                                       // Store that in variable CMD
    jsr !send_start_byte_ff+                      // Call the sub routine to send 233 to the esp32 to ask for the the user list next page
    lda TIMOUTERROR                               // 
    cmp #1                                        //
    bne !+                                        //           
    jsr !delay+                                   //
    jmp !l233-                                    //
!:  jmp !fp-                                      // jump back to the first page (fp) label to show the list of users on the second page.
                                                  // 
!prevpage:                                        // 
    lda PAGE                                      // Load the page number
    cmp #0                                        // compare with zero
    beq !keyinput-                                // if it is zero, there is no previous page, so jump back to keyinput
    lda #0                                        // set the page number back
    sta PAGE                                      // to zero
    jsr !clearinfofield+                          // clean the list of users
    jmp !zp-                                      // jump to the first page
                                                  // 
!exit_menu:                                       // F7 Pressed!
    lda RETURNTOMENU                              //
    cmp #1                                        // We reached the end so
    bne !return_to_chat+                          //
    jmp !mainmenu-                                // we jump back to main menu
                                                  // 
!clearinfofield:                                  // 
    ldx #4                                        // load 4 in x register
!clearlines:                                      // start a loop
    jsr $E9FF                                     // this kernal routine clears line x, where x is the line number
    inx                                           // increase x
    cpx #19                                       // compare x to 19
    bne !clearlines-                              // if x is still lower, repeat the loop
    rts                                           // return from sub routine
                                                  //
!return_to_chat:                                  // 
   jmp !exit_main_menu-                           //
//=========================================================================================================
//    ABOUT SCREEN
//=========================================================================================================
!about_screen:                                    // 
                                                  // 
    jsr !start_menu_screen-                       // 
    lda #23 ; sta _LINE_POS_                      // Load 23 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 23
                                                  // 
    displayText(text_about_menu,1,13)             //  
    displayText(text_about_line_1,4,1)            //  
    displayText(text_about_line_8,11,1)           //  
                                                  // 
    jsr !footer_F7_exit+                          // Display [ F7 ] to exit about
    ldx #0                                        // 
    lda #1                                        // 1 is color white
!loop:                                            // The version text is yellow by default, color that white
    lda #1                                        //
    sta $d935,x                                   //
    inx                                           //
    cpx #5                                        //
    bne !loop-                                    //
                                                  //
!f7_to_exit:                                      // 
    jsr $ffe4                                     // Call KERNAL routine: Get character from keyboard buffer
    cmp #136                                      // F7 key pressed?
    beq !exit_menu+                               // If true, exit to main menu.
    jmp !f7_to_exit-                              // Ignore all other keys and wait for user input again
                                                  // 
!exit_menu:                                       // F7 Pressed!
                                                  // We reached the end so
    jmp !mainmenu-                                // we jump back to main menu
                                                  // 
//=========================================================================================================
//    HELP Screen  
//=========================================================================================================
!help_screen:                                     // 
                                                  // 
    jsr !start_menu_screen-                       // 
    lda #23 ; sta _LINE_POS_                      // Load 23 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 23
                                                  // 
    displayText(text_help_pm,1,10)                // 
    displayText(text_help_private,4,1)            // 
    displayText(text_any_key,24,7)                //
                                                  //
    jsr !wait_for_a_key+                          //
    ldx #1 ; jsr $e9ff                            // clear line 1 
    jsr !clearinfofield-                          // clear line 4 through 19
    displayText(text_help_ai,1,10)                // 
    displayText(text_help_eliza,4,1)              // 
    displayText(text_any_key,24,7)                //
                                                  //
    jsr !wait_for_a_key+                          //
    ldx #1 ; jsr $e9ff                            // clear line 1
    jsr !clearinfofield-                          //
    displayText(text_help_ul,1,10)                // 
    displayText(text_help_userlist,4,1)           // 
    ldx #24 ; jsr $e9ff                           // clear line 24        
                                                  //
    jsr !footer_F7_exit+                          // Display footer [ F7 ] to exit this screen                                                   
    jmp !f7_to_exit-                              // 
    // 
!footer_F7_exit:
   // we use this same text only twice but the displayText macro is quite heavy so
   // it makes sense to create a routine for this
   displayText(text_about_footer,24,8)
rts

//=========================================================================================================
//    MENU OSC SETUP
//=========================================================================================================
// send byte 231 to get the osc destination ip and port
//=========================================================================================================
!osc_setup:                                   // 
    lda #255                                      //
    sta DELAY                                     //
    jsr !checkWiFi-                               // check if we have wifi   
    jsr !start_menu_screen-                       // 
    lda #10 ; sta _LINE_POS_                      // Load 10 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 8
    lda #20 ; sta _LINE_POS_                      // Load 20 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 20
    displayText(text_osc_menu,1,15)           // Display the menu title on line 1, row 15,
!ac_wifi_check:                                   //
    lda HAVEWIFI                                  //
    cmp #1                                        //
    beq !+                                        //
    displayText(text_any_key,21,7)                //
    displayText(text_error_no_internet,4,1)       //
    jsr !wait_for_a_key+                          //
    jmp !mainmenu-                                //
!:  lda #10 ; sta _LINE_POS_                      // Load 10 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 8
    displayText(text_osc_ip,6,1)             // Display static text "osc ip:" on line 6, row 1,  
    displayText(text_osc_port,8,1)           // Display static text "osc port:" on line 8, row 1,  
    
    lda #10 ; sta _LINE_POS_                      // Load 10 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line+                          // Call the draw_menu_line sub routine to draw a line on row 10
    jsr !display_F7_menuItem+                     // Display "[ F7 ] exit menu" on line 15, row 1.  
                                                  //
    lda VICEMODE                                  // \                                  
    cmp #1                                        //  \ Skip receiving the data from the cartridge if the cartridge is not attachted! 
    bne !+                                        //  /  
    jmp !fill_fields+                             // /   
                                                  // 
!sendcmd:                                         // 
!:  lda #231                                      // load the number #231
    sta CMD                                       // Store that in variable CMD
    jsr !send_start_byte_ff+                      // Call the sub routine to send 231 to the esp32 to ask for the osc ip and port
    lda TIMOUTERROR                               // RXBUFFER now contains Osc_IP[32]Osc_port[5]
    cmp #1                                        //
    bne !+                                        //           
    jsr !delay+                                   //
    jmp !sendcmd-                                 //
                                                  //
!:  lda #1                                        // we need the first element from the RXBUFFER (osc ip)
    sta $02                                       // store 1 (1=first element) in $02
jsr !splitRXbuffer-                              // copy the first element to Splitbuffer
    displayText(SPLITBUFFER,6,18)                 // Display the buffer (containing osc ip) on screen
                                                  // 
    lda #2                                        // now we need the second element from the RX buffer (osc port)
    sta $02                                       // so we put #2 in address $02
    jsr !splitRXbuffer-                          // and call the split routine to copy the element to the Splitbuffer
    displayText(SPLITBUFFER,8,18)                 // Display the buffer (containing osc port) on screen
                                                  // Now we need a text input box so the user can change the ip and port
!fill_fields:                                     // Set the limits to where the cursor can travel
    lda #5                                        // Load 2 into accumulator
    sta MENU_ID                                   // and store it as the ID of this menu
    lda #6                                        // Load 6 into accumulator
    sta HOME_LINE                                 // Store 6 into Home_line variable, so the cursor van not go above line 4
    lda #18                                       // Load 7 into accumulator
    sta HOME_COLM                                 // Store 7 into home_column variable, so the cursor can not go below 7
    lda #6                                        // Load 4 into accumulator
    sta LIMIT_LINE                                // Store 4 into limit_line variable so the cursor van not go below line 4
    lda #39                                       // Load 39 into accumulator
    sta LIMIT_COLM                                // Store 39 into the limit_column so the cursor can not go beyond that position
    lda #1                                        // Load 1 intop accumulator
    sta CLEAR_FIELD_FLAG                          // and SET clear text flag to 1 (default is zero)
    lda #31                                       //
    sta CURSORCOLOR                               //
    jsr !text_input+                              // Call the text input routine, we will be back when the user presses RETURN
    lda #8                                        // Load 6 into accumulator
    sta HOME_LINE                                 // Store 6 into Home_line variable, so the cursor van not go above line 22
    sta LIMIT_LINE                                // Store 6 into limit_line variable so the cursor van not go below line 24
    lda #18                                       // Load 11 into accumulator
    sta HOME_COLM                                 // Store 11 into home_column variable, so the cursor can not go below 10
    lda #23                                       // Load 5 into accumulator
    sta LIMIT_COLM                                // Store 5 into the limit_column so the cursor can not go beyond that position
    lda #1                                        // 
    sta CLEAR_FIELD_FLAG                          // 
    lda #149                                      //
    sta CURSORCOLOR                               //
    jsr !text_input+                              // Call the text input routine, we will be back when the user presses RETURN
    jsr !hide_cursor-                             // Hide the cursor
                                                  // 
    displayText(text_save_settings,13,3)          // Display "[ F1 Save settings" on line 13, row 3 
                                                  // 
!keyinput:                                        // At this point the user can select F1 or F7 to Save settings and Test settings, or exit the menu
                                                  // 
    jsr !wait_for_a_key+                          //
    cmp #133                                      // F1 key pressed?
    beq !save_settings+                           // If true, save the osc settings
    cmp #136                                      // F7 key pressed?
    beq !exit_menu+                               // If true, exit to main menu.
    jmp !keyinput-                                // Ignore all other keys and wait for user input again
                                                  // 
!exit_menu:                                       // F7 Pressed!
                                                  // We reached the end so
    jmp !mainmenu-                                // we jump back to main menu
                                                  // 
!save_settings:                                   // Read the registration code from screen into the TXBUFFER

                                                  // 
    ldx #22 ; jsr $E9FF                           // Clear line 22
    inx ; jsr $E9FF                               // Clear line 23
    displayText(text_settings_saved,23,6)         // 
                                                  // 
    lda #255                                      // Delay 255... hamsters
    sta DELAY                                     // Store 255 in the DELAY variable
    jsr !delay+                                   // and call the delay subroutine
    jsr !delay+                                   // a few times
    jsr !delay+                                   // a few times
    jsr !delay+                                   // a few times
    jsr !delay+                                   // a few times
    jmp !osc_setup-                           // Rinse and repeat
                                                  // 
                                                  // 
!loop_forever:                                    //                              
    jsr !delay+                                   //           
    jsr !delay+                                   //
    jsr !delay+                                   //
    jmp !reset_for_real-                          // Loop forever and wait for the ESP32 to reset the C64
                                                  // 




//=========================================================================================================
//    Function to wait for a key input
//=========================================================================================================
!wait_for_a_key:
!wait_for_any_key:                                //
    jsr $ffe4                                     // wait for any key                               
    beq !wait_for_any_key-                        //
    rts

//=========================================================================================================
//    Function Clear message lines
//=========================================================================================================   
!clear_message_lines:
   ldx #22 ; jsr $e9ff
   ldx #23 ; jsr $e9ff
   ldx #24 ; jsr $e9ff
   rts
//=========================================================================================================
//    Function for text input
//=========================================================================================================
!text_input:                                      // 
                                                  // 
!clearhome:                                       // 
    lda MENU_ID                                   // Load the menu ID
    cmp #1                                        // If menu ID is 1
    beq !m1+                                      // We do not want to clear the lines
    cmp #2                                        // If menu ID is 2,
    beq !m1+                                      // We do not want to clear the line
    lda SEND_ERROR                                // Load the Send_error flag
    cmp #1                                        // if it contains 1,
    beq !m1+                                      // we do not want to clear the lines
    ldx HOME_LINE                                 // Clear the text input box
                                                  // 
!clear_lines:                                     // Start of clear loop
    jsr $E9FF                                     // Clear line in register x
    cpx LIMIT_LINE                                // Are there more lines to clear?
    beq !all_clean+                               // If not, jmp to !all_clean and exit the loop
    inx                                           // Increase x register
    jmp !clear_lines-                             // Jump back to the start of the loop and clear the next line
                                                  // 
!all_clean:                                       // All lines cleared
                                                  // 
!m1:                                              // 
                                                  // 
!home:                                            //  
    lda DO_RESTORE_MESSAGE_LINES                  // 
    cmp #1                                        // 
    bne !+                                        // 
    dec DO_RESTORE_MESSAGE_LINES                  // 
    jsr !restore_message_lines+                   //     
    rts                                           // 
                                                  // 
!:  clc                                           // Clear carry so we can SET the cursor position
    ldx HOME_LINE                                 // Select row
    ldy HOME_COLM                                 // Select column
    jsr $fff0                                     // Set cursor
    jsr !show_cursor-                             // Show cursor
    lda CURSORCOLOR                               // Load cursor color 
    jsr $ffd2                                     // Output that petscii code to screen to change the cursor to white                                                  
    jsr !show_eliza+                              //
    jsr !fix_inverted_chars+                      // 
!keyinput:                                        //     
    jsr !check_for_messages+                      // 
    lda #0                                        // write zero to address $d4
    sta $d4                                       // to disable "quote mode" (special characters for cursor movement and such) 
!:  jsr $ffe4                                     // Call kernal routine: Get character from keyboard buffer
    beq !keyinput-                                // Loop if there is none
    
    cmp #141                                      // Shift+Return or C=+Return will send the message immediately
    bne !+                                        // 
    rts                                           // 
!:  cmp #221                                      // Shift Minus gives a vertical bar, we replace it with underscore
    bne !+                                        // If it is any other key, skip to the next !: marker
    lda #175                                      // Change the character into an underscore
!:  jsr !preventGraphChars+
    cmp #133                                      // F1 key pressed?
    bne !+                                        // No, try the next possible match
    jmp !exit_F1+                                 // Yes, jump to exit F1
!:  cmp #134                                      // F3 key pressed?
    bne !+                                        // No, try the next possible match
    jmp !exit_F3+                                 // Yes, jump to exit F3
!:  cmp #136                                      // F7 key pressed? (Is used to exit ANY menu)
    bne !+                                        // No, try the next possible match
    jmp !exit_F7+                                 // Yes, jump to exit F7
!:  cmp #135                                      // F5 key presses
    bne !+                                        // No, try the next possible match
    jmp !exit_F5+                                 // Yes, jmp to that exit
!:  cmp #139                                      // F6 key pressed? (is used in menu 2 - account setup)
    bne !+                                        // No, try the next possible match
    jmp !exit_F6+                                 // Yes, jump to exit F6
!:  cmp #140                                      //
    bne !+                                        //
    jmp !exit_F8+                                 //
!:  cmp #19                                       // Home key pressed?
    beq !home-                                    // Yes, jump to !home
    cmp #147                                      // Clear home key pressed?
    bne !+                                        // Yes, jump to !clearhome
    jmp !clearhome-                               // 
!:  cmp #148                                      // Insert key pressed?
    bne !+                                        // 
    jmp !keyinput-                                // Yes, jump to !keyinput
!:  cmp #20                                       // Del key pressed?
    bne !+                                        // 
    jmp !preventleft+                             // Yes, jump to !preventleft
!:  cmp #13                                       // Return key pressed?
    bne !+                                        // 
    jmp !preventdown+                             // Yes, jump to !preventdown
!:  cmp #145                                      // Cursor up pressed?
    bne !+                                        // 
    jmp !preventup+                               // Yes, jump to !preventup
!:  cmp #17                                       // Cursor down pressed?
    bne !+                                        // 
    jmp !preventdown+                             // Yes, jump to !preventdown
!:  cmp #157                                      // Cursor left pressed?
    bne !+                                        // 
    jmp !preventleft+                             // Yes, jump to !preventleft
!:  jmp !preventright+                            // Jump to !preventright
                                                  // 
!keyout:                                          // 
    jsr $ffd2                                     // Output the character to screen    
    jsr !fix_inverted_chars+
    lda SEND_ERROR                                // if we are in private messaging and the error message is displayed, remove it here!
    cmp #1                                        // so check if the SEND_ERROR var contains 1
    bne !+                                        // skip to the next label if it does not
    lda #0                                        // reset the error
    sta SEND_ERROR                                // 
    lda SCREEN_ID                                 // no need to continue if we are not in the private message screen.
    cmp #3                                        // compare the screen ID with 3
    bne !+                                        // skip to the next label if we are on any other screen.
    jsr !toggleText-                              // display the normal text on line 1
!:                                                // 
    lda $0286                                     // if the current color is black, reset it to white.
    cmp #0                                        // we do not want black text on black background
    bne !+                                        // 
    lda #5                                        // Load 5 in accumulator (petscii code for color white)
    jsr $ffd2                                     // Output that petscii code to screen to change the cursor to white
!:  jmp !keyinput-                                // jump back to key input
                                                  // 
!preventleft:                                     // 
    ldy $d3                                       // $d3 always contains the current column of the cursors position
    cpy HOME_COLM                                 // 
    beq !preventup+                               // 
    jmp !keyout-                                  // 
                                                  // 
!preventup:                                       // 
    ldx $d6                                       // $d6 alway contains the current line of the cursor position
    cpx HOME_LINE                                 // 
    beq !exit+                                    // 
    jmp !keyout-                                  // 
                                                  // 
!preventright:                                    // Prevent right is always in the loop, because normal typing can also cause you to go out of boundries!
!:  pha                                           // push the accu to the stack to keep it save
    jsr !clear_field+                             // We call !clear_field here because Prevent right is always in the loop.    
    pla                                           // restore the accumulator
    ldy $d3                                       // $d3 always contains the current column of the cursors position
    cpy LIMIT_COLM                                // 
    beq !preventdown+                             // 
    jmp !keyout-                                  // 
                                                  // 
!preventdown:                                     // 
    cmp #13                                       // Find out if we are here because the return key was pressed
    bne !notReturn+                               // 
    ldx $d6                                       // $d6 alway contains the current line of the cursor position
    cpx LIMIT_LINE                                // 
    bne !+                                        // 
    jsr !fix_inverted_chars+                      //
    rts                                           // Return to caller, this exits the keyinput routine!        
!:  clc                                           // clear carry bit so we can SET the cursor position
    inx                                           // x has the line number, so increase that                                     
    ldy #0                                        // Select column to zero (start of the line)
    jsr $fff0                                     // call the set cursor kernal routine 
    jmp !exit+                                    // and jump to exit
!notReturn:                                       // we are NOT here because user pressed return (maybe user pressed cursor down)
    ldx $d6                                       // $d6 alway contains the current line of the cursor position
    cpx LIMIT_LINE                                // se if we are on the final line
    beq !exit+                                    // if so, ignore this key press, jump to exit
    jmp !keyout-                                  // if not, no problem, output the key
                                                  // 
!exit:                                            //             
    lda #0                                        // load zero in accumulator (delete the keystroke that was in there)
    jmp !keyout-                                  // and jump to keyout
                                                  // 
!exit_F3:                                         // open the 'who is online page'
    lda #0                                        //
    sta RETURNTOMENU                              //
    lda SCREEN_ID                                 // Load the menu ID in accu
    cmp #0                                        // Compare it to zero (zero is the main chat screen)
    beq !m+                                       // 
    cmp #3                                        // 
    beq !p+                                       // 
    jmp !exit-                                    // If not equal, jump back up into the key input routine
!p: jsr !backup_pm_screen+                        // Make a backup of the chat before we clear the screen and jump to the main menu
    lda #0                                        // Set flag that we are coming from the main menu
    sta USER_LIST_FLAG                            // and store it
    jmp !list_users-                              // 
!m: jsr !backup_screen+                           // Make a backup of the chat before we clear the screen and jump to the main menu
    lda #1                                        // Set flag that we got here from the chat screen
    sta USER_LIST_FLAG                            // and store it
    jmp !list_users-                              //
                                                  //
!exit_F1:                                         // This exit to the main menu should only work in the main chat screen.
    lda SCREEN_ID                                 // Load the menu ID in accu
    cmp #0                                        // Compare it to zero (zero is the main chat screen)
    beq !b+                                       // 
    cmp #3                                        // 
    beq !b+                                       // 
    jmp !exit-                                    // If not equal, jump back up into the key input routine
!b: jsr !screen_backup+                           // Make a backup of the chat before we clear the screen and jump to the main menu
    jmp !mainmenu-                                // 
                                                  //
!exit_F5:                                         // 
    lda SCREEN_ID                                 // what screen are we on now?
    cmp #0                                        // if we are in the main chat, go to the private chat
    bne !+                                        // 
    jsr !backup_message_lines+                    // 
    jsr !backup_screen+                           // 
    jmp !private_chat_screen-                     // 
!:  cmp #3                                        // if we are in the private chat, go to the main chat
    bne !exit-                                    // just go to exit if we are on any other screen.
    jsr !backup_message_lines+                    // 
    jsr !backup_pm_screen+                        // make a backup of the private chat screen
    jsr !restore_screen+                          // restore the main chat screen
    jmp !main_chat_screen-                        // and return to the main chat
                                                  // 
!exit_F7:                                         // This exits TO the main menu or exits to the main chat screen from the private chat screen
    lda MENU_ID                                   //
    cmp #0                                        //
    bne !+                                        //  
    lda SCREEN_ID                                 // Load the menu ID in accu
    cmp #0                                        // Compare it to zero (zero is the main chat screen), F7 does nothing in that screen
    beq !ex+                                      // If not equal, jump back up into the key input routine
    cmp #3                                        // 3 is the private chat screen
    bne !+ 
!ex:jmp !exit-                                    // F7 does nothing in that screen
!:  jmp !mainmenu-                                // return to the main menu
                                                  // 
!exit_F6:                                         // 
    lda MENU_ID                                   // 
    cmp #2                                        // 
    bne !+                                        // 
    jmp !reset_factory-                           // 
!:  jmp !ex-                                      //                                               

!exit_F8:                                         //
    rts // NOT USED
    lda MENU_ID
    cmp #0
    beq !+
    jmp !exit-                                    //
!:  jsr !admin_screen_history+      
    jmp !exit-
    
!preventGraphChars:                               //
    cmp #175                                      // allow underscore, move to the exit
    beq !exit+                                    //
    cmp #94                                       // ignore arrow up
    beq !ignore+                                  //
    cmp #95                                       // ignore arrow to left
    beq !ignore+                                  //
    cmp #219                                      // ignore everything above 219
    bcs !ignore+                                  //
    cmp #160                                      // ignore every thing between 160 and 192 
    bcc !exit+                                    //
    cmp #192                                      //
    bcc !ignore+                                  //
!exit:                                            //
    rts                                           //
!ignore:                                          //
    lda #0                                        //
    rts                                           //
//=========================================================================================================
!show_eliza:                                      //
  lda SCREEN_ID                                   //
  cmp #3                                          //
  bne !exit+                                      //
  ldx #0                                          //
  stx $d3                                         //
!read_pm_user:                                    // 
  lda text_pmuser,x                               //  
  cmp #128                                        //
  beq !exit+                                      //
  sta $0770,x                                     //
  lda #1                                          //
  sta $db70,x                                     // color the text white
  inx                                             //
  inc $d3                                         // move the cursor
  jmp !read_pm_user-                              //
   

!exit:
  rts
//=========================================================================================================
// SUB ROUTINE, DEBUG SCREEN
//=========================================================================================================
!debugscreen:
    jsr $E544                                     // Clear screen after start screen
    lda #23                                       // Load 23 into accumulator and use it to
    sta $D018                                     // Switch to LOWER CASE
    lda #9                                        //
    sta MENU_ID                                   //
    jsr !start_menu_screen-
    jsr !display_F7_menuItem+
    
    ldx #0
!loop1:    
    
    lda $E475,x
    sta $428,x
    lda #1
    sta $D828,x
    inx
    cpx #35
    bne !loop1-
    
!keyinput:   
    jsr $ffe4                                     // Call KERNAL routine: Get character from keyboard buffer                  
    cmp #136 // F7 pressed
    beq !exit+
    jmp !keyinput-    
!exit:                                            // F7 Pressed, prepare to exit to chat screen
    jmp main_init
  
  
//=========================================================================================================
// SUB ROUTINE, CHECK FOR UPDATES
//=========================================================================================================
!check_updates:
    
    lda UPDATECHECK
    cmp #0                                        // 0 means do not check again (until next reset) 
    beq !exit+
    cmp #2                                        // 2 means we allready check and YES there is an update
    beq !exit+
    
    lda VICEMODE                                  // if we are running in simulation mode
    cmp #1                                        // jump to exit without interacting with ESP32
    bne !+    
    lda #2
    sta UPDATECHECK
    rts
    
!:    
    lda #239                                      // check for systemupdate
    sta CMD
    jsr !send_start_byte_ff+
    ldx #0                                        // 
    lda RXBUFFER,x                                // 
    cmp #128  
    beq !exit+ 
    lda #146
    ldy #0
    lda #146
    sta NEWROM,y
    sta NEWSW,y
    iny
!loop1:         
    lda RXBUFFER,x                                // copy the versions from the buffer to variables
    sta NEWROM,y         
    cmp #32              
    beq !+
    inx
    iny
    jmp !loop1-
!:  ldy #1
    inx
!loop2:
    lda RXBUFFER,x
    cmp #128
    beq !+
    sta NEWSW,y
    inx
    iny
    jmp !loop2-
    
!:  lda #2
    sta UPDATECHECK
    playsong(song3)
    ldx #0                   // copy sysmessage_update to RX buffer
!loop1:
    lda sysmessage_update,x
    sta RXBUFFER,x
    inx
    cmp #128
    bne !loop1-
    lda $0286                                     // Load the current color into the accumulator
    sta TEMPCOLOR                                 // Store it in a variable.
    jsr !sysmsg+

!exit:           
    rts    
//=========================================================================================================
// SUB ROUTINE, CHECK FOR NEW MESSAGES
//=========================================================================================================
!check_for_messages:                              // 
    lda MENU_ID
    cmp #1
    bcs !ex+
    lda $0286                                     // Load the current color into the accumulator
    sta TEMPCOLOR                                 // Store it in a variable.
                                                  // 
    lda SCREEN_ID                                 // check if we are in a chat screen
    cmp #0                                        // screen 0 is the main chat screen
    beq !throttle_down+                           // that's fine, continue
    cmp #3                                        // screen 3 is the private chat screen
    beq !throttle_down+                           // that's also fine, please go on
!ex:rts                                           // Not 0 or 3, just return
                                                  // 
                                                  // 
!throttle_down:                                   // this subroutine is triggered many times per second, way too often
    inc TIMER                                     // so we increase a timer variable (not realy a timer, more a counter)
    lda TIMER                                     // load the value of timer into the accu
    cmp #0                                        // see if it loops over to zero
    bne !e+                                       // if not exit the subroutine
    inc TIMER2                                    // if it has looped over to zero, increase timer 2
    lda TIMER2                                    // load the value of timer 2 into the accu
    cmp CHECKINTERVAL                             // and compare it to CHECKINTERVAL
    beq !do_check+                                // so if TIMER has looped over to zero 50 times, we check for messages.
!e: jmp !exit+                                    // 
                                                  // 
!do_check:                                        // 
    lda #0                                        // reset timer2
    sta TIMER2                                    // 
    lda VICEMODE                                  // if we are running in simulation mode
    cmp #1                                        // jump to exit without interacting with ESP32
    bne !+                                        // 
    jmp !exit+                                    // 
                                                  //     
!:  jsr !count_private_messages+                  // 
                                                  // Now we will check for new messages.
                                                  // send byte 254 to esp32
                                                  // it will respond with a message or byte 128 if there are no messages
    lda SCREEN_ID                                 // 
    cmp #0                                        // are we in public or private chat?
    beq !m+                                       // yes, check for public message
    lda #247                                      // load #247 (command byte to ask for private message)
    jmp !s+                                       // OR
!m: lda #254                                      // Load number #254  (ask for public messages)
!s: sta CMD                                       // Store that in variable CMD
    jsr !send_start_byte_ff+                      // Call the sub routine to send 254 to the esp32
    ldx #0                                        // 
    lda RXBUFFER,x                                // 
    cmp #128                                      // 
    bne !dispmessage+                             // 
    lda WAITFORMESSAGE                            //
    cmp #1                                        //
    beq !+                                        //
    lda #80                                       // 
    sta CHECKINTERVAL                             // 
!:  jsr !check_updates-                           //
    jsr !admin_screen+                            //
    jmp !exit+                                    // 
                                                  // 
!dispmessage:                                     // 
    lda #1                                        //      
    sta PRINTIT                                   // we have a message to display
    jsr !messagenoise+                            // make some noise now, there's a message!
    lda CHECKREPEAT                               // reset the check interval
    sta CHECKINTERVAL                             // 
    dec WAITFORMESSAGE
!sysmsg:                                          //
    lda RXBUFFER                                  // the first number in the rx buffer is the number of lines
    cmp #5                                        // this number should be 1 or 2 or 3. But not 4 or higher.
    bcs !error+                                   // jump to error (to display an error) if the number >= 5
    lda RXBUFFER                                  // load the number of lines in the y register
    cmp #0                                        // if this number is 0, that also is no good, should be 1,2,3 or 4                                         
    beq !shifterror+                              //
    ldy RXBUFFER                                  //
                                                  // Shift the screen up,
!up:                                              // repeat the shift_up routine as many times as needed
    jsr !Shift_Screen_up+                         // the RXBUFFER starts with the number of lines
    dey                                           // 
    cpy #0                                        // 
    bne !up-                                      // 
                                                  // 
    ldx RXBUFFER                                  // 
    lda message_start,x                           // load the start line from the message_start array, using x as the index
                                                  // 
    sta $f7                                       // 
    lda #0                                        // 
    sta $f8                                       // 
    lda #1                                        // 
    sta OFFSET                                    // used to offset the index when reading the buffer in displaytextK
                                                  // 
!load_buffer:                                     // 
                                                  // 
    lda #<(RXBUFFER)                              // 
    sta _BUFFER_POINTER_                          // 
    lda #>(RXBUFFER)                              // 
    sta _BUFFER_POINTER_ +1                       // 
    jsr !preparePrintBuffer+                      //
    jsr !displaytextK+                            // 
    lda PRINTER_ENABLED_FLAG                      // Do we have a printer enabled?
    cmp #1                                        //
    bne !+                                        //
    jsr !printTextK+                              //
!:  lda #0                                        // 
    sta OFFSET                                    // reset the offset buffer.
                                                  // 
!exit:                                            // 
                                                  // 
    lda TEMPCOLOR                                 // restore the current color
    sta $0286                                     // 
    rts                                           // 
!error:                                           // 
    jsr !sounderror-                              // 
    jsr !Shift_Screen_up+                         // 
    displayText(text_rxerror,20,0)                // 
    jmp !exit-                                    // 
!shifterror:                                      // 
    jmp !exit-                                    // 

!messagenoise:                                    //
   lda SCREEN_ID  
   cmp #0
   bne !+
   playsong(song0)
   rts
!: playsong(song5)   
   rts   
//=========================================================================================================
// SUB ROUTINE, ASK FOR THE NUMBER OF UNREAD PRIVATE MESSAGES
//=========================================================================================================
!count_private_messages:                          // 
    lda SCREEN_ID                                 // we only want to show this information on the main chat screen
    cmp #0                                        // main chat screen ID = 0
    bne !exit+                                    // if not 0, exit
                                                  //     
    lda #241                                      // Load 241 in accumulator (command byte for asking the number of unread private messages)
    sta CMD                                       // Store that in variable CMD
    jsr !send_start_byte_ff+                      // Call the sub routine to obtain connection status from esp32
                                                  // 
    lda #21                                       // display this on line 21
    sta $f7                                       // $f7 is used in displaytextK as the line number
    lda #26                                       // display this test at row (or column) 26
    sta $f8                                       // $f8 is used as the row number in displaytextK
    lda #12                                       // load the default color
    sta $0286                                     // store in address 0286 which holds the current color
    jsr !load_buffer-                             // 
                                                  // 
!exit:                                            // 
    
    rts                                           // return to sender, just like Elvis.
                                                  // 
//=========================================================================================================
// SUB ROUTINE, Get Result from sending the message
//=========================================================================================================
!getResult:                                       //
    lda #249                                      // Load number #249 (ask send result)
    sta CMD                                       // Store that in CMD variable
    jsr !send_start_byte_ff+                      // Call the sub routine to send 249 to the esp32    
    lda RXBUFFER                                  // 
    sta SEND_ERROR                                //
    rts                                           //
                                                  //
//=========================================================================================================
// SUB ROUTINE, Shift the message screen up. (so not the whole screen, just the messages)
//=========================================================================================================
!Shift_Screen_up:                                 //
    tya                                           // transfer y to a
    pha                                           // push it to the stack
                                                  // 
    ldx SCREEN_ID                                 // if screen_id==0 (public chat), we start scrolling at line 0
                                                  // if screen_id==3 (private chat), we start scrolling at line 3
!screenloop:                                      // 
                                                  // set destination pointers
    lda screen_lines_low,x                        // 
    sta $f9                                       // 
    sta $fd                                       // 
    lda screen_lines_high,x                       // 
    sta $fa                                       // 
    lda color_lines_high,x                        // 
    sta $fe                                       // 
                                                  // set source pointers
    inx                                           // increase x (the source is always 1 line below the destination)
    lda screen_lines_low,x                        // 
    sta $f7                                       // 
    sta _LINE_POS_                                // 
    lda screen_lines_high,x                       // 
    sta $f8                                       // 
    lda color_lines_high,x                        // 
    sta _LINE_POS_ +1                             // 
                                                  // 
    ldy #0                                        // y is the character counter (40 characters per line)
!readwrite:                                       // start the copy
    lda ($f7),y                                   // read character information
    sta ($f9),y                                   // write character information
    lda (_LINE_POS_),y                            // read color information
    sta ($fd),y                                   // write color information
    lda #32                                       // load the space character
    sta ($f7),y                                   // overwrite the source character
    iny                                           // increase y
    cpy #40                                       // are we at the end of the line?
    bne !readwrite-                               // if not continue the loop
    cpx #20                                       // have we reached line 20?
    beq !exit+                                    // if so, exit
    jmp !screenloop-                              // if not, continue with the next line
                                                  // 
!exit:                                            // 
    lda #0                                        //
    sta $d020                                     //
    pla                                           // pull the y register from the stack
    tay                                           // move it to the y register
    rts                                           // 
                                                  // 
//=========================================================================================================
// SUB ROUTINE, CHECK CONFIGURATION STATUS
//=========================================================================================================
!callstatus:                                      // 
    lda VICEMODE                                  // if we are running in simulation mode
    cmp #1                                        // jump to exit without interacting with ESP32
    bne !+                                        // branche if not equal (not in vice mode) to the next label
    lda #4                                        // if we are in vice mode, we load 4 into the rxbuffer (4 means fully configured, 5 means empty configuration)
    sta CONFIG_STATUS                             // so the program thinks we have a complete configuration
    ldx 0                                         //
                                                  //
    jmp !exit+                                    // exit this routine, we are in vice mode at this point
                                                  // 
!:  lda #236                                      // Load 236 in accumulator (get current connection status and servername)
    sta CMD                                       // Store that in CMD
    jsr !send_start_byte_ff+                      // Call the sub routine to obtain connection status from esp32
                                                  // the RXBUFFER now contains config_status[32]servername[128]
                                                  //
                                                  //
    lda #1                                        // set the variables up for the splitbuffer command
    sta $02                                       // we need the first element, so store #1 in $02
    jsr !splitRXbuffer-                           // and call spilt buffer
    lda SPLITBUFFER                               // SPLITBUFFER NOW CONTAINS THE CONFIG_STATUS
    sta CONFIG_STATUS                             // this is only one character, store it in config_status   
                                                  //
    lda #2                                        // we need the second element out of the rxbuffer   
    sta $02                                       // so put #2 in address $02 and jump to split buffer   
    jsr !splitRXbuffer-                           // SPLITBUFFER NOW CONTAINS THE SERVERNAME
                                                  // The servername is multiple characters so we need a loop to copy it to                                                  
    ldx #0                                        // the server name variable   
!read:                                            // start of the loop
    lda SPLITBUFFER,x                             // load a character from the splitbuffer   
    sta SERVERNAME,x                              // store it in the servername variable   
    cmp #32                                       // see if the character was a space character   
    beq !+                                        // if so, jump out of the loop   
    cmp #128                                      // see if the character was byte 128      
    beq !+                                        // if so, jump out of the loop      
    inx                                           // increase x for the next character   
    jmp !read-                                    // and repeat   
!:  lda #128                                      // finish the servername variable with byte 128   
    sta SERVERNAME,x                              //    
    lda #3                                        // now get the third element from the rx buffer    
    sta $02                                       // so put #3 in address $02 and jump to split buffer    
    jsr !splitRXbuffer-                           // SPLITBUFFER NOW CONTAINS THE SWVERSION
                                                  // The swversion is multiple characters so we need a loop
    ldx #0                                        // to copy the text to the SWVERSION variable   
!read:                                            // start of the loop
    lda SPLITBUFFER,x                             // load a character from the splitbuffer    
    sta SWVERSION,x                               // store it in the SWVERSION variable    
    cmp #32                                       // see if the character was a space character    
    beq !+                                        // if so, jump out of the loop   
    cmp #128                                      // see if the character was byte 128   
    beq !+                                        // if so, jump out of the loop   
    inx                                           // increase x for the next character    
    jmp !read-                                    // and repeat   
!:  lda #128                                      //    
    sta SWVERSION,x                               // finish the SWVERSION variable with byte 128 
!exit:                                            // 
    rts                                           // and return to caller
                                                  // 
//=========================================================================================================
// SUB ROUTINE, SEND CONFIGURATION STATUS
//=========================================================================================================
!sendstatus:                                      //
    ldy VICEMODE                                  // if we are running in simulation mode
    cpy #1                                        // jump to exit without interacting with ESP32
    bne !+                                        // 
    jmp !exit+                                    // 
                                                  // 
!:  ldy #0                                        // Y is our register, used for the index
    sta TXBUFFER,y                                // Put status character in the buffer at index y
    sta CONFIG_STATUS                             //
    iny                                           // Increase index
    lda #128                                      // Load 128 in accumulator
    sta TXBUFFER,y                                // Store 128 in the buffer to finish the buffer
    jsr !wait_for_ready_to_receive+               // Prepare the ESP to receive
    lda #235                                      // Load 235 into accumulator
    sta _IO1_                                     // Send the start byte (235 = configuration status)
    jsr !send_buffer+                             // 
!exit:                                            // 
    rts                                           // Return to caller
                                                  //
//=========================================================================================================
// SUB ROUTINE, CLEAR FIELD
//=========================================================================================================
!clear_field:                                     // 
                                                  // 
    lda CLEAR_FIELD_FLAG                          // Load the Clear flag
    cmp #1                                        // Compare it to #1
    beq !do_clear_field+                          // If it is #1, clear the rest of the fied
    rts                                           // If not return to caller
!do_clear_field:                                  // 
    dec CLEAR_FIELD_FLAG                          // First set clear flag back to zero
                                                  // 
                                                  // How to clear the field?
                                                  // We know that the cursor is on coordinated HOME_LINE, HOME_COLM
                                                  // So we print space characters until we reach LIMIT_COLM
                                                  // Then set the cursor back at the coordinates HOME_LINE,HOMECOLM
                                                  // 
    ldy HOME_COLM                                 // 
!loop:                                            // Now we loop y until LIMIT_COL is reached
    lda #32                                       // Load screen code for SPACE character
    jsr $ffd2                                     // Output the character to screen
    iny                                           // Increase y
    cpy LIMIT_COLM                                // Compare Y with limit_colm
    bne !loop-                                    // Continue the loop if not equal
    clc                                           // Clear the carry flag so we can SET the cursor back
    ldx HOME_LINE                                 // KERNAL routine $fff0 uses x,y for line,column. So HOME_LINE goes into x
    ldy HOME_COLM                                 // Load the home_colm into y register
    jsr $fff0                                     // Set cursor back to home_colm , x=line, y=column
    rts                                           // Return to caller
                                                  // 
//=========================================================================================================
// SUB ROUTINE, READ TEXT FIELD FROM SCREEN
//=========================================================================================================
!read_from_screen:                                // 
                                                  // 
    ldy #0                                        // y will be used as index for the text
!read_character:                                  // 
                                                  // we have a pointer in zero page address $fb that points to the screen position
    lda (_FIELD_),y                               // Read a character from screen, start at address ($fb), y is the offset
    sta TXBUFFER,y                                // Put the character in the buffer at index y
    iny                                           // Increment y
    cpy READLIMIT                                 // If y has reached the readlimit, the text field is finished
    bne !read_character-                          // If not jump back to read another character
                                                  // Close the buffer
    dey                                           // Decrement y
    lda #128                                      // Load 128 in accumulator
    sta TXBUFFER,y                                // Store 128 in the buffer to finish the buffer
    rts                                           // Return to sender, just like elvis.
                                                  // 
//=========================================================================================================
// SUB ROUTINE, to backup the 3 message lines
//=========================================================================================================
!backup_message_lines:                            // 
    lda #1                                        // load 1 into the accumulator
    sta HAVE_ML_BACKUP                            // store that value into the have_ml_backup variable
                                                  // 
    ldx #0                                        // load 0 into the x register, this is our loop index
!loop:                                            // start a loop
    lda $0770,x                                   // load a character from screen memory (770 is where the message box starts, where you type the message)
    sta M_CHARBLOCK770,x                          // store that character in the memory block reserved for the backup
    lda $db70,x                                   // load the color of that character from color memory
    sta M_COLBLOCK770,x                           // store that color value in the memory block reserved for the color backup
    inx                                           // increase the index x
    cpx #120                                      // compare the index with 120
    bne !loop-                                    // branche backup to the start if the loop if we have not reached 120
    rts                                           // exit the routine, return to caller
                                                  // 
//=========================================================================================================
// SUB ROUTINE, to restore the 3 message lines from backup
//=========================================================================================================
!restore_message_lines:                           // 
    lda HAVE_ML_BACKUP                            // see if there is a backup to restore
    cmp #1                                        // compare that variable to 1
    bne !exit+                                    // branche if not equal to exit
    ldx #0                                        // load 0 into the x register, this is our loop index
!loop:                                            // start a loop
    lda M_CHARBLOCK770,x                          // load a character from the backup memory block M_CHARBLOCK770 with index x
    sta $0770,x                                   // write that character at location $770 (in screen memory) with index x
    lda M_COLBLOCK770,x                           // load the color information from backup with index x
    sta $db70,x                                   // write it back to the creen color memory with index x
    inx                                           // increase the indexx
    cpx #120                                      // compare the index with 120
    bne !loop-                                    // branche backup to the start if the loop if we have not reached 120
!exit:                                            // 
    rts                                           // exit the routine, return to caller
                                                  // 
//=========================================================================================================
// SUB ROUTINE, to backup the private chat screen
//=========================================================================================================
!backup_pm_screen:                                // 
    lda #1                                        // 
    sta HAVE_P_BACKUP                             // set the have_backup marker to one
    ldx #0                                        // 
!loop:                                            // And also the color information in the same loop
                                                  // 
    lda $0400,x                                   // 
    sta P_CHARBLOCK400,x                          // Chars
    lda $D800,x                                   // 
    sta P_COLBLOCK400,x                           // Color
    lda $0500,x                                   // 
    sta P_CHARBLOCK500,x                          // Chars
    lda $D900,x                                   // 
    sta P_COLBLOCK500,x                           // Color
    lda $0600,x                                   // 
    sta P_CHARBLOCK600,x                          // Chars
    lda $DA00,x                                   // 
    sta P_COLBLOCK600,x                           // Color
    dex                                           // 
    bne !loop-                                    // 
    ldx #$00                                      // 
                                                  // 
!loop:                                            // This loop is to store the last few lines
                                                  // 
    lda $0700,x                                   // until, and including the divider line
    sta P_CHARBLOCK700,x                          // 
    lda $DB00,x                                   // 
    sta P_COLBLOCK700,x                           // 
    inx                                           // 
    cpx #$70                                      // 
    bne !loop-                                    // 
    rts                                           // Return to caller
                                                  // 
//=========================================================================================================
// SUB ROUTINE, to backup the main chat screen
//=========================================================================================================                                              
!backup_screen:                                   // 
    lda #1                                        // set the have_backup marker to one
    sta HAVE_M_BACKUP                             // 
    ldx #0                                        // Create a loop to store all character information
                                                  // 
!loop:                                            // And also the color information in the same loop
                                                  // 
    lda $0400,x                                   // 
    sta M_CHARBLOCK400,x                          // Chars
    lda $D800,x                                   // 
    sta M_COLBLOCK400,x                           // Color
    lda $0500,x                                   // 
    sta M_CHARBLOCK500,x                          // Chars
    lda $D900,x                                   // 
    sta M_COLBLOCK500,x                           // Color
    lda $0600,x                                   // 
    sta M_CHARBLOCK600,x                          // Chars
    lda $DA00,x                                   // 
    sta M_COLBLOCK600,x                           // Color
    dex                                           // 
    bne !loop-                                    // 
    ldx #$00                                      // 
                                                  // 
!loop:                                            // This loop is to store the last few lines
                                                  // 
    lda $0700,x                                   // until, and including the divider line
    sta M_CHARBLOCK700,x                          // 
    lda $DB00,x                                   // 
    sta M_COLBLOCK700,x                           // 
    inx                                           // 
    cpx #$70                                      // 
    bne !loop-                                    // 
    rts                                           // Return to caller
                                                  //                                                  
//=========================================================================================================
// SUB ROUTINE, to restore the private chat screen
//=========================================================================================================
!clear_input_field:                               //
    ldx #$16                                      // Clear the lines where you type messages
    jsr $E9FF                                     // Clear line 16(hex)
    ldx #$17                                      // Clear the line
    jsr $E9FF                                     // Clear line 17(hex)
    ldx #$18                                      // Clear the line
    jsr $E9FF                                     // Clear line 18(hex)
rts                                               //
                                                  //
!restore_pm_screen:                               // 
    lda HAVE_P_BACKUP                             // see if there is a backup to restore.
    cmp #1                                        // if HAVE_M_BACKUP==1, continue to the next label
    beq !+                                        // branche if equal
    rts                                           // return from subroutine if there is no backup.
!:  jsr !clear_input_field-                       // 
    ldx #$00                                      // 
!loop:                                            // Create a loop to restore all
                                                  // 
    lda P_CHARBLOCK400,x                          // Character and color information
    sta $0400,x                                   // 
    lda P_COLBLOCK400,x                           // 
    sta $D800,x                                   // 
    lda P_CHARBLOCK500,x                          // 
    sta $0500,x                                   // 
    lda P_COLBLOCK500,x                           // 
    sta $D900,x                                   // 
    lda P_CHARBLOCK600,x                          // 
    sta $0600,x                                   // 
    lda P_COLBLOCK600,x                           // 
    sta $DA00,x                                   // 
    dex                                           // 
    bne !loop-                                    // 
    ldx #$00                                      // 
                                                  // 
!loop:                                            // This next loop is to restore the last few lines
                                                  // 
    lda P_CHARBLOCK700,x                          // until and including the divider line
    sta $0700,x                                   // 
    lda P_COLBLOCK700,x                           // 
    sta $DB00,x                                   // 
    inx                                           // 
    cpx #$70                                      // 
    bne !loop-                                    // 
    rts                                           // 
                                                  // 
//=========================================================================================================
// SUB ROUTINE, to restore the main chat screen
//=========================================================================================================
!restore_screen:                                  // 
    lda HAVE_M_BACKUP                             // see if there is a backup to restore.
    cmp #1                                        // if HAVE_M_BACKUP==1, continue to the next label
    beq !+                                        // branche if equal
    rts                                           // return from subroutine if there is no backup.
                                                  // 
!:  jsr !clear_input_field-                       // 
    ldx #$00                                      // 
!loop:                                            // Create a loop to restore all
                                                  // 
    lda M_CHARBLOCK400,x                          // Character and color information
    sta $0400,x                                   // 
    lda M_COLBLOCK400,x                           // 
    sta $D800,x                                   // 
    lda M_CHARBLOCK500,x                          // 
    sta $0500,x                                   // 
    lda M_COLBLOCK500,x                           // 
    sta $D900,x                                   // 
    lda M_CHARBLOCK600,x                          // 
    sta $0600,x                                   // 
    lda M_COLBLOCK600,x                           // 
    sta $DA00,x                                   // 
    dex                                           // 
    bne !loop-                                    // 
    ldx #$00                                      // 
                                                  // 
!loop:                                            // This next loop is to restore the last few lines
                                                  // 
    lda M_CHARBLOCK700,x                          // until and including the divider line
    sta $0700,x                                   // 
    lda M_COLBLOCK700,x                           // 
    sta $DB00,x                                   // 
    inx                                           // 
    cpx #$70                                      // 
    bne !loop-                                    // 
    rts                                           // 
                                                  // 
//=========================================================================================================
// SUB ROUTINE, START SCREEN
//=========================================================================================================
!start_screen:                                    // 
                                                  // 
    lda #21                                       // switch to UPPER CASE/PETSCII MODE
    sta $D018                                     // 
    ldx #0                                        // black screen and border
    stx $d021                                     // 
    stx $d020                                     // 
    ldx #0                                        // 
!line:                                            // in this loop we draw line characters on the screen, starting in two places on the screen
                                                  // 
    lda #$e2                                      // load the character code into accumulator
    sta $400,x                                    // store it in the screen memory address $400 with offset x
    sta $6d0,x                                    // also store it in the screen memory address $6d0 with offset x
    lda #$0b                                      // load the gray color code into accumulator
    sta $d800,x                                   // store it in the color memory address $d800 with offset x
    sta $dad0,x                                   // also store it in the color memory address $dado with offset x
    inx                                           // count up x
    bne !line-                                    // if x loops over to zero, we are done
    ldx #39                                       // 
                                                  // 
!lastline:                                        // the last loop was only 255 long, we need to fill in 39 more places with the line character
                                                  // 
    lda #$e2                                      // load the horizontal bar character in the accumulator
    sta $7C0,x                                    // place it in the screen memory
    sta $4F0,x                                    // place it in the screen memory again
    lda #$0b                                      // load the gray color code into accumulator
    sta $d8f0,x                                   // store it in the color memory address $d8f0 with offset x
    sta $dbc0,x                                   // store it in the color memory address $dbc0 with offset x
    dex                                           // count down x
    bne !lastline-                                // if x is zero, we are done
    displayText(big_letters,8,8)                  //
                                                  // Next, color the stars
    lda #1                                        // load color 1 (white) in accumulator
    sta $d887                                     // Store in color RAM to color the part of a star white
    sta $db6b                                     // Store in color RAM to color the part of a star white
    lda #7                                        // load color code 7 (yellow) in accumulator
    sta COLOR                                     // store this in COLOR (the !color_stars sub routine will use this as the color)
    lda #<(stars1)                                // store the low byte of the stars array in zero page
    sta $fe                                       // memory location $fe, the !color_stars sub routine will use this to find the stars1 array
    lda #>(stars1)                                // store the high byte of the stars array in zero page
    sta $ff                                       // memory location $ff
    jsr !color_stars+                             // jump to the color_stars sub routine to do the work.    
    inc COLOR                                     // increase COLOR, it contains 8 now (a darker yellow)
    lda #<(stars2)                                // store the low byte of the stars2 array in zero page
    sta $fe                                       // memory location $fe, the !color_stars sub routine will use this to find the stars2 array
    lda #>(stars2)                                // store the high byte of the stars2 array in zero page
    sta $ff                                       // memory location $ff
    jsr !color_stars+                             // jump to the color_stars sub routine to do the work
    jsr !callstatus-                              // Check the configuration status                                              // 
//=========================================================================================================
//  SUB ROUTINE TO ANIMATE THE STARS
//=========================================================================================================
    playsong(song1)
!animate_stars:                                   // 
    ldx #1                                        // 
    lda #$d8                                      // this is the high byte of the color address of all the top stars
    sta $fc                                       // store that in zero page address $fc
!loop:                                            // 
    lda screen_lines_low,x                        // load the low byte of the color address
    sta _LINE_POS_                                // and store it in $fb
    jsr !shift_color_line_to_left+                // call the shift_left sub routine
    inx                                           // increase x to do the next line
    cpx #6                                        // check if x reaches 6
    bne !loop-                                    // if not continue..
!:  ldx #18                                       // 
!loop:                                            // 
    lda screen_lines_low,x                        // 
    sta $f7                                       // 
    lda color_lines_high,x                        // 
    sta $f8                                       // 
    jsr !shift_color_line_to_right+               // 
    inx                                           // 
    cpx #24                                       // 
    bne !loop-                                    // 
                                                  // 
!endloop:                                         // 
    lda #20                                       // 
    sta DELAY                                     // 
    jsr !delay+                                   // 
    jsr $ffe4                                     // get character from keyboard buffer
    beq !animate_stars-                           // loop if there is none
//    cmp #137
//    bne !+ 
//    jmp !debugscreen-
!:  lda #5                                        // 
    sta CURSORCOLOR                               // set current color to 1 (white)
    rts                                           // Return to caller
                                                  // 
//=========================================================================================================
//  SUB ROUTINE TO SHIFT THE COLORS IN THE STAR LINES TO LEFT
//=========================================================================================================
!shift_color_line_to_left:                        // a pointer to the color memory address where the line we want to shift starts
                                                  // is stored in zero page address $fb, $fc
    ldy #0                                        // before we start the loop we need to store the color of the very first character
    lda (_LINE_POS_),y                            // so load the color on the first position of the line
    pha                                           // push it to the stack, for later use
    iny                                           // y is our index for the loop, it starts at 1 this time.
                                                  // 
!loop:                                            // start the loop
                                                  // the loop works like this:
    lda (_LINE_POS_),y                            // 1) load the color of character at postion y in the accumulator
    dey                                           // 2) decrease y
    sta (_LINE_POS_),y                            // 3) store the color on position y. So now the color of character has shifted left
    cpy #39                                       // 4) see if we are at the end of the line
    beq !exit+                                    // and exit if we are
    iny                                           // 5) if not, increase y
    iny                                           // twice (because we decreased it in step 2
    jmp !loop-                                    // 6) back to step 1
                                                  // 
!exit:                                            // here we exit the loop
                                                  // 
    pla                                           // 7) we need to store the color of the very first character (the most left)
    sta (_LINE_POS_),y                            // on the most right position, so the line goes round and round
    rts                                           // now the colors in this line have shifted 1 position to the left
                                                  // 
//=========================================================================================================
//  SUB ROUTINE TO SHIFT THE COLORS IN THE STAR LINES TO RIGHT
//=========================================================================================================
!shift_color_line_to_right:                       // a pointer to the color memory address where the line we want to shift starts
                                                  // is stored in zero page address $f7, $f8
                                                  // shifting a line to the right is a bit more complicated as to shifting to the left.
                                                  // to better explain we have this line as example ABCDEFGH
                                                  // remember that we are only shifting the colors,not the characters
                                                  // 
    ldy #0                                        // start at postion zero (A in our line)
    lda ($f7),y                                   // read the characters color (the zero page address $f7,$f8
    sta $fe                                       // store it temporary in memory address $fe, so now A is stored in $fe
                                                  // 
!loop:                                            // 
    iny                                           // increase our index, y
    lda ($f7),y                                   // read the color at the next postion (B in our line of data)
    sta COLOR                                     // store color B temporary in memory address $ff, so now B is stored in $ff
    lda $fe                                       // now load $fe (that contains A) back into the accumulator
    sta ($f7),y                                   // and store it where B was. The Data line looks like this now AACDEFGH (A has shifted to the right and B is in temporary storage at $ff)
    iny                                           // increase y again
    lda ($f7),y                                   // Read the color on the next position (C in our line of data)
    sta $fe                                       // Store it it temporary in memory address $fe, so now B is stored in $fe
    lda COLOR                                     // now load $ff (that contains B) back into the accumulator
    sta ($f7),y                                   // and put that where C was. The data line now look like this: AABDEFGH (A and B have shifted and C is in temporary storage at $fe)
    cpy #38                                       // see if we are at the end of the line 
    bne !loop-                                    // if not, jump back to the start of the loop
                                                  // after the loop we have processed 39 positions, but the line is 40 long
                                                  // At this point G is in memory storage $fe and H is in storage at $ff
    iny                                           // increase y
    lda $fe                                       // load G
    sta ($f7),y                                   // put it in position H
                                                  // 
                                                  // NOW the data looks like this: AABCDEFG (all colors have shifted except for H which is in storeage at $fe)
    ldy #0                                        // set the index back to zero
    lda COLOR                                     // load color H into the accumulator
    sta ($f7),y                                   // and store it at the first position.
    rts                                           // Now our line looks like this: HABCDEFG all colors have shifted to the right one position.
                                                  // 
//=========================================================================================================
//  SUB ROUTINE TO HELP COLOR THE STARS ON THE START SCREEN
//=========================================================================================================
!color_stars:                                     // there are only a few colors in the stars,
                                                  // for instance all the memory addresses (in color memory) in the array 'stars1' get color 7. the array ends with 0
                                                  // the pointer to the array (stars1 for example) is stored in zero page address $fe, $ff. the wanted color is in $fd
    ldy #0                                        // y needs to be our index of both the color memory and the array index, we can not use x because we need Indirect-indexed addressing and that can only be done with y
    sty $fa                                       // So we use zero page memory address $fa to store the value of y
                                                  // 
!color_loop:                                      //      
    ldy $fa                                       // load y from $fa
    lda ($fe),y                                   // get the value from the stars array with index y, WATCH OUT: the array contains words (16 bit values) but this action will only read the first byte of that word
    cmp #0                                        // if it contains 0, we have reached the end
    beq !exit+                                    // exit in that case
    sta _LINE_POS_                                // if not store the value in zero page address $b.
    inc $fa                                       // increase $fa
    ldy $fa                                       // load $fa into y 
    lda ($fe),y                                   // get the next value from the stars array, this is the second byte of our 16 bit word
    sta _LINE_POS_ +1                             // store that value in $fc
                                                  // now we have a pointer in location $fb, $fc. taken from our stars array and pointing to an address in color memory
    inc $fa                                       // increase $fa for the next round
    ldy #0                                        // reset y to zero
                                                  // 
    lda COLOR                                     // load the color  
    sta (_LINE_POS_),y                            // store that color in the memory address where $fb,$fc points to 
    jmp !color_loop-                              //  
!exit:                                            // we exit when we find value 0 in our array.
    rts                                           // return from subroutine, jump back to the main code.
                                                  // 
//=========================================================================================================
//  SUB ROUTINE DISPLAY TEXT
//=========================================================================================================
!displaytextK:                                    // 
                                                  // first we find out if the text needs to be inverted
                                                  // if the first byte in the text is 143, we will invert the text
                                                  // Inverting the text is done by adding, or bitwise OR, with the number 128
                                                  // see the ora $4b command further down
                                                  // 
    lda #0                                        // by default INVERT = 0 so invertion does not work
    sta INVERT                                    // 
    ldy OFFSET                                    // the start index of the buffer
    lda (_BUFFER_POINTER_),y                      // load the very first character of the text
    cmp #143                                      // if it is not equal to 143, do nothing, skip to the next !: label
    bne !+                                        // 
    lda #128                                      // if the text starts with 143, load the number 128
    sta INVERT                                    // in to INVERT
    inc OFFSET                                    // increase the start index, so the byte 143 is skipped
                                                  // 
!:                                                // $f7 = line number
                                                  // $f8 = column
                                                  // $fb $fc = pointer to the text
    ldx $f7                                       // zero page f7 has the line number where the text should be displayed
    lda screen_lines_low,x                        // we need to create a pointer in $c1 $c2 to the location in screen RAM
    sta $c1                                       // and a pointer in $c3 $c4 to the location in color RAM
    sta $c3                                       // the lower byte of the color ram is the same as the screen ram
    lda screen_lines_high,x                       // get the high byte for the screen ram
    sta $c2                                       // store it in $c2 to complete the pointer
    lda color_lines_high,x                        // 
    sta $c4                                       // we now have pointers to the line, we need to add the column to end up in the exact address
                                                  // 
    clc                                           // Clear the carry flag, we are going to do some additions (adc) so we need to clear the flag
    lda $c3                                       // load the low byte of the pointer to color RAM (the pointer is in $c3,$c4)
    adc $f8                                       // add the column number (stored in $f8)
    sta $c3                                       // put the result back in $c3 (the low byte for the screen RAM pointer)
    sta $c1                                       // Also put the same value in $c1 (the low byte for the color RAM pointer)
    bcc !setup_index+                             // if the result was bigger than #$FF (#255) then the carry flag is set and we need to increase the high byte of the pointer also
    inc $c4                                       // increase the high byte of the screen RAM pointer with one
    inc $c2                                       // and also the high byte of the color RAM pointer
                                                  // 
!setup_index:                                     // 
    ldy OFFSET                                    // load start index into y, y will be our index. It has to be y because we will use Indirect-indexed addressing    (this is zero in most cases. except for when we receive messages)
    sty $ff                                       // we need two indexes, one for reading the buffer
    ldy #0                                        // 
    sty $fe                                       // and one for writing to the screen and color RAM
                                                  // we can not use one index because the buffer may contain bytes for changing the color (144 = black, 145=white, etc)
!readbuffer:                                      // 
    ldy $ff                                       // load the buffer index from address $ff
    lda (_BUFFER_POINTER_),y                      // load a character from the text with y as index this is Indirect-indexed addressing, $fb-$fc contains a pointer to the real address
    cmp #128                                      // compare it to 128, that is the end marker of the text we want to display
    beq !exit+                                    // if equal, exit the loop
    cmp #213                                      // code for skip a number of positions (next byte has that number)
    bne !+                                        //
    inc $ff                                       // set the index to the next byte in the buffer
    iny                                           // increase y
    clc                                           // clear the carry bit, we need to do some a additions (adc)
    lda (_BUFFER_POINTER_),y                      // load the next byte (= number of positions to skip)
    adc $c1                                       // add that to the low byte of the screen memory
    sta $c1                                       // store the result in the low byte of the screen memory
    sta $c3                                       // also store the result in the low byte of the color ram 
    bcc !skip+                                    // see if we rolled over to zero, 
    inc $c2                                       // increase the high bytes in that case
    inc $c4                                       // if not, skip
!skip:                                            //
    inc $ff                                       //
    jmp !readbuffer-                              //
!:  inc $ff                                       // increase the buffer index
    cmp #144                                      // if the byte is 144 or higher, it is not a character but a color code
    bcc !+                                        // if not skip to the next !: label
    sta $f7                                       // store the color code in this address
    jmp !readbuffer-                              // and jump back to read the next byte from the text/buffer
                                                  // 
!:  ldy $fe                                       // load the screen index into y
    ora INVERT                                    // do a bitwise OR operation with the number in address $4b. If the number is 0 nothing will happen. If the number is 128 the character will invert!
    sta ($c1),y                                   // write the character, $c1-$c2 contains a pointer to the address of screen RAM, y is the offset
    lda $f7                                       // load the current color from $f7. this adres contains the current color
    sta ($c3),y                                   // change the color of the character, $c3-$c4 contains a pointer an address in color RAM, y is the offset
    inc $fe                                       // increase the screen index
    jmp !readbuffer-                              // jump back to the beginning of the loop to read the next byte from the text/buffer
                                                  // 
!exit:                                            // at this point we encountered byte 128 in out text string, so we escaped the loop
    rts                                           // return to sender ;-)


//=========================================================================================================
// Prepare the print buffer
//=========================================================================================================
!preparePrintBuffer:   
    ldy OFFSET
    ldx #0
    
!readbuffer:    
    
    lda (_BUFFER_POINTER_),y                      // load a character from the text with y as index this is Indirect-indexed addressing, $fb-$fc contains a pointer to the real address
    cmp #128                                      // compare it to 128, that is the end marker of the text we want to display
    beq !exit+                                    // if equal, exit the loop
    cmp #143                                      // skip screen code 143 and up
    bcs !skip+ 
    stx $ff                                       // temporary store the value of x 
    tax
    lda SCREEN2ASCII,x                            // fetch the ascii code from the array, with x as index
                                                  // now the accumulator contains the Petsci code
    ldx $ff                                       // restore the value of x
    sta PRINTERBUFFER,x                           // store the ascii code in the printbuffer
!checkLineEnd:                                    //
    iny                                           //
    inx                                           //
    cpx #40                                       // insert a new line after the first 40 chars (first line is only 40 chars)
    beq !newline+                                 //
    cpx #118                                      // insert newlines before we reach 118 characters
    beq !newline+                                 //
    cpx #198                                      // insert newline before we reach the end of the second line
    beq !newline+                                 //
    jmp !readbuffer-                              //
!newline:                                         //
    lda #10                                       //
    sta PRINTERBUFFER,x                           //
    inx                                           //
    jmp !readbuffer-                              //
!skip:                                            //
    iny                                           //
    jmp !readbuffer-                              //
!exit:                                            //
    lda #10                                       //
    sta PRINTERBUFFER,x                           //
    inx                                           //
    lda #0                                        //
    sta PRINTERBUFFER,x                           //
rts                                               //
//=========================================================================================================
// SUBROUTINE FOR PRINTING 
// $fb $fc
//========================================================================================================= 
!printTextK:
    lda PRINTIT
    cmp #1
    beq !+
    rts
!:
    lda #4                                        // No need to do this every time?
    ldx #4                                        // No need to do this every time?
    ldy #7
    sty PRINTIT
    jsr $ffba                                     // No need to do this every time?
    jsr $ffc0                                     // No need to do this every time?
    ldx #4
    jsr $ffc9                                     // We leave in this one, in case the printer is 
    cmp #5                                        // switched off unexpectedly
    bne !printer_ready+                           // If true, all is OK, print the messagage
  lda #0                                          // If false, we disable the printer output    
    sta PRINTER_ENABLED_FLAG                      // No device found, set printer output to off
    jmp !+                                        // And return to caller    
!printer_ready:
    ldx #0                                        // x = termination character (nul)
    lda #<PRINTERBUFFER                           // a = lowbyte of print buffer
    ldy #>PRINTERBUFFER                           // y = highbyte of printbuffer
    jsr $B489                                     // jump to subroutine in basic rom
    jsr $AB21                                     // jump to actual printing routine in basic rom
!:  lda #4                                        // Close input and output channels  
  jsr $ffc3                                       //  
  jsr $ffcc                                       //
rts                                               // Return to caller 

//=========================================================================================================
// SUB ROUTINE, DELAY
//=========================================================================================================
!delay:                                           // the delay sub routine is just a loop inside a loop
                                                  // 
    ldx #00                                       // the inner loop counts up to 255
                                                  // 
!loop:                                            // the outer loop repeats that 255 times
                                                  // 
    cpx DELAY                                     // 
    beq !enddelay+                                // 
    inx                                           // 
    ldy #00                                       // 
                                                  // 
!delay:                                           // 
                                                  // 
    cpy #255                                      // 
    beq !loop-                                    // 
    nop                                           // 
    nop                                           // 
    iny                                           // 
    jmp !delay-                                   // 
                                                  // 
!enddelay:                                        // 
    rts                                           // 
                                                  // 
//=========================================================================================================
// SUB ROUTINE, diaplay [ F7 ] Exit menu
//=========================================================================================================
!display_F7_menuItem:
   // we use this same line multiple times in the menus and the displayText macro is quite heavy
   // so it makes sense to use a soub routine for this
   displayText(text_exit_menu,17,3)                                                  
   rts                                                   

//=========================================================================================================
// SUB ROUTINE, FIX INVERTED CHARACTERS IN THE MESSAGE LINES
//=========================================================================================================
!fix_inverted_chars:  
   lda MENU_ID 
   cmp #1
   bcs !menu_version+
   ldx #0
!loop:   
   lda $770,x 
   cmp #128
   bcc !+ 
   adc #127
   sta $770,x
!: inx
   cpx #120
   beq !exit+
   jmp !loop-
!exit:
   jsr !show_cursor-                             // Show the cursor
   lda #10; sta $cf
   rts

!menu_version:   
   ldx #0
!loop:   
   lda $4A0,x    
   cmp #128
   bcc !+ 
   adc #127
   sta $4A0,x
!: inx
   cpx #250
   beq !exit-
   jmp !loop-
   
   
   
//=========================================================================================================
// SUB ROUTINE, WAIT FOR READY TO RECIEVE SIGNAL FROM ESP32
//=========================================================================================================
!wait_for_ready_to_receive:                       // wait for ready to receive before we send a byte
                                                  // 
    lda _IO2_                                     // read a value from IO2
    cmp #128                                      // compare with 128
    bcc !wait_for_ready_to_receive-               // if smaller try again
    rts                                           // 
                                                  // 
//=========================================================================================================
// SUB ROUTINE, SEND TX BUFFER TO ESP32
//=========================================================================================================
!send_buffer:                                     // 
    lda VICEMODE                                  // if we are running in simulation mode
    cmp #1                                        // jump to exit without interacting with ESP32
    bne !+                                        // 
    jmp !exit+                                    //  
!:  ldx #0                                        // x will be our index when we loop over the RXBUFFER
!sendms:                                          //  
    jsr !wait_for_ready_to_receive-               // wait for ready to receive (bit D7 goes high)
    lda TXBUFFER,x                                // load a byte from the TXBUFFER with index x
    sta _IO1_                                     // send it to IO1
    cmp #128                                      // if the last byte was 128, the buffer is finished
    beq !exit+                                    // exit in that case
    inx                                           // increase the x index
    jmp !sendms-                                  // jump back to send the next byte
                                                  // 
!exit:                                            // 
    rts                                           // 
                                                  // 
//=========================================================================================================
// SUB ROUTINES, to draw horizontal lines on screen (used in the menus)
//=========================================================================================================
!draw_top_menu_lines:                             // this first routine uses the second routine to draw
    lda #0                                        // a line on line 0 and line 2
    sta _LINE_POS_                                // 
    jsr !draw_menu_line+                          // 
    lda #2                                        // 
    sta _LINE_POS_                                // 
    jsr !draw_menu_line+                          // 
    rts                                           // 
//=========================================================================================================
!draw_menu_line:                                  // 
    ldx _LINE_POS_                                // load the desired position of the line from $fb
    lda screen_lines_low,x                        // look up the corresponding address in screen RAM (low byte first)
    sta _LINE_POS_                                // store that in $fb to create a pointer to screen RAM
    sta _LINE_POS_ +2                             // store the same low byte to create a pointer to the corresponding address in color RAM
    lda screen_lines_high,x                       // load the high byte of the address of screen RAM
    sta _LINE_POS_ +1                             // store that in $fc, now we have a pointer $fb,$fc to the screen RAM
    lda color_lines_high,x                        // load the high byte of the address of color RAM
    sta _LINE_POS_ +3                             // store that in $fe, now we have a pointer $fd,$fe to the color RAM
    ldy #0                                        // y is the itterator for the loop
!loop:                                            // start the loop
    lda #64                                       // load the screen code for a horizontal bar
    sta (_LINE_POS_),y                            // put it on screen
    lda _LINE_COLOR_                              // load the color value
    sta (_LINE_POS_ + 2),y                        // put it on screen
    iny                                           // increase y
    cpy #40                                       // if y reaches 40, exit the loop
    bne !loop-                                    // else, continue the loop
    lda #5                                        // color number 5 is green
    sta _LINE_COLOR_                              // store the color code in $c9 as the default color
    rts                                           // return from subroutine
                                                  // 
//=========================================================================================================
// SUB ROUTINE, send start byte, byte should be stored in zero page address $ff
//=========================================================================================================
!send_start_byte_ff:                              // 
    lda VICEMODE                                  // if we are running in simulation mode
    cmp #1                                        // jump to exit without interacting with ESP32
    bne !+                                        // 
    jmp !vicemode+                                //   
                                                  //
!:  lda #0                                        // load zero into accumulator
    sta TIMOUTERROR                               //
    sta RXINDEX                                   // reset the receive buffer index
    sta RXFULL                                    // reset the rxfull flag
    lda #128                                      //
    sta RXBUFFER                                  //
    jsr !wait_for_ready_to_receive-               // 
    lda CMD                                       // load the byte from variable CMD
    sta _IO1_                                     // write the byte to IO1
                                                  // 
    lda #0                                        // 
    sta TIMEOUT1                                  // we need a simple timeout on this next loop
    sta TIMEOUT2                                  //
!wait_message_complete:                           // wait for a response
    inc TIMEOUT1                                  // increase variable timeout1
    lda TIMEOUT1                                  // 
    cmp #0                                        //
    bne !+                                        //
    inc TIMEOUT2                                  // increase timout2 when timeout1 overloops
    lda TIMEOUT2                                  //
    cmp #170                                      // when timeout2 reaches a certain number, exit the loop
    beq !exittimeout+                             //
!:                                                //
    lda RXFULL                                    // load RXFULL flag
    cmp #0                                        // compare with zero
    beq !wait_message_complete-                   // stay in this loop until we get a response
!exit:                                            // 
    rts                                           // return
                                                  // 
!exittimeout:                                     //
    lda #2                                        // make the border red
    sta $d020                                     // for a short while
    lda #30 ; sta DELAY ; jsr !delay-             //
    lda #0                                        // load zero into accumulator
    sta $d020                                     // make the border black again
    sta RXINDEX                                   // reset the receive buffer index
    sta RXFULL                                    // reset the rxfull flag
    lda #128                                      // 
    sta RXBUFFER                                  // Empty and close the RXBUFFER
    sta SPLITBUFFER                               // Empty and close the SPLITBUFFER
    lda #1                                        // set Timeouterror variable to 1
    sta TIMOUTERROR                               //
!vicemode:
    rts                                           //
                                                  //

//=========================================================================================================
// NMI ROUTINE
//=========================================================================================================
nmi:                                              // When the ESP32 loads a byte in the 74ls244 it pulls the NMI line low
                                                  // to signal the C64. Telling it to read the byte
    pushreg()                                     // 
    lda _IO2_                                     // read from IO2. This causes the IO2 line on the cartridge port to go low. Now the ESP32 knows the byte has been received.
    ldx RXINDEX                                   // Load the buffer index into x
    sta RXBUFFER,x                                // write the byte into the buffer index at position x
    cmp #128                                      // a message is complete when we receive 128
    beq !message_complete+                        // jump to then label "message complete" when the message is complete
    inx                                           // increase the x value
    stx RXINDEX                                   // store new x value in RXINDEX
    jmp  !exit_nmi+                               // jump to the exit of this routine
                                                  // 
!message_complete:                                // 
                                                  // 
    lda RXINDEX                                   // load the value of RXINDEX to see how much we have in the buffer
    cmp #0                                        // if the index is still 0, the buffer is empty, set RXFULL to 2 in that case
    bne !not_empty+                               // jump to the next label if the buffer is NOT empty
    lda #2                                        // RXFULL=2 means there is no message in buffer
    sta RXFULL                                    // store #2 in the RXFULL indicator
    jmp  !exit_nmi+                               // and exit the routine
                                                  // 
!not_empty:                                       // if the message is not empty
                                                  // 
    lda #1                                        // Store #1 in the RXFULL indicator
    sta RXFULL                                    // 
                                                  // 
!exit_nmi:                                        // 
    lda #$01                                      // acknowledge the nmi interrupt
    sta $dd0d                                     // you MUST write and read this address to acknowledge the nmi interrupt
    lda $dd0d                                     // you MUST write and read this address to acknowledge the nmi interrupt
    popreg()                                      // 
    rti                                           // return interupt
                                                  // 
admin_nmi:                                        // On the admin message screen, we use
    pushreg()                                     // a different NMI routine.
    lda _IO2_                                     // This one receives bytes (Petsci codes)
    cmp #128                                      // and writes them directly to screen.
    bne !chrout+                                  //
    lda #1                                        //
    sta RXFULL                                    //
    jmp !exit_nmi-                                //
!chrout: jsr $ffd2                                //
    jmp !exit_nmi-                                //
                                                  //
update_nmi:                                       // While the updates runs, we use a different
   pushreg()                                      //
   lda #1                                         //
   sta HOME_COLM                                  //
   lda _IO2_                                      // this is a number between 1 and 28
   and #31                                        //
   sta HOME_COLM                                  //
!: jmp !exit_nmi-                                 //

//=========================================================================================================                                                  
// SCREEN BACKUP / RESTORE SCREEN
//=========================================================================================================                                                  
!screen_backup:                                   //
    lda SCREEN_ID                                 //
    cmp #3                                        //
    bne !backup_public_screen+                    //    
!backup_private_screen:                           //
    jsr !backup_pm_screen-                        //
    rts                                           //
!backup_public_screen:                            //
    jsr !backup_screen-                           //
    rts                                           //
                                                  //
!screen_restore:                                  //
    lda SCREEN_ID                                 //
    cmp #3                                        //
    bne !restore_public_screen+                   //
!restore_private_screen:                          //
    jsr !restore_pm_screen-                       //
    jmp !exit+                                    //
!restore_public_screen:                           //
    jsr !restore_screen-                          //
!exit: clc                                        // Clear carry so we can SET the cursor position
    ldx #22                                       // Select row
    ldy #0                                        // Select column
    jsr $fff0                                     // Set cursor
    jsr !show_cursor-                             // Show cursor
    lda CURSORCOLOR                               // Load cursor color
    jsr $ffd2                                     // Output that petscii code to screen to change the cursor to white                                                  
    rts
    
//=========================================================================================================                                                  
// ADMIN MESSAGES
//=========================================================================================================                                                  
// this is a special screen with a message from the system admin
!admin_screen:                                    //  
    rts // NOT USED NOW
!:  lda #232                                      // Load 232 in accumulator (check for admin messages)
    sta CMD                                       // Store that in CMD
    jsr !send_start_byte_ff-                      // receive the admin message (if any)
    lda RXBUFFER                                  // load first byte of rxbuffer
    cmp #1                                        // if it equals 1, we have a message.
    beq !+                                        //
    rts                                           // if not, return 
!:  jsr !screen_backup-                           // at this point, we should have a message waiting for us.
    jsr $E544                                     // clear screen
    jsr !start_menu_screen-                       //
    displayText(text_sys_message,1,12)            //
    lda #22 ; sta _LINE_POS_                      // Load 23 into accumulator and store it in zero page address $fb
    jsr !draw_menu_line-                          // Call the draw_menu_line sub routine to draw a line on row 23
    displayText(text_list_menu,23,0)              //
                                                  //
    clc                                           // Clear carry so we can SET the cursor position
    ldx #5                                        // Select row
    ldy #0                                        // Select column
    jsr $fff0                                     // Set cursor
    lda #0                                        //
    sta RXFULL                                    //
    lda #<(admin_nmi)                             // \
    sta $0318                                     //  \ Load our new nmi vector
    lda #>(admin_nmi)                             //  / And replace the old vector to our own nmi routine
    sta $0319                                     // /  
                                                  //
    jsr !wait_for_ready_to_receive-               // 
    lda #231                                      // 
    sta _IO1_                                     // write the byte to IO1
                                                  //
!wait_screen_complete:                            //
    lda RXFULL                                    //
    cmp #1                                        //
    bne !wait_screen_complete-                    //
    lda #0                                        // reset RXFULL
    sta RXFULL                                    //
    lda #<(nmi)                                   // \
    sta $0318                                     //  \ Load our normal nmi vector
    lda #>(nmi)                                   //  / And replace the old vector to our own nmi routine
    sta $0319                                     // /  
                                                  //
!read_key:                                        //
  jsr $ffe4                                       //
  cmp #136                                        //
  beq !exit+                                      //
  cmp #78                                         // 'n' key pressed?
  beq !nextAdminMessage+                          // If true, go to the next message
  cmp #80                                         // 'p' key pressed?
  beq !prevAdminMessage+                          // if so, go to previous message
  jmp !read_key-                                  // 
!nextAdminMessage:
!prevAdminMessage:
!exit:                                            //
  jsr !screen_restore-                            //
  rts                                             //

!admin_screen_history: 
  jsr !screen_backup-  
  jsr $E544                                       // clear screen
  jsr !start_menu_screen-                         //
  displayText(text_sys_message,1,12)              //
  lda #22 ; sta _LINE_POS_                        // Load 23 into accumulator and store it in zero page address $fb
  jsr !draw_menu_line-                            // Call the draw_menu_line sub routine to draw a line on row 23
  displayText(text_list_menu,23,0)                //
  displayText(text_wait_please,10,13)             //
  
  lda #1
  sta TXBUFFER
  ldy #1
  lda #128
  sta TXBUFFER,y
  lda #230                                        // Load 230 into accumulator
  sta _IO1_                                       // Send the start byte
  jsr !send_buffer-                               // 
  
  // wait for the message..
  
  // display the message..
!: jmp !-
  rts 

//=========================================================================================================
// CONSTANTS
//=========================================================================================================              
text_sys_message:             .byte 151; .text "ADMIN MESSAGES"; .byte 128
text_f7_exit:                 .byte 147; .text "[ F7 ] Exit"; .byte 128
text_main_menu:               .byte 151; .text "MAIN MENU"; .byte 128
text_menu_item_1:             .byte 147; .text "[ F1 ] Wifi Setup"; .byte 128
text_menu_item_2:             .byte 147; .text "[ F2 ] Account Setup";.byte 128
text_menu_item_3:             .byte 147; .text "[ F3 ] List Users";.byte 128
text_menu_item_4:             .byte 147; .text "[ F4 ] Server Setup";.byte 128
text_menu_item_6:             .byte 147; .text "[ F5 ] OSC Setup";.byte 128
text_menu_item_5:             .byte 147; .text "[ F6 ] About This Software";.byte 128
text_menu_item_8:             .byte 147; .text "[ F8 ] Output Setup";.byte 128
text_version:                 .byte 151; .text "Version";.byte 128
version:                      .byte 151; .text "3.82"; .byte 128
versionmask:                  .byte 151; .text "ROM x.xx ESP x.xx"; .byte 128
version_date:                 .byte 151; .text "03/2025";.byte 128
text_wifi_menu:               .byte 151; .text "WIFI SETUP"; .byte 128
text_wifi_ssid:               .byte 145; .text "SSID:"; .byte 128
text_wifi_password:           .byte 145; .text "Password:"; .byte 128
text_wifi_wait:               .byte 145; .text "Wait for connection (" 
text_wifi_wait_countdown:     .text "9)"; .byte 128
text_server_menu:             .byte 151; .text "SERVER SETUP  ";.byte 213,94,145;.text "Server:"; .byte 213,73                                                                     
                                         .text "Example: www.chat64.nl"; .byte 128                                                                   
text_save_settings:           .byte 147; .text "[ F1 ] Save Settings"; .byte 128
text_exit_menu:               .byte 147; .text "[ F7 ] Exit Menu"; .byte 128

text_osc_menu:                   .byte 151; .text "OSC SETUP"; .byte 128
text_osc_ip:                    .byte 145; .text "OSC IP:"; .byte 128
text_osc_port:                  .byte 145; .text "OSC Port:"; .byte 128


text_output_menu:             .byte 151; .text "OUTPUT SETUP  "; .byte 213,94,145
text_status:                  .text "Output to printer Status:"; .byte 128                                                                                                                    
text_enabled:                 .byte 213,15,158; .text "Enabled "; .byte 128                                                                                                                                         
text_disabled:                .byte 213,15,158; .text "Disabled"; .byte 128                                                                                                                                          
text_printer_enabled:         .byte 145; .text "Printer Connected!          "; .byte 128                                                                                                                                                                                                                                                          
text_printer_disabled:        .byte 145; .text "Printer disabled            "; .byte 128                                                                                                                        
text_printer_error:           .byte 145; .text "Printer not found or offline"; .byte 128                                                                                                                            
text_output_enable:           .byte 147; .text "[ F1 ] Enable Output to printer"; .byte 128                   
text_output_disable:          .byte 147; .text "[ F3 ] Disable Output to printer"; .byte 128  
    

text_about_menu:              .byte 151; .text "ABOUT CHAT64"; .byte 128
text_about_line_1:            .byte 145; .text "Initially developed by Bart Venneker" ; .byte 213,4
                                         .text "as a proof of concept, a new version" ; .byte 213,4
                                         .text "of CHAT64 is now available to everyone. "
                                         .text "We proudly bring you CHAT64 3.0"  ; .byte 213,9 
                                         .text "Made by Bart Venneker and Theo van den  "
                                         .text "Beld in 2023"; .byte 128
                                        
text_about_line_8:            .byte 145; .text "Hardware and software (Open Source)" ; .byte 213,5
                                         .text "and a manual are available on GitHUB"; .byte 213,44                                                                                                                         
                                         .text "https://github.com/bvenneker/Chat64"; .byte 128

text_about_footer:            .byte 147; .text "[ F7 ] Exit to main menu"; .byte 128
text_account_menu:            .byte 151; .text "ACCOUNT SETUP" ; .byte 128
text_account_mac:             .byte 145; .text "Mac address:"; .byte 128
text_account_regid:           .byte 145; .text "Registration id:"; .byte 128
text_account_nick_name:       .byte 145; .text "Nick Name:" ; .byte 128
                                                                                                                        
text_settings_saved:          .byte 157; .text "Settings Saved, please wait"; .byte 128
text_account_menu_item_2:     .byte 147; .text "[ F6 ] Reset to factory defaults" ; .byte 128
text_reset_shure:             .byte 146; .text "Clear all settings?"  ; .byte 213,52
                                         .text "Are you shure? press [ F4 ] to confirm"; .byte 213,87
                                         .text "Press any other key to exit" ; .byte 128

text_help_pm:                 .byte 151; .text "Private Messaging"; .byte 128
text_help_private:            .byte 147; .text "To send a private message to someone:   type "; 
                              .byte 146; .text "@username"; .byte 147; .text " at the start of your"; .byte 213,5
                                         .text "message."; .byte 213,72 
                                         .text "Use F5 to switch between the public"; .byte 213,5
                                         .text "and private message screen."; .byte 128
                                         
text_error_no_internet:       .byte 146; .text "There is no Internet connection,        go back and check your WiFi Settings";.byte 128
text_help_ai:                      .byte 151; .text "A.I. Chatbot Eliza"; .byte 128                                                 
text_help_eliza:                   .byte 147; .text "Try our A.I. Chat Bot Eliza!"; .byte 213,12
                                         .text "Switch to private messaging and start"; .byte 213,3
                                         .text "your message with @Eliza"; .byte 213,56
                                         .text "Eliza is a true A.I. chatbot that uses  natural language processing to create   humanlike dialogue"
                                         .byte 213,62; .text "Try it! it's a lot of fun!";.byte 128                          
text_any_key:                 .byte 151; .text "Press any key to continue"; .byte 128
text_help_ul:                 .byte 151; .text "See who is online"; .byte 128
text_help_userlist:           .byte 147; .text "Press F3 from the chat window to see    who is online."; .byte 213,66
                                         .text "You will see a list of all users where  online users "
                                         .text "are marked in green while  offline users are gray"; .byte 128                                  
    
message_start:                .byte 21,20,19,18,17,16,15 // lookup table

text_time_offset:             .byte 145; .text "Time offset from GMT:"; .byte 128

text_unreg_error:             .byte 146; .text "Warning: Unregistered Cartridge"; .byte 213,11
                                         .text "to register goto: "; .byte 128                                                    
//empty_line:                   .text "                                        ";.byte 128
text_error_vice_mode:         .byte 146; .text "Cartridge not installed."; .byte 128
text_wait_please:             .byte 146; .text "Please wait"; .byte 128
text_error_private_message:   .byte 146; .text "Don't send public msgs from priv. screen"; .byte 128
text_F5_toggle:               .byte 151; .text "Private Messaging         [F5] Main Chat"; .byte 128
text_list_menu:               .byte 147; .text "[P]revious      [F7] Exit         [N]ext"; .byte 128
text_list_menu2:              .byte 147; .text "[P]revious    [R]eturn to Chat   [N]ext"; .byte 128
text_update_menu:             .byte 151; .text "UPDATE MENU"; .byte 128
text_update_line1:            .byte 147; .text "There is a new version available"; .byte 128
text_update_line2:            .byte 147; .text "Do you want to upgrade? Y/N"; .byte 128
text_update_line3:            .byte 151; .text "new Rom version : "; .byte 128
text_update_line4:            .byte 151; .text "new ESP version : "; .byte 128
text_update_line6:            .byte 147; .text "Please press Y or N"; .byte 128
text_update_download:         .byte 147; .text "Installing new firmware"; .byte 128
text_update_done:             .byte 147; .text "Update successful!"; .byte 128
text_update_download1:        .byte 147,112; .fill 28,64 ; .byte 110,128
text_update_download2:        .byte 147,93; .fill 28,32 ; .byte 93,128
text_update_download3:        .byte 147,109; .fill 28,64 ; .byte 125,128
sysmessage_update:            .byte 2,143,149;.text "New version available, Press F1!        "; .byte 128                                                                        
                                                                        
// data for big letters on the start screen
big_letters: .byte 158,85,69,69,73,93,32,32,93,85,69,69,73,67,114,67,32,85,69,69,73,66,213,19
             .byte 158,71,32,32,32,93,32,32,93,93,32,32,93,32,93,32,32,84,32,32,32,66,32,32,93,213,16
             .byte 150,71,32,32,32,107,67,67,115,107,67,67,115,32,93,32,32,84,69,69,73,74,67,67,115,213,16
             .byte 148,71,32,32,32,93,32,32,93,93,32,32,93,32,93,32,32,84,32,32,66,32,32,32,93,213,16
             .byte 148,74,70,70,75,93,32,32,93,93,32,32,93,32,93,32,32,74,82,82,75,32,32,32,93,213,93
             .byte 150; .text "made by bart and theo in 2023"; .byte 128
             
text_error_unknow_pmuser:     .byte 146; .text "Error: unknown user:  "; .byte 128
text_rxerror:                 .byte 143,146; .text"system: Error: received garbage";.byte 128
text_pmuser:                  .text "@Eliza "; .byte 128,128,128,128,128,128 ,128 
// data for stars on the start screen (these are memory addresses in the color RAM)
stars1:                       .word 55380,55391,55398,55410,55420,55430,55432,55462,55471,55481,56173,56188,56076,56099,56131,56170,56172,56189,56211,0,0// color memory addressed for the stars, color $07
stars2:                       .word 55381,55392,55390,55397,55399,55409,55411,55422,55425,55482,55502,55511,55521,55480,55463,55470,55340,55351,55358,55370,55379,55429,55433,55438,55461,55450,55441,55472,56075,56077,56098,56091,56100,56116,56130,56132,56139,56149,56169,56190,56210,56212,56229,56251,56036,56059,0,0// color memory addressed for the stars, color $08
text_name_taken:              .byte 146; .text "Error: nickname already taken"; .byte 128
text_registration_ok:         .byte 149; .text "Registration was successful";.byte 128
text_user_list:               .byte 151; .text "USER LIST";.byte 128                       
screen_lines_low:             .byte $00,$28,$50,$78,$A0,$C8,$F0,$18,$40,$68,$90,$b8,$e0,$08,$30,$58,$80,$a8,$d0,$f8,$20,$48,$70,$98,$c0 // lookup table
screen_lines_high:            .byte $04,$04,$04,$04,$04,$04,$04,$05,$05,$05,$05,$05,$05,$06,$06,$06,$06,$06,$06,$06,$07,$07,$07,$07,$07 // lookup table
color_lines_high:             .byte $d8,$d8,$d8,$d8,$d8,$d8,$d8,$d9,$d9,$d9,$d9,$d9,$d9,$da,$da,$da,$da,$da,$da,$da,$db,$db,$db,$db,$db // lookup table
petsciColors:                 .byte $05,$05,$1c,$9f,$9c,$1e,$1f,$9e,$81,$95,$96,$97,$98,$99,$9a,$9b // lookup table
factoryreset:                 .text "RESET!"; .byte 128
doupdate:                     .text "UPDATE!"; .byte 128  
NEWSW:                        .fill 10,32 ; .byte 128         
NEWROM:                       .fill 10,32 ; .byte 128         
SWVERSION:                    .fill 10,32 ; .byte 128            
SERVERNAME:                   .fill 40,32 ; .byte 128        
VOICE:                        .byte 1             // Use this voice of the sid chip (we alternate between 1 and 2)      
UPDATECHECK:                  .byte 1             //                                                  
OFFSET:                       .byte 0             // start reading the buffer with his offset                                                  
HAVE_M_BACKUP:                .byte 0             // 
HAVE_P_BACKUP:                .byte 0             //
HAVE_ML_BACKUP:               .byte 0             //                                                  
VICEMODE:                     .byte 0             //                                                  
CHECKINTERVAL:                .byte 60            //                                                  
CHECKREPEAT:                  .byte 2             //
WAITFORMESSAGE:               .byte 0             //
RETURNTOMENU:                 .byte 0             //                                   
PRINTIT:                      .byte 0             //                        
HAVEWIFI:                     .byte 0             //        
TIMOUTERROR:                  .byte 0             //      
SCREEN2ASCII:                                     //
.byte   64, 65, 66, 67, 68, 69, 70, 71, 72, 73            //   0 -   9
.byte  74, 75, 76, 77, 78, 79, 80,81, 82, 83              //  10 -  19
.byte  84, 85, 86, 87, 88, 89, 90, 91, 92, 93             //  20 -  29
.byte   94, 95, 32, 33, 34, 35, 36, 37, 38, 39            //  30 -  39
.byte   40, 41, 42, 43, 44, 45, 46, 47, 48, 49            //  40 -  49
.byte   50, 51, 52, 53, 54, 55, 56, 57, 58, 59            //  50 -  59
.byte   60, 61, 62, 63, 192, 193, 194, 195, 196, 197      //  60 -  69
.byte  198,199,200,201,202,203,204,205,206,207            //  70 -  79
.byte  208,209,210,211,212,213,214,215,216,217            //  80 -  89
.byte  218,219, 32, 121, 32, 32, 32, 32, 32, 32           //  90 -  99
.byte   95, 32, 32, 32, 32, 32, 32, 32, 32, 32            // 100 - 109
.byte   32, 95, 32, 32, 32, 32, 32, 32, 32, 32            // 110 - 119
.byte   32, 32, 32, 32, 32, 32, 32, 32, 64,65             // 120 - 129        
.byte   66, 67, 68, 69, 70, 71, 72, 73, 74, 75            // 130 - 139
.byte   76, 77, 78, 79, 80,81, 82, 83, 84, 85             // 140 - 149
.byte   86, 87, 88, 89, 90, 91, 92, 93, 94, 95            // 150 - 159
.byte   32, 33, 34, 35, 36, 37, 38, 39, 40, 41            // 160 - 169
.byte   42, 43, 44, 45, 46, 47, 48, 49, 50, 51            // 170 - 179
.byte   52, 53, 54, 55, 56, 57, 58, 59, 60, 61            // 180 - 189
.byte   62, 63, 192, 193, 194, 195, 196, 197,198,199      // 190 - 199
.byte   200,201,202,203,204,205,206,207,208,209           // 200 - 209
.byte   210,211,212,213,214,215,216,217,218,219           // 210 - 219
.byte   32, 121, 32, 32, 32, 32, 32, 32, 95, 32           // 220 - 229
.byte   32, 32, 32, 32, 32, 32, 32, 32, 32, 95            // 230 - 239
.byte   32, 32, 32, 32, 32, 32, 32, 32, 32, 32            // 240 - 249
.byte   32, 32, 32, 32, 32, 32                            // 250 - 255        

song0: .byte 8,26,7,0,8,22,7,0,8,24,255        
song1: .byte 25,20,7,0,25,30,25,20,25,30,40,50,10,0,30,40,10,0, 255        
song2: .byte 20,36,20,48,255     
song3: .byte 40,36,20,26,20,36,20,26,40,46,255      
song4: .byte 10,40, 10,0, 10,40, 10,0, 10,40, 10,0, 20,40,255        
song5: .byte 8,28,7,0,8,24,7,0,8,26,255
        
//=========================================================================================================
// VARIABLE BUFFERS
//=========================================================================================================
.segment Variables [start=$3200, virtual]
PRINTER_ENABLED_FLAG:     .byte 0         // Output to printer flag
PRINTERBUFFER:                .fill 165,0
USER_LIST_FLAG:               .byte 0             // User list source flag   
READLIMIT:                    .byte 0             // How many chars to read from screen (in configuration screens)
INVERT:                       .byte 0             // Invert the text (used in system messages)       
CMD:                          .byte 0             // Command to send to the cartridge
HOME_LINE:                    .byte 0             // the start line of the text input box
HOME_COLM:                    .byte 0             // the start column of the text input box
LIMIT_LINE:                   .byte 0             // the end line of the text input box
LIMIT_COLM:                   .byte 0             // the end column of the text input box
CLEAR_FIELD_FLAG:             .byte 0             // a variable to indicate we want to clean the textfield when we start typing, used in the menus
SCREEN_ID:                    .byte 0             // variable for the screen id, this changes the behaviour of the text input routine
MENU_ID:                      .byte 0             // variable for the menu id, this changes the behaviour of the text input routine
CONFIG_STATUS:                .byte 0             // variable to store the caonfiguration status
DELAY:                        .byte 0             // used in the delay routine
RXINDEX:                      .byte 0             // index for when we recieve data
RXFULL:                       .byte 0             // indicator if the buffer contains a complete message
PAGE:                         .byte 0             //
COLOR:                        .byte 0             //
TIMER:                        .byte 0             //
TIMER2:                       .byte 0             //
MESSAGELEN:                   .byte 0             //
TEMPCOLOR:                    .byte 0             //
SEND_ERROR:                   .byte 0             //
DO_RESTORE_MESSAGE_LINES:     .byte 0             //
PMUSER:                       .fill 12,32         //
CURSORCOLOR:                  .byte 0             //
SPLITBUFFER:                  .fill 40,32         //
RXBUFFER:                     .fill 256,128       // reserved space for incoming data
TXBUFFER:                     .fill 256,128       // reserved space for outgoing data 
M_CHARBLOCK400:               .fill 256,32        // reserved memory space to backup the screen 1
M_CHARBLOCK500:               .fill 256,32        // when leaving the main chat screen
M_CHARBLOCK600:               .fill 256,32        // 
M_CHARBLOCK700:               .fill 256,32        // 
M_CHARBLOCK770:               .fill 256,32        // reserved memory space to backup the message lines (character info)                                                  
M_COLBLOCK400:                .fill 256,0         // screen color information
M_COLBLOCK500:                .fill 256,0         // to backup colors when leaving the main chat screen
M_COLBLOCK600:                .fill 256,0         // 
M_COLBLOCK700:                .fill 256,0         // 
M_COLBLOCK770:                .fill 256,0         // reserved memory space to backup the message lines (color info)
P_CHARBLOCK400:               .fill 256,32        // reserved memory space to backup the screen 2
P_CHARBLOCK500:               .fill 256,32        // when leaving the private chat screen
P_CHARBLOCK600:               .fill 256,32        // 
P_CHARBLOCK700:               .fill 256,32        // 
P_COLBLOCK400:                .fill 256,0         // screen color information
P_COLBLOCK500:                .fill 256,0         // to backup colors when leaving the private chat screen
P_COLBLOCK600:                .fill 256,0         // 
P_COLBLOCK700:                .fill 256,0         //  
debug_in:                     .byte 0             //                                 
TIMEOUT1:                     .byte 0             //                                
TIMEOUT2:                     .byte 0             //            
// --- BEGIN ADDED CODE: OSC + Paddle Variables ---
osc_target_ip:     .fill 32, $20
osc_target_port:   .fill 6,  $20

potx1_target:      .fill 32, $20
poty1_target:      .fill 32, $20
potx2_target:      .fill 32, $20
poty2_target:      .fill 32, $20

cue_list:          .fill 10*32, $20 // 10 lines of 32 bytes each
last_potx1:        .byte 0
last_poty1:        .byte 0
last_potx2:        .byte 0
last_poty2:        .byte 0
// --- END ADDED CODE: OSC + Paddle Variables ---

//=========================================================================================================
// MACROS
//=========================================================================================================
.macro playsong(song){
  lda #<(song)
  sta _NOTE_
  lda #>(song)
  sta _NOTE_ +1
  jsr !playsongk-
  }
  
  
.macro displayText(text,line,column){             // 
                                                  // $f7 = line number
                                                  // $f8 = column
                                                  // $fb $fc = pointer to the text
                                                  // 
    lda #line                                     // 
    sta $f7                                       // store the line in zero page address $f7
    lda #column                                   // 
    sta $f8                                       // store the column in zero page address $f8
    lda #<(text)                                  // store the lowbyte of the text location in zero page address $fb
    sta _BUFFER_POINTER_                          // $fb is a zero page address
    lda #>(text)                                  // store the highbyte of the text location in $fc
    sta _BUFFER_POINTER_ +1                       // $FC is is a zero page address
    jsr !displaytextK-                            // Call the displaytext routine
                                                  // 
    }                                             // 
                                                  // 
.macro pushreg(){                                 // 
                                                  // 
    php                                           // push the status register to stack
    pha                                           // push A to stack
    txa                                           // move x to a
    pha                                           // push it to the stack
    tya                                           // move y to a
    pha                                           // push it to the stack
    }                                             // 
                                                  // 
.macro popreg(){                                  // 
                                                  // 
    pla                                           // pull the y register from the stack
    tay                                           // move it to the y register
    pla                                           // pull the x register from the stack
    tax                                           // move it to the x register
    pla                                           // pull the acc from the stack
    plp                                           // pull the the processor status from the stack
    }                                             // 
                                                  // 
.macro colordebug(i){                             // 
    sta debug_in                                  //
    lda #i                                        //
    sta $d020                                     //
    lda debug_in                                  //
}
