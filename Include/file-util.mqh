/************************************************
* Utility functions for working with files.
*
* Author: Pritesh Mhatre
************************************************/

/**
* Default variables.
*/

static string CSV_SEPARATOR = ",";

static uint FILE_DEFAULT_WRITE_RETRY_COUNT = 50;

static uint FILE_DEFAULT_MAX_LINES_SAFETY_CHECK = 100000;

static int FILE_DEFAULT_READ_FLAGS = FILE_READ|FILE_SHARE_READ|FILE_COMMON|FILE_TXT;

static int FILE_DEFAULT_WRITE_FLAGS = FILE_READ|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_WRITE|FILE_COMMON|FILE_TXT;

static string WINDOWS_NEWLINE = "\r\n";

/**
* MetaTrader function to write a given line along with newline character. Returns True on successful write.
*/
bool fileWriteLineAdvanced( string filePath, int openFlags, uint retryCount, string line )
{

	bool result = false;
	string data;
	data = line + WINDOWS_NEWLINE;
	
	for(uint i = 0; i < retryCount; i++) {
		ResetLastError();
		int handle = FileOpen(filePath, openFlags);
		if(handle != INVALID_HANDLE) {
			FileSeek(handle,0,SEEK_END); 
			FileWriteString(handle, data, StringLen(data));
			FileFlush(handle);
			FileClose(handle);
			result = true;
			break;
		}

		if(i == (retryCount - 1)) {
			Print("Failed to send line to file: ", line);
		}
	}

	return result;
	
}

/**
* MetaTrader function to write a given line along with newline character. Returns True on successful write.
*/
bool fileWriteLine( string filePath, string line )
{	
	return fileWriteLineAdvanced( filePath, FILE_DEFAULT_WRITE_FLAGS, FILE_DEFAULT_WRITE_RETRY_COUNT, line);
}

/**
* MetaTrader function to read column value from a CSV file by identifying row by the given rowId. 
* Returns column value if found otherwise NULL.
*/
string fileReadCsvColumnByRowId( string filePath, string rowId, 
	uint rowIdColumnIndex, uint columnIndex ) {
	
	ushort uSep = StringGetCharacter(CSV_SEPARATOR, 0);     
	int handle = FileOpen(filePath, FILE_DEFAULT_READ_FLAGS);
	string result = NULL;

	if(handle != INVALID_HANDLE) {
		while(!FileIsEnding(handle)) {
			string line = FileReadString(handle);
			StringTrimRight(line);
			StringTrimLeft(line);
			if(line == "") {
				break;
			}

			string cols[];
			int splitCnt = StringSplit(line, uSep, cols);			
			if(splitCnt > 0 && 
				StringCompare(rowId, cols[rowIdColumnIndex - 1]) == 0) {
				result = cols[columnIndex - 1];
				break;
			}			
		}
		FileClose(handle);
	}

	return result;
	
}