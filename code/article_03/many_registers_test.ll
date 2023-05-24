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

	store i32 %1, i32* @global_variable
	store i32 %2, i32* @global_variable
	store i32 %3, i32* @global_variable
	store i32 %4, i32* @global_variable
	store i32 %5, i32* @global_variable
	store i32 %6, i32* @global_variable
	store i32 %7, i32* @global_variable
	store i32 %8, i32* @global_variable
	store i32 %9, i32* @global_variable
	store i32 %10, i32* @global_variable
	store i32 %11, i32* @global_variable
	store i32 %12, i32* @global_variable
	store i32 %13, i32* @global_variable
	store i32 %14, i32* @global_variable
	store i32 %15, i32* @global_variable

	ret i32 0
}