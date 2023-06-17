; for.ll
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

define i32 @main() {
    %i = alloca i32 ; int i = ...
    store i32 0, i32* %i ; ... = 0
    br label %start
start:
    %i_value = load i32, i32* %i
    %comparison_result = icmp slt i32 %i_value, 4 ; test if i < a
    br i1 %comparison_result, label %A, label %B
A:
    ; do something A
    %1 = add i32 %i_value, 1 ; ... = i + 1
    store i32 %1, i32* %i ; i = ...
    br label %start
B:
    ; do something B

    ret i32 0
}