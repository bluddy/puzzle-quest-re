
void __thiscall Engine_DELETE_GEM_47ac70(int param_1,int param_2,int param_3)

{
  if ((((-1 < param_2) && (param_2 < 8)) && (-1 < param_3)) && (param_3 < 9)) {
    param_1 = param_1 + param_3 * 8 + param_2 * 0x48;
    *(undefined4 *)(param_1 + 4) = 0;
    *(undefined1 *)(param_1 + 9) = 0;
    *(undefined1 *)(param_1 + 8) = 0;
  }
  return;
}

