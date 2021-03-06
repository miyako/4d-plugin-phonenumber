/* --------------------------------------------------------------------------------
 #
 #	4DPlugin.h
 #	source generated by 4D Plugin Wizard
 #	Project : phonenumber
 #	author : miyako
 #	2017/07/08
 #
 # --------------------------------------------------------------------------------*/

#include "4DPluginAPI.h"

#include "phonenumbers/phonenumberutil.h"
#include "phonenumbers/geocoding/phonenumber_offline_geocoder.h"

#define USE_JSONCPP 1

#if USE_JSONCPP
#include "json/json.h"
void convertFromString(std::string &fromString, CUTF16String &toString);
#endif

// --- Phone Number
void Parse_phone_number(sLONG_PTR *pResult, PackagePtr pParams);
