#include "node.h"

node *node_alloc() {
  node *p;
  p = (node *)malloc(sizeof(node));
	if(p == NULL) {
		return NULL;
	}
  memset(p, 0, sizeof(node));
  return p;
}
