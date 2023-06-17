// try_catch_test.cpp
struct SomeOtherStruct { };
struct AnotherError { };

struct MyError { /* ... */ };
void foo() {
    SomeOtherStruct other_struct;
    throw MyError();
    return;
}

void bar() {
    try {
        foo();
    } catch (MyError err) {
        // do something with err
    } catch (AnotherError err) {
        // do something with err
    } catch (...) {
        // do something
    }
}

int main() {
    return 0;
}