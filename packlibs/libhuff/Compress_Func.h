#ifndef DLL_FUNC
#define DLL_FUNC __declspec(dllexport) 
#endif

#define DLL_NAME "KODI";
#define DLL_VERSION 1;

namespace CompressFunc
{
	DLL_FUNC int getname();
	DLL_FUNC int cdecl getver();
	DLL_FUNC void* cdecl compress (void* data, int size);
	DLL_FUNC int cdecl compsize ();
	DLL_FUNC void* cdecl decompress(void* data, int size, int outsize);
	DLL_FUNC int cdecl geterr();
	DLL_FUNC char* cdecl errstr();
}