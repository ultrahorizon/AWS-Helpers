# AWS-Helpers
Repository for AWS Helper Programs/Scripts under the MIT License.

## SMTP Credentials Converter

Within the current directory of the `smtp_converter.sh` file, perform the following actions in a shell:
```sh
$> export AWS_SECRET_ACCESS_KEY="<IAM user's secret access key>"
$> chmod +x ./smtp_converter.sh
$> ./smtp_converter.sh
```
The output string can then be used as a password for SES SMTP credentials.
