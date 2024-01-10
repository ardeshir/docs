##### Create a bash script that will walk all the files inside a /data directory and replace all blank spaces in filenames with under scores "_" ? 

Here is a simple bash script to task of replacing blanks spaces in file names within /data directory with underscores:

```bash
#!/bin/bash

# Define the directory path
dir="/data/"

find "$dir" -type f -name "* *" |
while IFS= ' ' read -r file
do
    mv "$file" "${file// /_}"
done
```

Save this script in a file, give it execute permissions using `chmod +x filename.sh`, and run it with `./filename.sh`.

This script works as follows:

- `find "$dir" -type f -name "* *"`: This will find all files (-type f) in the given directory which have space in their names.

- `while IFS= ' ' read -r file`: This is the start of a loop that will execute the `mv` command for each file found by the `find` command. The IFS (Internal Field Separator) is set to a space here to properly handle the file names.

- `mv "$file" "${file// /_}"`: This is the command that actually renames the file. `"${file// /_}"` is a parameter expansion in bash, which replaces all spaces in the filename with underscores.

**NB**: It is important to be very careful when running a script like this, to avoid unintended data loss or corruption. Always make sure you have a backup of your data.
