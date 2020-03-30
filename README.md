covid19 phone app
--------------------

This is the reference app for the [covid19 shared datastore](https://github.com/covid19database/covid19db-api/).

Installing
---
We are using the ionic v3.19.1 platform, which is a toolchain on top of the apache
cordova project. So the first step is to install ionic using their instructions.
http://ionicframework.com/docs/v1/getting-started/

NOTE: Since we are still on ionic v1, please do not install v2 or v3, as the current codebase will not work with it.
Issue the following commands to install Cordova and Ionic instead of the ones provided in the instruction above.

```
$ npm install -g cordova@8.0.0
$ npm install -g ionic@3.19.1
```

Install gradle (https://gradle.org/install/) for android builds.

Then, get the current version of our code

Setup the config

```
$ ./bin/configure_xml_and_json.js cordovabuild
```

Install all javascript components using bower

```
$ bower update
```

Make sure to install the other node modules required for the setup scripts.

```
npm install
```

Create a remote to pull updates from upstream

```
$ git remote add upstream https://github.com/e-mission/e-mission-phone.git
```

Setup cocoapods. For all versions > 1.9, we need https://cocoapods.org/ support. This is used by the push plugin for the GCM pod, and by the auth plugin to install the GTMOAuth framework. This is a good time to get a cup of your favourite beverage.

```
$ sudo gem install cocoapods
$ pod setup
```

To debug the cocoapods install, or make it less resource intensive, check out troubleshooting guide for the push plugin.
https://github.com/phonegap/phonegap-plugin-push/blob/master/docs/INSTALLATION.md#cocoapods

**Note about cocoapods 1.9, there seems to be an issue which breaks ```pod setup```:** 
https://github.com/flutter/flutter/issues/41253
1.75 seems to work: ```sudo gem install cocoapods -v 1.7.5```

Configure values if necessary - e.g.

Restore cordova platforms and plugins

```
$ cordova prepare
```

**Note:** Sometimes, the `$ cordova prepare` command fails because of errors while cloning plugins (`Failed to restore plugin "..." from config.xml.`). A workaround is at https://github.com/e-mission/e-mission-docs/blob/master/docs/overview/high_level_faq.md#i-get-an-error-while-adding-plugins

**Note #2:** After the update to the plugins to support api 26, for this repository **only** the first call `$ cordova prepare` fails with the error

    Using cordova-fetch for cordova-android@^6.4.0
    Error: Platform ios already added.
The workaround is to re-run `$cordova prepare`. This not required in the https://github.com/e-mission/e-mission-base repo although the config.xml seems to be the same for both repositories.

    $ cordova prepare
    Discovered platform "android@^6.4.0" in config.xml or package.json. Adding it to the project
    Using cordova-fetch for cordova-android@^6.4.0
    Adding android project...
    Creating Cordova project for the Android platform:
        Path: platforms/android
        Package: edu.berkeley.eecs.emission
        Name: emission
        Activity: MainActivity
        Android target: android-26


Installation is now complete. You can view the current state of the application in the emulator

    $ cordova emulate ios

    OR

    $ cordova emulate android

The android build and emulator have improved significantly in the last release
of Android Studio (3.0.1).  The build is significantly faster than iOS, the
emulator is just as snappy, and the debugger is better since chrome saves logs
from startup, so you don't have to use tricks like adding alerts to see errors
in startup.

**Note about Xcode >=10** The cordova build doesn't work super smoothly for iOS anymore. Concretely, you need two additional steps:
- install pods manually. Otherwise you will get a linker error for `-lAppAuth`
    ```
        $ cd platform/ios
        $ pod install
        $ cd ../..
    ```

- when you recompile, you will get the following compile error. The workaround is to compile from xcode. I have filed an issue for this (https://github.com/apache/cordova-ios/issues/550) but there have been no recent updates.

    ```
    /Users/shankari/e-mission/e-mission-phone/platforms/ios/Pods/JWT/Classes/Supplement/JWTBase64Coder.m:22:9: fatal error:
          'Base64/MF_Base64Additions.h' file not found
    #import <Base64/MF_Base64Additions.h>
            ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    1 error generated.
    ```

- Also, on Mojave, we have reports that [you may need to manually enable the Legacy Build system in Xcode if you want to run the app on a real device](https://stackoverflow.com/a/52528662/4040267).

Debugging
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
