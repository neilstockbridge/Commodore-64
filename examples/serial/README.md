
# Example of using the RS-232 port

Sending debug output to the RS-232 port is handy because:

  - It works in graphics mode or multi-color text mode
  - The data on the remote system is still there after a crash
  - The remote system being a modern machine can store lots of output and scroll through it


## Configuring VICE

  - Under `RS232 Settings` ( right-click)
    - Tick `Userport RS232 emulation`
    - Select `Userport RS232 baud rate > 2400`
    - Select `Userport RS232 device > Dump to file`
    - `touch /tmp/C64-RS232-output.txt` because it needs to exists before you can select it in VICE
    - Set `Dump filename...` to `/tmp/C64-RS232-output.txt`

  - Build and run the example

  - The C64 screen will show a new dot each second and the `/tmp/C64-RS232-output.txt` will get a new `A` character each second

