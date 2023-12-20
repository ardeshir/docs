#### Create a bash cli for common docker cli use case: 

- To improve the script and use the GNU command line parameters options library, we can make use of the getopt command. Here's an updated version of the script that incorporates this:

```bash

#!/bin/bash  
  
# Default values  
build=false  
tag=false  
run=false  
detach=false  
name=false  
stop=false  
  
# Parse command line options  
OPTS=$(getopt -o btrdns --long build,tag,run,detach,name,stop -- "$@")  
eval set -- "$OPTS"  
  
# Process command line options  
while true; do  
  case "$1" in  
    -b | --build )  
      build=true  
      shift  
      ;;  
    -t | --tag )  
      tag=true  
      shift  
      ;;  
    -r | --run )  
      run=true  
      shift  
      ;;  
    -d | --detach )  
      detach=true  
      shift  
      ;;  
    -n | --name )  
      name=true  
      shift  
      ;;  
    -s | --stop )  
      stop=true  
      shift  
      ;;  
    -- )  
      shift  
      break  
      ;;  
    * )  
      break  
      ;;  
  esac  
done  
  
# Execute actions based on options  
if $build; then  
  echo "building rust-server"  
  docker build --tag rust-server .  
fi  
  
if $tag; then  
  echo "tagging rust-server"  
  docker tag rust-server ardeshir/rust-server:v1.0.0  
fi  
  
if $run; then  
  if $detach; then  
    echo "running rust-server on 3001:8000 detached"  
    docker run -d -p 3001:8000 rust-server  
  else  
    echo "running rust-server on 3001:8000"  
    docker run -p 3001:8000 rust-server  
  fi  
fi  
  
if $name; then  
  echo "Naming & running rust-container detached"  
  docker run -d -p 3001:8000 --name rust-container rust-server  
fi  
  
if $stop; then  
  echo "stopping rust-server on 3001:8000"  
  docker stop rust-container  
else  
  echo "Running docker ps:"  
  docker ps -a  
fi  
```
 
Now you can pass command-line options to the script using either short options (e.g., -b, -t, -r, -d, -n, -s) or long options (e.g., --build, --tag, --run, --detach, --name, --stop), and the script will execute the corresponding actions based on the options provided. By default, all options are set to false, but when an option is specified on the command line, its corresponding variable is set to true.


