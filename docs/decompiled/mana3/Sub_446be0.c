
void __fastcall FUN_00446be0(int param_1)

{
  void *pvVar1;
  undefined4 *puVar2;
  wchar_t *pwVar3;
  int iVar4;
  undefined4 uVar5;
  int iVar6;
  int iVar7;
  int iVar8;
  int *piVar9;
  int iVar10;
  int iStack_21c;
  int iStack_218;
  int iStack_214;
  wchar_t *local_210;
  wchar_t local_20c [260];
  undefined4 local_4;
  
  local_4 = DAT_0057faa0;
  local_210 = (wchar_t *)0x0;
LAB_00446c00:
  do {
    pwVar3 = local_210;
    iVar4 = *(int *)(param_1 + 8);
    if (iVar4 != 0) {
      iVar4 = (*(int *)(param_1 + 0xc) - iVar4) / 0xa8;
    }
    if (iVar4 <= (int)local_210) {
      iVar7 = 0;
      iVar4 = 0;
      while( true ) {
        iVar10 = *(int *)(param_1 + 8);
        if (iVar10 != 0) {
          iVar10 = (*(int *)(param_1 + 0xc) - iVar10) / 0xa8;
        }
        if (iVar10 <= iVar7) break;
        (**(code **)(**(int **)(iVar4 + *(int *)(param_1 + 8)) + 0x20))(1,iVar7,0,0);
        iVar7 = iVar7 + 1;
        iVar4 = iVar4 + 0xa8;
      }
      FUN_005042e3();
      return;
    }
    swprintf(local_20c,0x51c010,local_210);
    iVar4 = FUN_004b2ba0(local_20c);
    if (iVar4 != 0) {
      uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      FUN_004b5690(uVar5);
    }
    iVar4 = (int)pwVar3 * 0xa8;
    if (*(char *)(iVar4 + 0x10 + *(int *)(param_1 + 8)) != '\0') {
      FUN_004679c0(1);
      FUN_0046c3a0(1,*(undefined4 *)
                      (*(int *)((uint)(pwVar3 == (wchar_t *)0x0) * 0xa8 + *(int *)(param_1 + 8)) + 4
                      ));
    }
    (**(code **)(**(int **)(iVar4 + *(int *)(param_1 + 8)) + 0x10))();
    *(undefined4 *)(iVar4 + *(int *)(param_1 + 8) + 0x1c) =
         *(undefined4 *)(*(int *)(iVar4 + *(int *)(param_1 + 8)) + 0x94);
    *(undefined4 *)(iVar4 + *(int *)(param_1 + 8) + 0x20) =
         *(undefined4 *)(*(int *)(iVar4 + *(int *)(param_1 + 8)) + 0x6c);
    *(undefined1 *)(iVar4 + 0x24 + *(int *)(param_1 + 8)) = 0;
    iVar7 = *(int *)(*(int *)(param_1 + 8) + 0xa4 + iVar4);
    piVar9 = (int *)(*(int *)(param_1 + 8) + iVar4);
    if (iVar7 < 0) {
      iVar10 = 1 - *(int *)(*piVar9 + 100);
      if (iVar7 <= iVar10) {
        iVar7 = iVar10;
      }
      piVar9[0x29] = iVar7;
    }
    iVar10 = *(int *)(iVar4 + *(int *)(param_1 + 8));
    iStack_21c = *(int *)(iVar4 + 0xa4 + *(int *)(param_1 + 8));
    iVar7 = iVar10 + 0x48;
    iVar6 = iVar7;
    Engine_ADD_MAX_LIFE_445030(iVar7);
    Engine_ADD_MAX_LIFE_444d40(iVar6);
    *(int *)(iVar10 + 100) = *(int *)(iVar10 + 100) + iStack_21c;
    Engine_ADD_MAX_LIFE_445030(iVar7);
    Engine_ADD_MAX_LIFE_444d80(iVar7);
    iVar10 = *(int *)(*(int *)(param_1 + 8) + iVar4);
    iStack_21c = *(int *)(*(int *)(param_1 + 8) + 0xa4 + iVar4);
    iVar7 = iVar10 + 0x48;
    iVar6 = iVar7;
    Engine_ADD_MAX_LIFE_445030(iVar7);
    Engine_ADD_MAX_LIFE_444d40(iVar6);
    iVar6 = iStack_21c + *(int *)(iVar10 + 0x70);
    if (*(int *)(iVar10 + 100) <= iVar6) {
      iVar6 = *(int *)(iVar10 + 100);
    }
    *(int *)(iVar10 + 0x70) = iVar6;
    Engine_ADD_MAX_LIFE_445030(iVar7);
    Engine_ADD_MAX_LIFE_444d80(iVar7);
    pvVar1 = *(void **)(iVar4 + 0x2c + *(int *)(param_1 + 8));
    iVar7 = iVar4 + 0x28 + *(int *)(param_1 + 8);
    if (pvVar1 != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
      operator_delete(pvVar1);
    }
    *(undefined4 *)(iVar7 + 4) = 0;
    *(undefined4 *)(iVar7 + 8) = 0;
    *(undefined4 *)(iVar7 + 0xc) = 0;
    pvVar1 = *(void **)(iVar4 + 0x3c + *(int *)(param_1 + 8));
    iVar7 = iVar4 + 0x38 + *(int *)(param_1 + 8);
    if (pvVar1 != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
      operator_delete(pvVar1);
    }
    *(undefined4 *)(iVar7 + 4) = 0;
    *(undefined4 *)(iVar7 + 8) = 0;
    *(undefined4 *)(iVar7 + 0xc) = 0;
    iVar7 = iVar4 + 0x48 + *(int *)(param_1 + 8);
    if (*(void **)(iVar7 + 4) != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
      operator_delete(*(void **)(iVar7 + 4));
    }
    *(undefined4 *)(iVar7 + 4) = 0;
    *(undefined4 *)(iVar7 + 8) = 0;
    *(undefined4 *)(iVar7 + 0xc) = 0;
    iStack_214 = 0;
    iVar7 = (**(code **)(**(int **)(iVar4 + *(int *)(param_1 + 8)) + 0x24))();
    if (0 < iVar7) {
      iStack_218 = 0;
      iVar7 = 0;
      do {
        uVar5 = (**(code **)(**(int **)(iVar4 + *(int *)(param_1 + 8)) + 0x28))(iVar7);
        iVar6 = *(int *)(iVar4 + 0x2c + *(int *)(param_1 + 8));
        iVar10 = iVar4 + 0x28 + *(int *)(param_1 + 8);
        if ((iVar6 == 0) ||
           ((uint)(*(int *)(iVar10 + 0xc) - iVar6 >> 2) <= (uint)(*(int *)(iVar10 + 8) - iVar6 >> 2)
           )) {
          FUN_004292c0(*(undefined4 *)(iVar10 + 8),1,&stack0xfffffde0);
        }
        else {
          puVar2 = *(undefined4 **)(iVar10 + 8);
          *puVar2 = uVar5;
          *(undefined4 **)(iVar10 + 8) = puVar2 + 1;
        }
        iVar10 = *(int *)(*(int *)(iVar4 + 0x2c + *(int *)(param_1 + 8)) + iVar7 * 4);
        iVar8 = Engine_HANDLE_SPELL_COST_4622c0();
        iVar6 = *(int *)(iVar4 + 0x3c + *(int *)(param_1 + 8));
        iVar7 = iVar4 + 0x38 + *(int *)(param_1 + 8);
        if ((iVar6 == 0) ||
           ((uint)(*(int *)(iVar7 + 0xc) - iVar6 >> 2) <= (uint)(*(int *)(iVar7 + 8) - iVar6 >> 2)))
        {
          FUN_004292c0(*(undefined4 *)(iVar7 + 8),1,&stack0xfffffde0);
        }
        else {
          puVar2 = *(undefined4 **)(iVar7 + 8);
          *puVar2 = *(undefined4 *)(*(int *)(iVar8 + 8) + 0x44 + iVar10 * 0x48);
          *(undefined4 **)(iVar7 + 8) = puVar2 + 1;
        }
        iVar10 = *(int *)(iVar4 + 0x4c + *(int *)(param_1 + 8));
        iVar7 = iVar4 + 0x48 + *(int *)(param_1 + 8);
        if ((iVar10 == 0) ||
           ((uint)(*(int *)(iVar7 + 0xc) - iVar10 >> 2) <= (uint)(*(int *)(iVar7 + 8) - iVar10 >> 2)
           )) {
          FUN_004292c0(*(undefined4 *)(iVar7 + 8),1,&iStack_21c);
        }
        else {
          puVar2 = *(undefined4 **)(iVar7 + 8);
          *puVar2 = 0;
          *(undefined4 **)(iVar7 + 8) = puVar2 + 1;
        }
        iVar6 = iStack_218 + 1;
        iStack_218 = iVar6;
        iVar10 = (**(code **)(**(int **)(iVar4 + *(int *)(param_1 + 8)) + 0x24))();
        iVar7 = iStack_214;
      } while (iVar6 < iVar10);
    }
    if (*(char *)(*(int *)(param_1 + 8) + 0x10 + iVar4) != '\0') {
      iVar7 = *(int *)(*(int *)(param_1 + 8) + iVar4);
      iVar10 = *(int *)(iVar7 + 0x1b4);
      if ((-1 < iVar10) && (iVar7 = *(int *)(*(int *)(iVar7 + 0x148) + iVar10 * 6), iVar7 != 0)) {
        iVar10 = FUN_004561a0();
        iVar7 = FUN_004560d0(iVar7);
        uVar5 = *(undefined4 *)(iVar7 * 0x270 + 0x124 + *(int *)(iVar10 + 8));
        Engine_HANDLE_SPELL_COST_4622c0(uVar5);
        iVar6 = FUN_00461d30(uVar5);
        iVar10 = *(int *)(iVar4 + 0x2c + *(int *)(param_1 + 8));
        iVar7 = iVar4 + 0x28 + *(int *)(param_1 + 8);
        iStack_218 = iVar6;
        if ((iVar10 == 0) ||
           ((uint)(*(int *)(iVar7 + 0xc) - iVar10 >> 2) <= (uint)(*(int *)(iVar7 + 8) - iVar10 >> 2)
           )) {
          FUN_004292c0(*(undefined4 *)(iVar7 + 8),1,&iStack_218);
        }
        else {
          piVar9 = *(int **)(iVar7 + 8);
          *piVar9 = iVar6;
          *(int **)(iVar7 + 8) = piVar9 + 1;
        }
        iVar7 = Engine_HANDLE_SPELL_COST_4622c0();
        iStack_218 = *(int *)(*(int *)(iVar7 + 8) + 0x44 + iVar6 * 0x48);
        iVar7 = iVar4 + 0x38 + *(int *)(param_1 + 8);
        iVar10 = *(int *)(iVar7 + 4);
        if ((iVar10 == 0) ||
           ((uint)(*(int *)(iVar7 + 0xc) - iVar10 >> 2) <= (uint)(*(int *)(iVar7 + 8) - iVar10 >> 2)
           )) {
          FUN_004292c0(*(undefined4 *)(iVar7 + 8),1,&iStack_218);
        }
        else {
          piVar9 = *(int **)(iVar7 + 8);
          *piVar9 = iStack_218;
          *(int **)(iVar7 + 8) = piVar9 + 1;
        }
        iVar7 = *(int *)(iVar4 + 0x4c + *(int *)(param_1 + 8));
        iVar4 = iVar4 + 0x48 + *(int *)(param_1 + 8);
        iStack_218 = 0;
        if ((iVar7 != 0) &&
           ((uint)(*(int *)(iVar4 + 8) - iVar7 >> 2) < (uint)(*(int *)(iVar4 + 0xc) - iVar7 >> 2)))
        {
          puVar2 = *(undefined4 **)(iVar4 + 8);
          *puVar2 = 0;
          *(undefined4 **)(iVar4 + 8) = puVar2 + 1;
          local_210 = (wchar_t *)((int)local_210 + 1);
          goto LAB_00446c00;
        }
        FUN_004292c0(*(undefined4 *)(iVar4 + 8),1,&iStack_218);
      }
    }
    local_210 = (wchar_t *)((int)local_210 + 1);
  } while( true );
}

