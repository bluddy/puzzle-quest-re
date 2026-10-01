
int __thiscall Engine_SET_GAMEPAD_OBJECT_4c2a10(int param_1,wchar_t *param_2)

{
  int iVar1;
  int *piVar2;
  
  piVar2 = (int *)**(int **)(param_1 + 0x38);
  if (piVar2 != *(int **)(param_1 + 0x38)) {
    do {
      iVar1 = wcscmp(param_2,(wchar_t *)(piVar2[2] + 0x32));
      if (iVar1 == 0) {
        return piVar2[2];
      }
      piVar2 = (int *)*piVar2;
    } while (piVar2 != (int *)*(int *)(param_1 + 0x38));
  }
  return 0;
}

