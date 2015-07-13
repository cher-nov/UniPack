#include "stdafx.h"
#include "Compress_Func.h"
#include <vector>

using namespace std;

struct node
{
	node* next;
	int key;
};

node* new_node(int key)
{
	node temp; temp.key = key; temp.next = NULL;
	return &temp;
}

int compare(const void * x1, const void * x2) 
{
	return (*(int*)x1 - *(int*)x2);    
}

namespace CompressFunc
{
	int getname()
	{
		return (int)DLL_NAME;
	}
	int cdecl getver()
	{
		return DLL_VERSION;
	}
	void* cdecl compress(void* data, int size)
	{
		vector<int>td_freq(256);
		for (int i = 0; i < size; i++)
		{
			td_freq[(int)(((char*)data)[i])]++;
		}
		qsort(&td_freq, 256, sizeof(int), compare);
		node* tree;
		return NULL;
	}
	int cdecl compsize()
	{
		return 0;
	}
	void* cdecl decompress(void* data, int size, int outsize)
	{
		return NULL;
	}
	int cdecl geterr()
	{
		return 0;
	}
	char* cdecl errstr()
	{
		return 0;
	}
}

