# FOLIO scripts

## Disclaimer

Use these scripts with extreme caution! Once called and confirmed, records will be **retrieved**, **updated** or **deleted** in the given tenant. Updating and deleting is irreversible.

For detailled information about how to use a scripta, consider the README in each subdirectory.

## Use

The scripts require the jq utility to use. All assume you have the following files in the working directory:

- *tenant* -- name of the FOLIO tenant
- *okapi_url* -- Okapi URL for the tenant
- *oakpi_username* -- username for login
- *okapi_password* -- password relating to okapi_username
- *okapi_token* -- contains a valid Okapi token **(DEPRECATED)**

## Authors

- **Felix Hemme** - *Initial work* - [ZBW](https://zbw.eu/de/)

## License

This project is licensed under the Apache License - see the [LICENSE](LICENSE) file for details
