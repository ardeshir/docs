# How to send a file to local curl 

To use `curl` to send a `temp.json` file to a local HTTPS endpoint, you can use the following command:

```sh
curl -X POST --data @temp.json -H "Content-Type: application/json" https://localhost:8080/glopar/v2
```

Here's a breakdown of each part of the command:

1. `curl`: This is the command-line tool for transferring data with URLs.
2. `-X POST`: This specifies that you want to send a POST request.
3. `--data @temp.json`: This tells `curl` to send the contents of the `temp.json` file as the data for the POST request. The `@` symbol indicates that `curl` should read the data from a file.
4. `-H "Content-Type: application/json"`: This sets the `Content-Type` header to `application/json` to indicate that the data being sent is in JSON format.
5. `https://localhost:8080/glopar/v2`: This is the URL of the endpoint to which you're sending the request.

If `localhost` is using a self-signed SSL certificate, `curl` might complain about the certificate's security. To bypass security checks (not recommended for production environments), you can add the `-k` or `--insecure` option:

```sh
curl -k -X POST --data @temp.json -H "Content-Type: application/json" https://localhost:8080/glopar/v2
```

For more details on `curl` usage, you can refer to the official [curl documentation](https://curl.se/docs/manpage.html).

> **Note**: Bypassing SSL verification with `-k` is unsafe for production use because it makes your connection vulnerable to Man-in-the-Middle (MitM) attacks. Always ensure proper SSL configuration in production environments.
