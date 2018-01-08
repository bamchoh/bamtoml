%{

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <io.h>
#include <sys/stat.h>
#include <ctype.h>
#include <math.h>
#include <share.h>
#include "node.h"
#include "toml_str.h"

typedef struct toml_table {
	int count;
	char** k;
	node** v;
} toml_table;

void add_kv_to_tbl(toml_table *tbl, char* k, node* v) {
	char** kl;
	node** vl;
	int i;
	if(tbl->count == 0) {
		i = tbl->count++;
		kl = (char**)calloc(tbl->count, sizeof(char*));
		vl = (node**)calloc(tbl->count, sizeof(node*));
	} else {
		i = tbl->count++;
		kl = (char**)realloc(tbl->k, sizeof(char*) * tbl->count);
		vl = (node**)realloc(tbl->v, sizeof(node*) * tbl->count);
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
	n->type = TOML_TABLE;
	n->value.p = toml_alloc_table();
	return n;
}

node *root_node_new() {
	node *n = toml_tbl_new();
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
						s->s = "true";
						s->i = strlen(s->s);
					} else {
						s->s = "false";
						s->i = strlen(s->s);
					}
					$1->type = TOML_STRING;
					$1->value.p = s;
				}
				;
val_lit : VAL_STRING
				| tINT
				| tBOOL
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
				toml_str_plus(p->current->value.p, c);
				break;
		}
		toml_str_plus(p->current->value.p, c);
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
		toml_str_plus(p->current->value.p, c);
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
		toml_str_plus(s,c);
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
	for(int i = 0;(c = nextc(p)) != -1;i++) {
		if(is_term(c)) {
			pushback(p, c);
			break;
		}
		if((c == '+' || c == '-') && i == 0) {
			prevc = c;
			toml_str_plus(s, c);
			continue;
		}
		if(c == '0' && i == 0) {
			p->count = pos;
			free(s);
			return -1;
		}
		if(c == '_' && i == 0) {
			p->count = pos;
			free(s);
			return -1;
		}
		if(c == '_' && isdigit(prevc) != 0) {
			prevc = c;
			continue;
		}
		if(isdigit(c) == 0) {
			p->count = pos;
			free(s);
			return -1;
		}
		prevc = c;
		toml_str_plus(s, c);
	}
	if(prevc == '_') {
		p->count = pos;
		free(s);
		return -1;
	}
	if(c == -1) {
		pushback(p,c);
	}
	node *n = node_alloc();
	n->type = TOML_INT;
	n->value.i = atol(s->s);
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
		toml_str_plus(p->current->value.p, c);
		parse_val_string(p);
		yylval = (node *)p->current;
		return VAL_STRING;
	}
	if(c == 't' || c == 'f') {
		pushback(p,c);
		if(check_bool(p) == 0) {
			yylval = p->current;
			return tBOOL;
		}
		c = nextc(p);
	}
	if(c == '+' || c == '-' || isdigit(c) != 0) {
		pushback(p,c);
		if(check_integer(p) == 0) {
			yylval = p->current;
			return tINT;
		}
		c = nextc(p);
	}
	if(c == '-' || c == '_' ||
		(0x30 <= c && c <= 0x39) ||
		(0x40 <= c && c <= 0x5A) ||
		(0x61 <= c && c <= 0x7A)) {
		p->current = new_str();
		toml_str_plus(p->current->value.p, c);
		parse_key_string(p);
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

int main(int argc, char* argv[])
{
	// yydebug = 1;
	if(argc <= 1) {
		fprintf(stderr, "file name is needed\n");
	}
	FILE *fp;
	long file_size;
	char *buffer;
	struct _stat stbuf;
	int fd;
	char c;
	if(_sopen_s(&fd, argv[1], O_RDONLY, _SH_DENYNO, 0)) {
		fprintf(stderr, "open error\n");
		exit(1);
	}
	fp = fdopen(fd, "rb");
	if(fp == NULL) {
		fprintf(stderr, "fdopen error\n");
		exit(1);
	}
	int result;
	result = _fstat(fd, &stbuf);
	if(result != 0) {
		fprintf(stderr, "fstat error\n");
		exit(1);
	}
	file_size = stbuf.st_size;
	buffer = (char*)calloc(file_size, sizeof(char));
	if (buffer == NULL) {
		fprintf(stderr, "malloc error\n");
		exit(1);
	}
	for(int i = 0; (c = fgetc(fp)) != -1; i++) {
		buffer[i] = c;
	}
	_close(fd);
	node *root;
	int ret;
	ret = toml_init(&root);
	if(ret == -1) {
		fprintf(stderr, "toml_init error\n");
		return -1;
	}
	ret = toml_parse(root, buffer, strlen(buffer));
	if(ret == -1) {
		fprintf(stderr, "toml_parse error\n");
		return -1;
	}
	node *n = root;
	toml_table *tbl = (toml_table *)n->value.p;
	printf("count : %d\n", tbl->count);
	for(int i = 0; i < tbl->count; i++) {
		switch(tbl->v[i]->type) {
			case TOML_STRING: {
				toml_string *tmp2 = (toml_string *)tbl->v[i]->value.p;
				printf("  [TOML_STR ]%s = %s\n", tbl->k[i], tmp2->s);
				break;
			}
			case TOML_BOOL:
				if(tbl->v[i]->value.i == 0) {
					printf("  [TOML_BOOL]%s = false\n", tbl->k[i]);
				} else {
					printf("  [TOML_BOOL]%s = true\n", tbl->k[i]);
				}
				break;
			case TOML_INT:
				printf("  [TOML_INT ]%s = %d\n", tbl->k[i], tbl->v[i]->value.i);
		}
	}
	
	return 0;
}
