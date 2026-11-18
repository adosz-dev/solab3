#include "types.h"
#include "user.h"

int main(int argc, char *argv[])
{
  if (argc < 4) {
    printf(1, "Bledna liczba parametrow\n");
    exit();
  }
  int a = atoi(argv[1]);
  int b = atoi(argv[3]);

  if (strcmp(argv[2], "+") == 0) {
    printf(1, "%d\n", a+b);
  }
  else if (strcmp(argv[2], "-") == 0) {
    printf(1, "%d\n", a-b);
  }
  else if (strcmp(argv[2], "*") == 0) {
    printf(1, "%d\n", a*b);
  }
  else if (strcmp(argv[2], "/") == 0) {
    if (b == 0) {
      printf(1, "Nie mozna dzielic przez 0\n");
      exit();
    }
    printf(1, "%d\n", a/b);
  }
  exit();
}

