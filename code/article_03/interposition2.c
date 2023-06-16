#include <stdio.h>

void f(void) {
    printf("From interposition2\n");
}

void g(void) {
    f();
}
