# 4d-plugin-phonenumber
4D implementation of [libphonenumber](https://github.com/googlei18n/libphonenumber) from Google

## Features

Only the ``PhoneNumberOfflineGeocoder`` feature is available. It seems ``PhoneNumberToCarrierMapper`` and ``PhoneNumberToTimeZonesMapper`` are for Java only. 

### Platform

| carbon | cocoa | win32 | win64 |
|:------:|:-----:|:---------:|:---------:|
|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|||

### Version

<img src="https://cloud.githubusercontent.com/assets/1725068/18940649/21945000-8645-11e6-86ed-4a0f800e5a73.png" width="32" height="32" /> <img src="https://cloud.githubusercontent.com/assets/1725068/18940648/2192ddba-8645-11e6-864d-6d5692d55717.png" width="32" height="32" />

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

``language``: ``string`` The locale for the result `description`` and ``descriptionForUserRegion``

``region``: ``string`` Specifier for ``language``

``user_region``: ``string`` The region for the result. For example, some formatting may be abbreviated for numbers in the same region
