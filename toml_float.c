#include "stdlib.h"
#include "toml_float.h"

toml_float *new_toml_float() {
	return (toml_float*)malloc(sizeof(toml_float));
}
