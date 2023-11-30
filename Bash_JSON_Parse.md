#### How to use bash script that parses json data from a file?

To parse JSON data in a bash script, you would typically use a command line tool such as 'jq'. `jq` is a command-line JSON processor. It's very powerful and easy to use for extracting data from JSON documents. Here is a basic script that would extract data from a JSON file:

```bash
#!/bin/bash
# My sample JSON file is named data.json, and I want to get the value of key named 'name'
JSON_FILE='data.json'
JSON_KEY='name'

DATA="$(jq -r ".$JSON_KEY" $JSON_FILE)"

echo $DATA
```

In this script, `jq` takes two arguments. The first argument (`-r ".$JSON_KEY"`) is a filter that tells `jq` what to do with the input it receives. The `".$JSON_KEY"` part of the filter will extract the value of JSON_KEY from the input JSON. The `-r` option tells `jq` to output raw strings instead of JSON-encoded strings.

The second argument is the name of the JSON file you want to parse. The values read from the JSON file is then stored in the `DATA` variable and then that data is printed out with `echo`.

To install `jq`, you can use package managers like `apt` for Ubuntu:

```bash
sudo apt-get install jq
```

Or `brew` for MacOS:

```bash
brew install jq
```

Note: JSON data and key are hypothetical and you would replace them with your actual JSON data and keys.

**Resource:**
- JQ documentation: https://stedolan.github.io/jq/manual/
