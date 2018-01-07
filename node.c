#include "node.h"

node *node_alloc() {
  node *p;
  p = (node *)malloc(sizeof(node));
  memset(p, 0, sizeof(node));
  return p;
}
