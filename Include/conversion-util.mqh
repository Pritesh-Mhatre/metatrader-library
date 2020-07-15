/************************************************
* Utility functions data conversion.
*
* Author: Pritesh Mhatre
************************************************/

template<typename T>
T StringToEnum(string str,T enu) {
	for(int i=0; i<256; i++) {
		if(EnumToString(enu=(T)i) == str)
			return (enu);
	}
	
	return (-1);
}

/*
* Converts a given datetime object into milliseconds since epoch.
*/
long convertDateTimeToMillisSinceEpoch(datetime time) {
   long millis = time * 1000;
	return millis;
}
