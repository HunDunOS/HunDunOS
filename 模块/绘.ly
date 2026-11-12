00 ========== 绘 —— 给 简 用的绘字/绘块封装 ==========
00 依赖：墨.asm 的 _gfx_text / _gfx_fill（链接时解析）
00 用途：六爻里没法可靠压 5 个参数，这里用寄存器中转
00 卦象 50，落址 0x2C0000

00 ---- 绘字(x, y, 串, 色) ----
00 六爻参数在 [rbp+16] / [rbp+24] / [rbp+32] / [rbp+40]
tt 绘字 01 02 -> u64  08
    zs 08
        sub rsp, 0x28
        mov eax, dword ptr [rbp+16]
        mov dword ptr [rsp+0x0], eax
        mov eax, dword ptr [rbp+24]
        mov dword ptr [rsp+0x8], eax
        mov rax, qword ptr [rbp+32]
        mov qword ptr [rsp+0x10], rax
        mov eax, dword ptr [rbp+40]
        mov dword ptr [rsp+0x18], eax
        call _gfx_text
        add rsp, 0x28
        mov rsp, rbp
        pop rbp
    09
    zz 0
 09

00 ---- 绘块(x, y, w, h, 色) ----
tt 绘块 01 02 -> u64  08
    zs 08
        sub rsp, 0x30
        mov eax, dword ptr [rbp+16]
        mov dword ptr [rsp+0x0], eax
        mov eax, dword ptr [rbp+24]
        mov dword ptr [rsp+0x8], eax
        mov eax, dword ptr [rbp+32]
        mov dword ptr [rsp+0x10], eax
        mov eax, dword ptr [rbp+40]
        mov dword ptr [rsp+0x18], eax
        mov eax, dword ptr [rbp+48]
        mov dword ptr [rsp+0x20], eax
        call _gfx_fill
        add rsp, 0x30
        mov rsp, rbp
        pop rbp
    09
    zz 0
 09
