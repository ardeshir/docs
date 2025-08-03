#### Create a Perl script that will walk all the files inside a /data directory and replace all blank spaces in filenames with under scores "_" ?

Sure, you can use a Perl script with the File::Find module to traverse through the directory, and the rename function to replace all blank spaces in filenames with underscores.

Here is an example Perl script:

```perl
#!/usr/local/bin/perl
use strict;
use warnings;
use File::Find;

find(\&wanted, '/data');

sub wanted {
    return unless -f; # only operate on files
    my $old_name = $_;
    my $new_name = $old_name =~ s/ /_/gr; # replace blank spaces with underscores

    if($new_name ne $old_name) {
        # Using ${File::Find::dir} gets the current directory find is at
        rename("$File::Find::dir/$old_name", "$File::Find::dir/$new_name") or warn $!;
    }
}
```
This script will recursively find and rename files in /data and its subdirectories. Any error in renaming (e.g., due to permissions) will generate a warning rather than stopping execution.

Please remember to back up your data before trying this script, in case something goes wrong.

Also, note that this Perl script has to be run as a user with appropriate permissions for read/write to the `/data` directory and its files.

Reference (File::Find documentation): https://perldoc.perl.org/File/Find

Before running the code, don't forget to check the file permissions.

### Connect: Join Univrs.io
- [Univrs.io Discord](https://discord.gg/pXwH6rQcsS)
- [Univrs Patreon](https://wwww.patreon.com/univrs)
- [Univrs.io](https://univrs.io)
- [https://ardeshir.io](https://ardeshir.io)
- [https://hachyderm.io/@sepahsalar](https://hachyderm.io/@sepahsalar)
- [https://github.com/ardeshir](https://github.com/ardeshir)
- [https://medium.com/@sepahsalar](https://medium.com/@sepahsalar)
- [https://www.linkedin.com/in/ardeshir](https://www.linkedin.com/in/ardeshir)
- [https://sepahsalar.substack.com/](https://sepahsalar.substack.com/)
- [LinkTree @Sepahsalar](https://linktr.ee/Sepahsalar) 
- [Univrs MetaLabel](https://univrs.metalabel.com)