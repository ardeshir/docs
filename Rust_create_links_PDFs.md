#### This Rust program does the same job as the C# and C++ programs: it scans the "./data" directory for PDF files, sorts them in alphabetical order, generates an HTML file with links to each PDF file, and writes the HTML content to the "index.html" file.

The fs::read_dir function is used to iterate over the files in the directory. The filename and its extension are retrieved using the fs::DirEntry::file_name and path::Path::extension methods, respectively.

The Vec::sort method is used to sort the filenames in alphabetical order. Then, the program opens the output file with fs::File::create and writes the HTML content to it using the writeln! macro.

Please note that this code uses the ? operator to handle errors. If an error occurs, the program will terminate and print the error message. If you want more sophisticated error handling, you'll need to replace the ? operator with appropriate error handling code.

```rust
use std::fs;
use std::io::Write;
use std::path::Path;

fn main() -> std::io::Result<()> {
    let dir_path = "./data";
    let output_path = "./index.html";

    // Check if the directory exists
    if !Path::new(dir_path).exists() {
        println!("Directory '{}' does not exist.", dir_path);
        return Ok(());
    }

    // Get pdf files
    let mut pdf_files: Vec<_> = fs::read_dir(dir_path)?
        .filter_map(Result::ok)
        .filter(|e| e.path().extension().unwrap_or_default() == "pdf")
        .map(|e| e.file_name().into_string().unwrap())
        .collect();

    // Sort the file names in alphabetical order
    pdf_files.sort();

    let mut file = fs::File::create(output_path)?;

    writeln!(file, "<html><title> PDF files</title>")?;
    writeln!(file, "<body>")?;
    writeln!(file, "<h1>List of ebooks</h1>")?;
    writeln!(file, "<ul>")?;

    // Create a list item for each pdf file
    for pdf_file in pdf_files {
        let file_name = pdf_file;
        let link_text = file_name.replace("_", " "); // Replace underscores with spaces
        writeln!(file, "<li><a href=\"{}\">{}</a></li>", file_name, link_text)?;
    }

    writeln!(file, "</ul>")?;
    writeln!(file, "</body>")?;
    writeln!(file, "</html>")?;

    println!("index.html has been created.");

    Ok(())
}


```

### [Connect: Join Univrs.io Discord](https://discord.gg/pXwH6rQcsS)
- [Univrs Patreon](https://wwww.patreon.com/univrs)
- [Univrs.io](https://univrs.io)
- [https://ardeshir.io](https://ardeshir.io)
- [https://hachyderm.io/@sepahsalar](https://hachyderm.io/@sepahsalar)
- [https://github.com/ardeshir](https://github.com/ardeshir)
- [https://medium.com/@sepahsalar](https://medium.com/@sepahsalar)
- [https://www.linkedin.com/in/ardeshir](https://www.linkedin.com/in/ardeshir)
- [https://sepahsalar.substack.com/](https://sepahsalar.substack.com/)
- [LinkTree @Sepahsalar](https://linktr.ee/Sepahsalar) 
- [Univrs MetaLabel](https://unvirs.metalabel.com)