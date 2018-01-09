%{

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
// #include <fcntl.h>
// #include <io.h>
// #include <sys/stat.h>
#include <ctype.h>
// #include <math.h>
// #include <share.h>
#include "toml_tbl.h"
#include "toml_str.h"
#include "toml.h"

int toml_node_free(node *n);

void add_kv_to_tbl(toml_table *tbl, char* k, node* v) {
	char** kl;
	node** vl;
	int i;
	if(tbl->count == 0) {
		i = tbl->count;
		tbl->count++;
		kl = (char**)calloc(tbl->count, sizeof(char*));
		vl = (node**)calloc(tbl->count, sizeof(node*));
	} else {
		i = tbl->count;
		kl = (char**)calloc(i+1, sizeof(char*));
		vl = (node**)calloc(i+1, sizeof(node*));
		memcpy(kl, tbl->k, i*sizeof(char*));
		memcpy(vl, tbl->v, i*sizeof(node*));
		free(tbl->k);
		free(tbl->v);
		tbl->count++;
	}
	kl[i] = k;
	vl[i] = v;
	tbl->k = kl;
	tbl->v = vl;
}

toml_table *toml_alloc_table() {
	toml_table *tbl = (toml_table *)calloc(1,sizeof(toml_table));
	return tbl;
}

node *toml_tbl_new() {
	node *n = node_alloc();
	if(n == NULL) {
		return NULL;
	}
	n->type = TOML_TABLE;
	n->value.p = toml_alloc_table();
	return n;
}

node *root_node_new() {
	node *n = toml_tbl_new();
	if(n == NULL) {
		return NULL;
	}
	n->type = TOML_ROOT;
	return n;
}

typedef struct toml_parser_state {
	char* buffer;
	int count;
	node* node_tree;
	node* current;
} parser_state;

#define YYSTYPE node*

int yylex(parser_state *p);
void yyerror(parser_state *p, const char* s);
int yyparse(parser_state *p);

%}

%token KEY_STRING
%token VAL_STRING
%token tINT
%token tBOOL
%token tFLOAT
%parse-param {parser_state *p}
%lex-param {parser_state *p}

%%

program : /* empty */
				| program line
				;
line    : '\n'
				| expr '\n'
				;
expr    : key_lit '=' val_lit {
				node *n = p->node_tree;
					toml_table *tbl = (toml_table *)n->value.p;
					toml_string *tmp1 = (toml_string *)$1->value.p;
					add_kv_to_tbl(n->value.p, tmp1->s, $3);
				}
				;
key_lit : KEY_STRING
				| VAL_STRING
				| tINT
				| tBOOL {
					toml_string *s = toml_alloc_string();
					if($1->value.i != 0) {
						s->s = (char *)malloc(5 + sizeof(char));
						strcpy(s->s, "true");
						s->i = strlen(s->s);
					} else {
						s->s = (char *)malloc(6 + sizeof(char));
						strcpy(s->s, "false");
						s->i = strlen(s->s);
					}
					$1->type = TOML_STRING;
					$1->value.p = s;
				}
				;
val_lit : VAL_STRING
				| tINT
				| tBOOL
				| tFLOAT
				;

;

%%

int nextc(parser_state *p) {
	int c;
	if(strlen(p->buffer) > p->count) {
		c = p->buffer[p->count];
		p->count++;
		if(c != 0) {
			return c;
		}
	}
	return EOF;
}

void pushback(parser_state *p, char c) {
	p->count--;
}

int peekc(parser_state *p) {
	int c;
	if(strlen(p->buffer) > p->count) {
		c = p->buffer[p->count];
		if(c != 0) {
			return c;
		}
	}
	return EOF;
}

int parse_val_string(parser_state *p) {
	int c;
	while(1) {
		c = nextc(p);
		if(c == -1) {
			break;
		}
		if(c == '\n') {
				pushback(p, c);
				break;
		}
		if(c == '"') {
			if(toml_str_plus(p->current->value.p, c) == -1) {
				return -2;
			}
			break;
		}
		if(toml_str_plus(p->current->value.p, c) == -1) {
			return -2;
		}
	}
	return 0;
}

int parse_key_string(parser_state *p) {
	int c;
	while(1) {
		c = nextc(p);
		if(c == -1) {
			break;
		}
		if(c == '\n') {
			pushback(p, c);
			break;
		}
		if(c == ' ') {
			break;
		}
		if(toml_str_plus(p->current->value.p, c) == -1) {
			return -2;
		}
	}
	return 0;
}

int is_term(char c) {
	if(c == ' ' || c == '\n') {
		return -1;
	}
	return 0;
}

int check_bool(parser_state *p) {
	toml_string *s = toml_alloc_string();
	int pos = p->count;
	char c;
	for(int i = 0;(c = nextc(p)) != -1;i++) {
		if(is_term(c)) {
			pushback(p,c);
			break;
		}
		if(toml_str_plus(s,c) == -1) {
			p->count = pos;
			free(s);
			return -2;
		}
	}
	if(strcmp(s->s, "true") == 0) {
		node *n = node_alloc();
		n->type = TOML_BOOL;
		n->value.i = -1;
		p->current = n;
		free(s);
		return 0;
	}
	if(strcmp(s->s, "false") == 0) {
		node *n = node_alloc();
		n->type = TOML_BOOL;
		n->value.i = 0;
		p->current = n;
		free(s);
		return 0;
	}
	p->count = pos;
	free(s);
	return -1;
}

int check_integer(parser_state *p) {
	toml_string *s = toml_alloc_string();
	char prevc = -1;
	char c;
	int pos = p->count;
	bool found_dot = false;
	for(int i = 0;(c = nextc(p)) != -1;i++) {
		if(is_term(c)) {
			pushback(p, c);
			break;
		}
		if((c == '0' || c == '_' || c == '.' ) && i == 0) {
			p->count = pos;
			free(s);
			return -1;
		}
		if((c == '+' || c == '-') && i == 0) {
			prevc = c;
			if(toml_str_plus(s, c) == -1) {
				p->count = pos;
				free(s);
				return -2;
			}
			continue;
		}
		if(c == '_' && isdigit(prevc) != 0 && isdigit(peekc(p)) != 0) {
			prevc = c;
			continue;
		}
		if(c == '_') {
			p->count = pos;
			free(s);
			return -1;
		}
		if(c == '.') {
			if(found_dot == true) {
				p->count = pos;
				free(s);
				return -1;
			}
			found_dot = true;
			prevc = c;
			if(toml_str_plus(s, c) == -1) {
				p->count = pos;
				free(s);
				return -2;
			}
			continue;
		}
		if(isdigit(c) == 0) {
			p->count = pos;
			free(s);
			return -1;
		}
		prevc = c;
		if(toml_str_plus(s, c) == -1) {
			p->count = pos;
			free(s);
			return -2;
		}
	}
	if(c == -1) {
		pushback(p,c);
	}
	node *n = node_alloc();
	if(found_dot == true) {
		n->type = TOML_FLOAT;
		n->value.f = atof(s->s);
	} else {
		n->type = TOML_INT;
		n->value.i = atol(s->s);
	}
	p->current = n;
	free(s);
	return 0;
}

/* トークン解析関数 */
int yylex(parser_state *p) {
	int c;
retry:
		 c = nextc(p);
	if(c == EOF) {
		return 0;
	}
	if(c == ' ') {
		goto retry;
	}
	if(c == '=' || c == '\n') {
		return c;
	}
	if(c == '"') {
		p->current = new_str();
		if(toml_str_plus(p->current->value.p, c) == -1) {
			fprintf(stderr, "toml_str_plus error in parsing string lit.\n");
			return 0;
		}
		if(parse_val_string(p) != 0) {
			fprintf(stderr, "parse_val_string error in parsing string lit.\n");
			return 0;
		}
		yylval = (node *)p->current;
		return VAL_STRING;
	}
	if(c == 't' || c == 'f') {
		pushback(p,c);
		int ret;
		ret = check_bool(p);
		if(ret == -2) {
			fprintf(stderr, "check_bool error\n");
			return 0;
		}
		if(ret == 0) {
			yylval = p->current;
			return tBOOL;
		}
		c = nextc(p);
	}
	if(c == '+' || c == '-' || c == '.' || isdigit(c) != 0) {
		pushback(p,c);
		int ret;
		ret = check_integer(p);
		if(ret == -2) {
			fprintf(stderr, "check_integer error\n");
			return 0;
		}
		if(ret == 0) {
			yylval = p->current;
			if(p->current->type == TOML_FLOAT) {
				return tFLOAT;
			} else {
				return tINT;
			}
		}
		c = nextc(p);
	}
	if(c == '-' || c == '_' ||
		(0x30 <= c && c <= 0x39) ||
		(0x40 <= c && c <= 0x5A) ||
		(0x61 <= c && c <= 0x7A)) {
		p->current = new_str();
		if(toml_str_plus(p->current->value.p, c) == -1) {
			fprintf(stderr, "toml_str_plus error in parsing key string.\n");
			return 0;
		}
		if(parse_key_string(p) != 0) {
			fprintf(stderr, "parse_key_string error in parsing parse_key_string.n");
			return 0;
		}
		yylval = (node *)p->current;
		return KEY_STRING;
	}
	fprintf(stderr, "undef token %c(%d)\n", c, c);
	return c;
}

/* エラー表示関数 */
void yyerror(parser_state *p, const char* s)
{
	fprintf(stderr, "error: %s\n", s);
}

int toml_init(node **root) {
	node *n = root_node_new();
	if(n == NULL) {
		return -1;
	}
	*root = n;
	return 0;
}

int toml_parse(node *root, char* buf, int len) {
	parser_state p;
	p.buffer = buf;
	p.count = 0;
	p.node_tree = root;
	return(yyparse(&p));
}

int toml_node_free(node *n) {
	switch(n->type) {
		case TOML_STRING:
			free(n->value.p);
			break;
	}
	free(n);
	return 0;
}

int toml_free(node *root) {
	toml_table *tbl = (toml_table *)root->value.p;
	for(int i = 0;i < tbl->count; i++) {
		free(tbl->k[i]);
		toml_node_free(tbl->v[i]);
	}
	free(tbl->k);
	free(tbl->v);
	free(tbl);
	free(root);
}

