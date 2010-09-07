--  Test driver for library-level generic instantiations. It only "with's" the
--  code with generic units, but does not with's any instantiation, and does
--  not instantiate anything itself. So no functional code shall be reported as
--  covered.

with Pack;
with Stacks_G;
with Support;         use Support;
procedure Test_Instantiations_No is
begin
   Assert (True);
end Test_Instantiations_No;

--# pack.adb
-- /new_value_g/   ~l- ~s-
-- /swap/          l- s-
-- /proc/          l- s-

--#  stacks_g.ads
-- /elab/          ~l- ~s-

--#  stacks_g.adb
-- /push/          ~l- ~s-
-- /pop/           ~l- ~s-
-- /n_values/      ~l- ~s-
-- /default_stack/ ~l- ~s-
-- /elab/          ~l- ~s-

--# update_g.adb
-- /stmt/          ~l- ~s-
