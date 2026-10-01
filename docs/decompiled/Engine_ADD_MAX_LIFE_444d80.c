
void Engine_ADD_MAX_LIFE_444d80(undefined4 param_1)

{
  int iVar1;
  int extraout_ECX;
  
  iVar1 = FUN_00444700(param_1);
  if (-1 < iVar1) {
    if (*(char *)(iVar1 * 0x1c + 1 + *(int *)(extraout_ECX + 8)) == '\0') {
      *(undefined1 *)(iVar1 * 0x1c + *(int *)(extraout_ECX + 8) + 1) = 1;
      FUN_00444760();
      return;
    }
  }
  return;
}

