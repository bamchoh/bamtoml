#ifndef TOML_TBL_H
#define TOML_TBL_H

#include "node.h"

typedef struct toml_table {
	int count;
	char** k;
	node** v;
} toml_table;

#endif

