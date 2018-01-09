#ifndef TOML_H
#define TOML_H

#include "toml_str.h"
#include "toml_tbl.h"
#include "node.h"

int toml_init(node **root);
int toml_parse(node *root, char* buf, int len);
int toml_node_free(node *n);
int toml_free(node *root);

#endif
