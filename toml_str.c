#include "toml_str.h"

toml_string *toml_alloc_string() {
	toml_string *str = (toml_string *)malloc(sizeof(toml_string));
	if(str == NULL) {
		return NULL;
	}
	str->i = 0;
	str->s = (char *)calloc(1,sizeof(char));
	str->s[0] = '\0';
	return str;
}

node* new_str() {
  node *n = node_alloc();
	if(n == NULL) {
		return NULL;
	}
	n->type = TOML_STRING;
	n->value.p = toml_alloc_string();
	return n;
}

int toml_str_plus(toml_string *str, char c) {
	int len = str->i+1;
	char* new_s = (char *)malloc((len+1) * sizeof(char));
	if(new_s == NULL) {
		return -1;
	}
	memcpy(new_s, str->s, str->i);
	free(str->s);
	new_s[str->i] = c;
	new_s[len] = '\0';
	str->i = len;
	str->s = new_s;
}


