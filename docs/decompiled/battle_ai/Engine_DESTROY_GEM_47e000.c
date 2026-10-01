
void __thiscall Engine_DESTROY_GEM_47e000(int param_1,int param_2,int param_3)

{
  int iVar1;
  undefined4 *puVar2;
  undefined1 local_12d;
  undefined4 local_12c;
  int local_128;
  int local_124;
  undefined1 local_120;
  undefined4 local_11c;
  
  if ((((-1 < param_2) && (param_2 < 8)) && (-1 < param_3)) && (param_3 < 9)) {
    local_12c = 1;
    FUN_0043fc10();
    local_128 = param_2;
    local_124 = param_3;
    local_120 = 1;
    local_11c = 1;
    FUN_0047b0c0(*(undefined4 *)(param_1 + 4 + param_3 * 8 + param_2 * 0x48),param_2,param_3,
                 &local_128,&local_12d,&local_12c);
    puVar2 = (undefined4 *)(param_1 + 0x3e4);
    for (iVar1 = 0x12; iVar1 != 0; iVar1 = iVar1 + -1) {
      *puVar2 = 0;
      puVar2 = puVar2 + 1;
    }
    FUN_0047a6c0(&local_128);
    FUN_0047cd90(&local_128);
  }
  return;
}

