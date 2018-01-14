#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <io.h>
#include <sys/stat.h>
#include <ctype.h>
#include <math.h>
#include <share.h>
#include "toml_str.h"
#include "toml_tbl.h"
#include "toml.h"

#ifndef _WIN32
#define _fdopen fdopen
#endif

char* readall() {
	FILE *fp;
	long file_size;
	char *buffer;
	struct _stat stbuf;
	int fd;
	char c;
	int capa = 1;
	int len = 0;
	buffer = (char*)calloc(capa, sizeof(char));
	while((c = fgetc(stdin)) != EOF) {
		if(len+1 >= capa) {
			capa *= 2;
			char *nbuf = (char*)calloc(capa, sizeof(char));
			memcpy(nbuf, buffer, len);
			free(buffer);
			buffer = nbuf;
		}
		buffer[len] = c;
		len++;
	}
	// fprintf(stderr, "%s(%d:%d)\n", buffer, strlen(buffer), capa);
	return buffer;
}

void print_json(node *root) {
	toml_table *tbl = (toml_table *)root->value.p;
	printf("{");
	for(int i = 0; i < tbl->count; i++) {
		if(i != 0) {
			printf(",");
		}
		switch(tbl->v[i]->type) {
			case TOML_STRING: {
				toml_string *tmp2 = (toml_string *)tbl->v[i]->value.p;
				printf("\"%s\": { \"type\": \"%s\", \"value\": \"%s\" }", tbl->k[i], "string", tmp2->s);
				break;
			}
			case TOML_BOOL:
				if(tbl->v[i]->value.i == 0) {
					printf("\"%s\": { \"type\": \"%s\", \"value\": \"%s\" }", tbl->k[i], "bool", "false");
				} else {
					printf("\"%s\": { \"type\": \"%s\", \"value\": \"%s\" }", tbl->k[i], "bool", "true");
				}
				break;
			case TOML_INT:
				printf("\"%s\": { \"type\": \"%s\", \"value\": \"%lld\" }", tbl->k[i], "integer", tbl->v[i]->value.i);
				break;
			case TOML_FLOAT:
				printf("\"%s\": { \"type\": \"%s\", \"value\": \"%.*lf\" }", tbl->k[i], "float", tbl->v[i]->value.f->p, tbl->v[i]->value.f->v);
				break;
		}
	}
	printf("}");
}

int main(int argc, char* argv[])
{
	char *buffer = readall();
	for(int i = 0; i < 1;i++) {
		node *root;
		int ret;
		ret = toml_init(&root);
		if(ret == -1) {
			fprintf(stderr, "toml_init error\n");
			return -1;
		}
		ret = toml_parse(root, buffer, strlen(buffer));
		if(ret != 0) {
			fprintf(stderr, "toml_parse error\n");
			return ret;
		}

		print_json(root);
		// TODO
		// insert test function here

		toml_free(root);
	}

	return 0;
}
