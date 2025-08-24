# VMTRT
Vinnie's MT-32 ROM Tool

Thank you for coming across my MT-32 ROM tool!
VMTRT is a little Powershell script that lets you prepare your MT-32 ROM dumps for use with emulators like MUNT.

## How to dump MT-32 ROMs
For dummies

  *Note: These instructions were developed through trial & error as a first-timer. They are not definitive but they worked for me with an older-revision unit. I have not tried this with the newer model or any other Roland LA equipment.*

  (Roland R15449122, R15449123)

  I used an XGecu T48 with Xgpro v12.96.

  install Xgpro, plug in programmer.

  Getting the chips out without damaging the board is a NIGHTMARE. Please do it with extreme caution and use some Chip Quik alloy or something. I didn't and I wound up needing to install bodge wires. Putting the chips back in, put in sockets.

### For control ROMs:

  	Go to "Select IC(s)", search 27C256.

  	Select MICROCHIP -> 27C256 @DIP28.

### For PCM ROM:

  	Go to "Select IC(s)", search 27C040

  	Select ATMEL-> AT27C040 @DIP32.

### After either:

Uncheck "Check ID" & "Verify after"

Set VPP voltage to 12.5v (not sure if necessary)

Click the big "READ" button

Should read.

Check CRC/SHA1 hash.

Do for both Control ROMs.

  

## How to format ROMs

If you're using the script directly, you will need to enter this into PowerShell in order to use it:

````Set-ExecutionPolicy Unrestricted -Scope CurrentUser````

Run script, select "Combine ROMs"

Select mux0 (Control ROM 0, IC26, R15449122)

Select mux1 (Control ROM 1, IC27, R15449123)

Select desired output file.

Check hash.

## To 'compile' for Windows:
Get [PS12EXE](https://github.com/steve02081504/ps12exe).

I used the following command for creating the EXE:
````ps12exe C:\Path\VMTRT.ps1 -noConsole -resourceParams @{ iconFile = 'C:\Path\VMTRT.ico' }````
