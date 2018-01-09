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

void print_all_node(node *n) {
	toml_table *tbl = (toml_table *)n->value.p;
	printf("count : %d\n", tbl->count);
	for(int i = 0; i < tbl->count; i++) {
		switch(tbl->v[i]->type) {
			case TOML_STRING: {
				toml_string *tmp2 = (toml_string *)tbl->v[i]->value.p;
				printf("  [TOML_STR  ]%s = %s\n", tbl->k[i], tmp2->s);
				break;
			}
			case TOML_BOOL:
				if(tbl->v[i]->value.i == 0) {
					printf("  [TOML_BOOL ]%s = false\n", tbl->k[i]);
				} else {
					printf("  [TOML_BOOL ]%s = true\n", tbl->k[i]);
				}
				break;
			case TOML_INT:
				printf("  [TOML_INT  ]%s = %d\n", tbl->k[i], tbl->v[i]->value.i);
				break;
			case TOML_FLOAT:
				printf("  [TOML_FLOAT]%s = %lf\n", tbl->k[i], tbl->v[i]->value.f);
				break;
		}
	}
}

int main(int argc, char* argv[])
{
	// yydebug = 1;
	if(argc <= 1) {
		fprintf(stderr, "file name is needed\n");
	}
	FILE *fp;
	long file_size;
	char *buffer;
	struct _stat stbuf;
	int fd;
	char c;
	if(_sopen_s(&fd, argv[1], O_RDONLY, _SH_DENYNO, 0)) {
		fprintf(stderr, "open error\n");
		exit(1);
	}
	fp = fdopen(fd, "rb");
	if(fp == NULL) {
		fprintf(stderr, "fdopen error\n");
		exit(1);
	}
	int result;
	result = _fstat(fd, &stbuf);
	if(result != 0) {
		fprintf(stderr, "fstat error\n");
		exit(1);
	}
	file_size = stbuf.st_size;
	buffer = (char*)calloc(file_size, sizeof(char));
	if (buffer == NULL) {
		fprintf(stderr, "malloc error\n");
		exit(1);
	}
	for(int i = 0; (c = fgetc(fp)) != -1; i++) {
		buffer[i] = c;
	}
	_close(fd);
	for(int i = 0; i < 1;i++) {
		node *root;
		int ret;
		ret = toml_init(&root);
		if(ret == -1) {
			fprintf(stderr, "toml_init error\n");
			return -1;
		}
		ret = toml_parse(root, buffer, strlen(buffer));
		if(ret == -1) {
			fprintf(stderr, "toml_parse error\n");
			return -1;
		}
		print_all_node(root);
		toml_free(root);
	}

	return 0;
}
