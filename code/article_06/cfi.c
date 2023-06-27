typedef void (*f)(void);

void foo1(void) {}
void foo2(void) {}
void bar(int a) {}

void baz(f func) {
    func();
}
