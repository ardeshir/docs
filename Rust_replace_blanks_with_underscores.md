#### Create a Rust script that will walk all the files inside a /data directory and replace all blank spaces in filenames with under scores "_" ? 

Here's a simple Rust script that should do the job:

```rust
use std::fs;
use std::path::Path;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let path = Path::new("/data");
    if path.is_dir() {
        for entry in fs::read_dir(path)? {
            let entry = entry?;
            let old_path = entry.path();
            if old_path.is_file() {
                let old_name = old_path.file_name().ok_or("No filename")?;
                let old_name = old_name.to_string_lossy();
                if old_name.contains(' ') {
                    let new_name = old_name.replace(" ", "_");
                    let new_path = old_path.with_file_name(new_name);
                    fs::rename(old_path, new_path)?;
                }
            }
        }
    }
    Ok(())
}
```
This script runs through all the files in the `/data` directory. If it encounters a filename which has a space in it, it will replace that space with an underscore using the replace method of a string. After that, the file is renamed with the fs::rename function.

The std::error::Error type is created so that our function can return any kind of error, as long as it implements the standard Error trait.

This code will return a Result type, if anything unexpected happens (like a permission error), you will know about it.

*If you are running this script via Rust, please make sure you have the correct permissions to modify the /data directory.
