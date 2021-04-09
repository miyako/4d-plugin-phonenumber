![version](https://img.shields.io/badge/version-18%2B-EB8E5F)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-phonenumber)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-phonenumber/total)

**Note**: for v17 and earlier, move `manifest.json` to `Contents`

# 4d-plugin-phonenumber
4D implementation of [libphonenumber](https://github.com/googlei18n/libphonenumber) from Google

macOS version: `8.12.21`
Windows version: `-` **TODO**: libraries update 

**TODO**: native object support

## Features

Only the ``PhoneNumberOfflineGeocoder`` feature is available. It seems ``PhoneNumberToCarrierMapper`` and ``PhoneNumberToTimeZonesMapper`` are for Java only. 

## Syntax

```
json:=Parse phone number (number{;params})
```

Parameter|Type|Description
------------|------------|----
number|TEXT|The phone number to process
params|TEXT|Options
json|TEXT|Parsed result

* Properties for ``params``

``default_region``: ``string`` The region to assume in case the country code is missing

``language``: ``string`` The locale for the result ``description`` and ``descriptionForUserRegion``

``region``: ``string`` Specifier for ``language``

``user_region``: ``string`` The region for the result. For example, some formatting may be abbreviated for numbers in the same region

### Examples

<img width="767" alt="2017-07-08 19 30 50" src="https://user-images.githubusercontent.com/1725068/27984649-60acdadc-6416-11e7-9b56-f74e1b1b804a.png">
