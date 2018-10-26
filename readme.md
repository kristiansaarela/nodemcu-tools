# nodemcu-tools

Difference scripts for NodeMCU

## specs

 - CPU: ESP8266
 - Memory: 128kB
 - Flash: 4MB

## installation

`yarn`

## using

Add `--port=COM5` to each command if not using `.nodemcutool` config file.

### find nodemcu port

Open device manager, see under PORTS

### initial file system

File system must be recreated after firmware update.

`nodemcu-tool mkfs`

### uploading files to nodemcu

`nodemcu-tool upload init.lua`

### run and view output

`nodemcu-tool terminal`

`dofile("index.lc")`
