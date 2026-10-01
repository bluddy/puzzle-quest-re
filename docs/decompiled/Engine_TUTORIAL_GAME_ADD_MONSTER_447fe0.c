
void __thiscall
Engine_TUTORIAL_GAME_ADD_MONSTER_447fe0(int param_1,ushort *param_2,undefined4 param_3)

{
  uint uVar1;
  undefined4 uVar2;
  
  uVar1 = (((uint)param_2[3] << 8 | (uint)param_2[2]) << 8 | (uint)param_2[1]) << 8 | (uint)*param_2
  ;
  FUN_004561a0(uVar1);
  uVar2 = FUN_004560d0(uVar1);
  *(undefined4 *)(param_1 + 0x84) = uVar2;
  *(undefined4 *)(param_1 + 0x88) = param_3;
  return;
}

