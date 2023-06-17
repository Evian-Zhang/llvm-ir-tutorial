; for.ll
define i32 @main() {
    %i = alloca i32                               ; int i = ...
    store i32 0, ptr %i                           ; ... = 0
    br label %start
start:
    %i_value = load i32, ptr %i
    %comparison_result = icmp slt i32 %i_value, 4 ; Test if i < 4
    br i1 %comparison_result, label %A, label %B
A:
    ; Do something A
    %1 = add i32 %i_value, 1                      ; ... = i + 1
    store i32 %1, ptr %i                          ; i = ...
    br label %start
B:
    ; Do something B

    ret i32 0
}
