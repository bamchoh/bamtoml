%{

#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include "toml_tbl.h"
#include "toml_str.h"
#include "toml_float.h"
#include "toml.h"
#include "limits.h"

#define ISALPHA(c) ((((unsigned)(c) | 0x20) - 'a') < 26)
#define ISDIGIT(c) (((unsigned)(c) - '0') < 10)
#define ISXDIGIT(c) (ISDIGIT(c) || ((unsigned)(c) | 0x20) - 'a' < 6)

typedef struct toml_parser_state {
	char *s, *send;
	unsigned int column;
	unsigned int count;
	unsigned int lineno;
	unsigned int tlen;
	int precision;
	char* tokbuf;
	node* node_tree;
	node* current;
} parser_state;

static void tokadd(parser_state *p, int32_t c);
static void backc(parser_state *p);

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

#define YYSTYPE node*

int yylex(parser_state *p);
void yyerror(parser_state *p, const char* s);
int yyparse(parser_state *p);

static inline int
nextc(parser_state *p)
{
	int c;
	if(!p->s || p->s >= p->send) {
		return EOF;
	}
	else {
		c = (unsigned char)*p->s++;
	}
	if (c >= 0) {
		p->column++;
	}
	if(c == '\r') {
		c = nextc(p);
		if(c != '\n') {
			backc(p);
			return '\r';
		}
		return c;
	}
	return c;
}

static void
backc(parser_state *p) {
	p->column--;
	p->s--;
}

static void
skip(parser_state *p, char term)
{
	int c;

	for(;;) {
		c = nextc(p);
		if (c < 0) break;
		if (c == term) break;
	}
}

static int
newtok(parser_state *p) {
	if(p->tokbuf != NULL) {
		free(p->tokbuf);
		p->tokbuf = NULL;
	}
	p->tidx = 0;
	return p->column - 1;
}

static void
tokadd(parser_state *p, int32_t c) {
}

int peekc(parser_state *p) {
	int c;
	if(strlen(p->s) > p->count) {
		c = p->s[p->count];
		if(c != 0) {
			return c;
		}
	}
	return EOF;
}

int parse_key_string(parser_state *p) {
}

int is_term2(char *s) {
	char c1 = s[0];
	char c2 = s[1];
	if(c1 == EOF || c1 == ' ' || c1 == '\n' || (c1 == '\r' && c2 == '\n')) {
		return TRUE;
	}
	return FALSE;
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
%token tTrue
%token tFalse
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
				| tTrue {
					toml_string *s = (toml_string *)malloc(sizeof(toml_string));
					s->s = "true";
					s->i = 5;
					$1->type = TOML_STRING;
					$1->value.p = s;
				}
				| tFalse {
					toml_string *s = (toml_string *)malloc(sizeof(toml_string));
					s->s = "false";
					s->i = 6;
					$1->type = TOML_STRING;
					$1->value.p = s;
				}
				;
val_lit : VAL_STRING
				| tINT
				| tTrue
				| tFalse
				| tFLOAT
				;

;

%%

int parser_is_equal(parser_state *p) {
	return peekc(p) == '=' ? TRUE : FALSE;
}

int parser_is_endline(parser_state *p) {
	return peekc(p) == '\n' ? TRUE : FALSE;
}

int parser_is_key_string(parser_state *p) {
	int pos = p->count;
	p->tokbuf = p->s + p->count;
	int c;
	while(1) {
		c = nextc(p);
		if(c == '-' || c == '_' ||
			(0x30 <= c && c <= 0x39) ||
			(0x40 <= c && c <= 0x5A) ||
			(0x61 <= c && c <= 0x7A)) {
			continue;
		}
		if(is_term(p,c) == TRUE || c == '=') {
			backc(p);
			p->tlen = p->count - pos;
			return TRUE;
		}
	}
	p->count = pos;
	return FALSE;
}

int parser_is_multi_string(parser_state *p) {
	int pos = p->count;
	p->tokbuf = p->s+p->count;
	if(strncmp((p->tokbuf),"\"\"\"", 3) == 0) {
		p->count+=3;
		while(peekc(p) != EOF) {
			if(strncmp(p->s+p->count,"\"\"\"", 3) == 0) {
				p->count+=3;
				p->tlen = p->count - pos;
				return TRUE;
			}
			p->count++;
		}
	}
	return FALSE;
}

int parser_is_string(parser_state *p) {
	int c;
	int pos = p->count;
	p->tokbuf = p->s + p->count;
	int esc = FALSE;
	if(nextc(p) == '"') {
		while(1) {
			c = nextc(p);
			if(c == -1) {
				p->tlen = 0;
				p->count = pos;
				return FALSE;
			}
			if(c == '\\') {
				c = nextc(p);
				switch(c) {
				case '"':
					continue;
				}
				backc(p);
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
	if(strncmp(p->tokbuf,lit,len) == 0) {
		p->count += len;
		int c;
		c = nextc(p);
		if(is_term(p,c) == TRUE) {
			p->tlen = len;
			backc(p);
			return TRUE;
		}
		backc(p);
		return FALSE;
	}
	return FALSE;
}

int parser_is_bool(parser_state *p) {
	char c;
	int pos = p->count;
	p->tokbuf = p->s + p->count;
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
	p->tokbuf = p->s + p->count;
	int c = nextc(p);
	if(c == '0' || c == '_' || c == '.' ) {
		backc(p);
		return FALSE;
	}
	if(c == '+' || c == '-' || ISDIGIT(c) != 0 ) {
		prevc = c;
		for(int i = 1;(c = nextc(p)) != EOF;i++) {
			if(is_term(p,c) == TRUE) {
				backc(p);
				return TRUE;
			}
			if(c == '_' && ISDIGIT(prevc) != 0 && ISDIGIT(peekc(p)) != 0) {
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
			if(ISDIGIT(c) == 0) {
				return FALSE;
			}
			if(*found_dot == TRUE) {
				p->precision++;
			}
			prevc = c;
		}
		if(c == EOF) {
			return FALSE;
		}
	}
	backc(p);
	return FALSE;
}

int parser_is_float(parser_state *p) {
	int pos = p->count;
	int found_dot = FALSE;
	p->precision = 0;
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

long long conv_ttol(char *token, int tlen) {
	long long l = 0;
	char *temp = rm_(token, tlen);
	sscanf(temp, "%lld",&l);
	free(temp);
	return l;
}

node *new_node_float(double d,int precision) {
	toml_float *f = new_toml_float();
	f->v = d;
	f->p = precision;
	node *n = node_alloc();
	if(n == NULL) {
		return NULL;
	}
	n->type = TOML_FLOAT;
	n->value.f = f;
	return n;
}

node *new_node_int(long long l) {
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

long utf16toUtf32(long val) {
	unsigned long hu16 =  0xFFFF & (val >> 16);
	unsigned long lu16 = (0xFFFF & val);
	if(hu16 < 0xD800 || 0xDBFF < hu16) {
		return -1;
	}
	if(lu16 < 0xDC00 || 0xDFFF < lu16) {
		return -1;
	}
	return 0x10000 + ((0x3FF & hu16) * 0x400) + (0x3FF & lu16);
}

int utf32toUtf8(long val, char *t, int *j) {
	if(val < 0 || val > 0x10FFFF) {
		return FALSE;
	}
	char utf8[4];
	int len;

	if(val < 0x80) {
		utf8[0] = (char)val;
		len = 1;
	} else if (val < 2048) {
		utf8[0] = (char)(0xC0 | (val >> 6));
		utf8[1] = (char)(0x80 | (val & 0x3F));
		len = 2;
	} else if (val < 65536) {
		utf8[0] = (char)(0xE0 |  (val >> 12)        );
		utf8[1] = (char)(0x80 | ((val >>  6) & 0x3F));
		utf8[2] = (char)(0x80 | ( val        & 0x3F));
		len = 3;
	} else {
		utf8[0] = (char)(0xF0 |  (val >> 18)        );
		utf8[1] = (char)(0x80 | ((val >> 12) & 0x3F));
		utf8[2] = (char)(0x80 | ((val >>  6) & 0x3F));
		utf8[3] = (char)(0x80 | ( val        & 0x3F));
		len = 4;
	}
	for(int i = 0;i < len;i++) {
		t[*j+i] = utf8[i];
	}
	*j += len-1;
	return TRUE;
}

long read_escape_unicode(char *src, int limit) {
	static const char hexdigit[] = "0123456789abcdef0123456789ABCDEF";
	int buf[9];
	long retval = 0;
	char *tmp;
	for(int i = 0;i < limit;i++) {
		if(!ISXDIGIT(src[i])) {
			return -1;
		}
		tmp = (char*)strchr(hexdigit, src[i]);
		retval <<= 4;
		retval |= (tmp - hexdigit) & 15;
	}
	return retval;
}

node *new_node_str(parser_state *p, char *str, int len) {
	long val;
	char *t = (char *)malloc(sizeof(char) * (len+1));
	// memcpy(t, str, len);

	int j = 0;
	for(int i = 0; i < len; i++,j++) {
		if(str[i] == '\\') {
			i++;
			switch(str[i]) {
			case 'b':
				t[j] = 0x08;
				break;
			case 't':
				t[j] = 0x09;
				break;
			case 'n':
				t[j] = 0x0A;
				break;
			case 'f':
				t[j] = 0x0C;
				break;
			case 'r':
				t[j] = 0x0D;
				break;
			case '"':
				t[j] = 0x22;
				break;
			case '/':
				t[j] = 0x2F;
				break;
			case '\\':
				t[j] = 0x5C;
				break;
			case 'u':
				if(i+4 > len) {
					yyerror(p,"invalid escape string");
				} else {
					val = read_escape_unicode(str+i+1,4);
				}
				if(val < 0 || 0xD800 <= val) {
					yyerror(p,"invalid escape string");
				}
				utf32toUtf8(val,t,&j);
				i+=4;
				break;
			case 'U':
				if(i+8 > len) {
					yyerror(p,"invalid escape string");
					i+=8;
					break;
				}
				val = read_escape_unicode(str+i+1,8);
				if(0 < val && val < 0xD800) {
					utf32toUtf8(val,t,&j);
				} else {
					val = utf16toUtf32(val);
					if(0xFFFF < val && val < 0x120000) {
						utf32toUtf8(val,t,&j);
					} else {
						yyerror(p,"invalid escape string");
					}
				}
				i+=8;
				break;
			default:
				yyerror(p,"undefined escape was found.");
			}
			continue;
		}
		t[j] = str[i];
	}
	t[j] = '\0';

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

node *new_node_mulstr(parser_state *p, char *str, int len) {
	char *tmp = (char*)malloc(len * sizeof(char));
	int ignore = FALSE;
	int j = 0;
	for(int i = 0; i < len; i++) {
		if(i == 0) {
			if(str[i] == '\n') {
				continue;
			}else if (str[i] == '\r' && str[i+1] == '\n') {
				i+=1;
				continue;
			}
		}
		if(str[i] == '\\') {
			int c1 = str[i+1];
			if(c1 == '\n') {
				i+=1;
				ignore = TRUE;
				continue;
			}
			int c2 = str[i+2];
			if(c1 == '\r' && c2 == '\n') {
				i+=2;
				ignore = TRUE;
				continue;
			}
			ignore = FALSE;
		}
		if(ignore == TRUE && is_term2(str+i)) {
			continue;
		}
		ignore = FALSE;
		tmp[j] = str[i];
		j++;
	}
	tmp[j] = '\0';
	node *n = new_node_str(p, tmp, j);
	free(tmp);
	return n;
}

int yylex(parser_state *p) {
	int32_t c;
retry:
	c = nextc(p);
	printf("%c(%02X)\n",c,c);
	switch(c) {
	case '\0': /* NUL */
	case -1: /* end of script */
		return 0;
	
	/* white spaces */
	case ' ': case '\r':
		goto retry;

	case '#':  /* it's a comment */
		skip(p, '\n');
		/* fall through */
	case '\n':
		p->lineno++;
		p->column = 0;
		return '\n';
	case '=':
		return c;
	case '_':
		// tBareKey
		goto barekey;
	case '+':
		// tINT
		tokadd(p,c);
		return c;
	case '-':
		// tINT / tFloat / tBareKey
		return c;
	default:
		break;
	}
	if(ISDIGIT(c)) {
		// tINT / tFloat / tDate / tBareKey
	}
	if(ISALPHA(c)) {
		// tBool / tFloat / tBareKey
		if(c == 't') {
			// tTrue / tBareKey
			if(strncmp(p->s,"rue",3) == 0) {
				p->s += 3;
				c = nextc(p);
				if(ISALPHA(c) || c == '_' || c == '-') {
					// tBareKey
					goto barekey;
				} else {
					// tTrue
					backc(p);
					return tTrue;
				}
			} else {
				goto barekey;
			}
		}
		if(c == 'f') {
			// tFalse / tBareKey
			if(strncmp(p->s,"alse",4) == 0) {
				p->s += 4;
				c = nextc(p);
				if(ISALPHA(c) || c == '_' || c == '-') {
					// tBareKey
					goto barekey;
				} else {
					// tFalse
					backc(p);
					return tTrue;
				}
			} else {
				goto barekey;
			}
		}
	}
	if(parser_is_int(p) == TRUE) {
		long long l = conv_ttol(p->tokbuf, p->tlen);
		yylval = new_node_int(l);
		return tINT;
	}
	if(parser_is_float(p) == TRUE) {
		double d = conv_ttof(p->tokbuf, p->tlen);
		yylval = new_node_float(d,p->precision);
		return tFLOAT;
	}
	if(parser_is_multi_string(p) == TRUE) {
		yylval = new_node_mulstr(p,p->tokbuf+3, p->tlen-6);
		return VAL_STRING;
	}
	if(parser_is_string(p) == TRUE) {
		node *n = new_node_str(p, p->tokbuf+1, p->tlen-2);
		if(n == NULL) return 0;
		yylval = n;
		return VAL_STRING;
	}
barekey:
	if(parser_is_key_string(p) == TRUE) {
		yylval = new_node_str(p, p->tokbuf, p->tlen);
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
	// fprintf(stderr, "  count   : %d\n", p->count);
	// fprintf(stderr, "  s  : >>>\n%s\n>>>\n", p->s + p->count);
	// fprintf(stderr, "  current : (%c)\n", p->s[p->count]);
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
	p.s = buf;
	p.send = buf + len;
	p.column = 0;
	p.lineno = 0;
	p.count = 0;
	p.tokbuf = NULL;
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

