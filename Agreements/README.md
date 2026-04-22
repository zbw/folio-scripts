# FOLIO Agreements scripts

## Disclaimer

Use the update scripts with extreme caution! Once called and confirmed, all records listed in the input file, will be **updated** in the given tenant.

## Retrieve records

You can currently retrieve the following record types:

- All agreements with `retrieve_all_agreements.sh`
- All agreement lines with `retrieve_all_agreement_lines.sh`

If you have a list of titleInstance identifiers, you can retrieve the matching records from the local KB. Currently ZDB-ID and e-ISBN are supported by the scripts `retrieve_titleInstance_uuid_by_zdbid.sh` or `retrieve_titleInstance_uuid_by_eisbn.sh`.

---
**NOTE**

In case you already have a list of titleInstance UUID's you want to update, this step can be skipped. Otherwise, proceed as follows.

---

1. Open the Agreements app and find the agreement where the package that contains the titleInstance is connected as agreement line. Copy the agreements UUID (e.g. from the URL).
2. Create a file containing the resource identifiers of the titleInstances. Currently ZDB-ID and e-ISBN are supported by these scripts.
3. The agreement and its content of e-resources can then be further processed with invoking either the script `retrieve_titleInstance_uuid_by_zdbid.sh` or `retrieve_titleInstance_uuid_by_eisbn.sh`, which downloads the agreement and all connected e-resources in JSON format, matches e-resources by ZDB-ID's or e-ISBN's provided in the external file and saves the result in an output file. Run it by calling

    ```console
    ./retrieve_titleInstance_uuid_by_zdbid.sh <agreement UUID> <file with ZDB-ID's>
    # or
    ./retrieve_titleInstance_uuid_by_eisbn.sh <agreement UUID> <file with e-ISBN's>
    ```

4. After the script ran successfully, it will move a bunch of temporary files into a subdirectory `data`. You can delete those files if you don't wanna keep them for historical reasons.
5. The script will move the file containing the titleInstance UUID's into a subdirectory `uuid`. You need this file for the next step.

## Update records

### Update agreements

#### Search and replace values in .supplementaryDocs[].location field

1. Run `retrieve_all_agreements.sh` to fetch all agreements. A JSON file with the full records is stored in the`data` subdirectory.
2. Edit `update_agreements_search_replace_value.sh` and enter the existing text that should be replaced into the variable `search` and the new replacement text into the variable `replace`. The text will be replaced while remaining in its current field.
3. Now run the update script and confirm the update.


#### Search and replace values in .supplementaryDocs[].location field and move the value from location to url

1. Run `retrieve_all_agreements.sh` to fetch all agreements. A JSON file with the full records is stored in the`data` subdirectory.
2. Edit `update_agreements_search_replace_value_move_suppDocsLocation_to_suppDocsUrl.sh` and enter the existing text that should be replaced into the variable `search` and the new replacement text into the variable `replace`. The text will be replaced and copied from location into url.
2. Now run the update script and confirm the update.

#### Search and replace values in .supplementaryDocs[].url field and move the value from url to location

1. Run `retrieve_all_agreements.sh` to fetch all agreements. A JSON file with the full records is stored in the`data` subdirectory.
2. Edit `update_agreements_search_replace_value_move_suppDocsUrl_to_suppDocsLocation.sh` and enter the existing text that should be replaced into the variable `search` and the new replacement text into the variable `replace`. The text will be replaced and copied from location into url.
3. Now run the update script and confirm the update.

### Update titleInstances

#### Change the value of suppressFromDiscovery

1. You have to specify if you want to set the `suppressFromDiscovery` flag to `true/false` respectively. Just modify the variable `suppress_switch` in the [update_titleInstances_suppressFromDiscovery_by_uuid.sh](update_titleInstances_suppressFromDiscovery_by_uuid.sh) update script.
2. You can send a PUT with the UUID's to `/erm/titles` by calling

    ```console
    ./update_titleInstance_suppressFromDiscovery_by_uuid.sh <file with titleInstance UUID's>
    ```

3. You have to confirm the update before the request is being processed. The process is logged and the logs are written into a subdirectory `log_updated_records`. It contains the JSON respone containing the updated values.

### Update packages

#### Change the value of syncContentsFromSource

1. Run `retrieve_all_agreement_lines.sh` to fetch all agreement lines. A JSON file with the full records is stored in the`data` subdirectory.
2. To update the `syncContentsFromSource` field in all packages to `true/false` respectively, run `update_packages_syncContentsFromSource.sh` by calling

    ```console
    ./update_packages_syncContentsFromSource.sh <file with agreement lines>
    ```

3. The script will filter the agreement lines by `.resource.class == "org.olf.kb.Pkg"` and extract their UUID's. These UUID's are then send to the `/erm/packages/controlSync` API. Adjust the value of the `sync_state` variable depening on your use case.
