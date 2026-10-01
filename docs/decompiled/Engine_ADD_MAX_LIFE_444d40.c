
void __thiscall Engine_ADD_MAX_LIFE_444d40(int param_1,undefined4 param_2)

{
  int iVar1;
  
  iVar1 = FUN_00444700(param_2);
  if ((-1 < iVar1) && (*(char *)(*(int *)(param_1 + 8) + 1 + iVar1 * 0x1c) != '\0')) {
    FUN_00444b00(iVar1);
    *(undefined1 *)(*(int *)(param_1 + 8) + iVar1 * 0x1c + 1) = 0;
  }
  return;
}

