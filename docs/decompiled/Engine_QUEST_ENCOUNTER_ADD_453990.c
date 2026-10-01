
void Engine_QUEST_ENCOUNTER_ADD_453990(undefined4 param_1)

{
  undefined4 uVar1;
  char cVar2;
  
  uVar1 = param_1;
  cVar2 = FUN_00451110(param_1);
  if (cVar2 == '\0') {
    param_1 = uVar1;
    FUN_004534c0(&param_1);
    FUN_004507a0(1);
  }
  return;
}

