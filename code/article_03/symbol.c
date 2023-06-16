int a;
extern int b;
static int c;
void d(void);
void e(void) {}
static void f(void) {}

int use_all(void) {
    d();
    e();
    f();
    return a + b + c;
}
