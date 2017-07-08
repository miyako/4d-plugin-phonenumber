/* --------------------------------------------------------------------------------
 #
 #	4DPlugin.cpp
 #	source generated by 4D Plugin Wizard
 #	Project : phonenumber
 #	author : miyako
 #	2017/07/08
 #
 # --------------------------------------------------------------------------------*/


#include "4DPluginAPI.h"
#include "4DPlugin.h"

void PluginMain(PA_long32 selector, PA_PluginParameters params)
{
	try
	{
		PA_long32 pProcNum = selector;
		sLONG_PTR *pResult = (sLONG_PTR *)params->fResult;
		PackagePtr pParams = (PackagePtr)params->fParameters;

		CommandDispatcher(pProcNum, pResult, pParams); 
	}
	catch(...)
	{

	}
}

void CommandDispatcher (PA_long32 pProcNum, sLONG_PTR *pResult, PackagePtr pParams)
{
	switch(pProcNum)
	{
// --- Phone Number

		case 1 :
			Parse_phone_number(pResult, pParams);
			break;

	}
}

// --------------------------------- Phone Number ---------------------------------

using namespace std;

#pragma mark JSON

void json_wconv(const char *value, std::wstring &u32)
{
	if(value)
	{
		C_TEXT t;
		CUTF8String u8;
		
		u8 = (const uint8_t *)value;
		t.setUTF8String(&u8);
		
#if VERSIONWIN
		u32 = std::wstring((wchar_t *)t.getUTF16StringPtr());
#else
		
		uint32_t dataSize = (t.getUTF16Length() * sizeof(wchar_t))+ sizeof(wchar_t);
		std::vector<char> buf(dataSize);
		
		PA_ConvertCharsetToCharset((char *)t.getUTF16StringPtr(),
															 t.getUTF16Length() * sizeof(PA_Unichar),
															 eVTC_UTF_16,
															 (char *)&buf[0],
															 dataSize,
															 eVTC_UTF_32);
		
		u32 = std::wstring((wchar_t *)&buf[0]);
#endif
	}else
	{
		u32 = L"";
	}
	
}

void json_set_text_return(JSONNODE *n, sLONG_PTR* pResult)
{
	C_TEXT t;
	
	if(n)
	{
		json_char *json_string = json_write_formatted(n);
		
		std::wstring wstr = std::wstring(json_string);
		
#if VERSIONWIN
		t.setUTF16String((const PA_Unichar *)wstr.c_str(), (uint32_t)wstr.length());
#else
		uint32_t dataSize = (uint32_t)((wstr.length() * sizeof(wchar_t)) + sizeof(PA_Unichar));
		std::vector<char> buf(dataSize);
		
		uint32_t len = PA_ConvertCharsetToCharset((char *)wstr.c_str(),
																							(PA_long32)(wstr.length() * sizeof(wchar_t)),
																							eVTC_UTF_32,
																							(char *)&buf[0],
																							dataSize,
																							eVTC_UTF_16);
		
		t.setUTF16String((const PA_Unichar *)&buf[0], len);
#endif
		
		json_free(json_string);
	}
	t.setReturn(pResult);
}

JSONNODE *json_get_text_param(PackagePtr pParams, uint16_t index)
{
	C_TEXT t;
	t.fromParamAtIndex(pParams, index);
	
	wstring u32;
	
#if VERSIONWIN
	u32 = wstring((wchar_t *)t.getUTF16StringPtr());
#else
	
	uint32_t dataSize = (t.getUTF16Length() * sizeof(wchar_t))+ sizeof(wchar_t);
	vector<char> buf(dataSize);
	
	PA_ConvertCharsetToCharset((char *)t.getUTF16StringPtr(),
														 t.getUTF16Length() * sizeof(PA_Unichar),
														 eVTC_UTF_16,
														 (char *)&buf[0],
														 dataSize,
														 eVTC_UTF_32);
	
	u32 = wstring((wchar_t *)&buf[0]);
#endif
	return json_parse((json_const json_char *)u32.c_str());
}

void json_set_string_property(JSONNODE *n, const wchar_t *name, const char *value)
{
	if(n)
	{
		if(value)
		{
			wstring w32;
			json_wconv(value, w32);
			json_push_back(n, json_new_a(name, w32.c_str()));
		}else
		{
			JSONNODE *node = json_new_a(name, L"");
			json_nullify(node);
			json_push_back(n, node);
		}
	}
}
void json_set_string_property(JSONNODE *n, const wchar_t *name, string &value)
{
	if(n)
	{
		wstring w32;
		json_wconv(value.c_str(), w32);
		json_push_back(n, json_new_a(name, w32.c_str()));
	}
}

BOOL json_get_string_property(JSONNODE *json, const wchar_t *name, string &value)
{
	value = (const char*)"";
	
	if(json)
	{
		JSONNODE *node = json_get(json, name);
		if(node)
		{
			json_char *s =json_as_string(node);
			
			std::wstring wstr = std::wstring(s);
			
			C_TEXT t;
			
#if VERSIONWIN
			t.setUTF16String((const PA_Unichar *)wstr.c_str(), (uint32_t)wstr.length());
#else
			uint32_t dataSize = (uint32_t)((wstr.length() * sizeof(wchar_t)) + sizeof(PA_Unichar));
			std::vector<char> buf(dataSize);
			
			uint32_t len = PA_ConvertCharsetToCharset((char *)wstr.c_str(),
																								(PA_long32)(wstr.length() * sizeof(wchar_t)),
																								eVTC_UTF_32,
																								(char *)&buf[0],
																								dataSize,
																								eVTC_UTF_16);
			
			t.setUTF16String((const PA_Unichar *)&buf[0], len);
#endif
			CUTF8String _value;
			t.copyUTF8String(&_value);
			value = string((const char *)_value.c_str());//don't pass length, trin trailing nulls
			json_free(s);
		}
	}
	
	return !!value.length();
}

using namespace i18n::phonenumbers;

void get_text_param(PackagePtr pParams, uint16_t index, string &value)
{
	C_TEXT Param;
	Param.fromParamAtIndex(pParams, index);
	CUTF8String _value;
	Param.copyUTF8String(&_value);
	value = string((const char *)_value.c_str());//don't pass length, trin trailing nulls
}

void Parse_phone_number(sLONG_PTR *pResult, PackagePtr pParams)
{
	//instances
	PhoneNumberUtil *phoneUtil = PhoneNumberUtil::GetInstance();
	PhoneNumberOfflineGeocoder geocoder;
	//default params
	Locale locale = Locale::getEnglish();
	string user_region;
	string default_region = "ZZ";
	C_TEXT returnValue;
	
	string phonenumber;
	get_text_param(pParams, 1, phonenumber);
	JSONNODE *json = json_get_text_param(pParams, 2);
	
	if(json)
	{
		//custom locale
		string language, region;
		if(json_get_string_property(json, L"language", language))
		{
			if(json_get_string_property(json, L"region", region))
			{
				locale = Locale(language.c_str(), region.c_str());
			}else
			{
				locale = Locale(language.c_str());
			}
		}
		
		//custom user region
		json_get_string_property(json, L"user_region", user_region);

		//custom default region
		json_get_string_property(json, L"default_region", default_region);
		
		json_delete(json);
	}

	string description, description_local,
	formatted_number_INTERNATIONAL,
	formatted_number_NATIONAL,
	formatted_number_RFC3966,
	formatted_number_E164;
	
	PhoneNumberUtil::PhoneNumberType number_type;
	
	PhoneNumber phoneNumberProto;
	if(PhoneNumberUtil::NO_PARSING_ERROR == phoneUtil->Parse(phonenumber, default_region, &phoneNumberProto))
	{
		description = geocoder.GetDescriptionForNumber(phoneNumberProto, locale);
		
		if(user_region.length())
		{
			description_local = geocoder.GetDescriptionForNumber(phoneNumberProto, locale, user_region);
		}else
		{
			description_local = description;
		}
		
		phoneUtil->Format(phoneNumberProto,
											PhoneNumberUtil::INTERNATIONAL,
											&formatted_number_INTERNATIONAL);
		phoneUtil->Format(phoneNumberProto,
											PhoneNumberUtil::NATIONAL,
											&formatted_number_NATIONAL);
		phoneUtil->Format(phoneNumberProto,
											PhoneNumberUtil::RFC3966,
											&formatted_number_RFC3966);
		phoneUtil->Format(phoneNumberProto,
											PhoneNumberUtil::E164,
											&formatted_number_E164);
		
		number_type = phoneUtil->GetNumberType(phoneNumberProto);
		
		JSONNODE *info = json_new(JSON_NODE);

		json_set_string_property(info, L"description", description);
		json_set_string_property(info, L"descriptionForUserRegion", description_local);

		
		switch (number_type)
		{
			case PhoneNumberUtil::PhoneNumberType::FIXED_LINE:
				json_set_string_property(info, L"phoneNumberType", "FIXED_LINE");
    break;
			case PhoneNumberUtil::PhoneNumberType::MOBILE:
				json_set_string_property(info, L"phoneNumberType", "MOBILE");
    break;
			case PhoneNumberUtil::PhoneNumberType::FIXED_LINE_OR_MOBILE:
				json_set_string_property(info, L"phoneNumberType", "FIXED_LINE_OR_MOBILE");
    break;
			case PhoneNumberUtil::PhoneNumberType::TOLL_FREE:
				json_set_string_property(info, L"phoneNumberType", "TOLL_FREE");
    break;
			case PhoneNumberUtil::PhoneNumberType::PREMIUM_RATE:
				json_set_string_property(info, L"phoneNumberType", "PREMIUM_RATE");
    break;
			case PhoneNumberUtil::PhoneNumberType::SHARED_COST:
				json_set_string_property(info, L"phoneNumberType", "SHARED_COST");
    break;
			case PhoneNumberUtil::PhoneNumberType::VOIP:
				json_set_string_property(info, L"phoneNumberType", "VOIP");
    break;
			case PhoneNumberUtil::PhoneNumberType::PERSONAL_NUMBER:
				json_set_string_property(info, L"phoneNumberType", "PERSONAL_NUMBER");
    break;
			case PhoneNumberUtil::PhoneNumberType::PAGER:
				json_set_string_property(info, L"phoneNumberType", "PAGER");
    break;
			case PhoneNumberUtil::PhoneNumberType::UAN:
				json_set_string_property(info, L"phoneNumberType", "UAN");
    break;
			case PhoneNumberUtil::PhoneNumberType::VOICEMAIL:
				json_set_string_property(info, L"phoneNumberType", "VOICEMAIL");
    break;
			default://UNKNOWN
				json_set_string_property(info, L"phoneNumberType", "UNKNOWN");
    break;
		}
		
		json_set_string_property(info, L"INTERNATIONAL", formatted_number_INTERNATIONAL);
		json_set_string_property(info, L"NATIONAL", formatted_number_NATIONAL);
		json_set_string_property(info, L"RFC3966", formatted_number_RFC3966);
		json_set_string_property(info, L"E164", formatted_number_E164);
		json_set_text_return(info, pResult);
		json_delete(info);
	}else
	{
		//parse error
	}
}

