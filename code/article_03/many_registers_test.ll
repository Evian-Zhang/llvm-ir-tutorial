; many_registers_test.ll
@global_variable = global i32 0

define i32 @main() {
	%1 = add i32 1, 2
	%2 = add i32 1, 2
	%3 = add i32 1, 2
	%4 = add i32 1, 2
	%5 = add i32 1, 2
	%6 = add i32 1, 2
	%7 = add i32 1, 2
	%8 = add i32 1, 2
	%9 = add i32 1, 2
	%10 = add i32 1, 2
	%11 = add i32 1, 2
	%12 = add i32 1, 2
	%13 = add i32 1, 2
	%14 = add i32 1, 2
	%15 = add i32 1, 2

	store i32 %1, ptr @global_variable
	store i32 %2, ptr @global_variable
	store i32 %3, ptr @global_variable
	store i32 %4, ptr @global_variable
	store i32 %5, ptr @global_variable
	store i32 %6, ptr @global_variable
	store i32 %7, ptr @global_variable
	store i32 %8, ptr @global_variable
	store i32 %9, ptr @global_variable
	store i32 %10, ptr @global_variable
	store i32 %11, ptr @global_variable
	store i32 %12, ptr @global_variable
	store i32 %13, ptr @global_variable
	store i32 %14, ptr @global_variable
	store i32 %15, ptr @global_variable

	ret i32 0
}
