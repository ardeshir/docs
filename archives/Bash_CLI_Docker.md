# Bash Docker Utility Script
 
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

#### updated to have $2 

- Updated script that incorporates the second $2 variable with default values for the -b and -t options, and a different default value for the --name option:

```bash
#!/bin/bash  
  
# Default values  
build=false  
build_name="rust-server"  
tag=false  
tag_name="rust-server"  
run=false  
detach=false  
name=false  
name_value="rust-container"  
stop=false  
  
# Parse command line options  
OPTS=$(getopt -o b:t:r:dns --long build:,tag:,run,detach,name:,stop -- "$@")  
eval set -- "$OPTS"  
  
# Process command line options  
while true; do  
  case "$1" in  
    -b | --build )  
      build=true  
      build_name="${2:-$build_name}"  
      shift 2  
      ;;  
    -t | --tag )  
      tag=true  
      tag_name="${2:-$tag_name}"  
      shift 2  
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
      name_value="${2:-$name_value}"  
      shift 2  
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
  echo "building $build_name"  
  docker build --tag "$build_name" .  
fi  
  
if $tag; then  
  echo "tagging $tag_name"  
  docker tag "$tag_name" "ardeshir/$tag_name:v1.0.0"  
fi  
  
if $run; then  
  if $detach; then  
    echo "running $build_name on 3001:8000 detached"  
    docker run -d -p 3001:8000 "$build_name"  
  else  
    echo "running $build_name on 3001:8000"  
    docker run -p 3001:8000 "$build_name"  
  fi  
fi  
  
if $name; then  
  echo "Naming & running $name_value detached"  
  docker run -d -p 3001:8000 --name "$name_value" "$build_name"  
fi  
  
if $stop; then  
  echo "stopping $build_name on 3001:8000"  
  docker stop "$name_value"  
else  
  echo "Running docker ps:"  
  docker ps -a  
fi  
```
 
-Now, when you use the -b or -t options, you can provide a second argument after the option to specify a different name. If no second argument is provided, the default name (rust-server) will be used. For the --name option, you can also provide a second argument to specify a different name, and if no second argument is provided, the default name (rust-container) will be used.


