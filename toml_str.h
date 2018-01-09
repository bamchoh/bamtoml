#ifndef TOML_STRING_H
#define TOML_STRING_H

#include "node.h"

typedef struct toml_string {
	int i;
	char* s;
} toml_string;

toml_string *toml_alloc_string();
void toml_string_free(toml_string *s);
node* new_str();
int toml_str_plus(toml_string *p, char c);

#endif
