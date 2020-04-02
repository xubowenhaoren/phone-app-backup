covid19 phone app
--------------------

This is the reference app for the [covid19 shared datastore](https://github.com/covid19database/covid19db-api/).

Pre-requisites
---
- the version of xcode used by the CI
    - to install a particular version, use [xcode-select](https://www.unix.com/man-page/OSX/1/xcode-select/)
    - or this [supposedly easier to use repo](https://github.com/xcpretty/xcode-install)
- git
- the most recent version of android studio

Important
---
Most of the recent issues encountered have been due to incompatible setup. We
have now:
- locked down the dependencies,
- created setup and teardown scripts to setup self-contained environments with
  those dependencies, and
- CI enabled to validate that they continue work.

If you have setup failures, please compare the configuration in the passing CI
builds with your configuration. That is almost certainly the source of the error.

Installing
---
Run the setup script for the platform you want to build

```
$ source setup/setup_android_native.sh
AND/OR
$ source setup/setup_ios_native.sh
```

Run in the emulator

```
$ npx cordova emulate ios
AND/OR
$ npx cordova emulate android
```

Troubleshooting
---
- Make sure to use `npx ionic` and `npx cordova`. This is
  because the setup script installs all the modules locally in a self-contained
  environment using `npm install` and not `npm install -g`
- Check the CI to see whether there is a known issue
- Run the commands from the script one by one and see which fails
    - compare the failed command with the CI logs
- Another workaround is to delete the local environment and recreate it
    - javascript errors: `rm -rf node_modules && npm install`
    - native code compile errors: `rm -rf plugins && rm -rf platforms && npx cordova prepare`

Create a remote to pull updates from upstream

Beta-testing debugging
---
If users run into problems, they have the ability to email logs to the
maintainer. These logs are in the form of an sqlite3 database, so they have to
be opened using `sqlite3`. Alternatively, you can export it to a csv with
dates using the `bin/csv_export_add_date.py` script.

```
<download the log file>
$ mv ~/Downloads/loggerDB /tmp/logger.<issue>
$ pwd
.../e-mission-phone
$ python bin/csv_export_add_date.py /tmp/loggerDB.<issue>
$ less /tmp/loggerDB.<issue>.withdate.log
```
