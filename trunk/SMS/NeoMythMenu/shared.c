// Shared data for all banks

#include "shared.h"


FileList games;
BYTE region;
BYTE keys,keysRepeat;

// For testing purposes
#ifdef EMULATOR
const char dummyGameList[] =
{
	0x00,0x02,0x41,0x00,0x00,0x00,0x0A,0x0B,
    '4', '0', '0', '1', ' ', 'R', '-', 'T',
    'Y', 'P', 'E', '.', 'S', 'M', 'S', ' ',
    ' ', ' ', ' ', ' ', ' ', ' ', ' ', 0,

	0x00,0x02,0x41,0x00,0x00,0x00,0x0A,0x0B,
    'A', 'l', 'e', 'x', ' ', 'K', 'i', 'd',
    'd', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
    ' ', ' ', ' ', ' ', ' ', ' ', ' ', 0,

	0x00,0x02,0x41,0x00,0x00,0x00,0x0A,0x0B,
    'S', 'o', 'n', 'i', 'c', ' ', '1', ' ',
    ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
    ' ', ' ', ' ', ' ', ' ', ' ', ' ', 0,

	0xFF,0x02,0x41,0x00,0x00,0x00,0x0A,0x0B,
    'A', 'l', 'e', 'x', ' ', 'K', 'i', 'd',
    'd', ' ', ' ', '.', ' ', ' ', ' ', ' ',
    ' ', ' ', ' ', ' ', ' ', ' ', ' ', 0
};

const BYTE *gbacGameList = (char*)&dummyGameList[0];
#else
const BYTE *gbacGameList = (const BYTE*)0xB000;
#endif


