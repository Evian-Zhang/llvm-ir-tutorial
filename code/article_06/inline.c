inline int foo(int a) __attribute__((always_inline));

int foo(int a) {
    if (a > 0) {
        return a;
    } else {
        return 0;
    }
}
