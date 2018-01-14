#ifndef TOML_FLOAT_H
#define TOML_FLOAT_H

typedef struct toml_float {
	double v;
	int p;
} toml_float;

toml_float *new_toml_float();

#endif
