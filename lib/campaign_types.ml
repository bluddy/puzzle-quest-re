type portrait = { file: string; sex: int; sprite: string; age: int }
type skill_affinities = { earth: int; fire: int; air: int; water: int; battle: int; cunning: int; morale: int }
type start_stats = { earth: int; fire: int; air: int; water: int; battle: int; cunning: int; morale: int; gold: int }
type skill_adds = { earth: float; fire: float; air: float; water: float; battle: float; cunning: float; morale: float; life: float }
type xp_table = { leveladd: int; levels: (int * int) list }  (* level -> xp *)
type spell_table = (int * string) list  (* level -> spell_id *)
