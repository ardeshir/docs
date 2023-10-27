##### Q: How do I use the Azure az cli to download from AzureDevOps Universal Artifacts a zip packake to my local machine?

A: To download a zip package from Azure DevOps Universal Artifacts using the Azure CLI, you can use the following command:

```bash
az artifacts universal download --feed <feed-name> --name <artifact-name> --version <artifact-version> --path <local-path-to-download>
```

Replace the placeholders with the required values:

- `<feed-name>`: Replace it with the name of the feed where the artifact is published.
- `<artifact-name>`: Replace it with the name of the artifact you want to download.
- `<artifact-version>`: Replace it with the version of the artifact you want to download.
- `<local-path-to-download>`: Replace it with the local path where you want to save the downloaded zip package. 

Here's an example:

```bash
az artifacts universal download --feed my-feed --name my-artifact --version 1.0.0 --path ./download-folder/
```

Make sure you have the Azure CLI installed and logged in before running this command.
