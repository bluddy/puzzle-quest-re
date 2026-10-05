
void __thiscall
FUN_004c6b10(int param_1,short param_2,short param_3,int param_4,undefined4 param_5,
            undefined4 param_6)

{
  short sVar1;
  
  sVar1 = FUN_004c9090(*(undefined2 *)(param_1 + 4),param_4);
  if (param_4 != 0) {
    FUN_004c9950(*(undefined2 *)(param_1 + 4),param_4,(int)(short)(param_2 - (sVar1 >> 1)),
                 (int)param_3,param_5,0xffffffff,0xffffffff,0xffffffff,param_6);
  }
  return;
}

