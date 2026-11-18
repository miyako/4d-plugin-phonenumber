![version](https://img.shields.io/badge/version-18%2B-EB8E5F)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-phonenumber)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-phonenumber/total)

**Note**: for v17 and earlier, move `manifest.json` to `Contents`

# 4d-plugin-phonenumber

4D implementation of [libphonenumber](https://github.com/googlei18n/libphonenumber) from Google. It runs entirely offline against the library's bundled metadata — no network access is needed.

macOS version: `8.12.21`
Windows version: `-` **TODO**: libraries update

**TODO**: native object support

## Features

Only the `PhoneNumberOfflineGeocoder` feature is available. It seems `PhoneNumberToCarrierMapper` and `PhoneNumberToTimeZonesMapper` are for Java only.

| Command | Returns | Purpose |
|---|---|---|
| [Parse phone number](#parse-phone-number) | `Text` (JSON) | Parse a phone number and return its formatted versions, type, and geographic description |

**Platforms:** macOS (universal: Intel and Apple silicon, macOS 11.5+) · Windows 64-bit (prebuilt binary)

---

## Requirements & platform notes

- **Two parameters are always read.** Pass `{}` as `params` when you don't need any options — an empty or non-JSON `params` string is silently ignored and the defaults are used.
- **Failure is silent, not a 4D error.** If the number cannot be parsed, the command returns an empty text — there is no error to catch. Check the result for `""` before parsing the JSON.
- **The result is pretty-printed JSON text**, not a 4D object. On 4D v20+, feed it to `JSON Parse` (check your Language Reference for the exact syntax on your version) to get an object; on earlier versions, parse the text yourself.
- **Windows ships a prebuilt binary** that is not rebuilt by the release workflow; its bundled libphonenumber version is older than the macOS build.

---

## Parse phone number

### Syntax

```4d
$json := Parse phone number ( $number ; $params )
```

### Parameters

| Parameter | Type | Description |
|---|---|---|
| `number` | `Text` | The phone number to process. May include formatting characters such as spaces, dashes, and parentheses. |
| `params` | `Text` | A JSON object string with optional settings (see below). Pass `{}` for defaults. |
| `Result` | `Text` | JSON text describing the parsed number, or `""` if parsing failed. |

`params` properties:

| Property | Type | Description |
|---|---|---|
| `default_region` | `string` | The region to assume when the number has no country code. Defaults to `"ZZ"` (unknown), which means numbers without a country code fail to parse unless this is set. |
| `language` | `string` | The language for the `description` and `descriptionForUserRegion` fields (an ICU locale language code, e.g. `"en"`, `"fr"`, `"de"`). |
| `region` | `string` | The region specifier paired with `language` (e.g. `"US"`, `"CA"`). Ignored unless `language` is also given. |
| `user_region` | `string` | The region the *user* is in. When set, `descriptionForUserRegion` is computed for that region (e.g. local formatting conventions); otherwise it equals `description`. |

### Description

Parses `number` with libphonenumber's offline geocoder and returns a JSON object with these fields:

| Property | Type | Description |
|---|---|---|
| `description` | `string` | Geographic description of the number's region, in the locale given by `language`/`region` (English by default). |
| `descriptionForUserRegion` | `string` | Description localized for `user_region`; identical to `description` when `user_region` is not set. |
| `phoneNumberType` | `string` | One of `FIXED_LINE`, `MOBILE`, `FIXED_LINE_OR_MOBILE`, `TOLL_FREE`, `PREMIUM_RATE`, `SHARED_COST`, `VOIP`, `PERSONAL_NUMBER`, `PAGER`, `UAN`, `VOICEMAIL`, `UNKNOWN`. |
| `INTERNATIONAL` | `string` | The number in international format, e.g. `+1 650-253-0000`. |
| `NATIONAL` | `string` | The number in national format for its region. |
| `RFC3966` | `string` | The number in RFC 3966 `tel:` URI format. |
| `E164` | `string` | The number in E.164 format, e.g. `+16502530000`. |

Unknown option keys in `params` are ignored.

### Example

```4d
$json := Parse phone number ( "+1 650-253-0000" ; {} )
// $json is JSON text; on 4D v20+:
// $obj := JSON Parse ( $json )
```

With options — parse a local-format number by assuming a region, and get descriptions in French:

```4d
$params := JSON Stringify ( New object( \
	"default_region" ; "US" ; \
	"language" ; "fr" ; \
	"region" ; "FR" ; \
	"user_region" ; "US" ) )
$json := Parse phone number ( "650-253-0000" ; $params )
```

Loop over a list of numbers and keep the ones that parse:

```4d
For each ( $number ; $numbers )
	If ( Parse phone number ( $number ; {} ) # "" )
		// parsed successfully
	End if
End for each
```

---

## Error handling & troubleshooting

- **Empty result means parse failure.** The command never raises a 4D error; an unparseable number (or one missing a country code with no usable `default_region`) returns `""`.
- **Bad `params` JSON is ignored.** If `params` isn't a valid JSON object, all defaults apply — `default_region` stays `"ZZ"`, so local-format numbers will fail unless they include a country code.
- **`region` without `language` does nothing.** The locale only changes when `language` is set; `region` alone is ignored.
- **Descriptions depend on the bundled metadata.** The offline geocoder's coverage and language data are fixed at build time (libphonenumber 8.12.21 on macOS); there is no way to update them without a plugin update.
- **Windows binary is stale.** The prebuilt Windows64 binary predates the current libphonenumber and is not covered by the macOS release pipeline — treat Windows results as best-effort.

---

## Quick reference

```4d
// Simplest call — international format number, defaults
$json := Parse phone number ( "+81 90-1234-5678" ; {} )

// Local number: must supply default_region
$json := Parse phone number ( "03-1234-5678" ; "{""default_region"":""JP""}" )

// Empty string = could not parse; always check first
If ( $json # "" )
	$obj := JSON Parse ( $json )  // v20+
	// $obj.E164, $obj.NATIONAL, $obj.phoneNumberType, $obj.description ...
End if
```
