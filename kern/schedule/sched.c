#include <list.h>
#include <sync.h>
#include <proc.h>
#include <sched.h>
#include <assert.h>

void
wakeup_proc(struct proc_struct *proc) {
    assert(proc->state != PROC_ZOMBIE && proc->state != PROC_RUNNABLE);
    proc->state = PROC_RUNNABLE;
}

//LAB4 function3 2411438_2411513
// schedule - 在 proc_list 中挑选下一个就绪线程并切换到它
//   采用最简单的 FIFO（Round-Robin 轮转）策略：
//   1. 先把当前线程的 need_resched 清 0；
//   2. 从当前线程的下一个位置开始找，若当前是 idleproc 则从链表头开始找，
//      保证所有线程机会均等；
//   3. 找不到就绪线程时退回 idleproc 保底；
//   4. 通过 proc_run 完成页表和上下文切换。
//   整个查找与切换过程都在关中断的临界区内完成，保证调度的原子性。
void schedule(void) {
    bool intr_flag;
    list_entry_t *le, *last;
    struct proc_struct *next = NULL;
    local_intr_save(intr_flag);
    {
        current->need_resched = 0;
        // current 不是 idleproc 时从它的下一个位置找，实现轮转
        last = (current == idleproc) ? &proc_list : &(current->list_link);
        le = last;
        do {
            if ((le = list_next(le)) != &proc_list) {
                next = le2proc(le, list_link);
                if (next->state == PROC_RUNNABLE) {
                    break;
                }
            }
        } while (le != last);
        if (next == NULL || next->state != PROC_RUNNABLE) {
            // 没有就绪线程，用 idleproc 保底
            next = idleproc;
        }
        next->runs ++;
        if (next != current) {
            proc_run(next);
        }
    }
    local_intr_restore(intr_flag);
}



