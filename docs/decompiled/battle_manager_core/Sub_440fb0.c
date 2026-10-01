
void __fastcall FUN_00440fb0(int param_1)

{
  int iVar1;
  undefined4 uVar2;
  int iVar3;
  int iVar4;
  int *local_10c;
  char local_f8;
  int iStack_c0;
  ushort uStack_64;
  ushort uStack_62;
  ushort uStack_60;
  ushort uStack_5e;
  undefined2 uStack_5c;
  byte bStack_52;
  undefined4 uStack_54;
  byte bStack_51;
  short sStack_2c;
  short sStack_2a;
  short sStack_28;
  short sStack_26;
  undefined4 local_10;
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_005121a3;
  local_c = ExceptionList;
  local_10 = DAT_0057faa0;
  ExceptionList = &local_c;
  iVar1 = Engine_EXTRA_TURN_4646e0();
  uVar2 = *(undefined4 *)(iVar1 + 4 + *(int *)(iVar1 + 0x28) * 4);
  Engine_ADD_GOLD_447c60(uVar2);
  uVar2 = Engine_ADD_GOLD_446200(uVar2);
  Engine_ADD_GOLD_404570(uVar2);
  local_4 = 0;
  if (local_f8 == '\0') {
    Engine_ADD_GOLD_4046a0();
  }
  else {
    iVar4 = 0;
    iVar1 = (**(code **)(*local_10c + 0x24))();
    if (0 < iVar1) {
      do {
        iVar1 = (**(code **)(*local_10c + 0x28))(iVar4);
        iVar3 = Engine_HANDLE_SPELL_COST_4622c0();
        Engine_IS_SPELL_CASTABLE_40d4d0(*(int *)(iVar3 + 8) + iVar1 * 0x48);
        local_4._0_1_ = 1;
        if ((((((local_10c[0x1d] < (int)sStack_2c) || (local_10c[0x1e] < (int)sStack_2a)) ||
              (local_10c[0x20] < (int)sStack_26)) ||
             ((local_10c[0x1f] < (int)sStack_28 || (0 < *(int *)(iStack_c0 + iVar4 * 4))))) ||
            ((*(int *)(param_1 + 0x48) == 0 && (iVar1 = FUN_004bd1f0(1,100,0), iVar1 < 0x32)))) ||
           ((*(int *)(param_1 + 0x48) == 1 && (iVar1 = FUN_004bd1f0(1,100,0), iVar1 < 0x19)))) {
          local_4 = (uint)local_4._1_3_ << 8;
        }
        else {
          uStack_64 = (ushort)uStack_54 & 0xff;
          uStack_62 = (ushort)(byte)((uint)uStack_54 >> 8);
          uStack_60 = (ushort)bStack_52;
          uStack_5e = (ushort)bStack_51;
          uStack_5c = 0;
          iVar1 = FUN_00484670(&uStack_64);
          local_4 = (uint)local_4._1_3_ << 8;
          if (iVar1 != 0) {
            *(int *)(param_1 + 0x44) = iVar4;
            *(undefined1 *)(param_1 + 0x2c) = 0;
            Engine_IS_SPELL_CASTABLE_474b40();
            Engine_ADD_GOLD_4046a0();
            goto LAB_004411b9;
          }
        }
        Engine_IS_SPELL_CASTABLE_474b40();
        iVar4 = iVar4 + 1;
        iVar1 = (**(code **)(*local_10c + 0x24))();
      } while (iVar4 < iVar1);
    }
    Engine_ADD_GOLD_4046a0();
  }
LAB_004411b9:
  ExceptionList = local_c;
  FUN_005042e3();
  return;
}

