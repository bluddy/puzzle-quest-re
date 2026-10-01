
void Engine_QUEST_LOAD_INT_467d30(uint *param_1)

{
  int *piVar1;
  byte bVar2;
  
  if (DAT_005829cc != 0) {
    bVar2 = *(byte *)(*(int *)(DAT_005829cc + 0x24c) + 0x22f + DAT_005829cc);
    *(int *)(DAT_005829cc + 0x24c) = *(int *)(DAT_005829cc + 0x24c) + 1;
    if (bVar2 == 0xff) {
      piVar1 = (int *)(DAT_005829cc + 0x24c);
      *param_1 = *(uint *)(*(int *)(DAT_005829cc + 0x24c) + 0x22f + DAT_005829cc);
      *piVar1 = *piVar1 + 4;
      return;
    }
    *param_1 = (uint)bVar2;
  }
  return;
}

