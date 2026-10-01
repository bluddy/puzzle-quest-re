
int __fastcall FUN_0043fc10(int param_1)

{
  undefined4 *puVar1;
  undefined4 *puVar2;
  int local_4;
  
  puVar2 = (undefined4 *)(param_1 + 0x10);
  local_4 = 10;
  do {
    puVar1 = puVar2 + 2;
    FUN_00401160(puVar1,4,5,&LAB_00402a10);
    *puVar2 = 0;
    puVar2[1] = 0;
    *(undefined2 *)((int)puVar2 + 10) = 0;
    puVar2 = puVar2 + 7;
    local_4 = local_4 + -1;
    *(undefined2 *)puVar1 = 0;
  } while (local_4 != 0);
  *(undefined4 *)(param_1 + 0x14) = 0;
  *(undefined4 *)(param_1 + 0x30) = 0;
  *(undefined4 *)(param_1 + 0x4c) = 0;
  *(undefined4 *)(param_1 + 0x68) = 0;
  *(undefined4 *)(param_1 + 0x84) = 0;
  *(undefined4 *)(param_1 + 0xa0) = 0;
  *(undefined4 *)(param_1 + 0xbc) = 0;
  *(undefined4 *)(param_1 + 0xd8) = 0;
  *(undefined4 *)(param_1 + 0xf4) = 0;
  *(undefined4 *)(param_1 + 0x110) = 0;
  return param_1;
}

