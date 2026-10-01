
void Engine_QUEST_SAVE_INT_467d90(int param_1)

{
  int *piVar1;
  undefined1 local_1;
  
  if (DAT_005829cc != 0) {
    if ((-1 < param_1) && (param_1 < 0xff)) {
      FUN_00467660(&local_1,1);
      return;
    }
    piVar1 = (int *)(DAT_005829cc + 0x24c);
    *(undefined1 *)(DAT_005829cc + 0x22f + *piVar1) = 0xff;
    *piVar1 = *piVar1 + 1;
    piVar1 = (int *)(DAT_005829cc + 0x24c);
    *(int *)(DAT_005829cc + 0x22f + *(int *)(DAT_005829cc + 0x24c)) = param_1;
    *piVar1 = *piVar1 + 4;
  }
  return;
}

