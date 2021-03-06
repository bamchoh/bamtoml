#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <io.h>
#include <sys/stat.h>
#include <ctype.h>
#include <math.h>
#include <share.h>
#include "toml_str.h"
#include "toml_tbl.h"
#include "toml.h"

#if defined(_WIN32)
# include <windows.h>
# include <io.h>
#ifdef _MSC_VER
# define isatty(x) _isatty(x)
# define fileno(x) _fileno(x)
#endif
#endif

#ifndef _WIN32
#define _fdopen fdopen
#endif

static void
printstr(char *str)
{
#if defined(_WIN32)
  if (isatty(fileno(stdout))) {
    DWORD written;
    char* utf8 = str;
    int mlen = strlen(str);
    int wlen = MultiByteToWideChar(CP_UTF8, 0, utf8, mlen, NULL, 0);
    wchar_t* utf16 = (wchar_t*)malloc((wlen+1) * sizeof(wchar_t));
    if (utf16 == NULL) return;
    if (MultiByteToWideChar(CP_UTF8, 0, utf8, mlen, utf16, wlen) > 0) {
      utf16[wlen] = 0;
      WriteConsoleW(GetStdHandle(STD_OUTPUT_HANDLE),
          utf16, wlen, &written, NULL);
    }
    free(utf16);
  } else
#endif
    fwrite(str, strlen(str), 1, stdout);
  fflush(stdout);
}

void print_all_node(node *n) {
  toml_table *tbl = (toml_table *)n->value.p;
  printf("count : %d\n", tbl->count);
  for(int i = 0; i < tbl->count; i++) {
    switch(tbl->v[i]->type) {
      case TOML_STRING: {
                          toml_string *tmp2 = (toml_string *)tbl->v[i]->value.p;
                          printf("  [TOML_STR  ]%s = \"",tbl->k[i]);
                          printstr(tmp2->s);
                          printf("\"\n");
                          break;
                        }
      case TOML_BOOL:
                        if(tbl->v[i]->value.i == 0) {
                          printf("  [TOML_BOOL ]%s = false\n", tbl->k[i]);
                        } else {
                          printf("  [TOML_BOOL ]%s = true\n", tbl->k[i]);
                        }
                        break;
      case TOML_INT:
                        printf("  [TOML_INT  ]%s = %lld\n", tbl->k[i], tbl->v[i]->value.i);
                        break;
      case TOML_FLOAT:
                        printf("  [TOML_FLOAT]%s = %.*lf\n", tbl->k[i], tbl->v[i]->value.f->p, tbl->v[i]->value.f->v);
                        break;
    }
  }
}

int main(int argc, char* argv[])
{
  if(argc <= 1) {
    fprintf(stderr, "file name is needed\n");
    exit(1);
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
  int result;
  result = _fstat(fd, &stbuf);
  if(result != 0) {
    fprintf(stderr, "fstat error\n");
    exit(1);
  }
  file_size = stbuf.st_size;
  _close(fd);
  buffer = (char*)calloc(file_size+1, sizeof(char));
  if (buffer == NULL) {
    fprintf(stderr, "malloc error\n");
    exit(1);
  }
  errno_t err;
  err = fopen_s(&fp, argv[1], "rb");
  if(err != 0) {
    fprintf(stderr, "fdopen error\n");
    exit(1);
  }
  for(int i = 0; (c = fgetc(fp)) != -1; i++) {
    buffer[i] = c;
  }
  buffer[file_size] = '\0';
  fclose(fp);
  for(int i = 0; i < 1;i++) {
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
    print_all_node(root);
    toml_free(root);
  }

  return 0;
}
