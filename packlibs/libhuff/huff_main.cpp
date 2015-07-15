/*
HUFF.H
(c) KoDi studio, 2015
*/
#include "stdafx.h"
#include "huff.h"
#include <memory.h>
#include <stdio.h>
#include <stdlib.h>
#include <bitset>
#include <malloc.h>

using namespace std; 

struct symb
{
	int code, freq;
};

struct res_symb
{
	int count;
	int code_i;
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
	node* child;
};

FILE* inf;
FILE* outf;
code_symb* res;
res_symb* res_table;
int curr_i;
int main_size;
int temp_d[32];
code_symb* itog_arr;
char* inbuf;
char* buf;
int n;

void sort_table(int k, symb* tb);
node* create_tree(symb tb[256]);
node* nodes_glued(int a, int b, on_node* t);
void create_code_symb(node* t, int a, int c);
void input_res(int* m, int c);
void create_itog_code();
void sort_itog(int k, code_symb* tb);
void sort_res(int k, res_symb* tb);
void to_record_data();



int lib_error = E_OK;
int lib_compsize = 0;

/* initialization functions */

int get_name() {
	return DLL_NAME;
}

int get_version() {
	return DLL_VERSION;
}

/* compress functions */

void* compress(void* data, int size_data) {
	/* check errors */
	if (data == NULL) {
		lib_error = E_BAD_INPUT;
		return NULL;
	}
	if (lib_compsize != 0) {
		lib_error = E_LOST_SIZE;
		return NULL;
	}

	/* compress alogorithm Huffman by Dima */

	main_size = size_data;
	symb table[256]{ 0, 0 };
	int table_freq[256]{ 0 };
	inbuf = (char*)data;
	unsigned char t;
	int x = 0;
	while (x < size_data)
	{
		t = inbuf[x];
		table[(int)t].freq++;
		table[(int)t].code = (int)t;
		table_freq[(int)t]++;
		x++;
	}
	for (int i = 0; i < 256; i++)
	{
		if (table[i].freq != 0) n++;
	}
	sort_table(256, table);
	n = 0;
	for (int i = 0; i < 256; i++)
	{
		if (table[i].freq != 0) n++;
	}
	node* tree = create_tree(table);
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
	buf = (char*)malloc(g*sizeof(char) + 256 * sizeof(char));
	for (int i = 0; i < 256; i++)
	{
		buf[i] = (unsigned char)res_table[i].count;
	}
	to_record_data();
	fclose(inf);
	fclose(outf);
	inf = fopen("out.txt", "rb");
	fclose(inf);

	/* code here */
	lib_compsize = size_data;
	return (void*)buf;
}

void* decompress(void* data, int size_data, int out_size) {
	/*check errors */
	if (data == NULL) {
		lib_error = E_BAD_INPUT;
		return NULL;
	}

	/* decompress algorithm Huffman by Dima */

	/* code here */

	return 0;

}

/* errors functions */

int get_err() {
	int err = lib_error;
	lib_error = E_OK;
	return err;
}

char* err_str(int a_error) {
	switch (a_error) {
	case E_OK:
		return "no errors";
	case E_BAD_INPUT:
		return "wrong input data";
	case E_LOST_SIZE:
		return "take off your data size";
	}
	return "unknown error";
}

void to_record_data()
{
	char ct = 0;
	int x = 0;
	char a = 99;
	int curr_i = 0;
	int curr_bit = 0; int curr_byte = 257;
	unsigned char t = 0;
	buf[curr_byte - 1] = 0;
	while (x < main_size)
	{
		t = inbuf[x];
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
		x++;
	}
}

void create_itog_code()
{                     
	sort_itog(n, res);
	int curr_count = res[0].count;
	itog_arr[0].count = res[0].count;
	itog_arr[0].code = res[0].code;
	itog_arr[0].code2 = 0;
	char b = 0;
	int q = 0;
	for (int i = 1; i < n; i++)
	{
		if (res[i - 1].count == res[i].count)
		{
			itog_arr[i].code = res[i].code;
			itog_arr[i].code2 = itog_arr[i - 1].code2 + 1;
			itog_arr[i].count = res[i].count;
		}
		else
		{
			itog_arr[i].code = res[i].code;
			itog_arr[i].code2 = (itog_arr[i - 1].code2 + 1) << (res[i].count - res[i - 1].count);
			itog_arr[i].count = res[i].count;
		}
	}
	delete(res);
	res_table = (res_symb*)malloc(256 * sizeof(res_symb));
	for (int i = 0; i < n; i++)
	{
		res_table[(int)itog_arr[i].code].count = itog_arr[i].count;
		res_table[(int)itog_arr[i].code].code_i = itog_arr[i].code;
		res_table[(int)itog_arr[i].code].code = itog_arr[i].code2;
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
			res[curr_i].code = t->code;
			res[curr_i].count = c;
			curr_i++;
			return;
		}
		else
		{
			create_code_symb(t->left, 0, c + 1);
			create_code_symb(t->right, 1, c + 1);
		}
	}
}

node* create_tree(symb tb[256])
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
		for (int i = new_n - 1; i > 0; i--)
		{
			if (ttree[i].child->freq > ttree[i - 1].child->freq)
			{
				swap(ttree[i], ttree[i - 1]);
			}
			else break;
		}
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

void sort_table(int k, symb* tb)
{
	for (int j = 0; j < k - 1; j++) {
		for (int i = 0; i < k - 1 - j; i++) {
			if (tb[i].freq > tb[i + 1].freq || tb[i].freq > tb[i + 1].freq && tb[i].code < tb[i + 1].code) {
				symb b = tb[i];
				tb[i] = tb[i + 1];
				tb[i + 1] = b;
			}
		}
	}
}

void sort_itog(int k, code_symb* tb)
{
	for (int j = 0; j < k - 1; j++) {
		for (int i = 0; i < k - 1 - j; i++) {
			if (tb[i].count > tb[i + 1].count || tb[i].count == tb[i + 1].count && tb[i].code > tb[i + 1].code) {
				code_symb b = tb[i];
				tb[i] = tb[i + 1];
				tb[i + 1] = b;
			}
		}
	}
}

void sort_res(int k, res_symb* tb)
{
	for (int j = 0; j < k - 1; j++) {
		for (int i = 0; i < k - 1 - j; i++) {
			if (tb[i].count > tb[i + 1].count || tb[i].count > tb[i + 1].count && tb[i].code_i < tb[i + 1].code_i) {
				res_symb b = tb[i];
				tb[i] = tb[i + 1];
				tb[i + 1] = b;
			}
		}
	}
}



