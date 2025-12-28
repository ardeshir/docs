### If os.path.exists(file) Check 

You can achieve this using the `os` module in Python which provides functions for interacting with the operating system. The `os.path.exists()` function is used to check if a file or directory exists.

Here is the code:

```python
import os

if os.path.exists('latest.md'):
    append_to_file()
else:
    write_to_file()
```

This code checks if a file named 'latest.md' exists in the same directory as your script. If it does exist, it calls the `append_to_file()` function. If it does not exist, it calls the `write_to_file()` function.

Note: This assumes that `append_to_file()` and `write_to_file()` are defined somewhere in your code.

For example:

```python
def append_to_file():
    with open('latest.md', 'a') as file:
        file.write('Appending some data')

def write_to_file():
    with open('latest.md', 'w') as file:
        file.write('Writing some data')
```

In the `append_to_file()` function, the 'a' parameter in the open() function opens the file in append mode, and in the `write_to_file()` function, the 'w' parameter opens the file in write mode.
