%{

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
	unsigned int count;
	unsigned int tlen;
	char* token;
	node* node_tree;
	node* current;
} parser_state;

#define YYSTYPE node*

int yylex(parser_state *p);
void yyerror(parser_state *p, const char* s);
int yyparse(parser_state *p);

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

void pushback(parser_state *p) {
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

int parse_key_string(parser_state *p) {
}

int is_term(parser_state *p, char c) {
	if(c == EOF || c == ' ' || c == '\n' || (c == '\r' && peekc(p) == '\n')) {
		return TRUE;
	}
	return FALSE;
}

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
					toml_string *str = $1->value.p;
					add_kv_to_tbl(p->node_tree->value.p, str->s, $3);
					free(str);
					free($1);
				}
				;
key_lit : KEY_STRING
				| VAL_STRING
				| tINT
				| tBOOL {
					toml_string *s = (toml_string *)malloc(sizeof(toml_string));
					if($1->value.i != 0) {
						s->s = (char *)malloc(5 + sizeof(char));
						memcpy(s->s, "true", 5);
						s->i = strlen(s->s);
					} else {
						s->s = (char *)malloc(6 + sizeof(char));
						memcpy(s->s, "false", 6);
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

int parser_is_whitespace(parser_state *p) {
	int c = nextc(p);
	if(c == ' ' || (c == '\r' && peekc(p) == '\n')) {
		return TRUE;
	}
	pushback(p);
	return FALSE;
}

int parser_is_equal(parser_state *p) {
	return peekc(p) == '=' ? TRUE : FALSE;
}

int parser_is_endline(parser_state *p) {
	return peekc(p) == '\n' ? TRUE : FALSE;
}

int parser_is_key_string(parser_state *p) {
	int pos = p->count;
	p->token = p->buffer + p->count;
	int c;
	while(1) {
		c = nextc(p);
		if(c == '-' || c == '_' ||
			(0x30 <= c && c <= 0x39) ||
			(0x40 <= c && c <= 0x5A) ||
			(0x61 <= c && c <= 0x7A)) {
			continue;
		}
		if(is_term(p,c) == TRUE) {
			pushback(p);
			p->tlen = p->count - pos;
			return TRUE;
		}
	}
	p->count = pos;
	return FALSE;
}

int parser_is_string(parser_state *p) {
	int c;
	int pos = p->count;
	p->token = p->buffer + p->count;
	if(nextc(p) == '"') {
		while(1) {
			c = nextc(p);
			if(c == -1) {
				p->tlen = 0;
				p->count = pos;
				return FALSE;
			}
			if(c == '\n') {
				p->tlen = 0;
				p->count = pos;
				return FALSE;
			}
			if(c == '"') {
				p->tlen = p->count - pos;
				return TRUE;
			}
		}
	}
	p->count = pos;
	return FALSE;
}

int parser_tokencmp(parser_state *p, char *lit, int len) {
	if(strncmp(p->token,lit,len) == 0) {
		p->count += len;
		int c;
		c = nextc(p);
		if(is_term(p,c) == TRUE) {
			p->tlen = len;
			pushback(p);
			return TRUE;
		}
		pushback(p);
		return FALSE;
	}
	return FALSE;
}

int parser_is_bool(parser_state *p) {
	char c;
	int pos = p->count;
	p->token = p->buffer + p->count;
	if(parser_tokencmp(p,"true",4) == TRUE) {
		return TRUE;
	}
	if(parser_tokencmp(p,"false",5) == TRUE) {
		return TRUE;
	}
	p->count = pos;
	return FALSE;
}

int parser_is_number(parser_state *p, int *found_dot) {
	int prevc = -1;
	p->token = p->buffer + p->count;
	int c = nextc(p);
	if(c == '0' || c == '_' || c == '.' ) {
		pushback(p);
		return FALSE;
	}
	if(c == '+' || c == '-' || isdigit(c) != 0 ) {
		prevc = c;
		for(int i = 1;(c = nextc(p)) != EOF;i++) {
			if(is_term(p,c) == TRUE) {
				pushback(p);
				return TRUE;
			}
			if(c == '_' && isdigit(prevc) != 0 && isdigit(peekc(p)) != 0) {
				prevc = c;
				continue;
			}
			if(c == '_') {
				return FALSE;
			}
			if(c == '.') {
				if(*found_dot == TRUE) {
					return FALSE;
				}
				*found_dot = TRUE;
				prevc = c;
				continue;
			}
			if(isdigit(c) == 0) {
				return FALSE;
			}
			prevc = c;
		}
		if(c == EOF) {
			return FALSE;
		}
	}
	pushback(p);
	return FALSE;
}

int parser_is_float(parser_state *p) {
	int pos = p->count;
	int found_dot = FALSE;
	if(parser_is_number(p, &found_dot) == TRUE) {
		if(found_dot == TRUE) {
			p->tlen = p->count + pos;
			return TRUE;
		} else {
			p->count = pos;
			return FALSE;
		}
	}
	return FALSE;
}


int parser_is_int(parser_state *p) {
	int pos = p->count;
	int found_dot = FALSE;
	if(parser_is_number(p, &found_dot) == TRUE) {
		if(found_dot == FALSE) {
			p->tlen = p->count + pos;
			return TRUE;
		} else {
			p->count = pos;
			return FALSE;
		}
	}
	return FALSE;
}

char *rm_(char *token, int tlen) {
	char *temp = (char *)malloc(sizeof(char) * tlen);
	int j = 0;
	for(int i = 0; i < tlen; i++) {
		if(token[i] == '_') {
			continue;
		}
		temp[j] = token[i];
		j++;
	}
	temp[j] = '\0';
	return temp;
}

double conv_ttof(char *token, int tlen) {
	double d;
	char *temp = rm_(token, tlen);
	sscanf(temp, "%lf",&d);
	free(temp);
	return d;
}

long conv_ttol(char *token, int tlen) {
	long l;
	char *temp = rm_(token, tlen);
	sscanf(temp, "%ld",&l);
	free(temp);
	return l;
}

node *new_node_float(double d) {
	node *n = node_alloc();
	if(n == NULL) {
		return NULL;
	}
	n->type = TOML_FLOAT;
	n->value.f = d;
	return n;
}

node *new_node_int(long l) {
	node *n = node_alloc();
	if(n == NULL) {
		return NULL;
	}
	n->type = TOML_INT;
	n->value.i = l;
	return n;
}

node *new_node_bool(int b) {
	node *n = node_alloc();
	if(n == NULL) {
		return NULL;
	}
	n->type = TOML_BOOL;
	n->value.i = b;
	return n;
}

node *new_node_str(char *str, int len) {
	char *t = (char *)malloc(sizeof(char) * (len+1));
	memcpy(t, str, len);
	t[len] = '\0';

toml_string *ts = (toml_string *)malloc(sizeof(toml_string));
	ts->i = len;
	ts->s = t;

node *n = node_alloc();
	if(n == NULL) {
		return NULL;
	}
	n->type = TOML_STRING;
	n->value.p = ts;
	return n;
}

int yylex(parser_state *p) {
	int c;
retry:
		 if(peekc(p) == EOF) {
		return nextc(p);
	}
	if(parser_is_whitespace(p) == TRUE) {
		goto retry;
	}
	if(parser_is_equal(p) == TRUE) {
		return nextc(p);
	}
	if(parser_is_endline(p) == TRUE) {
		return nextc(p);
	}
	if(parser_is_bool(p) == TRUE) {
		node *n;
		if(*(p->token) == 't') {
			n = new_node_bool(TRUE);
		} else {
			n = new_node_bool(FALSE);
		}
		if(n == NULL) {
			fprintf(stderr, "check_bool error\n");
			return 0;
		}
		yylval = n;
		return tBOOL;
	}
	if(parser_is_int(p) == TRUE) {
		long l = conv_ttol(p->token, p->tlen);
		yylval = new_node_int(l);
		return tINT;
	}
	if(parser_is_float(p) == TRUE) {
		double d = conv_ttof(p->token, p->tlen);
		yylval = new_node_float(d);
		return tFLOAT;
	}
	if(parser_is_string(p) == TRUE) {
		yylval = new_node_str(p->token+1, p->tlen-2);
		return VAL_STRING;
	}
	if(parser_is_key_string(p) == TRUE) {
		yylval = new_node_str(p->token, p->tlen);
		return KEY_STRING;
	}
	c = nextc(p);
	fprintf(stderr, "undef token %c(%d)\n", c, c);
	return c;
}

/* ƒGƒ‰[•\Ž¦ŠÖ” */
void yyerror(parser_state *p, const char* s)
{
	fprintf(stderr, "error: %s\n", s);
	fprintf(stderr, "  count   : %d\n", p->count);
	fprintf(stderr, "  buffer  : >>>\n%s\n>>>\n", p->buffer + p->count);
	fprintf(stderr, "  current : (%c)\n", p->buffer[p->count]);
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
	p.token = NULL;
	p.node_tree = root;
	return(yyparse(&p));
}

int toml_node_free(node *n) {
	switch(n->type) {
		case TOML_STRING:
			toml_string_free(n->value.p);
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

