; This file is a part of Julia. License is MIT: https://julialang.org/license

; RUN: opt -enable-new-pm=0 --opaque-pointers=0 -load libjulia-codegen%shlibext -LateLowerGCFrame -S %s | FileCheck %s -check-prefixes=CHECK,TYPED
; RUN: opt -enable-new-pm=1 --opaque-pointers=0 --load-pass-plugin=libjulia-codegen%shlibext -passes='function(LateLowerGCFrame)' -S %s | FileCheck %s -check-prefixes=CHECK,TYPED

; RUN: opt -enable-new-pm=0 --opaque-pointers=1 -load libjulia-codegen%shlibext -LateLowerGCFrame -S %s | FileCheck %s --check-prefixes=CHECK,OPAQUE
; RUN: opt -enable-new-pm=1 --opaque-pointers=1 --load-pass-plugin=libjulia-codegen%shlibext -passes='function(LateLowerGCFrame)' -S %s | FileCheck %s --check-prefixes=CHECK,OPAQUE

@tag = external addrspace(10) global {}, align 16

declare void @boxed_simple({} addrspace(10)*, {} addrspace(10)*)
declare {} addrspace(10)* @jl_box_int64(i64)
declare {}*** @julia.get_pgcstack()
declare void @jl_safepoint()
declare {} addrspace(10)* @jl_apply_generic({} addrspace(10)*, {} addrspace(10)**, i32)
declare noalias nonnull {} addrspace(10)* @julia.gc_alloc_obj({}**, i64, {} addrspace(10)*)
declare i32 @rooting_callee({} addrspace(12)*, {} addrspace(12)*)

define void @gc_frame_lowering(i64 %a, i64 %b) {
top:
; CHECK-LABEL: @gc_frame_lowering
; TYPED: %gcframe = call {} addrspace(10)** @julia.new_gc_frame(i32 2)
; TYPED:  %pgcstack = call {}*** @julia.get_pgcstack()

; OPAQUE: %gcframe = call ptr @julia.new_gc_frame(i32 2)
; OPAQUE:  %pgcstack = call ptr @julia.get_pgcstack()
    %pgcstack = call {}*** @julia.get_pgcstack()
; TYPED-NEXT: call void @julia.push_gc_frame({} addrspace(10)** %gcframe, i32 2)
; TYPED-NEXT: call {} addrspace(10)* @jl_box_int64

; OPAQUE-NEXT: call void @julia.push_gc_frame(ptr %gcframe, i32 2)
; OPAQUE-NEXT: call ptr addrspace(10) @jl_box_int64
    %aboxed = call {} addrspace(10)* @jl_box_int64(i64 signext %a)
; TYPED: [[GEP0:%.*]] = call {} addrspace(10)** @julia.get_gc_frame_slot({} addrspace(10)** %gcframe, i32 [[GEPSLOT0:[0-9]+]])
; TYPED-NEXT: store {} addrspace(10)* %aboxed, {} addrspace(10)** [[GEP0]]

; OPAQUE: [[GEP0:%.*]] = call ptr @julia.get_gc_frame_slot(ptr %gcframe, i32 [[GEPSLOT0:[0-9]+]])
; OPAQUE-NEXT: store ptr addrspace(10) %aboxed, ptr [[GEP0]]
    %bboxed = call {} addrspace(10)* @jl_box_int64(i64 signext %b)
; CHECK-NEXT: %bboxed =
; Make sure the same gc slot isn't re-used
; TYPED-NOT: call {} addrspace(10)** @julia.get_gc_frame_slot({} addrspace(10)** %gcframe, i32 [[GEPSLOT0]])
; TYPED: [[GEP1:%.*]] = call {} addrspace(10)** @julia.get_gc_frame_slot({} addrspace(10)** %gcframe, i32 [[GEPSLOT1:[0-9]+]])
; TYPED-NEXT: store {} addrspace(10)* %bboxed, {} addrspace(10)** [[GEP1]]

; OPAQUE-NOT: call ptr @julia.get_gc_frame_slot(ptr %gcframe, i32 [[GEPSLOT0]])
; OPAQUE: [[GEP1:%.*]] = call ptr @julia.get_gc_frame_slot(ptr %gcframe, i32 [[GEPSLOT1:[0-9]+]])
; OPAQUE-NEXT: store ptr addrspace(10) %bboxed, ptr [[GEP1]]

; CHECK-NEXT: call void @boxed_simple
    call void @boxed_simple({} addrspace(10)* %aboxed,
                            {} addrspace(10)* %bboxed)
; TYPED-NEXT: call void @julia.pop_gc_frame({} addrspace(10)** %gcframe)
; OPAQUE-NEXT: call void @julia.pop_gc_frame(ptr %gcframe)
    ret void
}

define {} addrspace(10)* @gc_alloc_lowering() {
top:
; CHECK-LABEL: @gc_alloc_lowering
    %pgcstack = call {}*** @julia.get_pgcstack()
    %0 = bitcast {}*** %pgcstack to {}**
    %current_task = getelementptr inbounds {}*, {}** %0, i64 -12
; TYPED: %current_task = getelementptr inbounds {}*, {}** %0, i64 -12
; TYPED-NEXT: [[ptls_field:%.*]] = getelementptr inbounds {}*, {}** %current_task, i64 16
; TYPED-NEXT: [[ptls_load:%.*]] = load {}*, {}** [[ptls_field]], align 8, !tbaa !0
; TYPED-NEXT: [[ppjl_ptls:%.*]] = bitcast {}* [[ptls_load]] to {}**
; TYPED-NEXT: [[ptls_i8:%.*]] = bitcast {}** [[ppjl_ptls]] to i8*
; TYPED-NEXT: %v = call {} addrspace(10)* @julia.gc_alloc_bytes(i8* [[ptls_i8]], [[SIZE_T:i.[0-9]+]] 8)
; TYPED-NEXT: [[V2:%.*]] = bitcast {} addrspace(10)* %v to {} addrspace(10)* addrspace(10)*
; TYPED-NEXT: [[V_HEADROOM:%.*]] = getelementptr inbounds {} addrspace(10)*, {} addrspace(10)* addrspace(10)* [[V2]], i64 -1
; TYPED-NEXT: store atomic {} addrspace(10)* @tag, {} addrspace(10)* addrspace(10)* [[V_HEADROOM]] unordered, align 8, !tbaa !4

; OPAQUE: %current_task = getelementptr inbounds ptr, ptr %0, i64 -12
; OPAQUE-NEXT: [[ptls_field:%.*]] = getelementptr inbounds ptr, ptr %current_task, i64 16
; OPAQUE-NEXT: [[ptls_load:%.*]] = load ptr, ptr [[ptls_field]], align 8, !tbaa !0
; OPAQUE-NEXT: %v = call ptr addrspace(10) @julia.gc_alloc_bytes(ptr [[ptls_load]], [[SIZE_T:i.[0-9]+]] 8)
; OPAQUE-NEXT: [[V_HEADROOM:%.*]] = getelementptr inbounds ptr addrspace(10), ptr addrspace(10) %v, i64 -1
; OPAQUE-NEXT: store atomic ptr addrspace(10) @tag, ptr addrspace(10) [[V_HEADROOM]] unordered, align 8, !tbaa !4
    %v = call noalias {} addrspace(10)* @julia.gc_alloc_obj({}** %current_task, i64 8, {} addrspace(10)* @tag)
; TYPED-NEXT: ret {} addrspace(10)* %v
; OPAQUE-NEXT: ret ptr addrspace(10) %v
    ret {} addrspace(10)* %v
}

; Confirm that loadedval instruction does not contain invariant.load metadata
; after the gc placement pass, but still contains the range metadata.
; Since loadedval is marked invariant, passes are allowed to move the use.
; But after the placement pass, must ensure it won't be relocated after our
; last gc-root use
define void @gc_drop_aliasing() {
top:
; CHECK-LABEL: @gc_drop_aliasing
    %pgcstack = call {}*** @julia.get_pgcstack()
    %0 = bitcast {}*** %pgcstack to {}**
    %current_task = getelementptr inbounds {}*, {}** %0, i64 -12
; TYPED: %current_task = getelementptr inbounds {}*, {}** %0, i64 -12
; TYPED-NEXT: [[ptls_field:%.*]] = getelementptr inbounds {}*, {}** %current_task, i64 16
; TYPED-NEXT: [[ptls_load:%.*]] = load {}*, {}** [[ptls_field]], align 8, !tbaa !0
; TYPED-NEXT: [[ppjl_ptls:%.*]] = bitcast {}* [[ptls_load]] to {}**
; TYPED-NEXT: [[ptls_i8:%.*]] = bitcast {}** [[ppjl_ptls]] to i8*
; TYPED-NEXT: %v = call {} addrspace(10)* @julia.gc_alloc_bytes(i8* [[ptls_i8]], [[SIZE_T:i.[0-9]+]] 8)
; TYPED-NEXT: [[V2:%.*]] = bitcast {} addrspace(10)* %v to {} addrspace(10)* addrspace(10)*
; TYPED-NEXT: [[V_HEADROOM:%.*]] = getelementptr inbounds {} addrspace(10)*, {} addrspace(10)* addrspace(10)* [[V2]], i64 -1
; TYPED-NEXT: store atomic {} addrspace(10)* @tag, {} addrspace(10)* addrspace(10)* [[V_HEADROOM]] unordered, align 8, !tbaa !4

; OPAQUE: %current_task = getelementptr inbounds ptr, ptr %0, i64 -12
; OPAQUE-NEXT: [[ptls_field:%.*]] = getelementptr inbounds ptr, ptr %current_task, i64 16
; OPAQUE-NEXT: [[ptls_load:%.*]] = load ptr, ptr [[ptls_field]], align 8, !tbaa !0
; OPAQUE-NEXT: %v = call ptr addrspace(10) @julia.gc_alloc_bytes(ptr [[ptls_load]], [[SIZE_T:i.[0-9]+]] 8)
; OPAQUE-NEXT: [[V_HEADROOM:%.*]] = getelementptr inbounds ptr addrspace(10), ptr addrspace(10) %v, i64 -1
; OPAQUE-NEXT: store atomic ptr addrspace(10) @tag, ptr addrspace(10) [[V_HEADROOM]] unordered, align 8, !tbaa !4
    %v = call noalias {} addrspace(10)* @julia.gc_alloc_obj({}** %current_task, i64 8, {} addrspace(10)* @tag)
; TYPED-NEXT: %v64 = bitcast {} addrspace(10)* %v to i64 addrspace(10)*
; OPAQUE-NEXT: %v64 = bitcast ptr addrspace(10) %v to ptr addrspace(10)
    %v64 = bitcast {} addrspace(10)* %v to i64 addrspace(10)*
; TYPED-NEXT: %loadedval = load i64, i64 addrspace(10)* %v64, align 8, !range !7
; OPAQUE-NEXT: %loadedval = load i64, ptr addrspace(10) %v64, align 8, !range !7
    %loadedval = load i64, i64 addrspace(10)* %v64, align 8, !range !0, !invariant.load !1
; TYPED-NEXT: store i64 %loadedval, i64 addrspace(10)* %v64, align 8, !noalias !8
; OPAQUE-NEXT: store i64 %loadedval, ptr addrspace(10) %v64, align 8, !noalias !8
    store i64 %loadedval, i64 addrspace(10)* %v64, align 8, !noalias !2
; TYPED-NEXT: %lv2 = load i64, i64 addrspace(10)* %v64, align 8, !tbaa !11, !range !7
; OPAQUE-NEXT: %lv2 = load i64, ptr addrspace(10) %v64, align 8, !tbaa !11, !range !7
    %lv2 = load i64, i64 addrspace(10)* %v64, align 8, !range !0, !tbaa !4
; CHECK-NEXT: ret void
    ret void
}

define i32 @callee_root({} addrspace(10)* %v0, {} addrspace(10)* %v1) {
top:
; CHECK-LABEL: @callee_root
; CHECK-NOT: @julia.new_gc_frame
  %v2 = call {}*** @julia.get_pgcstack()
  %v3 = bitcast {} addrspace(10)* %v0 to {} addrspace(10)* addrspace(10)*
  %v4 = addrspacecast {} addrspace(10)* addrspace(10)* %v3 to {} addrspace(10)* addrspace(11)*
  %v5 = load atomic {} addrspace(10)*, {} addrspace(10)* addrspace(11)* %v4 unordered, align 8
  %v6 = bitcast {} addrspace(10)* %v1 to {} addrspace(10)* addrspace(10)*
  %v7 = addrspacecast {} addrspace(10)* addrspace(10)* %v6 to {} addrspace(10)* addrspace(11)*
  %v8 = load atomic {} addrspace(10)*, {} addrspace(10)* addrspace(11)* %v7 unordered, align 8
  %v9 = addrspacecast {} addrspace(10)* %v5 to {} addrspace(12)*
  %v10 = addrspacecast {} addrspace(10)* %v8 to {} addrspace(12)*
  %v11 = call i32 @rooting_callee({} addrspace(12)* %v9, {} addrspace(12)* %v10)
  ret i32 %v11
; CHECK: ret i32
}

define i32 @freeze({} addrspace(10)* %v0, {} addrspace(10)* %v1) {
top:
; CHECK-LABEL: @freeze
; CHECK-NOT: @julia.new_gc_frame
  %v2 = call {}*** @julia.get_pgcstack()
  %v3 = bitcast {} addrspace(10)* %v0 to {} addrspace(10)* addrspace(10)*
  %v4 = addrspacecast {} addrspace(10)* addrspace(10)* %v3 to {} addrspace(10)* addrspace(11)*
  %v5 = load atomic {} addrspace(10)*, {} addrspace(10)* addrspace(11)* %v4 unordered, align 8
  %v6 = bitcast {} addrspace(10)* %v1 to {} addrspace(10)* addrspace(10)*
  %v7 = addrspacecast {} addrspace(10)* addrspace(10)* %v6 to {} addrspace(10)* addrspace(11)*
  %v8 = load atomic {} addrspace(10)*, {} addrspace(10)* addrspace(11)* %v7 unordered, align 8
  %fv8 = freeze {} addrspace(10)* %v8
  %v9 = addrspacecast {} addrspace(10)* %v5 to {} addrspace(12)*
  %v10 = addrspacecast {} addrspace(10)* %fv8 to {} addrspace(12)*
  %v11 = call i32 @rooting_callee({} addrspace(12)* %v9, {} addrspace(12)* %v10)
  ret i32 %v11
; CHECK: ret i32
}

; COM: the bugs here may be caught by death-by-verify-assertion
define {} addrspace(10)* @gclift_switch({} addrspace(13)* addrspace(10)* %input, i1 %unpredictable) {
  top:
  %0 = call {}*** @julia.get_pgcstack()
  br i1 %unpredictable, label %mid1, label %mid2
  mid1:
  br label %mid2
  mid2:
  %root = phi {} addrspace(13)* addrspace(10)* [ %input, %top ], [ %input, %mid1 ]
  %unrelated = phi i1 [ %unpredictable, %top ], [ %unpredictable, %mid1 ]
  %1 = addrspacecast {} addrspace(13)* addrspace(10)* %root to {} addrspace(13)* addrspace(11)*
  %2 = bitcast {} addrspace(13)* addrspace(11)* %1 to {} addrspace(11)*
  switch i1 %unpredictable, label %end [
    i1 1, label %end
    i1 0, label %end
  ]
  end:
  %phi = phi {} addrspace(11)* [ %2, %mid2 ], [ %2, %mid2 ], [ %2, %mid2 ]
  %ret = bitcast {} addrspace(13)* addrspace(10)* %input to {} addrspace(10)*
  ; CHECK: %gclift
  ret {} addrspace(10)* %ret
}

define void @decayar([2 x {} addrspace(10)* addrspace(11)*] %ar) {
  %v2 = call {}*** @julia.get_pgcstack()
  %e0 = extractvalue [2 x {} addrspace(10)* addrspace(11)*] %ar, 0
  %l0 = load {} addrspace(10)*, {} addrspace(10)* addrspace(11)* %e0
  %e1 = extractvalue [2 x {} addrspace(10)* addrspace(11)*] %ar, 1
  %l1 = load {} addrspace(10)*, {} addrspace(10)* addrspace(11)* %e1
  %r = call i32 @callee_root({} addrspace(10)* %l0, {} addrspace(10)* %l1)
  ret void
}

; CHECK-LABEL: @decayar
; TYPED:  %gcframe = call {} addrspace(10)** @julia.new_gc_frame(i32 2)
; TYPED:  [[gc_slot_addr_:%.*]] = call {} addrspace(10)** @julia.get_gc_frame_slot({} addrspace(10)** %gcframe, i32 1)
; TYPED:  store {} addrspace(10)* %l0, {} addrspace(10)** [[gc_slot_addr_:%.*]], align 8
; TYPED:  [[gc_slot_addr_:%.*]] = call {} addrspace(10)** @julia.get_gc_frame_slot({} addrspace(10)** %gcframe, i32 0)
; TYPED: store {} addrspace(10)* %l1, {} addrspace(10)** [[gc_slot_addr_:%.*]], align 8
; TYPED: %r = call i32 @callee_root({} addrspace(10)* %l0, {} addrspace(10)* %l1)
; TYPED: call void @julia.pop_gc_frame({} addrspace(10)** %gcframe)

; OPAQUE:  %gcframe = call ptr @julia.new_gc_frame(i32 2)
; OPAQUE: [[gc_slot_addr_:%.*]]1 = call ptr @julia.get_gc_frame_slot(ptr %gcframe, i32 1)
; OPAQUE:  store ptr addrspace(10) %l0, ptr [[gc_slot_addr_:%.*]], align 8
; OPAQUE:  [[gc_slot_addr_:%.*]] = call ptr @julia.get_gc_frame_slot(ptr %gcframe, i32 0)
; OPAQUE: store ptr addrspace(10) %l1, ptr [[gc_slot_addr_:%.*]], align 8
; OPAQUE: %r = call i32 @callee_root(ptr addrspace(10) %l0, ptr addrspace(10) %l1)
; OPAQUE: call void @julia.pop_gc_frame(ptr %gcframe)

!0 = !{i64 0, i64 23}
!1 = !{!1}
!2 = !{!7} ; scope list
!3 = !{!4, !4, i64 0, i64 1}
!4 = !{!"jtbaa_const", !5}
!5 = !{!"jtbaa"}
!6 = distinct !{!6} ; alias domain
!7 = distinct !{!7, !6} ; alias scope


; CHECK:      !0 = !{!1, !1, i64 0}
; CHECK-NEXT: !1 = !{!"jtbaa_gcframe", !2, i64 0}
; CHECK-NEXT: !2 = !{!"jtbaa", !3, i64 0}
; CHECK-NEXT: !3 = !{!"jtbaa"}
; CHECK-NEXT: !4 = !{!5, !5, i64 0}
; CHECK-NEXT: !5 = !{!"jtbaa_tag", !6, i64 0}
; CHECK-NEXT: !6 = !{!"jtbaa_data", !2, i64 0}
; CHECK-NEXT: !7 = !{i64 0, i64 23}
; CHECK-NEXT: !8 = !{!9}
; CHECK-NEXT: !9 = distinct !{!9, !10}
; CHECK-NEXT: !10 = distinct !{!10}
; CHECK-NEXT: !11 = !{!12, !12, i64 0}
; CHECK-NEXT: !12 = !{!"jtbaa_const", !3}
