
int __thiscall FUN_00446a60(int param_1,undefined4 param_2,undefined4 param_3)

{
  int iVar1;
  
  iVar1 = Engine_EXTRA_TURN_4646e0();
  iVar1 = Engine_GET_ENEMY_446220
                    (param_2,*(undefined4 *)(iVar1 + 4 + *(int *)(iVar1 + 0x28) * 4),param_3);
  return iVar1 * 0xa8 + *(int *)(param_1 + 8);
}

