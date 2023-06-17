; div_test.ll
define i8 @main() {
    %1 = udiv i8 -6, 2
    %2 = sdiv i8 -6, 2

    ret i8 %1
}
