// refs 0x005828dc @ 0043f870

void CBattleManager_GetSingleton(void)

{
  if (DAT_005828dc == (undefined4 *)0x0) {
    DAT_005828dc = (undefined4 *)FUN_004f0184(0x4c);
    if (DAT_005828dc != (undefined4 *)0x0) {
      *DAT_005828dc = &PTR_LAB_0052135c;
      DAT_005828dc[0x12] = 1;
      return;
    }
    DAT_005828dc = (undefined4 *)0x0;
  }
  return;
}

