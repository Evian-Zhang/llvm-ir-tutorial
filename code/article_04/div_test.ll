; div_test.ll
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

define i8 @main() {
	%1 = udiv i8 -6, 2
	%2 = sdiv i8 -6, 2
	
	ret i8 %1
}