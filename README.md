You can either run this file as a script or require the module in your own scripts. Change the 
SERVER_IP and SERVER_PORT according to your configuration. 

Running as a script (no arguments) puts your terminal in a limited REPL where you can supply 
commands to controll the receiver. Type "help" "h" or "?" to see the full list. If the first 
character you type is a "!", everything following it will be eval'ed as ruby code and the return 
value of eval will be printed. 

Currently only a very small subset of ISCP commands are implemented (I don't really need the rest). 
It would be trivial to add any command you find useful. You only need to edit the COMMANDS hash 
and make the OnkyoClient#update method aware of what the receiver would send back as an answer.
