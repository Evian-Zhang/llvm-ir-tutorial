; register_test.ll
define i32 @main() {
    %local_variable = add i32 1, 2
    ret i32 %local_variable
}
