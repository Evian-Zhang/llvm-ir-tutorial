; register_test.ll
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

define i32 @main() {
	%local_variable = add i32 1, 2
	ret i32 %local_variable
}