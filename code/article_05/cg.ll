; cg.ll
define void @foo1() {
  call void @foo4(i32 0)
  ret void
}

declare void @foo2()
declare void @foo3()

define void @foo4(i32 %0) {
  %comparison_result = icmp sgt i32 %0, 0
  br i1 %comparison_result, label %true_branch, label %false_branch

true_branch:
  call void @foo1()
  br label %final

false_branch:
  call void @foo2()
  br label %final

final:
  call void @foo3()
  ret void
}
