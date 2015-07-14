/*
 HUFF.H
 (c) KoDi studio, 2015
 */

#include "huff.h"
#include <memory.h>
#include <stdlib.h>
#include <stdio.h>
#include <bitset>
#include <malloc.h>

struct symb
{
	int code, freq;
};

struct res_symb
{
	int count;
	int code;
};

struct code_symb
{
	int code;
	int code2;
	int count;
};

struct node
{
	node* left;
	node* right;
	int freq;
	int code;
};

struct on_node
{
	node* child; int fsi;
};

FILE* inf;
FILE* outf;
code_symb* res;
res_symb* res_table;
int curr_i;
int temp_d[32];
code_symb* itog_arr;
char* buf;
int n;

void quick_sort(int l, int r, symb* tb);
void quick_sort_(int l, int r, on_node* tb);
node* create_tree(symb tb[256], int n);
node* nodes_glued(int a, int b, on_node* t);
void create_code_symb(node* t, int a, int c);
void input_res(int* m, int c);
void create_itog_code();
void quick_sort_itog(int l, int r, code_symb* tb);
void to_record_data(int size_buf);


int lib_error = E_OK;
int lib_compsize = 0;

/* initialization functions */

int get_name()  {
    return DLL_NAME;
}

int get_version()  {
    return DLL_VERSION;
}

/* compress functions */

void* compress(void* data, int size_data)  {
    /* check errors */
    if (data == NULL)  {
        lib_error = E_BAD_INPUT;
        return NULL;
    }
    if (lib_compsize != 0) {
        lib_error = E_LOST_SIZE;
        return NULL;
    }
    
    /* compress alogorithm Huffman by Dima */
	symb table[256]{ 0, 0 };
	int table_freq[256]{ 0 };
	unsigned char t;
	int x = 0;
	while (x < size_data)
	{
		t = (unsigned char)((*data)[x]);
		x++;
		table[(int)t].freq++;
		table[(int)t].code = (int)t;
		table_freq[(int)t]++;
	}
	quick_sort(0, 255, table);
	n = 0;
	for (int i = 0; i < 256; i++)
	{
		if (table[i].freq != 0) n++;
	}
	node* tree = create_tree(table, n);
	res = (code_symb*)malloc(n*sizeof(code_symb));
	curr_i = 0;
	create_code_symb(tree[0].left, 0, 1);
	create_code_symb(tree[0].right, 1, 1);
	itog_arr = (code_symb*)malloc(n*sizeof(code_symb));
	create_itog_code();
	int g = 0;
	for (int i = 0; i < 256; i++)
	{
		if (res_table[i].count > 0)
		{
			g += table_freq[i] * res_table[i].count;
		}
	}
	g = (g + 8 - g % 8) / 8;
	buf = (char*)malloc((g)*sizeof(char) + 256 * sizeof(char));

	//output data
	for (int i = 0; i < 256; i++)
	{
		buf[i] = res_table[i].count;
	}
	to_record_data(size_data);
    /* code here */
    lib_compsize = size_data;
    return *buf;
}

void* decompress(void* data, int size_data, int out_size)  {
    /*check errors */
    if (data == NULL)  {
        lib_error = E_BAD_INPUT;
        return NULL;
    }
    
    /* decompress algorithm Huffman by Dima */
    
    /* code here */
    
    return 0;
    
}


void to_record_data(int size_buf)/
{
	char ct = 0;
	int cx = 0;
	char a = 99;
	int curr_i = 0;
	int curr_bit = 0; int curr_byte = 257;
	unsigned char t = 0;
	buf[curr_byte - 1] = 0;
	while (cx < size_buf)
	{
		t = (unsigned char)((*data)[cx]);
		cx++;
		int j = (int)t;
		ct = res_table[j].code;
		curr_i = res_table[j].count - 1;
		while (curr_i >= 0)
		{
			if (curr_bit > 7)
			{
				curr_byte++;
				buf[curr_byte - 1] = 0;
				curr_bit = 0;
			}
			else
			{
				if (bitset<1>(ct >> curr_i) == 1) buf[curr_byte - 1] |= 1 << curr_bit;
				else buf[curr_byte - 1] |= 0 << curr_bit;
				curr_i--;
				curr_bit++;
			}
		}
	}
}

void create_itog_code() //составление таблицы символов (itog_ arr) и их итоговых кодов(коды сост. по количеству бит требуемых для записи)
{                       //оставление таблицы всех символов (res_table) с количеством бит для записи
	quick_sort_itog(0, n - 1, res);
	int curr_count = res[0].count;
	itog_arr[0].count = curr_count;
	itog_arr[0].code = res[0].code;
	itog_arr[0].code2 = 0;
	char b = 0;
	int q = 0;
	for (int i = 1; i < n; i++)
	{
		if (curr_count == res[i].count)
		{
			itog_arr[i].code = res[i].code;
			itog_arr[i].code2 = itog_arr[i - 1].code2 + 1;
			itog_arr[i].count = curr_count;
		}
		else
		{
			curr_count++;
			itog_arr[i].code = res[i].code;
			itog_arr[i].code2 = (itog_arr[i - 1].code2 + 1) << 1;
			itog_arr[i].count = curr_count;
		}
	}
	delete(res);
	res_table = (res_symb*)malloc(256 * sizeof(res_symb));
	for (int i = 0; i < n; i++)
	{
		res_table[(int)(itog_arr[i].code)].count = itog_arr[i].count;
		res_table[(int)(itog_arr[i].code)].code = itog_arr[i].code2;
	}
	for (int i = 0; i < 256; i++)
		if (res_table[i].count < 0)
		{
			res_table[i].count = 0;
			res_table[i].code = 0;
		}
}

void create_code_symb(node* t, int a, int c)
{
	if (!t) return;
	else
	{
		temp_d[c - 1] = a;
		if (t->code != -1)
		{
			int b = 0;
			int q = 0;
			for (int i = 0; i < c; i++)
			{
				if (temp_d[i]) b = (b + 1) << 1;
				else b = b << 1;
				q++;
			}
			b = b >> 1;
			res[curr_i].code2 = b;
			res[curr_i].code = t->code;
			res[curr_i].count = c;
			curr_i++;
		}
		else
		{
			create_code_symb(t->left, 0, c + 1);
			create_code_symb(t->right, 1, c + 1);
		}
	}
}

node* create_tree(symb tb[256], int n)
{
	on_node* ttree = (on_node*)malloc(n*sizeof(on_node));
	for (int i = 256 - n; i < 256; i++)
	{
		node* temp = (node*)malloc(sizeof(node));
		(*temp).code = tb[i].code;
		(*temp).freq = tb[i].freq;
		(*temp).left = NULL;
		(*temp).right = NULL;
		ttree[255 - i].child = temp;
	}
	bool foo = true;
	int new_n = n - 1;
	while (new_n != 0)
	{
		ttree[new_n - 1].child = nodes_glued(new_n - 1, new_n, ttree);
		quick_sort_(0, n - 1, ttree);
		int a;
		new_n--;
	}
	return ttree[0].child;
}

node* nodes_glued(int a, int b, on_node* t)
{
	node* temp;
	temp = (node*)malloc(sizeof(node));
	(*temp).freq = t[a].child->freq + t[b].child->freq; (*temp).code = -1;
	if (t[a].child->freq > t[b].child->freq)
	{
		(*temp).left = t[b].child; (*temp).right = t[a].child;
	}
	else if (t[a].child->freq < t[b].child->freq)
	{
		(*temp).left = t[a].child; (*temp).right = t[b].child;
	}
	else
	{
		if (t[a].child->code < t[b].child->code)
		{
			(*temp).left = t[a].child; (*temp).right = t[b].child;
		}
		else
		{
			(*temp).right = t[a].child; (*temp).left = t[b].child;
		}
	}
	return temp;
}

void quick_sort(int l, int r, symb* tb)
{
	double m = tb[l + (r - l) / 2].freq;
	int i = l;
	int j = r;
	while (i <= j)
	{
		while (tb[i].freq < m) i++;
		while (tb[j].freq > m) j--;
		if (i <= j)
		{
			if (tb[i].freq > tb[j].freq) swap(tb[i], tb[j]);
			i++;
			j--;
		}
	}
	if (i < r)
	{
		quick_sort(i, r, tb);
	}
	if (l < j)
	{
		quick_sort(l, j, tb);
	}
}

void quick_sort_(int l, int r, on_node* tb)
{
	double m = (tb[l + (r - l) / 2].child)->freq;
	int i = l;
	int j = r;
	while (i <= j)
	{
		while (tb[i].child->freq > m) i++;
		while (tb[j].child->freq < m) j--;
		if (i <= j)
		{
			if (tb[i].child->freq < tb[j].child->freq) swap(tb[i], tb[j]);
			i++;
			j--;
		}
	}
	if (i < r)
	{
		quick_sort_(i, r, tb);
	}
	if (l < j)
	{
		quick_sort_(l, j, tb);
	}
}

void quick_sort_itog(int l, int r, code_symb* tb)
{
	double m = tb[l + (r - l) / 2].count;
	int i = l;
	int j = r;
	while (i <= j)
	{
		while (tb[i].count < m) i++;
		while (tb[j].count > m) j--;
		if (i <= j)
		{
			if (tb[i].count > tb[j].count) swap(tb[i], tb[j]);
			i++;
			j--;
		}
	}
	if (i < r)
	{
		quick_sort_itog(i, r, tb);
	}
	if (l < j)
	{
		quick_sort_itog(l, j, tb);
	}
}

/* errors functions */

int get_err() {
    int err = lib_error;
    lib_error = E_OK;
    return err;
}

char* err_str(int a_error)  {
    switch (a_error)  {
        case E_OK:
            return "no errors";
        case E_BAD_INPUT:
            return "wrong input data";
        case E_LOST_SIZE:
            return "take off your data size";
    }
    return "unknown error";
}