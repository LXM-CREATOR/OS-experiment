
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    # a1: dtb physical address
    # 此时尚未开启分页，不能直接用高虚拟地址访问 boot_hartid/boot_dtb。
    # a0、a1 在下面的页表设置过程中不会被改写，开启分页后再保存。

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39)
ffffffffc0200000:	c02052b7          	lui	t0,0xc0205
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
ffffffffc0200004:	ffd0031b          	addiw	t1,zero,-3
ffffffffc0200008:	037a                	slli	t1,t1,0x1e
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
ffffffffc020000a:	406282b3          	sub	t0,t0,t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12
ffffffffc020000e:	00c2d293          	srli	t0,t0,0xc

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60
ffffffffc0200012:	fff0031b          	addiw	t1,zero,-1
ffffffffc0200016:	137e                	slli	t1,t1,0x3f
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1
ffffffffc0200018:	0062e2b3          	or	t0,t0,t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
ffffffffc020001c:	18029073          	csrw	satp,t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
ffffffffc0200020:	12000073          	sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop

    # 高地址映射已经生效，现在可以安全地保存 OpenSBI 传入的启动参数。
    la t0, boot_hartid
ffffffffc0200024:	00006297          	auipc	t0,0x6
ffffffffc0200028:	fdc28293          	addi	t0,t0,-36 # ffffffffc0206000 <boot_hartid>
    sd a0, 0(t0)
ffffffffc020002c:	00a2b023          	sd	a0,0(t0)
    la t0, boot_dtb
ffffffffc0200030:	00006297          	auipc	t0,0x6
ffffffffc0200034:	fd828293          	addi	t0,t0,-40 # ffffffffc0206008 <boot_dtb>
    sd a1, 0(t0)
ffffffffc0200038:	00b2b023          	sd	a1,0(t0)
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)
ffffffffc020003c:	c0205137          	lui	sp,0xc0205

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 跳转到 kern_init
    lui t0, %hi(kern_init)
ffffffffc0200040:	c02002b7          	lui	t0,0xc0200
    addi t0, t0, %lo(kern_init)
ffffffffc0200044:	0d628293          	addi	t0,t0,214 # ffffffffc02000d6 <kern_init>
    jr t0
ffffffffc0200048:	8282                	jr	t0

ffffffffc020004a <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
ffffffffc020004a:	1141                	addi	sp,sp,-16 # ffffffffc0204ff0 <bootstack+0x1ff0>
    extern char etext[], edata[], end[];
    cprintf("Special kernel symbols:\n");
ffffffffc020004c:	00002517          	auipc	a0,0x2
ffffffffc0200050:	e0450513          	addi	a0,a0,-508 # ffffffffc0201e50 <etext+0x6>
void print_kerninfo(void) {
ffffffffc0200054:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc0200056:	0fc000ef          	jal	ffffffffc0200152 <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005a:	00000597          	auipc	a1,0x0
ffffffffc020005e:	07c58593          	addi	a1,a1,124 # ffffffffc02000d6 <kern_init>
ffffffffc0200062:	00002517          	auipc	a0,0x2
ffffffffc0200066:	e0e50513          	addi	a0,a0,-498 # ffffffffc0201e70 <etext+0x26>
ffffffffc020006a:	0e8000ef          	jal	ffffffffc0200152 <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc020006e:	00002597          	auipc	a1,0x2
ffffffffc0200072:	ddc58593          	addi	a1,a1,-548 # ffffffffc0201e4a <etext>
ffffffffc0200076:	00002517          	auipc	a0,0x2
ffffffffc020007a:	e1a50513          	addi	a0,a0,-486 # ffffffffc0201e90 <etext+0x46>
ffffffffc020007e:	0d4000ef          	jal	ffffffffc0200152 <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200082:	00006597          	auipc	a1,0x6
ffffffffc0200086:	f9658593          	addi	a1,a1,-106 # ffffffffc0206018 <free_area>
ffffffffc020008a:	00002517          	auipc	a0,0x2
ffffffffc020008e:	e2650513          	addi	a0,a0,-474 # ffffffffc0201eb0 <etext+0x66>
ffffffffc0200092:	0c0000ef          	jal	ffffffffc0200152 <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc0200096:	00006597          	auipc	a1,0x6
ffffffffc020009a:	0a658593          	addi	a1,a1,166 # ffffffffc020613c <end>
ffffffffc020009e:	00002517          	auipc	a0,0x2
ffffffffc02000a2:	e3250513          	addi	a0,a0,-462 # ffffffffc0201ed0 <etext+0x86>
ffffffffc02000a6:	0ac000ef          	jal	ffffffffc0200152 <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
ffffffffc02000aa:	00000717          	auipc	a4,0x0
ffffffffc02000ae:	02c70713          	addi	a4,a4,44 # ffffffffc02000d6 <kern_init>
ffffffffc02000b2:	00006797          	auipc	a5,0x6
ffffffffc02000b6:	48978793          	addi	a5,a5,1161 # ffffffffc020653b <end+0x3ff>
ffffffffc02000ba:	8f99                	sub	a5,a5,a4
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000bc:	43f7d593          	srai	a1,a5,0x3f
}
ffffffffc02000c0:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000c2:	3ff5f593          	andi	a1,a1,1023
ffffffffc02000c6:	95be                	add	a1,a1,a5
ffffffffc02000c8:	85a9                	srai	a1,a1,0xa
ffffffffc02000ca:	00002517          	auipc	a0,0x2
ffffffffc02000ce:	e2650513          	addi	a0,a0,-474 # ffffffffc0201ef0 <etext+0xa6>
}
ffffffffc02000d2:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000d4:	a8bd                	j	ffffffffc0200152 <cprintf>

ffffffffc02000d6 <kern_init>:

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc02000d6:	00006517          	auipc	a0,0x6
ffffffffc02000da:	f4250513          	addi	a0,a0,-190 # ffffffffc0206018 <free_area>
ffffffffc02000de:	00006617          	auipc	a2,0x6
ffffffffc02000e2:	05e60613          	addi	a2,a2,94 # ffffffffc020613c <end>
int kern_init(void) {
ffffffffc02000e6:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc02000e8:	8e09                	sub	a2,a2,a0
ffffffffc02000ea:	4581                	li	a1,0
int kern_init(void) {
ffffffffc02000ec:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc02000ee:	54b010ef          	jal	ffffffffc0201e38 <memset>
    dtb_init();
ffffffffc02000f2:	144000ef          	jal	ffffffffc0200236 <dtb_init>
    cons_init();  // init the console
ffffffffc02000f6:	136000ef          	jal	ffffffffc020022c <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc02000fa:	00002517          	auipc	a0,0x2
ffffffffc02000fe:	7d650513          	addi	a0,a0,2006 # ffffffffc02028d0 <etext+0xa86>
ffffffffc0200102:	084000ef          	jal	ffffffffc0200186 <cputs>

    print_kerninfo();
ffffffffc0200106:	f45ff0ef          	jal	ffffffffc020004a <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc020010a:	705000ef          	jal	ffffffffc020100e <pmm_init>

    // Lab2 task 4: initialize the small-object allocator and run its checks.
    slub_init();
ffffffffc020010e:	0b6010ef          	jal	ffffffffc02011c4 <slub_init>
    slub_check();
ffffffffc0200112:	5a8010ef          	jal	ffffffffc02016ba <slub_check>

    /* do nothing */
    while (1)
ffffffffc0200116:	a001                	j	ffffffffc0200116 <kern_init+0x40>

ffffffffc0200118 <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
ffffffffc0200118:	1141                	addi	sp,sp,-16
ffffffffc020011a:	e022                	sd	s0,0(sp)
ffffffffc020011c:	e406                	sd	ra,8(sp)
ffffffffc020011e:	842e                	mv	s0,a1
    cons_putc(c);
ffffffffc0200120:	10e000ef          	jal	ffffffffc020022e <cons_putc>
    (*cnt) ++;
ffffffffc0200124:	401c                	lw	a5,0(s0)
}
ffffffffc0200126:	60a2                	ld	ra,8(sp)
    (*cnt) ++;
ffffffffc0200128:	2785                	addiw	a5,a5,1
ffffffffc020012a:	c01c                	sw	a5,0(s0)
}
ffffffffc020012c:	6402                	ld	s0,0(sp)
ffffffffc020012e:	0141                	addi	sp,sp,16
ffffffffc0200130:	8082                	ret

ffffffffc0200132 <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
ffffffffc0200132:	1101                	addi	sp,sp,-32
ffffffffc0200134:	862a                	mv	a2,a0
ffffffffc0200136:	86ae                	mv	a3,a1
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200138:	00000517          	auipc	a0,0x0
ffffffffc020013c:	fe050513          	addi	a0,a0,-32 # ffffffffc0200118 <cputch>
ffffffffc0200140:	006c                	addi	a1,sp,12
vcprintf(const char *fmt, va_list ap) {
ffffffffc0200142:	ec06                	sd	ra,24(sp)
    int cnt = 0;
ffffffffc0200144:	c602                	sw	zero,12(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200146:	0db010ef          	jal	ffffffffc0201a20 <vprintfmt>
    return cnt;
}
ffffffffc020014a:	60e2                	ld	ra,24(sp)
ffffffffc020014c:	4532                	lw	a0,12(sp)
ffffffffc020014e:	6105                	addi	sp,sp,32
ffffffffc0200150:	8082                	ret

ffffffffc0200152 <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
ffffffffc0200152:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
ffffffffc0200154:	02810313          	addi	t1,sp,40
cprintf(const char *fmt, ...) {
ffffffffc0200158:	f42e                	sd	a1,40(sp)
ffffffffc020015a:	f832                	sd	a2,48(sp)
ffffffffc020015c:	fc36                	sd	a3,56(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020015e:	862a                	mv	a2,a0
ffffffffc0200160:	004c                	addi	a1,sp,4
ffffffffc0200162:	00000517          	auipc	a0,0x0
ffffffffc0200166:	fb650513          	addi	a0,a0,-74 # ffffffffc0200118 <cputch>
ffffffffc020016a:	869a                	mv	a3,t1
cprintf(const char *fmt, ...) {
ffffffffc020016c:	ec06                	sd	ra,24(sp)
ffffffffc020016e:	e0ba                	sd	a4,64(sp)
ffffffffc0200170:	e4be                	sd	a5,72(sp)
ffffffffc0200172:	e8c2                	sd	a6,80(sp)
ffffffffc0200174:	ecc6                	sd	a7,88(sp)
    int cnt = 0;
ffffffffc0200176:	c202                	sw	zero,4(sp)
    va_start(ap, fmt);
ffffffffc0200178:	e41a                	sd	t1,8(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020017a:	0a7010ef          	jal	ffffffffc0201a20 <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
ffffffffc020017e:	60e2                	ld	ra,24(sp)
ffffffffc0200180:	4512                	lw	a0,4(sp)
ffffffffc0200182:	6125                	addi	sp,sp,96
ffffffffc0200184:	8082                	ret

ffffffffc0200186 <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
ffffffffc0200186:	1101                	addi	sp,sp,-32
ffffffffc0200188:	ec06                	sd	ra,24(sp)
ffffffffc020018a:	e822                	sd	s0,16(sp)
ffffffffc020018c:	87aa                	mv	a5,a0
    int cnt = 0;
    char c;
    while ((c = *str ++) != '\0') {
ffffffffc020018e:	00054503          	lbu	a0,0(a0)
ffffffffc0200192:	c905                	beqz	a0,ffffffffc02001c2 <cputs+0x3c>
ffffffffc0200194:	e426                	sd	s1,8(sp)
ffffffffc0200196:	00178493          	addi	s1,a5,1
ffffffffc020019a:	8426                	mv	s0,s1
    cons_putc(c);
ffffffffc020019c:	092000ef          	jal	ffffffffc020022e <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc02001a0:	87a2                	mv	a5,s0
ffffffffc02001a2:	00044503          	lbu	a0,0(s0)
ffffffffc02001a6:	0405                	addi	s0,s0,1
ffffffffc02001a8:	f975                	bnez	a0,ffffffffc020019c <cputs+0x16>
    (*cnt) ++;
ffffffffc02001aa:	9f85                	subw	a5,a5,s1
    cons_putc(c);
ffffffffc02001ac:	4529                	li	a0,10
    (*cnt) ++;
ffffffffc02001ae:	0027841b          	addiw	s0,a5,2
ffffffffc02001b2:	64a2                	ld	s1,8(sp)
    cons_putc(c);
ffffffffc02001b4:	07a000ef          	jal	ffffffffc020022e <cons_putc>
        cputch(c, &cnt);
    }
    cputch('\n', &cnt);
    return cnt;
}
ffffffffc02001b8:	60e2                	ld	ra,24(sp)
ffffffffc02001ba:	8522                	mv	a0,s0
ffffffffc02001bc:	6442                	ld	s0,16(sp)
ffffffffc02001be:	6105                	addi	sp,sp,32
ffffffffc02001c0:	8082                	ret
    cons_putc(c);
ffffffffc02001c2:	4529                	li	a0,10
ffffffffc02001c4:	06a000ef          	jal	ffffffffc020022e <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc02001c8:	4405                	li	s0,1
}
ffffffffc02001ca:	60e2                	ld	ra,24(sp)
ffffffffc02001cc:	8522                	mv	a0,s0
ffffffffc02001ce:	6442                	ld	s0,16(sp)
ffffffffc02001d0:	6105                	addi	sp,sp,32
ffffffffc02001d2:	8082                	ret

ffffffffc02001d4 <__panic>:
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
    if (is_panic) {
ffffffffc02001d4:	00006317          	auipc	t1,0x6
ffffffffc02001d8:	f1c32303          	lw	t1,-228(t1) # ffffffffc02060f0 <is_panic>
__panic(const char *file, int line, const char *fmt, ...) {
ffffffffc02001dc:	715d                	addi	sp,sp,-80
ffffffffc02001de:	ec06                	sd	ra,24(sp)
ffffffffc02001e0:	f436                	sd	a3,40(sp)
ffffffffc02001e2:	f83a                	sd	a4,48(sp)
ffffffffc02001e4:	fc3e                	sd	a5,56(sp)
ffffffffc02001e6:	e0c2                	sd	a6,64(sp)
ffffffffc02001e8:	e4c6                	sd	a7,72(sp)
    if (is_panic) {
ffffffffc02001ea:	00030363          	beqz	t1,ffffffffc02001f0 <__panic+0x1c>
    vcprintf(fmt, ap);
    cprintf("\n");
    va_end(ap);

panic_dead:
    while (1) {
ffffffffc02001ee:	a001                	j	ffffffffc02001ee <__panic+0x1a>
    is_panic = 1;
ffffffffc02001f0:	e822                	sd	s0,16(sp)
ffffffffc02001f2:	00006797          	auipc	a5,0x6
ffffffffc02001f6:	efe78793          	addi	a5,a5,-258 # ffffffffc02060f0 <is_panic>
ffffffffc02001fa:	4685                	li	a3,1
    va_start(ap, fmt);
ffffffffc02001fc:	1038                	addi	a4,sp,40
ffffffffc02001fe:	8432                	mv	s0,a2
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc0200200:	862e                	mv	a2,a1
ffffffffc0200202:	85aa                	mv	a1,a0
ffffffffc0200204:	00002517          	auipc	a0,0x2
ffffffffc0200208:	d1c50513          	addi	a0,a0,-740 # ffffffffc0201f20 <etext+0xd6>
    is_panic = 1;
ffffffffc020020c:	c394                	sw	a3,0(a5)
    va_start(ap, fmt);
ffffffffc020020e:	e43a                	sd	a4,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc0200210:	f43ff0ef          	jal	ffffffffc0200152 <cprintf>
    vcprintf(fmt, ap);
ffffffffc0200214:	65a2                	ld	a1,8(sp)
ffffffffc0200216:	8522                	mv	a0,s0
ffffffffc0200218:	f1bff0ef          	jal	ffffffffc0200132 <vcprintf>
    cprintf("\n");
ffffffffc020021c:	00002517          	auipc	a0,0x2
ffffffffc0200220:	d2450513          	addi	a0,a0,-732 # ffffffffc0201f40 <etext+0xf6>
ffffffffc0200224:	f2fff0ef          	jal	ffffffffc0200152 <cprintf>
ffffffffc0200228:	6442                	ld	s0,16(sp)
ffffffffc020022a:	b7d1                	j	ffffffffc02001ee <__panic+0x1a>

ffffffffc020022c <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc020022c:	8082                	ret

ffffffffc020022e <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc020022e:	0ff57513          	zext.b	a0,a0
ffffffffc0200232:	3570106f          	j	ffffffffc0201d88 <sbi_console_putchar>

ffffffffc0200236 <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc0200236:	711d                	addi	sp,sp,-96
    cprintf("DTB Init\n");
ffffffffc0200238:	00002517          	auipc	a0,0x2
ffffffffc020023c:	d1050513          	addi	a0,a0,-752 # ffffffffc0201f48 <etext+0xfe>
void dtb_init(void) {
ffffffffc0200240:	ec86                	sd	ra,88(sp)
ffffffffc0200242:	e8a2                	sd	s0,80(sp)
    cprintf("DTB Init\n");
ffffffffc0200244:	f0fff0ef          	jal	ffffffffc0200152 <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc0200248:	00006597          	auipc	a1,0x6
ffffffffc020024c:	db85b583          	ld	a1,-584(a1) # ffffffffc0206000 <boot_hartid>
ffffffffc0200250:	00002517          	auipc	a0,0x2
ffffffffc0200254:	d0850513          	addi	a0,a0,-760 # ffffffffc0201f58 <etext+0x10e>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc0200258:	00006417          	auipc	s0,0x6
ffffffffc020025c:	db040413          	addi	s0,s0,-592 # ffffffffc0206008 <boot_dtb>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc0200260:	ef3ff0ef          	jal	ffffffffc0200152 <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc0200264:	600c                	ld	a1,0(s0)
ffffffffc0200266:	00002517          	auipc	a0,0x2
ffffffffc020026a:	d0250513          	addi	a0,a0,-766 # ffffffffc0201f68 <etext+0x11e>
ffffffffc020026e:	ee5ff0ef          	jal	ffffffffc0200152 <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc0200272:	601c                	ld	a5,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc0200274:	00002517          	auipc	a0,0x2
ffffffffc0200278:	d0c50513          	addi	a0,a0,-756 # ffffffffc0201f80 <etext+0x136>
    if (boot_dtb == 0) {
ffffffffc020027c:	12078463          	beqz	a5,ffffffffc02003a4 <dtb_init+0x16e>
        return;
    }
    
    // 转换为虚拟地址
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc0200280:	5775                	li	a4,-3
ffffffffc0200282:	077a                	slli	a4,a4,0x1e
ffffffffc0200284:	97ba                	add	a5,a5,a4
    const struct fdt_header *header = (const struct fdt_header *)dtb_vaddr;
    
    // 验证DTB
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc0200286:	4398                	lw	a4,0(a5)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200288:	f456                	sd	s5,40(sp)
ffffffffc020028a:	00ff0ab7          	lui	s5,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020028e:	0107569b          	srliw	a3,a4,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200292:	0087559b          	srliw	a1,a4,0x8
ffffffffc0200296:	0187151b          	slliw	a0,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020029a:	0086969b          	slliw	a3,a3,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020029e:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a2:	0187571b          	srliw	a4,a4,0x18
ffffffffc02002a6:	8f49                	or	a4,a4,a0
ffffffffc02002a8:	16c2                	slli	a3,a3,0x30
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002aa:	0155f5b3          	and	a1,a1,s5
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002ae:	8dd9                	or	a1,a1,a4
    if (magic != 0xd00dfeed) {
ffffffffc02002b0:	d00e0637          	lui	a2,0xd00e0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002b4:	92c1                	srli	a3,a3,0x30
ffffffffc02002b6:	8dd5                	or	a1,a1,a3
    if (magic != 0xd00dfeed) {
ffffffffc02002b8:	eed60713          	addi	a4,a2,-275 # ffffffffd00dfeed <end+0xfed9db1>
ffffffffc02002bc:	0ee59863          	bne	a1,a4,ffffffffc02003ac <dtb_init+0x176>
ffffffffc02002c0:	4794                	lw	a3,8(a5)
ffffffffc02002c2:	47d8                	lw	a4,12(a5)
ffffffffc02002c4:	e4a6                	sd	s1,72(sp)
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002c6:	0106d59b          	srliw	a1,a3,0x10
ffffffffc02002ca:	0107561b          	srliw	a2,a4,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002ce:	0086d41b          	srliw	s0,a3,0x8
ffffffffc02002d2:	0087549b          	srliw	s1,a4,0x8
ffffffffc02002d6:	0186981b          	slliw	a6,a3,0x18
ffffffffc02002da:	0187151b          	slliw	a0,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002de:	0085959b          	slliw	a1,a1,0x8
ffffffffc02002e2:	0086161b          	slliw	a2,a2,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002e6:	0104141b          	slliw	s0,s0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002ea:	0186d69b          	srliw	a3,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002ee:	0104949b          	slliw	s1,s1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f2:	0187571b          	srliw	a4,a4,0x18
ffffffffc02002f6:	15c2                	slli	a1,a1,0x30
ffffffffc02002f8:	1642                	slli	a2,a2,0x30
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002fa:	01547433          	and	s0,s0,s5
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002fe:	00d866b3          	or	a3,a6,a3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200302:	0154f4b3          	and	s1,s1,s5
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200306:	8f49                	or	a4,a4,a0
ffffffffc0200308:	91c1                	srli	a1,a1,0x30
ffffffffc020030a:	9241                	srli	a2,a2,0x30
ffffffffc020030c:	8c55                	or	s0,s0,a3
ffffffffc020030e:	8cd9                	or	s1,s1,a4
ffffffffc0200310:	8c4d                	or	s0,s0,a1
ffffffffc0200312:	8cd1                	or	s1,s1,a2
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200314:	1402                	slli	s0,s0,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200316:	1482                	slli	s1,s1,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200318:	9001                	srli	s0,s0,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020031a:	9081                	srli	s1,s1,0x20
ffffffffc020031c:	e0ca                	sd	s2,64(sp)
ffffffffc020031e:	fc4e                	sd	s3,56(sp)
ffffffffc0200320:	f05a                	sd	s6,32(sp)
ffffffffc0200322:	ec5e                	sd	s7,24(sp)
ffffffffc0200324:	e862                	sd	s8,16(sp)
ffffffffc0200326:	f852                	sd	s4,48(sp)
ffffffffc0200328:	e466                	sd	s9,8(sp)
    int in_memory_node = 0;
ffffffffc020032a:	4b81                	li	s7,0
        switch (token) {
ffffffffc020032c:	4b0d                	li	s6,3
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020032e:	943e                	add	s0,s0,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200330:	94be                	add	s1,s1,a5
        switch (token) {
ffffffffc0200332:	4991                	li	s3,4
ffffffffc0200334:	4c05                	li	s8,1
ffffffffc0200336:	4909                	li	s2,2
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200338:	4018                	lw	a4,0(s0)
ffffffffc020033a:	00440a13          	addi	s4,s0,4
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020033e:	0107569b          	srliw	a3,a4,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200342:	0087579b          	srliw	a5,a4,0x8
ffffffffc0200346:	0187161b          	slliw	a2,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020034a:	0086969b          	slliw	a3,a3,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020034e:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200352:	0187571b          	srliw	a4,a4,0x18
ffffffffc0200356:	16c2                	slli	a3,a3,0x30
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200358:	0157f7b3          	and	a5,a5,s5
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020035c:	8f51                	or	a4,a4,a2
ffffffffc020035e:	92c1                	srli	a3,a3,0x30
ffffffffc0200360:	8fd9                	or	a5,a5,a4
ffffffffc0200362:	8fd5                	or	a5,a5,a3
        switch (token) {
ffffffffc0200364:	09678763          	beq	a5,s6,ffffffffc02003f2 <dtb_init+0x1bc>
ffffffffc0200368:	00fb6963          	bltu	s6,a5,ffffffffc020037a <dtb_init+0x144>
ffffffffc020036c:	05878963          	beq	a5,s8,ffffffffc02003be <dtb_init+0x188>
ffffffffc0200370:	01279763          	bne	a5,s2,ffffffffc020037e <dtb_init+0x148>
ffffffffc0200374:	4b81                	li	s7,0
ffffffffc0200376:	8452                	mv	s0,s4
ffffffffc0200378:	b7c1                	j	ffffffffc0200338 <dtb_init+0x102>
ffffffffc020037a:	ff378ee3          	beq	a5,s3,ffffffffc0200376 <dtb_init+0x140>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;
        memory_size = mem_size;
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc020037e:	00002517          	auipc	a0,0x2
ffffffffc0200382:	cca50513          	addi	a0,a0,-822 # ffffffffc0202048 <etext+0x1fe>
ffffffffc0200386:	dcdff0ef          	jal	ffffffffc0200152 <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc020038a:	64a6                	ld	s1,72(sp)
ffffffffc020038c:	6906                	ld	s2,64(sp)
ffffffffc020038e:	79e2                	ld	s3,56(sp)
ffffffffc0200390:	7a42                	ld	s4,48(sp)
ffffffffc0200392:	7aa2                	ld	s5,40(sp)
ffffffffc0200394:	7b02                	ld	s6,32(sp)
ffffffffc0200396:	6be2                	ld	s7,24(sp)
ffffffffc0200398:	6c42                	ld	s8,16(sp)
ffffffffc020039a:	6ca2                	ld	s9,8(sp)
ffffffffc020039c:	00002517          	auipc	a0,0x2
ffffffffc02003a0:	ce450513          	addi	a0,a0,-796 # ffffffffc0202080 <etext+0x236>
}
ffffffffc02003a4:	6446                	ld	s0,80(sp)
ffffffffc02003a6:	60e6                	ld	ra,88(sp)
ffffffffc02003a8:	6125                	addi	sp,sp,96
    cprintf("DTB init completed\n");
ffffffffc02003aa:	b365                	j	ffffffffc0200152 <cprintf>
}
ffffffffc02003ac:	6446                	ld	s0,80(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003ae:	7aa2                	ld	s5,40(sp)
}
ffffffffc02003b0:	60e6                	ld	ra,88(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003b2:	00002517          	auipc	a0,0x2
ffffffffc02003b6:	bee50513          	addi	a0,a0,-1042 # ffffffffc0201fa0 <etext+0x156>
}
ffffffffc02003ba:	6125                	addi	sp,sp,96
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003bc:	bb59                	j	ffffffffc0200152 <cprintf>
                int name_len = strlen(name);
ffffffffc02003be:	8552                	mv	a0,s4
ffffffffc02003c0:	1e3010ef          	jal	ffffffffc0201da2 <strlen>
ffffffffc02003c4:	8caa                	mv	s9,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003c6:	4619                	li	a2,6
ffffffffc02003c8:	8552                	mv	a0,s4
ffffffffc02003ca:	00002597          	auipc	a1,0x2
ffffffffc02003ce:	bfe58593          	addi	a1,a1,-1026 # ffffffffc0201fc8 <etext+0x17e>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc02003d2:	00840a13          	addi	s4,s0,8
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003d6:	23b010ef          	jal	ffffffffc0201e10 <strncmp>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc02003da:	2c81                	sext.w	s9,s9
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003dc:	00153513          	seqz	a0,a0
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc02003e0:	9a66                	add	s4,s4,s9
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003e2:	00abe533          	or	a0,s7,a0
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc02003e6:	ffca7a13          	andi	s4,s4,-4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003ea:	00050b9b          	sext.w	s7,a0
        switch (token) {
ffffffffc02003ee:	8452                	mv	s0,s4
ffffffffc02003f0:	b7a1                	j	ffffffffc0200338 <dtb_init+0x102>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc02003f2:	405c                	lw	a5,4(s0)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc02003f4:	00c40a13          	addi	s4,s0,12
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02003f8:	0107d71b          	srliw	a4,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02003fc:	0087d69b          	srliw	a3,a5,0x8
ffffffffc0200400:	01879c9b          	slliw	s9,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200404:	0087171b          	slliw	a4,a4,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200408:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020040c:	0187d79b          	srliw	a5,a5,0x18
ffffffffc0200410:	1742                	slli	a4,a4,0x30
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200412:	0156f6b3          	and	a3,a3,s5
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200416:	00fcecb3          	or	s9,s9,a5
ffffffffc020041a:	9341                	srli	a4,a4,0x30
ffffffffc020041c:	00dcecb3          	or	s9,s9,a3
ffffffffc0200420:	00ececb3          	or	s9,s9,a4
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200424:	000b9b63          	bnez	s7,ffffffffc020043a <dtb_init+0x204>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc0200428:	1c82                	slli	s9,s9,0x20
ffffffffc020042a:	020cdc93          	srli	s9,s9,0x20
ffffffffc020042e:	0a0d                	addi	s4,s4,3
ffffffffc0200430:	9a66                	add	s4,s4,s9
ffffffffc0200432:	ffca7a13          	andi	s4,s4,-4
        switch (token) {
ffffffffc0200436:	8452                	mv	s0,s4
ffffffffc0200438:	b701                	j	ffffffffc0200338 <dtb_init+0x102>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc020043a:	441c                	lw	a5,8(s0)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020043c:	00002597          	auipc	a1,0x2
ffffffffc0200440:	b9458593          	addi	a1,a1,-1132 # ffffffffc0201fd0 <etext+0x186>
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200444:	0087d69b          	srliw	a3,a5,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200448:	0107d71b          	srliw	a4,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020044c:	0187951b          	slliw	a0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200450:	0087171b          	slliw	a4,a4,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200454:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200458:	0187d79b          	srliw	a5,a5,0x18
ffffffffc020045c:	1742                	slli	a4,a4,0x30
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020045e:	0156f6b3          	and	a3,a3,s5
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200462:	8d5d                	or	a0,a0,a5
ffffffffc0200464:	9341                	srli	a4,a4,0x30
ffffffffc0200466:	8d55                	or	a0,a0,a3
ffffffffc0200468:	8d59                	or	a0,a0,a4
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc020046a:	1502                	slli	a0,a0,0x20
ffffffffc020046c:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020046e:	9526                	add	a0,a0,s1
ffffffffc0200470:	169010ef          	jal	ffffffffc0201dd8 <strcmp>
ffffffffc0200474:	f955                	bnez	a0,ffffffffc0200428 <dtb_init+0x1f2>
ffffffffc0200476:	47bd                	li	a5,15
ffffffffc0200478:	fb97f8e3          	bgeu	a5,s9,ffffffffc0200428 <dtb_init+0x1f2>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc020047c:	00c43703          	ld	a4,12(s0)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc0200480:	01443783          	ld	a5,20(s0)
        cprintf("Physical Memory from DTB:\n");
ffffffffc0200484:	00002517          	auipc	a0,0x2
ffffffffc0200488:	b5450513          	addi	a0,a0,-1196 # ffffffffc0201fd8 <etext+0x18e>
           fdt32_to_cpu(x >> 32);
ffffffffc020048c:	42075813          	srai	a6,a4,0x20
ffffffffc0200490:	4207d593          	srai	a1,a5,0x20
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200494:	01085e9b          	srliw	t4,a6,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200498:	02875613          	srli	a2,a4,0x28
ffffffffc020049c:	0287d693          	srli	a3,a5,0x28
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc02004a0:	00070e1b          	sext.w	t3,a4
ffffffffc02004a4:	0007889b          	sext.w	a7,a5
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004a8:	01859f9b          	slliw	t6,a1,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004ac:	0105d31b          	srliw	t1,a1,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004b0:	0188139b          	slliw	t2,a6,0x18
ffffffffc02004b4:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004b8:	0188581b          	srliw	a6,a6,0x18
ffffffffc02004bc:	0185df1b          	srliw	t5,a1,0x18
ffffffffc02004c0:	008e9e9b          	slliw	t4,t4,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c4:	0106161b          	slliw	a2,a2,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004c8:	010e529b          	srliw	t0,t3,0x10
ffffffffc02004cc:	0103e3b3          	or	t2,t2,a6
ffffffffc02004d0:	01efef33          	or	t5,t6,t5
ffffffffc02004d4:	0108d59b          	srliw	a1,a7,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004d8:	01567633          	and	a2,a2,s5
ffffffffc02004dc:	0087549b          	srliw	s1,a4,0x8
ffffffffc02004e0:	0087d41b          	srliw	s0,a5,0x8
ffffffffc02004e4:	0156f733          	and	a4,a3,s5
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004e8:	0083131b          	slliw	t1,t1,0x8
ffffffffc02004ec:	1ec2                	slli	t4,t4,0x30
ffffffffc02004ee:	007666b3          	or	a3,a2,t2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004f2:	018e1f9b          	slliw	t6,t3,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004f6:	030ede93          	srli	t4,t4,0x30
ffffffffc02004fa:	0082981b          	slliw	a6,t0,0x8
ffffffffc02004fe:	018e5e1b          	srliw	t3,t3,0x18
ffffffffc0200502:	01e767b3          	or	a5,a4,t5
ffffffffc0200506:	0085959b          	slliw	a1,a1,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020050a:	01889f1b          	slliw	t5,a7,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020050e:	1342                	slli	t1,t1,0x30
ffffffffc0200510:	0188d89b          	srliw	a7,a7,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200514:	0104949b          	slliw	s1,s1,0x10
ffffffffc0200518:	0104141b          	slliw	s0,s0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020051c:	01d6e733          	or	a4,a3,t4
ffffffffc0200520:	03035313          	srli	t1,t1,0x30
ffffffffc0200524:	011f66b3          	or	a3,t5,a7
ffffffffc0200528:	03059613          	slli	a2,a1,0x30
ffffffffc020052c:	1842                	slli	a6,a6,0x30
ffffffffc020052e:	01cfe5b3          	or	a1,t6,t3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200532:	0154f4b3          	and	s1,s1,s5
ffffffffc0200536:	01547433          	and	s0,s0,s5
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020053a:	03085813          	srli	a6,a6,0x30
ffffffffc020053e:	0067e7b3          	or	a5,a5,t1
ffffffffc0200542:	8c55                	or	s0,s0,a3
ffffffffc0200544:	9241                	srli	a2,a2,0x30
ffffffffc0200546:	8ccd                	or	s1,s1,a1
ffffffffc0200548:	0104e4b3          	or	s1,s1,a6
ffffffffc020054c:	8c51                	or	s0,s0,a2
           fdt32_to_cpu(x >> 32);
ffffffffc020054e:	1702                	slli	a4,a4,0x20
ffffffffc0200550:	1782                	slli	a5,a5,0x20
ffffffffc0200552:	9381                	srli	a5,a5,0x20
ffffffffc0200554:	9301                	srli	a4,a4,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200556:	1482                	slli	s1,s1,0x20
ffffffffc0200558:	1402                	slli	s0,s0,0x20
ffffffffc020055a:	8c5d                	or	s0,s0,a5
ffffffffc020055c:	8cd9                	or	s1,s1,a4
        cprintf("Physical Memory from DTB:\n");
ffffffffc020055e:	bf5ff0ef          	jal	ffffffffc0200152 <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc0200562:	85a6                	mv	a1,s1
ffffffffc0200564:	00002517          	auipc	a0,0x2
ffffffffc0200568:	a9450513          	addi	a0,a0,-1388 # ffffffffc0201ff8 <etext+0x1ae>
ffffffffc020056c:	be7ff0ef          	jal	ffffffffc0200152 <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc0200570:	01445613          	srli	a2,s0,0x14
ffffffffc0200574:	85a2                	mv	a1,s0
ffffffffc0200576:	00002517          	auipc	a0,0x2
ffffffffc020057a:	a9a50513          	addi	a0,a0,-1382 # ffffffffc0202010 <etext+0x1c6>
ffffffffc020057e:	bd5ff0ef          	jal	ffffffffc0200152 <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200582:	009405b3          	add	a1,s0,s1
ffffffffc0200586:	15fd                	addi	a1,a1,-1
ffffffffc0200588:	00002517          	auipc	a0,0x2
ffffffffc020058c:	aa850513          	addi	a0,a0,-1368 # ffffffffc0202030 <etext+0x1e6>
ffffffffc0200590:	bc3ff0ef          	jal	ffffffffc0200152 <cprintf>
        memory_base = mem_base;
ffffffffc0200594:	00006797          	auipc	a5,0x6
ffffffffc0200598:	b697b623          	sd	s1,-1172(a5) # ffffffffc0206100 <memory_base>
        memory_size = mem_size;
ffffffffc020059c:	00006797          	auipc	a5,0x6
ffffffffc02005a0:	b487be23          	sd	s0,-1188(a5) # ffffffffc02060f8 <memory_size>
ffffffffc02005a4:	b3dd                	j	ffffffffc020038a <dtb_init+0x154>

ffffffffc02005a6 <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc02005a6:	00006517          	auipc	a0,0x6
ffffffffc02005aa:	b5a53503          	ld	a0,-1190(a0) # ffffffffc0206100 <memory_base>
ffffffffc02005ae:	8082                	ret

ffffffffc02005b0 <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc02005b0:	00006517          	auipc	a0,0x6
ffffffffc02005b4:	b4853503          	ld	a0,-1208(a0) # ffffffffc02060f8 <memory_size>
ffffffffc02005b8:	8082                	ret

ffffffffc02005ba <best_fit_init>:
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc02005ba:	00006797          	auipc	a5,0x6
ffffffffc02005be:	a5e78793          	addi	a5,a5,-1442 # ffffffffc0206018 <free_area>
ffffffffc02005c2:	e79c                	sd	a5,8(a5)
ffffffffc02005c4:	e39c                	sd	a5,0(a5)

// 1. 初始化最佳适应分配器
static void
best_fit_init(void) {
    list_init(&free_list);
    nr_free = 0;
ffffffffc02005c6:	0007a823          	sw	zero,16(a5)
}
ffffffffc02005ca:	8082                	ret

ffffffffc02005cc <best_fit_nr_free_pages>:

// 5. 返回空闲页数量
static size_t
best_fit_nr_free_pages(void) {
    return nr_free;
}
ffffffffc02005cc:	00006517          	auipc	a0,0x6
ffffffffc02005d0:	a5c56503          	lwu	a0,-1444(a0) # ffffffffc0206028 <free_area+0x10>
ffffffffc02005d4:	8082                	ret

ffffffffc02005d6 <best_fit_alloc_pages>:
    assert(n > 0);
ffffffffc02005d6:	cd59                	beqz	a0,ffffffffc0200674 <best_fit_alloc_pages+0x9e>
    if (n > nr_free) {
ffffffffc02005d8:	00006817          	auipc	a6,0x6
ffffffffc02005dc:	a5082803          	lw	a6,-1456(a6) # ffffffffc0206028 <free_area+0x10>
ffffffffc02005e0:	86aa                	mv	a3,a0
ffffffffc02005e2:	00006617          	auipc	a2,0x6
ffffffffc02005e6:	a3660613          	addi	a2,a2,-1482 # ffffffffc0206018 <free_area>
ffffffffc02005ea:	02081793          	slli	a5,a6,0x20
ffffffffc02005ee:	9381                	srli	a5,a5,0x20
ffffffffc02005f0:	08a7e063          	bltu	a5,a0,ffffffffc0200670 <best_fit_alloc_pages+0x9a>
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc02005f4:	661c                	ld	a5,8(a2)
    size_t min_size = nr_free + 1; // 初始设定一个较大的值
ffffffffc02005f6:	0018059b          	addiw	a1,a6,1
ffffffffc02005fa:	1582                	slli	a1,a1,0x20
ffffffffc02005fc:	9181                	srli	a1,a1,0x20
    struct Page *page = NULL;
ffffffffc02005fe:	4501                	li	a0,0
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200600:	06c78763          	beq	a5,a2,ffffffffc020066e <best_fit_alloc_pages+0x98>
        if (p->property >= n && p->property < min_size) {
ffffffffc0200604:	ff87e703          	lwu	a4,-8(a5)
ffffffffc0200608:	00d76763          	bltu	a4,a3,ffffffffc0200616 <best_fit_alloc_pages+0x40>
ffffffffc020060c:	00b77563          	bgeu	a4,a1,ffffffffc0200616 <best_fit_alloc_pages+0x40>
            min_size = p->property;
ffffffffc0200610:	85ba                	mv	a1,a4
        struct Page *p = le2page(le, page_link);
ffffffffc0200612:	fe878513          	addi	a0,a5,-24
ffffffffc0200616:	679c                	ld	a5,8(a5)
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200618:	fec796e3          	bne	a5,a2,ffffffffc0200604 <best_fit_alloc_pages+0x2e>
    if (page != NULL) {
ffffffffc020061c:	c929                	beqz	a0,ffffffffc020066e <best_fit_alloc_pages+0x98>
        if (page->property > n) {
ffffffffc020061e:	01052883          	lw	a7,16(a0)
 * list_prev - get the previous entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_prev(list_entry_t *listelm) {
    return listelm->prev;
ffffffffc0200622:	6d18                	ld	a4,24(a0)
    __list_del(listelm->prev, listelm->next);
ffffffffc0200624:	710c                	ld	a1,32(a0)
ffffffffc0200626:	02089793          	slli	a5,a7,0x20
ffffffffc020062a:	9381                	srli	a5,a5,0x20
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc020062c:	e70c                	sd	a1,8(a4)
    next->prev = prev;
ffffffffc020062e:	e198                	sd	a4,0(a1)
            p->property = page->property - n;
ffffffffc0200630:	0006831b          	sext.w	t1,a3
        if (page->property > n) {
ffffffffc0200634:	02f6f563          	bgeu	a3,a5,ffffffffc020065e <best_fit_alloc_pages+0x88>
            struct Page *p = page + n;
ffffffffc0200638:	00269793          	slli	a5,a3,0x2
ffffffffc020063c:	97b6                	add	a5,a5,a3
ffffffffc020063e:	078e                	slli	a5,a5,0x3
ffffffffc0200640:	97aa                	add	a5,a5,a0
            SetPageProperty(p);
ffffffffc0200642:	6794                	ld	a3,8(a5)
            p->property = page->property - n;
ffffffffc0200644:	406888bb          	subw	a7,a7,t1
ffffffffc0200648:	0117a823          	sw	a7,16(a5)
            SetPageProperty(p);
ffffffffc020064c:	0026e693          	ori	a3,a3,2
ffffffffc0200650:	e794                	sd	a3,8(a5)
            list_add(prev, &(p->page_link));
ffffffffc0200652:	01878693          	addi	a3,a5,24
    prev->next = next->prev = elm;
ffffffffc0200656:	e194                	sd	a3,0(a1)
ffffffffc0200658:	e714                	sd	a3,8(a4)
    elm->next = next;
ffffffffc020065a:	f38c                	sd	a1,32(a5)
    elm->prev = prev;
ffffffffc020065c:	ef98                	sd	a4,24(a5)
        ClearPageProperty(page);
ffffffffc020065e:	651c                	ld	a5,8(a0)
        nr_free -= n;
ffffffffc0200660:	4068083b          	subw	a6,a6,t1
ffffffffc0200664:	01062823          	sw	a6,16(a2)
        ClearPageProperty(page);
ffffffffc0200668:	9bf5                	andi	a5,a5,-3
ffffffffc020066a:	e51c                	sd	a5,8(a0)
ffffffffc020066c:	8082                	ret
}
ffffffffc020066e:	8082                	ret
        return NULL;
ffffffffc0200670:	4501                	li	a0,0
ffffffffc0200672:	8082                	ret
best_fit_alloc_pages(size_t n) {
ffffffffc0200674:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc0200676:	00002697          	auipc	a3,0x2
ffffffffc020067a:	a2268693          	addi	a3,a3,-1502 # ffffffffc0202098 <etext+0x24e>
ffffffffc020067e:	00002617          	auipc	a2,0x2
ffffffffc0200682:	a2260613          	addi	a2,a2,-1502 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200686:	03900593          	li	a1,57
ffffffffc020068a:	00002517          	auipc	a0,0x2
ffffffffc020068e:	a2e50513          	addi	a0,a0,-1490 # ffffffffc02020b8 <etext+0x26e>
best_fit_alloc_pages(size_t n) {
ffffffffc0200692:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200694:	b41ff0ef          	jal	ffffffffc02001d4 <__panic>

ffffffffc0200698 <best_fit_check>:
    free_page(p1);
    free_page(p2);
}

static void
best_fit_check(void) {
ffffffffc0200698:	715d                	addi	sp,sp,-80
ffffffffc020069a:	f84a                	sd	s2,48(sp)
    return listelm->next;
ffffffffc020069c:	00006917          	auipc	s2,0x6
ffffffffc02006a0:	97c90913          	addi	s2,s2,-1668 # ffffffffc0206018 <free_area>
ffffffffc02006a4:	00893783          	ld	a5,8(s2)
ffffffffc02006a8:	e486                	sd	ra,72(sp)
ffffffffc02006aa:	e0a2                	sd	s0,64(sp)
ffffffffc02006ac:	fc26                	sd	s1,56(sp)
ffffffffc02006ae:	f44e                	sd	s3,40(sp)
ffffffffc02006b0:	f052                	sd	s4,32(sp)
ffffffffc02006b2:	ec56                	sd	s5,24(sp)
ffffffffc02006b4:	e85a                	sd	s6,16(sp)
ffffffffc02006b6:	e45e                	sd	s7,8(sp)
ffffffffc02006b8:	e062                	sd	s8,0(sp)
    int score = 0, sumscore = 6;
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc02006ba:	29278f63          	beq	a5,s2,ffffffffc0200958 <best_fit_check+0x2c0>
    int count = 0, total = 0;
ffffffffc02006be:	4401                	li	s0,0
ffffffffc02006c0:	4481                	li	s1,0
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p));
ffffffffc02006c2:	ff07b703          	ld	a4,-16(a5)
ffffffffc02006c6:	8b09                	andi	a4,a4,2
ffffffffc02006c8:	28070c63          	beqz	a4,ffffffffc0200960 <best_fit_check+0x2c8>
        count++, total += p->property;
ffffffffc02006cc:	ff87a703          	lw	a4,-8(a5)
ffffffffc02006d0:	679c                	ld	a5,8(a5)
ffffffffc02006d2:	2485                	addiw	s1,s1,1
ffffffffc02006d4:	9c39                	addw	s0,s0,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc02006d6:	ff2796e3          	bne	a5,s2,ffffffffc02006c2 <best_fit_check+0x2a>
    }
    assert(total == nr_free_pages());
ffffffffc02006da:	89a2                	mv	s3,s0
ffffffffc02006dc:	127000ef          	jal	ffffffffc0201002 <nr_free_pages>
ffffffffc02006e0:	37351063          	bne	a0,s3,ffffffffc0200a40 <best_fit_check+0x3a8>
    assert((p0 = alloc_page()) != NULL);
ffffffffc02006e4:	4505                	li	a0,1
ffffffffc02006e6:	105000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc02006ea:	8a2a                	mv	s4,a0
ffffffffc02006ec:	38050a63          	beqz	a0,ffffffffc0200a80 <best_fit_check+0x3e8>
    assert((p1 = alloc_page()) != NULL);
ffffffffc02006f0:	4505                	li	a0,1
ffffffffc02006f2:	0f9000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc02006f6:	89aa                	mv	s3,a0
ffffffffc02006f8:	36050463          	beqz	a0,ffffffffc0200a60 <best_fit_check+0x3c8>
    assert((p2 = alloc_page()) != NULL);
ffffffffc02006fc:	4505                	li	a0,1
ffffffffc02006fe:	0ed000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc0200702:	8aaa                	mv	s5,a0
ffffffffc0200704:	2e050e63          	beqz	a0,ffffffffc0200a00 <best_fit_check+0x368>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200708:	273a0c63          	beq	s4,s3,ffffffffc0200980 <best_fit_check+0x2e8>
ffffffffc020070c:	26aa0a63          	beq	s4,a0,ffffffffc0200980 <best_fit_check+0x2e8>
ffffffffc0200710:	26a98863          	beq	s3,a0,ffffffffc0200980 <best_fit_check+0x2e8>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200714:	000a2783          	lw	a5,0(s4)
ffffffffc0200718:	28079463          	bnez	a5,ffffffffc02009a0 <best_fit_check+0x308>
ffffffffc020071c:	0009a783          	lw	a5,0(s3)
ffffffffc0200720:	28079063          	bnez	a5,ffffffffc02009a0 <best_fit_check+0x308>
ffffffffc0200724:	411c                	lw	a5,0(a0)
ffffffffc0200726:	26079d63          	bnez	a5,ffffffffc02009a0 <best_fit_check+0x308>
extern struct Page *pages;
extern size_t npage;
extern const size_t nbase;
extern uint64_t va_pa_offset;

static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc020072a:	00006797          	auipc	a5,0x6
ffffffffc020072e:	a067b783          	ld	a5,-1530(a5) # ffffffffc0206130 <pages>
ffffffffc0200732:	ccccd6b7          	lui	a3,0xccccd
ffffffffc0200736:	ccd68693          	addi	a3,a3,-819 # ffffffffcccccccd <end+0xcac6b91>
ffffffffc020073a:	02069613          	slli	a2,a3,0x20
ffffffffc020073e:	40fa0733          	sub	a4,s4,a5
ffffffffc0200742:	9636                	add	a2,a2,a3
ffffffffc0200744:	870d                	srai	a4,a4,0x3
ffffffffc0200746:	02c70733          	mul	a4,a4,a2
ffffffffc020074a:	00002597          	auipc	a1,0x2
ffffffffc020074e:	4165b583          	ld	a1,1046(a1) # ffffffffc0202b60 <nbase>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200752:	00006697          	auipc	a3,0x6
ffffffffc0200756:	9d66b683          	ld	a3,-1578(a3) # ffffffffc0206128 <npage>
ffffffffc020075a:	06b2                	slli	a3,a3,0xc
ffffffffc020075c:	972e                	add	a4,a4,a1

static inline uintptr_t page2pa(struct Page *page) {
    return page2ppn(page) << PGSHIFT;
ffffffffc020075e:	0732                	slli	a4,a4,0xc
ffffffffc0200760:	26d77063          	bgeu	a4,a3,ffffffffc02009c0 <best_fit_check+0x328>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200764:	40f98733          	sub	a4,s3,a5
ffffffffc0200768:	870d                	srai	a4,a4,0x3
ffffffffc020076a:	02c70733          	mul	a4,a4,a2
ffffffffc020076e:	972e                	add	a4,a4,a1
    return page2ppn(page) << PGSHIFT;
ffffffffc0200770:	0732                	slli	a4,a4,0xc
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200772:	40d77763          	bgeu	a4,a3,ffffffffc0200b80 <best_fit_check+0x4e8>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200776:	40f507b3          	sub	a5,a0,a5
ffffffffc020077a:	878d                	srai	a5,a5,0x3
ffffffffc020077c:	02c787b3          	mul	a5,a5,a2
ffffffffc0200780:	97ae                	add	a5,a5,a1
    return page2ppn(page) << PGSHIFT;
ffffffffc0200782:	07b2                	slli	a5,a5,0xc
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200784:	3cd7fe63          	bgeu	a5,a3,ffffffffc0200b60 <best_fit_check+0x4c8>
    assert(alloc_page() == NULL);
ffffffffc0200788:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc020078a:	00093c03          	ld	s8,0(s2)
ffffffffc020078e:	00893b83          	ld	s7,8(s2)
    unsigned int nr_free_store = nr_free;
ffffffffc0200792:	00006b17          	auipc	s6,0x6
ffffffffc0200796:	896b2b03          	lw	s6,-1898(s6) # ffffffffc0206028 <free_area+0x10>
    elm->prev = elm->next = elm;
ffffffffc020079a:	01293023          	sd	s2,0(s2)
ffffffffc020079e:	01293423          	sd	s2,8(s2)
    nr_free = 0;
ffffffffc02007a2:	00006797          	auipc	a5,0x6
ffffffffc02007a6:	8807a323          	sw	zero,-1914(a5) # ffffffffc0206028 <free_area+0x10>
    assert(alloc_page() == NULL);
ffffffffc02007aa:	041000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc02007ae:	38051963          	bnez	a0,ffffffffc0200b40 <best_fit_check+0x4a8>
    free_page(p0);
ffffffffc02007b2:	8552                	mv	a0,s4
ffffffffc02007b4:	4585                	li	a1,1
ffffffffc02007b6:	041000ef          	jal	ffffffffc0200ff6 <free_pages>
    free_page(p1);
ffffffffc02007ba:	854e                	mv	a0,s3
ffffffffc02007bc:	4585                	li	a1,1
ffffffffc02007be:	039000ef          	jal	ffffffffc0200ff6 <free_pages>
    free_page(p2);
ffffffffc02007c2:	8556                	mv	a0,s5
ffffffffc02007c4:	4585                	li	a1,1
ffffffffc02007c6:	031000ef          	jal	ffffffffc0200ff6 <free_pages>
    assert(nr_free == 3);
ffffffffc02007ca:	00006717          	auipc	a4,0x6
ffffffffc02007ce:	85e72703          	lw	a4,-1954(a4) # ffffffffc0206028 <free_area+0x10>
ffffffffc02007d2:	478d                	li	a5,3
ffffffffc02007d4:	34f71663          	bne	a4,a5,ffffffffc0200b20 <best_fit_check+0x488>
    assert((p0 = alloc_page()) != NULL);
ffffffffc02007d8:	4505                	li	a0,1
ffffffffc02007da:	011000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc02007de:	89aa                	mv	s3,a0
ffffffffc02007e0:	32050063          	beqz	a0,ffffffffc0200b00 <best_fit_check+0x468>
    assert((p1 = alloc_page()) != NULL);
ffffffffc02007e4:	4505                	li	a0,1
ffffffffc02007e6:	005000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc02007ea:	8aaa                	mv	s5,a0
ffffffffc02007ec:	2e050a63          	beqz	a0,ffffffffc0200ae0 <best_fit_check+0x448>
    assert((p2 = alloc_page()) != NULL);
ffffffffc02007f0:	4505                	li	a0,1
ffffffffc02007f2:	7f8000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc02007f6:	8a2a                	mv	s4,a0
ffffffffc02007f8:	2c050463          	beqz	a0,ffffffffc0200ac0 <best_fit_check+0x428>
    assert(alloc_page() == NULL);
ffffffffc02007fc:	4505                	li	a0,1
ffffffffc02007fe:	7ec000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc0200802:	28051f63          	bnez	a0,ffffffffc0200aa0 <best_fit_check+0x408>
    free_page(p0);
ffffffffc0200806:	4585                	li	a1,1
ffffffffc0200808:	854e                	mv	a0,s3
ffffffffc020080a:	7ec000ef          	jal	ffffffffc0200ff6 <free_pages>
    assert(!list_empty(&free_list));
ffffffffc020080e:	00893783          	ld	a5,8(s2)
ffffffffc0200812:	1d278763          	beq	a5,s2,ffffffffc02009e0 <best_fit_check+0x348>
    assert((p = alloc_page()) == p0);
ffffffffc0200816:	4505                	li	a0,1
ffffffffc0200818:	7d2000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc020081c:	54a99263          	bne	s3,a0,ffffffffc0200d60 <best_fit_check+0x6c8>
    assert(alloc_page() == NULL);
ffffffffc0200820:	4505                	li	a0,1
ffffffffc0200822:	7c8000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc0200826:	50051d63          	bnez	a0,ffffffffc0200d40 <best_fit_check+0x6a8>
    assert(nr_free == 0);
ffffffffc020082a:	00005797          	auipc	a5,0x5
ffffffffc020082e:	7fe7a783          	lw	a5,2046(a5) # ffffffffc0206028 <free_area+0x10>
ffffffffc0200832:	4e079763          	bnez	a5,ffffffffc0200d20 <best_fit_check+0x688>
    free_page(p);
ffffffffc0200836:	854e                	mv	a0,s3
ffffffffc0200838:	4585                	li	a1,1
    free_list = free_list_store;
ffffffffc020083a:	01893023          	sd	s8,0(s2)
ffffffffc020083e:	01793423          	sd	s7,8(s2)
    nr_free = nr_free_store;
ffffffffc0200842:	01692823          	sw	s6,16(s2)
    free_page(p);
ffffffffc0200846:	7b0000ef          	jal	ffffffffc0200ff6 <free_pages>
    free_page(p1);
ffffffffc020084a:	8556                	mv	a0,s5
ffffffffc020084c:	4585                	li	a1,1
ffffffffc020084e:	7a8000ef          	jal	ffffffffc0200ff6 <free_pages>
    free_page(p2);
ffffffffc0200852:	8552                	mv	a0,s4
ffffffffc0200854:	4585                	li	a1,1
ffffffffc0200856:	7a0000ef          	jal	ffffffffc0200ff6 <free_pages>

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    struct Page *p0 = alloc_pages(5), *p1, *p2;
ffffffffc020085a:	4515                	li	a0,5
ffffffffc020085c:	78e000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc0200860:	89aa                	mv	s3,a0
    assert(p0 != NULL);
ffffffffc0200862:	48050f63          	beqz	a0,ffffffffc0200d00 <best_fit_check+0x668>
    assert(!PageProperty(p0));
ffffffffc0200866:	651c                	ld	a5,8(a0)
ffffffffc0200868:	8b89                	andi	a5,a5,2
ffffffffc020086a:	46079b63          	bnez	a5,ffffffffc0200ce0 <best_fit_check+0x648>
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);
ffffffffc020086e:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0200870:	00093b03          	ld	s6,0(s2)
ffffffffc0200874:	00893a83          	ld	s5,8(s2)
ffffffffc0200878:	01293023          	sd	s2,0(s2)
ffffffffc020087c:	01293423          	sd	s2,8(s2)
    assert(alloc_page() == NULL);
ffffffffc0200880:	76a000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc0200884:	42051e63          	bnez	a0,ffffffffc0200cc0 <best_fit_check+0x628>
    #endif
    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    // * - - * -
    free_pages(p0 + 1, 2);
ffffffffc0200888:	4589                	li	a1,2
ffffffffc020088a:	02898513          	addi	a0,s3,40
    unsigned int nr_free_store = nr_free;
ffffffffc020088e:	00005b97          	auipc	s7,0x5
ffffffffc0200892:	79abab83          	lw	s7,1946(s7) # ffffffffc0206028 <free_area+0x10>
    free_pages(p0 + 4, 1);
ffffffffc0200896:	0a098c13          	addi	s8,s3,160
    nr_free = 0;
ffffffffc020089a:	00005797          	auipc	a5,0x5
ffffffffc020089e:	7807a723          	sw	zero,1934(a5) # ffffffffc0206028 <free_area+0x10>
    free_pages(p0 + 1, 2);
ffffffffc02008a2:	754000ef          	jal	ffffffffc0200ff6 <free_pages>
    free_pages(p0 + 4, 1);
ffffffffc02008a6:	8562                	mv	a0,s8
ffffffffc02008a8:	4585                	li	a1,1
ffffffffc02008aa:	74c000ef          	jal	ffffffffc0200ff6 <free_pages>
    assert(alloc_pages(4) == NULL);
ffffffffc02008ae:	4511                	li	a0,4
ffffffffc02008b0:	73a000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc02008b4:	3e051663          	bnez	a0,ffffffffc0200ca0 <best_fit_check+0x608>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc02008b8:	0309b783          	ld	a5,48(s3)
ffffffffc02008bc:	8b89                	andi	a5,a5,2
ffffffffc02008be:	3c078163          	beqz	a5,ffffffffc0200c80 <best_fit_check+0x5e8>
ffffffffc02008c2:	0389a703          	lw	a4,56(s3)
ffffffffc02008c6:	4789                	li	a5,2
ffffffffc02008c8:	3af71c63          	bne	a4,a5,ffffffffc0200c80 <best_fit_check+0x5e8>
    // * - - * *
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc02008cc:	4505                	li	a0,1
ffffffffc02008ce:	71c000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc02008d2:	8a2a                	mv	s4,a0
ffffffffc02008d4:	38050663          	beqz	a0,ffffffffc0200c60 <best_fit_check+0x5c8>
    assert(alloc_pages(2) != NULL);
ffffffffc02008d8:	4509                	li	a0,2
ffffffffc02008da:	710000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc02008de:	36050163          	beqz	a0,ffffffffc0200c40 <best_fit_check+0x5a8>
    assert(p0 + 4 == p1);
ffffffffc02008e2:	334c1f63          	bne	s8,s4,ffffffffc0200c20 <best_fit_check+0x588>
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    p2 = p0 + 1;
    free_pages(p0, 5);
ffffffffc02008e6:	854e                	mv	a0,s3
ffffffffc02008e8:	4595                	li	a1,5
ffffffffc02008ea:	70c000ef          	jal	ffffffffc0200ff6 <free_pages>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc02008ee:	4515                	li	a0,5
ffffffffc02008f0:	6fa000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc02008f4:	89aa                	mv	s3,a0
ffffffffc02008f6:	30050563          	beqz	a0,ffffffffc0200c00 <best_fit_check+0x568>
    assert(alloc_page() == NULL);
ffffffffc02008fa:	4505                	li	a0,1
ffffffffc02008fc:	6ee000ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc0200900:	2e051063          	bnez	a0,ffffffffc0200be0 <best_fit_check+0x548>

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    assert(nr_free == 0);
ffffffffc0200904:	00005797          	auipc	a5,0x5
ffffffffc0200908:	7247a783          	lw	a5,1828(a5) # ffffffffc0206028 <free_area+0x10>
ffffffffc020090c:	2a079a63          	bnez	a5,ffffffffc0200bc0 <best_fit_check+0x528>
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);
ffffffffc0200910:	854e                	mv	a0,s3
ffffffffc0200912:	4595                	li	a1,5
    nr_free = nr_free_store;
ffffffffc0200914:	01792823          	sw	s7,16(s2)
    free_list = free_list_store;
ffffffffc0200918:	01693023          	sd	s6,0(s2)
ffffffffc020091c:	01593423          	sd	s5,8(s2)
    free_pages(p0, 5);
ffffffffc0200920:	6d6000ef          	jal	ffffffffc0200ff6 <free_pages>
    return listelm->next;
ffffffffc0200924:	00893783          	ld	a5,8(s2)

    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200928:	01278963          	beq	a5,s2,ffffffffc020093a <best_fit_check+0x2a2>
        struct Page *p = le2page(le, page_link);
        count--, total -= p->property;
ffffffffc020092c:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200930:	679c                	ld	a5,8(a5)
ffffffffc0200932:	34fd                	addiw	s1,s1,-1
ffffffffc0200934:	9c19                	subw	s0,s0,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200936:	ff279be3          	bne	a5,s2,ffffffffc020092c <best_fit_check+0x294>
    }
    assert(count == 0);
ffffffffc020093a:	26049363          	bnez	s1,ffffffffc0200ba0 <best_fit_check+0x508>
    assert(total == 0);
ffffffffc020093e:	e06d                	bnez	s0,ffffffffc0200a20 <best_fit_check+0x388>
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
}
ffffffffc0200940:	60a6                	ld	ra,72(sp)
ffffffffc0200942:	6406                	ld	s0,64(sp)
ffffffffc0200944:	74e2                	ld	s1,56(sp)
ffffffffc0200946:	7942                	ld	s2,48(sp)
ffffffffc0200948:	79a2                	ld	s3,40(sp)
ffffffffc020094a:	7a02                	ld	s4,32(sp)
ffffffffc020094c:	6ae2                	ld	s5,24(sp)
ffffffffc020094e:	6b42                	ld	s6,16(sp)
ffffffffc0200950:	6ba2                	ld	s7,8(sp)
ffffffffc0200952:	6c02                	ld	s8,0(sp)
ffffffffc0200954:	6161                	addi	sp,sp,80
ffffffffc0200956:	8082                	ret
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200958:	4981                	li	s3,0
    int count = 0, total = 0;
ffffffffc020095a:	4401                	li	s0,0
ffffffffc020095c:	4481                	li	s1,0
ffffffffc020095e:	bbbd                	j	ffffffffc02006dc <best_fit_check+0x44>
        assert(PageProperty(p));
ffffffffc0200960:	00001697          	auipc	a3,0x1
ffffffffc0200964:	77068693          	addi	a3,a3,1904 # ffffffffc02020d0 <etext+0x286>
ffffffffc0200968:	00001617          	auipc	a2,0x1
ffffffffc020096c:	73860613          	addi	a2,a2,1848 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200970:	0d300593          	li	a1,211
ffffffffc0200974:	00001517          	auipc	a0,0x1
ffffffffc0200978:	74450513          	addi	a0,a0,1860 # ffffffffc02020b8 <etext+0x26e>
ffffffffc020097c:	859ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200980:	00001697          	auipc	a3,0x1
ffffffffc0200984:	7e068693          	addi	a3,a3,2016 # ffffffffc0202160 <etext+0x316>
ffffffffc0200988:	00001617          	auipc	a2,0x1
ffffffffc020098c:	71860613          	addi	a2,a2,1816 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200990:	0a100593          	li	a1,161
ffffffffc0200994:	00001517          	auipc	a0,0x1
ffffffffc0200998:	72450513          	addi	a0,a0,1828 # ffffffffc02020b8 <etext+0x26e>
ffffffffc020099c:	839ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc02009a0:	00001697          	auipc	a3,0x1
ffffffffc02009a4:	7e868693          	addi	a3,a3,2024 # ffffffffc0202188 <etext+0x33e>
ffffffffc02009a8:	00001617          	auipc	a2,0x1
ffffffffc02009ac:	6f860613          	addi	a2,a2,1784 # ffffffffc02020a0 <etext+0x256>
ffffffffc02009b0:	0a200593          	li	a1,162
ffffffffc02009b4:	00001517          	auipc	a0,0x1
ffffffffc02009b8:	70450513          	addi	a0,a0,1796 # ffffffffc02020b8 <etext+0x26e>
ffffffffc02009bc:	819ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc02009c0:	00002697          	auipc	a3,0x2
ffffffffc02009c4:	80868693          	addi	a3,a3,-2040 # ffffffffc02021c8 <etext+0x37e>
ffffffffc02009c8:	00001617          	auipc	a2,0x1
ffffffffc02009cc:	6d860613          	addi	a2,a2,1752 # ffffffffc02020a0 <etext+0x256>
ffffffffc02009d0:	0a400593          	li	a1,164
ffffffffc02009d4:	00001517          	auipc	a0,0x1
ffffffffc02009d8:	6e450513          	addi	a0,a0,1764 # ffffffffc02020b8 <etext+0x26e>
ffffffffc02009dc:	ff8ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(!list_empty(&free_list));
ffffffffc02009e0:	00002697          	auipc	a3,0x2
ffffffffc02009e4:	87068693          	addi	a3,a3,-1936 # ffffffffc0202250 <etext+0x406>
ffffffffc02009e8:	00001617          	auipc	a2,0x1
ffffffffc02009ec:	6b860613          	addi	a2,a2,1720 # ffffffffc02020a0 <etext+0x256>
ffffffffc02009f0:	0bd00593          	li	a1,189
ffffffffc02009f4:	00001517          	auipc	a0,0x1
ffffffffc02009f8:	6c450513          	addi	a0,a0,1732 # ffffffffc02020b8 <etext+0x26e>
ffffffffc02009fc:	fd8ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200a00:	00001697          	auipc	a3,0x1
ffffffffc0200a04:	74068693          	addi	a3,a3,1856 # ffffffffc0202140 <etext+0x2f6>
ffffffffc0200a08:	00001617          	auipc	a2,0x1
ffffffffc0200a0c:	69860613          	addi	a2,a2,1688 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200a10:	09f00593          	li	a1,159
ffffffffc0200a14:	00001517          	auipc	a0,0x1
ffffffffc0200a18:	6a450513          	addi	a0,a0,1700 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200a1c:	fb8ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(total == 0);
ffffffffc0200a20:	00002697          	auipc	a3,0x2
ffffffffc0200a24:	96068693          	addi	a3,a3,-1696 # ffffffffc0202380 <etext+0x536>
ffffffffc0200a28:	00001617          	auipc	a2,0x1
ffffffffc0200a2c:	67860613          	addi	a2,a2,1656 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200a30:	11500593          	li	a1,277
ffffffffc0200a34:	00001517          	auipc	a0,0x1
ffffffffc0200a38:	68450513          	addi	a0,a0,1668 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200a3c:	f98ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(total == nr_free_pages());
ffffffffc0200a40:	00001697          	auipc	a3,0x1
ffffffffc0200a44:	6a068693          	addi	a3,a3,1696 # ffffffffc02020e0 <etext+0x296>
ffffffffc0200a48:	00001617          	auipc	a2,0x1
ffffffffc0200a4c:	65860613          	addi	a2,a2,1624 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200a50:	0d600593          	li	a1,214
ffffffffc0200a54:	00001517          	auipc	a0,0x1
ffffffffc0200a58:	66450513          	addi	a0,a0,1636 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200a5c:	f78ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200a60:	00001697          	auipc	a3,0x1
ffffffffc0200a64:	6c068693          	addi	a3,a3,1728 # ffffffffc0202120 <etext+0x2d6>
ffffffffc0200a68:	00001617          	auipc	a2,0x1
ffffffffc0200a6c:	63860613          	addi	a2,a2,1592 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200a70:	09e00593          	li	a1,158
ffffffffc0200a74:	00001517          	auipc	a0,0x1
ffffffffc0200a78:	64450513          	addi	a0,a0,1604 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200a7c:	f58ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200a80:	00001697          	auipc	a3,0x1
ffffffffc0200a84:	68068693          	addi	a3,a3,1664 # ffffffffc0202100 <etext+0x2b6>
ffffffffc0200a88:	00001617          	auipc	a2,0x1
ffffffffc0200a8c:	61860613          	addi	a2,a2,1560 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200a90:	09d00593          	li	a1,157
ffffffffc0200a94:	00001517          	auipc	a0,0x1
ffffffffc0200a98:	62450513          	addi	a0,a0,1572 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200a9c:	f38ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200aa0:	00001697          	auipc	a3,0x1
ffffffffc0200aa4:	78868693          	addi	a3,a3,1928 # ffffffffc0202228 <etext+0x3de>
ffffffffc0200aa8:	00001617          	auipc	a2,0x1
ffffffffc0200aac:	5f860613          	addi	a2,a2,1528 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200ab0:	0ba00593          	li	a1,186
ffffffffc0200ab4:	00001517          	auipc	a0,0x1
ffffffffc0200ab8:	60450513          	addi	a0,a0,1540 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200abc:	f18ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200ac0:	00001697          	auipc	a3,0x1
ffffffffc0200ac4:	68068693          	addi	a3,a3,1664 # ffffffffc0202140 <etext+0x2f6>
ffffffffc0200ac8:	00001617          	auipc	a2,0x1
ffffffffc0200acc:	5d860613          	addi	a2,a2,1496 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200ad0:	0b800593          	li	a1,184
ffffffffc0200ad4:	00001517          	auipc	a0,0x1
ffffffffc0200ad8:	5e450513          	addi	a0,a0,1508 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200adc:	ef8ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200ae0:	00001697          	auipc	a3,0x1
ffffffffc0200ae4:	64068693          	addi	a3,a3,1600 # ffffffffc0202120 <etext+0x2d6>
ffffffffc0200ae8:	00001617          	auipc	a2,0x1
ffffffffc0200aec:	5b860613          	addi	a2,a2,1464 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200af0:	0b700593          	li	a1,183
ffffffffc0200af4:	00001517          	auipc	a0,0x1
ffffffffc0200af8:	5c450513          	addi	a0,a0,1476 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200afc:	ed8ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200b00:	00001697          	auipc	a3,0x1
ffffffffc0200b04:	60068693          	addi	a3,a3,1536 # ffffffffc0202100 <etext+0x2b6>
ffffffffc0200b08:	00001617          	auipc	a2,0x1
ffffffffc0200b0c:	59860613          	addi	a2,a2,1432 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200b10:	0b600593          	li	a1,182
ffffffffc0200b14:	00001517          	auipc	a0,0x1
ffffffffc0200b18:	5a450513          	addi	a0,a0,1444 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200b1c:	eb8ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(nr_free == 3);
ffffffffc0200b20:	00001697          	auipc	a3,0x1
ffffffffc0200b24:	72068693          	addi	a3,a3,1824 # ffffffffc0202240 <etext+0x3f6>
ffffffffc0200b28:	00001617          	auipc	a2,0x1
ffffffffc0200b2c:	57860613          	addi	a2,a2,1400 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200b30:	0b400593          	li	a1,180
ffffffffc0200b34:	00001517          	auipc	a0,0x1
ffffffffc0200b38:	58450513          	addi	a0,a0,1412 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200b3c:	e98ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200b40:	00001697          	auipc	a3,0x1
ffffffffc0200b44:	6e868693          	addi	a3,a3,1768 # ffffffffc0202228 <etext+0x3de>
ffffffffc0200b48:	00001617          	auipc	a2,0x1
ffffffffc0200b4c:	55860613          	addi	a2,a2,1368 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200b50:	0af00593          	li	a1,175
ffffffffc0200b54:	00001517          	auipc	a0,0x1
ffffffffc0200b58:	56450513          	addi	a0,a0,1380 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200b5c:	e78ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200b60:	00001697          	auipc	a3,0x1
ffffffffc0200b64:	6a868693          	addi	a3,a3,1704 # ffffffffc0202208 <etext+0x3be>
ffffffffc0200b68:	00001617          	auipc	a2,0x1
ffffffffc0200b6c:	53860613          	addi	a2,a2,1336 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200b70:	0a600593          	li	a1,166
ffffffffc0200b74:	00001517          	auipc	a0,0x1
ffffffffc0200b78:	54450513          	addi	a0,a0,1348 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200b7c:	e58ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200b80:	00001697          	auipc	a3,0x1
ffffffffc0200b84:	66868693          	addi	a3,a3,1640 # ffffffffc02021e8 <etext+0x39e>
ffffffffc0200b88:	00001617          	auipc	a2,0x1
ffffffffc0200b8c:	51860613          	addi	a2,a2,1304 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200b90:	0a500593          	li	a1,165
ffffffffc0200b94:	00001517          	auipc	a0,0x1
ffffffffc0200b98:	52450513          	addi	a0,a0,1316 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200b9c:	e38ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(count == 0);
ffffffffc0200ba0:	00001697          	auipc	a3,0x1
ffffffffc0200ba4:	7d068693          	addi	a3,a3,2000 # ffffffffc0202370 <etext+0x526>
ffffffffc0200ba8:	00001617          	auipc	a2,0x1
ffffffffc0200bac:	4f860613          	addi	a2,a2,1272 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200bb0:	11400593          	li	a1,276
ffffffffc0200bb4:	00001517          	auipc	a0,0x1
ffffffffc0200bb8:	50450513          	addi	a0,a0,1284 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200bbc:	e18ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(nr_free == 0);
ffffffffc0200bc0:	00001697          	auipc	a3,0x1
ffffffffc0200bc4:	6c868693          	addi	a3,a3,1736 # ffffffffc0202288 <etext+0x43e>
ffffffffc0200bc8:	00001617          	auipc	a2,0x1
ffffffffc0200bcc:	4d860613          	addi	a2,a2,1240 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200bd0:	10900593          	li	a1,265
ffffffffc0200bd4:	00001517          	auipc	a0,0x1
ffffffffc0200bd8:	4e450513          	addi	a0,a0,1252 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200bdc:	df8ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200be0:	00001697          	auipc	a3,0x1
ffffffffc0200be4:	64868693          	addi	a3,a3,1608 # ffffffffc0202228 <etext+0x3de>
ffffffffc0200be8:	00001617          	auipc	a2,0x1
ffffffffc0200bec:	4b860613          	addi	a2,a2,1208 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200bf0:	10300593          	li	a1,259
ffffffffc0200bf4:	00001517          	auipc	a0,0x1
ffffffffc0200bf8:	4c450513          	addi	a0,a0,1220 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200bfc:	dd8ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0200c00:	00001697          	auipc	a3,0x1
ffffffffc0200c04:	75068693          	addi	a3,a3,1872 # ffffffffc0202350 <etext+0x506>
ffffffffc0200c08:	00001617          	auipc	a2,0x1
ffffffffc0200c0c:	49860613          	addi	a2,a2,1176 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200c10:	10200593          	li	a1,258
ffffffffc0200c14:	00001517          	auipc	a0,0x1
ffffffffc0200c18:	4a450513          	addi	a0,a0,1188 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200c1c:	db8ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(p0 + 4 == p1);
ffffffffc0200c20:	00001697          	auipc	a3,0x1
ffffffffc0200c24:	72068693          	addi	a3,a3,1824 # ffffffffc0202340 <etext+0x4f6>
ffffffffc0200c28:	00001617          	auipc	a2,0x1
ffffffffc0200c2c:	47860613          	addi	a2,a2,1144 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200c30:	0fa00593          	li	a1,250
ffffffffc0200c34:	00001517          	auipc	a0,0x1
ffffffffc0200c38:	48450513          	addi	a0,a0,1156 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200c3c:	d98ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(alloc_pages(2) != NULL);
ffffffffc0200c40:	00001697          	auipc	a3,0x1
ffffffffc0200c44:	6e868693          	addi	a3,a3,1768 # ffffffffc0202328 <etext+0x4de>
ffffffffc0200c48:	00001617          	auipc	a2,0x1
ffffffffc0200c4c:	45860613          	addi	a2,a2,1112 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200c50:	0f900593          	li	a1,249
ffffffffc0200c54:	00001517          	auipc	a0,0x1
ffffffffc0200c58:	46450513          	addi	a0,a0,1124 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200c5c:	d78ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc0200c60:	00001697          	auipc	a3,0x1
ffffffffc0200c64:	6a868693          	addi	a3,a3,1704 # ffffffffc0202308 <etext+0x4be>
ffffffffc0200c68:	00001617          	auipc	a2,0x1
ffffffffc0200c6c:	43860613          	addi	a2,a2,1080 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200c70:	0f800593          	li	a1,248
ffffffffc0200c74:	00001517          	auipc	a0,0x1
ffffffffc0200c78:	44450513          	addi	a0,a0,1092 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200c7c:	d58ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc0200c80:	00001697          	auipc	a3,0x1
ffffffffc0200c84:	65868693          	addi	a3,a3,1624 # ffffffffc02022d8 <etext+0x48e>
ffffffffc0200c88:	00001617          	auipc	a2,0x1
ffffffffc0200c8c:	41860613          	addi	a2,a2,1048 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200c90:	0f600593          	li	a1,246
ffffffffc0200c94:	00001517          	auipc	a0,0x1
ffffffffc0200c98:	42450513          	addi	a0,a0,1060 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200c9c:	d38ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(alloc_pages(4) == NULL);
ffffffffc0200ca0:	00001697          	auipc	a3,0x1
ffffffffc0200ca4:	62068693          	addi	a3,a3,1568 # ffffffffc02022c0 <etext+0x476>
ffffffffc0200ca8:	00001617          	auipc	a2,0x1
ffffffffc0200cac:	3f860613          	addi	a2,a2,1016 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200cb0:	0f500593          	li	a1,245
ffffffffc0200cb4:	00001517          	auipc	a0,0x1
ffffffffc0200cb8:	40450513          	addi	a0,a0,1028 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200cbc:	d18ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200cc0:	00001697          	auipc	a3,0x1
ffffffffc0200cc4:	56868693          	addi	a3,a3,1384 # ffffffffc0202228 <etext+0x3de>
ffffffffc0200cc8:	00001617          	auipc	a2,0x1
ffffffffc0200ccc:	3d860613          	addi	a2,a2,984 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200cd0:	0e900593          	li	a1,233
ffffffffc0200cd4:	00001517          	auipc	a0,0x1
ffffffffc0200cd8:	3e450513          	addi	a0,a0,996 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200cdc:	cf8ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(!PageProperty(p0));
ffffffffc0200ce0:	00001697          	auipc	a3,0x1
ffffffffc0200ce4:	5c868693          	addi	a3,a3,1480 # ffffffffc02022a8 <etext+0x45e>
ffffffffc0200ce8:	00001617          	auipc	a2,0x1
ffffffffc0200cec:	3b860613          	addi	a2,a2,952 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200cf0:	0e000593          	li	a1,224
ffffffffc0200cf4:	00001517          	auipc	a0,0x1
ffffffffc0200cf8:	3c450513          	addi	a0,a0,964 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200cfc:	cd8ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(p0 != NULL);
ffffffffc0200d00:	00001697          	auipc	a3,0x1
ffffffffc0200d04:	59868693          	addi	a3,a3,1432 # ffffffffc0202298 <etext+0x44e>
ffffffffc0200d08:	00001617          	auipc	a2,0x1
ffffffffc0200d0c:	39860613          	addi	a2,a2,920 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200d10:	0df00593          	li	a1,223
ffffffffc0200d14:	00001517          	auipc	a0,0x1
ffffffffc0200d18:	3a450513          	addi	a0,a0,932 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200d1c:	cb8ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(nr_free == 0);
ffffffffc0200d20:	00001697          	auipc	a3,0x1
ffffffffc0200d24:	56868693          	addi	a3,a3,1384 # ffffffffc0202288 <etext+0x43e>
ffffffffc0200d28:	00001617          	auipc	a2,0x1
ffffffffc0200d2c:	37860613          	addi	a2,a2,888 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200d30:	0c300593          	li	a1,195
ffffffffc0200d34:	00001517          	auipc	a0,0x1
ffffffffc0200d38:	38450513          	addi	a0,a0,900 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200d3c:	c98ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200d40:	00001697          	auipc	a3,0x1
ffffffffc0200d44:	4e868693          	addi	a3,a3,1256 # ffffffffc0202228 <etext+0x3de>
ffffffffc0200d48:	00001617          	auipc	a2,0x1
ffffffffc0200d4c:	35860613          	addi	a2,a2,856 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200d50:	0c100593          	li	a1,193
ffffffffc0200d54:	00001517          	auipc	a0,0x1
ffffffffc0200d58:	36450513          	addi	a0,a0,868 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200d5c:	c78ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert((p = alloc_page()) == p0);
ffffffffc0200d60:	00001697          	auipc	a3,0x1
ffffffffc0200d64:	50868693          	addi	a3,a3,1288 # ffffffffc0202268 <etext+0x41e>
ffffffffc0200d68:	00001617          	auipc	a2,0x1
ffffffffc0200d6c:	33860613          	addi	a2,a2,824 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200d70:	0c000593          	li	a1,192
ffffffffc0200d74:	00001517          	auipc	a0,0x1
ffffffffc0200d78:	34450513          	addi	a0,a0,836 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200d7c:	c58ff0ef          	jal	ffffffffc02001d4 <__panic>

ffffffffc0200d80 <best_fit_free_pages>:
best_fit_free_pages(struct Page *base, size_t n) {
ffffffffc0200d80:	1141                	addi	sp,sp,-16
ffffffffc0200d82:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200d84:	14058963          	beqz	a1,ffffffffc0200ed6 <best_fit_free_pages+0x156>
    for (; p != base + n; p ++) {
ffffffffc0200d88:	00259713          	slli	a4,a1,0x2
ffffffffc0200d8c:	972e                	add	a4,a4,a1
ffffffffc0200d8e:	070e                	slli	a4,a4,0x3
ffffffffc0200d90:	00e506b3          	add	a3,a0,a4
    struct Page *p = base;
ffffffffc0200d94:	87aa                	mv	a5,a0
    for (; p != base + n; p ++) {
ffffffffc0200d96:	cf09                	beqz	a4,ffffffffc0200db0 <best_fit_free_pages+0x30>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200d98:	6798                	ld	a4,8(a5)
ffffffffc0200d9a:	8b0d                	andi	a4,a4,3
ffffffffc0200d9c:	10071d63          	bnez	a4,ffffffffc0200eb6 <best_fit_free_pages+0x136>
        p->flags = 0;
ffffffffc0200da0:	0007b423          	sd	zero,8(a5)



static inline int page_ref(struct Page *page) { return page->ref; }

static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200da4:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc0200da8:	02878793          	addi	a5,a5,40
ffffffffc0200dac:	fed796e3          	bne	a5,a3,ffffffffc0200d98 <best_fit_free_pages+0x18>
    SetPageProperty(base);
ffffffffc0200db0:	6510                	ld	a2,8(a0)
    nr_free += n;
ffffffffc0200db2:	00005717          	auipc	a4,0x5
ffffffffc0200db6:	27672703          	lw	a4,630(a4) # ffffffffc0206028 <free_area+0x10>
ffffffffc0200dba:	00005697          	auipc	a3,0x5
ffffffffc0200dbe:	25e68693          	addi	a3,a3,606 # ffffffffc0206018 <free_area>
    base->property = n;
ffffffffc0200dc2:	0005881b          	sext.w	a6,a1
    return list->next == list;
ffffffffc0200dc6:	669c                	ld	a5,8(a3)
    SetPageProperty(base);
ffffffffc0200dc8:	00266613          	ori	a2,a2,2
ffffffffc0200dcc:	e510                	sd	a2,8(a0)
    nr_free += n;
ffffffffc0200dce:	0107073b          	addw	a4,a4,a6
    base->property = n;
ffffffffc0200dd2:	01052823          	sw	a6,16(a0)
    nr_free += n;
ffffffffc0200dd6:	ca98                	sw	a4,16(a3)
    if (list_empty(&free_list)) {
ffffffffc0200dd8:	08d78463          	beq	a5,a3,ffffffffc0200e60 <best_fit_free_pages+0xe0>
            struct Page* page = le2page(le, page_link);
ffffffffc0200ddc:	fe878713          	addi	a4,a5,-24
ffffffffc0200de0:	4881                	li	a7,0
ffffffffc0200de2:	01850613          	addi	a2,a0,24
            if (base < page) {
ffffffffc0200de6:	00e56a63          	bltu	a0,a4,ffffffffc0200dfa <best_fit_free_pages+0x7a>
    return listelm->next;
ffffffffc0200dea:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc0200dec:	06d70063          	beq	a4,a3,ffffffffc0200e4c <best_fit_free_pages+0xcc>
    struct Page *p = base;
ffffffffc0200df0:	87ba                	mv	a5,a4
            struct Page* page = le2page(le, page_link);
ffffffffc0200df2:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc0200df6:	fee57ae3          	bgeu	a0,a4,ffffffffc0200dea <best_fit_free_pages+0x6a>
ffffffffc0200dfa:	00088463          	beqz	a7,ffffffffc0200e02 <best_fit_free_pages+0x82>
ffffffffc0200dfe:	0066b023          	sd	t1,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200e02:	6398                	ld	a4,0(a5)
    prev->next = next->prev = elm;
ffffffffc0200e04:	e390                	sd	a2,0(a5)
ffffffffc0200e06:	e710                	sd	a2,8(a4)
    elm->prev = prev;
ffffffffc0200e08:	ed18                	sd	a4,24(a0)
    elm->next = next;
ffffffffc0200e0a:	f11c                	sd	a5,32(a0)
    if (le != &free_list) {
ffffffffc0200e0c:	00d78d63          	beq	a5,a3,ffffffffc0200e26 <best_fit_free_pages+0xa6>
        if (base + base->property == p) {
ffffffffc0200e10:	1582                	slli	a1,a1,0x20
ffffffffc0200e12:	9181                	srli	a1,a1,0x20
ffffffffc0200e14:	00259713          	slli	a4,a1,0x2
ffffffffc0200e18:	972e                	add	a4,a4,a1
ffffffffc0200e1a:	070e                	slli	a4,a4,0x3
        p = le2page(le, page_link);
ffffffffc0200e1c:	fe878613          	addi	a2,a5,-24
        if (base + base->property == p) {
ffffffffc0200e20:	972a                	add	a4,a4,a0
ffffffffc0200e22:	04e60b63          	beq	a2,a4,ffffffffc0200e78 <best_fit_free_pages+0xf8>
    return listelm->prev;
ffffffffc0200e26:	6d18                	ld	a4,24(a0)
    if (le != &free_list) {
ffffffffc0200e28:	00d70f63          	beq	a4,a3,ffffffffc0200e46 <best_fit_free_pages+0xc6>
        if (p + p->property == base) {
ffffffffc0200e2c:	ff872603          	lw	a2,-8(a4)
ffffffffc0200e30:	02061693          	slli	a3,a2,0x20
ffffffffc0200e34:	9281                	srli	a3,a3,0x20
ffffffffc0200e36:	00269793          	slli	a5,a3,0x2
ffffffffc0200e3a:	97b6                	add	a5,a5,a3
ffffffffc0200e3c:	078e                	slli	a5,a5,0x3
ffffffffc0200e3e:	17a1                	addi	a5,a5,-24
ffffffffc0200e40:	97ba                	add	a5,a5,a4
ffffffffc0200e42:	04f50d63          	beq	a0,a5,ffffffffc0200e9c <best_fit_free_pages+0x11c>
}
ffffffffc0200e46:	60a2                	ld	ra,8(sp)
ffffffffc0200e48:	0141                	addi	sp,sp,16
ffffffffc0200e4a:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc0200e4c:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200e4e:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc0200e50:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc0200e52:	ed1c                	sd	a5,24(a0)
                list_add(le, &(base->page_link));
ffffffffc0200e54:	8332                	mv	t1,a2
        while ((le = list_next(le)) != &free_list) {
ffffffffc0200e56:	00d70e63          	beq	a4,a3,ffffffffc0200e72 <best_fit_free_pages+0xf2>
ffffffffc0200e5a:	4885                	li	a7,1
    struct Page *p = base;
ffffffffc0200e5c:	87ba                	mv	a5,a4
ffffffffc0200e5e:	bf51                	j	ffffffffc0200df2 <best_fit_free_pages+0x72>
}
ffffffffc0200e60:	60a2                	ld	ra,8(sp)
        list_add(&free_list, &(base->page_link));
ffffffffc0200e62:	01850713          	addi	a4,a0,24
    elm->next = next;
ffffffffc0200e66:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200e68:	ed1c                	sd	a5,24(a0)
    prev->next = next->prev = elm;
ffffffffc0200e6a:	e398                	sd	a4,0(a5)
ffffffffc0200e6c:	e798                	sd	a4,8(a5)
}
ffffffffc0200e6e:	0141                	addi	sp,sp,16
ffffffffc0200e70:	8082                	ret
ffffffffc0200e72:	e290                	sd	a2,0(a3)
    return listelm->next;
ffffffffc0200e74:	87b6                	mv	a5,a3
ffffffffc0200e76:	bf59                	j	ffffffffc0200e0c <best_fit_free_pages+0x8c>
            base->property += p->property;
ffffffffc0200e78:	ff87a603          	lw	a2,-8(a5)
            ClearPageProperty(p);
ffffffffc0200e7c:	ff07b703          	ld	a4,-16(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc0200e80:	0007b883          	ld	a7,0(a5)
ffffffffc0200e84:	678c                	ld	a1,8(a5)
            base->property += p->property;
ffffffffc0200e86:	0106063b          	addw	a2,a2,a6
ffffffffc0200e8a:	c910                	sw	a2,16(a0)
            ClearPageProperty(p);
ffffffffc0200e8c:	9b75                	andi	a4,a4,-3
ffffffffc0200e8e:	fee7b823          	sd	a4,-16(a5)
    prev->next = next;
ffffffffc0200e92:	00b8b423          	sd	a1,8(a7)
    next->prev = prev;
ffffffffc0200e96:	0115b023          	sd	a7,0(a1)
ffffffffc0200e9a:	b771                	j	ffffffffc0200e26 <best_fit_free_pages+0xa6>
            p->property += base->property;
ffffffffc0200e9c:	4914                	lw	a3,16(a0)
            ClearPageProperty(base);
ffffffffc0200e9e:	651c                	ld	a5,8(a0)
    __list_del(listelm->prev, listelm->next);
ffffffffc0200ea0:	710c                	ld	a1,32(a0)
            p->property += base->property;
ffffffffc0200ea2:	9eb1                	addw	a3,a3,a2
ffffffffc0200ea4:	fed72c23          	sw	a3,-8(a4)
            ClearPageProperty(base);
ffffffffc0200ea8:	9bf5                	andi	a5,a5,-3
ffffffffc0200eaa:	e51c                	sd	a5,8(a0)
}
ffffffffc0200eac:	60a2                	ld	ra,8(sp)
    prev->next = next;
ffffffffc0200eae:	e70c                	sd	a1,8(a4)
    next->prev = prev;
ffffffffc0200eb0:	e198                	sd	a4,0(a1)
ffffffffc0200eb2:	0141                	addi	sp,sp,16
ffffffffc0200eb4:	8082                	ret
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200eb6:	00001697          	auipc	a3,0x1
ffffffffc0200eba:	4da68693          	addi	a3,a3,1242 # ffffffffc0202390 <etext+0x546>
ffffffffc0200ebe:	00001617          	auipc	a2,0x1
ffffffffc0200ec2:	1e260613          	addi	a2,a2,482 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200ec6:	06200593          	li	a1,98
ffffffffc0200eca:	00001517          	auipc	a0,0x1
ffffffffc0200ece:	1ee50513          	addi	a0,a0,494 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200ed2:	b02ff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(n > 0);
ffffffffc0200ed6:	00001697          	auipc	a3,0x1
ffffffffc0200eda:	1c268693          	addi	a3,a3,450 # ffffffffc0202098 <etext+0x24e>
ffffffffc0200ede:	00001617          	auipc	a2,0x1
ffffffffc0200ee2:	1c260613          	addi	a2,a2,450 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200ee6:	05f00593          	li	a1,95
ffffffffc0200eea:	00001517          	auipc	a0,0x1
ffffffffc0200eee:	1ce50513          	addi	a0,a0,462 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200ef2:	ae2ff0ef          	jal	ffffffffc02001d4 <__panic>

ffffffffc0200ef6 <best_fit_init_memmap>:
best_fit_init_memmap(struct Page *base, size_t n) {
ffffffffc0200ef6:	1141                	addi	sp,sp,-16
ffffffffc0200ef8:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200efa:	c9e9                	beqz	a1,ffffffffc0200fcc <best_fit_init_memmap+0xd6>
    for (; p != base + n; p ++) {
ffffffffc0200efc:	00259713          	slli	a4,a1,0x2
ffffffffc0200f00:	972e                	add	a4,a4,a1
ffffffffc0200f02:	070e                	slli	a4,a4,0x3
ffffffffc0200f04:	00e506b3          	add	a3,a0,a4
    struct Page *p = base;
ffffffffc0200f08:	87aa                	mv	a5,a0
    for (; p != base + n; p ++) {
ffffffffc0200f0a:	cf11                	beqz	a4,ffffffffc0200f26 <best_fit_init_memmap+0x30>
        assert(PageReserved(p));
ffffffffc0200f0c:	6798                	ld	a4,8(a5)
ffffffffc0200f0e:	8b05                	andi	a4,a4,1
ffffffffc0200f10:	cf59                	beqz	a4,ffffffffc0200fae <best_fit_init_memmap+0xb8>
        p->flags = p->property = 0;
ffffffffc0200f12:	0007a823          	sw	zero,16(a5)
ffffffffc0200f16:	0007b423          	sd	zero,8(a5)
ffffffffc0200f1a:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc0200f1e:	02878793          	addi	a5,a5,40
ffffffffc0200f22:	fed795e3          	bne	a5,a3,ffffffffc0200f0c <best_fit_init_memmap+0x16>
    SetPageProperty(base);
ffffffffc0200f26:	6510                	ld	a2,8(a0)
    nr_free += n;
ffffffffc0200f28:	00005717          	auipc	a4,0x5
ffffffffc0200f2c:	10072703          	lw	a4,256(a4) # ffffffffc0206028 <free_area+0x10>
ffffffffc0200f30:	00005697          	auipc	a3,0x5
ffffffffc0200f34:	0e868693          	addi	a3,a3,232 # ffffffffc0206018 <free_area>
    base->property = n;
ffffffffc0200f38:	2581                	sext.w	a1,a1
    return list->next == list;
ffffffffc0200f3a:	669c                	ld	a5,8(a3)
    SetPageProperty(base);
ffffffffc0200f3c:	00266613          	ori	a2,a2,2
    base->property = n;
ffffffffc0200f40:	c90c                	sw	a1,16(a0)
    nr_free += n;
ffffffffc0200f42:	9f2d                	addw	a4,a4,a1
    SetPageProperty(base);
ffffffffc0200f44:	e510                	sd	a2,8(a0)
    nr_free += n;
ffffffffc0200f46:	ca98                	sw	a4,16(a3)
    if (list_empty(&free_list)) {
ffffffffc0200f48:	04d78663          	beq	a5,a3,ffffffffc0200f94 <best_fit_init_memmap+0x9e>
            struct Page* page = le2page(le, page_link);
ffffffffc0200f4c:	fe878713          	addi	a4,a5,-24
ffffffffc0200f50:	4581                	li	a1,0
ffffffffc0200f52:	01850613          	addi	a2,a0,24
            if (base < page) {
ffffffffc0200f56:	00e56a63          	bltu	a0,a4,ffffffffc0200f6a <best_fit_init_memmap+0x74>
    return listelm->next;
ffffffffc0200f5a:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc0200f5c:	02d70263          	beq	a4,a3,ffffffffc0200f80 <best_fit_init_memmap+0x8a>
    struct Page *p = base;
ffffffffc0200f60:	87ba                	mv	a5,a4
            struct Page* page = le2page(le, page_link);
ffffffffc0200f62:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc0200f66:	fee57ae3          	bgeu	a0,a4,ffffffffc0200f5a <best_fit_init_memmap+0x64>
ffffffffc0200f6a:	c199                	beqz	a1,ffffffffc0200f70 <best_fit_init_memmap+0x7a>
ffffffffc0200f6c:	0106b023          	sd	a6,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200f70:	6398                	ld	a4,0(a5)
}
ffffffffc0200f72:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc0200f74:	e390                	sd	a2,0(a5)
ffffffffc0200f76:	e710                	sd	a2,8(a4)
    elm->prev = prev;
ffffffffc0200f78:	ed18                	sd	a4,24(a0)
    elm->next = next;
ffffffffc0200f7a:	f11c                	sd	a5,32(a0)
ffffffffc0200f7c:	0141                	addi	sp,sp,16
ffffffffc0200f7e:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc0200f80:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200f82:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc0200f84:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc0200f86:	ed1c                	sd	a5,24(a0)
                list_add(le, &(base->page_link));
ffffffffc0200f88:	8832                	mv	a6,a2
        while ((le = list_next(le)) != &free_list) {
ffffffffc0200f8a:	00d70e63          	beq	a4,a3,ffffffffc0200fa6 <best_fit_init_memmap+0xb0>
ffffffffc0200f8e:	4585                	li	a1,1
    struct Page *p = base;
ffffffffc0200f90:	87ba                	mv	a5,a4
ffffffffc0200f92:	bfc1                	j	ffffffffc0200f62 <best_fit_init_memmap+0x6c>
}
ffffffffc0200f94:	60a2                	ld	ra,8(sp)
        list_add(&free_list, &(base->page_link));
ffffffffc0200f96:	01850713          	addi	a4,a0,24
    elm->next = next;
ffffffffc0200f9a:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200f9c:	ed1c                	sd	a5,24(a0)
    prev->next = next->prev = elm;
ffffffffc0200f9e:	e398                	sd	a4,0(a5)
ffffffffc0200fa0:	e798                	sd	a4,8(a5)
}
ffffffffc0200fa2:	0141                	addi	sp,sp,16
ffffffffc0200fa4:	8082                	ret
ffffffffc0200fa6:	60a2                	ld	ra,8(sp)
ffffffffc0200fa8:	e290                	sd	a2,0(a3)
ffffffffc0200faa:	0141                	addi	sp,sp,16
ffffffffc0200fac:	8082                	ret
        assert(PageReserved(p));
ffffffffc0200fae:	00001697          	auipc	a3,0x1
ffffffffc0200fb2:	40a68693          	addi	a3,a3,1034 # ffffffffc02023b8 <etext+0x56e>
ffffffffc0200fb6:	00001617          	auipc	a2,0x1
ffffffffc0200fba:	0ea60613          	addi	a2,a2,234 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200fbe:	45ed                	li	a1,27
ffffffffc0200fc0:	00001517          	auipc	a0,0x1
ffffffffc0200fc4:	0f850513          	addi	a0,a0,248 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200fc8:	a0cff0ef          	jal	ffffffffc02001d4 <__panic>
    assert(n > 0);
ffffffffc0200fcc:	00001697          	auipc	a3,0x1
ffffffffc0200fd0:	0cc68693          	addi	a3,a3,204 # ffffffffc0202098 <etext+0x24e>
ffffffffc0200fd4:	00001617          	auipc	a2,0x1
ffffffffc0200fd8:	0cc60613          	addi	a2,a2,204 # ffffffffc02020a0 <etext+0x256>
ffffffffc0200fdc:	45e1                	li	a1,24
ffffffffc0200fde:	00001517          	auipc	a0,0x1
ffffffffc0200fe2:	0da50513          	addi	a0,a0,218 # ffffffffc02020b8 <etext+0x26e>
ffffffffc0200fe6:	9eeff0ef          	jal	ffffffffc02001d4 <__panic>

ffffffffc0200fea <alloc_pages>:
}

// alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE
// memory
struct Page *alloc_pages(size_t n) {
    return pmm_manager->alloc_pages(n);
ffffffffc0200fea:	00005797          	auipc	a5,0x5
ffffffffc0200fee:	11e7b783          	ld	a5,286(a5) # ffffffffc0206108 <pmm_manager>
ffffffffc0200ff2:	6f9c                	ld	a5,24(a5)
ffffffffc0200ff4:	8782                	jr	a5

ffffffffc0200ff6 <free_pages>:
}

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    pmm_manager->free_pages(base, n);
ffffffffc0200ff6:	00005797          	auipc	a5,0x5
ffffffffc0200ffa:	1127b783          	ld	a5,274(a5) # ffffffffc0206108 <pmm_manager>
ffffffffc0200ffe:	739c                	ld	a5,32(a5)
ffffffffc0201000:	8782                	jr	a5

ffffffffc0201002 <nr_free_pages>:
}

// nr_free_pages - call pmm->nr_free_pages to get the size (nr*PAGESIZE)
// of current free memory
size_t nr_free_pages(void) {
    return pmm_manager->nr_free_pages();
ffffffffc0201002:	00005797          	auipc	a5,0x5
ffffffffc0201006:	1067b783          	ld	a5,262(a5) # ffffffffc0206108 <pmm_manager>
ffffffffc020100a:	779c                	ld	a5,40(a5)
ffffffffc020100c:	8782                	jr	a5

ffffffffc020100e <pmm_init>:
    pmm_manager = &best_fit_pmm_manager; 
ffffffffc020100e:	00002797          	auipc	a5,0x2
ffffffffc0201012:	8e278793          	addi	a5,a5,-1822 # ffffffffc02028f0 <best_fit_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0201016:	638c                	ld	a1,0(a5)
    // 8. 将空闲页交给分配器
    init_memmap(pages + free_index_start, free_page_count);
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc0201018:	7179                	addi	sp,sp,-48
ffffffffc020101a:	f406                	sd	ra,40(sp)
ffffffffc020101c:	ec26                	sd	s1,24(sp)
ffffffffc020101e:	e84a                	sd	s2,16(sp)
ffffffffc0201020:	f022                	sd	s0,32(sp)
ffffffffc0201022:	e44e                	sd	s3,8(sp)
    pmm_manager = &best_fit_pmm_manager; 
ffffffffc0201024:	00005497          	auipc	s1,0x5
ffffffffc0201028:	0e448493          	addi	s1,s1,228 # ffffffffc0206108 <pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc020102c:	00001517          	auipc	a0,0x1
ffffffffc0201030:	3b450513          	addi	a0,a0,948 # ffffffffc02023e0 <etext+0x596>
    pmm_manager = &best_fit_pmm_manager; 
ffffffffc0201034:	e09c                	sd	a5,0(s1)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0201036:	91cff0ef          	jal	ffffffffc0200152 <cprintf>
    pmm_manager->init();
ffffffffc020103a:	609c                	ld	a5,0(s1)
ffffffffc020103c:	679c                	ld	a5,8(a5)
ffffffffc020103e:	9782                	jalr	a5
    uint64_t memory_base = get_memory_base();
ffffffffc0201040:	d66ff0ef          	jal	ffffffffc02005a6 <get_memory_base>
ffffffffc0201044:	892a                	mv	s2,a0
    uint64_t memory_size = get_memory_size();
ffffffffc0201046:	d6aff0ef          	jal	ffffffffc02005b0 <get_memory_size>
    if (memory_base == 0 || memory_size == 0) {
ffffffffc020104a:	0e090b63          	beqz	s2,ffffffffc0201140 <pmm_init+0x132>
ffffffffc020104e:	c96d                	beqz	a0,ffffffffc0201140 <pmm_init+0x132>
    npage = (memory_base + memory_size) / PGSIZE;
ffffffffc0201050:	00a905b3          	add	a1,s2,a0
ffffffffc0201054:	777d                	lui	a4,0xfffff
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0201056:	57f5                	li	a5,-3
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);
ffffffffc0201058:	00006617          	auipc	a2,0x6
ffffffffc020105c:	0e360613          	addi	a2,a2,227 # ffffffffc020713b <end+0xfff>
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0201060:	07fa                	slli	a5,a5,0x1e
ffffffffc0201062:	8e79                	and	a2,a2,a4
    npage = (memory_base + memory_size) / PGSIZE;
ffffffffc0201064:	00c5d813          	srli	a6,a1,0xc
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0201068:	00005417          	auipc	s0,0x5
ffffffffc020106c:	0b840413          	addi	s0,s0,184 # ffffffffc0206120 <va_pa_offset>
ffffffffc0201070:	e01c                	sd	a5,0(s0)
    npage = (memory_base + memory_size) / PGSIZE;
ffffffffc0201072:	00005717          	auipc	a4,0x5
ffffffffc0201076:	0b073b23          	sd	a6,182(a4) # ffffffffc0206128 <npage>
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);
ffffffffc020107a:	00005797          	auipc	a5,0x5
ffffffffc020107e:	0ac7bb23          	sd	a2,182(a5) # ffffffffc0206130 <pages>
ffffffffc0201082:	00005517          	auipc	a0,0x5
ffffffffc0201086:	0ba50513          	addi	a0,a0,186 # ffffffffc020613c <end>
    for (size_t i = 0; i < npage; i++) {
ffffffffc020108a:	02080163          	beqz	a6,ffffffffc02010ac <pmm_init+0x9e>
ffffffffc020108e:	00281693          	slli	a3,a6,0x2
ffffffffc0201092:	96c2                	add	a3,a3,a6
ffffffffc0201094:	068e                	slli	a3,a3,0x3
ffffffffc0201096:	96b2                	add	a3,a3,a2
ffffffffc0201098:	87b2                	mv	a5,a2
        SetPageReserved(pages + i);
ffffffffc020109a:	6798                	ld	a4,8(a5)
    for (size_t i = 0; i < npage; i++) {
ffffffffc020109c:	02878793          	addi	a5,a5,40
        SetPageReserved(pages + i);
ffffffffc02010a0:	00176713          	ori	a4,a4,1
ffffffffc02010a4:	fee7b023          	sd	a4,-32(a5)
    for (size_t i = 0; i < npage; i++) {
ffffffffc02010a8:	fed799e3          	bne	a5,a3,ffffffffc020109a <pmm_init+0x8c>
    uintptr_t kernel_end_pa = PADDR(end);
ffffffffc02010ac:	c02009b7          	lui	s3,0xc0200
ffffffffc02010b0:	0f356a63          	bltu	a0,s3,ffffffffc02011a4 <pmm_init+0x196>
    uintptr_t pages_array_end_pa = PADDR(pages) + npage * sizeof(struct Page);
ffffffffc02010b4:	0d366b63          	bltu	a2,s3,ffffffffc020118a <pmm_init+0x17c>
    uintptr_t free_pa_start = ROUNDUP(pages_array_end_pa, PGSIZE);
ffffffffc02010b8:	000c0737          	lui	a4,0xc0
ffffffffc02010bc:	0705                	addi	a4,a4,1 # c0001 <kern_entry-0xffffffffc013ffff>
ffffffffc02010be:	0732                	slli	a4,a4,0xc
    uintptr_t pages_array_end_pa = PADDR(pages) + npage * sizeof(struct Page);
ffffffffc02010c0:	00281793          	slli	a5,a6,0x2
    uintptr_t free_pa_start = ROUNDUP(pages_array_end_pa, PGSIZE);
ffffffffc02010c4:	177d                	addi	a4,a4,-1
    uintptr_t pages_array_end_pa = PADDR(pages) + npage * sizeof(struct Page);
ffffffffc02010c6:	97c2                	add	a5,a5,a6
    uintptr_t free_pa_start = ROUNDUP(pages_array_end_pa, PGSIZE);
ffffffffc02010c8:	9732                	add	a4,a4,a2
    uintptr_t pages_array_end_pa = PADDR(pages) + npage * sizeof(struct Page);
ffffffffc02010ca:	078e                	slli	a5,a5,0x3
    uintptr_t free_pa_start = ROUNDUP(pages_array_end_pa, PGSIZE);
ffffffffc02010cc:	97ba                	add	a5,a5,a4
ffffffffc02010ce:	777d                	lui	a4,0xfffff
ffffffffc02010d0:	8ff9                	and	a5,a5,a4
    uintptr_t free_pa_end = ROUNDDOWN(memory_base + memory_size, PGSIZE);
ffffffffc02010d2:	8df9                	and	a1,a1,a4
    if (free_pa_start >= free_pa_end) {
ffffffffc02010d4:	08b7ff63          	bgeu	a5,a1,ffffffffc0201172 <pmm_init+0x164>
    pmm_manager->init_memmap(base, n);
ffffffffc02010d8:	6094                	ld	a3,0(s1)
    size_t free_index_start = (free_pa_start - memory_base) / PGSIZE;
ffffffffc02010da:	41278733          	sub	a4,a5,s2
ffffffffc02010de:	8331                	srli	a4,a4,0xc
    init_memmap(pages + free_index_start, free_page_count);
ffffffffc02010e0:	00271513          	slli	a0,a4,0x2
ffffffffc02010e4:	953a                	add	a0,a0,a4
    pmm_manager->init_memmap(base, n);
ffffffffc02010e6:	6a98                	ld	a4,16(a3)
    size_t free_page_count = (free_pa_end - free_pa_start) / PGSIZE;
ffffffffc02010e8:	8d9d                	sub	a1,a1,a5
    init_memmap(pages + free_index_start, free_page_count);
ffffffffc02010ea:	050e                	slli	a0,a0,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc02010ec:	81b1                	srli	a1,a1,0xc
ffffffffc02010ee:	9532                	add	a0,a0,a2
ffffffffc02010f0:	9702                	jalr	a4
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc02010f2:	609c                	ld	a5,0(s1)
ffffffffc02010f4:	7b9c                	ld	a5,48(a5)
ffffffffc02010f6:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc02010f8:	00001517          	auipc	a0,0x1
ffffffffc02010fc:	38850513          	addi	a0,a0,904 # ffffffffc0202480 <etext+0x636>
ffffffffc0201100:	852ff0ef          	jal	ffffffffc0200152 <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc0201104:	00004597          	auipc	a1,0x4
ffffffffc0201108:	efc58593          	addi	a1,a1,-260 # ffffffffc0205000 <boot_page_table_sv39>
ffffffffc020110c:	00005797          	auipc	a5,0x5
ffffffffc0201110:	00b7b623          	sd	a1,12(a5) # ffffffffc0206118 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc0201114:	0535e263          	bltu	a1,s3,ffffffffc0201158 <pmm_init+0x14a>
ffffffffc0201118:	601c                	ld	a5,0(s0)
}
ffffffffc020111a:	7402                	ld	s0,32(sp)
ffffffffc020111c:	70a2                	ld	ra,40(sp)
ffffffffc020111e:	64e2                	ld	s1,24(sp)
ffffffffc0201120:	6942                	ld	s2,16(sp)
ffffffffc0201122:	69a2                	ld	s3,8(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc0201124:	40f586b3          	sub	a3,a1,a5
ffffffffc0201128:	00005797          	auipc	a5,0x5
ffffffffc020112c:	fed7b423          	sd	a3,-24(a5) # ffffffffc0206110 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0201130:	00001517          	auipc	a0,0x1
ffffffffc0201134:	37050513          	addi	a0,a0,880 # ffffffffc02024a0 <etext+0x656>
ffffffffc0201138:	8636                	mv	a2,a3
}
ffffffffc020113a:	6145                	addi	sp,sp,48
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc020113c:	816ff06f          	j	ffffffffc0200152 <cprintf>
        panic("Invalid physical memory info from DTB!\n");
ffffffffc0201140:	00001617          	auipc	a2,0x1
ffffffffc0201144:	2b860613          	addi	a2,a2,696 # ffffffffc02023f8 <etext+0x5ae>
ffffffffc0201148:	04c00593          	li	a1,76
ffffffffc020114c:	00001517          	auipc	a0,0x1
ffffffffc0201150:	2d450513          	addi	a0,a0,724 # ffffffffc0202420 <etext+0x5d6>
ffffffffc0201154:	880ff0ef          	jal	ffffffffc02001d4 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc0201158:	86ae                	mv	a3,a1
ffffffffc020115a:	00001617          	auipc	a2,0x1
ffffffffc020115e:	2d660613          	addi	a2,a2,726 # ffffffffc0202430 <etext+0x5e6>
ffffffffc0201162:	08c00593          	li	a1,140
ffffffffc0201166:	00001517          	auipc	a0,0x1
ffffffffc020116a:	2ba50513          	addi	a0,a0,698 # ffffffffc0202420 <etext+0x5d6>
ffffffffc020116e:	866ff0ef          	jal	ffffffffc02001d4 <__panic>
        panic("No free physical memory available!\n");
ffffffffc0201172:	00001617          	auipc	a2,0x1
ffffffffc0201176:	2e660613          	addi	a2,a2,742 # ffffffffc0202458 <etext+0x60e>
ffffffffc020117a:	06f00593          	li	a1,111
ffffffffc020117e:	00001517          	auipc	a0,0x1
ffffffffc0201182:	2a250513          	addi	a0,a0,674 # ffffffffc0202420 <etext+0x5d6>
ffffffffc0201186:	84eff0ef          	jal	ffffffffc02001d4 <__panic>
    uintptr_t pages_array_end_pa = PADDR(pages) + npage * sizeof(struct Page);
ffffffffc020118a:	4681                	li	a3,0
ffffffffc020118c:	00001617          	auipc	a2,0x1
ffffffffc0201190:	2a460613          	addi	a2,a2,676 # ffffffffc0202430 <etext+0x5e6>
ffffffffc0201194:	06700593          	li	a1,103
ffffffffc0201198:	00001517          	auipc	a0,0x1
ffffffffc020119c:	28850513          	addi	a0,a0,648 # ffffffffc0202420 <etext+0x5d6>
ffffffffc02011a0:	834ff0ef          	jal	ffffffffc02001d4 <__panic>
    uintptr_t kernel_end_pa = PADDR(end);
ffffffffc02011a4:	00005697          	auipc	a3,0x5
ffffffffc02011a8:	f9868693          	addi	a3,a3,-104 # ffffffffc020613c <end>
ffffffffc02011ac:	00001617          	auipc	a2,0x1
ffffffffc02011b0:	28460613          	addi	a2,a2,644 # ffffffffc0202430 <etext+0x5e6>
ffffffffc02011b4:	06600593          	li	a1,102
ffffffffc02011b8:	00001517          	auipc	a0,0x1
ffffffffc02011bc:	26850513          	addi	a0,a0,616 # ffffffffc0202420 <etext+0x5d6>
ffffffffc02011c0:	814ff0ef          	jal	ffffffffc02001d4 <__panic>

ffffffffc02011c4 <slub_init>:
    return (void *)((uintptr_t)slab + header);
}

void
slub_init(void) {
    if (slub_ready) {
ffffffffc02011c4:	00005797          	auipc	a5,0x5
ffffffffc02011c8:	f747a783          	lw	a5,-140(a5) # ffffffffc0206138 <slub_ready>
ffffffffc02011cc:	eb9d                	bnez	a5,ffffffffc0201202 <slub_init+0x3e>
ffffffffc02011ce:	00001717          	auipc	a4,0x1
ffffffffc02011d2:	7c270713          	addi	a4,a4,1986 # ffffffffc0202990 <slub_sizes>
ffffffffc02011d6:	00005797          	auipc	a5,0x5
ffffffffc02011da:	e6278793          	addi	a5,a5,-414 # ffffffffc0206038 <slub_caches+0x8>
ffffffffc02011de:	00005617          	auipc	a2,0x5
ffffffffc02011e2:	f1a60613          	addi	a2,a2,-230 # ffffffffc02060f8 <memory_size>
        return;
    }
    for (size_t i = 0; i < SLUB_CACHE_COUNT; i ++) {
        slub_caches[i].object_size = slub_sizes[i];
ffffffffc02011e6:	6314                	ld	a3,0(a4)
    elm->prev = elm->next = elm;
ffffffffc02011e8:	e79c                	sd	a5,8(a5)
ffffffffc02011ea:	e39c                	sd	a5,0(a5)
ffffffffc02011ec:	fed7bc23          	sd	a3,-8(a5)
    for (size_t i = 0; i < SLUB_CACHE_COUNT; i ++) {
ffffffffc02011f0:	07e1                	addi	a5,a5,24
ffffffffc02011f2:	0721                	addi	a4,a4,8
ffffffffc02011f4:	fec799e3          	bne	a5,a2,ffffffffc02011e6 <slub_init+0x22>
        list_init(&slub_caches[i].slabs);
    }
    slub_ready = 1;
ffffffffc02011f8:	4785                	li	a5,1
ffffffffc02011fa:	00005717          	auipc	a4,0x5
ffffffffc02011fe:	f2f72f23          	sw	a5,-194(a4) # ffffffffc0206138 <slub_ready>
}
ffffffffc0201202:	8082                	ret

ffffffffc0201204 <slub_alloc>:

void *
slub_alloc(size_t size) {
    if (size == 0) {
ffffffffc0201204:	1e050b63          	beqz	a0,ffffffffc02013fa <slub_alloc+0x1f6>
        return NULL;
    }
    if (!slub_ready) {
ffffffffc0201208:	00005797          	auipc	a5,0x5
ffffffffc020120c:	f307a783          	lw	a5,-208(a5) # ffffffffc0206138 <slub_ready>
slub_alloc(size_t size) {
ffffffffc0201210:	7179                	addi	sp,sp,-48
ffffffffc0201212:	ec26                	sd	s1,24(sp)
ffffffffc0201214:	f406                	sd	ra,40(sp)
ffffffffc0201216:	f022                	sd	s0,32(sp)
ffffffffc0201218:	e84a                	sd	s2,16(sp)
ffffffffc020121a:	84aa                	mv	s1,a0
    if (!slub_ready) {
ffffffffc020121c:	18078c63          	beqz	a5,ffffffffc02013b4 <slub_alloc+0x1b0>
    for (size_t i = 0; i < SLUB_CACHE_COUNT; i ++) {
ffffffffc0201220:	00005917          	auipc	s2,0x5
ffffffffc0201224:	e1090913          	addi	s2,s2,-496 # ffffffffc0206030 <slub_caches>
ffffffffc0201228:	87ca                	mv	a5,s2
ffffffffc020122a:	4401                	li	s0,0
ffffffffc020122c:	46a1                	li	a3,8
        if (size <= slub_caches[i].object_size) {
ffffffffc020122e:	6398                	ld	a4,0(a5)
ffffffffc0201230:	08977163          	bgeu	a4,s1,ffffffffc02012b2 <slub_alloc+0xae>
    for (size_t i = 0; i < SLUB_CACHE_COUNT; i ++) {
ffffffffc0201234:	0405                	addi	s0,s0,1
ffffffffc0201236:	07e1                	addi	a5,a5,24
ffffffffc0201238:	fed41be3          	bne	s0,a3,ffffffffc020122e <slub_alloc+0x2a>
    size_t page_count = ROUNDUP(header + size, PGSIZE) / PGSIZE;
ffffffffc020123c:	6905                	lui	s2,0x1
ffffffffc020123e:	04f90913          	addi	s2,s2,79 # 104f <kern_entry-0xffffffffc01fefb1>
ffffffffc0201242:	9926                	add	s2,s2,s1
ffffffffc0201244:	00c95913          	srli	s2,s2,0xc
    struct Page *page = alloc_pages(page_count);
ffffffffc0201248:	854a                	mv	a0,s2
ffffffffc020124a:	da1ff0ef          	jal	ffffffffc0200fea <alloc_pages>
ffffffffc020124e:	87aa                	mv	a5,a0
    if (page == NULL) {
ffffffffc0201250:	18050e63          	beqz	a0,ffffffffc02013ec <slub_alloc+0x1e8>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0201254:	00005617          	auipc	a2,0x5
ffffffffc0201258:	edc63603          	ld	a2,-292(a2) # ffffffffc0206130 <pages>
ffffffffc020125c:	ccccd737          	lui	a4,0xccccd
ffffffffc0201260:	ccd70713          	addi	a4,a4,-819 # ffffffffcccccccd <end+0xcac6b91>
ffffffffc0201264:	02071693          	slli	a3,a4,0x20
ffffffffc0201268:	8f91                	sub	a5,a5,a2
ffffffffc020126a:	9736                	add	a4,a4,a3
ffffffffc020126c:	878d                	srai	a5,a5,0x3
ffffffffc020126e:	02e787b3          	mul	a5,a5,a4
ffffffffc0201272:	00002597          	auipc	a1,0x2
ffffffffc0201276:	8ee5b583          	ld	a1,-1810(a1) # ffffffffc0202b60 <nbase>
    return (void *)(page2pa(page) + va_pa_offset);
ffffffffc020127a:	00005697          	auipc	a3,0x5
ffffffffc020127e:	ea66b683          	ld	a3,-346(a3) # ffffffffc0206120 <va_pa_offset>
    slab->magic = SLUB_LARGE_MAGIC;
ffffffffc0201282:	00002617          	auipc	a2,0x2
ffffffffc0201286:	8e663603          	ld	a2,-1818(a2) # ffffffffc0202b68 <nbase+0x8>
    slab->inuse = 1;
ffffffffc020128a:	4705                	li	a4,1
ffffffffc020128c:	97ae                	add	a5,a5,a1
    return page2ppn(page) << PGSHIFT;
ffffffffc020128e:	07b2                	slli	a5,a5,0xc
    return (void *)(page2pa(page) + va_pa_offset);
ffffffffc0201290:	97b6                	add	a5,a5,a3
    list_init(&slab->link);
ffffffffc0201292:	03878693          	addi	a3,a5,56
    slab->cache_index = SLUB_CACHE_COUNT;
ffffffffc0201296:	e780                	sd	s0,8(a5)
    slab->pages = page_count;
ffffffffc0201298:	0327b023          	sd	s2,32(a5)
    slab->requested = size;
ffffffffc020129c:	f784                	sd	s1,40(a5)
    slab->free_list = NULL;
ffffffffc020129e:	0207b823          	sd	zero,48(a5)
    slab->magic = SLUB_LARGE_MAGIC;
ffffffffc02012a2:	e390                	sd	a2,0(a5)
ffffffffc02012a4:	e3b4                	sd	a3,64(a5)
ffffffffc02012a6:	ff94                	sd	a3,56(a5)
    slab->inuse = 1;
ffffffffc02012a8:	eb98                	sd	a4,16(a5)
    slab->total = 1;
ffffffffc02012aa:	ef98                	sd	a4,24(a5)
    return (void *)((uintptr_t)slab + header);
ffffffffc02012ac:	05078513          	addi	a0,a5,80
ffffffffc02012b0:	a8e5                	j	ffffffffc02013a8 <slub_alloc+0x1a4>
ffffffffc02012b2:	e44e                	sd	s3,8(sp)
        return slub_alloc_large(size);
    }

    struct slub_cache *cache = &slub_caches[cache_index];
    struct slub_page *slab = NULL;
    list_entry_t *entry = &cache->slabs;
ffffffffc02012b4:	00141993          	slli	s3,s0,0x1
ffffffffc02012b8:	008984b3          	add	s1,s3,s0
ffffffffc02012bc:	048e                	slli	s1,s1,0x3
ffffffffc02012be:	04a1                	addi	s1,s1,8
ffffffffc02012c0:	94ca                	add	s1,s1,s2
ffffffffc02012c2:	87a6                	mv	a5,s1
    while ((entry = list_next(entry)) != &cache->slabs) {
ffffffffc02012c4:	a021                	j	ffffffffc02012cc <slub_alloc+0xc8>
        struct slub_page *candidate =
            to_struct(entry, struct slub_page, link);
        if (candidate->free_list != NULL) {
ffffffffc02012c6:	ff87b503          	ld	a0,-8(a5)
ffffffffc02012ca:	e171                	bnez	a0,ffffffffc020138e <slub_alloc+0x18a>
    return listelm->next;
ffffffffc02012cc:	679c                	ld	a5,8(a5)
    while ((entry = list_next(entry)) != &cache->slabs) {
ffffffffc02012ce:	fef49ce3          	bne	s1,a5,ffffffffc02012c6 <slub_alloc+0xc2>
    struct Page *page = alloc_page();
ffffffffc02012d2:	4505                	li	a0,1
ffffffffc02012d4:	d17ff0ef          	jal	ffffffffc0200fea <alloc_pages>
    if (page == NULL) {
ffffffffc02012d8:	10050963          	beqz	a0,ffffffffc02013ea <slub_alloc+0x1e6>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc02012dc:	00005797          	auipc	a5,0x5
ffffffffc02012e0:	e547b783          	ld	a5,-428(a5) # ffffffffc0206130 <pages>
ffffffffc02012e4:	ccccd737          	lui	a4,0xccccd
ffffffffc02012e8:	ccd70713          	addi	a4,a4,-819 # ffffffffcccccccd <end+0xcac6b91>
ffffffffc02012ec:	02071693          	slli	a3,a4,0x20
ffffffffc02012f0:	40f507b3          	sub	a5,a0,a5
ffffffffc02012f4:	9736                	add	a4,a4,a3
ffffffffc02012f6:	878d                	srai	a5,a5,0x3
ffffffffc02012f8:	02e787b3          	mul	a5,a5,a4
    size_t total = (PGSIZE - header) / cache->object_size;
ffffffffc02012fc:	00898733          	add	a4,s3,s0
ffffffffc0201300:	00002617          	auipc	a2,0x2
ffffffffc0201304:	86063603          	ld	a2,-1952(a2) # ffffffffc0202b60 <nbase>
ffffffffc0201308:	070e                	slli	a4,a4,0x3
ffffffffc020130a:	974a                	add	a4,a4,s2
    return (void *)(page2pa(page) + va_pa_offset);
ffffffffc020130c:	00005697          	auipc	a3,0x5
ffffffffc0201310:	e146b683          	ld	a3,-492(a3) # ffffffffc0206120 <va_pa_offset>
    size_t total = (PGSIZE - header) / cache->object_size;
ffffffffc0201314:	630c                	ld	a1,0(a4)
ffffffffc0201316:	6705                	lui	a4,0x1
ffffffffc0201318:	fb070713          	addi	a4,a4,-80 # fb0 <kern_entry-0xffffffffc01ff050>
ffffffffc020131c:	97b2                	add	a5,a5,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc020131e:	07b2                	slli	a5,a5,0xc
    return (void *)(page2pa(page) + va_pa_offset);
ffffffffc0201320:	97b6                	add	a5,a5,a3
    size_t total = (PGSIZE - header) / cache->object_size;
ffffffffc0201322:	02b756b3          	divu	a3,a4,a1
    assert(total > 0);
ffffffffc0201326:	0cb76c63          	bltu	a4,a1,ffffffffc02013fe <slub_alloc+0x1fa>
    slab->magic = SLUB_SMALL_MAGIC;
ffffffffc020132a:	fff68613          	addi	a2,a3,-1
ffffffffc020132e:	00002817          	auipc	a6,0x2
ffffffffc0201332:	84283803          	ld	a6,-1982(a6) # ffffffffc0202b70 <nbase+0x10>
    slab->pages = 1;
ffffffffc0201336:	4505                	li	a0,1
    slab->total = total;
ffffffffc0201338:	ef94                	sd	a3,24(a5)
    slab->cache_index = cache_index;
ffffffffc020133a:	e780                	sd	s0,8(a5)
    slab->requested = 0;
ffffffffc020133c:	0207b423          	sd	zero,40(a5)
    slab->magic = SLUB_SMALL_MAGIC;
ffffffffc0201340:	0107b023          	sd	a6,0(a5)
    slab->pages = 1;
ffffffffc0201344:	f388                	sd	a0,32(a5)
    slab->requested = 0;
ffffffffc0201346:	4681                	li	a3,0
ffffffffc0201348:	02b60733          	mul	a4,a2,a1
ffffffffc020134c:	05070713          	addi	a4,a4,80
ffffffffc0201350:	973e                	add	a4,a4,a5
ffffffffc0201352:	a011                	j	ffffffffc0201356 <slub_alloc+0x152>
ffffffffc0201354:	167d                	addi	a2,a2,-1
        *(void **)object = slab->free_list;
ffffffffc0201356:	e314                	sd	a3,0(a4)
        void *object = (void *)(first + (i - 1) * cache->object_size);
ffffffffc0201358:	86ba                	mv	a3,a4
    for (size_t i = total; i > 0; i --) {
ffffffffc020135a:	8f0d                	sub	a4,a4,a1
ffffffffc020135c:	fe65                	bnez	a2,ffffffffc0201354 <slub_alloc+0x150>
    __list_add(elm, listelm, listelm->next);
ffffffffc020135e:	00898733          	add	a4,s3,s0
ffffffffc0201362:	070e                	slli	a4,a4,0x3
ffffffffc0201364:	fb94                	sd	a3,48(a5)
ffffffffc0201366:	974a                	add	a4,a4,s2
ffffffffc0201368:	6b14                	ld	a3,16(a4)
    list_add(&cache->slabs, &slab->link);
ffffffffc020136a:	03878613          	addi	a2,a5,56
    void *object = slab->free_list;
    slab->free_list = *(void **)object;
    slab->inuse ++;
    assert(slab->inuse <= slab->total);
    return object;
}
ffffffffc020136e:	70a2                	ld	ra,40(sp)
    prev->next = next->prev = elm;
ffffffffc0201370:	e290                	sd	a2,0(a3)
ffffffffc0201372:	eb10                	sd	a2,16(a4)
    void *object = slab->free_list;
ffffffffc0201374:	7b88                	ld	a0,48(a5)
    elm->prev = prev;
ffffffffc0201376:	ff84                	sd	s1,56(a5)
    elm->next = next;
ffffffffc0201378:	e3b4                	sd	a3,64(a5)
    slab->free_list = *(void **)object;
ffffffffc020137a:	6118                	ld	a4,0(a0)
}
ffffffffc020137c:	7402                	ld	s0,32(sp)
    slab->inuse ++;
ffffffffc020137e:	4585                	li	a1,1
ffffffffc0201380:	eb8c                	sd	a1,16(a5)
    slab->free_list = *(void **)object;
ffffffffc0201382:	fb98                	sd	a4,48(a5)
    assert(slab->inuse <= slab->total);
ffffffffc0201384:	69a2                	ld	s3,8(sp)
}
ffffffffc0201386:	64e2                	ld	s1,24(sp)
ffffffffc0201388:	6942                	ld	s2,16(sp)
ffffffffc020138a:	6145                	addi	sp,sp,48
ffffffffc020138c:	8082                	ret
    slab->inuse ++;
ffffffffc020138e:	fd87b703          	ld	a4,-40(a5)
    slab->free_list = *(void **)object;
ffffffffc0201392:	6110                	ld	a2,0(a0)
    assert(slab->inuse <= slab->total);
ffffffffc0201394:	fe07b683          	ld	a3,-32(a5)
    slab->inuse ++;
ffffffffc0201398:	0705                	addi	a4,a4,1
ffffffffc020139a:	fce7bc23          	sd	a4,-40(a5)
    slab->free_list = *(void **)object;
ffffffffc020139e:	fec7bc23          	sd	a2,-8(a5)
    assert(slab->inuse <= slab->total);
ffffffffc02013a2:	06e6ee63          	bltu	a3,a4,ffffffffc020141e <slub_alloc+0x21a>
ffffffffc02013a6:	69a2                	ld	s3,8(sp)
}
ffffffffc02013a8:	70a2                	ld	ra,40(sp)
ffffffffc02013aa:	7402                	ld	s0,32(sp)
ffffffffc02013ac:	64e2                	ld	s1,24(sp)
ffffffffc02013ae:	6942                	ld	s2,16(sp)
ffffffffc02013b0:	6145                	addi	sp,sp,48
ffffffffc02013b2:	8082                	ret
ffffffffc02013b4:	00001717          	auipc	a4,0x1
ffffffffc02013b8:	5dc70713          	addi	a4,a4,1500 # ffffffffc0202990 <slub_sizes>
ffffffffc02013bc:	00005797          	auipc	a5,0x5
ffffffffc02013c0:	c7c78793          	addi	a5,a5,-900 # ffffffffc0206038 <slub_caches+0x8>
ffffffffc02013c4:	00005617          	auipc	a2,0x5
ffffffffc02013c8:	d3460613          	addi	a2,a2,-716 # ffffffffc02060f8 <memory_size>
        slub_caches[i].object_size = slub_sizes[i];
ffffffffc02013cc:	6314                	ld	a3,0(a4)
    elm->prev = elm->next = elm;
ffffffffc02013ce:	e79c                	sd	a5,8(a5)
ffffffffc02013d0:	e39c                	sd	a5,0(a5)
ffffffffc02013d2:	fed7bc23          	sd	a3,-8(a5)
    for (size_t i = 0; i < SLUB_CACHE_COUNT; i ++) {
ffffffffc02013d6:	07e1                	addi	a5,a5,24
ffffffffc02013d8:	0721                	addi	a4,a4,8
ffffffffc02013da:	fec799e3          	bne	a5,a2,ffffffffc02013cc <slub_alloc+0x1c8>
    slub_ready = 1;
ffffffffc02013de:	4785                	li	a5,1
ffffffffc02013e0:	00005717          	auipc	a4,0x5
ffffffffc02013e4:	d4f72c23          	sw	a5,-680(a4) # ffffffffc0206138 <slub_ready>
ffffffffc02013e8:	bd25                	j	ffffffffc0201220 <slub_alloc+0x1c>
ffffffffc02013ea:	69a2                	ld	s3,8(sp)
}
ffffffffc02013ec:	70a2                	ld	ra,40(sp)
ffffffffc02013ee:	7402                	ld	s0,32(sp)
ffffffffc02013f0:	64e2                	ld	s1,24(sp)
ffffffffc02013f2:	6942                	ld	s2,16(sp)
        return NULL;
ffffffffc02013f4:	4501                	li	a0,0
}
ffffffffc02013f6:	6145                	addi	sp,sp,48
ffffffffc02013f8:	8082                	ret
        return NULL;
ffffffffc02013fa:	4501                	li	a0,0
}
ffffffffc02013fc:	8082                	ret
    assert(total > 0);
ffffffffc02013fe:	00001697          	auipc	a3,0x1
ffffffffc0201402:	0e268693          	addi	a3,a3,226 # ffffffffc02024e0 <etext+0x696>
ffffffffc0201406:	00001617          	auipc	a2,0x1
ffffffffc020140a:	c9a60613          	addi	a2,a2,-870 # ffffffffc02020a0 <etext+0x256>
ffffffffc020140e:	04b00593          	li	a1,75
ffffffffc0201412:	00001517          	auipc	a0,0x1
ffffffffc0201416:	0de50513          	addi	a0,a0,222 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc020141a:	dbbfe0ef          	jal	ffffffffc02001d4 <__panic>
    assert(slab->inuse <= slab->total);
ffffffffc020141e:	00001697          	auipc	a3,0x1
ffffffffc0201422:	0e268693          	addi	a3,a3,226 # ffffffffc0202500 <etext+0x6b6>
ffffffffc0201426:	00001617          	auipc	a2,0x1
ffffffffc020142a:	c7a60613          	addi	a2,a2,-902 # ffffffffc02020a0 <etext+0x256>
ffffffffc020142e:	0a300593          	li	a1,163
ffffffffc0201432:	00001517          	auipc	a0,0x1
ffffffffc0201436:	0be50513          	addi	a0,a0,190 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc020143a:	d9bfe0ef          	jal	ffffffffc02001d4 <__panic>

ffffffffc020143e <slub_free>:
    }
}

void
slub_free(void *ptr) {
    if (ptr == NULL) {
ffffffffc020143e:	12050963          	beqz	a0,ffffffffc0201570 <slub_free+0x132>
        return;
    }

    struct slub_page *slab =
        (struct slub_page *)ROUNDDOWN((uintptr_t)ptr, PGSIZE);
ffffffffc0201442:	76fd                	lui	a3,0xfffff
    assert(slab->magic == SLUB_SMALL_MAGIC ||
ffffffffc0201444:	534c57b7          	lui	a5,0x534c5
        (struct slub_page *)ROUNDDOWN((uintptr_t)ptr, PGSIZE);
ffffffffc0201448:	8ee9                	and	a3,a3,a0
    assert(slab->magic == SLUB_SMALL_MAGIC ||
ffffffffc020144a:	54278793          	addi	a5,a5,1346 # 534c5542 <kern_entry-0xffffffff6cd3aabe>
ffffffffc020144e:	534d4737          	lui	a4,0x534d4
ffffffffc0201452:	6290                	ld	a2,0(a3)
slub_free(void *ptr) {
ffffffffc0201454:	1141                	addi	sp,sp,-16
    assert(slab->magic == SLUB_SMALL_MAGIC ||
ffffffffc0201456:	1782                	slli	a5,a5,0x20
ffffffffc0201458:	14c70713          	addi	a4,a4,332 # 534d414c <kern_entry-0xffffffff6cd2beb4>
slub_free(void *ptr) {
ffffffffc020145c:	e406                	sd	ra,8(sp)
    assert(slab->magic == SLUB_SMALL_MAGIC ||
ffffffffc020145e:	97ba                	add	a5,a5,a4
ffffffffc0201460:	06f60763          	beq	a2,a5,ffffffffc02014ce <slub_free+0x90>
ffffffffc0201464:	534c57b7          	lui	a5,0x534c5
ffffffffc0201468:	54278793          	addi	a5,a5,1346 # 534c5542 <kern_entry-0xffffffff6cd3aabe>
ffffffffc020146c:	4c415737          	lui	a4,0x4c415
ffffffffc0201470:	1782                	slli	a5,a5,0x20
ffffffffc0201472:	24770713          	addi	a4,a4,583 # 4c415247 <kern_entry-0xffffffff73deadb9>
ffffffffc0201476:	97ba                	add	a5,a5,a4
ffffffffc0201478:	20f61563          	bne	a2,a5,ffffffffc0201682 <slub_free+0x244>
           slab->magic == SLUB_LARGE_MAGIC);

    if (slab->magic == SLUB_LARGE_MAGIC) {
        assert((uintptr_t)ptr == (uintptr_t)slab + slub_header_size());
ffffffffc020147c:	05068793          	addi	a5,a3,80 # fffffffffffff050 <end+0x3fdf8f14>
ffffffffc0201480:	1ea79163          	bne	a5,a0,ffffffffc0201662 <slub_free+0x224>
        size_t pages_to_free = slab->pages;
        slab->magic = 0;
ffffffffc0201484:	0006b023          	sd	zero,0(a3)
        free_pages(pa2page(PADDR(slab)), pages_to_free);
ffffffffc0201488:	c02007b7          	lui	a5,0xc0200
        size_t pages_to_free = slab->pages;
ffffffffc020148c:	728c                	ld	a1,32(a3)
        free_pages(pa2page(PADDR(slab)), pages_to_free);
ffffffffc020148e:	20f6ea63          	bltu	a3,a5,ffffffffc02016a2 <slub_free+0x264>
ffffffffc0201492:	00005797          	auipc	a5,0x5
ffffffffc0201496:	c8e7b783          	ld	a5,-882(a5) # ffffffffc0206120 <va_pa_offset>
static inline int page_ref_dec(struct Page *page) {
    page->ref -= 1;
    return page->ref;
}
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc020149a:	00005717          	auipc	a4,0x5
ffffffffc020149e:	c8e73703          	ld	a4,-882(a4) # ffffffffc0206128 <npage>
ffffffffc02014a2:	40f687b3          	sub	a5,a3,a5
ffffffffc02014a6:	83b1                	srli	a5,a5,0xc
ffffffffc02014a8:	0ee7f563          	bgeu	a5,a4,ffffffffc0201592 <slub_free+0x154>
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc02014ac:	00001717          	auipc	a4,0x1
ffffffffc02014b0:	6b473703          	ld	a4,1716(a4) # ffffffffc0202b60 <nbase>
ffffffffc02014b4:	00005517          	auipc	a0,0x5
ffffffffc02014b8:	c7c53503          	ld	a0,-900(a0) # ffffffffc0206130 <pages>
ffffffffc02014bc:	8f99                	sub	a5,a5,a4
ffffffffc02014be:	00279713          	slli	a4,a5,0x2
    if (slab->inuse == 0) {
        list_del(&slab->link);
        slab->magic = 0;
        free_page(pa2page(PADDR(slab)));
    }
}
ffffffffc02014c2:	60a2                	ld	ra,8(sp)
ffffffffc02014c4:	97ba                	add	a5,a5,a4
ffffffffc02014c6:	078e                	slli	a5,a5,0x3
        free_page(pa2page(PADDR(slab)));
ffffffffc02014c8:	953e                	add	a0,a0,a5
}
ffffffffc02014ca:	0141                	addi	sp,sp,16
        free_page(pa2page(PADDR(slab)));
ffffffffc02014cc:	b62d                	j	ffffffffc0200ff6 <free_pages>
    assert(slab->cache_index < SLUB_CACHE_COUNT);
ffffffffc02014ce:	6698                	ld	a4,8(a3)
ffffffffc02014d0:	479d                	li	a5,7
ffffffffc02014d2:	0ce7ec63          	bltu	a5,a4,ffffffffc02015aa <slub_free+0x16c>
    size_t object_size = slub_caches[slab->cache_index].object_size;
ffffffffc02014d6:	00171793          	slli	a5,a4,0x1
ffffffffc02014da:	97ba                	add	a5,a5,a4
ffffffffc02014dc:	078e                	slli	a5,a5,0x3
ffffffffc02014de:	00005717          	auipc	a4,0x5
ffffffffc02014e2:	b5270713          	addi	a4,a4,-1198 # ffffffffc0206030 <slub_caches>
ffffffffc02014e6:	973e                	add	a4,a4,a5
    uintptr_t first = (uintptr_t)slab + slub_header_size();
ffffffffc02014e8:	05068793          	addi	a5,a3,80
    size_t object_size = slub_caches[slab->cache_index].object_size;
ffffffffc02014ec:	6310                	ld	a2,0(a4)
    assert(address >= first);
ffffffffc02014ee:	0cf56e63          	bltu	a0,a5,ffffffffc02015ca <slub_free+0x18c>
    assert(address < first + slab->total * object_size);
ffffffffc02014f2:	6e98                	ld	a4,24(a3)
ffffffffc02014f4:	02e60733          	mul	a4,a2,a4
ffffffffc02014f8:	973e                	add	a4,a4,a5
ffffffffc02014fa:	0ee57863          	bgeu	a0,a4,ffffffffc02015ea <slub_free+0x1ac>
    assert((address - first) % object_size == 0);
ffffffffc02014fe:	40f507b3          	sub	a5,a0,a5
ffffffffc0201502:	02c7f7b3          	remu	a5,a5,a2
ffffffffc0201506:	12079e63          	bnez	a5,ffffffffc0201642 <slub_free+0x204>
    for (void *free_object = slab->free_list;
ffffffffc020150a:	7a98                	ld	a4,48(a3)
         free_object != NULL;
ffffffffc020150c:	c711                	beqz	a4,ffffffffc0201518 <slub_free+0xda>
    for (void *free_object = slab->free_list;
ffffffffc020150e:	87ba                	mv	a5,a4
        assert(free_object != ptr);
ffffffffc0201510:	06a78163          	beq	a5,a0,ffffffffc0201572 <slub_free+0x134>
         free_object = *(void **)free_object) {
ffffffffc0201514:	639c                	ld	a5,0(a5)
         free_object != NULL;
ffffffffc0201516:	ffed                	bnez	a5,ffffffffc0201510 <slub_free+0xd2>
    assert(slab->inuse > 0);
ffffffffc0201518:	6a9c                	ld	a5,16(a3)
ffffffffc020151a:	0e078863          	beqz	a5,ffffffffc020160a <slub_free+0x1cc>
    *(void **)ptr = slab->free_list;
ffffffffc020151e:	e118                	sd	a4,0(a0)
    slab->inuse --;
ffffffffc0201520:	17fd                	addi	a5,a5,-1
ffffffffc0201522:	ea9c                	sd	a5,16(a3)
    slab->free_list = ptr;
ffffffffc0201524:	fa88                	sd	a0,48(a3)
    if (slab->inuse == 0) {
ffffffffc0201526:	e3b1                	bnez	a5,ffffffffc020156a <slub_free+0x12c>
    __list_del(listelm->prev, listelm->next);
ffffffffc0201528:	7e98                	ld	a4,56(a3)
ffffffffc020152a:	62bc                	ld	a5,64(a3)
        free_page(pa2page(PADDR(slab)));
ffffffffc020152c:	c0200637          	lui	a2,0xc0200
    prev->next = next;
ffffffffc0201530:	e71c                	sd	a5,8(a4)
    next->prev = prev;
ffffffffc0201532:	e398                	sd	a4,0(a5)
        slab->magic = 0;
ffffffffc0201534:	0006b023          	sd	zero,0(a3)
        free_page(pa2page(PADDR(slab)));
ffffffffc0201538:	0ec6e963          	bltu	a3,a2,ffffffffc020162a <slub_free+0x1ec>
ffffffffc020153c:	00005797          	auipc	a5,0x5
ffffffffc0201540:	be47b783          	ld	a5,-1052(a5) # ffffffffc0206120 <va_pa_offset>
    if (PPN(pa) >= npage) {
ffffffffc0201544:	00005717          	auipc	a4,0x5
ffffffffc0201548:	be473703          	ld	a4,-1052(a4) # ffffffffc0206128 <npage>
ffffffffc020154c:	40f687b3          	sub	a5,a3,a5
ffffffffc0201550:	83b1                	srli	a5,a5,0xc
ffffffffc0201552:	04e7f063          	bgeu	a5,a4,ffffffffc0201592 <slub_free+0x154>
    return &pages[PPN(pa) - nbase];
ffffffffc0201556:	00001717          	auipc	a4,0x1
ffffffffc020155a:	60a73703          	ld	a4,1546(a4) # ffffffffc0202b60 <nbase>
ffffffffc020155e:	00005517          	auipc	a0,0x5
ffffffffc0201562:	bd253503          	ld	a0,-1070(a0) # ffffffffc0206130 <pages>
ffffffffc0201566:	4585                	li	a1,1
ffffffffc0201568:	bf91                	j	ffffffffc02014bc <slub_free+0x7e>
}
ffffffffc020156a:	60a2                	ld	ra,8(sp)
ffffffffc020156c:	0141                	addi	sp,sp,16
ffffffffc020156e:	8082                	ret
ffffffffc0201570:	8082                	ret
        assert(free_object != ptr);
ffffffffc0201572:	00001697          	auipc	a3,0x1
ffffffffc0201576:	0f668693          	addi	a3,a3,246 # ffffffffc0202668 <etext+0x81e>
ffffffffc020157a:	00001617          	auipc	a2,0x1
ffffffffc020157e:	b2660613          	addi	a2,a2,-1242 # ffffffffc02020a0 <etext+0x256>
ffffffffc0201582:	0b400593          	li	a1,180
ffffffffc0201586:	00001517          	auipc	a0,0x1
ffffffffc020158a:	f6a50513          	addi	a0,a0,-150 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc020158e:	c47fe0ef          	jal	ffffffffc02001d4 <__panic>
        panic("pa2page called with invalid pa");
ffffffffc0201592:	00001617          	auipc	a2,0x1
ffffffffc0201596:	00e60613          	addi	a2,a2,14 # ffffffffc02025a0 <etext+0x756>
ffffffffc020159a:	06a00593          	li	a1,106
ffffffffc020159e:	00001517          	auipc	a0,0x1
ffffffffc02015a2:	02250513          	addi	a0,a0,34 # ffffffffc02025c0 <etext+0x776>
ffffffffc02015a6:	c2ffe0ef          	jal	ffffffffc02001d4 <__panic>
    assert(slab->cache_index < SLUB_CACHE_COUNT);
ffffffffc02015aa:	00001697          	auipc	a3,0x1
ffffffffc02015ae:	02668693          	addi	a3,a3,38 # ffffffffc02025d0 <etext+0x786>
ffffffffc02015b2:	00001617          	auipc	a2,0x1
ffffffffc02015b6:	aee60613          	addi	a2,a2,-1298 # ffffffffc02020a0 <etext+0x256>
ffffffffc02015ba:	0a900593          	li	a1,169
ffffffffc02015be:	00001517          	auipc	a0,0x1
ffffffffc02015c2:	f3250513          	addi	a0,a0,-206 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc02015c6:	c0ffe0ef          	jal	ffffffffc02001d4 <__panic>
    assert(address >= first);
ffffffffc02015ca:	00001697          	auipc	a3,0x1
ffffffffc02015ce:	02e68693          	addi	a3,a3,46 # ffffffffc02025f8 <etext+0x7ae>
ffffffffc02015d2:	00001617          	auipc	a2,0x1
ffffffffc02015d6:	ace60613          	addi	a2,a2,-1330 # ffffffffc02020a0 <etext+0x256>
ffffffffc02015da:	0ad00593          	li	a1,173
ffffffffc02015de:	00001517          	auipc	a0,0x1
ffffffffc02015e2:	f1250513          	addi	a0,a0,-238 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc02015e6:	beffe0ef          	jal	ffffffffc02001d4 <__panic>
    assert(address < first + slab->total * object_size);
ffffffffc02015ea:	00001697          	auipc	a3,0x1
ffffffffc02015ee:	02668693          	addi	a3,a3,38 # ffffffffc0202610 <etext+0x7c6>
ffffffffc02015f2:	00001617          	auipc	a2,0x1
ffffffffc02015f6:	aae60613          	addi	a2,a2,-1362 # ffffffffc02020a0 <etext+0x256>
ffffffffc02015fa:	0ae00593          	li	a1,174
ffffffffc02015fe:	00001517          	auipc	a0,0x1
ffffffffc0201602:	ef250513          	addi	a0,a0,-270 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc0201606:	bcffe0ef          	jal	ffffffffc02001d4 <__panic>
    assert(slab->inuse > 0);
ffffffffc020160a:	00001697          	auipc	a3,0x1
ffffffffc020160e:	07668693          	addi	a3,a3,118 # ffffffffc0202680 <etext+0x836>
ffffffffc0201612:	00001617          	auipc	a2,0x1
ffffffffc0201616:	a8e60613          	addi	a2,a2,-1394 # ffffffffc02020a0 <etext+0x256>
ffffffffc020161a:	0cc00593          	li	a1,204
ffffffffc020161e:	00001517          	auipc	a0,0x1
ffffffffc0201622:	ed250513          	addi	a0,a0,-302 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc0201626:	baffe0ef          	jal	ffffffffc02001d4 <__panic>
        free_page(pa2page(PADDR(slab)));
ffffffffc020162a:	00001617          	auipc	a2,0x1
ffffffffc020162e:	e0660613          	addi	a2,a2,-506 # ffffffffc0202430 <etext+0x5e6>
ffffffffc0201632:	0d400593          	li	a1,212
ffffffffc0201636:	00001517          	auipc	a0,0x1
ffffffffc020163a:	eba50513          	addi	a0,a0,-326 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc020163e:	b97fe0ef          	jal	ffffffffc02001d4 <__panic>
    assert((address - first) % object_size == 0);
ffffffffc0201642:	00001697          	auipc	a3,0x1
ffffffffc0201646:	ffe68693          	addi	a3,a3,-2 # ffffffffc0202640 <etext+0x7f6>
ffffffffc020164a:	00001617          	auipc	a2,0x1
ffffffffc020164e:	a5660613          	addi	a2,a2,-1450 # ffffffffc02020a0 <etext+0x256>
ffffffffc0201652:	0af00593          	li	a1,175
ffffffffc0201656:	00001517          	auipc	a0,0x1
ffffffffc020165a:	e9a50513          	addi	a0,a0,-358 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc020165e:	b77fe0ef          	jal	ffffffffc02001d4 <__panic>
        assert((uintptr_t)ptr == (uintptr_t)slab + slub_header_size());
ffffffffc0201662:	00001697          	auipc	a3,0x1
ffffffffc0201666:	f0668693          	addi	a3,a3,-250 # ffffffffc0202568 <etext+0x71e>
ffffffffc020166a:	00001617          	auipc	a2,0x1
ffffffffc020166e:	a3660613          	addi	a2,a2,-1482 # ffffffffc02020a0 <etext+0x256>
ffffffffc0201672:	0c400593          	li	a1,196
ffffffffc0201676:	00001517          	auipc	a0,0x1
ffffffffc020167a:	e7a50513          	addi	a0,a0,-390 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc020167e:	b57fe0ef          	jal	ffffffffc02001d4 <__panic>
    assert(slab->magic == SLUB_SMALL_MAGIC ||
ffffffffc0201682:	00001697          	auipc	a3,0x1
ffffffffc0201686:	e9e68693          	addi	a3,a3,-354 # ffffffffc0202520 <etext+0x6d6>
ffffffffc020168a:	00001617          	auipc	a2,0x1
ffffffffc020168e:	a1660613          	addi	a2,a2,-1514 # ffffffffc02020a0 <etext+0x256>
ffffffffc0201692:	0c000593          	li	a1,192
ffffffffc0201696:	00001517          	auipc	a0,0x1
ffffffffc020169a:	e5a50513          	addi	a0,a0,-422 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc020169e:	b37fe0ef          	jal	ffffffffc02001d4 <__panic>
        free_pages(pa2page(PADDR(slab)), pages_to_free);
ffffffffc02016a2:	00001617          	auipc	a2,0x1
ffffffffc02016a6:	d8e60613          	addi	a2,a2,-626 # ffffffffc0202430 <etext+0x5e6>
ffffffffc02016aa:	0c700593          	li	a1,199
ffffffffc02016ae:	00001517          	auipc	a0,0x1
ffffffffc02016b2:	e4250513          	addi	a0,a0,-446 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc02016b6:	b1ffe0ef          	jal	ffffffffc02001d4 <__panic>

ffffffffc02016ba <slub_check>:
        assert(bytes[i] == value);
    }
}

void
slub_check(void) {
ffffffffc02016ba:	d1010113          	addi	sp,sp,-752
ffffffffc02016be:	2e813023          	sd	s0,736(sp)
ffffffffc02016c2:	2c913c23          	sd	s1,728(sp)
ffffffffc02016c6:	2d213823          	sd	s2,720(sp)
ffffffffc02016ca:	2d413023          	sd	s4,704(sp)
ffffffffc02016ce:	2b513c23          	sd	s5,696(sp)
ffffffffc02016d2:	2b613823          	sd	s6,688(sp)
ffffffffc02016d6:	2b713423          	sd	s7,680(sp)
ffffffffc02016da:	2e113423          	sd	ra,744(sp)
ffffffffc02016de:	2d313423          	sd	s3,712(sp)
ffffffffc02016e2:	0024                	addi	s1,sp,8
    static const size_t requests[] = {
        1, 16, 17, 32, 63, 64, 129, 511, 1024, 1500, 2048, 2049, 5000,
    };
    void *objects[sizeof(requests) / sizeof(requests[0])];
    size_t before = nr_free_pages();
ffffffffc02016e4:	91fff0ef          	jal	ffffffffc0201002 <nr_free_pages>
ffffffffc02016e8:	00001b17          	auipc	s6,0x1
ffffffffc02016ec:	240b0b13          	addi	s6,s6,576 # ffffffffc0202928 <requests.0>
ffffffffc02016f0:	842a                	mv	s0,a0
ffffffffc02016f2:	8926                	mv	s2,s1
ffffffffc02016f4:	8bda                	mv	s7,s6

    assert(slub_alloc(0) == NULL);
    for (size_t i = 0; i < sizeof(requests) / sizeof(requests[0]); i ++) {
ffffffffc02016f6:	4a81                	li	s5,0
ffffffffc02016f8:	4a35                	li	s4,13
        objects[i] = slub_alloc(requests[i]);
ffffffffc02016fa:	000bb983          	ld	s3,0(s7)
ffffffffc02016fe:	854e                	mv	a0,s3
ffffffffc0201700:	b05ff0ef          	jal	ffffffffc0201204 <slub_alloc>
ffffffffc0201704:	00a93023          	sd	a0,0(s2)
        assert(objects[i] != NULL);
ffffffffc0201708:	1e050563          	beqz	a0,ffffffffc02018f2 <slub_check+0x238>
        slub_fill(objects[i], requests[i], (uint8_t)(0x20 + i));
ffffffffc020170c:	020a869b          	addiw	a3,s5,32 # ff0020 <kern_entry-0xffffffffbf20ffe0>
ffffffffc0201710:	0ff6f693          	zext.b	a3,a3
    for (size_t i = 0; i < size; i ++) {
ffffffffc0201714:	00098a63          	beqz	s3,ffffffffc0201728 <slub_check+0x6e>
ffffffffc0201718:	00a98733          	add	a4,s3,a0
ffffffffc020171c:	87aa                	mv	a5,a0
        bytes[i] = value;
ffffffffc020171e:	00d78023          	sb	a3,0(a5)
    for (size_t i = 0; i < size; i ++) {
ffffffffc0201722:	0785                	addi	a5,a5,1
ffffffffc0201724:	fee79de3          	bne	a5,a4,ffffffffc020171e <slub_check+0x64>
        for (size_t j = 0; j < i; j ++) {
ffffffffc0201728:	140a8163          	beqz	s5,ffffffffc020186a <slub_check+0x1b0>
ffffffffc020172c:	87a6                	mv	a5,s1
            assert(objects[i] != objects[j]);
ffffffffc020172e:	6398                	ld	a4,0(a5)
ffffffffc0201730:	14e50163          	beq	a0,a4,ffffffffc0201872 <slub_check+0x1b8>
        for (size_t j = 0; j < i; j ++) {
ffffffffc0201734:	07a1                	addi	a5,a5,8
ffffffffc0201736:	ff279ce3          	bne	a5,s2,ffffffffc020172e <slub_check+0x74>
    for (size_t i = 0; i < sizeof(requests) / sizeof(requests[0]); i ++) {
ffffffffc020173a:	0a85                	addi	s5,s5,1
ffffffffc020173c:	0ba1                	addi	s7,s7,8
ffffffffc020173e:	00878913          	addi	s2,a5,8
ffffffffc0201742:	fb4a9ce3          	bne	s5,s4,ffffffffc02016fa <slub_check+0x40>
ffffffffc0201746:	06848513          	addi	a0,s1,104
ffffffffc020174a:	85a6                	mv	a1,s1
ffffffffc020174c:	02000693          	li	a3,32
        }
    }
    for (size_t i = 0; i < sizeof(requests) / sizeof(requests[0]); i ++) {
        slub_expect(objects[i], requests[i], (uint8_t)(0x20 + i));
ffffffffc0201750:	000b3603          	ld	a2,0(s6)
ffffffffc0201754:	619c                	ld	a5,0(a1)
    for (size_t i = 0; i < size; i ++) {
ffffffffc0201756:	ca09                	beqz	a2,ffffffffc0201768 <slub_check+0xae>
ffffffffc0201758:	963e                	add	a2,a2,a5
        assert(bytes[i] == value);
ffffffffc020175a:	0007c703          	lbu	a4,0(a5)
ffffffffc020175e:	12d71a63          	bne	a4,a3,ffffffffc0201892 <slub_check+0x1d8>
    for (size_t i = 0; i < size; i ++) {
ffffffffc0201762:	0785                	addi	a5,a5,1
ffffffffc0201764:	fec79be3          	bne	a5,a2,ffffffffc020175a <slub_check+0xa0>
    for (size_t i = 0; i < sizeof(requests) / sizeof(requests[0]); i ++) {
ffffffffc0201768:	2685                	addiw	a3,a3,1
ffffffffc020176a:	05a1                	addi	a1,a1,8
ffffffffc020176c:	0ff6f693          	zext.b	a3,a3
ffffffffc0201770:	0b21                	addi	s6,s6,8
ffffffffc0201772:	fca59fe3          	bne	a1,a0,ffffffffc0201750 <slub_check+0x96>
    }
    cprintf("[SLUB Test] different sizes and no overlap: PASS\n");
ffffffffc0201776:	00001517          	auipc	a0,0x1
ffffffffc020177a:	f6a50513          	addi	a0,a0,-150 # ffffffffc02026e0 <etext+0x896>
ffffffffc020177e:	9d5fe0ef          	jal	ffffffffc0200152 <cprintf>

    for (size_t i = sizeof(requests) / sizeof(requests[0]); i > 0; i --) {
ffffffffc0201782:	06810913          	addi	s2,sp,104
        slub_free(objects[i - 1]);
ffffffffc0201786:	00093503          	ld	a0,0(s2)
ffffffffc020178a:	cb5ff0ef          	jal	ffffffffc020143e <slub_free>
    for (size_t i = sizeof(requests) / sizeof(requests[0]); i > 0; i --) {
ffffffffc020178e:	87ca                	mv	a5,s2
ffffffffc0201790:	1961                	addi	s2,s2,-8
ffffffffc0201792:	fe979ae3          	bne	a5,s1,ffffffffc0201786 <slub_check+0xcc>
    }
    assert(nr_free_pages() == before);
ffffffffc0201796:	86dff0ef          	jal	ffffffffc0201002 <nr_free_pages>
ffffffffc020179a:	16851c63          	bne	a0,s0,ffffffffc0201912 <slub_check+0x258>

    void *first = slub_alloc(64);
ffffffffc020179e:	04000513          	li	a0,64
ffffffffc02017a2:	a63ff0ef          	jal	ffffffffc0201204 <slub_alloc>
ffffffffc02017a6:	84aa                	mv	s1,a0
    void *second = slub_alloc(64);
ffffffffc02017a8:	04000513          	li	a0,64
ffffffffc02017ac:	a59ff0ef          	jal	ffffffffc0201204 <slub_alloc>
ffffffffc02017b0:	892a                	mv	s2,a0
    assert(first != NULL && second != NULL && first != second);
ffffffffc02017b2:	1e048063          	beqz	s1,ffffffffc0201992 <slub_check+0x2d8>
ffffffffc02017b6:	1c050e63          	beqz	a0,ffffffffc0201992 <slub_check+0x2d8>
ffffffffc02017ba:	1ca48c63          	beq	s1,a0,ffffffffc0201992 <slub_check+0x2d8>
    slub_free(first);
ffffffffc02017be:	8526                	mv	a0,s1
ffffffffc02017c0:	c7fff0ef          	jal	ffffffffc020143e <slub_free>
    void *reused = slub_alloc(64);
ffffffffc02017c4:	04000513          	li	a0,64
ffffffffc02017c8:	a3dff0ef          	jal	ffffffffc0201204 <slub_alloc>
    assert(reused == first);
ffffffffc02017cc:	16a49363          	bne	s1,a0,ffffffffc0201932 <slub_check+0x278>
    slub_free(reused);
ffffffffc02017d0:	c6fff0ef          	jal	ffffffffc020143e <slub_free>
    slub_free(second);
ffffffffc02017d4:	854a                	mv	a0,s2
ffffffffc02017d6:	c69ff0ef          	jal	ffffffffc020143e <slub_free>
    assert(nr_free_pages() == before);
ffffffffc02017da:	829ff0ef          	jal	ffffffffc0201002 <nr_free_pages>
ffffffffc02017de:	16851a63          	bne	a0,s0,ffffffffc0201952 <slub_check+0x298>
    cprintf("[SLUB Test] object reuse: PASS\n");
ffffffffc02017e2:	00001517          	auipc	a0,0x1
ffffffffc02017e6:	f9e50513          	addi	a0,a0,-98 # ffffffffc0202780 <etext+0x936>
ffffffffc02017ea:	1884                	addi	s1,sp,112
ffffffffc02017ec:	967fe0ef          	jal	ffffffffc0200152 <cprintf>
ffffffffc02017f0:	8926                	mv	s2,s1

    void *many[70];
    for (size_t i = 0; i < 70; i ++) {
        many[i] = slub_alloc(64);
ffffffffc02017f2:	04000513          	li	a0,64
ffffffffc02017f6:	a0fff0ef          	jal	ffffffffc0201204 <slub_alloc>
ffffffffc02017fa:	00a93023          	sd	a0,0(s2)
        assert(many[i] != NULL);
ffffffffc02017fe:	c955                	beqz	a0,ffffffffc02018b2 <slub_check+0x1f8>
    for (size_t i = 0; i < 70; i ++) {
ffffffffc0201800:	0921                	addi	s2,s2,8
ffffffffc0201802:	151c                	addi	a5,sp,672
ffffffffc0201804:	ff2797e3          	bne	a5,s2,ffffffffc02017f2 <slub_check+0x138>
    }
    assert(nr_free_pages() <= before - 2);
ffffffffc0201808:	ffaff0ef          	jal	ffffffffc0201002 <nr_free_pages>
ffffffffc020180c:	ffe40793          	addi	a5,s0,-2
ffffffffc0201810:	0ca7e163          	bltu	a5,a0,ffffffffc02018d2 <slub_check+0x218>
    for (size_t i = 0; i < 70; i ++) {
        slub_free(many[i]);
ffffffffc0201814:	6088                	ld	a0,0(s1)
    for (size_t i = 0; i < 70; i ++) {
ffffffffc0201816:	04a1                	addi	s1,s1,8
        slub_free(many[i]);
ffffffffc0201818:	c27ff0ef          	jal	ffffffffc020143e <slub_free>
    for (size_t i = 0; i < 70; i ++) {
ffffffffc020181c:	151c                	addi	a5,sp,672
ffffffffc020181e:	fe979be3          	bne	a5,s1,ffffffffc0201814 <slub_check+0x15a>
    }
    assert(nr_free_pages() == before);
ffffffffc0201822:	fe0ff0ef          	jal	ffffffffc0201002 <nr_free_pages>
ffffffffc0201826:	14851663          	bne	a0,s0,ffffffffc0201972 <slub_check+0x2b8>
    cprintf("[SLUB Test] slab growth and page reclaim: PASS\n");
ffffffffc020182a:	00001517          	auipc	a0,0x1
ffffffffc020182e:	fa650513          	addi	a0,a0,-90 # ffffffffc02027d0 <etext+0x986>
ffffffffc0201832:	921fe0ef          	jal	ffffffffc0200152 <cprintf>
    cprintf("[SLUB Test] ALL PASS\n");
}
ffffffffc0201836:	2e013403          	ld	s0,736(sp)
ffffffffc020183a:	2e813083          	ld	ra,744(sp)
ffffffffc020183e:	2d813483          	ld	s1,728(sp)
ffffffffc0201842:	2d013903          	ld	s2,720(sp)
ffffffffc0201846:	2c813983          	ld	s3,712(sp)
ffffffffc020184a:	2c013a03          	ld	s4,704(sp)
ffffffffc020184e:	2b813a83          	ld	s5,696(sp)
ffffffffc0201852:	2b013b03          	ld	s6,688(sp)
ffffffffc0201856:	2a813b83          	ld	s7,680(sp)
    cprintf("[SLUB Test] ALL PASS\n");
ffffffffc020185a:	00001517          	auipc	a0,0x1
ffffffffc020185e:	fa650513          	addi	a0,a0,-90 # ffffffffc0202800 <etext+0x9b6>
}
ffffffffc0201862:	2f010113          	addi	sp,sp,752
    cprintf("[SLUB Test] ALL PASS\n");
ffffffffc0201866:	8edfe06f          	j	ffffffffc0200152 <cprintf>
    for (size_t i = 0; i < sizeof(requests) / sizeof(requests[0]); i ++) {
ffffffffc020186a:	0ba1                	addi	s7,s7,8
ffffffffc020186c:	0921                	addi	s2,s2,8
ffffffffc020186e:	4a85                	li	s5,1
ffffffffc0201870:	b569                	j	ffffffffc02016fa <slub_check+0x40>
            assert(objects[i] != objects[j]);
ffffffffc0201872:	00001697          	auipc	a3,0x1
ffffffffc0201876:	e3668693          	addi	a3,a3,-458 # ffffffffc02026a8 <etext+0x85e>
ffffffffc020187a:	00001617          	auipc	a2,0x1
ffffffffc020187e:	82660613          	addi	a2,a2,-2010 # ffffffffc02020a0 <etext+0x256>
ffffffffc0201882:	0f600593          	li	a1,246
ffffffffc0201886:	00001517          	auipc	a0,0x1
ffffffffc020188a:	c6a50513          	addi	a0,a0,-918 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc020188e:	947fe0ef          	jal	ffffffffc02001d4 <__panic>
        assert(bytes[i] == value);
ffffffffc0201892:	00001697          	auipc	a3,0x1
ffffffffc0201896:	e3668693          	addi	a3,a3,-458 # ffffffffc02026c8 <etext+0x87e>
ffffffffc020189a:	00001617          	auipc	a2,0x1
ffffffffc020189e:	80660613          	addi	a2,a2,-2042 # ffffffffc02020a0 <etext+0x256>
ffffffffc02018a2:	0e400593          	li	a1,228
ffffffffc02018a6:	00001517          	auipc	a0,0x1
ffffffffc02018aa:	c4a50513          	addi	a0,a0,-950 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc02018ae:	927fe0ef          	jal	ffffffffc02001d4 <__panic>
        assert(many[i] != NULL);
ffffffffc02018b2:	00001697          	auipc	a3,0x1
ffffffffc02018b6:	eee68693          	addi	a3,a3,-274 # ffffffffc02027a0 <etext+0x956>
ffffffffc02018ba:	00000617          	auipc	a2,0x0
ffffffffc02018be:	7e660613          	addi	a2,a2,2022 # ffffffffc02020a0 <etext+0x256>
ffffffffc02018c2:	11100593          	li	a1,273
ffffffffc02018c6:	00001517          	auipc	a0,0x1
ffffffffc02018ca:	c2a50513          	addi	a0,a0,-982 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc02018ce:	907fe0ef          	jal	ffffffffc02001d4 <__panic>
    assert(nr_free_pages() <= before - 2);
ffffffffc02018d2:	00001697          	auipc	a3,0x1
ffffffffc02018d6:	ede68693          	addi	a3,a3,-290 # ffffffffc02027b0 <etext+0x966>
ffffffffc02018da:	00000617          	auipc	a2,0x0
ffffffffc02018de:	7c660613          	addi	a2,a2,1990 # ffffffffc02020a0 <etext+0x256>
ffffffffc02018e2:	11300593          	li	a1,275
ffffffffc02018e6:	00001517          	auipc	a0,0x1
ffffffffc02018ea:	c0a50513          	addi	a0,a0,-1014 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc02018ee:	8e7fe0ef          	jal	ffffffffc02001d4 <__panic>
        assert(objects[i] != NULL);
ffffffffc02018f2:	00001697          	auipc	a3,0x1
ffffffffc02018f6:	d9e68693          	addi	a3,a3,-610 # ffffffffc0202690 <etext+0x846>
ffffffffc02018fa:	00000617          	auipc	a2,0x0
ffffffffc02018fe:	7a660613          	addi	a2,a2,1958 # ffffffffc02020a0 <etext+0x256>
ffffffffc0201902:	0f300593          	li	a1,243
ffffffffc0201906:	00001517          	auipc	a0,0x1
ffffffffc020190a:	bea50513          	addi	a0,a0,-1046 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc020190e:	8c7fe0ef          	jal	ffffffffc02001d4 <__panic>
    assert(nr_free_pages() == before);
ffffffffc0201912:	00001697          	auipc	a3,0x1
ffffffffc0201916:	e0668693          	addi	a3,a3,-506 # ffffffffc0202718 <etext+0x8ce>
ffffffffc020191a:	00000617          	auipc	a2,0x0
ffffffffc020191e:	78660613          	addi	a2,a2,1926 # ffffffffc02020a0 <etext+0x256>
ffffffffc0201922:	10100593          	li	a1,257
ffffffffc0201926:	00001517          	auipc	a0,0x1
ffffffffc020192a:	bca50513          	addi	a0,a0,-1078 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc020192e:	8a7fe0ef          	jal	ffffffffc02001d4 <__panic>
    assert(reused == first);
ffffffffc0201932:	00001697          	auipc	a3,0x1
ffffffffc0201936:	e3e68693          	addi	a3,a3,-450 # ffffffffc0202770 <etext+0x926>
ffffffffc020193a:	00000617          	auipc	a2,0x0
ffffffffc020193e:	76660613          	addi	a2,a2,1894 # ffffffffc02020a0 <etext+0x256>
ffffffffc0201942:	10800593          	li	a1,264
ffffffffc0201946:	00001517          	auipc	a0,0x1
ffffffffc020194a:	baa50513          	addi	a0,a0,-1110 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc020194e:	887fe0ef          	jal	ffffffffc02001d4 <__panic>
    assert(nr_free_pages() == before);
ffffffffc0201952:	00001697          	auipc	a3,0x1
ffffffffc0201956:	dc668693          	addi	a3,a3,-570 # ffffffffc0202718 <etext+0x8ce>
ffffffffc020195a:	00000617          	auipc	a2,0x0
ffffffffc020195e:	74660613          	addi	a2,a2,1862 # ffffffffc02020a0 <etext+0x256>
ffffffffc0201962:	10b00593          	li	a1,267
ffffffffc0201966:	00001517          	auipc	a0,0x1
ffffffffc020196a:	b8a50513          	addi	a0,a0,-1142 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc020196e:	867fe0ef          	jal	ffffffffc02001d4 <__panic>
    assert(nr_free_pages() == before);
ffffffffc0201972:	00001697          	auipc	a3,0x1
ffffffffc0201976:	da668693          	addi	a3,a3,-602 # ffffffffc0202718 <etext+0x8ce>
ffffffffc020197a:	00000617          	auipc	a2,0x0
ffffffffc020197e:	72660613          	addi	a2,a2,1830 # ffffffffc02020a0 <etext+0x256>
ffffffffc0201982:	11700593          	li	a1,279
ffffffffc0201986:	00001517          	auipc	a0,0x1
ffffffffc020198a:	b6a50513          	addi	a0,a0,-1174 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc020198e:	847fe0ef          	jal	ffffffffc02001d4 <__panic>
    assert(first != NULL && second != NULL && first != second);
ffffffffc0201992:	00001697          	auipc	a3,0x1
ffffffffc0201996:	da668693          	addi	a3,a3,-602 # ffffffffc0202738 <etext+0x8ee>
ffffffffc020199a:	00000617          	auipc	a2,0x0
ffffffffc020199e:	70660613          	addi	a2,a2,1798 # ffffffffc02020a0 <etext+0x256>
ffffffffc02019a2:	10500593          	li	a1,261
ffffffffc02019a6:	00001517          	auipc	a0,0x1
ffffffffc02019aa:	b4a50513          	addi	a0,a0,-1206 # ffffffffc02024f0 <etext+0x6a6>
ffffffffc02019ae:	827fe0ef          	jal	ffffffffc02001d4 <__panic>

ffffffffc02019b2 <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc02019b2:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02019b6:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc02019b8:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02019bc:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc02019be:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02019c2:	f022                	sd	s0,32(sp)
ffffffffc02019c4:	ec26                	sd	s1,24(sp)
ffffffffc02019c6:	e84a                	sd	s2,16(sp)
ffffffffc02019c8:	f406                	sd	ra,40(sp)
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc02019ca:	fff7041b          	addiw	s0,a4,-1
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02019ce:	84aa                	mv	s1,a0
ffffffffc02019d0:	892e                	mv	s2,a1
    unsigned mod = do_div(result, base);
ffffffffc02019d2:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc02019d4:	05067063          	bgeu	a2,a6,ffffffffc0201a14 <printnum+0x62>
ffffffffc02019d8:	e44e                	sd	s3,8(sp)
ffffffffc02019da:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc02019dc:	4785                	li	a5,1
ffffffffc02019de:	00e7d763          	bge	a5,a4,ffffffffc02019ec <printnum+0x3a>
            putch(padc, putdat);
ffffffffc02019e2:	85ca                	mv	a1,s2
ffffffffc02019e4:	854e                	mv	a0,s3
        while (-- width > 0)
ffffffffc02019e6:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc02019e8:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc02019ea:	fc65                	bnez	s0,ffffffffc02019e2 <printnum+0x30>
ffffffffc02019ec:	69a2                	ld	s3,8(sp)
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02019ee:	1a02                	slli	s4,s4,0x20
ffffffffc02019f0:	020a5a13          	srli	s4,s4,0x20
ffffffffc02019f4:	00001797          	auipc	a5,0x1
ffffffffc02019f8:	e2478793          	addi	a5,a5,-476 # ffffffffc0202818 <etext+0x9ce>
ffffffffc02019fc:	97d2                	add	a5,a5,s4
}
ffffffffc02019fe:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201a00:	0007c503          	lbu	a0,0(a5)
}
ffffffffc0201a04:	70a2                	ld	ra,40(sp)
ffffffffc0201a06:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201a08:	85ca                	mv	a1,s2
ffffffffc0201a0a:	87a6                	mv	a5,s1
}
ffffffffc0201a0c:	6942                	ld	s2,16(sp)
ffffffffc0201a0e:	64e2                	ld	s1,24(sp)
ffffffffc0201a10:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201a12:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc0201a14:	03065633          	divu	a2,a2,a6
ffffffffc0201a18:	8722                	mv	a4,s0
ffffffffc0201a1a:	f99ff0ef          	jal	ffffffffc02019b2 <printnum>
ffffffffc0201a1e:	bfc1                	j	ffffffffc02019ee <printnum+0x3c>

ffffffffc0201a20 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc0201a20:	7119                	addi	sp,sp,-128
ffffffffc0201a22:	f4a6                	sd	s1,104(sp)
ffffffffc0201a24:	f0ca                	sd	s2,96(sp)
ffffffffc0201a26:	ecce                	sd	s3,88(sp)
ffffffffc0201a28:	e8d2                	sd	s4,80(sp)
ffffffffc0201a2a:	e4d6                	sd	s5,72(sp)
ffffffffc0201a2c:	e0da                	sd	s6,64(sp)
ffffffffc0201a2e:	f862                	sd	s8,48(sp)
ffffffffc0201a30:	fc86                	sd	ra,120(sp)
ffffffffc0201a32:	f8a2                	sd	s0,112(sp)
ffffffffc0201a34:	fc5e                	sd	s7,56(sp)
ffffffffc0201a36:	f466                	sd	s9,40(sp)
ffffffffc0201a38:	f06a                	sd	s10,32(sp)
ffffffffc0201a3a:	ec6e                	sd	s11,24(sp)
ffffffffc0201a3c:	892a                	mv	s2,a0
ffffffffc0201a3e:	84ae                	mv	s1,a1
ffffffffc0201a40:	8c32                	mv	s8,a2
ffffffffc0201a42:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201a44:	02500993          	li	s3,37
        char padc = ' ';
        width = precision = -1;
        lflag = altflag = 0;

    reswitch:
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201a48:	05500b13          	li	s6,85
ffffffffc0201a4c:	00001a97          	auipc	s5,0x1
ffffffffc0201a50:	f84a8a93          	addi	s5,s5,-124 # ffffffffc02029d0 <slub_sizes+0x40>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201a54:	000c4503          	lbu	a0,0(s8)
ffffffffc0201a58:	001c0413          	addi	s0,s8,1
ffffffffc0201a5c:	01350a63          	beq	a0,s3,ffffffffc0201a70 <vprintfmt+0x50>
            if (ch == '\0') {
ffffffffc0201a60:	cd0d                	beqz	a0,ffffffffc0201a9a <vprintfmt+0x7a>
            putch(ch, putdat);
ffffffffc0201a62:	85a6                	mv	a1,s1
ffffffffc0201a64:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201a66:	00044503          	lbu	a0,0(s0)
ffffffffc0201a6a:	0405                	addi	s0,s0,1
ffffffffc0201a6c:	ff351ae3          	bne	a0,s3,ffffffffc0201a60 <vprintfmt+0x40>
        width = precision = -1;
ffffffffc0201a70:	5cfd                	li	s9,-1
ffffffffc0201a72:	8d66                	mv	s10,s9
        char padc = ' ';
ffffffffc0201a74:	02000d93          	li	s11,32
        lflag = altflag = 0;
ffffffffc0201a78:	4b81                	li	s7,0
ffffffffc0201a7a:	4601                	li	a2,0
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201a7c:	00044683          	lbu	a3,0(s0)
ffffffffc0201a80:	00140c13          	addi	s8,s0,1
ffffffffc0201a84:	fdd6859b          	addiw	a1,a3,-35
ffffffffc0201a88:	0ff5f593          	zext.b	a1,a1
ffffffffc0201a8c:	02bb6663          	bltu	s6,a1,ffffffffc0201ab8 <vprintfmt+0x98>
ffffffffc0201a90:	058a                	slli	a1,a1,0x2
ffffffffc0201a92:	95d6                	add	a1,a1,s5
ffffffffc0201a94:	4198                	lw	a4,0(a1)
ffffffffc0201a96:	9756                	add	a4,a4,s5
ffffffffc0201a98:	8702                	jr	a4
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc0201a9a:	70e6                	ld	ra,120(sp)
ffffffffc0201a9c:	7446                	ld	s0,112(sp)
ffffffffc0201a9e:	74a6                	ld	s1,104(sp)
ffffffffc0201aa0:	7906                	ld	s2,96(sp)
ffffffffc0201aa2:	69e6                	ld	s3,88(sp)
ffffffffc0201aa4:	6a46                	ld	s4,80(sp)
ffffffffc0201aa6:	6aa6                	ld	s5,72(sp)
ffffffffc0201aa8:	6b06                	ld	s6,64(sp)
ffffffffc0201aaa:	7be2                	ld	s7,56(sp)
ffffffffc0201aac:	7c42                	ld	s8,48(sp)
ffffffffc0201aae:	7ca2                	ld	s9,40(sp)
ffffffffc0201ab0:	7d02                	ld	s10,32(sp)
ffffffffc0201ab2:	6de2                	ld	s11,24(sp)
ffffffffc0201ab4:	6109                	addi	sp,sp,128
ffffffffc0201ab6:	8082                	ret
            putch('%', putdat);
ffffffffc0201ab8:	85a6                	mv	a1,s1
ffffffffc0201aba:	02500513          	li	a0,37
ffffffffc0201abe:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc0201ac0:	fff44783          	lbu	a5,-1(s0)
ffffffffc0201ac4:	02500713          	li	a4,37
ffffffffc0201ac8:	8c22                	mv	s8,s0
ffffffffc0201aca:	f8e785e3          	beq	a5,a4,ffffffffc0201a54 <vprintfmt+0x34>
ffffffffc0201ace:	ffec4783          	lbu	a5,-2(s8)
ffffffffc0201ad2:	1c7d                	addi	s8,s8,-1
ffffffffc0201ad4:	fee79de3          	bne	a5,a4,ffffffffc0201ace <vprintfmt+0xae>
ffffffffc0201ad8:	bfb5                	j	ffffffffc0201a54 <vprintfmt+0x34>
                ch = *fmt;
ffffffffc0201ada:	00144783          	lbu	a5,1(s0)
                if (ch < '0' || ch > '9') {
ffffffffc0201ade:	4525                	li	a0,9
                precision = precision * 10 + ch - '0';
ffffffffc0201ae0:	fd068c9b          	addiw	s9,a3,-48
                if (ch < '0' || ch > '9') {
ffffffffc0201ae4:	fd07871b          	addiw	a4,a5,-48
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201ae8:	8462                	mv	s0,s8
                ch = *fmt;
ffffffffc0201aea:	2781                	sext.w	a5,a5
                if (ch < '0' || ch > '9') {
ffffffffc0201aec:	02e56463          	bltu	a0,a4,ffffffffc0201b14 <vprintfmt+0xf4>
                precision = precision * 10 + ch - '0';
ffffffffc0201af0:	002c971b          	slliw	a4,s9,0x2
                ch = *fmt;
ffffffffc0201af4:	00144683          	lbu	a3,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc0201af8:	0197073b          	addw	a4,a4,s9
ffffffffc0201afc:	0017171b          	slliw	a4,a4,0x1
ffffffffc0201b00:	9f3d                	addw	a4,a4,a5
                if (ch < '0' || ch > '9') {
ffffffffc0201b02:	fd06859b          	addiw	a1,a3,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc0201b06:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc0201b08:	fd070c9b          	addiw	s9,a4,-48
                ch = *fmt;
ffffffffc0201b0c:	0006879b          	sext.w	a5,a3
                if (ch < '0' || ch > '9') {
ffffffffc0201b10:	feb570e3          	bgeu	a0,a1,ffffffffc0201af0 <vprintfmt+0xd0>
            if (width < 0)
ffffffffc0201b14:	f60d54e3          	bgez	s10,ffffffffc0201a7c <vprintfmt+0x5c>
                width = precision, precision = -1;
ffffffffc0201b18:	8d66                	mv	s10,s9
ffffffffc0201b1a:	5cfd                	li	s9,-1
ffffffffc0201b1c:	b785                	j	ffffffffc0201a7c <vprintfmt+0x5c>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201b1e:	8db6                	mv	s11,a3
ffffffffc0201b20:	8462                	mv	s0,s8
ffffffffc0201b22:	bfa9                	j	ffffffffc0201a7c <vprintfmt+0x5c>
ffffffffc0201b24:	8462                	mv	s0,s8
            altflag = 1;
ffffffffc0201b26:	4b85                	li	s7,1
            goto reswitch;
ffffffffc0201b28:	bf91                	j	ffffffffc0201a7c <vprintfmt+0x5c>
    if (lflag >= 2) {
ffffffffc0201b2a:	4785                	li	a5,1
            precision = va_arg(ap, int);
ffffffffc0201b2c:	008a0713          	addi	a4,s4,8
    if (lflag >= 2) {
ffffffffc0201b30:	00c7c463          	blt	a5,a2,ffffffffc0201b38 <vprintfmt+0x118>
    else if (lflag) {
ffffffffc0201b34:	18060763          	beqz	a2,ffffffffc0201cc2 <vprintfmt+0x2a2>
        return va_arg(*ap, unsigned long);
ffffffffc0201b38:	000a3603          	ld	a2,0(s4)
ffffffffc0201b3c:	46c1                	li	a3,16
ffffffffc0201b3e:	8a3a                	mv	s4,a4
            printnum(putch, putdat, num, base, width, padc);
ffffffffc0201b40:	000d879b          	sext.w	a5,s11
ffffffffc0201b44:	876a                	mv	a4,s10
ffffffffc0201b46:	85a6                	mv	a1,s1
ffffffffc0201b48:	854a                	mv	a0,s2
ffffffffc0201b4a:	e69ff0ef          	jal	ffffffffc02019b2 <printnum>
            break;
ffffffffc0201b4e:	b719                	j	ffffffffc0201a54 <vprintfmt+0x34>
            putch(va_arg(ap, int), putdat);
ffffffffc0201b50:	000a2503          	lw	a0,0(s4)
ffffffffc0201b54:	85a6                	mv	a1,s1
ffffffffc0201b56:	0a21                	addi	s4,s4,8
ffffffffc0201b58:	9902                	jalr	s2
            break;
ffffffffc0201b5a:	bded                	j	ffffffffc0201a54 <vprintfmt+0x34>
    if (lflag >= 2) {
ffffffffc0201b5c:	4785                	li	a5,1
            precision = va_arg(ap, int);
ffffffffc0201b5e:	008a0713          	addi	a4,s4,8
    if (lflag >= 2) {
ffffffffc0201b62:	00c7c463          	blt	a5,a2,ffffffffc0201b6a <vprintfmt+0x14a>
    else if (lflag) {
ffffffffc0201b66:	14060963          	beqz	a2,ffffffffc0201cb8 <vprintfmt+0x298>
        return va_arg(*ap, unsigned long);
ffffffffc0201b6a:	000a3603          	ld	a2,0(s4)
ffffffffc0201b6e:	46a9                	li	a3,10
ffffffffc0201b70:	8a3a                	mv	s4,a4
ffffffffc0201b72:	b7f9                	j	ffffffffc0201b40 <vprintfmt+0x120>
            putch('0', putdat);
ffffffffc0201b74:	85a6                	mv	a1,s1
ffffffffc0201b76:	03000513          	li	a0,48
ffffffffc0201b7a:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc0201b7c:	85a6                	mv	a1,s1
ffffffffc0201b7e:	07800513          	li	a0,120
ffffffffc0201b82:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0201b84:	000a3603          	ld	a2,0(s4)
            goto number;
ffffffffc0201b88:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0201b8a:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc0201b8c:	bf55                	j	ffffffffc0201b40 <vprintfmt+0x120>
            putch(ch, putdat);
ffffffffc0201b8e:	85a6                	mv	a1,s1
ffffffffc0201b90:	02500513          	li	a0,37
ffffffffc0201b94:	9902                	jalr	s2
            break;
ffffffffc0201b96:	bd7d                	j	ffffffffc0201a54 <vprintfmt+0x34>
            precision = va_arg(ap, int);
ffffffffc0201b98:	000a2c83          	lw	s9,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201b9c:	8462                	mv	s0,s8
            precision = va_arg(ap, int);
ffffffffc0201b9e:	0a21                	addi	s4,s4,8
            goto process_precision;
ffffffffc0201ba0:	bf95                	j	ffffffffc0201b14 <vprintfmt+0xf4>
    if (lflag >= 2) {
ffffffffc0201ba2:	4785                	li	a5,1
            precision = va_arg(ap, int);
ffffffffc0201ba4:	008a0713          	addi	a4,s4,8
    if (lflag >= 2) {
ffffffffc0201ba8:	00c7c463          	blt	a5,a2,ffffffffc0201bb0 <vprintfmt+0x190>
    else if (lflag) {
ffffffffc0201bac:	10060163          	beqz	a2,ffffffffc0201cae <vprintfmt+0x28e>
        return va_arg(*ap, unsigned long);
ffffffffc0201bb0:	000a3603          	ld	a2,0(s4)
ffffffffc0201bb4:	46a1                	li	a3,8
ffffffffc0201bb6:	8a3a                	mv	s4,a4
ffffffffc0201bb8:	b761                	j	ffffffffc0201b40 <vprintfmt+0x120>
            if (width < 0)
ffffffffc0201bba:	87ea                	mv	a5,s10
ffffffffc0201bbc:	000d5363          	bgez	s10,ffffffffc0201bc2 <vprintfmt+0x1a2>
ffffffffc0201bc0:	4781                	li	a5,0
ffffffffc0201bc2:	00078d1b          	sext.w	s10,a5
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201bc6:	8462                	mv	s0,s8
            goto reswitch;
ffffffffc0201bc8:	bd55                	j	ffffffffc0201a7c <vprintfmt+0x5c>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201bca:	000a3703          	ld	a4,0(s4)
ffffffffc0201bce:	12070b63          	beqz	a4,ffffffffc0201d04 <vprintfmt+0x2e4>
            if (width > 0 && padc != '-') {
ffffffffc0201bd2:	0da05563          	blez	s10,ffffffffc0201c9c <vprintfmt+0x27c>
ffffffffc0201bd6:	02d00793          	li	a5,45
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201bda:	00170413          	addi	s0,a4,1
            if (width > 0 && padc != '-') {
ffffffffc0201bde:	14fd9a63          	bne	s11,a5,ffffffffc0201d32 <vprintfmt+0x312>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201be2:	00074783          	lbu	a5,0(a4)
ffffffffc0201be6:	0007851b          	sext.w	a0,a5
ffffffffc0201bea:	c785                	beqz	a5,ffffffffc0201c12 <vprintfmt+0x1f2>
ffffffffc0201bec:	5dfd                	li	s11,-1
ffffffffc0201bee:	000cc563          	bltz	s9,ffffffffc0201bf8 <vprintfmt+0x1d8>
ffffffffc0201bf2:	3cfd                	addiw	s9,s9,-1
ffffffffc0201bf4:	01bc8d63          	beq	s9,s11,ffffffffc0201c0e <vprintfmt+0x1ee>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201bf8:	0c0b9a63          	bnez	s7,ffffffffc0201ccc <vprintfmt+0x2ac>
                    putch(ch, putdat);
ffffffffc0201bfc:	85a6                	mv	a1,s1
ffffffffc0201bfe:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201c00:	00044783          	lbu	a5,0(s0)
ffffffffc0201c04:	0405                	addi	s0,s0,1
ffffffffc0201c06:	3d7d                	addiw	s10,s10,-1
ffffffffc0201c08:	0007851b          	sext.w	a0,a5
ffffffffc0201c0c:	f3ed                	bnez	a5,ffffffffc0201bee <vprintfmt+0x1ce>
            for (; width > 0; width --) {
ffffffffc0201c0e:	01a05963          	blez	s10,ffffffffc0201c20 <vprintfmt+0x200>
                putch(' ', putdat);
ffffffffc0201c12:	85a6                	mv	a1,s1
ffffffffc0201c14:	02000513          	li	a0,32
            for (; width > 0; width --) {
ffffffffc0201c18:	3d7d                	addiw	s10,s10,-1
                putch(' ', putdat);
ffffffffc0201c1a:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc0201c1c:	fe0d1be3          	bnez	s10,ffffffffc0201c12 <vprintfmt+0x1f2>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201c20:	0a21                	addi	s4,s4,8
ffffffffc0201c22:	bd0d                	j	ffffffffc0201a54 <vprintfmt+0x34>
    if (lflag >= 2) {
ffffffffc0201c24:	4785                	li	a5,1
            precision = va_arg(ap, int);
ffffffffc0201c26:	008a0b93          	addi	s7,s4,8
    if (lflag >= 2) {
ffffffffc0201c2a:	00c7c363          	blt	a5,a2,ffffffffc0201c30 <vprintfmt+0x210>
    else if (lflag) {
ffffffffc0201c2e:	c625                	beqz	a2,ffffffffc0201c96 <vprintfmt+0x276>
        return va_arg(*ap, long);
ffffffffc0201c30:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc0201c34:	0a044f63          	bltz	s0,ffffffffc0201cf2 <vprintfmt+0x2d2>
            num = getint(&ap, lflag);
ffffffffc0201c38:	8622                	mv	a2,s0
ffffffffc0201c3a:	8a5e                	mv	s4,s7
ffffffffc0201c3c:	46a9                	li	a3,10
ffffffffc0201c3e:	b709                	j	ffffffffc0201b40 <vprintfmt+0x120>
            if (err < 0) {
ffffffffc0201c40:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201c44:	4619                	li	a2,6
            if (err < 0) {
ffffffffc0201c46:	41f7d71b          	sraiw	a4,a5,0x1f
ffffffffc0201c4a:	8fb9                	xor	a5,a5,a4
ffffffffc0201c4c:	40e786bb          	subw	a3,a5,a4
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201c50:	02d64663          	blt	a2,a3,ffffffffc0201c7c <vprintfmt+0x25c>
ffffffffc0201c54:	00001797          	auipc	a5,0x1
ffffffffc0201c58:	ed478793          	addi	a5,a5,-300 # ffffffffc0202b28 <error_string>
ffffffffc0201c5c:	00369713          	slli	a4,a3,0x3
ffffffffc0201c60:	97ba                	add	a5,a5,a4
ffffffffc0201c62:	639c                	ld	a5,0(a5)
ffffffffc0201c64:	cf81                	beqz	a5,ffffffffc0201c7c <vprintfmt+0x25c>
                printfmt(putch, putdat, "%s", p);
ffffffffc0201c66:	86be                	mv	a3,a5
ffffffffc0201c68:	00001617          	auipc	a2,0x1
ffffffffc0201c6c:	be060613          	addi	a2,a2,-1056 # ffffffffc0202848 <etext+0x9fe>
ffffffffc0201c70:	85a6                	mv	a1,s1
ffffffffc0201c72:	854a                	mv	a0,s2
ffffffffc0201c74:	0f4000ef          	jal	ffffffffc0201d68 <printfmt>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201c78:	0a21                	addi	s4,s4,8
ffffffffc0201c7a:	bbe9                	j	ffffffffc0201a54 <vprintfmt+0x34>
                printfmt(putch, putdat, "error %d", err);
ffffffffc0201c7c:	00001617          	auipc	a2,0x1
ffffffffc0201c80:	bbc60613          	addi	a2,a2,-1092 # ffffffffc0202838 <etext+0x9ee>
ffffffffc0201c84:	85a6                	mv	a1,s1
ffffffffc0201c86:	854a                	mv	a0,s2
ffffffffc0201c88:	0e0000ef          	jal	ffffffffc0201d68 <printfmt>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201c8c:	0a21                	addi	s4,s4,8
ffffffffc0201c8e:	b3d9                	j	ffffffffc0201a54 <vprintfmt+0x34>
            lflag ++;
ffffffffc0201c90:	2605                	addiw	a2,a2,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201c92:	8462                	mv	s0,s8
            goto reswitch;
ffffffffc0201c94:	b3e5                	j	ffffffffc0201a7c <vprintfmt+0x5c>
        return va_arg(*ap, int);
ffffffffc0201c96:	000a2403          	lw	s0,0(s4)
ffffffffc0201c9a:	bf69                	j	ffffffffc0201c34 <vprintfmt+0x214>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201c9c:	00074783          	lbu	a5,0(a4)
ffffffffc0201ca0:	0007851b          	sext.w	a0,a5
ffffffffc0201ca4:	dfb5                	beqz	a5,ffffffffc0201c20 <vprintfmt+0x200>
ffffffffc0201ca6:	00170413          	addi	s0,a4,1
ffffffffc0201caa:	5dfd                	li	s11,-1
ffffffffc0201cac:	b789                	j	ffffffffc0201bee <vprintfmt+0x1ce>
        return va_arg(*ap, unsigned int);
ffffffffc0201cae:	000a6603          	lwu	a2,0(s4)
ffffffffc0201cb2:	46a1                	li	a3,8
ffffffffc0201cb4:	8a3a                	mv	s4,a4
ffffffffc0201cb6:	b569                	j	ffffffffc0201b40 <vprintfmt+0x120>
ffffffffc0201cb8:	000a6603          	lwu	a2,0(s4)
ffffffffc0201cbc:	46a9                	li	a3,10
ffffffffc0201cbe:	8a3a                	mv	s4,a4
ffffffffc0201cc0:	b541                	j	ffffffffc0201b40 <vprintfmt+0x120>
ffffffffc0201cc2:	000a6603          	lwu	a2,0(s4)
ffffffffc0201cc6:	46c1                	li	a3,16
ffffffffc0201cc8:	8a3a                	mv	s4,a4
ffffffffc0201cca:	bd9d                	j	ffffffffc0201b40 <vprintfmt+0x120>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201ccc:	3781                	addiw	a5,a5,-32
ffffffffc0201cce:	05e00713          	li	a4,94
ffffffffc0201cd2:	f2f775e3          	bgeu	a4,a5,ffffffffc0201bfc <vprintfmt+0x1dc>
                    putch('?', putdat);
ffffffffc0201cd6:	03f00513          	li	a0,63
ffffffffc0201cda:	85a6                	mv	a1,s1
ffffffffc0201cdc:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201cde:	00044783          	lbu	a5,0(s0)
ffffffffc0201ce2:	0405                	addi	s0,s0,1
ffffffffc0201ce4:	3d7d                	addiw	s10,s10,-1
ffffffffc0201ce6:	0007851b          	sext.w	a0,a5
ffffffffc0201cea:	d395                	beqz	a5,ffffffffc0201c0e <vprintfmt+0x1ee>
ffffffffc0201cec:	f00cd3e3          	bgez	s9,ffffffffc0201bf2 <vprintfmt+0x1d2>
ffffffffc0201cf0:	bff1                	j	ffffffffc0201ccc <vprintfmt+0x2ac>
                putch('-', putdat);
ffffffffc0201cf2:	85a6                	mv	a1,s1
ffffffffc0201cf4:	02d00513          	li	a0,45
ffffffffc0201cf8:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc0201cfa:	40800633          	neg	a2,s0
ffffffffc0201cfe:	8a5e                	mv	s4,s7
ffffffffc0201d00:	46a9                	li	a3,10
ffffffffc0201d02:	bd3d                	j	ffffffffc0201b40 <vprintfmt+0x120>
            if (width > 0 && padc != '-') {
ffffffffc0201d04:	01a05663          	blez	s10,ffffffffc0201d10 <vprintfmt+0x2f0>
ffffffffc0201d08:	02d00793          	li	a5,45
ffffffffc0201d0c:	00fd9b63          	bne	s11,a5,ffffffffc0201d22 <vprintfmt+0x302>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201d10:	02800793          	li	a5,40
ffffffffc0201d14:	853e                	mv	a0,a5
ffffffffc0201d16:	00001417          	auipc	s0,0x1
ffffffffc0201d1a:	b1b40413          	addi	s0,s0,-1253 # ffffffffc0202831 <etext+0x9e7>
ffffffffc0201d1e:	5dfd                	li	s11,-1
ffffffffc0201d20:	b5f9                	j	ffffffffc0201bee <vprintfmt+0x1ce>
ffffffffc0201d22:	00001417          	auipc	s0,0x1
ffffffffc0201d26:	b0f40413          	addi	s0,s0,-1265 # ffffffffc0202831 <etext+0x9e7>
                p = "(null)";
ffffffffc0201d2a:	00001717          	auipc	a4,0x1
ffffffffc0201d2e:	b0670713          	addi	a4,a4,-1274 # ffffffffc0202830 <etext+0x9e6>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201d32:	853a                	mv	a0,a4
ffffffffc0201d34:	85e6                	mv	a1,s9
ffffffffc0201d36:	e43a                	sd	a4,8(sp)
ffffffffc0201d38:	084000ef          	jal	ffffffffc0201dbc <strnlen>
ffffffffc0201d3c:	40ad0d3b          	subw	s10,s10,a0
ffffffffc0201d40:	6722                	ld	a4,8(sp)
ffffffffc0201d42:	01a05b63          	blez	s10,ffffffffc0201d58 <vprintfmt+0x338>
                    putch(padc, putdat);
ffffffffc0201d46:	2d81                	sext.w	s11,s11
ffffffffc0201d48:	85a6                	mv	a1,s1
ffffffffc0201d4a:	856e                	mv	a0,s11
ffffffffc0201d4c:	e43a                	sd	a4,8(sp)
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201d4e:	3d7d                	addiw	s10,s10,-1
                    putch(padc, putdat);
ffffffffc0201d50:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201d52:	6722                	ld	a4,8(sp)
ffffffffc0201d54:	fe0d1ae3          	bnez	s10,ffffffffc0201d48 <vprintfmt+0x328>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201d58:	00074783          	lbu	a5,0(a4)
ffffffffc0201d5c:	0007851b          	sext.w	a0,a5
ffffffffc0201d60:	ec0780e3          	beqz	a5,ffffffffc0201c20 <vprintfmt+0x200>
ffffffffc0201d64:	5dfd                	li	s11,-1
ffffffffc0201d66:	b561                	j	ffffffffc0201bee <vprintfmt+0x1ce>

ffffffffc0201d68 <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201d68:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc0201d6a:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201d6e:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201d70:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201d72:	ec06                	sd	ra,24(sp)
ffffffffc0201d74:	f83a                	sd	a4,48(sp)
ffffffffc0201d76:	fc3e                	sd	a5,56(sp)
ffffffffc0201d78:	e0c2                	sd	a6,64(sp)
ffffffffc0201d7a:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc0201d7c:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201d7e:	ca3ff0ef          	jal	ffffffffc0201a20 <vprintfmt>
}
ffffffffc0201d82:	60e2                	ld	ra,24(sp)
ffffffffc0201d84:	6161                	addi	sp,sp,80
ffffffffc0201d86:	8082                	ret

ffffffffc0201d88 <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc0201d88:	00004717          	auipc	a4,0x4
ffffffffc0201d8c:	28873703          	ld	a4,648(a4) # ffffffffc0206010 <SBI_CONSOLE_PUTCHAR>
ffffffffc0201d90:	4781                	li	a5,0
ffffffffc0201d92:	88ba                	mv	a7,a4
ffffffffc0201d94:	852a                	mv	a0,a0
ffffffffc0201d96:	85be                	mv	a1,a5
ffffffffc0201d98:	863e                	mv	a2,a5
ffffffffc0201d9a:	00000073          	ecall
ffffffffc0201d9e:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc0201da0:	8082                	ret

ffffffffc0201da2 <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc0201da2:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc0201da6:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc0201da8:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc0201daa:	cb81                	beqz	a5,ffffffffc0201dba <strlen+0x18>
        cnt ++;
ffffffffc0201dac:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc0201dae:	00a707b3          	add	a5,a4,a0
ffffffffc0201db2:	0007c783          	lbu	a5,0(a5)
ffffffffc0201db6:	fbfd                	bnez	a5,ffffffffc0201dac <strlen+0xa>
ffffffffc0201db8:	8082                	ret
    }
    return cnt;
}
ffffffffc0201dba:	8082                	ret

ffffffffc0201dbc <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc0201dbc:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201dbe:	e589                	bnez	a1,ffffffffc0201dc8 <strnlen+0xc>
ffffffffc0201dc0:	a811                	j	ffffffffc0201dd4 <strnlen+0x18>
        cnt ++;
ffffffffc0201dc2:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201dc4:	00f58863          	beq	a1,a5,ffffffffc0201dd4 <strnlen+0x18>
ffffffffc0201dc8:	00f50733          	add	a4,a0,a5
ffffffffc0201dcc:	00074703          	lbu	a4,0(a4)
ffffffffc0201dd0:	fb6d                	bnez	a4,ffffffffc0201dc2 <strnlen+0x6>
ffffffffc0201dd2:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc0201dd4:	852e                	mv	a0,a1
ffffffffc0201dd6:	8082                	ret

ffffffffc0201dd8 <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201dd8:	00054783          	lbu	a5,0(a0)
ffffffffc0201ddc:	e791                	bnez	a5,ffffffffc0201de8 <strcmp+0x10>
ffffffffc0201dde:	a02d                	j	ffffffffc0201e08 <strcmp+0x30>
ffffffffc0201de0:	00054783          	lbu	a5,0(a0)
ffffffffc0201de4:	cf89                	beqz	a5,ffffffffc0201dfe <strcmp+0x26>
ffffffffc0201de6:	85b6                	mv	a1,a3
ffffffffc0201de8:	0005c703          	lbu	a4,0(a1)
        s1 ++, s2 ++;
ffffffffc0201dec:	0505                	addi	a0,a0,1
ffffffffc0201dee:	00158693          	addi	a3,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201df2:	fef707e3          	beq	a4,a5,ffffffffc0201de0 <strcmp+0x8>
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201df6:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc0201dfa:	9d19                	subw	a0,a0,a4
ffffffffc0201dfc:	8082                	ret
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201dfe:	0015c703          	lbu	a4,1(a1)
ffffffffc0201e02:	4501                	li	a0,0
}
ffffffffc0201e04:	9d19                	subw	a0,a0,a4
ffffffffc0201e06:	8082                	ret
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201e08:	0005c703          	lbu	a4,0(a1)
ffffffffc0201e0c:	4501                	li	a0,0
ffffffffc0201e0e:	b7f5                	j	ffffffffc0201dfa <strcmp+0x22>

ffffffffc0201e10 <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201e10:	ce01                	beqz	a2,ffffffffc0201e28 <strncmp+0x18>
ffffffffc0201e12:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc0201e16:	167d                	addi	a2,a2,-1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201e18:	cb91                	beqz	a5,ffffffffc0201e2c <strncmp+0x1c>
ffffffffc0201e1a:	0005c703          	lbu	a4,0(a1)
ffffffffc0201e1e:	00f71763          	bne	a4,a5,ffffffffc0201e2c <strncmp+0x1c>
        n --, s1 ++, s2 ++;
ffffffffc0201e22:	0505                	addi	a0,a0,1
ffffffffc0201e24:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201e26:	f675                	bnez	a2,ffffffffc0201e12 <strncmp+0x2>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201e28:	4501                	li	a0,0
ffffffffc0201e2a:	8082                	ret
ffffffffc0201e2c:	00054503          	lbu	a0,0(a0)
ffffffffc0201e30:	0005c783          	lbu	a5,0(a1)
ffffffffc0201e34:	9d1d                	subw	a0,a0,a5
}
ffffffffc0201e36:	8082                	ret

ffffffffc0201e38 <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc0201e38:	ca01                	beqz	a2,ffffffffc0201e48 <memset+0x10>
ffffffffc0201e3a:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc0201e3c:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc0201e3e:	0785                	addi	a5,a5,1
ffffffffc0201e40:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc0201e44:	fef61de3          	bne	a2,a5,ffffffffc0201e3e <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc0201e48:	8082                	ret
