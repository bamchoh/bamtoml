#ifndef NODE_H
#define NODE_H

#include <stdlib.h>
#include <string.h>
#include "toml_float.h"

typedef enum {
	TOML_ROOT = 1,
	TOML_TABLE,
	TOML_STRING,
  TOML_BOOL,
	TOML_INT,
	TOML_FLOAT,
	TOML_UNDEF = -1,
} node_type;

typedef struct node {
	union {
		long long i;
		toml_float *f;
		void *p;
	} value;
	node_type type;
} node;

node *node_alloc();

#endif
