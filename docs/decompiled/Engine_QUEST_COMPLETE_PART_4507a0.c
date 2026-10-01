
void __thiscall Engine_QUEST_COMPLETE_PART_4507a0(int param_1,undefined4 param_2)

{
  undefined4 uVar1;
  int *piVar2;
  
  uVar1 = DAT_0057f484;
  if (DAT_005af27c != '\0') {
    if ((char)param_2 != '\0') {
      FUN_0045adc0();
      FUN_0045af90();
    }
    piVar2 = (int *)**(int **)(param_1 + 0x48);
    if (piVar2 != *(int **)(param_1 + 0x48)) {
      do {
        (**(code **)(*(int *)piVar2[2] + 0xc))(*(undefined4 *)(param_1 + 0x40),uVar1,param_2);
        piVar2 = (int *)*piVar2;
      } while (piVar2 != (int *)*(int *)(param_1 + 0x48));
    }
  }
  return;
}

