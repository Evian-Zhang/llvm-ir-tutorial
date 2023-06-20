; tail_call_test.ll
define fastcc i32 @foo(i32 %a) {
    %res = icmp eq i32 %a, 1
    br i1 %res, label %btrue, label %bfalse
btrue:
    ret i32 1
bfalse:
    %sub = sub i32 %a, 1
    %tail_call = tail call fastcc i32 @foo(i32 %sub)
    ret i32 %tail_call
}
