; extract_insert_value.ll
%MyStruct = type {
    i32,
    i32
}
@my_struct = global %MyStruct { i32 1, i32 2 }

define i32 @main() {
    %1 = load %MyStruct, ptr @my_struct
    %2 = extractvalue %MyStruct %1, 1
    %3 = insertvalue %MyStruct %1, i32 233, 1

    ret i32 0
}