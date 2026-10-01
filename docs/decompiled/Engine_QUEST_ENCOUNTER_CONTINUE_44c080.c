
void Engine_QUEST_ENCOUNTER_CONTINUE_44c080(void)

{
  if (DAT_00582964 == (undefined4 *)0x0) {
    DAT_00582964 = (undefined4 *)FUN_004f0184(0x248);
    if (DAT_00582964 != (undefined4 *)0x0) {
      *DAT_00582964 = &PTR_LAB_005217a8;
      *(undefined2 *)(DAT_00582964 + 2) = 0xffff;
      *(undefined2 *)((int)DAT_00582964 + 10) = 0xffff;
      *(undefined2 *)(DAT_00582964 + 0x8f) = 0xffff;
      *(undefined2 *)((int)DAT_00582964 + 0x23e) = 0xffff;
      *(undefined2 *)(DAT_00582964 + 0x90) = 0xffff;
      *(undefined2 *)((int)DAT_00582964 + 0x242) = 0xffff;
      return;
    }
    DAT_00582964 = (undefined4 *)0x0;
  }
  return;
}

